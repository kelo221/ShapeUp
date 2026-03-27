using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;
using ShapeUp.Core.TrenchBroomClipboard;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class ShapeExtrusionTargetTests
{
    [Test]
    public void FixedExtrude_DefaultBox_ProducesTrenchBroomClipboard()
    {
        var ex = new ShapeExtrusionTarget
        {
            targetMode = ShapeEditorTargetMode.FixedExtrude,
            fixedExtrudeDistance = 0.25f,
        };
        ex.SetProject(new Project());

        Assert.That(ex.BuildPreviewMesh(), Is.Not.Null);
        var clip = ex.BuildTrenchBroomClipboard("Test");
        Assert.That(clip, Is.Not.Null.And.Not.Empty);
        Assert.That(clip, Does.Contain("\"classname\" \"worldspawn\""));
        Assert.That(clip, Does.Contain("\"mapversion\" \"220\""));
        Assert.That(clip, Does.Contain("\"_tb_textures\""));
        Assert.That(clip, Does.Contain("// brush"));
        var faceLines = 0;
        foreach (var line in clip!.Split('\n'))
        {
            if (line.Contains("__TB_empty", System.StringComparison.Ordinal))
                faceLines++;
        }
        Assert.That(faceLines, Is.EqualTo(6));
        TrenchBroomClipboardBuilderTests.AssertPointInsideAllFaces(clip, System.Numerics.Vector3.Zero);
    }

    [Test]
    public void ScaledExtrude_DefaultBox_ProducesMultipleBrushesInClipboard()
    {
        var ex = new ShapeExtrusionTarget
        {
            targetMode = ShapeEditorTargetMode.ScaledExtrude,
            scaledExtrudeDistance = 1f,
        };
        ex.SetProject(new Project());

        Assert.That(ex.TryGetPolygonMeshes(out var meshes), Is.True);
        Assert.That(meshes, Is.Not.Null.And.Not.Empty);
        var clip = PolygonMeshTrenchBroomExport.BuildClipboard(meshes!, "Scaled");
        Assert.That(clip, Does.Contain("// brush"));
    }

    [Test]
    public void Standalone_map_matches_worldspawn_nested_clipboard_shape()
    {
        var ex = new ShapeExtrusionTarget
        {
            targetMode = ShapeEditorTargetMode.FixedExtrude,
            fixedExtrudeDistance = 0.25f,
        };
        ex.SetProject(new Project());

        var map = ex.BuildTrenchBroomStandaloneMap("G");
        Assert.That(map, Is.Not.Null);
        Assert.That(map, Does.Contain("\"classname\" \"worldspawn\""));
        Assert.That(map, Does.Contain("\"_tb_textures\""));
        Assert.That(map, Does.Not.Contain("\"classname\" \"func_group\""));
        Assert.That(map, Does.Not.Contain("// entity 1"));
    }
}
