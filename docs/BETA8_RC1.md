# Beta.8 RC1 Windows review candidate

The review build identifies itself as `0.1.0-beta.8-rc.1` on the development channel. Extract the Windows x64 ZIP, keep the EXE next to its PCK and compare the full source revision in `BUILD-INFO.txt` with the provenance for the build you downloaded. The ZIP also contains the playtest guide and an internal checksum manifest. Beta.7 is the published Windows release. [Windows playtest guide](PLAYTEST_MAIN_ACCEPTANCE.md) · [Published Beta.7](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases/tag/v0.1.0-beta.7).

## Changelog

- Brickwater's authored service alley now has larger mounted neon signs, view-dependent puddle reflections, additional wall and overhead utility details, and grounded service clutter. Open the Night Shift Repairs door, walk to the counter and pay to repair a nearby damaged car. The door and the player's position can be restored inside the shop. [Alley](BRICKWATER_REALISM_REFERENCE.md) · [Repair shop](BRICKWATER_STOREFRONT.md).
- The base integration includes collision-first city streaming, reachable M-Line station platforms and lifts, corrected vehicle camera clearance, and a rigged courier. [Integrated base](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/190).
- Live default traffic reuses shared wheel and collision geometry and cuts redundant headway checks. The asphalt's upward-facing triangles now render with back-face culling. [Traffic work](TRAFFIC_OPTIMIZATION_NATIVE.md) · [Road face correction](PHOTO_ROAD_FACING.md).
- NightGrid FM ships twenty authorized tracks. Each district has its own ambience, with surface footsteps, vehicle and rail audio, venue transitions and clearer police dispatch. [Audio implementation and sources](AUDIO_MIX_QA.md).

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
