# MORROW BAY — second-ring city expansion

This expansion enlarges NightGrid: Afterhours from a **6×6-block downtown (36 blocks)** to an **8×8-block city (64 blocks)**, or **77.8% more blocks**. Streets are on 58 m centers and the playable 8×8 footprint runs approximately 464 m across intersection-to-intersection. Four new neighborhood types extend the existing four, keeping old coordinates, established businesses and quests intact.

## District geography

| District | Map | Civic identity | Distinctive streetscape |
|---|---|---|---|
| Vesper Market | Original northwest center | Independents, nightlife, food | Saffron signs and dense storefronts |
| Glassline | Original northeast center | Transit and offices | Tall facades and sea-blue glass |
| Brickwater | Original southwest center | Industrial housing and unions | Fire escapes and red brick |
| Afterhours | Original southeast center | Music, clubs and late shops | Pink neon and reflective paving |
| **North Quay** | Northern outer band | Harbour food chain and public market | Sea-glass shades, fish-market stalls, covered concourse |
| **West Docks** | Western outer band | Freight, shipping and mechanics | Copper floodlights, cargo structures and stacked crates |
| **Horizon Gardens** | Eastern outer band | Community healthcare, urban greenery and local retail | Planted avenues, garden courtyards and clinics |
| **Southworks** | Southern outer band | Civic services, bus maintenance and industrial supply | Municipal architecture, machinery and work depots |

District membership is **authored**, not a random biome choice: the original downtown quadrants are unchanged and the outer edges are explicitly zoned. The four new landmark blocks are **North Quay Exchange**, **Pier Nine Depot**, **Horizon Commons**, and **Southworks Hall**. All four are open-air or sheltered civic plazas with pedestrian space, architecture, props and landscaping; they do not replace real enterable building interiors.

## Fixed map skeleton, random only on New Game

`scripts/world_plan.gd` is the geography authority with `GRID_RADIUS=4` and `WORLD_LAYOUT_VERSION=2`. Landmarks, block grid, streets, station locations, transit tracks, business names, service addresses and quest destinations are **permanent**.

`GameSession` owns one world seed. The downtown's 64 original building profiles remain fixed except for the previously added curated alternatives. The expanded outer blocks select from **16 authored building archetypes across four zoning families**; a seed picks facade pairs at New Game. That gives neighborhood-scale replay variation without unpredictable roads or mission sites.

**Important persistence improvement:** A version-one save now contains an explicit `world_manifest` snapshot of the **112 chosen building profiles for all 56 non-landmark blocks**, in addition to the original world seed, gameplay state and transit state. On F9, geometry is recreated from this stored manifest, not re-rolled by current random state. Seeds also govern secondary planting/window patterns. The layout is not regenerated while driving or walking.

Older version-one saves without `world_manifest` are still accepted: the game creates an updated outer-ring manifest from their original seed, preserving downtown locations. **New Game F6** clears the active generated manifest and requests a fresh seed, without overwriting the previous disk save until **F5**. This is a finite authored procedural layout, not infinite Minecraft-style chunk generation; streaming and persistent world-generation-version migrations are future improvements.

## Transportation coverage

The expansion extends **all existing transport layers**, not just the road meshes:

- **81 controlled road intersections** (9×9 intersection grid) with existing green/yellow/all-red phasing.
- **25 ambient civilian vehicles**, running the downtown, inner, perimeter and newly accessible ring road routes with basic speed control, red/yellow compliance and following distance.
- **4 City Loop buses**: two original inner buses plus two new **Outer Connector** vehicles, with **16 marked stops** split across eight existing center stops and eight outer-district transfer points.
- **Five permanent M-Line stations**, adding **West Quay Gate** and **East Gardens** to the earlier three. The elevated right-of-way now extends roughly 520 meters end to end, with an updated pier sequence.
- **81 authored streetlight fixture records**, pooled down to eight nearby active unshadowed OmniLights for night lighting. A new 8×8 street grid also gets sidewalks, curbs, crosswalks, lane paint, pavers, planted street trees and environmental props.
- Passenger boarding, bus dwell, train progress, signal elapsed time and vehicle movement remain part of the current F5/F9 save flow. New outer bus vehicle IDs are stable.

These are scaled **gameplay simulations**, not professional traffic models. The player can ride transit at stops, use roads and cross districts without losing their city state. True pedestrian priority controllers, freight railway interchange and responsive traffic incident systems remain future work.

## Sixteen meaningful public destinations

Every permanent site has a named operator, hours, signage and an original close-up outdoor/streetfront composition. Distinctive detail includes produce racks, checkout stations, library books, medical beds, fire trucks, warehouse loading pallets, municipal counters, garages with tooling, and electrical control cabinets.

| District | Permanent destinations | Uses |
|---|---|---|
| North Quay | Quay Fresh, Tide Clinic, Harbor Reading Room, Seawall Pantry | Buy provisions, medical care, investigate records |
| West Docks | Freight Control, Crane & Gear, Dock Watch Desk, Cold Chain 09 | Cargo jobs, repair cars, settle citations, refrigeration logistics |
| Horizon Gardens | Horizon Health, Eastside Fire 4, Orchard Grocer, Commons Library | Neighborhood triage, rescue first aid, groceries, archives |
| Southworks | Southworks Records, South Bus Works, Union Distribution, Grid Annex Four | Municipal services, garages, freight dispatch, power documents |

**Gameplay:** On foot, walk near a service counter and press **G**; press **1** for a service or information, **2** for a contract and **G/Escape** to close. Interactions share the same UI as the pre-existing nightlife venues, so there is not a second incompatible interaction system.

Services include: buying two food-supply packs ($24–29); pressing **R** while on foot to consume one for +25 health; paid clinic and fire-station treatment; paid citation settlement (-1.75 police heat); garages that restore a damaged nearby parked car's condition; free archive/power records stored as discovered clues; and warehouse workboards. Car collisions now reduce condition and therefore top speed until repaired. Services check prerequisites and cash before taking money.

The four original nightlife-contract missions remain separate. The new **four logistics jobs** are: *The Cold Chain* ($310), *The Lifeline* ($365), *After the Sparks* ($280), and *Grid Audit* ($415). A receiving location must be staffed/open for handoff. They are one-shot, reward currency, track their destination, and persist with the save.

## Saved mutable state

The version-one save includes previous gameplay fields plus: `world_manifest`, `ration_packs`, `civic_intel`, `civic_job_active`, `civic_job_completed`, and condition for each player-drivable parked car. New fields are optional for backward compatibility. Position, currency, heat, health, completed and active nightlife jobs, mission progress, bus position/dwell, rail progress, signal clock, and world seed remain supported.

## Graphics and performance envelope

The RTX 3060 12GB / Ryzen 7 / 32GB / 1080p at ~60 FPS remains the **target, not a benchmark result**. Most city facade details use GPU MultiMesh instancing; architectural batches are now grouped by material **and approximate two-block region** so distant areas can cull independently. Each additional civic site is handcrafted using low-poly original geometry and cached materials, and only two of its nearby local unshadowed lights may be on at once. The 81 intersection signal heads, 128 street trees, and four-bus network add real CPU/render cost.

The expanded city is **fully constructed at startup**. It is not yet streamed or LOD'd like an AAA open-world title, and this pass does **not** claim to deliver fully furnished, walkable interiors for each of the 16 businesses. Those will require proper shell cutouts, navigation, entry/exit flows and on-hardware frame profiling. Start with the new landmarks and the busiest service sites.

## Validation

`tests/expansion_smoke.gd` verifies all eight districts, a full saved parcel manifest, reroll differences on fresh seeds, the expanded traffic counts, unique civic destinations, grocery purchase and consumption, logistics delivery, vehicle repair, free record discovery, actual JSON save/reload and backward-compatible saves. The previous city, nightlife, rendering, traffic, and 90-frame smoke tests continue to run in CI.
