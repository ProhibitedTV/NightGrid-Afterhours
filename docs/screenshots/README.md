# Authentic game captures

The gallery PNGs are unedited Godot viewport outputs, not concept art or mockups. The [capture manifest](capture-manifest.json) identifies the exact rendered source revision, renderer and hashes. Older captures used Godot 4.3; the updated workflow pins Godot 4.7.2. The manifest is authoritative for the images actually committed.

The capture script stages actual locations in the playable world, opens the real menus and enters Quay Fresh through the normal game method. It uses a virtual X11 display and Mesa software OpenGL Compatibility, not the Windows Forward+/Vulkan renderer. The gallery is not an RTX performance benchmark.

| File | Scene |
|---|---|
| 01-morrow-bay-neon-night.png | Central Exchange |
| 02-vesper-market-nightlife.png | Moon Noodles |
| 03-m-line-helix-terminal.png | M-Line |
| 04-horizon-commons-daylight.png | Horizon Commons |
| 05-quay-fresh-interior.png | Quay Fresh interior |
| 06-title-menu.png | Title |
| 07-city-map-menu.png | Live city map |
| 08-city-bus-coachwork.png | Actual outer-route bus, staged at Moon Noodles in daylight |
| 09-civilian-sedan-coachwork.png | Actual outer-route sedan, staged at Moon Noodles at night |

[Capture workflow](../../.github/workflows/capture-screenshots.yml) · [Capture script](../../tools/capture_screenshots.gd). The workflow deletes previous PNGs before rendering, requires a successful capture marker, verifies the new files and commits the new manifest with the images on the designated branch. Native Windows screenshots (F10) and frame measurements (F8) remain a separate playtest goal.

## Expanded player-facing capture set

The expanded gallery uses 33 frames from the running game: all eight districts, ten additional fixed storefronts, six additional enterable rooms, two ordinary gameplay-camera views and the original nine scenes. The capture workflow must publish all PNGs and the exact source manifest before the gallery can pass preflight. Staged camera positions and time-of-day are intentional; they do not represent live player movement or FPS measurements. [Browse the full gallery](GALLERY.md).

## November 21 integrated art refresh
[Successful actual capture run 44955189798](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44955189798) rendered source `40487cc` with photo asphalt, concrete sidewalks, Vesper window assemblies and photographic brick. All seven PNGs were committed and their byte lengths match the manifest. The Vesper scene now shows photographic masonry and framed windows; the visible original bus is not the later coachwork pilot in #112. The latter needs its own render review. The screenshot commit and this record change documentation/feedback only, not rendered game source.

## Vehicle-focused gallery refresh
The two new close views use the actual four-bus/25-car fleet rather than a separate art scene. The capture script temporarily stages two real vehicles on their normal outer loop, freezes traffic for the shots, and uses a street-level camera. The entire gallery is re-rendered with the new art. Until the capture bot commits all nine verified PNGs and the manifest, the nine-image preflight intentionally fails. No native RTX performance claim.

## Verified nine-image capture
[Capture run 44956626055](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44956626055) succeeded, rendering `1caa6bc3635538c4f101033724217c975aef892a`. All nine committed PNG byte lengths match the manifest. Visual inspection confirms the new bus and sedan bodies in the real Vesper streetscape. Remaining art limitations include angular silhouettes, simplified wheel faces, opaque windows, repeating street/facade detail, and daylight haze. This is a prototype art improvement, not photorealistic or native Windows performance acceptance. Final preflight rechecks every image hash before merging.

## Visual acceptance before publication

After the fresh capture commit, run `python3 tools/check_screenshots.py`, then install Pillow in a local virtual environment and run `python3 tools/review_screenshot_gallery.py`. It validates every source image against the manifest and produces review-only contact sheets with a per-frame checklist in `exports/gallery-review/`. The sheets are not player gallery images and must not replace the original viewport PNGs. Open the full-size originals before approving each frame; check that the named place is visible, camera is not inside geometry, HUD is readable where promised, and each shot offers a useful distinct view. Flag any weak composition for recapture. Never publish this checklist as if all frames have already passed visual inspection.
