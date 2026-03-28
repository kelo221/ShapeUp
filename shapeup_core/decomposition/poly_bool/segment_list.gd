# PolyBool — SegmentList (from Types.cs).
extends RefCounted
class_name SegmentList

var segments: Array = []
var inverted: bool = false

func _init(_capacity: Variant = null) -> void:
	pass

func size() -> int:
	return segments.size()

func append(seg) -> void:
	segments.append(seg)

func _to_string() -> String:
	return "Count=%s" % segments.size()
