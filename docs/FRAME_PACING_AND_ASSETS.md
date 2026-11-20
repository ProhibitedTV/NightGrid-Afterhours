# NightGrid quality pass — fixed simulation and real asset gate

**Status:** Code-level frame-pacing change and authentic screenshot recapture workflow; **not** a GPU benchmark or AAA acceptance.

## Godot 4.3 timing contract

- `physics/common/physics_ticks_per_second=60`: player/car/traffic physics and rail simulation use a 16.667ms fixed clock. Mission triggers, damage and heat/cooldown timers now advance in `world._physics_process`.
- `application/run/max_fps=0`: rendering is **not hard-capped** by the physics frequency. The game still honors the player's VSync preference. A 60 FPS quality target is not a 60 FPS hard cap.
- **Godot 4.3 has no native 3D interpolation:** the train's gameplay transform remains authoritative while its display child interpolates between its last/current physics-tick positions via `Engine.get_physics_interpolation_fraction()`. On teleport or saved-state restore, rendering history resets. Collision, station boarding and save data never read the interpolated visual child.
- City streaming, lighting, venue/civic proximity and HUD strings refresh at 10Hz rather than once per rendered frame. At 36m/s this permits up to ~3.6m focus lag; validate this on a high-speed playtest. Camera smoothing and look input remain render-rate responsive.
- `tests/frame_pacing_smoke.gd` runs the same 240 physics ticks with one versus four render callbacks per physics tick, then compares the resulting station, speed, dwell and position state. The test also validates reload/teleport reset. **It cannot measure frame rate.**

## 60 FPS acceptance on RTX 3060 12GB

At **1920×1080**, the target is **≤16.67ms/frame** with p95/p99, 1% lows and a representative 60-second traversal—not merely an average FPS readout. On the Windows build use actual **Forward+/Vulkan**. Test Central Exchange at daylight, rainy dusk and midnight; walk/drive through architecture and traffic, then enter/exit clubs, use public transit and restore saves. Record CPU main/render-thread and GPU frametimes independently. Isolate SSR, SSAO, volumetric atmosphere, shadow cost and texture streaming to identify causes of stalls. Never claim 1080p60 without data.

## Quality-first asset acceptance

1. **Use authored asset files instead of runtime cosmetic geometry where possible.** Package original or properly licensed DCC source, glTF meshes with sensible LODs, UV-mapped PBR albedo/normal/roughness/metallic/AO and texture/source/license metadata. The current photographed Poly Haven CC0 sets already satisfy the texture provenance portion for two pilot façades, but not the complete art quality gate.
2. Finish one existing Morrow Bay location at a time: structural depth, real window openings, glazing, stairs, curb continuity, architecture silhouette, grounded lighting and appropriate nightlife props. High-distance variants should use HLOD, atlas or instance batching/culling **without** lowering the close-range fidelity target to cubes.
3. Keep detailed *visual* geometry separate from stable simplified *physics*. Preserve current building lot IDs, traffic paths, interactable doors, camera collision contracts and v1 save manifests.
4. Review **real Godot framebuffer captures**, not concept images or generated art. CI currently captures 1280×720 software Mesa OpenGL Compatibility and cannot certify Windows Forward+ reflections, final realism or performance.

## Screenshot promotion

`.github/workflows/capture-screenshots.yml` now reacts to game source or asset changes on the designated AAA feature branch. It instantiates the playable world, captures seven true images, validates them, writes a manifest containing the source commit and image SHA-256 hashes, and commits updated PNGs on the feature branch. The first frame points at real Central Exchange PBR architecture rather than the obsolete generic street angle. A successful CI recapture proves *provenance*, not final AAA visual quality.
