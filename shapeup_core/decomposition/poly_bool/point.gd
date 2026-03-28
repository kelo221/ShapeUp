# PolyBool — Point (from Types.cs).
extends RefCounted
class_name Point

var x: float = 0.0
var y: float = 0.0

func _init(px: float = 0.0, py: float = 0.0) -> void:
	x = px
	y = py

static func from_vec2(v: Vector2):
	return new(v.x, v.y)

func to_vec2() -> Vector2:
	return Vector2(x, y)
