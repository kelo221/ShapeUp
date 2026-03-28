## Sweep-line triangulation context (from DTSweepContext.cs).
class_name DTSweepContext
extends TriangulationContext

const ALPHA: float = 0.3

class SweepBasin:
	var bottom_node: AdvancingFrontNode
	var left_highest: bool = false
	var left_node: AdvancingFrontNode
	var right_node: AdvancingFrontNode
	var width: float = 0.0


class SweepEdgeEvent:
	var constrained_edge: DTSweepConstraint
	var right: bool = false


var a_front: AdvancingFront
var basin: SweepBasin = SweepBasin.new()
var edge_event: SweepEdgeEvent = SweepEdgeEvent.new()

var head_point: TriangulationPoint
var tail_point: TriangulationPoint
## When true, current outer edge_event chain should stop (replaces PointOnEdgeException catch).
var edge_event_aborted: bool = false


func _init() -> void:
	clear()


func remove_from_list(triangle: DelaunayTriangle) -> void:
	triangles.erase(triangle)


func mesh_clean(triangle: DelaunayTriangle) -> void:
	_mesh_clean_req(triangle)


func _mesh_clean_req(triangle: DelaunayTriangle) -> void:
	if triangle != null and not triangle.is_interior:
		triangle.is_interior = true
		triangulatable.add_triangle(triangle)
		for i in range(3):
			if not triangle.edge_is_constrained.get_at(i):
				_mesh_clean_req(triangle.neighbors.get_at(i) as DelaunayTriangle)


func clear() -> void:
	super.clear()
	triangles.clear()


func add_node(node: AdvancingFrontNode) -> void:
	a_front.add_node(node)


func remove_node(node: AdvancingFrontNode) -> void:
	a_front.remove_node(node)


func locate_node(point: TriangulationPoint) -> AdvancingFrontNode:
	return a_front.locate_node_from_point(point)


func create_advancing_front() -> void:
	var i_triangle := DelaunayTriangle.new(points[0], tail_point, head_point)
	triangles.append(i_triangle)

	var head_node := AdvancingFrontNode.new(i_triangle.points.value1 as TriangulationPoint)
	head_node.triangle = i_triangle

	var middle := AdvancingFrontNode.new(i_triangle.points.value0 as TriangulationPoint)
	middle.triangle = i_triangle

	var tail_node := AdvancingFrontNode.new(i_triangle.points.value2 as TriangulationPoint)

	a_front = AdvancingFront.new(head_node, tail_node)
	a_front.add_node(middle)

	a_front.head.next = middle
	middle.next = a_front.tail
	middle.prev = a_front.head
	a_front.tail.prev = middle


func map_triangle_to_nodes(t: DelaunayTriangle) -> void:
	for i in range(3):
		if t.neighbors.get_at(i) == null:
			var n: AdvancingFrontNode = a_front.locate_point(t.point_cw(t.points.get_at(i) as TriangulationPoint))
			if n != null:
				n.triangle = t


func prepare_triangulation(t: TriangulatableBase) -> void:
	super.prepare_triangulation(t)

	var xmin: float = points[0].x
	var ymin: float = points[0].y
	var xmax: float = xmin
	var ymax: float = ymin

	for p in points:
		if p.x > xmax:
			xmax = p.x
		if p.x < xmin:
			xmin = p.x
		if p.y > ymax:
			ymax = p.y
		if p.y < ymin:
			ymin = p.y

	var delta_x: float = ALPHA * (xmax - xmin)
	var delta_y: float = ALPHA * (ymax - ymin)
	var p1 := TriangulationPoint.new(xmax + delta_x, ymin - delta_y)
	var p2 := TriangulationPoint.new(xmin - delta_x, ymin - delta_y)

	head_point = p1
	tail_point = p2

	points.sort_custom(func(a: TriangulationPoint, b: TriangulationPoint) -> bool:
		return DTSweepPointComparator.less_than(a, b)
	)


func finalize_triangulation() -> void:
	triangulatable.add_triangles(triangles)
	triangles.clear()


func new_constraint(a: TriangulationPoint, b: TriangulationPoint) -> TriangulationConstraint:
	return DTSweepConstraint.new(a, b)
