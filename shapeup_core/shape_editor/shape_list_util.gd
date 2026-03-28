extends RefCounted
class_name ShapeListUtil


static func splice(arr: Array, index: int, count: int) -> Array:
	var items: Array = arr.slice(index, index + count)
	for _j in count:
		arr.remove_at(index)
	return items
