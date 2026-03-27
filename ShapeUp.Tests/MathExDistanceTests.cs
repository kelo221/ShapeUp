using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;
using Unity.Mathematics;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class MathExDistanceTests
{
    [Test]
    public void DistanceToSegment_OnSegment_IsZero()
    {
        var d = MathEx.DistanceToSegment(new float2(0.5f, 0f), float2.zero, new float2(1f, 0f));
        Assert.That(d, Is.LessThan(1e-5f));
    }

    [Test]
    public void DistanceToSegment_OffSegment_IsPerpendicularDistance()
    {
        var d = MathEx.DistanceToSegment(new float2(0.5f, 1f), float2.zero, new float2(1f, 0f));
        Assert.That(d, Is.EqualTo(1f).Within(1e-4f));
    }
}
