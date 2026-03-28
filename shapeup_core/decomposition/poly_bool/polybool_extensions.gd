# PolyBool — conversions (from PolyboolExtensions.cs). No engine Polygon type: use PackedVector2Array / PointList.
extends RefCounted
class_name PolyboolExtensions

const _Point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")
const _PointList := preload("res://shapeup_core/decomposition/poly_bool/point_list.gd")
const _Polygon := preload("res://shapeup_core/decomposition/poly_bool/polygon.gd")
const _PolyBool := preload("res://shapeup_core/decomposition/poly_bool/poly_bool.gd")
const _Epsilon := preload("res://shapeup_core/decomposition/poly_bool/epsilon.gd")

class _HierarchyNode:
	var region = null
	var children: Array = [] ## Array of _HierarchyNode

	func _init(p_region = null) -> void:
		region = p_region


## Single region from a closed or open ring (points as Vector2).
static func to_polybool_polygon(outer: PackedVector2Array, inverted: bool = false):
	var points = _PointList.new()
	for i in outer.size():
		var v := outer[i]
		points.append(_Point.new(v.x, v.y))
	var poly = _Polygon.new()
	poly.regions = [points]
	poly.inverted = inverted
	return poly


## Multiple regions (holes as separate rings); each element is PackedVector2Array.
static func to_polybool_polygon_multi(regions: Array, inverted: bool = false):
	var plist: Array = []
	for r in regions:
		if r is PackedVector2Array:
			plist.append(_region_from_packed(r))
		else:
			plist.append(r)
	var poly = _Polygon.new()
	poly.regions = plist
	poly.inverted = inverted
	return poly


static func _region_from_packed(outer: PackedVector2Array):
	var points = _PointList.new()
	for i in outer.size():
		var v := outer[i]
		points.append(_Point.new(v.x, v.y))
	return points


## Flattens hierarchy to contours as PackedVector2Array (exterior + holes order per polybooljs).
static func to_packed_regions(poly, poly_bool):
	var cleaned = poly_bool.polygon(poly_bool.segments(poly))
	var roots = _HierarchyNode.new(null)
	for i in cleaned.regions.size():
		var region = cleaned.regions[i]
		if region.points.size() < 3:
			continue
		_add_child(roots, region)
	var geopolys: Array = []
	for j in roots.children.size():
		_add_exterior(roots.children[j], geopolys)
	var out_arr: Array = []
	for reg in geopolys:
		var pl = reg
		var packed := PackedVector2Array()
		for k in pl.points.size():
			var p = pl.points[k]
			packed.append(Vector2(p.x, p.y))
		out_arr.append(packed)
	return out_arr


static func _region_inside_region(r1, r2) -> bool:
	var p0 = r1.points[0]
	var p1 = r1.points[1]
	return _Epsilon.point_inside_region(
		_Point.new((p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5),
		r2
	)


static func _add_child(root: _HierarchyNode, region) -> void:
	for i in root.children.size():
		var child = root.children[i]
		if _region_inside_region(region, child.region):
			_add_child(child, region)
			return
	var node = _HierarchyNode.new(region)
	var i2 := 0
	while i2 < root.children.size():
		var ch = root.children[i2]
		if _region_inside_region(ch.region, region):
			node.children.append(ch)
			root.children.remove_at(i2)
			continue
		i2 += 1
	root.children.append(node)


static func _force_winding(region, clockwise: bool):
	var winding := 0.0
	var pts = region.points
	if pts.is_empty():
		return _PointList.new()
	var last = pts[pts.size() - 1]
	var last_x: float = last.x
	var last_y: float = last.y
	var copy = _PointList.new()
	for i in pts.size():
		var curr = pts[i]
		var curr_x: float = curr.x
		var curr_y: float = curr.y
		copy.append(_Point.new(curr_x, curr_y))
		winding += curr_y * last_x - curr_x * last_y
		last_x = curr_x
		last_y = curr_y
	var is_cw := winding < 0.0
	if is_cw != clockwise:
		copy.reverse()
	return copy


static func _add_exterior(node: _HierarchyNode, polygons: Array) -> void:
	polygons.append(_force_winding(node.region, false))
	for i in node.children.size():
		polygons.append(_get_interior(node.children[i], polygons))


static func _get_interior(node: _HierarchyNode, polygons: Array):
	for i in node.children.size():
		_add_exterior(node.children[i], polygons)
	return _force_winding(node.region, true)
