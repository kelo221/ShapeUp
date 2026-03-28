extends RefCounted
class_name ShapeEditorEnums

enum SimpleGlobalAxis { NONE = 0, HORIZONTAL = 1, VERTICAL = 2 }

enum SegmentGeneratorType { LINEAR = 0, BEZIER = 1, SINE = 2, REPEAT = 3, ARCH = 4 }

enum ShapeEditorTargetMode {
	POLYGON = 0,
	FIXED_EXTRUDE = 1,
	SPLINE_EXTRUDE = 2,
	REVOLVE_EXTRUDE = 3,
	LINEAR_STAIRCASE = 4,
	SCALED_EXTRUDE = 5,
	REVOLVE_CHOPPED = 6,
}

## Matches C# `Editor2DTool` (2D viewport toolbar).
enum Editor2DTool { SELECT = 0, MOVE = 1, ROTATE = 2, DRAW = 3, CUT = 4, MEASURE = 5 }
