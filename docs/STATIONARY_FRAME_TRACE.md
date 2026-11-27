# Stationary frame-time investigation

Use F8 in the actual exported Windows build; capture separate fixed-position views (Synaxis ground, B1, executive, street) and matched traversal, with the same render settings, build identity and camera direction. Record each capture's scene, cold/warm state and whether the camera moves. Keep raw CSVs and accompanying vehicle sidecars.

    python tools/analyze_stationary_trace.py <F8-capture.csv>

Reports p50/p95/p99, worst interval, 1% low and hitch counts for stationary versus moving horizontal position, on foot or in a vehicle, and positive versus zero streaming build time. Uses the recorder's existing fields: no extra per-frame telemetry or profiler overhead. Half-second warmup and post-mode-change windows are excluded. Stationary means accumulated horizontal displacement <=0.10m across at least half a second, not an unmoving camera or pure GPU timing. Positive stream build is an association only. Use the existing vehicle trace analyzer for entry/exit analysis. This tool does not establish a performance improvement; native captures are still required.
