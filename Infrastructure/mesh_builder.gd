extends RefCounted
class_name MeshBuilder

const _EditorPolygon := preload("res://shapeup_core/decomposition/editor_polygon.gd")
const _EditorVertex := preload("res://shapeup_core/decomposition/editor_vertex.gd")
const _MathExClass := preload("res://shapeup_core/decomposition/su_math_ex.gd")


static func build_extruded_array_mesh(convex: EditorPolygonMesh, distance: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in convex.polygons:
		_add_extruded_polygon(st, poly, distance)
	st.generate_normals()
	return st.commit()


static func _add_extruded_polygon(st: SurfaceTool, poly: EditorPolygon, dz: float) -> void:
	var n := poly.vertices.size()
	if n < 3:
		return
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for i in n:
		var p: Vector3 = poly.vertices[i].position
		front.append(p)
		back.append(p + Vector3(0.0, 0.0, dz))
	# front fan
	var n0 := (front[2] - front[0]).cross(front[1] - front[0]).normalized()
	for i in range(2, n):
		_add_tri(st, front[0], front[i - 1], front[i], n0)
	# back fan (reverse winding)
	var n1 := (back[2] - back[0]).cross(back[1] - back[0]).normalized()
	for i2 in range(2, n):
		_add_tri(st, back[0], back[i2], back[i2 - 1], -n1)
	# sides
	for k in n - 1:
		var nb := (back[k] - front[k]).cross(front[k + 1] - front[k]).normalized()
		_add_tri(st, front[k], back[k], back[k + 1], nb)
		_add_tri(st, front[k], back[k + 1], front[k + 1], nb)
	var nb2 := (back[n - 1] - front[n - 1]).cross(front[0] - front[n - 1]).normalized()
	_add_tri(st, front[n - 1], back[n - 1], back[0], nb2)
	_add_tri(st, front[n - 1], back[0], front[0], nb2)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)


static func _dup_vertex_at(v, pos: Vector3):
	return _EditorVertex.new(pos, v.uv0, v.hidden, v.material)


static func _append_polygon_fan(st: SurfaceTool, poly: EditorPolygon, flip: bool) -> void:
	var nv := poly.vertices.size()
	if nv < 3:
		return
	poly.recalculate_plane()
	var nn := poly.plane.normal
	if flip:
		nn = -nn
	var v0: Vector3 = poly.vertices[0].position
	for i in range(2, nv):
		var v1: Vector3 = poly.vertices[i - 1].position
		var v2: Vector3 = poly.vertices[i].position
		if flip:
			_add_tri(st, v0, v2, v1, nn)
		else:
			_add_tri(st, v0, v1, v2, nn)


static func _add_side_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a)
	if n.length_squared() < 1e-20:
		return
	n = n.normalized()
	_add_tri(st, a, b, c, n)
	_add_tri(st, a, c, d, n)


## Two triangles with their own normals (C# may split non-planar quads).
static func _add_side_quad_per_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n1 := (b - a).cross(c - a)
	if n1.length_squared() < 1e-24:
		return
	n1 = n1.normalized()
	_add_tri(st, a, b, c, n1)
	var n2 := (c - a).cross(d - a)
	if n2.length_squared() < 1e-24:
		n2 = n1
	else:
		n2 = n2.normalized()
	_add_tri(st, a, c, d, n2)


## C# Polygon.GetTriangles fans as (next, 0, i). Unity CW front → Godot CCW uses (i, 0, next). Per-triangle normal fixes non-planar revolve caps.
static func _append_polygon_fan_per_tri_godot(st: SurfaceTool, poly: EditorPolygon) -> void:
	var nv := poly.vertices.size()
	if nv < 3:
		return
	var v0: Vector3 = poly.vertices[0].position
	var next := 1
	for i in range(2, nv):
		var vn: Vector3 = poly.vertices[next].position
		var vi: Vector3 = poly.vertices[i].position
		var tri_n: Vector3 = (v0 - vi).cross(vn - vi)
		if tri_n.length_squared() < 1e-24:
			next = i
			continue
		tri_n = tri_n.normalized()
		_add_tri(st, vi, v0, vn, tri_n)
		next = i


static func _commit_mesh(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


static func build_polygon_cap_array_mesh(convex: EditorPolygonMesh, double_sided: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for src in convex.polygons:
		if src.vertices.size() < 3:
			continue
		var fp: EditorPolygon = src.duplicate_polygon()
		fp.apply_xy_based_uv0(Vector2(0.5, 0.5))
		_append_polygon_fan(st, fp.with_front_material(), false)
		if double_sided:
			var bp: EditorPolygon = src.duplicate_polygon()
			bp.reverse()
			bp.apply_xy_based_uv0(Vector2(0.5, 0.5))
			_append_polygon_fan(st, bp.with_back_material(), false)
	return _commit_mesh(st)


static func _extrude_polygon_along_spline_once(src: EditorPolygon, spline: _MathExClass.Spline3, precision: int) -> Array:
	var count := src.vertices.size()
	var results: Array = []
	if count < 3:
		return results
	var last_poly: EditorPolygon = src.duplicate_polygon()
	var there0 := 0.0
	var tnext0 := 1.0 / float(precision)
	var f0a: Vector3 = spline.get_forward(there0)
	var f0b: Vector3 = spline.get_forward(tnext0)
	var avg0 := (f0a + f0b)
	if avg0.length_squared() < 1e-16:
		avg0 = Vector3(0, 0, -1)
	else:
		avg0 = avg0.normalized()
	var up0 := spline.get_up(there0)
	var basis0 := Basis.looking_at(avg0, up0 if up0.length_squared() > 1e-16 else Vector3.UP, true)
	last_poly.rotate_by_quaternion(basis0.get_rotation_quaternion())
	last_poly.translate(spline.get_point(there0))
	results.append(last_poly.with_front_material())
	for p in range(1, precision + 1):
		var poly: EditorPolygon = src.duplicate_polygon()
		var there := float(p) / float(precision)
		var tnext := float(p + 1) / float(precision)
		var fa: Vector3 = spline.get_forward(there)
		var fb: Vector3 = spline.get_forward(tnext)
		var avg := (fa + fb)
		if avg.length_squared() < 1e-16:
			avg = Vector3(0, 0, -1)
		else:
			avg = avg.normalized()
		var up_at := spline.get_up(there)
		var basis := Basis.looking_at(avg, up_at if up_at.length_squared() > 1e-16 else Vector3.UP, true)
		poly.rotate_by_quaternion(basis.get_rotation_quaternion())
		poly.translate(spline.get_point(there))
		for i in range(count - 1):
			if poly.vertices[i].hidden:
				continue
			var qpoly := _EditorPolygon.new()
			qpoly.vertices.append(_EditorPolygon._dup_vertex(last_poly.vertices[i]))
			qpoly.vertices.append(_EditorPolygon._dup_vertex(poly.vertices[i]))
			qpoly.vertices.append(_EditorPolygon._dup_vertex(poly.vertices[i + 1]))
			qpoly.vertices.append(_EditorPolygon._dup_vertex(last_poly.vertices[i + 1]))
			results.append(qpoly)
		if not poly.vertices[count - 1].hidden:
			var q2 := _EditorPolygon.new()
			q2.vertices.append(_EditorPolygon._dup_vertex(last_poly.vertices[count - 1]))
			q2.vertices.append(_EditorPolygon._dup_vertex(poly.vertices[count - 1]))
			q2.vertices.append(_EditorPolygon._dup_vertex(poly.vertices[0]))
			q2.vertices.append(_EditorPolygon._dup_vertex(last_poly.vertices[0]))
			results.append(q2)
		last_poly = poly
	last_poly.reverse()
	results.append(last_poly.with_back_material())
	return results


static func build_spline_extruded_array_mesh(convex: EditorPolygonMesh, spline_pts: PackedVector3Array, precision: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if spline_pts.size() < 3:
		return st.commit()
	var spline := _MathExClass.Spline3.new(spline_pts)
	var prec := maxi(2, precision)
	for src in convex.polygons:
		if src.vertices.size() < 3:
			continue
		src.apply_xy_based_uv0(Vector2(0.5, 0.5))
		var pieces: Array = _extrude_polygon_along_spline_once(src, spline, prec)
		for poly in pieces:
			if poly is EditorPolygon:
				poly.apply_position_based_uv0(Vector2(0.5, 0.5))
				_append_polygon_fan(st, poly, false)
	return _commit_mesh(st)


static func build_linear_staircase_array_mesh(convex: EditorPolygonMesh, precision: int, distance: float, height: float, sloped: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prec := maxi(1, precision)
	var sloped_h := Vector3.ZERO
	var h := height
	if sloped:
		prec = 1
		sloped_h = Vector3(0.0, height, 0.0)
	h -= sloped_h.y
	for j in range(prec):
		var forward := Vector3(0.0, 0.0, (float(j) / float(prec)) * distance)
		var forward_next := Vector3(0.0, 0.0, (float(j + 1) / float(prec)) * distance)
		var height_off := Vector3.ZERO
		if prec >= 2:
			height_off.y = (float(j) / float(prec - 1)) * h
		for poly_src in convex.polygons:
			if poly_src.vertices.size() < 3:
				continue
			var poly: EditorPolygon = poly_src.duplicate_polygon()
			poly.translate(forward + height_off)
			poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
			var next_poly: EditorPolygon = poly_src.duplicate_polygon()
			next_poly.translate(forward_next + height_off + sloped_h)
			next_poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
			var pvc := poly.vertices.size()
			if h == 0.0 or sloped:
				if j == 0:
					_append_polygon_fan(st, poly.with_front_material(), false)
				if j == prec - 1:
					var back_w: EditorPolygon = next_poly.get_flipped()
					back_w.apply_xy_based_uv0(Vector2(0.5, 0.5))
					_append_polygon_fan(st, back_w.with_back_material(), false)
			else:
				_append_polygon_fan(st, poly.with_front_material(), false)
				var back2: EditorPolygon = next_poly.get_flipped()
				back2.apply_xy_based_uv0(Vector2(0.5, 0.5))
				_append_polygon_fan(st, back2.with_back_material(), false)
			for k in range(pvc - 1):
				if poly.vertices[k].hidden:
					continue
				_add_side_quad_per_tri(
					st,
					poly.vertices[k].position,
					next_poly.vertices[k].position,
					next_poly.vertices[k + 1].position,
					poly.vertices[k + 1].position
				)
			if pvc > 0 and not poly.vertices[pvc - 1].hidden:
				_add_side_quad_per_tri(
					st,
					poly.vertices[pvc - 1].position,
					next_poly.vertices[pvc - 1].position,
					next_poly.vertices[0].position,
					poly.vertices[0].position
				)
	# Same as revolve chopped: many coincident verts from stacked brushes; generate_normals() averages and kills side lighting.
	return st.commit()


static func build_scaled_extrude_array_mesh(
	convex: EditorPolygonMesh,
	distance: float,
	begin_scale: Vector2,
	end_scale: Vector2,
	offset: Vector2
) -> ArrayMesh:
	if begin_scale.x == 0.0 and begin_scale.y == 0.0 and end_scale.x == 0.0 and end_scale.y == 0.0:
		var empty_st := SurfaceTool.new()
		empty_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		return empty_st.commit()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly_src in convex.polygons:
		if poly_src.vertices.size() < 3:
			continue
		var poly: EditorPolygon = poly_src.duplicate_polygon()
		poly.scale(Vector3(begin_scale.x, begin_scale.y, 1.0))
		poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
		var next_poly: EditorPolygon = poly_src.duplicate_polygon()
		next_poly.scale(Vector3(end_scale.x, end_scale.y, 1.0))
		next_poly.translate(Vector3(offset.x, offset.y, distance))
		next_poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
		var pvc := poly.vertices.size()
		if begin_scale.x != 0.0 and begin_scale.y != 0.0:
			_append_polygon_fan(st, poly.with_front_material(), false)
		if end_scale.x != 0.0 and end_scale.y != 0.0:
			var back: EditorPolygon = next_poly.get_flipped()
			back.apply_xy_based_uv0(Vector2(0.5, 0.5))
			_append_polygon_fan(st, back.with_back_material(), false)
		for k in range(pvc - 1):
			if poly.vertices[k].hidden:
				continue
			_add_side_quad(
				st,
				poly.vertices[k].position,
				next_poly.vertices[k].position,
				next_poly.vertices[k + 1].position,
				poly.vertices[k + 1].position
			)
		if pvc > 0 and not poly.vertices[pvc - 1].hidden:
			_add_side_quad(
				st,
				poly.vertices[pvc - 1].position,
				next_poly.vertices[pvc - 1].position,
				next_poly.vertices[0].position,
				poly.vertices[0].position
			)
	return _commit_mesh(st)


static func _circle_position(radius: float, t: float) -> Vector3:
	var u := fposmod(t, 1.0)
	return Vector3(sin(u * TAU) * radius, 0.0, cos(u * TAU) * radius)


static func build_revolve_extruded_array_mesh(
	convex: EditorPolygonMesh,
	precision: int,
	degrees: float,
	radius: float,
	height: float,
	sloped: bool
) -> ArrayMesh:
	convex.calculate_bounds_2d()
	var b := convex.bounds_2d
	var project_center_offset := (
		Vector3(-(b.position.x + b.size.x), 0.0, 0.0)
		if degrees > 0.0
		else Vector3(-b.position.x, 0.0, 0.0)
	)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prec := maxi(2, precision)
	var deg_abs := absf(degrees)
	var sloped_h := Vector3.ZERO
	var h := height
	if sloped and prec >= 2:
		sloped_h.y = height / float(prec)
	h -= sloped_h.y
	var pivot := Vector3(radius if degrees > 0.0 else -radius, 0.0, 0.0)
	for src in convex.polygons:
		if src.vertices.size() < 3:
			continue
		src.apply_xy_based_uv0(Vector2(0.5, 0.5))
		for j in range(prec):
			var shifted: EditorPolygon = src.duplicate_polygon()
			shifted.translate(project_center_offset)
			var pvc := shifted.vertices.size()
			var base_pos: Array = []
			for vi in range(pvc):
				base_pos.append(shifted.vertices[vi].position)
			var poly: EditorPolygon = shifted.duplicate_polygon()
			var next_poly: EditorPolygon = shifted.duplicate_polygon()
			for vi in range(pvc):
				var hoff := Vector3.ZERO
				if prec >= 2:
					hoff.y = (float(j) / float(prec - 1)) * h
				var ang_j := lerpf(0.0, degrees, float(j) / float(prec))
				var ang_n := lerpf(0.0, degrees, float(j + 1) / float(prec))
				var pj: Vector3 = hoff + _MathExClass.rotate_point_around_pivot_3d(base_pos[vi], pivot, Vector3(0.0, ang_j, 0.0))
				var pn: Vector3 = hoff + sloped_h + _MathExClass.rotate_point_around_pivot_3d(base_pos[vi], pivot, Vector3(0.0, ang_n, 0.0))
				poly.vertices[vi] = _dup_vertex_at(shifted.vertices[vi], pj)
				next_poly.vertices[vi] = _dup_vertex_at(shifted.vertices[vi], pn)
			var cap_partial := (deg_abs != 360.0 and (h == 0.0 or sloped)) or (deg_abs == 360.0 and (h != 0.0 and sloped))
			if cap_partial:
				if j == 0:
					_append_polygon_fan(st, poly.with_front_material(), false)
				if j == prec - 1:
					var bk: EditorPolygon = next_poly.get_flipped()
					bk.apply_xy_based_uv0(Vector2(0.5, 0.5))
					_append_polygon_fan(st, bk.with_back_material(), false)
			elif is_equal_approx(deg_abs, 360.0) and h == 0.0:
				pass
			else:
				_append_polygon_fan(st, poly.with_front_material(), false)
				var bk2: EditorPolygon = next_poly.get_flipped()
				bk2.apply_xy_based_uv0(Vector2(0.5, 0.5))
				_append_polygon_fan(st, bk2.with_back_material(), false)
			for k in range(pvc - 1):
				if poly.vertices[k].hidden:
					continue
				_add_side_quad(
					st,
					poly.vertices[k].position,
					next_poly.vertices[k].position,
					next_poly.vertices[k + 1].position,
					poly.vertices[k + 1].position
				)
			if pvc > 0 and not poly.vertices[pvc - 1].hidden:
				_add_side_quad(
					st,
					poly.vertices[pvc - 1].position,
					next_poly.vertices[pvc - 1].position,
					next_poly.vertices[0].position,
					poly.vertices[0].position
				)
	st.generate_normals()
	var mesh := st.commit()
	return _translate_array_mesh(mesh, -project_center_offset)


static func _translate_array_mesh(mesh: ArrayMesh, delta: Vector3) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var out := ArrayMesh.new()
	for si in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var v2 := verts.duplicate()
		for i in range(v2.size()):
			v2[i] += delta
		arrays[Mesh.ARRAY_VERTEX] = v2
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), arrays)
	return out


static func build_revolve_chopped_array_mesh(chopped_slices: Array, degrees: float, extrude_distance: float) -> ArrayMesh:
	if chopped_slices.is_empty():
		var empty_st := SurfaceTool.new()
		empty_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		return empty_st.commit()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var precision := chopped_slices.size()
	var union_bounds := Rect2()
	var first := true
	for slice in chopped_slices:
		if slice is EditorPolygonMesh:
			slice.calculate_bounds_2d()
			if first:
				union_bounds = slice.bounds_2d
				first = false
			else:
				union_bounds = union_bounds.merge(slice.bounds_2d)
	var project_center_offset := Vector3(union_bounds.position.x, 0.0, 0.0)
	var circ_signed := union_bounds.size.x * signf(degrees)
	var t_part := fposmod(absf(degrees) / 360.0, 1.0)
	var inner_r: float = circ_signed / TAU if is_zero_approx(t_part) else circ_signed / (t_part * TAU)
	var outer_r: float = inner_r + extrude_distance * signf(degrees)
	var inner_circumference: float = inner_r * TAU
	var step_x := union_bounds.size.x / float(precision)
	for i in range(precision):
		var slice_mesh = chopped_slices[i]
		if not slice_mesh is EditorPolygonMesh:
			continue
		var convex: EditorPolygonMesh = slice_mesh
		var s1 := float(i) * step_x
		var s2 := float(i + 1) * step_x
		var t1: float = 0.0
		var t2: float = 1.0
		if absf(inner_circumference) > 1e-8:
			t1 = s1 / inner_circumference
			t2 = s2 / inner_circumference
		var ip1 := _circle_position(inner_r, t1) + project_center_offset
		var ip2 := _circle_position(inner_r, t2) + project_center_offset
		var op1 := _circle_position(outer_r, t1) + project_center_offset
		var op2 := _circle_position(outer_r, t2) + project_center_offset
		for src in convex.polygons:
			if src.vertices.size() < 3:
				continue
			var poly: EditorPolygon = src.duplicate_polygon()
			poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
			poly.translate(-project_center_offset)
			var back_poly: EditorPolygon = src.duplicate_polygon()
			var pvc := poly.vertices.size()
			for vi in range(pvc):
				var vx: float = poly.vertices[vi].position.x
				var u := inverse_lerp(s1, s2, vx) if absf(s2 - s1) > 1e-8 else 0.5
				var inner_pos := Vector3(lerpf(ip1.x, ip2.x, u), poly.vertices[vi].position.y, lerpf(ip1.z, ip2.z, u))
				var outer_pos := Vector3(lerpf(op1.x, op2.x, u), poly.vertices[vi].position.y, lerpf(op1.z, op2.z, u))
				inner_pos.z -= inner_r
				outer_pos.z -= inner_r
				if degrees < 0.0:
					inner_pos.z += extrude_distance
					outer_pos.z += extrude_distance
				poly.vertices[vi] = _dup_vertex_at(poly.vertices[vi], inner_pos)
				back_poly.vertices[vi] = _dup_vertex_at(poly.vertices[vi], outer_pos)
			# Caps: C# order + per-triangle normals (chopped caps are non-planar). Do not combine get_flipped() with _append_polygon_fan(..., true) — double flip.
			if degrees < 0.0:
				_append_polygon_fan_per_tri_godot(st, poly.get_flipped().with_front_material())
				_append_polygon_fan_per_tri_godot(st, back_poly.with_back_material())
			else:
				_append_polygon_fan_per_tri_godot(st, poly.with_front_material())
				_append_polygon_fan_per_tri_godot(st, back_poly.get_flipped().with_back_material())
			for k in range(pvc - 1):
				if poly.vertices[k].hidden:
					continue
				if degrees < 0.0:
					_add_side_quad_per_tri(
						st,
						poly.vertices[k + 1].position,
						back_poly.vertices[k + 1].position,
						back_poly.vertices[k].position,
						poly.vertices[k].position
					)
				else:
					_add_side_quad_per_tri(
						st,
						poly.vertices[k].position,
						back_poly.vertices[k].position,
						back_poly.vertices[k + 1].position,
						poly.vertices[k + 1].position
					)
			if pvc > 0 and not poly.vertices[pvc - 1].hidden:
				if degrees < 0.0:
					_add_side_quad_per_tri(
						st,
						poly.vertices[0].position,
						back_poly.vertices[0].position,
						back_poly.vertices[pvc - 1].position,
						poly.vertices[pvc - 1].position
					)
				else:
					_add_side_quad_per_tri(
						st,
						poly.vertices[pvc - 1].position,
						back_poly.vertices[pvc - 1].position,
						back_poly.vertices[0].position,
						poly.vertices[0].position
					)
	# Explicit per-triangle normals; global smooth pass flips/warps lighting on non-planar chopped geometry.
	return st.commit()
