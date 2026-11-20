# NightGrid: Afterhours — authentic captures

These seven PNG files are **unaltered framebuffer captures from the actual running Godot 4.3 game**. They are not AI-generated concept art, stock renders, image mockups or promotional composites. They were produced on November 20, 2026 by the repository's `tools/capture_screenshots.gd` script and `.github/workflows/capture-screenshots.yml` on an Ubuntu GitHub Actions runner.

**Capture environment:** 1280×720, Godot 4.3, Xvfb virtual X11 display, Mesa software OpenGL 3/Compatibility renderer. The shipped Windows version targets Godot Forward+/Vulkan and RTX 3060; exact lighting, reflections, bloom and framerate on that Windows renderer may differ. These frames are genuine scenes, but not a measured RTX 3060 gameplay benchmark.

| File | Actual scene |
|---|---|
| `01-morrow-bay-neon-night.png` | Central Exchange road-visible PBR architecture after the new capture run; old PNG remains the previous corridor frame until replaced |
| `02-vesper-market-nightlife.png` | Moon Noodles streetfront with gameplay HUD, live city map and cars |
| `03-m-line-helix-terminal.png` | Actual raised M-Line rail infrastructure at Helix Terminal |
| `04-horizon-commons-daylight.png` | Planted Horizon Gardens community plaza under the day/night system |
| `05-quay-fresh-interior.png` | Real entered, physically collidable Quay Fresh grocery room |
| `06-title-menu.png` | Actual keyboard/controller-capable title screen |
| `07-city-map-menu.png` | Actual enlarged city map, business pins and transit markers |

### How the capture works

The workflow installs the same Godot 4.3 project runtime used in the game's tests, runs the normal game scene in a real software-rendered X11 viewport (never the headless dummy renderer), and reads the active viewport's framebuffer with `root.get_texture().get_image()`. It changes game-world hour, camera position and player position to expose actual landmarks and enters Quay Fresh through the game's real interior transition. It opens the title/map using the actual live menu controls. Files are saved directly with Godot's `Image.save_png`.

The script validates dimensions, minimum distinct sampled colors and file size; the workflow verifies PNG signatures and 1280×720 dimensions and uploads the captures as a CI artifact. On designated feature-branch pushes, it commits regenerated PNGs plus a `capture-manifest.json` identifying the captured source revision and SHA-256 hash of each unmodified framebuffer. This is a provenance record, not Vulkan validation. `tools/check_screenshots.py` also validates the files and README references in ordinary preflight CI.

For future capture from a physical RTX 3060, run the game normally at 1080p with the Forward+ renderer, record gameplay screenshots using Steam or a graphics capture tool, then replace selected gallery files with that version and clearly label the new capture source. Do not describe these virtual Linux software-renderer frames as Windows RTX benchmarks.
