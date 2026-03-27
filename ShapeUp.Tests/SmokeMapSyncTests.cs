using System.IO;
using NUnit.Framework;
using ShapeUp.Core.TrenchBroomClipboard;

namespace ShapeUp.Tests;

[TestFixture]
public sealed class SmokeMapSyncTests
{
    static string ShapeUpRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "ShapeUp.sln")))
                return dir.FullName;
            dir = dir.Parent;
        }

        throw new InvalidOperationException("ShapeUp.sln not found from test bin.");
    }

    [Test]
    public void SmokeMap_OnDisk_MatchesBuilder()
    {
        var path = Path.Combine(ShapeUpRepoRoot(), "test_maps", "shapeup_smoke.map");
        Assert.That(File.Exists(path), Is.True, "Missing test_maps/shapeup_smoke.map (generate from TrenchBroomSmokeMap.BuildDocument).");
        var expected = NormalizeEol(TrenchBroomSmokeMap.BuildDocument());
        var actual = NormalizeEol(File.ReadAllText(path));
        Assert.That(actual, Is.EqualTo(expected));
    }

    static string NormalizeEol(string s) => s.Replace("\r\n", "\n");
}
