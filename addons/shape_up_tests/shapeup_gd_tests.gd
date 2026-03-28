extends RefCounted
## Mirrors key assertions from ShapeUp.Tests (C#). Returns error message or empty string if OK.

const _EPS := 1e-4


func _fail(msg: String) -> String:
	push_error("ShapeUp GD test: " + msg)
	return msg


func _f_eq(a: float, b: float, eps: float, ctx: String) -> String:
	return "" if absf(a - b) <= eps else _fail("%s: expected %s ~= %s (eps %s)" % [ctx, a, b, eps])


func run_all() -> String:
	var e: String = ""
	e = _test_trenchbroom_grid()
	if e != "":
		return e
	e = _test_math_ex_distance()
	if e != "":
		return e
	e = _test_json_roundtrip_and_fixture()
	return e


func _test_trenchbroom_grid() -> String:
	var e: String
	if TrenchBroomGrid.mod(0, 64) != 0:
		return _fail("mod 0")
	if TrenchBroomGrid.mod(-64, 64) != 0:
		return _fail("mod -64")
	if TrenchBroomGrid.mod(-65, 64) != 63:
		return _fail("mod -65")
	if TrenchBroomGrid.mod(65, 64) != 1:
		return _fail("mod 65")
	e = _f_eq(TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(1.0 / 64.0), 1.0 / 64.0, 1e-6, "sp2 1/64")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(0.125), 0.125, 1e-6, "sp2 0.125")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(0.11), 0.125, 1e-6, "sp2 0.11")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.smallest_power_of_two_quake_step_at_least(1.0), 1.0, 1e-6, "sp2 1")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.pick_viewport_grid_step_world(0.125, 120.0, 10.0), 0.125, 1e-6, "pick hi zoom")
	if e != "":
		return e
	var coarse: float = TrenchBroomGrid.pick_viewport_grid_step_world(0.125, 8.0, 10.0)
	if coarse <= 0.125:
		return _fail("pick coarse should be > 0.125")
	var q: int = int(round(coarse * TrenchBroomGrid.QUAKE_UNITS_PER_WORLD))
	if q <= 0 or (q & (q - 1)) != 0:
		return _fail("quake coarse not pow2: %d" % q)
	if TrenchBroomGrid.world_to_quake(1.0) != 64:
		return _fail("w2q 1")
	if TrenchBroomGrid.world_to_quake(-1.0) != -64:
		return _fail("w2q -1")
	if TrenchBroomGrid.format_map_file_point(Vector3(1, 2, 3)) != "64 192 -128":
		return _fail("fmt map point got " + TrenchBroomGrid.format_map_file_point(Vector3(1, 2, 3)))
	e = _f_eq(TrenchBroomGrid.rotate_snap_step_degrees_from_snap_world(1.0), 180.0, 1e-4, "rot snap 1")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.rotate_snap_step_degrees_from_snap_world(0.5), 90.0, 1e-4, "rot snap 0.5")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.rotate_snap_step_degrees_from_snap_world(0.25), 45.0, 1e-4, "rot snap 0.25")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.rotate_snap_step_degrees_from_snap_world(0.125), 22.5, 1e-4, "rot snap 0.125")
	if e != "":
		return e
	e = _f_eq(
		TrenchBroomGrid.rotate_snap_step_degrees_from_snap_world(1.0 / 64.0), 360.0 / 128.0, 1e-4, "rot snap 1/64"
	)
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.snap_angle_degrees(23.0, 22.5), 22.5, 1e-4, "snap ang")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.snap_angle_degrees(10.0, 0.0), 10.0, 1e-4, "snap ang off")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.next_finer_snap_world(0.125), 0.0625, 1e-6, "finer")
	if e != "":
		return e
	e = _f_eq(TrenchBroomGrid.next_coarser_snap_world(0.125), 0.25, 1e-6, "coarser")
	if e != "":
		return e
	e = _f_eq(
		TrenchBroomGrid.next_finer_snap_world(TrenchBroomGrid.MIN_SNAP_WORLD),
		TrenchBroomGrid.MIN_SNAP_WORLD,
		1e-6,
		"finer min"
	)
	if e != "":
		return e
	e = _f_eq(
		TrenchBroomGrid.next_coarser_snap_world(TrenchBroomGrid.MAX_SNAP_WORLD),
		TrenchBroomGrid.MAX_SNAP_WORLD,
		1e-6,
		"coarser max"
	)
	return e


func _test_math_ex_distance() -> String:
	var d0 := MathEx.distance_to_segment(Vector2(0.5, 0), Vector2.ZERO, Vector2(1, 0))
	if d0 >= 1e-5:
		return _fail("dist on segment %s" % d0)
	return _f_eq(MathEx.distance_to_segment(Vector2(0.5, 1), Vector2.ZERO, Vector2(1, 0)), 1.0, 1e-4, "dist perp")


func _test_json_roundtrip_and_fixture() -> String:
	var Ser = load("res://shapeup_core/shape_editor/shapeup_serialization.gd")
	var ShapeProjectScript = load("res://shapeup_core/shape_editor/shape_project.gd")
	var project = ShapeProjectScript.new()
	project.shapes[0].segments[0].position = Vector2(1.25, -0.5)
	project.validate()
	var copy = project.clone_project()
	copy.validate()
	var e: String = _f_eq(copy.shapes[0].segments[0].position.x, 1.25, 1e-4, "clone x")
	if e != "":
		return e
	e = _f_eq(copy.shapes[0].segments[0].position.y, -0.5, 1e-4, "clone y")
	if e != "":
		return e
	var json: String = Ser.project_to_json(project)
	var restored = Ser.project_from_json(json)
	restored.validate()
	if restored.shapes.size() != project.shapes.size():
		return _fail("shape count")
	var n: int = project.shapes[0].segments.size()
	if restored.shapes[0].segments.size() != n:
		return _fail("seg count")
	for i in n:
		e = _f_eq(
			restored.shapes[0].segments[i].position.x,
			project.shapes[0].segments[i].position.x,
			1e-4,
			"json seg x"
		)
		if e != "":
			return e
		e = _f_eq(
			restored.shapes[0].segments[i].position.y,
			project.shapes[0].segments[i].position.y,
			1e-4,
			"json seg y"
		)
		if e != "":
			return e
	var path := "res://tests/fixtures/project_default_gd.json"
	if not FileAccess.file_exists(path):
		return _fail("missing golden fixture " + path)
	var golden := FileAccess.get_file_as_string(path)
	var from_golden = Ser.project_from_json(golden)
	from_golden.validate()
	var back: String = Ser.project_to_json(from_golden)
	var d1: Variant = JSON.parse_string(golden)
	var d2: Variant = JSON.parse_string(back)
	if d1 == null or d2 == null:
		return _fail("golden json parse")
	if not Ser.deep_equal_variant(d1, d2, 1e-4):
		return _fail("golden structural round-trip")
	return ""
