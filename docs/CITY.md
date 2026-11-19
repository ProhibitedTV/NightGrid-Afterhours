# NightGrid city atlas — first detail pass

The city has a **deterministic seed** (`834726`), a 58 m road grid, and four fictional neighborhood identities. These are art directions for the generated world, not a claim that every shop has an interior or that signals control AI traffic.

| Quadrant (x/z) | District | Look |
|---|---|---|
| negative / negative | **Vesper Market** | warm storefronts, small blocks, awnings, noodle vendors, amber signs |
| positive / negative | **Glassline** | glass office towers, blue vertical light fins, skyline antennas and planted sidewalks |
| negative / positive | **Brickwater** | aged brick, service alleys, crates, rooftop tanks and external fire escapes |
| positive / positive | **Afterhours** | clubs and arcades, vivid pink trim, vending machines, public benches |

## World details

- 64 physically collidable procedural building shells plus four authored landmark plazas, 64 frontage signs, individual window grids and recessed-look store faces.
- Structural silhouette variety from district-based building height, parapets, vent/HVAC arrangements and rooftop elements.
- Signal boxes, street lamps, fire hydrants, curbs, road shoulder paint, stop bars, crossings and asphalt patches.
- Neighborhood furniture such as planters, market stalls, dumpsters, trees, bins, crates and benches.
- Ambient back-of-city skyline silhouettes. No third-party assets, textures or fonts required.

## Rendering approach

The player, cars and core roads still use the existing controllers. Only static decoration is added. The city generator in `scripts/city_details.gd` places collidable building envelopes as `StaticBody3D` nodes; decorative details are put in material-based `MultiMeshInstance3D` batches. This is an intentional **prototype** trade-off: whole-city batching has less draw overhead but no chunk streaming or per-block LOD yet. Neon uses emissive materials rather than dozens of expensive real-time point lights.

## Validation

Run `godot --headless --path . --import --quit`, then `godot --headless --path . --script res://tests/city_smoke.gd`. This asserts that city generation runs, all 72 buildings/fronts exist, there is sufficient detail density and district mapping is correct. The Windows export CI also remains active.

## Next city focus

1. District streaming and frustum-aware decoration batches for better performance.
2. Real sidewalks/crosswalk navigation, physical street props and traffic AI that respects signals.
3. Facade textures/material atlases, richer ground-level details, and fully authored landmark blocks.
4. Atmosphere pass: weather, particles, environment audio, lighting transitions and selective reflections.
5. Enterable interiors and persistent world state.

**Boundaries:** storefront doors are currently graphic facades, not enterable; sign text and lights are static, and district names are procedural rather than quest hubs.

## New authored world systems

The [Morrow Bay World Bible](WORLD_BIBLE.md) defines four story-relevant fixed landmarks, an original neighborhood conflict, planting rules, the 24-minute diurnal cycle, art palette, and RTX 3060 performance targets. `scripts/world_plan.gd` owns stable landmark coordinates; `scripts/city_details.gd` generates each reserved block as a recognizable exterior; `scripts/flora.gd` plants four botanical species and small per-district details using instancing.
