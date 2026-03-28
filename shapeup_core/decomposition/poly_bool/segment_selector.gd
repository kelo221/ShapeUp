# PolyBool — SegmentSelector (from SegmentSelector.cs).
extends RefCounted
class_name SegmentSelector

static var _UNION_SELECT_TABLE: PackedInt32Array = PackedInt32Array([
	0, 2, 1, 0,
	2, 2, 0, 0,
	1, 0, 1, 0,
	0, 0, 0, 0
])

static var _INTERSECT_SELECT_TABLE: PackedInt32Array = PackedInt32Array([
	0, 0, 0, 0,
	0, 2, 0, 2,
	0, 0, 1, 1,
	0, 2, 1, 0
])

static var _DIFFERENCE_SELECT_TABLE: PackedInt32Array = PackedInt32Array([
	0, 0, 0, 0,
	2, 0, 2, 0,
	1, 1, 0, 0,
	0, 1, 2, 0
])

static var _DIFFERENCE_REV_SELECT_TABLE: PackedInt32Array = PackedInt32Array([
	0, 2, 1, 0,
	0, 0, 1, 1,
	0, 2, 0, 2,
	0, 0, 0, 0
])

static var _XOR_SELECT_TABLE: PackedInt32Array = PackedInt32Array([
	0, 2, 1, 0,
	2, 0, 0, 1,
	1, 0, 0, 2,
	0, 1, 2, 0
])

const _Segment := preload("res://shapeup_core/decomposition/poly_bool/segment.gd")
const _SegmentFill := preload("res://shapeup_core/decomposition/poly_bool/segment_fill.gd")
const _SegmentList := preload("res://shapeup_core/decomposition/poly_bool/segment_list.gd")

static func union(segments, build_log):
	return _select(segments, _UNION_SELECT_TABLE, build_log)

static func intersect(segments, build_log):
	return _select(segments, _INTERSECT_SELECT_TABLE, build_log)

static func difference(segments, build_log):
	return _select(segments, _DIFFERENCE_SELECT_TABLE, build_log)

static func difference_rev(segments, build_log):
	return _select(segments, _DIFFERENCE_REV_SELECT_TABLE, build_log)

static func xor(segments, build_log):
	return _select(segments, _XOR_SELECT_TABLE, build_log)

static func _my_below_bit(sf) -> int:
	if sf.below == null:
		return 0
	return 1 if bool(sf.below) else 0

static func _other_below_bit(of) -> int:
	if of == null or of.below == null:
		return 0
	return 1 if bool(of.below) else 0

static func _select(segments, selection: PackedInt32Array, build_log):
	var result := _SegmentList.new()
	for seg in segments.segments:
		var s = seg
		var index := \
			(8 if s.my_fill.above else 0) + \
			(4 * _my_below_bit(s.my_fill)) + \
			(2 if (s.other_fill != null and s.other_fill.above) else 0) + \
			(_other_below_bit(s.other_fill) if s.other_fill != null else 0)
		if index < 0 or index >= selection.size():
			continue
		var sel := selection[index]
		if sel != 0:
			var copy := _Segment.new()
			copy.id = build_log.segment_id() if build_log != null else -1
			copy.start = s.start
			copy.end = s.end
			copy.my_fill = _SegmentFill.new()
			copy.my_fill.above = sel == 1
			copy.my_fill.below = sel == 2
			copy.other_fill = null
			result.append(copy)
	if build_log != null:
		build_log.selected(result)
	return result
