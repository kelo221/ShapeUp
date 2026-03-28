## PolyBool ↔ EditorPolygon helpers (C# PolyboolExtensions.ToPolygons → EditorPolygon list).
extends RefCounted
class_name EditorPolygonExtensions

const _PolyboolExtensions := preload("res://shapeup_core/decomposition/poly_bool/polybool_extensions.gd")


static func to_editor_polygons(poly: Polygon, poly_bool: PolyBool) -> Array[EditorPolygon]:
	var packed_regions: Array = _PolyboolExtensions.to_packed_regions(poly, poly_bool)
	var out: Array[EditorPolygon] = []
	for pr in packed_regions:
		if pr is PackedVector2Array:
			var ring := pr as PackedVector2Array
			var ep := EditorPolygon.new()
			for i in ring.size():
				var v2: Vector2 = ring[i]
				ep.add_vertex(EditorVertex.new(Vector3(v2.x, v2.y, 0.0)))
			out.append(ep)
	return out
