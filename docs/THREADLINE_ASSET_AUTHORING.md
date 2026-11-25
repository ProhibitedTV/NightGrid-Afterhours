# Threadline fitted garment geometry pilot

Authoring-only matrix: oversized tee vs long racing jacket over racer shirt, baggy denim vs cargo pants, sneakers vs combat boots. Eight combinations share the exact protagonist base profile, with default scarf, gloves and backpack removed. The combinations are fitted as a whole because body masking and joint weights differ with clothing coverage. This is the first bounded geometry experiment, not a claim of unrestricted mesh mixing.

Run from repository root (Node 24, Python 3.11, pinned Ara package):
```bash
python tools/wardrobe/author.py list
python tools/wardrobe/author.py prepare
python tools/wardrobe/author.py build --id tee_denim_trainer
python tools/wardrobe/author.py verify --id tee_denim_trainer
```
The workflow builds all eight candidates and runs Godot import and live-rig smoke. The GLB validator checks embedded assets, joint order, hierarchy, rest transforms, inverse bind matrices, weighted attributes, expected materials and size limits. It records provenance and SHA-256, never marks a candidate reviewed. Material names are strict provisional acceptance patterns and may require reconciliation with pinned exporter output. Candidate artifacts are not published to the game automatically.

Native review: inspect body coverage, elbows, armpits, neck, waist, crotch, shoes and camera at idle, walk/run, sit, drive, aim and door interaction. Reject clipping, skin holes, misplaced footwear, animation drift, excessive memory or changed character appearance. Then decide whether to publish fitted combinations or extract shared compatible garment/body masks. No runtime inference, asset download, new skeleton or animation controller. Existing colorway wardrobe remains playable while candidates are reviewed.

Source and licensing: same pinned Ara/MakeHuman lineage as assets/models/nightgrid/courier/SOURCE.md; verify source/license for each garment before promotion. Document current source, model/profile hashes and genuine captures. No binary assets generated in this commit.
