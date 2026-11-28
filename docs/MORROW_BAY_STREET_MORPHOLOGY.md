# Morrow Bay street morphology — Bay Area precedent study

Original conceptual design; no external map artwork or road dataset copied. Research reviewed 2026-11-28.

- San Francisco: [SFO Museum historic maps](https://www.sfomuseum.org/exhibitions/san-francisco-david-rumsey-map-collection/gallery), [TCLF landscape history](https://www.tclf.org/places/view-city-and-regional-guides/san-francisco-bay-area/san-francisco-bay-areas-landscape): Market Street mediated incompatible early surveys; emulate inherited diagonal, wedge parcels, smaller older blocks and larger later parcels. [SF Central Waterfront Plan](https://sfplanning.s3.amazonaws.com/generalplan/Central_Waterfront.htm): industrial land reclamation and large waterfront parcels; emulate quay road and freight yards.
- Oakland: [SPUR historical plans](https://www.spur.org/publications/urbanist-article/2015-02-03/four-plans-shaped-downtown-oaklands-first-100-years): converging corridors and long blocks reflect successive plans; emulate collector hierarchy and selective consolidation.
- Berkeley: [Daley's Scenic Park improvements](https://berkeleyplaques.org/plaque/daleys-park-improvements/): winding roads and stairs replaced parts of earlier rigid grid; emulate hillside streets only after terrain survey.
- San Jose: [NPS downtown historic district](https://www.nps.gov/places/san-jose-s-downtown-historic-district.htm): surveys incorporated older settlement paths; emulate persistent routes and newer commercial centers.

## Existing implementation audit
`world_plan.gd` uses 58 m cells, 64 blocks and two save-stable profiles per ordinary block. `city_details.gd` positions shell and facade independently with common offsets; `photo_road_network.gd` tiles axis-aligned roads. `street_route.gd`, `hud_radar.gd`, `world_audio.gd`, `sidewalk_population.gd`, `sidewalk_certification.gd`, `city_perimeter.gd`, traffic/signal and rail systems depend on grid assumptions. Do not warp the rendering alone.

## Migration order
1. Survey exact current anchors and candidate conflict list, including story, properties, parking, rail, service access, traffic and save recovery.
2. Introduce versioned road/parcel graph interfaces while reproducing existing v2 map byte-for-byte; streaming cells remain spatial buckets, not street graph IDs.
3. Migrate consumers individually and test legacy parity, then pilot one redevelopment block and one new collector intersection. Keep native collision and visual geometry aligned, including sidewalks, crossings and signals.
4. Enable authored v3 map in new games with the clean #200 save schema; reject historical incompatible saves clearly and validate named anchor restore within new schema. Match route reachability, police and vehicle navigation, GPS/minimap, rail, traffic phases, walking, first-use stalls and native RTX3060 performance. No automatic save rewrite.

The offline `street_network_candidates.py` graph is a design study, not a road construction contract. Coordinates and widths are provisional. No terrain grades or actual lane turn arcs are certified. The historic inspiration informs fictional urban growth rather than replicating real city geography.

This is Phase 2 of the [Cascadia master plan](CASCADIA_MASTER_PLAN.md); it does not authorize simultaneous regional city construction.

## Reconciliation with existing authored-city decision (#197–#206)
The creator's explicit Nov 22/23 decision in #200 waives historical pre-alpha v1/beta.7/beta.8 save migration. The new fixed authored layout and clean save schema are authoritative. Legacy v2 geometry is a temporary survey and parity baseline during engineering, NOT a promise to maintain a second runtime layout provider or migrate old saves. Keep existing live build intact until a reviewed replacement; reject incompatible saves gracefully, never overwrite them silently. Protect mission/business/property identity and validate persistence within the new schema. #198 survey, #199 registry, #200 save, #201 streaming, #202 corridor, #203 route/consumer binding, #204 mutable state, #205 acceptance and #206 city expansion are existing work items; #592 extends their design toward irregular streets, not a duplicate implementation backlog. This decision supersedes contradictory preservation language in older planning artifacts.
