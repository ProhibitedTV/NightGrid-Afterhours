# Morrow Bay physical coherence

This pass follows the native Windows reports in issues [#29](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/29), [#133](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/133), [#136](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/136) and [#138–#142](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues?q=is%3Aissue+138+139+140+141+142). It builds on Brickwater art in PR #163 and the streaming work in PR #164.

| Generated fixture | Change |
| --- | --- |
| M-Line east–west corridor, Z −58 | Eight curbside piers, continuous steel stringers and transfer girders carry the guideway outside the traffic lanes. The closest pier footing is 10.13 m from the road centerline. The bottom of the transfer structure is above 10 m. |
| East Gardens, X 232 | The street approach has a 1:12 grade, with a level landing at the station door. Use the existing Transit action to call the lift, walk the guarded bridge to the platform and use Transit at the marked door of a stopped train. At the next stop, platform passengers alight by a train door and can call a lift down. |
| Grid intersections | Two grounded masts per standard intersection carry four approach-facing heads. The original phase rules and Central Exchange assembly keep their existing behavior. |
| Horizon Commons, X 203 / Z 40 | The canopy has its own matching collision shape. The chase camera sweeps a 30 cm radius from the vehicle focus to the proposed camera position and contracts at roof edges. |
| North Quay Exchange, X −29 / Z −203 | Eight counters and the roof are solid. Four delivery cartons can be dislodged by sufficient contact speed. A carton spawns at most one short-lived physics body, owned by the landmark chunk, and can transfer momentum without applying structural vehicle damage. Vehicles lose the into-surface component of their movement on hard contact and play a severity-scaled impact cue. |
| Pier Storage / Night Services, block (−4, −1) | The existing photo-material walls and roof face outward, the brick closes to grade and the upper fascia, and both shutter bays have fitted jambs and headers. Building footprint, shell collision and address are preserved. |
| General alleys and South Bus Works | Ordinary dumpsters now register their two matched visible shapes during the shell stage. The authored Brickwater pilot keeps its existing dumpster. The existing South Bus Works check covers ten solid props, including their streaming lifetime. |

Station IDs, train timetable, lot generation and save version remain stable. Legacy street boarding remains available at the four other stations. An older train save without platform information uses the legacy street exit. A v1 save made while the lift is in motion resumes at the destination landing.

## Assets

The market cartons use the existing [Poly Haven cardboard box source](../assets/models/polyhaven/cardboard_box_01/SOURCE.json) and its pinned CC0 mesh and material maps. Pier Storage reuses the existing [Poly Haven scanned shutter](WEST_DOCKS_CC0_GLTF_ART.md) and [photographic wall and roofing maps](../assets/pbr/polyhaven/SOURCE.json). The rail and traffic mounting geometry and vehicle impact cues are original project code. The patch uses the existing city material library and adds no downloaded assets.

## Validation

Run the real generated-location smoke with `godot --headless --path . --script res://tests/physical_coherence_smoke.gd`. It also runs in Windows Forward+ with its normal gameplay camera, player and vehicle controllers. Set `NIGHTGRID_PHYSICAL_PLAYTEST_DIR` to a new absolute directory to save those gameplay frames.

For matched Windows captures, use Godot 4.7.2 with the same graphics profile, seed and screen size on both revisions. Set `NIGHTGRID_PHYSICAL_CAPTURE_DIR` to a new absolute directory and set `NIGHTGRID_SOURCE_REVISION` to the revision being captured. On the baseline, copy only the capture script into the source checkout.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_physical_coherence.gd
```

The F8 trace uses the existing [Brickwater streaming route](STREAMING_PERFORMANCE.md) with `--measure --profile --drive-night --trace-only --settled`. The recording starts after 60 rendered frames and repeats the same route.

## Remaining scope

- Lift transfers use the Transit action and a visible timed cabin. Full walk-in lift interiors and animated landing doors remain follow-up work.
- Destruction is scoped to the four delivery cartons. They reset on chunk rebuild or reload. Permanently installed fixtures, structural buildings and railway supports stay static.
- Ambient traffic was disabled for the repeatable playback. Manual controller feel, an unrestricted traffic playtest and every possible older save position inside newly solid props remain unverified.
