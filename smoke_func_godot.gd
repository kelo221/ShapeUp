extends Node

func _ready() -> void:
	var map := FuncGodotMap.new()
	map.name = "FuncGodotSmoke"
	map.local_map_file = "res://test_maps/shapeup_smoke.map"
	add_child(map)
	map.build()
	var ok := map.get_child_count() >= 1
	print("SHAPEUP_FUNC_GODOT_SMOKE ", "OK" if ok else "FAIL", " children=", map.get_child_count())
	get_tree().quit(0 if ok else 1)
