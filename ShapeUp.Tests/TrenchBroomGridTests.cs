using System;
using NUnit.Framework;
using ShapeUp.Core.ShapeEditor;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class TrenchBroomGridTests
{
    static bool IsPowerOfTwo(int n) => n > 0 && (n & (n - 1)) == 0;

    [Test]
    public void Mod_handles_negative_coordinates()
    {
        Assert.That(TrenchBroomGrid.Mod(0, 64), Is.EqualTo(0));
        Assert.That(TrenchBroomGrid.Mod(-64, 64), Is.EqualTo(0));
        Assert.That(TrenchBroomGrid.Mod(-65, 64), Is.EqualTo(63));
        Assert.That(TrenchBroomGrid.Mod(65, 64), Is.EqualTo(1));
    }

    [Test]
    public void SmallestPowerOfTwoQuakeStepAtLeast_matches_tb_steps()
    {
        Assert.That(TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast(1f / 64f), Is.EqualTo(1f / 64f).Within(1e-6f));
        Assert.That(TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast(0.125f), Is.EqualTo(0.125f).Within(1e-6f));
        Assert.That(TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast(0.11f), Is.EqualTo(0.125f).Within(1e-6f));
        Assert.That(TrenchBroomGrid.SmallestPowerOfTwoQuakeStepAtLeast(1f), Is.EqualTo(1f).Within(1e-6f));
    }

    [Test]
    public void PickViewportGridStepWorld_coarsens_when_zoom_is_low()
    {
        Assert.That(TrenchBroomGrid.PickViewportGridStepWorld(0.125f, 120f, 10f), Is.EqualTo(0.125f).Within(1e-6f));
        var coarse = TrenchBroomGrid.PickViewportGridStepWorld(0.125f, 8f, 10f);
        Assert.That(coarse, Is.GreaterThan(0.125f));
        var q = (int)Math.Round(coarse * TrenchBroomGrid.QuakeUnitsPerWorld);
        Assert.That(IsPowerOfTwo(q), Is.True);
    }

    [Test]
    public void WorldToQuake_rounds_like_clipboard()
    {
        Assert.That(TrenchBroomGrid.WorldToQuake(1f), Is.EqualTo(64));
        Assert.That(TrenchBroomGrid.WorldToQuake(-1f), Is.EqualTo(-64));
    }

    [Test]
    public void FormatMapFilePoint_maps_unity_xy_profile_and_negates_y_for_tb_z()
    {
        Assert.That(TrenchBroomGrid.FormatMapFilePoint(new System.Numerics.Vector3(1f, 2f, 3f)), Is.EqualTo("64 192 -128"));
    }

    [Test]
    public void RotateSnapStepDegreesFromSnapWorld_follows_power_of_two_ladder()
    {
        Assert.That(TrenchBroomGrid.RotateSnapStepDegreesFromSnapWorld(1f), Is.EqualTo(180f).Within(1e-4f));
        Assert.That(TrenchBroomGrid.RotateSnapStepDegreesFromSnapWorld(0.5f), Is.EqualTo(90f).Within(1e-4f));
        Assert.That(TrenchBroomGrid.RotateSnapStepDegreesFromSnapWorld(0.25f), Is.EqualTo(45f).Within(1e-4f));
        Assert.That(TrenchBroomGrid.RotateSnapStepDegreesFromSnapWorld(0.125f), Is.EqualTo(22.5f).Within(1e-4f));
        Assert.That(TrenchBroomGrid.RotateSnapStepDegreesFromSnapWorld(1f / 64f), Is.EqualTo(360f / 128f).Within(1e-4f));
    }

    [Test]
    public void SnapAngleDegrees_rounds_to_step()
    {
        Assert.That(TrenchBroomGrid.SnapAngleDegrees(23f, 22.5f), Is.EqualTo(22.5f).Within(1e-4f));
        Assert.That(TrenchBroomGrid.SnapAngleDegrees(10f, 0f), Is.EqualTo(10f).Within(1e-4f));
    }

    [Test]
    public void NextFinerSnapWorld_and_NextCoarserSnapWorld_step_power_of_two_ladder()
    {
        Assert.That(TrenchBroomGrid.NextFinerSnapWorld(0.125f), Is.EqualTo(0.0625f).Within(1e-6f));
        Assert.That(TrenchBroomGrid.NextCoarserSnapWorld(0.125f), Is.EqualTo(0.25f).Within(1e-6f));
        Assert.That(TrenchBroomGrid.NextFinerSnapWorld(TrenchBroomGrid.MinSnapWorld), Is.EqualTo(TrenchBroomGrid.MinSnapWorld).Within(1e-6f));
        Assert.That(TrenchBroomGrid.NextCoarserSnapWorld(TrenchBroomGrid.MaxSnapWorld), Is.EqualTo(TrenchBroomGrid.MaxSnapWorld).Within(1e-6f));
    }
}
