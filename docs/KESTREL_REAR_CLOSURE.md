# Kestrel S6 rear body and South Bus Works contact

The first #31 fix added a closed trunk to the legacy loft. Native inspection at South Bus Works showed rear headrests through the sloped glass, a gap at the window frame, and trim and lights standing away from the tail. This pass fits the authored rear in gameplay. The existing front section meets the glTF rear at body-local Z 0.77 m.

- The painted shell is a closed mesh with a wrapped hatch, curved fenders, a sealed underbody and cutouts around the existing rear wheels. A separate closed opaque bulkhead finishes the cabin behind the rear bench.
- Bonded rear glass, C-pillar rails and contoured seats fit the existing roof and doors. The rear bench has shaped cushions and two head restraints below the glass.
- The shaped lamp housings follow the curved tail. The brake and reverse guides use the car's existing brake state and signed speed. The shared materials update on state changes. The assembly adds zero dynamic lights.
- The rear reuses the NightGrid-authored micro-normal from the front fascia. Shared glTF meshes and Godot import LODs serve both street and police Kestrels. The near and reduced sources contain 4,131 and 1,911 triangles, including the glass, lights and rear seats.
- The legacy hub caps now sit just proud of the wheel face. Axle, tire, steering and collision dimensions use the existing chassis package.

## South Bus Works

The ten documented bins, posts and cargo boxes have matching static collision. The integration test drives the production car into the actual cargo stack at (85.0, 184.5). It then places the curbside door next to the stack, blocks the other door with a parked car and verifies occupancy. After the second car clears, the courier exits on the open side and regains collision.

Exit checks for ground near the door threshold and sweeps the courier capsule from the sill. The right side retains priority when clear. A blocked right door allows a left-side exit. A fully blocked exit keeps the courier seated and reports the obstruction.

## Reproduce

```text
python tools/author_kestrel_rear.py
python tools/check_kestrel_rear.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/kestrel_rear_closure_smoke.gd
godot --headless --path . --script res://tests/southworks_playtest_smoke.gd
```

Asset hashes, original-art provenance and the axle/socket coordinates are in [the rear source manifest](../assets/models/nightgrid/kestrel_s6_rear/source.json). The checker audits closed directed edges, nondegenerate faces, UVs, wheel-well clearance, lamp mounts and rear seat bounds. The Godot regression examines the imported geometry, tests coverage across the cargo deck, exercises the lamp states and checks save restoration and the police variant.

For native evidence run `tools/capture_kestrel_rear.gd` against the Windows Forward+/Vulkan game pack. Set `NIGHTGRID_KESTREL_REAR_DIR` to a new absolute folder and `NIGHTGRID_SOURCE_REVISION` to the exported SHA. `NIGHTGRID_SOUTHWORKS_CAPTURE_DIR` adds two real in-game frames to the native Southworks regression.

Creator sign-off, the complete #211 exterior, front lamps and cabin, the authored wheel assembly, weather-driven wear and fleet performance remain open.

[Native comparison and driving results](playtest/kestrel-rear-and-exit/NATIVE_REVIEW.md).
