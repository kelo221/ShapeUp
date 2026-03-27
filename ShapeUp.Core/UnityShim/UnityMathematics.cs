using UnityEngine;

namespace Unity.Mathematics;

public struct float2 : IEquatable<float2>
{
    public float x, y;

    public float2(float x, float y)
    {
        this.x = x;
        this.y = y;
    }

    public float2(float v)
        : this(v, v)
    {
    }

    public static float2 zero => new(0f, 0f);

    public readonly bool Equals(float2 other) => x.Equals(other.x) && y.Equals(other.y);
    public override readonly bool Equals(object? obj) => obj is float2 f && Equals(f);
    public override readonly int GetHashCode() => HashCode.Combine(x, y);

    public static float2 operator *(float2 a, float2 b) => new(a.x * b.x, a.y * b.y);
    public static float2 operator +(float2 a, float2 b) => new(a.x + b.x, a.y + b.y);
    public static float2 operator -(float2 a, float2 b) => new(a.x - b.x, a.y - b.y);
    public static float2 operator -(float2 a) => new(-a.x, -a.y);
    public static float2 operator *(float2 a, float s) => new(a.x * s, a.y * s);
    public static float2 operator *(float s, float2 a) => a * s;
    public static float2 operator /(float2 a, float s) => new(a.x / s, a.y / s);

    public static implicit operator Vector2(float2 f) => new(f.x, f.y);
    public static implicit operator float2(Vector2 v) => new(v.x, v.y);
}

public struct float3 : IEquatable<float3>
{
    public float x, y, z;

    public float3(float x, float y, float z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public readonly bool Equals(float3 other) => x.Equals(other.x) && y.Equals(other.y) && z.Equals(other.z);
    public override readonly bool Equals(object? obj) => obj is float3 f && Equals(f);
    public override readonly int GetHashCode() => HashCode.Combine(x, y, z);

    public static float3 operator +(float3 a, float3 b) => new(a.x + b.x, a.y + b.y, a.z + b.z);
    public static float3 operator -(float3 a, float3 b) => new(a.x - b.x, a.y - b.y, a.z - b.z);
    public static float3 operator *(float3 a, float s) => new(a.x * s, a.y * s, a.z * s);
}

public static class math
{
    public static float abs(float v) => MathF.Abs(v);
    public static float min(float a, float b) => MathF.Min(a, b);
    public static float max(float a, float b) => MathF.Max(a, b);
    public static float cos(float v) => MathF.Cos(v);
    public static float sin(float v) => MathF.Sin(v);
    public static float atan2(float y, float x) => MathF.Atan2(y, x);
    public static float degrees(float radians) => radians * (180f / MathF.PI);
    public static float radians(float degrees) => degrees * (MathF.PI / 180f);
    public static float distance(float2 a, float2 b)
    {
        var dx = a.x - b.x;
        var dy = a.y - b.y;
        return MathF.Sqrt(dx * dx + dy * dy);
    }

    public static float2 normalize(float2 v)
    {
        var len = MathF.Sqrt(v.x * v.x + v.y * v.y);
        if (len < 1e-8f) return default;
        return new float2(v.x / len, v.y / len);
    }

    public static float lengthsq(float2 v) => v.x * v.x + v.y * v.y;
    public static float lengthsq(float3 v) => v.x * v.x + v.y * v.y + v.z * v.z;

    public static float length(float2 v) => MathF.Sqrt(lengthsq(v));

    public static float2 lerp(float2 a, float2 b, float t) => a + (b - a) * t;
}
