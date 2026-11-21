# Civic road restrictions — phase 1
Part of #87, community feedback on temporary traffic changes. The standalone
`RoadRestrictions` service provides a bounded registry (four bidirectional
whole-block restrictions; maximum three simulated hours each) with owner,
reason, expiry and revision. IDs are canonical adjacent grid indices; invalid,
duplicate and disconnecting restrictions are rejected transactionally.
`plan(origin,target)` retains the exact existing StreetRoute behavior when
empty, otherwise searches the current grid deterministically for shortest
accessible routes. An endpoint projected into a closed segment returns no route
rather than permitting an off-road shortcut. `catalog()` returns copies;
`advance(minutes)` expires restrictions and increments revision.

This first PR does not enable live closures, change traffic loops, save data,
or place collision barriers. Future integration uses the existing WorldPlan grid radius; it must preserve bus access and occupied-lane safety, cache
routes by revision, and connect real incident lifecycle and visible signage.
A restriction cannot imply an actual officer is present. The scene integration
must safely defer occupied segments and preserve access to required destinations.
Headless fallback/detour/connectivity/expiry tests run in preflight; native
visual and frame-time work belongs to #87/#88.
