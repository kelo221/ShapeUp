using System;
using System.Collections.Generic;
using System.Linq;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;
using UnityEngine;

namespace ShapeUp.Features.Editor2D;

/// <summary>High-level project edits mirroring Unity ShapeEditorWindow user commands.</summary>
public static class EditorProjectCommands
{
    public static List<Shape> GetFullySelectedShapes(Project project)
    {
        project.Validate();
        return project.shapes.Where(s => s.IsSelected()).ToList();
    }

    public static List<float2> CollectSelectedPositions(Project project)
    {
        project.Validate();
        var points = new List<float2>();
        foreach (var shape in project.shapes)
        {
            foreach (var segment in shape.segments)
            {
                if (segment.selected)
                    points.Add(segment.position);
                foreach (var sel in segment.generator.ForEachSelectableObject())
                {
                    if (sel.selected)
                        points.Add(sel.position);
                }
            }
        }

        return points;
    }

    public static void ExtrudeSelectedLinearEdges(Project project, Action? beforeMutation)
    {
        project.Validate();
        var toExtrude = new List<Segment>();
        foreach (var shape in project.shapes)
        {
            foreach (var seg in shape.segments)
            {
                if (seg.selected && seg.next.selected && seg.generator.type == SegmentGeneratorType.Linear)
                    toExtrude.Add(seg);
            }
        }

        if (toExtrude.Count == 0)
            return;

        beforeMutation?.Invoke();
        project.ClearSelection();
        foreach (var segment in toExtrude)
            ExtrudeSegment(segment);
        project.Invalidate();
    }

    static void ExtrudeSegment(Segment segment)
    {
        var shape = segment.shape;
        var position1 = segment.position;
        var position2 = segment.next.position;

        var s1 = new Segment(shape, position1);
        s1.selected = true;
        shape.InsertSegmentBefore(segment.next, s1);

        var s2 = new Segment(shape, position2);
        s2.selected = true;
        shape.InsertSegmentBefore(segment.next.next, s2);
    }

    /// <summary>Builds a new shape from selected vertices/pivots (3+ points). Returns false if too few points.</summary>
    public static bool TryShapeFromSelection(Project project, Action? beforeMutation)
    {
        var points = CollectSelectedPositions(project);
        if (points.Count < 3)
            return false;

        beforeMutation?.Invoke();

        var shape = new Shape();
        shape.segments.Clear();

        if (points.Count == 3)
        {
            if (MathEx.IsCounterClockwise(points[0], points[1], points[2]) < 0f)
                points.Reverse();

            foreach (var point in points)
                shape.AddSegment(new Segment(shape, point));
        }
        else if (points.Count == 4)
        {
            var a = MathEx.LineIntersect2(
                new Vector2(points[0].x, points[0].y),
                new Vector2(points[1].x, points[1].y),
                new Vector2(points[2].x, points[2].y),
                new Vector2(points[3].x, points[3].y),
                out _);
            var b = MathEx.LineIntersect2(
                new Vector2(points[1].x, points[1].y),
                new Vector2(points[2].x, points[2].y),
                new Vector2(points[0].x, points[0].y),
                new Vector2(points[3].x, points[3].y),
                out _);
            if (a || b)
            {
                (points[2], points[3]) = (points[3], points[2]);
            }

            if (MathEx.IsCounterClockwise(points[0], points[1], points[2]) < 0f ||
                MathEx.IsCounterClockwise(points[1], points[2], points[3]) < 0f)
                points.Reverse();

            foreach (var point in points)
                shape.AddSegment(new Segment(shape, point));
        }
        else
        {
            foreach (var point in MathEx.GiftWrap.GetConvexHull(points))
                shape.AddSegment(new Segment(shape, point));
        }

        project.shapes.Add(shape);
        project.ClearSelection();
        shape.SelectAll();
        project.Invalidate();
        return true;
    }

    public static void DuplicateFullySelectedShapes(Project project, Action? beforeMutation)
    {
        var src = GetFullySelectedShapes(project);
        if (src.Count == 0)
            return;

        beforeMutation?.Invoke();
        project.ClearSelection();
        const float ox = 0.35f;
        const float oy = 0.35f;
        foreach (var shape in src)
        {
            var clone = shape.Clone();
            clone.Validate();
            foreach (var seg in clone.segments)
                seg.position += new float2(ox, oy);
            project.shapes.Add(clone);
            clone.SelectAll();
        }

        project.Invalidate();
    }

    public static void ApplySymmetryForSelectedShapes(Project project, Action? beforeMutation)
    {
        project.Validate();
        if (!project.shapes.Any(s => s.IsSelected()))
            return;

        beforeMutation?.Invoke();
        var shapesToSelect = new List<Shape>();
        for (var i = project.shapes.Count; i-- > 0;)
        {
            var shape = project.shapes[i];
            if (!shape.IsSelected())
                continue;

            var symmetryShapes = shape.GenerateSymmetryShapes();
            for (var j = 0; j < symmetryShapes.Length; j++)
            {
                var sym = symmetryShapes[j];
                sym.Validate();
                project.shapes.Insert(i + 1, sym);
                shapesToSelect.Add(sym);
            }

            shape.symmetryAxes = SimpleGlobalAxis.None;
        }

        if (shapesToSelect.Count == 0)
            return;

        project.ClearSelection();
        foreach (var s in shapesToSelect)
            s.SelectAll();
        project.Invalidate();
    }

    public static void PushFullySelectedShapes(Project project, bool toFront, Action? beforeMutation)
    {
        var move = GetFullySelectedShapes(project);
        if (move.Count == 0)
            return;

        beforeMutation?.Invoke();
        foreach (var shape in move)
            project.shapes.Remove(shape);

        if (toFront)
        {
            foreach (var shape in move)
                project.shapes.Add(shape);
        }
        else
        {
            for (var i = move.Count; i-- > 0;)
                project.shapes.Insert(0, move[i]);
        }

        project.Invalidate();
    }

    public static string SerializeShapesToClipboard(IEnumerable<Shape> shapes)
    {
        var data = new ClipboardData();
        foreach (var s in shapes)
            data.shapes.Add(s.Clone());
        return JsonUtility.ToJson(data);
    }

    public static bool TryPasteFromClipboardJson(Project project, string json, Action? beforeMutation)
    {
        if (string.IsNullOrWhiteSpace(json))
            return false;

        ClipboardData? clip = null;
        try
        {
            clip = JsonUtility.FromJson<ClipboardData>(json);
        }
        catch
        {
            return false;
        }

        if (clip?.shapes == null || clip.shapes.Count == 0)
            return false;

        beforeMutation?.Invoke();
        project.ClearSelection();
        foreach (var shape in clip.shapes)
        {
            shape.Validate();
            project.shapes.Add(shape);
            shape.SelectAll();
        }

        project.Invalidate();
        return true;
    }
}
