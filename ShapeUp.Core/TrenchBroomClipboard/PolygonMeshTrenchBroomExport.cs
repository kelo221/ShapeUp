using System.Collections.Generic;
using System.Numerics;
using ShapeUp.Core.ShapeEditor;

namespace ShapeUp.Core.TrenchBroomClipboard;

/// <summary>Maps ShapeEditor <see cref="PolygonMesh"/> planes to clipboard builder input.</summary>
public static class PolygonMeshTrenchBroomExport
{
    public static List<List<UnityStylePlane>> ToBrushPlaneLists(IReadOnlyList<PolygonMesh> brushes)
    {
        var result = new List<List<UnityStylePlane>>(brushes.Count);
        foreach (var mesh in brushes)
        {
            var planes = mesh.ToPlanes();
            var list = new List<UnityStylePlane>(planes.Length);
            foreach (var p in planes)
            {
                var n = p.normal;
                list.Add(new UnityStylePlane(new Vector3(n.x, n.y, n.z), p.distance));
            }

            result.Add(list);
        }

        return result;
    }

    /// <summary>TrenchBroom paste and FuncGodot: single <c>worldspawn</c> entity with nested brushes.</summary>
    public static string BuildClipboard(IReadOnlyList<PolygonMesh> brushes, string groupName = "2D Shape Editor")
    {
        var lists = ToBrushPlaneLists(brushes);
        return TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(lists, groupName);
    }

    /// <summary>Same document as <see cref="BuildClipboard"/> (no separate <c>func_group</c> entity).</summary>
    public static string BuildStandaloneMapFile(IReadOnlyList<PolygonMesh> brushes, string groupName = "ShapeUp") =>
        BuildClipboard(brushes, groupName);
}
