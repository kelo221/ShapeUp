extends RefCounted
class_name ShapeSegment

const _Enums := preload("res://shapeup_core/shape_editor/editor_enums.gd")
const _SegmentGenerator := preload("res://shapeup_core/shape_editor/shape_segment_generator.gd")

var shape = null ## ShapeShape
var position: Vector2 = Vector2.ZERO
var selected: bool = false
var previous = null
var next = null
var generator = null
var material: int = 0
var gp_vector1: Vector2 = Vector2.ZERO


func _init(p_shape = null, x: float = 0.0, y: float = 0.0) -> void:
	shape = p_shape
	position = Vector2(x, y)
	generator = _SegmentGenerator.new(self, _Enums.SegmentGeneratorType.LINEAR)
