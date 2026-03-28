class_name PolygonMeshTrenchBroomExport
extends RefCounted

static func to_brush_plane_lists(brushes: Array) -> Array:
	var result: Array = []
	for mesh in brushes:
		if mesh is EditorPolygonMesh:
			var pm := mesh as EditorPolygonMesh
			# pm.to_planes() returns Array[Plane] already oriented for Godot
			var planes: Array[Plane] = pm.to_planes()
			result.append(planes)
	return result

static func build_clipboard(brushes: Array, group_name: String = "2D Shape Editor") -> String:
	var lists := to_brush_plane_lists(brushes)
	return TrenchBroomClipboardBuilder.generate_clipboard_brushes_text(lists, group_name)

static func build_standalone_map_file(brushes: Array, group_name: String = "ShapeUp") -> String:
	return build_clipboard(brushes, group_name)
