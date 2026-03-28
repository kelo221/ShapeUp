extends RefCounted
class_name VertexSelectionTransforms

const _ShapeShape := preload("res://shapeup_core/shape_editor/shape_shape.gd")
const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")


static func translate_selection(project, delta: Vector2) -> void:
	if delta.length_squared() < 1e-16:
		return
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if seg.selected:
				seg.position += delta
			var g = seg.generator
			for sel in _ShapeShape._for_each_selectable(g):
				if sel.selected:
					sel.position += delta
	project.invalidate()


static func has_selected_segment_vertex(project) -> bool:
	for sh in project.shapes:
		for seg in sh.segments:
			if seg.selected:
				return true
	return false


static func get_centroid_of_selected_segment_vertices(project) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			sum += seg.position
			n += 1
	return sum / float(n) if n > 0 else Vector2.ZERO


static func capture_rotate_baseline(project) -> void:
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			seg.gp_vector1 = seg.position
			var g = seg.generator
			match g.type:
				_Enums.SegmentGeneratorType.BEZIER:
					g.bezier_pivot1.gp_vector1 = g.bezier_pivot1.position
					if not g.bezier_quadratic:
						g.bezier_pivot2.gp_vector1 = g.bezier_pivot2.position
				_Enums.SegmentGeneratorType.SINE:
					g.sine_pivot1.gp_vector1 = g.sine_pivot1.position
				_:
					pass


static func apply_rotate_from_baseline(project, pivot: Vector2, degrees_total: float) -> void:
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			seg.position = _MathEx.rotate_point_around_pivot_2d(seg.gp_vector1, pivot, degrees_total)
			var g = seg.generator
			match g.type:
				_Enums.SegmentGeneratorType.BEZIER:
					g.bezier_pivot1.position = _MathEx.rotate_point_around_pivot_2d(
						g.bezier_pivot1.gp_vector1, pivot, degrees_total
					)
					if not g.bezier_quadratic:
						g.bezier_pivot2.position = _MathEx.rotate_point_around_pivot_2d(
							g.bezier_pivot2.gp_vector1, pivot, degrees_total
						)
				_Enums.SegmentGeneratorType.SINE:
					g.sine_pivot1.position = _MathEx.rotate_point_around_pivot_2d(
						g.sine_pivot1.gp_vector1, pivot, degrees_total
					)
				_:
					pass
	project.invalidate()


static func angle_from_pivot_to_point_deg(pivot: Vector2, target: Vector2) -> float:
	var d := target - pivot
	return rad_to_deg(atan2(d.y, d.x))


static func rotate_selection_degrees(project, degrees: float) -> void:
	if absf(degrees) < 1e-6 or not has_selected_segment_vertex(project):
		return
	project.validate()
	var c := get_centroid_of_selected_segment_vertices(project)
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			seg.position = _MathEx.rotate_point_around_pivot_2d(seg.position, c, degrees)
			var g = seg.generator
			match g.type:
				_Enums.SegmentGeneratorType.BEZIER:
					g.bezier_pivot1.position = _MathEx.rotate_point_around_pivot_2d(g.bezier_pivot1.position, c, degrees)
					if not g.bezier_quadratic:
						g.bezier_pivot2.position = _MathEx.rotate_point_around_pivot_2d(g.bezier_pivot2.position, c, degrees)
				_Enums.SegmentGeneratorType.SINE:
					g.sine_pivot1.position = _MathEx.rotate_point_around_pivot_2d(g.sine_pivot1.position, c, degrees)
				_:
					pass
	project.invalidate()
