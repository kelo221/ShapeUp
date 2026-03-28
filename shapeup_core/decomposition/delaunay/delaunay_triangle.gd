## Poly2Tri triangle (from DelaunayTriangle.cs).
class_name DelaunayTriangle
extends RefCounted

var edge_is_constrained: FixedArray3 = FixedArray3.new(false, false, false)
var edge_is_delaunay: FixedArray3 = FixedArray3.new(false, false, false)
var neighbors: FixedArray3 = FixedArray3.new(null, null, null)
var points: FixedArray3
var is_interior: bool = false


func _init(p1: TriangulationPoint, p2: TriangulationPoint, p3: TriangulationPoint) -> void:
	points = FixedArray3.new(p1, p2, p3)


func index_of(p: TriangulationPoint) -> int:
	var i: int = points.index_of(p)
	if i == -1:
		push_error("Calling index with a point that doesn't exist in triangle")
	return i


func index_cw(p: TriangulationPoint) -> int:
	var index: int = index_of(p)
	match index:
		0:
			return 2
		1:
			return 0
		_:
			return 1


func index_ccw(p: TriangulationPoint) -> int:
	var index: int = index_of(p)
	match index:
		0:
			return 1
		1:
			return 2
		_:
			return 0


func contains_point(p: TriangulationPoint) -> bool:
	return p == points.value0 or p == points.value1 or p == points.value2


func contains_edge(e: DTSweepConstraint) -> bool:
	return contains_point(e.p) and contains_point(e.q)


func contains_pair(p: TriangulationPoint, q: TriangulationPoint) -> bool:
	return contains_point(p) and contains_point(q)


func _mark_neighbor_pair(p1: TriangulationPoint, p2: TriangulationPoint, t: DelaunayTriangle) -> void:
	if (p1 == points.value2 and p2 == points.value1) or (p1 == points.value1 and p2 == points.value2):
		neighbors.set_at(0, t)
	elif (p1 == points.value0 and p2 == points.value2) or (p1 == points.value2 and p2 == points.value0):
		neighbors.set_at(1, t)
	elif (p1 == points.value0 and p2 == points.value1) or (p1 == points.value1 and p2 == points.value0):
		neighbors.set_at(2, t)


func mark_neighbor_tri(t: DelaunayTriangle) -> void:
	if t.contains_pair(points.value1, points.value2):
		neighbors.set_at(0, t)
		t._mark_neighbor_pair(points.value1, points.value2, self)
	elif t.contains_pair(points.value0, points.value2):
		neighbors.set_at(1, t)
		t._mark_neighbor_pair(points.value0, points.value2, self)
	elif t.contains_pair(points.value0, points.value1):
		neighbors.set_at(2, t)
		t._mark_neighbor_pair(points.value0, points.value1, self)


func clear_neighbors() -> void:
	neighbors.clear()
	neighbors = FixedArray3.new(null, null, null)


func clear_neighbor(triangle: DelaunayTriangle) -> void:
	if neighbors.value0 == triangle:
		neighbors.set_at(0, null)
	elif neighbors.value1 == triangle:
		neighbors.set_at(1, null)
	else:
		neighbors.set_at(2, null)


func clear() -> void:
	for i in range(3):
		var t: Variant = neighbors.get_at(i)
		if t != null:
			(t as DelaunayTriangle).clear_neighbor(self)
	clear_neighbors()
	points.clear()
	points = FixedArray3.new(null, null, null)


func opposite_point(t: DelaunayTriangle, p: TriangulationPoint) -> TriangulationPoint:
	return point_cw(t.point_cw(p))


func neighbor_cw(point: TriangulationPoint) -> DelaunayTriangle:
	return neighbors.get_at((index_of(point) + 1) % 3) as DelaunayTriangle


func neighbor_ccw(point: TriangulationPoint) -> DelaunayTriangle:
	return neighbors.get_at((index_of(point) + 2) % 3) as DelaunayTriangle


func neighbor_across(point: TriangulationPoint) -> DelaunayTriangle:
	return neighbors.get_at(index_of(point)) as DelaunayTriangle


func point_ccw(point: TriangulationPoint) -> TriangulationPoint:
	return points.get_at((index_of(point) + 1) % 3) as TriangulationPoint


func point_cw(point: TriangulationPoint) -> TriangulationPoint:
	return points.get_at((index_of(point) + 2) % 3) as TriangulationPoint


func _rotate_cw() -> void:
	var t: TriangulationPoint = points.value2 as TriangulationPoint
	points.value2 = points.value1
	points.value1 = points.value0
	points.value0 = t


func legalize(o_point: TriangulationPoint, n_point: TriangulationPoint) -> void:
	_rotate_cw()
	points.set_at(index_ccw(o_point), n_point)


func _to_string() -> String:
	return str(points.value0) + "," + str(points.value1) + "," + str(points.value2)


func mark_neighbor_edges() -> void:
	for i in range(3):
		if edge_is_constrained.get_at(i) and neighbors.get_at(i) != null:
			var nb: DelaunayTriangle = neighbors.get_at(i) as DelaunayTriangle
			nb.mark_constrained_edge_pair(points.get_at((i + 1) % 3) as TriangulationPoint, points.get_at((i + 2) % 3) as TriangulationPoint)


func mark_edge_tri(triangle: DelaunayTriangle) -> void:
	for i in range(3):
		if edge_is_constrained.get_at(i):
			triangle.mark_constrained_edge_pair(points.get_at((i + 1) % 3) as TriangulationPoint, points.get_at((i + 2) % 3) as TriangulationPoint)


func mark_edge_list(t_list: Array) -> void:
	for t in t_list:
		var tri: DelaunayTriangle = t as DelaunayTriangle
		for i in range(3):
			if tri.edge_is_constrained.get_at(i):
				mark_constrained_edge_pair(tri.points.get_at((i + 1) % 3) as TriangulationPoint, tri.points.get_at((i + 2) % 3) as TriangulationPoint)


func mark_constrained_edge_index(index: int) -> void:
	edge_is_constrained.set_at(index, true)


func mark_constrained_edge_constraint(edge: DTSweepConstraint) -> void:
	mark_constrained_edge_pair(edge.p, edge.q)


func mark_constrained_edge_pair(p: TriangulationPoint, q: TriangulationPoint) -> void:
	var i: int = edge_index(p, q)
	if i != -1:
		edge_is_constrained.set_at(i, true)


func area() -> float:
	var b: float = (points.value0 as TriangulationPoint).x - (points.value1 as TriangulationPoint).x
	var h: float = (points.value2 as TriangulationPoint).y - (points.value1 as TriangulationPoint).y
	return abs(b * h * 0.5)


func centroid() -> TriangulationPoint:
	var p0: TriangulationPoint = points.value0 as TriangulationPoint
	var p1: TriangulationPoint = points.value1 as TriangulationPoint
	var p2: TriangulationPoint = points.value2 as TriangulationPoint
	var cx: float = (p0.x + p1.x + p2.x) / 3.0
	var cy: float = (p0.y + p1.y + p2.y) / 3.0
	return TriangulationPoint.new(cx, cy)


func edge_index(p1: TriangulationPoint, p2: TriangulationPoint) -> int:
	var i1: int = points.index_of(p1)
	var i2: int = points.index_of(p2)
	var a: bool = i1 == 0 or i2 == 0
	var b: bool = i1 == 1 or i2 == 1
	var c: bool = i1 == 2 or i2 == 2
	if b and c:
		return 0
	if a and c:
		return 1
	if a and b:
		return 2
	return -1


func get_constrained_edge_ccw(p: TriangulationPoint) -> bool:
	return edge_is_constrained.get_at((index_of(p) + 2) % 3)


func get_constrained_edge_cw(p: TriangulationPoint) -> bool:
	return edge_is_constrained.get_at((index_of(p) + 1) % 3)


func get_constrained_edge_across(p: TriangulationPoint) -> bool:
	return edge_is_constrained.get_at(index_of(p))


func set_constrained_edge_ccw(p: TriangulationPoint, ce: bool) -> void:
	edge_is_constrained.set_at((index_of(p) + 2) % 3, ce)


func set_constrained_edge_cw(p: TriangulationPoint, ce: bool) -> void:
	edge_is_constrained.set_at((index_of(p) + 1) % 3, ce)


func set_constrained_edge_across(p: TriangulationPoint, ce: bool) -> void:
	edge_is_constrained.set_at(index_of(p), ce)


func get_delaunay_edge_ccw(p: TriangulationPoint) -> bool:
	return edge_is_delaunay.get_at((index_of(p) + 2) % 3)


func get_delaunay_edge_cw(p: TriangulationPoint) -> bool:
	return edge_is_delaunay.get_at((index_of(p) + 1) % 3)


func get_delaunay_edge_across(p: TriangulationPoint) -> bool:
	return edge_is_delaunay.get_at(index_of(p))


func set_delaunay_edge_ccw(p: TriangulationPoint, ce: bool) -> void:
	edge_is_delaunay.set_at((index_of(p) + 2) % 3, ce)


func set_delaunay_edge_cw(p: TriangulationPoint, ce: bool) -> void:
	edge_is_delaunay.set_at((index_of(p) + 1) % 3, ce)


func set_delaunay_edge_across(p: TriangulationPoint, ce: bool) -> void:
	edge_is_delaunay.set_at(index_of(p), ce)


func clear_edge_delaunay_flags() -> void:
	edge_is_delaunay.clear_bool()
