# Pedestrian streaming director pilot
Integrates #116, #117 and #119 on a separately testable branch for #99.
The director is not installed in the playable World. Configure it once with
the actual city, saved seed, curated candidate links and a verified rigged
visual scene; the empty fixture in the headless test is not a game asset.
Call tick once per physics frame after updating the current gameplay camera.
Route checks are scheduled for up to 24 local, potentially hidden candidates;
only certified, locally grounded hidden actors can activate. The logical
model enforces distance, active-cap and bounded changes. Reserve the parcel
before activation and roll back any failed activation. Release only after
the physical body is disabled. No synchronous chunk loads.
Indoor mode suppresses transitions. Save snapshot captures live phase or
returns empty on failure; restore is only before activation. Shutdown disables
the pool before releasing parcels and is intended for level destruction only.
No witnesses are exposed yet. Actual rigged visuals, live World wiring,
dynamic obstacle recovery, camera motion prediction and genuine native
playtest evidence remain rollout blockers. The fixture tests real physics
and camera guards with a minimal city API; not a full native city validation.

## Local movement recovery
The pool now reports WALK, YIELD or DISPLACED for live leases. A grounded
actor making negligible forward progress for 1.2 seconds reverses along the
same link with a 2-second reversal cooldown. If deflected more than 0.6 m
laterally it stops horizontal motion and stays leased. This is conservative
obstacle handling, not a freeform pathfinder; actors do not sidestep into
traffic or teleport. The physical pool smoke adds a real static obstruction
and checks yield/reversal. Native crowded-street validation remains required.

## Daily activity integration (#121)
The optional final tick argument is the actual game hour (pass DayNight.hour
when wiring World). It filters both candidate certification and activation,
using stable seeded civilian roles. Negative/default preserves prior behavior.
A schedule change never forces active actors to vanish. active_routines()
returns only the currently leased identities' role/threshold data for future
visual selection and dialogue. It is not a witness API. Combined CI includes
the approved main-branch civilian car coachwork checks and all earlier tests.
