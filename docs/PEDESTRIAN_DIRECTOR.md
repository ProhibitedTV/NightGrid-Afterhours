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
