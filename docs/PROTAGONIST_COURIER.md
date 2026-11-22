# Morrow courier

The playable courier uses a skinned adult model with short dark hair, photo-based skin, fingerless gloves, layered technical fabric, cargo trousers, boots and a strapped delivery pack. An original Morrow Dispatch fabric patch follows the pack's joint weights. The export contains 49,246 triangles, 24 material primitives, 66 joints and 28 clips. The art uses one medium-detail playable mesh and a single reusable animation library. [Sources, redistribution terms and rebuild](../assets/models/nightgrid/courier/SOURCE.md).

## Gameplay

- The original capsule still owns movement and floor contact at 60 Hz. The visual boot origin follows the bottom of that capsule. Grounded animation uses measured controller velocity, so pushing into a wall stops the gait. The imported eyes sit 9.49 cm ahead of the head joint on local +Z.
- Camera-relative movement keeps the +Z facing contract from #30. The courier faces travel on foot and faces the camera heading while aiming. Crossfades connect idle, walk, run, strafe, reverse and jump phases. The sprint keeps its existing movement speed with a faster run cycle.
- The existing Pulse and Arc actions use a hand-bound visual prop and equipped clips. The weapon system still owns firing, ammunition, hit tests, reload requirements and raycasts. At a reachable indoor service counter, the existing interaction can play a reach gesture.
- The same skinned model moves to the driver's seat while the player capsule is disabled. A stopped driver-side approach plays the boarding clip. Other valid entries use the seated pose. Exiting uses the curb-side end of the alighting clip at the existing gameplay exit point. Occupied v1 saves restore the seated pose from the existing car index.

This branch is based on PR #164. Its runtime and workflow changes merged cleanly in a trial merge with the physical-coherence branch. Pedestrian, transportation and lot-generation code files are outside this pass.

## Validation

Clean Windows preflight at `acb33cd` passed all 68 Godot regressions and the Windows release export. It includes the real skinned-face and animated-joint checks, the Southworks orientation regression, gamepad actions, interiors, combat, transport and occupied save restore. The baked city material check also passed. The exported executable booted on the RTX 3060 with Forward+ and Vulkan and exited normally after 180 frames. [Hosted preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45045724495) · [Hosted Windows build](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45045724280).

## Native gameplay evidence

Both builds used Windows Godot 4.7.2, Forward+ / Vulkan, an RTX 3060 12 GB and 1920×1080. The pairs compare the PR #164 game tree `171c9e6` with the courier game tree `c361e49`. The fixed views share the existing city seed, same camera pose, lens and game clock. Walking and running use real analogue-strength and sprint inputs. The labels show the camera or action from which each real engine frame was captured.

| View | Prototype | Courier |
| --- | --- | --- |
| Daylight face and collar | [Before](playtest/courier-132/day-face-before.png) | [After](playtest/courier-132/day-face-after.png) |
| Daylight rear and pack | [Before](playtest/courier-132/day-rear-before.png) | [After](playtest/courier-132/day-rear-after.png) |
| Daylight side | [Before](playtest/courier-132/day-side-before.png) | [After](playtest/courier-132/day-side-after.png) |
| Daylight walking | [Before](playtest/courier-132/day-walking-before.png) | [After](playtest/courier-132/day-walking-after.png) |
| Brickwater at 22:06 | [Before](playtest/courier-132/night-rear-before.png) | [After](playtest/courier-132/night-rear-after.png) |

The native playback exercised eight directions and a stationary camera orbit, actual grounded walking, sprinting and jumping, the equipped wrist position, firing and reload, driver-side boarding, seating, occupied restore and curb-side alighting. The boot origin was within 0.65 mm of the test floor when idle. [Aim close-up](playtest/courier-132/aim-detail.png) · [Driver seated](playtest/courier-132/vehicle-seated.png) · [Playback measurements](playtest/courier-132/playback.json).

Set `NIGHTGRID_COURIER_CAPTURE_DIR` to a new absolute directory and `NIGHTGRID_SOURCE_REVISION` to the runtime commit before running the capture tool. For the baseline, copy the capture script alone into the baseline checkout.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_courier.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan --write-movie dist/courier.avi --fixed-fps 30 --script res://tools/capture_courier.gd -- --showcase
```

The 11.53-second video is a scripted live-game replay using Movie Maker's fixed recording cadence. All 346 frames decoded after H.264 encoding. It is separate from the real-time benchmark. [Native gameplay video](playtest/courier-132/courier-gameplay.mp4).

## F8 frame times

The same seeded Brickwater walking route ran at 1920×1080 on the RTX 3060 12 GB, Ryzen 7 2700X and 32 GB RAM. The settings used SSR, AO, glow and fog, a 60 Hz physics step, VSync off and a 60-rendered-frame settle. Each pass reached the route endpoint. These are game F8 frame times. The raw profile also includes wall intervals and reported renderer timing.

| Revision | Pass | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| #164 baseline | First | 8.33 | 40.00 | 137.18 | 150.00 | 56 | 42 |
| #164 baseline | Repeat | 9.52 | 13.33 | 15.29 | 16.72 | 1 | 0 |
| Courier | First | 8.33 | 11.26 | 13.33 | 18.60 | 1 | 0 |
| Courier | Repeat | 9.72 | 12.96 | 14.10 | 15.86 | 0 | 0 |
| #164 baseline confirmation | First | 9.09 | 12.50 | 15.08 | 18.18 | 1 | 0 |
| #164 baseline confirmation | Repeat | 9.30 | 13.89 | 15.26 | 16.45 | 0 | 0 |
| Courier confirmation | First | 8.33 | 16.67 | 54.17 | 133.33 | 36 | 17 |
| Courier confirmation | Repeat | 9.09 | 13.89 | 15.22 | 18.27 | 1 | 0 |

Both revisions saw an outlying first pass. The baseline peaked at a 555.42 ms wall interval and the courier at 1,011.78 ms. At the latter interval the sampled viewport reported 3.66 ms CPU, 4.66 ms GPU and a 0.13 ms tagged chunk stage. Both intervals remain unattributed, and neither recorded focus loss. The courier's two warm F8 p99 results were within 16.67 ms. Peak Godot texture memory in the first matched pair was 833.71 MiB on baseline and 955.20 MiB with the courier. These measurements cover one route. The cold results do not establish sustained 60 FPS. [Timing summary](playtest/courier-132/f8-statistics.json) · [Raw CSVs and profiler events](playtest/courier-132/f8-traces.zip).

## Remaining limits

- The original vehicle doors are static. The character transition brings the courier into a real seat and back to the existing curb-side exit, with potential body intersections during the boarding blend. A door rig and travel-aligned hand contact remain follow-up work.
- The equipped clips move the current Pulse and Arc props. Dedicated prop animation and reload contact remain part of the equipment art work tracked in #72.
- The arcade sprint retains its existing top speed, so the feet can slip at that speed. A planted-foot IK pass for steep surfaces would need separate review.
- Manual physical-controller feel and artist acceptance remain unverified. The automated replay covers analogue input strength, eight directions and the existing keyboard/gamepad mappings through preflight.
