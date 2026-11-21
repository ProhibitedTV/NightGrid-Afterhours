# Authentic game captures

The nine gallery PNGs are unedited Godot viewport outputs, not concept art or mockups. The [capture manifest](capture-manifest.json) identifies the exact rendered source revision, renderer and hashes. Older captures used Godot 4.3; the updated workflow pins Godot 4.7.2. The manifest is authoritative for the images actually committed.

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

## November 21 integrated art refresh
[Successful actual capture run 44955189798](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44955189798) rendered source `40487cc` with photo asphalt, concrete sidewalks, Vesper window assemblies and photographic brick. All seven PNGs were committed and their byte lengths match the manifest. The Vesper scene now shows photographic masonry and framed windows; the visible original bus is not the later coachwork pilot in #112. The latter needs its own render review. The screenshot commit and this record change documentation/feedback only, not rendered game source.

## Vehicle-focused gallery refresh
The two new close views use the actual four-bus/25-car fleet rather than a separate art scene. The capture script temporarily stages two real vehicles on their normal outer loop, freezes traffic for the shots, and uses a street-level camera. The entire gallery is re-rendered with the new art. Until the capture bot commits all nine verified PNGs and the manifest, the nine-image preflight intentionally fails. No native RTX performance claim.

## Verified nine-image capture
[Capture run 44956626055](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44956626055) succeeded, rendering `1caa6bc3635538c4f101033724217c975aef892a`. All nine committed PNG byte lengths match the manifest. Visual inspection confirms the new bus and sedan bodies in the real Vesper streetscape. Remaining art limitations include angular silhouettes, simplified wheel faces, opaque windows, repeating street/facade detail, and daylight haze. This is a prototype art improvement, not photorealistic or native Windows performance acceptance. Final preflight rechecks every image hash before merging.

## Post-beta.7 road and wheel comparison candidate
This branch combines the already tested wheel candidate (#115) and front-face asphalt correction (#118). The public nine-frame baseline is pinned at [`8b4a502`](https://github.com/ProhibitedTV/NightGrid-Afterhours/tree/8b4a502d87591675d20d44d9b6bfb4961084af73/docs/screenshots). Capture the identical cameras, clock and real staged vehicles to compare road visibility and rim detail. The current manifest, not this note, identifies which runtime revision actually rendered the images. This branch must not merge before beta.7 is published, fresh captures are verified, and full integrated checks pass. No native RTX performance claim.

## Verified road/wheel visual comparison
[Capture 44958563012](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44958563012) completed successfully at `8d6a366ca0b1f223f0032a50ccf36d3d61125325`; every committed PNG byte length matches its manifest. The matched bus and sedan views were inspected: the formerly visible square foundation pattern is gone from the road and six-spoke rims are visible on both actor types. Surface repetition, simplified coachwork and lighting still need art work. Reconciled with beta.7 main, preserving all pedestrian foundation changes and the released version identity. Gallery source predates those passive foundations. Native Windows performance still unmeasured.
