using System.Globalization;

namespace UnityEngine;

public struct Vector2 : IEquatable<Vector2>
{
    public float x, y;

    public Vector2(float x, float y)
    {
        this.x = x;
        this.y = y;
    }

    public static Vector2 zero => new(0, 0);
    public static Vector2 one => new(1, 1);

    public readonly float magnitude => MathF.Sqrt(x * x + y * y);

    public readonly Vector2 normalized => Normalize(this);

    public static Vector2 Normalize(Vector2 v)
    {
        var m = v.magnitude;
        if (m < 1e-8f) return zero;
        return new Vector2(v.x / m, v.y / m);
    }

    /// <summary>90° counter-clockwise (Unity-compatible).</summary>
    public static Vector2 Perpendicular(Vector2 v) => new(-v.y, v.x);

    public static Vector2 Lerp(Vector2 a, Vector2 b, float t) => new(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t);

    public static float Dot(Vector2 a, Vector2 b) => a.x * b.x + a.y * b.y;

    public readonly bool Equals(Vector2 other) => x.Equals(other.x) && y.Equals(other.y);

    public override readonly bool Equals(object? obj) => obj is Vector2 v && Equals(v);

    public override readonly int GetHashCode() => HashCode.Combine(x, y);

    public static bool operator ==(Vector2 a, Vector2 b) => a.Equals(b);

    public static bool operator !=(Vector2 a, Vector2 b) => !a.Equals(b);

    public static implicit operator Vector3(Vector2 v) => new(v.x, v.y, 0f);

    public static implicit operator Vector2(Vector3 v) => new(v.x, v.y);

    public override readonly string ToString() =>
        $"({x.ToString(CultureInfo.InvariantCulture)}, {y.ToString(CultureInfo.InvariantCulture)})";
}

public struct Vector3 : IEquatable<Vector3>
{
    public float x, y, z;

    public Vector3(float x, float y, float z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public Vector3(float x, float y) : this(x, y, 0f) { }

    public static Vector3 zero => new(0, 0, 0);
    public static Vector3 one => new(1, 1, 1);
    public static Vector3 up => new(0, 1, 0);
    public static Vector3 down => new(0, -1, 0);
    public static Vector3 right => new(1, 0, 0);
    public static Vector3 left => new(-1, 0, 0);
    public static Vector3 forward => new(0, 0, 1);
    public static Vector3 back => new(0, 0, -1);

    public static Vector3 Lerp(Vector3 a, Vector3 b, float t) => new(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t);

    public static float Dot(Vector3 a, Vector3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

    public static Vector3 Cross(Vector3 a, Vector3 b) => new(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x);

    public static Vector3 Normalize(Vector3 v)
    {
        var len = MathF.Sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
        if (len < 1e-8f) return zero;
        return new Vector3(v.x / len, v.y / len, v.z / len);
    }

    public readonly float magnitude => MathF.Sqrt(x * x + y * y + z * z);

    public readonly Vector3 normalized => Normalize(this);

    public static float Distance(Vector3 a, Vector3 b)
    {
        var dx = a.x - b.x;
        var dy = a.y - b.y;
        var dz = a.z - b.z;
        return MathF.Sqrt(dx * dx + dy * dy + dz * dz);
    }

    public static Vector3 Min(Vector3 a, Vector3 b) => new(MathF.Min(a.x, b.x), MathF.Min(a.y, b.y), MathF.Min(a.z, b.z));
    public static Vector3 Max(Vector3 a, Vector3 b) => new(MathF.Max(a.x, b.x), MathF.Max(a.y, b.y), MathF.Max(a.z, b.z));

    public static Vector3 operator +(Vector3 a, Vector3 b) => new(a.x + b.x, a.y + b.y, a.z + b.z);
    public static Vector3 operator -(Vector3 a, Vector3 b) => new(a.x - b.x, a.y - b.y, a.z - b.z);
    public static Vector3 operator -(Vector3 a) => new(-a.x, -a.y, -a.z);
    public static Vector3 operator *(Vector3 a, float s) => new(a.x * s, a.y * s, a.z * s);
    public static Vector3 operator *(float s, Vector3 a) => a * s;
    public static Vector3 operator /(Vector3 a, float s) => new(a.x / s, a.y / s, a.z / s);

    public readonly bool Equals(Vector3 other) => x.Equals(other.x) && y.Equals(other.y) && z.Equals(other.z);

    public override readonly bool Equals(object? obj) => obj is Vector3 v && Equals(v);

    public override readonly int GetHashCode() => HashCode.Combine(x, y, z);

    public static bool operator ==(Vector3 a, Vector3 b) => a.Equals(b);

    public static bool operator !=(Vector3 a, Vector3 b) => !a.Equals(b);
}

public struct Vector4 : IEquatable<Vector4>
{
    public float x, y, z, w;

    public Vector4(float x, float y, float z, float w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    public readonly bool Equals(Vector4 other) =>
        x.Equals(other.x) && y.Equals(other.y) && z.Equals(other.z) && w.Equals(other.w);

    public override readonly bool Equals(object? obj) => obj is Vector4 v && Equals(v);

    public override readonly int GetHashCode() => HashCode.Combine(x, y, z, w);

    public static bool operator ==(Vector4 a, Vector4 b) => a.Equals(b);
    public static bool operator !=(Vector4 a, Vector4 b) => !a.Equals(b);
}
