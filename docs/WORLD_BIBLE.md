# MORROW BAY — authored world and art direction

**NightGrid: Afterhours** takes place in **Morrow Bay**, a dense, fictional post-industrial city during a power-grid ownership crisis. Our visual language is **graphic-noir neon**: broad readable geometry, charcoal/ink shadows, copper daylight, cyan public infrastructure and magenta nightlife. This is neither GTA nor Night City; familiar crime-sandbox and immersive-world design patterns serve an original setting.

## Immutable city geography

Street blocks are 58 meters. **Districts, street corridors and landmark blocks are authored, stable, and testable.** Procedural generation fills ordinary lots and varies flora/rooftops/window patterns with fixed seeds. Future quest logic can rely on fixed landmark positions across builds.

| Landmark | Block (x,z) | District | Narrative function |
|---|---|---|---|
| Lantern Court | (-2,-2) | Vesper Market | Independent market, illegal-courier contacts |
| Helix Terminal | (0,-2) | Glassline | Privatized transit/power infrastructure |
| Foundry Commons | (-2,0) | Brickwater | Reclaimed community park, union organizers |
| Sable Square | (1,1) | Afterhours | Midnight performances, contacts and rumor network |
| North Quay Exchange | (-1,-4) | North Quay | Public food and produce market |
| Pier Nine Depot | (-4,0) | West Docks | Freight exchange and worker delivery contracts |
| Horizon Commons | (3,0) | Horizon Gardens | Health/community pavilion and open garden |
| Southworks Hall | (0,3) | Southworks | Municipal desks, services and public assistance |

The four anchor blocks replace random building lots. Every other parcel is seeded and procedural. Fixed landmarks are **visual exteriors**, not enterable buildings or implemented quest hubs yet.

## Original storyline direction

You are a late-shift courier carrying physical parcels across increasingly unreliable districts. First arc: small paid routes, then discovering why power outages cluster around certain streets. Middle arc: choosing which factions to help, paying rent and keeping old neighborhood routes alive. Long arc: a citywide infrastructure takeover in which your relationships and your route knowledge matter more than fame. Crime is a *choice with consequences*; the world is about people, neighborhoods and civic systems rather than indiscriminate chaos.

Three faction pillars to expand: **The Relay** (independent couriers and local radio); **Blue Meridian** (the power/transit operator); **Dock Nine Collective** (former industrial workers preserving the commons). All original working names.

## Flora grammar

| District | Character | Planting logic |
|---|---|---|
| Vesper Market | Gold ginkgo / warm herbs | Street tree grates, storefront pots, four-corner market garden |
| Glassline | Blue-green ficus | Regularly spaced street trees, controlled planter boxes at office facades |
| Brickwater | Dark pines / scrub | Hardy street trees, volunteer wildflowers, reclaimed Foundry Commons |
| Afterhours | Pink flowering plum | Pink ornamental canopies, nightclub planters and Sable Square |

Botanicals are stylized low-poly silhouettes rather than asset-store photorealistic meshes. Four tree species, shrub clusters and three flower colors use GPU instancing. Street tree trunks get simple collision; flowers do not. Trees are deliberately planted outside traffic lanes.

## Time and color

24 in-game hours over **24 real minutes** (1 real minute per game hour). Starts at 19:15 so the first launch communicates the ink-and-neon identity. Daylight is copper/sea-glass; sunset is lavender/peach; night is ink-blue with controlled neon. T advances one game hour, Y pauses/resumes the clock for testing.

## RTX 3060 12 GB / Ryzen 7 / 32 GB baseline

**Performance target, not a measured result:** 1920x1080, approximately 60 fps gameplay on the target PC. Use the Forward+ Vulkan renderer for SSR and glow as the current PC baseline, one dynamic shadowed directional light, no volumetric fog/SSGI, instanced flora and decorative geometry, opaque materials, and collision only where it serves gameplay. A later renderer/quality comparison should be profiled on the actual GPU before increasing Forward+ effects.

Proposed budgets to verify with Godot profiler: <= 4 ms CPU city-update overhead, <= 1.5 ms CPU simulation overhead, and stable GPU frame time <= 16.7 ms at 1080p. Those are **targets**, not achieved measurements. Add LOD/visible-block streaming before enlarging city; instance batching alone cannot solve culling of an unbounded world.

## Second-ring city expansion

The [expansion guide](EXPANSION.md) is authoritative for the 8×8-block geography, the four new civic/industrial/ecological districts, sixteen staffed public services, and the explicit generated-lot manifest saved with the world. Original downtown story geography and four faction influences remain the anchor; the new edge districts supply their groceries, hospitals, civic records, repair shops, warehouses and physical power infrastructure.
