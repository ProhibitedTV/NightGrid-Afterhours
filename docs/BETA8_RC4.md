# Beta.8 RC4 — circular radar playtest

Unsigned Windows development prerelease; RC3 is retained unchanged for comparison.

## Changes since RC3
- Circular lower-left player-centered radar with live player/car heading, offscreen destination bearings, local road and transit details, venues, services, police markers, closure-aware waypoint routing and separate interactive atlas (#264).
- Dialogue hides radar, then restores it; debug overlay is repositioned. Radar redraws at 10 Hz without an extra 3D viewport.
- Additional Brickwater wall-art regression checks (#265) and offline original automotive authoring/validation tooling (#263). The Vesper prototype is not a drivable shipped car.
- Retains all RC3 streaming, photographic surfaces, Cinder cockpit and Kestrel rear work.

## Verification
The radar integration passed full preflight, exported Windows startup, and actual Godot software-renderer framebuffer capture at 1280x720, 1920x1080 and a 1920x810 window (1440x810 letterboxed content). See [radar capture run](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45469930018). The integrated main before the RC4 version bump passed [preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45471386241) and [Windows build](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45471386240).

Publication requires successful preflight and Windows packaged startup on the exact current main revision, plus verified artifact hashes. No tag overwrite. Native Vulkan visual approval, controller/audio/save acceptance and 60 FPS are not certified. Use [the native acceptance route](PLAYTEST_MAIN_ACCEPTANCE.md); additionally test radar on foot/in car, road detours, mission bearings, dialogue visibility, map navigation and HUD overlap. The final Beta.8 cockpit evidence gate remains outstanding.
