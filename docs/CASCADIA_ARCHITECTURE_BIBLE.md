# Cascadia urban and architectural production bible

Planning contract, linked to master plan G1–G5. Anubis produces original candidates; no future-city assets are implied to exist. Place design determines demand, not the reverse.

## City signatures
| Place | Street morphology | Buildings and materials | Economic activity | Environmental signature |
|---|---|---|---|---|
| Morrow Bay | Port grids meet inherited diagonal; dense irregular plots, hills, plazas | Historic brick, rowhouses, concrete, glass towers, weathered stone | Finance, services, nightlife, port commerce | Coastal fog, sea wind, salt staining |
| Ironhaven | Freight arterials, long industrial blocks, sidings, small residential grids | Steel sheds, brick workshops, converted factories, bungalow streets | Logistics, fabrication, independent music, repair | Maritime haze, diesel/rail ambience, weathered industrial surfaces |
| Silica Valley | Older downtown, broad collectors, campuses, separated service yards | Research labs, office parks, cleanroom support, data centers, older storefronts | Chip manufacturing, robotics, corporate research | Drier southern valley, irrigated landscaping, cooling plant ambience |
| Redwood Heights | Terrain-following residential roads and stairs | Timber, stone, retaining walls, hillside houses | Local services, outdoor tourism, estates | Redwoods, wet slopes, shade |
| Ashford | Pedestrian campus routes through established neighborhoods | Academic courtyards, student housing, cafés, bookstores | Education, research, independent culture | Leafy streets, busy pedestrian nodes |
| Saltmere | Peninsula rail corridor and smaller blocks | Commuter stations, duplexes, neighborhood retail | Commuting, local shops, small industry | Marshes, rail ambience |
| Delta Junction | Riverfront freight roads and separated industrial yards | Depots, tanks, utility infrastructure, truck stops | Freight and process industry | River haze and industrial lighting |

Names other than Cascadia and Morrow Bay are provisional. Do not stereotype neighborhoods or copy real logos/addresses. Develop distinct land use and atmosphere through observable details, not caricatures.

## Building kit hierarchy
- **Regional kit:** roads, bridges, ferry terminals, rail structures, retaining walls, vegetation, utility hardware, shared material families.
- **District kit:** era-specific facade bays, windows, cornices, doors, podiums, industrial roof profiles, drainage, street furniture and signage mounts.
- **Building assembly:** parcel footprint, floor heights, vertical structure, real openings, roof drainage/plant, back-of-house access, service routes, planned indoor/outdoor thresholds.
- **Room kit:** purpose, occupancy proxy, wall thickness, door swing, stairs/lifts, furniture clearance, daylight and artificial lights, service fixtures, audio zone. Floor plan precedes props.
- **Hero assets:** hand-directed unique architecture/vehicles/characters only where close gameplay demands it. Generated props are references or candidates, not automatically functional mechanisms.

## Production work orders
Each approved place request should identify parcel_id, building_id, room_id where applicable, geometry revision, design era/use, real metre dimensions, anchor IDs and clearance envelope, source/rights, reusable stock, priority, requested derivatives, acceptance views, performance envelope and reviewer. Stable order ID; immutable source/settings/output hashes. Reuse existing raw and refined outputs if identical. Private high-poly masters on NAS; generate no citywide asset batches without place demand. When geometry changes, invalidate dependent room lighting/collision/proxies explicitly.

## First four Morrow Bay pilot packages (design allocation, not surveyed locations)
1. Brickwater service courtyard: old shop, workshop, service annex; front/rear access, real loading circulation, utilities and varied brick/metal aging.
2. Glassline podium: corporate lobby and office core, tower setback, plaza and service yard; lobby light bake and roof/silhouette study. Do not overwrite Synaxis or existing parking without #460 survey.
3. North Quay market: hall with stall aisles, food service, cold storage, back-of-house deliveries, dock hardware; waterfront environment.
4. Horizon courtyard: unequal residential wings, stair and lift core, entry mail/intercom, shared garden and maintenance access; compare visual openness and occlusion.

Select only one for first runtime activation after G0/G1. Work orders for remaining pilots can be planned and produced offline. Match design to exact lot dimensions before placement. No code compliance claims.

## Vertical slice content tests
A complete place needs a coherent arrival path, visible entrance, accessible purpose, interior circulation, service access, day/night lighting, soundscape and at least one existing gameplay interaction. A drive-through should reveal district identity at street level and distant silhouette. Screenshots must show actual native game frames, not generated concepts. Match baseline weather and viewpoint; check first-use performance and collision. Rejected variants stay private; promote selected optimized derivatives only.

## Regional expansion packages
G3 bridge pilot: modular deck, piers, railing, approach roads, skyline proxy, fog, vehicle and pedestrian safety envelope; route first, art second. G4 Ironhaven: one freight street, one warehouse/service interior, music venue and courier destination; no full city. G5 Silica Valley: one campus/downtown contrast, research building interior and intercity transit stop; no blanket campus generation. Northern rainbelt planning begins only after measured G5. Use shared materials and asset licenses across regions.

## First production work order register
These are proposed briefs for the next authoring pass, not automatic dispatch jobs. Exact live parcel IDs/anchors remain blocked on #198/#199 surveys. Prioritize reuse before asking Anubis for new geometry.

| Work order | Package | First requested derivatives | Acceptance |
|---|---|---|---|
| MB-BW-001 | Brickwater shop/workshop/annex | surveyed footprint, entry and loading geometry, façade kit, UV2, LOD0–2, proxy, collision candidate | clear shop/service paths; preserved Night Shift Repairs identity; matched wet/night frame |
| MB-GL-001 | Glassline podium and office | vertical core, lobby, glazed entry, stair/lift anchors, tower proxy, static light bake candidate | visually legible arrival and vertical circulation; no Synaxis #460 conflicts |
| MB-NQ-001 | North Quay market yard | stall/aisle plan, delivery yard, shore hardware, canopy, day/night candidate lighting | physically plausible freight access separated from public paths |
| MB-HG-001 | Horizon courtyard housing | wing modules, stair core, mail/intercom, garden, retaining geometry, proxy | accessible gameplay entry, residential scale, courtyard openness |
| CS-BR-001 | Cascadia bridge pilot | surveyed alignment, modular deck/approach, barriers, distant city proxy, collision seams | blocked on G3 #594; no automatic generation until surveyed |

Each brief becomes executable only after explicit dimensions, sources/rights, accepted placement transforms, dependency hashes and review requirements are supplied. Gate progression is independent of how many candidate assets are generated.
