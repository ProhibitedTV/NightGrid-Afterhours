# Brickwater corner building — single-building realism pass

**Building:** Central Exchange, Brickwater corner parcel `(-1,0)`, lot `1`.  
**Scope:** One existing 15–17m-wide building only; the Afterhours building and all other parcels retain their old geometry. **Not approved AAA fidelity yet.**

## Visible implementation

- `scripts/brickwater_corner_finish.gd` closes the south-to-avenue (0.32m lateral / 0.60m longitudinal) transition, the rear avenue return and both service-alley transitions with **closed, six-faced, outward-wound wall solids**. Short overlap distances avoid cracks in the otherwise separate source meshes. The existing facade modules and 4.55m storefront datum are retained.
- The street-level base has a continuous masonry footing; the roof now has a real membrane volume, four solid parapet walls, separate scanned metal copings and a recessed service hatch rather than a front-only floating strip. These features share PBR material families with the parent building.
- The Brickwater south and avenue windows now render tinted, **alpha-blended glass on one plane**, with separate dark or softly lit backing panels 0.7m deeper. This is a shallow visual room—not a claim of fully traversable, furnished interiors or expensive real refraction.
- Three source-owned Poly Haven CC0 2K texture triplets provide photographed brick, blue-painted steel and **weathered bitumen roofing** albedo, tangent normals and roughness, with the normal-map feature explicitly enabled, anisotropic filtering and mesh tangents generated. The roof membrane has real tar/aggregate texture instead of the inherited bright concrete-tile grid. CC0 bitumen provenance: https://polyhaven.com/a/bitumen. Closed new mesh uses back-face culling; legacy inset reveals retain their existing double-sided policy until their winding is proven in all views.
- Static meshes load once with the city streaming chunk: no frame-dependent geometry, new physics bodies, dynamic lamps or per-frame render callbacks. This pass does not tie rendering to the fixed 60Hz gameplay physics clock.

## Verification and acceptance

`tests/central_frontages_smoke.gd` asserts that exactly the Brickwater pilot has all four sealed structural returns, four solid roof edges/coping strips, the two footings and four coherent material-sorted meshes including photographed bitumen, with normal maps enabled on brick, steel and roofing, alpha glass and actual separate interior backing. The other corner building must remain unchanged; existing same-save/streaming, collision and shop-identity tests still run.

**Outstanding quality gates:** inspect the **actual** in-game captures at street-eye angle in noon/dusk, a close corner seam view, roof view and night glazing with Windows Godot 4.3 Forward+ Vulkan; look for edge cracks, reverse normals, Z-fighting, transparent sorting, believable human-scale material texel density and roof/canopy intersections. Compare with the approved reference and previous real frames. Measure GPU frame-time p95/p99 and resident texture memory on RTX 3060 12GB at 1080p; aim for 60 FPS without coupling to 60Hz physics.

The automatic README captures on this feature branch use **real Godot software OpenGL framebuffer** and must be clearly distinguished from human-verified Windows Forward+ results. Green headless CI and good-looking thumbnails do **not** constitute AAA approval. A professional, DCC-authored/UV-unwrapped glTF building, deeper furnished interiors and original material art remain future replacement work. This targeted solidity and PBR-correctness pass reduces visible construction defects but does not pretend to equal a shipped AAA game.
