# Brickwater CC0 production intake

Related #134, #144, #147, #148, #150 and native gate #152. Independent from draft #143 to avoid touching its active scene or catalog. The nine additions in `tools/brickwater_cc0_intake.json` were checked against official publisher CC0 pages on Nov 21, 2026. They are source-verified **candidates**, not integrated assets. Trashbag overlaps the earlier catalog intentionally: this is its acquisition queue, not another copy.

| Batch | Candidate | Placement intent |
|---|---|---|
| architecture | [modular_urban_apartments_facade](https://polyhaven.com/a/modular_urban_apartments_facade) | Select individual window/door modules; adapt to stable parcel dimensions; weather and age clean surfaces. |
| architecture | [modular_fire_escape](https://polyhaven.com/a/modular_fire_escape) | Select ladder, landing and stair modules; attach to real wall/door anchors. |
| utilities | [modular_electric_cables](https://polyhaven.com/a/modular_electric_cables) | Select junctions and clips; author sagging span between actual anchors. |
| utilities | [modular_pipes](https://polyhaven.com/a/modular_pipes) | Use risers, elbows and clamps rather than duplicating whole kit. |
| utilities | [industrial_caged_sconce](https://polyhaven.com/a/industrial_caged_sconce) | Use housing and emissive glass; shared bounded lights only. |
| clutter | [trashbag](https://polyhaven.com/a/trashbag) | Place by existing bin; classify soft/movable. |
| clutter | [cardboard_box_01](https://polyhaven.com/a/cardboard_box_01) | Select worn package; simple convex breakable proxy later. |
| clutter | [plastic_crate_01](https://polyhaven.com/a/plastic_crate_01) | Stack reusable crate variants; keep clear passage. |
| clutter | [hand_truck](https://polyhaven.com/a/hand_truck) | Park at service doorway; bounded movable proxy. |

## Acquire, not automatically install

`python tools/intake_brickwater_cc0.py --batch clutter --out /tmp/brickwater-clutter` (also use architecture or utilities). GitHub workflow runs each independently and uploads verified staging packages; no repository write permission, no runtime downloads, no scene changes. A missing file, missing publisher checksum or oversized package fails the batch instead of claiming acquisition. Packages include source metadata and exact SHA256 per file. Only dependencies referenced by glTF are acquired; no 8K textures, Blender files, preview images or DX normals.

Reuse existing exterior_aircon_unit, utility_box_01, metal_trash_can and rollershutter_window_01 without reinserting them. The large modular facade is a source library, **not** a 51.5 m building to import intact. Split by module, check UV scale, material sharing, correct pivots, wall thickness and clearance, and re-export only needed modules with derived provenance. Source triangle counts are approximate publisher figures, not a final per-instance budget. Prefer 1K maps initially; selectively upgrade a visible hero surface only after review. For crates, trash and carts use explicit solid/movable/breakable proxies; fixtures must terminate at wall supports, never float. Preserve parcel (-2,1), saves, collision and path access. No new gameplay light per fixture.

## Handoff and acceptance

1. Inspect acquisition logs and manifests; failed batch is not a delivered asset.
2. Compare meshes and hashes against existing inventory. Review license and inspect source GLTF in DCC/Godot; strip unused variants; add LODs and bounded shared materials.
3. Commit only selected game-ready files and manifest(s), separate from download tooling. Integrate one permanent Brickwater alley first. No whole-pack instancing.
4. Native Windows Forward+ same-camera 22:06/day review, collision checks and F8 frametimes on RTX 3060 class; do not equate headless import or concept art with fidelity.

Original scene not changed in this PR. No source binaries are committed by this intake change. Follow #152 for actual fidelity acceptance.
