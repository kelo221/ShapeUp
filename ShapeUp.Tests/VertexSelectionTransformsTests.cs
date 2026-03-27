using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class VertexSelectionTransformsTests
{
    [Test]
    public void TranslateSelection_moves_only_selected_vertices()
    {
        var project = new Project();
        var shape = project.shapes[0];
        shape.segments[0].selected = true;
        shape.segments[1].selected = false;

        var p0 = shape.segments[0].position;
        var p1 = shape.segments[1].position;

        VertexSelectionTransforms.TranslateSelection(project, new float2(0.25f, -0.5f));

        Assert.That(shape.segments[0].position.x, Is.EqualTo(p0.x + 0.25f).Within(1e-4));
        Assert.That(shape.segments[0].position.y, Is.EqualTo(p0.y - 0.5f).Within(1e-4));
        Assert.That(shape.segments[1].position.x, Is.EqualTo(p1.x).Within(1e-4));
        Assert.That(shape.segments[1].position.y, Is.EqualTo(p1.y).Within(1e-4));
    }

    [Test]
    public void TranslateSelection_moves_all_selected_vertices_together()
    {
        var project = new Project();
        var shape = project.shapes[0];
        foreach (var s in shape.segments)
            s.selected = true;

        var before = shape.segments.ConvertAll(s => s.position);

        VertexSelectionTransforms.TranslateSelection(project, new float2(1f, 2f));

        for (var i = 0; i < shape.segments.Count; i++)
        {
            Assert.That(shape.segments[i].position.x, Is.EqualTo(before[i].x + 1f).Within(1e-4));
            Assert.That(shape.segments[i].position.y, Is.EqualTo(before[i].y + 2f).Within(1e-4));
        }
    }

    [Test]
    public void TranslateSelection_moves_selected_bezier_pivot()
    {
        var project = new Project();
        var shape = project.shapes[0];
        var seg = shape.segments[0];
        seg.generator = new SegmentGenerator(seg, SegmentGeneratorType.Bezier);
        seg.generator.bezierPivot1.selected = true;
        var pivotPos = seg.generator.bezierPivot1.position;

        VertexSelectionTransforms.TranslateSelection(project, new float2(0.1f, 0.2f));

        Assert.That(seg.generator.bezierPivot1.position.x, Is.EqualTo(pivotPos.x + 0.1f).Within(1e-4));
        Assert.That(seg.generator.bezierPivot1.position.y, Is.EqualTo(pivotPos.y + 0.2f).Within(1e-4));
    }

    [Test]
    public void TranslateSelection_zero_delta_is_noop()
    {
        var project = new Project();
        project.Invalidate();
        var shape = project.shapes[0];
        var p0 = shape.segments[0].position;

        VertexSelectionTransforms.TranslateSelection(project, default);

        Assert.That(shape.segments[0].position.x, Is.EqualTo(p0.x).Within(1e-6));
        Assert.That(shape.segments[0].position.y, Is.EqualTo(p0.y).Within(1e-6));
    }

    [Test]
    public void Translate_then_validate_restores_generator_segment_refs()
    {
        var project = new Project();
        project.Validate();
        var seg = project.shapes[0].segments[0];
        seg.selected = true;

        VertexSelectionTransforms.TranslateSelection(project, new float2(0.125f, 0f));

        project.Validate();
        Assert.That(seg.generator.segment, Is.SameAs(seg));
        Assert.That(seg.shape, Is.SameAs(project.shapes[0]));
    }

    [Test]
    public void TranslateSelection_applies_across_multiple_shapes()
    {
        var project = new Project();
        project.shapes.Add(new Shape());
        project.Validate();

        project.shapes[0].segments[0].selected = true;
        project.shapes[1].segments[2].selected = true;

        var a = project.shapes[0].segments[0].position;
        var b = project.shapes[1].segments[2].position;

        VertexSelectionTransforms.TranslateSelection(project, new float2(-1f, 0.5f));

        Assert.That(project.shapes[0].segments[0].position.x, Is.EqualTo(a.x - 1f).Within(1e-4));
        Assert.That(project.shapes[1].segments[2].position.y, Is.EqualTo(b.y + 0.5f).Within(1e-4));
    }
}
