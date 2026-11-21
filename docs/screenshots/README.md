# Authentic game captures

The seven gallery PNGs are unedited Godot viewport outputs, not concept art or mockups. The [capture manifest](capture-manifest.json) identifies the exact rendered source revision, renderer and hashes. Older captures used Godot 4.3; the updated workflow pins Godot 4.7.2. The manifest is authoritative for the images actually committed.

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

[Capture workflow](../../.github/workflows/capture-screenshots.yml) · [Capture script](../../tools/capture_screenshots.gd). The workflow deletes previous PNGs before rendering, requires a successful capture marker, verifies the new files and commits the new manifest with the images on the designated branch. Native Windows screenshots (F10) and frame measurements (F8) remain a separate playtest goal.
