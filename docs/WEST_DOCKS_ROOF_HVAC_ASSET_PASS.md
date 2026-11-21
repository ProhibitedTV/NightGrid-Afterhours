# West Docks — production asset pass: photographed rooftop HVAC + original steel saddles

**Status:** integrated art milestone / native Godot visual inspection still outstanding.  
**Address:** Dock Watch block `(-4,-1)`, **lot 1** (PIER STORAGE / NIGHT SERVICES), behind the existing public sidewalk/road.  
**Parent:** [#51](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/51). Reuse the unchanged photographed service frontage and closed original collision shells.

## Open-source model imported

**Poly Haven — Exterior Aircon Unit**, creator **Monsta3D**, distributed under **CC0 1.0**:
- [Original asset](https://polyhaven.com/a/exterior_aircon_unit)
- [Official unrestricted CC0 license](https://polyhaven.com/license)
- **Source format:** upstream original 1K glTF 2.0 plus `.bin` and textured PBR dependencies (not generated substitutes).
- **Two source versions:** intact/clean and weathered/rusty. The original glTF carries two source mesh nodes with two material surfaces each, retaining their native color, normal, and metallic/roughness maps.
- **Offline-pinned** 14 verified upstream source files, ~7.67 MB total, in `assets/models/polyhaven/exterior_aircon_unit/`. Every file has its original URL, official MD5, SHA-256 and size recorded in `SOURCE.json`. Import is restricted to official Poly Haven HTTPS hosts and the temporary named art branch. Normal gameplay and CI do not download any assets.
- **Source integrity gate:** `tools/check_cc0_aircon.py` verifies the 14 files, original model mesh/UV/normal contracts and all photo PBR material bindings.

This is licensed *source geometry*, not a low-poly mockup or a screenshot of the model.

## Original authored geometry and placement

`scripts/west_docks_hvac_roof_kit.gd` is a dedicated, fixed installation loaded only as part of the existing `WestDocksServiceFrontage` city chunk:

- Two 2.2×-scaled rooftop aircon variants on the building's photographed bitumen roof, each with its own visible imported model. Offset positions on the roof are fixed at x = -3.1 m and +3.1 m, several meters behind the front parapet. Unused upstream comparison duplicates remain hidden, not overlapped.
- Four original **UV-mapped 0.20×0.15 m I-section mounting rails**, individually extruded from 12-point flange/web profiles, with proper caps, triangle normals and tangent bases. They use the **already committed** Poly Haven CC0 **2K blue_metal_plate** photographic albedo, normal and roughness. No new generic BoxMesh façade panels.
- All units and mounts stay inside the existing warehouse footprint and above public headroom. This is visual art only: no additional collision bodies, local lights, traffic blockers, gameplay state, or save fields. Existing street-level CC0 dual roller shutters remain installed.

This pass adds photographed rooftop servicing identity; it does **not** make the whole district or its cars photorealistic.

## Automation and release QA

The unchanged project still targets Godot **4.7.2**, Forward+ Vulkan and fixed **60 Hz physics**. CI runs:

```bash
python tools/check_cc0_aircon.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/west_docks_roof_hvac_smoke.gd
godot --headless --path . --script res://tests/west_docks_cc0_art_smoke.gd
```

The new integration test verifies both PBR scan variants, the original UV/tangent steel mounts, their roof-relative position, retained Dock Watch civic frontage, unchanged two building shell colliders, deterministic chunk unload/reload and untouched world seed/manifest.

### Native Windows acceptance (required before visual sign-off)

1. Take **actual F10 Godot frames** at Dock Watch 22:07 and at midday, from the same street-level camera and a second higher camera angle. Compare to beta.6. The equipment must silhouette against the sky, align with the roof, and have believable scale/roughness.
2. Look closely at imported HVAC fans/grilles and rusted/clean PBR normals, roof saddle contact, two shutter bays and the service facade. Check for floating units, inverted normals, excessive density, texture mip shimmering and obvious tiling.
3. Walk, enter Dock Watch, drive under the elevated infrastructure and return. Confirm the original H/interior exit, camera clearance and road/rail behavior.
4. Capture two **F8 CSV** driving runs for cold/warm data; record F7 markers on any stutter or render pop. Measure p95/p99 and 1% lows on RTX 3060 12 GB at 1080p. **60 FPS is a target, not a benchmark claimed by headless CI.**

The next art pass after this roofline should replace the adjacent generic warehouse envelope and surrounding underpass/curb infrastructure with original authored UV geometry and more verified CC0 source models; vehicles remain a separate major fidelity issue. Never substitute concept art for actual README gameplay captures.
