# Horizon Commons — one scanned fern asset, 2K PBR hero pass

**Location:** fixed HORIZON COMMONS park bed, block `(3,0)` / world `(187.5, 0.20, 29.0)`.  
**Scope:** replace ONE placeholder flower patch with a real imported UV-authored botanical source; leave every tree, vehicle, other garden and save manifest as-is. This is a **photographed AAA-quality input asset and careful technical integration**, NOT a claim that all foliage in the game is AAA-ready.

## Source, legal rights and source-art provenance

- **Model:** [Poly Haven / Fern 02](https://polyhaven.com/a/fern_02) — licensed **CC0 1.0**; model by Rico Cilliers, scanning by Rob Tuytel. Poly Haven's [license](https://polyhaven.com/license) permits redistribution, including games. Original API [model files](https://api.polyhaven.com/files/fern_02).
- A verified original **2K glTF with FOUR separately authored frond meshes**, packed roughness/AO/metal material, photographed diffuse/normal textures, and original .bin geometry are committed under `assets/models/polyhaven/fern_02/`. The complete exact source URL, original file bytes and SHA-256 hashes are recorded in `SOURCE.json`.
- **Essential mask correction:** Poly Haven's downloaded glTF material requests `alphaMode: MASK`, but its diffuse is JPEG without an alpha channel. `tools/import_polyhaven_fern.py` imports the source's separate Alpha map, bakes it onto the photographed leaf atlas as real RGBA PNG and updates glTF's image URI and MIME type to PNG. Both unmodified source images remain available for audit. Without this step, Godot would show background-colored rectangular leaf cards.

## Rendering and authored asset pass

- `scripts/horizon_fern_hero.gd` instantiates the actual model from disk **once**, without re-generating leaves or multiplying it across 128 streets.
- Preserves high-resolution source UVs, normal and ORM maps. If Godot import omits a tangent array, generates it ONCE during asset initialization; applies physically lit per-pixel shading, anisotropic mipmap filtering and two-sided alpha-scissor foliage. Sunlight shadows respect the masked leaf silhouette.
- Four mesh parts; source indices total **6,232 triangles**. One instance gets an 85m visibility budget with 12m end margin; **zero** new physics colliders, dynamic lamps or per-render/physics-frame geometry generation.
- Keeps the original authored bed anchored at the same location on every world seed/reload. This does not modify gameplay, train cadence or the independent 60Hz fixed physics clock.

## Mandatory acceptance checks

`tests/hero_fern_smoke.gd` checks exact placement, one source instance, all four PBR cutout/tangent/UV mesh parts, 3k–8k triangle range, no additional dynamic lighting/collision or frame updates, existing street-tree count and immutable save manifest. Existing headless world/city/menu/export tests still apply.

The workflow `.github/workflows/capture-fern.yml` makes **two actual Godot 4.3 rendered framebuffer captures**, not generated art, at midday and dusk. The source-revision plus screenshot SHA-256 manifest is committed with the images:

- [Real daylight fern closeup](fern-review/horizon-fern-daylight-real-godot.png)
- [Real dusk fern closeup](fern-review/horizon-fern-dusk-real-godot.png)

**Final visual gates requiring physical Windows / RTX 3060 testing:** cutout quality at 0.5–5m, leaf silhouettes without rectangular cards/halos, natural PBR roughness and variation, soft directional shadows, reasonable world-scale 0.2–0.5m plant height, no sun-through frond gaps or inverted normal artifacts, no pop-in when the plant reaches 85m, and RTX 3060 1080p p95/p99 frame-time measurements. A green Linux headless build or software OpenGL capture alone **does not** establish AAA scene acceptance or achieve 60 FPS.
