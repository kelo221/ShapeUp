using System.Collections.Generic;
using UnityEngine;
using ShapeUp.Core.TrenchBroomClipboard;

namespace ShapeUp.Core.ShapeEditor;

/// <summary>Standalone extrusion + TrenchBroom export (ported from Unity <c>ShapeEditorTarget</c> partials).</summary>
public sealed class ShapeExtrusionTarget
{
    public Project project = new();

    PolygonMesh? _convexPolygons2D;
    PolygonMeshes? _choppedPolygons2D;

    public ShapeEditorTargetMode targetMode = ShapeEditorTargetMode.FixedExtrude;

    public bool polygonDoubleSided;

    public float fixedExtrudeDistance = 0.25f;

    public int splineExtrudePrecision = 8;
    public List<Vector3> SplineControlPoints { get; } = new();

    public int revolveExtrudePrecision = 8;
    public float revolveExtrudeDegrees = 90f;
    public float revolveExtrudeRadius = 2f;
    public float revolveExtrudeHeight;
    public bool revolveExtrudeSloped;

    public int linearStaircasePrecision = 8;
    public float linearStaircaseDistance = 1f;
    public float linearStaircaseHeight = 0.75f;
    public bool linearStaircaseSloped;

    public float scaledExtrudeDistance = 1f;
    public Vector2 scaledExtrudeFrontScale = new(1f, 1f);
    public Vector2 scaledExtrudeBackScale = new(0f, 0f);
    public Vector2 scaledExtrudeOffset;

    public int revolveChoppedPrecision = 8;
    public float revolveChoppedDegrees = 90f;
    public float revolveChoppedDistance = 0.25f;

    public void SetProject(Project p)
    {
        _convexPolygons2D = null;
        _choppedPolygons2D = null;
        project = p ?? new Project();
    }

    public void InvalidateCache()
    {
        project.Invalidate();
        _convexPolygons2D = null;
        _choppedPolygons2D = null;
    }

    void RequireConvexPolygons2D()
    {
        if (_convexPolygons2D == null)
        {
            project.Validate();
            _convexPolygons2D = project.GenerateConvexPolygons();
            _convexPolygons2D.CalculateBounds2D();
        }
    }

    void RequireChoppedPolygons2D(int chopCount)
    {
        if (_choppedPolygons2D == null || _choppedPolygons2D.Count != chopCount)
        {
            project.Validate();
            _choppedPolygons2D = project.GenerateChoppedPolygons(chopCount);
            _choppedPolygons2D.CalculateBounds2D();
        }
    }

    MathEx.Spline3? GetSpline3()
    {
        if (SplineControlPoints.Count < 3) return null;
        return new MathEx.Spline3(SplineControlPoints.ToArray());
    }

    void ClampRevolve(ref float degrees)
    {
        if (degrees >= 0f && degrees < 0.1f) degrees = 0.1f;
        else if (degrees < 0f && degrees > -0.1f) degrees = -0.1f;
    }

    public Mesh? BuildPreviewMesh()
    {
        switch (targetMode)
        {
            case ShapeEditorTargetMode.Polygon:
                RequireConvexPolygons2D();
                return MeshGenerator.CreatePolygonMesh(_convexPolygons2D!, polygonDoubleSided);

            case ShapeEditorTargetMode.FixedExtrude:
                RequireConvexPolygons2D();
                return MeshGenerator.CreateExtrudedPolygonMesh(_convexPolygons2D!, fixedExtrudeDistance);

            case ShapeEditorTargetMode.SplineExtrude:
                RequireConvexPolygons2D();
                var sp = GetSpline3();
                if (sp == null) return null;
                return MeshGenerator.CreateSplineExtrudedMesh(_convexPolygons2D!, sp, splineExtrudePrecision);

            case ShapeEditorTargetMode.RevolveExtrude:
                RequireConvexPolygons2D();
                var rd = revolveExtrudeDegrees;
                ClampRevolve(ref rd);
                return MeshGenerator.CreateRevolveExtrudedMesh(_convexPolygons2D!, revolveExtrudePrecision, rd, revolveExtrudeRadius, revolveExtrudeHeight, revolveExtrudeSloped);

            case ShapeEditorTargetMode.LinearStaircase:
                RequireConvexPolygons2D();
                return MeshGenerator.CreateLinearStaircaseMesh(_convexPolygons2D!, linearStaircasePrecision, linearStaircaseDistance, linearStaircaseHeight, linearStaircaseSloped);

            case ShapeEditorTargetMode.ScaledExtrude:
                RequireConvexPolygons2D();
                return MeshGenerator.CreateScaleExtrudedMesh(_convexPolygons2D!, scaledExtrudeDistance, scaledExtrudeFrontScale, scaledExtrudeBackScale, scaledExtrudeOffset);

            case ShapeEditorTargetMode.RevolveChopped:
                RequireChoppedPolygons2D(revolveChoppedPrecision);
                var rc = revolveChoppedDegrees;
                ClampRevolve(ref rc);
                return MeshGenerator.CreateRevolveChoppedMesh(_choppedPolygons2D!, rc, revolveChoppedDistance);

            default:
                return null;
        }
    }

    public bool TryGetPolygonMeshes(out List<PolygonMesh> polygonMeshes)
    {
        polygonMeshes = default!;

        switch (targetMode)
        {
            case ShapeEditorTargetMode.Polygon:
                return false;

            case ShapeEditorTargetMode.FixedExtrude:
                RequireConvexPolygons2D();
                polygonMeshes = MeshGenerator.CreateExtrudedPolygonMeshes(_convexPolygons2D!, fixedExtrudeDistance);
                return true;

            case ShapeEditorTargetMode.SplineExtrude:
                RequireConvexPolygons2D();
                var spline = GetSpline3();
                if (spline == null) return false;
                polygonMeshes = MeshGenerator.CreateSplineExtrudedPolygonMeshes(_convexPolygons2D!, spline, splineExtrudePrecision);
                return true;

            case ShapeEditorTargetMode.RevolveExtrude:
                RequireConvexPolygons2D();
                ClampRevolve(ref revolveExtrudeDegrees);
                polygonMeshes = MeshGenerator.CreateRevolveExtrudedPolygonMeshes(_convexPolygons2D!, revolveExtrudePrecision, revolveExtrudeDegrees, revolveExtrudeRadius, revolveExtrudeHeight, revolveExtrudeSloped);
                return true;

            case ShapeEditorTargetMode.LinearStaircase:
                RequireConvexPolygons2D();
                polygonMeshes = MeshGenerator.CreateLinearStaircaseMeshes(_convexPolygons2D!, linearStaircasePrecision, linearStaircaseDistance, linearStaircaseHeight, linearStaircaseSloped);
                return true;

            case ShapeEditorTargetMode.ScaledExtrude:
                RequireConvexPolygons2D();
                polygonMeshes = MeshGenerator.CreateScaleExtrudedMeshes(_convexPolygons2D!, scaledExtrudeDistance, scaledExtrudeFrontScale, scaledExtrudeBackScale, scaledExtrudeOffset);
                return true;

            case ShapeEditorTargetMode.RevolveChopped:
                RequireChoppedPolygons2D(revolveChoppedPrecision);
                ClampRevolve(ref revolveChoppedDegrees);
                polygonMeshes = MeshGenerator.CreateRevolveChoppedMeshes(_choppedPolygons2D!, revolveChoppedDegrees, revolveChoppedDistance);
                return true;

            default:
                return false;
        }
    }

    public string? BuildTrenchBroomClipboard(string groupName = "ShapeUp")
    {
        if (!TryGetPolygonMeshes(out var list) || list == null || list.Count == 0)
            return null;
        return PolygonMeshTrenchBroomExport.BuildClipboard(list, groupName);
    }

    /// <summary>Same .map as <see cref="BuildTrenchBroomClipboard"/> (single <c>worldspawn</c> with nested brushes).</summary>
    public string? BuildTrenchBroomStandaloneMap(string groupName = "ShapeUp")
    {
        if (!TryGetPolygonMeshes(out var list) || list == null || list.Count == 0)
            return null;
        return PolygonMeshTrenchBroomExport.BuildStandaloneMapFile(list, groupName);
    }
}
