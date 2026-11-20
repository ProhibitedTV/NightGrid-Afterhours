# Predictive city streaming pass

**Issue:** [#32](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/32), stutter at chunk boundaries.

## What changed

Continuous gameplay no longer calls synchronous `set_focus()` every time the
player crosses a city cell. The normal `world.gd::_process` focus tick calls
`city_details.request_focus(actor_position, actor_velocity)` instead.

- The current 5x5 collision/visual ring is retained.
- A second 5x5 window is predicted 1.25 seconds along the actor's planar
  velocity; the union is queued before reaching the next road block.
- Existing blocks are reused, missing blocks are ranked by current/predicted
  proximity and **at most one complete block** is built during each
  `CityDetails._process` call.
- Distant blocks are removed only after queued replacements have loaded.
- Explicit save restore, world teleport, entering/leaving interiors and manual
  `set_focus` continue to build the whole destination collision ring
  synchronously; existing tests and v1 saves require this.
- No overlay, scene fade, modal loading screen or extra procedural map content
  is introduced.
- The F3 overlay now reports the outstanding block queue and last/peak
  block-build time so players can correlate stutters with streaming.
- Per-block deterministic RNG and the immutable `WorldPlan` manifest are
  untouched.

## Limitations / honest status

This is a **burst-reduction and prefetch pass**, not proof of hitch-free 60 FPS.
One chunk still creates meshes, collision nodes and MultiMeshes together on the
game thread; on some hardware **a single heavy chunk may exceed the 16.67 ms
frame-time budget**. Godot's headless smoke tests do not measure RTX 3060
render-frame latency, shader compilation or Windows audio/driver cost.

Further production work for #32 includes background-thread *data preparation*
(with scene-tree mutations only on the main thread), smaller chunk work units,
prewarmed materials/shaders, staged collision proxies, visual continuity and a
measured cold-/warm-cache profile. Keep the P0 issue open until these are done
and a real Windows 1080p playtest confirms p95/p99 and 1% low frame times.

## Tests

`tests/predictive_streaming_smoke.gd` verifies:
1. 25 initial blocks fully solid; no queue at initial spawn.
2. Predicted driving focus queues a 5-block forward ring without a synchronous
   construction burst.
3. Each processed frame constructs no more than one block; the forward
   collision ring arrives before the focus crosses the boundary.
4. No duplicate work when the target doesn't change.
5. Explicit distant focus immediately builds required destination collision
   and unloads distant city geometry; the persistent save seed doesn't change.

Other existing integration tests still cover city determinism, interior
streaming, Southworks solid collision geometry and 60 Hz physics.

To review in the Windows game: use F3 while driving several laps between
Southworks and Central Exchange, record Godot profiler frame times and the
frame-time histogram before/after the feature branch. Check peak times both
after cold launch and after the district has been visited once.
