# One-off: emit segment_generator_arch.gd from SegmentGenerator.Arch.cs (mechanical).
import re
from pathlib import Path

cs = Path(__file__).resolve().parents[1] / "ShapeUp.Core/ShapeEditor/Generators/SegmentGenerator.Arch.cs"
text = cs.read_text(encoding="utf-8")
# Strip C# wrapper, keep switch body lines for manual paste — script documents source.
out = Path(__file__).resolve().parents[1] / "shapeup_core/shape_editor/segment_generator_arch.gd"
out.parent.mkdir(parents=True, exist_ok=True)
# Minimal header; full body appended by this script parsing switch cases is fragile.
# Instead: copy-paste marker
print("Source lines:", len(text.splitlines()))
