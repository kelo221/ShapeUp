# PolyBool — BuildLog (from BuildLog.cs). JSON via Godot JSON (replaces System.Text.Json).
extends RefCounted
class_name BuildLog

class Entry:
	var type: String = ""
	var data: Variant = null

var entries: Array = [] ## Array of Entry
var _next_segment_id: int = 0
var _cur_vert: Variant = null

func _init() -> void:
	pass

func to_json_string() -> String:
	var payload: Array = []
	for e in entries:
		var ent: Entry = e as Entry
		payload.append({"type": ent.type, "data": ent.data})
	return JSON.stringify(payload)

func segment_id() -> int:
	var id := _next_segment_id
	_next_segment_id += 1
	return id

func clear() -> void:
	entries.clear()
	_next_segment_id = 0
	_cur_vert = null

func check_intersection(seg1: Variant, seg2: Variant) -> BuildLog:
	return push("check", {"seg1": seg1, "seg2": seg2})

func segment_chop(seg: Variant, end_pt: Variant) -> BuildLog:
	push("div_seg", {"seg": seg, "pt": end_pt})
	return push("chop", {"seg": seg, "pt": end_pt})

func status_remove(seg: Variant) -> BuildLog:
	return push("pop_seg", {"seg": seg})

func segment_update(seg: Variant) -> BuildLog:
	return push("seg_update", {"seg": seg})

func segment_new(seg: Variant, primary: Variant) -> BuildLog:
	return push("new_seg", {"seg": seg, "primary": primary})

func segment_remove(seg: Variant) -> BuildLog:
	return push("rem_seg", {"seg": seg})

func temp_status(seg: Variant, above: Variant, below: Variant) -> BuildLog:
	return push("temp_status", {"seg": seg, "above": above, "below": below})

func rewind(seg: Variant) -> BuildLog:
	return push("rewind", {"seg": seg})

func status(seg: Variant, above: Variant, below: Variant) -> BuildLog:
	return push("status", {"seg": seg, "above": above, "below": below})

func vert(x: Variant) -> BuildLog:
	if x == _cur_vert:
		return self
	_cur_vert = x
	return push("vert", {"x": x})

func log_data(data: Variant) -> BuildLog:
	return push("log", {"txt": str(data)})

func reset() -> BuildLog:
	return push("reset", null)

func selected(segs: Variant) -> BuildLog:
	return push("selected", {"segs": segs})

func chain_start(seg: Variant) -> BuildLog:
	return push("chain_start", {"seg": seg})

func chain_remove_head(index: Variant, pt: Variant) -> BuildLog:
	return push("chain_rem_head", {"index": index, "pt": pt})

func chain_remove_tail(index: Variant, pt: Variant) -> BuildLog:
	return push("chain_rem_tail", {"index": index, "pt": pt})

func chain_new(pt1: Variant, pt2: Variant) -> BuildLog:
	return push("chain_new", {"pt1": pt1, "pt2": pt2})

func chain_match(index: Variant) -> BuildLog:
	return push("chain_match", {"index": index})

func chain_close(index: Variant) -> BuildLog:
	return push("chain_close", {"index": index})

func chain_add_head(index: Variant, pt: Variant) -> BuildLog:
	return push("chain_add_head", {"index": index, "pt": pt})

func chain_add_tail(index: Variant, pt: Variant) -> BuildLog:
	return push("chain_add_tail", {"index": index, "pt": pt})

func chain_connect(index1: Variant, index2: Variant) -> BuildLog:
	return push("chain_con", {"index1": index1, "index2": index2})

func chain_reverse(index: Variant) -> BuildLog:
	return push("chain_rev", {"index": index})

func chain_join(index1: Variant, index2: Variant) -> BuildLog:
	return push("chain_join", {"index1": index1, "index2": index2})

func done() -> BuildLog:
	return push("done", null)

func push(type: String, data: Variant) -> BuildLog:
	var entry := Entry.new()
	entry.type = type
	entry.data = _clone_data(data)
	entries.append(entry)
	return self

func _clone_data(data: Variant) -> Variant:
	if data == null:
		return null
	var json_str := JSON.stringify(data)
	if json_str.is_empty() and data != null:
		return str(data)
	var parsed = JSON.parse_string(json_str)
	return parsed
