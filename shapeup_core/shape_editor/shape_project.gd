extends RefCounted
class_name ShapeProject

const _PBO := preload("res://shapeup_core/decomposition/polygon_boolean_operator.gd")
const _PolyBoolRoot := preload("res://shapeup_core/decomposition/poly_bool/poly_bool_root.gd")
const _ShapeShape := preload("res://shapeup_core/shape_editor/shape_shape.gd")
const _ShapePivot := preload("res://shapeup_core/shape_editor/shape_pivot.gd")
const _PolyBool := preload("res://shapeup_core/decomposition/poly_bool/poly_bool.gd")
const _SegmentList := preload("res://shapeup_core/decomposition/poly_bool/segment_list.gd")
const _EditorPolygonMesh := preload("res://shapeup_core/decomposition/polygon_mesh.gd")
const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")
const _PolyboolExtensions := preload("res://shapeup_core/decomposition/poly_bool/polybool_extensions.gd")

var version: int = 2
var shapes: Array = []
var global_pivot = _ShapePivot.new()
var _is_valid: bool = false


func _init() -> void:
	shapes.append(_ShapeShape.new())


func validate() -> void:
	if not _is_valid:
		_is_valid = true
		for s in shapes:
			s.validate()


func invalidate() -> void:
	_is_valid = false


func clone_project():
	var ser: GDScript = load("res://shapeup_core/shape_editor/shapeup_serialization.gd") as GDScript
	var json: Variant = ser.project_to_json(self)
	return ser.project_from_json(json)


func generate_convex_polygons(use_holes: bool = true) -> EditorPolygonMesh:
	validate()
	var poly_bool = _PolyBool.new()
	var result_seg_list = _generate_concave_segment_list(poly_bool)
	return _segment_list_to_convex_mesh(poly_bool, result_seg_list, use_holes)


func _generate_concave_segment_list(poly_bool) -> Variant:
	var result = _SegmentList.new()
	for si in range(shapes.size()):
		var shape = shapes[si]
		var polys = shape.generate_concave_polygons(true)
		for j in polys.size():
			var ep = polys[j]
			var pb_poly = ep.to_polybool()
			var seg2 = poly_bool.segments(pb_poly)
			var comb = poly_bool.combine(result, seg2)
			if shape.boolean_operator == _PBO.PolygonBooleanOperator.UNION:
				result = poly_bool.select_union(comb)
			else:
				result = poly_bool.select_difference(comb)
	return result


func _segment_list_to_convex_mesh(poly_bool, segment_list, use_holes: bool):
	var pb_shape = poly_bool.polygon(segment_list)
	var concave: Array = EditorPolygonExtensions.to_editor_polygons(pb_shape, poly_bool)
	var convex_mesh = _EditorPolygonMesh.new()
	var holes: Array = []
	for i in concave.size():
		var cp = concave[i]
		if not cp.is_counter_clockwise_2d():
			holes.append(cp)
	var has_holes := holes.size() > 0
	for i2 in concave.size():
		var conc = concave[i2]
		if not conc.is_counter_clockwise_2d():
			continue
		if use_holes:
			if has_holes:
				conc.holes.clear()
				for h in holes:
					if conc.convex_contains(h):
						conc.holes.append(h)
				if conc.holes.size() > 0:
					convex_mesh.append_polygons(DelaunayDecomposer.convex_partition(conc))
				else:
					convex_mesh.append_polygons(BayazitDecomposer.convex_partition(conc))
			else:
				convex_mesh.append_polygons(BayazitDecomposer.convex_partition(conc))
		else:
			convex_mesh.append_polygons(BayazitDecomposer.convex_partition(conc))
	if not use_holes:
		for hi in holes.size():
			var hole_poly = holes[hi]
			hole_poly.reverse()
			var hole_parts = BayazitDecomposer.convex_partition(hole_poly)
			for hp in hole_parts:
				hp.boolean_operator = _PBO.PolygonBooleanOperator.DIFFERENCE
				convex_mesh.append_polygon(hp)
	return convex_mesh


func get_project_bounds_2d() -> Rect2:
	var cm := generate_convex_polygons(true)
	cm.calculate_bounds_2d()
	return cm.bounds_2d


## Vertical strips along X (C# `GenerateChoppedPolygons`). Each element is an [EditorPolygonMesh] slice.
func generate_chopped_polygons(chop_count: int, use_holes: bool = true) -> Array:
	validate()
	if chop_count < 1:
		return []
	var poly_bool = _PolyBool.new()
	var project_segment_list = _generate_concave_segment_list(poly_bool)
	var project_polygons = poly_bool.polygon(project_segment_list)
	var bounds := get_project_bounds_2d()
	var w: float = bounds.size.x
	if w < 1e-8:
		w = 1.0
	var chop_w: float = w / float(chop_count)
	var y0: float = bounds.position.y
	var y1: float = bounds.position.y + bounds.size.y
	var out: Array = []
	for i in range(chop_count):
		var x1: float = bounds.position.x + chop_w * float(i)
		var x2: float = x1 + chop_w
		var rect_pts := PackedVector2Array([
			Vector2(x1, y0), Vector2(x2, y0), Vector2(x2, y1), Vector2(x1, y1)
		])
		var chop_poly = _PolyboolExtensions.to_polybool_polygon(rect_pts, false)
		var comb = poly_bool.combine(poly_bool.segments(project_polygons), poly_bool.segments(chop_poly))
		var inter = poly_bool.select_intersect(comb)
		var mesh = _segment_list_to_convex_mesh(poly_bool, inter, use_holes)
		out.append(mesh)
	return out


func select_all() -> void:
	validate()
	for s in shapes:
		s.select_all()


func clear_selection() -> void:
	validate()
	for s in shapes:
		s.clear_selection()


func invert_selection() -> void:
	validate()
	for s in shapes:
		s.invert_selection()


func has_any_fully_selected_edge() -> bool:
	validate()
	for sh in shapes:
		for seg in sh.segments:
			if seg.selected and seg.next.selected:
				return true
	return false


func find_segment_line_at_position(grid: Vector2, max_distance: float):
	validate()
	var best = null
	var best_d := INF
	for sh in shapes:
		for j in range(sh.segments.size()):
			var segment = sh.segments[j]
			var current_point: Vector2 = segment.position
			var last_point: Vector2 = segment.next.position
			var d: float
			if segment.generator.type == _Enums.SegmentGeneratorType.LINEAR:
				d = _MathEx.distance_to_segment(grid, current_point, last_point)
				if d < max_distance and d < best_d:
					best_d = d
					best = segment
			else:
				for p in segment.generator.for_each_additional_segment_point():
					var generated_point: Vector2 = p
					d = _MathEx.distance_to_segment(grid, current_point, generated_point)
					if d < max_distance and d < best_d:
						best_d = d
						best = segment
					current_point = generated_point
				d = _MathEx.distance_to_segment(grid, current_point, last_point)
				if d < max_distance and d < best_d:
					best_d = d
					best = segment
	return best


static func _update_best_edge_insert_candidate(
	position: Vector2,
	max_edge_distance: float,
	min_dist_from_vertex: float,
	a: Vector2,
	b: Vector2,
	segment,
	best_d_ref: Array,
	best_seg_ref: Array,
	best_pt_ref: Array
) -> void:
	var nearest: Vector2 = _MathEx.find_nearest_point_on_line(position, a, b)
	var d: float = position.distance_to(nearest)
	var best_d: float = best_d_ref[0]
	if d >= max_edge_distance or d >= best_d:
		return
	if nearest.distance_to(a) < min_dist_from_vertex or nearest.distance_to(b) < min_dist_from_vertex:
		return
	best_d_ref[0] = d
	best_seg_ref[0] = segment
	best_pt_ref[0] = nearest


func try_find_edge_insert_point(grid: Vector2, max_edge_distance: float, min_dist_from_vertex: float) -> Variant:
	validate()
	var best_d_ref: Array = [INF]
	var best_seg_ref: Array = [null]
	var best_pt_ref: Array = [Vector2.ZERO]
	for sh in shapes:
		for j in range(sh.segments.size()):
			var segment = sh.segments[j]
			var last_point: Vector2 = segment.next.position
			if segment.generator.type == _Enums.SegmentGeneratorType.LINEAR:
				_update_best_edge_insert_candidate(
					grid, max_edge_distance, min_dist_from_vertex, segment.position, last_point, segment,
					best_d_ref, best_seg_ref, best_pt_ref
				)
			else:
				var current_point: Vector2 = segment.position
				for p in segment.generator.for_each_additional_segment_point():
					var generated_point: Vector2 = p
					_update_best_edge_insert_candidate(
						grid, max_edge_distance, min_dist_from_vertex, current_point, generated_point, segment,
						best_d_ref, best_seg_ref, best_pt_ref
					)
					current_point = generated_point
				_update_best_edge_insert_candidate(
					grid, max_edge_distance, min_dist_from_vertex, current_point, last_point, segment,
					best_d_ref, best_seg_ref, best_pt_ref
				)
	if best_seg_ref[0] == null:
		return null
	return {"host": best_seg_ref[0], "closest": best_pt_ref[0]}
