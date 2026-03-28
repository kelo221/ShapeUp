extends Node3D

const ORBIT_SENS := 0.005
const PAN_SENS := 0.0035
const ZOOM_FACTOR := 0.12
const PITCH_LIMIT := 1.48

var camera: Camera3D
var _target := Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 2.5
var _last_screen := Vector2.ZERO
var _rmb: bool = false
var _mmb: bool = false


func _input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb = mb.pressed
			if mb.pressed:
				_last_screen = mb.position
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mmb = mb.pressed
			if mb.pressed:
				_last_screen = mb.position
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var dir := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			_distance *= 1.0 + dir * ZOOM_FACTOR
			_distance = clampf(_distance, 0.08, 256.0)
			_apply_camera()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rmb:
			var d := mm.position - _last_screen
			_last_screen = mm.position
			_yaw -= d.x * ORBIT_SENS
			_pitch -= d.y * ORBIT_SENS
			_pitch = clampf(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
			_apply_camera()
			get_viewport().set_input_as_handled()
		elif _mmb:
			var d2 := mm.position - _last_screen
			_last_screen = mm.position
			var cam_basis := camera.global_transform.basis
			var pan := (-cam_basis.x * d2.x + cam_basis.y * d2.y) * PAN_SENS * maxf(_distance, 0.2)
			_target += pan
			_apply_camera()
			get_viewport().set_input_as_handled()


func frame_bounding_box(aabb: AABB, fov_degrees: float, oblique_view: bool = false) -> void:
	if camera == null:
		return
	var center := aabb.position + aabb.size * 0.5
	var ext := aabb.size
	var radius := maxf(maxf(ext.x, ext.y), ext.z) * 0.5
	if radius < 1e-4:
		radius = 0.5
	_target = center
	var fov_rad := deg_to_rad(fov_degrees)
	_distance = radius / tan(fov_rad * 0.5)
	_distance = maxf(_distance, 0.35) * 1.35
	if oblique_view:
		_yaw = 0.65
		_pitch = 0.35
	else:
		_yaw = 0.0
		_pitch = 0.0
	_apply_camera()


func set_preset_top() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_distance = maxf(_distance, 0.5)
	_apply_camera()


func set_preset_front() -> void:
	_yaw = 0.0
	_pitch = PI * 0.5 - 0.03
	_distance = maxf(_distance, 0.5)
	_apply_camera()


func set_preset_right() -> void:
	_yaw = PI * 0.5
	_pitch = 0.0
	_distance = maxf(_distance, 0.5)
	_apply_camera()


func set_preset_iso() -> void:
	_yaw = 0.65
	_pitch = 0.35
	_distance = maxf(_distance, 0.5)
	_apply_camera()


func _apply_camera() -> void:
	if camera == null:
		return
	var cp := cos(_pitch)
	var pos := _target + Vector3(
		_distance * sin(_yaw) * cp,
		_distance * sin(_pitch),
		_distance * cos(_yaw) * cp
	)
	camera.position = pos
	camera.look_at(_target, Vector3.UP)
