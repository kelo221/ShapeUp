# Types.cs → Godot splits (one global `class_name` per .gd file):
#   point.gd (Point), intersection.gd (Intersection), segment_fill.gd (SegmentFill),
#   segment.gd (Segment), point_list.gd (PointList / region), segment_list.gd (SegmentList),
#   combined_segment_lists.gd (CombinedSegmentLists), polygon.gd (Polygon).
# Transition + EventNode + StatusNode + lists → linked_list.gd (class PolyBoolLists).
extends RefCounted
