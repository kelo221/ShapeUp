## Poly2Tri point cloud (from Sets/PointSet.cs).
class_name DelaunayPointSet
extends TriangulatableBase

var _source_points: Array[TriangulationPoint] = []
var _triangles: Array = []


func _init(pts: Array) -> void:
	for p in pts:
		_source_points.append(p)


func get_point_list() -> Array:
	return _source_points


func get_triangle_list() -> Array:
	return _triangles


func get_triangulation_mode() -> int:
	return TriangulationModeKind.TriangulationMode.UNCONSTRAINED


func add_triangle(t: DelaunayTriangle) -> void:
	_triangles.append(t)


func add_triangles(list: Array) -> void:
	for tri in list:
		_triangles.append(tri)


func clear_triangles() -> void:
	_triangles.clear()


func prepare_triangulation(tcx: TriangulationContext) -> void:
	_triangles.clear()
	for p in _source_points:
		tcx.points.append(p)
