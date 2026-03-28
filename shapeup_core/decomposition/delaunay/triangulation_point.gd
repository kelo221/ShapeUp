## Poly2Tri point (from TriangulationPoint.cs).
class_name TriangulationPoint
extends RefCounted

var x: float
var y: float
var edges: Array = []


func _init(px: float = 0.0, py: float = 0.0) -> void:
	x = px
	y = py


func get_xf() -> float:
	return x


func set_xf(v: float) -> void:
	x = v


func get_yf() -> float:
	return y


func set_yf(v: float) -> void:
	y = v


func has_edges() -> bool:
	return not edges.is_empty()


func add_edge(e) -> void:
	edges.append(e)


func _to_string() -> String:
	return "[%s,%s]" % [str(x), str(y)]
