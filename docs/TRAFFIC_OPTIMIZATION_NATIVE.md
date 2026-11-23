# Live traffic and Windows traversal

Run #8 builds on the integrated Brickwater, physical-world, character, audio and storefront work in #194. Standard play keeps the existing 25 civilian sedans and four City Loop buses. Fixed physics remains 60 Hz.

## Changes retained after profiling

- The traffic controller samples peer positions once per fixed tick. A broad rejection skips distant peers. Plausible nearby peers still use their live position to decide the same longitudinal gap and lane width, including the original bus following distance. Save restoration invalidates the sample.
- Cars and buses keep the same four tires, four hubs, dimensions, materials, positions and coachwork. The renderer submits two shared wheel batches per vehicle instead of eight separate meshes. Cars and buses each share their existing collision shape dimensions while retaining separate physical bodies.
- `--pooled-traffic` enables a separate pilot. It keeps 25 seeded logical IDs and up to 16 prebuilt physical sedan slots. A single 0.20-second director reuses the slots only for candidates outside the expanded camera frustum, beyond a speed-adjusted distance guard, on an open lane that has supporting collision and room for the car. Camera swings suspend leases until the camera settles. The controller checks available collision and closures ahead of leased cars, blocks admissions from indoor or transit focus, and keeps parked slots out of physics, visibility, headway, witness and audio registries.
- Buses, rail, police and player-owned cars stay in their existing systems. On v1 saves the original vehicle list and IDs stay available, with optional logical phases. The original fixed-fleet snapshots are accepted by the pilot. Recycled motor voices fade at the old location until reassigned to a live identity.

The tighter CPU headway path and shared vehicle geometry are enabled for the fixed fleet. Two trials that combined whole signal groups increased measured draw submissions and were removed. The current branch retains the original signal geometry, phases and physical mounting.

## Reproduction

Use Godot 4.7.2 on Windows with a compiled import and a fresh absolute output directory. Supply `NIGHTGRID_SOURCE_REVISION` and `NIGHTGRID_ALLEY_CAPTURE_DIR`. The fixed reference is `c41f709`, an instrumented checkout that retains the gameplay of #194. The optimized runtime is `65070ad`. The later capture script was also used on the reference to keep the native replay settings identical.

```powershell
godot --path . --audio-driver WASAPI --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_brickwater_alley.gd -- --measure --profile --trace-only --settled --living-streets --live-traffic --drive-night --drive-evidence
```

Use `--drive-noon --road-speed` in place of `--drive-night` for the road-speed replay. Add `--pooled-traffic` only for the pilot. The same northbound road crosses Southworks, Afterhours and Glassline. Both launches start at the same coordinate and reset seeded traffic and signals for the repeat. The road-speed fixture releases and reapplies the normal throttle. The night fixture keeps it held up to the existing 130 km/h maximum. Both include a full camera turn at the same distance. Screenshot readback follows the timing interval.

The cold label means the first traverse after rendering the spawn viewpoint for 60 frames. The shader cache remains the OS and driver cache on disk. The warm label means the same route in the same launch. Its normal city streaming can still activate blocks. Measurements use RTX 3060 12 GB, 1920×1080, Forward+/Vulkan, WASAPI, VSync off, SSR, AO, fog and glow on, and seed 834726. Living Streets ran in all modes.

## Native F8 results

The comparison below uses the final focused replay set, with all cars reaching the same end and retaining full condition. The night sessions reached 130 km/h. Daytime sessions peaked at 53–58 km/h. The cold fixed-fleet noon session reached 58 km/h and contained a long wall-clock interruption. The archived data also includes the earlier A/B series and the daylight repeat excluded from the primary table because the game lost focus.

| Setting and fleet | Pass | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Night, original fixed | Cold | 25.00 | 33.33 | 34.72 | 47.46 | 241 | 41 |
| Night, optimized fixed | Cold | 21.84 | 31.94 | 33.33 | 47.29 | 262 | 10 |
| Night, pooled pilot | Cold | 20.99 | 29.92 | 31.66 | 57.30 | 264 | 3 |
| Night, original fixed | Warm | 25.76 | 34.72 | 38.63 | 39.79 | 241 | 55 |
| Night, optimized fixed | Warm | 23.49 | 33.33 | 34.00 | 35.12 | 255 | 22 |
| Night, pooled pilot | Warm | 22.04 | 30.95 | 31.16 | 32.60 | 258 | 0 |
| Noon, original fixed | Cold | 20.00 | 29.63 | 30.00 | 36.70 | 605 | 1 |
| Noon, optimized fixed | Cold | 17.50 | 37.82 | 117.83 | 143.85 | 430 | 47 |
| Noon, pooled pilot | Cold | 17.35 | 26.19 | 29.63 | 42.50 | 503 | 1 |
| Noon, original fixed | Warm | 20.83 | 31.82 | 34.72 | 42.29 | 623 | 28 |
| Noon, optimized fixed | Warm | 19.32 | 30.56 | 30.95 | 37.85 | 563 | 2 |
| Noon, pooled pilot | Warm | 18.33 | 50.00 | 124.44 | 148.56 | 416 | 57 |

### CPU, GPU and residual gaps

With the same 25 civilian cars, p95 headway CPU time fell from 1.27–1.45 ms across the four passes to 0.43–0.51 ms. Warm night median draw submissions fell from 8,142 to 7,941. In that pass, p95 viewport CPU render time fell from 16.54 to 15.97 ms and p95 GPU render time fell from 9.12 to 8.71 ms. At those costs the 16.67 ms overall target remains open. The optimized fixed pass still spends around 3.1 ms at p95 on Living Streets script work in addition to render and physics work. The measurements describe overlapping pipeline stages, so they should be compared individually.

Chunk stages in the final fixed-fleet traces stayed below 2.3 ms. The largest unresolved wall gap was 1,049.41 ms in the optimized cold noon pass. Another was 894.70 ms in the pooled noon repeat. Earlier traces also show gaps around 1,039 ms in both original and optimized builds. These wall gaps are preserved alongside the game-delta F8 data. During the long-gap samples the recorded viewport CPU and GPU work and adjacent chunk stages accounted for a small part of the interval. Draw-pipeline counts stayed unchanged and no traversal material bakes were logged. Windows Performance Recorder could not start the system CPU/GPU capture under the current Windows policy (`0xc5585011`). The system or driver interval remains unattributed.

The pooled pilot reached four cars at night and five at noon in the final replay. The trace logged **24 admissions**, each outside the expanded active camera frustum and at least 88.94 m from the actor. There were no lease retirements in the final matched corridor. An earlier optimized pilot pass exercised one retirement. Broader traffic density, repeated visible continuity across camera changes and sustained lease turnover remain open. The fixed fleet remains the default.

## Gameplay frames and validation

| Southworks chase view | Baseline fixed fleet | Optimized fixed fleet | Pooled pilot |
| --- | --- | --- | --- |
| 21:30 | [Before](playtest/traffic-32/repeat-reference-night.jpg) | [After](playtest/traffic-32/repeat-fixed-night.jpg) | [Pilot](playtest/traffic-32/repeat-hybrid-night.jpg) |
| Noon | [Before](playtest/traffic-32/repeat-reference-noon.jpg) | [After](playtest/traffic-32/focused-fixed-noon.jpg) | [Pilot](playtest/traffic-32/repeat-hybrid-noon.jpg) |

The full 74-case Godot regression workflow and Windows x64 export passed for `65070ad`. The shipped executable booted and shut down normally on Windows Forward+/Vulkan, and the exported PCK passed the pooled traffic smoke test. The focused local regressions covered live pooled admission, closed-lane rejection, v1 traffic migration, bus continuity, exact wheel and body placement, traffic voice reuse, collision-ready high-speed traversal, and the physical world's camera, lift, track and vehicle impacts. [Project preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45098853838) · [Windows export](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45098853898).

[Raw F8 and renderer traces](playtest/traffic-32/windows-raw-traces.zip) · [Benchmarks by case](playtest/traffic-32/benchmark-summary.json) · [Image hashes and lease boundaries](playtest/traffic-32/capture-evidence.json).
