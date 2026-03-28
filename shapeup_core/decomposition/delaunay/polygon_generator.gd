## Test polygon factory (from Util/PolygonGenerator.cs).
class_name DelaunayPolygonGenerator
extends RefCounted

static var _rng := RandomNumberGenerator.new()


static func random_circle_sweep(scale: float, vertex_count: int) -> DelaunayPolygon:
	var radius: float = scale / 4.0
	var points: Array[PolygonPoint] = []
	for i in vertex_count:
		while true:
			if i % 250 == 0:
				radius += scale / 2.0 * (0.5 - _rng.randf())
			elif i % 50 == 0:
				radius += scale / 5.0 * (0.5 - _rng.randf())
			else:
				radius += 25.0 * scale / vertex_count * (0.5 - _rng.randf())
			radius = minf(scale / 2.0, radius)
			radius = maxf(scale / 10.0, radius)
			if radius >= scale / 10.0 and radius <= scale / 2.0:
				break
		var ang: float = TAU * float(i) / float(vertex_count)
		points.append(PolygonPoint.new(radius * cos(ang), radius * sin(ang)))
	return DelaunayPolygon.new(points)


static func random_circle_sweep2(scale: float, vertex_count: int) -> DelaunayPolygon:
	var radius: float = scale / 4.0
	var points: Array[PolygonPoint] = []
	for i in vertex_count:
		while true:
			radius += scale / 5.0 * (0.5 - _rng.randf())
			radius = minf(scale / 2.0, radius)
			radius = maxf(scale / 10.0, radius)
			if radius >= scale / 10.0 and radius <= scale / 2.0:
				break
		var ang: float = TAU * float(i) / float(vertex_count)
		points.append(PolygonPoint.new(radius * cos(ang), radius * sin(ang)))
	return DelaunayPolygon.new(points)
