# First Windows playtest — defect stabilization (2026-11-20)

User-observed defects: inconsistent building placement, a club exit that appears to plunge into an abyss before the scene recovers, primitive rectangular characters, unusual-looking vehicles, third-person camera clipping into buildings, and a city that reads cartoonish rather than stylized photoreal.

**Critical distinction:** functional scene/headless tests were green before this feedback. Those tests do *not* verify real Windows Forward+ materials, camera aesthetics, model silhouette, asset fidelity or real GPU frame timing. The previous AAA-quality language overstated the achieved art quality.

## This stabilization patch

| Report | Source finding | Concrete fix | Still requires human check |
|---|---|---|---|
| Club H exit → apparent abyss | Room located near (950,950), street in ~[-232,232]; third-person camera interpolated between positions instead of snapping, exposing distant empty space | Camera now snaps on H enter, H exit, indoor save restore, respawn, or any abrupt `>35m` displacement; city collision chunks are reloaded before street return | Verify H exit at Static Room, Prism, Blue Hour and all civic interiors on Windows |
| Camera enters buildings | `world.gd` had no physical obstruction ray test | Physics ray from player focus to camera goal, excluding the actor vehicle; smoothly shortening camera arm with 0.38m wall clearance (also applied after smoothing) | Test narrow sidewalks, city corners, train/cars, clubs, large buildings and tight rooms; watch near-wall camera |
| Building facades dislocated | Procedural collision-building front = `block_center + offset_z - depth/2`; fixed shopfront walls = `block_center.z -14.88` | Both rendered and collidable shells align to shared frontage setback `WorldPlan.PUBLIC_FACADE_SETBACK` | This intentionally shifts some buildings a few meters even in old-save worlds; validate old vehicles/player positions, landmarks and alley clearance |
| Characters are rectangles | Player was literally three boxes, and every generic contact was three more boxes | Original rounded human-scale anatomical placeholder with face/eyes/hair, jacket, work boots, four animated limbs, idle and movement; original gameplay collider retained | **Not final AAA human art**. Real UVs, sculpted geometry, hair, skin material maps and animations still needed |
| Cars look weird | Current vehicle generated from original procedural section ring and many box-derived body details | Tracked as [vehicle redesign #20](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/20); **not fixed by this patch** | Film/render front/side/rear at day/night; production-quality model rework |
| City is cartoonish | Box facades, generic colors, stylized generated materials and no approved photoreal reference | Tracked as [visual art reset #19](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/19) and [city layout #21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21); **not fixed by this patch** | Actual Windows renders, reference-guided human art review and GPU profile |

## Test and reporting protocol

`tests/playtest_geometry_smoke.gd` boots the playable real game and checks the static-room entry/exit path, indoor save restore, instantaneous camera positioning, obstruction-physics ray, actual block building collision fronts, and player/generic-host humanoid replacements. All older gameplay/seed/metro/venue/café tests remain required in GitHub Actions.

On the Windows build **after this PR**, run this sequence: (1) at club storefront press H, (2) take two steps then press H at exit, (3) watch for void/black frames and FPS drop, (4) orbit camera tight to large building wall, (5) visit a few shops, (6) inspect the real player/host model, (7) save while inside a club and F9 reload, (8) evaluate KESTREL and daylight geometry separately. Capture screenshots or video of any repeat failures, with clock, map position, Graphics Settings and F3 FPS.

**Shipping caveat:** any improved character in this patch is still a low-cost procedural stand-in, not a licensed or scanned high-detail humanoid. The camera collision ray handles *collidable* surfaces; thin non-colliding decorative meshes may still cross the view. Preexisting city lot manifest keeps height/width/depth/types but uses a new street-alignment rule, so old-world visual geometry positions adjust even though the saved file format is unchanged. Production-grade vehicle/characters/districts remain substantial uncompleted projects.
