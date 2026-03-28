# PolyBool — Intersection (from Types.cs).
extends RefCounted
class_name Intersection

const _Point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")

var pt = null
var along_a: int = 0
var along_b: int = 0

static func empty():
	var i = new()
	i.pt = _Point.new()
	return i
