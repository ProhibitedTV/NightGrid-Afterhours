# NightGrid: Afterhours — first Windows playtest field guide

**Build:** use the newest successful **Windows playtest build** GitHub Actions run for the merged `main` branch. In that run's **Artifacts** section, download `nightgrid-afterhours-windows-x64`; unzip the archive and keep all extracted files together. Launch `NightGrid-Afterhours.exe` on Windows. It is an unsigned prototype; treat security warnings and antivirus findings with normal caution and confirm that the downloaded source is the project's GitHub Actions page. Godot 4.3 source playtesting (open `project.godot`, press F5) is also supported.

This is an alpha-quality playable prototype, not a commercial AAA release. The original source is in the linked GitHub repository, and the Windows build is produced by its public Actions workflow. The existing README screenshots predate the latest five visual hero passes.

## Five-minute first look

1. Launch the title screen and choose **New World**, then walk around the spawned city using **WASD + mouse**. Open the city map with **M** (gamepad **View**). Check that the player can move and look around smoothly.
2. Stand near a parked car, press **E**, drive with **W/S** and steer with **A/D**. Check KESTREL body/glass, wheel motion, headlamps, brake lights and street-surface reflections. Exit using **E**.
3. Travel to the **Central Exchange** crossroads at world origin. Check its four pedestrian crossings, curb ramps, storm-drain metalwork, road-weathering and real traffic signal phases. The traffic system should behave normally.
4. Find an M-Line stop and board using **F** during a station dwell. Look at CICADA M8 doors, accessible platform, coaches, signs and lights. Use **F** to leave at a stop. The working train should not trap the player.
5. Find **LANTERN CUP** in **Vesper Market**. Walk to its permanent shopfront, **H** to enter. Check the polished brew bar, real host Mara, and **five seated café regulars** on wall-side booths. Standing near Tamsin's booth (left-hand middle seats), press **G** to overhear her authored line. Approach Mara's counter, **G**, then **3** (gamepad **Y**) to talk. Use **1/A** to buy coffee if you need health. Walk to the right-rear booth and press **G** to read Mara's shift notes. Return to the entrance; **H** exits.
6. Open pause using **Esc/Start**, save the game, move or change location, then load. If you saved inside Lantern Cup, it should reconstruct the *same* five regulars, Mara and interior. The discovered shift notes should remain saved. The city should retain the same generated buildings and traffic layout.

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
| F3 | Settings | FPS and streamed-block overlay |

Enable **F3** to see an actual FPS/frametime estimate, and use the pause **Settings** toggles for SSR, bloom, contact shading and fog if the GPU struggles. Hardware target is **1080p/60 on RTX 3060**, *not yet benchmarked*. On a poor-performing system, first test with SSR/ambient occlusion off rather than assuming gameplay bugs.

## What to report for a useful bug

A good report includes: **Windows version**, GPU and driver, monitor resolution, keyboard or controller model, **fresh New World vs loaded save**, reproduction steps, expected vs actual behavior, approximate on-screen FPS (F3), and a screenshot/video if available. For gameplay bugs also include the in-game clock and location (use map), and whether the problem survives Save/Load. You can file it at the repository's **Issues** page.

### Known alpha boundaries

- **Procedural hero artwork** is not yet verified, production-quality photorealistic PBR mesh/sculpt work; inspect colors, silhouette, Z-fighting and clipping at multiple times of day.
- Café regulars are **stationary ambient actors with deterministic idle animation and authored G lines**; they are not navigation-enabled pedestrians, crowd simulators or full quest givers.
- The entire open-world street network is **not** hand-polished to the Central Exchange benchmark; the advanced junction is one fixed landmark.
- Train and car collision/accessibility, indoor pathfinding around all seating and NPC gestures still need hands-on playtests.
- Initial README screenshots are **real older game captures**, not footage of the latest assets; use actual playtest screenshots when reporting findings.
- CI's headless tests cover scene construction, key interactions, restore contracts and a 90-frame run, **not** real controller compatibility, sound fidelity, GPU frametime or Windows rendering.
