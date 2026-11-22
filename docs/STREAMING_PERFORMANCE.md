# City streaming on Windows

This change targets issue #32 and builds on the Brickwater implementation in PR #163. The comparison uses the instrumented reference at `a1c68638b8a1bac4ddec3feb943caa86d68a3d47`. That reference uses the same runtime texture generator and streaming scheduler as `0346ed0`. See the [Windows benchmark report, raw traces and visual parity checks](performance/city-streaming-32/README.md).

## What the trace found

The original Brickwater walk repeatedly encountered a long CPU spike when the stream reached block `(-4, 3)`. In one profiled run, the street-dressing stage used 156.56 ms. Baking the three 128×128 `WOOD` images and their mipmaps accounted for 155.33 ms of that frame. The workload came from the first solid cargo prop in Southworks. The same operation took about 155 ms on the first drive. Imported resource lookups, the graphics upload API calls and physics shell registration are recorded separately from the whole stage.

The immediate-start probe also saw a burst of slow GPU frames during first presentation, with no additional draw-pipeline compilations during that burst. Some long repeat-route wall intervals also had small recorded viewport CPU and GPU times and no expensive chunk span. Those intervals need further engine or system-level attribution. Godot reports totals for pipeline creation by source, texture allocation in bytes and viewport CPU/GPU elapsed time. Some counters arrive after the corresponding draw. The capture also records each texture submission's elapsed CPU time. These signals support correlation with the tagged stages. [Godot pipeline compilation counters](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) · [RenderingServer timing and memory counters](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)

## Implementation

- Bake the eight procedural texture families with the original equations in `tools/bake_city_material_maps.gd`. The packed resource stores lossless RGBA8 image data and its original mip chain. Runtime keeps the existing lazy shared `ImageTexture` cache. Its first use only submits the baked images. The byte-for-byte verification runs in preflight.
- Reuse a single unit-detail mesh across the city's existing material batches. Each batch retains its original transforms, material, spatial extent and lifetime owner. Brickwater's authored geometry and shaders continue through their original paths.
- Preserve the staged construction, predictive focus, occupied-cell collision fallback and explicit restore paths. The extended smoke test writes and restores v1 exterior saves in three districts while speculative streaming work is queued.

The imported scenes used by the pilot are already held by its preloads. The reported traversal spans favored removing generation work and reusing geometry over introducing a second asynchronous loader or general scene pool. The first-view render burst remains a separate measurement from cold chunk arrivals.

## Reproduction

Use an imported Windows checkout and Godot 4.7.2. Set `NIGHTGRID_ALLEY_CAPTURE_DIR` to a new absolute directory and pass the exact revision in `NIGHTGRID_SOURCE_REVISION`.

```powershell
$env:NIGHTGRID_SOURCE_REVISION = git rev-parse HEAD
$env:NIGHTGRID_ALLEY_CAPTURE_DIR = Join-Path (Get-Location) 'dist/streaming-walk'
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_brickwater_alley.gd -- --measure --walk --profile --trace-only
```

The walk uses the PR #163 route and freeze time. Run a second session with `--settled` to render 60 frames at the spawn camera before traversing previously unvisited chunks. For the vehicle sessions replace `--walk` with `--drive-night` or `--drive-noon` and use `--settled`. The lane-clear fixture uses the Kestrel's normal input and physics, starts at Southworks, passes Afterhours and ends in Glassline. It rotates the camera a full turn across a fixed 45 m segment. Ambient traffic processing is disabled for the vehicle fixture to keep the route reproducible.

The harness saves the same game-frame CSV as F8 and separately records wall time between post-draw callbacks. These are different clocks, particularly during long stalls or catch-up physics. `tools/summarize_streaming_profile.py` summarizes either recorded clock and links tagged construction work to draw frame numbers. The capture itself performs no screenshot readback during timing.
