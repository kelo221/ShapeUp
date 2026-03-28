## Collection of EditorPolygon (C# PolygonMesh). Use EditorPolygonMesh.PolygonMeshes for C# PolygonMeshes (inner class — one class_name per .gd file).
extends RefCounted
class_name EditorPolygonMesh

const _PBO = preload("res://shapeup_core/decomposition/polygon_boolean_operator.gd")

var polygons: Array = []
var boolean_operator: _PBO.PolygonBooleanOperator = _PBO.PolygonBooleanOperator.UNION
var bounds_2d: Rect2 = Rect2()


func _init(_p_capacity_hint: int = 0) -> void:
	pass


func size() -> int:
	return polygons.size()


func get_polygon(i: int):
	return polygons[i]


func set_polygon(i: int, p: Variant) -> void:
	polygons[i] = p


func append_polygon(p: Variant) -> void:
	polygons.append(p)


func append_polygons(from: Array) -> void:
	polygons.append_array(from)


func append_mesh(other: Variant) -> void:
	polygons.append_array(other.polygons)


## C# PolygonMesh.Combine
static func combine_meshes(mesh_list: Array):
	var result = new()
	for m in mesh_list:
		if m is EditorPolygonMesh:
			result.append_mesh(m)
	return result


func translate(value: Vector3) -> void:
	for p in polygons:
		p.translate(value)


func calculate_bounds_2d() -> Rect2:
	var count = polygons.size()
	if count == 0:
		bounds_2d = Rect2()
		return bounds_2d
	bounds_2d = polygons[0].get_aabb_2d()
	for i in range(1, count):
		bounds_2d = bounds_2d.merge(polygons[i].get_aabb_2d())
	return bounds_2d


func to_points() -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	for poly in polygons:
		for v in poly.vertices:
			pts.append(v.position)
	return pts


func to_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertex_lists = []
	var uv_lists = []
	var index_lists = []
	for i in 8:
		vertex_lists.append(PackedVector3Array())
		uv_lists.append(PackedVector2Array())
		index_lists.append(PackedInt32Array())

	var offsets = [0, 0, 0, 0, 0, 0, 0, 0]

	for poly in polygons:
		var m: int = poly.get_material_index()
		if m < 0 or m >= 8:
			m = 0
		
		var verts = poly.get_vertex_positions()
		var uvs = poly.get_uv0_array()
		var tris = poly.get_triangles(0)
		
		for idx in tris:
			index_lists[m].append(idx + offsets[m])
			
		vertex_lists[m].append_array(verts)
		uv_lists[m].append_array(uvs)
		
		offsets[m] += verts.size()

	for i in 8:
		if vertex_lists[i].is_empty():
			continue
			
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertex_lists[i]
		arrays[Mesh.ARRAY_TEX_UV] = uv_lists[i]
		arrays[Mesh.ARRAY_INDEX] = index_lists[i]
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var final_mesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	for i in mesh.get_surface_count():
		st.clear()
		st.create_from(mesh, i)
		st.generate_normals()
		st.generate_tangents()
		st.commit(final_mesh)

	return final_mesh


func to_planes() -> Array[Plane]:
	var count = polygons.size()
	var planes: Array[Plane] = []
	planes.resize(count)
	for i in count:
		var poly = polygons[i]
		poly.recalculate_plane()
		# Godot's Plane(p1,p2,p3) uses CLOCKWISE default, producing the opposite
		# normal from Unity's constructor. So Godot's recalculate_plane() already
		# gives the "outward" normal that C# only gets after .flipped — no flip needed.
		planes[i] = poly.plane
	return planes


func to_material_planes() -> Dictionary:
	var count = polygons.size()
	var planes: Array[Plane] = []
	planes.resize(count)
	var materials = PackedInt32Array()
	materials.resize(count)
	for i in count:
		var poly = polygons[i]
		poly.recalculate_plane()
		# Same as to_planes() — no flip needed in Godot.
		planes[i] = poly.plane
		materials[i] = poly.get_material_index()
	return { "planes": planes, "materials": materials }
