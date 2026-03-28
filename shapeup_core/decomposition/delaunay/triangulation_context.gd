## Poly2Tri triangulation context base (from TriangulationContext.cs).
class_name TriangulationContext
extends RefCounted

var points: Array[TriangulationPoint] = []
var triangles: Array = []
var triangulation_mode: int = TriangulationModeKind.TriangulationMode.UNCONSTRAINED
var triangulatable: TriangulatableBase
var terminated: bool = false
var step_count: int = 0
var is_debug_enabled: bool = false


func done() -> void:
	step_count += 1


func prepare_triangulation(t: TriangulatableBase) -> void:
	triangulatable = t
	triangulation_mode = t.get_triangulation_mode()
	t.prepare_triangulation(self)


func new_constraint(_a: TriangulationPoint, _b: TriangulationPoint) -> TriangulationConstraint:
	push_error("TriangulationContext.new_constraint: override required")
	return null


func update(_message: Variant) -> void:
	pass


func clear() -> void:
	points.clear()
	terminated = false
	step_count = 0
