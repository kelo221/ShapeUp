## Preload decomposition stack (PolyBool, Delaunay, Bayazit, mesh wrappers, editor types) for deterministic parse order.
extends RefCounted
class_name DecompositionRoot

const poly_bool_root := preload("res://shapeup_core/decomposition/poly_bool/poly_bool_root.gd")
const delaunay_root := preload("res://shapeup_core/decomposition/delaunay/delaunay_root.gd")
const su_math_ex := preload("res://shapeup_core/decomposition/su_math_ex.gd")
const vertex_material := preload("res://shapeup_core/decomposition/vertex_material.gd")
const polygon_boolean_operator := preload("res://shapeup_core/decomposition/polygon_boolean_operator.gd")
const editor_vertex := preload("res://shapeup_core/decomposition/editor_vertex.gd")
const editor_polygon := preload("res://shapeup_core/decomposition/editor_polygon.gd")
const editor_polygon_extensions := preload("res://shapeup_core/decomposition/editor_polygon_extensions.gd")
const bayazit_decomposer := preload("res://shapeup_core/decomposition/bayazit_decomposer.gd")
const polygon_mesh := preload("res://shapeup_core/decomposition/polygon_mesh.gd")


static func ensure_loaded() -> void:
	pass
