# Morrow Bay physical coherence

This pass follows the native Windows reports tracked in [issue #159](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/159). It builds on the [Brickwater art pass](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/163) and [streaming work](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/164).

| Generated fixture | Change |
| --- | --- |
| M-Line east–west corridor, Z −58 | Eight curbside piers, continuous steel stringers and transfer girders carry the guideway outside the traffic lanes. The closest pier footing is 10.13 m from the road centerline. The bottom of the transfer structure is above 10 m. |
| East Gardens, X 232 | The street approach has a 1:12 grade, with a level landing at the station door. Use the existing Transit action to call the lift, walk the guarded bridge to the platform and use Transit at the marked door of a stopped train. At the next stop, platform passengers alight by a train door and can call a lift down. |
| Grid intersections | Two grounded masts per standard intersection carry four approach-facing heads. The original phase rules and Central Exchange assembly keep their existing behavior. |
| Horizon Commons, X 203 / Z 40 | The canopy has its own matching collision shape and the light housing meets the soffit. The chase camera sweeps a 30 cm radius from the vehicle focus to the proposed camera position and contracts at roof edges. |
| North Quay Exchange, X −29 / Z −203 | Eight counters and the roof are solid. Four delivery cartons can be dislodged by sufficient contact speed. A carton spawns at most one short-lived physics body, owned by the landmark chunk, and can transfer momentum without applying structural vehicle damage. Vehicles lose the into-surface component of their movement on hard contact and play a severity-scaled impact cue. |
| Pier Storage / Night Services, block (−4, −1) | The existing photo-material walls and roof face outward, the brick closes to grade and the upper fascia, and both shutter bays have fitted jambs and headers. Building footprint, shell collision and address are preserved. |
| General alleys and South Bus Works | Ordinary dumpsters are parked alongside the building to leave a continuous path. Their two matched shapes register with their visuals in the shell stage. The existing South Bus Works check covers ten solid props through unload and reload. |

Station IDs, train timetable, lot generation and save version remain stable. Legacy street boarding remains available at the four other stations. An older train save without platform information uses the legacy street exit. A v1 save made while the lift is in motion resumes at the destination landing.

## Assets

The market cartons use the existing [Poly Haven cardboard box source](../assets/models/polyhaven/cardboard_box_01/SOURCE.json) and its pinned CC0 mesh and material maps. Pier Storage reuses the existing [Poly Haven scanned shutter](WEST_DOCKS_CC0_GLTF_ART.md) and [photographic wall and roofing maps](../assets/pbr/polyhaven/SOURCE.json). The rail and traffic mounting geometry and vehicle impact cues are original project code. The patch uses the existing city material library and adds no downloaded assets.

## Validation

All 68 Godot regressions passed on game commit `a8cb369`, including the generated-location and staged-streaming checks. Windows preflight verified the original baked material bytes and all mipmaps. The Windows release export started under native Forward+ and Vulkan on the RTX 3060 and exited normally after 180 frames. [Hosted preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45041266375) · [Hosted Windows build](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45041266367).

Run the real generated-location smoke with `godot --headless --path . --script res://tests/physical_coherence_smoke.gd`. It also runs in Windows Forward+ with its normal gameplay camera, player and vehicle controllers. Set `NIGHTGRID_PHYSICAL_PLAYTEST_DIR` to a new absolute directory to save those gameplay frames.

For matched Windows captures, use Godot 4.7.2 with the same graphics profile, seed and screen size on both revisions. Set `NIGHTGRID_PHYSICAL_CAPTURE_DIR` to a new absolute directory and set `NIGHTGRID_SOURCE_REVISION` to the revision being captured. On the baseline, copy only the capture script into the source checkout.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_physical_coherence.gd
```

The F8 trace uses the existing [Brickwater streaming route](STREAMING_PERFORMANCE.md) with `--measure --profile --drive-night --trace-only --settled`. The recording starts after 60 rendered frames and repeats the same route.

## Windows gameplay captures

Both sets ran at 1920×1080 with Forward+ and Vulkan on the RTX 3060. The fixed views use matching cameras, lenses and clocks. The Horizon Commons frames use the actual chase camera with the same vehicle, yaw and pitch. The clearance correction moves that camera from 9.52 m to 4.87 m above world origin and keeps the car in view.

| Location | Before | After |
| --- | --- | --- |
| Pier Storage / Night Services | [Warehouse envelope](playtest/physical-coherence-159/pier-storage-before.png) | [Warehouse envelope](playtest/physical-coherence-159/pier-storage-after.png) |
| East Gardens approach | [Intersection and guideway](playtest/physical-coherence-159/m-line-and-signals-before.png) | [Intersection and guideway](playtest/physical-coherence-159/m-line-and-signals-after.png) |
| Horizon Commons, 02:01 | [Chase camera](playtest/physical-coherence-159/horizon-gameplay-camera-before.png) | [Chase camera](playtest/physical-coherence-159/horizon-gameplay-camera-after.png) |

The [East Gardens gameplay frame](playtest/physical-coherence-159/east-gardens-platform.png) was captured after walking up from the lift to the stopped train's door. The native replay reached 130 km/h through the former pier line with 100% vehicle condition. After hitting a carton at North Quay, the car still traveled at 21.29 m/s with full condition. Its subsequent counter impact brought it to a standstill and reduced condition to 86.19%. The same replay checked walking clearance under the canopy, a solid lift landing at 13.25 m, and boarding, alighting and returning to street level at Helix. [Playback data](playtest/physical-coherence-159/playback.json).

The [before manifest](playtest/physical-coherence-159/before-manifest.json) and [after manifest](playtest/physical-coherence-159/after-manifest.json) preserve the original capture names and hashes. The checked-in image names add a `-before` or `-after` suffix for the pairs above.

## Native F8 timing

These runs used Windows Godot 4.7.2, Forward+ and Vulkan at 1920×1080, an RTX 3060 12 GB, Ryzen 7 2700X, 32 GB RAM, world seed 834726, VSync off and the same 60 Hz physics settings. Every pass used the same city route, camera rotation and real accelerator input, reached 130 km/h, and retained full vehicle condition. Ambient traffic was disabled. The before and after figures use the game's F8 recorder. The profiler also records wall time between viewport draws.

| Game revision | Pass | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| #164 baseline `171c9e6` | First | 18.75 | 25.69 | 30.00 | 44.74 | 248 | 2 |
| #164 baseline `171c9e6` | Repeat | 19.70 | 27.80 | 29.44 | 31.19 | 254 | 0 |
| #159 candidate `a8cb369` | First | 19.05 | 26.19 | 28.36 | 31.21 | 242 | 0 |
| #159 candidate `a8cb369` | Repeat | 22.25 | 53.82 | 149.00 | 150.00 | 205 | 26 |
| #159 candidate confirmation | First | 18.06 | 27.08 | 29.76 | 33.44 | 227 | 1 |
| #159 candidate confirmation | Repeat | 19.44 | 28.33 | 28.90 | 31.32 | 262 | 0 |

The first-pass F8 p99 was close across revisions. Both builds recorded zero runtime material bakes in the matched drives. The first candidate repeat had a 759.54 ms wall-frame interval. At that frame the profiler reported 12.57 ms viewport CPU, 5.13 ms viewport GPU and 0.60 ms for the longest tagged chunk stage. The long interval remains unattributed. The confirmation repeat recorded no frames above 33.3 ms. The 16.67 ms target remains unmet on the measured night route. [Summary with viewport timings](playtest/physical-coherence-159/f8-statistics.json) · [Raw CSVs and profiles](playtest/physical-coherence-159/f8-traces.zip).

## Remaining scope

- Lift transfers use the Transit action and a visible timed cabin. Full walk-in lift interiors and animated landing doors remain follow-up work.
- Destruction is scoped to the four delivery cartons. They reset on chunk rebuild or reload. Permanently installed fixtures, structural buildings and railway supports stay static.
- Ambient traffic was disabled for the repeatable playback. Manual controller feel, an unrestricted traffic playtest and every possible older save position inside newly solid props remain unverified.
