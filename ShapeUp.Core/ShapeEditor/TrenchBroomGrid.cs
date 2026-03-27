using System;
using System.Numerics;

namespace ShapeUp.Core.ShapeEditor;

/// <summary>
/// TrenchBroom uses integer Quake map units; ShapeUp world coordinates map as <c>quake = round(world * 64)</c>
/// (see <see cref="TrenchBroomClipboard.TrenchBroomClipboardBuilder"/>). Grid steps are powers of two in Quake space.
/// </summary>
public static class TrenchBroomGrid
{
    public const float QuakeUnitsPerWorld = 64f;

    /// <summary>Minimum snap/grid step in world units (1 Quake unit). Matches editor snap UI min.</summary>
    public const float MinSnapWorld = 1f / QuakeUnitsPerWorld;

    /// <summary>Maximum snap/grid step in world units. Matches editor snap UI max.</summary>
    public const float MaxSnapWorld = 4f;

    /// <summary>Non-negative remainder (works for negative coordinates).</summary>
    public static int Mod(int a, int m)
    {
        if (m <= 0)
            return 0;
        var r = a % m;
        return r < 0 ? r + m : r;
    }

    /// <summary>Smallest world step of the form <c>2^n / 64</c> that is ≥ <paramref name="minWorld"/>.</summary>
    public static float SmallestPowerOfTwoQuakeStepAtLeast(float minWorld)
    {
        if (minWorld <= 1e-8f)
            return 1f / QuakeUnitsPerWorld;
        var need = Math.Max(1, (int)Math.Ceiling(minWorld * QuakeUnitsPerWorld - 1e-6));
        var p = 1;
        while (p < need)
            p <<= 1;
        return p / QuakeUnitsPerWorld;
    }

    /// <summary>
    /// Viewport grid step: power-of-two in Quake, at least snap-sized, coarsened until lines are spaced by at least <paramref name="minLineSpacingPx"/>.
    /// </summary>
    public static float PickViewportGridStepWorld(float snapWorld, float zoomPixelsPerUnit, float minLineSpacingPx = 10f)
    {
        var s = SmallestPowerOfTwoQuakeStepAtLeast(snapWorld);
        while (s * zoomPixelsPerUnit < minLineSpacingPx && s < 1e6f)
            s *= 2f;
        return s;
    }

    /// <summary>
    /// Rotation snap step in degrees from the same power-of-two Quake ladder as <see cref="SmallestPowerOfTwoQuakeStepAtLeast"/>.
    /// Coarser snap (e.g. 1 world) → 180°; 0.125 → 22.5°; finer → 11.25°, 5.625°, … down to 360/256°.
    /// </summary>
    public static float RotateSnapStepDegreesFromSnapWorld(float snapWorldMin)
    {
        var minW = snapWorldMin <= 1e-8f ? 1f / QuakeUnitsPerWorld : snapWorldMin;
        var stepWorld = SmallestPowerOfTwoQuakeStepAtLeast(minW);
        var stepQuake = Math.Max(1, (int)Math.Round(stepWorld * QuakeUnitsPerWorld));
        var exp = BitOperations.Log2((uint)stepQuake);
        var pow = Math.Clamp(7 - exp, 1, 8);
        return 360f / (1 << pow);
    }

    /// <summary>Rounds <paramref name="degrees"/> to the nearest multiple of <paramref name="stepDegrees"/> (no-op if step ≤ 0).</summary>
    public static float SnapAngleDegrees(float degrees, float stepDegrees)
    {
        if (stepDegrees <= 1e-8f)
            return degrees;
        return MathF.Round(degrees / stepDegrees) * stepDegrees;
    }

    /// <summary>Next finer power-of-two step on the TB ladder (halve), clamped to <see cref="MinSnapWorld"/>.</summary>
    public static float NextFinerSnapWorld(float snapWorld)
    {
        var q = SmallestPowerOfTwoQuakeStepAtLeast(snapWorld);
        var finer = q * 0.5f;
        return finer < MinSnapWorld - 1e-9f ? MinSnapWorld : finer;
    }

    /// <summary>Next coarser power-of-two step (double), clamped to <see cref="MaxSnapWorld"/>.</summary>
    public static float NextCoarserSnapWorld(float snapWorld)
    {
        var q = SmallestPowerOfTwoQuakeStepAtLeast(snapWorld);
        var coarse = q * 2f;
        return coarse > MaxSnapWorld + 1e-9f ? MaxSnapWorld : coarse;
    }

    /// <summary>Rounds world to nearest Quake integer (TB paste grid).</summary>
    public static int WorldToQuake(float world) =>
        (int)Math.Round(world * QuakeUnitsPerWorld);

    /// <summary>
    /// Unity/shape space: XY = 2D profile, +Z = extrusion. TrenchBroom map points are (X,Y,Z) with Z-up and XY as the top view plane.
    /// Uses (X,Y,Z) = (Unity X, Unity Z, -Unity Y) in Quake units so orientation matches the 2D editor and preserves handedness
    /// (a plain X↔Z swap with Y would mirror the brush).
    /// </summary>
    public static void MapUnityWorldToQuakeFileCoords(Vector3 unityWorld, out int fileX, out int fileY, out int fileZ)
    {
        var s = QuakeUnitsPerWorld;
        fileX = (int)MathF.Round(unityWorld.X * s);
        fileY = (int)MathF.Round(unityWorld.Z * s);
        fileZ = -(int)MathF.Round(unityWorld.Y * s);
    }

    static float UnityWorldToQuakeFileFloatX(Vector3 unityWorld) => unityWorld.X * QuakeUnitsPerWorld;
    static float UnityWorldToQuakeFileFloatY(Vector3 unityWorld) => unityWorld.Z * QuakeUnitsPerWorld;
    static float UnityWorldToQuakeFileFloatZ(Vector3 unityWorld) => -unityWorld.Y * QuakeUnitsPerWorld;

    static string FormatMapNumber(float value)
    {
        var text = value.ToString("0.######", System.Globalization.CultureInfo.InvariantCulture)
            .TrimEnd('0')
            .TrimEnd('.');
        return string.IsNullOrEmpty(text) || text == "-" ? "0" : text;
    }

    /// <summary>Space-separated map file coordinates for one brush plane point.</summary>
    public static string FormatMapFilePoint(Vector3 unityWorld)
    {
        MapUnityWorldToQuakeFileCoords(unityWorld, out var fx, out var fy, out var fz);
        return $"{fx} {fy} {fz}";
    }

    /// <summary>
    /// Space-separated map file coordinates without integer snapping. Required for slanted planes
    /// so the emitted point triples still reconstruct the original plane after text export.
    /// </summary>
    public static string FormatMapFilePointPrecise(Vector3 unityWorld)
    {
        var fx = UnityWorldToQuakeFileFloatX(unityWorld);
        var fy = UnityWorldToQuakeFileFloatY(unityWorld);
        var fz = UnityWorldToQuakeFileFloatZ(unityWorld);
        return $"{FormatMapNumber(fx)} {FormatMapNumber(fy)} {FormatMapNumber(fz)}";
    }
}
