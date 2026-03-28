## Poly2Tri polygon with holes (from Polygon/Polygon.cs). Renamed from Polygon to avoid PolyBool Polygon.
class_name DelaunayPolygon
extends TriangulatableBase

var _holes: Array[DelaunayPolygon] = []
var _last: PolygonPoint
var _points: Array[TriangulationPoint] = []
var _steiner_points: Array[TriangulationPoint] = []
var _triangles: Array = []


func _init(point_list: Array = []) -> void:
	if point_list.is_empty():
		return
	if point_list.size() < 3:
		push_error("DelaunayPolygon: list has fewer than 3 points")
		return
	var pts: Array = point_list.duplicate()
	if pts[0] == pts[pts.size() - 1]:
		pts.pop_back()
	for p in pts:
		_points.append(p)


func get_holes() -> Array[DelaunayPolygon]:
	return _holes


func add_steiner_point(point: TriangulationPoint) -> void:
	_steiner_points.append(point)


func add_steiner_points(point_list: Array) -> void:
	for p in point_list:
		_steiner_points.append(p)


func clear_steiner_points() -> void:
	_steiner_points.clear()


func add_hole(poly: DelaunayPolygon) -> void:
	_holes.append(poly)


func insert_point_after(point: PolygonPoint, new_point: PolygonPoint) -> void:
	var index: int = _points.find(point)
	if index == -1:
		push_error("insert_point_after: point not in polygon")
		return
	new_point.poly_next = point.poly_next
	new_point.poly_prev = point
	point.poly_next.poly_prev = new_point
	point.poly_next = new_point
	_points.insert(index + 1, new_point)


func add_points(point_list: Array) -> void:
	for p in point_list:
		var pp: PolygonPoint = p as PolygonPoint
		pp.poly_prev = _last
		if _last != null:
			pp.poly_next = _last.poly_next
			_last.poly_next = pp
		_last = pp
		_points.append(pp)
	var first: PolygonPoint = _points[0] as PolygonPoint
	_last.poly_next = first
	first.poly_prev = _last


func add_point(p: PolygonPoint) -> void:
	p.poly_prev = _last
	p.poly_next = _last.poly_next
	_last.poly_next = p
	_points.append(p)


func remove_point(p: PolygonPoint) -> void:
	var next_pt: PolygonPoint = p.poly_next
	var prev_pt: PolygonPoint = p.poly_prev
	prev_pt.poly_next = next_pt
	next_pt.poly_prev = prev_pt
	_points.erase(p)


func get_triangulation_mode() -> int:
	return TriangulationModeKind.TriangulationMode.POLYGON


func get_point_list() -> Array:
	return _points


func get_triangle_list() -> Array:
	return _triangles


func add_triangle(t: DelaunayTriangle) -> void:
	_triangles.append(t)


func add_triangles(list: Array) -> void:
	for t in list:
		_triangles.append(t)


func clear_triangles() -> void:
	_triangles.clear()


func prepare_triangulation(tcx: TriangulationContext) -> void:
	_triangles.clear()
	var i: int = 0
	while i < _points.size() - 1:
		tcx.new_constraint(_points[i], _points[i + 1])
		i += 1
	if _points.size() > 1:
		tcx.new_constraint(_points[0], _points[_points.size() - 1])
	for p in _points:
		tcx.points.append(p)
	if not _holes.is_empty():
		for hole_poly: DelaunayPolygon in _holes:
			var hp: Array = hole_poly._points
			var j: int = 0
			while j < hp.size() - 1:
				tcx.new_constraint(hp[j], hp[j + 1])
				j += 1
			if hp.size() > 1:
				tcx.new_constraint(hp[0], hp[hp.size() - 1])
			for hpnt in hp:
				tcx.points.append(hpnt)
	for sp in _steiner_points:
		tcx.points.append(sp)


## Append boundary vertex (used by DelaunayDecomposer; mirrors List.Add on C# Polygon.Points).
func append_boundary_point(p: TriangulationPoint) -> void:
	_points.append(p)
