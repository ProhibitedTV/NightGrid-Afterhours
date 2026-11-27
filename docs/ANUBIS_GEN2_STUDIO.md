# Anubis art department — Generation 2

Batch 001 proved offline generation, refinement, imports and opt-in integration. The first studio/native comparisons also reveal a limitation: single-view reconstructed engineering props can have a plausible front but fragmented or distorted sides. More triangles do not solve incorrect geometry.

## Production tracks

- **Engineered hard surfaces:** dimensioned original offline geometry, explicitly modeled openings, seams and hardware, source-bound photo PBR, deterministic LODs. Start with the rejected Brickwater grate, then copier/IT equipment, elevator panels and storefront fittings.
- **Organic/irregular props:** retain image-to-3D candidates for shapes that benefit from it. Add consistent multi-angle references and evaluate a local multiview backend separately; no backend is selected or installed by this PR.
- **Characters:** continue Ara/MakeHuman rig-aware authoring and animation review. Never use static prop decimation on weighted humans.
- **Materials:** reuse licensed photo scans where appropriate, validate physical scale and tile seams; derived image-only estimates remain provisional.
- **Complete-place integration:** preserve routes, missions and stable anchors. Native matched Windows views and RTX 3060 measurements determine acceptance, not candidate counts.

## First hard-surface pilot — Brickwater cast drain

From a separate updated checkout, after verifying the NAS mount:

    python3 tools/asset_refinement/gen2_grate.py --out /mnt/z/NightGrid-Afterhours/Visual/Gen2/brickwater-grate-001

This builds three self-contained GLBs with a real rectangular hollow frame, thirteen cast ribs, fourteen open slots, two below-grade supports and higher-LOD fasteners. LOD2 retains the same apertures and envelope. It embeds the existing Poly Haven CC0 steel color, normal and ORM maps, hash-checked against their repository source notice, with provisional cast-iron tint. No model weights, network calls, GPU, Blender installation or third-party package needed. Original geometry is meter-scale, with Y=0 grade, width .48m, length .72m and depth .065m; these are **proposed dimensions**, not a measurement of the existing scene or a load-rated drainage product. The mesh components overlap at joints; they are not boolean-unioned.

The candidate manifest hashes the GLBs, source and texture inputs. Output is separate from game checkout and never overwritten intentionally. No collision is generated: keep the existing walkable floor and steam effects unchanged. The Gen2 format is deliberately separate from Gen1 raw reconstruction manifests; do not fabricate SDXL/TripoSR provenance or bypass the handoff gate.

Before promotion: measure the existing drain footprint, inspect six angles and material under wet/dry lighting, import all LODs in Godot, compare close and street-eye captures in Brickwater, check floor clipping, steam alignment, pedestrian traversal, legacy saves and RTX 3060 timing. Placement, material suitability and native acceptance remain outstanding. Do not claim AAA fidelity from procedural geometry alone.
