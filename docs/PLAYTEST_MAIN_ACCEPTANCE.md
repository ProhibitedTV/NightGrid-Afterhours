# NightGrid: Afterhours — verified main-branch Windows playtest

**Audience:** player/developer reviewing the *integrated* Morrow Bay game, not the older public beta.7.  
**Target:** Windows x64, Godot 4.7.2, 1920×1080 Forward+/Vulkan, RTX 3060 12 GB (60 FPS is a target, **not a proven outcome**).  
**Current feature-integration baseline:** merge commit `50dd617e2ac8f5b9a2f8a6acb9fa644b8956a648` ([PR #190](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/190)). Every subsequent build must be identified from **its own** `BUILD-INFO.txt`, not assumed to be this SHA.

## 1. Get the correct build

Open the [Windows playtest workflow](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/workflows/windows-build.yml). Choose a **successful run on branch `main`**. Under *Artifacts*, download `nightgrid-afterhours-windows-x64` (GitHub may require login). Alternatively, the [first green post-merge build](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45082966816/artifacts/14778197336) is a known reference, retained until December 22, 2026.

Extract **everything** into one folder; `NightGrid-Afterhours.exe` and `NightGrid-Afterhours.pck` must remain together. The Windows bundle also contains this guide, `BUILD-INFO.txt`, `SHA256SUMS.txt`, and the asset/music attribution. An older bundle may omit this guide but still has the executable, PCK, build info and checksum manifest.

**Identify the build** by the full 40-character source commit, development channel and Godot version in `BUILD-INFO.txt`. Compare the source commit to the Actions run or the review candidate's provenance. The versioned Beta.8 RC1 bundle also carries this information and its changelog. [Beta.8 RC1 review notes](BETA8_RC1.md).

**Verify payload integrity** (PowerShell opened inside the extracted folder):

```powershell
Get-Content .\BUILD-INFO.txt
Get-Content .\SHA256SUMS.txt | ForEach-Object {
    if ($_ -notmatch '^([0-9a-f]{64})  (.+)$') { throw "Invalid checksum line: $_" }
    $expected = $Matches[1]
    $file = $Matches[2]
    if (!(Test-Path -LiteralPath $file)) { throw "Missing: $file" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "SHA256 mismatch: $file" }
}
"All listed file checksums match"
```

This checks **files inside** the extracted bundle. GitHub Actions has independently tested the complete artifact and a 90-frame Windows headless startup. The game remains unsigned; do **not** disable security software or bypass a malware verdict in order to test it.

## 2. Start clean, then opt into crowds

1. Copy/backup your existing Godot **user data and saves** before touching an older profile. Start a **New World** for the baseline test. Never use an irreplaceable save as the first test case.
2. Double-click `NightGrid-Afterhours.exe`, then choose New World. Use the mouse/keyboard first. Default street-crowd pilot is **off**.
3. In a separate run, test the opt-in pedestrian pilot from PowerShell in this folder:

```powershell
.\NightGrid-Afterhours.exe -- --living-streets
```

The `--` separator passes `--living-streets` to the game. Compare the same seed, route and clock with crowds off and on. The Beta.8 candidate changes how the four original civilian GLBs embed their texture maps. Check clothing and normal-map detail in both lighting conditions. [Import tracker #191](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/191).

## 3. First 15–25 minutes: acceptance route

Use the in-game map (**M**) for district names and **Y** to freeze the clock when comparing daylight/night. Capture exactly what you see; do not substitute concept art for F10 screenshots.

| Stage | How to test | What qualifies as success |
| --- | --- | --- |
| Start and controls | Title → New World, WASD+mouse, Shift/Space; pause with Esc, map M, journal Tab. Try physical Xbox/XInput pad if available. | Starts without crash; normal camera-facing movement, correct menu input/pause. |
| Car and collision | E enter Kestrel, drive through Southworks near the bus works/crates, park and exit E. Inspect front, side and trunk. | No going through crates, posts or train supports; rear shell opaque; clean entry/exit. |
| City streaming | F8 to start trace; drive Southworks → Central Exchange → Vesper Market → West Docks, stop F8; repeat warm route with equivalent graphics. | Continuous drivable geometry; no void/teleport, bounded stutter. Record F3 p95/p99, don't assert 60 FPS without trace. |
| Brickwater art | At Central Exchange reach Brickwater service alley; freeze at night and at noon, F10 from eye height and vehicle height. | Correctly joined façades, original surfaces/props, realistic mounting; no floating/transparent structures. |
| Public transit | Board M-Line or bus with **F** when stopped; ride then leave with **F**. | Reachable platform/dwell, coherent car/rail collisions, no stuck player. |
| NightGrid FM and sound | Car **B** powers FM; **N** skips tracks. Listen with headphones across exterior → Lantern Cup (**H**) → exterior and by police dispatch. | Audible creator-owned music, no silence, proper crossfades/venue attenuation; footsteps/engine/rail/dispatch audible. |
| Save/restore | **F5** save; change position/location; restart game, **F9** load (or use menu). Repeat an old save only after backup. | Same city, mission, player position, song preference and building state. |
| Street population pilot | Restart with `-- --living-streets`; walk Brickwater and Vesper Market; compare F8 and F10 to pilot-off. | NPCs exist only when enabled, no trapped/phantom colliders, bounded frame cost. |

**Do not perform destructive in-game tests on the only copy of an old save.** You can test controller, police heat, destructible objects, or 130 km/h streaming in a fresh world.

## Cinder R9 acceptance (RC2)

- Locate a parked Cinder R9, enter with E / Y, and use V / D-pad Left to switch from chase to cockpit. Use mouse / right stick to look, then toggle back. Check the windshield, dashboard readability, door openings and that the view never intersects the rider or world geometry.
- Drive, brake, reverse and turn at low/high speed. Inspect rolling wheels, steering rim, fixed brake calipers, body weight transfer and small wheel suspension travel. Stop against a solid obstruction and confirm the wheels stop advancing with actual travel.
- Cycle weather with F2 and freeze the clock with Y. Compare clear and rain at daylight/night, including wet-road spray, contact shadows, brake/reverse lights, dashboard and courtesy light. Stop and park: spray and cabin lights must settle and switch off.
- Save in the Cinder; exit, restore, and verify the same car and body damage. The camera should restore to chase and transient effects should reset.
- F8 two matched cold/warm routes at 1080p, and F10 for cockpit images. The target remains 60 FPS; report actual median, p95, p99 and hitches, not a momentary counter.

## 4. Collect objective evidence

- **F3**: frame intervals/rolling p95, p99, streamed blocks and FPS.
- **F7**: place an exact-time incident marker. Game displays the local path of the `user://playtest-logs` **JSONL** file. Never assume the OS user-folder name.
- **F8**: start/stop frame-interval CSV for *cold* and *warm* copies of the **same** driving route. Data include VSync and CPU frame pacing, **not direct GPU-frame timing**.
- **F10**: save the real Godot frame **PNG + JSON** (camera, seed, time, location, graphics and rolling frame intervals) in `user://playtest-evidence`.
- **F11**: compare Filmic/ACES/AgX without moving the camera. Leave SSR, resolution, clock and graphics otherwise fixed.
- When finished, exit normally to flush diagnostics. Keep any engine crash text/log as well as the playtest JSONL. Logs and captures are local-only.

For FPS evaluation use **actual native Windows gameplay at 1080p**, not headless CI. A 60 FPS frame budget is about 16.7 ms; judge sustained frame intervals, tail hitches and perceptible smoothness, not an isolated FPS counter. Note GPU model/driver, Windows version, resolution, fullscreen state, controller, renderer, VSync and rendering preset.

## 5. Report and accept

File a [playtest bug](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/new?template=playtest-bug.md) or update [native acceptance tracker #129](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/129). Keep untested items **unchecked**. For a useful report, paste this short scorecard:

```text
Build source SHA / channel:
Windows / GPU / driver / display resolution:
Graphics profile / VSync / controller:
New world or restored save? Seed:
Start/menu/control: PASS / FAIL / NOT TESTED
Car collisions and rear shell: PASS / FAIL / NOT TESTED
Brickwater day+night visual: PASS / FAIL / NOT TESTED
Rail/bus boarding and transit: PASS / FAIL / NOT TESTED
Cold vs warm streaming: PASS / FAIL / NOT TESTED
NightGrid FM and spatial audio: PASS / FAIL / NOT TESTED
Save, quit, reload: PASS / FAIL / NOT TESTED
Living Streets off/on: PASS / FAIL / NOT TESTED
F8 median / p95 / p99 frame_ms, hitch count:
F7 incident marker time / expected vs observed:
Files: JSONL, F8 CSV, F10 PNG + JSON, crash log (if any)
```

Before sharing, remove any private username/path or personal information from the evidence. **Native image quality, audio listening, pad support, old-save compatibility, and RTX 3060 60 FPS remain unverified until someone plays this specific build.** The published [beta.7](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases/tag/v0.1.0-beta.7) stays an independent rollback; this development artifact is **not** an official new release.

## Executive Privilege acceptance (RC7)

Start a New World after backing up saves. Follow the [RC7 chapter acceptance route](BETA8_RC7.md): arrival, folder and IT audit, departmental lift exploration, executive briefing, HR, physical equipment return and exit. Verify $75 once, revoked access on revisit and QuotaDrop pickup. Test the parking guard and appliances with both input modes. Record native FPS/trace data; automated smoke tests do not establish visual quality or full-route frame pacing.

### Office evidence capture (stabilization follow-up)
F7 markers and F8 frame traces are enabled during the prologue. F10 records a clean viewport outside arrival/lift transitions; office objective UI is hidden for the captured frame. JSON includes exact build revision and chapter floor/stage. The frame sampler measures callback intervals in the office as well as outside. This follow-up is intended for review without moving the current RC7 release tip until its queued validation completes.
