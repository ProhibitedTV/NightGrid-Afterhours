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

## Staged construction follow-up — PR #43

The initial predictive pass above only limited the number of *complete*
district blocks per frame. Each block still produced its entire collision,
two façades, street furniture and all `MultiMesh` batches in one callback.

The next pass breaks each block into deterministic work stages:

1. Prepare sidewalks and **both existing building collision shells**. The
   original shells are not doubled by later façade work. A landmark's open
   public space is prepared independently.
2. Construct the first saved parcel's architecture (or the fixed landmark).
3. Construct the second saved parcel, retaining the same stored manifest.
4. Add the alley and district-specific street furniture.
5. Flush the accumulated material-sorted `MultiMesh` transforms in groups of
   **six batches per frame**, preserving the original draw-call grouping.

Normal gameplay advances **one stage per render frame**, not an entire block;
previously complete neighborhoods stay loaded until the replacement ring is
ready. An unexpectedly reached actor cell, manual teleport or saved-game restore
**synchronously finishes** any pending destination work, retaining a valid
collision volume rather than passing through unfinished walls. Abandoned
speculative chunks are discarded if a route changes; their partial nodes
and materials are never published to the set of completed blocks.

The source seed and per-block RNG state are retained across stages. Windows F8
CSV traces now include `stream_stage_steps`. `stream_build_ms` is computed from
a **monotonic cumulative build-time counter**, so unfinished parcels are
accounted for instead of charging all cost to the final frame. The F3
last/peak build timer now describes an individual stage, not a whole chunk.

**Remaining limitations:** this still performs Godot scene-tree and mesh
operations on the main thread. No hard frame-time limit is guaranteed for one
complex parcel or landmark; only the amount of work is bounded. Initial
construction and teleport/reload remain synchronous for collision safety. The
first test only proves work partitioning and save determinism; verify Windows
1080p cold/warm p95, p99 and driving footage before claiming the hitch is gone.
The staged shell is visibly present before fine decorations; inspect for
near-field pop-in, draw calls, material instantiation and shader compilation.


## Bounded idle eviction follow-up

Normal focus updates now mark eviction work due instead of freeing every obsolete
completed block at once. Once replacement construction drains, each idle streaming
callback queues at most one obsolete completed block for deletion, never on the
same callback as a construction stage. Each callback recomputes distance against
the latest current/forecast cells and live pedestrian reservations. The pending
prune survives an unchanged focus and is visible as `prune_due` in streaming stats.
Explicit teleport/save restore still prunes synchronously. Streaming resumes only
after a valid focus has been supplied.

This targets potential scene-tree and RenderingServer teardown bursts, not the
unattributed Windows wall-clock stall documented in TRAFFIC_OPTIMIZATION_NATIVE.md.
Individual block teardown, cancellation of partially built speculative blocks,
render submission, shader/driver stalls and other systems remain possible costs.
The predictive smoke checks the eviction cap, construction/eviction separation,
stationary queue drain and retained occupied collision. Re-run native cold/warm
live-traffic driving traces and inspect wall-clock and F8 percentiles before
closing #32 or claiming a measured improvement.
