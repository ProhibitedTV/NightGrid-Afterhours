# Sidewalk population foundation
Part of #84. Pure data model, not yet live pedestrians. Candidate links
follow the existing parcel-sidewalk 19.3m offset, stay away from corners,
and deliberately do not cross roads. The candidates are not verified
walkable: props, hero architecture and collision can obstruct them.
Supply a curated subset to configure; do not treat all generated candidates
as a finished pedestrian network. Up to 128 logical agents, 12 proposed active,
two changes per planning cycle. Stable IDs, background out-and-back walking
phase, active handoff projection and JSON-safe phase persistence.

## Integration for Codex
1. Certify whole candidate links against loaded ground, pedestrian capsule
   clearance and actual authored obstacles. Add explicit safe links around
   props and signal-aware crossings separately. No walking through walls.
2. Use one pool/director; spawn only with actual camera visibility and collision
   readiness checks. Fail closed on missing checks. Capture live phase on
   release. Never use always-true fixture callbacks in the game.
3. Add original or license-verified rigged assets and walk/idle transitions;
   avoid mesh creation per frame. Only live visible bodies may be submitted
   to existing Wanted.witnesses with actual position, facing and RID. Never
   submit abstract agents or create player heat directly. Test occlusion.
4. Keep fixed game behavior until a native A/B run confirms no popping,
   valid sidewalks and bounded CPU/GPU costs. Coordinate #32/#83/#95. No
   native visual or performance claim from this standalone model.

## Route certification pilot (part of #98)
`SidewalkCertification.evaluate(city, space, entry)` returns PENDING, CLEAR or BLOCKED; advance the same candidate on successive physics ticks until decided. One job at a time, at most eight supporting-ground rays per tick plus final endpoint overlaps and continuous capsule sweep. No synchronous chunk load. Restricted to straight existing parcel-side sidewalk strips; no crosswalks. Cache is bounded and short-lived, invalidated by city load/unload counters or city identity. `cached_clear` is a predicate for the streaming planner, not permanent permission; recheck actual spawn clearance and use CharacterBody movement collision. The probe uses layer 1 physical geometry and rejects interrupted support and large height changes; it cannot certify visual-only props or future moving obstacles. The smoke uses real physics fixtures rather than claiming every native street is walkable. District-round-robin population selection covers all eight districts under the cap. Remaining: native candidate audit, visual-only props and curated obstacle detours, integration with pooled NPCs, verification of actual foot height and route continuity. Existing live game unchanged.

## Bounded scheduling for the pedestrian director
Call `advance_candidates(city, space, entries)` once per physics tick with a local priority-ordered list (at most 256 entries considered). It returns an empty dictionary when no work is due, or an ID and PENDING/CLEAR/BLOCKED status for the one evaluated link. An unfinished job stays pinned across distance-priority changes while relevant; when it is no longer in the supplied set, it is discarded. Fresh CLEAR and BLOCKED results are skipped until expiry or city revision invalidation. Use `cached_clear` separately in the real spawn guard; never treat PENDING as permission. This scheduling API does not instantiate pedestrians, change existing world behavior, or certify untested native streets.
