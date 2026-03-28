# PolyBool — epsilon utilities (from Epsilon.cs).
extends Object
class_name Epsilon

const _Point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")
const _Intersection := preload("res://shapeup_core/decomposition/poly_bool/intersection.gd")

const _BASE_EPS: float = 1e-10
static var eps: float = _BASE_EPS

static func point_above_or_on_line(pt, left, right) -> bool:
	var ax: float = left.x
	var ay: float = left.y
	var bx: float = right.x
	var by: float = right.y
	var cx: float = pt.x
	var cy: float = pt.y
	var abx: float = bx - ax
	var aby: float = by - ay
	var ab: float = sqrt(abx * abx + aby * aby)
	return abx * (cy - ay) - aby * (cx - ax) >= -eps * ab


static func point_between(pt, left, right) -> bool:
	if points_same(pt, left) or points_same(pt, right):
		return false
	var d_py_ly: float = pt.y - left.y
	var d_rx_lx: float = right.x - left.x
	var d_px_lx: float = pt.x - left.x
	var d_ry_ly: float = right.y - left.y
	var dot := d_px_lx * d_rx_lx + d_py_ly * d_ry_ly
	if dot < 0:
		return false
	var sqlen := d_rx_lx * d_rx_lx + d_ry_ly * d_ry_ly
	return dot <= sqlen


static func points_same_x(p1, p2) -> bool:
	return absf(p1.x - p2.x) < eps


static func points_same_y(p1, p2) -> bool:
	return absf(p1.y - p2.y) < eps


static func points_same(p1, p2) -> bool:
	return absf(p1.x - p2.x) < eps and absf(p1.y - p2.y) < eps


static func points_compare(p1, p2) -> int:
	if points_same_x(p1, p2):
		return 0 if points_same_y(p1, p2) else (-1 if p1.y < p2.y else 1)
	return -1 if p1.x < p2.x else 1


static func points_collinear(p1, p2, p3) -> bool:
	var dx1: float = p1.x - p2.x
	var dy1: float = p1.y - p2.y
	var dx2: float = p2.x - p3.x
	var dy2: float = p2.y - p3.y
	var n1: float = sqrt(dx1 * dx1 + dy1 * dy1)
	var n2: float = sqrt(dx2 * dx2 + dy2 * dy2)
	return absf(dx1 * dy2 - dx2 * dy1) <= eps * (n1 + n2)


static func lines_intersect(a0, a1, b0, b1) -> Dictionary:
	var adx: float = a1.x - a0.x
	var ady: float = a1.y - a0.y
	var bdx: float = b1.x - b0.x
	var bdy: float = b1.y - b0.y
	var axb: float = adx * bdy - ady * bdx
	var n1: float = sqrt(adx * adx + ady * ady)
	var n2: float = sqrt(bdx * bdx + bdy * bdy)
	if absf(axb) <= eps * (n1 + n2):
		return {"ok": false, "intersection": _Intersection.empty()}
	var dx: float = a0.x - b0.x
	var dy: float = a0.y - b0.y
	var a_param: float = (bdx * dy - bdy * dx) / axb
	var b_param: float = (adx * dy - ady * dx) / axb
	var pt := _Point.new(a0.x + a_param * adx, a0.y + a_param * ady)
	var iscr2: GDScript = load("res://shapeup_core/decomposition/poly_bool/intersection.gd") as GDScript
	var intersection = iscr2.new()
	intersection.pt = pt
	intersection.along_a = 0
	intersection.along_b = 0
	if points_same(pt, a0):
		intersection.along_a = -1
	elif points_same(pt, a1):
		intersection.along_a = 1
	elif a_param < 0.0:
		intersection.along_a = -2
	elif a_param > 1.0:
		intersection.along_a = 2
	if points_same(pt, b0):
		intersection.along_b = -1
	elif points_same(pt, b1):
		intersection.along_b = 1
	elif b_param < 0.0:
		intersection.along_b = -2
	elif b_param > 1.0:
		intersection.along_b = 2
	return {"ok": true, "intersection": intersection}


static func point_inside_region(pt, region) -> bool:
	var pts: Array = region.points
	if pts.is_empty():
		return false
	var x: float = pt.x
	var y: float = pt.y
	var last = pts[pts.size() - 1]
	var last_x: float = last.x
	var last_y: float = last.y
	var inside := false
	for i in pts.size():
		var curr = pts[i]
		var curr_x: float = curr.x
		var curr_y: float = curr.y
		if ((curr_y - y > eps) != (last_y - y > eps)) and (last_x - curr_x) * (y - curr_y) / (last_y - curr_y) + curr_x - x > eps:
			inside = not inside
		last_x = curr_x
		last_y = curr_y
	return inside
