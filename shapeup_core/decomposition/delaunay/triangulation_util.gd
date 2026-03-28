## Poly2Tri math helpers (from TriangulationUtil.cs).
class_name TriangulationUtil
extends RefCounted

const EPSILON: float = 1e-12


static func smart_incircle(pa: TriangulationPoint, pb: TriangulationPoint, pc: TriangulationPoint, pd: TriangulationPoint) -> bool:
	var pdx: float = pd.x
	var pdy: float = pd.y
	var adx: float = pa.x - pdx
	var ady: float = pa.y - pdy
	var bdx: float = pb.x - pdx
	var bdy: float = pb.y - pdy

	var adxbdy: float = adx * bdy
	var bdxady: float = bdx * ady
	var oabd: float = adxbdy - bdxady

	if oabd <= 0.0:
		return false

	var cdx: float = pc.x - pdx
	var cdy: float = pc.y - pdy

	var cdxady: float = cdx * ady
	var adxcdy: float = adx * cdy
	var ocad: float = cdxady - adxcdy

	if ocad <= 0.0:
		return false

	var bdxcdy: float = bdx * cdy
	var cdxbdy: float = cdx * bdy

	var alift: float = adx * adx + ady * ady
	var blift: float = bdx * bdx + bdy * bdy
	var clift: float = cdx * cdx + cdy * cdy

	var det: float = alift * (bdxcdy - cdxbdy) + blift * ocad + clift * oabd

	return det > 0.0


static func in_scan_area(pa: TriangulationPoint, pb: TriangulationPoint, pc: TriangulationPoint, pd: TriangulationPoint) -> bool:
	var oadb: float = (pa.x - pb.x) * (pd.y - pb.y) - (pd.x - pb.x) * (pa.y - pb.y)
	if oadb >= -EPSILON:
		return false

	var oadc: float = (pa.x - pc.x) * (pd.y - pc.y) - (pd.x - pc.x) * (pa.y - pc.y)
	if oadc <= EPSILON:
		return false
	return true


static func orient2d(pa: TriangulationPoint, pb: TriangulationPoint, pc: TriangulationPoint) -> int:
	var detleft: float = (pa.x - pc.x) * (pb.y - pc.y)
	var detright: float = (pa.y - pc.y) * (pb.x - pc.x)
	var val: float = detleft - detright
	if val > -EPSILON and val < EPSILON:
		return TriangulationOrientation.Orientation.COLLINEAR
	if val > 0.0:
		return TriangulationOrientation.Orientation.CCW
	return TriangulationOrientation.Orientation.CW
