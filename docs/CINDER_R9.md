# Cinder R9

The Cinder R9 is Morrow Bay’s original mid-engine sports coupe. The earlier lineup introduced it at fleet indices 2, 6, and 8. The Kestrel review stack branched before that lineup, so its builds showed Kestrels at those addresses. This branch restores the R9 at the same three positions without moving saved vehicles or replacing the Kestrel.

| Fleet index | Parking coordinate (X, Z) | Paint |
| --- | --- | --- |
| 2 | 63, 33 | Crimson |
| 6 | 63, -143 | Midnight blue |
| 8 | -237, -202 | Acid yellow |

The design study used the Lamborghini Temerario’s low nose, compact overhangs, airflow below the lamps and supported rear aero. The Revuelto informed the separation of the painted coachwork, dark ducts and visible exhaust outlets. The R9 keeps its own proportions, panel contours and three curved light guides. [Lamborghini Temerario](https://www.lamborghini.com/en-en/models/temerario) · [Lamborghini Revuelto](https://www.lamborghini.com/en-en/models/revuelto-models/revuelto)

## Geometry and materials

The 4.66 m long, 2.03 m wide coupe retains its 2.87 m wheelbase and 1.31 m roof height. Its glTF has a recessed bonnet seam, inlet returns and cores, stepped headlamp housings, a side intake, rear-deck louvres, carbon diffuser, titanium exhaust rims, a supported wing, and hinged scissor doors with inner skins. Imported geometry has UVs, tangents and generated Godot LODs. Paint uses a separate clearcoat, distance-filtered metallic fleck and a rain-film normal. The car also uses satin carbon twill, textured titanium and wheel alloy, rubber, cabin upholstery, laminated glass and separate optical polycarbonate.

Two forward spots, one rear spot, and two sill lights are shared in purpose across the three parked instances. Only the occupied R9 projects headlight and sill light at night. The rear projector responds to running lights, braking or reverse. Oncoming lamps and underglow affect the existing road materials through local lighting and Forward+ reflections. The projected lights use no additional shadow maps. Godot’s screen-space reflections depend on the visible scene and quality settings.

Enter the coupe through the normal vehicle action. Use the interaction action beside the parked car to raise or lower a door when a venue or civic interaction is clear. The doors check nearby obstacles before opening. v1 saves keep the same parking and occupied indices. A new optional damage field preserves panel wear on the R9, and a repair clears it.

## Reproduce the assets and capture

Run `python tools/art/author_cinder_r9.py` from the project root. The original project geometry, carbon texture, sockets, bounds orientation and file hashes live in `assets/models/nightgrid/road_cars`. `tools/art/vehicle_rain.py` is the original rain-normal generator. The reused steel normal comes from the existing AmbientCG material set credited in the Central Exchange curb sources. No third-party body mesh or vehicle badges ship with this pass.

Run `tools/capture_cinder_r9.gd` in Godot 4.7.2 Windows Forward+/Vulkan at 1920×1080 with `NIGHTGRID_CINDER_R9_DIR` set to a new absolute folder and `NIGHTGRID_SOURCE_REVISION` set to the build SHA. It renders the actual game at Jade Wash with a fixed camera and clock, records frame deltas and viewport CPU/GPU time, and checksums each PNG. The baseline uses the old `a59e02ac` R9 body and lamps restored to the same world. These are parked render samples. Traversal, traffic and citywide frame pacing are separate measurements.

## Audio provenance

The original Cinder clips are edited from recordings released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). A six-ratio virtual gearbox mixes the recorded idle, mid and load bands. Dedicated tire contact and spray tracks follow motion and surface film. One spatial door emitter plays each latch movement.

| In-game clip | Original recording |
| --- | --- |
| Idle | [SFX_Car_Engine_Inside_Idle.wav by GiocoSound](https://freesound.org/people/GiocoSound/sounds/401550/) |
| Mid and load | [Car Engine Contact Recording by TheLittleCrow](https://freesound.org/people/TheLittleCrow/sounds/669618/) |
| Tire contact | [Car Interior, Driving on Highway by bmacphail](https://freesound.org/people/bmacphail/sounds/795866/) |
| Tire spray | [Passing Car (Wet road) by Breviceps](https://freesound.org/people/Breviceps/sounds/462862/) |
| Door | [Car Door open and close 3.wav by NachtmahrTV](https://freesound.org/people/NachtmahrTV/sounds/556690/) |
