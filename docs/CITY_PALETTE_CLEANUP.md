# City palette and prototype ground cleanup

The shared city palette previously scanned every cached material on each day/night notification and initialized newly streamed emissive materials at a fixed brightness unrelated to the current clock. Register only actual emissive StandardMaterial3D resources; initialize them at current brightness, and update only when the effective brightness changes. Same palette keys, resources and dusk curve.

Remove the three raised rectangular grime cuboids from ordinary street-furniture generation, along with the special-case flag for Brickwater. These blocks were not collision or saved parcel objects. Furniture generation is the last randomized work in the per-parcel stage; subsequent neighbor architecture and batch flushing use no city RNG. The seeded buildings and manifest remain intact. Ordinary alleys keep the existing service path and joints; this change does not claim to replace their bespoke surface detail yet. The photo materials now own general wetness; future ground detail should be integrated into those materials.

City smoke verifies late-created light brightness, cache identity, stationary night update suppression, and no old grime palette allocation. Native visual/performance acceptance remains pending.
