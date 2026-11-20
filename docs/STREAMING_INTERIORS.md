# Morrow Bay — live block streaming and enterable rooms

This pass adds real on-demand structural geometry loading to the existing 64-block city, plus a room transition at each of the 28 named business locations. The seed, building profiles, transport network, fixed venues, jobs and version-one saves are preserved.

## Loading and unloading city blocks

CityDetails no longer instantiates all 112 building shells during startup. It builds permanent roads/intersections and distant skyline, then loads building colliders, plaza objects, signage and decorative MultiMesh instances for nearby 58-meter blocks. A Chebyshev distance of two blocks gives up to 25 loaded blocks near a center location. Chunks farther than three blocks are removed from the active registry and queued for deletion. The extra unload distance reduces churn when crossing a boundary.

The focus follows the player on foot, in a car, or aboard public transit. A block gets the same exact building profiles from the existing persisted world_manifest and its detail RNG is reseeded from immutable block coordinates plus the saved world seed. Revisiting cannot arbitrarily reroll the facades.

Live metrics can be read from CityDetails.get_streaming_stats(), which reports blocks loaded, blocks in the authored city, shell count, load and unload events, and the radii.

**Limit:** Terrain, base roads, bus/rail infrastructure, signal controllers, planted vegetation and catalogued business frontages are still resident. Individual structural blocks load synchronously when the player crosses a cell boundary, not by threaded disk I/O. The city does not regenerate at runtime; it merely recreates its pre-determined nearby geometry.

## Enterable business interiors

Press **H** while on foot near a named cafe, bar, nightclub, food stall or civic-service frontage. The game creates **one active physical room**, places the player inside, and remembers the source business and precise street position. Room geometry includes collidable floors, outer walls, a three-meter opening, counter, lighting, a host silhouette, and distinctive furnishing archetypes:

- **Markets and food stalls:** stocked shelves, crates, produce displays and checkout counters.
- **Clinics and fire services:** treatment beds and triage/rescue fixtures.
- **Libraries and civic offices:** bookcases, public records and desks.
- **Warehouses, repair shops and utilities:** cargo pallets, machinery, grid equipment and service bays.
- **Cafes, bars and nightclubs:** stools/tables, shelves, espresso equipment or stage elements, with original synthesized ambience.

Inside, walk to the counter and press **G** for the *existing* business menu. Press **1** for useful services or **2** to accept/deliver a local mission. Press **G** to close, then return to the entry door and press **H** to go outside. The streetfront G interaction remains available without entering.

This is a **separate furnished interior instance**, not a seamless door cut through an exterior building mesh. A room is released when the player leaves; another business can load its own. Distinct business kinds have different furniture, but the locations do not all have 28 individually authored floorplans or NPC navigation yet.

## Save/load and quest continuity

The standard F5 snapshot stores optional interior metadata (business ID, VENUE or CIVIC catalog, and the outside return coordinate). Physical player position records where the player was walking inside the room. F9 recreates the correct room and restores the inventory, active jobs and world layout. Loading older saves with no interior field returns outdoors as before. Invalid indoor records fail snapshot validation.

The minimap uses the real street address while the player is indoors, not the internal room staging coordinates. Police pursuit and street courier proximity triggers are suppressed during an indoor visit.

## Performance and validation

Streaming reduces how many outer-district building colliders and material batches stay live. It is not yet a complete all-system stream, async generator, low-poly distance LOD, or proof of 1080p/60 FPS on an RTX 3060. Room loads and chunk construction can still produce a short main-thread hitch. Future work should add timed construction budgets, street-actor streaming and dedicated profiling on the user's Ryzen 7/RTX 3060.

The CI script tests/streaming_interiors_smoke.gd travels across the map with the real player and checks both unloading and deterministic recreation of a landmark chunk. It then enters a grocery, checks real counter proximity, buys food packs, saves and reloads while indoors, verifies the return point and currency, rejects malformed records, and enters an existing nightclub room. Existing city, transport, renderer and nightlife smoke tests remain active.
