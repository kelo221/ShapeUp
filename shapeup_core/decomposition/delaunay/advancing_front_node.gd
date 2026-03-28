## Advancing front list node (from AdvancingFrontNode.cs).
class_name AdvancingFrontNode
extends RefCounted

var next: AdvancingFrontNode
var point: TriangulationPoint
var prev: AdvancingFrontNode
var triangle: DelaunayTriangle
var value: float


func _init(pt: TriangulationPoint) -> void:
	point = pt
	value = pt.x


func has_next() -> bool:
	return next != null


func has_prev() -> bool:
	return prev != null
