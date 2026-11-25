# Brickwater alley — actual framebuffer review
Gallery artifacts are created by the dedicated capture workflow, not concept art. Seven shots use the real playable scene and permanent block (-2,1) at world origin (-87,0,87); matched north views at 22:06 and noon, reverse view, drain/wet pavement, wall art, overhead infrastructure, and driving-height approach. CSV-free JSON metadata records camera/lens, clock, renderer, source commit and PNG hashes. Automated CI uses software OpenGL (no Forward+ SSR), so the required Windows Forward+ visual acceptance remains open. To get comparable 1920x1080 native captures on Windows run from the repo with Godot 4.7.2 and the offline radio resources generated: `godot --path . --rendering-method forward_plus --resolution 1920x1080 --script res://tools/capture_brickwater_alley.gd`. Output is `exports/brickwater_review/`. No screenshot is represented as captured until the renderer produces a verified PNG.

## Native Windows stationary frame timing

From the repository, use the Godot executable with:

```powershell
godot --path . --rendering-method forward_plus --resolution 1920x1080 --script res://tools/capture_brickwater_alley.gd -- --measure
```

This is opt-in; it disables the frame cap and VSync for the standalone capture process, warms up each fixed camera for 60 frames, then samples 180 frame-to-frame intervals without PNG readback or encoding. The manifest contains mean, median, p95, p99 and maximum milliseconds, adapter, renderer, resolution and camera. The 60 FPS reference is 16.67 ms. These are stationary viewport timings, not GPU-only timings or proof of 60 FPS while driving/streaming. Verify the actual graphics settings and collect moving gameplay frame times separately with F8. Keep native output separate from the committed OpenGL gallery. No native results have been collected yet.

CI now verifies all seven published PNG hashes, dimensions, the matched camera pair and the exact gallery links; the gallery publisher's `--check` mode does not modify README.
