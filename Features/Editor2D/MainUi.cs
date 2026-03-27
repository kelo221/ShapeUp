using System;
using System.Globalization;
using Godot;
using GVector2 = Godot.Vector2;
using GVector3 = Godot.Vector3;
using ShapeUp.Core.ShapeEditor;
using ShapeUp.Infrastructure.Clipboard;
using ShapeUp.Infrastructure.Mesh;
using UnityEngine;

namespace ShapeUp.Features.Editor2D;

/// <summary>Root UI: menu bar, icon toolbar, left tool palette, 2D editor, 3D preview, status bar.</summary>
public partial class MainUi : Control
{
    // Menu item IDs
    const int MFile_Open = 100;
    const int MFile_Save = 101;
    const int MFile_CopyBrushes = 102;
    const int MFile_CopyGodotMap = 103;
    const int MEdit_Undo = 200;
    const int MEdit_Redo = 201;
    const int MEdit_SelectAll = 210;
    const int MEdit_ClearSel = 211;
    const int MEdit_InvertSel = 212;
    const int MEdit_FlipH = 220;
    const int MEdit_FlipV = 221;
    const int MEdit_SnapSel = 222;
    const int MEdit_CopyShapes = 223;
    const int MEdit_PasteShapes = 224;
    const int MEdit_DupSelShapes = 225;
    const int MEdit_ExtrudeEdges = 226;
    const int MEdge_ToBezier = 300;
    const int MEdge_ToLinear = 301;
    const int MEdge_Arch = 310;
    const int MEdge_Sine = 311;
    const int MEdge_Repeat = 312;
    const int MEdge_ApplyGen = 320;
    const int MEdge_ApplyProps = 321;
    const int MShape_Add = 400;
    const int MShape_Dup = 401;
    const int MShape_MoveUp = 410;
    const int MShape_MoveDown = 411;
    const int MShape_BoolUnion = 420;
    const int MShape_BoolDiff = 421;
    const int MShape_SymH = 430;
    const int MShape_SymV = 431;
    const int MShape_FromSel = 432;
    const int MShape_ApplySym = 433;
    const int MShape_PushFront = 434;
    const int MShape_PushBack = 435;
    const int MView_Top = 500;
    const int MView_Front = 501;
    const int MView_Right = 502;
    const int MView_Iso = 503;
    const int MView_BgImage = 504;
    const int MTools_Circle = 600;

    ShapeExtrusionTarget _extrusion = new();
    ShapeEditor2DView? _view;
    OptionButton? _modeOption;
    LineEdit? _groupName;
    SpinBox? _fixedDistance;
    SpinBox? _bezierDetailSpin;
    MeshInstance3D? _previewMesh;
    Camera3D? _previewCam;
    PreviewCameraOrbit? _previewOrbit;
    Label? _statusLabel;

    PopupMenu? _menuFile;
    PopupMenu? _menuEdit;
    PopupMenu? _menuEdge;
    PopupMenu? _menuShape;
    PopupMenu? _menuView;
    PopupMenu? _menuTools;

    Button[]? _toolPaletteButtons;
    readonly Editor2DTool[] _toolPaletteToolOrder =
    {
        Editor2DTool.Select,
        Editor2DTool.Move,
        Editor2DTool.Rotate,
        Editor2DTool.Draw,
        Editor2DTool.Cut,
        Editor2DTool.Measure,
    };

    SpinBox? _snapSpin;
    CheckButton? _snapToggle;
    CheckButton? _chkClickEdgeAdd;

    bool _previewAutoFrameOnce;
    bool _previewFrameOblique;

    public override void _Ready()
    {
        _extrusion.SetProject(new Project());
        _extrusion.SplineControlPoints.Add(new UnityEngine.Vector3(0f, 0f, 0f));
        _extrusion.SplineControlPoints.Add(new UnityEngine.Vector3(0f, 0f, 0.5f));
        _extrusion.SplineControlPoints.Add(new UnityEngine.Vector3(0.5f, 0f, 0.5f));

        ProcessMode = ProcessModeEnum.Always;

        var root = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        root.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(root);

        // ── Menu Bar ──
        var menuBar = BuildMenuBar();
        root.AddChild(menuBar);

        // ── Icon Toolbar ──
        var iconToolbar = BuildIconToolbar();
        root.AddChild(iconToolbar);

        // ── Editor Enhancements (mode panels only) ──
        SetupEditorEnhancements(root);

        // ── Main Area: tool palette + split (2D + 3D) ──
        var mainArea = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        root.AddChild(mainArea);

        var toolPalette = BuildToolPalette();
        mainArea.AddChild(toolPalette);

        var split = new HSplitContainer { SizeFlagsVertical = SizeFlags.ExpandFill, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        mainArea.AddChild(split);

        _view = new ShapeEditor2DView
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
            TooltipText = "Wheel: zoom • Ctrl+wheel (Cmd+wheel on Mac): finer/coarser grid (snap step) • MMB: pan • Drag box: select • Drag vertex/edge: move • Edge: Shift+click both corners (or click edge) → Right-click for Bezier/Arch • Dbl-click edge: add vertex • Del: remove vertices",
        };
        _view.Project = _extrusion.project;
        _view.SnapIncrement = TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast((float)_snapSpin!.Value);
        _view.SnapIncrementAdjusted += OnViewportSnapIncrementAdjusted;
        _view.SnapEnabled = _snapToggle!.ButtonPressed;
        _view.ProjectChanged += OnProjectEdited;
        _view.BeforeProjectMutation = () => _undo.PushBeforeMutation(_extrusion.project);
        _chkClickEdgeAdd!.Toggled += v => _view.ClickInsertVertexMode = v;
        split.AddChild(_view);
        WireEdgeContextMenu();
        SetViewportTool(Editor2DTool.Select);

        // ── 3D Preview ──
        var previewCol = BuildPreviewPanel();
        split.AddChild(previewCol);

        // ── Status Bar ──
        var statusBar = new HBoxContainer { CustomMinimumSize = new GVector2(0, 26) };
        root.AddChild(statusBar);

        _statusLabel = new Label
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            VerticalAlignment = VerticalAlignment.Center,
            AutowrapMode = TextServer.AutowrapMode.Off,
        };
        statusBar.AddChild(_statusLabel);

        _previewAutoFrameOnce = true;
        RefreshPreview();
    }

    // ── Menu Bar ──

    MenuBar BuildMenuBar()
    {
        var bar = new MenuBar();

        _menuFile = AddMenu(bar, "File");
        _menuFile.AddItem("Open…", MFile_Open);
        _menuFile.SetItemShortcut(0, MkShortcut(Key.O, ctrl: true));
        _menuFile.AddItem("Save As…", MFile_Save);
        _menuFile.SetItemShortcut(1, MkShortcut(Key.S, ctrl: true, shift: true));
        _menuFile.AddSeparator();
        _menuFile.AddItem("Copy TrenchBroom Brushes", MFile_CopyBrushes);
        _menuFile.AddItem("Copy .map for Godot (same as toolbar copy)", MFile_CopyGodotMap);
        _menuFile.IdPressed += OnFileMenuPressed;

        _menuEdit = AddMenu(bar, "Edit");
        _menuEdit.AddItem("Undo", MEdit_Undo);
        _menuEdit.SetItemShortcut(0, MkShortcut(Key.Z, ctrl: true));
        _menuEdit.AddItem("Redo", MEdit_Redo);
        _menuEdit.SetItemShortcut(1, MkShortcut(Key.Y, ctrl: true));
        _menuEdit.AddSeparator();
        _menuEdit.AddItem("Select All", MEdit_SelectAll);
        _menuEdit.SetItemShortcut(3, MkShortcut(Key.A, ctrl: true));
        _menuEdit.AddItem("Clear Selection", MEdit_ClearSel);
        _menuEdit.AddItem("Invert Selection", MEdit_InvertSel);
        _menuEdit.AddSeparator();
        _menuEdit.AddItem("Flip Horizontal", MEdit_FlipH);
        _menuEdit.AddItem("Flip Vertical", MEdit_FlipV);
        _menuEdit.AddItem("Snap to Grid", MEdit_SnapSel);
        _menuEdit.AddSeparator();
        _menuEdit.AddItem("Copy shapes", MEdit_CopyShapes);
        _menuEdit.AddItem("Paste shapes", MEdit_PasteShapes);
        _menuEdit.AddItem("Duplicate selected shapes", MEdit_DupSelShapes);
        _menuEdit.AddItem("Extrude selected edges", MEdit_ExtrudeEdges);
        _menuEdit.IdPressed += OnEditMenuPressed;

        _menuEdge = AddMenu(bar, "Edge");
        _menuEdge.AddItem("Convert to Bezier", MEdge_ToBezier);
        _menuEdge.AddItem("Convert to Linear", MEdge_ToLinear);
        _menuEdge.AddSeparator();
        _menuEdge.AddItem("Toggle Arch", MEdge_Arch);
        _menuEdge.AddItem("Toggle Sine", MEdge_Sine);
        _menuEdge.AddItem("Toggle Repeat", MEdge_Repeat);
        _menuEdge.AddSeparator();
        _menuEdge.AddItem("Apply Generators", MEdge_ApplyGen);
        _menuEdge.AddItem("Apply Props to Selection", MEdge_ApplyProps);
        _menuEdge.IdPressed += OnEdgeMenuPressed;

        _menuShape = AddMenu(bar, "Shape");
        _menuShape.AddItem("Add Shape", MShape_Add);
        _menuShape.AddItem("Duplicate Shape", MShape_Dup);
        _menuShape.AddSeparator();
        _menuShape.AddItem("Move Up", MShape_MoveUp);
        _menuShape.AddItem("Move Down", MShape_MoveDown);
        _menuShape.AddSeparator();
        _menuShape.AddItem("Boolean: Union", MShape_BoolUnion);
        _menuShape.AddItem("Boolean: Difference", MShape_BoolDiff);
        _menuShape.AddSeparator();
        _menuShape.AddCheckItem("Symmetry Horizontal", MShape_SymH);
        _menuShape.AddCheckItem("Symmetry Vertical", MShape_SymV);
        _menuShape.AddSeparator();
        _menuShape.AddItem("Shape from selection", MShape_FromSel);
        _menuShape.AddItem("Apply symmetry (bake mirrors)", MShape_ApplySym);
        _menuShape.AddSeparator();
        _menuShape.AddItem("Push selected to front", MShape_PushFront);
        _menuShape.AddItem("Push selected to back", MShape_PushBack);
        _menuShape.IdPressed += OnShapeMenuPressed;

        _menuView = AddMenu(bar, "View");
        _menuView.AddItem("Top", MView_Top);
        _menuView.AddItem("Front", MView_Front);
        _menuView.AddItem("Right", MView_Right);
        _menuView.AddItem("Iso", MView_Iso);
        _menuView.AddSeparator();
        _menuView.AddItem("Background image…", MView_BgImage);
        _menuView.IdPressed += OnViewMenuPressed;

        _menuTools = AddMenu(bar, "Tools");
        _menuTools.AddItem("Circle shape…", MTools_Circle);
        _menuTools.IdPressed += OnToolsMenuPressed;

        return bar;
    }

    static PopupMenu AddMenu(MenuBar bar, string title)
    {
        var popup = new PopupMenu { Name = title };
        bar.AddChild(popup);
        return popup;
    }

    static Shortcut MkShortcut(Key key, bool ctrl = false, bool shift = false)
    {
        var ev = new InputEventKey { Keycode = key, CtrlPressed = ctrl, ShiftPressed = shift };
        var sc = new Shortcut();
        sc.Events = new Godot.Collections.Array { ev };
        return sc;
    }

    void OnFileMenuPressed(long id)
    {
        switch ((int)id)
        {
            case MFile_Open: OnOpenProject(); break;
            case MFile_Save: OnSaveProject(); break;
            case MFile_CopyBrushes: OnCopyPressed(); break;
            case MFile_CopyGodotMap: OnCopyGodotMapPressed(); break;
        }
    }

    void OnEditMenuPressed(long id)
    {
        switch ((int)id)
        {
            case MEdit_Undo: OnUndo(); break;
            case MEdit_Redo: OnRedo(); break;
            case MEdit_SelectAll:
                _extrusion.project.SelectAll();
                _view?.QueueRedraw();
                OnProjectEdited();
                break;
            case MEdit_ClearSel:
                _extrusion.project.ClearSelection();
                _view?.QueueRedraw();
                break;
            case MEdit_InvertSel:
                _extrusion.project.InvertSelection();
                _view?.QueueRedraw();
                OnProjectEdited();
                break;
            case MEdit_FlipH: _view?.FlipSelectionHorizontally(); break;
            case MEdit_FlipV: _view?.FlipSelectionVertically(); break;
            case MEdit_SnapSel: _view?.SnapSelectionToGrid(); break;
            case MEdit_CopyShapes: OnCopyShapesInternal(); break;
            case MEdit_PasteShapes: OnPasteShapesInternal(); break;
            case MEdit_DupSelShapes: OnDuplicateSelectedShapes(); break;
            case MEdit_ExtrudeEdges: OnExtrudeSelectedEdges(); break;
        }
    }

    void OnEdgeMenuPressed(long id)
    {
        switch ((int)id)
        {
            case MEdge_ToBezier: OnConvertToBezier(); break;
            case MEdge_ToLinear: _view?.ConvertSelectedEdgeToLinear(); break;
            case MEdge_Arch: ToggleEdges(SegmentGeneratorType.Arch); break;
            case MEdge_Sine: ToggleEdges(SegmentGeneratorType.Sine); break;
            case MEdge_Repeat: ToggleEdges(SegmentGeneratorType.Repeat); break;
            case MEdge_ApplyGen: OnApplyGenerators(); break;
            case MEdge_ApplyProps: OnApplyGeneratorPropsToSelection(); break;
        }
    }

    void OnShapeMenuPressed(long id)
    {
        switch ((int)id)
        {
            case MShape_Add: OnAddShape(); break;
            case MShape_Dup: OnDuplicateShape(); break;
            case MShape_MoveUp: MoveShape(-1); break;
            case MShape_MoveDown: MoveShape(1); break;
            case MShape_BoolUnion:
                if (_boolPicker != null) { _boolPicker.Select(0); OnBooleanOpSelected(0); }
                break;
            case MShape_BoolDiff:
                if (_boolPicker != null) { _boolPicker.Select(1); OnBooleanOpSelected(1); }
                break;
            case MShape_SymH:
                if (_symH != null) { _symH.ButtonPressed = !_symH.ButtonPressed; OnSymmetryToggled(false); }
                break;
            case MShape_SymV:
                if (_symV != null) { _symV.ButtonPressed = !_symV.ButtonPressed; OnSymmetryToggled(false); }
                break;
            case MShape_FromSel: OnShapeFromSelection(); break;
            case MShape_ApplySym: OnApplySymmetryForSelectedShapes(); break;
            case MShape_PushFront: OnPushSelectedShapes(true); break;
            case MShape_PushBack: OnPushSelectedShapes(false); break;
        }
    }

    void OnViewMenuPressed(long id)
    {
        switch ((int)id)
        {
            case MView_Top: _previewOrbit?.SetPresetTop(); break;
            case MView_Front: _previewOrbit?.SetPresetFront(); break;
            case MView_Right: _previewOrbit?.SetPresetRight(); break;
            case MView_Iso:
                _previewAutoFrameOnce = true;
                _previewFrameOblique = true;
                RefreshPreview();
                break;
            case MView_BgImage: OnPickBackgroundImage(); break;
        }
    }

    void OnToolsMenuPressed(long id)
    {
        if ((int)id == MTools_Circle)
            OnCircleShapeDialog();
    }

    // ── Icon Toolbar ──

    HBoxContainer BuildIconToolbar()
    {
        var bar = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Begin };

        bar.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_new.svg", ApplyNewProject, "New project"));
        bar.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_open.svg", OnOpenProject, "Open… (Ctrl+O)"));
        bar.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_save.svg", OnSaveProject, "Save As… (Ctrl+Shift+S)"));
        bar.AddChild(new VSeparator());
        bar.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_undo.svg", OnUndo, "Undo (Ctrl+Z)"));
        bar.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_redo.svg", OnRedo, "Redo (Ctrl+Y)"));
        bar.AddChild(new VSeparator());
        bar.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_copy_export.svg", OnCopyPressed,
            "Copy .map text (worldspawn + nested brushes) for TrenchBroom paste or FuncGodot. File → Copy .map for Godot… is the same format."));
        bar.AddChild(new VSeparator());

        _modeOption = new OptionButton();
        foreach (ShapeEditorTargetMode m in Enum.GetValues(typeof(ShapeEditorTargetMode)))
            _modeOption.AddItem(m.ToString(), (int)m);
        _modeOption.Select((int)_extrusion.targetMode);
        _modeOption.ItemSelected += OnModeSelected;
        bar.AddChild(_modeOption);

        _groupName = new LineEdit
        {
            Text = "ShapeUp",
            PlaceholderText = "Name (optional)",
            CustomMinimumSize = new GVector2(140, 0),
        };
        bar.AddChild(_groupName);

        bar.AddChild(new VSeparator());

        bar.AddChild(new Label { Text = "Snap:" });
        // Step must be fine enough that Godot's SpinBox shows enough decimals (TB steps like 0.125 were rounded to "0.13").
        // Arrows still move by 1/64 via CustomArrowStep.
        _snapSpin = new SpinBox
        {
            MinValue = 1.0 / 64.0,
            MaxValue = 4,
            Step = 1.0 / 4096.0,
            CustomArrowStep = 1.0 / 64.0,
            Value = 0.125,
            CustomMinimumSize = new GVector2(88, 0),
            TooltipText = "Snap step in ShapeUp world units (1 unit = 64 Quake/TB map units). Values snap to powers of two in TB space (1/64 … 4). Ctrl+scroll in the 2D view steps finer/coarser.",
        };
        _snapSpin.ValueChanged += OnSnapSpinValueChanged;
        bar.AddChild(_snapSpin);

        _snapToggle = new CheckButton { Text = "On", ButtonPressed = true };
        _snapToggle.Toggled += on =>
        {
            if (_view != null) _view.SnapEnabled = on;
        };
        bar.AddChild(_snapToggle);

        bar.AddChild(new VSeparator());

        bar.AddChild(new Label { Text = "Extrude:" });
        _fixedDistance = new SpinBox
        {
            MinValue = 0.05,
            MaxValue = 50,
            Step = 0.05,
            Value = _extrusion.fixedExtrudeDistance,
            CustomMinimumSize = new GVector2(72, 0),
        };
        _fixedDistance.ValueChanged += v =>
        {
            _extrusion.fixedExtrudeDistance = (float)v;
            RefreshPreview();
        };
        bar.AddChild(_fixedDistance);

        bar.AddChild(new Label { Text = "Bezier:" });
        _bezierDetailSpin = new SpinBox
        {
            MinValue = 2,
            MaxValue = 64,
            Step = 1,
            Rounded = true,
            Value = 8,
            CustomMinimumSize = new GVector2(56, 0),
            TooltipText = "Smoothness of Bezier edges. Select edge (both endpoints) → right-click → Bezier, then drag handles.",
        };
        _bezierDetailSpin.ValueChanged += v => ApplyBezierDetailToAll((int)v);
        bar.AddChild(_bezierDetailSpin);

        _chkClickEdgeAdd = new CheckButton { Text = "Click+Add", TooltipText = "Single-click an edge to insert a vertex." };
        bar.AddChild(_chkClickEdgeAdd);

        return bar;
    }

    // ── Tool Palette (left side) ──

    VBoxContainer BuildToolPalette()
    {
        var palette = new VBoxContainer
        {
            CustomMinimumSize = new GVector2(32, 0),
        };

        _toolPaletteButtons = new Button[_toolPaletteToolOrder.Length];
        void AddTool(string icon, Editor2DTool tool, string tip)
        {
            var i = Array.IndexOf(_toolPaletteToolOrder, tool);
            var b = MkIconBtn(icon, () => SetViewportTool(tool), tip);
            if (i >= 0)
                _toolPaletteButtons[i] = b;
            palette.AddChild(b);
        }

        AddTool("res://Features/Editor2D/icons/icon_select.svg", Editor2DTool.Select, "Select (pointer)");
        AddTool("res://Features/Editor2D/icons/icon_move.svg", Editor2DTool.Move, "Move vertices (drag)");
        AddTool("res://Features/Editor2D/icons/icon_rotate.svg", Editor2DTool.Rotate, "Click-drag to rotate around centroid; with snap on, angle steps match grid (180° / 90° / 45° / 22.5° / … from snap size). R / ↻ = Rot°");
        AddTool("res://Features/Editor2D/icons/icon_draw.svg", Editor2DTool.Draw, "Draw: single-click edges to add vertices");
        AddTool("res://Features/Editor2D/icons/icon_cut.svg", Editor2DTool.Cut, "Cut: click edge to insert vertex");
        AddTool("res://Features/Editor2D/icons/icon_measure.svg", Editor2DTool.Measure, "Measure tape (drag; key 4)");
        palette.AddChild(MkIconBtn("res://Features/Editor2D/icons/icon_snap.svg", () =>
        {
            if (_snapToggle != null) _snapToggle.ButtonPressed = !_snapToggle.ButtonPressed;
        }, "Toggle snap"));

        return palette;
    }

    void SetViewportTool(Editor2DTool tool)
    {
        if (_view != null)
            _view.ActiveTool = tool;
        if (_toolPaletteButtons == null)
            return;
        for (var i = 0; i < _toolPaletteButtons.Length; i++)
        {
            var active = _toolPaletteToolOrder[i] == tool;
            _toolPaletteButtons[i].Modulate = active ? Colors.White : new Godot.Color(0.52f, 0.52f, 0.55f);
        }
    }

    // ── 3D Preview Panel ──

    VBoxContainer BuildPreviewPanel()
    {
        var previewCol = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };

        var previewToolbar = new HBoxContainer();
        previewCol.AddChild(previewToolbar);
        previewToolbar.AddChild(new Label { Text = "3D view:" });

        void AddViewBtn(string text, Action act, string tip)
        {
            var b = new Button { Text = text, TooltipText = tip };
            b.Pressed += () => act();
            previewToolbar.AddChild(b);
        }

        AddViewBtn("Top", () => _previewOrbit?.SetPresetTop(), "Plan view (top-down)");
        AddViewBtn("Front", () => _previewOrbit?.SetPresetFront(), "Front view (−Z)");
        AddViewBtn("Right", () => _previewOrbit?.SetPresetRight(), "Right view (+X)");
        AddViewBtn("Iso", () =>
        {
            _previewAutoFrameOnce = true;
            _previewFrameOblique = true;
            RefreshPreview();
        }, "Re-frame camera (oblique)");

        var sub = new SubViewportContainer
        {
            Stretch = true,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
            CustomMinimumSize = new GVector2(200, 200),
            TooltipText = "Right-drag: orbit • Mid-drag: pan • Wheel: zoom",
        };
        previewCol.AddChild(sub);

        var vp = new SubViewport
        {
            HandleInputLocally = true,
            Size = new Vector2I(512, 512),
            RenderTargetUpdateMode = SubViewport.UpdateMode.WhenVisible,
            ScreenSpaceAA = SubViewport.ScreenSpaceAAEnum.Smaa,
        };
        sub.AddChild(vp);

        _previewOrbit = new PreviewCameraOrbit();
        vp.AddChild(_previewOrbit);

        _previewOrbit.AddChild(new DirectionalLight3D
        {
            Transform = new Transform3D(Basis.Identity.Rotated(GVector3.Right, Godot.Mathf.DegToRad(-48f))
                .Rotated(GVector3.Up, Godot.Mathf.DegToRad(-28f)), new GVector3(0f, 2.2f, 0f)),
            LightEnergy = 1.05f,
        });

        _previewOrbit.AddChild(new DirectionalLight3D
        {
            Transform = new Transform3D(Basis.Identity.Rotated(GVector3.Up, Godot.Mathf.DegToRad(115f))
                .Rotated(GVector3.Right, Godot.Mathf.DegToRad(35f)), GVector3.Zero),
            LightColor = new Godot.Color(0.82f, 0.88f, 1f),
            LightEnergy = 0.32f,
        });

        _previewCam = new Camera3D
        {
            Fov = 55f,
            Near = 0.01f,
            Far = 256f,
            Environment = new Godot.Environment
            {
                AmbientLightSource = Godot.Environment.AmbientSource.Color,
                AmbientLightColor = new Godot.Color(0.2f, 0.21f, 0.24f),
                AmbientLightEnergy = 0.45f,
            },
        };
        _previewOrbit.AddChild(_previewCam);
        _previewOrbit.Camera = _previewCam;

        _previewMesh = new MeshInstance3D
        {
            MaterialOverride = new StandardMaterial3D
            {
                AlbedoColor = new Godot.Color(0.76f, 0.78f, 0.8f),
                Roughness = 0.78f,
                Metallic = 0.06f,
            },
        };
        _previewOrbit.AddChild(_previewMesh);

        return previewCol;
    }

    // ── Helpers ──

    static Button MkIconBtn(string iconPath, Action action, string tooltip)
    {
        var btn = new Button
        {
            TooltipText = tooltip,
            FocusMode = FocusModeEnum.None,
            CustomMinimumSize = new GVector2(28, 28),
        };
        var tex = GD.Load<Texture2D>(iconPath);
        if (tex != null)
            btn.Icon = tex;
        else
            btn.Text = tooltip.Length > 0 ? tooltip[..1] : "?";
        btn.Pressed += () => action();
        return btn;
    }

    // ── Core Logic (unchanged) ──

    void OnSnapSpinValueChanged(double value)
    {
        var w = (float)value;
        var q = TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast(w);
        if (Math.Abs(q - w) > 1e-6f && _snapSpin != null)
            _snapSpin.Value = q;
        if (_view != null)
            _view.SnapIncrement = q;
    }

    void OnViewportSnapIncrementAdjusted(float worldStep)
    {
        if (_snapSpin == null)
            return;
        var v = Math.Clamp((double)worldStep, _snapSpin.MinValue, _snapSpin.MaxValue);
        _snapSpin.Value = v;
    }

    void OnConvertToBezier()
    {
        _view?.ConvertSelectedEdgeToBezier();
        if (_bezierDetailSpin != null)
            ApplyBezierDetailToAll((int)_bezierDetailSpin.Value);
    }

    void ApplyBezierDetailToAll(int detail)
    {
        detail = Godot.Mathf.Clamp(detail, 2, 128);
        _extrusion.project.Validate();
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.generator.type == SegmentGeneratorType.Bezier)
                    seg.generator.bezierDetail = detail;
            }
        }

        _extrusion.project.Invalidate();
        OnProjectEdited();
    }

    public override void _Process(double delta)
    {
        if (_statusLabel == null || _view == null)
            return;

        var segs = 0;
        var bez = 0;
        foreach (var sh in _extrusion.project.shapes)
        {
            segs += sh.segments.Count;
            foreach (var s in sh.segments)
            {
                if (s.generator.type == SegmentGeneratorType.Bezier)
                    bez++;
            }
        }

        var snapOn = _view.SnapEnabled ? "on" : "off";
        var snapText = _view.SnapIncrement.ToString("0.######", CultureInfo.InvariantCulture).TrimEnd('0').TrimEnd('.');
        if (string.IsNullOrEmpty(snapText))
            snapText = "0";
        _statusLabel.Text =
            $"Segments: {segs}  |  Bezier edges: {bez}  |  2D zoom: {_view.ViewZoomPixelsPerUnit:F0} px/unit  |  Snap: {snapText} ({snapOn})";
    }

    void OnModeSelected(long idx)
    {
        _extrusion.targetMode = (ShapeEditorTargetMode)(int)idx;
        _previewAutoFrameOnce = true;
        UpdateExtrusionPanelVisibility();
        RefreshPreview();
    }

    void OnProjectEdited()
    {
        _extrusion.InvalidateCache();
        SyncMaterialInspectorFromProject();
        RefreshPreview();
        _view?.QueueRedraw();
    }

    void OnCopyPressed()
    {
        _extrusion.targetMode = (ShapeEditorTargetMode)_modeOption!.Selected;
        var name = string.IsNullOrWhiteSpace(_groupName!.Text) ? "ShapeUp" : _groupName.Text;
        var text = _extrusion.BuildTrenchBroomClipboard(name);
        if (string.IsNullOrEmpty(text))
        {
            OS.Alert("Nothing to copy (mode may not export brushes, or geometry is invalid).", "ShapeUp");
            return;
        }

        GodotClipboard.SetText(text);
    }

    void OnCopyGodotMapPressed()
    {
        _extrusion.targetMode = (ShapeEditorTargetMode)_modeOption!.Selected;
        var name = string.IsNullOrWhiteSpace(_groupName!.Text) ? "ShapeUp" : _groupName.Text;
        var text = _extrusion.BuildTrenchBroomStandaloneMap(name);
        if (string.IsNullOrEmpty(text))
        {
            OS.Alert("Nothing to copy (mode may not export brushes, or geometry is invalid).", "ShapeUp");
            return;
        }

        GodotClipboard.SetText(text);
    }

    void RefreshPreview()
    {
        if (_previewMesh == null || _previewCam == null)
            return;

        _extrusion.targetMode = (ShapeEditorTargetMode)_modeOption!.Selected;
        _extrusion.fixedExtrudeDistance = (float)_fixedDistance!.Value;

        var um = _extrusion.BuildPreviewMesh();
        if (um == null || um.VerticesReadOnly.Count == 0)
        {
            _previewMesh.Mesh = null;
            _previewAutoFrameOnce = true;
            return;
        }

        var am = UnityMeshToGodot.ToArrayMesh(um);
        _previewMesh.Mesh = am;
        _previewMesh.Position = GVector3.Zero;
        _previewMesh.Rotation = GVector3.Zero;

        var aabb = am.GetAabb();
        if (_previewAutoFrameOnce)
        {
            _previewOrbit?.FrameBoundingBox(aabb, _previewCam?.Fov ?? 55f, _previewFrameOblique);
            _previewFrameOblique = false;
            _previewAutoFrameOnce = false;
        }
    }
}
