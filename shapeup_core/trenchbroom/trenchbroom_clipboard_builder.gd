class_name TrenchBroomClipboardBuilder
extends RefCounted

enum EntityKind {
	WORLDSPAWN_BRUSHES,
	FUNC_GROUP
}

const DEFAULT_FACE_VALVE220_SUFFIX := "[ 1 0 0 0 ] [ 0 1 0 0 ] 0 0.25 0.25"
const DEFAULT_TB_TEXTURES_KEY_VALUE := "\"_tb_textures\" \"textures/Bricks;textures/Concrete;textures/Dev;textures/Wood\""
const _PLANE_POINT_TANGENT_WORLD := 1.0 / TrenchBroomGrid.QUAKE_UNITS_PER_WORLD

var _sb: PackedStringArray = []
var _brush_counter := 0
var _done := false
var _group_name: String

func _init(kind: int = EntityKind.WORLDSPAWN_BRUSHES, group_name: String = "2D Shape Editor") -> void:
	_group_name = group_name
	_sb.append("// entity 0")
	_sb.append("{")
	if kind == EntityKind.WORLDSPAWN_BRUSHES:
		_sb.append("\"mapversion\" \"220\"")
		_sb.append(DEFAULT_TB_TEXTURES_KEY_VALUE)
		_sb.append("\"classname\" \"worldspawn\"")
	else:
		_sb.append("\"classname\" \"func_group\"")
		_sb.append("\"_tb_type\" \"_tb_group\"")
		_sb.append("\"_tb_name\" \"%s\"" % _group_name)
		_sb.append("\"_tb_id\" \"1\"")

func add_brush(planes: Array[Plane]) -> void:
	if _done:
		push_error("Cannot add brushes after build().")
		return
	
	_sb.append("// brush %d" % _brush_counter)
	_brush_counter += 1
	_sb.append("{")
	
	for plane in planes:
		var normal := plane.normal.normalized()
		var point_on_plane := normal * plane.d
		
		var cross_axis := Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var u := normal.cross(cross_axis).normalized()
		var v := normal.cross(u).normalized()
		
		var p1 := point_on_plane
		var p2 := point_on_plane + u * _PLANE_POINT_TANGENT_WORLD
		var p3 := point_on_plane + v * _PLANE_POINT_TANGENT_WORLD
		
		var n_out_map := TrenchBroomValve220FaceAxes.unity_outward_normal_to_map(normal)
		var valve_suffix := TrenchBroomValve220FaceAxes.format_face_suffix(n_out_map)
		
		# Quake MAP derives face normal from cross(p3 - p1, p2 - p1)
		_sb.append(
			"( %s ) ( %s ) ( %s ) __TB_empty %s" % [
				TrenchBroomGrid.format_map_file_point_precise(p1),
				TrenchBroomGrid.format_map_file_point_precise(p3),
				TrenchBroomGrid.format_map_file_point_precise(p2),
				valve_suffix
			]
		)
	
	_sb.append("}")

func build() -> String:
	if not _done:
		_sb.append("}")
		_done = true
	var res := "\n".join(_sb)
	if not res.ends_with("\n"):
		res += "\n"
	return res

static func generate_clipboard_brushes_text(brushes: Array, group_name: String = "2D Shape Editor") -> String:
	var b := TrenchBroomClipboardBuilder.new(EntityKind.WORLDSPAWN_BRUSHES, group_name)
	for brush in brushes:
		var typed: Array[Plane] = []
		for p in brush:
			if p is Plane:
				typed.append(p as Plane)
		b.add_brush(typed)
	return b.build()

static func generate_func_group_clipboard_text(brushes: Array, group_name: String = "2D Shape Editor") -> String:
	var b := TrenchBroomClipboardBuilder.new(EntityKind.FUNC_GROUP, group_name)
	for brush in brushes:
		var typed: Array[Plane] = []
		for p in brush:
			if p is Plane:
				typed.append(p as Plane)
		b.add_brush(typed)
	return b.build()
