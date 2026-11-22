# Production-scale urban asset library

Approved Brickwater concept is the art target (#134, #144–#152). Reuse existing imported resources before acquiring new files. The catalog is `tools/urban_asset_catalog.json`: 10 reusable resource families, 14 additional named model candidates and 6 material candidates; the 39-entry Hidden Alley collection offers further discovery. Candidate does not mean imported or native-approved. Exact publisher asset IDs/files and available LODs must be validated before ingestion. Poly Haven CC0 permits redistribution (https://polyhaven.com/license); ambientCG CC0 assets can also be redistributed (https://ambientcg.com/). Preserve upstream source manifests with per-file hashes and credits, plus derived asset recipes. No paid marketplace packs or third-party game rips.

## Intake stages

1. Curate by role and target district, deduplicate against current glTF and texture hashes.
2. Acquire the smallest sufficient available LOD/1K maps for street clutter, 2K for close hero surfaces. Prefer glTF with external buffers and only required texture dependencies. No duplicate Blender scene, preview models, DX normals, unused 8K textures or source ZIPs in shipped game.
3. Check metric bounds, pivot, winding, opaque/alpha material settings, GL normals, packed roughness/metallic channels, texture paths and licensing. Use existing source assets without mutation; create derived variants separately with recorded lineage.
4. Create reusable scenes with appropriate collision class, mounting and interaction. Use shared meshes/materials and spatial batches, near/far LOD and memory limits; static prop scene instances must not become separate texture copies. Author missing pieces around the actual setting.
5. Inspect actual in-engine screenshots and native walking/driving interactions, log frame-time/VRAM. Import-only or preview-only assets do not satisfy the conversion. No runtime downloads.

Start with a first production batch of 14 model candidates and 6 material candidates. Grow toward 100–160 environment mesh families, 35–60 shared material families across the city (planning scope, not a quota or performance guarantee). Character art/rig #132 is separate. Prefer many reusable families with meaningful variants instead of a single gigantic pack. Track imported vs integrated vs native-accepted. Use issue #147 as prop production backlog, #145 material backlog, #148 utilities, #149 signage and #150 lighting. #152 is final native reference gate.
