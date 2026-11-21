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
