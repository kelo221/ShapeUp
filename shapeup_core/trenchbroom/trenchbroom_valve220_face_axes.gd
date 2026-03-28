class_name TrenchBroomValve220FaceAxes
extends RefCounted

const SCALE_ROTATION_TAIL := "0 0.25 0.25"

static func unity_outward_normal_to_map(outward_unity: Vector3) -> Vector3:
	var n := outward_unity.normalized()
	return Vector3(n.x, n.z, -n.y).normalized()

static func format_face_suffix(outward_map_normal: Vector3) -> String:
	var n := outward_map_normal.normalized()
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	var t := 0.98

	if ax >= t and ax >= ay and ax >= az:
		return _min_map_x() if n.x < 0.0 else _max_map_x()
	if ay >= t and ay >= ax and ay >= az:
		return _min_map_y() if n.y < 0.0 else _max_map_y()
	if az >= t and az >= ax and az >= ay:
		return _min_map_z() if n.z < 0.0 else _max_map_z()

	return "[ 1 0 0 0 ] [ 0 1 0 0 ] " + SCALE_ROTATION_TAIL

static func _min_map_x() -> String: return "[ 0 -1 0 0 ] [ 0 0 -1 0 ] " + SCALE_ROTATION_TAIL
static func _max_map_x() -> String: return "[ 1 0 0 0 ] [ 0 -1 0 0 ] " + SCALE_ROTATION_TAIL

static func _min_map_y() -> String: return "[ 1 0 0 0 ] [ 0 0 -1 0 ] " + SCALE_ROTATION_TAIL
static func _max_map_y() -> String: return "[ -1 0 0 0 ] [ 0 0 -1 0 ] " + SCALE_ROTATION_TAIL

static func _min_map_z() -> String: return "[ -1 0 0 0 ] [ 0 -1 0 0 ] " + SCALE_ROTATION_TAIL
static func _max_map_z() -> String: return "[ 0 1 0 0 ] [ 0 0 -1 0 ] " + SCALE_ROTATION_TAIL
