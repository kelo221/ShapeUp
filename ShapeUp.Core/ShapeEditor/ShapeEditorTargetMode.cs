namespace ShapeUp.Core.ShapeEditor;

/// <summary>The operating mode for extrusion / brush export (ported from ShapeEditor).</summary>
public enum ShapeEditorTargetMode
{
    Polygon = 0,
    FixedExtrude = 1,
    ScaledExtrude = 5,
    SplineExtrude = 2,
    RevolveChopped = 6,
    RevolveExtrude = 3,
    LinearStaircase = 4,
}
