# Frame-budgeted city decoration and unloads — issue #32

The old predictive streamer fixed the largest synchronous 5x5 loading spike,
but it still built **every decorative MultiMesh group within a complete city
block in the same frame**. One block may contain several hundred different
material/shape combinations and individual scene-tree / rendering-server
resource allocations. Fast traversal through Southworks and outer districts
could still hitch despite the nominal one-block-per-frame limit.

## This pass

Normal travel now has two independently bounded phases:

1. **Collision-first block construction.** On an upcoming block, generate
   actual solid building bodies and the base physical shell immediately.
   All decorative transforms are collected but not committed to the
   renderer en masse. This guarantees safe player/vehicle collision even
   when a chunk is still visually staging.
2. **Deferred material batches.** Upload at most **8 distinct MultiMesh
   batches per rendered frame**, with a 2,200 µs advisory wall-time
   watchdog. Each material batch is atomic (not forcibly split mid-mesh),
   so a slow batch can still exceed the budget. The per-block job remains
   active until every facade/detail batch is installed in its own chunk.
   Every finished and speculative city block now shares one immutable
   base unit BoxMesh rather than allocating one BoxMesh per load.

Once the necessary blocks are loaded, obsolete chunks are **unloaded
at most one per frame**, and a focus reversal revalidates the new
predictive safety ring before removing any old collision objects.
A teleport/save restore still intentionally creates *complete* physical
and visual geometry synchronously, preserving the older game contract.
The user does not see a loading screen or a fade.

## Instrumentation

`get_streaming_stats()` keeps all existing fields and adds:

- `pending_detail_batches` — MultiMesh material batches still staged;
- `completed_detail_batches` — lifetime committed material batches;
- `pending_unloads` — obsolete chunks awaiting paced removal;
- `detail_budget_usec` — advisory scheduled upload budget, not measured
  frame time.

The existing **F3** streaming overlay and **F7** CSV telemetry continue
to show the real last/peak build work and pending blocks. F7 wall-clock
frame intervals, p95/p99 and slowest 1% FPS remain the source of hardware
validation.

## QA and limitations

`tests/predictive_streaming_smoke.gd` now checks collision-first
construction in the first speculative block, no more than eight batches
or one new block/eviction per frame, full queue drainage, immediate
collision on an unexpectedly large position jump, idempotent focus
requests and unchanged world seed.

This reduces **resource upload bursts**, but it does **not** guarantee
the full chunk's CPU-side architecture generation stays under the target
16.67 ms frame deadline. A material batch can exceed the watchdog and
Forward+ shader compilation/resource upload may span multiple frames.
Profile cold/warm Southworks driving, night lighting, traffic and
district transitions on the RTX 3060 in Windows. Review long-range
detail popping in the real game as well: the safe but visibly incomplete
future block may need distance-based invisibility staging or offline
authored asset precomputation.

Do **not** close #32 until 1080p60 and real p95/p99/1% low hardware
traces demonstrate smooth collision-safe traversal.
