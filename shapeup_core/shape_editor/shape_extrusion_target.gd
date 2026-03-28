extends RefCounted
class_name ShapeExtrusionTarget

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _ShapeProject := preload("res://shapeup_core/shape_editor/shape_project.gd")
const _MeshBuilder := preload("res://Infrastructure/mesh_builder.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")

var project = _ShapeProject.new()
var _convex_cache = null
var _chopped_cache: Array = []
var _chopped_cache_count: int = -1

var target_mode: int = _Enums.ShapeEditorTargetMode.FIXED_EXTRUDE
var polygon_double_sided: bool = false
var fixed_extrude_distance: float = 0.25

var spline_extrude_precision: int = 8
var spline_control_points: Array = []

var revolve_extrude_precision: int = 8
var revolve_extrude_degrees: float = 90.0
var revolve_extrude_radius: float = 2.0
var revolve_extrude_height: float = 0.0
var revolve_extrude_sloped: bool = false

var linear_staircase_precision: int = 8
var linear_staircase_distance: float = 1.0
var linear_staircase_height: float = 0.75
var linear_staircase_sloped: bool = false

var scaled_extrude_distance: float = 1.0
var scaled_extrude_front_scale: Vector2 = Vector2(1.0, 1.0)
var scaled_extrude_back_scale: Vector2 = Vector2.ZERO
var scaled_extrude_offset: Vector2 = Vector2.ZERO

var revolve_chopped_precision: int = 8
var revolve_chopped_degrees: float = 90.0
var revolve_chopped_distance: float = 0.25


func set_project(p: Variant) -> void:
	_convex_cache = null
	_chopped_cache.clear()
	_chopped_cache_count = -1
	project = p if p != null else _ShapeProject.new()


func invalidate_cache() -> void:
	project.invalidate()
	_convex_cache = null
	_chopped_cache.clear()
	_chopped_cache_count = -1


func _require_convex():
	if _convex_cache == null:
		project.validate()
		_convex_cache = project.generate_convex_polygons()
		_convex_cache.calculate_bounds_2d()
	return _convex_cache


func _require_chopped(chop_count: int) -> Array:
	if chop_count < 1:
		return []
	if _chopped_cache.is_empty() or _chopped_cache_count != chop_count:
		project.validate()
		_chopped_cache = project.generate_chopped_polygons(chop_count)
		_chopped_cache_count = chop_count
	return _chopped_cache


func _spline_packed() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in spline_control_points:
		if p is Vector3:
			out.append(p)
	return out


func _clamp_revolve_degrees(deg: float) -> float:
	var d := deg
	if d >= 0.0 and d < 0.1:
		d = 0.1
	elif d < 0.0 and d > -0.1:
		d = -0.1
	return d


## Returns [ArrayMesh] preview mesh, or `null` when C# would return no mesh (e.g. invalid spline).
func build_preview_mesh() -> Variant:
	match target_mode:
		_Enums.ShapeEditorTargetMode.POLYGON:
			return _MeshBuilder.build_polygon_cap_array_mesh(_require_convex(), polygon_double_sided)
		_Enums.ShapeEditorTargetMode.FIXED_EXTRUDE:
			return _MeshBuilder.build_extruded_array_mesh(_require_convex(), fixed_extrude_distance)
		_Enums.ShapeEditorTargetMode.SPLINE_EXTRUDE:
			var pts := _spline_packed()
			if pts.size() < 3:
				return null
			return _MeshBuilder.build_spline_extruded_array_mesh(_require_convex(), pts, spline_extrude_precision)
		_Enums.ShapeEditorTargetMode.REVOLVE_EXTRUDE:
			var rd := revolve_extrude_degrees
			rd = _clamp_revolve_degrees(rd)
			return _MeshBuilder.build_revolve_extruded_array_mesh(
				_require_convex(),
				revolve_extrude_precision,
				rd,
				revolve_extrude_radius,
				revolve_extrude_height,
				revolve_extrude_sloped
			)
		_Enums.ShapeEditorTargetMode.LINEAR_STAIRCASE:
			return _MeshBuilder.build_linear_staircase_array_mesh(
				_require_convex(),
				linear_staircase_precision,
				linear_staircase_distance,
				linear_staircase_height,
				linear_staircase_sloped
			)
		_Enums.ShapeEditorTargetMode.SCALED_EXTRUDE:
			return _MeshBuilder.build_scaled_extrude_array_mesh(
				_require_convex(),
				scaled_extrude_distance,
				scaled_extrude_front_scale,
				scaled_extrude_back_scale,
				scaled_extrude_offset
			)
		_Enums.ShapeEditorTargetMode.REVOLVE_CHOPPED:
			var slices := _require_chopped(revolve_chopped_precision)
			if slices.is_empty():
				return null
			var rc := revolve_chopped_degrees
			rc = _clamp_revolve_degrees(rc)
			return _MeshBuilder.build_revolve_chopped_array_mesh(slices, rc, revolve_chopped_distance)
		_:
			return _MeshBuilder.build_extruded_array_mesh(_require_convex(), fixed_extrude_distance)

## Builds Quake .map clipboard brush data instead of an ArrayMesh.
func build_trenchbroom_clipboard(group_name: String) -> String:
	var brushes: Array = []
	match target_mode:
		_Enums.ShapeEditorTargetMode.POLYGON:
			brushes = [] # Polygon mode is flat, requires 3D brushes
		_Enums.ShapeEditorTargetMode.FIXED_EXTRUDE:
			brushes = MeshGenerator.create_extruded_polygon_meshes(_require_convex().polygons, fixed_extrude_distance)
		_Enums.ShapeEditorTargetMode.SPLINE_EXTRUDE:
			var pts := _spline_packed()
			if pts.size() >= 3:
				var spline := _MathEx.Spline3.new(pts)
				brushes = MeshGenerator.create_spline_extruded_polygon_meshes(_require_convex().polygons, spline, spline_extrude_precision)
		_Enums.ShapeEditorTargetMode.REVOLVE_EXTRUDE:
			var rd := _clamp_revolve_degrees(revolve_extrude_degrees)
			brushes = MeshGenerator.create_revolve_extruded_polygon_meshes(
				_require_convex(),
				revolve_extrude_precision,
				rd,
				revolve_extrude_radius,
				revolve_extrude_height,
				revolve_extrude_sloped
			)
		_Enums.ShapeEditorTargetMode.LINEAR_STAIRCASE:
			brushes = MeshGenerator.create_linear_staircase_meshes(
				_require_convex(),
				linear_staircase_precision,
				linear_staircase_distance,
				linear_staircase_height,
				linear_staircase_sloped
			)
		_Enums.ShapeEditorTargetMode.SCALED_EXTRUDE:
			brushes = MeshGenerator.create_scale_extruded_meshes(
				_require_convex(),
				scaled_extrude_distance,
				scaled_extrude_front_scale,
				scaled_extrude_back_scale,
				scaled_extrude_offset
			)
		_Enums.ShapeEditorTargetMode.REVOLVE_CHOPPED:
			var slices := _require_chopped(revolve_chopped_precision)
			if not slices.is_empty():
				var rc := _clamp_revolve_degrees(revolve_chopped_degrees)
				brushes = MeshGenerator.create_revolve_chopped_meshes(slices, rc, revolve_chopped_distance)
		_:
			brushes = MeshGenerator.create_extruded_polygon_meshes(_require_convex().polygons, fixed_extrude_distance)
	
	if brushes.is_empty():
		return ""
	
	return PolygonMeshTrenchBroomExport.build_clipboard(brushes, group_name)
