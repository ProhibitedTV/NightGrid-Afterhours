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
## Automotive body surfacing refinement — 2026-11-23

The first full vehicle was an engineering blockout (11,118 triangles LOD0, 9,231 LOD1). The subsequent authored sculpt pass tackles visible prototype defects rather than trying to purchase a human model:

- **Unified source geometry:** `tools/vehicles/vehicle_body_surface.py` defines original C1 Hermite body stations (width + shoulder elevation) shared by front bonnet, rear tonneau, flank panels and both fascia caps. A finite-difference tangent check tests across station boundaries; this is a **C1 numeric design check, not certified Class-A/G2**.
- **One-piece full-width hood/deck:** replaced independent half patches with matching-edge sheet geometry, camber, subtle stamped creases and tonneau bulges which taper to zero at side seams.
- **Wheel cutouts:** smooth rising lip boundary with realistic tire crown clearance, black inner-arch geometry and distinctly modeled sidewall/tread/bead tires rather than an exposed primitive torus.
- **Manufactured fascia:** full-width curved shell follows the same body shoulder and central camber. The original giant crash-cover boxes have been retired, front inlet and rear ventilation geometry is inset, and shared-silhouette seam tests prevent the black full-width gap originally visible beneath the hood.
- **Headlamp engineering:** fitted oval rubber seal, reflective dish, curved polycarbonate lens, internal projector elements and narrow perimeter daytime-running guide; rear lamp is mounted against the tail fascia. These remain artistic geometry only; light projectors are not gameplay-integrated.
- **Cockpit:** soft upholstered bucket cushion/backrest surface meshes, seat-belt catch, frame, laminated transparent windscreen instead of a single opaque plane; retained seat/hinge/roof socket contracts.
- **Verification:** `tests/test_vehicle_body_surface.py` checks C1 station jumps, body-to-fender caps, front/rear fascia continuity, tire closure, wheel clearance, all finite/nondegenerate geometry and invalid station inputs. Existing strict GLB validator and headless Blender pipeline remain mandatory.

The first surfacing + detailed optics build **passed** [Actions run 45280774518](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45280774518), and the subsequent seat/glazing pass passed [Actions run 45280956174](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45280956174). The newest seam-alignment and expanded test changes are undergoing revalidation; do not infer their success from earlier build results.

### Remaining quality blockers
The current generated car remains an **early sculpt study**, not an AAA production vehicle. In particular it still lacks: individually authored inner headlamp optics and true clearcoat/normal/roughness texture sets, deliberate lower-LOD retopology and high→low baked maps, precise sealed door thickness and window lift mechanisms, functioning convertible linkage, exposed chassis/cabin mechanical design, real in-Godot materials and lighting, and native city driving/traffic frame-time evidence. Maintain the distinction between Blender preview imagery and Godot gameplay screenshots.

### Artistic next review
Compare the original four-view shot (Nov 23), the first body-surface candidate and latest corrected source at identical Workbench camera angles. **Approve based on actual highlight flow and panel fit, not polygon count.** Only after acceptance proceed to UV/baking/material review and isolated native Godot scene (#231–#233). Avoid fetching external car model packs or equating polished lighting with accurate geometry.


## Surface development cycle — visual comparison and source-level QA

We now have a repeatable **inspect → adjust → regenerate → validate → compare** workflow for the same original car.

**Inspect:** Use exactly matched real Blender Workbench camera poses in material colors and neutral clay. Both are offline Blender previews, never Godot screenshots. The initial full car study exported ~11,118 LOD0 triangles; the successful C2/normals candidate exported ~18,196. Higher polygon count is not by itself artistic certification.

**Adjust:** `vehicle_body_surface.py` contains original C2 cubic width/shoulder design stations, shared bonnet/fender/tonneau/bumper boundaries, correct exterior face normals, circular tire-clearance arches, matching wheel-liner anchors and enclosed tires. These are authored mechanical geometry *proxies*, not a replacement for a human sculptor.

**Regenerate:** Blender writes editable .blend, LOD0/LOD1 GLBs, semantic sockets and SHA-256 manifest. The CI job also outputs `geometry_audit.json` measuring curvature and seam continuity, outward normals and minimum wheel clearance; numeric checks are not full Class-A/G2 surface approval.

**Compare:** Download two run artifacts with their original `source.json` files and authentic Workbench PNGs. Install Pillow and run:

    python -m pip install Pillow
    python tools/vehicles/compare_vesper_reviews.py --baseline /path/to/old --candidate /path/to/new --output /path/to/vesper-comparison.png

The comparison utility validates the input PNG SHA-256 hashes and writes matched-pose images plus a JSON provenance record. Its contact sheet supports human review; it is NOT an automated AAA score.

**Remaining gaps:** True manufacturable body-part thickness and interior mechanism fit, independent high-poly detail and retopology, optimized atlas UVs and true baked PBR, animated convertible mechanism, transparent glazing reflection, native Godot driving screenshots and RTX 3060 frame-time verification.

### Verification record

- [Actions 45282462122](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45282462122) successfully verified the C2/profile and exterior normals candidate through Blender and GLB checks.
- Later wheel clearance, clay passes, metric reports, rear integration and updated review tooling need their own successful latest-run evidence. Do not reuse an old green check to claim new commits are validated.
- This is a draft model with original geometry. Never represent Blender Workbench previews as actual in-game screenshots.

## Precision-body iteration — reflected zebra, normal continuity and real panel shells

The new Vesper iteration is deliberately **not** simply subdividing the first car. It treats the hood/fender join, wheel arch and physical panel construction as model-authorship problems that are visible in neutral-clay and reflected-stripe views.

### Precision surfacing

- Longitudinal designer control stations remain C2 natural cubic splines. A new `side_surface_point` builds a deliberate subtle flare and an upper return so the fender's tangent points into the top panel. This fixes the previous shape where aligned vertex coordinates nevertheless made an abrupt, unrealistic shoulder highlight.
- `shoulder_normal_alignment(z, sign)` measures the 3D normal angle across the hood/fender edge at sampled positions; the source audit rejects >1.0 degree. This is a G1-inspired **numeric** seam test, not an industrial Class-A or G2 certification.
- Wheel opening follows an exact circular tire-radius offset while the tire occupies that part of the arch, then a matched-tangent cubic return to the rocker. The previous arc had an infinite slope at its outer endpoint. Both junctions are tested and sampled for clearance.
- Fender flare is subtle and localized above the wheels rather than indiscriminately inflating the whole car. Its mathematical return can be evaluated separately on each wheel side.
- Full fenders, doors, hood/deck and front/rear fascia now use Blender SOLIDIFY modifiers to give manufactured sheet thickness and editable source. The authoring script rejects a master or LOD layer that has fewer than ten body-panel shells or thinner than the specified 4 mm minimum. These are illustrative prototype values, not assertions about real car manufacturing specifications.

### Human-facing visual diagnostics

- `render_vesper_v2_blender.py` produces four identical material-color and four neutral-clay Workbench views.
- `render_vesper_zebra_blender.py` adds two Cycles CPU **reflection-vector zebra** studies at matching 3/4 cameras. Black/white reflected bands visually expose mesh pinches, shading discontinuities and inconsistent normals; only original painted-body materials are replaced. These are **offline Blender diagnostics, not real Godot captures**, and cannot by themselves certify production styling.
- `audit_vesper_geometry.py` now includes the maximum upper-fender normal angle and maximum rocker-arch tangent jump alongside previous station continuity and minimum tire clearance. CI validates the values, not arbitrary file size.
- Source comparison tool requires valid signed-off image hashes; final quality still requires an artist reviewing and iterating on the actual editable control cages, followed by native Godot gameplay.

### Deferred issues for a truly finished convertible

Fully engineered individual panel junctions, car-class-specific geometry detail, true retopology plus baked normal/roughness/AO maps, specific window/door weather seals, functioning multi-bow folding roof, underside/suspension/rims, calibrated HDR/clearcoat lighting and player/traffic physics remain incomplete. The new pass is primarily improving **geometry construction and quality gates**. A green CI check means reproducible files and measurable geometry properties, *not* "human-level" or "AAA" art.

### Current regeneration status

These corrections are committed on draft #238 and are being built by the dedicated Vesper GitHub Actions workflow. Validate the source SHA of every resulting `.blend`/`.glb`/clay/zebra image before comparing to the previous successful verified build. The latest complete rendered artifact, not this text, determines whether the visual change is acceptable.