# Next Windows playtest — instrumentation, route, evidence (2026-11-20)

**Source branch:** `integration/nightgrid-2026-11-20-playtest`.
Use the successful **Windows playtest build** artifact on that branch, not an
older `main` build. The Windows export workflow now includes the exact commit
in `playtest-build-info.json` and embeds it into the running game.
The four feature pull requests #37–#40 remain **draft**, not merged into main.

## Keyboard diagnostics (new)

| Key | Action |
| --- | --- |
| **F3** | Show live FPS and city-stream backlog; last/peak chunk-build times |
| **F7** | **Start** a frame trace; press again to **stop and write** local CSV + JSON |
| **F8** | Capture a **real** full-resolution gameplay PNG plus a JSON context report |
| **F4** | Toggle SSR to compare reflection overhead without changing gameplay |
| F5 / F9 | Save / load a game |
| B / N while driving | NightGrid FM radio on/off and next track (when Ogg files installed) |

F7 and F8 do **not** use any online service. Files go under the Godot
`user://playtest_evidence` folder, with the exact absolute location printed
in the game's log when a recording or screenshot is saved. Each trace
writes a `nightgrid-frame-trace-*.csv` plus paired JSON with frame count,
p50/p95/p99 wall-clock frame interval in milliseconds, maximum frame time,
number of frames over 33.3 ms, and average FPS of the slowest 1% frames.
The CSV also contains: render-frame time, engine-reported process/physics
times, current district, on-foot/car/transit context, coordinates,
outstanding chunk requests, and last chunk-build milliseconds.

These are measured **render callback intervals**, not actual GPU timestamps
or a substitute for a graphics profiler. To establish the target RTX 3060
1080p/60, record native Godot GPU/CPU profiler metrics plus 1% low FPS.
Don't mistake software-renderer CI screenshots for Forward+ captures.

## Test route

1. **Baseline:** Record the exact build revision, Windows GPU/driver,
   resolution, graphics preset, VSync state, and warm versus cold launch.
   Start downtown outside the title/menu, set 1080p and intended visual
   settings. Press F7 and drive across Central Exchange/Glassline.
2. **Streaming:** Drive at speed toward Vesper Market, Brickwater,
   Southworks and back through Central Exchange. Observe F3 backlog, p95/p99,
   asset popping, lighting/shadow changes and collision continuity. Drive
   the loop once from cold start and again after the district has been loaded.
3. **World edges:** At north, west, east and south last roads, attempt to
   drive past the actual safety barriers. Confirm the vehicle stops against
   visible geometry. Capture **F8 at each**; examine harbor water, grounded
   industrial land, eastern ridgeline, crosswalks/road markings, and camera
   behavior. Include a high or elevated M-Line view and a 21:30 view.
4. **KESTREL S6:** Park at South Bus Works, rotate camera around rear-left,
   high rear, low rear, rear glass and both sides. Capture F8 from at least
   three angles, day and night. Test visible paint/cabin bulkhead, lamps,
   glass sorting, wheel contact and cargo-box collision. Try a police
   KESTREL variant too.
5. **Interiors:** Enter/leave the Lantern Cup or nightclub with H, save
   inside, reload and exit. Check for camera teleport/void/occlusion, empty
   geometry, audio attenuation and scene streaming hitches.
6. **Original sound design:** Listen to distinct downtown, docks,
   Southworks and cafe ambience, footsteps, vehicle audio and UI cues.
   **Important:** the 20 NightGrid FM Ogg tracks are still **not committed**
   to GitHub; a green Windows export cannot demonstrate actual chipwave
   song playback until the licensed audio archive is imported (#36).
7. **Finish:** Stop F7 to flush CSV/JSON. Review if the trace covers the
   driving/camera problem; zip or attach the relevant F8 PNG/JSON pairs and
   the paired F7 trace when reporting a defect.

## CI-generated renderer proof

The **Next playtest real-world visual evidence** workflow for this integration
branch renders eight *real game* frames using X11/Mesa OpenGL Compatibility:
four city boundaries, three angles of the actual drivable KESTREL S6 with
rear-hatch fix, plus an elevated harbor overlook. It validates frame size,
nonblank color diversity, unique images and exact Git commit SHA, then
attaches `nightgrid-next-playtest-real-framebuffers` to the run. It does
**not** commit binary screenshot files or silently replace the public
README gallery. It is not Windows/Vulkan or measured RTX 3060 60 FPS evidence.

## Release / acceptance gate

Before merging the four drafts or calling this a stable AAA iteration:

- Both integration Godot headless preflight and Windows export pass on the
  **same exact SHA**.
- Evidence capture produces all eight verified renderer frames.
- Actual Windows driving, car topology, edge collision and save/reload are
  inspected; no known P0 regressions.
- Capture real player-provided visuals and a cold/warm hardware frame trace
  for p95/p99 and 1% low FPS; fix any documented P0.
- Explicitly state which visuals are still prototype-grade compared to the
  approved photorealistic neon waterfront reference.
- Soundtrack archives are imported and audited before claiming an audible
  NightGrid FM release.

Artifacts are generated only upon execution. Check the workflow run for
actual results; this document itself is not a claim that the visual or
hardware QA has completed.
