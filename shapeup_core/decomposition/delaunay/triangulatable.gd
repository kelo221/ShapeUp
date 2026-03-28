## Poly2Tri triangulation target (from Triangulatable.cs).
class_name TriangulatableBase
extends RefCounted


func get_point_list() -> Array:
	return []


func get_triangle_list() -> Array:
	return []


func get_triangulation_mode() -> int:
	return TriangulationModeKind.TriangulationMode.UNCONSTRAINED


func prepare_triangulation(_tcx: TriangulationContext) -> void:
	pass


func add_triangle(_t: DelaunayTriangle) -> void:
	pass


func add_triangles(_list: Array) -> void:
	pass


func clear_triangles() -> void:
	pass
