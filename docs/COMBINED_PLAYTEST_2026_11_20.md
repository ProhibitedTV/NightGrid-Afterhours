# Combined Morrow Bay Windows playtest — 2026-11-20

This **temporary integration branch** gathers four independently developed
draft PRs into one Godot Windows build without merging any of them to `main`.

| Source | Included |
| --- | --- |
| #37 | Original NightGrid FM music director, car radio, venue playlists, ambient districts, footsteps, audio controls |
| #38 | Predictive block requests, one newly built chunk per frame, emergency occupied-cell collision fallback, F3 build-time instrumentation |
| #39 | North/West working harbor, eastern ridgeline, southern freight yard and four physical visible city limits |
| #40 | KESTREL S6 rear hatch manifold, opaque trunk bulkhead and quarter closures |

**Known asset blocker:** the 20 Ogg files from the creator's NightGrid FM
game audio ZIP are still missing from the GitHub repository. The integration
build will have working UI, original ambience and sound effects, but NightGrid
FM *music playback* cannot be audible until those 20 files are placed at
`assets/audio/nightgrid_fm/*.ogg`. Don't mistake a successful Windows
build for a sound-equipped music release; see issue #36.

## Developer acceptance playtest

1. Download the **Windows playtest build** artifact from Actions for this
   exact branch, if the workflow passed. Do not assume earlier `main`
   builds contain these changes.
2. Drive across several district boundaries, then teleport/load a saved
   game. Use **F3** to observe pending chunks and build time. Track p95/p99
   rendered frame times in the Godot profiler, not just average FPS.
3. Drive to every compass map limit from Southworks and downtown. Check
   physical collision, bay water to north and west, grounded landscapes east
   and south, no falls, no endless asphalt or sudden clipping. Evaluate high
   transit camera perspective at midday and at 21:30.
4. Circle the parked KESTREL S6 at rear-left/rear-top/low-rear and through
   both rear and side windows. Confirm the hatch and luggage area appear
   solid, both for civilian and police models; watch for PBR/backface
   artifacts and glass sorting.
5. Walk on concrete, into a café/club, enter/exit car and transit, open/close
   game menu; check the ambient mix, district change and independent
   saved audio controls.
6. For NightGrid FM song tests, first explicitly commit the authorized game
   Ogg files. Then check title, vehicle B/N radio (and D-pad equivalents),
   club and café fade behavior and spatial venue attenuation.
7. Reload an old save and inspect deterministic lot placement, car condition
   and transit state. Confirm no collision or city-streaming regression.

All four source pull requests remain draft until their real Windows gameplay
acceptance work is complete. This aggregation is intended to speed that
combined QA, *not* to replace individual review or assert the visual work is
already AAA quality.
