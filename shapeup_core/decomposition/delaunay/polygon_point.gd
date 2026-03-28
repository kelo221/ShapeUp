## Doubly-linked polygon vertex (from PolygonPoint.cs).
class_name PolygonPoint
extends TriangulationPoint

var poly_next: PolygonPoint
var poly_prev: PolygonPoint


func _init(px: float = 0.0, py: float = 0.0) -> void:
	super(px, py)
