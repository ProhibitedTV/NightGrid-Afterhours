# Morrow Bay authored coastal perimeter — issue #34

The existing 8×8 saved city layout (`WorldPlan.GRID_RADIUS=4`, layout version 2)
remains unchanged. The original scene had an 850×850-meter concrete pad
under a ~464-meter-wide populated street grid, with streets extending to
520 m. Driving away from the final city block exposed a bare concrete
apron, followed by a visible world truncation and eventual respawn at
390 m. The far silhouette ring alone was not a navigable landscape.

## Permanent new geography

`scripts/city_perimeter.gd` is a single permanent Node3D, not a
streamed district, with four distinct authored boundaries.

| Compass side | Environment outside the final road |
| --- | --- |
| North (NORTH QUAY) | A harbor water plane, shoreline details, four projecting pier decks, pilings and cargo-crane gantries |
| West (WEST DOCKS) | Connected open harbor water, tideline, three perpendicular cargo piers and gantries |
| East (HORIZON GARDENS) | A continuous gently rising terrain mesh with fixed ridgeline variation, behind the hillside soundwall |
| South (SOUTHWORKS) | A grounded freight-yard extension, staggered industrial warehouse roofs and storage tanks behind the security wall |

The city foundation and street lengths now end at +/-245 m instead of
extending into unsupported land. The **visible** quay, sound and security
bulkheads have real 3D collision along all four sides. Crown rails,
posts and yellow road-end markings identify intentional endpoints;
vehicles cannot reach the water or unsupported outskirts by following
normal public streets. The old out-of-world respawn remains a separate
last-resort recovery for unexpected physics escapes, not the normal
boundary mechanic.

The external scenery is background-only, with no extra interactive
districts or persistent random lots. Large harbor surfaces are two
simple meshes, hills one static low-triangle mesh, and rail posts use
MultiMesh batching. The first integrated visual review also added the
original `morrow_harbor_water.gdshader` to both water surfaces: shallow
time-varying swells, an inexpensive color/ripple response and bounded
roughness variation. It uses no screen/depth reads and no runtime-generated
geometry. The final production water shader, photographed shoreline assets,
shipping details and realistic reflections remain separate art requirements.
There are **no loading transitions or per-frame procedural water meshes**
in this pass.

## Automated regression

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/coastal_perimeter_smoke.gd
```

The test covers:
- All four geographically distinct boundary regions and 36 marked
  final-road approaches;
- Explicit raycast hits against the real visible solid perimeter at
  north, south, east and west road ends;
- Water beginning outside the playable city pad rather than covering
  city streets;
- Seven port piers, southern industrial skyline elements and eastern
  terrain meshes;
- Canonical 8×8 district plan, original 112 building shells and
  unchanged saved world manifest.

## Remaining visual QA / honest limitations

This is a substantial **world-termination and environmental-layout
pass**, **not** full cinematic-quality ocean simulation or verified
photorealism. Water still uses a physically shaded but static surface;
distant buildings and cranes are geometric placeholders; surface
microdetail, terrain blending, shipping, lighting and proper harbor
weather remain to be produced with authored production-quality assets.
Verify every final road and elevated train line in actual Windows
Forward+ at midday, twilight and night. Capture genuine game screenshots
of all compass sides and a high view, and benchmark 1080p/60 on the
target RTX 3060 before closing #34 or claiming completion.

The issue remains open until actual player/vehicle QA and visual
references confirm the edge never reads as a void or a flat barrier.
