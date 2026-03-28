extends Control

signal project_changed
signal snap_increment_adjusted(new_value: float)
signal before_project_mutation

const DEFAULT_ZOOM := 120.0
const MIN_ZOOM := 18.0
const MAX_ZOOM := 720.0
const ZOOM_STEP := 1.12
const EDGE_PICK_PX := 14.0
const VERTEX_PICK_PX := 12.0
const PIVOT_PICK_PX := 11.0
const MARQUEE_DRAG_THRESHOLD_PX := 5.0

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _ShapeSegment := preload("res://shapeup_core/shape_editor/shape_segment.gd")
const _ShapeSegmentGenerator := preload("res://shapeup_core/shape_editor/shape_segment_generator.gd")
const _VertexSelectionTransforms := preload("res://shapeup_core/shape_editor/vertex_selection_transforms.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")

var project = null
var snap_increment: float = 0.125
var snap_enabled: bool = true
var _active_tool: int = _Enums.Editor2DTool.SELECT
var active_tool: int:
	get:
		return _active_tool
	set(v):
		if _active_tool == v:
			return
		if _active_tool == _Enums.Editor2DTool.MEASURE:
			_reset_measure_state()
		if v != _Enums.Editor2DTool.ROTATE:
			_cancel_rotate_drag_session()
		_active_tool = v
		queue_redraw()
var click_insert_vertex_mode: bool = false
var background_image: Texture2D = null
var background_scale: float = 1.0
var background_alpha: float = 0.25

var _zoom: float = DEFAULT_ZOOM
var _pan := Vector2.ZERO
var _viewport_initialized: bool = false
var _is_panning: bool = false
var _last_pan_mouse := Vector2.ZERO
var _left_button_held: bool = false

var _drag_vertex_segment = null
var _drag_pivot = null
var _vertex_drag_last_grid := Vector2.ZERO
var _pivot_drag_origin := Vector2.ZERO
var _vertex_drag_undo_pushed: bool = false
var _pivot_drag_undo_pushed: bool = false

var _marquee_pending: bool = false
var _marquee_dragging: bool = false
var _marquee_start := Vector2.ZERO
var _marquee_end := Vector2.ZERO
var _marquee_had_shift: bool = false

var _measure_start := Vector2.ZERO
var _measure_end := Vector2.ZERO
var _measure_proc: bool = false
var _measure_dragging: bool = false
var _measure_length: float = 0.0

var _rotate_drag_active: bool = false
var _rotate_pivot := Vector2.ZERO
var _rotate_start_angle_deg: float = 0.0
var _rotate_undo_pushed: bool = false
var _rotate_drag_last_screen := Vector2.ZERO

var edge_menu_bezier: Callable
var edge_menu_linear: Callable
var edge_menu_arch: Callable
var edge_menu_sine: Callable
var edge_menu_repeat: Callable
var edge_menu_apply_generators: Callable
var edge_menu_apply_props: Callable

var _edge_context_menu: PopupMenu

func _ready() -> void:
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	
	_edge_context_menu = PopupMenu.new()
	_edge_context_menu.hide_on_item_selection = true
	_edge_context_menu.id_pressed.connect(_on_edge_context_menu_id_pressed)
	add_child(_edge_context_menu)
	_build_edge_context_menu_items()

func _build_edge_context_menu_items() -> void:
	var m = _edge_context_menu
	m.clear()
	m.add_item("Bezier curve (drag handles)", 0)
	m.set_item_tooltip(m.get_item_count() - 1, "Editable cubic curve between the two corners.")
	m.add_item("Straight edge", 1)
	m.set_item_tooltip(m.get_item_count() - 1, "Remove curve / wave / arch on this edge.")
	m.add_separator()
	m.add_item("Arch (preset profile)", 2)
	m.set_item_tooltip(m.get_item_count() - 1, "Parametric arch; tune mode & detail in the inspector.")
	m.add_item("Sine wave", 3)
	m.set_item_tooltip(m.get_item_count() - 1, "Wavy edge; drag yellow pivot.")
	m.add_item("Repeat (zigzag)", 4)
	m.set_item_tooltip(m.get_item_count() - 1, "Repeated segments along the edge.")
	m.add_separator()
	m.add_item("Bake curve → corner vertices", 5)
	m.set_item_tooltip(m.get_item_count() - 1, "Replace generator with plain vertices (destructive).")
	m.add_item("Apply inspector numbers to edge", 6)
	m.set_item_tooltip(m.get_item_count() - 1, "Copy Arch/Sine/Repeat fields from spinboxes to this edge.")

func _on_edge_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			if edge_menu_bezier.is_valid():
				edge_menu_bezier.call()
		1:
			if edge_menu_linear.is_valid():
				edge_menu_linear.call()
		2:
			if edge_menu_arch.is_valid():
				edge_menu_arch.call()
		3:
			if edge_menu_sine.is_valid():
				edge_menu_sine.call()
		4:
			if edge_menu_repeat.is_valid():
				edge_menu_repeat.call()
		5:
			if edge_menu_apply_generators.is_valid():
				edge_menu_apply_generators.call()
		6:
			if edge_menu_apply_props.is_valid():
				edge_menu_apply_props.call()

func _open_edge_context_menu_at(local_position: Vector2) -> void:
	if _edge_context_menu == null:
		return
	_edge_context_menu.position = Vector2i(local_position.round())
	_edge_context_menu.popup()


func get_view_zoom_pixels_per_unit() -> float:
	return _zoom


func _effective_click_insert_vertex() -> bool:
	return click_insert_vertex_mode or _active_tool == _Enums.Editor2DTool.DRAW


func _reset_measure_state() -> void:
	_measure_proc = false
	_measure_dragging = false
	_measure_length = 0.0


func _cancel_rotate_drag_session() -> void:
	_rotate_drag_active = false
	_rotate_undo_pushed = false


func _delta_angle_deg(from_deg: float, to_deg: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(from_deg), deg_to_rad(to_deg)))


func _begin_rotate_drag(mouse_grid_unsnapped: Vector2, mouse_screen: Vector2) -> void:
	if project == null:
		return
	_VertexSelectionTransforms.capture_rotate_baseline(project)
	_rotate_pivot = _VertexSelectionTransforms.get_centroid_of_selected_segment_vertices(project)
	_rotate_start_angle_deg = _VertexSelectionTransforms.angle_from_pivot_to_point_deg(
		_rotate_pivot, mouse_grid_unsnapped
	)
	_rotate_drag_active = true
	_rotate_undo_pushed = false
	_rotate_drag_last_screen = mouse_screen


func _process_rotate_drag_motion(screen_pos: Vector2) -> void:
	if project == null or not _rotate_drag_active:
		return
	_rotate_drag_last_screen = screen_pos
	var mouse_grid := screen_to_grid(screen_pos)
	var cur: float = _VertexSelectionTransforms.angle_from_pivot_to_point_deg(_rotate_pivot, mouse_grid)
	var raw_total: float = _delta_angle_deg(_rotate_start_angle_deg, cur)
	var step_deg: float = (
		TrenchBroomGrid.rotate_snap_step_degrees_from_snap_world(snap_increment)
		if snap_enabled
		else 0.0
	)
	var total_deg: float = TrenchBroomGrid.snap_angle_degrees(raw_total, step_deg)
	if not _rotate_undo_pushed and absf(total_deg) > 1e-4:
		before_project_mutation.emit()
		_rotate_undo_pushed = true
	_VertexSelectionTransforms.apply_rotate_from_baseline(project, _rotate_pivot, total_deg)
	project_changed.emit()
	queue_redraw()
	accept_event()


func _draw_rotate_drag_visual() -> void:
	if not _rotate_drag_active or project == null:
		return
	var pivot_s := grid_to_screen_draw(_rotate_pivot.x, _rotate_pivot.y)
	draw_circle(pivot_s, 5.0, Color(0.35, 0.85, 1.0, 0.95))
	draw_dashed_line(pivot_s, _rotate_drag_last_screen, Color(0.6, 0.6, 0.65, 0.85), 12.0, 4.0)


func rotate_selected_vertices_degrees(degrees: float) -> void:
	if project == null or absf(degrees) < 1e-6:
		return
	if not _VertexSelectionTransforms.has_selected_segment_vertex(project):
		return
	before_project_mutation.emit()
	_VertexSelectionTransforms.rotate_selection_degrees(project, degrees)
	project_changed.emit()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_try_init_viewport()


func _try_init_viewport() -> void:
	var sz := size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	if _viewport_initialized:
		return
	_viewport_initialized = true
	_pan = Vector2(roundf(sz.x * 0.5), roundf(sz.y * 0.5))


func grid_to_screen(grid: Vector2) -> Vector2:
	return _pan + Vector2(grid.x, -grid.y) * _zoom


func grid_to_screen_draw(gx: float, gy: float) -> Vector2:
	var p := grid_to_screen(Vector2(gx, gy))
	return Vector2(roundf(p.x), roundf(p.y))


func screen_to_grid(screen: Vector2) -> Vector2:
	var g := (screen - _pan) / _zoom
	return Vector2(g.x, -g.y)


func _snap_grid(g: Vector2) -> Vector2:
	if not snap_enabled or snap_increment <= 1e-8:
		return g
	var s: float = TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(snap_increment)
	return Vector2(roundf(g.x / s) * s, roundf(g.y / s) * s)


func _get_tb_grid_draw_step_world() -> float:
	return TrenchBroomGrid.pick_viewport_grid_step_world(maxf(snap_increment, 1e-6), _zoom, 10.0)


func _tb_grid_line_style(quake_coord: int, minor_quake: int) -> Dictionary:
	var on_world: bool = TrenchBroomGrid.mod(quake_coord, 64) == 0
	var block: int = minor_quake * 8
	var on_eight: bool = (not on_world) and block > 0 and TrenchBroomGrid.mod(quake_coord, block) == 0
	if on_world:
		return {"color": Color(1, 1, 1, 0.22), "width": 2.0}
	if on_eight:
		return {"color": Color(1, 1, 1, 0.12), "width": 1.35}
	return {"color": Color(1, 1, 1, 0.055), "width": 1.0}


func _apply_zoom_towards(screen_pos: Vector2, new_zoom: float) -> void:
	new_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	var old_z := _zoom
	if absf(new_zoom - old_z) < 1e-5:
		return
	var g := screen_to_grid(screen_pos)
	_pan.x += g.x * (old_z - new_zoom)
	_pan.y += g.y * (new_zoom - old_z)
	_zoom = new_zoom


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_try_init_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.14))
	if project == null:
		return
	project.validate()
	_draw_background_image()
	_draw_tb_grid()
	for sh in project.shapes:
		_draw_shape_filled_outline(sh)
	_draw_parametric_edges()
	_draw_bezier_decorations()
	_draw_measure_overlay()
	_draw_rotate_drag_visual()
	for sh in project.shapes:
		for seg in sh.segments:
			var p := grid_to_screen_draw(seg.position.x, seg.position.y)
			var rad := 6.0 if seg.selected else 4.0
			draw_circle(p, rad, Color.ORANGE_RED if seg.selected else Color.WHITE)
	if _marquee_dragging:
		var a := _marquee_start
		var b := _marquee_end
		var r := Rect2(
			Vector2(minf(a.x, b.x), minf(a.y, b.y)),
			Vector2(absf(b.x - a.x), absf(b.y - a.y))
		)
		draw_rect(r, Color(0.2, 0.55, 1.0, 0.12))
		draw_rect(r, Color(0.35, 0.65, 1.0, 0.9), false, 1.0)


func _draw_tb_grid() -> void:
	var step := _get_tb_grid_draw_step_world()
	var minor_quake: int = maxi(1, int(round(step * TrenchBroomGrid.QUAKE_UNITS_PER_WORLD)))
	var c0 := screen_to_grid(Vector2.ZERO)
	var c1 := screen_to_grid(Vector2(size.x, 0))
	var c2 := screen_to_grid(Vector2(0, size.y))
	var c3 := screen_to_grid(size)
	var min_gx := minf(minf(c0.x, c1.x), minf(c2.x, c3.x))
	var max_gx := maxf(maxf(c0.x, c1.x), maxf(c2.x, c3.x))
	var min_gy := minf(minf(c0.y, c1.y), minf(c2.y, c3.y))
	var max_gy := maxf(maxf(c0.y, c1.y), maxf(c2.y, c3.y))
	var margin := step * 2.0
	min_gx -= margin
	max_gx += margin
	min_gy -= margin
	max_gy += margin
	var gx0 := floorf(min_gx / step - 1e-6) * step
	var gx1 := ceilf(max_gx / step + 1e-6) * step
	var gy0 := floorf(min_gy / step - 1e-6) * step
	var gy1 := ceilf(max_gy / step + 1e-6) * step
	var gx := gx0
	while gx <= gx1 + step * 0.001:
		var qq := TrenchBroomGrid.world_to_quake(gx)
		var st: Dictionary = _tb_grid_line_style(qq, minor_quake)
		var pa := grid_to_screen_draw(gx, min_gy)
		var pb := grid_to_screen_draw(gx, max_gy)
		draw_line(pa, pb, st.color, st.width)
		gx += step
	var gy := gy0
	while gy <= gy1 + step * 0.001:
		var qq2 := TrenchBroomGrid.world_to_quake(gy)
		var st2: Dictionary = _tb_grid_line_style(qq2, minor_quake)
		var pc := grid_to_screen_draw(min_gx, gy)
		var pd := grid_to_screen_draw(max_gx, gy)
		draw_line(pc, pd, st2.color, st2.width)
		gy += step
	var origin := grid_to_screen_draw(0.0, 0.0)
	draw_line(Vector2(0, origin.y), Vector2(size.x, origin.y), Color(0.95, 0.2, 0.15, 0.9), 2.0)
	draw_line(Vector2(origin.x, 0), Vector2(origin.x, size.y), Color(0.2, 0.85, 0.25, 0.9), 2.0)


func _draw_background_image() -> void:
	if background_image == null or background_scale <= 1e-6 or background_alpha <= 1e-4:
		return

	var half := 0.5 * background_scale
	var c0 := grid_to_screen_draw(-half, -half)
	var c1 := grid_to_screen_draw(half, half)
	var bounds_w := absf(c1.x - c0.x)
	var bounds_h := absf(c1.y - c0.y)
	if bounds_w < 1.0 or bounds_h < 1.0:
		return

	var tex_w := float(background_image.get_width())
	var tex_h := float(background_image.get_height())
	var ratio := minf(1.0 / tex_w, 1.0 / tex_h)
	var w := tex_w * ratio * bounds_w
	var h := tex_h * ratio * bounds_h

	var mid_x := (c0.x + c1.x) * 0.5
	var mid_y := (c0.y + c1.y) * 0.5
	var rect := Rect2(
		Vector2(mid_x - w * 0.5, mid_y - h * 0.5),
		Vector2(w, h)
	)

	draw_texture_rect(background_image, rect, false, Color(1, 1, 1, background_alpha))


func _draw_shape_filled_outline(sh: Variant) -> void:
	var outline := Color(0.45, 0.78, 1.0, 0.95)
	var fill := Color(0.18, 0.42, 0.62, 0.22)
	sh.validate()
	var polys: Array = sh.generate_concave_polygons(false)
	for poly in polys:
		var n: int = poly.vertices.size()
		if n < 2:
			continue
		var pts2: PackedVector2Array = PackedVector2Array()
		for i in range(n):
			var v = poly.vertices[i]
			var pos: Vector3 = v.position
			pts2.append(grid_to_screen_draw(pos.x, pos.y))
		if pts2.size() >= 3:
			draw_colored_polygon(pts2, fill)
		var loop: PackedVector2Array = PackedVector2Array()
		for i in range(n):
			var v2 = poly.vertices[i]
			var p3: Vector3 = v2.position
			loop.append(grid_to_screen_draw(p3.x, p3.y))
		if not loop.is_empty():
			loop.append(loop[0])
			draw_polyline(loop, outline, 2.0, true)


func _draw_parametric_edges() -> void:
	for sh in project.shapes:
		for seg in sh.segments:
			var t: int = seg.generator.type
			if t != _Enums.SegmentGeneratorType.ARCH and t != _Enums.SegmentGeneratorType.SINE and t != _Enums.SegmentGeneratorType.REPEAT:
				continue
			var col := Color(0.95, 0.45, 0.2, 0.85) if t == _Enums.SegmentGeneratorType.ARCH else Color(0.95, 0.9, 0.2, 0.85) if t == _Enums.SegmentGeneratorType.SINE else Color(0.25, 0.85, 0.95, 0.85)
			var prev: Vector2 = seg.position
			for p in seg.generator.for_each_additional_segment_point():
				var a := grid_to_screen_draw(prev.x, prev.y)
				var b := grid_to_screen_draw(p.x, p.y)
				draw_line(a, b, col, 1.25)
				prev = p
			var e: Vector2 = seg.next.position
			draw_line(grid_to_screen_draw(prev.x, prev.y), grid_to_screen_draw(e.x, e.y), col, 1.25)


func _draw_bezier_decorations() -> void:
	for sh in project.shapes:
		for seg in sh.segments:
			if seg.generator.type != _Enums.SegmentGeneratorType.BEZIER:
				continue
			var gen = seg.generator
			var s0 := grid_to_screen_draw(seg.position.x, seg.position.y)
			var s1 := grid_to_screen_draw(gen.bezier_pivot1.position.x, gen.bezier_pivot1.position.y)
			var s2 := grid_to_screen_draw(gen.bezier_pivot2.position.x, gen.bezier_pivot2.position.y)
			var s3 := grid_to_screen_draw(seg.next.position.x, seg.next.position.y)
			var cyan := Color(0, 0.85, 0.85, 0.7)
			var blue := Color(0.25, 0.45, 1.0, 0.75)
			if gen.bezier_quadratic:
				draw_dashed_line(s0, s1, cyan, 6.0, 4.0)
				draw_dashed_line(s1, s3, cyan, 6.0, 4.0)
			else:
				draw_line(s0, s1, blue, 1.0)
				draw_line(s3, s2, blue, 1.0)
			_draw_pivot_handle(gen.bezier_pivot1)
			if not gen.bezier_quadratic:
				_draw_pivot_handle(gen.bezier_pivot2)
		for seg2 in sh.segments:
			if seg2.generator.type == _Enums.SegmentGeneratorType.SINE:
				_draw_pivot_handle(seg2.generator.sine_pivot1)


func _draw_pivot_handle(pivot: Variant) -> void:
	var p := grid_to_screen_draw(pivot.position.x, pivot.position.y)
	var half := 4.0
	var r := Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
	var c := Color(1.0, 0.92, 0.2, 0.95) if pivot.selected else Color(1.0, 0.85, 0.15, 0.85)
	draw_rect(r, c)


func _draw_measure_overlay() -> void:
	if _active_tool != _Enums.Editor2DTool.MEASURE:
		return
	var p1 := grid_to_screen_draw(_measure_start.x, _measure_start.y)
	var p2 := grid_to_screen_draw(_measure_end.x, _measure_end.y)
	draw_line(p1, p2, Color.WHITE, 2.0)
	draw_dashed_line(p1, p2, Color.RED, 10.0, 6.0)
	draw_circle(p1, 6.0, Color(1.0, 0.5, 0.0))
	draw_circle(p2, 6.0, Color(1.0, 0.5, 0.0))
	if not _measure_proc or _measure_length <= 1e-6:
		return
	var font := ThemeDB.fallback_font
	var text := "%.5f" % _measure_length
	text = text.rstrip("0").rstrip(".") + "u"
	var mid := (p1 + p2) * 0.5
	draw_string(font, mid + Vector2(-1, -1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0, 0, 0, 0.85))
	draw_string(font, mid, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)


func _try_pick_vertex(g: Vector2, max_dist: float):
	var best = null
	var best_d := INF
	for sh in project.shapes:
		for s in sh.segments:
			var d := g.distance_to(s.position)
			if d < max_dist and d < best_d:
				best_d = d
				best = s
	return best


func _try_pick_bezier_pivot(g: Vector2, max_dist: float):
	var best = null
	var best_d := INF
	for sh in project.shapes:
		for s in sh.segments:
			if s.generator.type != _Enums.SegmentGeneratorType.BEZIER:
				continue
			var gen = s.generator
			var d1 := g.distance_to(gen.bezier_pivot1.position)
			if d1 < max_dist and d1 < best_d:
				best_d = d1
				best = gen.bezier_pivot1
			if not gen.bezier_quadratic:
				var d2 := g.distance_to(gen.bezier_pivot2.position)
				if d2 < max_dist and d2 < best_d:
					best_d = d2
					best = gen.bezier_pivot2
	return best


func _try_pick_sine_pivot(g: Vector2, max_dist: float):
	var best = null
	var best_d := INF
	for sh in project.shapes:
		for s in sh.segments:
			if s.generator.type != _Enums.SegmentGeneratorType.SINE:
				continue
			var d1 := g.distance_to(s.generator.sine_pivot1.position)
			if d1 < max_dist and d1 < best_d:
				best_d = d1
				best = s.generator.sine_pivot1
	return best


func _apply_marquee_selection(add_to_existing: bool) -> void:
	var g0 := screen_to_grid(_marquee_start)
	var g1 := screen_to_grid(_marquee_end)
	var min_x := minf(g0.x, g1.x)
	var max_x := maxf(g0.x, g1.x)
	var min_y := minf(g0.y, g1.y)
	var max_y := maxf(g0.y, g1.y)
	if not add_to_existing:
		project.clear_selection()
	for sh in project.shapes:
		for seg in sh.segments:
			var p: Vector2 = seg.position
			if p.x >= min_x and p.x <= max_x and p.y >= min_y and p.y <= max_y:
				seg.selected = true
			if seg.generator.type == _Enums.SegmentGeneratorType.BEZIER:
				var gen = seg.generator
				var p1: Vector2 = gen.bezier_pivot1.position
				if p1.x >= min_x and p1.x <= max_x and p1.y >= min_y and p1.y <= max_y:
					gen.bezier_pivot1.selected = true
				if not gen.bezier_quadratic:
					var p2: Vector2 = gen.bezier_pivot2.position
					if p2.x >= min_x and p2.x <= max_x and p2.y >= min_y and p2.y <= max_y:
						gen.bezier_pivot2.selected = true
			elif seg.generator.type == _Enums.SegmentGeneratorType.SINE:
				var sp: Vector2 = seg.generator.sine_pivot1.position
				if sp.x >= min_x and sp.x <= max_x and sp.y >= min_y and sp.y <= max_y:
					seg.generator.sine_pivot1.selected = true


func _try_delete_selected_vertices() -> bool:
	project.validate()
	var any_removed := false
	var blocked := false
	for sh in project.shapes:
		var to_remove: Array = []
		for s in sh.segments:
			if s.selected:
				to_remove.append(s)
		if to_remove.is_empty():
			continue
		if sh.segments.size() - to_remove.size() < 3:
			blocked = true
			continue
		to_remove.sort_custom(func(a, b): return sh.segments.find(a) > sh.segments.find(b))
		for s in to_remove:
			if sh.segments.size() <= 3:
				break
			var prev = s.previous
			sh.remove_segment(s)
			prev.generator = _ShapeSegmentGenerator.new(prev, _Enums.SegmentGeneratorType.LINEAR)
			any_removed = true
	if any_removed:
		project.invalidate()
		project.clear_selection()
		project_changed.emit()
		queue_redraw()
	elif blocked:
		push_warning("ShapeUp: each shape must keep at least 3 vertices.")
	return any_removed


func _insert_vertex_on_edge(host, raw: Vector2) -> void:
	var snap_pt := _snap_grid(raw)
	if snap_pt.distance_to(host.position) <= 1e-4 or snap_pt.distance_to(host.next.position) <= 1e-4:
		return
	before_project_mutation.emit()
	var shp = host.shape
	var new_seg := _ShapeSegment.new(shp, snap_pt.x, snap_pt.y)
	shp.insert_segment_before(host.next, new_seg)
	host.generator = _ShapeSegmentGenerator.new(host, _Enums.SegmentGeneratorType.LINEAR)
	project.invalidate()
	project.clear_selection()
	project_changed.emit()
	queue_redraw()


func _nearest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	return _MathEx.find_nearest_point_on_line(p, a, b)


func _try_handle_tool_specific_input(event: InputEvent) -> bool:
	if project == null:
		return false
	if _active_tool == _Enums.Editor2DTool.MEASURE:
		return _handle_measure_tool_input(event)
	if _active_tool == _Enums.Editor2DTool.CUT:
		return _handle_cut_tool_input(event)
	return false


func _handle_measure_tool_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_panning:
			return false
		var g := _snap_grid(screen_to_grid(mm.position))
		if not _measure_proc:
			_measure_start = g
			_measure_end = g
			queue_redraw()
			accept_event()
			return true
		if _measure_dragging:
			_measure_end = g
			_measure_length = _measure_start.distance_to(_measure_end)
			queue_redraw()
			accept_event()
			return true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if _is_panning:
			return false
		var g2 := _snap_grid(screen_to_grid(mb.position))
		if mb.pressed:
			_measure_start = g2
			_measure_end = g2
			_measure_proc = true
			_measure_dragging = true
			_measure_length = 0.0
			queue_redraw()
			accept_event()
			return true
		_measure_end = g2
		_measure_length = _measure_start.distance_to(_measure_end)
		if _measure_length <= 1e-6:
			_measure_proc = false
		_measure_dragging = false
		queue_redraw()
		accept_event()
		return true
	return false


func _handle_cut_tool_input(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return false
	if _is_panning:
		return false
	var g := screen_to_grid(mb.position)
	var edge_tol := EDGE_PICK_PX / _zoom
	var host = project.find_segment_line_at_position(g, edge_tol)
	if host == null:
		accept_event()
		return true
	var nearest := _nearest_point_on_segment(g, host.position, host.next.position)
	_insert_vertex_on_edge(host, nearest)
	accept_event()
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		grab_focus()

	if event is InputEventMouseButton:
		var mb0 := event as InputEventMouseButton
		if mb0.button_index == MOUSE_BUTTON_MIDDLE and mb0.pressed:
			_is_panning = true
			_last_pan_mouse = mb0.position
			accept_event()
			return
		elif mb0.button_index == MOUSE_BUTTON_MIDDLE and not mb0.pressed:
			_is_panning = false
			accept_event()
			return
		elif mb0.pressed and (mb0.button_index == MOUSE_BUTTON_WHEEL_UP or mb0.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if mb0.ctrl_pressed or mb0.meta_pressed:
				# Matches C# ShapeEditor2DView: wheel up → finer snap, wheel down → coarser.
				var next: float = (
					TrenchBroomGrid.next_finer_snap_world(snap_increment)
					if mb0.button_index == MOUSE_BUTTON_WHEEL_UP
					else TrenchBroomGrid.next_coarser_snap_world(snap_increment)
				)
				if absf(next - snap_increment) > 1e-8:
					snap_increment = next
					snap_increment_adjusted.emit(snap_increment)
			else:
				var new_z := _zoom * (ZOOM_STEP if mb0.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
				_apply_zoom_towards(mb0.position, new_z)
			queue_redraw()
			accept_event()
			return

	if project == null:
		return

	project.validate()

	if event is InputEventKey:
		var ik := event as InputEventKey
		if ik.pressed and not ik.echo and (ik.keycode == KEY_DELETE or ik.keycode == KEY_BACKSPACE):
			before_project_mutation.emit()
			_try_delete_selected_vertices()
			accept_event()
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if project.has_any_fully_selected_edge():
				_open_edge_context_menu_at(mb.position)
			accept_event()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _try_handle_tool_specific_input(event):
				return

			var shift := mb.shift_pressed
			var g := screen_to_grid(mb.position)
			var edge_tol := EDGE_PICK_PX / _zoom
			var vert_tol := VERTEX_PICK_PX / _zoom
			var pivot_tol := PIVOT_PICK_PX / _zoom

			if mb.pressed:
				_left_button_held = true
				if _is_panning:
					return

				if mb.double_click:
					if (
						_try_pick_vertex(g, vert_tol) == null
						and _try_pick_bezier_pivot(g, pivot_tol) == null
						and _try_pick_sine_pivot(g, pivot_tol) == null
					):
						var ins = project.try_find_edge_insert_point(g, edge_tol, vert_tol * 0.9)
						if ins != null:
							var host = ins["host"]
							var raw: Vector2 = ins["closest"]
							_insert_vertex_on_edge(host, raw)
					accept_event()
					return

				_drag_vertex_segment = null
				_drag_pivot = null
				_vertex_drag_undo_pushed = false
				_pivot_drag_undo_pushed = false
				_marquee_pending = false
				_marquee_dragging = false

				if _active_tool == _Enums.Editor2DTool.ROTATE and _VertexSelectionTransforms.has_selected_segment_vertex(project):
					var g_unsnapped := screen_to_grid(mb.position)
					_begin_rotate_drag(g_unsnapped, mb.position)
					accept_event()
					return

				var bp = _try_pick_bezier_pivot(g, pivot_tol)
				if bp != null:
					if not shift:
						project.clear_selection()
					else:
						bp.selected = not bp.selected
					if not shift or bp.selected:
						if not shift:
							bp.selected = true
						_drag_pivot = bp
						_pivot_drag_origin = bp.position
						_pivot_drag_undo_pushed = false
					project_changed.emit()
					queue_redraw()
					accept_event()
					return

				var sp = _try_pick_sine_pivot(g, pivot_tol)
				if sp != null:
					if not shift:
						project.clear_selection()
					else:
						sp.selected = not sp.selected
					if not shift or sp.selected:
						if not shift:
							sp.selected = true
						_drag_pivot = sp
						_pivot_drag_origin = sp.position
						_pivot_drag_undo_pushed = false
					project_changed.emit()
					queue_redraw()
					accept_event()
					return

				var vertex_seg = _try_pick_vertex(g, vert_tol)
				if vertex_seg != null:
					if not shift:
						if not vertex_seg.selected:
							project.clear_selection()
						vertex_seg.selected = true
						_drag_vertex_segment = vertex_seg
						_vertex_drag_last_grid = _snap_grid(g)
						_vertex_drag_undo_pushed = false
					else:
						vertex_seg.selected = not vertex_seg.selected
						if vertex_seg.selected:
							_drag_vertex_segment = vertex_seg
							_vertex_drag_last_grid = _snap_grid(g)
							_vertex_drag_undo_pushed = false
					project_changed.emit()
					queue_redraw()
					accept_event()
					return

				if _effective_click_insert_vertex():
					var ins2 = project.try_find_edge_insert_point(g, edge_tol, vert_tol * 0.9)
					if ins2 != null:
						var ins_host = ins2["host"]
						var ins_raw: Vector2 = ins2["closest"]
						_insert_vertex_on_edge(ins_host, ins_raw)
					accept_event()
					return

				var edge_seg = project.find_segment_line_at_position(g, edge_tol)
				if edge_seg != null:
					if not shift:
						project.clear_selection()
						edge_seg.selected = true
						edge_seg.next.selected = true
					else:
						var on: bool = not (edge_seg.selected and edge_seg.next.selected)
						edge_seg.selected = on
						edge_seg.next.selected = on
					_drag_vertex_segment = (
						edge_seg
						if g.distance_to(edge_seg.position) <= g.distance_to(edge_seg.next.position)
						else edge_seg.next
					)
					_vertex_drag_last_grid = _snap_grid(g)
					_vertex_drag_undo_pushed = false
					project_changed.emit()
					queue_redraw()
					accept_event()
					return

				_marquee_start = mb.position
				_marquee_end = mb.position
				_marquee_pending = true
				_marquee_had_shift = shift
				accept_event()
				return
			else:
				_left_button_held = false
				_cancel_rotate_drag_session()
				if _marquee_dragging:
					_apply_marquee_selection(_marquee_had_shift)
				elif _marquee_pending and not _marquee_had_shift:
					project.clear_selection()
				_marquee_pending = false
				_marquee_dragging = false
				_drag_vertex_segment = null
				_drag_pivot = null
				_vertex_drag_undo_pushed = false
				_pivot_drag_undo_pushed = false
				project_changed.emit()
				queue_redraw()
				accept_event()
				return

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_panning and (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_pan += mm.position - _last_pan_mouse
			_last_pan_mouse = mm.position
			queue_redraw()
			accept_event()
			return

		if _try_handle_tool_specific_input(event):
			return

		var left_held := _left_button_held or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if _rotate_drag_active and left_held:
			_process_rotate_drag_motion(mm.position)
			return
		if not left_held:
			return

		if _marquee_pending and not _marquee_dragging:
			if _marquee_start.distance_to(mm.position) >= MARQUEE_DRAG_THRESHOLD_PX:
				if not _marquee_had_shift:
					project.clear_selection()
					project_changed.emit()
				_marquee_dragging = true

		if _marquee_dragging:
			_marquee_end = mm.position
			queue_redraw()
			accept_event()
			return

		if _drag_pivot != null:
			var snapped_p := _snap_grid(screen_to_grid(mm.position))
			if not _pivot_drag_undo_pushed and snapped_p.distance_to(_pivot_drag_origin) > 1e-8:
				before_project_mutation.emit()
				_pivot_drag_undo_pushed = true
			_drag_pivot.position = snapped_p
			project_changed.emit()
			queue_redraw()
			accept_event()
			return

		if _drag_vertex_segment != null:
			var grid_now := _snap_grid(screen_to_grid(mm.position))
			var delta := grid_now - _vertex_drag_last_grid
			if delta.length_squared() < 1e-16:
				accept_event()
				return
			if not _vertex_drag_undo_pushed:
				before_project_mutation.emit()
				_vertex_drag_undo_pushed = true
			_vertex_drag_last_grid = grid_now
			_VertexSelectionTransforms.translate_selection(project, delta)
			project_changed.emit()
			queue_redraw()
			accept_event()
			return


static func _try_find_edge_from_two_vertices(shape) -> Variant:
	var a = null
	var b = null
	for s in shape.segments:
		if not s.selected:
			continue
		if a == null:
			a = s
		elif b == null:
			b = s
		else:
			return null
	if a == null or b == null:
		return null
	if a.next == b:
		return a
	if b.next == a:
		return b
	return null


func _apply_bezier_to_segment(seg) -> void:
	before_project_mutation.emit()
	seg.generator = _ShapeSegmentGenerator.new(seg, _Enums.SegmentGeneratorType.BEZIER)
	project.invalidate()
	project.clear_selection()
	project_changed.emit()
	queue_redraw()


func _apply_linear_to_segment(seg) -> void:
	before_project_mutation.emit()
	seg.generator = _ShapeSegmentGenerator.new(seg, _Enums.SegmentGeneratorType.LINEAR)
	project.invalidate()
	project.clear_selection()
	project_changed.emit()
	queue_redraw()


func convert_selected_edge_to_bezier() -> void:
	if project == null:
		return
	project.validate()
	for sh in project.shapes:
		var edge = _try_find_edge_from_two_vertices(sh)
		if edge != null:
			_apply_bezier_to_segment(edge)
			return
	for sh2 in project.shapes:
		for seg in sh2.segments:
			if seg.selected and seg.next.selected:
				_apply_bezier_to_segment(seg)
				return


func convert_selected_edge_to_linear() -> void:
	if project == null:
		return
	project.validate()
	for sh in project.shapes:
		var edge = _try_find_edge_from_two_vertices(sh)
		if edge != null:
			_apply_linear_to_segment(edge)
			return
	for sh2 in project.shapes:
		for seg in sh2.segments:
			if seg.selected and seg.next.selected:
				_apply_linear_to_segment(seg)
				return


func flip_selection_horizontally() -> void:
	if project == null:
		return
	before_project_mutation.emit()
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			var pos: Vector2 = seg.position
			pos.x *= -1.0
			seg.position = pos
			var g = seg.generator
			if g.type == _Enums.SegmentGeneratorType.BEZIER:
				var bp1: Vector2 = g.bezier_pivot1.position
				bp1.x *= -1.0
				g.bezier_pivot1.position = bp1
				if not g.bezier_quadratic:
					var bp2: Vector2 = g.bezier_pivot2.position
					bp2.x *= -1.0
					g.bezier_pivot2.position = bp2
			elif g.type == _Enums.SegmentGeneratorType.SINE:
				var sp: Vector2 = g.sine_pivot1.position
				sp.x *= -1.0
				g.sine_pivot1.position = sp
			g.flip_direction()
	project.invalidate()
	project_changed.emit()
	queue_redraw()


func flip_selection_vertically() -> void:
	if project == null:
		return
	before_project_mutation.emit()
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			var pos: Vector2 = seg.position
			pos.y *= -1.0
			seg.position = pos
			var g = seg.generator
			if g.type == _Enums.SegmentGeneratorType.BEZIER:
				var bp1: Vector2 = g.bezier_pivot1.position
				bp1.y *= -1.0
				g.bezier_pivot1.position = bp1
				if not g.bezier_quadratic:
					var bp2: Vector2 = g.bezier_pivot2.position
					bp2.y *= -1.0
					g.bezier_pivot2.position = bp2
			elif g.type == _Enums.SegmentGeneratorType.SINE:
				var sp: Vector2 = g.sine_pivot1.position
				sp.y *= -1.0
				g.sine_pivot1.position = sp
			g.flip_direction()
	project.invalidate()
	project_changed.emit()
	queue_redraw()


func snap_selection_to_grid() -> void:
	if project == null:
		return
	before_project_mutation.emit()
	project.validate()
	for sh in project.shapes:
		for seg in sh.segments:
			if not seg.selected:
				continue
			seg.position = _snap_grid(seg.position)
			var g = seg.generator
			if g.type == _Enums.SegmentGeneratorType.BEZIER:
				g.bezier_pivot1.position = _snap_grid(g.bezier_pivot1.position)
				if not g.bezier_quadratic:
					g.bezier_pivot2.position = _snap_grid(g.bezier_pivot2.position)
			elif g.type == _Enums.SegmentGeneratorType.SINE:
				g.sine_pivot1.position = _snap_grid(g.sine_pivot1.position)
	project.invalidate()
	project_changed.emit()
	queue_redraw()
