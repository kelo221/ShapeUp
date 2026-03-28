# PolyBool — SegmentChainer (from SegmentChainer.cs).
extends RefCounted
class_name SegmentChainer

const _Epsilon := preload("res://shapeup_core/decomposition/poly_bool/epsilon.gd")
const _PointList := preload("res://shapeup_core/decomposition/poly_bool/point_list.gd")

class _Match:
	var index: int = 0
	var matches_head: bool = false
	var matches_pt1: bool = false

var _chains: Array = [] ## Array of PointList
var _regions: Array = [] ## Array of PointList
var _build_log = null
var _first_match := _Match.new()
var _second_match := _Match.new()
var _next_match: Variant = null

func chain_segments(segments, build_log = null) -> Array:
	_build_log = build_log
	_chains.clear()
	_regions.clear()
	for seg_obj in segments.segments:
		var seg = seg_obj
		var pt1 = seg.start
		var pt2 = seg.end
		if _Epsilon.points_same(pt1, pt2):
			push_warning("PolyBool: Zero-length segment detected; epsilon may be wrong")
			continue
		if _build_log != null:
			_build_log.chain_start(seg)
		_first_match.index = 0
		_first_match.matches_head = false
		_first_match.matches_pt1 = false
		_second_match.index = 0
		_second_match.matches_head = false
		_second_match.matches_pt1 = false
		_next_match = _first_match
		for i in _chains.size():
			var pl = _chains[i]
			var pts: Array = pl.points
			if pts.size() < 2:
				continue
			var head = pts[0]
			var _head2 = pts[1]
			var tail = pts[pts.size() - 1]
			var _tail2 = pts[pts.size() - 2]
			if _Epsilon.points_same(head, pt1):
				if _set_match(i, true, true):
					break
			elif _Epsilon.points_same(head, pt2):
				if _set_match(i, true, false):
					break
			elif _Epsilon.points_same(tail, pt1):
				if _set_match(i, false, true):
					break
			elif _Epsilon.points_same(tail, pt2):
				if _set_match(i, false, false):
					break
		if _next_match == _first_match:
			var new_chain := _PointList.new()
			new_chain.append(pt1)
			new_chain.append(pt2)
			_chains.append(new_chain)
			if _build_log != null:
				_build_log.chain_new(pt1, pt2)
			continue
		if _next_match == _second_match:
			if _build_log != null:
				_build_log.chain_match(_first_match.index)
			var index := _first_match.index
			var pt = pt2 if _first_match.matches_pt1 else pt1
			var add_to_head := _first_match.matches_head
			var pl2 = _chains[index]
			var cpts: Array = pl2.points
			var grow = cpts[0] if add_to_head else cpts[cpts.size() - 1]
			var grow2 = cpts[1] if add_to_head else cpts[cpts.size() - 2]
			var oppo = cpts[cpts.size() - 1] if add_to_head else cpts[0]
			var oppo2 = cpts[cpts.size() - 2] if add_to_head else cpts[1]
			if _Epsilon.points_collinear(grow2, grow, pt):
				if add_to_head:
					if _build_log != null:
						_build_log.chain_remove_head(_first_match.index, pt)
					pl2.remove_at(0)
				else:
					if _build_log != null:
						_build_log.chain_remove_tail(_first_match.index, pt)
					pl2.remove_at(pl2.points.size() - 1)
				grow = grow2
			if _Epsilon.points_same(oppo, pt):
				_chains.remove_at(index)
				if _Epsilon.points_collinear(oppo2, oppo, grow):
					if add_to_head:
						if _build_log != null:
							_build_log.chain_remove_tail(_first_match.index, grow)
						pl2.remove_at(pl2.points.size() - 1)
					else:
						if _build_log != null:
							_build_log.chain_remove_head(_first_match.index, grow)
						pl2.remove_at(0)
				if _build_log != null:
					_build_log.chain_close(_first_match.index)
				_regions.append(pl2)
				continue
			if add_to_head:
				if _build_log != null:
					_build_log.chain_add_head(_first_match.index, pt)
				pl2.insert_at(0, pt)
			else:
				if _build_log != null:
					_build_log.chain_add_tail(_first_match.index, pt)
				pl2.append(pt)
			continue
		var f := _first_match.index
		var s := _second_match.index
		if _build_log != null:
			_build_log.chain_connect(f, s)
		var reverse_f: bool = _chains[f].points.size() < _chains[s].points.size()
		if _first_match.matches_head:
			if _second_match.matches_head:
				if reverse_f:
					_reverse_chain(f)
					_append_chain(f, s)
				else:
					_reverse_chain(s)
					_append_chain(s, f)
			else:
				_append_chain(s, f)
		else:
			if _second_match.matches_head:
				_append_chain(f, s)
			else:
				if reverse_f:
					_reverse_chain(f)
					_append_chain(s, f)
				else:
					_reverse_chain(s)
					_append_chain(f, s)
	return _regions

func _reverse_chain(index: int) -> void:
	if _build_log != null:
		_build_log.chain_reverse(index)
	_chains[index].reverse()

func _set_match(index: int, matches_head: bool, matches_pt1: bool) -> bool:
	_next_match.index = index
	_next_match.matches_head = matches_head
	_next_match.matches_pt1 = matches_pt1
	if _next_match == _first_match:
		_next_match = _second_match
		return false
	_next_match = null
	return true

func _append_chain(index1: int, index2: int) -> void:
	var chain1 = _chains[index1]
	var chain2 = _chains[index2]
	var p1: Array = chain1.points
	var p2: Array = chain2.points
	var tail = p1[p1.size() - 1]
	var tail2 = p1[p1.size() - 2]
	var head = p2[0]
	var head2 = p2[1]
	if _Epsilon.points_collinear(tail2, tail, head):
		if _build_log != null:
			_build_log.chain_remove_tail(index1, tail)
		chain1.remove_at(chain1.points.size() - 1)
		tail = tail2
	if _Epsilon.points_collinear(tail, head, head2):
		if _build_log != null:
			_build_log.chain_remove_head(index2, head)
		chain2.remove_at(0)
	if _build_log != null:
		_build_log.chain_join(index1, index2)
	chain1.append_points(chain2)
	_chains.remove_at(index2)
