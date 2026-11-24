# Beta.8 RC3 — citywide materials and traversal playtest

Unsigned Windows development-channel prerelease; not final Beta.8. RC2 remains immutable as a comparison build.

## Changes since RC2
- Shared photographic road, sidewalk, curb and masonry weather response (#250, #252, #256).
- Batched wet-road puddles and consolidated practical light refresh (#254, #257).
- Removed redundant emissive material writes and raised prototype grime blocks (#258).
- Bounded obsolete sector teardown independently of construction during traversal (#259).
- Retains the RC2 Cinder cockpit, articulated steering, suspension and audio.

## Acceptance
Publish only the exact current main commit after successful Project preflight and Windows playtest build, including delivered EXE/PCK checksum and startup smoke. No tag or release overwrite. Do not claim native driving performance, visual approval, controller/audio/save acceptance or 60 FPS until measured. Follow [the Windows acceptance route](PLAYTEST_MAIN_ACCEPTANCE.md), especially high-speed repeated district crossings, wet weather, memory growth, and frame-time spikes. The [RC2 cockpit provenance gate](BETA8_RC2.md) remains outstanding for final Beta.8. The separately stacked Kestrel authored parts are not included unless independently integrated and verified.
