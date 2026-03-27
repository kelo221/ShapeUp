using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;
using UnityEngine;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class ProjectJsonRoundtripTests
{
    [Test]
    public void Project_Clone_preserves_segment_positions_after_validate()
    {
        var project = new Project();
        project.shapes[0].segments[0].position = new float2(1.25f, -0.5f);
        project.Validate();

        var copy = project.Clone();
        copy.Validate();

        Assert.That(copy.shapes[0].segments[0].position.x, Is.EqualTo(1.25f).Within(1e-4));
        Assert.That(copy.shapes[0].segments[0].position.y, Is.EqualTo(-0.5f).Within(1e-4));
        Assert.That(copy.shapes[0].segments[0].generator.segment, Is.SameAs(copy.shapes[0].segments[0]));
    }

    [Test]
    public void JsonUtility_FromJson_ToJson_roundtrip_matches_clone()
    {
        var project = new Project();
        project.Validate();
        var json = JsonUtility.ToJson(project);
        var restored = JsonUtility.FromJson<Project>(json);
        restored.Validate();

        Assert.That(restored.shapes.Count, Is.EqualTo(project.shapes.Count));
        Assert.That(restored.shapes[0].segments.Count, Is.EqualTo(project.shapes[0].segments.Count));
        for (var i = 0; i < project.shapes[0].segments.Count; i++)
        {
            Assert.That(restored.shapes[0].segments[i].position.x,
                Is.EqualTo(project.shapes[0].segments[i].position.x).Within(1e-4));
            Assert.That(restored.shapes[0].segments[i].position.y,
                Is.EqualTo(project.shapes[0].segments[i].position.y).Within(1e-4));
        }
    }
}
