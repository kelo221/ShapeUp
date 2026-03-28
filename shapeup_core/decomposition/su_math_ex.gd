## Minimal MathEx (Velcro-style) for Bayazit / polygon 2D ops — mirrors C# ShapeUp.Core.ShapeEditor.MathEx subset.
extends RefCounted
class_name MathEx

const EPSILON_5 := 1e-5
const EPSILON_VELCRO := 1.192092896e-07


static func area_vec2(a: Vector2, b: Vector2, c: Vector2) -> float:
	return a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)


static func area2d_vec3(a: Vector3, b: Vector3, c: Vector3) -> float:
	return a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)


static func float_in_range(value: float, min_v: float, max_v: float) -> bool:
	return value >= min_v and value <= max_v


static func is_collinear(a: Vector2, b: Vector2, c: Vector2, tolerance: float = 0.0) -> bool:
	var ar := area_vec2(a, b, c)
	return float_in_range(ar, -tolerance, tolerance)


## Eric Jordan / Velcro-style segment intersection; grazing returns false.
static func line_intersect2(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> Variant:
	if a0 == b0 or a0 == b1 or a1 == b0 or a1 == b1:
		return null
	var x1 := a0.x
	var y1 := a0.y
	var x2 := a1.x
	var y2 := a1.y
	var x3 := b0.x
	var y3 := b0.y
	var x4 := b1.x
	var y4 := b1.y
	if maxf(x1, x2) < minf(x3, x4) or maxf(x3, x4) < minf(x1, x2):
		return null
	if maxf(y1, y2) < minf(y3, y4) or maxf(y3, y4) < minf(y1, y2):
		return null
	var ua := (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)
	var ub := (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)
	var denom := (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
	if absf(denom) < EPSILON_VELCRO:
		return null
	ua /= denom
	ub /= denom
	if ua > 0.0 and ua < 1.0 and ub > 0.0 and ub < 1.0:
		return Vector2(x1 + ua * (x2 - x1), y1 + ua * (y2 - y1))
	return null


## Jeremy Bell segment–segment intersection; coincident lines return false.
static func line_intersect(
	point1: Vector2, point2: Vector2, point3: Vector2, point4: Vector2,
	first_is_segment: bool, second_is_segment: bool
) -> Variant:
	var a := point4.y - point3.y
	var b := point2.x - point1.x
	var c := point4.x - point3.x
	var d := point2.y - point1.y
	var denom := (a * b) - (c * d)
	if denom >= -EPSILON_VELCRO and denom <= EPSILON_VELCRO:
		return null
	var e := point1.y - point3.y
	var f := point1.x - point3.x
	var one_over_denom := 1.0 / denom
	var ua := ((c * e) - (a * f)) * one_over_denom
	if first_is_segment and (ua < 0.0 or ua > 1.0):
		return null
	var ub := ((b * e) - (d * f)) * one_over_denom
	if second_is_segment and (ub < 0.0 or ub > 1.0):
		return null
	if ua == 0.0 and ub == 0.0:
		return null
	return Vector2(point1.x + ua * b, point1.y + ua * d)


const EPSILON_4 := 1e-4
const EPSILON_3 := 1e-3
const EPSILON_2 := 1e-2
const EPSILON_1 := 1e-1
const TWO_PI := PI * 2.0


static func snapf(value: float, snap: float) -> float:
	if snap == 0.0:
		return value
	return roundf(value / snap) * snap


static func snap_vec2(value: Vector2, snap: float) -> Vector2:
	return Vector2(snapf(value.x, snap), snapf(value.y, snap))


static func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var nearest := find_nearest_point_on_line(point, a, b)
	return point.distance_to(nearest)


static func find_nearest_point_on_line(point: Vector2, origin: Vector2, end: Vector2) -> Vector2:
	var heading := end - origin
	var magnitude_max := heading.length()
	if magnitude_max < EPSILON_5:
		return origin
	var dir := heading / magnitude_max
	var lhs := point - origin
	var dot_p: float = lhs.x * dir.x + lhs.y * dir.y
	dot_p = clampf(dot_p, 0.0, magnitude_max)
	return origin + dir * dot_p


static func is_point_on_line2(point: Vector2, from_v: Vector2, to_v: Vector2, max_distance: float) -> bool:
	var nearest := find_nearest_point_on_line(point, from_v, to_v)
	return nearest.distance_to(point) <= max_distance


static func bezier_get_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var omt := 1.0 - t
	return (
		omt * omt * omt * p0
		+ 3.0 * omt * omt * t * p1
		+ 3.0 * omt * t * t * p2
		+ t * t * t * p3
	)


static func get_bezier_control_points_quadratic(p1: Vector2, p2: Vector2, p3: Vector2) -> Array:
	var n12 := (p2 - p1).normalized()
	var n32 := (p2 - p3).normalized()
	var d1 := p1.distance_to(p2)
	var d2 := p3.distance_to(p2)
	var cp1 := p1 + n12 * (d1 * (2.0 / 3.0))
	var cp2 := p3 + n32 * (d2 * (2.0 / 3.0))
	return [cp1, cp2]


static func rotate_point_around_pivot_2d(point: Vector2, pivot: Vector2, degrees: float) -> Vector2:
	var p := point - pivot
	var r := deg_to_rad(degrees)
	var x := p.x * cos(r) - p.y * sin(r)
	var y := p.y * cos(r) + p.x * sin(r)
	return Vector2(x, y) + pivot


static func rotate_point_around_pivot_3d(point: Vector3, pivot: Vector3, angles_deg: Vector3) -> Vector3:
	var rad := Vector3(deg_to_rad(angles_deg.x), deg_to_rad(angles_deg.y), deg_to_rad(angles_deg.z))
	var b := Basis.from_euler(rad)
	return b * (point - pivot) + pivot


## Minimal multi-segment quadratic spline for extrusion preview (C# MathEx.Spline3 subset).
class Spline3:
	var points: PackedVector3Array


	func _init(pts: PackedVector3Array) -> void:
		points = pts


	func curve_count() -> int:
		return maxi(0, (points.size() - 1) / 2)


	func get_point(t: float) -> Vector3:
		var n := points.size()
		if n < 3:
			return Vector3.ZERO
		var i: int
		var local_t: float
		if t >= 1.0:
			local_t = 1.0
			i = n - 3
		else:
			var tc := clampf(t, 0.0, 1.0) * float(curve_count())
			i = int(tc)
			local_t = tc - float(i)
			i *= 2
		if i + 2 >= n:
			i = n - 3
		return _quad_point(points[i], points[i + 1], points[i + 2], local_t)


	func get_forward(t: float) -> Vector3:
		var a := get_point(clampf(t - 0.001, 0.0, 1.0))
		var b := get_point(clampf(t + 0.001, 0.0, 1.0))
		var d := b - a
		if d.length_squared() < 1e-16:
			return Vector3(0.0, 0.0, -1.0)
		return d.normalized()


	func get_right(t: float) -> Vector3:
		var a := get_point(clampf(t - 0.001, 0.0, 1.0))
		var b := get_point(clampf(t + 0.001, 0.0, 1.0))
		var delta := (b - a).normalized()
		var r := Vector3(-delta.z, 0.0, delta.x)
		if r.length_squared() < 1e-16:
			return Vector3.RIGHT
		return r.normalized()


	func get_up(t: float) -> Vector3:
		var d := get_point(clampf(t - 0.001, 0.0, 1.0))
		var b := get_point(clampf(t + 0.001, 0.0, 1.0))
		var delta := (b - d).normalized()
		var u := delta.cross(get_right(t))
		if u.length_squared() < 1e-16:
			return Vector3.UP
		return u.normalized()


	static func _quad_point(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
		t = clampf(t, 0.0, 1.0)
		var omt := 1.0 - t
		return omt * omt * p0 + 2.0 * omt * t * p1 + t * t * p2


class Circle:
	var radius: float
	var diameter: float
	var circumference: float
	var circle_area: float
	var sphere_surface_area: float
	var sphere_volume: float


	func _init(p_radius: float = 0.0) -> void:
		set_radius(p_radius)


	func set_radius(value: float) -> void:
		radius = value
		diameter = radius * 2.0
		circumference = radius * 2.0 * PI
		circle_area = radius * radius * PI
		sphere_surface_area = radius * radius * 4.0 * PI
		sphere_volume = radius * radius * radius * 4.0 * PI / 3.0


	func set_diameter(value: float) -> void:
		set_radius(value / 2.0)


	func set_circumference(value: float) -> void:
		set_radius(value / (2.0 * PI))


	func set_circle_area(value: float) -> void:
		set_radius(sqrt(value / PI))


	func set_sphere_surface_area(value: float) -> void:
		set_radius(sqrt(value / (PI * 4.0)))


	func set_sphere_volume(value: float) -> void:
		set_radius(pow(value * 3.0 / (PI * 4.0), 1.0 / 3.0))


	func get_circle_position(t: float) -> Vector3:
		t = fposmod(t, 1.0)
		return Vector3(sin(t * PI * 2.0) * radius, 0.0, cos(t * PI * 2.0) * radius)


	static func get_circle_radius_that_fits_circumference(p_circumference: float, t: float) -> float:
		t = fposmod(t, 1.0)
		if t == 0.0:
			return p_circumference / (PI * 2.0)
		return p_circumference / (t * PI * 2.0)


	static func get_circle_that_fits_circumference(p_circumference: float, t: float) -> Circle:
		return Circle.new(get_circle_radius_that_fits_circumference(p_circumference, t))
