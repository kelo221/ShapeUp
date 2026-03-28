extends RefCounted
class_name TrenchBroomGrid

const QUAKE_UNITS_PER_WORLD := 64.0
## Minimum snap/grid step in world units (1 Quake unit). Matches C# `MinSnapWorld`.
const MIN_SNAP_WORLD := 1.0 / QUAKE_UNITS_PER_WORLD
## Maximum snap/grid step in world units. Matches C# `MaxSnapWorld`.
const MAX_SNAP_WORLD := 4.0


static func mod(a: int, m: int) -> int:
	if m <= 0:
		return 0
	var r: int = a % m
	return r + m if r < 0 else r


static func smallest_power_of_two_quake_step_at_least(min_world: float) -> float:
	if min_world <= 1e-8:
		return 1.0 / QUAKE_UNITS_PER_WORLD
	var need := maxi(1, int(ceil(min_world * QUAKE_UNITS_PER_WORLD - 1e-6)))
	var p := 1
	while p < need:
		p <<= 1
	return float(p) / QUAKE_UNITS_PER_WORLD


static func pick_viewport_grid_step_world(snap_world: float, zoom_pixels_per_unit: float, min_line_spacing_px: float = 10.0) -> float:
	var s := smallest_power_of_two_quake_step_at_least(snap_world)
	while s * zoom_pixels_per_unit < min_line_spacing_px and s < 1e6:
		s *= 2.0
	return s


static func _log2_pow2(n: int) -> int:
	return int(floor(log(float(n)) / log(2.0)))


static func rotate_snap_step_degrees_from_snap_world(snap_world_min: float) -> float:
	var min_w: float = (1.0 / QUAKE_UNITS_PER_WORLD) if snap_world_min <= 1e-8 else snap_world_min
	var step_world := smallest_power_of_two_quake_step_at_least(min_w)
	var step_quake: int = maxi(1, int(round(step_world * QUAKE_UNITS_PER_WORLD)))
	var quake_exp: int = _log2_pow2(step_quake)
	var pow_i: int = clampi(7 - quake_exp, 1, 8)
	return 360.0 / float(1 << pow_i)


static func snap_angle_degrees(degrees: float, step_degrees: float) -> float:
	if step_degrees <= 1e-8:
		return degrees
	return roundf(degrees / step_degrees) * step_degrees


static func next_finer_snap_world(snap_world: float) -> float:
	var q := smallest_power_of_two_quake_step_at_least(snap_world)
	var finer := q * 0.5
	return MIN_SNAP_WORLD if finer < MIN_SNAP_WORLD - 1e-9 else finer


static func next_coarser_snap_world(snap_world: float) -> float:
	var q := smallest_power_of_two_quake_step_at_least(snap_world)
	var coarse := q * 2.0
	return MAX_SNAP_WORLD if coarse > MAX_SNAP_WORLD + 1e-9 else coarse


static func world_to_quake(world: float) -> int:
	return int(round(world * QUAKE_UNITS_PER_WORLD))


static func map_unity_world_to_quake_file_coords(unity_world: Vector3) -> Vector3i:
	var s := QUAKE_UNITS_PER_WORLD
	var fx := int(round(unity_world.x * s))
	var fy := int(round(unity_world.z * s))
	var fz := -int(round(unity_world.y * s))
	return Vector3i(fx, fy, fz)


static func format_map_file_point(unity_world: Vector3) -> String:
	var c := map_unity_world_to_quake_file_coords(unity_world)
	return "%d %d %d" % [c.x, c.y, c.z]


static func _format_map_number(value: float) -> String:
	if absf(value) < 0.0000005:
		return "0"
	var text := "%.6f" % value
	text = text.rstrip("0").rstrip(".")
	if text.is_empty() or text == "-":
		return "0"
	return text


static func format_map_file_point_precise(unity_world: Vector3) -> String:
	var fx := unity_world.x * QUAKE_UNITS_PER_WORLD
	var fy := unity_world.z * QUAKE_UNITS_PER_WORLD
	var fz := -unity_world.y * QUAKE_UNITS_PER_WORLD
	return "%s %s %s" % [_format_map_number(fx), _format_map_number(fy), _format_map_number(fz)]
