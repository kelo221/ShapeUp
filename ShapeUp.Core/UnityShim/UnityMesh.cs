using System.Collections.Generic;

namespace UnityEngine.Rendering
{
    public enum IndexFormat
    {
        UInt16 = 0,
        UInt32 = 1,
    }
}

namespace UnityEngine
{
    /// <summary>Minimal mesh buffer for ShapeEditor polygon extraction; Godot builds ArrayMesh from this.</summary>
    public sealed class Mesh
    {
        public string name = string.Empty;
        public Rendering.IndexFormat indexFormat = Rendering.IndexFormat.UInt16;

        readonly List<Vector3> _vertices = new();
        readonly List<Vector3> _normals = new();
        readonly List<Vector2> _uv0 = new();
        readonly List<List<int>> _submeshTriangles = new();

        public IReadOnlyList<Vector3> VerticesReadOnly => _vertices;
        public IReadOnlyList<Vector3> NormalsReadOnly => _normals;
        public IReadOnlyList<Vector2> Uv0ReadOnly => _uv0;
        public IReadOnlyList<IReadOnlyList<int>> SubmeshTriangles => _submeshTriangles;

        public void SetVertices(IList<Vector3> v)
        {
            _vertices.Clear();
            _vertices.AddRange(v);
            _normals.Clear();
        }

        public void SetUVs(int channel, IList<Vector2> uvs)
        {
            if (channel != 0) return;
            _uv0.Clear();
            _uv0.AddRange(uvs);
        }

        public int subMeshCount { get; set; }

        public void SetTriangles(IList<int> triangles, int submesh)
        {
            while (_submeshTriangles.Count <= submesh)
                _submeshTriangles.Add(new List<int>());
            var list = _submeshTriangles[submesh];
            list.Clear();
            list.AddRange(triangles);
        }

        public void RecalculateNormals()
        {
            var n = _vertices.Count;
            if (n == 0)
            {
                _normals.Clear();
                return;
            }

            var acc = new Vector3[n];
            foreach (var sub in _submeshTriangles)
            {
                for (var t = 0; t + 2 < sub.Count; t += 3)
                {
                    var i0 = sub[t];
                    var i1 = sub[t + 1];
                    var i2 = sub[t + 2];
                    if ((uint)i0 >= (uint)n || (uint)i1 >= (uint)n || (uint)i2 >= (uint)n)
                        continue;
                    var e1 = _vertices[i1] - _vertices[i0];
                    var e2 = _vertices[i2] - _vertices[i0];
                    var fn = Vector3.Cross(e1, e2);
                    var len = fn.magnitude;
                    if (len < 1e-20f)
                        continue;
                    fn /= len;
                    acc[i0] += fn;
                    acc[i1] += fn;
                    acc[i2] += fn;
                }
            }

            _normals.Clear();
            for (var i = 0; i < n; i++)
            {
                var nn = acc[i];
                var m = nn.magnitude;
                _normals.Add(m > 1e-20f ? nn / m : Vector3.up);
            }
        }

        public void RecalculateTangents() { }
    }
}
