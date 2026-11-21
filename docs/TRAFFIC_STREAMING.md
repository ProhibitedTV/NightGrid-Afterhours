# Logical traffic and streaming foundation
Part of #89. The current 25 civilian cars and four buses remain unchanged.
`LogicalTraffic` is a pure RefCounted model, configured with authored route
specs (id, Vector3 path, count). With the four existing loop specs, seeded
IDs, initial fractions, paint and cruise-speed draw order match the fixed
fleet initialization. No active nodes are created by this model.
- `advance(seconds, active_ids)` advances only background phases; this is
  idealized lane circulation, not a physical signal/headway simulation.
- `sample(id)` provides lane position, heading, next index and visual data.
- `capture_live(id, position, next_index)` projects a released live car
  onto its existing segment, rejecting large offsets.
- `snapshot()/restore()` store JSON-safe phases, ignore unknown IDs and
  invalid values; integration should seed from existing v1 car snapshots.
- `plan_changes(focus,camera,speed,indoors,active_positions,occupied,
  can_spawn,can_hide)` proposes up to two changes per call, maximum sixteen
  active ambient cars, distance hysteresis, speed-dependent near guard and
  nine-metre horizontal separation from existing and proposed car positions.
  Callbacks MUST implement actual conservative frustum, collision-loaded,
  road-clearance and scene safety checks. False or missing predicates deny
  changes; do not substitute unconditional true at runtime. Active positions
  come from live scene nodes, and both actors and camera must be distant.
  This function does not enforce global budgets across multiple callers;
  call from one director at a bounded cadence.

## Codex integration sequence
1. Add one director, disabled by default until native evidence. Seed phases
   from current save and retain stable vehicle IDs; reserve spawn slots
   transactionally, verify actual lane/headway and collision clearance.
2. Pool/reconfigure civilian TrafficVehicle nodes without rebuilding body
   meshes per activation. Capture live position before recycling. Keep
   buses, rail, police, player cars distinct. Cleanup audio/witness references.
3. Add real visibility and predictive collision readiness predicates,
   account for alternate cameras and speed, indoor exterior focus (or no
   changes), closure-aware routes, and frame-time budget diagnostics.
4. Native A/B tests and only then consider enabling by default. Report
   visible pop-in, active counts, CPU/GPU/frame percentiles, and preserve
   original v1 compatibility. No performance improvement is claimed yet.
