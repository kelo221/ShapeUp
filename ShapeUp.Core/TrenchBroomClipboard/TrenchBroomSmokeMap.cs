using System.Collections.Generic;
using System.Numerics;

namespace ShapeUp.Core.TrenchBroomClipboard;

/// <summary>Minimal Quake .map document for FuncGodot / TB smoke (single <c>worldspawn</c> with one brush).</summary>
public static class TrenchBroomSmokeMap
{
    public static string BuildDocument(string groupName = "ShapeUpSmoke")
    {
        var cube = new List<UnityStylePlane>
        {
            new(new Vector3(1, 0, 0), -0.5f),
            new(new Vector3(-1, 0, 0), -0.5f),
            new(new Vector3(0, 1, 0), -0.5f),
            new(new Vector3(0, -1, 0), -0.5f),
            new(new Vector3(0, 0, 1), -0.5f),
            new(new Vector3(0, 0, -1), -0.5f),
        };
        return TrenchBroomClipboardBuilder.GenerateClipboardBrushesText(
            new List<IReadOnlyList<UnityStylePlane>> { cube }, groupName);
    }
}
