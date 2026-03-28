extends Control

const _ShapeExtrusionTarget := preload("res://shapeup_core/shape_editor/shape_extrusion_target.gd")
const _ShapeProject := preload("res://shapeup_core/shape_editor/shape_project.gd")
const _ShapeShape := preload("res://shapeup_core/shape_editor/shape_shape.gd")
const _ShapeSegmentGenerator := preload("res://shapeup_core/shape_editor/shape_segment_generator.gd")
const _ProjectUndoStack := preload("res://features/editor_2d/project_undo_stack.gd")
const _ShapeEditor2DView := preload("res://features/editor_2d/shape_editor_2d_view.gd")
const _PreviewCameraOrbit := preload("res://features/editor_2d/preview_camera_orbit.gd")
const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")

const M_FILE_OPEN := 100
const M_FILE_SAVE := 101
const M_FILE_COPY_BRUSHES := 102
const M_FILE_COPY_GODOT_MAP := 103
const M_EDIT_UNDO := 200
const M_EDIT_REDO := 201
const M_EDIT_SELECT_ALL := 210
const M_EDIT_CLEAR_SEL := 211
const M_EDIT_INVERT_SEL := 212
const M_EDIT_FLIP_H := 220
const M_EDIT_FLIP_V := 221
const M_EDIT_SNAP_SEL := 222
const M_EDGE_TO_BEZIER := 300
const M_EDGE_TO_LINEAR := 301
const M_EDGE_ARCH := 310
const M_EDGE_SINE := 311
const M_EDGE_REPEAT := 312
const M_EDGE_APPLY_GEN := 320
const M_EDGE_APPLY_PROPS := 321
const M_SHAPE_ADD := 400
const M_VIEW_TOP := 500
const M_VIEW_FRONT := 501
const M_VIEW_RIGHT := 502
const M_VIEW_ISO := 503
const M_VIEW_BG := 504
const M_TOOLS_CIRCLE := 600

const _ICON_DIR := "res://Features/Editor2D/icons/"
const _TOOL_ORDER: Array[int] = [
	_Enums.Editor2DTool.SELECT,
	_Enums.Editor2DTool.MOVE,
	_Enums.Editor2DTool.ROTATE,
	_Enums.Editor2DTool.DRAW,
	_Enums.Editor2DTool.CUT,
	_Enums.Editor2DTool.MEASURE,
]

const _MODE_NAMES: Array[String] = [
	"Polygon",
	"FixedExtrude",
	"SplineExtrude",
	"RevolveExtrude",
	"LinearStaircase",
	"ScaledExtrude",
	"RevolveChopped",
]

var _extrusion
var _undo
var _view
var _preview_mesh: MeshInstance3D
var _preview_cam: Camera3D
var _preview_orbit: Node3D
var _status_label: Label
var _snap_spin: SpinBox
var _snap_toggle: CheckButton
var _fixed_distance: SpinBox
var _mode_option: OptionButton
var _bezier_detail_spin: SpinBox
var _group_name: LineEdit
var _chk_click_edge_add: CheckButton
var _tool_palette_buttons: Array = []
var _preview_auto_frame_once: bool = true
var _preview_frame_oblique: bool = false

var _panel_polygon: Control
var _panel_fixed: Control
var _panel_spline: Control
var _panel_revolve: Control
var _panel_stair: Control
var _panel_scaled: Control
var _panel_chopped: Control
var _extr_wrap_polygon: Control
var _extr_wrap_fixed: Control
var _extr_wrap_spline: Control
var _extr_wrap_revolve: Control
var _extr_wrap_stair: Control
var _extr_wrap_scaled: Control
var _extr_wrap_chopped: Control
var _poly_double_sided: CheckButton
var _spline_rows_host: VBoxContainer
var _spin_spline_precision: SpinBox
var _spin_rev_prec: SpinBox
var _spin_rev_deg: SpinBox
var _spin_rev_rad: SpinBox
var _spin_rev_h: SpinBox
var _chk_rev_sloped: CheckButton
var _spin_stair_prec: SpinBox
var _spin_stair_dist: SpinBox
var _spin_stair_h: SpinBox
var _chk_stair_sloped: CheckButton
var _spin_scaled_dist: SpinBox
var _spin_scale_fx: SpinBox
var _spin_scale_fy: SpinBox
var _spin_scale_bx: SpinBox
var _spin_scale_by: SpinBox
var _spin_scale_ox: SpinBox
var _spin_scale_oy: SpinBox
var _spin_chop_prec: SpinBox
var _spin_chop_deg: SpinBox
var _spin_chop_dist: SpinBox

var _circle_dialog: AcceptDialog
var _circle_detail_spin: SpinBox
var _circle_diameter_spin: SpinBox

var _file_bg_image: FileDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_extrusion = _ShapeExtrusionTarget.new()
	_undo = _ProjectUndoStack.new()
	_extrusion.spline_control_points = [
		Vector3.ZERO, Vector3(0, 0, 0.5), Vector3(0.5, 0, 0.5),
	]

	_view = _ShapeEditor2DView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.project = _extrusion.project
	_view.snap_increment = TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(0.125)
	_view.tooltip_text = "Wheel: zoom • Ctrl+wheel: finer/coarser grid • MMB: pan • Box: select • Drag vertex/edge: move • Dbl-click edge: add vertex • Del: remove vertices"
	_view.snap_increment_adjusted.connect(_on_viewport_snap_adjusted)
	_view.before_project_mutation.connect(_on_before_viewport_mutation)
	_view.project_changed.connect(_on_project_edited)
	
	_view.edge_menu_bezier = func():
		_view.convert_selected_edge_to_bezier()
		_on_bezier_detail_changed(float(_bezier_detail_spin.value))
	_view.edge_menu_linear = func(): _view.convert_selected_edge_to_linear()
	_view.edge_menu_arch = func(): _toggle_selected_edges(_Enums.SegmentGeneratorType.ARCH)
	_view.edge_menu_sine = func(): _toggle_selected_edges(_Enums.SegmentGeneratorType.SINE)
	_view.edge_menu_repeat = func(): _toggle_selected_edges(_Enums.SegmentGeneratorType.REPEAT)
	_view.edge_menu_apply_generators = func(): _on_edge_menu(M_EDGE_APPLY_GEN)
	_view.edge_menu_apply_props = func(): _on_edge_menu(M_EDGE_APPLY_PROPS)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var menu_bar := MenuBar.new()
	root.add_child(menu_bar)
	_build_all_menus(menu_bar)

	var icon_toolbar := HBoxContainer.new()
	icon_toolbar.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(icon_toolbar)
	_build_icon_toolbar(icon_toolbar)

	root.add_child(_build_extrusion_inspector())

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	var tool_palette := _build_tool_palette()
	main_row.add_child(tool_palette)


	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.add_child(split)

	split.add_child(_view)

	var preview_col := _build_preview_panel()
	split.add_child(preview_col)

	var status := HBoxContainer.new()
	status.custom_minimum_size.y = 26
	root.add_child(status)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_child(_status_label)

	_preview_auto_frame_once = true
	_set_viewport_tool(_Enums.Editor2DTool.SELECT)
	_rebuild_spline_rows()
	_update_extrusion_panel_visibility()
	_setup_aux_dialogs()
	_setup_file_dialogs()
	refresh_preview()


func _shortcut_key(key: Key, ctrl: bool = false, shift: bool = false) -> Shortcut:
	var sc := Shortcut.new()
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	sc.events = [ev]
	return sc


func _build_all_menus(bar: MenuBar) -> void:
	var file_menu := PopupMenu.new()
	file_menu.name = "File"
	bar.add_child(file_menu)
	file_menu.add_item("Open…", M_FILE_OPEN)
	file_menu.set_item_shortcut(0, _shortcut_key(KEY_O, true), true)
	file_menu.add_item("Save As…", M_FILE_SAVE)
	file_menu.set_item_shortcut(1, _shortcut_key(KEY_S, true, true), true)
	file_menu.add_separator()
	file_menu.add_item("Copy TrenchBroom Brushes", M_FILE_COPY_BRUSHES)
	file_menu.add_item("Copy .map for Godot", M_FILE_COPY_GODOT_MAP)
	file_menu.id_pressed.connect(_on_file_menu)

	var edit_menu := PopupMenu.new()
	edit_menu.name = "Edit"
	bar.add_child(edit_menu)
	edit_menu.add_item("Undo", M_EDIT_UNDO)
	edit_menu.set_item_shortcut(0, _shortcut_key(KEY_Z, true), true)
	edit_menu.add_item("Redo", M_EDIT_REDO)
	edit_menu.set_item_shortcut(1, _shortcut_key(KEY_Y, true), true)
	edit_menu.add_separator()
	edit_menu.add_item("Select All", M_EDIT_SELECT_ALL)
	edit_menu.set_item_shortcut(3, _shortcut_key(KEY_A, true), true)
	edit_menu.add_item("Clear Selection", M_EDIT_CLEAR_SEL)
	edit_menu.add_item("Invert Selection", M_EDIT_INVERT_SEL)
	edit_menu.add_separator()
	edit_menu.add_item("Flip Horizontal", M_EDIT_FLIP_H)
	edit_menu.add_item("Flip Vertical", M_EDIT_FLIP_V)
	edit_menu.add_item("Snap to Grid", M_EDIT_SNAP_SEL)
	edit_menu.id_pressed.connect(_on_edit_menu)

	var edge_menu := PopupMenu.new()
	edge_menu.name = "Edge"
	bar.add_child(edge_menu)
	edge_menu.add_item("Convert to Bezier", M_EDGE_TO_BEZIER)
	edge_menu.add_item("Convert to Linear", M_EDGE_TO_LINEAR)
	edge_menu.add_separator()
	edge_menu.add_item("Toggle Arch", M_EDGE_ARCH)
	edge_menu.add_item("Toggle Sine", M_EDGE_SINE)
	edge_menu.add_item("Toggle Repeat", M_EDGE_REPEAT)
	edge_menu.add_separator()
	edge_menu.add_item("Apply Generators", M_EDGE_APPLY_GEN)
	edge_menu.add_item("Apply Props to Selection", M_EDGE_APPLY_PROPS)
	edge_menu.id_pressed.connect(_on_edge_menu)

	var shape_menu := PopupMenu.new()
	shape_menu.name = "Shape"
	bar.add_child(shape_menu)
	shape_menu.add_item("Add Shape", M_SHAPE_ADD)
	shape_menu.id_pressed.connect(_on_shape_menu)

	var view_menu := PopupMenu.new()
	view_menu.name = "View"
	bar.add_child(view_menu)
	view_menu.add_item("Top", M_VIEW_TOP)
	view_menu.add_item("Front", M_VIEW_FRONT)
	view_menu.add_item("Right", M_VIEW_RIGHT)
	view_menu.add_item("Iso", M_VIEW_ISO)
	view_menu.add_separator()
	view_menu.add_item("Background image…", M_VIEW_BG)
	view_menu.id_pressed.connect(_on_view_menu)

	var tools_menu := PopupMenu.new()
	tools_menu.name = "Tools"
	bar.add_child(tools_menu)
	tools_menu.add_item("Circle shape…", M_TOOLS_CIRCLE)
	tools_menu.id_pressed.connect(_on_tools_menu)


func _mk_icon_btn(icon_path: String, pressed_cb: Callable, tooltip: String) -> Button:
	var btn := Button.new()
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(28, 28)
	var tex: Texture2D = load(icon_path) as Texture2D
	if tex != null:
		btn.icon = tex
	elif tooltip.length() > 0:
		btn.text = tooltip.substr(0, 1)
	btn.pressed.connect(pressed_cb)
	return btn


func _build_icon_toolbar(bar: HBoxContainer) -> void:
	bar.add_child(_mk_icon_btn(_ICON_DIR + "icon_new.svg", _apply_new_project, "New project"))
	bar.add_child(_mk_icon_btn(_ICON_DIR + "icon_open.svg", _open_project_dialog, "Open… (Ctrl+O)"))
	bar.add_child(_mk_icon_btn(_ICON_DIR + "icon_save.svg", _save_project_dialog, "Save As… (Ctrl+Shift+S)"))
	bar.add_child(VSeparator.new())
	bar.add_child(_mk_icon_btn(_ICON_DIR + "icon_undo.svg", _on_undo, "Undo (Ctrl+Z)"))
	bar.add_child(_mk_icon_btn(_ICON_DIR + "icon_redo.svg", _on_redo, "Redo (Ctrl+Y)"))
	bar.add_child(VSeparator.new())
	bar.add_child(_mk_icon_btn(_ICON_DIR + "icon_copy_export.svg", _on_copy_export_pressed,
		"Copy TrenchBroom .map brushes to clipboard"))
	bar.add_child(VSeparator.new())

	_mode_option = OptionButton.new()
	for i in range(_MODE_NAMES.size()):
		_mode_option.add_item(_MODE_NAMES[i], i)
	_mode_option.selected = _extrusion.target_mode
	_mode_option.item_selected.connect(_on_mode_selected)
	bar.add_child(_mode_option)

	_group_name = LineEdit.new()
	_group_name.text = "ShapeUp"
	_group_name.placeholder_text = "Name (optional)"
	_group_name.custom_minimum_size.x = 140
	bar.add_child(_group_name)

	bar.add_child(VSeparator.new())
	var snap_lbl := Label.new()
	snap_lbl.text = "Snap:"
	bar.add_child(snap_lbl)
	_snap_spin = SpinBox.new()
	_snap_spin.min_value = 1.0 / 64.0
	_snap_spin.max_value = 4.0
	_snap_spin.step = 1.0 / 4096.0
	_snap_spin.custom_minimum_size.x = 88
	_snap_spin.value = 0.125
	_snap_spin.tooltip_text = "Snap step (world units). Ctrl+scroll in 2D view steps TB ladder."
	_snap_spin.value_changed.connect(_on_snap_spin_changed)
	bar.add_child(_snap_spin)

	_snap_toggle = CheckButton.new()
	_snap_toggle.text = "On"
	_snap_toggle.button_pressed = true
	_snap_toggle.toggled.connect(func(on: bool): _view.snap_enabled = on)
	bar.add_child(_snap_toggle)

	bar.add_child(VSeparator.new())
	var ext_lbl := Label.new()
	ext_lbl.text = "Extrude:"
	bar.add_child(ext_lbl)
	_fixed_distance = SpinBox.new()
	_fixed_distance.min_value = 0.05
	_fixed_distance.max_value = 50.0
	_fixed_distance.step = 0.05
	_fixed_distance.value = _extrusion.fixed_extrude_distance
	_fixed_distance.custom_minimum_size.x = 72
	_fixed_distance.value_changed.connect(func(v: float):
		_extrusion.fixed_extrude_distance = v
		refresh_preview()
	)
	bar.add_child(_fixed_distance)

	var bez_lbl := Label.new()
	bez_lbl.text = "Bezier:"
	bar.add_child(bez_lbl)
	_bezier_detail_spin = SpinBox.new()
	_bezier_detail_spin.min_value = 2
	_bezier_detail_spin.max_value = 64
	_bezier_detail_spin.step = 1
	_bezier_detail_spin.rounded = true
	_bezier_detail_spin.value = 8
	_bezier_detail_spin.custom_minimum_size.x = 56
	_bezier_detail_spin.tooltip_text = "Bezier smoothness for all Bezier edges."
	_bezier_detail_spin.value_changed.connect(_on_bezier_detail_changed)
	bar.add_child(_bezier_detail_spin)

	_chk_click_edge_add = CheckButton.new()
	_chk_click_edge_add.text = "Click+Add"
	_chk_click_edge_add.tooltip_text = "Single-click an edge to insert a vertex."
	_chk_click_edge_add.toggled.connect(func(on: bool): _view.click_insert_vertex_mode = on)
	bar.add_child(_chk_click_edge_add)


func _mk_extr_spin(min_v: float, max_v: float, value: float, step: float, rounded: bool = false) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.rounded = rounded
	s.value = value
	s.custom_minimum_size.x = 72
	return s


func _extr_labeled_row(label_txt: String, field: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var lb := Label.new()
	lb.text = label_txt
	lb.custom_minimum_size.x = 100
	h.add_child(lb)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(field)
	return h


func _wrap_extrusion_panel(title: String, inner: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := Label.new()
	tl.text = title
	vb.add_child(tl)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(inner)
	pc.add_child(vb)
	return pc


func _build_extrusion_inspector() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)

	_panel_polygon = VBoxContainer.new()
	_poly_double_sided = CheckButton.new()
	_poly_double_sided.text = "Double-sided"
	_poly_double_sided.button_pressed = _extrusion.polygon_double_sided
	_poly_double_sided.toggled.connect(func(on: bool):
		_extrusion.polygon_double_sided = on
		refresh_preview()
	)
	_panel_polygon.add_child(_poly_double_sided)
	_extr_wrap_polygon = _wrap_extrusion_panel("Polygon (2D cap)", _panel_polygon)
	stack.add_child(_extr_wrap_polygon)

	_panel_fixed = VBoxContainer.new()
	var fixed_hint := Label.new()
	fixed_hint.text = "Use the Extrude spinbox in the toolbar."
	_panel_fixed.add_child(fixed_hint)
	_extr_wrap_fixed = _wrap_extrusion_panel("Fixed extrude", _panel_fixed)
	stack.add_child(_extr_wrap_fixed)

	_panel_spline = VBoxContainer.new()
	var spline_head := HBoxContainer.new()
	var spl_l := Label.new()
	spl_l.text = "Precision"
	spline_head.add_child(spl_l)
	_spin_spline_precision = _mk_extr_spin(2, 128, _extrusion.spline_extrude_precision, 1, true)
	_spin_spline_precision.value_changed.connect(func(v: float):
		_extrusion.spline_extrude_precision = int(v)
		refresh_preview()
	)
	spline_head.add_child(_spin_spline_precision)
	_panel_spline.add_child(spline_head)
	_spline_rows_host = VBoxContainer.new()
	_panel_spline.add_child(_spline_rows_host)
	_extr_wrap_spline = _wrap_extrusion_panel("Spline extrude", _panel_spline)
	stack.add_child(_extr_wrap_spline)

	_panel_revolve = VBoxContainer.new()
	_spin_rev_prec = _mk_extr_spin(2, 64, _extrusion.revolve_extrude_precision, 1, true)
	_spin_rev_prec.value_changed.connect(func(v: float):
		_extrusion.revolve_extrude_precision = int(v)
		refresh_preview()
	)
	_panel_revolve.add_child(_extr_labeled_row("Precision", _spin_rev_prec))
	_spin_rev_deg = _mk_extr_spin(-720, 720, _extrusion.revolve_extrude_degrees, 1)
	_spin_rev_deg.value_changed.connect(func(v: float):
		_extrusion.revolve_extrude_degrees = v
		refresh_preview()
	)
	_panel_revolve.add_child(_extr_labeled_row("Degrees", _spin_rev_deg))
	_spin_rev_rad = _mk_extr_spin(0.05, 50.0, _extrusion.revolve_extrude_radius, 0.05)
	_spin_rev_rad.value_changed.connect(func(v: float):
		_extrusion.revolve_extrude_radius = v
		refresh_preview()
	)
	_panel_revolve.add_child(_extr_labeled_row("Radius", _spin_rev_rad))
	_spin_rev_h = _mk_extr_spin(-20, 20.0, _extrusion.revolve_extrude_height, 0.05)
	_spin_rev_h.value_changed.connect(func(v: float):
		_extrusion.revolve_extrude_height = v
		refresh_preview()
	)
	_panel_revolve.add_child(_extr_labeled_row("Height", _spin_rev_h))
	_chk_rev_sloped = CheckButton.new()
	_chk_rev_sloped.text = "Sloped (spiral-style)"
	_chk_rev_sloped.button_pressed = _extrusion.revolve_extrude_sloped
	_chk_rev_sloped.toggled.connect(func(on: bool):
		_extrusion.revolve_extrude_sloped = on
		refresh_preview()
	)
	_panel_revolve.add_child(_chk_rev_sloped)
	_extr_wrap_revolve = _wrap_extrusion_panel("Revolve extrude", _panel_revolve)
	stack.add_child(_extr_wrap_revolve)

	_panel_stair = VBoxContainer.new()
	_spin_stair_prec = _mk_extr_spin(1, 64, _extrusion.linear_staircase_precision, 1, true)
	_spin_stair_prec.value_changed.connect(func(v: float):
		_extrusion.linear_staircase_precision = int(v)
		refresh_preview()
	)
	_panel_stair.add_child(_extr_labeled_row("Precision", _spin_stair_prec))
	_spin_stair_dist = _mk_extr_spin(0.05, 50.0, _extrusion.linear_staircase_distance, 0.05)
	_spin_stair_dist.value_changed.connect(func(v: float):
		_extrusion.linear_staircase_distance = v
		refresh_preview()
	)
	_panel_stair.add_child(_extr_labeled_row("Distance", _spin_stair_dist))
	_spin_stair_h = _mk_extr_spin(0, 20.0, _extrusion.linear_staircase_height, 0.05)
	_spin_stair_h.value_changed.connect(func(v: float):
		_extrusion.linear_staircase_height = v
		refresh_preview()
	)
	_panel_stair.add_child(_extr_labeled_row("Height", _spin_stair_h))
	_chk_stair_sloped = CheckButton.new()
	_chk_stair_sloped.text = "Sloped (ramp)"
	_chk_stair_sloped.button_pressed = _extrusion.linear_staircase_sloped
	_chk_stair_sloped.toggled.connect(func(on: bool):
		_extrusion.linear_staircase_sloped = on
		refresh_preview()
	)
	_panel_stair.add_child(_chk_stair_sloped)
	_extr_wrap_stair = _wrap_extrusion_panel("Linear staircase", _panel_stair)
	stack.add_child(_extr_wrap_stair)

	_panel_scaled = VBoxContainer.new()
	_spin_scaled_dist = _mk_extr_spin(0.05, 50.0, _extrusion.scaled_extrude_distance, 0.05)
	_spin_scaled_dist.value_changed.connect(func(v: float):
		_extrusion.scaled_extrude_distance = v
		refresh_preview()
	)
	_panel_scaled.add_child(_extr_labeled_row("Distance", _spin_scaled_dist))
	var row_fs := HBoxContainer.new()
	_spin_scale_fx = _mk_extr_spin(0, 4.0, _extrusion.scaled_extrude_front_scale.x, 0.05)
	_spin_scale_fy = _mk_extr_spin(0, 4.0, _extrusion.scaled_extrude_front_scale.y, 0.05)
	_spin_scale_fx.value_changed.connect(func(_v: float):
		_extrusion.scaled_extrude_front_scale = Vector2(_spin_scale_fx.value, _spin_scale_fy.value)
		refresh_preview()
	)
	_spin_scale_fy.value_changed.connect(func(_v2: float):
		_extrusion.scaled_extrude_front_scale = Vector2(_spin_scale_fx.value, _spin_scale_fy.value)
		refresh_preview()
	)
	row_fs.add_child(_spin_scale_fx)
	row_fs.add_child(_spin_scale_fy)
	_panel_scaled.add_child(_extr_labeled_row("Front scale XY", row_fs))
	var row_bs := HBoxContainer.new()
	_spin_scale_bx = _mk_extr_spin(0, 4.0, _extrusion.scaled_extrude_back_scale.x, 0.05)
	_spin_scale_by = _mk_extr_spin(0, 4.0, _extrusion.scaled_extrude_back_scale.y, 0.05)
	_spin_scale_bx.value_changed.connect(func(_v: float):
		_extrusion.scaled_extrude_back_scale = Vector2(_spin_scale_bx.value, _spin_scale_by.value)
		refresh_preview()
	)
	_spin_scale_by.value_changed.connect(func(_v2: float):
		_extrusion.scaled_extrude_back_scale = Vector2(_spin_scale_bx.value, _spin_scale_by.value)
		refresh_preview()
	)
	row_bs.add_child(_spin_scale_bx)
	row_bs.add_child(_spin_scale_by)
	_panel_scaled.add_child(_extr_labeled_row("Back scale XY", row_bs))
	var row_os := HBoxContainer.new()
	_spin_scale_ox = _mk_extr_spin(-10, 10.0, _extrusion.scaled_extrude_offset.x, 0.05)
	_spin_scale_oy = _mk_extr_spin(-10, 10.0, _extrusion.scaled_extrude_offset.y, 0.05)
	_spin_scale_ox.value_changed.connect(func(_v: float):
		_extrusion.scaled_extrude_offset = Vector2(_spin_scale_ox.value, _spin_scale_oy.value)
		refresh_preview()
	)
	_spin_scale_oy.value_changed.connect(func(_v2: float):
		_extrusion.scaled_extrude_offset = Vector2(_spin_scale_ox.value, _spin_scale_oy.value)
		refresh_preview()
	)
	row_os.add_child(_spin_scale_ox)
	row_os.add_child(_spin_scale_oy)
	_panel_scaled.add_child(_extr_labeled_row("Offset XY", row_os))
	_extr_wrap_scaled = _wrap_extrusion_panel("Scaled extrude", _panel_scaled)
	stack.add_child(_extr_wrap_scaled)

	_panel_chopped = VBoxContainer.new()
	_spin_chop_prec = _mk_extr_spin(2, 64, _extrusion.revolve_chopped_precision, 1, true)
	_spin_chop_prec.value_changed.connect(func(v: float):
		_extrusion.revolve_chopped_precision = int(v)
		refresh_preview()
	)
	_panel_chopped.add_child(_extr_labeled_row("Chop count", _spin_chop_prec))
	_spin_chop_deg = _mk_extr_spin(-720, 720, _extrusion.revolve_chopped_degrees, 1)
	_spin_chop_deg.value_changed.connect(func(v: float):
		_extrusion.revolve_chopped_degrees = v
		refresh_preview()
	)
	_panel_chopped.add_child(_extr_labeled_row("Degrees", _spin_chop_deg))
	_spin_chop_dist = _mk_extr_spin(0.05, 10.0, _extrusion.revolve_chopped_distance, 0.05)
	_spin_chop_dist.value_changed.connect(func(v: float):
		_extrusion.revolve_chopped_distance = v
		refresh_preview()
	)
	_panel_chopped.add_child(_extr_labeled_row("Distance", _spin_chop_dist))
	_extr_wrap_chopped = _wrap_extrusion_panel("Revolve chopped", _panel_chopped)
	stack.add_child(_extr_wrap_chopped)

	var bg_panel := VBoxContainer.new()
	var bg_scale := _mk_extr_spin(0.01, 100.0, _view.background_scale, 0.05)
	bg_scale.value_changed.connect(func(v: float):
		_view.background_scale = v
		_view.queue_redraw()
	)
	bg_panel.add_child(_extr_labeled_row("Scale", bg_scale))
	var bg_alpha := _mk_extr_spin(0.0, 1.0, _view.background_alpha, 0.05)
	bg_alpha.value_changed.connect(func(v: float):
		_view.background_alpha = v
		_view.queue_redraw()
	)
	bg_panel.add_child(_extr_labeled_row("Alpha", bg_alpha))
	var btn_remove := Button.new()
	btn_remove.text = "Remove background image"
	btn_remove.pressed.connect(func():
		_view.background_image = null
		_view.queue_redraw()
	)
	bg_panel.add_child(btn_remove)
	stack.add_child(_wrap_extrusion_panel("Background Reference", bg_panel))

	return scroll


func _rebuild_spline_rows() -> void:
	if _spline_rows_host == null:
		return
	for c in _spline_rows_host.get_children():
		c.queue_free()
	var pts: Array = _extrusion.spline_control_points
	for i in range(pts.size()):
		var idx: int = i
		var h := HBoxContainer.new()
		var pl := Label.new()
		pl.text = "P%d" % idx
		pl.custom_minimum_size.x = 28
		h.add_child(pl)
		var pv: Vector3 = pts[idx] as Vector3 if pts[idx] is Vector3 else Vector3.ZERO
		var sx := _mk_extr_spin(-50, 50.0, pv.x, 0.05)
		var sy := _mk_extr_spin(-50, 50.0, pv.y, 0.05)
		var sz := _mk_extr_spin(-50, 50.0, pv.z, 0.05)
		sx.value_changed.connect(func(v: float):
			var p: Vector3 = pts[idx] as Vector3
			p.x = v
			pts[idx] = p
			refresh_preview()
		)
		sy.value_changed.connect(func(v: float):
			var p: Vector3 = pts[idx] as Vector3
			p.y = v
			pts[idx] = p
			refresh_preview()
		)
		sz.value_changed.connect(func(v: float):
			var p: Vector3 = pts[idx] as Vector3
			p.z = v
			pts[idx] = p
			refresh_preview()
		)
		h.add_child(sx)
		h.add_child(sy)
		h.add_child(sz)
		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size.x = 28
		del_btn.pressed.connect(func():
			if pts.size() <= 3:
				return
			pts.remove_at(idx)
			_rebuild_spline_rows()
			refresh_preview()
		)
		h.add_child(del_btn)
		_spline_rows_host.add_child(h)
	var add_row := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "+ Control point"
	add_btn.pressed.connect(func():
		var last: Vector3 = pts[pts.size() - 1] as Vector3 if pts[pts.size() - 1] is Vector3 else Vector3.ZERO
		pts.append(Vector3(last.x + 0.25, last.y, last.z + 0.25))
		_rebuild_spline_rows()
		refresh_preview()
	)
	add_row.add_child(add_btn)
	_spline_rows_host.add_child(add_row)


func _update_extrusion_panel_visibility() -> void:
	if _mode_option == null:
		return
	var m: int = _mode_option.selected
	_extr_wrap_polygon.visible = m == _Enums.ShapeEditorTargetMode.POLYGON
	_extr_wrap_fixed.visible = m == _Enums.ShapeEditorTargetMode.FIXED_EXTRUDE
	_extr_wrap_spline.visible = m == _Enums.ShapeEditorTargetMode.SPLINE_EXTRUDE
	_extr_wrap_revolve.visible = m == _Enums.ShapeEditorTargetMode.REVOLVE_EXTRUDE
	_extr_wrap_stair.visible = m == _Enums.ShapeEditorTargetMode.LINEAR_STAIRCASE
	_extr_wrap_scaled.visible = m == _Enums.ShapeEditorTargetMode.SCALED_EXTRUDE
	_extr_wrap_chopped.visible = m == _Enums.ShapeEditorTargetMode.REVOLVE_CHOPPED


func _build_tool_palette() -> VBoxContainer:
	var palette := VBoxContainer.new()
	palette.custom_minimum_size.x = 32
	_tool_palette_buttons.clear()

	var specs: Array = [
		["icon_select.svg", _Enums.Editor2DTool.SELECT, "Select"],
		["icon_move.svg", _Enums.Editor2DTool.MOVE, "Move vertices"],
		["icon_rotate.svg", _Enums.Editor2DTool.ROTATE, "Rotate: select vertices, then drag (snap steps angle)"],
		["icon_draw.svg", _Enums.Editor2DTool.DRAW, "Draw: click edges to add vertices"],
		["icon_cut.svg", _Enums.Editor2DTool.CUT, "Cut: click edge to insert vertex"],
		["icon_measure.svg", _Enums.Editor2DTool.MEASURE, "Measure tape"],
	]
	for spec in specs:
		var icon_name: String = spec[0]
		var tool: int = spec[1]
		var tip: String = spec[2]
		var path := _ICON_DIR + icon_name
		var b := _mk_icon_btn(path, _set_viewport_tool.bind(tool), tip)
		_tool_palette_buttons.append(b)
		palette.add_child(b)

	palette.add_child(_mk_icon_btn(_ICON_DIR + "icon_snap.svg", func():
		if _snap_toggle:
			_snap_toggle.button_pressed = not _snap_toggle.button_pressed
	, "Toggle snap"))
	return palette


func _set_viewport_tool(tool: int) -> void:
	if _view:
		_view.active_tool = tool
	var dim := Color(0.52, 0.52, 0.55)
	for i in range(_tool_palette_buttons.size()):
		var b = _tool_palette_buttons[i]
		if b is Button:
			(b as Button).modulate = Color.WHITE if _TOOL_ORDER[i] == tool else dim


func _build_preview_panel() -> VBoxContainer:
	var preview_col := VBoxContainer.new()
	preview_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_col.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var preview_toolbar := HBoxContainer.new()
	preview_col.add_child(preview_toolbar)
	var lbl := Label.new()
	lbl.text = "3D view:"
	preview_toolbar.add_child(lbl)

	var add_btn := func(txt: String, cb: Callable, tip: String) -> void:
		var b := Button.new()
		b.text = txt
		b.tooltip_text = tip
		b.pressed.connect(cb)
		preview_toolbar.add_child(b)

	add_btn.call("Top", func(): _preview_orbit.set_preset_top(), "Plan view")
	add_btn.call("Front", func(): _preview_orbit.set_preset_front(), "Front view")
	add_btn.call("Right", func(): _preview_orbit.set_preset_right(), "Right view")
	add_btn.call("Iso", func():
		_preview_auto_frame_once = true
		_preview_frame_oblique = true
		refresh_preview()
	, "Re-frame oblique")

	var sub := SubViewportContainer.new()
	sub.stretch = true
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub.custom_minimum_size = Vector2(200, 200)
	sub.tooltip_text = "Right-drag: orbit • Mid-drag: pan • Wheel: zoom"
	preview_col.add_child(sub)

	var vp := SubViewport.new()
	vp.handle_input_locally = true
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	sub.add_child(vp)

	_preview_orbit = _PreviewCameraOrbit.new()
	vp.add_child(_preview_orbit)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.position = Vector3(0, 2.2, 0)
	sun.light_energy = 1.05
	_preview_orbit.add_child(sun)

	_preview_cam = Camera3D.new()
	_preview_cam.fov = 55.0
	_preview_cam.near = 0.01
	_preview_cam.far = 256.0
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.21, 0.24)
	env.ambient_light_energy = 0.45
	_preview_cam.environment = env
	_preview_orbit.add_child(_preview_cam)
	_preview_orbit.camera = _preview_cam

	_preview_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.76, 0.78, 0.8)
	mat.roughness = 0.78
	mat.metallic = 0.06
	_preview_mesh.material_override = mat
	_preview_orbit.add_child(_preview_mesh)

	return preview_col


func _apply_new_project() -> void:
	_undo.clear()
	_extrusion.set_project(_ShapeProject.new())
	_view.project = _extrusion.project
	_on_project_edited()


func _open_project_dialog() -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.add_filter("*.json", "JSON")
	d.file_selected.connect(func(path: String):
		var t := FileAccess.get_file_as_string(path)
		_extrusion.set_project(ShapeupSerialization.project_from_json(t))
		_view.project = _extrusion.project
		_undo.clear()
		_on_project_edited()
		d.queue_free()
	)
	add_child(d)
	d.popup_centered_ratio(0.5)


func _save_project_dialog() -> void:
	var d2 := FileDialog.new()
	d2.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	d2.access = FileDialog.ACCESS_FILESYSTEM
	d2.add_filter("*.json", "JSON")
	d2.file_selected.connect(func(path: String):
		var c := FileAccess.open(path, FileAccess.WRITE)
		if c:
			c.store_string(ShapeupSerialization.project_to_json(_extrusion.project))
		d2.queue_free()
	)
	add_child(d2)
	d2.popup_centered_ratio(0.5)


func _on_file_menu(id: int) -> void:
	match id:
		M_FILE_OPEN:
			_open_project_dialog()
		M_FILE_SAVE:
			_save_project_dialog()
		M_FILE_COPY_BRUSHES, M_FILE_COPY_GODOT_MAP:
			var txt: String = _extrusion.build_trenchbroom_clipboard(_group_name.text)
			if txt.is_empty():
				push_warning("ShapeUp: Nothing to copy (either no valid shapes or mode does not support 3D brushes).")
			else:
				DisplayServer.clipboard_set(txt)
				print("ShapeUp: Copied %d bytes to clipboard." % txt.length())


func _on_edit_menu(id: int) -> void:
	match id:
		M_EDIT_UNDO:
			_on_undo()
		M_EDIT_REDO:
			_on_redo()
		M_EDIT_SELECT_ALL:
			_extrusion.project.select_all()
			_view.queue_redraw()
			_on_project_edited()
		M_EDIT_CLEAR_SEL:
			_extrusion.project.clear_selection()
			_view.queue_redraw()
		M_EDIT_INVERT_SEL:
			_extrusion.project.invert_selection()
			_view.queue_redraw()
			_on_project_edited()
		M_EDIT_FLIP_H:
			_view.flip_selection_horizontally()
		M_EDIT_FLIP_V:
			_view.flip_selection_vertically()
		M_EDIT_SNAP_SEL:
			_view.snap_selection_to_grid()


func _toggle_selected_edges(gen_type: int) -> void:
	if _extrusion.project == null:
		return
	_on_before_viewport_mutation()
	_extrusion.project.validate()
	for sh in _extrusion.project.shapes:
		for seg in sh.segments:
			if not (seg.selected and seg.next.selected):
				continue
			if seg.generator.type == gen_type:
				seg.generator = _ShapeSegmentGenerator.new(seg, _Enums.SegmentGeneratorType.LINEAR)
			else:
				seg.generator = _ShapeSegmentGenerator.new(seg, gen_type)
	_extrusion.project.invalidate()
	_on_project_edited()
	_view.queue_redraw()


func _on_edge_menu(id: int) -> void:
	match id:
		M_EDGE_TO_BEZIER:
			_view.convert_selected_edge_to_bezier()
			_on_bezier_detail_changed(float(_bezier_detail_spin.value))
		M_EDGE_TO_LINEAR:
			_view.convert_selected_edge_to_linear()
		M_EDGE_ARCH:
			_toggle_selected_edges(_Enums.SegmentGeneratorType.ARCH)
		M_EDGE_SINE:
			_toggle_selected_edges(_Enums.SegmentGeneratorType.SINE)
		M_EDGE_REPEAT:
			_toggle_selected_edges(_Enums.SegmentGeneratorType.REPEAT)
		M_EDGE_APPLY_GEN:
			_on_apply_generators()
		M_EDGE_APPLY_PROPS:
			_on_apply_generator_props_to_selection()

func _on_apply_generators() -> void:
	if _view.project == null:
		return
	_undo.push_before_mutation(_extrusion.project)
	_extrusion.project.validate()
	for shape in _extrusion.project.shapes:
		for seg in shape.segments:
			if not (seg.selected and seg.next.selected):
				continue
			if seg.generator.type == _Enums.SegmentGeneratorType.LINEAR:
				continue
			seg.generator.apply_generator()
			seg.generator = _ShapeSegmentGenerator.new(seg, _Enums.SegmentGeneratorType.LINEAR)
	
	_extrusion.project.invalidate()
	_extrusion.project.clear_selection()
	_on_project_edited()
	_view.queue_redraw()


func _on_apply_generator_props_to_selection() -> void:
	# C# version syncs from inspector spinboxes.
	# Since we haven't implemented the Edge Inspector yet, 
	# this is a placeholder or can sync from some defaults.
	# For now, we can at least ensure it's wired.
	push_warning("ShapeUp: Apply Props requires Edge Inspector implemented.")


func _on_shape_menu(id: int) -> void:
	if id == M_SHAPE_ADD:
		_on_before_viewport_mutation()
		_extrusion.project.shapes.append(_ShapeShape.new())
		_extrusion.project.invalidate()
		_on_project_edited()


func _on_view_menu(id: int) -> void:
	match id:
		M_VIEW_TOP:
			_preview_orbit.set_preset_top()
		M_VIEW_FRONT:
			_preview_orbit.set_preset_front()
		M_VIEW_RIGHT:
			_preview_orbit.set_preset_right()
		M_VIEW_ISO:
			_preview_auto_frame_once = true
			_preview_frame_oblique = true
			refresh_preview()
		M_VIEW_BG:
			_on_pick_background_image()


func _on_pick_background_image() -> void:
	_file_bg_image.popup_centered_ratio(0.55)


func _setup_file_dialogs() -> void:
	_file_bg_image = FileDialog.new()
	_file_bg_image.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_bg_image.access = FileDialog.ACCESS_FILESYSTEM
	_file_bg_image.title = "Background reference image"
	_file_bg_image.add_filter("*.png", "PNG")
	_file_bg_image.add_filter("*.jpg,*.jpeg", "JPEG")
	_file_bg_image.add_filter("*.webp", "WebP")
	_file_bg_image.add_filter("*.svg", "SVG")
	_file_bg_image.file_selected.connect(_on_background_image_selected)
	add_child(_file_bg_image)


func _on_background_image_selected(path: String) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("ShapeUp: Could not load background image: " + path)
		return
	_view.background_image = tex
	_view.background_scale = maxf(_view.background_scale, 0.01)
	_view.queue_redraw()


func _on_tools_menu(id: int) -> void:
	if id == M_TOOLS_CIRCLE:
		_circle_dialog.popup_centered_ratio(0.35)


func _setup_aux_dialogs() -> void:
	_circle_dialog = AcceptDialog.new()
	_circle_dialog.title = "Circle shape"
	_circle_dialog.ok_button_text = "Create"
	_circle_dialog.confirmed.connect(_on_circle_dialog_confirmed)
	add_child(_circle_dialog)

	var vb := VBoxContainer.new()
	_circle_detail_spin = _mk_extr_spin(3, 128, 16, 1, true)
	_circle_diameter_spin = _mk_extr_spin(0.05, 50, 1, 0.05)
	vb.add_child(_extr_labeled_row("Detail (vertices)", _circle_detail_spin))
	vb.add_child(_extr_labeled_row("Diameter (world units)", _circle_diameter_spin))
	_circle_dialog.add_child(vb)


func _on_circle_dialog_confirmed() -> void:
	var detail: int = clampi(int(_circle_detail_spin.value), 3, 256)
	var diameter: float = float(_circle_diameter_spin.value)
	
	_on_before_viewport_mutation()
	
	var circle := _MathEx.Circle.new()
	circle.set_diameter(diameter)
	
	var shape := _ShapeShape.new()
	shape.segments.clear()
	for i in range(detail):
		var pos := circle.get_circle_position(float(i) / float(detail))
		# Unity coordinate mapping: (x, y, z) circle pos -> (x, -z) for 2D XY shape
		# Vector3(sin(t*2PI)*R, 0, cos(t*2PI)*R) -> x=sin, y=-cos
		var ShapeSegmentClass = load("res://shapeup_core/shape_editor/shape_segment.gd")
		shape.add_segment(ShapeSegmentClass.new(shape, pos.x, -pos.z))

	_extrusion.project.clear_selection()
	_extrusion.project.shapes.append(shape)
	shape.select_all()
	_extrusion.project.invalidate()
	_on_project_edited()
	_view.queue_redraw()


func _on_undo() -> void:
	var restored = _undo.pop_undo(_extrusion.project)
	if restored == null:
		return
	_extrusion.set_project(restored)
	_view.project = _extrusion.project
	_on_project_edited()


func _on_redo() -> void:
	var restored = _undo.pop_redo(_extrusion.project)
	if restored == null:
		return
	_extrusion.set_project(restored)
	_view.project = _extrusion.project
	_on_project_edited()


func _on_copy_export_pressed() -> void:
	var txt: String = _extrusion.build_trenchbroom_clipboard(_group_name.text)
	if txt.is_empty():
		push_warning("ShapeUp: Nothing to copy (either no valid shapes or mode does not support 3D brushes).")
	else:
		DisplayServer.clipboard_set(txt)
		print("ShapeUp: Copied %d bytes to clipboard." % txt.length())


func _on_bezier_detail_changed(value: float) -> void:
	var detail: int = clampi(int(round(value)), 2, 128)
	_extrusion.project.validate()
	for sh in _extrusion.project.shapes:
		for seg in sh.segments:
			if seg.generator.type == _Enums.SegmentGeneratorType.BEZIER:
				seg.generator.bezier_detail = detail
	_extrusion.project.invalidate()
	_on_project_edited()


func _on_snap_spin_changed(value: float) -> void:
	var q: float = TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(value)
	if absf(q - value) > 1e-6 and _snap_spin:
		_snap_spin.value = q
	_view.snap_increment = q


func _on_viewport_snap_adjusted(world_step: float) -> void:
	if _snap_spin:
		_snap_spin.set_value_no_signal(clampf(world_step, _snap_spin.min_value, _snap_spin.max_value))


func _on_before_viewport_mutation() -> void:
	if _extrusion != null and _extrusion.project != null and _undo != null:
		_undo.push_before_mutation(_extrusion.project)


func _on_mode_selected(idx: int) -> void:
	_extrusion.target_mode = idx
	_preview_auto_frame_once = true
	_update_extrusion_panel_visibility()
	refresh_preview()


func _on_project_edited() -> void:
	_extrusion.invalidate_cache()
	refresh_preview()
	if _view:
		_view.queue_redraw()


func refresh_preview() -> void:
	if _preview_mesh == null or _preview_cam == null:
		return
	_extrusion.target_mode = _mode_option.selected
	_extrusion.fixed_extrude_distance = float(_fixed_distance.value)
	var am = _extrusion.build_preview_mesh() as ArrayMesh
	if am == null or am.get_surface_count() == 0:
		_preview_mesh.mesh = null
		_preview_auto_frame_once = true
		return
	_preview_mesh.mesh = am
	var aabb: AABB = am.get_aabb()
	if _preview_auto_frame_once:
		_preview_orbit.frame_bounding_box(aabb, _preview_cam.fov, _preview_frame_oblique)
		_preview_frame_oblique = false
		_preview_auto_frame_once = false


func _process(_delta: float) -> void:
	if _status_label == null or _view == null or _extrusion.project == null:
		return
	var segs := 0
	var bez := 0
	for sh in _extrusion.project.shapes:
		segs += sh.segments.size()
		for s in sh.segments:
			if s.generator.type == _Enums.SegmentGeneratorType.BEZIER:
				bez += 1
	var snap_on := "on" if _view.snap_enabled else "off"
	var snap_txt := str(_view.snap_increment)
	_status_label.text = "Segments: %d | Bezier edges: %d | 2D zoom: %.0f px/unit | Snap: %s (%s)" % [
		segs, bez, _view.get_view_zoom_pixels_per_unit(), snap_txt, snap_on
	]
