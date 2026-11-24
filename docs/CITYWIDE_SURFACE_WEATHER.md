# Citywide surface weather rollout

Goal: extend the reference-led Brickwater wetness work to all Morrow Bay streets, not replicate a hero alley in each district. The existing weather clock now drives two citywide asphalt material batches (including Central Exchange), and cached photographic sidewalk/curb materials at its existing quantized cadence. Road crown wets less than the gutters; concrete remains rougher than asphalt. Newly streamed or cached concrete inherits the current film; clearing the weather restores the dry baselines. No geometry, collisions, texture copies, new scene nodes, or reflection cameras.

Visual acceptance: F2 clear/rain/storm/clear at Central Exchange, Vesper Market, Southworks, West Docks and Glassline; F10 identical camera poses and F8 repeated routes. Material clearcoat is kept enabled at zero strength to avoid switching shader variants during rainfall. Native GPU overhead and actual appearance are unverified.

Next rollout: replace static puddle patches with bounded weather-aware ground treatments; share district masonry/metal/photo art standards; pool motivated practicals and local atmosphere by district; test district coverage and frame pacing, not just a hero shot.

The superseded Central Exchange-only roadway pilot is retired. The shared road union covers the same center and approaches, below the junction markings; the existing junction regression now asserts exact coverage without duplication and stable save/restore. Historical documentation and the tagged RC2 remain intact.
