# KESTREL S6 — the second NightGrid hero asset

**Art target:** hyper-realistic material and engineering cues, stylized cyberpunk futurism. The Kestrel S6 is an original, four-seat civilian electric fastback that establishes the vehicle language of Morrow Bay: a familiar, mechanically coherent profile with copper surface reveals, purposeful lighting and futuristic city hardware.

## Implemented production-style systems

| Area | Implemented | Still needed for production AAA |
|---|---|---|
| Outer form | Original lofted and beveled 3D monocoque with eight longitudinal sections; trim, vent ducts, rocker beams, diffuser, hood stampings and body joint details | Sculpted panels with wheel-arch cutouts and custom LOD meshes, UV-unwrapped texture atlas |
| Surface treatments | Clearcoat metallic paint, graphite rubber, physically grounded alloy, tinted transparent roof and windshield glass; paint colors survive seeded world variations | Authored multilayer material atlases, clearcoat validation, dirt/age wear masks, custom normal/roughness textures |
| Cabin | Four articulated silhouette seats, headrests, steering column, central console and luminous HUD/instrument blade | Complete interactive interior and dashboard, NPC/driver animation, mirrors and instrument telemetry |
| Running gear | Four detailed tire/alloy assemblies, suspension arms and underbody EV battery shield; wheels spin with signed physical velocity and steering pivots obey player input | Correct tire tread, rim topology, steering linkages, suspension travel and full vehicle rig |
| Exterior lighting | Two projected white lamps; cyan DRL, rear red lamps, dynamic brake and reverse lights, amber mirror repeaters | Street-legal photometric calibration, blinking indicator controls, weather-dependent light behavior |
| Driving sound | Original cached synthesized EV motor/road sound, pitch and volume following speed | Multi-sample professional sound design, responsive tire/traction and collision audio |
| Police trim | Original emergency rooftop bar, alternating red/blue lights, steel pushbar on the same chassis and driving logic | Accurate patrol lighting and siren behavior |
| Performance | Lights are emitted only by occupied cars or pursuing officers; static cars do not allocate per-frame meshes; shared material maps reused | Benchmark at 1080p/60 on actual RTX 3060, LOD and light range tuning |

## Integration and compatibility

- **One reusable hero model** is attached to all 12 save-indexed parked cars and dynamically spawned police pursuit cars.
- The character controller and original `2.35 × 1.65 × 4.7` collision box, arcade acceleration/steering, vehicle occupancy, repair/condition, heat and existing JSON save format remain **unchanged**.
- **No textures, third-party art or sound files were imported.** The motor tone and rolling sounds are generated once in source-owned GDScript.
- The visual component's `update_motion(speed, steering, braking, occupied, police, delta)` is called after the existing physics body moves. It does **not** own, simulate or save a second vehicle.
- New `tests/hero_vehicle_smoke.gd` checks geometry, transparent windows, four-seat cabin, wheel assemblies, brake/reverse and active headlight behavior, patrol trim, audio and a save/restore roundtrip. It runs in the GitHub Actions preflight pipeline.

## Visual acceptance protocol

1. At 12:00 and 00:00, photograph each car from a 3/4 exterior at 3–5 m, side profile, cockpit close-up and rear bumper.
2. Verify **glass rendering from both sides**, paint highlight shape, absence of inverted normals on the lofted body and clipping of all four moving wheels.
3. Drive forward, brake, reverse and steer in-game; watch wheel movement, brake lamps, reverse lights and active headlight beams. Test police pursuit for alternating emergency lamps.
4. Reload a game with the car occupied and a damaged vehicle to verify exact saved position/yaw/condition and rebuilding of all visuals.
5. Use the real Godot Forward+ renderer on a supported GPU for screenshots. The GitHub headless suite validates code and scene structure, **not final artistic quality or FPS**.

## Next slice

Use this vehicle art language to build a detailed street intersection as a complete environmental hero scene: actual drainage, curbs, paint wear, crosswalk tactile ramps, traffic signal poles, signage, and motivated lighting. Then tackle a fully furnished, inhabited café.
