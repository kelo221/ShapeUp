using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class VertexSelectionRotateScaleTests
{
    [Test]
    public void RotateSelectionDegrees_90_leaves_centroid_fixed()
    {
        var project = new Project();
        var shape = project.shapes[0];
        foreach (var s in shape.segments)
            s.selected = true;

        var cBefore = Centroid(project);
        VertexSelectionTransforms.RotateSelectionDegrees(project, 90f);
        var cAfter = Centroid(project);

        Assert.That(cAfter.x, Is.EqualTo(cBefore.x).Within(1e-4));
        Assert.That(cAfter.y, Is.EqualTo(cBefore.y).Within(1e-4));
    }

    [Test]
    public void RotateSelectionDegrees_90_rotates_corner_on_unit_square()
    {
        var project = new Project();
        project.Validate();
        var shape = project.shapes[0];
        foreach (var s in shape.segments)
            s.selected = true;

        var corner = shape.segments[1]; // was (1, -1); centroid (0,0); +90° → (1, 1)

        VertexSelectionTransforms.RotateSelectionDegrees(project, 90f);

        Assert.That(corner.position.x, Is.EqualTo(1f).Within(1e-3));
        Assert.That(corner.position.y, Is.EqualTo(1f).Within(1e-3));
    }

    [Test]
    public void ScaleSelectionUniform_doubles_offset_from_centroid()
    {
        var project = new Project();
        var shape = project.shapes[0];
        foreach (var s in shape.segments)
            s.selected = true;

        var c = Centroid(project);
        var before = shape.segments.ConvertAll(s => s.position);
        VertexSelectionTransforms.ScaleSelectionUniform(project, 2f);

        for (var i = 0; i < shape.segments.Count; i++)
        {
            var expected = c + (before[i] - c) * 2f;
            Assert.That(shape.segments[i].position.x, Is.EqualTo(expected.x).Within(1e-4));
            Assert.That(shape.segments[i].position.y, Is.EqualTo(expected.y).Within(1e-4));
        }
    }

    [Test]
    public void RotateSelectionDegrees_zero_is_noop()
    {
        var project = new Project();
        var shape = project.shapes[0];
        shape.segments[0].selected = true;
        var p = shape.segments[0].position;

        VertexSelectionTransforms.RotateSelectionDegrees(project, 0f);

        Assert.That(shape.segments[0].position.x, Is.EqualTo(p.x).Within(1e-6));
        Assert.That(shape.segments[0].position.y, Is.EqualTo(p.y).Within(1e-6));
    }

    [Test]
    public void HasSelectedSegmentVertex_false_when_none_selected()
    {
        var project = new Project();
        foreach (var s in project.shapes[0].segments)
            s.selected = false;

        Assert.That(VertexSelectionTransforms.HasSelectedSegmentVertex(project), Is.False);
    }

    static float2 Centroid(Project project)
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

        return sum / math.max(1, n);
    }
}
