# PolyBool — Intersecter (from Intersecter.cs).
extends RefCounted
class_name Intersecter

const _LinkedList := preload("res://shapeup_core/decomposition/poly_bool/linked_list.gd")
const _Point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")
const _Segment := preload("res://shapeup_core/decomposition/poly_bool/segment.gd")
const _SegmentFill := preload("res://shapeup_core/decomposition/poly_bool/segment_fill.gd")
const _SegmentList := preload("res://shapeup_core/decomposition/poly_bool/segment_list.gd")
const _Epsilon := preload("res://shapeup_core/decomposition/poly_bool/epsilon.gd")

var _self_intersection: bool = false
var _build_log = null
var _event_root: _LinkedList.EventLinkedList
var _status_root: _LinkedList.StatusLinkedList

func _init(p_self_intersection: bool, build_log = null) -> void:
	_self_intersection = p_self_intersection
	_build_log = build_log
	_event_root = _LinkedList.EventLinkedList.new()

func segment_new(start, end):
	var seg := _Segment.new()
	seg.id = _build_log.segment_id() if _build_log != null else -1
	seg.start = start
	seg.end = end
	seg.my_fill = _SegmentFill.new()
	seg.other_fill = null
	return seg

func segment_copy(start, end, seg):
	var ns := _Segment.new()
	ns.id = _build_log.segment_id() if _build_log != null else -1
	ns.start = start
	ns.end = end
	ns.my_fill = _SegmentFill.new()
	ns.my_fill.above = seg.my_fill.above
	ns.my_fill.below = seg.my_fill.below
	ns.other_fill = null
	return ns

func event_add(ev: _LinkedList.EventNode, other_pt) -> void:
	_event_root.insert_before(ev, other_pt)

func event_add_segment_start(seg, primary: bool) -> _LinkedList.EventNode:
	var ev_start := _LinkedList.EventNode.new()
	ev_start.is_start = true
	ev_start.pt = seg.start
	ev_start.seg = seg
	ev_start.primary = primary
	ev_start.other = null
	ev_start.status = null
	event_add(ev_start, seg.end)
	return ev_start

func event_add_segment_end(ev_start: _LinkedList.EventNode, seg, primary: bool) -> _LinkedList.EventNode:
	var ev_end := _LinkedList.EventNode.new()
	ev_end.is_start = false
	ev_end.pt = seg.end
	ev_end.seg = seg
	ev_end.primary = primary
	ev_end.other = ev_start
	ev_end.status = null
	ev_start.other = ev_end
	event_add(ev_end, ev_start.pt)
	return ev_end

func event_add_segment(seg, primary: bool) -> _LinkedList.EventNode:
	var ev_start := event_add_segment_start(seg, primary)
	event_add_segment_end(ev_start, seg, primary)
	return ev_start

func event_update_end(ev: _LinkedList.EventNode, end) -> void:
	if _build_log != null:
		_build_log.segment_chop(ev.seg, end)
	ev.other.remove()
	ev.seg.end = end
	ev.other.pt = end
	event_add(ev.other, ev.pt)

func event_divide(ev: _LinkedList.EventNode, pt) -> _LinkedList.EventNode:
	var ns = segment_copy(pt, ev.seg.end, ev.seg)
	event_update_end(ev, pt)
	return event_add_segment(ns, ev.primary)

## C# calculate(inverted) when selfIntersection is true.
func calculate_self(inverted: bool):
	if not _self_intersection:
		push_error("Intersecter.calculate_self: selfIntersection must be true")
		return _SegmentList.new()
	return _calculate_internal(inverted, false)

## C# calculate(segments1, inverted1, segments2, inverted2) when selfIntersection is false.
func calculate_pair(segments1, inverted1: bool, segments2, inverted2: bool):
	if _self_intersection:
		push_error("Intersecter.calculate_pair: selfIntersection must be false")
		return _SegmentList.new()
	for i in segments1.segments.size():
		event_add_segment(segments1.segments[i], true)
	for i in segments2.segments.size():
		event_add_segment(segments2.segments[i], false)
	return _calculate_internal(inverted1, inverted2)

func add_region(region) -> void:
	if not _self_intersection:
		push_error("Intersecter.add_region: only valid when selfIntersection = true")
		return
	var pts: Array = region.points
	if pts.is_empty():
		return
	if not _Epsilon.points_same(pts[pts.size() - 1], pts[0]):
		region.append(pts[0])
	var pt1 = _Point.new()
	var pt2 = pts[pts.size() - 1]
	for i in pts.size():
		pt1 = pt2
		pt2 = pts[i]
		var forward: int = _Epsilon.points_compare(pt1, pt2)
		if forward == 0:
			continue
		event_add_segment(
			segment_new(pt1 if forward < 0 else pt2, pt2 if forward < 0 else pt1),
			true
		)

func _status_find_surrounding(ev: _LinkedList.EventNode) -> _LinkedList.Transition:
	return _status_root.find_transition(ev)

func _check_intersection(ev1: _LinkedList.EventNode, ev2: _LinkedList.EventNode) -> _LinkedList.EventNode:
	var seg1 = ev1.seg
	var seg2 = ev2.seg
	var a1 = seg1.start
	var a2 = seg1.end
	var b1 = seg2.start
	var b2 = seg2.end
	if _build_log != null:
		_build_log.check_intersection(seg1, seg2)
	var li: Dictionary = _Epsilon.lines_intersect(a1, a2, b1, b2)
	if not li.get("ok", false):
		if not _Epsilon.points_collinear(a1, a2, b1):
			return null
		if _Epsilon.points_same(a1, b2) or _Epsilon.points_same(a2, b1):
			return null
		var a1_equ_b1: bool = _Epsilon.points_same(a1, b1)
		var a2_equ_b2: bool = _Epsilon.points_same(a2, b2)
		if a1_equ_b1 and a2_equ_b2:
			return ev2
		var a1_between: bool = (not a1_equ_b1) and _Epsilon.point_between(a1, b1, b2)
		var a2_between: bool = (not a2_equ_b2) and _Epsilon.point_between(a2, b1, b2)
		if a1_equ_b1:
			if a2_between:
				event_divide(ev2, a2)
			else:
				event_divide(ev1, b2)
			return ev2
		elif a1_between:
			if not a2_equ_b2:
				if a2_between:
					event_divide(ev2, a2)
				else:
					event_divide(ev1, b2)
			event_divide(ev2, a1)
	else:
		var intersect = li["intersection"]
		if intersect.along_a == 0:
			if intersect.along_b == -1:
				event_divide(ev1, b1)
			elif intersect.along_b == 0:
				event_divide(ev1, intersect.pt)
			elif intersect.along_b == 1:
				event_divide(ev1, b2)
		if intersect.along_b == 0:
			if intersect.along_a == -1:
				event_divide(ev2, a1)
			elif intersect.along_a == 0:
				event_divide(ev2, intersect.pt)
			elif intersect.along_a == 1:
				event_divide(ev2, a2)
	return null

func _check_both_intersections(ev: _LinkedList.EventNode, above: _LinkedList.EventNode, below: _LinkedList.EventNode) -> _LinkedList.EventNode:
	if above != null:
		var eve := _check_intersection(ev, above)
		if eve != null:
			return eve
	if below != null:
		return _check_intersection(ev, below)
	return null

func _fill_below_value(sf) -> bool:
	if sf.below == null:
		return false
	return bool(sf.below)

func _calculate_internal(primary_poly_inverted: bool, secondary_poly_inverted: bool):
	var segments := _SegmentList.new()
	_status_root = _LinkedList.StatusLinkedList.new()
	while not _event_root.is_empty:
		var ev: _LinkedList.EventNode = _event_root.head
		if _build_log != null:
			_build_log.vert(ev.pt.x)
		if ev.is_start:
			if _build_log != null:
				_build_log.segment_new(ev.seg, ev.primary)
			var surrounding := _status_find_surrounding(ev)
			var above: _LinkedList.EventNode = surrounding.before
			var below: _LinkedList.EventNode = surrounding.after
			if _build_log != null:
				_build_log.temp_status(
					ev.seg,
					above.seg if above != null else false,
					below.seg if below != null else false
				)
			var eve := _check_both_intersections(ev, above, below)
			if eve != null:
				if _self_intersection:
					var toggle: bool
					if ev.seg.my_fill.below == null:
						toggle = true
					else:
						toggle = ev.seg.my_fill.above != _fill_below_value(ev.seg.my_fill)
					if toggle:
						eve.seg.my_fill.above = not eve.seg.my_fill.above
				else:
					eve.seg.other_fill = ev.seg.my_fill
				if _build_log != null:
					_build_log.segment_update(eve.seg)
				ev.other.remove()
				ev.remove()
			if _event_root.head != ev:
				if _build_log != null:
					_build_log.rewind(ev.seg)
				continue
			if _self_intersection:
				var toggle2: bool
				if ev.seg.my_fill.below == null:
					toggle2 = true
				else:
					toggle2 = ev.seg.my_fill.above != _fill_below_value(ev.seg.my_fill)
				if below == null:
					ev.seg.my_fill.below = primary_poly_inverted
				else:
					ev.seg.my_fill.below = below.seg.my_fill.above
				if toggle2:
					ev.seg.my_fill.above = not _fill_below_value(ev.seg.my_fill)
				else:
					ev.seg.my_fill.above = _fill_below_value(ev.seg.my_fill)
			else:
				if ev.seg.other_fill == null:
					var inside: bool
					if below == null:
						inside = (secondary_poly_inverted if ev.primary else primary_poly_inverted)
					else:
						if ev.primary == below.primary:
							inside = below.seg.other_fill.above
						else:
							inside = below.seg.my_fill.above
					var of := _SegmentFill.new()
					of.above = inside
					of.below = inside
					ev.seg.other_fill = of
			if _build_log != null:
				_build_log.status(
					ev.seg,
					above.seg if above != null else false,
					below.seg if below != null else false
				)
			ev.other.status = _status_root.insert(surrounding, ev)
		else:
			var st := ev.status
			if st == null:
				push_error("PolyBool: Zero-length segment detected; epsilon is probably wrong")
				return segments
			if _status_root.exists(st.prev) and _status_root.exists(st.next):
				_check_intersection(st.prev.ev, st.next.ev)
			if _build_log != null:
				_build_log.status_remove(st.ev.seg)
			st.remove()
			if not ev.primary:
				var s = ev.seg.my_fill
				ev.seg.my_fill = ev.seg.other_fill
				ev.seg.other_fill = s
			segments.append(ev.seg)
		_event_root.head.remove()
	if _build_log != null:
		_build_log.done()
	return segments
