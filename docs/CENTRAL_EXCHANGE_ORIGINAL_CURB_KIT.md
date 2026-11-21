# Central Exchange — Original 3D concrete street curb + steel drain production kit

**Milestone:** Photoreal Environment Vertical Slice, phase 2. **Issue:** [#21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21). **Status:** source-authoring and in-game integration; native Windows F10 and F8 review pending. Continuation of [phase 1](CENTRAL_EXCHANGE_PHOTOREAL_VERTICAL_SLICE.md).

## What changed in the playable world

The eight **generic 36m pale gray rectangular curb strips** at the four blocks bordering **Central Exchange (0,0)** are no longer built by `scripts/city_details.gd`. They are replaced by **eight static imported glTF modules**, two for each of four street corners, instantiated only once as permanent hero streetscape geometry:

- Four longitudinal runs at **x=±8.2m, z=±32m**; four perpendicular runs at **x=±32m, z=±8.2m**. Each spans 36m along the street, leaving the original 6m inner gap for the established **eight accessible curb ramps** and existing crossing markings.
- Each authored module is **1,560 source triangles / 3,264 vertices**, grouped into just three PBR material surfaces. Every model has actual UVs, mesh normals and tangents, front-facing single-sided geometry and a complete closed bevel-profile curb instead of an infinitely thin top plane. Two distinct mirrored variants ensure the 0.83m **concrete sidewalk apron remains on the pedestrian side** when rotated onto the four roads.
- Each 36m edge contains **12 individually shaped 3m curbstones**, original vertical/faceted street profile and physically separated expansion joints. Along the asphalt side, a restrained recessed bitumen run holds **six fully modelled open-slot steel storm grates**: physical steel rim profiles and **nine bars/slots per grate** (54 grate slots per module), not a procedural black rectangle. **48 drainage grates and 96 paving sections** across all eight street runs.
- The original road paint, traffic lanes, signals, ramps, existing dramatic photo-bitumen roadway, original source-glTF bins/cabinets, venue entrances, save layout, city chunk streaming and traffic physics remain unchanged.
- Source glTF and PBR are imported once. **No new physics bodies or dynamic lights** and no per-frame geometry generation. Existing collision is intentionally unaffected; a collision authoring pass for ramp/curb lips requires dedicated player accessibility QA rather than casually introducing blocking shapes.

## Actual photographed material and provenance

Three source-photo PBR materials (**9 unique optimized 1K texture maps** total):
1. [Poly Haven Concrete Floor 01](https://polyhaven.com/a/concrete_floor_01) — original CC0 1K diffuse and OpenGL normal, and official grayscale roughness photograph. The latter is **authored into proper glTF packed ARM**: R=AO(255), G=photographed roughness, B=0 *nonmetal concrete*. All official source links, MD5 and SHA256 are pinned. The source author of Concrete Floor 01 is Rob Tuytel.
2. Existing pinned [Poly Haven Blue Metal Plate](https://polyhaven.com/a/blue_metal_plate) — derive 1K photographic steel albedo, normals, green-channel roughness and partial metallness from the existing audited 2K source scans.
3. Existing pinned [Poly Haven Bitumen](https://polyhaven.com/a/bitumen) — derive 1K photographed gutter asphalt color/normal/roughness from the project's already-audited 2K originals.

**License:** [Poly Haven CC0](https://polyhaven.com/license), usable/redistributable in commercial art. The **architectural/municipal model geometry is original NightGrid work**, not falsely attributed as a real-world photographed curb model or to another studio.

`tools/author_central_curb.py` is the pinned source art authoring script. `.github/workflows/pin-central-exchange-curb.yml` runs it only on a specifically named art branch to fetch the concrete photo source through official Poly Haven HTTPS hosts and verify official MD5; Pillow 11.3.0 resizes existing 2K photo maps and packs correct glTF ARM channels. Output is **two portable original glTF v2.0 meshes**, two geometry binaries, nine photo maps and `SOURCE.json` with source/license metadata and hash for every output. The retail Windows build has no network or Pillow dependency.

## Automated acceptance

```bash
python tools/check_central_exchange_curbs.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/central_exchange_authored_curbs_smoke.gd
godot --headless --path . --script res://tests/hero_intersection_smoke.gd
```

The static audit enforces official concrete source asset provenance, hash-pinned original 2K dependencies, correct nonmetal concrete ARM packing, both 36m geometry variants, UV/normal/tangent/materials and all 13 generated source files. The live Godot smoke boots the **real playable main scene** and verifies eight properly positioned meshes, 24 photographic PBR surfaces, 48 full steel drain assemblies, 96 segmented curb sections, no added colliders/lights and original 81 live traffic signals, existing 8 accessible slopes, existing other photo street props, city save/restore and world seed identity.

Run full project headless suite and Windows x64 export before merging.

## Visual and performance review requirements

1. Capture genuine **F10** frames at **Central Exchange (0,0)** from original identical camera coordinates for night **22:07** and midday. Zoom on concrete kerb bevels, slotted metal grates, dirt accumulation and the original curb slope entrance gap; compare with previous all-gray BoxMesh edges.
2. Check for **z-fighting at every 3m expansion joint**, seams or reversed normals when the imported mirrored module rotates 90°, and overly repeated UVs on long gutters. The source has physically real face depth; it still needs real human art sign-off.
3. Walk all four corners, drive through the junction and return; log F7 issues for camera, objects, curb approach, traffic. Since visual-only geometry has not changed collision, verify there are no newly *perceived* solid footpath obstructions.
4. Collect paired **F8 frame-times** for night/day and driving cold/warm on native Godot 4.7.2 Windows Forward+/Vulkan, 1080p RTX 3060 12 GB. No headless render run proves 60FPS. Compare p95/p99 and 1% lows against previous native baseline.
5. Following approval, proceed toward **physically enterable shopfront thresholds and visible retail interiors**, integrated practical lighting and bounded localized fog/reflection. Do not silently apply a major render toggle city-wide.

This is a meaningful **full curb and drainage profile replacement** at one reference junction, not a claim the entire city has photoreal sidewalks or that all eight 36m edges look AAA in screenshots.
