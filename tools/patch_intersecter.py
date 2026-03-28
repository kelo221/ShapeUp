import re

p = r"c:\Users\V\Desktop\Shape\ShapeUp\shapeup_core\decomposition\poly_bool\intersecter.gd"
with open(p, "r", encoding="utf-8") as f:
    s = f.read()

hdr = """# PolyBool — Intersecter (from Intersecter.cs).
extends RefCounted
class_name Intersecter

const _Point := preload("res://shapeup_core/decomposition/poly_bool/point.gd")
const _Segment := preload("res://shapeup_core/decomposition/poly_bool/segment.gd")
const _SegmentFill := preload("res://shapeup_core/decomposition/poly_bool/segment_fill.gd")
const _SegmentList := preload("res://shapeup_core/decomposition/poly_bool/segment_list.gd")

"""

s = re.sub(
    r"^# PolyBool — Intersecter.*?\nextends RefCounted\nclass_name Intersecter\n\n",
    hdr,
    s,
    count=1,
    flags=re.DOTALL,
)
for a, b in [
    ("Point.new(", "_Point.new("),
    ("Segment.new(", "_Segment.new("),
    ("SegmentFill.new(", "_SegmentFill.new("),
    ("SegmentList.new(", "_SegmentList.new("),
]:
    s = s.replace(a, b)

s = s.replace("var _build_log: BuildLog = null", "var _build_log = null")
s = s.replace(
    "func _init(p_self_intersection: bool, build_log: BuildLog = null) -> void:",
    "func _init(p_self_intersection: bool, build_log = null) -> void:",
)
s = s.replace("func segment_new(start: Point, end: Point) -> Segment:", "func segment_new(start, end):")
s = s.replace(
    "func segment_copy(start: Point, end: Point, seg: Segment) -> Segment:",
    "func segment_copy(start, end, seg):",
)
s = s.replace(
    "func event_add(ev: PolyBoolLists.EventNode, other_pt: Point) -> void:",
    "func event_add(ev: PolyBoolLists.EventNode, other_pt) -> void:",
)
s = s.replace(
    "func event_add_segment_start(seg: Segment, primary: bool) -> PolyBoolLists.EventNode:",
    "func event_add_segment_start(seg, primary: bool) -> PolyBoolLists.EventNode:",
)
s = s.replace(
    "func event_add_segment_end(ev_start: PolyBoolLists.EventNode, seg: Segment, primary: bool) -> PolyBoolLists.EventNode:",
    "func event_add_segment_end(ev_start: PolyBoolLists.EventNode, seg, primary: bool) -> PolyBoolLists.EventNode:",
)
s = s.replace(
    "func event_add_segment(seg: Segment, primary: bool) -> PolyBoolLists.EventNode:",
    "func event_add_segment(seg, primary: bool) -> PolyBoolLists.EventNode:",
)
s = s.replace(
    "func event_update_end(ev: PolyBoolLists.EventNode, end: Point) -> void:",
    "func event_update_end(ev: PolyBoolLists.EventNode, end) -> void:",
)
s = s.replace(
    "func event_divide(ev: PolyBoolLists.EventNode, pt: Point) -> PolyBoolLists.EventNode:",
    "func event_divide(ev: PolyBoolLists.EventNode, pt) -> PolyBoolLists.EventNode:",
)
s = s.replace("func calculate_self(inverted: bool) -> SegmentList:", "func calculate_self(inverted: bool):")
s = s.replace(
    "func calculate_pair(segments1: SegmentList, inverted1: bool, segments2: SegmentList, inverted2: bool) -> SegmentList:",
    "func calculate_pair(segments1, inverted1: bool, segments2, inverted2: bool):",
)
s = s.replace("var pt2: Point = ", "var pt2 = ")

with open(p, "w", encoding="utf-8") as f:
    f.write(s)
print("patched")
