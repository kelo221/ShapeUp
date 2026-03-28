# PolyBool — Segment (from Types.cs).
extends RefCounted
class_name Segment

const _SegmentFill := preload("res://shapeup_core/decomposition/poly_bool/segment_fill.gd")

var id: int = -1
var start = null
var end = null
var my_fill = null
var other_fill = null

func _init() -> void:
	my_fill = _SegmentFill.new()

func _to_string() -> String:
	return "Start=%s, End=%s, Fill=%s" % [start, end, my_fill]
