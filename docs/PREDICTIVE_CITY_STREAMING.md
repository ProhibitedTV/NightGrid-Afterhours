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
- If an extreme jump unexpectedly outruns prediction, the **currently occupied** cell is built immediately as a one-block collision safety fallback; other blocks still stream incrementally.
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

## Instrumented Windows driving trace (next playtest)

Press **F3** for a live, rolling 240-render-frame view: average frame interval,
nearest-rank p95/p99 frame interval, 1% low FPS (reciprocal of the mean
slowest 1% of frame intervals), and number of frames slower than 33.33 ms.
The first few frames after opening the game do not represent a full window.

Press **F8** once to start a frame-by-frame trace and again to stop and save
a CSV in the Godot user-data folder. The on-screen notification gives the full
path. The CSV includes elapsed time, observed frame interval, newly built
city block count, measured main-thread city-build time, pending chunk count,
player/vehicle world X/Z and whether driving. Recording is capped at 18,000
frames (approximately five minutes at 60 FPS) to prevent unbounded memory
growth. A new F8 recording replaces the previous in-memory capture; exported
CSV files are kept separately with timestamps.

**Scope of measurement:** `delta` is the elapsed time between Godot
`_process` callbacks, including pacing/VSync, OS scheduling, and other work.
It is **not** GPU execution time. The city-build duration is measured from
`Time.get_ticks_usec()` inside the block builder; it correlates with but
does not exhaustively explain long render intervals. Main-world callbacks
observe CityDetails' last completed build on the following frame. A block's
duration is recorded only when the loaded-block counter increases, preventing
the last build timestamp from being falsely repeated on every idle frame.

For comparable runs: capture a **cold** drive out of Southworks at 21:30,
save the trace, revisit the same route for a **warm** drive, save separately,
then compare p95/p99, 1% lows and build-event rows. Repeat at midday and with
SSR on/off. Keep #32 open until the observed long frames have been reduced and
player-visible stutter is independently verified on Windows Forward+.
