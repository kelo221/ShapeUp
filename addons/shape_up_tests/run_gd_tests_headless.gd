extends SceneTree

func _init() -> void:
	var runner = load("res://addons/shape_up_tests/shapeup_gd_tests.gd").new()
	var err: String = runner.run_all()
	if err != "":
		push_error("ShapeUp GD tests FAILED: " + err)
		quit(1)
	else:
		print("ShapeUp GD tests OK.")
		quit(0)
