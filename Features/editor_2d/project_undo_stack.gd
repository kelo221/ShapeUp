extends RefCounted

const MAX_DEPTH := 48

var _undo: PackedStringArray = PackedStringArray()
var _redo: PackedStringArray = PackedStringArray()


func clear() -> void:
	_undo.clear()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func push_before_mutation(current: Variant) -> void:
	_redo.clear()
	_undo.append(ShapeupSerialization.project_to_json(current.clone_project()))
	while _undo.size() > MAX_DEPTH:
		_undo.remove_at(0)


func pop_undo(present: Variant):
	if _undo.is_empty():
		return null
	_redo.append(ShapeupSerialization.project_to_json(present.clone_project()))
	var json: Variant = _undo[_undo.size() - 1]
	_undo.remove_at(_undo.size() - 1)
	return ShapeupSerialization.project_from_json(json)


func pop_redo(present: Variant):
	if _redo.is_empty():
		return null
	_undo.append(ShapeupSerialization.project_to_json(present.clone_project()))
	var json: Variant = _redo[_redo.size() - 1]
	_redo.remove_at(_redo.size() - 1)
	return ShapeupSerialization.project_from_json(json)
