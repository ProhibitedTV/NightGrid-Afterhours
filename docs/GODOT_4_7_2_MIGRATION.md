# Godot 4.3 → 4.7.2 stable migration

**Target:** [Godot 4.7.2 stable](https://godotengine.org/article/maintenance-release-godot-4-7-2/) (released 2026-08-18). As of 2026-11-20, 4.8 is an **unstable beta** and has not been selected. The previously released NightGrid **v0.1.0-beta.3 is still a 4.3.0 game**, not automatically upgraded by this source change.

## Scope and safeguards

- Update `project.godot` feature hint and all three distinct CI/export template pins: **Project preflight**, **Windows playtest build** and **Windows beta release**. The export templates must be the **same 4.7.2** release as the editor used to import scenes and run GDScript tests.
- **Never** silently change physics engine during an engine migration. New Godot 4.6+ projects may use **Jolt**; this older save-stable game previously used **GodotPhysics3D**. Explicitly select `physics/3d/physics_engine="GodotPhysics3D"` and keep 60 Hz simulation for vehicles/cameras; Jolt adaptation should be a separately benchmarked gameplay PR.
- **Never** silently change desktop graphics API during an engine migration. New Windows projects may start in **Direct3D 12**, but all existing NightGrid beta F10 images targeted **Forward+ Vulkan**. Explicitly retain Vulkan for apples-to-apples comparisons; D3D12 / HDR output can be evaluated later with native Windows GPU traces.
- The new Godot native `Logger` class collides with a previously valid `const Logger` in our diagnostic smoke test. Rename that local preloaded alias only; game JSONL logs still write to `user://playtest-logs`.
- Keep the original **Filmic** night look as the default. With 4.7.2, F11 now cycles `filmic_baseline → sky_aces_experiment → sky_agx_experiment → filmic_baseline`. The third profile exposes **actual AgX** tonemapping with the *same* sky ambient, shadows and fog as beta.3's ACES profile so the ACES-versus-AgX comparison isolates the tone curve. No GI, SSIL, volumetric fog, HDR output or other expensive features are silently enabled.
- The F10 PNG/JSON and F7 JSONL label the active profile for a fair screenshot comparison. We keep existing v1 save manifest, collision, traffic and CityDetails streaming code intact.

## Official migration references

- [4.3 → 4.4](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.4.html)
- [4.4 → 4.5](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.5.html)
- [4.5 → 4.6](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.6.html)
- [4.6 → 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html)
- [4.7 Environment / AgX tone mapping](https://docs.godotengine.org/en/4.7/classes/class_environment.html)

The engine minor releases change some resource imports, input device IDs, physics defaults, display drivers, colour handling, and APIs. Do not interpret green headless checks as Windows visual equivalence.

## Player and release acceptance

1. On the branch / PR, run `godot --headless --path . --import --quit`, all preflight tests, and Windows x64 `--export-release`. Confirm no parse failures or unused resource references. A new smoke verifies the engine pin and three rendering profiles and restored baseline.
2. After merging, *only a successful main preflight* authorizes a tagged **beta.4** ZIP with `NightGrid-Afterhours.exe` and its matching `.pck`, SHA-256 checksum, and `BUILD-INFO.txt` saying **Godot 4.7.2**.
3. On actual Windows hardware, run the same **West Docks / Dock Watch** camera at 22:07: press Y to freeze the clock, press F10 for Filmic, F11 and F10 for ACES, F11 and F10 for AgX. Press F11 once more to return to baseline. Do not move the camera or change graphics settings between the three captures.
4. Drive the same cold and warm district loops recording F8 CSV, place F7 markers at hitches, compare p95/p99 / long frame stalls, and check the car trunk, collisions, interior exit, saves/loads, lighting pop and sound. Target 1080p/60 FPS remains **unverified** until this playtest.
5. If native crashes/graphics change, retain tagged beta.3 for regression comparison. Do not auto-ship the experimental AgX mode as the default or switch physics/rendering backend without verified data.

**What this migration does NOT accomplish:** a photorealistic city. Issue #51 still requires original glTF assets for streets, cars and buildings, better material UVs and authored lighting; switching engines is an enabling step, not a replacement for art.
