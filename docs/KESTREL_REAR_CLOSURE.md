# KESTREL S6 rear-body closure — issue #31

The original KESTREL S6 had a lofted monocoque plus independent
transparent rear glass, a small rear diffuser and decorative vents.
Even when the underlying loft formally closed at its ends, the rear
cabin/trunk assembly lacked convincing solid deck/hatch topology and an
inner opaque wall behind the passenger seats. From elevated rear
camera angles the trunk could appear hollow or disconnected.

## Structural repair

`scripts/kestrel_s6_visual.gd` now models an intentionally closed,
tapered rear hatch volume with four authored longitudinal cross
sections. Each section has four perimeter corners, four connected
walls, and front/rear caps. Surfaces are triangulated with outward
normals and the same PBR paint as the primary Kestrel monocoque.
The hatch is a **real manifold mesh**, not an overlay pretending to
cover a hole.

A fixed opaque inner cargo bulkhead, parcel shelf, weather seals and
quarter-panel webs complete the visible separation between rear seats
and luggage compartment. The rear windscreen and existing four-seat
interior remain intact. This is a visual-only vehicle change: physics,
lights, speed-responsive tire rotation, motor audio, police variant
and save snapshots are left unchanged.

## Automated geometry verification

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/kestrel_rear_closure_smoke.gd
```

The regression parses actual rear hatch mesh vertices and normals,
rejects degenerate triangles, requires every quantized undirected
mesh edge to appear exactly twice, asserts outward top and rear normals,
and checks that the opaque bulkhead is present on both civilian and
police variants after a save/restore cycle.

## Remaining visual QA

Real Windows Forward+ camera orbit (rear-left, high rear, low rear,
sides, front, wet daylight and 21:30 lighting) remains necessary:
headless topology checks do not prove that glass transparency, PBR,
smoothing, deck seams, lighting and automotive proportions look
convincing. The wider #20 automotive asset redesign still calls for
professionally modeled and authored high-detail art rather than
relying on box details. Keep #31 open until rear camera captures show
the trunk is truly visually sealed.
