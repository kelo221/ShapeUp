@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_tool_menu_item("Run ShapeUp tests (GDScript)", _on_run_gd_tests)
	add_tool_menu_item("Run ShapeUp tests (dotnet test)", _on_run_tests)


func _exit_tree() -> void:
	remove_tool_menu_item("Run ShapeUp tests (GDScript)")
	remove_tool_menu_item("Run ShapeUp tests (dotnet test)")


func _on_run_gd_tests() -> void:
	var runner = load("res://addons/shape_up_tests/shapeup_gd_tests.gd").new()
	var err: String = runner.run_all()
	var dlg := AcceptDialog.new()
	dlg.title = "ShapeUp GDScript tests"
	dlg.dialog_text = ("All GDScript tests passed." if err == "" else ("FAILED:\n" + err))
	dlg.ok_button_text = "OK"
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered_ratio(0.35)
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.close_requested.connect(func(): dlg.queue_free())


func _on_run_tests() -> void:
	var project_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var sln: String = "%s/ShapeUp.sln" % project_dir
	if not FileAccess.file_exists(sln):
		push_error(
			"ShapeUp: ShapeUp.sln not found (C# stack removed). Use Project → Run ShapeUp tests (GDScript)."
		)
		return

	var output: Array = []
	var args: PackedStringArray = ["test", sln, "--nologo", "-v", "q"]
	# Godot 4+: execute() is blocking; args are path, arguments, output, read_stderr, open_console.
	var code := OS.execute("dotnet", args, output, true, false)
	var text := "\n".join(PackedStringArray(output))
	if text.is_empty():
		text = "(no output)"
	var summary := "dotnet test exited with code %d.\n\n%s" % [code, text]
	print("[ShapeUp tests] ", summary)
	var dlg := AcceptDialog.new()
	dlg.title = "ShapeUp tests"
	dlg.dialog_text = summary
	dlg.ok_button_text = "OK"
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered_ratio(0.5)
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.close_requested.connect(func(): dlg.queue_free())
