# NightGrid Afterhours — State of Cascadia
## Integrated world, architecture and art production roadmap

**Decision:** Cascadia is the canonical fictional state name. Morrow Bay is the starting city and primary playable development target. This is alternate-history fiction inspired by the geography and urban development of western North America, not an assertion about actual political borders. Ironhaven, Silica Valley, Redwood Heights, Ashford, Saltmere and Delta Junction are working names. Other northern cities remain future concepts.

**North star:** An authored, lived-in multi-city cyberpunk world with realistic construction and urban history, native Godot 4.7.2 Forward+ at 1080p60 on RTX 3060 12 GB as the target. Expensive offline production, bounded runtime cost. Quality and measured performance precede geographic expansion.

### 1. World structure
- Initial region: Morrow Bay (historic port/corporate core), Ironhaven (industrial East Bay-inspired port), Silica Valley (South Bay research/manufacturing), plus Redwood Heights (wooded hills), Ashford (university), Saltmere (commuter peninsula) and Delta Junction (inland freight/refineries).
- Water, bridges, rail, ferries, forests, tidal marshes and mountain roads give travel meaning. The schematic atlas has seven settlements and eight connections; it does not establish final distances or construction coordinates.
- Eventual separate northern rainbelt regions inspired by Portland and Seattle are deliberately outside current production. No feature or release commitment.
- Preserve the economic and architectural contrast of historic working neighborhoods, corporate redevelopment and ordinary residential life. Map geometry must reflect fictional development eras: port settlement, trade corridors, industry, transit expansion, hillside housing, corporate consolidation.

### 2. Morrow Bay v3 — prerequisite to expansion (#592)
Keep 58 m streaming buckets separate from road/parcel topology. Existing v2 saves, missions, business IDs, properties and anchor positions must remain recoverable. Audit all consumers before replacing the road grid. Start with a non-story parcel and an isolated intersection pilot, not a wholesale rewrite.
- Street hierarchy: inherited diagonal boulevard; irregular setbacks, variable block dimensions, T junctions, shore-following streets, service lanes and pedestrian shortcuts. Terrain and slope survey before hillside geometry.
- District signatures: Brickwater historic industrial fabric; Glassline corporate podiums/plazas; Vesper fine-grained commerce; North Quay port markets; West Docks freight; Afterhours entertainment; Horizon courtyards/hills; Southworks civic infrastructure.
- Interiors: design room program first, then walls, openings, structural core, stairs/elevators, services, daylight, furniture and collision. Match exterior entrances to actual rooms. Maintain accessible gameplay clearances, named anchors and door reachability. Synaxis #460 remains a separate detailed contract.
- Candidate output already in #591: four parcel plans, three interior programs, street graph study, nine distinct shell structures, 27 building LOD models and four parcel proxies. These are recipes/experimental candidates, not installed finished buildings.

### 3. Art department / Anubis (#590, #571, #585–#589)
One existing checkout; existing models and toolchains; serial guarded runs, immutable batch identities, hash-bound inputs/outputs, private Z: NAS candidates, resumable stage logs and review packets. No redundant clones, implicit installs or automatic promotion.
- Existing music and visual factory; second coastal detail catalog (56 subjects, 112 concepts, 96 mesh jobs, 16 material variants); seven botanical species/two mesh tiers; 224 Cycles impostor views; building UV2/LOD/occlusion candidates; ten synthetic HDR skies; eight weathering decals; character candidates; isolated native Synaxis lightmap pilots; inventory/evidence/dashboard.
- Expand by **demand from actual authored places**: historic homes, garages, rooftops, construction, groceries, interiors, utility networks and regional landscape kits. Explicit rights and provenance, physical metre scale, texture budgets, material sharing, collision and reuse. Do not mass-produce future cities before their block plans exist.
- Art pipeline stages: planning/survey → geometry/room layout → material source/bake → LOD/UV2/proxy → isolated import/lighting → matched native A/B → human approval → integration PR. High-poly sources and failed output never ship. Actual local reflections, shader bake/export tests, real dependency-closure audit, native runtime impostors, full SFX/voice integration and finished interiors remain open.
- Latest queue contract: [ANUBIS_SINGLE_SHOT_PRODUCTION.md](ANUBIS_SINGLE_SHOT_PRODUCTION.md). Dry plan and preflight before execute, explicit hardware invocation by owner. No native production completion claim from CI alone.

### 4. Delivery gates and ownership
| Gate | Work | Acceptance before advancing |
|---|---|---|
| G0 — production readiness | #590 / #591 | Current CI passes; dependency/space preflight; end-to-end local candidate run, verified index and review packet |
| G1 — visual pilot | #585–#589 / #571 | Representative native import, lighting and material review; fixed-camera day/night/wet; cold and warm traversal; PCK and residency accounting |
| G2 — city redevelopment | #592 / #460 | Legacy road API parity, exact anchor survey, one new parcel and intersection, doors and routes physically traversable; no save or traffic regressions |
| G3 — regional travel | #593 | Stable city IDs/local coordinates, bridge and sparse destination block, safe travel/return/reload, distant silhouette, staged prefetch, bounded active simulation |
| G4 — second city | #593 | Ironhaven authored district vertical slice with same gameplay systems; measured cross-city traversal; no full-region preload |
| G5 — third city | #593 | Silica Valley authored slice; intercity freight, music and economy; independent resource packs and dependency audit |
| G6 — wider state | future | Northern regions only after earlier gates; scope and names separately approved |

G0–G2 can overlap in offline planning, but runtime activation follows the prerequisites. No dates or completion guarantees are implied. Use representative native 1080p60 target (16.67 ms frame budget), report cold/warm p95/p99 and stalls, CPU/GPU and memory; establish measured per-system budgets instead of declaring speculative allocations as fact.

### 5. Shared game systems
Intercity courier/freight, jobs, music touring, venues, property, transit and jurisdiction-aware dispatch should use the same data contracts. Preserve compact persistent state in unloaded regions. Keep day/night and weather coherent; do not simulate all pedestrians/vehicles everywhere. No new gameplay promises until vertical slices pass.

### 6. Sources of truth
- [Regional vision](CASCADIA_REGIONAL_VISION.md), [street morphology](MORROW_BAY_STREET_MORPHOLOGY.md), [Synaxis architectural study](SYNAXIS_HQ_ARCHITECTURAL_RESEARCH.md).
- `tools/asset_refinement/regional_concept.json` is the schematic atlas source; `regional_candidates.py` exports JSON/SVG and architecture demand. State name is fixed; settlement names and positions provisional.
- #590 production dispatcher; #592 urban redevelopment; #593 regional roadmap. Keep these open until their actual implementation/acceptance gates pass. The current consolidated PR #591 is a candidate production implementation, not certification of the whole vision.

### 7. Detailed implementation contracts
- [World architecture and migration](CASCADIA_WORLD_ARCHITECTURE.md): coordinate/identity separation, legacy route parity, save transactions, regional travel states, resource ownership, test matrix.
- [Urban and architectural production bible](CASCADIA_ARCHITECTURE_BIBLE.md): city signatures, kit hierarchy, place-driven work orders and vertical slice content requirements.
These documents expand the approved plan; the engineering designs and first pilot allocation are proposals, not active features.
