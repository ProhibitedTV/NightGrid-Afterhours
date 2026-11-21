# Shared streamed NPC safety (part of #95 and #98)
`StreamingSafety` offers conservative predicates for existing logical
traffic and sidewalk population planners. Call observe once per physics tick
using the current gameplay camera, not from rendering callbacks. Camera switch
or rapid rotation resets a 0.35s settling window. hidden requires a same-tick
sample and considers the whole sphere plus an 8m frustum margin. Occlusion
never grants permission: a hidden-in-frustum position is rejected.
The camera guard is not a guarantee against future camera rotation.

`CityDetails.is_spawn_area_ready(at,radius)` requires every overlapped
parcel fully loaded; staged chunks and exterior positions fail. It does not
force synchronous work. Physics clearance uses real static supporting ground,
body overlap and collision layer 1, no actor excludes. The ground probe and
volume query are local checks; the director must also validate lane geometry,
full sidewalk links, speed/distance, actual occupancy and road restrictions.
Pedestrian callback takes an entry dictionary and mandatory certified-link
predicate; vehicle callback takes position. Recycle requires hidden plus the
existing distance guard and successful logical handoff. Use one bounded
director, never run these tests for the entire population each frame.
Keep feature opt-in; no live fleet change in this PR. Native camera turn,
scene transitions, occlusion, visual pop-in and performance review remain
required. Smoke tests use an actual world camera, partial city stage and
physics fixtures, not a guarantee of live route feasibility.
