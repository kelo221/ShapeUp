using Godot;

namespace ShapeUp.Features.Editor2D;

/// <summary>Mouse orbit / pan / zoom for the 3D extrusion preview (runs inside the SubViewport).</summary>
public partial class PreviewCameraOrbit : Node3D
{
    const float OrbitSensitivity = 0.005f;
    const float PanSensitivity = 0.0035f;
    const float ZoomFactor = 0.12f;
    const float PitchLimit = 1.48f;

    Camera3D? _camera;
    Vector3 _target;
    float _yaw;
    float _pitch;
    float _distance = 2.5f;

    Vector2 _lastScreenPos;
    bool _rmb;
    bool _mmb;

    public Camera3D? Camera
    {
        get => _camera;
        set => _camera = value;
    }

    /// <summary>Last mesh bounds center (world), for presets.</summary>
    public Vector3 LastMeshCenter => _target;

    public override void _Input(InputEvent @event)
    {
        if (_camera == null)
            return;

        switch (@event)
        {
            case InputEventMouseButton mb:
                if (mb.ButtonIndex == MouseButton.Right)
                {
                    _rmb = mb.Pressed;
                    if (mb.Pressed)
                        _lastScreenPos = mb.Position;
                    GetViewport().SetInputAsHandled();
                }
                else if (mb.ButtonIndex == MouseButton.Middle)
                {
                    _mmb = mb.Pressed;
                    if (mb.Pressed)
                        _lastScreenPos = mb.Position;
                    GetViewport().SetInputAsHandled();
                }
                else if (mb.Pressed && (mb.ButtonIndex == MouseButton.WheelUp || mb.ButtonIndex == MouseButton.WheelDown))
                {
                    var in_ = mb.ButtonIndex == MouseButton.WheelUp ? -1f : 1f;
                    _distance *= 1f + in_ * ZoomFactor;
                    _distance = Mathf.Clamp(_distance, 0.08f, 256f);
                    ApplyCamera();
                    GetViewport().SetInputAsHandled();
                }

                break;

            case InputEventMouseMotion mm:
                if (_rmb)
                {
                    var d = mm.Position - _lastScreenPos;
                    _lastScreenPos = mm.Position;
                    _yaw -= d.X * OrbitSensitivity;
                    _pitch -= d.Y * OrbitSensitivity;
                    _pitch = Mathf.Clamp(_pitch, -PitchLimit, PitchLimit);
                    ApplyCamera();
                    GetViewport().SetInputAsHandled();
                }
                else if (_mmb)
                {
                    var d = mm.Position - _lastScreenPos;
                    _lastScreenPos = mm.Position;
                    var basis = _camera.GlobalTransform.Basis;
                    var pan = (-basis.X * d.X + basis.Y * d.Y) * PanSensitivity * Mathf.Max(_distance, 0.2f);
                    _target += pan;
                    ApplyCamera();
                    GetViewport().SetInputAsHandled();
                }

                break;
        }
    }

    /// <summary>Fit and center on an axis-aligned box in world space (mesh local at origin).</summary>
    /// <param name="obliqueView">If true, use the oblique (Iso-style) yaw/pitch; otherwise top-down plan view.</param>
    public void FrameBoundingBox(Aabb aabb, float fovDegrees, bool obliqueView = false)
    {
        if (_camera == null)
            return;

        var center = aabb.Position + aabb.Size * 0.5f;
        var ext = aabb.Size;
        var radius = Mathf.Max(Mathf.Max(ext.X, ext.Y), ext.Z) * 0.5f;
        if (radius < 1e-4f)
            radius = 0.5f;

        _target = center;
        var fovRad = Mathf.DegToRad(fovDegrees);
        _distance = radius / Mathf.Tan(fovRad * 0.5f);
        _distance = Mathf.Max(_distance, 0.35f) * 1.35f;

        if (obliqueView)
        {
            _yaw = 0.65f;
            _pitch = 0.35f;
        }
        else
        {
            _yaw = 0f;
            _pitch = Mathf.Pi / 2f - 0.03f;
        }

        ApplyCamera();
    }

    public void SetPresetTop()
    {
        _yaw = 0;
        _pitch = Mathf.Pi / 2f - 0.03f;
        _distance = Mathf.Max(_distance, 0.5f);
        ApplyCamera();
    }

    public void SetPresetFront()
    {
        _yaw = 0;
        _pitch = 0;
        _distance = Mathf.Max(_distance, 0.5f);
        ApplyCamera();
    }

    public void SetPresetRight()
    {
        _yaw = Mathf.Pi / 2f;
        _pitch = 0;
        _distance = Mathf.Max(_distance, 0.5f);
        ApplyCamera();
    }

    public void SetPresetIso()
    {
        _yaw = 0.65f;
        _pitch = 0.35f;
        _distance = Mathf.Max(_distance, 0.5f);
        ApplyCamera();
    }

    void ApplyCamera()
    {
        if (_camera == null)
            return;
        var cp = Mathf.Cos(_pitch);
        var pos = _target + new Vector3(
            _distance * Mathf.Sin(_yaw) * cp,
            _distance * Mathf.Sin(_pitch),
            _distance * Mathf.Cos(_yaw) * cp);
        _camera.Position = pos;
        _camera.LookAt(_target, Vector3.Up);
    }
}
