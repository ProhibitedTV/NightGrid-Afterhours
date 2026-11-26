# Morrow Bay expansion — Horizon Ridge pilot

Issue #481. The current canonical 8×8 grid (58 m blocks, 464 m across) and layout version 2 remain unchanged. The coast is preserved; expansion starts on the terrestrial east edge rather than filling the harbor.

## First playable land blockout

Opt in with `-- --horizon-ridge` on a disposable new-world playtest. The existing east road at z=0 opens through a 22 m gap in the soundwall, with no road-end chevrons in the opening. A 108×108 m terrace (11,664 square metres excluding the small floor overlap) occupies x=245.5..353.5 and z=-54..54. Two development parcels flank a central access strip and sidewalks. A solid floor bridges the old foundation by 0.5 m. The distant ridge mesh leaves the same four terrain cells clear, and matching physical retaining walls close the three outer edges. No teleport, new persistent parcel IDs, or change to the city grid. The default build retains all original walls and geography.

This is an engineering layout blockout, not an art-quality pass or a finished ninth district. It intentionally has no new buildings, shops, jobs, traffic routes, NPCs, map overlays, terrain decoration, or save destination. All assets are existing shared surfaces, with no additional model downloads. Existing navigation bounds and traffic paths are unchanged; use a fresh disposable test world and return inside the original city before saving. Do not disable the flag while using a save positioned outside the original foundation. Vehicle/pedestrian traversal and save behavior require native validation. The pilot remains opt-in pending the existing native quality gate.

## Proposed expansion direction

- Horizon Ridge: east-side residential hillside, overlook, walking paths, hillside transit stop and mixed-use main street, with a real road loop rather than a repeated square grid.
- Southworks: later freight and light-industrial service extension, truck access and workshops; remove only corresponding background silhouettes after authored ground/road integration.
- North Quay / West Docks: preserve water, expand shoreline promenades and reachable dock infrastructure with individually authored bridges and safety boundaries.
- Link gameplay and production demand to each new site. Prioritize reusable authored architecture, clear navigation anchors, actual services and missions over decorative acreage. Native Forward+ matching frames and traversal benchmarks before enabling any expansion by default.

## CI

The opt-in test uses the actual scene and physics raycasts to verify the opened east road, continuous floor, retained walls and unchanged layout version. Existing coastal perimeter regression remains the default-map gate. No native performance or fidelity claim.
