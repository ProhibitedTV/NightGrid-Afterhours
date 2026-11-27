# Synaxis entrance production contract

Issue #532. Related #439, #441, #447, #460, #448; preserve merged #531 and unfinished local lighting work.

## Spatial program
Street approach → covered forecourt → automatic outer door → weather vestibule → inner door → public reception/security → employee optical gates → secure lobby. Provide a wider accessible lane and independent safe egress. Survey parcel and existing collision before changing dimensions. Use real HQ architectural references and commercial gate/door documentation; record sources and dimensions before modeling. No reference imagery is claimed as game evidence.

## Opening shot contract
| Shot | Nominal duration | Camera | Action |
|---|---:|---|---|
| Exterior | 4 s | Cinematic establishing | Tower, branding, morning arrivals |
| Approach | 4 s | Cinematic tracking | Protagonist joins employee circulation |
| Vestibule | 2 s | Fixed physical CCTV | Brief understated surveillance insert |
| Credential | 3 s | Cinematic close-up | Badge presented, authorization, gate begins opening |
| Lobby | 4 s | Cinematic wide | Protagonist crosses gate |
| Handoff | 3 s | Gameplay transition | Camera settles, objective and control restored |

Timing is provisional; native animation and footage determine final pacing. At most two short surveillance inserts; no persistent CCTV filter. Match physical camera mount and lens; restrained timestamp and camera ID. Offboarding may echo the vestibule angle, with revoked credentials and unobstructed egress.

## Integration contract
Use existing mission director and cinematic lifecycle; no parallel progression authority. Badge authorization is a presentation of current employment/access state, not a new independent save flag. Drive reader light, chime and gate animation from the same authorization event. Skip must reach the same valid terminal state as natural playback; cancellation/reset must release camera, input and audio ownership. Do not gate emergency egress on employment status. Avoid duplicate reward or objective advancement. Preserve keyboard/controller pause.

## Production lanes
- Architecture: measured modular GLB assemblies, PBR, doors, gates, reception, camera mounts, collision and sightlines.
- Character: badge mesh and deterministic artwork, attachment/hand IK, employee and guard performances.
- Cinematic: authored cameras and cut timing, one brief CCTV insert, smooth handoff, offboarding callback.
- Audio: offline door, gate, reader, footsteps and ambience, synchronized cues.
- QA: native Windows package, matched captures, natural/skip/reset regression, traversal, full Chapter One, cold/warm RTX 3060 frame times.

## Evidence gates
No production acceptance from graybox or headless checks alone. Record source hashes/licenses, native screenshots and opening/offboarding footage, exact revision, p50/p95/p99, pipeline counters and interactive traversal. Preserve private assets and local lighting work. No public release or forced merge. Creator visual acceptance remains separate from CI.
