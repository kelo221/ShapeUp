# PolyBool — main API (from PolyBool.cs). Use PolyBool.new() like C# new PolyBool().
extends RefCounted
class_name PolyBool

const _Intersecter := preload("res://shapeup_core/decomposition/poly_bool/intersecter.gd")
const _SegmentChainer := preload("res://shapeup_core/decomposition/poly_bool/segment_chainer.gd")
const _SegmentSelector := preload("res://shapeup_core/decomposition/poly_bool/segment_selector.gd")
const _CombinedSegmentLists := preload("res://shapeup_core/decomposition/poly_bool/combined_segment_lists.gd")
const _Polygon := preload("res://shapeup_core/decomposition/poly_bool/polygon.gd")

var build_log = null


func segments(poly):
	var i = _Intersecter.new(true, build_log)
	for region in poly.regions:
		i.add_region(region)
	var result = i.calculate_self(poly.inverted)
	result.inverted = poly.inverted
	return result


func combine(segments1, segments2):
	var i = _Intersecter.new(false, build_log)
	var combined = i.calculate_pair(
		segments1, segments1.inverted,
		segments2, segments2.inverted
	)
	var csl = _CombinedSegmentLists.new()
	csl.combined = combined
	csl.inverted1 = segments1.inverted
	csl.inverted2 = segments2.inverted
	return csl


func select_union(combined):
	var result = _SegmentSelector.union(combined.combined, build_log)
	result.inverted = combined.inverted1 or combined.inverted2
	return result


func select_intersect(combined):
	var result = _SegmentSelector.intersect(combined.combined, build_log)
	result.inverted = combined.inverted1 and combined.inverted2
	return result


func select_difference(combined):
	var result = _SegmentSelector.difference(combined.combined, build_log)
	result.inverted = combined.inverted1 and not combined.inverted2
	return result


func select_difference_rev(combined):
	var result = _SegmentSelector.difference_rev(combined.combined, build_log)
	result.inverted = (not combined.inverted1) and combined.inverted2
	return result


func select_xor(combined):
	var result = _SegmentSelector.xor(combined.combined, build_log)
	result.inverted = combined.inverted1 != combined.inverted2
	return result


func polygon(seg_list):
	var chain: Array = _SegmentChainer.new().chain_segments(seg_list, build_log)
	var poly = _Polygon.new()
	poly.regions = chain
	poly.inverted = seg_list.inverted
	return poly


func union(poly1, poly2):
	return _operate(poly1, poly2, Callable(self, "select_union"))


func intersect(poly1, poly2):
	return _operate(poly1, poly2, Callable(self, "select_intersect"))


func difference(poly1, poly2):
	return _operate(poly1, poly2, Callable(self, "select_difference"))


func difference_rev(poly1, poly2):
	return _operate(poly1, poly2, Callable(self, "select_difference_rev"))


func xor(poly1, poly2):
	return _operate(poly1, poly2, Callable(self, "select_xor"))


func _operate(poly1, poly2, selector: Callable):
	var seg1 = segments(poly1)
	var seg2 = segments(poly2)
	var comb = combine(seg1, seg2)
	var seg3 = selector.call(comb)
	return polygon(seg3)

##
## Preload: poly_bool_root.gd (once) registers all scripts in dependency order.
##
