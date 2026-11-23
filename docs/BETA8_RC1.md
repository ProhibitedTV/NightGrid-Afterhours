# Beta.8 RC1 Windows review candidate

The review build identifies itself as `0.1.0-beta.8-rc.1` on the development channel. Extract the Windows x64 ZIP, keep the EXE next to its PCK and compare the full source revision in `BUILD-INFO.txt` with the provenance for the build you downloaded. The ZIP also contains the playtest guide and an internal checksum manifest. Beta.7 is the published Windows release. [Windows playtest guide](PLAYTEST_MAIN_ACCEPTANCE.md) · [Published Beta.7](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases/tag/v0.1.0-beta.7).

The exact Windows playtest source is `bd827599672a05b57bf77cd61dcebf7447c6cdfe`. All 76 local Godot regressions, clean import, baked material verification, headless startup and Windows release export passed at that revision. The exported EXE completed the 180-frame native startup on Forward+/Vulkan and reported its embedded source revision. The Windows Actions artifact is a separate export from the same commit with its own checksums. [Draft PR #196](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/196) · [Download exact-source Actions artifact](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45104137489/artifacts/14785794877) · [Windows export and artifact check](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45104137489) · [Exact-source CI preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45104137385).

## Changelog

- Brickwater's authored service alley now has larger mounted neon signs, view-dependent puddle reflections, additional wall and overhead utility details, and grounded service clutter. Open the Night Shift Repairs door, walk to the counter and pay to repair a nearby damaged car. The door and the player's position can be restored inside the shop. [Alley](BRICKWATER_REALISM_REFERENCE.md) · [Repair shop](BRICKWATER_STOREFRONT.md).
- The base integration includes collision-first city streaming, reachable M-Line station platforms and lifts, corrected vehicle camera clearance, and a rigged courier. [Integrated base](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/190).
- Live default traffic reuses shared wheel and collision geometry and cuts redundant headway checks. The asphalt's upward-facing triangles now render with back-face culling. [Traffic work](TRAFFIC_OPTIMIZATION_NATIVE.md) · [Road face correction](PHOTO_ROAD_FACING.md).
- NightGrid FM ships twenty authorized tracks. Each district has its own ambience, with surface footsteps, vehicle and rail audio, venue transitions and clearer police dispatch. [Audio implementation and sources](AUDIO_MIX_QA.md).
- Restore waits for the initial physics synchronization before enabling kinematic motion. In the unfixed build, a transient bus collider displaced a courier after loading a save created by the published Beta.7 binary. The startup regression exercises that position in the real generated city.

### Experimental

- `-- --living-streets` enables the bounded pedestrian pilot with physical civilian rigs and line-of-sight witnesses. Four GLBs now use lossless scene embedding to retain the source's texture maps and avoid a second Basis Universal compression attempt. The original GLBs and texture source hashes are unchanged. [Import defect](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/191) · [Godot 4.7 texture import modes](https://docs.godotengine.org/en/4.7/classes/class_gltfstate.html).
- `-- --pooled-traffic` enables guarded ambient traffic leasing. Default traffic keeps the fixed 25 sedans and four buses. The experimental pool still has routes that retain the fixed fleet. [Traffic profile and constraints](TRAFFIC_OPTIMIZATION_NATIVE.md).

## Integration audit

The GitHub audit was taken on November 22, 2026 after fetching the latest `main`. The open drafts below had no recorded approvals. The exact RC needs its own reviewer approval and full native acceptance. The branch keeps the existing public Beta.7 release workflow on its published tag. [Release issue](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/161) · [Development board](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/162) · [Native tracker](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/129).

| Work | Disposition | Review evidence |
| --- | --- | --- |
| #163 → #164 → #165 → #166 → #187 → #188 | Included once | #163 merged. The current main merge #190 already contains the rest of the stack, with green project preflight, Windows export and artifact launch. Pedestrians remain opt-in. |
| #194, #195, local Brickwater realism pass | Integrated on top of #190 | Both PR heads had green structure, Godot and export checks, with native shop and traffic evidence. The experimental pool remains opt-in. The final matched Brickwater pass is included. |
| #193 | Integrated | Green structure, Godot, Windows export and downloaded-artifact launch. The Windows bundle carries the version and verification guide. |
| #125, #124 | Already in main | Atmosphere update deduplication and the verified CC0 pedestrian intake were retained. |
| #143, #153, #154, #156, #157 | Superseded by #163 | #163 reconciled the geometry and assets. #143 has merge conflicts; #156's framebuffer gate failed; #153 and #157 had no check data at audit. #154 had green preflight/export. |
| #120, #123 | Superseded by #187 | #120 was conflicted despite green head checks. #123 was conflicted with a failed Godot job. The integrated branch uses the later director and asset intake. |
| #118 | Integrated the two focused road commits | Green structure, Godot and Windows export. Existing road geometry, collision and UVs were retained. |
| #115, #122 | Deferred | #115 overlaps #195's shared wheel and traffic changes. #122 bundles its own old gallery with #115 and #118, and had no head checks reported. |
| #126, #128 | Deferred | Water and crane heads passed automated checks. They still lack their requested native scene comparisons and GPU evidence. |
| #155 | Deferred | Radar preflight/export passed. Its 720p, 1080p and ultrawide visual gates failed. |
| #127 | Deferred | Conflicted with main and had no head checks reported. The integrated RC has its own capture provenance. |

## Windows frame pacing

The exported PCK ran at 1920×1080 in Godot 4.7.2 Forward+/Vulkan on an RTX 3060. Each pair uses seed `834726`, fixed 60 Hz physics, VSync off, SSR, AO, glow and fog enabled, and the default fixed traffic fleet. The car follows the same northbound road through Southworks, Afterhours and Glassline, including a full camera turn. The night passes reached 130 km/h. The noon passes reached 53–54 km/h. All six completed 227 m at full vehicle condition with zero unfocused draw samples. Cold is the first route in its process after 60 rendered frames at spawn. Warm repeats the route in that process. The OS and driver caches were left in place.

| F8 scenario | Pass | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Night, 130 km/h, Living Streets | Cold | 24.03 | 118.29 | 141.53 | 145.12 | 189 | 51 |
| Night, 130 km/h, Living Streets | Warm | 22.92 | 33.33 | 34.72 | 38.84 | 251 | 39 |
| Noon, road speed, Living Streets | Cold | 19.68 | 28.79 | 29.92 | 53.39 | 568 | 5 |
| Noon, road speed, Living Streets | Warm | 20.37 | 31.82 | 33.88 | 75.00 | 561 | 24 |
| Night, 130 km/h, default population | Cold | 19.44 | 28.07 | 42.01 | 62.94 | 267 | 5 |
| Night, 130 km/h, default population | Warm | 20.83 | 30.56 | 31.32 | 32.94 | 271 | 0 |

The largest night draw gap with Living Streets enabled was 1050.19 ms. The counters reported 13.01 ms viewport CPU, 6.24 ms viewport GPU and 6.85 ms physics process at that sample. The longest measured chunk stage on the route was 2.68 ms, and draw-pipeline counters stayed flat. The unaccounted time still needs system-level profiling. Warm night p95 was 16.56 ms on viewport CPU and 9.20 ms on viewport GPU. Noon viewport CPU p95 was about 14.3 ms and GPU p95 was 8.5–8.6 ms. In the separate default launch, cold/warm CPU p95 was 16.66/15.90 ms and GPU p95 was 7.82/8.50 ms. These are separate pipeline timings. One pair per configuration cannot isolate the cause of an intermittent stall. The 16.67 ms frame target remains unmet in both configurations. [Raw F8 and viewport traces](playtest/beta8-rc1/windows-performance.zip) · [Performance tracker #32](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/32).

## Packaged Windows gameplay

The native replays load the exported PCK and use temporary profiles. They exercise actual game systems with scripted input and repeatable fixture placement, with the ordinary EXE startup checked separately.

| Scenario | Observed result |
| --- | --- |
| Title, New World, walking, saving and relaunch | The title's New World flow generated seed `1386802008`. A native keyboard-input replay moved the courier and saved with F5. A separate process used Continue and restored seed, manifest, cash and position with 0.00 m error. |
| Published Beta.7 save | Generated a real v1 save from the checksum-verified public package `78442f988a631bc13848c6cd5eea770040d98967`. Beta.8 restored seed `1241220418`, city manifest and courier position with 0.00 m error. |
| Rail, camera and collisions | Walked from the East Gardens lift to the platform, boarded the stopped train, alighted at Helix and returned to street level. The chase camera cleared the canopy. The Kestrel reached 130 km/h beside the railway and stopped at the North Quay structural wall. |
| Brickwater and repair shop | Walked through the animated door, used the counter, paid $24, restored an indoor save, and walked back out. The native keyboard event replay and simulated Xbox-mapped button and stick events passed. |
| Living Streets and witnesses | Day/night Brickwater walk with the pilot enabled, capped active bodies, real clothing textures and line-of-sight reaction tests. The native witness fixture exercised a live civilian and verified exterior streaming stays stable during a business visit. |
| NightGrid FM and sound | All 20 tracks were present. Eight non-silent 48 kHz WASAPI WAV captures cover the title, Brickwater footsteps, café and club doorways, car radio, transit, dispatch and harbor. Subjective headphone mix review is pending. |
| Police and player interactions | The gameplay fixture dismissed the title and exercised a real patrol collider, wall occlusion, wanted heat and the pause and driving input gates. The headless test assumes gameplay has started, so its unadapted native invocation stopped at the title-screen HUD gate. |

[Integrated Windows gameplay gallery](screenshots/beta8-rc1/GALLERY.md) · [Exact framebuffer provenance and PCK hash](screenshots/beta8-rc1/provenance.json).

## Promotion gates

- The high-speed cold run had severe draw stalls and every route exceeded the 16.67 ms budget. Keep performance acceptance open.
- Godot detected no physical controller. Complete hands-on controller review, listening review and a manual playthrough of the Windows checklist before promotion.
- The local headless NightGrid FM test passed but still reported ten leaked ObjectDB instances and four resources in use at shutdown. Native playback and startup checks are separate evidence. [Teardown tracker #192](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/192).
- Obtain reviewer approval on the candidate and visual acceptance of the integrated captures. Beta.7 remains the published download.
