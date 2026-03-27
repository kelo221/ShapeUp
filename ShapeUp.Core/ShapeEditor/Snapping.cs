using System;

namespace ShapeUp.Core.ShapeEditor;

/// <summary>Grid snap (replaces UnityEditor.Snapping for standalone core).</summary>
internal static class Snapping
{
    public static float Snap(float value, float snap)
    {
        if (snap == 0f) return value;
        return MathF.Round(value / snap) * snap;
    }
}
