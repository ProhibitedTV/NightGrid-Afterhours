# Cinder R9

Morrow Bay’s fixed civilian fleet has three Cinder R9 mid-engine coupes and nine Kestrel S6s. The R9s occupy their original fleet indices 2, 6 and 8, so both models remain available in new games and at the expected addresses in v1 saves.

| Fleet index | Parking coordinate (X, Z) | Paint |
| --- | --- | --- |
| 2 | 63, 33 | Crimson |
| 6 | 63, -143 | Midnight blue |
| 8 | -237, -202 | Acid yellow |

The design study used the Lamborghini Temerario’s low nose, compact overhangs, airflow below the lamps and supported rear aero. The Revuelto informed the separation of the painted coachwork, dark ducts and visible exhaust outlets. The R9 has its own panel contours, swept signature light guide and twin projector modules. [Lamborghini Temerario](https://www.lamborghini.com/en-en/models/temerario) · [Lamborghini Revuelto](https://www.lamborghini.com/en-en/models/revuelto-models/revuelto)

## Geometry and materials

The 4.66 m long, 2.03 m wide coupe retains its 2.87 m wheelbase and 1.31 m roof height. The resculpted front and rear share continuous swept edges with the fenders, and the bonnet, curved windshield, roof and door shoulders form a coherent profile. Narrow panel gaps, a lower door cove, a flush handle, an arched fender lip, split-spoke wheels with visible rotors, a recessed rear plate pocket and a cambered wing add detail at close range.

The headlamps have bonded covers, shaped return walls, dark bezels, stepped metal collars and convex projector optics. A separate light guide follows the outer housing. The rear lamps use distinct running, brake and reverse elements. Imported geometry retains UVs, tangents and generated Godot LODs. The paint uses layered clearcoat, distance-filtered metallic fleck, a rain-film normal and slightly rougher lower panels. Other finishes include satin carbon twill, brushed titanium, forged alloy, rubber, laminated glass and polycarbonate.

Two forward spots, one rear spot, and two sill lights are shared in purpose across the three parked instances. Only the occupied R9 projects headlight and sill light at night. The rear projector responds to running lights, braking or reverse. Oncoming lamps and underglow affect the existing road materials through local lighting and Forward+ reflections. The projected lights use no additional shadow maps. Godot’s screen-space reflections depend on the visible scene and quality settings.

Enter the coupe through the normal vehicle action. Use the interaction action beside the parked car to raise or lower a door when a venue or civic interaction is clear. The doors check nearby obstacles before opening. v1 saves keep the same parking and occupied indices. A new optional damage field preserves panel wear on the R9, and a repair clears it.

## Reproduce the assets and capture

Run `python tools/art/author_cinder_r9.py` from the project root. The original project geometry, carbon texture, sockets, bounds orientation and file hashes live in `assets/models/nightgrid/road_cars`. `tools/art/vehicle_rain.py` is the original rain-normal generator. The reused steel normal comes from the existing AmbientCG material set credited in the Central Exchange curb sources. No third-party body mesh or vehicle badges ship with this pass.

Run `tools/capture_cinder_r9.gd` in Godot 4.7.2 Windows Forward+/Vulkan at 1920×1080 with `NIGHTGRID_CINDER_R9_DIR` set to a new absolute folder and `NIGHTGRID_SOURCE_REVISION` set to the build SHA. It renders the actual game at Jade Wash with a fixed camera and clock, records frame deltas and viewport CPU/GPU time, and checksums each PNG. The first six cameras match the earlier `4ce55de4` review build. The rear daylight and headlamp detail cameras provide extra inspection angles. These are parked render samples. Traversal, traffic and citywide frame pacing are separate measurements.

## Audio provenance

The original Cinder clips are edited from recordings released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). A six-ratio virtual gearbox mixes the recorded idle, mid and load bands. Dedicated tire contact and spray tracks follow motion and surface film. One spatial door emitter plays each latch movement.

| In-game clip | Original recording |
| --- | --- |
| Idle | [SFX_Car_Engine_Inside_Idle.wav by GiocoSound](https://freesound.org/people/GiocoSound/sounds/401550/) |
| Mid and load | [Car Engine Contact Recording by TheLittleCrow](https://freesound.org/people/TheLittleCrow/sounds/669618/) |
| Tire contact | [Car Interior, Driving on Highway by bmacphail](https://freesound.org/people/bmacphail/sounds/795866/) |
| Tire spray | [Passing Car (Wet road) by Breviceps](https://freesound.org/people/Breviceps/sounds/462862/) |
| Door | [Car Door open and close 3.wav by NachtmahrTV](https://freesound.org/people/NachtmahrTV/sounds/556690/) |


## Bonded headlight cover refinement

PR #239 adds **actual finite-thickness headlight polycarbonate**, instead of a single transparent face suspended over a cavity. The original Cinder visual design, two optic projectors, LED guide geometry, drivable controller, existing 12 parking indices, and save compatibility remain unchanged.

- `tools/art/author_cinder_r9.py` authors an original 3.6 mm lens shell with outer/inner surfaces and perimeter walls on both front corners, generated from exactly the same body-cover coordinates as the previous single-sided version.
- `scripts/road_car_visual.gd` adjusts runtime lens opacity for the two aligned translucent layers so the headlights do not become unnecessarily dark merely from adding a back skin.
- `tests/test_cinder_bonded_optics.py` checks both positions, opposing normals, perimeter edge normals, paired-vertex physical thickness, optical translucency, and checksum provenance.
- `tests/cinder_r9_smoke.gd` verifies the modeled shell inside the Godot vehicle scene while preserving the existing lighting/driving/save tests.
- Generated `cinder_r9.gltf`, `cinder_r9.bin` and `source.json` were regenerated and committed by the scoped GitHub Actions workflow after its geometry checks passed in [run 45300743564](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45300743564).

This is a **focused optics fidelity milestone**, not proof of cinematic or AAA finished visuals. It still requires a real in-game daylight and nighttime close-up check using the documented native capture fixture, particularly to assess transparency sorting and specular reflections. Do not confuse that required visual review with automated geometry validation.

## Original wheel arch / rocker sculpt pass

Continuing [Cinder wheel/fender issue #225](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/225), the authored Cinder now generates a proper circular tire envelope rather than a fractional-power arch that changed tangent abruptly at its rocker endpoints. The generator matches the sampled upper tire arc with a 36 mm radial design gap, then returns through a cubic Hermite section to the lower body at ±0.520 m around each wheel. This keeps the original wheelbase, physical tire radius and save/parking identifiers unchanged. This is a source **geometric design clearance**; dynamic suspension and steering clearance must still be evaluated separately.

- `ARCH_CIRCLE_JOIN = .340` m: analytic circular portion near tire
- `ARCH_CLEARANCE_RADIUS = .394` m and tire radius `.358` m: 36 mm nominal offset
- `ARCH_WIDTH = .520` m: complete sculpted lip including tangent-matched sill return
- `tests/test_cinder_arch_fit.py`: five independent tests sample both axle tire arcs at 1,001 points; verify C1 tangent joins, monotonic rocker return, lip endpoints, and clearance geometry
- The regenerated front/rear cover, inner wheel tub and wheel-lip meshes all use the same source curve, rather than visually disconnected approximations. The wheel arch test and the original paired-optics checks both passed in [Actions run 45301460762](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45301460762), which regenerated the game glTF/bin on the isolated draft branch.

### Native game art review fixture

`tools/capture_cinder_r9.gd` now contains 11 fixed poses instead of eight. The added `headlight-night-detail` aligns with the daylight lens close-up; `wheel-arch-day-detail` and `wheel-arch-night-detail` share the same front-left wheel camera to compare geometry under consistent camera orientation. These are **capture definitions**, not fabricated images. Run the existing native Godot 4.7.2 Windows Forward+ capture procedure documented earlier to produce true PNG evidence. Review shading on the arch, seal contact, brake/tire fit and alpha-sorting under both lighting conditions before considering any finished-art signoff.

The pass remains stacked on Cinder PR #220. A successful Python geometry gate is not evidence of human-quality automobile sculpting, dynamic no-clipping behavior, or RTX 3060 real-game frame timing.

## Independent stationary calipers

The wheel-arch source improvement has been followed by **physically distinct, non-rotating original brake calipers**. Cinder's shared Cinder wheel-model file now contains the original `Wheel` rotating mesh plus two authored static brake assemblies `BrakeCaliperL` and `BrakeCaliperR`; the driving scene selects the correct left/right caliper for each wheel.

- Authoring: `build_brake_caliper(side)` generates cast-looking, symmetric brake caliper shells, pad-facing regions and metallic retention hardware with fit inside the existing forged rim. The car's wheels, steering, original paint and save-slot assignments are unchanged.
- Runtime: `scripts/road_car_visual.gd` mounts caliper mesh instances directly beneath each steering knuckle, **not** beneath the rotating `Wheel` MeshInstance3D. Thus front calipers steer with the wheel knuckle while all four brake assemblies remain stationary around their axle when the rim spins.
- Source QA: `tests/test_cinder_brake_hardware.py` verifies distinct wheel/caliper GLTF node names, mirrored left/right geometry, clearance within the rim, material assignment, normal triangle count and source manifest hashes. `tests/cinder_r9_smoke.gd` now checks live steering-parent attachments and verifies that wheel rotation never rotates the fixed caliper.
- Asset publishing: the Cinder regeneration workflow now commits **both `wheel.gltf` and `wheel.bin`**, in addition to body glTF/bin and source manifest. It previously committed a new manifest without its new wheel data. This is a critical reproducibility and playable-asset fix.
- Verified: [Cinder regeneration run 45302412080](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45302412080) passed the original optics tests, tire clearance, new caliper geometry/provenance tests and regenerated asset commit. Exported `wheel.gltf` now contains Wheel + BrakeCaliperL + BrakeCaliperR with 4,956 / 292 / 292 triangles.

### Not yet a finished in-game art signoff

The updated model is on stacked draft PR #239, not merged into `main`. Full Godot game smoke and Windows build evidence must be checked against the newest asset commit. The current simplified caliper shell is a manufacturability/animation improvement, not a fully detailed high-poly brake system or guaranteed real-time close-up quality. Native daylight/night wheel captures, steering suspension sweep, occlusion and performance checks remain.

## Opposed-jaw brake fit — non-intersecting rotor channel

The first stationary calipers were separate from spinning wheel meshes but still occupied the physical space swept by the titanium rotor. This refinement fixes the actual mechanical design instead of adding cosmetic complexity.

- The generated cast caliper now has independent outer and inner jaw shells, two inset graphite friction-pad regions and a joined radial bridge *outside* the rotor diameter. These are original Python-authored geometry, not third-party meshes.
- The rotor's modeled axial envelope is 15–41 mm from the wheel's local centerline on the viewed side. The caliper bodies and pads leave that channel empty through the 205 mm disc track; friction-pad faces are at approximately 12 mm and 47 mm, maintaining nominal 3 mm and 6 mm side clearances respectively. The connecting casting bridge begins beyond 214 mm radius.
- The authored outer housing and inner pad are fully formed radial/axial surface shells with real thickness rather than one-sided rectangular decals. Static brake hardware is still attached as a sibling to the spinning rim beneath its shared steering pivot.
- Source tests in `tests/test_cinder_brake_hardware.py` now read actual exported GLTF triangle indices to verify a connecting brake bridge above the rotor's swept radius, no stationary geometry in its axial path, friction pads on both sides and mirrored mounting geometry.
- Verified source regeneration and all three Cinder-specific Python checks: [GitHub Actions run 45303399438](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45303399438). Generated `wheel.gltf` contains `BrakeCaliperL` and `BrakeCaliperR` at **772 triangles each**, previously 292 triangles each. The spinning wheel is still 4,956 triangles. Source checksums and models are committed to the draft PR.

**Remaining:** human visual inspection of day/night native Godot wheel closeups, brake fade/temperature materials and realistic caliper fasteners, measured steering and suspension range without body collisions, texture baking, and production FPS. Numerically empty rotor space does not prove actual driven-car visual realism. Source geometry checks were green; check latest Godot/Windows workflows separately before merge.

## Ackermann steering and full-lock fender safety pass

Real automotive visual steering now uses unequal **inside/outside Ackermann angles** rather than parallel wheel rotation. The controller's positive steering input actually decreases chassis yaw (turns toward car-local +X), so the visual wheels were previously facing the wrong direction. `scripts/road_car_visual.gd` now mirrors the yaw sign, computes a 2.87 m wheelbase and 0.858 m half-track geometry from the vehicle catalog, and slews the steering knuckles at no more than 1.55 rad/s. The fixed calipers follow the steering pivots without rotating with the spinning wheel. Parking re-centers the front wheels.

The source geometry envelope needed a matching revision: at maximum inner front wheel angle (~0.413 radians), a 36 mm straight-ahead tire/arch opening was predicted to narrow to only ~14 mm at the sidewall. The Cinder arch radial envelope is now `.415 m` (57 mm straight-ahead design clearance) and maintains **over 40 mm in the sampled full-lock vertical tire/arch cross-section**. `tests/test_cinder_arch_fit.py` sweeps both sidewalls at ±0.42 radians over 2,501 upper tire samples to prevent a regression; the original C1 arch-to-rocker continuity, monotonic return and source hashes are preserved.

The existing Godot Cinder smoke test now checks correct steering direction, inner-wheel-angle greater than outer, bounded slewing, parked centering and fixed caliper rotation. The native Forward+ capture fixture also adds matching right- and left-lock front wheel closeups and records both front angles with each screenshot in `manifest.json`.

**Limit:** This sweep is a 2D nominal-design clearance gate, not a physical suspension/steering sweep through all body polygons. Actual 3D wheel-to-body contact at full bump, fender overhang, and 1080p/60 FPS require native Godot visual/performance signoff. A source test passing does not establish a human-finished car.


### Confirmed source generation for the full-lock refinement

- [GitHub Actions Cinder regeneration #45304654632](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45304654632) passed the complete source-authored body regeneration, bonded-optics check, tire/arch clearance checks including the ±0.42 radian steering sweep, and stationary brake geometry/provenance tests.
- The workflow committed the regenerated GLTF/binary files to the draft vehicle branch at source-artifact commit `499cb32f2728e12bb6b3c6092c06b08c82932039`. This source-generated asset is the actual game model, not a concept render.
- At 78% right input, computed steering angles are approximately **-0.266 rad left/outside** and **-0.315 rad right/inside**. For left input the angles mirror to **+0.315 rad left/inside** and **+0.266 rad right/outside**. The smoke test checks correct direction and steering-rate/return-to-center behavior. The front steering source is not a new independent physics controller.
- Source-envelope analysis estimates a straight-ahead top-center tire-to-arch gap of 57 mm and a minimum ~43 mm at ±0.42 radian modeled yaw. Actual steering under bump, sidewall/fender lateral fit, and tire slip in game remain **not verified**.
- The follow-up Windows and full Godot runs need to use the latest regenerated asset SHA; a previously green run on an older checkout is not proof of the final vehicle package. No production native screenshot or performance evidence is implied.

## Stamped optical cradles and lens clearance

Review of the actual Forward+ Cinder studio artifact [run 45308732598](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45308732598) identified large faceted black headlight voids, despite good bonded-glass thickness and working headlights. The new original-sculpting pass addresses **the cavity backing**, not the existing player lighting circuit.

- `tools/art/author_cinder_r9.py` now creates a dedicated `HeadlampReflectorHousing` metallic PBR material and two pressed-metal reflector cradles beneath the 3.6 mm bonded polycarbonate lenses. Shallow perimeter returns follow the original on-deck body stations; the trays develop gradually into contoured bowl-shaped projector mounts with a Gaussian local setback behind each module. No additional disconnected glass planes or altered projector sockets are introduced.
- The `OpticCover`, headlight projectors, DRL line, and original painted fender edge stay on their existing geometrically sourced paths. Runtime `scripts/road_car_visual.gd` assigns the pressed housing a subdued 67%-metallic satin finish, while emissive lighting remains separately controlled.
- `tests/test_cinder_headlamp_housing.py` validates the newly exported left and right reflector surface, distinct opaque metallic material, panel depth variation, lens-to-bowl clearance at shared X/Z stations, and source SHA-256 provenance. Existing bonded-optic, wheel arch, tire groove and caliper clearance tests still run.
- The new test gate passed along with the original source regeneration in [Cinder rebuild run 45317105634](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45317105634). Generated binary/glTF assets were committed to draft PR #239.
- Native Godot Forward+/Mesa screenshots are automatically rerun when generated Cinder body assets change. [Capture run 45317188503](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45317188503) is the visual comparison candidate. Geometry and tests alone do not prove that the housings have achieved a professional finish; check actual night/day images first. This studio is not the in-city Windows playtest or RTX 3060 benchmark.

Remaining headlamp art work includes manufactured optical reflectors, realistic gaskets and fasteners, legal-style beam patterns, close-up lighting behavior and native Windows performance. No merge to main until stacked branches and real-game playtests are reconciled.