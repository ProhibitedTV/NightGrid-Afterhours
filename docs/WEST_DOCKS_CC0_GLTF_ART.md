# West Docks Dock Watch neighbor: first open-source DCC/glTF production art

**Status: implemented technical pilot pending genuine Windows visual approval.**
Permanent site: **(-4,-1), lot 1**, immediately beside existing Dock Watch Desk on lot 0.
The original published beta.5 does not include this art. Issue #51 stays open.

## Why this asset

The user requested that the next fidelity milestone reuse high-quality openly
licensed Godot-compatible assets where available, then commission/create original
assets for missing scene elements.

- **Source model:** [Poly Haven: Rollershutter Window 01](https://polyhaven.com/a/rollershutter_window_01), made by **MP**, marked **CC0 1.0**. Source page shows two photographic clean and graffitied metal shutter variants and real geometry/PBR maps; the game imports their original **glTF 2.0 mesh**, not flattened screenshots or fake BoxMeshes. [Poly Haven license](https://polyhaven.com/license).
- **Source import:** `tools/import_polyhaven_shutter.py` downloads the fixed 1K glTF and all official bin/texture dependencies from HTTPS `api.polyhaven.com`/`dl.polyhaven.org`, verifies official MD5s, size-bounds the download and writes per-file SHA-256 to `assets/models/polyhaven/rollershutter_window_01/SOURCE.json`. A one-time [restricted import workflow](../.github/workflows/pin-west-docks-shutter.yml) committed these **actual binaries** to this art branch; retail/workflow builds are **offline** and depend on committed assets, not runtime URLs.
- **Build integrity:** `tools/check_cc0_shutter.py` validates **every committed byte** against hashes, official CC0 source, texture references, both variants and normal/PBR material presence.
- **Other photographic maps already bundled:** the existing, separately audited [Poly Haven CC0 texture packs](../assets/pbr/polyhaven/SOURCE.json): **brick_wall_001**, **blue_metal_plate**, **bitumen**, each with diffuse albedo, OpenGL tangent normal and roughness at 2K. No new ambiguous or third-party paid-asset redistribution license.
- **Why not Kenney/typical Godot city packs:** those are genuinely useful CC0 sources for prototyping and gameplay; their intentionally low-poly city blocks would **not** meet the already-approved photorealistic direction. Similarly a paid repackaged CC0 library can impose separate restrictions; we import from the original Poly Haven source only.

## Changed city geometry

`scripts/west_docks_service_frontage.gd` is a fixed authored **envelope** for the existing warehouse rather than a generic block of runtime random cubes. The building has:

- Contiguous photo-PBR UV-unwrapped material-sorted front wall, closed rear wall, two continuous side elevations and a complete photographed roof surface/parapet. Correct roof X/Z, wall X/Y or Z/Y UV bases, with tangent normals for scanned materials.
- Two open service shutter bays, framed with jambs and a header; the original scanned **clean** and **graffiti** variants occupy the bays at human-scale real-world dimensions. No duplicated 3m-offset invisible side-by-side upstream preview meshes.
- Recessed genuine front glass openings with drawn reveals and separate interior backings; exterior side glazing has recessed panes/backing and avoids drawing the opaque flat whole-wall rectangle directly behind the glass.
- One service identity at a fixed world anchor. This is an actual building for the game, not a screenshot-only 3D viewer.

The original **`StaticBody3D` solid envelope and identical `BoxShape3D`** remain on this parcel, so a shutter is visually **closed** and not a new enterable doorway. The adjacent existing **Dock Watch Desk civic address, entrance, interactions, adjacent travel routes and camera** remain unchanged. Neither traffic collision nor the saved `world_seed` / parcel manifest changes. The entire original district is **not** replaced.

The building is loaded and freed only with the corresponding staged city chunk. It uses no additional dynamic lighting, physics objects or save fields.

## Validation gates

CI executes `tools/check_cc0_shutter.py`, Godot 4.7.2 clean project import, **`tests/west_docks_cc0_art_smoke.gd`**, the full legacy regression suite and Windows x64 export. The new test checks source-loaded mesh vertices, imported original PBR albedo/normal textures, two clean/graffiti variants, photographed roof/steel/brick maps, approximately human-scale bays, exact original collider count and Dock Watch address, lossless stream unload/reload and identical saved seed/manifest.

**A passing headless test or Windows export is not screenshot approval.** The art still lacks surveyed window interiors, full DCC architecture, modern layered urban clutter, LODs, architectural glass/lighting calibration and realistically proportioned premium traffic vehicles.

## Actual native art approval

On the next Windows build containing this PR, stand at **West Docks 22:07** facing Dock Watch Desk and the neighboring **PIER STORAGE / NIGHT SERVICES** garage building. Press **Y** to hold clock, **F10** for a genuine 16:9 frame of the new building beside the existing Dock Watch frontage. Do not compare with beta.5 from a different camera position.

- Day/night F10 from fixed camera; check shutter scan visible and both variant textures normal-mapped, 1K sharpness vs 2K building surfaces, and proper scale around 2.8m wide and 2.5m high.
- Close-up F10 of original glTF shutter louvers, black/clean/graffiti variation, 2K brick/metal/roof surfaces and accurately recessed glazing. Verify there is no z-fighting or invisible hole from below.
- Walk, drive and enter Dock Watch as before. F7-mark collision anomalies; F8-drive twice along that same route to capture cold and warm GPU/CPU frame-time percentiles (target 1080p/60 on RTX 3060, unverified).
- If the shutter surface faces inward or the material looks washed out, **do not** mark this art final; use the precise F10 screenshot and JSON camera pose for a targeted fix.

## Art roadmap after this pilot

1. Replace adjoining visible low-resolution façades on *this one block* with actual Blender-authored glTF using licensed PBR. Signage should identify real Morrow Bay businesses and have realistic entry depth.
2. Improve curb/sidewalk/crossing continuity, service infrastructure, realistic damp road textures and visible lighting motivation, while retaining traffic paths.
3. Replace KESTREL/traffic placeholder bodies with original UV-modeled appropriately proportioned vehicles, preserving existing wheel/steering/headlight attachment points and save data.
4. Review matching Windows real frames and measured F8 traces; only then expand the kit to neighboring lots.

No Kenney-style low-poly asset is being represented as a photoreal upgrade, and no third-party premium source/model is copied.
