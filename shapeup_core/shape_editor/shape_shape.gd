extends RefCounted
class_name ShapeShape

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _PBO := preload("res://shapeup_core/decomposition/polygon_boolean_operator.gd")
const _ShapeSegment := preload("res://shapeup_core/shape_editor/shape_segment.gd")
const _ShapeSegmentGenerator := preload("res://shapeup_core/shape_editor/shape_segment_generator.gd")
const _EditorPolygon := preload("res://shapeup_core/decomposition/editor_polygon.gd")
const _EditorVertex := preload("res://shapeup_core/decomposition/editor_vertex.gd")

var segments: Array = []
var boolean_operator: _PBO.PolygonBooleanOperator = _PBO.PolygonBooleanOperator.UNION
var symmetry_axes: int = _Enums.SimpleGlobalAxis.NONE
var front_material: int = 0
var back_material: int = 0


func _init() -> void:
	reset_to_box()


func default_box_half_extent(snap_increment: float) -> float:
	if snap_increment < 1e-8:
		return 1.0
	var n: int = maxi(1, int(round(1.0 / snap_increment)))
	return float(n) * snap_increment


func reset_to_square(half_extent: float) -> void:
	segments.clear()
	add_segment(_ShapeSegment.new(self, -half_extent, -half_extent))
	add_segment(_ShapeSegment.new(self, half_extent, -half_extent))
	add_segment(_ShapeSegment.new(self, half_extent, half_extent))
	add_segment(_ShapeSegment.new(self, -half_extent, half_extent))


func reset_to_box() -> void:
	reset_to_square(1.0)


func add_segment(seg: Variant) -> void:
	var n := segments.size()
	if n == 0:
		seg.previous = seg
		seg.next = seg
	else:
		var last = segments[n - 1]
		last.next = seg
		segments[0].previous = seg
		seg.previous = last
		seg.next = segments[0]
	segments.append(seg)


func validate() -> void:
	var n := segments.size()
	for i in n:
		var seg = segments[i]
		seg.shape = self
		var prev_i := (i - 1 + n) % n
		var next_i := (i + 1) % n
		seg.previous = segments[prev_i]
		seg.next = segments[next_i]
		if seg.generator == null:
			seg.generator = _ShapeSegmentGenerator.new(seg, _Enums.SegmentGeneratorType.LINEAR)
		else:
			seg.generator.segment = seg
	for seg2 in segments:
		if seg2.generator != null:
			seg2.generator.finalize_endpoint_geometry_if_needed()


func clear_selection() -> void:
	for seg in segments:
		seg.selected = false
		if seg.generator.type != _Enums.SegmentGeneratorType.LINEAR:
			for sel in _for_each_selectable(seg.generator):
				sel.selected = false


func select_all() -> void:
	for seg in segments:
		seg.selected = true
		if seg.generator.type != _Enums.SegmentGeneratorType.LINEAR:
			for sel in _for_each_selectable(seg.generator):
				sel.selected = true


func invert_selection() -> void:
	for seg in segments:
		seg.selected = not seg.selected
		if seg.generator.type != _Enums.SegmentGeneratorType.LINEAR:
			for sel in _for_each_selectable(seg.generator):
				sel.selected = not sel.selected


static func _for_each_selectable(gen: Variant) -> Array:
	var r: Array = []
	match gen.type:
		_Enums.SegmentGeneratorType.BEZIER:
			if gen.bezier_quadratic:
				r.append(gen.bezier_pivot1)
			else:
				r.append(gen.bezier_pivot1)
				r.append(gen.bezier_pivot2)
		_Enums.SegmentGeneratorType.SINE:
			r.append(gen.sine_pivot1)
	return r


func generate_concave_polygon(mirror: int = _Enums.SimpleGlobalAxis.NONE):
	var verts = _EditorPolygon.new()
	var flip_x := -1.0 if (mirror & _Enums.SimpleGlobalAxis.HORIZONTAL) != 0 else 1.0
	var flip_y := -1.0 if (mirror & _Enums.SimpleGlobalAxis.VERTICAL) != 0 else 1.0
	for seg in segments:
		verts.call("add_vertex", _EditorVertex.new(Vector3(flip_x * seg.position.x, flip_y * seg.position.y, 0.0)))
		for p in seg.generator.for_each_additional_segment_point():
			verts.call("add_vertex", _EditorVertex.new(Vector3(flip_x * p.x, flip_y * p.y, 0.0)))
	verts.call("force_counter_clockwise_2d")
	return verts


func generate_concave_polygons(flip_y: bool) -> Array:
	var ax := _Enums.SimpleGlobalAxis
	var original: Variant = generate_concave_polygon(ax.VERTICAL if flip_y else ax.NONE)
	var mirror_x = null
	var mirror_y = null
	var mirror_xy = null
	if (symmetry_axes & ax.HORIZONTAL) != 0:
		mirror_x = generate_concave_polygon(ax.HORIZONTAL | (ax.VERTICAL if flip_y else ax.NONE))
	if (symmetry_axes & ax.VERTICAL) != 0:
		mirror_y = generate_concave_polygon(ax.NONE if flip_y else ax.VERTICAL)
	if (symmetry_axes & (ax.HORIZONTAL | ax.VERTICAL)) == (ax.HORIZONTAL | ax.VERTICAL):
		mirror_xy = generate_concave_polygon(ax.HORIZONTAL | (ax.NONE if flip_y else ax.VERTICAL))
	var out: Array = []
	out.append(original)
	if mirror_x != null and mirror_y != null:
		out.append(mirror_x)
		out.append(mirror_y)
		out.append(mirror_xy)
	elif mirror_x != null:
		out.append(mirror_x)
	elif mirror_y != null:
		out.append(mirror_y)
	return out


func contains_point(point: Vector3) -> int:
	var poly: Variant = generate_concave_polygon()
	return poly.contains_point_2d(point)


## Insert `segment` immediately before `current` in the ring (C# `InsertSegmentBefore`).
func insert_segment_before(current, segment) -> void:
	var n := segments.size()
	if n == 0:
		add_segment(segment)
		return
	var idx := segments.find(current)
	if idx < 0:
		add_segment(segment)
		return
	current.previous.next = segment
	segment.previous = current.previous
	segment.next = current
	current.previous = segment
	segments.insert(idx, segment)


## Remove `segment` from the ring (C# `RemoveSegment`).
func remove_segment(segment) -> void:
	var idx := segments.find(segment)
	if idx < 0:
		return
	segment.next.previous = segment.previous
	segment.previous.next = segment.next
	segments.remove_at(idx)
