## Closed polygon with optional holes — mirrors C# Polygon (List<Vertex>) for ShapeUp decomposition / CSG.
extends RefCounted
class_name EditorPolygon

const _PBO := preload("res://shapeup_core/decomposition/polygon_boolean_operator.gd")
const _EditorVertex := preload("res://shapeup_core/decomposition/editor_vertex.gd")
const _VertexMaterial := preload("res://shapeup_core/decomposition/vertex_material.gd")
const _PolyBoolPolygon := preload("res://shapeup_core/decomposition/poly_bool/polygon.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")
const _PolyboolExtensions := preload("res://shapeup_core/decomposition/poly_bool/polybool_extensions.gd")

var vertices: Array = []
var holes: Array = []
var boolean_operator: _PBO.PolygonBooleanOperator = _PBO.PolygonBooleanOperator.UNION

#region 3D (Polygon.3D.cs)
var plane: Plane = Plane(Vector3.UP, 0.0)


func get_material_index() -> int:
	if vertices.is_empty():
		return 0
	return vertices[0].material.extrude


func with_front_material():
	var p = duplicate_polygon()
	if not p.vertices.is_empty():
		var v0 = p.vertices[0]
		var m: Variant = v0.material
		v0.material = _VertexMaterial.new(m.front, 0, 0)
		p.vertices[0] = v0
	return p


func with_back_material():
	var p = duplicate_polygon()
	if not p.vertices.is_empty():
		var v0 = p.vertices[0]
		var m: Variant = v0.material
		v0.material = _VertexMaterial.new(m.back, 0, 0)
		p.vertices[0] = v0
	return p


func recalculate_plane() -> Plane:
	var count := vertices.size()
	assert(count >= 3, "EditorPolygon.recalculate_plane: need at least 3 vertices")
	plane = Plane(vertices[0].position, vertices[1].position, vertices[2].position)
	if plane.normal.length_squared() < 1e-20 and count > 3:
		var pos1: Vector3 = vertices[0].position
		var pos2: Vector3 = vertices[1].position
		if pos1 != pos2:
			for i in range(3, count):
				plane = Plane(pos1, pos2, vertices[i].position)
				if plane.normal.length_squared() > 1e-20:
					break
		else:
			for i in range(1, count):
				if i + 2 >= count:
					break
				plane = Plane(vertices[i].position, vertices[i + 1].position, vertices[i + 2].position)
				if plane.normal.length_squared() > 1e-20:
					break
	assert(plane.normal.length_squared() > 1e-20, "EditorPolygon.recalculate_plane: zero normal")
	return plane


func get_flipped():
	var p = duplicate_polygon()
	p.reverse()
	return p


func rotate_by_quaternion(rotation: Quaternion) -> void:
	var count := vertices.size()
	for i in count:
		var v = vertices[i]
		v.position = rotation * v.position
		vertices[i] = v


func apply_sabre_csg_auto_uv0(offset: Vector2) -> void:
	var count := vertices.size()
	recalculate_plane()
	var n := plane.normal
	if n.length_squared() < 1e-20:
		return
	# C# uses: Quaternion.Inverse(Quaternion.LookRotation(plane.normal))
	# Unity's LookRotation aligns +Z with 'forward', while Godot's
	# Basis.looking_at aligns -Z with 'target'. Passing -n to looking_at
	# gives the same +Z alignment as Unity's LookRotation(n).
	var up := Vector3.UP
	if absf(n.dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	var look_basis := Basis.looking_at(-n, up)
	var inv_quat := look_basis.get_rotation_quaternion().inverse()
	for i in count:
		var v = vertices[i]
		var local: Vector3 = inv_quat * (v.position + Vector3(offset.x, offset.y, 0.0))
		v.uv0 = Vector2(local.x, local.y)
		vertices[i] = v


func apply_position_based_uv0(offset: Vector2) -> void:
	var count := vertices.size()
	if count < 1:
		return
	var min_x: float = vertices[0].position.x
	var max_x: float = min_x
	var min_y: float = vertices[0].position.y
	var max_y: float = min_y
	var min_z: float = vertices[0].position.z
	var max_z: float = min_z
	for i in range(1, count):
		var pos: Vector3 = vertices[i].position
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
		min_z = minf(min_z, pos.z)
		max_z = maxf(max_z, pos.z)
	var xspan: float = max_x - min_x
	var yspan: float = max_y - min_y
	var zspan: float = max_z - min_z
	var min_span := minf(xspan, minf(yspan, zspan))
	var is_y_normal := is_equal_approx(yspan, min_span)
	var is_z_normal := is_equal_approx(zspan, min_span)
	for i in count:
		var v = vertices[i]
		var u: float
		var vv: float
		if is_z_normal:
			u = offset.x + v.position.x
			vv = offset.y + v.position.y
		elif is_y_normal:
			u = offset.x + v.position.x
			vv = offset.y + v.position.z
		else:
			# X-normal case
			u = offset.x + v.position.y
			vv = offset.y + v.position.z
		v.uv0 = Vector2(u, vv)
		vertices[i] = v


func map_to_2d() -> Transform3D:
	recalculate_plane()
	var n := plane.normal
	var right: Vector3
	if absf(n.x) > absf(n.z):
		right = n.cross(Vector3(0, 0, 1))
	else:
		right = n.cross(Vector3(1, 0, 0))
	right = right.normalized()
	var backward := right.cross(n)
	var b := Basis(right, n, backward)
	var count := vertices.size()
	for p in range(count):
		var v = vertices[p]
		v.position = b.inverse() * v.position
		vertices[p] = v
	return Transform3D(b, Vector3.ZERO)


func map_to_3d(matrix: Transform3D) -> void:
	var b := matrix.basis
	var count := vertices.size()
	for p in range(count):
		var v = vertices[p]
		v.position = b * v.position
		vertices[p] = v


func split_non_planar4() -> Array:
	## Returns empty if not split; otherwise two triangles (C# Polygon[]).
	var count := vertices.size()
	if count != 4:
		return []
	var pl := Plane(vertices[0].position, vertices[1].position, vertices[2].position)
	var distances: Array[float] = []
	distances.resize(4)
	for i in 4:
		var d := pl.distance_to(vertices[i].position)
		if absf(d) < _MathEx.EPSILON_5:
			d = 0.0
		distances[i] = d
	if distances[0] == 0.0 and distances[1] == 0.0 and distances[2] == 0.0 and distances[3] == 0.0:
		return []
	var v0: Variant = vertices[0]
	var v1: Variant = vertices[1]
	var v2: Variant = vertices[2]
	var v3: Variant = vertices[3]
	var zero_one_two: Array = [_triangle_poly(v0, v1, v2), _triangle_poly(v0, v2, v3)]
	var one_two_three: Array = [_triangle_poly(v1, v2, v3), _triangle_poly(v0, v1, v3)]
	if distances[0] == 0.0 and distances[1] == 0.0 and distances[2] == 0.0:
		return one_two_three if distances[3] < 0.0 else zero_one_two
	if distances[1] == 0.0 and distances[2] == 0.0 and distances[3] == 0.0:
		return zero_one_two if distances[0] < 0.0 else one_two_three
	return []


static func _triangle_poly(a, b, c):
	var p = new()
	p.vertices.append(_dup_vertex(a))
	p.vertices.append(_dup_vertex(b))
	p.vertices.append(_dup_vertex(c))
	return p


static func _dup_vertex(v) :
	return _EditorVertex.new(v.position, v.uv0, v.hidden, v.material)

#endregion


#region Core list + 2D (Polygon.cs + Polygon.2D.cs)

func _init() -> void:
	pass


func add_vertex(v) -> void:
	vertices.append(v)


func get_vertex(i: int) :
	return vertices[i]


func set_vertex(i: int, v) -> void:
	vertices[i] = v


func get_vertex_count() -> int:
	return vertices.size()


func next_index(index: int) -> int:
	return 0 if index + 1 > vertices.size() - 1 else index + 1


func next_vertex(index: int) :
	return vertices[next_index(index)]


func previous_index(index: int) -> int:
	return vertices.size() - 1 if index - 1 < 0 else index - 1


func previous_vertex(index: int) :
	return vertices[previous_index(index)]


func translate(value: Vector3) -> void:
	var count := vertices.size()
	for i in count:
		var v = vertices[i]
		v.position += value
		vertices[i] = v


func scale_by(value: Vector3) -> void:
	var count := vertices.size()
	for i in count:
		var v = vertices[i]
		v.position = Vector3(v.position.x * value.x, v.position.y * value.y, v.position.z * value.z)
		vertices[i] = v


func scale(value: Vector3) -> void:
	scale_by(value)


func get_vertex_positions() -> PackedVector3Array:
	var count := vertices.size()
	var out := PackedVector3Array()
	out.resize(count)
	for i in count:
		out[i] = vertices[i].position
	return out


func get_uv0_array() -> PackedVector2Array:
	var count := vertices.size()
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		out[i] = vertices[i].uv0
	return out


func get_triangles(offset: int = 0) -> PackedInt32Array:
	var count := vertices.size()
	var tri_count := maxi(0, (count - 2) * 3)
	var triangles := PackedInt32Array()
	triangles.resize(tri_count)
	var index := 0
	var next := 1
	for i in range(2, count):
		triangles[index] = offset + next
		triangles[index + 1] = offset
		triangles[index + 2] = offset + i
		index += 3
		next = i
	return triangles


func reverse() -> void:
	vertices.reverse()


func clear_vertices() -> void:
	vertices.clear()


func is_counter_clockwise_2d() -> bool:
	if vertices.size() < 3:
		return false
	return get_signed_area_2d() > 0.0


func force_counter_clockwise_2d() -> void:
	if vertices.size() < 3:
		return
	if not is_counter_clockwise_2d():
		reverse()


func get_signed_area_2d() -> float:
	var count := vertices.size()
	if count < 3:
		return 0.0
	var area := 0.0
	for i in count:
		var j := (i + 1) % count
		var vi = vertices[i]
		var vj = vertices[j]
		area += vi.position.x * vj.position.y
		area -= vi.position.y * vj.position.x
	return area * 0.5


func contains_point_2d(point: Vector3, collinear_epsilon: float = 0.0) -> int:
	var count := vertices.size()
	if count < 3:
		return -1
	var wn := 0
	for i in count:
		var p1 = vertices[i]
		var p2 = vertices[next_index(i)]
		var edge: Vector3 = p2.position - p1.position
		var area: float = _MathEx.area2d_vec3(p1.position, p2.position, point)
		if absf(area) <= collinear_epsilon:
			var p2d := Vector2(point.x - p1.position.x, point.y - p1.position.y)
			var e2d := Vector2(edge.x, edge.y)
			if p2d.dot(e2d) >= 0.0 and Vector2(point.x - p2.position.x, point.y - p2.position.y).dot(e2d) <= 0.0:
				return 0
		if p1.position.y <= point.y:
			if p2.position.y > point.y and area > 0.0:
				wn += 1
		else:
			if p2.position.y <= point.y and area < 0.0:
				wn -= 1
	return -1 if wn == 0 else 1


func apply_xy_based_uv0(offset: Vector2) -> void:
	var count := vertices.size()
	for i in count:
		var v = vertices[i]
		v.uv0 = Vector2(offset.x + v.position.x, offset.y + v.position.y)
		vertices[i] = v


func get_vertices_2d() -> PackedVector2Array:
	var count := vertices.size()
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		var p: Vector3 = vertices[i].position
		out[i] = Vector2(p.x, p.y)
	return out


func is_simple() -> bool:
	var count := vertices.size()
	if count < 3:
		return false
	for i in count:
		var a1 = vertices[i]
		var a2 = next_vertex(i)
		for j in range(i + 1, count):
			var b1 = vertices[j]
			var b2 = next_vertex(j)
			if _MathEx.line_intersect2(
				Vector2(a1.position.x, a1.position.y),
				Vector2(a2.position.x, a2.position.y),
				Vector2(b1.position.x, b1.position.y),
				Vector2(b2.position.x, b2.position.y)
			) != null:
				return false
	return true


func get_aabb_2d() -> Rect2:
	var count := vertices.size()
	var lb := Vector2(INF, INF)
	var ub := Vector2(-INF, -INF)
	for i in count:
		var x: float = vertices[i].position.x
		lb.x = minf(lb.x, x)
		ub.x = maxf(ub.x, x)
		var y: float = vertices[i].position.y
		lb.y = minf(lb.y, y)
		ub.y = maxf(ub.y, y)
	return Rect2(lb, ub - lb)


func collinear_simplify(collinearity_tolerance: float = 0.0) -> void:
	var count := vertices.size()
	if count < 3:
		return
	var simplified: Array = []
	for i in count:
		var prev: Vector3 = previous_vertex(i).position
		var cur: Vector3 = vertices[i].position
		var nxt: Vector3 = next_vertex(i).position
		var p2 := Vector2(prev.x, prev.y)
		var c2 := Vector2(cur.x, cur.y)
		var n2 := Vector2(nxt.x, nxt.y)
		if _MathEx.is_collinear(p2, c2, n2, collinearity_tolerance):
			continue
		simplified.append(vertices[i])
	vertices.clear()
	for v in simplified:
		vertices.append(v)


func convex_contains(other) -> bool:
	var oc: int = other.vertices.size()
	for i in oc:
		var pos: Vector3 = other.vertices[i].position
		if contains_point_2d(pos) == -1:
			return false
	return true


func boundary_to_packed_xy() -> PackedVector2Array:
	return get_vertices_2d()


func to_polybool():
	return _PolyboolExtensions.to_polybool_polygon(boundary_to_packed_xy(), false)


func duplicate_polygon():
	var p = new()
	p.boolean_operator = boolean_operator
	for v in vertices:
		p.vertices.append(_dup_vertex(v))
	for h in holes:
		p.holes.append(h.duplicate_polygon())
	p.plane = plane
	return p

#endregion

#region 3D Extrusion (Polygon.3D.cs)

func extrude(distance: float) -> Array:
	var count := vertices.size()
	var results := []
	if count < 3:
		return results

	recalculate_plane()
	var n := plane.normal

	for i in range(count - 1):
		if vertices[i].hidden:
			continue
		var p = get_script().new()
		p.vertices.append(vertices[i])
		p.vertices.append(_EditorVertex.new(vertices[i].position + n * distance, vertices[i].uv0))
		p.vertices.append(_EditorVertex.new(vertices[i + 1].position + n * distance, vertices[i + 1].uv0))
		p.vertices.append(vertices[i + 1])
		results.append(p)

	if not vertices[count - 1].hidden:
		var p = get_script().new()
		p.vertices.append(vertices[count - 1])
		p.vertices.append(_EditorVertex.new(vertices[count - 1].position + n * distance, vertices[count - 1].uv0))
		p.vertices.append(_EditorVertex.new(vertices[0].position + n * distance, vertices[0].uv0))
		p.vertices.append(vertices[0])
		results.append(p)

	return results


func extrude_along_spline(spline: _MathEx.Spline3, precision: int) -> Array:
	var count := vertices.size()
	var results := []
	if count < 3:
		return results

	var last_poly = duplicate_polygon()
	var there := 0.0
	var tnext := 1.0 / float(precision)
	var avgforward := (spline.get_forward(there) + spline.get_forward(tnext)).normalized()

	var look_basis := Basis.looking_at(avgforward, spline.get_up(there), true)
	last_poly.rotate_by_quaternion(look_basis.get_rotation_quaternion())
	last_poly.translate(spline.get_point(there))

	results.append(last_poly.with_front_material())

	for p in range(1, precision + 1):
		var poly = duplicate_polygon()
		there = float(p) / float(precision)
		tnext = float(p + 1) / float(precision)
		avgforward = (spline.get_forward(there) + spline.get_forward(tnext)).normalized()

		look_basis = Basis.looking_at(avgforward, spline.get_up(there), true)
		poly.rotate_by_quaternion(look_basis.get_rotation_quaternion())
		poly.translate(spline.get_point(there))

		for i in range(count - 1):
			if poly.vertices[i].hidden:
				continue
			var ep = get_script().new()
			ep.vertices.append(last_poly.vertices[i])
			ep.vertices.append(poly.vertices[i])
			ep.vertices.append(poly.vertices[i + 1])
			ep.vertices.append(last_poly.vertices[i + 1])
			results.append(ep)

		if not poly.vertices[count - 1].hidden:
			var ep = get_script().new()
			ep.vertices.append(last_poly.vertices[count - 1])
			ep.vertices.append(poly.vertices[count - 1])
			ep.vertices.append(poly.vertices[0])
			ep.vertices.append(last_poly.vertices[0])
			results.append(ep)

		last_poly = poly

	last_poly.reverse()
	results.append(last_poly.with_back_material())

	return results


func extrude_brushes_along_spline(spline: _MathEx.Spline3, precision: int) -> Array:
	var count := vertices.size()
	var results := []
	if count < 3:
		return results

	var PolygonMeshClass = load("res://shapeup_core/decomposition/polygon_mesh.gd")

	var last_poly = duplicate_polygon()
	var there := 0.0
	var tnext := 1.0 / float(precision)
	var avgforward := (spline.get_forward(there) + spline.get_forward(tnext)).normalized()

	var look_basis := Basis.looking_at(avgforward, spline.get_up(there), true)
	last_poly.rotate_by_quaternion(look_basis.get_rotation_quaternion())
	last_poly.translate(spline.get_point(there))

	for p in range(1, precision + 1):
		var polys := []

		var poly = duplicate_polygon()
		there = float(p) / float(precision)
		tnext = float(p + 1) / float(precision)
		avgforward = (spline.get_forward(there) + spline.get_forward(tnext)).normalized()

		look_basis = Basis.looking_at(avgforward, spline.get_up(there), true)
		poly.rotate_by_quaternion(look_basis.get_rotation_quaternion())
		poly.translate(spline.get_point(there))

		polys.append(last_poly.with_back_material())

		var extruded_poly
		for i in range(count - 1):
			extruded_poly = get_script().new()
			extruded_poly.vertices.append(last_poly.vertices[i])
			extruded_poly.vertices.append(poly.vertices[i])
			extruded_poly.vertices.append(poly.vertices[i + 1])
			extruded_poly.vertices.append(last_poly.vertices[i + 1])

			var planar_polys = extruded_poly.split_non_planar4()
			if planar_polys.size() > 0:
				polys.append_array(planar_polys)
			else:
				polys.append(extruded_poly)

		extruded_poly = get_script().new()
		extruded_poly.vertices.append(last_poly.vertices[count - 1])
		extruded_poly.vertices.append(poly.vertices[count - 1])
		extruded_poly.vertices.append(poly.vertices[0])
		extruded_poly.vertices.append(last_poly.vertices[0])

		var planar_polys2 = extruded_poly.split_non_planar4()
		if planar_polys2.size() > 0:
			polys.append_array(planar_polys2)
		else:
			polys.append(extruded_poly)

		var back = poly.duplicate_polygon()
		back.reverse()
		polys.append(back.with_front_material())

		var brush = PolygonMeshClass.new()
		brush.polygons = polys
		brush.boolean_operator = boolean_operator
		results.append(brush)

		last_poly = poly

	return results

#endregion
