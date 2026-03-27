namespace UnityEngine;

public static class Mathf
{
    public const float PI = MathF.PI;
    public const float Deg2Rad = MathF.PI / 180f;
    public const float Rad2Deg = 180f / MathF.PI;

    public static float Abs(float v) => MathF.Abs(v);
    public static float Min(float a, float b) => MathF.Min(a, b);
    public static float Max(float a, float b) => MathF.Max(a, b);
    public static int Max(int a, int b) => a > b ? a : b;

    public static float InverseLerp(float a, float b, float value)
    {
        if (MathF.Abs(b - a) < 1e-8f) return 0f;
        return Clamp01((value - a) / (b - a));
    }
    public static float Clamp01(float v) => v < 0f ? 0f : v > 1f ? 1f : v;
    public static float Clamp(float v, float a, float b) => v < a ? a : v > b ? b : v;
    public static float Sign(float v) => v >= 0f ? 1f : -1f;
    public static float Lerp(float a, float b, float t) => a + (b - a) * t;
    public static float Sin(float v) => MathF.Sin(v);
    public static float Cos(float v) => MathF.Cos(v);
    public static float Sqrt(float v) => MathF.Sqrt(v);
    public static float Pow(float a, float b) => MathF.Pow(a, b);
    public static float Repeat(float t, float length) => t - MathF.Floor(t / length) * length;

    /// <summary>Shortest difference from <paramref name="current"/> to <paramref name="target"/> in degrees (−180, 180].</summary>
    public static float DeltaAngle(float current, float target)
    {
        var d = Repeat(target - current, 360f);
        if (d > 180f)
            d -= 360f;
        return d;
    }
}
