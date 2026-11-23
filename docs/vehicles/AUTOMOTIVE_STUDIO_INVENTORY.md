# NightGrid Afterhours — Automotive Studio Inventory & Art Production Standard
**Audit date:** 2026-11-23  
**Base reviewed:** `main` at `3ec2af18b7f371f2b0adfb8ccff5209be58019b0`; draft work `#218`, `#219`, `#220`  
**Issue of record:** [#228](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/228)

> This is an engineering + art-direction inventory, **not** a certificate of completed AAA art or measured 60 FPS. Read `AGENTS.md`, `docs/APPROVED_WORLD_FIDELITY_TARGET.md` and current heads before running Codex.

## Artistic north star
Morrow Bay is a coherent original realistic/cyberpunk world. Cars belong to its road engineering, climate, night lighting, culture, repair shops and districts. No random third-party car models with inconsistent poly/material/proportion aesthetics. Original model silhouettes, practical construction and recognizable design language are requirements. Open-source model data may serve as *reference* or licensed generic hardware where art-reviewed, but the hero coachwork is authored for NightGrid.

## Baseline inventory and true status
| Family | Present in baseline | Source | Art state |
|---|---|---|---|
| **Kestrel S6** | 12 parked drivable models + shared police/pursuit variant | `scripts/kestrel_s6_visual.gd`, `scripts/car.gd`, `scripts/world.gd` | Main uses lofted and primitive body; authored glTF front bumper in draft #218, rear closure in draft #219. Neither draft automatically establishes visual approval. |
| **Cinder R9** | **Draft #220 only**; configured for parking slots 2, 6, 8 | `tools/art/author_cinder_r9.py`, `scripts/road_car_visual.gd`, `assets/models/nightgrid/road_cars/` on draft branch | Original script-authored glTF sports body, scissor doors, modeled running gear, custom paint/glazing and audio/damage. Still has optical/door fit, daylight and frame-time gaps. |
| **Civilian commuter sedan** | 25 ambient cars on default non-pooled routes, split 8/7/6/4 | `scripts/civilian_car_coachwork.gd`, `scripts/traffic_vehicle.gd`, `scripts/traffic_system.gd` | One original SurfaceTool coachwork profile with paint variants; primitive cylinder wheel batch. Not a finished photorealistic fleet. |
| **City buses** | Four moving route buses | `scripts/bus_coachwork.gd`, `scripts/traffic_vehicle.gd` | Single procedural ring-based body family; actual route/stop/dwell behavior exists. |
| **Police** | Kestrel-based response and routine patrol vehicles | `scripts/car.gd`, `scripts/world.gd` and dispatch | Existing gameplay infrastructure; needs physically credible original pursuit treatment and native visual review. |

The count descriptions are baseline configurations, not the claim that all pooled cars always exist as visible physics objects. The **Cinder draft replaces 3 parked Kestrel instances**, not three additional cars or three different Cinder model families.

### Important design conflict — do not merge identities
The creator clarified on Nov 23 that the **Cinder R9 is the low, vented, scissor-door supercar at Jade Wash** and the **Kestrel S6 is the boxier, utility-oriented vehicle inspected at South Bus Works**. Yet draft #218's `docs/asset_forge/KESTREL_S6_PRODUCTION_BRIEF.md` labels the low crimson sports fastback as Kestrel. This is a documented **concept-to-model mapping error**. Preserve provenance and tested technical geometry, but put final S6 full-body sculpt approval on hold until an identity-correct design brief is accepted. Don't rename images misleadingly or swap entire models under existing save IDs.

## What is already valuable
- Persistent driving physics, input, collisions, camera, routine/pursuit systems and per-vehicle state live in gameplay scripts. **Do not throw them away to rebuild art.**
- Original scripted geometry production is already real work: the Cinder builder generates glTF and wheel sources, while #218/#219 generate authored Kestrel front/rear pieces. They provide useful dimensional hardpoints, semantic parts and regression fixtures.
- Asset Forge [#175](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/175) already describes source/manifest/Blender/export/import/licensing tests. **Extend, don't fork**, this pipeline.
- The R9 draft has automotive paint and glazing shaders, plus weather/audio systems. Avoid multiple incompatible copies of automotive shaders.
- Existing automatic tests, native captures and F8 traces are real technical evidence, but not creator aesthetic signoff.

## How we sculpt and model original production cars
**A car is manufactured hard-surface geometry first, and sculpted surface detail second.** The highest value is believable silhouette and highlight flow.

1. **Vehicle design bible (#229).** Choose brand identity, vehicle class/use, front/side/rear orthographics, dimensions/axles/collision, car-specific lights, panel geometry, finish, cabin and mechanical logic. The creator approves the direction *before* whole-body modeling. No concept art is proof of an in-game asset.
2. **Editable high-poly master in Blender (#230).** Start from dimensions and a low-resolution body cage. Author curves with control loops/subdivision, creases and consistent smooth curvature; use bevels, engineered booleans and support topology for actual apertures. Separate metal skins, inner structure, glass, reflectors, lamps, fasteners, cabin, wheels and door mechanisms. Sculpt-mode tools are appropriate for upholstery, wear and damage, not as a substitute for precise coachwork geometry. Retain a native editable `.blend` and a reproducible Blender Python process where feasible.
3. **Production low-poly and texture bake (#231).** Deliberately optimize mesh topology, preserve essential silhouette, create UV islands and trim/decal atlases, bake tangent-space normals/AO/curvature where appropriate from high-poly to game geometry. Specify tangent basis/orientation, texel density and padding. Don't simply use bevelled BoxMesh or a high-poly export for every traffic car.
4. **Consistent cyberpunk vehicle PBR (#231).** Shared shader/material architecture with different finishes: practical Kestrel, high-end R9, older commuter, civic bus. Painted clearcoat, metal/plastic/rubber, polycarbonate, glass, grilles, decals, grime, wetness and controlled neon reflections must have consistent physics and art direction. Use proper color spaces/data map conventions, original motifs and licensed texture provenance. Work with world exposure and fog rather than hiding wrong geometry using heavy bloom.
5. **Modular rig and physical registration (#232).** Metres, +Y up, -Z front, fixed wheel/hinge/seat/lamp/camera/damage sockets, collisions separate from render, independent chassis physics, correct door sweep/blocked exit, and per-class audio and signals. Shared code is fine; vehicle silhouettes and scale remain distinct.
6. **Quality tiers and performance (#232).** Hero high detail near the player, optimized mid LOD, economical far fleet; manage texture memory, shaders/material counts and lights. Godot scene import provides LOD options, but approve custom lower meshes for sensitive silhouettes. The 1080p/60 FPS RTX 3060 budget must be *measured* under dynamic traffic and cold streaming.
7. **Real Godot review (#233).** Keep three distinct image sources: creator-approved concept, Blender workbench/turntable, **authentic Windows Forward+/Vulkan in-game shot**. Fixed camera/lens/clock/dry/noon/wet/night, vehicle entry/exit, moving, brake/reverse, rear/cabin, real F8 p95/p99/max, CI and license manifest. Require human approval before promoting production art.

## Prioritized development schedule
| Stage | GitHub | Outcome |
|---|---|---|
| Audit & reconcile | [#229](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/229) | Exact census, family identity, design bible and S6/R9 mapping corrected |
| Sculpt pilot | [#230](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/230) | ONE original Blender high-poly hard-surface component + validated Godot low-poly import |
| Baking/materials | [#231](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/231) | Repeatable high→low bake, shared but correctly distinct auto-material palette |
| Runtime integration | [#232](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/232) | Socket/rig/LOD and traffic-safe visual upgrade |
| Two-car gold slice | [#233](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/233) | Fully reviewed separate R9 and S6 original vehicles, native evidence, 60 FPS target |
| Expand ecosystem | [#234](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/234) | Civilian sedan → bus → work/delivery van → more classes only as needed |

### Signoff definition
Do not mark "AAA complete" because tests pass, models have many polygons, or one parked screenshot looks impressive. Close each gold-slice issue only after the creator accepts the **same finished car in real gameplay** through its complete 360° camera and driving/weather conditions.

## Existing related boards
- [Kestrel S6 #20](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/20), [#210–#217](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/210)
- [Cinder R9 #221](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/221), [#222–#227](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/222)
- [Asset Forge #175](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/175)
- World overhaul [#19](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/19), physical damage [#141](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/141), game audio [#33](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/33).

*This inventory is a point-in-time source audit. New development/merges require refreshing all runtime counts, assets and status flags before use.*
