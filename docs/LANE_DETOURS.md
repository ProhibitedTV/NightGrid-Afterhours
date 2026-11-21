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
