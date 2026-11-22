# Brickwater service alley

The pilot is the existing block `(-2, 1)`, with origin `(-87, 0, 87)` and two saved parcels. The adjacent block `(-1, 1)` uses the same residential kit without the pilot’s businesses, clutter or steam. Review the pilot from the street and both walking approaches before extending it further.

## Integration decisions

| Source | Used here |
| --- | --- |
| [#143](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/143) | Solid alley floor, photo-metal dumpster and shared scanned props. The old decorative strip, ghost dumpster and three raised square ground patches are suppressed in the pilot. Their random draws are preserved. |
| [#153](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/153) | Nine identical source-pinned Poly Haven packages, manifests and verification tools. |
| [#154](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/154) | Five original wall pieces. Mounted against the new masonry, with positions adjusted around the workroom. |
| [#156](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/156) | Openings in the render envelope, dark backing behind the kit, original parcel-sized collision and fitted steel escape collision. The separate gold-slice scene, duplicate fixtures and alternate sign set are omitted. |
| [#157](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/157) | Primary layer for apartment bays, occupied glazing, condensers, connected conduit, closed service doors, corrugated shelters, blade signs, wet concrete and local drain vapor. One instance of each service assembly per intended site. |

The imported frames sit inside matching wall reveals. Their original UVs and material maps are retained. Ground-floor brick returns close the saved envelope. The repair-shop display window has a one-metre cavity with a metal stock shelf, two reused crates and a warm task light. The existing parcel collider still closes both service entrances. The separately tracked [continuous storefront entry](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/135) retains its own acceptance criteria.

The pilot builds its walkable collision first, then spreads the lot envelope, props, upper architecture and lighting across existing streaming stages. It reuses the original lot dimensions, lane and road coordinates, storefront identity selection, world seed and save schema. Blade sign emission follows the actual printed colors and fades with the city clock. The wet concrete shader varies roughness and normal response within one surface. The nine-particle drain plume and five local lights are scoped to the pilot. Existing graphics settings control SSR, AO, glow and fog.

## Sources

The publisher, CC0 terms, exact upstream URLs, sizes and hashes are recorded in `assets/models/polyhaven/*/SOURCE.json` for the apartment kit, fire escape, electrical cables, pipes, caged sconce, bag, cardboard box, crate and hand truck. The retained meshes and original textures are byte-identical to those pinned in #153. The project already includes the Poly Haven air conditioner, rusted can and cabinet, plus `brick_wall_001`, `blue_metal_plate` and the Central Exchange `concrete_floor_01` maps. The intake process and shared-material catalogs are described in [the CC0 intake](BRICKWATER_CC0_INTAKE.md) and [asset pipeline](URBAN_ASSET_PIPELINE.md). The glTF scenes import via Godot’s normal scene path. The authored sign, notice, weathering and paint SVGs under `assets/models/nightgrid/brickwater_*` are original project art inherited from #143, #154 and #157.

## Reproduce native evidence

Use Godot 4.7.2 on Windows and start from an imported project. For the before pass, copy the same capture script to the beta.7 checkout at `78442f988a631bc13848c6cd5eea770040d98967`. Set the revision and a fresh absolute output directory in each checkout.

```powershell
$env:NIGHTGRID_SOURCE_REVISION = (git rev-parse HEAD)
$env:NIGHTGRID_ALLEY_CAPTURE_DIR = Join-Path (Get-Location) 'dist/brickwater-review'
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_brickwater_alley.gd -- --measure --walk
```

The harness writes unmodified framebuffer PNGs with world-space cameras, clock, lens, graphics flags, adapter and SHA-256. `--measure` disables VSync after the menu initializes, then samples one stationary view. `--walk` follows the in-game forward input with physics and city streaming active and saves the same CSV format as F8. Use `--ssr-off` with a separate output directory to inspect the fallback. Driving-height screenshots use a fixed camera. They do not measure moving vehicle performance.
