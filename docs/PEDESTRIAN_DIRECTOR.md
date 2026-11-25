# Living Streets

Run the Windows playtest with `NightGrid-Afterhours.exe -- --living-streets`. The same switch works with the Godot project. The pilot is opt-in under #160, so an ordinary launch keeps the current public beta behavior.

## Simulation

- The city seed generates up to 128 stable identities across eight districts. A district's hourly profile determines which identities can appear. A nearby actor keeps its route when the clock advances.
- The director reuses up to 12 collidable actors, three of each of four authored costumes. It prefers nearby paths, admits at most two pool changes every 0.20 seconds, and spreads whole-path collision checks over multiple physics ticks. An expanded, settled camera frustum and a live clearance query govern activation. The body is disabled before its parcel lease is released.
- Physical routes stay on existing sidewalk strips. Selected endpoints pause at signal-controlled approaches. The two Central Exchange storefront links continue through the existing doors into their walk-in vestibules. Calm actors can rest, look into a storefront or face and wave to another calm actor within four meters and in clear sight.
- Active actors use the same blocking physics as the street and vehicles. A blocked actor yields and can reverse along its certified route. Approaching vehicles and nearby, unobstructed incidents trigger a look-and-stop reaction. The camera still sweeps against structures.
- Only active, rigged, nearby actors in the live camera frustum can provide a civilian eye position, facing and body RID. The existing bounded wanted ray checks line of sight to the event, including walls and other solid objects. Abstract population and occluded actors provide no new heat.
- Saves retain the existing v1 schema. A new optional phase snapshot restores the seeded population before activation. Old slots use their existing seed and default starting phases. Indoor and transit modes suppress exterior activation and recycling.

The dedicated branch integrates the selected #120 director and pool changes with the already-merged #116, #117 and #119 dependencies, and includes the #123 adapter. #124's intake tooling is already merged in main. The exact verified source binaries from its CI artifact were converted for playback and checked into this branch. The branch is stacked on #166 so the Windows checks include the updated courier, Brickwater and physical world. [Asset provenance and rebuild](../assets/models/nightgrid/pedestrians/SOURCE.md).

## Scope

The pilot certifies local straight paths. It waits on the sidewalk at crossings and uses the two actual walk-in retail vestibules. Continuous cross-street journeys, long-distance destination routing and full business-interior schedules need additional authored links. A severely displaced actor stays protected instead of teleporting back onto its route. Reactions are local pauses, looks and route reversals. Congested pavement can produce backtracking while the path clears.

The four meshes have distinct silhouettes and texture atlases. Godot supplies mesh LODs, and the animator updates distant and offscreen actors at lower rates while maintaining elapsed time. The player uses its existing independent courier rig. [Adapter contract](PEDESTRIAN_RIG_VISUAL.md).

## Native Windows pilot

The six pairs use Godot 4.7.2, Windows Forward+ and Vulkan on an RTX 3060 12 GB, Ryzen 7 2700X and 32 GB RAM. Both sides ran runtime `22aab3e` at 1920×1080 with seed 834726, SSR, ambient occlusion, glow and fog enabled, and VSync off. The feature switch was the only game-mode change. Each screenshot uses the same camera and lens in its pair, with clock fixed at noon or 22:00. Each F8 pass used the same walking input for 290 physics ticks and ended at the same world position on both sides, 19.50 to 19.51 meters from its start.

The capture chooses a street-eye view of an already active resident. It leaves the pool, leases and motion running in the real world and replays the same camera for the feature-off image. A camera-to-body physics ray reached one resident in each enabled view. The Brickwater night subject is farther down the street. The live peak column counts nearby leases across the walk, including adjacent districts.

| District and hour | Off | On | Peak live |
| --- | --- | --- | ---: |
| Brickwater noon | [Screenshot](playtest/living-streets-160/brickwater-day-off.png) | [Screenshot](playtest/living-streets-160/brickwater-day-on.png) | 5 |
| Brickwater 22:00 | [Screenshot](playtest/living-streets-160/brickwater-night-off.png) | [Screenshot](playtest/living-streets-160/brickwater-night-on.png) | 4 |
| Afterhours noon | [Screenshot](playtest/living-streets-160/afterhours-day-off.png) | [Screenshot](playtest/living-streets-160/afterhours-day-on.png) | 7 |
| Afterhours 22:00 | [Screenshot](playtest/living-streets-160/afterhours-night-off.png) | [Screenshot](playtest/living-streets-160/afterhours-night-on.png) | 5 |
| West Docks noon | [Screenshot](playtest/living-streets-160/west-docks-day-off.png) | [Screenshot](playtest/living-streets-160/west-docks-day-on.png) | 3 |
| West Docks 22:00 | [Screenshot](playtest/living-streets-160/west-docks-night-off.png) | [Screenshot](playtest/living-streets-160/west-docks-night-on.png) | 2 |

### F8 frame times

The numbers below are milliseconds and show off → on. These are frame intervals from the game recorder. No timed run recorded streamed geometry construction.

| District and hour | Median | p95 | p99 | Maximum | Frames >16.67 ms | Frames >33.3 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Brickwater noon | 9.72 → 11.67 | 11.11 → 14.23 | 11.61 → 16.43 | 13.99 → 18.22 | 0 → 2 | 0 → 0 |
| Brickwater 22:00 | 19.70 → 21.21 | 21.21 → 25.00 | 23.39 → 28.31 | 27.61 → 30.02 | 241 → 224 | 0 → 0 |
| Afterhours noon | 10.39 → 12.50 | 14.84 → 15.48 | 23.79 → 17.45 | 101.47 → 18.24 | 9 → 6 | 4 → 0 |
| Afterhours 22:00 | 10.42 → 12.25 | 11.52 → 14.75 | 13.46 → 16.11 | 15.86 → 20.80 | 0 → 1 | 0 → 0 |
| West Docks noon | 4.17 → 4.76 | 4.55 → 49.72 | 5.00 → 133.33 | 8.48 → 144.77 | 0 → 42 | 0 → 34 |
| West Docks 22:00 | 12.96 → 14.29 | 15.07 → 15.76 | 16.55 → 16.82 | 16.83 → 20.34 | 2 → 4 | 0 → 0 |

Brickwater at night fell outside the 16.67 ms budget on both builds. The enabled West Docks noon pass had a hitch burst with zero streamed block loads. The disabled Afterhours noon pass also had separate outliers. This measurement set does not establish citywide 60 FPS or isolate the source of the two hitch bursts. [F8 summary](playtest/living-streets-160/f8-statistics.json) · [Raw CSVs and manifests](playtest/living-streets-160/f8-traces.zip).

The isolated West Docks noon repeat reversed the run order and kept the same world, camera, clock and walk. With three civilians active, median was 4.17 → 4.76 ms, p95 was 4.76 → 5.56 ms, p99 was 5.37 → 7.41 ms and maximum was 8.71 → 12.61 ms. Neither repeat exceeded 16.67 ms or lost window focus. Renderer CPU p99 was 2.043 → 2.045 ms, and renderer GPU p99 was 3.215 → 3.216 ms. The initial burst did not recur, and its source remains unattributed. [Repeat F8 summary](playtest/living-streets-160/west-docks-repeat.json) · [Repeat renderer and F8 traces](playtest/living-streets-160/west-docks-repeat.zip).

Exact runtime `22aab3e` passed all 72 local Godot regressions, project preflight, baked-material byte verification and Windows release export. The exported executable completed 180 frames with the opt-in switch on the RTX 3060's Forward+ / Vulkan renderer. The regression exercised both real storefront entrances, physical witness occlusion, indoor suppression, v1 save restore, and parcel cleanup. Performance and art acceptance remain open under #100. [Hosted preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45072103953) · [Hosted Windows export](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45072104022).

To reproduce, set `NIGHTGRID_SOURCE_REVISION` to the tested runtime and `NIGHTGRID_LIVING_STREETS_DIR` to a new absolute output directory. Run the command below, then set `NIGHTGRID_LIVING_STREETS_REFERENCE` to the enabled capture's manifest, set a fresh output directory and repeat with the feature switch omitted. Optional `NIGHTGRID_LIVING_STREETS_DISTRICT` and `NIGHTGRID_LIVING_STREETS_HOUR` values select a single case. The additional `--diagnostic` argument records wall intervals, renderer CPU and GPU timings and window focus alongside the F8 data.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_living_streets.gd -- --living-streets
```

## Daily activity and local awareness pass (#282)
Live pooled residents now carry their seeded role and sample the current clock: office and service workers favor commute windows and midday breaks, shift workers commute around shifts, patrons linger at night, and shoppers make errands. These are local activity intents expressed through different dwell lengths at existing safe sidewalk endpoints; storefront and signal holds retain precedence. No new routes to specific homes, jobs, seating or transit destinations are claimed. Existing safe leasing, active cap (12), logical cap (128), save phases and default opt-in switch remain intact.

Visible incidents interrupt holds/socializing; pedestrians look toward the event, and urgent actual shot events can trigger a short faster retreat along the certified link, stopping at its boundary. The perception ray uses existing solid geometry, bounded radius (24m maximum) and per-agent cooldown. No additional heat, wall penetration, omniscient reporting or extra actors. Regression coverage checks role windows, wall obstruction, alert/retreat and recovery. Native Godot/Windows test and performance verification pending. Audio follow-up per AGENTS.md: plan stable authored cues for conversation, startled reactions and retreat (e.g. pedestrian.social, pedestrian.alert, pedestrian.retreat), through the Anubis catalogs with distance/cooldown, licensed original cast and caption fallback; no new voice clips or triggers in this slice. Reuse existing footsteps and incident sounds. No runtime inference.

## Street satire / ambient personality pilot
Six fictional archetypes (robot romantic, nothing-happens cynic, gig grinder, subscription skeptic, street visionary and nightlife regular), each with three original lines. Stable seeded logical pedestrian IDs choose their personality, not costume or a real-world identity. Nearby calm live pedestrians within 8m and line of sight may deliver a remark; initial 12-second quiet period, 24-second global minimum between accepted remarks and 75-second per-lease cooldown. On foot only, no interruptions of existing speech, no world AI inference, no added NPCs. Scope cancellation prevents speech from a recycled actor or an alerted speaker. Cooldowns/variant counters are transient per lease; this does not yet add persistent conversation history, player dialogue choices, new meshes or gestures. Captions work before recordings exist; approved spatial audio is prewarmed by the existing director. 

The 18 canonical street lines extend the existing Anubis manifest to 45 dialogue cues plus 37 SFX. Python coverage validates the runtime text and stable IDs. For example: `python tools/voice/anubis.py bake --character robot_romantic` or `python tools/voice/anubis.py bake --character nothing_happens`. Both use original voice designs and the existing approval gate. No recordings have been generated or published in this pass; native listening and performance proof still pending.
