## Random / grid point sets (from Util/PointGenerator.cs).
class_name DelaunayPointGenerator
extends RefCounted

static var _rng := RandomNumberGenerator.new()


static func uniform_distribution(n: int, scale: float) -> Array[TriangulationPoint]:
	var points: Array[TriangulationPoint] = []
	for i in n:
		points.append(TriangulationPoint.new(scale * (0.5 - _rng.randf()), scale * (0.5 - _rng.randf())))
	return points


static func uniform_grid(n: int, scale: float) -> Array[TriangulationPoint]:
	var x: float = 0.0
	var size: float = scale / n
	var half_scale: float = 0.5 * scale
	var points: Array[TriangulationPoint] = []
	for i in n + 1:
		x = half_scale - i * size
		for j in n + 1:
			points.append(TriangulationPoint.new(x, half_scale - j * size))
	return points
