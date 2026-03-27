// Ported from ShapeEditor (MIT, Henry de Jongh) — ExternalTrenchBroom.cs
using System;
using System.Numerics;
using System.Text;
using ShapeUp.Core.ShapeEditor;

namespace ShapeUp.Core.TrenchBroomClipboard;

/// <summary>How the outer entity is written for .map clipboard / file text.</summary>
public enum TrenchBroomClipboardEntityKind
{
    /// <summary>TrenchBroom paste: <c>mapversion</c> + <c>worldspawn</c> with brushes nested inside the same block (matches TB’s own copy format).</summary>
    WorldspawnBrushes,

    /// <summary><c>func_group</c> with TrenchBroom group keys (legacy; not used for default ShapeUp export).</summary>
    FuncGroup,
}

/// <summary>Builds Quake .map-style clipboard text for pasting brushes into TrenchBroom.</summary>
public sealed class TrenchBroomClipboardBuilder
{
    /// <summary>Fallback Valve 220 suffix for non–axis-aligned faces (scale matches TB default grid).</summary>
    public const string DefaultFaceValve220Suffix = "[ 1 0 0 0 ] [ 0 1 0 0 ] 0 0.25 0.25";

    /// <summary>Semicolon-separated texture roots TrenchBroom writes on <c>worldspawn</c>; paste often fails without this key.</summary>
    public const string DefaultTbTexturesKeyValue = "\"_tb_textures\" \"textures/Bricks;textures/Concrete;textures/Dev;textures/Wood\"";

    /// <summary>World offset along each in-plane tangent so three points are 1 Quake unit apart (TB-style), not 4096.</summary>
    const float PlanePointTangentWorld = 1f / TrenchBroomGrid.QuakeUnitsPerWorld;

    private readonly StringBuilder _sb = new();
    private int _brushCounter;
    private bool _done;
    private readonly string _groupName;

    public TrenchBroomClipboardBuilder(
        TrenchBroomClipboardEntityKind kind = TrenchBroomClipboardEntityKind.WorldspawnBrushes,
        string groupName = "2D Shape Editor")
    {
        _groupName = groupName;
        _sb.AppendLine("// entity 0");
        _sb.AppendLine("{");
        if (kind == TrenchBroomClipboardEntityKind.WorldspawnBrushes)
        {
            // Order matches TrenchBroom’s own copy/paste (mapversion → _tb_textures → classname).
            _sb.AppendLine("\"mapversion\" \"220\"");
            _sb.AppendLine(DefaultTbTexturesKeyValue);
            _sb.AppendLine("\"classname\" \"worldspawn\"");
        }
        else
        {
            _sb.AppendLine("\"classname\" \"func_group\"");
            _sb.AppendLine("\"_tb_type\" \"_tb_group\"");
            _sb.AppendLine($"\"_tb_name\" \"{_groupName}\"");
            _sb.AppendLine("\"_tb_id\" \"1\"");
        }
    }

    public void AddBrush(IReadOnlyList<UnityStylePlane> planes)
    {
        if (_done)
            throw new InvalidOperationException("Cannot add brushes after Build().");

        _sb.AppendLine($"// brush {_brushCounter++}");
        _sb.AppendLine("{");

        for (var i = 0; i < planes.Count; i++)
        {
            var plane = planes[i];
            var normal = Vector3.Normalize(plane.Normal);
            var distance = plane.Distance;

            var pointOnPlane = -normal * distance;

            var u = Vector3.Cross(normal, Math.Abs(Vector3.Dot(normal, Vector3.UnitY)) > 0.9f ? Vector3.UnitX : Vector3.UnitY);
            u = Vector3.Normalize(u);

            var v = Vector3.Normalize(Vector3.Cross(normal, u));

            var p1 = pointOnPlane;
            var p2 = pointOnPlane + u * PlanePointTangentWorld;
            var p3 = pointOnPlane + v * PlanePointTangentWorld;

            // Quake MAP derives the face normal from cross(p3 - p1, p2 - p1), so point order must
            // be chosen to preserve the outward brush normal. p1, p3, p2 yields the outward normal.
            var nOutUnity = normal;
            var nOutMap = TrenchBroomValve220FaceAxes.UnityOutwardNormalToMap(nOutUnity);
            var valveSuffix = TrenchBroomValve220FaceAxes.FormatFaceSuffix(nOutMap);

            _sb.AppendLine(
                $"( {TrenchBroomGrid.FormatMapFilePointPrecise(p1)} ) ( {TrenchBroomGrid.FormatMapFilePointPrecise(p3)} ) ( {TrenchBroomGrid.FormatMapFilePointPrecise(p2)} ) __TB_empty {valveSuffix}");
        }

        _sb.AppendLine("}");
    }

    public string Build()
    {
        if (!_done)
        {
            _sb.AppendLine("}");
            _done = true;
        }

        return _sb.ToString();
    }

    /// <summary>Generates clipboard text: <see cref="TrenchBroomClipboardEntityKind.WorldspawnBrushes"/> (TrenchBroom paste + FuncGodot). <paramref name="groupName"/> is ignored for that kind.</summary>
    public static string GenerateClipboardBrushesText(
        IReadOnlyList<IReadOnlyList<UnityStylePlane>> brushes,
        string groupName = "2D Shape Editor")
    {
        var b = new TrenchBroomClipboardBuilder(TrenchBroomClipboardEntityKind.WorldspawnBrushes, groupName);
        foreach (var brush in brushes)
            b.AddBrush(brush);
        return b.Build();
    }

    /// <summary>Legacy <c>func_group</c> wrapper (same brush bodies as <see cref="GenerateClipboardBrushesText"/>).</summary>
    public static string GenerateFuncGroupClipboardText(
        IReadOnlyList<IReadOnlyList<UnityStylePlane>> brushes,
        string groupName = "2D Shape Editor")
    {
        var b = new TrenchBroomClipboardBuilder(TrenchBroomClipboardEntityKind.FuncGroup, groupName);
        foreach (var brush in brushes)
            b.AddBrush(brush);
        return b.Build();
    }
}
