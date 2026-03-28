extends Node

## Ensures PolyBool (and nested types) register before any scene/script preloads poly_bool.gd in isolation.
const _poly_bool_root := preload("res://shapeup_core/decomposition/poly_bool/poly_bool_root.gd")
## Pulls `shape_project` + model types early so main scene and tooling see registered `class_name` types.
const _shapeup_serialization := preload("res://shapeup_core/shape_editor/shapeup_serialization.gd")
## Parsed before main scene scripts so `class_name` globals exist for Control entry scripts.
const _trenchbroom_grid := preload("res://shapeup_core/shape_editor/trenchbroom_grid.gd")


func _ready() -> void:
	pass
