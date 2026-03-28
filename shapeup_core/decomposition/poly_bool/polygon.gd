# PolyBool — Polygon (from Types.cs).
extends RefCounted
class_name Polygon

## Array of PointList
var regions: Array = []
var inverted: bool = false

func _to_string() -> String:
	return "Regions=%s, Inverted=%s" % [regions.size(), inverted]
