namespace UnityEngine;

public struct Color
{
    public float r, g, b, a;

    public Color(float r, float g, float b, float a = 1f)
    {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    public static Color white => new(1, 1, 1, 1);
    public static Color black => new(0, 0, 0, 1);
    public static Color red => new(1, 0, 0, 1);
    public static Color cyan => new(0, 1, 1, 1);
    public static Color blue => new(0, 0, 1, 1);

    public static Color Lerp(Color a, Color b, float t) => new(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        a.a + (b.a - a.a) * t);
}

/// <summary>2D rectangle (Unity-compatible subset).</summary>
public struct Rect
{
    public float x, y, width, height;

    public Rect(float x, float y, float width, float height)
    {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    public readonly float xMax => x + width;
    public readonly float yMax => y + height;

    public readonly bool Contains(Vector2 p) =>
        p.x >= x && p.x <= xMax && p.y >= y && p.y <= yMax;
}

public struct Bounds
{
    public Vector3 center;
    public Vector3 size;

    public readonly Vector3 min => center - size * 0.5f;
    public readonly Vector3 max => center + size * 0.5f;

    public void Encapsulate(Vector3 point)
    {
        var mn = Vector3.Min(min, point);
        var mx = Vector3.Max(max, point);
        center = (mn + mx) * 0.5f;
        size = mx - mn;
    }

    public void Encapsulate(Bounds b)
    {
        Encapsulate(b.min);
        Encapsulate(b.max);
    }

    public void SetMinMax(Vector3 min, Vector3 max)
    {
        size = max - min;
        center = (min + max) * 0.5f;
    }
}
