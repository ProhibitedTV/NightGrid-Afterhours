# Vehicle Forge — editable hard-surface source and geometry gate

**Status:** proof-of-pipeline for the Cinder R9 optical enclosure. **Not integrated into Godot, not a finished R9 headlamp, and not certified AAA art.** Tracks Automotive Studio #230, generic Asset Forge #175/#177/#179, and Cinder R9 optics #222. Do not mix this part into Kestrel S6.

## Approach

Car coachwork needs controlled manufactured highlight flow and precision geometry. Blender is the editable DCC source of truth. The Python recipe is an **original contour-based tool** for one enclosed optical module. Its saved Blender source has two collections:

- **MASTER__HIGH_POLY__NOT_EXPORTED:** editable higher-resolution enclosure, gasket, lens, reflector and light-guide, with non-destructive bevel modifiers and adjustable contour control points.
- **GAME__LOW_POLY:** reduced geometry, stable semantic socket names, material groups and provisional UVs. Only this collection is exported as GLB.

This pilot **does not** yet perform high-to-low normal-map baking, final vehicle fitment, or Godot gameplay integration. Full high-poly surfacing, retopology, UV bake and vehicle-specific materials remain in #231 and #222.

## Generate a review candidate

Requires Blender with the glTF exporter and Python 3.11+.

    blender --background --python-exit-code 1 --python tools/vehicles/author_r9_optic_blender.py -- --output-dir out/r9-optic

    python3 tools/vehicles/validate_gltf.py out/r9-optic/r9_optic_game.glb --require-node SocketHeadlampMount --require-node SocketHeadlampBeam --require-node SocketIndicator --max-triangles 5000 --manifest out/r9-optic/source.json

    python3 -m unittest discover -s tests -p 'test_vehicle_asset_gate.py' -v

Outputs: r9_optic_master.blend, r9_optic_game.glb, source.json with the Blender version and SHA-256 checksums. Generated binaries are CI review artifacts, not automatically shipped by the game. All geometry is original, local metres, +Y up, −Z forward. Optical light guides are visible meshes; no extra runtime spotlight is spawned.

## Integrity validator

The pure-stdlib gate checks glTF/GLB header and chunk integrity, unsafe external-buffer paths, accessor bounds and strides, indexed triangles, non-degenerate faces, finite positions, normalized normals, UVs, assigned materials, local bounds, triangle budget, named sockets, and an optional export-manifest hash.

**This is not** a full watertightness proof, a high/low bake verification, a visual fidelity metric, or a Godot performance benchmark. These require more specialist validation and genuine native gameplay captures.

## Production progression

1. Creator approves an **R9-specific** original optical concept and measures its fit to the actual Cinder front fascia. Do not use the unrelated Kestrel reference.
2. Refine high-poly optics and adjacent body/fender geometry in Blender: Class-A-inspired controlled curvature, real panel thickness, optical gasket, mounting structure and manufacturable cuts.
3. Retopologize deliberately. Add panel UV islands, trim atlases, and bake tangent-space normal/AO/curvature with verified cage and tangent conventions (#231).
4. Place the approved GLB in an isolated Godot Cinder review fixture. Preserve vehicle controller, collisions, seats, doors and illumination state. Compare dry noon, fog, neon night and wet night.
5. Run authentic Windows Forward+/Vulkan 1080p gameplay on RTX 3060-class GPU. Document source SHA, 360-degree closeups, headlamp-off optical depth, lit LED signature and frame pacing (F8 p95/p99/max and VRAM).

Concept art, Blender renders, and original Godot screenshot evidence are **three distinct** asset types. Only the latter supports a claim of implemented game appearance.

## Native C++ decision

**No C++ / GDExtension is justified for this first milestone.** Blender/Python handles offline authoring; Godot already supports glTF import. C++ cannot repair poor automotive silhouette, UVs, roughness or reflection behavior. Consider native code only if real profiling identifies a repeatable CPU bottleneck after the existing mesh-batching, LOD and streaming mechanisms are tested.

## Verification limits

Pure Python unit tests and syntax checks passed locally. Blender's system-packaged glTF exporter requires NumPy; CI installs python3-numpy and enables --python-exit-code to fail hard on exporter errors. Blender was unavailable in the local execution environment. The new GitHub Actions Blender build + geometry-gate job is the required next integration check. This PR is a **tooling candidate** until that job succeeds and the exported model receives visual review.
