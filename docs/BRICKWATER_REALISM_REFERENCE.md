# Brickwater realism target

The image supplied on November 22, 2026 shows Brickwater at 22:06. It is the visual target for the existing service alley in block `(-2, 1)`. It supplements the [approved city-wide art direction](APPROVED_WORLD_FIDELITY_TARGET.md). The project uses its own architecture, businesses, signs, courier and interface. The supplied image is retained with the local comparison as reference material.

Image SHA-256 `59c366e7979332afc07551295623f625a255991af8206224e0c4a4ab85ea472d`.

The target relies on several things working together. Wall-mounted fixtures give saturated light a physical source. That light follows the damp ground into broken highlights, with dry aggregate visible around standing water. The immediate foreground uses realistic service details and scale. Street activity and closely packed, occupied architecture beyond the alley give the scene depth.

## First native pass

This pass keeps the existing walk-in Night Shift Repairs, Jade Laundry, route, parcel shapes and save positions. It replaces the two small blade faces with original, double-sided modeled glass lettering, backed enamel, steel plates and bolts. The two existing local spill lights now correspond to the larger fixtures. Existing CC0 crates and utility parts form a stacked return area and two wall-mounted feed pipes near the approach. Four added overhead lines terminate at mounted junction boxes above the route. Steam still comes from the existing drain.

The one opaque concrete shader retains its original photographic color, roughness and normal sources, and adds joints, irregular catchments and low-amplitude ripple normals. For the two neon signs, a view-dependent ray reaches their modeled emitter planes and samples masks made from the same tube paths. The wet film uses that source contribution only where water can reflect it and while the sign is lit. The existing screenshot and runtime SSR settings still control scene-wide screen-space reflections.

The implementation adds neither a general reflection pass nor another render camera. The source-only sign approximation does not trace moving occluders. Far-street storefront detail, greater architectural depth above and beyond the alley, and believable activity at its mouth remain the largest visible gaps. [Sign asset source and hashes](../assets/models/nightgrid/brickwater_alley/NEON_SOURCE.json) · [Original authoring script](../tools/author_brickwater_neon.py) · [Existing CC0 source catalog](BRICKWATER_CC0_INTAKE.md).

## Matched Windows scenes

The images are real 1080p viewport captures from Godot 4.7.2 Forward+/Vulkan on the RTX 3060. The Windows replay used the same camera positions, look targets, lens, clock and graphics settings on the original integrated build `0fc7daa` and the art pass `d4ed0ba`. The courier was placed at a fixed point on the actual alley floor.

| Scene | Before | After |
| --- | --- | --- |
| Courier approach at 22:06 | [Native frame](playtest/brickwater-realism/before-courier.jpg) | [Native frame](playtest/brickwater-realism/after-courier.jpg) |
| Dusk at street height | [Native frame](playtest/brickwater-realism/before-dusk.jpg) | [Native frame](playtest/brickwater-realism/after-dusk.jpg) |
| Daylight | [Native frame](playtest/brickwater-realism/before-daylight.jpg) | [Native frame](playtest/brickwater-realism/after-daylight.jpg) |
| Wet pavement and drain | [Native frame](playtest/brickwater-realism/before-surface.jpg) | [Native frame](playtest/brickwater-realism/after-surface.jpg) |
| Driving-height inspection | [Native frame](playtest/brickwater-realism/before-driving-height.jpg) | [Native frame](playtest/brickwater-realism/after-driving-height.jpg) |

Both walking passes on the art revision covered 44.59 m with Living Streets enabled and the game focused. VSync was off. SSR, fog, ambient occlusion and glow were on.

| Art revision | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms | Viewport GPU p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| First walk | 9.25 | 13.96 | 15.46 | 122.20 | 4 | 3 | 5.91 |
| Repeat walk | 10.61 | 13.64 | 14.55 | 16.67 | 0 | 0 | 5.53 |

The fixed night view recorded 8.29 ms wall-clock p99 across 180 samples. The first walk still had transient outliers. The original revision lost focus during both walks, so its raw timings are retained for diagnosis and excluded from the performance comparison. [Capture metadata](playtest/brickwater-realism/native-metadata.json) · [F8 and renderer traces](playtest/brickwater-realism/windows-walking-traces.zip).

To repeat, set `NIGHTGRID_ALLEY_CAPTURE_DIR` to a fresh absolute directory and set `NIGHTGRID_SOURCE_REVISION` to the revision in use.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_brickwater_alley.gd -- --measure --profile --walk --settled --living-streets --reference-view
```
