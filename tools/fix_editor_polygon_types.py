import re

p = r"c:\Users\V\Desktop\Shape\ShapeUp\shapeup_core\decomposition\editor_polygon.gd"
with open(p, "r", encoding="utf-8") as f:
    s = f.read()

old = (
    'const _PolyboolExtensions := preload("res://shapeup_core/decomposition/poly_bool/polybool_extensions.gd")\n\nvar vertices'
)
new = (
    'const _PolyboolExtensions := preload("res://shapeup_core/decomposition/poly_bool/polybool_extensions.gd")\n'
    'const _EditorVertex := preload("res://shapeup_core/decomposition/editor_vertex.gd")\n\nvar vertices'
)
if old not in s:
    raise SystemExit("anchor not found")
s = s.replace(old, new)
s = s.replace("var vertices: Array[EditorVertex] = []", "var vertices: Array = []")
s = s.replace("var holes: Array[EditorPolygon] = []", "var holes: Array = []")
s = re.sub(r": EditorVertex", "", s)
s = re.sub(r"-> EditorVertex:", ":", s)
s = s.replace("Array[EditorPolygon]", "Array")
s = s.replace("Array[EditorVertex]", "Array")
s = s.replace("return EditorVertex.new(", "return _EditorVertex.new(")

with open(p, "w", encoding="utf-8") as f:
    f.write(s)
print("ok")
