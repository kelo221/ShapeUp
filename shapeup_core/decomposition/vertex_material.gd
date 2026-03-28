## Per-vertex material indices for extrusion / mesh build (C# VertexMaterial struct).
extends RefCounted
class_name VertexMaterial

var extrude: int = 0
var front: int = 0
var back: int = 0


func _init(p_extrude: int = 0, p_front: int = 0, p_back: int = 0) -> void:
	extrude = p_extrude & 0xFF
	front = p_front & 0xFF
	back = p_back & 0xFF
