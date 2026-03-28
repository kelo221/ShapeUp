# PolyBool — PointList / region (from Types.cs).
extends RefCounted
class_name PointList

const _Point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")

var points: Array = []

func _init(_capacity: Variant = null) -> void:
	pass

func size() -> int:
	return points.size()

func append(p) -> void:
	points.append(p)

func insert_at(i: int, p) -> void:
	points.insert(i, p)

func remove_at(i: int) -> void:
	points.remove_at(i)

func reverse() -> void:
	points.reverse()

func append_points(other) -> void:
	for p in other.points:
		points.append(p)

func duplicate_points():
	var pl = new()
	for p in points:
		pl.append(_Point.new(p.x, p.y))
	return pl

func _to_string() -> String:
	return "Count=%s" % points.size()
