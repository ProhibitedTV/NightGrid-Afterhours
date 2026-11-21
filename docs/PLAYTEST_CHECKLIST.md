# NightGrid: Afterhours — first Windows playtest field guide

**Recommended Windows beta:** use the [versioned GitHub prerelease](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases/tag/v0.1.0-beta.3), asset `NightGrid-Afterhours-v0.1.0-beta.3-windows-x64.zip`, after it is published by the successful main-branch test gate. Download the ZIP asset (not automatically generated source code archives), verify against its `SHA256SUMS.txt` if desired, and extract **all contents**, keeping `NightGrid-Afterhours.exe` and `NightGrid-Afterhours.pck` side by side. Launch the EXE. The binary is **unsigned**, so publishing on GitHub alone does not prevent Chrome/SmartScreen warnings. Do not globally disable Safe Browsing or ignore malware detections. The previous [GitHub Actions playtest artifacts](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/workflows/windows-build.yml) remain a development-build fallback. For the **current development source**, use **Godot 4.7.2 stable** (open `project.godot`, press F5). The linked beta.3 executable remains on 4.3 until the next engine-upgrade release.

This is an **early, diagnostics-focused beta**, not a commercial AAA-quality release. The original source is in the linked GitHub repository, and the Windows build is produced by its public Actions workflow. The README screenshots are genuine game captures, but are not proof that the Windows Vulkan renderer meets the approved photorealistic target.

## Five-minute first look

1. Launch the title screen and choose **New World**, then walk around the spawned city using **WASD + mouse**. Open the city map with **M** (gamepad **View**). Check that the player can move and look around smoothly.
2. Stand near a parked car, press **E**, drive with **W/S** and steer with **A/D**. Check KESTREL body/glass, wheel motion, headlamps, brake lights and street-surface reflections. Exit using **E**.
3. Travel to the **Central Exchange** crossroads at world origin. Check its four pedestrian crossings, curb ramps, storm-drain metalwork, road-weathering and real traffic signal phases. The traffic system should behave normally.
4. Find an M-Line stop and board using **F** during a station dwell. Look at CICADA M8 doors, accessible platform, coaches, signs and lights. Use **F** to leave at a stop. The working train should not trap the player.
5. Find **LANTERN CUP** in **Vesper Market**. Walk to its permanent shopfront, **H** to enter. Check the polished brew bar, real host Mara, and **five seated café regulars** on wall-side booths. Standing near Tamsin's booth (left-hand middle seats), press **G** to overhear her authored line. Approach Mara's counter, **G**, then **3** (gamepad **Y**) to talk. Use **1/A** to buy coffee if you need health. Walk to the right-rear booth and press **G** to read Mara's shift notes. Return to the entrance; **H** exits.
6. Open pause using **Esc/Start**, save the game, move or change location, then load. If you saved inside Lantern Cup, it should reconstruct the *same* five regulars, Mara and interior. The discovered shift notes should remain saved. The city should retain the same generated buildings and traffic layout.

## Rendering A/B experiment (beta.3 and newer)

**Tagged beta.3 (Godot 4.3):** F11 toggles Filmic baseline ↔ ACES + sky. **Engine-upgrade development source (Godot 4.7.2):** F11 cycles **Filmic → sky/ACES → sky/AgX → Filmic**. The original Filmic lighting remains the launch default. Press **Y** to freeze the clock, capture **F10** at each look from one unmoving camera and compare the JSON `render_profile` labels. Record separate F8 CSV runs before judging performance. AgX may be more expensive; it is a preview, not the new default. [Detailed comparison](GODOT_VIDEO_REALISM_AB.md).

## Performance and controls

| Keyboard | Standard Xbox-style pad | Action |
|---|---|---|
| WASD / Mouse | Left/Right sticks | Walk and look |
| E | Y | Enter/leave car (outside dialogue) |
| F | RB | Board/leave public transit |
| H | LB | Enter/leave an interior |
| G | X | Interact: venue, customer gossip, Mara's booth clue |
| 1 / 2 / 3 | A / X / Y inside venue dialogue | Purchase / contract / talk to Mara |
| Esc | Start | Main pause menu |
| M | View | Enlarged city map |
| Tab | Journal in pause menu | Quest/notes inventory |
| F5 / F9 | Pause → Save/Load | Save/load |
| T / Y | — | Debug clock advance / pause |
| F3 | Settings | Rolling frame-time p95/p99/1% lows, streamed-block overlay |
| F7 | — | Mark a visible bug right now in the automatic playtest log (no pause) |
| F8 | — | Start/stop frame-by-frame driving trace (CSV in Godot user-data folder) |
| F11 | — | Beta.3: toggle Filmic/ACES; current Godot 4.7.2 source: cycle Filmic, ACES and AgX |
| F10 | — | Save an actual clean gameplay PNG with camera/world/graphics/frame-time JSON |

### Automatic diagnostics for the next Windows playtest

**No setup needed:** a new local `.jsonl` diagnostic file starts automatically whenever the Windows game world launches. The console prints its full path as `NIGHTGRID_PLAYTEST_LOG:`. Logs are kept in Godot's `user://playtest-logs` folder (use the **exact path printed on startup or shown after F7**, since the Windows folder name is chosen by Godot).

- **F7** immediately adds a `manual_marker` and displays the full local log path. Press it when a car clips into a crate, the camera jumps, a building pops, a venue exit glitches, or audio unexpectedly changes. Repeat if necessary.
- The log automatically records **frame intervals above 50 ms** (rate-limited to one detailed event every 1.5 seconds; all slow frames are counted), chunk-collision fallback events, 15-second health/streaming summaries, camera jumps, vehicle/transit and door transitions, respawns, save/load events, and F8/F10 capture actions.
- **F8** remains the optional full frame-by-frame CSV for deeper hitch diagnosis. **F10** still captures the real clean viewport PNG and JSON metadata. For a useful issue, press **F7**, then **F10** if the problem is visual; start **F8** before a repeatable driving route.
- Logs are **local-only** and never automatically uploaded. Each run receives a separate timestamped filename; writes are buffered/flushed periodically, capped at 6,000 events, and flushed on normal exit. A hard crash or power loss can lose the most recent buffered entries. The JSONL is structured game diagnostics, **not** a complete engine-crash dump or a GPU profiler trace.
- When filing an issue, attach the **JSONL**, the related **F8 CSV** (if recorded), and **F10 PNG/JSON**. The F7 marker's timestamp helps correlate the three. Keep a copy of the logs before deleting/reinstalling the game.

Enable **F3** for rolling measured frame intervals and **F8** to capture a repeatable per-frame CSV while driving. A recording holds up to 18,000 frames; stop with F8 to export, then compare Southworks-to-Central Exchange cold/warm drives. Frame intervals include VSync and are not GPU-only timings. Use the pause **Settings** toggles for SSR, bloom, contact shading and fog if the GPU struggles. Hardware target is **1080p/60 on RTX 3060**, *not yet benchmarked*. On a poor-performing system, first test with SSR/ambient occlusion off rather than assuming gameplay bugs.

## Central Exchange building-by-building visual acceptance

For the **Brickwater southwest corner (-1,0 / lot 1)** and the **Afterhours southeast corner (0,0 / lot 0)**, compare the same in-game night and midday views at normal walking and driving camera heights. Examine:

- The south-to-avenue outer corner from both street directions, including the two building bases, corner returns and rear/service-yard joins. **No visible light/sky slits**, no view through walls, no floating awning joints.
- Full-height tinted shop windows, the shadowed room backing, steel mullions and material normal/roughness response. Check for exaggerated alpha sorting, glowing plastic facades, coplanar flashes or obvious texture repetition.
- Roofing from the train approach or an external inspection camera: scanned tar/bitumen membrane, four parapet walls and metal coping; the Afterhours ventilation housing should sit on the roof, not float through it.
- Save in the vicinity, leave the streaming radius and return or reload. The same buildings and shop identities must reappear without model pop-in or newly blocked roads.
- With **F3** enabled, compare 1080p rendered FPS and frame-time behavior at noon and dusk, with and without SSR and ambient occlusion. Physics should stay at fixed 60Hz independently of render frame rate; visual 60 FPS remains **an unverified target**, not a pass/fail claim.

Report which location/time/view exposed any issues. **Do not approve the buildings as AAA solely because headless tests pass**. See [Brickwater](BRICKWATER_CORNER_BUILDING_PASS.md) and [Afterhours](AFTERHOURS_CORNER_BUILDING_PASS.md) acceptance sheets.

## What to report for a useful bug

A good report includes: **Windows version**, GPU and driver, monitor resolution, keyboard or controller model, **fresh New World vs loaded save**, reproduction steps, expected vs actual behavior, approximate on-screen FPS (F3), and a screenshot/video if available. For gameplay bugs also include the in-game clock and location (use map), and whether the problem survives Save/Load. You can file it at the repository's **Issues** page.

### Known alpha boundaries

- **Procedural hero artwork** is not yet verified, production-quality photorealistic PBR mesh/sculpt work; inspect colors, silhouette, Z-fighting and clipping at multiple times of day.
- Café regulars are **stationary ambient actors with deterministic idle animation and authored G lines**; they are not navigation-enabled pedestrians, crowd simulators or full quest givers.
- The entire open-world street network is **not** hand-polished to the Central Exchange benchmark; the advanced junction is one fixed landmark.
- Train and car collision/accessibility, indoor pathfinding around all seating and NPC gestures still need hands-on playtests.
- README screenshots are **real Godot framebuffer captures** automatically refreshed for this visual-development branch, but are made using software OpenGL Compatibility, not Windows Forward+/Vulkan. Use screenshots and frametime logs from the actual Windows build for final rendering evaluation.
- CI's headless tests cover scene construction, key interactions, restore contracts and a 90-frame run, **not** real controller compatibility, sound fidelity, GPU frametime or Windows rendering.
