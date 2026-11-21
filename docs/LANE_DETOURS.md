# Civilian lane detours (part of #87)

LaneDetour is a standalone finite route adapter. It consumes the existing
RoadRestrictions registry and junction indices; a successful plan supplies
3D waypoints with the current 3.25m right-hand lane offset, mitered junction
joins, and preserved height. All individual grid edges are rechecked against
the registry including compressed straight blocks. Invalid geometry, U-turns
and outward boundary lanes fail closed. It does not supply turn animations,
collision certification or a complete cyclic vehicle route.

Integrate at an actual junction handoff, never teleport or reverse traffic
mid-block. Preserve vehicle identity, speed, headway and signal checks. A
finite detour must terminate explicitly and resume the original loop only
at a compatible lane/junction; the existing modulo-index TrafficVehicle
controller cannot consume it directly. Protect buses and occupied segments
with the eligibility gate. Replan on registry revision only at safe handoffs
with bounded work; validate actual turn clearance, approach reservation and
save/load. Native traffic continuity and frame pacing remain acceptance gates.
No live traffic behavior changes in this PR.

## Finite controller pilot
TrafficVehicle.begin_finite_detour(path,rejoin_index,certify) accepts an opt-in path only for a stopped/near-stopped civilian at its existing lane, with a compatible original-loop exit and mandatory external certification. The original route remains unchanged; the physics controller uses existing signals, headway and speed rules for the finite cursor, then rejoins without a position assignment. Buses never accept this request. Interrupted snapshots deliberately hold rather than blindly resume the loop: certified save recovery and live route supervision are required before enabling a director. Fixture tests explicitly stage reached points; do not claim autonomous native driving evidence. No live code calls the pilot yet.
