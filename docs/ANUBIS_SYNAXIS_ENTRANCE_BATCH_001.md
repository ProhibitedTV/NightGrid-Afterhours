# Synaxis entrance art batch 001

Refs #532, #534. Run locally on Anubis, not in CI. Read docs/ANUBIS_GEN2_STUDIO.md and tools/asset_refinement/gen2_synaxis_architecture.py. Preserve unfinished creator lighting work. Use a separate checkout or private output directory.

## Operator commands (WSL bash)
Verify NAS mount and free space, Blender and Ollama availability. Select an installed coding model from ollama list. The following generates a candidate script only; inspect it before executing, preferably in an isolated offline environment with no private mounts.

```bash
ollama list
blender --version
findmnt /mnt/z
mkdir -p "$HOME/nightgrid-art/synaxis-entrance-art-batch-001"
cd "$HOME/nightgrid-art/synaxis-entrance-art-batch-001"
# Set MODEL to an installed model from ollama list.
ollama run "$MODEL" < /path/to/checkout/tools/asset_refinement/synaxis_entrance_batch_001_prompt.txt > candidate.py
```

Remove markdown fences if the model ignored instructions; review source manually. Do not automatically execute untrusted generated code. After review, run Blender in an isolated environment with only the candidate and writable output exposed:
```bash
mkdir -p output
blender -b --factory-startup --disable-autoexec --python-exit-code 1 --python candidate.py -- "$PWD/output"
```

## Acceptance
Four separate GLBs, source blends, named gate leaves and reader indicator, measured bounds and pivots, six-angle renders, original badge artwork, material/triangle/texture inventory, source/model/version/hash provenance. Inspect all angles and reject malformed candidates. Stage approved files and hashes in a new NAS folder Visual/Gen2/synaxis-entrance-art-batch-001 only after confirming mount and no existing output. Never automatically copy into game assets. Native Godot integration and visual acceptance separate. Proposed dimensions require scene survey. No automated local model execution or validated outputs yet.
