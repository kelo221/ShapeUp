using System.Globalization;
using Godot;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;
using GVector2 = Godot.Vector2;

namespace ShapeUp.Features.Editor2D;

public partial class ShapeEditor2DView
{
    Editor2DTool _activeTool = Editor2DTool.Select;

    public Editor2DTool ActiveTool
    {
        get => _activeTool;
        set
        {
            if (_activeTool == value)
                return;
            if (_activeTool == Editor2DTool.Measure)
                ResetMeasureState();
            if (value != Editor2DTool.Rotate)
                CancelRotateDragSession();
            _activeTool = value;
            QueueRedraw();
        }
    }

    /// <summary>Reference image under the grid (world-centered, matches Unity background).</summary>
    public Texture2D? BackgroundImage { get; set; }

    public float BackgroundScale { get; set; } = 1f;
    public float BackgroundAlpha { get; set; } = 0.25f;

    float2 _measureStart;
    float2 _measureEnd;
    bool _measureProc;
    bool _measureDragging;
    float _measureLength;

    bool EffectiveClickInsertVertex => ClickInsertVertexMode || ActiveTool == Editor2DTool.Draw;

    bool _rotateDragActive;
    float2 _rotatePivot;
    float _rotateStartAngleDeg;
    bool _rotateUndoPushed;
    GVector2 _rotateDragLastScreen;

    void CancelRotateDragSession()
    {
        _rotateDragActive = false;
        _rotateUndoPushed = false;
    }

    void BeginRotateDrag(float2 mouseGridUnsnapped, GVector2 mouseScreen)
    {
        if (Project == null)
            return;
        VertexSelectionTransforms.CaptureRotateBaseline(Project);
        _rotatePivot = VertexSelectionTransforms.GetCentroidOfSelectedSegmentVertices(Project);
        _rotateStartAngleDeg = VertexSelectionTransforms.AngleFromPivotToPointDeg(_rotatePivot, mouseGridUnsnapped);
        _rotateDragActive = true;
        _rotateUndoPushed = false;
        _rotateDragLastScreen = mouseScreen;
    }

    void ProcessRotateDragMotion(GVector2 screenPos)
    {
        if (Project == null || !_rotateDragActive)
            return;

        _rotateDragLastScreen = screenPos;
        var mouseGrid = ScreenToGrid(screenPos);
        var cur = VertexSelectionTransforms.AngleFromPivotToPointDeg(_rotatePivot, mouseGrid);
        var rawTotalDeg = UnityEngine.Mathf.DeltaAngle(_rotateStartAngleDeg, cur);
        var stepDeg = SnapEnabled ? TrenchBroomGrid.RotateSnapStepDegreesFromSnapWorld(SnapIncrement) : 0f;
        var totalDeg = TrenchBroomGrid.SnapAngleDegrees(rawTotalDeg, stepDeg);

        if (!_rotateUndoPushed && math.abs(totalDeg) > 1e-4f)
        {
            BeforeProjectMutation?.Invoke();
            _rotateUndoPushed = true;
        }

        VertexSelectionTransforms.ApplyRotateFromBaseline(Project, _rotatePivot, totalDeg);
        ProjectChanged?.Invoke();
        QueueRedraw();
        GetViewport().SetInputAsHandled();
    }

    void DrawRotateDragVisual()
    {
        if (!_rotateDragActive || Project == null)
            return;

        var pivotS = GridToScreenDraw(_rotatePivot.x, _rotatePivot.y);
        DrawCircle(pivotS, 5f, new Godot.Color(0.35f, 0.85f, 1f, 0.95f));
        DrawDashedLine(pivotS, _rotateDragLastScreen, new Godot.Color(0.6f, 0.6f, 0.65f, 0.85f), 12);
    }

    void ResetMeasureState()
    {
        _measureProc = false;
        _measureDragging = false;
        _measureLength = 0f;
    }

    static string FormatMeasureDistance(float worldUnits)
    {
        var s = worldUnits.ToString("0.00000", CultureInfo.InvariantCulture).TrimEnd('0').TrimEnd('.');
        return s + "u";
    }

    static float2 NearestPointOnSegment(float2 p, float2 a, float2 b)
    {
        var ab = b - a;
        var ap = p - a;
        var denom = math.max(1e-12f, math.lengthsq(ab));
        var t = Godot.Mathf.Clamp((ap.x * ab.x + ap.y * ab.y) / denom, 0f, 1f);
        return a + ab * t;
    }

    void DrawBackgroundImage(GVector2 viewportSize)
    {
        if (BackgroundImage == null || BackgroundScale <= 1e-6f || BackgroundAlpha <= 1e-4f)
            return;

        var half = 0.5f * BackgroundScale;
        var c0 = GridToScreenDraw(-half, -half);
        var c1 = GridToScreenDraw(half, half);
        var boundsW = Math.Abs(c1.X - c0.X);
        var boundsH = Math.Abs(c1.Y - c0.Y);
        if (boundsW < 1f || boundsH < 1f)
            return;

        var texW = (float)BackgroundImage.GetWidth();
        var texH = (float)BackgroundImage.GetHeight();
        var ratio = Math.Min(1f / texW, 1f / texH);
        var w = texW * ratio * boundsW;
        var h = texH * ratio * boundsH;

        var midX = (c0.X + c1.X) * 0.5f;
        var midY = (c0.Y + c1.Y) * 0.5f;
        var rect = new Rect2(
            new GVector2(midX - w * 0.5f, midY - h * 0.5f),
            new GVector2(w, h));

        DrawTextureRect(BackgroundImage, rect, false, new Godot.Color(1f, 1f, 1f, BackgroundAlpha));
    }

    void DrawMeasuringTape()
    {
        if (ActiveTool != Editor2DTool.Measure)
            return;

        var p1 = GridToScreenDraw(_measureStart.x, _measureStart.y);
        var p2 = GridToScreenDraw(_measureEnd.x, _measureEnd.y);
        DrawLine(p1, p2, Colors.White, 2f);
        DrawDashedLine(p1, p2, Colors.Red, 16);

        var pivotCol = new Godot.Color(1f, 0.5f, 0f, 1f);
        DrawCircle(p1, 6f, pivotCol);
        DrawCircle(p2, 6f, pivotCol);

        if (!_measureProc || _measureLength <= 1e-6f)
            return;

        var text = FormatMeasureDistance(_measureLength);
        var font = ThemeDB.FallbackFont ?? GetThemeDefaultFont();
        var mid = (p1 + p2) * 0.5f;
        const int sz = 14;
        DrawString(font, mid + new GVector2(-1, -1), text, HorizontalAlignment.Center, -1, sz, new Godot.Color(0, 0, 0, 0.85f));
        DrawString(font, mid, text, HorizontalAlignment.Center, -1, sz, Colors.White);
    }

    /// <summary>Handles measure / cut tool input. Returns true if the event was consumed.</summary>
    bool TryHandleToolSpecificInput(InputEvent @event)
    {
        if (Project == null)
            return false;

        if (ActiveTool == Editor2DTool.Measure)
            return HandleMeasureToolInput(@event);

        if (ActiveTool == Editor2DTool.Cut)
            return HandleCutToolInput(@event);

        return false;
    }

    bool HandleMeasureToolInput(InputEvent @event)
    {
        if (@event is InputEventMouseMotion mm)
        {
            if (_isPanning)
                return false;

            var g = SnapGrid(ScreenToGrid(mm.Position));
            if (!_measureProc)
            {
                _measureStart = g;
                _measureEnd = g;
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                return true;
            }

            if (_measureDragging)
            {
                _measureEnd = g;
                _measureLength = math.distance(_measureStart, _measureEnd);
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                return true;
            }
        }
        else if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (_isPanning)
                return false;

            var g = SnapGrid(ScreenToGrid(mb.Position));
            if (mb.Pressed)
            {
                _measureStart = g;
                _measureEnd = g;
                _measureProc = true;
                _measureDragging = true;
                _measureLength = 0f;
                QueueRedraw();
                GetViewport().SetInputAsHandled();
                AcceptEvent();
                return true;
            }

            _measureEnd = g;
            _measureLength = math.distance(_measureStart, _measureEnd);
            if (_measureLength <= 1e-6f)
                _measureProc = false;
            _measureDragging = false;
            QueueRedraw();
            GetViewport().SetInputAsHandled();
            AcceptEvent();
            return true;
        }

        return false;
    }

    bool HandleCutToolInput(InputEvent @event)
    {
        if (@event is not InputEventMouseButton mb || mb.ButtonIndex != MouseButton.Left || !mb.Pressed)
            return false;
        if (_isPanning)
            return false;

        var g = ScreenToGrid(mb.Position);
        var edgeTol = EdgePickPixels / _zoom;
        var host = Project!.FindSegmentLineAtPosition(g, edgeTol);
        if (host == null)
        {
            GetViewport().SetInputAsHandled();
            AcceptEvent();
            return true;
        }

        var nearest = NearestPointOnSegment(g, host.position, host.next.position);
        var snapped = SnapGrid(nearest);
        if (math.distance(snapped, host.position) <= 1e-4f || math.distance(snapped, host.next.position) <= 1e-4f)
        {
            GetViewport().SetInputAsHandled();
            AcceptEvent();
            return true;
        }

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
        return true;
    }
}
