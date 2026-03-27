using System;
using System.Numerics;

namespace ShapeUp.Core.TrenchBroomClipboard;

/// <summary>
/// Valve 220 texture axis pairs per face normal, matching TrenchBroom's Z-up map axes (file X,Y,Z).
/// See sample cube export: outward normal selects <c>[ Uaxis ] [ Vaxis ]</c>; second axis often uses <c>-Z</c>.
/// </summary>
public static class TrenchBroomValve220FaceAxes
{
    public const string ScaleRotationTail = "0 0.25 0.25";

    /// <summary>Unity outward normal → map-file outward normal (same linear part as <see cref="TrenchBroomGrid.MapUnityWorldToQuakeFileCoords"/>).</summary>
    public static Vector3 UnityOutwardNormalToMap(Vector3 outwardUnity)
    {
        var n = Vector3.Normalize(outwardUnity);
        return Vector3.Normalize(new Vector3(n.X, n.Z, -n.Y));
    }

    /// <summary>TB-style suffix for axis-aligned faces; generic fallback otherwise.</summary>
    public static string FormatFaceSuffix(Vector3 outwardMapNormal)
    {
        var n = Vector3.Normalize(outwardMapNormal);
        var ax = MathF.Abs(n.X);
        var ay = MathF.Abs(n.Y);
        var az = MathF.Abs(n.Z);
        const float t = 0.98f;

        if (ax >= t && ax >= ay && ax >= az)
            return n.X < 0f ? MinMapX() : MaxMapX();
        if (ay >= t && ay >= ax && ay >= az)
            return n.Y < 0f ? MinMapY() : MaxMapY();
        if (az >= t && az >= ax && az >= ay)
            return n.Z < 0f ? MinMapZ() : MaxMapZ();

        return $"[ 1 0 0 0 ] [ 0 1 0 0 ] {ScaleRotationTail}";
    }

    // Outward -X (min X face)
    static string MinMapX() => $"[ 0 -1 0 0 ] [ 0 0 -1 0 ] {ScaleRotationTail}";

    // Outward +X
    static string MaxMapX() => $"[ 1 0 0 0 ] [ 0 -1 0 0 ] {ScaleRotationTail}";

    // Outward -Y (min Y)
    static string MinMapY() => $"[ 1 0 0 0 ] [ 0 0 -1 0 ] {ScaleRotationTail}";

    // Outward +Y
    static string MaxMapY() => $"[ -1 0 0 0 ] [ 0 0 -1 0 ] {ScaleRotationTail}";

    // Outward -Z (min Z)
    static string MinMapZ() => $"[ -1 0 0 0 ] [ 0 -1 0 0 ] {ScaleRotationTail}";

    // Outward +Z
    static string MaxMapZ() => $"[ 0 1 0 0 ] [ 0 0 -1 0 ] {ScaleRotationTail}";
}
