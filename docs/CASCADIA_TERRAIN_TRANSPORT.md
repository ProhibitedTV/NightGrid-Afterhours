# Cascadia — terrain, water and transportation planning
Status: conceptual preproduction; no terrain geometry, bridge construction or route commitments. G2–G3 dependencies #592/#594. Designed geography precedes assets.

## Geographic composition
Initial atlas contains a coastal peninsula, eastern industrial shore, southern valley, wooded north ridge, inland delta and tidal marshes. Larger water bodies, wetlands and elevation changes break the continuous city carpet. Preserve existing Morrow Bay perimeter until its actual approaches are surveyed. Never infer shoreline or grades from the schematic atlas SVG.

## Survey and design layers
1. Height and water datum: metres in city-local coordinates, declared sea datum, terrain seam ownership, buildable slopes, shore edges, flood/retaining structure locations. Roads and foundations must meet terrain rather than float.
2. Land use and parcels: reserve bridge approaches, rail rights-of-way, freight yards, service access, pedestrian links, public space and views before footprint authoring. Record physical constraints and named anchors; no real map copied.
3. Transportation hierarchy: local streets, collectors, arterial boulevards, controlled-access regional roads and rail/ferry. Use separate connectors for turns and grade separation; centerlines are not lane geometry. Route widths, curvature, banking, grades and clearances set by measured vehicle envelopes and gameplay speed rather than unverified real-world compliance claims.
4. Structures: actual piers/foundations, coherent spans, rail and utility attachments, visible service access, collision continuity, guardrails; clear vertical envelopes. Don't choose suspension/cable-stayed aesthetics before span and site design.
5. Environment: distinguish tide line and foam, fog depth, distant atmospheric perspective, hills and vegetation; keep sky direct lighting separate from HDR ambient. Wet pavement and water reflections must be budgeted together.

## Travel-corridor art kit
- Modular road deck with continuous UVs, expansion-joint decal, lane markings, barrier and drainage profiles; no visible module seams. Separate near collision from far geometry.
- Structural span/pier library with consistent load paths, approach ramps and retaining walls, original wayfinding, lighting anchors and emergency/service niches only where physically plausible.
- Shoreline kit: retaining walls, riprap, tidal flats, boardwalk pilings and port quay geometry. Align visual water and collision; water traversal/swimming is not promised.
- Landscape kit: coastal grass, scrub, palms where appropriate, redwood/evergreen groves in northern hills, rock/soil and slope materials; spatial batching, HLOD/impostors and reduced distant shadows. Don't make every district a palm-lined avenue.
- Distant city silhouettes reflect actual authored landmarks and parcel volumes, not random towers. Bake proxy materials, test fog/day/night silhouettes from corridor viewpoints.
- Rail and ferry structures remain design work until their actual boarding and route contracts exist.

## First bridge slice work order
Survey departure anchor, entry/exit connector, bridge deck alignment, destination landing parcel, nearby shoreline and actual vehicle envelope. Start with a blocked-off test route outside the live map until collision, camera, streaming, return and save tests pass. Maintain named safe staging points on both ends, source ownership until destination ready, clear failure UI. Road sign IDs and destination labels remain original. Use one transport mode first; add rail/ferry only after independently tested transfers. Do not use schematic atlas kilometres as a gameplay scale or promise a trip duration.

## Render/streaming budgets
Use low-cost distant terrain and skyline, actual local collider/visual continuity, spatial material grouping, bounded texture and geometry residency and deferred resource activation. Native A/B compare fog, clear day and night; bridge-to-city cold/warm drive, fastest supported vehicle, camera turns and repeated crossings. Log p95/p99/max, frames over 16.67/33.3/50 ms, VRAM/RAM, draw calls and pipeline stalls against pinned baseline. No allocation or claimed performance improvement without measurement.
