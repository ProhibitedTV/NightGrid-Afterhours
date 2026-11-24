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