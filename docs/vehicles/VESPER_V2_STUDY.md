# Vesper V2 | Original Convertible Study

Status: **full-vehicle offline Blender modeling experiment, not an integrated or approved game car.** GitHub issue #237. This branch is stacked on Vehicle Forge #236; neither branch is assumed merged.

## Original design brief

Vesper V2 is a fictional near-future electric two-seat boulevard roadster for Morrow Bay. It is separate from the Cinder R9 performance coupe and Kestrel S6 utility car. Its visual identity is a restrained petrol-blue body with hand-built copper trim, low hood, open cockpit, deliberately separated front/rear coachwork, sculpted rear tonneau, a visible folded soft-top cassette and structural roll hoops.

Initial design dimensions: 4.38 m long, 1.92 m wide, 2.71 m wheelbase. These are concept geometry dimensions, **not validated against NightGrid car physics or roadway collisions**. Godot uses +Y up and -Z forward. Roof is shown stowed; no animated convertible roof is claimed.

## Automotive design and modeling process

Real car surfacing begins with packaging constraints (wheels, occupants, crash and mechanical envelopes), followed by full-scale silhouette and design surfaces, production panel separation, then engineered/visible details. Autodesk's Class-A guidance is particularly useful for controlled highlight flow. https://help.autodesk.com/cloudhelp/2021/ENU/Alias-Tutorials/files/GUID-64611955-D2CC-44F2-98F0-D4F1FE931D8B.htm

Our process substitutes an editable Blender high-detail master and original cubic Bézier hood/deck patches for dedicated automotive NURBS/industrial Class-A surfacing software. This **does not certify G2 or G3 continuity**. Important quality gates are visible reflections, door and headlamp fit, wheel sweep, glazing, materials and real lighting. Blender's subdivision surface modifier supports local edge topology and controlled smoothing: https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/subdivision_surface.html

After shape approval, game production deliberately retopologizes/optimizes and bakes high-poly details into texture maps; Blender's official baking documentation: https://docs.blender.org/manual/en/5.0/render/cycles/baking.html. This first study **does not yet run high-to-low normal baking**, so detail and material quality are provisional. Godot's built-in imported scene LOD and glTF scene import are separate from Blender LOD source models: https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html

## What the tool actually authors

- Editable native Blender master with body/bonnet/deck/quarters/doors, open cabin with dashboard and seats, side rails, windshield glass and fitted frame, roll hoops and folded roof cassette.
- Original Bézier hood and rear tonneau surfaces, 3D front/rear fascias, sills/handles, exposed brake discs/calipers, tires/wheels, lamp bezels and visible light elements.
- Separate GLB exports for LOD0 and LOD1; named wheels, door hinges, seats, lamp and convertible roof sockets. These are currently **data attachment points**, not animated driving/roof behavior.
- Original prototype PBR-like material separation: petrol-blue paint, copper, glass, composite, leather, aluminum, brake metal and tire. Provisional UVs are NOT polished high/low baked atlases.
- Actual Blender Workbench images (front 3/4, rear 3/4, side, open cockpit) for assessment. These are **offline previews only**, not native Godot gameplay or final game-quality shaders.

## Generate

Requires Blender Python with NumPy and Python 3.11+. From repo root:

    blender --background --python-exit-code 1 --python tools/vehicles/author_vesper_v2_blender.py -- --output-dir out/vesper-v2

    python3 tools/vehicles/validate_gltf.py out/vesper-v2/vesper_v2_lod0.glb --max-triangles 120000 --require-node WheelFL --require-node WheelFR --require-node SeatDriver --require-node SeatPassenger --require-node RoofStow --manifest out/vesper-v2/source.json

Generated files: vesper_v2_master.blend, vesper_v2_lod0.glb, vesper_v2_lod1.glb, source.json and four offline preview PNGs. CI uploads these as an artifact for visual review. All mesh geometry is originally authored; no externally sourced car meshes.

## Known gaps / release gate

1. The body is a **geometry study**. It needs measured surface continuity, exact integrated parts, properly inset wheels, full inner architecture, real optimized LODs and improved original panel fit before realism approval.
2. Convertible top is visibly stowed; roof mechanism, folded fabric physics, seals, pivots, animation and rain/wind effects are only future contracts.
3. No measured Godot visual quality or 1080p/60 FPS. Do not add it to world, traffic or garage indices until creator approves geometry and an isolated native Forward+/Vulkan Godot fixture is built.
4. Next: real high-to-low bake/UV atlas under #231, then native screenshots, collision/door motion/roof clearance and performance evaluation under #232/#233.

Current first goal is modest and honest: **Can Vehicle Forge create a complete, original, editable car body and detailed component set that looks coherent from 360 degrees?**