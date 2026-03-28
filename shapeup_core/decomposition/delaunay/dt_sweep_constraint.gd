## Ordered sweep constraint (from DTSweepConstraint.cs).
class_name DTSweepConstraint
extends TriangulationConstraint


func _init(p1: TriangulationPoint, p2: TriangulationPoint) -> void:
	p = p1
	q = p2
	if p1.y > p2.y:
		q = p1
		p = p2
	elif p1.y == p2.y:
		if p1.x > p2.x:
			q = p1
			p = p2
	q.add_edge(self)
