# Morrow Bay transport network — first accessible mobility slice

The network is fixed. In the playable 8×8-block city, road coordinates, right-hand lanes, signalized junctions, bus routes, stations, elevated guideway, and eight major landmarks **never reroll**. New-game procedural variation is limited to eight downtown curated alternates and sixteen outer-zone facade archetypes, cosmetic details, window lighting, planting variations, vehicle color/speed and other seeded infill. This is important for mission locations and transit memorability.

## Surface streets and traffic engineering principles

- **14-meter paved street width**, two directions of travel, lane centers offset approximately **3.25 meters** from the centerline. No intersections are randomly placed.
- **81 signalized intersections**, with two competing through-traffic phases, a representative **30-second green**, **4-second yellow**, and **2-second all-red** clearance per phase. Coordinated offsets smooth flow along corridors. The complete local cycle is **72 seconds**.
- **25 moving ambient vehicles**, with speed limits of roughly **34–41 km/h** (depending on vehicle), a simple car-following headway model, stop-bar enforcement, slowed corners, and no CPU-expensive road-graph search each frame.
- Traffic obeys red/yellow approaches and resumes on green. Vehicles in an intersection clear it rather than stopping mid-crosswalk. This is a modest traffic simulation, **not engineering-grade actuated signal control or crash avoidance**.
- No pedestrian signal controller, protected left turns, real signal detection loops, emergency priority, traffic assignment or vehicle pathfinding beyond these lanes yet. Plan those before expanding the grid.

The yellow interval is within FHWA/MUTCD's commonly recommended 3–6 seconds, but **the fixed 2-second red clearance and 72-second cycle here are game design prototypes**; they are not calculated or certified for real-world roads. FHWA guidance: [Traffic Signal Timing Manual](https://ops.fhwa.dot.gov/publications/fhwahop08024/chapter5.htm).

## City Loop — buses

- Four independently moving buses run two **clockwise fixed loops**: an inner city loop and a new outer-district connector.
- Sixteen authored curbside bus stops sit **17 meters beyond the intersection** (far-side), away from crosswalks and intersection interiors; buses dwell 7 seconds.
- Players can walk to a marked **B / CITY LOOP** stop and press **F** to board while the bus is stopped. Camera follows the vehicle. Press **F** again at a subsequent stop to alight on the sidewalk.
- This favors usable transfers and shorter walk connections; it draws on NACTO's bus stop placement guidance. Real accessibility compliance, turn templates and transit signal priority require further work. [NACTO stop placement](https://nacto.org/publication/transit-street-design-guide/stations-stops/stop-design-factors/stop-placement-intersection-configuration/).

## M-Line — elevated rail

- **One moving two-car train** on an extended dedicated elevated guideway running east/west over the corridor at `z=-58`, roughly 12 meters above streets; does not contend with road traffic.
- Five **permanent** stations: **West Quay Gate**, **Brickwater Crossing**, **Central Exchange**, **Helix Terminal**, **East Gardens**. Train travels between them, pauses eight seconds at each, and reverses at the endpoints.
- Each station has a detailed raised platform with tactile edge cues, protective glazing, overhead canopy, lighting, a skybridge connection and a marked street-level elevator/boarding point. Press **F** from the entrance when the train is stopped; press **F** at a station to get off. Boarding is intentionally instantaneous between street and train in this prototype.
- Elevated track piers are placed away from through lanes. Station geometry and traffic are intentionally kept inside the current city before expanding.
- **CICADA M8 hero train:** the playable two-car visual model now has a curved/bevelled lofted alloy shell, semi-transparent windows with an actual opening to a furnished cabin, route branding, reversible marker lamps and forward spot beams, multi-part running bogies, roof equipment, gangway seals, and cosmetic double sliding doors animated from actual station dwells. The rail route, 17 m/s top speed, five stations, eight-second stops and old save snapshots remain intact.
- **Engineer-facing details:** batched 171 ties, copper service strips, platform tactile markers, cabin grab rails, station identifier signs, door edge warnings and overhead lighting. This is a high-detail procedural art pass, **not** a claim of finished AAA production asset quality or accessibility compliance. See [Art direction](ART_DIRECTION.md).

## Save/load: one world, one seed

`GameSession` owns a single integer seed. The first launch uses a known baseline seed. Press **F6** to start a **new game with a different seed** and rebuild the scene; this does **not** overwrite your saved slot until you explicitly press **F5**. Press **F5** to save and **F9** to load. Save file is `user://saves/afterhours_slot_1.json`; in Godot on Windows this is in the user data folder.

Snapshot version 1 includes: seed, player position, current vehicle or transit rider state, owned/claimed parked cars and their positions, traffic vehicle positions/speed/stop timers, M-Line progress, signal time, clock hour, cash, health, heat and delivery progress. Reload reconstructs city using the stored seed **before** applying moving-world state. Cosmetic variation stays constant during gameplay and after load, like a seeded world generator; a fresh seed changes variations **only when the player requests New Game**.

Validation: `tests/transport_smoke.gd` checks signal conflict exclusion, yellow/all-red clearance, road routes, bus and train boarding, seed propagation, and a real JSON round-trip to an **isolated test file** (never the player's normal save).

## Performance / expansion plan

On the RTX 3060 12GB, Ryzen 7 and 32GB baseline, fleet counts are deliberately bounded: **25 ambient cars + 4 buses + 1 train**. The traffic actors use low-poly meshes and simple collision/kinematics; no dynamic navmesh searches or hundreds of shadowed headlamps. Profile CPU physics and rendering on actual hardware before raising fleet counts or city bounds.

**Next iterations:** pedestrian signals and crossings; multiple bus routes and transit transfers; occupancy and safe player boarding animations; bus shelters with collision/ADA-like entrance geometry; bus lane priority; elevated rail switching and additional lines; intersection conflict zones; traffic spawn/despawn by camera distance; chunk/LOD streaming and tile-based authored expansion. The network is a realistic *organizing principle*, not a complete professional city traffic model.

## Curated replay variants

Eight designated non-landmark parcels in `scripts/world_plan.gd` each have three artist-selected facade pairs: the baseline and two alternate catalog designs. The New Game seed chooses **one whole composed pair per parcel**, so the change is visible but still authored. It is not runtime city mutation, arbitrary procedural block generation, or endless random urban sprawl. Mission coordinates, landmark sites, transit lanes and named stops do not change. Both seeds and selected world geometry reconstruct identically after save/load.

## Current expansion and persistence

The road grid now covers 64 blocks, has 81 signalized intersections, 25 ambient cars, four boardable buses and 16 curb stops, and supports five M-Line stations. Layout geometry for all non-landmark parcels is saved as an explicit `world_manifest` with the world seed. Old slot-one saves remain loadable. [See the city and civil-services expansion.](EXPANSION.md)
