# PolyBool — CombinedSegmentLists (from Types.cs).
extends RefCounted
class_name CombinedSegmentLists

var combined = null
var inverted1: bool = false
var inverted2: bool = false

func _to_string() -> String:
	return "Count=%s" % (combined.segments.size() if combined != null else 0)
