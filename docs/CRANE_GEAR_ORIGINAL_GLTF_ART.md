# West Docks: original Crane & Gear warehouse architecture
**State:** implemented original source-owned glTF technical production art, awaiting actual Windows visual approval. **Issue:** [#51](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/51). Permanent location **West Docks (-4,-2) lot 1**, immediately south of the original Dock Watch block (-4,-1).

## What is actually installed in gameplay
A complete architectural mesh **replaces** the generic opaque, repeated-windows warehouse render for the existing Crane & Gear parcel. The original, save-stable invisible `StaticBody3D`/BoxShape3D collider is **preserved**, and all public sidewalk/road/rail geometry, civic service interaction pins, world seed, stored manifest and camera collision remain unchanged. The source glTF lives within the normal city chunk lifetime and unloads/reloads deterministically.

- Original authored **glTF 2.0** in `assets/models/nightgrid/crane_gear/crane_gear_warehouse.gltf` with six material-grouped primitives; **3,114 mesh triangles, 6,228 UV-mapped vertices**. The full geometry is generated in a one-time *art-authoring* pass by `tools/author_crane_gear_gltf.py`. The retail game never runs the authoring script.
- Two genuine **recessed sectional loading bays**, assembled from jambs, physical steel headers, thresholds, segmented rollup panels and section joints. These are visibly closed (the original parcel collider remains solid); they are not fake gameplay doorways.
- **Sixteen true front window apertures + 24 side windows** with glTF modelled frame depth, separate backing room layers, mullions and sealed external walls. Not floating window rectangles over opaque walls.
- Full back elevation, original three-dimensional structural steel canopy, wall returns, sloped four-section roof, complete parapet and rooftop mechanical enclosures. No new lights, scene-node BoxMeshes, collision volumes or gameplay doors.
- Exactly **three photographic CC0 material families** with real UV coordinates, tangent-space normal maps, and proper glTF green-channel roughness / blue-channel metallic: **Poly Haven Brick Wall 001, Blue Metal Plate, and Bitumen**. These were already installed as 2K CC0 scans; the authored model bundles offline-pinned optimized 1K color/normal/packed ARM derivatives. Additional glass, interior, and painted steel are original physically based parameters.
- The **eleven generated files** (one `gltf`, one `bin`, nine derivative textures) are self-contained, SHA-256 pinned and importable by the Godot 4.7.2 glTF importer. No game runtime network dependency.
- Source is original NightGrid architectural geometry (not a repackaged third-party building or falsely claimed Blender artist asset). Production authoring script is committed, with its SHA-256 pinned alongside all exported file hashes; `tools/check_crane_gear_gltf.py` audits offline.

## Measured layout / compatibility
The authoring reference envelope is **16.1 m wide, 20 m high, 23 m deep** (W2 West Docks archetype at the default seeded parcel). Runtime scales the same model to the saved lot width, height, and depth to preserve older persisted seed/variant layouts. The model's positive Y axis is up, front doors face `-Z`, and the lower source model base is 0.12 m above its local origin.

The separate civic services **CRANE & GEAR** site remains at its existing independent world address. The source has *zero* new collision bodies or practical lights. There is no physics change that would make the shutter bays enterable; carving the collider for real access would require a separate tested gameplay feature.

## Source/rights
Licensed photographs:
- https://polyhaven.com/a/brick_wall_001
- https://polyhaven.com/a/blue_metal_plate
- https://polyhaven.com/a/bitumen
- https://polyhaven.com/license — **CC0 1.0**

The original meshes are authored specifically for the fictional NightGrid world. Neither the City/NightGrid branding nor original meshes are claimed to be public-domain merely because their derivative photographic texture layers came from CC0.

## Validation
The PR adds both `python tools/check_crane_gear_gltf.py` and `godot --headless --path . --script res://tests/crane_gear_gltf_smoke.gd` to the existing preflight suite. The smoke checks actual imported Gltf meshes/material maps/UV tangent basis and source geometry; the two original parcel colliders; the exact persisted profile footprint/address, world seed and manifest; and unload/reload. The existing full suite and Windows x64 export remain required before merge.

## Real Windows visual acceptance
This is a **functional geometry/PBR pilot, not a verified AAA screenshot**.
1. At West Docks, stand at **CRANE & GEAR, block (-4,-2)**, at night 22:07 and midday. Capture genuine in-engine **F10** images and camera/clock metadata, including three close views of the recessed doors, roof parapet and side/rear elevations.
2. Compare to the older warehouse at the **same camera location** in the previous build; confirm no reversed faces, floating doors, low-resolution normal/roughness seams, conspicuous stretching from older saved profile sizes, or conflicting civic signage.
3. Drive from Dock Watch across this block and return. Use **F7** markers for collision/streaming issues and two **F8** cold/warm CSV runs. Target **1080p/60 RTX 3060** remains unverified until measured; the new asset does not justify asserting a frame-rate gain or visual acceptance.
4. Once real Windows frames pass review, repeat this measured design pattern (with differentiated architecture, not copies) for the other remaining West Docks lots, and replace the visible underpass/curb transition.

This replaces **one** complete physically modeled building envelope; it does not yet deliver a full photorealistic city, modern vehicles or measured AAA lighting.
