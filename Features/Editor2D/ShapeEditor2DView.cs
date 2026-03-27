using System;
using System.Collections.Generic;
using Godot;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;
using GVector2 = Godot.Vector2;

namespace ShapeUp.Features.Editor2D;

/// <summary>2D shape viewport: user pan/zoom, TrenchBroom-style power-of-two grid (64 Quake units/world), marquee multi-select.</summary>
public partial class ShapeEditor2DView : Control
{
    const float EdgePickPixels = 14f;
    const float VertexPickPixels = 12f;
    const float PivotPickPixels = 11f;
    const float MarqueeDragThresholdPx = 5f;
    const float DefaultZoom = 120f;
    const float MinZoom = 18f;
    const float MaxZoom = 720f;
    const float ZoomStepFactor = 1.12f;

    public Project? Project { get; set; }
    public Action? ProjectChanged;

    /// <summary>Fired before mutating geometry (vertex drag records undo on first meaningful move).</summary>
    public Action? BeforeProjectMutation;

    /// <summary>Right-click edge menu: set from <c>MainUi</c> to run Edge menu actions (Bezier, Arch, etc.).</summary>
    public Action? EdgeMenuBezier;
    public Action? EdgeMenuLinear;
    public Action? EdgeMenuArch;
    public Action? EdgeMenuSine;
    public Action? EdgeMenuRepeat;
    public Action? EdgeMenuApplyGenerators;
    public Action? EdgeMenuApplyProps;

    /// <summary>When true, single left-click on an edge inserts a vertex (same as double-click).</summary>
    public bool ClickInsertVertexMode { get; set; }

    public float SnapIncrement { get; set; } = 0.125f;
    public bool SnapEnabled { get; set; } = true;

    /// <summary>Fired when snap/grid step changes from the viewport (e.g. Ctrl+scroll). Sync toolbar spinbox.</summary>
    public Action<float>? SnapIncrementAdjusted;

    /// <summary>Pixels per world unit in the 2D editor (for status bar).</summary>
    public float ViewZoomPixelsPerUnit => _zoom;

    float _zoom = DefaultZoom;
    GVector2 _pan;
    bool _viewportInitialized;

    bool _isPanning;
    GVector2 _lastPanMousePos;

    Segment? _dragVertexSegment;
    Pivot? _dragPivot;
    float2 _vertexDragOrigin;
    float2 _vertexDragLastGrid;
    float2 _pivotDragOrigin;
    bool _vertexDragUndoPushed;
    bool _pivotDragUndoPushed;
    /// <summary>Godot sometimes omits left button in <see cref="InputEventMouseMotion.ButtonMask"/> while dragging; track explicitly.</summary>
    bool _leftButtonHeld;

    bool _marqueePending;
    bool _marqueeDragging;
    GVector2 _marqueeStart;
    GVector2 _marqueeEnd;
    bool _marqueeHadShift;

    PopupMenu? _edgeContextMenu;

    const int CtxBezier = 1;
    const int CtxLinear = 2;
    const int CtxArch = 3;
    const int CtxSine = 4;
    const int CtxRepeat = 5;
    const int CtxApplyGen = 6;
    const int CtxApplyProps = 7;

    public override void _Ready()
    {
        FocusMode = FocusModeEnum.Click;
        MouseFilter = MouseFilterEnum.Stop;
        ClipContents = true;
        TryInitializeViewport();

        _edgeContextMenu = new PopupMenu();
        AddChild(_edgeContextMenu);
        _edgeContextMenu.HideOnItemSelection = true;
        _edgeContextMenu.IdPressed += OnEdgeContextMenuIdPressed;
        BuildEdgeContextMenuItems();
    }

    void BuildEdgeContextMenuItems()
    {
        if (_edgeContextMenu == null)
            return;
        var m = _edgeContextMenu;
        m.Clear();
        m.AddItem("Bezier curve (drag handles)", CtxBezier);
        m.SetItemTooltip(m.ItemCount - 1, "Editable cubic curve between the two corners.");
        m.AddItem("Straight edge", CtxLinear);
        m.SetItemTooltip(m.ItemCount - 1, "Remove curve / wave / arch on this edge.");
        m.AddSeparator();
        m.AddItem("Arch (preset profile)", CtxArch);
        m.SetItemTooltip(m.ItemCount - 1, "Parametric arch; tune mode & detail in the inspector.");
        m.AddItem("Sine wave", CtxSine);
        m.SetItemTooltip(m.ItemCount - 1, "Wavy edge; drag yellow pivot.");
        m.AddItem("Repeat (zigzag)", CtxRepeat);
        m.SetItemTooltip(m.ItemCount - 1, "Repeated segments along the edge.");
        m.AddSeparator();
        m.AddItem("Bake curve → corner vertices", CtxApplyGen);
        m.SetItemTooltip(m.ItemCount - 1, "Replace generator with plain vertices (destructive).");
        m.AddItem("Apply inspector numbers to edge", CtxApplyProps);
        m.SetItemTooltip(m.ItemCount - 1, "Copy Arch/Sine/Repeat fields from spinboxes to this edge.");
    }

    void OnEdgeContextMenuIdPressed(long id)
    {
        switch ((int)id)
        {
            case CtxBezier: EdgeMenuBezier?.Invoke(); break;
            case CtxLinear: EdgeMenuLinear?.Invoke(); break;
            case CtxArch: EdgeMenuArch?.Invoke(); break;
            case CtxSine: EdgeMenuSine?.Invoke(); break;
            case CtxRepeat: EdgeMenuRepeat?.Invoke(); break;
            case CtxApplyGen: EdgeMenuApplyGenerators?.Invoke(); break;
            case CtxApplyProps: EdgeMenuApplyProps?.Invoke(); break;
        }
    }

    void OpenEdgeContextMenuAt(GVector2 localPosition)
    {
        if (_edgeContextMenu == null)
            return;
        _edgeContextMenu.Position = (Vector2I)localPosition;
        _edgeContextMenu.Popup();
    }

    /// <summary>Centers world origin in the control once we have a size (no auto-fit to bounds).</summary>
    void TryInitializeViewport()
    {
        var size = Size;
        if (size.X < 8f || size.Y < 8f)
            return;
        if (_viewportInitialized)
            return;

        _zoom = DefaultZoom;
        _pan = new GVector2(MathF.Round(size.X * 0.5f), MathF.Round(size.Y * 0.5f));
        _viewportInitialized = true;
        QueueRedraw();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationResized)
            TryInitializeViewport();
        base._Notification(what);
    }

    void ApplyZoomTowards(GVector2 screenPos, float newZoom)
    {
        newZoom = Godot.Mathf.Clamp(newZoom, MinZoom, MaxZoom);
        var oldZ = _zoom;
        if (Math.Abs(newZoom - oldZ) < 1e-5f)
            return;

        var g = ScreenToGrid(screenPos);
        _pan.X += g.x * (oldZ - newZoom);
        _pan.Y += g.y * (newZoom - oldZ);
        _zoom = newZoom;
    }

    public override void _Draw()
    {
        if (Project == null)
            return;

        var size = Size;
        if (size.X < 1 || size.Y < 1)
            return;

        TryInitializeViewport();

        DrawRect(new Rect2(GVector2.Zero, size), new Godot.Color(0.12f, 0.12f, 0.14f, 1f));
        DrawBackgroundImage(size);
        DrawGrid(size);

        Project.Validate();

        foreach (var shape in Project.shapes)
        {
            var polys = shape.GenerateConcavePolygons(false);
            foreach (var poly in polys)
            {
                var pts = new GVector2[poly.Count + 1];
                for (var i = 0; i < poly.Count; i++)
                    pts[i] = GridToScreenDraw(poly[i].position.x, poly[i].position.y);
                pts[^1] = pts[0];

                var sc = shape.segmentColor;
                DrawPolyline(pts, new Godot.Color(sc.r, sc.g, sc.b, 0.95f), 2f, true);
            }
        }

        DrawBezierDecorations();
        DrawParametricGeneratorCurves();
        DrawMeasuringTape();
        DrawRotateDragVisual();

        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                var p = GridToScreenDraw(seg.position.x, seg.position.y);
                var sel = seg.selected;
                DrawCircle(p, sel ? 6f : 4f, sel ? Colors.OrangeRed : Colors.White);
            }
        }

        if (_marqueeDragging)
        {
            var a = _marqueeStart;
            var b = _marqueeEnd;
            var rect = new Rect2(
                new GVector2(Math.Min(a.X, b.X), Math.Min(a.Y, b.Y)),
                new GVector2(Math.Abs(b.X - a.X), Math.Abs(b.Y - a.Y)));
            DrawRect(rect, new Godot.Color(0.2f, 0.55f, 1f, 0.12f));
            DrawRect(rect, new Godot.Color(0.35f, 0.65f, 1f, 0.9f), false, 1f);
        }
    }

    /// <summary>TB grid step in world space: power-of-two in Quake, coarsened by zoom so lines stay readable.</summary>
    float GetTrenchBroomGridDrawStepWorld() =>
        TrenchBroomGrid.PickViewportGridStepWorld(Math.Max(SnapIncrement, 1e-6f), _zoom, 10f);

    static void TbGridLineStyle(int quakeCoord, int minorQuake, out Godot.Color color, out float width)
    {
        var onWorld = TrenchBroomGrid.Mod(quakeCoord, 64) == 0;
        var block = minorQuake * 8;
        var onEightCells = !onWorld && block > 0 && TrenchBroomGrid.Mod(quakeCoord, block) == 0;
        if (onWorld)
        {
            color = new Godot.Color(1f, 1f, 1f, 0.22f);
            width = 2f;
        }
        else if (onEightCells)
        {
            color = new Godot.Color(1f, 1f, 1f, 0.12f);
            width = 1.35f;
        }
        else
        {
            color = new Godot.Color(1f, 1f, 1f, 0.055f);
            width = 1f;
        }
    }

    void DrawGrid(GVector2 size)
    {
        var step = GetTrenchBroomGridDrawStepWorld();
        var minorQuake = Math.Max(1, (int)Math.Round(step * TrenchBroomGrid.QuakeUnitsPerWorld));

        var c0 = ScreenToGridRaw(GVector2.Zero);
        var c1 = ScreenToGridRaw(new GVector2(size.X, 0));
        var c2 = ScreenToGridRaw(new GVector2(0, size.Y));
        var c3 = ScreenToGridRaw(size);

        var minGx = Math.Min(Math.Min(c0.X, c1.X), Math.Min(c2.X, c3.X));
        var maxGx = Math.Max(Math.Max(c0.X, c1.X), Math.Max(c2.X, c3.X));
        var minGy = Math.Min(Math.Min(c0.Y, c1.Y), Math.Min(c2.Y, c3.Y));
        var maxGy = Math.Max(Math.Max(c0.Y, c1.Y), Math.Max(c2.Y, c3.Y));

        var margin = step * 2f;
        minGx -= margin;
        maxGx += margin;
        minGy -= margin;
        maxGy += margin;

        var gx0 = (float)(Math.Floor(minGx / step - 1e-6) * step);
        var gx1 = (float)(Math.Ceiling(maxGx / step + 1e-6) * step);
        var gy0 = (float)(Math.Floor(minGy / step - 1e-6) * step);
        var gy1 = (float)(Math.Ceiling(maxGy / step + 1e-6) * step);

        for (var gx = gx0; gx <= gx1 + step * 0.001f; gx += step)
        {
            var qq = TrenchBroomGrid.WorldToQuake(gx);
            TbGridLineStyle(qq, minorQuake, out var col, out var w);
            var a = GridToScreenDraw(gx, minGy);
            var b = GridToScreenDraw(gx, maxGy);
            DrawGridLine2D(a, b, col, w);
        }

        for (var gy = gy0; gy <= gy1 + step * 0.001f; gy += step)
        {
            var qq = TrenchBroomGrid.WorldToQuake(gy);
            TbGridLineStyle(qq, minorQuake, out var col, out var w);
            var a = GridToScreenDraw(minGx, gy);
            var b = GridToScreenDraw(maxGx, gy);
            DrawGridLine2D(a, b, col, w);
        }

        var origin = GridToScreenDraw(0f, 0f);
        DrawGridLine2D(new GVector2(0, origin.Y), new GVector2(size.X, origin.Y), new Godot.Color(0.95f, 0.2f, 0.15f, 0.9f), 2f);
        DrawGridLine2D(new GVector2(origin.X, 0), new GVector2(origin.X, size.Y), new Godot.Color(0.2f, 0.85f, 0.25f, 0.9f), 2f);
    }

    void DrawBezierDecorations()
    {
        if (Project == null)
            return;

        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.generator.type == SegmentGeneratorType.Bezier)
                {
                    var gen = seg.generator;
                    var s0 = GridToScreenDraw(seg.position.x, seg.position.y);
                    var s1 = GridToScreenDraw(gen.bezierPivot1.position.x, gen.bezierPivot1.position.y);
                    var s2 = GridToScreenDraw(gen.bezierPivot2.position.x, gen.bezierPivot2.position.y);
                    var s3 = GridToScreenDraw(seg.next.position.x, seg.next.position.y);

                    if (gen.bezierQuadratic)
                    {
                        DrawDashedLine(s0, s1, new Godot.Color(0f, 0.85f, 0.85f, 0.7f));
                        DrawDashedLine(s1, s3, new Godot.Color(0f, 0.85f, 0.85f, 0.7f));
                    }
                    else
                    {
                        DrawGridLine2D(s0, s1, new Godot.Color(0.25f, 0.45f, 1f, 0.75f), 1f);
                        DrawGridLine2D(s3, s2, new Godot.Color(0.25f, 0.45f, 1f, 0.75f), 1f);
                    }

                    DrawPivotHandle(gen.bezierPivot1);
                    if (!gen.bezierQuadratic)
                        DrawPivotHandle(gen.bezierPivot2);
                }
                else if (seg.generator.type == SegmentGeneratorType.Sine)
                {
                    DrawPivotHandle(seg.generator.sinePivot1);
                }
            }
        }
    }

    void DrawParametricGeneratorCurves()
    {
        if (Project == null)
            return;

        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                var t = seg.generator.type;
                if (t != SegmentGeneratorType.Arch && t != SegmentGeneratorType.Sine && t != SegmentGeneratorType.Repeat)
                    continue;

                var col = t switch
                {
                    SegmentGeneratorType.Arch => new Godot.Color(0.95f, 0.45f, 0.2f, 0.85f),
                    SegmentGeneratorType.Sine => new Godot.Color(0.95f, 0.9f, 0.2f, 0.85f),
                    _ => new Godot.Color(0.25f, 0.85f, 0.95f, 0.85f),
                };

                var prev = seg.position;
                foreach (var p in seg.generator.ForEachAdditionalSegmentPoint())
                {
                    var a = GridToScreenDraw(prev.x, prev.y);
                    var b = GridToScreenDraw(p.x, p.y);
                    DrawGridLine2D(a, b, col, 1.25f);
                    prev = p;
                }

                var end = seg.next.position;
                DrawGridLine2D(GridToScreenDraw(prev.x, prev.y), GridToScreenDraw(end.x, end.y), col, 1.25f);
            }
        }
    }

    void DrawPivotHandle(Pivot pivot)
    {
        var c = GridToScreenDraw(pivot.position.x, pivot.position.y);
        var half = Math.Max(4f, ShapeEditorWindow.halfPivotScale * _zoom);
        var rect = new Rect2(c - new GVector2(half, half), new GVector2(half * 2f, half * 2f));
        var fill = pivot.selected ? Colors.LightYellow : Colors.White;
        DrawRect(rect, fill);
        DrawRect(rect, Colors.Black, false, 1f);
    }

    void DrawDashedLine(GVector2 a, GVector2 b, Godot.Color color, int segments = 10)
    {
        for (var i = 0; i < segments; i += 2)
        {
            var t0 = i / (float)segments;
            var t1 = Math.Min(1f, (i + 1) / (float)segments);
            var p0 = a.Lerp(b, t0);
            var p1 = a.Lerp(b, t1);
            DrawGridLine2D(p0, p1, color, 1f);
        }
    }

    void DrawGridLine2D(GVector2 a, GVector2 b, Godot.Color color, float width) =>
        DrawMultiline(new[] { a, b }, color, width, true);

    GVector2 GridToScreen(float gx, float gy)
    {
        var dx = gx * _zoom + _pan.X;
        var dy = -gy * _zoom + _pan.Y;
        return new GVector2(dx, dy);
    }

    /// <summary>Pixel-rounded projection so grid intersections and vertex handles land on the same screen pixels.</summary>
    GVector2 GridToScreenDraw(float gx, float gy)
    {
        var p = GridToScreen(gx, gy);
        return new GVector2(MathF.Round(p.X), MathF.Round(p.Y));
    }

    float2 ScreenToGrid(GVector2 screen)
    {
        var gx = (screen.X - _pan.X) / _zoom;
        var gy = -(screen.Y - _pan.Y) / _zoom;
        return new float2(gx, gy);
    }

    GVector2 ScreenToGridRaw(GVector2 screen)
    {
        var g = ScreenToGrid(screen);
        return new GVector2(g.x, g.y);
    }

    float2 SnapGrid(float2 g)
    {
        if (!SnapEnabled || SnapIncrement <= 1e-8f)
            return g;
        var s = (double)TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast(SnapIncrement);
        var x = (float)(Math.Round(g.x / s) * s);
        var y = (float)(Math.Round(g.y / s) * s);
        return new float2(x, y);
    }

    public override void _GuiInput(InputEvent @event)
    {
        TryInitializeViewport();

        if (@event is InputEventMouseButton mb)
        {
            if (mb.ButtonIndex == MouseButton.WheelUp && mb.Pressed)
            {
                if (mb.CtrlPressed || mb.MetaPressed)
                {
                    var next = TrenchBroomGrid.NextFinerSnapWorld(SnapIncrement);
                    if (Math.Abs(next - SnapIncrement) > 1e-8f)
                    {
                        SnapIncrement = next;
                        SnapIncrementAdjusted?.Invoke(next);
                    }

                    QueueRedraw();
                    GetViewport().SetInputAsHandled();
                    return;
                }

                ApplyZoomTowards(mb.Position, _zoom * ZoomStepFactor);
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                return;
            }

            if (mb.ButtonIndex == MouseButton.WheelDown && mb.Pressed)
            {
                if (mb.CtrlPressed || mb.MetaPressed)
                {
                    var next = TrenchBroomGrid.NextCoarserSnapWorld(SnapIncrement);
                    if (Math.Abs(next - SnapIncrement) > 1e-8f)
                    {
                        SnapIncrement = next;
                        SnapIncrementAdjusted?.Invoke(next);
                    }

                    QueueRedraw();
                    GetViewport().SetInputAsHandled();
                    return;
                }

                ApplyZoomTowards(mb.Position, _zoom / ZoomStepFactor);
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                return;
            }

            if (mb.ButtonIndex == MouseButton.Middle)
            {
                if (mb.Pressed)
                {
                    _isPanning = true;
                    _lastPanMousePos = mb.Position;
                }
                else
                    _isPanning = false;

                GetViewport().SetInputAsHandled();
                return;
            }
        }

        if (Project == null)
            return;

        Project.Validate();

        if (@event is InputEventKey ik && ik.Pressed && !ik.Echo)
        {
            if (ik.Keycode == Key.Delete || ik.Keycode == Key.Backspace)
            {
                BeforeProjectMutation?.Invoke();
                TryDeleteSelectedVertices();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return;
            }
        }

        if (@event is InputEventMouseButton mbR && mbR.ButtonIndex == MouseButton.Right && mbR.Pressed)
        {
            if (Project.HasAnyFullySelectedEdge())
                OpenEdgeContextMenuAt(mbR.Position);
            GetViewport().SetInputAsHandled();
            AcceptEvent();
            return;
        }

        if (@event is InputEventMouseButton mb2 && mb2.ButtonIndex == MouseButton.Left)
        {
            if (TryHandleToolSpecificInput(@event))
                return;

            var shift = mb2.ShiftPressed;
            var g = ScreenToGrid(mb2.Position);

            if (mb2.Pressed)
            {
                _leftButtonHeld = true;

                if (_isPanning)
                    return;

                var edgeTol = EdgePickPixels / _zoom;
                var vertTol = VertexPickPixels / _zoom;
                var pivotTol = PivotPickPixels / _zoom;

                if (mb2.DoubleClick)
                {
                    if (!TryPickVertex(g, vertTol, out _) && !TryPickBezierPivot(g, pivotTol, out _) &&
                        !TryPickSinePivot(g, pivotTol, out _))
                    {
                        if (Project.TryFindEdgeInsertPoint(g, edgeTol, vertTol * 0.9f, out var host, out var raw))
                        {
                            var snapped = SnapGrid(raw);
                            if (math.distance(snapped, host.position) > 1e-4f &&
                                math.distance(snapped, host.next.position) > 1e-4f)
                            {
                                BeforeProjectMutation?.Invoke();
                                var shape = host.shape;
                                shape.InsertSegmentBefore(host.next, new Segment(shape, snapped));
                                host.generator = new SegmentGenerator(host);
                                Project.Invalidate();
                                Project.ClearSelection();
                                ProjectChanged?.Invoke();
                                QueueRedraw();
                                GetViewport().SetInputAsHandled();
                                AcceptEvent();
                                return;
                            }
                        }
                    }
                }

                if (ActiveTool == Editor2DTool.Rotate &&
                    VertexSelectionTransforms.HasSelectedSegmentVertex(Project))
                {
                    var gUnsnapped = ScreenToGrid(mb2.Position);
                    _dragVertexSegment = null;
                    _dragPivot = null;
                    _vertexDragUndoPushed = false;
                    _pivotDragUndoPushed = false;
                    _marqueePending = false;
                    _marqueeDragging = false;
                    BeginRotateDrag(gUnsnapped, mb2.Position);
                    GetViewport().SetInputAsHandled();
                    AcceptEvent();
                    return;
                }

                _dragVertexSegment = null;
                _dragPivot = null;
                _vertexDragUndoPushed = false;
                _pivotDragUndoPushed = false;
                _marqueePending = false;
                _marqueeDragging = false;

                if (TryPickBezierPivot(g, pivotTol, out var pivot))
                {
                    if (!shift)
                        Project.ClearSelection();
                    else
                        pivot.selected = !pivot.selected;
                    if (!shift || pivot.selected)
                    {
                        if (!shift)
                            pivot.selected = true;
                        _dragPivot = pivot;
                        _pivotDragOrigin = pivot.position;
                        _pivotDragUndoPushed = false;
                    }

                    ProjectChanged?.Invoke();
                    QueueRedraw();
                    GetViewport().SetInputAsHandled();
                }
                else if (TryPickSinePivot(g, pivotTol, out var sinePivot))
                {
                    if (!shift)
                        Project.ClearSelection();
                    else
                        sinePivot.selected = !sinePivot.selected;
                    if (!shift || sinePivot.selected)
                    {
                        if (!shift)
                            sinePivot.selected = true;
                        _dragPivot = sinePivot;
                        _pivotDragOrigin = sinePivot.position;
                        _pivotDragUndoPushed = false;
                    }

                    ProjectChanged?.Invoke();
                    QueueRedraw();
                    GetViewport().SetInputAsHandled();
                }
                else if (TryPickVertex(g, vertTol, out var vertexSeg))
                {
                    if (!shift)
                    {
                        // Keep existing multi-selection when dragging an already-selected vertex.
                        if (!vertexSeg.selected)
                            Project.ClearSelection();
                        vertexSeg.selected = true;
                        _dragVertexSegment = vertexSeg;
                        _vertexDragOrigin = vertexSeg.position;
                        _vertexDragLastGrid = SnapGrid(g);
                        _vertexDragUndoPushed = false;
                    }
                    else
                    {
                        vertexSeg.selected = !vertexSeg.selected;
                        if (vertexSeg.selected)
                        {
                            _dragVertexSegment = vertexSeg;
                            _vertexDragOrigin = vertexSeg.position;
                            _vertexDragLastGrid = SnapGrid(g);
                            _vertexDragUndoPushed = false;
                        }
                    }

                    ProjectChanged?.Invoke();
                    QueueRedraw();
                    GetViewport().SetInputAsHandled();
                }
                else if (mb2.AltPressed && !shift)
                {
                    SelectShapeFaceAt(g);
                    GetViewport().SetInputAsHandled();
                }
                else if (EffectiveClickInsertVertex && Project.TryFindEdgeInsertPoint(g, edgeTol, vertTol * 0.9f, out var insHost, out var insRaw))
                {
                    var snapped = SnapGrid(insRaw);
                    if (math.distance(snapped, insHost.position) > 1e-4f &&
                        math.distance(snapped, insHost.next.position) > 1e-4f)
                    {
                        BeforeProjectMutation?.Invoke();
                        var shp = insHost.shape;
                        shp.InsertSegmentBefore(insHost.next, new Segment(shp, snapped));
                        insHost.generator = new SegmentGenerator(insHost);
                        Project.Invalidate();
                        Project.ClearSelection();
                        ProjectChanged?.Invoke();
                        QueueRedraw();
                        GetViewport().SetInputAsHandled();
                    }
                }
                else if (Project.FindSegmentLineAtPosition(g, edgeTol) is { } edgeSeg)
                {
                    if (!shift)
                    {
                        Project.ClearSelection();
                        edgeSeg.selected = true;
                        edgeSeg.next.selected = true;
                    }
                    else
                    {
                        var on = !(edgeSeg.selected && edgeSeg.next.selected);
                        edgeSeg.selected = on;
                        edgeSeg.next.selected = on;
                    }

                    // Edge pick selects endpoints but did not set a drag anchor — motion was ignored.
                    _dragVertexSegment = math.distance(g, edgeSeg.position) <= math.distance(g, edgeSeg.next.position)
                        ? edgeSeg
                        : edgeSeg.next;
                    _vertexDragOrigin = _dragVertexSegment.position;
                    _vertexDragLastGrid = SnapGrid(g);
                    _vertexDragUndoPushed = false;

                    ProjectChanged?.Invoke();
                    QueueRedraw();
                    GetViewport().SetInputAsHandled();
                }
                else
                {
                    _marqueeStart = mb2.Position;
                    _marqueeEnd = mb2.Position;
                    _marqueePending = true;
                    _marqueeHadShift = shift;
                    GetViewport().SetInputAsHandled();
                }
            }
            else
            {
                _leftButtonHeld = false;

                if (_marqueeDragging)
                    ApplyMarqueeSelection(_marqueeHadShift);
                else if (_marqueePending && !_marqueeHadShift)
                    Project.ClearSelection();

                _marqueePending = false;
                _marqueeDragging = false;
                _dragVertexSegment = null;
                _dragPivot = null;
                _vertexDragUndoPushed = false;
                _pivotDragUndoPushed = false;
                CancelRotateDragSession();
                ProjectChanged?.Invoke();
                QueueRedraw();
            }
        }
        else if (@event is InputEventMouseMotion mm)
        {
            if (_isPanning && (mm.ButtonMask & MouseButtonMask.Middle) != 0)
            {
                var d = mm.Position - _lastPanMousePos;
                _pan += d;
                _lastPanMousePos = mm.Position;
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                return;
            }

            if (TryHandleToolSpecificInput(@event))
                return;

            var leftHeld = _leftButtonHeld || (mm.ButtonMask & MouseButtonMask.Left) != 0;
            if (!leftHeld)
                return;

            if (_rotateDragActive)
            {
                ProcessRotateDragMotion(mm.Position);
                return;
            }

            if (_marqueePending && !_marqueeDragging && _marqueeStart.DistanceTo(mm.Position) >= MarqueeDragThresholdPx)
            {
                if (!_marqueeHadShift)
                    Project.ClearSelection();
                _marqueeDragging = true;
            }

            if (_marqueeDragging)
            {
                _marqueeEnd = mm.Position;
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                return;
            }

            var snapped = SnapGrid(ScreenToGrid(mm.Position));

            if (_dragPivot != null)
            {
                if (!_pivotDragUndoPushed && math.distance(snapped, _pivotDragOrigin) > 1e-8f)
                {
                    BeforeProjectMutation?.Invoke();
                    _pivotDragUndoPushed = true;
                }

                _dragPivot.position = snapped;
                ProjectChanged?.Invoke();
                QueueRedraw();
                GetViewport().SetInputAsHandled();
            }
            else if (_dragVertexSegment != null)
            {
                var gridNow = SnapGrid(ScreenToGrid(mm.Position));
                var delta = gridNow - _vertexDragLastGrid;
                if (math.lengthsq(delta) < 1e-16f)
                {
                    GetViewport().SetInputAsHandled();
                    return;
                }

                if (!_vertexDragUndoPushed)
                {
                    BeforeProjectMutation?.Invoke();
                    _vertexDragUndoPushed = true;
                }

                _vertexDragLastGrid = gridNow;
                VertexSelectionTransforms.TranslateSelection(Project!, delta);
                ProjectChanged?.Invoke();
                QueueRedraw();
                GetViewport().SetInputAsHandled();
            }
        }
    }

    bool TryDeleteSelectedVertices()
    {
        if (Project == null)
            return false;

        Project.Validate();

        var anyRemoved = false;
        var blocked = false;

        foreach (var shape in Project.shapes)
        {
            var toRemove = new List<Segment>();
            foreach (var s in shape.segments)
            {
                if (s.selected)
                    toRemove.Add(s);
            }

            if (toRemove.Count == 0)
                continue;

            if (shape.segments.Count - toRemove.Count < 3)
            {
                blocked = true;
                continue;
            }

            toRemove.Sort((a, b) => shape.segments.IndexOf(b).CompareTo(shape.segments.IndexOf(a)));

            foreach (var s in toRemove)
            {
                if (shape.segments.Count <= 3)
                    break;
                var prev = s.previous;
                shape.RemoveSegment(s);
                prev.generator = new SegmentGenerator(prev);
                anyRemoved = true;
            }
        }

        if (anyRemoved)
        {
            Project.Invalidate();
            Project.ClearSelection();
            ProjectChanged?.Invoke();
            QueueRedraw();
        }
        else if (blocked)
            OS.Alert("Each shape must keep at least 3 vertices.", "ShapeUp");

        return anyRemoved;
    }

    void ApplyMarqueeSelection(bool addToExisting)
    {
        if (Project == null)
            return;

        var g0 = ScreenToGrid(_marqueeStart);
        var g1 = ScreenToGrid(_marqueeEnd);
        var minX = Math.Min(g0.x, g1.x);
        var maxX = Math.Max(g0.x, g1.x);
        var minY = Math.Min(g0.y, g1.y);
        var maxY = Math.Max(g0.y, g1.y);

        if (!addToExisting)
            Project.ClearSelection();

        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                var p = seg.position;
                if (p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY)
                    seg.selected = true;

                if (seg.generator.type == SegmentGeneratorType.Bezier)
                {
                    var gen = seg.generator;
                    var p1 = gen.bezierPivot1.position;
                    if (p1.x >= minX && p1.x <= maxX && p1.y >= minY && p1.y <= maxY)
                        gen.bezierPivot1.selected = true;
                    if (!gen.bezierQuadratic)
                    {
                        var p2 = gen.bezierPivot2.position;
                        if (p2.x >= minX && p2.x <= maxX && p2.y >= minY && p2.y <= maxY)
                            gen.bezierPivot2.selected = true;
                    }
                }
                else if (seg.generator.type == SegmentGeneratorType.Sine)
                {
                    var p1 = seg.generator.sinePivot1.position;
                    if (p1.x >= minX && p1.x <= maxX && p1.y >= minY && p1.y <= maxY)
                        seg.generator.sinePivot1.selected = true;
                }
            }
        }
    }

    bool TryPickVertex(float2 g, float maxDist, out Segment seg)
    {
        seg = null!;
        Segment? best = null;
        var bestD = float.MaxValue;
        foreach (var shape in Project!.shapes)
        {
            foreach (var s in shape.segments)
            {
                var d = math.distance(g, s.position);
                if (d < maxDist && d < bestD)
                {
                    bestD = d;
                    best = s;
                }
            }
        }

        if (best == null)
            return false;
        seg = best;
        return true;
    }

    bool TryPickBezierPivot(float2 g, float maxDist, out Pivot pivot)
    {
        pivot = null!;
        Pivot? best = null;
        var bestD = float.MaxValue;
        foreach (var shape in Project!.shapes)
        {
            foreach (var s in shape.segments)
            {
                if (s.generator.type != SegmentGeneratorType.Bezier)
                    continue;

                var gen = s.generator;
                var d1 = math.distance(g, gen.bezierPivot1.position);
                if (d1 < maxDist && d1 < bestD)
                {
                    bestD = d1;
                    best = gen.bezierPivot1;
                }

                if (!gen.bezierQuadratic)
                {
                    var d2 = math.distance(g, gen.bezierPivot2.position);
                    if (d2 < maxDist && d2 < bestD)
                    {
                        bestD = d2;
                        best = gen.bezierPivot2;
                    }
                }
            }
        }

        if (best == null)
            return false;
        pivot = best;
        return true;
    }

    bool TryPickSinePivot(float2 g, float maxDist, out Pivot pivot)
    {
        pivot = null!;
        Pivot? best = null;
        var bestD = float.MaxValue;
        foreach (var shape in Project!.shapes)
        {
            foreach (var s in shape.segments)
            {
                if (s.generator.type != SegmentGeneratorType.Sine)
                    continue;
                var d1 = math.distance(g, s.generator.sinePivot1.position);
                if (d1 < maxDist && d1 < bestD)
                {
                    bestD = d1;
                    best = s.generator.sinePivot1;
                }
            }
        }

        if (best == null)
            return false;
        pivot = best;
        return true;
    }

    static bool TryFindEdgeFromTwoVertices(Shape shape, out Segment? edgeSeg)
    {
        edgeSeg = null;
        Segment? a = null;
        Segment? b = null;
        foreach (var s in shape.segments)
        {
            if (!s.selected)
                continue;
            if (a == null)
                a = s;
            else if (b == null)
                b = s;
            else
                return false;
        }

        if (a == null || b == null)
            return false;
        if (a.next == b || b.next == a)
        {
            edgeSeg = a.next == b ? a : b;
            return true;
        }

        return false;
    }

    void ApplyBezierToSegment(Segment seg)
    {
        BeforeProjectMutation?.Invoke();
        seg.generator = new SegmentGenerator(seg, SegmentGeneratorType.Bezier);
        Project!.Invalidate();
        Project.ClearSelection();
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    void ApplyLinearToSegment(Segment seg)
    {
        BeforeProjectMutation?.Invoke();
        seg.generator = new SegmentGenerator(seg);
        Project!.Invalidate();
        Project.ClearSelection();
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    public void ConvertSelectedEdgeToBezier()
    {
        if (Project == null)
            return;

        Project.Validate();
        foreach (var shape in Project.shapes)
        {
            if (TryFindEdgeFromTwoVertices(shape, out var edge) && edge != null)
            {
                ApplyBezierToSegment(edge);
                return;
            }

            foreach (var seg in shape.segments)
            {
                if (seg.selected && seg.next.selected)
                {
                    ApplyBezierToSegment(seg);
                    return;
                }
            }
        }
    }

    public void ConvertSelectedEdgeToLinear()
    {
        if (Project == null)
            return;

        Project.Validate();
        foreach (var shape in Project.shapes)
        {
            if (TryFindEdgeFromTwoVertices(shape, out var edge) && edge != null)
            {
                ApplyLinearToSegment(edge);
                return;
            }

            foreach (var seg in shape.segments)
            {
                if (seg.selected && seg.next.selected)
                {
                    ApplyLinearToSegment(seg);
                    return;
                }
            }
        }
    }

    public void FlipSelectionHorizontally()
    {
        if (Project == null)
            return;
        BeforeProjectMutation?.Invoke();
        Project.Validate();
        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;
                var pos = seg.position;
                pos.x *= -1f;
                seg.position = pos;
                var g = seg.generator;
                if (g.type == SegmentGeneratorType.Bezier)
                {
                    var bp1 = g.bezierPivot1.position;
                    bp1.x *= -1f;
                    g.bezierPivot1.position = bp1;
                    if (!g.bezierQuadratic)
                    {
                        var bp2 = g.bezierPivot2.position;
                        bp2.x *= -1f;
                        g.bezierPivot2.position = bp2;
                    }
                }
                else if (g.type == SegmentGeneratorType.Sine)
                {
                    var sp = g.sinePivot1.position;
                    sp.x *= -1f;
                    g.sinePivot1.position = sp;
                }

                g.FlipDirection();
            }
        }

        Project.Invalidate();
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    public void FlipSelectionVertically()
    {
        if (Project == null)
            return;
        BeforeProjectMutation?.Invoke();
        Project.Validate();
        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;
                var pos = seg.position;
                pos.y *= -1f;
                seg.position = pos;
                var g = seg.generator;
                if (g.type == SegmentGeneratorType.Bezier)
                {
                    var bp1 = g.bezierPivot1.position;
                    bp1.y *= -1f;
                    g.bezierPivot1.position = bp1;
                    if (!g.bezierQuadratic)
                    {
                        var bp2 = g.bezierPivot2.position;
                        bp2.y *= -1f;
                        g.bezierPivot2.position = bp2;
                    }
                }
                else if (g.type == SegmentGeneratorType.Sine)
                {
                    var sp = g.sinePivot1.position;
                    sp.y *= -1f;
                    g.sinePivot1.position = sp;
                }

                g.FlipDirection();
            }
        }

        Project.Invalidate();
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    public void SnapSelectionToGrid()
    {
        if (Project == null)
            return;
        BeforeProjectMutation?.Invoke();
        Project.Validate();
        foreach (var shape in Project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;
                seg.position = SnapGrid(seg.position);
                var g = seg.generator;
                if (g.type == SegmentGeneratorType.Bezier)
                {
                    g.bezierPivot1.position = SnapGrid(g.bezierPivot1.position);
                    if (!g.bezierQuadratic)
                        g.bezierPivot2.position = SnapGrid(g.bezierPivot2.position);
                }
                else if (g.type == SegmentGeneratorType.Sine)
                    g.sinePivot1.position = SnapGrid(g.sinePivot1.position);
            }
        }

        Project.Invalidate();
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    public void RotateSelectedVerticesDegrees(float degrees)
    {
        if (Project == null || math.abs(degrees) < 1e-6f)
            return;
        if (!VertexSelectionTransforms.HasSelectedSegmentVertex(Project))
            return;
        BeforeProjectMutation?.Invoke();
        VertexSelectionTransforms.RotateSelectionDegrees(Project, degrees);
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    public void ScaleSelectedVertices(float uniformScale)
    {
        if (Project == null || math.abs(uniformScale - 1f) < 1e-6f)
            return;
        if (!VertexSelectionTransforms.HasSelectedSegmentVertex(Project))
            return;
        BeforeProjectMutation?.Invoke();
        VertexSelectionTransforms.ScaleSelectionUniform(Project, uniformScale);
        ProjectChanged?.Invoke();
        QueueRedraw();
    }

    static bool PointInPolygon(float2 p, Polygon poly)
    {
        var n = poly.Count;
        var inside = false;
        for (var i = 0; i < n; i++)
        {
            var j = (i + n - 1) % n;
            var vi = poly[i].position;
            var vj = poly[j].position;
            var yi = vi.y;
            var yj = vj.y;
            if ((yi > p.y) == (yj > p.y))
                continue;
            var xi = vi.x;
            var xj = vj.x;
            var x = (xj - xi) * (p.y - yi) / (yj - yi) + xi;
            if (p.x < x)
                inside = !inside;
        }

        return inside;
    }

    /// <summary>Face-style: select all vertices of shapes whose filled outline contains the point (first hit).</summary>
    public void SelectShapeFaceAt(float2 gridPoint)
    {
        if (Project == null)
            return;
        Project.Validate();
        Project.ClearSelection();
        foreach (var shape in Project.shapes)
        {
            var polys = shape.GenerateConcavePolygons(false);
            foreach (var poly in polys)
            {
                if (poly.Count < 3)
                    continue;
                if (!PointInPolygon(gridPoint, poly))
                    continue;
                foreach (var seg in shape.segments)
                    seg.selected = true;
                Project.Invalidate();
                ProjectChanged?.Invoke();
                QueueRedraw();
                return;
            }
        }
    }
}
