# Afterhours Corner — focused building fidelity gate

**Location:** Central Exchange, Afterhours parcel `(0,0)`, lot `0`, preserved world-space anchor and street-facing shop ID.  
**Scope:** This single existing building only; Brickwater and other Morrow Bay buildings retain their original art/collision. This is **intermediate architectural engineering**, not AAA visual acceptance.

## Engineering changes

The previous Afterhours upper floor contained road-visible photographs of blue-painted steel, but its south façade, west-facing street elevation and rear shell ended in disconnected planes. The new `scripts/afterhours_corner_finish.gd` inherits the closed-triangle mesh and UV/tangent builder from the first Brickwater quality gate, while designing an **Afterhours-specific west-side** architectural envelope:

- Four actual outward-wound, six-faced pilaster/return solids bridge the south-to-west corner, opposite service-side corners and the +Z rear wall. Small structural overlaps eliminate sky-visible L-corner cracks without coincident surface z-fighting.
- Two continuous opaque metal foundation/watertable runs close the base of the streetfront elevations at pedestrian eye height.
- One photographed, CC0 **Poly Haven Bitumen** 2K normal/roughness/albedo roof surface, enclosed by four closed blue-metal parapet walls and separate copings. Poly Haven Blue Metal Plate 2K supplies cladding texture; original license/source hashes are retained under `assets/pbr/polyhaven/SOURCE.json`.
- A six-slot roof ventilation grille/housing and three structural awning edge strips give the roof silhouette and the long street-side canopy deliberate physical thickness; no new gameplay colliders or real-time lights are introduced.
- Front and avenue glazing now use a tinted transparent plane followed by a 0.72m-deep, separately shaded warm or dark room backing, instead of flat amber/opaque glass cards. These are **not** enterable furnished interiors.
- UV-mapped, tangent-correct, material-sorted triangle surfaces only, built when the permanent city lot is streamed. No per-frame mesh generation, additional draw-time update callbacks, or physics-rate tied rendering.

This is a targeted fix to building continuity, believable material response and representative roof/shader details. It is not a claim that a handful of material-sorted extrusions equal a hand-modeled game-ready AAA building. **The next asset maturity step remains an original, UV-unwrapped, artist-authored glTF building** with verified real apertures, interiors and LODs.

## Verification

`tests/central_frontages_smoke.gd` loads the playable scene and verifies both protected lots, the completed corner return/foundation/parapet/roof and canopy counts, explicit PBR normal maps and tangent data, the shallow glass/room gap, and zero new collisions/lights; checks against reload/streaming/save manifest remain in the same suite.

The automated review workflow captures **actual running Godot** 1280×720 software OpenGL framebuffer images, with new Afterhours corner-eye and rooftop inspection viewpoints in addition to the old Brickwater references. The updated README panorama is genuine framebuffer evidence, not a generated concept.

**Still required before final visual approval:** visual review of the real roof, street corners, rear returns, right-angle normals, glass sorting and canopy, 1920×1080 Windows Forward+/Vulkan noon/dusk/night captures, gameplay navigation, original photoreal design reference comparison, and measured p95/p99 frame times on RTX 3060 12GB. 60 FPS is a goal only; fixed 60Hz physics is independent of rendered FPS.
