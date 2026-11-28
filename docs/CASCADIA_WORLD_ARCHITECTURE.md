# Cascadia world architecture — implementation contracts

Status: proposed engineering design for #592 and #593, not runtime implementation. Preserve Godot 4.7.2 Forward+ and current gameplay; #200 explicitly waives historical save migration.

## Existing baseline
`world_plan.gd` layout version 2: 58 m spatial cells, 64 blocks, 56 ordinary blocks with two persisted profiles each. `game_session.gd` save format version 1 and 16 MiB limit; older saves synthesize a manifest from seed. `street_route.gd` uses axis-aligned grid projections; `road_restrictions.gd` identifies bidirectional edges via integer grid indices and four-neighbor traversal. `navigation_waypoint.gd` bounds points using grid radius. Existing transit: 81 signalized junctions, four bus vehicles/16 stops, one elevated train/five stations. These are legacy compatibility fixtures, not requirements for future cities.

## Four independent coordinate systems
1. **Region atlas:** abstract positions/connectivity used for design and regional map; never directly used for spawning.
2. **City local world:** metre coordinates, Y up, stable origin and declared bounds per city; Morrow Bay v2 retains exact origin.
3. **Spatial buckets:** 58 m existing city chunks initially, independent of roads/ownership. Choose future bucket sizes from profiling, not from street width.
4. **Persistent identity:** city, street, junction, lane, parcel, entrance, room, property, business, station and mission anchor IDs. No persisted NodePath, resource handle, instance ID or index into an editable array.

Use immutable IDs and explicit transforms; separate map revision from save schema. No large-world coordinates engine build until measurements show precision need; region/local coordinates permit either contiguous transforms or isolated local scenes later. Do not implement an origin shift solely for a speculative map size.

## Road graph migration contract
Proposed graph schema: city_id, layout_version, junctions (ID, position, control type), streets (ID, endpoints, centerline polyline, width profile, grade, surface class), directed lanes (ID, street, direction, allowed modes, centerline, connectors), intersections (connector conflict groups and stop lines), sidewalks/crossings, transit paths. All lengths in metres; explicit direction/handedness; lane connectors separate from junction point. Validate finite coordinates, unique IDs, registered crossings, geometry continuity, positive widths, graph connectivity per allowed mode, legal turns and grade bounds. No road centerline is itself a certified drivable lane.
- First implement v2 adapter reproducing original route geometry, snap semantics, lengths, tie-breaking, closures, turn guidance and edge IDs; compare fixtures and randomized deterministic samples. Keep original code as oracle until parity proven.
- Consumer migration: navigation and minimap/radar → restrictions/detours → police route/drive and dispatch → road mesh/material/footstep classification → traffic signals/vehicle routing → sidewalks, spawn/parking, bus/rail and perimeter. Roll out one consumer at a time; retain v2 implementation only during incremental development until the authored replacement is validated.
- Route recalculation keyed by graph revision, closure revision and meaningful origin/target movement. Cache graph adjacency; no whole-region route search each frame. Route across cities uses coarse itinerary followed by local graph, with mode transfer validation.
- Before v3: exact survey of doors, property entrances, parking, story cameras/triggers, delivery sites, stations, collision boundaries and saved spawn points. Produce conflict report: anchor ID, current location, proposed location, reason, impacted systems, mitigation, evidence. No automatic nearest-road relocation of story anchors.
- First physical pilot: a low-risk non-story parcel and one T junction/diagonal connection, explicit street and sidewalk meshes from same graph; native drives and walks, lane-turn swept volumes, signal phases, police detours, GPS, audio, and matched before/after screenshots.

## New authored-world save contract (#200)
Proposed new schema: layout_id, city_id, local_position, orientation, named_safe_anchor, content_revision, simulation seed and per-city compact progression/ownership deltas. Historical v1/beta saves explicitly need not migrate. Preserve files on disk; incompatible saves receive a clear message and new-game path. Unknown layout/ID, NaN, missing anchor, corrupt state or content mismatch fail closed; no silent fallback to arbitrary origin. Atomic write and round-trip readback for new schema; validate physical spawn clearance before restore. One fixed layout for all new games; no persisted static building profiles or seeded static geography. Retain existing save-at-authorized-property policy and size limit pending measured new-schema sizes.

## Regional travel state machine
`LOCAL_ACTIVE → PREFETCH_CORRIDOR → CORRIDOR_ACTIVE → PREFETCH_DESTINATION → VALIDATE_READY → DESTINATION_ACTIVE → RELEASE_SOURCE`. This is a proposed state machine, not a claim of existing seamless travel.
- Stable route ID, city pair, supported transport mode and named entry/exit anchors. Start with one bridge route to sparse Ironhaven block, not the whole city.
- Maintain source simulation until safe corridor transition. Preload bounded next-cell collision and visible assets, prepare render resources incrementally on main thread as required by Godot, activate only when physics/camera/transport state consistent. Do not mutate active scene graph from arbitrary worker threads.
- On load timeout, corrupt pack, cancellation or blocked spawn: hold at safe corridor staging area, retry or return to source without loss of progression/vehicle/inventory. No driving into void. No promise of zero loading screens until native proof.
- During travel preserve clock, weather context, player vehicle/occupants, inventory, current objective and police state according to explicit jurisdiction rules. Do not duplicate actor IDs across scenes. Far cities maintain only compact economy/mission state.
- Resource ownership: region coordinator owns packs, city owner owns road/anchor registry, cell owner owns scene/RenderingServer handles. Reference-count shared assets; staged activation/teardown, no freeing resources still used by visible cells. Avoid global preload of all cities. Test memory after repeated A→B→A loops, first and warm traversals, failure recovery and save/load in allowed locations.
- Native gates: matched 1080p Forward+ on RTX3060; record p50/p95/p99/max frame time, frames over 16.67/33.3/50 ms, load CPU time, GPU time, actual peak RAM/VRAM, draw calls, active cells/vehicles/actors, PCK size and dependency closure. Compare against pinned baseline with same weather/camera/route/driver. Performance target is 60fps, not a certification; budget each subsystem only after evidence.

## Test matrix
| Area | Minimum evidence |
|---|---|
| Legacy adapter | v2 fixtures reproduce manifests, routes, closure behavior and saved coordinates |
| Graph integrity | invalid intersections, duplicate edges, disconnected modes, malformed coordinates rejected |
| Physical city | drive/sweep lanes, doors, stairs, collision and pedestrian access; no clipping or floaters |
| Save schema | new authored save roundtrip, old format rejected without overwrite, corrupt save, missing content, named anchor recovery, rollback |
| Regional loading | first/cached roundtrip, cancellation, missing pack, vehicle and transit continuity |
| Runtime | repeated traversal memory plateau; frame timing, render counts, crash/stall logs |
| Content | identical identity across day/night/weather; validated mission, venue and property reachability |

Acceptance belongs to #592/#593 and native playtest evidence; passing static graph tests alone does not authorize replacing a street or activating regional travel.

## Reconciliation with existing authored-city decision (#197–#206)
The creator's explicit Nov 22/23 decision in #200 waives historical pre-alpha v1/beta.7/beta.8 save migration. The new fixed authored layout and clean save schema are authoritative. Legacy v2 geometry is a temporary survey and parity baseline during engineering, NOT a promise to maintain a second runtime layout provider or migrate old saves. Keep existing live build intact until a reviewed replacement; reject incompatible saves gracefully, never overwrite them silently. Protect mission/business/property identity and validate persistence within the new schema. #198 survey, #199 registry, #200 save, #201 streaming, #202 corridor, #203 route/consumer binding, #204 mutable state, #205 acceptance and #206 city expansion are existing work items; #592 extends their design toward irregular streets, not a duplicate implementation backlog. This decision supersedes contradictory preservation language in older planning artifacts.
