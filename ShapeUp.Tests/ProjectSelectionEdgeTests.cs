using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class ProjectSelectionEdgeTests
{
    [Test]
    public void HasAnyFullySelectedEdge_false_when_only_one_vertex()
    {
        var p = new Project();
        p.Validate();
        p.shapes[0].segments[0].selected = true;
        Assert.That(p.HasAnyFullySelectedEdge(), Is.False);
    }

    [Test]
    public void HasAnyFullySelectedEdge_true_when_adjacent_pair_selected()
    {
        var p = new Project();
        p.Validate();
        var a = p.shapes[0].segments[0];
        var b = a.next;
        a.selected = true;
        b.selected = true;
        Assert.That(p.HasAnyFullySelectedEdge(), Is.True);
    }
}
