# Morrow courier

The playable courier uses a skinned adult model with short dark hair, photo-based skin, fingerless gloves, layered technical fabric, cargo trousers, boots and a strapped delivery pack. An original Morrow Dispatch fabric patch follows the pack's joint weights. The export contains 49,246 triangles, 24 material primitives, 66 joints and 28 clips. The art uses one medium-detail playable mesh and a single reusable animation library. [Sources, redistribution terms and rebuild](../assets/models/nightgrid/courier/SOURCE.md).

## Gameplay

- The original capsule still owns movement and floor contact at 60 Hz. The visual boot origin follows the bottom of that capsule. Grounded animation uses measured controller velocity, so pushing into a wall stops the gait. The imported eyes sit 9.49 cm ahead of the head joint on local +Z.
- Camera-relative movement keeps the +Z facing contract from #30. The courier faces travel on foot and faces the camera heading while aiming. Crossfades connect idle, walk, run, strafe, reverse and jump phases. The sprint keeps its existing movement speed with a faster run cycle.
- The existing Pulse and Arc actions use a hand-bound visual prop and equipped clips. The weapon system still owns firing, ammunition, hit tests, reload requirements and raycasts. At a reachable indoor service counter, the existing interaction can play a reach gesture.
- The same skinned model moves to the driver's seat while the player capsule is disabled. A stopped driver-side approach plays the boarding clip. Other valid entries use the seated pose. Exiting uses the curb-side end of the alighting clip at the existing gameplay exit point. Occupied v1 saves restore the seated pose from the existing car index.

The character branch includes PR #165 at `1d45c0a`, with PRs #164 and #163 under it. It carries its player-specific integrations in the courier, player and world scripts. The game rig uses standard humanoid bone names and stable clip names in a shared animation library. The skinned scene and motions can be retargeted separately from the driver's seat and equipment attachments. The pedestrian branch has no dependency on this character.

## Validation

The combined regression covers the skinned face and animated joints, the Southworks orientation regression, gamepad actions, interiors, combat and occupied save restore. Its integration fixture takes the player through Horizon Commons vehicle entry and exit, the North Quay counter, East Gardens lift access, boarding at a modeled M-Line door and platform alighting at Helix. The final runtime at `8270356` also passes a native check that immediately re-equips the same weapon on exit and verifies that the prop returns to the courier's hand.

The integrated capture revision `17ad6cf` passed all 69 Godot regressions, project preflight, byte-level verification of the baked material maps and the Windows release export. The exported game opened with Windows Forward+ / Vulkan on the RTX 3060. The Windows playtest and beta packaging include the courier attribution. [Hosted preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45068049302) · [Hosted Windows export](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45068049169).

## Native gameplay evidence

Both builds used Windows Godot 4.7.2, Forward+ / Vulkan, an RTX 3060 12 GB and 1920×1080. The pairs compare PR #165 at `1d45c0a` with the integrated courier game at `17ad6cf`. Every pair shares a city seed, camera, lens and game clock. The walking and sprinting photos also share scripted movement inputs. [Baseline manifest](playtest/courier-132/before-manifest.json) · [Courier manifest](playtest/courier-132/after-manifest.json).

| View | Prototype | Courier |
| --- | --- | --- |
| Daylight front | [Before](playtest/courier-132/day-front-before.png) | [After](playtest/courier-132/day-front-after.png) |
| Daylight face and collar | [Before](playtest/courier-132/day-face-before.png) | [After](playtest/courier-132/day-face-after.png) |
| Daylight rear and pack | [Before](playtest/courier-132/day-rear-before.png) | [After](playtest/courier-132/day-rear-after.png) |
| Daylight side | [Before](playtest/courier-132/day-side-before.png) | [After](playtest/courier-132/day-side-after.png) |
| Daylight walking | [Before](playtest/courier-132/day-walking-before.png) | [After](playtest/courier-132/day-walking-after.png) |
| Daylight sprinting | [Before](playtest/courier-132/day-running-before.png) | [After](playtest/courier-132/day-running-after.png) |
| Brickwater front at 22:06 | [Before](playtest/courier-132/night-front-before.png) | [After](playtest/courier-132/night-front-after.png) |
| Brickwater at 22:06 | [Before](playtest/courier-132/night-rear-before.png) | [After](playtest/courier-132/night-rear-after.png) |

The final native playback at `8270356` exercised eight directions and a stationary camera orbit, walking, sprinting and jumping, aiming, firing and reload, driver-side boarding, seating, occupied restore and curb-side alighting. The boot origin was within 0.65 mm of the test floor when idle. [Aim close-up](playtest/courier-132/aim-detail.png) · [Driver entry](playtest/courier-132/vehicle-entry.png) · [Driver seated](playtest/courier-132/vehicle-seated.png) · [Curb-side exit](playtest/courier-132/vehicle-exit.png).

The car chase camera stayed at 4.85 m under the Horizon canopy and the courier stopped at the North Quay counter. The East Gardens lift and stopped train kept the correct pedestrian rig owner, and alighting restored the visible courier with the capsule grounded at Helix. [Horizon chase](playtest/courier-132/horizon-chase.png) · [North Quay collision](playtest/courier-132/market-counter.png) · [East Gardens boarding](playtest/courier-132/east-gardens-platform.png) · [Helix alighting](playtest/courier-132/helix-alight.png) · [Measured playback](playtest/courier-132/playback.json).

Set `NIGHTGRID_COURIER_CAPTURE_DIR` to a new absolute directory and `NIGHTGRID_SOURCE_REVISION` to the runtime commit before running the capture tool. For the baseline, copy the capture script alone into the baseline checkout.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_courier.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan --write-movie dist/courier.avi --fixed-fps 30 --script res://tools/capture_courier.gd -- --showcase
```

The 11.53-second video is a scripted live-game replay using Movie Maker's fixed recording cadence. All 346 frames decoded after H.264 encoding. Movie Maker reported an ObjectDB cleanup warning as it exited after recording. The real-time replay and F8 runs completed separately. [Native gameplay video](playtest/courier-132/courier-gameplay.mp4).

## F8 frame times

The same seeded Brickwater walking route ran at 1920×1080 on the RTX 3060 12 GB, Ryzen 7 2700X and 32 GB RAM. The settings used SSR, AO, glow and fog, a 60 Hz physics step, VSync off and a 60-rendered-frame settle. Each pass reached the route endpoint. The table shows F8 frame times on the matched capture revisions `1d45c0a` and `17ad6cf`. The raw profile also includes wall intervals and reported renderer timing.

| Revision | Pass | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| #165 baseline | First | 9.09 | 11.91 | 16.67 | 22.83 | 4 | 0 |
| #165 baseline | Repeat | 9.09 | 13.33 | 14.29 | 15.65 | 0 | 0 |
| Integrated courier | First | 9.26 | 11.67 | 16.67 | 27.17 | 4 | 0 |
| Integrated courier | Repeat | 9.09 | 12.96 | 14.28 | 16.73 | 1 | 0 |

All four passes recorded zero F8 frames above 33.3 ms and zero runtime material bakes. The wall intervals peaked at 26.30 ms before and 29.87 ms after. Peak Godot texture memory was 833.21 MiB on baseline and 954.70 MiB with the courier. Earlier runs on the #164 stack contained unattributed first-pass stalls on both revisions. This matched #165 comparison covers one walking route. Citywide sustained 60 FPS remains unverified. [Current timing summary](playtest/courier-132/f8-statistics.json) · [Raw CSVs and profiler events](playtest/courier-132/f8-traces.zip) · [Earlier #164 measurements](https://github.com/ProhibitedTV/NightGrid-Afterhours/blob/f1774a2b86d429435c1ccd712b360aaacdcb2ea0/docs/PROTAGONIST_COURIER.md).

## Remaining limits

- The original vehicle doors are static. The character transition brings the courier into a real seat and back to the existing curb-side exit, with potential body intersections during the boarding blend. A door rig and travel-aligned hand contact remain follow-up work.
- The equipped clips move the current Pulse and Arc props. Dedicated prop animation and reload contact remain part of the equipment art work tracked in #72.
- The arcade sprint retains its existing top speed, so the feet can slip at that speed. A planted-foot IK pass for steep surfaces would need separate review.
- Manual physical-controller feel and artist acceptance remain unverified. The automated replay covers analogue input strength, eight directions and the existing keyboard/gamepad mappings through preflight.
