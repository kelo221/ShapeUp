## Poly2Tri constrained point set (from Sets/ConstrainedPointSet.cs).
class_name ConstrainedPointSet
extends DelaunayPointSet

var _constrained_point_list: Array = []
var edge_index: PackedInt32Array = PackedInt32Array()


func _init(pts: Array, index_or_constraints = null) -> void:
	super(pts)
	if index_or_constraints is PackedInt32Array:
		edge_index = index_or_constraints
	elif index_or_constraints is Array:
		_constrained_point_list = index_or_constraints.duplicate()


func get_triangulation_mode() -> int:
	return TriangulationModeKind.TriangulationMode.CONSTRAINED


func prepare_triangulation(tcx: TriangulationContext) -> void:
	super(tcx)
	if not _constrained_point_list.is_empty():
		var idx: int = 0
		while idx < _constrained_point_list.size():
			var p1: TriangulationPoint = _constrained_point_list[idx]
			idx += 1
			if idx >= _constrained_point_list.size():
				break
			var p2: TriangulationPoint = _constrained_point_list[idx]
			idx += 1
			tcx.new_constraint(p1, p2)
	else:
		var pts: Array = get_point_list()
		var i: int = 0
		while i < edge_index.size():
			tcx.new_constraint(pts[edge_index[i]], pts[edge_index[i + 1]])
			i += 2
