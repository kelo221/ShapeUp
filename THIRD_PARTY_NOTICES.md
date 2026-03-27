# Third-party notices and acknowledgements

ShapeUp incorporates or adapts the following projects. Thanks to their authors.

## ShapeEditor (primary upstream)

- **Author:** Henry de Jongh ([Henry00IS](https://github.com/Henry00IS))
- **Project:** [ShapeEditor](https://github.com/Henry00IS/ShapeEditor) — 2D shape editor for Unity, extrusion, CSG-related workflows, and TrenchBroom-oriented export ideas.
- **License:** MIT License

Large parts of `ShapeUp.Core/ShapeEditor/` and related export code are derived from or inspired by ShapeEditor. The original Unity editor UI was replaced with a Godot front end; core mesh/polygon logic retains upstream structure and comments in many files.

## Poly2Tri (Delaunay / constrained triangulation)

- **Project:** [Poly2Tri](http://code.google.com/p/poly2tri/) (ported C# / integrated via ShapeEditor lineage)
- **Copyright:** (c) 2009–2010, Poly2Tri Contributors
- **License:** BSD 3-Clause (reproduced below; full text also appears in source file headers under `ShapeUp.Core/ShapeEditor/Decomposition/Delaunay/`)

```
Copyright (c) 2009-2010, Poly2Tri Contributors
http://code.google.com/p/poly2tri/

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
* Neither the name of Poly2Tri nor the names of its contributors may be
  used to endorse or promote products derived from this software without specific
  prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## Velcro Physics (Bayazit decomposition, math snippets)

- **Project:** [Velcro Physics](https://github.com/Genbox/VelcroPhysics) (formerly Farseer)
- **Copyright:** (c) 2017 Ian Qvist (and contributors per upstream)
- **License:** MIT License (per upstream repository)

Used for convex decomposition (Bayazit) and related code paths; see file-level comments in `BayazitDecomposer.cs`, `MathEx.cs`, `Shape.cs`, and `DelaunayDecomposer.cs`.

**Algorithm credit:** Bayazit convex decomposition after Mark Bayazit — see <https://mpen.ca/406/bayazit>.

## Polygon boolean operations

- **PolyBoolCS:** <https://github.com/StagPoint/PolyBoolCS/>
- **polybooljs:** <https://github.com/velipso/polybooljs>

Source files under `ShapeUp.Core/ShapeEditor/Decomposition/PolyBoolCS/` contain attribution comments; follow the license terms of those upstream projects when reusing or redistributing that subtree.

## FuncGodot (Godot addon)

- **Project:** [func-godot](https://github.com/func-godot/func_godot) (bundled under `addons/func_godot/`)
- **License:** MIT — see `addons/func_godot/LICENSE`

## Godot Engine

- **Project:** [Godot Engine](https://godotengine.org/)
- **License:** MIT (see Godot documentation and source distribution)

ShapeUp is a Godot 4 project using the .NET / C# module; runtime and editor are subject to Godot’s license and third-party notices from the engine build you use.

## TrenchBroom / Quake map format

Map clipboard output targets the Quake-family `.map` format (including Valve 220) as understood by [TrenchBroom](https://trenchbroom.github.io/) and similar tools. TrenchBroom is a separate project; no code from TrenchBroom is bundled—only text output compatibility is intended.

---

If you believe a credit is missing or incorrect, please open an issue or PR.
