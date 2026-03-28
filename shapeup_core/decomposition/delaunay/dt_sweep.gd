## Constrained Delaunay sweep (from DTSweep.cs).
class_name DTSweep
extends RefCounted

const PI_DIV2: float = PI / 2.0
const PI_3DIV4: float = 3.0 * PI / 4.0


static func triangulate(tcx: DTSweepContext) -> void:
	tcx.create_advancing_front()
	_sweep(tcx)
	if tcx.triangulation_mode == TriangulationModeKind.TriangulationMode.POLYGON:
		_finalization_polygon(tcx)
	else:
		_finalization_convex_hull(tcx)
	tcx.done()


static func _sweep(tcx: DTSweepContext) -> void:
	var pts: Array[TriangulationPoint] = tcx.points
	for i in range(1, pts.size()):
		var point: TriangulationPoint = pts[i]
		var node: AdvancingFrontNode = _point_event(tcx, point)
		if point.has_edges():
			for e in point.edges:
				_edge_event_from_constraint(tcx, e as DTSweepConstraint, node)
		tcx.update(null)


static func _finalization_convex_hull(tcx: DTSweepContext) -> void:
	var t1: DelaunayTriangle
	var t2: DelaunayTriangle
	var n1: AdvancingFrontNode = tcx.a_front.head.next
	var n2: AdvancingFrontNode = n1.next
	_turn_advancing_front_convex(tcx, n1, n2)

	n1 = tcx.a_front.tail.prev
	if n1.triangle.contains_point(n1.next.point) and n1.triangle.contains_point(n1.prev.point):
		t1 = n1.triangle.neighbor_across(n1.point)
		_rotate_triangle_pair(n1.triangle, n1.point, t1, t1.opposite_point(n1.triangle, n1.point))
		tcx.map_triangle_to_nodes(n1.triangle)
		tcx.map_triangle_to_nodes(t1)
	n1 = tcx.a_front.head.next
	if n1.triangle.contains_point(n1.prev.point) and n1.triangle.contains_point(n1.next.point):
		t1 = n1.triangle.neighbor_across(n1.point)
		_rotate_triangle_pair(n1.triangle, n1.point, t1, t1.opposite_point(n1.triangle, n1.point))
		tcx.map_triangle_to_nodes(n1.triangle)
		tcx.map_triangle_to_nodes(t1)

	var first: TriangulationPoint = tcx.a_front.head.point
	n2 = tcx.a_front.tail.prev
	t1 = n2.triangle
	var p1: TriangulationPoint = n2.point
	n2.triangle = null
	while true:
		tcx.remove_from_list(t1)
		p1 = t1.point_ccw(p1)
		if p1 == first:
			break
		t2 = t1.neighbor_ccw(p1)
		t1.clear()
		t1 = t2

	first = tcx.a_front.head.next.point
	p1 = t1.point_cw(tcx.a_front.head.point)
	t2 = t1.neighbor_cw(tcx.a_front.head.point)
	t1.clear()
	t1 = t2
	while p1 != first:
		tcx.remove_from_list(t1)
		p1 = t1.point_ccw(p1)
		t2 = t1.neighbor_ccw(p1)
		t1.clear()
		t1 = t2

	tcx.a_front.head = tcx.a_front.head.next
	tcx.a_front.head.prev = null
	tcx.a_front.tail = tcx.a_front.tail.prev
	tcx.a_front.tail.next = null

	tcx.finalize_triangulation()


static func _turn_advancing_front_convex(tcx: DTSweepContext, b: AdvancingFrontNode, c: AdvancingFrontNode) -> void:
	var first: AdvancingFrontNode = b
	while c != tcx.a_front.tail:
		if TriangulationUtil.orient2d(b.point, c.point, c.next.point) == TriangulationOrientation.Orientation.CCW:
			_fill(tcx, c)
			c = c.next
		else:
			if b != first and TriangulationUtil.orient2d(b.prev.point, b.point, c.point) == TriangulationOrientation.Orientation.CCW:
				_fill(tcx, b)
				b = b.prev
			else:
				b = c
				c = c.next


static func _finalization_polygon(tcx: DTSweepContext) -> void:
	var t: DelaunayTriangle = tcx.a_front.head.next.triangle
	var p: TriangulationPoint = tcx.a_front.head.next.point
	while not t.get_constrained_edge_cw(p):
		t = t.neighbor_ccw(p)
	tcx.mesh_clean(t)


static func _point_event(tcx: DTSweepContext, point: TriangulationPoint) -> AdvancingFrontNode:
	var node: AdvancingFrontNode = tcx.locate_node(point)
	var new_node: AdvancingFrontNode = _new_front_triangle(tcx, point, node)
	if point.x <= node.point.x + TriangulationUtil.EPSILON:
		_fill(tcx, node)
	tcx.add_node(new_node)
	_fill_advancing_front(tcx, new_node)
	return new_node


static func _new_front_triangle(tcx: DTSweepContext, point: TriangulationPoint, node: AdvancingFrontNode) -> AdvancingFrontNode:
	var triangle := DelaunayTriangle.new(point, node.point, node.next.point)
	triangle.mark_neighbor_tri(node.triangle)
	tcx.triangles.append(triangle)

	var new_node := AdvancingFrontNode.new(point)
	new_node.next = node.next
	new_node.prev = node
	node.next.prev = new_node
	node.next = new_node

	tcx.add_node(new_node)

	if not _legalize(tcx, triangle):
		tcx.map_triangle_to_nodes(triangle)

	return new_node


static func _edge_event_from_constraint(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	tcx.edge_event_aborted = false
	tcx.edge_event.constrained_edge = edge
	tcx.edge_event.right = edge.p.x > edge.q.x

	if _is_edge_side_of_triangle(node.triangle, edge.p, edge.q):
		return

	_fill_edge_event(tcx, edge, node)

	if tcx.edge_event_aborted:
		return

	_edge_event_detail(tcx, edge.p, edge.q, node.triangle, edge.q)


static func _fill_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event.right:
		_fill_right_above_edge_event(tcx, edge, node)
	else:
		_fill_left_above_edge_event(tcx, edge, node)


static func _fill_right_concave_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	_fill(tcx, node.next)
	if node.next.point != edge.p:
		if TriangulationUtil.orient2d(edge.q, node.next.point, edge.p) == TriangulationOrientation.Orientation.CCW:
			if TriangulationUtil.orient2d(node.point, node.next.point, node.next.next.point) == TriangulationOrientation.Orientation.CCW:
				_fill_right_concave_edge_event(tcx, edge, node)


static func _fill_right_convex_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	if TriangulationUtil.orient2d(node.next.point, node.next.next.point, node.next.next.next.point) == TriangulationOrientation.Orientation.CCW:
		_fill_right_concave_edge_event(tcx, edge, node.next)
	else:
		if TriangulationUtil.orient2d(edge.q, node.next.next.point, edge.p) == TriangulationOrientation.Orientation.CCW:
			_fill_right_convex_edge_event(tcx, edge, node.next)


static func _fill_right_below_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	if node.point.x < edge.p.x:
		if TriangulationUtil.orient2d(node.point, node.next.point, node.next.next.point) == TriangulationOrientation.Orientation.CCW:
			_fill_right_concave_edge_event(tcx, edge, node)
		else:
			_fill_right_convex_edge_event(tcx, edge, node)
			_fill_right_below_edge_event(tcx, edge, node)


static func _fill_right_above_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	while node.next.point.x < edge.p.x:
		var o1: int = TriangulationUtil.orient2d(edge.q, node.next.point, edge.p)
		if o1 == TriangulationOrientation.Orientation.CCW:
			_fill_right_below_edge_event(tcx, edge, node)
			if tcx.edge_event_aborted:
				return
		else:
			node = node.next


static func _fill_left_convex_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	if TriangulationUtil.orient2d(node.prev.point, node.prev.prev.point, node.prev.prev.prev.point) == TriangulationOrientation.Orientation.CW:
		_fill_left_concave_edge_event(tcx, edge, node.prev)
	else:
		if TriangulationUtil.orient2d(edge.q, node.prev.prev.point, edge.p) == TriangulationOrientation.Orientation.CW:
			_fill_left_convex_edge_event(tcx, edge, node.prev)


static func _fill_left_concave_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	_fill(tcx, node.prev)
	if node.prev.point != edge.p:
		if TriangulationUtil.orient2d(edge.q, node.prev.point, edge.p) == TriangulationOrientation.Orientation.CW:
			if TriangulationUtil.orient2d(node.point, node.prev.point, node.prev.prev.point) == TriangulationOrientation.Orientation.CW:
				_fill_left_concave_edge_event(tcx, edge, node)


static func _fill_left_below_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	if node.point.x > edge.p.x:
		if TriangulationUtil.orient2d(node.point, node.prev.point, node.prev.prev.point) == TriangulationOrientation.Orientation.CW:
			_fill_left_concave_edge_event(tcx, edge, node)
		else:
			_fill_left_convex_edge_event(tcx, edge, node)
			_fill_left_below_edge_event(tcx, edge, node)


static func _fill_left_above_edge_event(tcx: DTSweepContext, edge: DTSweepConstraint, node: AdvancingFrontNode) -> void:
	if tcx.edge_event_aborted:
		return
	while node.prev.point.x > edge.p.x:
		var o1: int = TriangulationUtil.orient2d(edge.q, node.prev.point, edge.p)
		if o1 == TriangulationOrientation.Orientation.CW:
			_fill_left_below_edge_event(tcx, edge, node)
			if tcx.edge_event_aborted:
				return
		else:
			node = node.prev


static func _is_edge_side_of_triangle(triangle: DelaunayTriangle, ep: TriangulationPoint, eq: TriangulationPoint) -> bool:
	var index: int = triangle.edge_index(ep, eq)
	if index != -1:
		triangle.mark_constrained_edge_index(index)
		var t2: DelaunayTriangle = triangle.neighbors.get_at(index) as DelaunayTriangle
		if t2 != null:
			t2.mark_constrained_edge_pair(ep, eq)
		return true
	return false


static func _edge_event_detail(tcx: DTSweepContext, ep: TriangulationPoint, eq: TriangulationPoint, triangle: DelaunayTriangle, point: TriangulationPoint) -> void:
	if tcx.edge_event_aborted:
		return

	if _is_edge_side_of_triangle(triangle, ep, eq):
		return

	var p1: TriangulationPoint = triangle.point_ccw(point)
	var o1: int = TriangulationUtil.orient2d(eq, p1, ep)
	if o1 == TriangulationOrientation.Orientation.COLLINEAR:
		if triangle.contains_pair(eq, p1):
			triangle.mark_constrained_edge_pair(eq, p1)
			tcx.edge_event.constrained_edge.q = p1
			triangle = triangle.neighbor_across(point)
			_edge_event_detail(tcx, ep, p1, triangle, p1)
		else:
			tcx.edge_event_aborted = true
			push_warning("DTSweep: skipping edge (point on constrained edge)")
		return

	var p2: TriangulationPoint = triangle.point_cw(point)
	var o2: int = TriangulationUtil.orient2d(eq, p2, ep)
	if o2 == TriangulationOrientation.Orientation.COLLINEAR:
		if triangle.contains_pair(eq, p2):
			triangle.mark_constrained_edge_pair(eq, p2)
			tcx.edge_event.constrained_edge.q = p2
			triangle = triangle.neighbor_across(point)
			_edge_event_detail(tcx, ep, p2, triangle, p2)
		else:
			tcx.edge_event_aborted = true
			push_warning("DTSweep: skipping edge (point on constrained edge)")
		return

	if o1 == o2:
		if o1 == TriangulationOrientation.Orientation.CW:
			triangle = triangle.neighbor_ccw(point)
		else:
			triangle = triangle.neighbor_cw(point)
		_edge_event_detail(tcx, ep, eq, triangle, point)
	else:
		_flip_edge_event(tcx, ep, eq, triangle, point)


static func _flip_edge_event(tcx: DTSweepContext, ep: TriangulationPoint, eq: TriangulationPoint, t: DelaunayTriangle, p: TriangulationPoint) -> void:
	if tcx.edge_event_aborted:
		return

	var ot: DelaunayTriangle = t.neighbor_across(p)

	if t.get_constrained_edge_across(p):
		push_error("DTSweep: intersecting constraints")
		return

	var op: TriangulationPoint = ot.opposite_point(t, p)

	var in_scan_area: bool = TriangulationUtil.in_scan_area(p, t.point_ccw(p), t.point_cw(p), op)
	if in_scan_area:
		_rotate_triangle_pair(t, p, ot, op)
		tcx.map_triangle_to_nodes(t)
		tcx.map_triangle_to_nodes(ot)

		if p == eq and op == ep:
			if eq == tcx.edge_event.constrained_edge.q and ep == tcx.edge_event.constrained_edge.p:
				t.mark_constrained_edge_pair(ep, eq)
				ot.mark_constrained_edge_pair(ep, eq)
				_legalize(tcx, t)
				_legalize(tcx, ot)
		else:
			var o: int = TriangulationUtil.orient2d(eq, op, ep)
			t = _next_flip_triangle(tcx, o, t, ot, p, op)
			_flip_edge_event(tcx, ep, eq, t, p)
	else:
		var new_p: TriangulationPoint = _next_flip_point(ep, eq, ot, op)
		if new_p == null:
			tcx.edge_event_aborted = true
			return
		_flip_scan_edge_event(tcx, ep, eq, t, ot, new_p)
		_edge_event_detail(tcx, ep, eq, t, p)


static func _next_flip_point(ep: TriangulationPoint, eq: TriangulationPoint, ot: DelaunayTriangle, op: TriangulationPoint) -> TriangulationPoint:
	var o2d: int = TriangulationUtil.orient2d(eq, op, ep)
	if o2d == TriangulationOrientation.Orientation.CW:
		return ot.point_ccw(op)
	if o2d == TriangulationOrientation.Orientation.CCW:
		return ot.point_cw(op)
	push_warning("DTSweep: point on constrained edge (next flip)")
	return null


static func _next_flip_triangle(tcx: DTSweepContext, o: int, t: DelaunayTriangle, ot: DelaunayTriangle, p: TriangulationPoint, op: TriangulationPoint) -> DelaunayTriangle:
	var edge_index: int
	if o == TriangulationOrientation.Orientation.CCW:
		edge_index = ot.edge_index(p, op)
		ot.edge_is_delaunay.set_at(edge_index, true)
		_legalize(tcx, ot)
		ot.clear_edge_delaunay_flags()
		return t

	edge_index = t.edge_index(p, op)
	t.edge_is_delaunay.set_at(edge_index, true)
	_legalize(tcx, t)
	t.clear_edge_delaunay_flags()
	return ot


static func _flip_scan_edge_event(tcx: DTSweepContext, ep: TriangulationPoint, eq: TriangulationPoint, flip_triangle: DelaunayTriangle, t: DelaunayTriangle, p: TriangulationPoint) -> void:
	if tcx.edge_event_aborted:
		return

	var ot: DelaunayTriangle = t.neighbor_across(p)
	var op: TriangulationPoint = ot.opposite_point(t, p)

	var in_scan_area: bool = TriangulationUtil.in_scan_area(eq, flip_triangle.point_ccw(eq), flip_triangle.point_cw(eq), op)
	if in_scan_area:
		_flip_edge_event(tcx, eq, op, ot, op)
	else:
		var new_p: TriangulationPoint = _next_flip_point(ep, eq, ot, op)
		if new_p == null:
			tcx.edge_event_aborted = true
			return
		_flip_scan_edge_event(tcx, ep, eq, flip_triangle, ot, new_p)


static func _fill_advancing_front(tcx: DTSweepContext, n: AdvancingFrontNode) -> void:
	var angle: float
	var node: AdvancingFrontNode = n.next
	while node.has_next():
		if _large_hole_dont_fill(node):
			break
		_fill(tcx, node)
		node = node.next

	node = n.prev
	while node.has_prev():
		if _large_hole_dont_fill(node):
			break
		angle = _hole_angle(node)
		if angle > PI_DIV2 or angle < -PI_DIV2:
			break
		_fill(tcx, node)
		node = node.prev

	if n.has_next() and n.next.has_next():
		angle = _basin_angle(n)
		if angle < PI_3DIV4:
			_fill_basin(tcx, n)


static func _large_hole_dont_fill(node: AdvancingFrontNode) -> bool:
	var next_node: AdvancingFrontNode = node.next
	var prev_node: AdvancingFrontNode = node.prev
	if not _angle_exceeds_90_degrees(node.point, next_node.point, prev_node.point):
		return false

	var next2_node: AdvancingFrontNode = next_node.next
	if next2_node != null and not _angle_exceeds_plus_90_or_negative(node.point, next2_node.point, prev_node.point):
		return false

	var prev2_node: AdvancingFrontNode = prev_node.prev
	if prev2_node != null and not _angle_exceeds_plus_90_or_negative(node.point, next_node.point, prev2_node.point):
		return false

	return true


static func _angle_exceeds_90_degrees(origin: TriangulationPoint, pa: TriangulationPoint, pb: TriangulationPoint) -> bool:
	var angle: float = _angle(origin, pa, pb)
	return angle > PI_DIV2 or angle < -PI_DIV2


static func _angle_exceeds_plus_90_or_negative(origin: TriangulationPoint, pa: TriangulationPoint, pb: TriangulationPoint) -> bool:
	var angle: float = _angle(origin, pa, pb)
	return angle > PI_DIV2 or angle < 0.0


static func _angle(origin: TriangulationPoint, pa: TriangulationPoint, pb: TriangulationPoint) -> float:
	var px: float = origin.x
	var py: float = origin.y
	var ax: float = pa.x - px
	var ay: float = pa.y - py
	var bx: float = pb.x - px
	var by: float = pb.y - py
	var x: float = ax * by - ay * bx
	var y: float = ax * bx + ay * by
	return atan2(x, y)


static func _fill_basin(tcx: DTSweepContext, node: AdvancingFrontNode) -> void:
	if TriangulationUtil.orient2d(node.point, node.next.point, node.next.next.point) == TriangulationOrientation.Orientation.CCW:
		tcx.basin.left_node = node
	else:
		tcx.basin.left_node = node.next

	tcx.basin.bottom_node = tcx.basin.left_node
	while tcx.basin.bottom_node.has_next() and tcx.basin.bottom_node.point.y >= tcx.basin.bottom_node.next.point.y:
		tcx.basin.bottom_node = tcx.basin.bottom_node.next

	if tcx.basin.bottom_node == tcx.basin.left_node:
		return

	tcx.basin.right_node = tcx.basin.bottom_node
	while tcx.basin.right_node.has_next() and tcx.basin.right_node.point.y < tcx.basin.right_node.next.point.y:
		tcx.basin.right_node = tcx.basin.right_node.next

	if tcx.basin.right_node == tcx.basin.bottom_node:
		return

	tcx.basin.width = tcx.basin.right_node.point.x - tcx.basin.left_node.point.x
	tcx.basin.left_highest = tcx.basin.left_node.point.y > tcx.basin.right_node.point.y

	_fill_basin_req(tcx, tcx.basin.bottom_node)


static func _fill_basin_req(tcx: DTSweepContext, node: AdvancingFrontNode) -> void:
	if _is_shallow(tcx, node):
		return

	_fill(tcx, node)
	if node.prev == tcx.basin.left_node and node.next == tcx.basin.right_node:
		return
	if node.prev == tcx.basin.left_node:
		var o1: int = TriangulationUtil.orient2d(node.point, node.next.point, node.next.next.point)
		if o1 == TriangulationOrientation.Orientation.CW:
			return
		node = node.next
	elif node.next == tcx.basin.right_node:
		var o2: int = TriangulationUtil.orient2d(node.point, node.prev.point, node.prev.prev.point)
		if o2 == TriangulationOrientation.Orientation.CCW:
			return
		node = node.prev
	else:
		if node.prev.point.y < node.next.point.y:
			node = node.prev
		else:
			node = node.next
	_fill_basin_req(tcx, node)


static func _is_shallow(tcx: DTSweepContext, node: AdvancingFrontNode) -> bool:
	var height: float
	if tcx.basin.left_highest:
		height = tcx.basin.left_node.point.y - node.point.y
	else:
		height = tcx.basin.right_node.point.y - node.point.y
	return tcx.basin.width > height


static func _hole_angle(node: AdvancingFrontNode) -> float:
	var px: float = node.point.x
	var py: float = node.point.y
	var ax: float = node.next.point.x - px
	var ay: float = node.next.point.y - py
	var bx: float = node.prev.point.x - px
	var by: float = node.prev.point.y - py
	return atan2(ax * by - ay * bx, ax * bx + ay * by)


static func _basin_angle(node: AdvancingFrontNode) -> float:
	var ax: float = node.point.x - node.next.next.point.x
	var ay: float = node.point.y - node.next.next.point.y
	return atan2(ay, ax)


static func _fill(tcx: DTSweepContext, node: AdvancingFrontNode) -> void:
	var triangle := DelaunayTriangle.new(node.prev.point, node.point, node.next.point)
	triangle.mark_neighbor_tri(node.prev.triangle)
	triangle.mark_neighbor_tri(node.triangle)
	tcx.triangles.append(triangle)

	node.prev.next = node.next
	node.next.prev = node.prev
	tcx.remove_node(node)

	if not _legalize(tcx, triangle):
		tcx.map_triangle_to_nodes(triangle)


static func _legalize(tcx: DTSweepContext, t: DelaunayTriangle) -> bool:
	for i in range(3):
		if t.edge_is_delaunay.get_at(i):
			continue

		var ot: DelaunayTriangle = t.neighbors.get_at(i) as DelaunayTriangle
		if ot != null:
			var p: TriangulationPoint = t.points.get_at(i) as TriangulationPoint
			var op: TriangulationPoint = ot.opposite_point(t, p)
			var oi: int = ot.index_of(op)

			if ot.edge_is_constrained.get_at(oi) or ot.edge_is_delaunay.get_at(oi):
				t.edge_is_constrained.set_at(i, ot.edge_is_constrained.get_at(oi))
				continue

			var inside: bool = TriangulationUtil.smart_incircle(p, t.point_ccw(p), t.point_cw(p), op)

			if inside:
				t.edge_is_delaunay.set_at(i, true)
				ot.edge_is_delaunay.set_at(oi, true)

				_rotate_triangle_pair(t, p, ot, op)

				var not_legalized: bool = not _legalize(tcx, t)
				if not_legalized:
					tcx.map_triangle_to_nodes(t)
				not_legalized = not _legalize(tcx, ot)
				if not_legalized:
					tcx.map_triangle_to_nodes(ot)

				t.edge_is_delaunay.set_at(i, false)
				ot.edge_is_delaunay.set_at(oi, false)

				return true

	return false


static func _rotate_triangle_pair(t: DelaunayTriangle, p: TriangulationPoint, ot: DelaunayTriangle, op: TriangulationPoint) -> void:
	var n1: DelaunayTriangle = t.neighbor_ccw(p)
	var n2: DelaunayTriangle = t.neighbor_cw(p)
	var n3: DelaunayTriangle = ot.neighbor_ccw(op)
	var n4: DelaunayTriangle = ot.neighbor_cw(op)

	var ce1: bool = t.get_constrained_edge_ccw(p)
	var ce2: bool = t.get_constrained_edge_cw(p)
	var ce3: bool = ot.get_constrained_edge_ccw(op)
	var ce4: bool = ot.get_constrained_edge_cw(op)

	var de1: bool = t.get_delaunay_edge_ccw(p)
	var de2: bool = t.get_delaunay_edge_cw(p)
	var de3: bool = ot.get_delaunay_edge_ccw(op)
	var de4: bool = ot.get_delaunay_edge_cw(op)

	t.legalize(p, op)
	ot.legalize(op, p)

	ot.set_delaunay_edge_ccw(p, de1)
	t.set_delaunay_edge_cw(p, de2)
	t.set_delaunay_edge_ccw(op, de3)
	ot.set_delaunay_edge_cw(op, de4)

	ot.set_constrained_edge_ccw(p, ce1)
	t.set_constrained_edge_cw(p, ce2)
	t.set_constrained_edge_ccw(op, ce3)
	ot.set_constrained_edge_cw(op, ce4)

	t.neighbors.clear()
	ot.neighbors.clear()
	if n1 != null:
		ot.mark_neighbor_tri(n1)
	if n2 != null:
		t.mark_neighbor_tri(n2)
	if n3 != null:
		t.mark_neighbor_tri(n3)
	if n4 != null:
		ot.mark_neighbor_tri(n4)
	t.mark_neighbor_tri(ot)
