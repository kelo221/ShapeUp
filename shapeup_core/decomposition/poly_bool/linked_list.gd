# PolyBool — event/status linked lists (from LinkedList.cs). Types.Transition lives here (depends on nodes).
## Namespace class so inner types share one file (Godot: one global class_name per .gd file).
extends Object
class_name PolyBoolLists

class EventNode:
	extends RefCounted
	var is_start: bool = false
	var pt = null
	var seg = null
	var primary: bool = false
	var other: EventNode = null
	var status: StatusNode = null
	var next: EventNode = null
	var prev: EventNode = null

	func remove() -> void:
		if prev != null:
			prev.next = next
		if next != null:
			next.prev = prev
		prev = null
		next = null

	func _to_string() -> String:
		return "Start=%s, Point=%s, Segment=%s" % [is_start, pt, seg]


class StatusNode:
	extends RefCounted
	var ev: EventNode = null
	var next: StatusNode = null
	var prev: StatusNode = null

	func remove() -> void:
		if prev != null:
			prev.next = next
		if next != null:
			next.prev = prev
		prev = null
		next = null


class Transition:
	extends RefCounted
	var before: EventNode = null
	var after: EventNode = null
	var prev: StatusNode = null
	var here: StatusNode = null


class StatusLinkedList:
	extends RefCounted
	var root: StatusNode

	func _init() -> void:
		root = StatusNode.new()

	var is_empty: bool:
		get:
			return root.next == null

	var head: StatusNode:
		get:
			return root.next

	func exists(node: StatusNode) -> bool:
		if node == null or node == root:
			return false
		return true

	func find_transition(ev: EventNode) -> Transition:
		var prev: StatusNode = root
		var here: StatusNode = root.next
		while here != null:
			if _find_transition_predicate(ev, here):
				break
			prev = here
			here = here.next
		var t := Transition.new()
		t.before = null if prev == root else prev.ev
		t.after = here.ev if here != null else null
		t.here = here
		t.prev = prev
		return t

	func insert(surrounding: Transition, ev: EventNode) -> StatusNode:
		var prev_sn: StatusNode = surrounding.prev
		var here_sn: StatusNode = surrounding.here
		var node := StatusNode.new()
		node.ev = ev
		node.prev = prev_sn
		node.next = here_sn
		prev_sn.next = node
		if here_sn != null:
			here_sn.prev = node
		return node

	func _find_transition_predicate(ev: EventNode, here: StatusNode) -> bool:
		return _status_compare(ev, here.ev) > 0

	func _status_compare(ev1: EventNode, ev2: EventNode) -> int:
		var _E = load("res://shapeup_core/decomposition/poly_bool/epsilon.gd")
		var a1 = ev1.seg.start
		var a2 = ev1.seg.end
		var b1 = ev2.seg.start
		var b2 = ev2.seg.end
		if _E.points_collinear(a1, b1, b2):
			if _E.points_collinear(a2, b1, b2):
				return 1
			return 1 if _E.point_above_or_on_line(a2, b1, b2) else -1
		return 1 if _E.point_above_or_on_line(a1, b1, b2) else -1


class EventLinkedList:
	extends RefCounted
	var root: EventNode

	func _init() -> void:
		root = EventNode.new()

	var is_empty: bool:
		get:
			return root.next == null

	var head: EventNode:
		get:
			return root.next

	func insert_before(node: EventNode, other_pt) -> void:
		var last: EventNode = root
		var here: EventNode = root.next
		while here != null:
			if _insert_before_predicate(here, node, other_pt):
				node.prev = here.prev
				node.next = here
				here.prev.next = node
				here.prev = node
				return
			last = here
			here = here.next
		last.next = node
		node.prev = last
		node.next = null

	func _insert_before_predicate(here: EventNode, ev: EventNode, other_pt) -> bool:
		return _event_compare(
			ev.is_start, ev.pt, other_pt,
			here.is_start, here.pt, here.other.pt
		) < 0

	func _event_compare(
		p1_is_start: bool, p1_1, p1_2,
		p2_is_start: bool, p2_1, p2_2
	) -> int:
		var _E = load("res://shapeup_core/decomposition/poly_bool/epsilon.gd")
		var comp: int = _E.points_compare(p1_1, p2_1)
		if comp != 0:
			return comp
		if _E.points_same(p1_2, p2_2):
			return 0
		if p1_is_start != p2_is_start:
			return 1 if p1_is_start else -1
		return 1 if _E.point_above_or_on_line(
			p1_2,
			p2_1 if p2_is_start else p2_2,
			p2_2 if p2_is_start else p2_1
		) else -1
