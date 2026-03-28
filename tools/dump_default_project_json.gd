extends SceneTree

func _init() -> void:
	var ShapeProjectScript = load("res://shapeup_core/shape_editor/shape_project.gd")
	var Ser = load("res://shapeup_core/shape_editor/shapeup_serialization.gd")
	var p = ShapeProjectScript.new()
	var j: String = Ser.project_to_json(p)
	var dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var path := (dir + "/tests/fixtures/project_default_gd.json").simplify_path()
	var da := DirAccess.open(dir)
	if da:
		da.make_dir_recursive("tests/fixtures")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(j)
		f.close()
	else:
		push_error("dump_default_project_json: cannot write %s (%s)" % [path, FileAccess.get_open_error()])
	quit()
