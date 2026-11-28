# Cascadia — living regional economy and gameplay design
Status: proposed design contract, not implemented systems or an expansion release. Builds on the actual 2036 economy, QuotaDrop, Morrow OS, music career, venue and progression systems. Master plan G2–G5 governs rollout.

## Design rule: geography has a purpose
Cascadia's cities exchange goods, services, people and culture because their industries differ. Don't simulate every citizen, truck or business. An authored regional supply graph creates a small number of believable player-facing opportunities; local physical scenes embody the visible consequences. No mandatory survival grind or real cryptocurrency network.

| Place | Exports/services | Imports/dependencies | Player-facing purpose |
|---|---|---|---|
| Morrow Bay | Finance, software, hospitality, live entertainment, professional services | Food, equipment, manufactured goods, freight | Starting story, courier work, social hubs, nightlife |
| Ironhaven | Freight handling, fabrication, repair, live music production | Electronics, parts, consumer goods | Industrial contracts, garages, touring, port deliveries |
| Silica Valley | Electronics, research, test equipment | Industrial components, laboratory supplies, logistics | Consulting, equipment courier, corporate research |
| Redwood Heights | Recreation, small services | Groceries, maintenance, supplies | Scenic routes, small-town jobs, property |
| Ashford | Academic services, independent culture | Equipment, books, food | Campus contracts, bookstores and gigs |
| Saltmere | Commuter services, light industry | Goods from both large cities | Transfer hub, residential and commercial deliveries |
| Delta Junction | Process-industry and river freight | Machinery and service parts | Freight routes, industrial diagnostics |

All non-Morrow Bay content remains provisional; these are economic roles, not a claim that actual cities or businesses exist.

## Shared gameplay contracts
**Permanent data:** city, venue/business, property, employer, contract template, transport stop, jurisdiction, item and route IDs. **Mutable data:** player funds, inventory, ownership, quest receipts, career progress, booked gigs, active cargo and a compact set of site changes. No world geometry in the new save (#200). Dynamic schedules use the shared game clock (not wall clock); one bounded active-city registry. A city does not own a separate wallet or career.

- Preserve `scripts/economy.gd` fictional 2036 price convention (2026 anchor × 1.343916379, whole USD; authored 400 sats/USD), existing progression ledger, transaction caps and receipts. Regional price modifiers must be explicit, reviewed and bounded; no actual financial service.
- QuotaDrop offer selection and off-duty semantics stay consistent; a new intercity contract binds named pickup/dropoff anchors and supported modes, valid hours, cargo volume/weight class, agreed reward and route revision. Declining before pickup is free; carried cargo follows existing abandon/retry rules. No payment on accepting an offer or arriving at city boundary.
- Workboard expands existing technical consulting and documented mission progression into fictional hardware, logistics and facilities problems. Reuse one-time receipts; no repeated payouts from city reload.
- Morrow OS remains the shared directory and route interface. App name can stay Morrow OS as an in-world brand; regional UI not yet approved. City-aware itinerary shows local leg, transfer, destination. Phone is not a remote payout or automatic contract acceptance mechanism.
- Music: PocketBeat and Blue Hour progression remain canon. Regional booking extends existing roster/rehearsal/cred instead of starting a parallel skill tree. Offer discovery at local venue, rehearsal/gear requirements, agreed fee, performance receipt, optional merchandise. No fabricated ability to play an unbuilt venue.
- Property: named owned/leased addresses, storage and authorized save points; don't sell fictional inaccessible property as playable. Preserve player-controlled rest and local recovery. Vehicle ownership and damage belong to stable vehicle IDs; jurisdiction or region crossing does not duplicate cars.
- Police: local dispatch with bounded active units; a city boundary must not magically erase heat. Define persistent incident identity, reporting delay, jurisdiction handoff and expiry rules separately; no global offscreen pursuit simulation or free reset exploit. Existing in-city policy remains intact until verified.

## First regional playable loop (after G3)
Working contract concept, not new story canon: local electronics repair supplier in Morrow Bay → physically collect a sealed non-hazardous spare component → choose supported road transport → cross the bridge → deliver to a staffed Ironhaven workshop → receive exactly one agreed payout → optional return trip. One route, one delivery, one destination interior, one source hub. Make the arrival and business purpose visually intelligible.
- Source and destination hours use existing venue schedule semantics; allow player to wait or return without losing necessary progression.
- Prove cargo/vehicle state crosses the boundary exactly once; exit/re-entry and failed travel cannot duplicate payment or inventory.
- Offer economics: pay for additional distance/time and plausible work, not arbitrary city prestige. Tune using measured in-game trip time and existing starter incomes/expenses; do not announce a reward yet.
- Zero-cash recovery: a viable local job and affordable recovery path remain available; no mandatory intercity toll, fuel or repair expense may strand the player without a documented route to recover. Test low funds, full inventory, blocked entrance, closed business, wrong destination, death/abandonment and reload. No mandatory starvation/thirst mechanics.

## Daily life, schedules and ambient activity
Each district has a few authored time bands (commute, daytime service, evening, overnight) with different foot traffic, storefront states, freight deliveries, transit and music. Closed doors, windows, loading bays, exterior fixtures and quiet streets should reflect business hours. Keep outdoor ambience, indoor zones and radio distinct. Weather affects appearance and ambient population, not a hidden tax. Only nearby NPCs have physical movement, collision or animation; far population is a seeded schedule/aggregate, not resident simulation. Cosmetic seeds must never change static geography. Cap actors/lights/emitters by measured budgets; use pools and deterministic spawn anchors, defer during streaming pressure.

## Art department briefs from gameplay
- Source electronics shop: small service counter, antistatic workstation, parts drawers, original blank-label packaging, racks, freight trolley; visible entry and handoff point.
- Ironhaven workshop: industrial facade, roller opening, separate public entry, tool benches, inspection surface, storage racks and loading area with turning clearance. No actual site assignment before atlas survey.
- Bridge route: guardrails, drainage, expansion joints, original fictional road markings, gantries, inspection recesses, fog and nighttime skyline; low-cost modular deck and far proxies.
- Intercity transit: original wayfinding signs, timetables, seating, accessible boarding areas, ticketing hardware and service doors; gameplay travel modes depend on actual verified routes.
- Culture: band posters, rehearsal rooms, road cases, original venue identities, local radio station IDs. All original or licensed; no real band imitation, real addresses or logos.
- Use existing coastal-detail catalog and material families first. Each missing family gets a place work order with measured dimensions, runtime derivative limits, provenance and camera acceptance views. No automatic future-city generation in current Anubis queue.

## Acceptance matrix
| Test | Required outcome |
|---|---|
| Economy | Single receipt on delivery, no duplicate payout after retry/reload, caps enforced, fee/payout visible |
| Cargo | Exactly one payload state, valid pickup/dropoff and mode, recoverable failure |
| Progression | Existing prologue, local jobs, music and property still work; travel is optional |
| Persistence | New fixed-world save roundtrip; incompatible historical saves gracefully rejected per #200 |
| Simulation | Closed/open state consistent across unload and reload, no duplicate NPCs, bounded resident actors |
| Routing | Named anchors and physically usable route; GPS, bridge collision, transit and dispatch coherent |
| Native | Repeat matched Morrow Bay ↔ Ironhaven trips with frame timing, RAM/VRAM and stable resource teardown |

No payout values, region distances or new release dates are specified. These contracts describe a playable vertical slice to test before broader regional economy.
