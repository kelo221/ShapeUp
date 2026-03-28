## Convex decomposition (Mark Bayazit) — VelcroPhysics-derived; holes not supported (C# BayazitDecomposer).
extends RefCounted
class_name BayazitDecomposer

const MAX_POLYGON_VERTICES := 1024
const _STACK_DEPTH := 800
const _EPSILON := 1.192092896e-07


static func convex_partition(vertices: EditorPolygon) -> Array[EditorPolygon]:
	assert(vertices.vertices.size() >= 3)
	assert(vertices.is_counter_clockwise_2d())
	var depth_ref: Array = [_STACK_DEPTH]
	var result := _triangulate_polygon(vertices, depth_ref)
	if depth_ref[0] <= 0:
		push_error(
			"BayazitDecomposer: stack depth exhausted (thin/degenerate geometry or boolean singularity)."
		)
	return result


static func _triangulate_polygon(vertices: EditorPolygon, depth_ref: Array) -> Array[EditorPolygon]:
	var d: int = depth_ref[0]
	if d <= 0:
		return [vertices.duplicate_polygon()]
	depth_ref[0] = d - 1
	var list: Array[EditorPolygon] = []
	var lower_int := Vector2.ZERO
	var upper_int := Vector2.ZERO
	var lower_index := 0
	var upper_index := 0
	var lower_poly: EditorPolygon
	var upper_poly: EditorPolygon
	var n := vertices.vertices.size()
	for i in n:
		if _reflex(i, vertices):
			var upper_dist := INF
			var lower_dist := INF
			for j in n:
				var dist_ij: float
				var p: Vector2
				if _left(_at(i - 1, vertices), _at(i, vertices), _at(j, vertices)) and _right_on(
					_at(i - 1, vertices), _at(i, vertices), _at(j - 1, vertices)
				):
					p = _line_intersect_lines(
						_at(i - 1, vertices), _at(i, vertices), _at(j, vertices), _at(j - 1, vertices)
					)
					if _right(_at(i + 1, vertices), _at(i, vertices), p):
						dist_ij = _square_dist(_at(i, vertices), p)
						if dist_ij < lower_dist:
							lower_dist = dist_ij
							lower_int = p
							lower_index = j
				if _left(_at(i + 1, vertices), _at(i, vertices), _at(j + 1, vertices)) and _right_on(
					_at(i + 1, vertices), _at(i, vertices), _at(j, vertices)
				):
					p = _line_intersect_lines(
						_at(i + 1, vertices), _at(i, vertices), _at(j, vertices), _at(j + 1, vertices)
					)
					if _left(_at(i - 1, vertices), _at(i, vertices), p):
						dist_ij = _square_dist(_at(i, vertices), p)
						if dist_ij < upper_dist:
							upper_dist = dist_ij
							upper_index = j
							upper_int = p
			var ref_z: float = vertices.vertices[i].position.z
			if lower_index == (upper_index + 1) % n:
				var mid := (lower_int + upper_int) * 0.5
				lower_poly = _copy_range(i, upper_index, vertices)
				lower_poly.add_vertex(EditorVertex.new(Vector3(mid.x, mid.y, ref_z)))
				upper_poly = _copy_range(lower_index, i, vertices)
				upper_poly.add_vertex(EditorVertex.new(Vector3(mid.x, mid.y, ref_z)))
			else:
				var highest_score := 0.0
				var best_index := lower_index
				var ui := upper_index
				while ui < lower_index:
					ui += n
				for j in range(lower_index, ui + 1):
					if _can_see(i, j, vertices):
						var score := 1.0 / (_square_dist(_at(i, vertices), _at(j, vertices)) + 1.0)
						if _reflex(j, vertices):
							if (
								_right_on(_at(j - 1, vertices), _at(j, vertices), _at(i, vertices))
								and _left_on(_at(j + 1, vertices), _at(j, vertices), _at(i, vertices))
							):
								score += 3.0
							else:
								score += 2.0
						else:
							score += 1.0
						if score > highest_score:
							best_index = j
							highest_score = score
				lower_poly = _copy_range(i, best_index, vertices)
				upper_poly = _copy_range(best_index, i, vertices)
			list.append_array(_triangulate_polygon(lower_poly, depth_ref))
			list.append_array(_triangulate_polygon(upper_poly, depth_ref))
			return list
	if n > MAX_POLYGON_VERTICES:
		lower_poly = _copy_range(0, n / 2, vertices)
		upper_poly = _copy_range(n / 2, 0, vertices)
		list.append_array(_triangulate_polygon(lower_poly, depth_ref))
		list.append_array(_triangulate_polygon(upper_poly, depth_ref))
	else:
		list.append(vertices.duplicate_polygon())
	return list


static func _at(i: int, verts: EditorPolygon) -> Vector2:
	var s := verts.vertices.size()
	var idx: int
	if i < 0:
		idx = s - 1 - ((-i - 1) % s)
	else:
		idx = i % s
	var pv: Vector3 = verts.vertices[idx].position
	return Vector2(pv.x, pv.y)


static func _copy_range(i: int, j: int, verts: EditorPolygon) -> EditorPolygon:
	var jj := j
	var ii := i
	var s := verts.vertices.size()
	while jj < ii:
		jj += s
	var poly = EditorPolygon.new()
	for k in range(ii, jj + 1):
		var src: EditorVertex = _vertex_at_wrapped_index(k, verts)
		poly.add_vertex(
			EditorVertex.new(src.position, src.uv0, src.hidden, src.material)
		)
	return poly


static func _vertex_at_wrapped_index(i: int, verts: EditorPolygon) -> EditorVertex:
	var s := verts.vertices.size()
	var idx: int
	if i < 0:
		idx = s - 1 - ((-i - 1) % s)
	else:
		idx = i % s
	return verts.vertices[idx]


static func _can_see(i: int, j: int, vertices: EditorPolygon) -> bool:
	var n := vertices.vertices.size()
	if _reflex(i, vertices):
		if (
			_left_on(_at(i, vertices), _at(i - 1, vertices), _at(j, vertices))
			and _right_on(_at(i, vertices), _at(i + 1, vertices), _at(j, vertices))
		):
			return false
	else:
		if (
			_right_on(_at(i, vertices), _at(i + 1, vertices), _at(j, vertices))
			or _left_on(_at(i, vertices), _at(i - 1, vertices), _at(j, vertices))
		):
			return false
	if _reflex(j, vertices):
		if (
			_left_on(_at(j, vertices), _at(j - 1, vertices), _at(i, vertices))
			and _right_on(_at(j, vertices), _at(j + 1, vertices), _at(i, vertices))
		):
			return false
	else:
		if (
			_right_on(_at(j, vertices), _at(j + 1, vertices), _at(i, vertices))
			or _left_on(_at(j, vertices), _at(j - 1, vertices), _at(i, vertices))
		):
			return false
	for k in range(n):
		var k1 := (k + 1) % n
		if k1 == i or k == i or k1 == j or k == j:
			continue
		var hit: Variant = MathEx.line_intersect(
			_at(i, vertices),
			_at(j, vertices),
			_at(k, vertices),
			_at(k1, vertices),
			true,
			true
		)
		if hit != null:
			return false
	return true


static func _reflex(i: int, vertices: EditorPolygon) -> bool:
	return _right(_at(i - 1, vertices), _at(i, vertices), _at(i + 1, vertices))


static func _right(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return MathEx.area_vec2(a, b, c) < 0.0


static func _left(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return MathEx.area_vec2(a, b, c) > 0.0


static func _left_on(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return MathEx.area_vec2(a, b, c) >= 0.0


static func _right_on(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return MathEx.area_vec2(a, b, c) <= 0.0


static func _square_dist(a: Vector2, b: Vector2) -> float:
	var dx := b.x - a.x
	var dy := b.y - a.y
	return dx * dx + dy * dy


static func _line_intersect_lines(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> Vector2:
	var a1 := p2.y - p1.y
	var b1 := p1.x - p2.x
	var c1 := a1 * p1.x + b1 * p1.y
	var a2 := q2.y - q1.y
	var b2 := q1.x - q2.x
	var c2 := a2 * q1.x + b2 * q1.y
	var det := a1 * b2 - a2 * b1
	var i := Vector2.ZERO
	if not _float_equals(det, 0.0):
		i.x = (b2 * c1 - b1 * c2) / det
		i.y = (a1 * c2 - a2 * c1) / det
	return i


static func _float_equals(value1: float, value2: float) -> bool:
	return absf(value1 - value2) <= _EPSILON
