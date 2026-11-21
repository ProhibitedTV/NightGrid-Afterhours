# Central Exchange — first world-fidelity implementation (2026-11-20)

**Scope: real source-code and geometry changes**, not a concept image, UI mockup or claim that the game is now photoreal. This first architectural pilot follows the **[approved world reference](APPROVED_WORLD_FIDELITY_TARGET.md)** and directly addresses the November 20 Windows playtest criticism that buildings are cubes and inconsistent.

## One controlled location, two protected addresses

The two real corner lots facing the southward Central Exchange approach are:

| Grid cell / lot | District | Road-visible orientation | Geometry |
|---|---|---|---|
| `(-1, 0)`, building `1` | Brickwater | East-facing avenue façade and south street façade | Recessed windows, ground-floor glazing, masonry openings and metal canopy |
| `(0, 0)`, building `0` | Afterhours | West-facing avenue façade and south street façade | Recessed windows, glass/steel panel rhythm, ground-floor glazing and canopy |

Original saved lot footprints, street center lines, building collision bodies, permanent shops, entrance/interior code, traffic signals and the world seed **remain unchanged**. These two lots deliberately **skip** the old thin, fake-box window/awning decoration. Other parcels still use the old procedural visual treatment. No new camera or physics collisions are added in this pilot.

### Geometry design

`scripts/central_exchange_frontages.gd` builds true material-sorted `ArrayMesh` architecture surfaces: structural wall segments *around* window openings, 0.24m-deep recessed glazing, real jamb reveals and mullions, ground-floor glazing at human scale, a continuous canopy, and original existing shop identities.

`scripts/central_exchange_avenue.gd` covers the **road-facing side walls**, which are what actual street-level player cameras see from Central Exchange. This side work was added only **after inspecting our real Godot screenshot and discovering that the initial south façades were hidden from the main view**. Each avenue elevation contains real missing wall topology at the shopfront and upper windows, backed by glazing, with 3.45m storeys. Meshes have coherent UVs along the Y/Z plane rather than box-mesh projection smearing. Caution: the existing collision shell is still full-volume, so these glazed storefronts are not walk-through; separate interior-system doors retain their existing behavior.

### Real CC0 texture acquisition — bundled, offline after import

The old standard city texture triplets are only `128×128`, and were insufficient to convey micro-surface realism. This pilot imports **two photographed 2048px Poly Haven PBR sets** using the official public API; no runtime network or unlicensed asset hotlinking:

- **Brick Wall 001** — albedo (2K JPG), OpenGL normal (2K PNG), roughness (2K PNG), used for the Brickwater masonry face. <https://polyhaven.com/a/brick_wall_001>
- **Blue Metal Plate** — the same three maps, used for painted blue steel cladding/canopy profiles across both lots. <https://polyhaven.com/a/blue_metal_plate>

Original files and SHA-256/source URL/licensing metadata are committed under `assets/pbr/polyhaven/` with `SOURCE.json`. All six assets are CC0; Poly Haven's terms/license are at <https://polyhaven.com/license>. `tools/import_polyhaven_pbr.py` and `.github/workflows/import-central-pbr.yml` provide a reproducible, authenticated-offline distribution path. The runtime loads only repository assets and falls back to older textures if not present, which is **not** acceptable for final visual approval.

Estimated **~38 MB source images on disk**, with final Vulkan compression and active GPU memory to be measured on the actual Windows build. No additional dynamic lamps, new crowd meshes or new physics collision bodies in this pass.

## Grounded validation

- `tests/central_frontages_smoke.gd` loads the real playable scene, locates both exact saved parcels, verifies true custom `ArrayMesh` geometries, **front AND avenue window holes**, PBR map binding, shared store IDs, zero new collisions and lights, and consistent recreation after leaving the streaming radius. It also validates the unchanged seed/manifests on save/load.
- `.github/workflows/preflight.yml` runs the new test with previous city, transport, hero assets and indoor save tests.
- `tools/capture_central_frontages.gd` captures **four *real game* frames** at 1280×720: dusk/noon intersection overview and detailed Brickwater/Afterhours avenue storefront viewpoints. The corresponding [screenshot workflow](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/workflows/review-central-frontages.yml) labels them as **software Mesa OpenGL Compatibility**, NOT Windows Vulkan Forward+. They are real framebuffers, not the approved AI visual reference.
- No claim of achieving the approved neon waterfront image, 1080p/60, ray-tracing, full authored glTF/Blender assets, believable transparent working interiors, or AAA-quality mesh proportions. Human screenshot inspection and actual Windows Forward+ testing are next gates.

## Next art passes (not yet implemented)

1. **Human visual approval for real 3D proportions and facades:** independently verify the corner storefront looks less box-like from ordinary driver/player eye height. Record actual Windows Forward+ captures and GPU timing.
2. **Upgrade the third dimension of the entire building:** authored roof and side supports, true apertures through collision where doorways must work, accessible thresholds, actual lit interior depth, sustainable LODs.
3. **Improve the rest of the reference composition:** realistic wet street material and curb/drainage, transport supports, human/car silhouettes and physically consistent storefront lighting, one street at a time.
4. **Do not propagate to the rest of Morrow Bay until an actual before/after screenshot and hands-on player review confirms the fidelity is meaningfully better**.

These constraints correspond to open [visual quality #19](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/19), [vehicle design #20](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/20), and [city placement #21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21). None is closed by this pilot.

## Photographed asphalt pilot — November 20, follow-on PR

The original road deck is still a flat collision-safe 14m-wide network, but
its top surface used the same low-resolution, generated 128px material that
makes much of Morrow Bay read as abstract/blockout. The new, **visually
limited** Central Exchange road-surface study attaches
`scripts/central_exchange_road_surface.gd` to the actual playable scene.

This pilot reuses the **already imported and licensed CC0 2K Poly Haven
bitumen scan**, with albedo, OpenGL-space normal, and roughness maps. It does
not claim the roofing-grade scan is the final traffic-worn aggregate material;
that choice needs visual approval and may be replaced by a documented,
licensed pavement/asphalt photoscan. At present the scan is closer to a
physical micro-surface than generated color noise, but it must be inspected
before use in other districts.

The two actual `ArrayMesh` render nodes cover thirteen noncolliding street
patches: the permanent 14m central road center, four travelling-lane approach
panels, and eight narrow damp shoulders/gutters. Every surface uses an
unwrapped, world-anchored **3.5m texture repeat**, signed tangents for proper
normal-map response, and correct up-facing triangle winding. The damp strip
has lower roughness and a controlled clearcoat; the dry centre remains matte.
There are **no new physics bodies, streetlights, reflective decals, roadway
boxes or changes to lane centerlines**. This is a two-drawable PBR swap at
one review location, not a citywide scene dressing pass.

The road photoscan sits at **Y=0.016m**, above the original road top but
below the visible lane markings; the central square ends at ±7m and the
approaches begin at ±14.15m so the zebra/stop-bar zone at approximately
±10.3–13m remains clear. The 28m lane approaches end at ±42m, well before
the next intersection. All storefronts, train positions, sidewalk foundations,
road collision, v1 save and seed manifests remain unmodified.

Grounding and quality gates:

- `tests/central_road_surface_smoke.gd` checks actual 2K map binding,
  triangle winding, UV scale and tangent buffers, two material-sorted
  drawables, crosswalk clearance, no collisions/lights, and save continuity.
- The screenshot workflow publishes genuine Godot **Mesa OpenGL compatibility**
  frames from exactly the same road-level camera at noon and dusk:
  `central-scanned-road-noon-real-godot.png` and
  `central-scanned-road-dusk-real-godot.png`. They are useful for verifying
  the integration, **not a substitute for Windows Vulkan Forward+**.
- On Windows, compare a matching before/after view, inspect tiling scale
  under shallow driving viewpoints, neon and dry/wet reflective response,
  midday texture color, contact with curbs/paint, GPU memory and p95/p99
  driving performance. Do **not** promote this small engineering pass as
  proof that the game has reached the approved AAA photoreal target.

Next full-quality work remains real asphalt/aesthetic reference selection,
district-specific road drainage, credible coastal boulevard geography,
high-quality modular buildings, physically connected transit, car silhouette
and genuine RTX 3060 Forward+ visual/frame-time acceptance.
