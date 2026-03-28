## Shape editor vertex (2D decomposition uses x/y from position; matches ShapeUp.Core Vertex).
extends RefCounted
class_name EditorVertex

const _VertexMaterialScript := preload("res://shapeup_core/decomposition/vertex_material.gd")

var position: Vector3 = Vector3.ZERO
var uv0: Vector2 = Vector2.ZERO
var hidden: bool = false
var material = null


func _init(
	p: Vector3 = Vector3.ZERO,
	uv: Vector2 = Vector2.ZERO,
	p_hidden: bool = false,
	p_material = null
) -> void:
	position = p
	uv0 = uv
	hidden = p_hidden
	material = p_material if p_material != null else _VertexMaterialScript.new()


func get_x() -> float:
	return position.x


func get_y() -> float:
	return position.y


func get_z() -> float:
	return position.z
