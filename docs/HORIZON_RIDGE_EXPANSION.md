# Morrow Bay expansion — Horizon Ridge pilot

Issue #481. The current canonical 8×8 grid (58 m blocks, 464 m across) and layout version 2 remain unchanged. The coast is preserved; expansion starts on the terrestrial east edge rather than filling the harbor.

## First playable land blockout

Opt in with `-- --horizon-ridge` on a disposable new-world playtest. The existing east road at z=0 opens through a 22 m gap in the soundwall, with no road-end chevrons in the opening. A 108×108 m terrace (11,664 square metres excluding the small floor overlap) occupies x=245.5..353.5 and z=-54..54. Two development parcels flank a central access strip and sidewalks. The shared render/collision surface overlaps the old foundation by 0.5 m. The distant ridge mesh leaves the same four terrain cells clear, and matching physical retaining walls close the three outer edges. No teleport, new persistent parcel IDs, or change to the city grid. The default build retains all original walls and geography.

This is an engineering layout blockout, not an art-quality pass or a finished ninth district. It intentionally has no new buildings, shops, jobs, traffic routes, NPCs, map overlays, terrain decoration, or save destination. All assets are existing shared surfaces, with no additional model downloads. Existing navigation bounds and traffic paths are unchanged; use a fresh disposable test world and return inside the original city before saving. Do not disable the flag while using a save positioned outside the original foundation. Vehicle/pedestrian traversal and save behavior require native validation. The pilot remains opt-in pending the existing native quality gate.

## Proposed expansion direction

- Horizon Ridge: east-side residential hillside, overlook, walking paths, hillside transit stop and mixed-use main street, with a real road loop rather than a repeated square grid.
- Southworks: later freight and light-industrial service extension, truck access and workshops; remove only corresponding background silhouettes after authored ground/road integration.
- North Quay / West Docks: preserve water, expand shoreline promenades and reachable dock infrastructure with individually authored bridges and safety boundaries.
- Link gameplay and production demand to each new site. Prioritize reusable authored architecture, clear navigation anchors, actual services and missions over decorative acreage. Native Forward+ matching frames and traversal benchmarks before enabling any expansion by default.

## CI

The opt-in test uses the actual scene and physics raycasts to verify the opened east road, continuous floor, retained walls and unchanged layout version. Existing coastal perimeter regression remains the default-map gate. No native performance or fidelity claim.

## Elevation pass

The pilot now climbs 7.2 m over its 108 m length. The authored profile has an almost-level entry, eased approach, maximum 10% longitudinal grade and a level final 20 m landing (after the alignment pass). All five surface strips use the same surveyed station heights, and collision derives directly from each rendered triangle mesh; no invisible flat floor. Stepped retaining wall volumes extend from below the original grade to nearly 2 m above the highest local road point. The existing city and default perimeter remain untouched. Automated rays sample road, sidewalks and development parcels at multiple grades, check the level landing and raised retaining barriers. Native player/vehicle traction, suspension, camera, slopes, save positions and appearance remain unverified. This is a grade/circulation prototype, not a claim of finished architectural realism or real-world road-code compliance.

## Curved access and summit

Follow-up #483. The road alignment bends laterally from 0 to -9 m and back to +4 m along explicit shared station points; no straight grid extension. Road and sidewalks remain continuous, and each development parcel's outer edge stays at z=±54 m. The final 20 m is level, widening from the standard 15.6 m paved width to 30 m near the end, reserving a turning court and pedestrian approach for a future skyline overlook. Centerline dashes are batched original UV geometry following the same grade and alignment, stopping before the court. The maximum longitudinal rise remains 10% and elevation gain 7.2 m. Physics ray tests cover the curved center, both edges and summit; actual vehicle swept paths, road camber, turning behavior, landscape and overlook furnishings remain unvalidated. No new art-quality claim or default enablement.
