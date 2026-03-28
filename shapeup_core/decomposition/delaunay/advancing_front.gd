## Advancing front (from AdvancingFront.cs).
class_name AdvancingFront
extends RefCounted

var head: AdvancingFrontNode
var tail: AdvancingFrontNode
var _search: AdvancingFrontNode


func _init(head_node: AdvancingFrontNode, tail_node: AdvancingFrontNode) -> void:
	head = head_node
	tail = tail_node
	_search = head_node
	add_node(head_node)
	add_node(tail_node)


func add_node(_node: AdvancingFrontNode) -> void:
	pass


func remove_node(_node: AdvancingFrontNode) -> void:
	pass


func _to_string() -> String:
	var sb: String = ""
	var node: AdvancingFrontNode = head
	while node != tail:
		sb += str(node.point.x) + "->"
		node = node.next
	sb += str(tail.point.x)
	return sb


func _find_search_node(_x: float) -> AdvancingFrontNode:
	return _search


func locate_node_from_point(point: TriangulationPoint) -> AdvancingFrontNode:
	return locate_node(point.x)


func locate_node(x: float) -> AdvancingFrontNode:
	var node: AdvancingFrontNode = _find_search_node(x)
	if x < node.value:
		while true:
			node = node.prev
			if node == null:
				return null
			if x >= node.value:
				_search = node
				return node
	else:
		while true:
			node = node.next
			if node == null:
				return null
			if x < node.value:
				_search = node.prev
				return node.prev
	return null


func locate_point(point: TriangulationPoint) -> AdvancingFrontNode:
	var px: float = point.x
	var node: AdvancingFrontNode = _find_search_node(px)
	var nx: float = node.point.x
	if px == nx:
		if point != node.point:
			if point == node.prev.point:
				node = node.prev
			elif point == node.next.point:
				node = node.next
			else:
				push_error("AdvancingFront: failed to find node for point")
				return null
	elif px < nx:
		while true:
			node = node.prev
			if node == null:
				break
			if point == node.point:
				break
	else:
		while true:
			node = node.next
			if node == null:
				break
			if point == node.point:
				break
	_search = node
	return node
