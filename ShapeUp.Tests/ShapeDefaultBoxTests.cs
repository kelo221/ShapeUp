using System;
using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class ShapeDefaultBoxTests
{
    [Test]
    public void DefaultBoxHalfExtent_aligns_to_snap()
    {
        Assert.That(Shape.DefaultBoxHalfExtent(0.125f), Is.EqualTo(1f).Within(1e-5f));
        Assert.That(Shape.DefaultBoxHalfExtent(0.1f), Is.EqualTo(1f).Within(1e-5f));
        Assert.That(Shape.DefaultBoxHalfExtent(1f), Is.EqualTo(1f).Within(1e-5f));
        Assert.That(Shape.DefaultBoxHalfExtent(0.25f), Is.EqualTo(1f).Within(1e-5f));
        Assert.That(Shape.DefaultBoxHalfExtent(0.15f), Is.EqualTo(1.05f).Within(1e-4f));
    }

    [Test]
    public void ResetToBoxSnapped_corners_on_grid()
    {
        var s = new Shape();
        s.segments.Clear();
        const float snap = 0.11f;
        s.ResetToBoxSnapped(snap);
        var h = Shape.DefaultBoxHalfExtent(snap);
        foreach (var seg in s.segments)
        {
            foreach (var c in new[] { seg.position.x, seg.position.y })
            {
                var k = Math.Round(c / snap);
                Assert.That(c, Is.EqualTo((float)(k * snap)).Within(1e-3f));
            }
        }

        Assert.That(Math.Abs(s.segments[0].position.x), Is.EqualTo(h).Within(1e-3f));
    }

    [Test]
    public void New_shape_default_is_2_world_units_128_quake_units_per_axis()
    {
        var s = new Shape();
        float minX = float.MaxValue, maxX = float.MinValue, minY = float.MaxValue, maxY = float.MinValue;
        foreach (var seg in s.segments)
        {
            minX = Math.Min(minX, seg.position.x);
            maxX = Math.Max(maxX, seg.position.x);
            minY = Math.Min(minY, seg.position.y);
            maxY = Math.Max(maxY, seg.position.y);
        }

        Assert.That(maxX - minX, Is.EqualTo(2f).Within(1e-5f));
        Assert.That(maxY - minY, Is.EqualTo(2f).Within(1e-5f));
        const int quakePerWorld = 64;
        Assert.That((int)Math.Round((maxX - minX) * quakePerWorld), Is.EqualTo(128));
        Assert.That((int)Math.Round((maxY - minY) * quakePerWorld), Is.EqualTo(128));
    }
}
