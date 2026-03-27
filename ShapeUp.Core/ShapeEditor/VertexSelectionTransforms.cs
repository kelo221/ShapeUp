using System;
using Unity.Mathematics;
using UnityEngine;

namespace ShapeUp.Core.ShapeEditor;

/// <summary>Moves, rotates, and scales selected vertices and generator pivots (shared by editor UI and automated tests).</summary>
public static class VertexSelectionTransforms
{
    /// <summary>Translates every selected <see cref="Segment"/> position and selected generator pivots by <paramref name="delta"/>.</summary>
    public static void TranslateSelection(Project project, float2 delta)
    {
        if (math.lengthsq(delta) < 1e-16f)
            return;

        project.Validate();
        foreach (var shape in project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.selected)
                    seg.position += delta;

                foreach (var selectable in seg.generator.ForEachSelectableObject())
                {
                    if (selectable.selected)
                        selectable.position += delta;
                }
            }
        }

        project.Invalidate();
    }

    /// <summary>Rotates selected segment vertices and selected pivots around the centroid of selected <em>segment</em> positions (degrees, CCW in +Y-up space).</summary>
    public static void RotateSelectionDegrees(Project project, float degrees)
    {
        if (math.abs(degrees) < 1e-6f || !AnySegmentVertexSelected(project))
            return;

        project.Validate();
        var c = GetCentroidOfSelectedSegmentVertices(project);
        var rad = degrees * (MathF.PI / 180f);
        TransformSelectedPositions(project, p => RotateAround(p, c, rad));
    }

    /// <summary>Uniform scale of selected segment vertices and pivots about the centroid of selected segment positions.</summary>
    public static void ScaleSelectionUniform(Project project, float uniformScale)
    {
        if (math.abs(uniformScale - 1f) < 1e-6f || !AnySegmentVertexSelected(project))
            return;

        project.Validate();
        var c = GetCentroidOfSelectedSegmentVertices(project);
        TransformSelectedPositions(project, p => c + (p - c) * uniformScale);
    }

    /// <summary>True if any segment vertex is selected (rotate/scale operate on segment selection).</summary>
    public static bool HasSelectedSegmentVertex(Project project)
    {
        foreach (var shape in project.shapes)
        foreach (var seg in shape.segments)
            if (seg.selected)
                return true;
        return false;
    }

    static bool AnySegmentVertexSelected(Project project) => HasSelectedSegmentVertex(project);

    /// <summary>Centroid of selected segment vertex positions (ignores pivot-only selection).</summary>
    public static float2 GetCentroidOfSelectedSegmentVertices(Project project)
    {
        float2 sum = default;
        var n = 0;
        foreach (var shape in project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;
                sum += seg.position;
                n++;
            }
        }

        return n > 0 ? sum / n : float2.zero;
    }

    /// <summary>Stores current positions into <see cref="Segment.gpVector1"/> / pivot <c>gpVector1</c> for selected segments (rotate-drag baseline).</summary>
    public static void CaptureRotateBaseline(Project project)
    {
        project.Validate();
        foreach (var shape in project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;

                seg.gpVector1 = seg.position;
                var g = seg.generator;
                switch (g.type)
                {
                    case SegmentGeneratorType.Bezier:
                        g.bezierPivot1.gpVector1 = g.bezierPivot1.position;
                        if (!g.bezierQuadratic)
                            g.bezierPivot2.gpVector1 = g.bezierPivot2.position;
                        break;
                    case SegmentGeneratorType.Sine:
                        g.sinePivot1.gpVector1 = g.sinePivot1.position;
                        break;
                }
            }
        }
    }

    /// <summary>Sets live positions from baseline rotated by <paramref name="degreesTotal"/> around <paramref name="pivot"/>.</summary>
    public static void ApplyRotateFromBaseline(Project project, float2 pivot, float degreesTotal)
    {
        project.Validate();
        foreach (var shape in project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;

                seg.position = MathEx.RotatePointAroundPivot(seg.gpVector1, pivot, degreesTotal);
                var g = seg.generator;
                switch (g.type)
                {
                    case SegmentGeneratorType.Bezier:
                        g.bezierPivot1.position = MathEx.RotatePointAroundPivot(g.bezierPivot1.gpVector1, pivot, degreesTotal);
                        if (!g.bezierQuadratic)
                            g.bezierPivot2.position = MathEx.RotatePointAroundPivot(g.bezierPivot2.gpVector1, pivot, degreesTotal);
                        break;
                    case SegmentGeneratorType.Sine:
                        g.sinePivot1.position = MathEx.RotatePointAroundPivot(g.sinePivot1.gpVector1, pivot, degreesTotal);
                        break;
                }
            }
        }

        project.Invalidate();
    }

    /// <summary>Angle in degrees from <paramref name="pivot"/> to <paramref name="target"/> in grid space (+X = 0°, CCW positive).</summary>
    public static float AngleFromPivotToPointDeg(float2 pivot, float2 target)
    {
        var d = target - pivot;
        return math.degrees(math.atan2(d.y, d.x));
    }

    /// <summary>Maps every <em>selected</em> segment vertex and that segment's generator pivots (matches 2D view rotate/scale).</summary>
    static void TransformSelectedPositions(Project project, Func<float2, float2> map)
    {
        foreach (var shape in project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (!seg.selected)
                    continue;

                seg.position = map(seg.position);
                var g = seg.generator;
                switch (g.type)
                {
                    case SegmentGeneratorType.Bezier:
                        g.bezierPivot1.position = map(g.bezierPivot1.position);
                        if (!g.bezierQuadratic)
                            g.bezierPivot2.position = map(g.bezierPivot2.position);
                        break;
                    case SegmentGeneratorType.Sine:
                        g.sinePivot1.position = map(g.sinePivot1.position);
                        break;
                }
            }
        }

        project.Invalidate();
    }

    static float2 RotateAround(float2 p, float2 center, float radians)
    {
        var q = p - center;
        var cos = math.cos(radians);
        var sin = math.sin(radians);
        return center + new float2(q.x * cos - q.y * sin, q.x * sin + q.y * cos);
    }
}
