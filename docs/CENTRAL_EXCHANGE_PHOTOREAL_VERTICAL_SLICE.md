# Central Exchange photoreal street-level vertical slice — phase 1

**Status:** playable source-asset integration / native visual acceptance pending. **Issue:** [#21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21).

The desired game world is the approved *photorealistic neon coastal metropolis*, not a low-poly procedural city. This PR upgrades the **one permanent existing Central Exchange junction (0,0)** at pedestrian eye level, making a reusable, explicit and auditable scan-to-Godot pipeline. The previously installed CC0 photographic road bitumen, two true-geometry corner shopfronts, signals, 8 existing curb ramps, original storm-drains and bounded practical street lights stay intact.

## Source-verified new photographed urban geometry

The genuine two upstream Poly Haven **Hidden Alley** model assets are now pinned as original 1K glTF 2.0 with original 1K normal/albedo/packed material maps:

- [Metal Trash Can](https://polyhaven.com/a/metal_trash_can), **3 street placements** using both original clean and rust variants, retaining four visible source mesh components (can body, lid, two handles) each. Upstream comparison models are correctly offset/recentered and only the requested variant is visible in each placement. 8 original files, ~5 MB.
- [Utility Box 01](https://polyhaven.com/a/utility_box_01), **2 street placements**, actual original photogrammetry/modelled metal enclosure and its high-voltage labeling, no generic box geometry. 5 upstream original files, ~2 MB.
- **License:** [Poly Haven CC0 1.0](https://polyhaven.com/license). All source asset files originate from official Poly Haven hosts. `tools/import_polyhaven_urban_props.py` is a single-use, branch-restricted importer that checks official MD5 data, allowable path/host sizes and records every source URL, SHA-256, MD5 and byte length in two `SOURCE.json` manifests. Normal game builds and Godot runtime do not download assets.
- `scripts/central_exchange_street_kit.gd` installs **five fixed authored street spots**, inside the existing Central Exchange landmark, not independently rerolled with a world seed. Each scanned photo-mesh has a tightly measured collision volume so the avatar cannot walk through the garbage cans or switch cabinets. All five placements are farther than 11.5 m from each traffic-axis crossing center: the existing 14 m roads, signal masts, emergency routing, current buildings, curb ramps, doorway/venue addresses and deterministic world manifest remain unchanged.

There is no invented claim of a completed 39-asset kit or an entire Blender source environment installed; this milestone imports **two** distinct official model assets from that collection with three and two instantiations respectively.

## Source-derived Forward+ material wear

The pre-existing 2K **CC0 Poly Haven Bitumen** photographic diffuse, OpenGL normal and roughness assets (https://polyhaven.com/a/bitumen) are the fixed source for **two** original 512px masked oil/grit decals.

- `tools/author_exchange_grime_decals.py` produces transparent photographic albedo, tangent-normal and correctly packed ORM material layers for **oil** (restrained lower roughness) and **grit** (high roughness). One-time source-authoring via `.github/workflows/pin-central-exchange-grime.yml` commits **six small PNGs + SHA-256 source/generator manifest**.
- Four **Godot 4.7 `Decal` Forward+ projections**, placed along gutters at x/z coordinates outside the central crosswalk. They have no physics bodies, no light emitters, 0.19 m projection height to avoid vehicle/body contamination, and fade between 35 and 49 m for reasonable visibility/lifetime. Texture references are shared between two variants; no runtime pixel noise, scene-altering meshes, or globally mirrored streets.
- Godot documentation: https://docs.godotengine.org/en/4.7/classes/class_decal.html (Forward+ clustered decals, albedo/normal/ORM layers and distance fades). These decals alter the *appearance* of the existing asphalt. They are not new terrain material and do not alter traction/physics.

## Performance / user experience constraints

- New scene content: five authored photo-props, five small static collision boxes and four projected decals. Source textures are imported once and reused among placements. No new dynamic lights, shaders running per gameplay frame or additional city chunks.
- Four street decals have bounded projection volumes and fade at 49m, rather than hundreds of arbitrarily lit unique road assets.
- All original city controls, 81 intersection signals, civic/permanent location identifiers, deterministic save seed/manifest, 60Hz physics and Windows Vulkan/Forward+ remain authoritative.
- This is an **integrated technical source-art pass**, not a visual or FPS signoff. The player must review native F10/Windows frames at night and daylight, and measure F8 run p95/p99 and 1% lows before claiming quality. 1080p/60 on RTX 3060 12GB is a target.

## Validation gates

```bash
python tools/check_exchange_photo_street_kit.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/central_exchange_street_kit_smoke.gd
godot --headless --path . --script res://tests/hero_intersection_smoke.gd
```

`tools/check_exchange_photo_street_kit.py` audits every committed official CC0 model source hash, correct UV/normal/ORM glTF bindings, six PBR derivative maps, original recipe and photographic source hash. `central_exchange_street_kit_smoke.gd` boots the actual playable scene, locates the fixed Central Exchange node, validates five correct scanned model variants, photo PBR materials and real collisions, gutter-only bounded decals, unchanged traffic signals, and identical save/restore stats and manifest.

The existing complete Godot 4.7.2 preflight suite and Windows export **must pass** before merging.

## Native Windows visual acceptance and next vertical slice phases

1. At **Central Exchange (0,0)**, hold in-world time around **22:07** and press **F10** for an honest real screenshot with the NE and NW sidewalk corners and the wet roadway in frame. Capture the *same exact camera* at midday; include real application build/version metadata. No concept imagery in the README game screenshot gallery.
2. Confirm the two variants look like scanned metal, no overlapping side-by-side duplicates, grounded feet, normal/roughness response, realistic 1.12m utility cabinet, no intersections with door canopies, crosswalk signage or light poles, and close/long camera stability.
3. Inspect road stain footprints: transparent edges, faithful roughness differences from their corresponding albedo masks, no projections on vehicles/buildings and no 1K shimmering. Do **not** claim realistic real-time reflection just from a smooth ORM decal.
4. Walk into each model to confirm the colliders correspond to visible real geometry, then drive both cross streets. Capture F7 notes and F8 cold/warm runs (1080p RTX 3060). Compare all frame-time percentiles and actual visual images against the previous baseline.
5. **Subsequent work:** replace remaining junction `BoxMesh` signal cabinets and signboards with genuinely authored hardware, build a consistent sidewalk/curb trim kit, improve two storefront interiors and building entrances, calibrate volumetric dusk/reflections under measured budgets, and capture a meaningful real-game before/after set. Plugin tests for Asset Commons, Road Generator and Terrain3D should remain **isolated authoring experiments**, not replace the production road/save system.

This is phase 1 of a coherent photoreal vertical slice: existing architecture + existing CC0 photographed road + new physically grounded scanned street furniture + new measured PBR road wear. It does **not** yet mean the complete junction matches the approved reference image.
