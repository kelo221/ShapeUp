extends RefCounted

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _ShapeSegment := preload("res://shapeup_core/shape_editor/shape_segment.gd")
const _ShapeShape := preload("res://shapeup_core/shape_editor/shape_shape.gd")
const _ShapeProject := preload("res://shapeup_core/shape_editor/shape_project.gd")
const _MathEx := preload("res://shapeup_core/decomposition/su_math_ex.gd")

static func get_fully_selected_shapes(project) -> Array:
	project.validate()
	var result = []
	for s in project.shapes:
		if s.is_selected():
			result.append(s)
	return result

static func collect_selected_positions(project) -> Array[Vector2]:
	project.validate()
	var points: Array[Vector2] = []
	for shape in project.shapes:
		for segment in shape.segments:
			if segment.selected:
				points.append(segment.position)
			for sel in segment.generator.for_each_selectable_object():
				if sel.selected:
					points.append(sel.position)
	return points

static func extrude_selected_linear_edges(project, before_mutation: Callable) -> void:
	project.validate()
	var to_extrude = []
	for shape in project.shapes:
		for seg in shape.segments:
			if seg.selected and seg.next.selected and seg.generator.type == _Enums.SegmentGeneratorType.LINEAR:
				to_extrude.append(seg)
	
	if to_extrude.is_empty():
		return
		
	if before_mutation.is_valid():
		before_mutation.call()
		
	project.clear_selection()
	for segment in to_extrude:
		_extrude_segment(segment)
	project.invalidate()

static func _extrude_segment(segment) -> void:
	var shape = segment.shape
	var position1 = segment.position
	var position2 = segment.next.position

	var s1 = _ShapeSegment.new(shape, position1.x, position1.y)
	s1.selected = true
	shape.insert_segment_before(segment.next, s1)

	var s2 = _ShapeSegment.new(shape, position2.x, position2.y)
	s2.selected = true
	shape.insert_segment_before(segment.next.next, s2)

static func try_shape_from_selection(project, before_mutation: Callable) -> bool:
	var points = collect_selected_positions(project)
	if points.size() < 3:
		return false
		
	if before_mutation.is_valid():
		before_mutation.call()
		
	var shape = _ShapeShape.new()
	shape.segments.clear()
	
	if points.size() == 3:
		if Geometry2D.is_polygon_clockwise(PackedVector2Array(points)):
			points.reverse()
		for p in points:
			shape.add_segment(_ShapeSegment.new(shape, p.x, p.y))
	elif points.size() == 4:
		var a = _MathEx.line_intersect2(points[0], points[1], points[2], points[3]) != null
		var b = _MathEx.line_intersect2(points[1], points[2], points[0], points[3]) != null
		if a or b:
			var t = points[2]
			points[2] = points[3]
			points[3] = t
			
		if Geometry2D.is_polygon_clockwise(PackedVector2Array(points)):
			points.reverse()
			
		for p in points:
			shape.add_segment(_ShapeSegment.new(shape, p.x, p.y))
	else:
		var hull = Geometry2D.convex_hull(PackedVector2Array(points))
		# Geometry2D.convex_hull returns the first point again at the end, so we skip the last.
		for i in range(hull.size() - 1):
			shape.add_segment(_ShapeSegment.new(shape, hull[i].x, hull[i].y))
			
	project.shapes.append(shape)
	project.clear_selection()
	shape.select_all()
	project.invalidate()
	return true

static func duplicate_fully_selected_shapes(project, before_mutation: Callable) -> void:
	var src = get_fully_selected_shapes(project)
	if src.is_empty():
		return
		
	if before_mutation.is_valid():
		before_mutation.call()
		
	project.clear_selection()
	var ox = 0.35
	var oy = 0.35
	for shape in src:
		var clone = shape.clone()
		clone.validate()
		for seg in clone.segments:
			seg.position += Vector2(ox, oy)
		project.shapes.append(clone)
		clone.select_all()
		
	project.invalidate()

static func apply_symmetry_for_selected_shapes(project, before_mutation: Callable) -> void:
	project.validate()
	var any_selected = false
	for s in project.shapes:
		if s.is_selected():
			any_selected = true
			break
			
	if not any_selected:
		return
		
	if before_mutation.is_valid():
		before_mutation.call()
		
	var shapes_to_select = []
	for i in range(project.shapes.size() - 1, -1, -1):
		var shape = project.shapes[i]
		if not shape.is_selected():
			continue
			
		var symmetry_shapes = shape.generate_symmetry_shapes()
		for j in range(symmetry_shapes.size()):
			var sym = symmetry_shapes[j]
			sym.validate()
			project.shapes.insert(i + 1, sym)
			shapes_to_select.append(sym)
			
		shape.symmetry_axes = _Enums.SimpleGlobalAxis.NONE
		
	if shapes_to_select.is_empty():
		return
		
	project.clear_selection()
	for s in shapes_to_select:
		s.select_all()
	project.invalidate()

static func push_fully_selected_shapes(project, to_front: bool, before_mutation: Callable) -> void:
	var move = get_fully_selected_shapes(project)
	if move.is_empty():
		return
		
	if before_mutation.is_valid():
		before_mutation.call()
		
	for shape in move:
		project.shapes.erase(shape)
		
	if to_front:
		for shape in move:
			project.shapes.append(shape)
	else:
		for i in range(move.size() - 1, -1, -1):
			project.shapes.insert(0, move[i])
			
	project.invalidate()

static func serialize_shapes_to_clipboard(shapes: Array) -> String:
	var dict = {"shapes": []}
	for s in shapes:
		var c = s.clone()
		dict["shapes"].append(ShapeupSerialization.shape_to_json(c))
	return JSON.stringify(dict)

static func try_paste_from_clipboard_json(project, json: String, before_mutation: Callable) -> bool:
	if json == null or json.strip_edges() == "":
		return false
		
	var clip = JSON.parse_string(json)
	if clip == null or not (clip is Dictionary):
		return false
		
	if not clip.has("shapes") or clip["shapes"].size() == 0:
		return false
		
	if before_mutation.is_valid():
		before_mutation.call()
		
	project.clear_selection()
	for sh_dict in clip["shapes"]:
		var shape = ShapeupSerialization.shape_from_json(sh_dict)
		shape.validate()
		project.shapes.append(shape)
		shape.select_all()
		
	project.invalidate()
	return true
