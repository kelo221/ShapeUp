# PolyBool — SegmentFill (from Types.cs).
extends RefCounted
class_name SegmentFill

var above: bool = false
## null means unset (C# bool? below).
var below: Variant = null

func _to_string() -> String:
	return "[Above=%s, Below=%s]" % [above, below]
