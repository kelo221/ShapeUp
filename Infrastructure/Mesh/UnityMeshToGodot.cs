using System.Collections.Generic;
using Godot;
using GVector2 = Godot.Vector2;
using GVector3 = Godot.Vector3;
using UnityEngine;

namespace ShapeUp.Infrastructure.Mesh;

/// <summary>Maps ShapeEditor Unity-style mesh buffers (XY profile, Z extrusion) into Godot Y-up space (x, z, y).</summary>
public static class UnityMeshToGodot
{
    public static ArrayMesh ToArrayMesh(UnityEngine.Mesh mesh)
    {
        var am = new ArrayMesh();
        var verts = mesh.VerticesReadOnly;
        if (verts.Count == 0)
            return am;

        var godotVerts = new GVector3[verts.Count];
        for (var i = 0; i < verts.Count; i++)
        {
            var v = verts[i];
            godotVerts[i] = new GVector3(v.x, v.z, v.y);
        }

        var uvs = mesh.Uv0ReadOnly;
        var allIdx = new List<int>(verts.Count * 2);
        for (var sm = 0; sm < mesh.subMeshCount; sm++)
        {
            var tris = mesh.SubmeshTriangles[sm];
            if (tris == null || tris.Count == 0)
                continue;
            foreach (var t in tris)
                allIdx.Add(t);
        }

        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Godot.Mesh.ArrayType.Max);
        arrays[(int)Godot.Mesh.ArrayType.Vertex] = godotVerts;

        if (uvs.Count == verts.Count)
        {
            var uv2 = new GVector2[uvs.Count];
            for (var i = 0; i < uvs.Count; i++)
            {
                var u = uvs[i];
                uv2[i] = new GVector2(u.x, u.y);
            }

            arrays[(int)Godot.Mesh.ArrayType.TexUV] = uv2;
        }

        if (allIdx.Count > 0)
            arrays[(int)Godot.Mesh.ArrayType.Index] = allIdx.ToArray();

        var norms = mesh.NormalsReadOnly;
        if (norms.Count == verts.Count)
        {
            var gn = new GVector3[verts.Count];
            for (var i = 0; i < verts.Count; i++)
            {
                var n = norms[i];
                gn[i] = new GVector3(n.x, n.z, n.y);
            }

            arrays[(int)Godot.Mesh.ArrayType.Normal] = gn;
        }
        else if (allIdx.Count > 0)
            arrays[(int)Godot.Mesh.ArrayType.Normal] = ComputeNormalsIndexed(godotVerts, allIdx);

        am.AddSurfaceFromArrays(Godot.Mesh.PrimitiveType.Triangles, arrays);
        return am;
    }

    static GVector3[] ComputeNormalsIndexed(GVector3[] godotVerts, List<int> indices)
    {
        var n = godotVerts.Length;
        var acc = new GVector3[n];
        for (var t = 0; t + 2 < indices.Count; t += 3)
        {
            var i0 = indices[t];
            var i1 = indices[t + 1];
            var i2 = indices[t + 2];
            if ((uint)i0 >= (uint)n || (uint)i1 >= (uint)n || (uint)i2 >= (uint)n)
                continue;
            var e1 = godotVerts[i1] - godotVerts[i0];
            var e2 = godotVerts[i2] - godotVerts[i0];
            var fn = e1.Cross(e2);
            var len = fn.Length();
            if (len < 1e-20f)
                continue;
            fn /= len;
            acc[i0] += fn;
            acc[i1] += fn;
            acc[i2] += fn;
        }

        var outN = new GVector3[n];
        for (var i = 0; i < n; i++)
        {
            var nn = acc[i];
            var m = nn.Length();
            outN[i] = m > 1e-20f ? nn / m : GVector3.Up;
        }

        return outN;
    }
}
