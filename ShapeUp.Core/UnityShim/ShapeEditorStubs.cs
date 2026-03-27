using Unity.Mathematics;
using UnityEngine;

namespace ShapeUp.Core.ShapeEditor;

/// <summary>Editor stub: drawing uses no-op GL; GridPointToScreen is identity for headless/core use.</summary>
public partial class ShapeEditorWindow
{
    public const float halfPivotScale = 0.05f;
    public const float pivotScale = 0.1f;

    public int selectedSegmentsCount { get; set; }
    public float2 selectedSegmentsAveragePosition { get; set; }

    public static Color segmentColor = new(1f, 1f, 1f, 1f);
    public static Color segmentColorDifference = new(1f, 0f, 0f, 1f);
    public static Color segmentPivotOutlineColor = new(0f, 0f, 0f, 1f);
    public static Color segmentPivotSelectedColor = new(1f, 1f, 0f, 1f);

    public Vector2 GridPointToScreen(float2 p) => new(p.x, p.y);
}

public static class GLUtilities
{
    public static void DrawLine(float thickness, float x1, float y1, float x2, float y2) { }

    public static void DrawLine(float thickness, float x1, float y1, float x2, float y2, Color a, Color b) { }

    public static void DrawLine(float thickness, Vector2 from, Vector2 to) { }

    public static void DrawBezierLine(float thickness, Vector2 start, Vector2 p1, Vector2 p2, Vector2 end, int detail) { }

    public static void DrawDottedLine(float thickness, Vector2 from, Vector2 to, float screenSpaceSize = 4f) { }

    public static void DrawLineArrow(float thickness, Vector2 from, Vector2 to, float arrowHeadLength = 16f, float arrowHeadAngle = 20f) { }

    public static void DrawSolidRectangleWithOutline(float x, float y, float w, float h, Color fill, Color outline) { }
}
