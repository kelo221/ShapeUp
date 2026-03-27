using System;
using System.Collections.Generic;
using Godot;
using ShapeUp.Core.ShapeEditor;
using ShapeUp.Infrastructure.Clipboard;
using GVector2 = Godot.Vector2;
using Unity.Mathematics;
using UnityEngine;

namespace ShapeUp.Features.Editor2D;

public partial class MainUi
{
    readonly ProjectUndoStack _undo = new();
    FileDialog? _fileOpen;
    FileDialog? _fileSave;
    FileDialog? _fileBgImage;

    AcceptDialog? _circleDialog;
    SpinBox? _circleDetailSpin;
    SpinBox? _circleDiameterSpin;

    SpinBox? _spinFrontMat;
    SpinBox? _spinBackMat;
    SpinBox? _spinEdgeMat;
    bool _materialInspectorSync;

    int _activeShapeIndex;

    Control? _panelPolygon;
    Control? _panelFixed;
    Control? _panelSpline;
    Control? _panelRevolve;
    Control? _panelStair;
    Control? _panelScaled;
    Control? _panelChopped;

    CheckButton? _polyDoubleSided;
    SpinBox? _spinSplinePrecision;
    VBoxContainer? _splineRowsHost;

    SpinBox? _spinRevPrec;
    SpinBox? _spinRevDeg;
    SpinBox? _spinRevRad;
    SpinBox? _spinRevH;
    CheckButton? _chkRevSloped;

    SpinBox? _spinStairPrec;
    SpinBox? _spinStairDist;
    SpinBox? _spinStairH;
    CheckButton? _chkStairSloped;

    SpinBox? _spinScaledDist;
    SpinBox? _spinScaleFx;
    SpinBox? _spinScaleFy;
    SpinBox? _spinScaleBx;
    SpinBox? _spinScaleBy;
    SpinBox? _spinScaleOx;
    SpinBox? _spinScaleOy;

    SpinBox? _spinChopPrec;
    SpinBox? _spinChopDeg;
    SpinBox? _spinChopDist;

    OptionButton? _shapePicker;
    OptionButton? _boolPicker;
    CheckButton? _symH;
    CheckButton? _symV;

    SpinBox? _spinArchDetail;
    OptionButton? _archModePick;
    SpinBox? _spinSineDetail;
    SpinBox? _spinSineFreq;
    SpinBox? _spinRepeatSegs;
    SpinBox? _spinRepeatTimes;

    SpinBox? _spinRotateDeg;
    SpinBox? _spinScaleUniform;

    /// <summary>Builds extrusion-mode panels and shape/generator inspectors (no toolbar rows — those live in menus now).</summary>
    void SetupEditorEnhancements(VBoxContainer root)
    {
        // ── Compact inspector row: shape picker, bool, symmetry, rotate, scale ──
        var inspectorRow = new HBoxContainer();
        root.AddChild(inspectorRow);

        inspectorRow.AddChild(new Label { Text = "Shape:" });
        _shapePicker = new OptionButton();
        _shapePicker.ItemSelected += OnActiveShapeSelected;
        inspectorRow.AddChild(_shapePicker);
        inspectorRow.AddChild(MkBtn("+", OnAddShape, "Add shape"));
        inspectorRow.AddChild(MkBtn("Dup", OnDuplicateShape, "Duplicate active shape"));
        inspectorRow.AddChild(new VSeparator());
        inspectorRow.AddChild(new Label { Text = "Bool:" });
        _boolPicker = new OptionButton();
        _boolPicker.AddItem("Union", (int)PolygonBooleanOperator.Union);
        _boolPicker.AddItem("Difference", (int)PolygonBooleanOperator.Difference);
        _boolPicker.ItemSelected += OnBooleanOpSelected;
        inspectorRow.AddChild(_boolPicker);
        _symH = new CheckButton { Text = "Sym H" };
        _symH.Toggled += OnSymmetryToggled;
        inspectorRow.AddChild(_symH);
        _symV = new CheckButton { Text = "Sym V" };
        _symV.Toggled += OnSymmetryToggled;
        inspectorRow.AddChild(_symV);
        inspectorRow.AddChild(new VSeparator());
        inspectorRow.AddChild(new Label { Text = "Rot°" });
        _spinRotateDeg = MkSpin(-360, 360, 0, 15);
        inspectorRow.AddChild(_spinRotateDeg);
        inspectorRow.AddChild(MkBtn("↻", () => _view!.RotateSelectedVerticesDegrees((float)_spinRotateDeg!.Value), "Rotate selection"));
        inspectorRow.AddChild(new Label { Text = "Scale" });
        _spinScaleUniform = MkSpin(0.05, 20, 1, 0.05);
        inspectorRow.AddChild(_spinScaleUniform);
        inspectorRow.AddChild(MkBtn("⊡", () => _view!.ScaleSelectedVertices((float)_spinScaleUniform!.Value), "Scale selection"));
        inspectorRow.AddChild(new VSeparator());
        inspectorRow.AddChild(new Label { Text = "Mat F" });
        _spinFrontMat = MkSpinByte(0, 255, 0);
        _spinFrontMat.ValueChanged += _ => OnFrontMaterialSpinChanged();
        inspectorRow.AddChild(_spinFrontMat);
        inspectorRow.AddChild(new Label { Text = "B" });
        _spinBackMat = MkSpinByte(0, 255, 0);
        _spinBackMat.ValueChanged += _ => OnBackMaterialSpinChanged();
        inspectorRow.AddChild(_spinBackMat);
        inspectorRow.AddChild(new Label { Text = "Edge" });
        _spinEdgeMat = MkSpinByte(0, 255, 0);
        _spinEdgeMat.TooltipText = "Extrude material index for one fully selected linear edge.";
        _spinEdgeMat.ValueChanged += _ => OnEdgeMaterialSpinChanged();
        inspectorRow.AddChild(_spinEdgeMat);

        // ── Hidden generator inspector fields (used by menu actions) ──
        _spinArchDetail = MkSpin(2, 64, 8, 1);
        _archModePick = new OptionButton();
        foreach (var name in Enum.GetNames(typeof(SegmentGenerator.ArchMode)))
            _archModePick.AddItem(name);
        _archModePick.ItemSelected += OnArchInspectorChanged;
        _spinSineDetail = MkSpin(4, 128, 64, 1);
        _spinSineFreq = MkSpin(-20, 20, -3.5, 0.25);
        _spinRepeatSegs = MkSpin(1, 32, 2, 1);
        _spinRepeatTimes = MkSpin(1, 64, 4, 1);

        _spinArchDetail.ValueChanged += _ => OnArchInspectorChanged(0);
        _spinSineDetail.ValueChanged += _ => OnSineInspectorChanged(0);
        _spinSineFreq.ValueChanged += _ => OnSineInspectorChanged(0);
        _spinRepeatSegs.ValueChanged += _ => OnRepeatInspectorChanged(0);
        _spinRepeatTimes.ValueChanged += _ => OnRepeatInspectorChanged(0);

        // ── Extrusion mode panels (in a compact scroll area) ──
        var scroll = new ScrollContainer
        {
            CustomMinimumSize = new GVector2(0, 60),
            SizeFlagsVertical = SizeFlags.Fill,
            HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled,
        };
        root.AddChild(scroll);
        var modeStack = new VBoxContainer();
        scroll.AddChild(modeStack);

        _polyDoubleSided = new CheckButton { Text = "Double-sided", ButtonPressed = _extrusion.polygonDoubleSided };
        _polyDoubleSided.Toggled += v =>
        {
            _extrusion.polygonDoubleSided = v;
            RefreshPreview();
        };
        _panelPolygon = MkPanel("Polygon (2D cap)", _polyDoubleSided);
        modeStack.AddChild(_panelPolygon);

        _panelFixed = MkPanel("Fixed extrude", new Label { Text = "Use 'Extrude' spinbox in the toolbar." });
        modeStack.AddChild(_panelFixed);

        var splineHead = new HBoxContainer();
        splineHead.AddChild(new Label { Text = "Precision" });
        _spinSplinePrecision = MkSpin(2, 128, _extrusion.splineExtrudePrecision, 1);
        _spinSplinePrecision.ValueChanged += v =>
        {
            _extrusion.splineExtrudePrecision = (int)v;
            RefreshPreview();
        };
        splineHead.AddChild(_spinSplinePrecision);
        _splineRowsHost = new VBoxContainer();
        _panelSpline = MkPanel("Spline extrude", splineHead, _splineRowsHost);
        modeStack.AddChild(_panelSpline);

        _panelRevolve = MkPanel("Revolve extrude",
            Row("Precision", _spinRevPrec = MkSpin(2, 64, _extrusion.revolveExtrudePrecision, 1)),
            Row("Degrees", _spinRevDeg = MkSpin(-720, 720, _extrusion.revolveExtrudeDegrees, 1)),
            Row("Radius", _spinRevRad = MkSpin(0.05, 50, _extrusion.revolveExtrudeRadius, 0.05)),
            Row("Height", _spinRevH = MkSpin(-20, 20, _extrusion.revolveExtrudeHeight, 0.05)),
            _chkRevSloped = new CheckButton { Text = "Sloped (spiral-style)", ButtonPressed = _extrusion.revolveExtrudeSloped });
        BindSpin(_spinRevPrec, v => _extrusion.revolveExtrudePrecision = (int)v);
        BindSpin(_spinRevDeg, v => _extrusion.revolveExtrudeDegrees = (float)v);
        BindSpin(_spinRevRad, v => _extrusion.revolveExtrudeRadius = (float)v);
        BindSpin(_spinRevH, v => _extrusion.revolveExtrudeHeight = (float)v);
        _chkRevSloped.Toggled += v =>
        {
            _extrusion.revolveExtrudeSloped = v;
            RefreshPreview();
        };
        modeStack.AddChild(_panelRevolve);

        _panelStair = MkPanel("Linear staircase",
            Row("Precision", _spinStairPrec = MkSpin(1, 64, _extrusion.linearStaircasePrecision, 1)),
            Row("Distance", _spinStairDist = MkSpin(0.05, 50, _extrusion.linearStaircaseDistance, 0.05)),
            Row("Height", _spinStairH = MkSpin(0, 20, _extrusion.linearStaircaseHeight, 0.05)),
            _chkStairSloped = new CheckButton { Text = "Sloped (ramp)", ButtonPressed = _extrusion.linearStaircaseSloped });
        BindSpin(_spinStairPrec, v => _extrusion.linearStaircasePrecision = (int)v);
        BindSpin(_spinStairDist, v => _extrusion.linearStaircaseDistance = (float)v);
        BindSpin(_spinStairH, v => _extrusion.linearStaircaseHeight = (float)v);
        _chkStairSloped.Toggled += v =>
        {
            _extrusion.linearStaircaseSloped = v;
            RefreshPreview();
        };
        modeStack.AddChild(_panelStair);

        _panelScaled = MkPanel("Scaled extrude (pyramid/bevel)",
            Row("Distance", _spinScaledDist = MkSpin(0.05, 50, _extrusion.scaledExtrudeDistance, 0.05)),
            Row("Front scale XY", H(_spinScaleFx = MkSpin(0, 4, _extrusion.scaledExtrudeFrontScale.x, 0.05), _spinScaleFy = MkSpin(0, 4, _extrusion.scaledExtrudeFrontScale.y, 0.05))),
            Row("Back scale XY", H(_spinScaleBx = MkSpin(0, 4, _extrusion.scaledExtrudeBackScale.x, 0.05), _spinScaleBy = MkSpin(0, 4, _extrusion.scaledExtrudeBackScale.y, 0.05))),
            Row("Offset XY", H(_spinScaleOx = MkSpin(-10, 10, _extrusion.scaledExtrudeOffset.x, 0.05), _spinScaleOy = MkSpin(-10, 10, _extrusion.scaledExtrudeOffset.y, 0.05))));
        BindSpin(_spinScaledDist, v => _extrusion.scaledExtrudeDistance = (float)v);
        Bind2(_spinScaleFx, _spinScaleFy, (x, y) => _extrusion.scaledExtrudeFrontScale = new UnityEngine.Vector2(x, y));
        Bind2(_spinScaleBx, _spinScaleBy, (x, y) => _extrusion.scaledExtrudeBackScale = new UnityEngine.Vector2(x, y));
        Bind2(_spinScaleOx, _spinScaleOy, (x, y) => _extrusion.scaledExtrudeOffset = new UnityEngine.Vector2(x, y));
        modeStack.AddChild(_panelScaled);

        _panelChopped = MkPanel("Revolve chopped",
            Row("Chop count", _spinChopPrec = MkSpin(2, 64, _extrusion.revolveChoppedPrecision, 1)),
            Row("Degrees", _spinChopDeg = MkSpin(-720, 720, _extrusion.revolveChoppedDegrees, 1)),
            Row("Distance", _spinChopDist = MkSpin(0.05, 10, _extrusion.revolveChoppedDistance, 0.05)));
        BindSpin(_spinChopPrec, v => _extrusion.revolveChoppedPrecision = (int)v);
        BindSpin(_spinChopDeg, v => _extrusion.revolveChoppedDegrees = (float)v);
        BindSpin(_spinChopDist, v => _extrusion.revolveChoppedDistance = (float)v);
        modeStack.AddChild(_panelChopped);

        RebuildShapePicker();
        RebuildSplineRows();
        UpdateExtrusionPanelVisibility();
        SetupFileDialogs();
        SetupAuxDialogs();

        var bgRow = new HBoxContainer();
        bgRow.AddChild(new Label { Text = "Ref bg scale" });
        var sBgScale = MkSpin(0.05, 50, 1, 0.05);
        sBgScale.ValueChanged += v =>
        {
            if (_view != null)
            {
                _view.BackgroundScale = (float)v;
                _view.QueueRedraw();
            }
        };
        bgRow.AddChild(sBgScale);
        bgRow.AddChild(new Label { Text = "α" });
        var sBgA = MkSpin(0, 1, 0.25, 0.05);
        sBgA.ValueChanged += v =>
        {
            if (_view != null)
            {
                _view.BackgroundAlpha = (float)v;
                _view.QueueRedraw();
            }
        };
        bgRow.AddChild(sBgA);
        bgRow.AddChild(MkBtn("Clear bg", () =>
        {
            if (_view != null)
            {
                _view.BackgroundImage = null;
                _view.QueueRedraw();
            }
        }, "Remove background image"));
        root.AddChild(bgRow);
    }

    static Control H(params Control[] c)
    {
        var h = new HBoxContainer();
        foreach (var x in c)
            h.AddChild(x);
        return h;
    }

    static HBoxContainer Row(string label, Control c)
    {
        var h = new HBoxContainer();
        h.AddChild(new Label { Text = label, CustomMinimumSize = new GVector2(100, 0) });
        h.AddChild(c);
        return h;
    }

    static MarginContainer MkPanel(string title, params Control[] children)
    {
        var m = new MarginContainer { ThemeTypeVariation = "Panel" };
        var v = new VBoxContainer();
        m.AddChild(v);
        v.AddChild(new Label { Text = title });
        foreach (var ch in children)
            v.AddChild(ch);
        return m;
    }

    static Button MkBtn(string t, Action a, string? tip = null)
    {
        var b = new Button { Text = t, TooltipText = tip ?? "" };
        b.Pressed += () => a();
        return b;
    }

    static SpinBox MkSpin(double min, double max, double val, double step)
    {
        return new SpinBox
        {
            MinValue = min,
            MaxValue = max,
            Value = val,
            Step = step,
            CustomMinimumSize = new GVector2(72, 0),
        };
    }

    static SpinBox MkSpinByte(int min, int max, byte val)
    {
        var s = MkSpin(min, max, val, 1);
        s.Rounded = true;
        s.CustomMinimumSize = new GVector2(52, 0);
        return s;
    }

    void BindSpin(SpinBox s, Action<double> set)
    {
        s.ValueChanged += v =>
        {
            set(v);
            RefreshPreview();
        };
    }

    void Bind2(SpinBox ax, SpinBox ay, Action<float, float> set)
    {
        void Both()
        {
            set((float)ax.Value, (float)ay.Value);
            RefreshPreview();
        }

        ax.ValueChanged += _ => Both();
        ay.ValueChanged += _ => Both();
    }

    void SetupFileDialogs()
    {
        _fileOpen = new FileDialog
        {
            FileMode = FileDialog.FileModeEnum.OpenFile,
            Access = FileDialog.AccessEnum.Filesystem,
            Title = "Open ShapeUp project",
        };
        _fileOpen.Filters = new[] { "*.json ; JSON project" };
        _fileOpen.FileSelected += OnFileOpenSelected;
        AddChild(_fileOpen);

        _fileSave = new FileDialog
        {
            FileMode = FileDialog.FileModeEnum.SaveFile,
            Access = FileDialog.AccessEnum.Filesystem,
            Title = "Save ShapeUp project",
        };
        _fileSave.Filters = new[] { "*.json ; JSON project" };
        _fileSave.FileSelected += OnFileSaveSelected;
        AddChild(_fileSave);

        _fileBgImage = new FileDialog
        {
            FileMode = FileDialog.FileModeEnum.OpenFile,
            Access = FileDialog.AccessEnum.Filesystem,
            Title = "Background reference image",
        };
        _fileBgImage.Filters = new[] { "*.png ; PNG", "*.jpg,*.jpeg ; JPEG", "*.webp ; WebP", "*.svg ; SVG" };
        _fileBgImage.FileSelected += OnBackgroundImageSelected;
        AddChild(_fileBgImage);
    }

    void SetupAuxDialogs()
    {
        _circleDialog = new AcceptDialog
        {
            Title = "Circle shape",
            OkButtonText = "Create",
        };
        _circleDialog.DialogText = " ";
        _circleDialog.Confirmed += OnCircleDialogConfirmed;
        AddChild(_circleDialog);

        var vb = new VBoxContainer();
        _circleDetailSpin = MkSpinByte(3, 128, 8);
        _circleDiameterSpin = MkSpin(0.05, 50, 1, 0.05);
        vb.AddChild(Row("Detail (vertices)", _circleDetailSpin));
        vb.AddChild(Row("Diameter (world units)", _circleDiameterSpin));
        _circleDialog.AddChild(vb);
    }

    void OnOpenProject() => _fileOpen!.PopupCenteredRatio(0.5f);

    void OnSaveProject() => _fileSave!.PopupCenteredRatio(0.5f);

    void OnFileOpenSelected(string path)
    {
        try
        {
            var text = Godot.FileAccess.GetFileAsString(path);
            var p = JsonUtility.FromJson<Project>(text);
            if (p == null)
            {
                OS.Alert("Invalid project file.", "ShapeUp");
                return;
            }

            _undo.Clear();
            ApplyLoadedProject(p);
        }
        catch (Exception ex)
        {
            OS.Alert($"Open failed: {ex.Message}", "ShapeUp");
        }
    }

    void OnFileSaveSelected(string path)
    {
        try
        {
            var json = JsonUtility.ToJson(_extrusion.project);
            using var f = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Write);
            if (f == null)
            {
                OS.Alert("Could not write file.", "ShapeUp");
                return;
            }

            f.StoreString(json);
        }
        catch (Exception ex)
        {
            OS.Alert($"Save failed: {ex.Message}", "ShapeUp");
        }
    }

    void ApplyLoadedProject(Project p)
    {
        p.Validate();
        _extrusion.SetProject(p);
        if (_view != null)
            _view.Project = p;
        _activeShapeIndex = Godot.Mathf.Clamp(_activeShapeIndex, 0, Math.Max(0, p.shapes.Count - 1));
        RebuildShapePicker();
        RebuildSplineRows();
        OnProjectEdited();
    }

    void ApplyNewProject()
    {
        _undo.Clear();
        ApplyLoadedProject(new Project());
    }

    void OnUndo()
    {
        var prev = _undo.PopUndo(_extrusion.project);
        if (prev == null)
            return;
        prev.Validate();
        ApplyLoadedProject(prev);
    }

    void OnRedo()
    {
        var next = _undo.PopRedo(_extrusion.project);
        if (next == null)
            return;
        next.Validate();
        ApplyLoadedProject(next);
    }

    public override void _UnhandledKeyInput(InputEvent @event)
    {
        if (@event is InputEventKey k && k.Pressed && !k.Echo)
        {
            if (k.CtrlPressed && k.Keycode == Key.Z)
            {
                OnUndo();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (k.CtrlPressed && (k.Keycode == Key.Y || (k.ShiftPressed && k.Keycode == Key.Z)))
            {
                OnRedo();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (!ShouldShapeShortcutsApply())
            {
                base._UnhandledKeyInput(@event);
                return;
            }

            if (k.CtrlPressed && k.Keycode == Key.C)
            {
                OnCopyShapesInternal();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (k.CtrlPressed && k.Keycode == Key.V)
            {
                OnPasteShapesInternal();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (k.CtrlPressed && k.Keycode == Key.D)
            {
                OnDuplicateSelectedShapes();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (k.CtrlPressed && k.Keycode == Key.E)
            {
                OnShapeFromSelection();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (!k.CtrlPressed && !k.AltPressed && k.Keycode == Key.E)
            {
                OnExtrudeSelectedEdges();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (!k.CtrlPressed && !k.AltPressed && k.Keycode == Key.Key4)
            {
                SetViewportTool(Editor2DTool.Measure);
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }

            if (!k.CtrlPressed && !k.AltPressed && k.Keycode == Key.R)
            {
                if (_view != null && _spinRotateDeg != null &&
                    VertexSelectionTransforms.HasSelectedSegmentVertex(_extrusion.project))
                {
                    _view.RotateSelectedVerticesDegrees((float)_spinRotateDeg.Value);
                    GetViewport().SetInputAsHandled();
                    AcceptEvent();
                    return;
                }
            }
        }

        base._UnhandledKeyInput(@event);
    }

    static bool IsTypingInTextControl(Control? c)
    {
        while (c != null)
        {
            if (c is LineEdit || c is TextEdit || c is CodeEdit)
                return true;
            c = c.GetParent() as Control;
        }

        return false;
    }

    bool ShouldShapeShortcutsApply()
    {
        if (IsTypingInTextControl(GetViewport().GuiGetFocusOwner()))
            return false;
        return true;
    }

    void RebuildShapePicker()
    {
        if (_shapePicker == null)
            return;
        _shapePicker.Clear();
        for (var i = 0; i < _extrusion.project.shapes.Count; i++)
            _shapePicker.AddItem($"Shape {i}", i);
        if (_extrusion.project.shapes.Count == 0)
            return;
        _activeShapeIndex = Godot.Mathf.Clamp(_activeShapeIndex, 0, _extrusion.project.shapes.Count - 1);
        _shapePicker.Select(_activeShapeIndex);
        SyncShapeInspector();
    }

    void OnActiveShapeSelected(long idx)
    {
        _activeShapeIndex = (int)idx;
        SyncShapeInspector();
    }

    void SyncShapeInspector()
    {
        if (_boolPicker == null || _symH == null || _symV == null)
            return;
        if (_extrusion.project.shapes.Count == 0)
            return;
        var sh = _extrusion.project.shapes[_activeShapeIndex];
        _boolPicker.Select((int)sh.booleanOperator);
        _symH.ButtonPressed = sh.symmetryAxes.HasFlag(SimpleGlobalAxis.Horizontal);
        _symV.ButtonPressed = sh.symmetryAxes.HasFlag(SimpleGlobalAxis.Vertical);
        SyncMaterialInspectorFromProject();
    }

    void OnBooleanOpSelected(long idx)
    {
        if (_extrusion.project.shapes.Count == 0)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        _extrusion.project.shapes[_activeShapeIndex].booleanOperator = (PolygonBooleanOperator)(int)idx;
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void OnSymmetryToggled(bool _)
    {
        if (_extrusion.project.shapes.Count == 0 || _symH == null || _symV == null)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        var a = SimpleGlobalAxis.None;
        if (_symH.ButtonPressed)
            a |= SimpleGlobalAxis.Horizontal;
        if (_symV.ButtonPressed)
            a |= SimpleGlobalAxis.Vertical;
        _extrusion.project.shapes[_activeShapeIndex].symmetryAxes = a;
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void OnAddShape()
    {
        _undo.PushBeforeMutation(_extrusion.project);
        var ns = new Shape();
        var ox = _extrusion.project.shapes.Count * 1.75f;
        ns.Validate();
        foreach (var seg in ns.segments)
            seg.position += new Unity.Mathematics.float2(ox, 0f);
        _extrusion.project.shapes.Add(ns);
        _activeShapeIndex = _extrusion.project.shapes.Count - 1;
        RebuildShapePicker();
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void OnDuplicateShape()
    {
        if (_extrusion.project.shapes.Count == 0)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        var src = _extrusion.project.shapes[_activeShapeIndex];
        var json = JsonUtility.ToJson(src);
        var copy = JsonUtility.FromJson<Shape>(json);
        if (copy == null)
            return;
        copy.Validate();
        foreach (var seg in copy.segments)
            seg.position += new Unity.Mathematics.float2(0.35f, 0.35f);
        _extrusion.project.shapes.Insert(_activeShapeIndex + 1, copy);
        _activeShapeIndex++;
        RebuildShapePicker();
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void MoveShape(int delta)
    {
        var list = _extrusion.project.shapes;
        var i = _activeShapeIndex;
        var j = i + delta;
        if (j < 0 || j >= list.Count)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        (list[i], list[j]) = (list[j], list[i]);
        _activeShapeIndex = j;
        RebuildShapePicker();
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void ToggleEdges(SegmentGeneratorType type)
    {
        if (_view?.Project == null)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        _extrusion.project.Validate();
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!(seg.selected && seg.next.selected))
                    continue;
                if (seg.generator.type == type)
                    seg.generator = new SegmentGenerator(seg);
                else
                    seg.generator = new SegmentGenerator(seg, type);
            }
        }

        _extrusion.project.Invalidate();
        OnProjectEdited();
        _view.QueueRedraw();
    }

    void OnApplyGenerators()
    {
        if (_view?.Project == null)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        _extrusion.project.Validate();
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!(seg.selected && seg.next.selected))
                    continue;
                if (seg.generator.type == SegmentGeneratorType.Linear)
                    continue;
                seg.generator.ApplyGenerator();
                seg.generator = new SegmentGenerator(seg);
            }
        }

        _extrusion.project.Invalidate();
        _extrusion.project.ClearSelection();
        OnProjectEdited();
        _view.QueueRedraw();
    }

    void OnArchInspectorChanged(long _)
    {
        if (_view?.Project == null || _spinArchDetail == null || _archModePick == null)
            return;
        _extrusion.project.Validate();
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.generator.type != SegmentGeneratorType.Arch)
                    continue;
                if (!(seg.selected && seg.next.selected))
                    continue;
                seg.generator.archDetail = (int)_spinArchDetail.Value;
                seg.generator.archMode = (SegmentGenerator.ArchMode)(int)_archModePick.Selected;
            }
        }

        _extrusion.project.Invalidate();
        OnProjectEdited();
        _view.QueueRedraw();
    }

    void OnSineInspectorChanged(long _)
    {
        if (_view?.Project == null || _spinSineDetail == null || _spinSineFreq == null)
            return;
        _extrusion.project.Validate();
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.generator.type != SegmentGeneratorType.Sine)
                    continue;
                if (!(seg.selected && seg.next.selected))
                    continue;
                seg.generator.sineDetail = (int)_spinSineDetail.Value;
                seg.generator.sineFrequency = (float)_spinSineFreq.Value;
            }
        }

        _extrusion.project.Invalidate();
        OnProjectEdited();
        _view.QueueRedraw();
    }

    void OnRepeatInspectorChanged(long _)
    {
        if (_view?.Project == null || _spinRepeatSegs == null || _spinRepeatTimes == null)
            return;
        _extrusion.project.Validate();
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.generator.type != SegmentGeneratorType.Repeat)
                    continue;
                if (!(seg.selected && seg.next.selected))
                    continue;
                seg.generator.repeatSegments = (int)_spinRepeatSegs.Value;
                seg.generator.repeatTimes = (int)_spinRepeatTimes.Value;
            }
        }

        _extrusion.project.Invalidate();
        OnProjectEdited();
        _view.QueueRedraw();
    }

    void OnApplyGeneratorPropsToSelection()
    {
        OnArchInspectorChanged(0);
        OnSineInspectorChanged(0);
        OnRepeatInspectorChanged(0);
    }

    void UpdateExtrusionPanelVisibility()
    {
        var m = (ShapeEditorTargetMode)_modeOption!.Selected;
        void Vis(Control? c, bool on) { if (c != null) c.Visible = on; }
        Vis(_panelPolygon, m == ShapeEditorTargetMode.Polygon);
        Vis(_panelFixed, m == ShapeEditorTargetMode.FixedExtrude);
        Vis(_panelSpline, m == ShapeEditorTargetMode.SplineExtrude);
        Vis(_panelRevolve, m == ShapeEditorTargetMode.RevolveExtrude);
        Vis(_panelStair, m == ShapeEditorTargetMode.LinearStaircase);
        Vis(_panelScaled, m == ShapeEditorTargetMode.ScaledExtrude);
        Vis(_panelChopped, m == ShapeEditorTargetMode.RevolveChopped);
    }

    void RebuildSplineRows()
    {
        if (_splineRowsHost == null)
            return;
        foreach (var c in _splineRowsHost.GetChildren())
            c.QueueFree();
        var pts = _extrusion.SplineControlPoints;
        for (var i = 0; i < pts.Count; i++)
        {
            var idx = i;
            var h = new HBoxContainer();
            h.AddChild(new Label { Text = $"P{idx}", CustomMinimumSize = new GVector2(28, 0) });
            var sx = MkSpin(-50, 50, pts[idx].x, 0.05);
            var sy = MkSpin(-50, 50, pts[idx].y, 0.05);
            var sz = MkSpin(-50, 50, pts[idx].z, 0.05);
            sx.ValueChanged += v =>
            {
                var p = pts[idx];
                p.x = (float)v;
                pts[idx] = p;
                RefreshPreview();
            };
            sy.ValueChanged += v =>
            {
                var p = pts[idx];
                p.y = (float)v;
                pts[idx] = p;
                RefreshPreview();
            };
            sz.ValueChanged += v =>
            {
                var p = pts[idx];
                p.z = (float)v;
                pts[idx] = p;
                RefreshPreview();
            };
            h.AddChild(sx);
            h.AddChild(sy);
            h.AddChild(sz);
            var del = MkBtn("×", () =>
            {
                if (pts.Count <= 3)
                    return;
                _undo.PushBeforeMutation(_extrusion.project);
                pts.RemoveAt(idx);
                RebuildSplineRows();
                RefreshPreview();
            });
            h.AddChild(del);
            _splineRowsHost.AddChild(h);
        }

        var addRow = new HBoxContainer();
        addRow.AddChild(MkBtn("+ Control point", () =>
        {
            _undo.PushBeforeMutation(_extrusion.project);
            var last = pts[^1];
            pts.Add(new UnityEngine.Vector3(last.x + 0.25f, last.y, last.z + 0.25f));
            RebuildSplineRows();
            RefreshPreview();
        }));
        _splineRowsHost.AddChild(addRow);
    }

    void WireEdgeContextMenu()
    {
        if (_view == null)
            return;
        _view.EdgeMenuBezier = OnConvertToBezier;
        _view.EdgeMenuLinear = () => _view.ConvertSelectedEdgeToLinear();
        _view.EdgeMenuArch = () => ToggleEdges(SegmentGeneratorType.Arch);
        _view.EdgeMenuSine = () => ToggleEdges(SegmentGeneratorType.Sine);
        _view.EdgeMenuRepeat = () => ToggleEdges(SegmentGeneratorType.Repeat);
        _view.EdgeMenuApplyGenerators = OnApplyGenerators;
        _view.EdgeMenuApplyProps = OnApplyGeneratorPropsToSelection;
    }

    void OnCopyShapesInternal()
    {
        var shapes = EditorProjectCommands.GetFullySelectedShapes(_extrusion.project);
        var json = EditorProjectCommands.SerializeShapesToClipboard(shapes);
        GodotClipboard.SetText(json);
    }

    void OnPasteShapesInternal()
    {
        var json = GodotClipboard.GetText();
        if (!EditorProjectCommands.TryPasteFromClipboardJson(_extrusion.project, json,
                () => _undo.PushBeforeMutation(_extrusion.project)))
            return;
        RebuildShapePicker();
        OnProjectEdited();
        _view?.QueueRedraw();
    }

    void OnDuplicateSelectedShapes()
    {
        EditorProjectCommands.DuplicateFullySelectedShapes(_extrusion.project,
            () => _undo.PushBeforeMutation(_extrusion.project));
        RebuildShapePicker();
        OnProjectEdited();
        _view?.QueueRedraw();
    }

    void OnShapeFromSelection()
    {
        if (!EditorProjectCommands.TryShapeFromSelection(_extrusion.project,
                () => _undo.PushBeforeMutation(_extrusion.project)))
        {
            OS.Alert("Select at least three vertices or pivots.", "ShapeUp");
            return;
        }

        RebuildShapePicker();
        _activeShapeIndex = _extrusion.project.shapes.Count - 1;
        _shapePicker?.Select(_activeShapeIndex);
        OnProjectEdited();
        _view?.QueueRedraw();
    }

    void OnExtrudeSelectedEdges()
    {
        EditorProjectCommands.ExtrudeSelectedLinearEdges(_extrusion.project,
            () => _undo.PushBeforeMutation(_extrusion.project));
        OnProjectEdited();
        _view?.QueueRedraw();
    }

    void OnApplySymmetryForSelectedShapes()
    {
        EditorProjectCommands.ApplySymmetryForSelectedShapes(_extrusion.project,
            () => _undo.PushBeforeMutation(_extrusion.project));
        RebuildShapePicker();
        SyncShapeInspector();
        OnProjectEdited();
        _view?.QueueRedraw();
    }

    void OnPushSelectedShapes(bool toFront)
    {
        EditorProjectCommands.PushFullySelectedShapes(_extrusion.project, toFront,
            () => _undo.PushBeforeMutation(_extrusion.project));
        RebuildShapePicker();
        OnProjectEdited();
    }

    void OnPickBackgroundImage() => _fileBgImage!.PopupCenteredRatio(0.55f);

    void OnBackgroundImageSelected(string path)
    {
        var tex = GD.Load<Texture2D>(path);
        if (tex == null)
        {
            OS.Alert("Could not load image.", "ShapeUp");
            return;
        }

        if (_view != null)
        {
            _view.BackgroundImage = tex;
            _view.BackgroundScale = Math.Max(_view.BackgroundScale, 0.01f);
            _view.QueueRedraw();
        }
    }

    void OnCircleShapeDialog() => _circleDialog!.PopupCenteredRatio(0.35f);

    void OnCircleDialogConfirmed()
    {
        var detail = Godot.Mathf.Clamp((int)_circleDetailSpin!.Value, 3, 256);
        var diameter = (float)_circleDiameterSpin!.Value;
        _undo.PushBeforeMutation(_extrusion.project);
        var circle = new MathEx.Circle();
        circle.SetDiameter(diameter);
        var shape = new Shape();
        shape.segments.Clear();
        for (var i = 0; i < detail; i++)
        {
            var position = circle.GetCirclePosition(i / (float)detail);
            shape.AddSegment(new Segment(shape, new float2(position.x, -position.z)));
        }

        _extrusion.project.ClearSelection();
        _extrusion.project.shapes.Add(shape);
        shape.SelectAll();
        _extrusion.project.Invalidate();
        _activeShapeIndex = _extrusion.project.shapes.Count - 1;
        RebuildShapePicker();
        _shapePicker?.Select(_activeShapeIndex);
        OnProjectEdited();
        _view?.QueueRedraw();
    }

    void SyncMaterialInspectorFromProject()
    {
        if (_spinFrontMat == null || _spinBackMat == null || _spinEdgeMat == null)
            return;
        if (_extrusion.project.shapes.Count == 0)
            return;

        _materialInspectorSync = true;
        try
        {
            var sh = _extrusion.project.shapes[_activeShapeIndex];
            _spinFrontMat.Value = sh.frontMaterial;
            _spinBackMat.Value = sh.backMaterial;

            _extrusion.project.Validate();
            Segment? edge = null;
            var n = 0;
            foreach (var shape in _extrusion.project.shapes)
            {
                foreach (var seg in shape.segments)
                {
                    if (seg.selected && seg.next.selected && seg.generator.type == SegmentGeneratorType.Linear)
                    {
                        n++;
                        edge = seg;
                    }
                }
            }

            if (n == 1 && edge != null)
            {
                _spinEdgeMat.Editable = true;
                _spinEdgeMat.Value = edge.material;
            }
            else
            {
                _spinEdgeMat.Editable = false;
                _spinEdgeMat.Value = 0;
            }
        }
        finally
        {
            _materialInspectorSync = false;
        }
    }

    void OnFrontMaterialSpinChanged()
    {
        if (_materialInspectorSync || _extrusion.project.shapes.Count == 0)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        _extrusion.project.shapes[_activeShapeIndex].frontMaterial = (byte)_spinFrontMat!.Value;
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void OnBackMaterialSpinChanged()
    {
        if (_materialInspectorSync || _extrusion.project.shapes.Count == 0)
            return;
        _undo.PushBeforeMutation(_extrusion.project);
        _extrusion.project.shapes[_activeShapeIndex].backMaterial = (byte)_spinBackMat!.Value;
        _extrusion.InvalidateCache();
        OnProjectEdited();
    }

    void OnEdgeMaterialSpinChanged()
    {
        if (_materialInspectorSync || !_spinEdgeMat!.Editable)
            return;
        _extrusion.project.Validate();
        Segment? edge = null;
        var n = 0;
        foreach (var shape in _extrusion.project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.selected && seg.next.selected && seg.generator.type == SegmentGeneratorType.Linear)
                {
                    n++;
                    edge = seg;
                }
            }
        }

        if (n != 1 || edge == null)
            return;

        _undo.PushBeforeMutation(_extrusion.project);
        edge.material = (byte)_spinEdgeMat.Value;
        _extrusion.project.Invalidate();
        _extrusion.InvalidateCache();
        OnProjectEdited();
        _view?.QueueRedraw();
    }
}
