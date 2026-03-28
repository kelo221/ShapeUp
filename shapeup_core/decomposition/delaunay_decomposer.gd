## Constrained Delaunay convex partition (from DelaunayDecomposer.cs).
extends RefCounted
class_name DelaunayDecomposer


static func convex_partition(verts: EditorPolygon) -> Array[EditorPolygon]:
	assert(verts.vertices.size() >= 3)
	var poly := DelaunayPolygon.new()
	for vertex in verts.vertices:
		poly.append_boundary_point(TriangulationPoint.new(vertex.get_x(), vertex.get_y()))
	for hole_poly in verts.holes:
		var hole := DelaunayPolygon.new()
		for hv in hole_poly.vertices:
			hole.append_boundary_point(TriangulationPoint.new(hv.get_x(), hv.get_y()))
		poly.add_hole(hole)
	var tcx := DTSweepContext.new()
	tcx.prepare_triangulation(poly)
	DTSweep.triangulate(tcx)
	var results: Array[EditorPolygon] = []
	for t in poly.get_triangle_list():
		var tri: DelaunayTriangle = t as DelaunayTriangle
		var v: EditorPolygon = EditorPolygon.new()
		for i in range(3):
			var p: TriangulationPoint = tri.points.get_at(i) as TriangulationPoint
			v.vertices.append(EditorVertex.new(Vector3(p.x, p.y, 0.0)))
		results.append(v)
	return results
