## Fixed-size 3-slot array (from FixedArray3.cs).
class_name FixedArray3
extends RefCounted

var value0: Variant
var value1: Variant
var value2: Variant


func _init(v0: Variant = null, v1: Variant = null, v2: Variant = null) -> void:
	value0 = v0
	value1 = v1
	value2 = v2


func get_at(index: int) -> Variant:
	match index:
		0:
			return value0
		1:
			return value1
		2:
			return value2
		_:
			push_error("FixedArray3 index out of range")
			return null


func set_at(index: int, v: Variant) -> void:
	match index:
		0:
			value0 = v
		1:
			value1 = v
		2:
			value2 = v
		_:
			push_error("FixedArray3 index out of range")


func index_of(value: Variant) -> int:
	if value0 == value:
		return 0
	if value1 == value:
		return 1
	if value2 == value:
		return 2
	return -1


func clear() -> void:
	value0 = null
	value1 = null
	value2 = null


func clear_bool() -> void:
	value0 = false
	value1 = false
	value2 = false
