## Generates meshes for a given collection of decomposed convex polygons.
extends RefCounted
class_name MeshGenerator




## Creates a flat mesh out of convex polygons (concave).
static func create_polygon_mesh(convex_polygons: Array, double_sided: bool) -> ArrayMesh:
	var polygon_mesh = EditorPolygonMesh.new()
	var count = convex_polygons.size()
	for i in count:
		convex_polygons[i].apply_xy_based_uv0(Vector2(0.5, 0.5))
		polygon_mesh.append_polygon(convex_polygons[i].with_front_material())
		if double_sided:
			polygon_mesh.append_polygon(convex_polygons[i].get_flipped().with_back_material())
	return polygon_mesh.to_mesh()


## [Convex] Creates extruded meshes out of convex polygons.
static func create_extruded_polygon_meshes(convex_polygons: Array, distance: float) -> Array:
	var count = convex_polygons.size()
	var polygon_meshes = []

	for i in count:
		var brush = EditorPolygonMesh.new()
		polygon_meshes.append(brush)
		brush.boolean_operator = convex_polygons[i].boolean_operator

		var poly = convex_polygons[i].duplicate_polygon()
		var next_poly = convex_polygons[i].duplicate_polygon()
		next_poly.translate(Vector3(0.0, 0.0, distance))

		brush.append_polygon(poly.with_front_material())
		brush.append_polygon(next_poly.get_flipped().with_back_material())

		var poly_vertex_count = poly.get_vertex_count()
		for k in range(poly_vertex_count - 1):
			var ep = EditorPolygon.new()
			ep.vertices.append(poly.vertices[k])
			ep.vertices.append(next_poly.vertices[k])
			ep.vertices.append(next_poly.vertices[k + 1])
			ep.vertices.append(poly.vertices[k + 1])
			brush.append_polygon(ep)

		var ep2 = EditorPolygon.new()
		ep2.vertices.append(poly.vertices[poly_vertex_count - 1])
		ep2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
		ep2.vertices.append(next_poly.vertices[0])
		ep2.vertices.append(poly.vertices[0])
		brush.append_polygon(ep2)

	return polygon_meshes


## [Concave] Creates an extruded mesh out of convex polygons.
static func create_extruded_polygon_mesh(convex_polygons: Array, distance: float) -> ArrayMesh:
	var count = convex_polygons.size()
	var polygon_meshes = []

	for i in count:
		var brush = EditorPolygonMesh.new()
		polygon_meshes.append(brush)

		var poly = convex_polygons[i].duplicate_polygon()
		poly.apply_xy_based_uv0(Vector2(0.5, 0.5))

		var next_poly = convex_polygons[i].duplicate_polygon()
		next_poly.translate(Vector3(0.0, 0.0, distance))
		next_poly.apply_xy_based_uv0(Vector2(0.5, 0.5))

		brush.append_polygon(poly.with_front_material())
		brush.append_polygon(next_poly.get_flipped().with_back_material())

		var poly_vertex_count = poly.get_vertex_count()
		for k in range(poly_vertex_count - 1):
			if poly.vertices[k].hidden:
				continue
			var ep = EditorPolygon.new()
			ep.vertices.append(poly.vertices[k])
			ep.vertices.append(next_poly.vertices[k])
			ep.vertices.append(next_poly.vertices[k + 1])
			ep.vertices.append(poly.vertices[k + 1])
			ep.apply_sabre_csg_auto_uv0(Vector2(0.5, 0.5))
			brush.append_polygon(ep)

		if not poly.vertices[poly_vertex_count - 1].hidden:
			var ep2 = EditorPolygon.new()
			ep2.vertices.append(poly.vertices[poly_vertex_count - 1])
			ep2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
			ep2.vertices.append(next_poly.vertices[0])
			ep2.vertices.append(poly.vertices[0])
			ep2.apply_sabre_csg_auto_uv0(Vector2(0.5, 0.5))
			brush.append_polygon(ep2)

	var combined = EditorPolygonMesh.combine_meshes(polygon_meshes)
	return combined.to_mesh()


## [Convex] Creates meshes by extruding the convex polygons along a 3 point spline.
static func create_spline_extruded_polygon_meshes(convex_polygons: Array, spline: MathEx.Spline3, precision: int) -> Array:
	var polygon_meshes = []
	var count = convex_polygons.size()
	for i in count:
		var brushes = convex_polygons[i].extrude_brushes_along_spline(spline, precision)
		polygon_meshes.append_array(brushes)
	return polygon_meshes


## [Concave] Creates a mesh by extruding the convex polygons along a 3 point spline.
static func create_spline_extruded_mesh(convex_polygons: Array, spline: MathEx.Spline3, precision: int) -> ArrayMesh:
	var polygon_meshes = []
	var count = convex_polygons.size()
	for i in count:
		convex_polygons[i].apply_xy_based_uv0(Vector2(0.5, 0.5))
		var brush = EditorPolygonMesh.new()
		polygon_meshes.append(brush)

		var extruded_polygons = convex_polygons[i].extrude_along_spline(spline, precision)
		for ep in extruded_polygons:
			ep.apply_position_based_uv0(Vector2(0.5, 0.5))
			brush.append_polygon(ep)

	var combined = EditorPolygonMesh.combine_meshes(polygon_meshes)
	return combined.to_mesh()


## [Convex] Creates a mesh by revolving extruded convex polygons along a circle.
static func create_revolve_extruded_polygon_meshes(convex_polygons: EditorPolygonMesh, precision: int, degrees: float, diameter: float, height: float, sloped: bool) -> Array:
	var polygon_meshes = []
	var sloped_height_offset = Vector3.ZERO
	if sloped and precision >= 2:
		sloped_height_offset = Vector3(0.0, height / float(precision), 0.0)
	
	height -= sloped_height_offset.y
	
	var project_center_offset: Vector3 = Vector3(-convex_polygons.bounds_2d.end.x, 0.0, 0.0) if degrees > 0.0 else Vector3(-convex_polygons.bounds_2d.position.x, 0.0, 0.0)
	
	var count = convex_polygons.size()
	for i in count:
		for j in precision:
			var brush = EditorPolygonMesh.new()
			polygon_meshes.append(brush)
			brush.boolean_operator = convex_polygons.get_polygon(i).boolean_operator
			
			var poly = convex_polygons.get_polygon(i).duplicate_polygon()
			poly.translate(project_center_offset)
			
			var next_poly = poly.duplicate_polygon()
			var poly_vertex_count = poly.get_vertex_count()
			
			var pivot = Vector3(diameter if degrees > 0.0 else -diameter, 0.0, 0.0)
			
			for v in poly_vertex_count:
				var height_offset = Vector3.ZERO
				if precision >= 2:
					height_offset.y = (float(j) / float(precision - 1)) * height
					
				var ang1 = lerpf(0.0, degrees, float(j) / float(precision))
				var ang2 = lerpf(0.0, degrees, float(j + 1) / float(precision))
				
				var rotated1 = MathEx.rotate_point_around_pivot_3d(poly.vertices[v].position, pivot, Vector3(0.0, ang1, 0.0))
				var rotated2 = MathEx.rotate_point_around_pivot_3d(next_poly.vertices[v].position, pivot, Vector3(0.0, ang2, 0.0))
				
				poly.vertices[v] = EditorVertex.new(height_offset + rotated1, poly.vertices[v].uv0, poly.vertices[v].hidden, poly.vertices[v].material)
				next_poly.vertices[v] = EditorVertex.new(height_offset + sloped_height_offset + rotated2, next_poly.vertices[v].uv0, next_poly.vertices[v].hidden, next_poly.vertices[v].material)
				
			brush.append_polygon(poly.with_front_material())
			brush.append_polygon(next_poly.get_flipped().with_back_material())
			
			for k in range(poly_vertex_count - 1):
				var extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k + 1])
				extruded.vertices.append(poly.vertices[k + 1])
				
				var planar_polys = extruded.split_non_planar4()
				if height != 0.0 and sloped and planar_polys.size() > 0:
					brush.append_polygons(planar_polys)
				else:
					brush.append_polygon(extruded)
					
			var extruded2 = EditorPolygon.new()
			extruded2.vertices.append(poly.vertices[poly_vertex_count - 1])
			extruded2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
			extruded2.vertices.append(next_poly.vertices[0])
			extruded2.vertices.append(poly.vertices[0])
			
			var planar_polys2 = extruded2.split_non_planar4()
			if height != 0.0 and sloped and planar_polys2.size() > 0:
				brush.append_polygons(planar_polys2)
			else:
				brush.append_polygon(extruded2)
				
			brush.translate(-project_center_offset)
			
	return polygon_meshes


## [Concave] Creates a mesh by revolving extruded convex polygons along a circle.
static func create_revolve_extruded_mesh(convex_polygons: EditorPolygonMesh, precision: int, degrees: float, diameter: float, height: float, sloped: bool) -> ArrayMesh:
	var polygon_meshes = []
	var degrees_abs = absf(degrees)
	var sloped_height_offset = Vector3.ZERO
	if sloped and precision >= 2:
		sloped_height_offset = Vector3(0.0, height / float(precision), 0.0)
	
	height -= sloped_height_offset.y
	var project_center_offset: Vector3 = Vector3(-convex_polygons.bounds_2d.end.x, 0.0, 0.0) if degrees > 0.0 else Vector3(-convex_polygons.bounds_2d.position.x, 0.0, 0.0)
	
	var count = convex_polygons.size()
	for i in count:
		convex_polygons.get_polygon(i).apply_xy_based_uv0(Vector2(0.5, 0.5))
		for j in precision:
			var brush = EditorPolygonMesh.new()
			polygon_meshes.append(brush)
			
			var poly = convex_polygons.get_polygon(i).duplicate_polygon()
			poly.translate(project_center_offset)
			var next_poly = poly.duplicate_polygon()
			var poly_vertex_count = poly.get_vertex_count()
			var pivot = Vector3(diameter if degrees > 0.0 else -diameter, 0.0, 0.0)
			
			for v in poly_vertex_count:
				var height_offset = Vector3.ZERO
				if precision >= 2:
					height_offset.y = (float(j) / float(precision - 1)) * height
				var ang1 = lerpf(0.0, degrees, float(j) / float(precision))
				var ang2 = lerpf(0.0, degrees, float(j + 1) / float(precision))
				var rotated1 = MathEx.rotate_point_around_pivot_3d(poly.vertices[v].position, pivot, Vector3(0.0, ang1, 0.0))
				var rotated2 = MathEx.rotate_point_around_pivot_3d(next_poly.vertices[v].position, pivot, Vector3(0.0, ang2, 0.0))
				poly.vertices[v] = EditorVertex.new(height_offset + rotated1, poly.vertices[v].uv0, poly.vertices[v].hidden, poly.vertices[v].material)
				next_poly.vertices[v] = EditorVertex.new(height_offset + sloped_height_offset + rotated2, next_poly.vertices[v].uv0, next_poly.vertices[v].hidden, next_poly.vertices[v].material)
			
			if (degrees_abs != 360.0 and (height == 0.0 or sloped)) or (degrees_abs == 360.0 and (height != 0.0 and sloped)):
				if j == 0:
					brush.append_polygon(poly.with_front_material())
				if j == precision - 1:
					brush.append_polygon(next_poly.get_flipped().with_back_material())
			elif degrees_abs == 360.0 and height == 0.0:
				pass
			else:
				brush.append_polygon(poly.with_front_material())
				brush.append_polygon(next_poly.get_flipped().with_back_material())
				
			for k in range(poly_vertex_count - 1):
				if poly.vertices[k].hidden:
					continue
				var extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k + 1])
				extruded.vertices.append(poly.vertices[k + 1])
				extruded.apply_position_based_uv0(Vector2(0.5, 0.5))
				brush.append_polygon(extruded)
				
			if not poly.vertices[poly_vertex_count - 1].hidden:
				var extruded2 = EditorPolygon.new()
				extruded2.vertices.append(poly.vertices[poly_vertex_count - 1])
				extruded2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
				extruded2.vertices.append(next_poly.vertices[0])
				extruded2.vertices.append(poly.vertices[0])
				extruded2.apply_position_based_uv0(Vector2(0.5, 0.5))
				brush.append_polygon(extruded2)
				
	var combined = EditorPolygonMesh.combine_meshes(polygon_meshes)
	combined.translate(-project_center_offset)
	return combined.to_mesh()


## [Convex] Creates a mesh by placing extruded convex polygons along a linear slope.
static func create_linear_staircase_meshes(convex_polygons: EditorPolygonMesh, precision: int, distance: float, height: float, sloped: bool) -> Array:
	var count = convex_polygons.size()
	var polygon_meshes = []
	
	var sloped_height_offset = Vector3.ZERO
	if sloped:
		precision = 1
		sloped_height_offset = Vector3(0.0, height, 0.0)
	
	height -= sloped_height_offset.y
	for j in precision:
		var forward = Vector3(0.0, 0.0, (float(j) / float(precision)) * distance)
		var forward_next = Vector3(0.0, 0.0, (float(j + 1) / float(precision)) * distance)
		
		var height_offset = Vector3.ZERO
		if precision >= 2:
			height_offset.y = (float(j) / float(precision - 1)) * height
			
		for i in count:
			var brush = EditorPolygonMesh.new()
			polygon_meshes.append(brush)
			brush.boolean_operator = convex_polygons.get_polygon(i).boolean_operator
			
			var poly = convex_polygons.get_polygon(i).duplicate_polygon()
			var poly_vertex_count = poly.get_vertex_count()
			poly.translate(forward + height_offset)
			
			var next_poly = convex_polygons.get_polygon(i).duplicate_polygon()
			next_poly.translate(forward_next + height_offset + sloped_height_offset)
			
			brush.append_polygon(poly.with_front_material())
			brush.append_polygon(next_poly.get_flipped().with_back_material())
			
			for k in range(poly_vertex_count - 1):
				var extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k + 1])
				extruded.vertices.append(poly.vertices[k + 1])
				brush.append_polygon(extruded)
				
			var extruded2 = EditorPolygon.new()
			extruded2.vertices.append(poly.vertices[poly_vertex_count - 1])
			extruded2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
			extruded2.vertices.append(next_poly.vertices[0])
			extruded2.vertices.append(poly.vertices[0])
			brush.append_polygon(extruded2)
			
	return polygon_meshes


## [Concave] Creates a mesh by placing extruded convex polygons along a linear slope.
static func create_linear_staircase_mesh(convex_polygons: EditorPolygonMesh, precision: int, distance: float, height: float, sloped: bool) -> ArrayMesh:
	var count = convex_polygons.size()
	var polygon_meshes = []
	
	var sloped_height_offset = Vector3.ZERO
	if sloped:
		precision = 1
		sloped_height_offset = Vector3(0.0, height, 0.0)
	
	height -= sloped_height_offset.y
	for j in precision:
		var forward = Vector3(0.0, 0.0, (float(j) / float(precision)) * distance)
		var forward_next = Vector3(0.0, 0.0, (float(j + 1) / float(precision)) * distance)
		var height_offset = Vector3.ZERO
		if precision >= 2:
			height_offset.y = (float(j) / float(precision - 1)) * height
			
		for i in count:
			var brush = EditorPolygonMesh.new()
			polygon_meshes.append(brush)
			var poly = convex_polygons.get_polygon(i).duplicate_polygon()
			var poly_vertex_count = poly.get_vertex_count()
			poly.translate(forward + height_offset)
			poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
			
			var next_poly = convex_polygons.get_polygon(i).duplicate_polygon()
			next_poly.translate(forward_next + height_offset + sloped_height_offset)
			next_poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
			
			if height == 0.0 or sloped:
				if j == 0: brush.append_polygon(poly.with_front_material())
				if j == precision - 1: brush.append_polygon(next_poly.get_flipped().with_back_material())
			else:
				brush.append_polygon(poly.with_front_material())
				brush.append_polygon(next_poly.get_flipped().with_back_material())
				
			for k in range(poly_vertex_count - 1):
				if poly.vertices[k].hidden: continue
				var extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k])
				extruded.vertices.append(next_poly.vertices[k + 1])
				extruded.vertices.append(poly.vertices[k + 1])
				if sloped:
					extruded.apply_sabre_csg_auto_uv0(Vector2(0.5, 0.5))
				else:
					extruded.apply_position_based_uv0(Vector2(0.5, 0.5))
				brush.append_polygon(extruded)
				
			if not poly.vertices[poly_vertex_count - 1].hidden:
				var extruded2 = EditorPolygon.new()
				extruded2.vertices.append(poly.vertices[poly_vertex_count - 1])
				extruded2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
				extruded2.vertices.append(next_poly.vertices[0])
				extruded2.vertices.append(poly.vertices[0])
				if sloped:
					extruded2.apply_sabre_csg_auto_uv0(Vector2(0.5, 0.5))
				else:
					extruded2.apply_position_based_uv0(Vector2(0.5, 0.5))
				brush.append_polygon(extruded2)
				
	var combined = EditorPolygonMesh.combine_meshes(polygon_meshes)
	return combined.to_mesh()


## [Convex] Creates a mesh by scaling extruded convex polygons to a point or clipped.
static func create_scale_extruded_meshes(convex_polygons: EditorPolygonMesh, distance: float, begin_scale: Vector2, end_scale: Vector2, offset: Vector2) -> Array:
	if begin_scale.x == 0.0 and begin_scale.y == 0.0 and end_scale.x == 0.0 and end_scale.y == 0.0:
		return []
		
	var count = convex_polygons.size()
	var polygon_meshes = []
	for i in count:
		var brush = EditorPolygonMesh.new()
		polygon_meshes.append(brush)
		brush.boolean_operator = convex_polygons.get_polygon(i).boolean_operator
		
		var poly = convex_polygons.get_polygon(i).duplicate_polygon()
		poly.scale(Vector3(begin_scale.x, begin_scale.y, 1.0))
		
		var next_poly = convex_polygons.get_polygon(i).duplicate_polygon()
		next_poly.scale(Vector3(end_scale.x, end_scale.y, 1.0))
		next_poly.translate(Vector3(offset.x, offset.y, 0.0) + Vector3(0.0, 0.0, distance))
		
		if begin_scale.x != 0.0 and begin_scale.y != 0.0:
			brush.append_polygon(poly.with_front_material())
		if end_scale.x != 0.0 and end_scale.y != 0.0:
			brush.append_polygon(next_poly.get_flipped().with_back_material())
			
		var poly_vertex_count = poly.get_vertex_count()
		for k in range(poly_vertex_count - 1):
			var extruded = EditorPolygon.new()
			extruded.vertices.append(poly.vertices[k])
			extruded.vertices.append(next_poly.vertices[k])
			extruded.vertices.append(next_poly.vertices[k + 1])
			extruded.vertices.append(poly.vertices[k + 1])
			
			if (begin_scale.x != begin_scale.y or end_scale.x != end_scale.y):
				var planar_polys = extruded.split_non_planar4()
				if planar_polys.size() > 0:
					brush.append_polygons(planar_polys)
				else:
					brush.append_polygon(extruded)
			else:
				brush.append_polygon(extruded)
				
		var extruded2 = EditorPolygon.new()
		extruded2.vertices.append(poly.vertices[poly_vertex_count - 1])
		extruded2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
		extruded2.vertices.append(next_poly.vertices[0])
		extruded2.vertices.append(poly.vertices[0])
		
		if (begin_scale.x != begin_scale.y or end_scale.x != end_scale.y):
			var planar_polys2 = extruded2.split_non_planar4()
			if planar_polys2.size() > 0:
				brush.append_polygons(planar_polys2)
			else:
				brush.append_polygon(extruded2)
		else:
			brush.append_polygon(extruded2)
			
	return polygon_meshes


## [Concave] Creates a mesh by scaling extruded convex polygons to a point or clipped.
static func create_scale_extruded_mesh(convex_polygons: EditorPolygonMesh, distance: float, begin_scale: Vector2, end_scale: Vector2, offset: Vector2) -> ArrayMesh:
	if begin_scale.x == 0.0 and begin_scale.y == 0.0 and end_scale.x == 0.0 and end_scale.y == 0.0:
		return ArrayMesh.new()
		
	var count = convex_polygons.size()
	var polygon_meshes = []
	for i in count:
		var brush = EditorPolygonMesh.new()
		polygon_meshes.append(brush)
		
		var poly = convex_polygons.get_polygon(i).duplicate_polygon()
		poly.scale(Vector3(begin_scale.x, begin_scale.y, 1.0))
		poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
		
		var next_poly = convex_polygons.get_polygon(i).duplicate_polygon()
		next_poly.scale(Vector3(end_scale.x, end_scale.y, 1.0))
		next_poly.translate(Vector3(offset.x, offset.y, 0.0) + Vector3(0.0, 0.0, distance))
		next_poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
		
		if begin_scale.x != 0.0 and begin_scale.y != 0.0: brush.append_polygon(poly.with_front_material())
		if end_scale.x != 0.0 and end_scale.y != 0.0: brush.append_polygon(next_poly.get_flipped().with_back_material())
		
		var poly_vertex_count = poly.get_vertex_count()
		for k in range(poly_vertex_count - 1):
			if poly.vertices[k].hidden: continue
			var extruded = EditorPolygon.new()
			extruded.vertices.append(poly.vertices[k])
			extruded.vertices.append(next_poly.vertices[k])
			extruded.vertices.append(next_poly.vertices[k + 1])
			extruded.vertices.append(poly.vertices[k + 1])
			extruded.apply_position_based_uv0(Vector2(0.5, 0.5))
			brush.append_polygon(extruded)
			
		if not poly.vertices[poly_vertex_count - 1].hidden:
			var extruded2 = EditorPolygon.new()
			extruded2.vertices.append(poly.vertices[poly_vertex_count - 1])
			extruded2.vertices.append(next_poly.vertices[poly_vertex_count - 1])
			extruded2.vertices.append(next_poly.vertices[0])
			extruded2.vertices.append(poly.vertices[0])
			extruded2.apply_position_based_uv0(Vector2(0.5, 0.5))
			brush.append_polygon(extruded2)
			
	var combined = EditorPolygonMesh.combine_meshes(polygon_meshes)
	return combined.to_mesh()


## [Convex] Creates a mesh by revolving chopped convex polygons along a circle.
static func create_revolve_chopped_meshes(chopped_polygons: Array, degrees: float, distance: float) -> Array:
	var precision = chopped_polygons.size()
	var polygon_meshes = []
	var project_bounds: Rect2
	for i in precision:
		var pm = chopped_polygons[i] as EditorPolygonMesh
		if i == 0:
			project_bounds = pm.calculate_bounds_2d()
		else:
			project_bounds = project_bounds.merge(pm.calculate_bounds_2d())
			
	var project_center_offset = Vector3(project_bounds.position.x, 0.0, 0.0)
	var sign_deg = signf(degrees)
	var inner_circle = MathEx.Circle.get_circle_that_fits_circumference(project_bounds.size.x * sign_deg, absf(degrees) / 360.0)
	var outer_circle = MathEx.Circle.new(inner_circle.radius + distance * sign_deg)
	
	for i in precision:
		var convex_polygons = chopped_polygons[i]
		var count = convex_polygons.size()
		var step_length = project_bounds.size.x / float(precision)
		var s1 = float(i) * step_length
		var s2 = float(i + 1) * step_length
		var t1 = s1 / inner_circle.circumference
		var t2 = s2 / inner_circle.circumference
		
		var inner_cpos1 = inner_circle.get_circle_position(t1) + project_center_offset
		var inner_cpos2 = inner_circle.get_circle_position(t2) + project_center_offset
		var outer_cpos1 = outer_circle.get_circle_position(t1) + project_center_offset
		var outer_cpos2 = outer_circle.get_circle_position(t2) + project_center_offset
		
		for j in count:
			var poly = convex_polygons.get_polygon(j).duplicate_polygon()
			var brush = EditorPolygonMesh.new()
			polygon_meshes.append(brush)
			brush.boolean_operator = convex_polygons.get_polygon(j).boolean_operator
			poly.translate(-project_center_offset)
			
			var back_poly = convex_polygons.get_polygon(j).duplicate_polygon()
			var poly_count = poly.get_vertex_count()
			
			for v in poly_count:
				var vertex = poly.vertices[v]
				var t_inv = inverse_lerp(s1, s2, vertex.position.x)
				var inner_pos = Vector3(inner_cpos1.x, vertex.position.y, inner_cpos1.z).lerp(Vector3(inner_cpos2.x, vertex.position.y, inner_cpos2.z), t_inv)
				var outer_pos = Vector3(outer_cpos1.x, vertex.position.y, outer_cpos1.z).lerp(Vector3(outer_cpos2.x, vertex.position.y, outer_cpos2.z), t_inv)
				
				inner_pos.z -= inner_circle.radius
				outer_pos.z -= inner_circle.radius
				if degrees < 0.0:
					inner_pos.z += distance
					outer_pos.z += distance
					
				poly.vertices[v] = EditorVertex.new(inner_pos, vertex.uv0, vertex.hidden, vertex.material)
				back_poly.vertices[v] = EditorVertex.new(outer_pos, vertex.uv0, vertex.hidden, vertex.material)
				
			if degrees < 0.0:
				brush.append_polygon(poly.get_flipped().with_front_material())
				brush.append_polygon(back_poly.with_back_material())
			else:
				brush.append_polygon(poly.with_front_material())
				brush.append_polygon(back_poly.get_flipped().with_back_material())
				
			var extruded
			for k in range(poly_count - 1):
				extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[k])
				extruded.vertices.append(back_poly.vertices[k])
				extruded.vertices.append(back_poly.vertices[k + 1])
				extruded.vertices.append(poly.vertices[k + 1])
				if degrees < 0.0: extruded = extruded.get_flipped()
				
				var planar_polys = extruded.split_non_planar4()
				if planar_polys.size() > 0: brush.append_polygons(planar_polys)
				else: brush.append_polygon(extruded)
				
			extruded = EditorPolygon.new()
			extruded.vertices.append(poly.vertices[poly_count - 1])
			extruded.vertices.append(back_poly.vertices[poly_count - 1])
			extruded.vertices.append(back_poly.vertices[0])
			extruded.vertices.append(poly.vertices[0])
			if degrees < 0.0: extruded = extruded.get_flipped()
			
			var planar_polys2 = extruded.split_non_planar4()
			if planar_polys2.size() > 0: brush.append_polygons(planar_polys2)
			else: brush.append_polygon(extruded)
			
	return polygon_meshes


## [Concave] Creates a mesh by revolving chopped convex polygons along a circle.
static func create_revolve_chopped_mesh(chopped_polygons: Array, degrees: float, distance: float) -> ArrayMesh:
	var precision = chopped_polygons.size()
	var polygon_meshes = []
	var project_bounds: Rect2
	for i in precision:
		var pm = chopped_polygons[i] as EditorPolygonMesh
		if i == 0:
			project_bounds = pm.calculate_bounds_2d()
		else:
			project_bounds = project_bounds.merge(pm.calculate_bounds_2d())
			
	var project_center_offset = Vector3(project_bounds.position.x, 0.0, 0.0)
	var sign_deg = signf(degrees)
	var inner_circle = MathEx.Circle.get_circle_that_fits_circumference(project_bounds.size.x * sign_deg, absf(degrees) / 360.0)
	var outer_circle = MathEx.Circle.new(inner_circle.radius + distance * sign_deg)
	
	for i in precision:
		var convex_polygons = chopped_polygons[i]
		var count = convex_polygons.size()
		var brush = EditorPolygonMesh.new()
		var step_length = project_bounds.size.x / float(precision)
		var s1 = float(i) * step_length
		var s2 = float(i + 1) * step_length
		var t1 = s1 / inner_circle.circumference
		var t2 = s2 / inner_circle.circumference
		
		var inner_cpos1 = inner_circle.get_circle_position(t1) + project_center_offset
		var inner_cpos2 = inner_circle.get_circle_position(t2) + project_center_offset
		var outer_cpos1 = outer_circle.get_circle_position(t1) + project_center_offset
		var outer_cpos2 = outer_circle.get_circle_position(t2) + project_center_offset
		
		for j in count:
			var poly = convex_polygons.get_polygon(j).duplicate_polygon()
			poly.apply_xy_based_uv0(Vector2(0.5, 0.5))
			poly.translate(-project_center_offset)
			
			var back_poly = convex_polygons.get_polygon(j).duplicate_polygon()
			var poly_count = poly.get_vertex_count()
			
			for v in poly_count:
				var vertex = poly.vertices[v]
				var t_inv = inverse_lerp(s1, s2, vertex.position.x)
				var inner_pos = Vector3(inner_cpos1.x, vertex.position.y, inner_cpos1.z).lerp(Vector3(inner_cpos2.x, vertex.position.y, inner_cpos2.z), t_inv)
				var outer_pos = Vector3(outer_cpos1.x, vertex.position.y, outer_cpos1.z).lerp(Vector3(outer_cpos2.x, vertex.position.y, outer_cpos2.z), t_inv)
				
				inner_pos.z -= inner_circle.radius
				outer_pos.z -= inner_circle.radius
				if degrees < 0.0:
					inner_pos.z += distance
					outer_pos.z += distance
					
				poly.vertices[v] = EditorVertex.new(inner_pos, vertex.uv0, vertex.hidden, vertex.material)
				back_poly.vertices[v] = EditorVertex.new(outer_pos, vertex.uv0, vertex.hidden, vertex.material)
				
			if degrees < 0.0:
				brush.append_polygon(poly.get_flipped().with_front_material())
				brush.append_polygon(back_poly.with_back_material())
			else:
				brush.append_polygon(poly.with_front_material())
				brush.append_polygon(back_poly.get_flipped().with_back_material())
				
			var extruded
			for k in range(poly_count - 1):
				if poly.vertices[k].hidden: continue
				extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[k])
				extruded.vertices.append(back_poly.vertices[k])
				extruded.vertices.append(back_poly.vertices[k + 1])
				extruded.vertices.append(poly.vertices[k + 1])
				extruded.apply_position_based_uv0(Vector2(0.5, 0.5))
				brush.append_polygon(extruded.get_flipped() if degrees < 0.0 else extruded)
				
			if not poly.vertices[poly_count - 1].hidden:
				extruded = EditorPolygon.new()
				extruded.vertices.append(poly.vertices[poly_count - 1])
				extruded.vertices.append(back_poly.vertices[poly_count - 1])
				extruded.vertices.append(back_poly.vertices[0])
				extruded.vertices.append(poly.vertices[0])
				extruded.apply_position_based_uv0(Vector2(0.5, 0.5))
				brush.append_polygon(extruded.get_flipped() if degrees < 0.0 else extruded)
				
		polygon_meshes.append(brush)
		
	var combined = EditorPolygonMesh.combine_meshes(polygon_meshes)
	return combined.to_mesh()

