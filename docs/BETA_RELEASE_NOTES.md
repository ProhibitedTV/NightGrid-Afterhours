# NightGrid: Afterhours — Windows beta 0.1.0-beta.1

**Status: early, diagnostics-focused beta (Windows x64).** This is a playable feedback build, not a completed photorealistic/AAA game. The build is based on the exact commit shown in its `BUILD-INFO.txt`, reproduced from the GitHub repository after the **full main-branch Godot 4.3 preflight** passed.

## Download and run

1. Download the **NightGrid-Afterhours-v0.1.0-beta.1-windows-x64.zip** asset on the GitHub [Releases](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases) page. **Do not** use the GitHub automatically generated "Source code" archive as the executable build.
2. Optionally check the ZIP against the published `SHA256SUMS.txt` (PowerShell: `Get-FileHash -Algorithm SHA256 .\\NightGrid-Afterhours-v0.1.0-beta.1-windows-x64.zip`).
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

The GitHub release is generated only after a **successful push-to-main preflight** at the exact commit being packaged. The release job exports Godot 4.3 Windows x64, checks the EXE/PCK, creates a complete ZIP with diagnostics guide and build info, verifies the archive and publishes its SHA-256. Assets are linked to one immutable Git tag. The included `BUILD-INFO.txt` and the initial `session_start` JSONL record identify the release commit.
