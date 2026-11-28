# Morrow Bay botanical studio — coastal corporate futurism

Morrow Bay echoes the Bay Area, not tropical Miami: mature date palms in Glassline's corporate boulevards, fan palms on North Quay's waterfront, oak-like branching trees elsewhere, compact cypress-like industrial greenery, drought-tolerant agaves and ornamental grasses in premium planters. Preserve the original scanned fern at Horizon Commons. Neglected industrial districts should later receive weeds, cracked planters and wind-weathered coastal plants.

## First production lane
Original deterministic geometry; no inference, remote assets or third-party textures. Seven species, two geometry tiers each: individually modeled palm pinnae, curved folded leaves, bark rings, branch systems and color variation. These are first-pass procedural assets, not photographed trees. Bark texture, leaf atlas/detail, mature silhouette variants, convincing wind and material response remain art tasks. LOD budgets 14,000/4,000 triangles per model. Same 128 street anchors, same collision footprint, sector-batched MultiMesh rendering. Discrete LOD at 95m from batch bounds; verify transitions and total draw calls natively. No new lights or frame callbacks.

Run from the existing checkout of this branch:
```bash
python3 tools/asset_refinement/botanical_candidates.py --out /mnt/z/NightGrid-Afterhours/Visual/Botanical/coastal-001 --execute
python3 tools/asset_refinement/botanical_candidates.py --out assets/models/nightgrid/botanical --execute
```
Both generate the same deterministic bank. Source manifest records SHA-256 and per-model bounds/triangle counts. Existing mismatching directories fail closed; no overwrite. CPU-only, no GPU model or package installation. Import with Godot 4.7.2, then `--headless --path . --script res://tests/botanical_bank_smoke.gd -- --require-bank`. A normal checkout without the generated bank retains previous vegetation. Commit the original GLBs and manifest after inspection; no generated .godot cache files. Native capture at HQ approach, Glassline boulevard, North Quay, Horizon Commons and industrial outskirts, plus matched moving-route frame p95/p99 and sidewalk clearance. This is not full-city art acceptance. Separate city-detail planters, venue planters, primitive shrubs on interiors, and robotics/furniture still need a follow-up pass.
