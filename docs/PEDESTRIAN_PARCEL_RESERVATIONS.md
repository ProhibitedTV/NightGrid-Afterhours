# Occupied sidewalk parcel protection (#99)
The optional physical pedestrian director must reserve loaded geometry before
activating a slot. `CityDetails.reserve_pedestrian_parcel(id,start,end)` accepts
only finite single-parcel links (1–30 m), with expanded bounds inside a fully
loaded parcel, and at most 12 active IDs. It never loads a parcel. Multiple
IDs can share a parcel; a duplicate ID cannot move its lease to another block.
Reservation is a retention guarantee, not a route or spawn certificate.
Use only with the full route certification and local collision/camera guards.

After a physical slot is disabled/recycled, call
`release_pedestrian_parcel(id)`. A failed activation must roll its new lease
back immediately. Normal and explicit focus pruning skip occupied parcels.
Final release triggers a deferred normal prune even when the focus is static.
Never release before deactivation. Before changing world/seed or destroying
the director, disable its actors and clear all its own leases. Never restore
leases directly from a save; rebuild through checked activation. No live
pedestrian producer is introduced by this patch. Existing games continue
without reservations.
