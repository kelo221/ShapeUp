namespace UnityEngine;

public struct Plane
{
    public Vector3 normal;
    public float distance;

    public Plane(Vector3 inNormal, float inDistance)
    {
        normal = Vector3.Normalize(inNormal);
        distance = inDistance;
    }

    /// <summary>Constructs plane through three points (Unity-compatible).</summary>
    public Plane(Vector3 a, Vector3 b, Vector3 c)
    {
        var ba = b - a;
        var ca = c - a;
        var n = Vector3.Cross(ba, ca);
        normal = Vector3.Normalize(n);
        distance = -Vector3.Dot(normal, a);
    }

    public readonly Plane flipped => new(new Vector3(-normal.x, -normal.y, -normal.z), -distance);

    public readonly float GetDistanceToPoint(Vector3 p) => Vector3.Dot(normal, p) + distance;
}

public struct Quaternion
{
    public float x, y, z, w;

    public Quaternion(float x, float y, float z, float w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    public static Quaternion Euler(Vector3 eulerDeg)
    {
        var cx = MathF.Cos(eulerDeg.x * Mathf.Deg2Rad * 0.5f);
        var sx = MathF.Sin(eulerDeg.x * Mathf.Deg2Rad * 0.5f);
        var cy = MathF.Cos(eulerDeg.y * Mathf.Deg2Rad * 0.5f);
        var sy = MathF.Sin(eulerDeg.y * Mathf.Deg2Rad * 0.5f);
        var cz = MathF.Cos(eulerDeg.z * Mathf.Deg2Rad * 0.5f);
        var sz = MathF.Sin(eulerDeg.z * Mathf.Deg2Rad * 0.5f);
        return new Quaternion(
            sx * cy * cz - cx * sy * sz,
            cx * sy * cz + sx * cy * sz,
            cx * cy * sz - sx * sy * cz,
            cx * cy * cz + sx * sy * sz);
    }

    public static Quaternion LookRotation(Vector3 forward) => LookRotation(forward, Vector3.up);

    public static Quaternion LookRotation(Vector3 forward, Vector3 upwards)
    {
        var f = Vector3.Normalize(forward);
        var u = Vector3.Normalize(upwards);
        var r = Vector3.Normalize(Vector3.Cross(u, f));
        u = Vector3.Cross(f, r);

        var m00 = r.x; var m01 = r.y; var m02 = r.z;
        var m10 = u.x; var m11 = u.y; var m12 = u.z;
        var m20 = f.x; var m21 = f.y; var m22 = f.z;

        var trace = m00 + m11 + m22;
        if (trace > 0f)
        {
            var s = 0.5f / MathF.Sqrt(trace + 1f);
            return new Quaternion(
                (m12 - m21) * s,
                (m20 - m02) * s,
                (m01 - m10) * s,
                0.25f / s);
        }

        if (m00 > m11 && m00 > m22)
        {
            var s = 2f * MathF.Sqrt(1f + m00 - m11 - m22);
            return new Quaternion(
                0.25f * s,
                (m01 + m10) / s,
                (m20 + m02) / s,
                (m12 - m21) / s);
        }

        if (m11 > m22)
        {
            var s = 2f * MathF.Sqrt(1f + m11 - m00 - m22);
            return new Quaternion(
                (m01 + m10) / s,
                0.25f * s,
                (m12 + m21) / s,
                (m20 - m02) / s);
        }

        {
            var s = 2f * MathF.Sqrt(1f + m22 - m00 - m11);
            return new Quaternion(
                (m20 + m02) / s,
                (m12 + m21) / s,
                0.25f * s,
                (m01 - m10) / s);
        }
    }

    public static Quaternion Inverse(Quaternion q)
    {
        var n = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
        if (n < 1e-8f) return new Quaternion(0, 0, 0, 1);
        n = 1f / n;
        return new Quaternion(-q.x * n, -q.y * n, -q.z * n, q.w * n);
    }

    public static Vector3 operator *(Quaternion q, Vector3 v)
    {
        var qv = new Vector3(q.x, q.y, q.z);
        var t = 2f * Vector3.Cross(qv, v);
        return v + q.w * t + Vector3.Cross(qv, t);
    }
}

public struct Matrix4x4
{
    System.Numerics.Matrix4x4 _m;

    Matrix4x4(System.Numerics.Matrix4x4 n)
    {
        _m = n;
    }

    public Matrix4x4(Vector4 column0, Vector4 column1, Vector4 column2, Vector4 column3)
    {
        _m = new System.Numerics.Matrix4x4(
            column0.x, column1.x, column2.x, column3.x,
            column0.y, column1.y, column2.y, column3.y,
            column0.z, column1.z, column2.z, column3.z,
            column0.w, column1.w, column2.w, column3.w);
    }

    public readonly Matrix4x4 inverse
    {
        get
        {
            System.Numerics.Matrix4x4.Invert(_m, out var inv);
            return new Matrix4x4(inv);
        }
    }

    public static Vector3 operator *(Matrix4x4 m, Vector3 v)
    {
        var nv = System.Numerics.Vector3.Transform(
            new System.Numerics.Vector3(v.x, v.y, v.z),
            m._m);
        return new Vector3(nv.X, nv.Y, nv.Z);
    }
}
