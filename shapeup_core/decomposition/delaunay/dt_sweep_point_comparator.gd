## Y-then-X point ordering (from DTSweepPointComparator.cs).
class_name DTSweepPointComparator
extends RefCounted


static func less_than(a: TriangulationPoint, b: TriangulationPoint) -> bool:
	if a.y < b.y:
		return true
	if a.y > b.y:
		return false
	if a.x < b.x:
		return true
	return false
