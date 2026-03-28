## Poly2Tri polygon collection (from Polygon/PolygonSet.cs).
class_name DelaunayPolygonSet
extends RefCounted

var _polygons: Array[DelaunayPolygon] = []


func _init(poly: DelaunayPolygon = null) -> void:
	if poly != null:
		_polygons.append(poly)


func get_polygons() -> Array[DelaunayPolygon]:
	return _polygons


func add(p: DelaunayPolygon) -> void:
	_polygons.append(p)
