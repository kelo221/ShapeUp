extends RefCounted
class_name ShapeSegmentGenerator

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _ShapePivot := preload("res://shapeup_core/shape_editor/shape_pivot.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")
const _SegmentGeneratorArch = preload("res://shapeup_core/shape_editor/segment_generator_arch.gd")

var segment = null ## ShapeSegment
var type: int = _Enums.SegmentGeneratorType.LINEAR

var arch_detail: int = 8
var arch_flipped: bool = false
var arch_grid_snap_size: float = 0.0
var arch_mode: int = 0

var bezier_detail: int = 8
var bezier_grid_snap_size: float = 0.0
var bezier_pivot1 := _ShapePivot.new()
var bezier_pivot2 := _ShapePivot.new()
var bezier_quadratic: bool = false

var sine_detail: int = 64
var sine_frequency: float = -3.5
var sine_grid_snap_size: float = 0.0
var sine_pivot1 := _ShapePivot.new()

var repeat_segments: int = 2
var repeat_times: int = 4

## True when BEZIER/SINE endpoint setup was skipped because `segment.next` was not linked yet (e.g. JSON load).
var _needs_endpoint_geometry_init: bool = false


func _init(p_segment = null, p_type: int = _Enums.SegmentGeneratorType.LINEAR) -> void:
	segment = p_segment
	type = p_type
	if segment != null:
		match type:
			_Enums.SegmentGeneratorType.BEZIER:
				if segment.next != null:
					_bezier_constructor()
				else:
					_needs_endpoint_geometry_init = true
			_Enums.SegmentGeneratorType.SINE:
				if segment.next != null:
					_sine_constructor()
				else:
					_needs_endpoint_geometry_init = true


func duplicate_for_segment(p_segment):
	var g = get_script().new(p_segment, type)
	g.arch_detail = arch_detail
	g.arch_flipped = arch_flipped
	g.arch_grid_snap_size = arch_grid_snap_size
	g.arch_mode = arch_mode
	g.bezier_detail = bezier_detail
	g.bezier_grid_snap_size = bezier_grid_snap_size
	g.bezier_quadratic = bezier_quadratic
	g.bezier_pivot1.position = bezier_pivot1.position
	g.bezier_pivot1.selected = bezier_pivot1.selected
	g.bezier_pivot1.gp_vector1 = bezier_pivot1.gp_vector1
	g.bezier_pivot2.position = bezier_pivot2.position
	g.bezier_pivot2.selected = bezier_pivot2.selected
	g.bezier_pivot2.gp_vector1 = bezier_pivot2.gp_vector1
	g.sine_detail = sine_detail
	g.sine_frequency = sine_frequency
	g.sine_grid_snap_size = sine_grid_snap_size
	g.sine_pivot1.position = sine_pivot1.position
	g.repeat_segments = repeat_segments
	g.repeat_times = repeat_times
	g._needs_endpoint_geometry_init = _needs_endpoint_geometry_init
	return g


## Call after polygon links (`segment.next`) are valid — e.g. from [method ShapeShape.validate].
func finalize_endpoint_geometry_if_needed() -> void:
	if not _needs_endpoint_geometry_init:
		return
	if segment == null or segment.next == null:
		return
	match type:
		_Enums.SegmentGeneratorType.BEZIER:
			_bezier_constructor()
		_Enums.SegmentGeneratorType.SINE:
			_sine_constructor()
	_needs_endpoint_geometry_init = false


func _bezier_constructor() -> void:
	if segment == null or segment.next == null:
		return
	var p1: Vector2 = segment.position
	var p4: Vector2 = segment.next.position
	var dist := p1.distance_to(p4)
	var n := (p4 - p1).normalized()
	bezier_pivot1.position = p1 + n * dist * 0.25
	bezier_pivot2.position = p4 - n * dist * 0.25


func _sine_constructor() -> void:
	if segment == null or segment.next == null:
		return
	var p1: Vector2 = segment.position
	var p2: Vector2 = segment.next.position
	var dist := p1.distance_to(p2)
	var n := (p2 - p1).normalized()
	sine_pivot1.position = p1 + n * dist * 0.125


func for_each_additional_segment_point() -> Array[Vector2]:
	var out: Array[Vector2] = []
	match type:
		_Enums.SegmentGeneratorType.LINEAR:
			pass
		_Enums.SegmentGeneratorType.BEZIER:
			var p1: Vector2 = segment.position
			var p2: Vector2 = bezier_pivot1.position
			var p3: Vector2 = bezier_pivot2.position
			var p4: Vector2 = segment.next.position
			if bezier_quadratic:
				var cps := _MathEx.get_bezier_control_points_quadratic(p1, p2, p4)
				p2 = cps[0]
				p3 = cps[1]
			var last := Vector2(-INF, -INF)
			for i in range(1, bezier_detail):
				var t := float(i) / float(bezier_detail)
				var pt := _MathEx.bezier_get_point(p1, p2, p3, p4, t)
				pt = _MathEx.snap_vec2(pt, bezier_grid_snap_size)
				if pt != last:
					out.append(pt)
					last = pt
		_Enums.SegmentGeneratorType.SINE:
			var p1s: Vector2 = segment.position
			var p2s: Vector2 = segment.next.position
			var p3s: Vector2 = sine_pivot1.position
			var height := p1s.distance_to(p3s)
			var normal := (p2s - p1s).normalized()
			var cross := Vector2(-normal.y, normal.x)
			var last2 := Vector2(-INF, -INF)
			for i in range(1, sine_detail):
				var tf := float(i) / float(sine_detail)
				var pos := p1s.lerp(p2s, tf)
				var curve: float = sin(TAU * tf * sine_frequency) * height
				pos.x += curve * cross.x
				pos.y += curve * cross.y
				var point := _MathEx.snap_vec2(pos, sine_grid_snap_size)
				if point != last2:
					out.append(point)
					last2 = point
		_Enums.SegmentGeneratorType.REPEAT:
			if repeat_segments > 0:
				var begin = segment
				for _i in repeat_segments:
					begin = begin.previous
				var last_point: Vector2 = segment.position
				for _ri in repeat_times:
					var current = begin
					for _j in repeat_segments:
						var next_last := Vector2.ZERO
						for pt in _repeat_get_points(last_point, current):
							out.append(pt)
							next_last = pt
						last_point = next_last
						current = current.next
		_Enums.SegmentGeneratorType.ARCH:
			for pt in _SegmentGeneratorArch.collect_arch_points(self):
				out.append(pt)
	return out


func _repeat_get_points(previous: Vector2, current) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	if current.generator.type != _Enums.SegmentGeneratorType.REPEAT:
		for p in current.generator.for_each_additional_segment_point():
			pts.append(previous + (p - current.position))
	pts.append(previous + (current.next.position - current.position))
	return pts


func apply_generator() -> void:
	if segment == null or segment.shape == null:
		return
	var next_seg = segment.next
	var ShapeSegmentClass = load("res://shapeup_core/shape_editor/shape_segment.gd")
	for point in for_each_additional_segment_point():
		var new_seg = ShapeSegmentClass.new(segment.shape, point.x, point.y)
		segment.shape.insert_segment_before(next_seg, new_seg)


func flip_direction() -> void:
	match type:
		_Enums.SegmentGeneratorType.SINE:
			sine_frequency *= -1.0
		_Enums.SegmentGeneratorType.ARCH:
			arch_flipped = not arch_flipped
