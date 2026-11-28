# Full creator character bank

The creator approved use of all 24 generated candidates on 2026-11-27, with replacement of primitive NPCs as the priority. This is **private playtest art acceptance**, not an assertion of commercial redistribution clearance. The NAS originals stay unchanged. Do not commit the staged GLBs or their imported images.

Stage from the existing checkout (no clone needed):

```bash
python3 tools/asset_refinement/stage_character_bank.py --source /mnt/z/NightGrid-Afterhours/Characters/postmusic-001
```

The stage command verifies all 24 candidate manifests, exact profiles, embedded geometry and SHA-256 before copying any files. The local ignored bank contains all 24 original GLBs and bank.json; Godot imports the scenes natively. On a clean source checkout the optional bank is absent and existing assets remain available. Use Godot 4.7.2 import then run:

```
godot --headless --path . --script res://tests/character_bank_smoke.gd -- --require-bank
```

The opening cinematic retains its authored four-lead pose and prop adapter using the new bank where available. Other office actors and workfloor workers use the role-selected bank, with provisional skeletal seated posing for rigs without authored seated animations. Café patrons, Mara and Lin use the bank. Street pool keeps the 12-active cap and six existing logical style classes with two distinct rig slots each. Source and runtime checks are necessary but not visual approval. Capture each floor, seating fit, reception/security badges, hand props and animation, city crowd variety and 1080p frame pacing before packaging. New named identities, appropriate uniforms, nonrepeating seated workers, musicians and remaining procedural actor paths require additional production and regression checks; no claim of zero placeholders until measured.
