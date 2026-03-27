using System;
using System.Collections.Generic;
using System.Numerics;
using System.Text.RegularExpressions;
using NUnit.Framework;
using ShapeUp.Core.TrenchBroomClipboard;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class TrenchBroomClipboardBuilderTests
{
    private readonly record struct ParsedFace(Vector3 P1, Vector3 P2, Vector3 P3);

    private static readonly Regex FacePointRegex = new(@"\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    /// <summary>Axis-aligned unit cube [-0.5,0.5]^3 with Unity-style planes.</summary>
    private static List<UnityStylePlane> UnitCubePlanes()
    {
        return new List<UnityStylePlane>
        {
            new(new Vector3(1, 0, 0), -0.5f),
            new(new Vector3(-1, 0, 0), -0.5f),
            new(new Vector3(0, 1, 0), -0.5f),
            new(new Vector3(0, -1, 0), -0.5f),
            new(new Vector3(0, 0, 1), -0.5f),
            new(new Vector3(0, 0, -1), -0.5f),
        };
    }

    private static List<ParsedFace> ParseFacePoints(string text)
    {
        var faces = new List<ParsedFace>();
        foreach (var line in text.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            if (!line.Contains("__TB_empty", StringComparison.Ordinal))
                continue;

            var matches = FacePointRegex.Matches(line);
            Assert.That(matches.Count, Is.EqualTo(3), $"Expected 3 point triples in face line: {line}");

            static Vector3 ParsePoint(Match match) => new(
                float.Parse(match.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture),
                float.Parse(match.Groups[2].Value, System.Globalization.CultureInfo.InvariantCulture),
                float.Parse(match.Groups[3].Value, System.Globalization.CultureInfo.InvariantCulture));

            faces.Add(new ParsedFace(ParsePoint(matches[0]), ParsePoint(matches[1]), ParsePoint(matches[2])));
        }

        return faces;
    }

    private static Vector3 QuakeFaceNormal(ParsedFace face) =>
        Vector3.Cross(face.P3 - face.P1, face.P2 - face.P1);

    private static float CosineSimilarity(Vector3 a, Vector3 b)
    {
        var aa = Vector3.Normalize(a);
        var bb = Vector3.Normalize(b);
        return Vector3.Dot(aa, bb);
    }

    internal static void AssertPointInsideAllFaces(string text, Vector3 point, float epsilon = 1e-4f)
    {
        var faces = ParseFacePoints(text);
        Assert.That(faces, Is.Not.Empty, "Expected at least one exported face.");

        foreach (var face in faces)
        {
            var normal = QuakeFaceNormal(face);
            Assert.That(normal.LengthSquared(), Is.GreaterThan(epsilon), "Face points must define a non-degenerate plane.");

            var signedDistance = Vector3.Dot(point - face.P1, normal);
            Assert.That(signedDistance, Is.LessThanOrEqualTo(epsilon),
                $"Expected point {point} to be inside face half-space, got {signedDistance} for {face}.");
        }
    }

    [Test]
    public void SingleBrush_ContainsWorldspawnMapversionAndSixFaces()
    {
        var brushes = new List<IReadOnlyList<UnityStylePlane>> { UnitCubePlanes() };
        var text = TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(brushes, "TestGroup");

        Assert.That(text, Does.Contain("\"classname\" \"worldspawn\""));
        Assert.That(text, Does.Contain("\"mapversion\" \"220\""));
        Assert.That(text, Does.Contain("\"_tb_textures\""));
        Assert.That(text, Does.Contain("textures/Bricks"));
        Assert.That(text, Does.Not.Contain("\"classname\" \"func_group\""));
        Assert.That(text, Does.Contain("// brush 0"));
        var faceLines = 0;
        foreach (var line in text.Split('\n'))
        {
            if (line.Contains("__TB_empty", System.StringComparison.Ordinal))
                faceLines++;
        }
        Assert.That(faceLines, Is.EqualTo(6));
        Assert.That(text, Does.Contain(TrenchBroomValve220FaceAxes.ScaleRotationTail));
        foreach (var line in text.Split('\n'))
        {
            if (!line.Contains("__TB_empty", System.StringComparison.Ordinal))
                continue;
            Assert.That(line, Does.Contain(TrenchBroomValve220FaceAxes.ScaleRotationTail));
        }
    }

    [Test]
    public void UnitCube_FaceWindings_ContainBrushCenter()
    {
        var text = TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(
            new List<IReadOnlyList<UnityStylePlane>> { UnitCubePlanes() });

        AssertPointInsideAllFaces(text, Vector3.Zero);
    }

    [Test]
    public void GoldenSample_NormalNearlyVertical_UsesRightAsU()
    {
        // Plane with normal ~ up triggers Vector3.Right branch for u axis
        var planes = new List<UnityStylePlane>
        {
            new(new Vector3(0.01f, 1f, 0f), 0f),
            new(new Vector3(1, 0, 0), -1f),
            new(new Vector3(-1, 0, 0), -1f),
            new(new Vector3(0, 0, 1), -1f),
            new(new Vector3(0, 0, -1), -1f),
        };
        var text = TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(
            new List<IReadOnlyList<UnityStylePlane>> { planes });

        Assert.That(text, Does.Contain("__TB_empty"));
        Assert.That(text, Does.Contain("// brush 0"));
    }

    [Test]
    public void FuncGroup_legacy_mode_still_emits_tb_group_keys()
    {
        var brushes = new List<IReadOnlyList<UnityStylePlane>> { UnitCubePlanes() };
        var text = TrenchBroomClipboardBuilder.GenerateFuncGroupClipboardText(brushes, "G");
        Assert.That(text, Does.Contain("\"classname\" \"func_group\""));
        Assert.That(text, Does.Contain("\"_tb_name\" \"G\""));
        Assert.That(text, Does.Contain("// brush 0"));
    }

    [Test]
    public void Default_clipboard_is_single_entity_worldspawn_before_brush()
    {
        var text = TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(
            new List<IReadOnlyList<UnityStylePlane>> { UnitCubePlanes() });
        var mv = text.IndexOf("\"mapversion\"", System.StringComparison.Ordinal);
        var tb = text.IndexOf("\"_tb_textures\"", System.StringComparison.Ordinal);
        var w = text.IndexOf("\"classname\" \"worldspawn\"", System.StringComparison.Ordinal);
        var b = text.IndexOf("// brush 0", System.StringComparison.Ordinal);
        Assert.That(mv, Is.GreaterThanOrEqualTo(0));
        Assert.That(tb, Is.GreaterThan(mv));
        Assert.That(w, Is.GreaterThan(tb));
        Assert.That(b, Is.GreaterThan(w));
        Assert.That(text, Does.Not.Contain("// entity 1"));
    }

    [Test]
    public void SlantedFace_PreservesExportedPlaneNormal()
    {
        var planes = new List<UnityStylePlane>
        {
            new(Vector3.Normalize(new Vector3(-50f, 0f, -3f)), -1.25f),
        };
        var text = TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(
            new List<IReadOnlyList<UnityStylePlane>> { planes });
        var faces = ParseFacePoints(text);
        Assert.That(faces.Count, Is.EqualTo(1));
        var actual = QuakeFaceNormal(faces[0]);
        var expected = TrenchBroomValve220FaceAxes.UnityOutwardNormalToMap(planes[0].Normal);
        Assert.That(CosineSimilarity(actual, expected), Is.GreaterThan(0.999f),
            $"Expected exported face normal {actual} to match mapped normal {expected}.");
        Assert.That(text, Does.Contain("."), "Expected precise coordinates for slanted face export.");
    }
}
