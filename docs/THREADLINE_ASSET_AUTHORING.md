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

The offline structural gate additionally verifies every four-influence joint index and weight vector: legal joint range, finite and nonnegative weights, normalized integer encoding where applicable, and sum within 0.015 of unity. Structural acceptance is not a substitute for visual fit. No new fitted binaries are claimed by this increment.

## Native review station

After generating and importing candidates, run a real native Godot window from the repo root:

```bash
godot --path . --import --quit
godot --path . --script res://tools/wardrobe/review_station.gd -- res://assets/models/nightgrid/wardrobe_candidates/tee_denim_trainer/Morrow_Courier.glb --capture-dir=user://wardrobe-review
```

Provide additional candidate paths after `--` to cycle them with N/P. Arrow keys orbit and change the six live animation clips, B compares the original courier, +/- zooms, F10 records a genuine viewport PNG with pose and candidate ID. This isolated development scene never writes saves or installs gameplay garments. It rejects incompatible imported skin bind names, indices and poses, and the automated candidate smoke now checks actual pose existence and samples four phases per clip. Native visual review is still required; the screenshots are evidence only when actually captured. Do not publish candidate GLBs or list them for sale based solely on this harness.

## District garment collection expansion

The eight stable streetwear candidate IDs remain. Four curated review-only profiles now cover tailoring and technical fashion using existing suit and technical jacket profile keys: Vesper Meridian suit, Obscura Monolith suit, Quay Forge utility and Nocturne Afterimage utility. The first pair share the suit/tie/oxford silhouette; the second pair use technical jackets, cargo trousers and either combat boots or sneakers. The manifest associates collections with intended retailers, not runtime entitlements.

`python tools/wardrobe/author.py list --collection tailored` lists the tailored candidates. Use `prepare`, `build` or `verify` with the same collection flag. CI shards the three collections (8 / 2 / 2) independently and produces separate artifacts. Verification rejects mismatched profiles, duplicate or unsafe IDs and exceeded budgets. No GLB output or successful native import is claimed by this change.
