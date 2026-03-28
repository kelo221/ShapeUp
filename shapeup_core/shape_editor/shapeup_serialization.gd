extends RefCounted
class_name ShapeupSerialization

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _PBO := preload("res://shapeup_core/decomposition/polygon_boolean_operator.gd")
## Register before `ShapeProject` so `class_name` types resolve inside shape_project.gd.
const _EditorPolygonExtensionsReg := preload("res://shapeup_core/decomposition/editor_polygon_extensions.gd")
const _BayazitDecomposerReg := preload("res://shapeup_core/decomposition/bayazit_decomposer.gd")
const _DelaunayDecomposerReg := preload("res://shapeup_core/decomposition/delaunay_decomposer.gd")
const _ShapePivot := preload("res://shapeup_core/shape_editor/shape_pivot.gd")
const _ShapeSegmentGenerator := preload("res://shapeup_core/shape_editor/shape_segment_generator.gd")
const _ShapeSegment := preload("res://shapeup_core/shape_editor/shape_segment.gd")
const _ShapeShape := preload("res://shapeup_core/shape_editor/shape_shape.gd")
const _ShapeProject := preload("res://shapeup_core/shape_editor/shape_project.gd")

static func vec2_from_json(v: Variant) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", 0.0)), float(v.get("y", 0.0)))
	return Vector2.ZERO


static func vec2_to_json(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


static func pivot_from_json(d: Dictionary):
	var p = _ShapePivot.new()
	p.position = vec2_from_json(d.get("position", {}))
	p.selected = bool(d.get("selected", false))
	p.gp_vector1 = vec2_from_json(d.get("gpVector1", {}))
	return p


static func pivot_to_json(p) -> Dictionary:
	return {
		"position": vec2_to_json(p.position),
		"selected": p.selected,
		"gpVector1": vec2_to_json(p.gp_vector1),
	}


static func generator_from_json(d: Dictionary, seg):
	var g = _ShapeSegmentGenerator.new(seg, int(d.get("type", 0)))
	g.arch_detail = int(d.get("archDetail", 8))
	g.arch_flipped = bool(d.get("archFlipped", false))
	g.arch_grid_snap_size = float(d.get("archGridSnapSize", 0.0))
	g.arch_mode = int(d.get("archMode", 0))
	g.bezier_detail = int(d.get("bezierDetail", 8))
	g.bezier_grid_snap_size = float(d.get("bezierGridSnapSize", 0.0))
	g.bezier_quadratic = bool(d.get("bezierQuadratic", false))
	if d.has("bezierPivot1"):
		g.bezier_pivot1 = pivot_from_json(d["bezierPivot1"])
	if d.has("bezierPivot2"):
		g.bezier_pivot2 = pivot_from_json(d["bezierPivot2"])
	g.sine_detail = int(d.get("sineDetail", 64))
	g.sine_frequency = float(d.get("sineFrequency", -3.5))
	g.sine_grid_snap_size = float(d.get("sineGridSnapSize", 0.0))
	if d.has("sinePivot1"):
		g.sine_pivot1 = pivot_from_json(d["sinePivot1"])
	g.repeat_segments = int(d.get("repeatSegments", 2))
	g.repeat_times = int(d.get("repeatTimes", 4))
	if g.type == _Enums.SegmentGeneratorType.BEZIER and d.has("bezierPivot1"):
		g._needs_endpoint_geometry_init = false
	elif g.type == _Enums.SegmentGeneratorType.SINE and d.has("sinePivot1"):
		g._needs_endpoint_geometry_init = false
	return g


static func generator_to_json(g) -> Dictionary:
	return {
		"archDetail": g.arch_detail,
		"archFlipped": g.arch_flipped,
		"archGridSnapSize": g.arch_grid_snap_size,
		"archMode": g.arch_mode,
		"bezierDetail": g.bezier_detail,
		"bezierGridSnapSize": g.bezier_grid_snap_size,
		"bezierPivot1": pivot_to_json(g.bezier_pivot1),
		"bezierPivot2": pivot_to_json(g.bezier_pivot2),
		"bezierQuadratic": g.bezier_quadratic,
		"type": g.type,
		"repeatSegments": g.repeat_segments,
		"repeatTimes": g.repeat_times,
		"sineDetail": g.sine_detail,
		"sineFrequency": g.sine_frequency,
		"sineGridSnapSize": g.sine_grid_snap_size,
		"sinePivot1": pivot_to_json(g.sine_pivot1),
	}


static func segment_from_json(d: Dictionary, sh):
	var pos := vec2_from_json(d.get("position", {}))
	var seg = _ShapeSegment.new(sh, pos.x, pos.y)
	seg.selected = bool(d.get("selected", false))
	seg.gp_vector1 = vec2_from_json(d.get("gpVector1", {}))
	seg.material = int(d.get("material", 0))
	if d.has("generator"):
		seg.generator = generator_from_json(d["generator"], seg)
	else:
		seg.generator = _ShapeSegmentGenerator.new(seg, _Enums.SegmentGeneratorType.LINEAR)
	return seg


static func segment_to_json(seg) -> Dictionary:
	return {
		"position": vec2_to_json(seg.position),
		"selected": seg.selected,
		"gpVector1": vec2_to_json(seg.gp_vector1),
		"generator": generator_to_json(seg.generator),
		"material": seg.material,
	}


static func shape_from_json(d: Dictionary):
	var sh = _ShapeShape.new()
	sh.segments.clear()
	sh.boolean_operator = int(d.get("booleanOperator", 0))
	sh.symmetry_axes = int(d.get("symmetryAxes", 0))
	sh.front_material = int(d.get("frontMaterial", 0))
	sh.back_material = int(d.get("backMaterial", 0))
	for sd in d.get("segments", []):
		if sd is Dictionary:
			sh.segments.append(segment_from_json(sd, sh))
	return sh


static func shape_to_json(sh) -> Dictionary:
	var arr: Array = []
	for seg in sh.segments:
		arr.append(segment_to_json(seg))
	return {
		"segments": arr,
		"booleanOperator": sh.boolean_operator,
		"symmetryAxes": sh.symmetry_axes,
		"frontMaterial": sh.front_material,
		"backMaterial": sh.back_material,
	}


static func project_from_json(text: String):
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_error("ShapeupSerialization: invalid JSON")
		return _ShapeProject.new()
	return project_from_dict(data)


static func project_from_dict(data: Dictionary):
	var p = _ShapeProject.new()
	p.shapes.clear()
	p.version = int(data.get("version", 2))
	for shd in data.get("shapes", []):
		if shd is Dictionary:
			p.shapes.append(shape_from_json(shd))
	if p.shapes.is_empty():
		p.shapes.append(_ShapeShape.new())
	if data.has("globalPivot"):
		p.global_pivot = pivot_from_json(data["globalPivot"])
	p.invalidate()
	p.validate()
	return p


static func project_to_json(p) -> String:
	p.validate()
	var arr: Array = []
	for sh in p.shapes:
		arr.append(shape_to_json(sh))
	var root := {
		"version": p.version,
		"shapes": arr,
		"globalPivot": pivot_to_json(p.global_pivot),
	}
	return JSON.stringify(root)


static func deep_equal_variant(a: Variant, b: Variant, eps: float = 1e-4) -> bool:
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_DICTIONARY:
			var da: Dictionary = a
			var db: Dictionary = b
			if da.size() != db.size():
				return false
			for k in da.keys():
				if not db.has(k):
					return false
				if not deep_equal_variant(da[k], db[k], eps):
					return false
			return true
		TYPE_ARRAY:
			var aa: Array = a
			var ab: Array = b
			if aa.size() != ab.size():
				return false
			for i in aa.size():
				if not deep_equal_variant(aa[i], ab[i], eps):
					return false
			return true
		TYPE_FLOAT:
			return absf(a - b) <= eps
		TYPE_INT:
			return a == b
		TYPE_BOOL:
			return a == b
		TYPE_STRING:
			return a == b
		_:
			return a == b
