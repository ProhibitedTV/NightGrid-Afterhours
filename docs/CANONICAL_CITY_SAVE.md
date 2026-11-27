# Canonical Morrow Bay — New Game and saves

Every New Game starts the same city. The permanent outer-lot and core facade assignments are explicit in `scripts/world_plan.gd`, frozen from the historical default layout to preserve its existing building dimensions and sightlines. City dressing and flora use fixed deterministic placement rules and do not accept session overrides. No new city seed is generated or shown to the player.

Save version 2 stores `layout_id: morrow-bay`, the layout revision and mutable gameplay state. No saved `seed` or per-save `world_manifest` is accepted. Old v1 development slots are incompatible; Continue is disabled and New Game leaves old bytes intact until the first new save. No migration or automatic deletion. The fixed diagnostic compatibility getter and legacy placement signatures remain for old capture/test scripts; random-number generators used for fixed scenery and gameplay are not a player-selectable layout input.

The current atlas still builds streamed reusable meshes; full site-by-site hand authoring remains ongoing. Test two new games, fixed parcel profile assignments, rejected old saves, atomic v2 save/restore, streaming and native Windows startup before calling the migration complete.
