# NightGrid: Afterhours — Windows beta 0.1.0-beta.7

**Status: early, diagnostics-focused beta (Windows x64).**

## New in beta.7 — city art and ambient traffic overhaul

- Photographic asphalt across the established street network, damp gutter materials, and photographic concrete sidewalks/curbs.
- Ordinary brick shells reuse the existing CC0 photographic masonry maps, and the Moon Noodles parcel has modeled upper-floor window frames and inset glazing.
- Original mesh replacements for 25 ambient sedan bodies and four city buses, with wheel-well openings, sloping glazing on sedans, shared materials and revised wheel stance; traffic routes, collision shapes, and passenger boarding stay unchanged.
- Expanded civic simulation, central police dispatch and routine patrol service; bounded road restriction and pedestrian/traffic streaming foundations. Automatic civilian detours and pooled street crowds are not enabled yet.
- Nine actual game captures on the README, including intentionally staged portraits of real traffic actors. These are Linux compatibility-renderer images, not native RTX frame-time evidence.
- Visual feedback, gameplay suggestions and bug/performance templates are available on the public issue tracker. Use F7/F8/F10 to capture repeatable playtest evidence.

This version is prepared for publication only after the integrated source and nine-image gallery pass preflight and the Windows export and archive verification complete. It remains an early beta. Native Windows fidelity, continuous driving and 1080p/60 performance require playtesting.

## Previously in beta.6 — licensed, real-model West Docks street art

The first playable art milestone incorporates original, auditably licensed 3D geometry rather than another lighting preset. It is still a technical pilot, **not a finished AAA world**.

- **Permanent West Docks parcel (-4,-1, lot 1), next to Dock Watch Desk:** replaced its old opaque façade with an original cohesive full-envelope service-building mesh, sealed photo-bitumen roof, recessed upper glazing/backing, and UV-mapped surfaces using real 2K Poly Haven CC0 brick, blue steel, and roof photography plus normal/roughness maps.
- **Real scanned roller shutters:** two physically modeled clean and graffitied variants of [Poly Haven's CC0 Rollershutter Window 01](https://polyhaven.com/a/rollershutter_window_01) are imported as original **glTF 2.0 1K PBR** assets, including geometry binary, albedo, normals and metal/rough maps. All originals are committed, not runtime downloads.
- **Verified licensing:** official Poly Haven API/CDN source, per-file MD5 verification and SHA-256 source manifest; offline source-integrity test included.
- **Game stability:** unchanged building collision shells, civic interactions, saved parcels/seed, roads and streaming; no extra dynamic lights or physics. Full Godot 4.7.2 tests and Windows export passed, including new geometry/PBR and deterministic reload checks.
- **Your comparison:** return to West Docks Dock Watch at 22:07, inspect the adjacent PIER STORAGE / NIGHT SERVICES rolling garage, freeze clock with Y and capture F10. Repeat at noon, check both source-model shutters, then record F8 over the same road route and mark issues with F7. Tagged **beta.5** remains the old-art control.
- **Open work:** Native Windows photoreal quality and RTX 3060 frame-time measurements remain unverified. The surrounding city and car silhouettes still need original high-quality UV glTF art under issues #51 and #20. [Source and visual sign-off guide](https://github.com/ProhibitedTV/NightGrid-Afterhours/blob/main/docs/WEST_DOCKS_CC0_GLTF_ART.md).

## Previously in beta.5 — RenderingServer streamed city and real street lighting

Based on the [Firebelley Games video “Stop Using Nodes for Everything in Godot”](https://www.youtube.com/watch?v=1PnG3r1rKcs) and the player's three **real Vesper Market, 19:34 beta.4 screenshots** (Filmic vs ACES vs AgX), this release addresses both **scene-tree overhead during chunk loading** and **real-looking street-level illumination**.

- **Decorative city chunks are no longer one render node per material bucket.** Their existing spatially grouped MultiMesh batches are drawn through Godot 4.7.2 `RenderingServer` with **one lightweight RID lifetime owner per chunk** and one global owner for street markings. Save-stable building collisions, signs, cars, scripts and authored façades remain normal Godot nodes. Unloading/cancelling a chunk frees the RIDs and their backing resources safely.
- **Street lights are now anchored to the actual geometry.** The previous pool was positioned on a different grid from the emissive lamppost heads. Of the same **eight** pooled shadow-free OmniLights, four illuminate real pole heads and four illuminate the existing district storefront canopies/entrances. They turn off completely during the day, retain bounded ranges and have no added per-building GPU-shadow costs.
- **Better evidence on F7/F10:** live `RenderingServer` batch and detail instance counts, avoided scene nodes and active practical-light counts are written to F10 frame metadata and F7 incident markers. F8 remains the long-form frame time CSV.
- **All regressions green:** full Godot 4.7.2 headless test suite plus Windows x64 export, including new tests for exact physical lamp/source alignment, eight-light cap, renderer resource ownership, chunk unload teardown and deterministic reload. These are **functional tests**, not a measured FPS improvement on RTX 3060.
- **Test location:** return to **Vesper Market 19:34**, near DOCK 9 and LAST SHIFT (the beta.4 screenshot). Freeze the clock using Y; capture Filmic, ACES, and AgX in place using F10/F11. Repeat a cold/warm driving route with F8, and press F7 at hitches or lighting pops. See the included `PLAYTEST-CHECKLIST.md` and [engineering walkthrough](https://github.com/ProhibitedTV/NightGrid-Afterhours/blob/main/docs/RENDERING_SERVER_LIVE_CITY.md).
- **Limits:** existing vehicle silhouettes and most repeated façades remain prototype art. Better scene batching and motivated illumination do **not** make the world AAA photorealistic or certify 1080p/60. The commercial-fidelity streetscape and vehicles remain tracked in issue #51.

## Previously in beta.4 — Godot 4.7.2 stable and actual AgX

This release upgrades the **entire engine/toolchain from Godot 4.3.0 to 4.7.2 stable**—the playable project, clean source import, full headless regression suite, Windows x64 export templates and the package itself. Engine migration landed through [PR #55](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/55).

- **F11 now cycles through three explicitly labelled looks:** original **Filmic** (default) → **sky/ACES** → **sky/AgX** → Filmic. AgX is the real Godot 4.7 tonemapper, not an imitation. The new AgX and existing ACES experiments share sky-ambient fill, exposure, fog and shadow settings, isolating the tonemapping differences.
- **Y** freezes the clock. Take **F10** screenshots/JSON from the same Dock Watch camera at 22:07 in all three profiles. **F8** logs repeated driving runs for actual frame-time comparisons; **F7** places local bug markers. Each event records the exact build revision and rendering profile.
- **Preserved gameplay contract:** original GodotPhysics3D solver (not a silent switch to Jolt), fixed 60Hz physics, the Windows Forward+/Vulkan comparison target, deterministic saved city and existing NightGrid FM/gameplay controls.
- The engine's new native `Logger` class conflicted with one legacy test preload; that alias was fixed. The 4.7.2 preflight validates playable city geometry, physics, saves, new AgX profile reversibility, streaming, menus and interiors; the Windows export has also passed.
- **Still a graphics experiment, not AAA art:** the West Docks screenshot's sparse street life, repetitive city geometry and simplified cars remain. F11 can change colour and shadow perception, but does not import photorealistic assets, guarantee 60 FPS on RTX 3060 or prove the Windows game visually improved.
- Engine migration details: [Godot 4.7.2 migration and hardware verification](https://github.com/ProhibitedTV/NightGrid-Afterhours/blob/main/docs/GODOT_4_7_2_MIGRATION.md).

## Previously in beta.3 — video-inspired render comparison

- **F11** switches between the unchanged launch-default **Filmic** lighting and an *experimental* `sky_aces_experiment`: Godot 4.3-compatible **ACES** tone mapping, sky-sourced ambient shadow illumination, slightly thinner nighttime fog and shorter, softer sun shadows. This is a test preset, not a confirmed visual improvement.
- Source: [Coding Quests — Why 3D Games Look Bad in Godot](https://www.youtube.com/watch?v=0792U-wuwjA) and its [creator companion article](https://codingquests.io/blog/how-to-make-godot-3d-look-better). The tutorial uses **Godot 4.7** and AgX tone mapping, which our **Godot 4.3** release does not support; ACES is the explicitly labelled comparison instead.
- Use **Y** to freeze the game clock; take **F10** frame/metadata at Dock Watch, press **F11** without moving, then take **F10** again. Both PNG metadata and local event logs record the render profile; matched **F8** drives measure real hardware costs. F11 has no effect on saved city geometry or game state.
- Expensive SDFGI, SSIL and volumetric fog remain **off**. The new mode is intentionally opt-in until Windows Vulkan visual review and native 1080p/60 RTX 3060 frame timing. It cannot fix the remaining placeholder vehicle models or repetitive architecture.
- See the included `PLAYTEST-CHECKLIST.md` and [12-technique compatibility breakdown](https://github.com/ProhibitedTV/NightGrid-Afterhours/blob/main/docs/GODOT_VIDEO_REALISM_AB.md).

## Earlier beta.2 improvement (also included)



- **West Docks — Dock Watch Desk:** one fixed permanent civic building at parcel **(-4,-1), lot 0** now uses actual recessed-window wall geometry, transparent glass with room backing, photographed 2K CC0 steel cladding and a sealed scanned-bitumen roof instead of a flat opaque block façade.
- Civic counter access, existing collider, deterministic city seed and saved layout remain intact. **Only one building is upgraded**; neighboring buildings, car geometry and nighttime lighting still need the full visual overhaul tracked in [West Docks realism issue #51](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/51).
- Existing F7/F8/F10 local logging and Windows artifact provenance are unchanged; beta.2 records its own tag and exact source commit.
- This is a new testable visual engineering pilot, **not verified as a convincing photoreal improvement** until the player provides matching Windows/Vulkan frames and 1080p driving traces.
 This is a playable feedback build, not a completed photorealistic/AAA game. The build is based on the exact commit shown in its `BUILD-INFO.txt`, reproduced from the GitHub repository after the **full main-branch Godot 4.7.2 preflight** passed.

## Download and run

1. Download the **NightGrid-Afterhours-v0.1.0-beta.7-windows-x64.zip** asset on the GitHub [Releases](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases) page. **Do not** use the GitHub automatically generated "Source code" archive as the executable build.
2. Optionally check the ZIP against the published `SHA256SUMS.txt` (PowerShell: `Get-FileHash -Algorithm SHA256 .\\NightGrid-Afterhours-v0.1.0-beta.7-windows-x64.zip`).
3. Extract the **entire ZIP** to a folder. Keep the `NightGrid-Afterhours.exe` and `NightGrid-Afterhours.pck` **in the same folder**. Run the EXE.
4. Windows SmartScreen or Chrome may flag an **unsigned, newly published executable**. Publishing on GitHub is not code-signing and does not guarantee the download will be unblocked. Confirm the URL is the real project release and inspect/scan files before making any exception. **Do not disable Chrome Safe Browsing or antivirus globally.** If an antivirus reports malware rather than an unknown publisher, do not bypass it; file an issue with the exact warning.

## Built-in playtest evidence

Each game world launch creates its own timestamped, bounded **local JSONL log** containing the version, release commit, engine/platform metadata, frame hitches >50 ms (details rate limited), streaming/collision fallback events, 15-second summaries, scene transitions, camera jumps, save/load and vehicle events.

- **F7** — Insert a manual incident marker and display the log path. Press just after you notice a glitch.
- **F8** — Start/stop a detailed frame-by-frame CSV; good for repeating a route that stutters.
- **F10** — Capture a *real* HUD-free viewport PNG and accompanying JSON of camera, game, settings and frame timing.
- **F3** — Toggle live performance statistics.

Logs and screenshots are **never automatically uploaded**. Send the local `playtest-logs/*.jsonl`, F8 trace CSV and F10 PNG/JSON with a report. File location is printed at startup and shown with F7; it is under the game's Godot `user://` directory, **not** in the ZIP beside the EXE. Frames measure callback spacing including VSync, **not direct GPU profiling**.

## Test route for first beta

Drive from South Bus Works through Central Exchange and into other districts, once cold and once on a warm return route. Mark F7 if you notice a loading hitch, invisible wall, prop collision or map edge. Park and enter a café/club, exit, then repeat after saving and loading. Inspect car trunk/roof/camera intersections. Use F8 for continuous drive traces and F10 for visual evidence. See the included `PLAYTEST-CHECKLIST.md` for the full route and commands.

## Known limitations (not fixed by naming this a beta)

- Some city blocks, character and vehicle models remain placeholder quality. The approved photorealistic neon-coastal world fidelity goal is **not yet reached**.
- Streaming and world-edge issues still require Windows field validation; passing headless tests does not certify no stutters or visual popping, nor 1080p/60 FPS on an RTX 3060.
- The 20 creator-owned NightGrid FM **Ogg recordings are not yet checked into the game asset directory**. The audio director and other procedural ambience exist, but the full radio soundtrack is absent from this build.
- The game is **unsigned**, uses an existing save schema, and has not undergone a commercial-scale QA/security audit.

## Build provenance

The GitHub release is generated only after a **successful push-to-main preflight** at the exact commit being packaged. The release job exports Godot 4.7.2 Windows x64, checks the EXE/PCK, creates a complete ZIP with diagnostics guide and build info, verifies the archive and publishes its SHA-256. Assets are linked to one immutable Git tag. The included `BUILD-INFO.txt` and the initial `session_start` JSONL record identify the release commit.
