# PolyBool module loader — preload once so all class_name scripts register in dependency order.
# C# namespace equivalent: ShapeUp.Core.ShapeEditor.PolyBoolCS
extends RefCounted
class_name PolyBoolRoot

const _types_doc := preload("res://shapeup_core/decomposition/poly_bool/types.gd")
const _point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")
const _intersection := preload("res://shapeup_core/decomposition/poly_bool/intersection.gd")
const _segment_fill := preload("res://shapeup_core/decomposition/poly_bool/segment_fill.gd")
const _segment := preload("res://shapeup_core/decomposition/poly_bool/segment.gd")
const _point_list := preload("res://shapeup_core/decomposition/poly_bool/point_list.gd")
const _segment_list := preload("res://shapeup_core/decomposition/poly_bool/segment_list.gd")
const _combined_segment_lists := preload("res://shapeup_core/decomposition/poly_bool/combined_segment_lists.gd")
const _polygon := preload("res://shapeup_core/decomposition/poly_bool/polygon.gd")
const _epsilon := preload("res://shapeup_core/decomposition/poly_bool/epsilon.gd")
const _build_log := preload("res://shapeup_core/decomposition/poly_bool/build_log.gd")
const _linked_list := preload("res://shapeup_core/decomposition/poly_bool/linked_list.gd")
const _intersecter := preload("res://shapeup_core/decomposition/poly_bool/intersecter.gd")
const _segment_selector := preload("res://shapeup_core/decomposition/poly_bool/segment_selector.gd")
const _segment_chainer := preload("res://shapeup_core/decomposition/poly_bool/segment_chainer.gd")
const _poly_bool := preload("res://shapeup_core/decomposition/poly_bool/poly_bool.gd")
const _polybool_extensions := preload("res://shapeup_core/decomposition/poly_bool/polybool_extensions.gd")

## Types.cs maps to: point.gd, intersection.gd, segment_fill.gd, segment.gd, point_list.gd,
## segment_list.gd, combined_segment_lists.gd, polygon.gd (one global class_name per Godot file).

static func ensure_loaded() -> void:
	pass
