# One-command Anubis factory (incremental implementation)

Use free tools, local compute whenever possible, NAS-backed output and eventually a commit-ready reviewed handoff. No paid API, no inference at gameplay runtime, no automatic promotion of unreviewed output.

The site launcher assumes existing Windows Z: mapping and Ubuntu WSL, Python 3.11 and already installed visual model environments, generation checkout sibling NightGrid-Visual with ANUBIS_VISUAL_OUT support, and Blender plus python3-numpy. It does not modify the generation checkout. Finish the current production run first.

    cd /d "%USERPROFILE%\Desktop\NightGrid-Refine"
    tools\asset_refinement\run_factory.cmd smoke

Smoke processes at most one new candidate at 128/64/64 resolution. Review its output and test native imports. Then:

    tools\asset_refinement\run_factory.cmd existing

Processes existing complete mesh candidates at 1024/512/256. To run generation -> refinement -> bake -> review index:

    tools\asset_refinement\run_factory.cmd full

Existing generation lock, independent factory lock, mount check, startup physical SSD/NAS reserve checks, per-candidate NAS reserve, immutable hash-addressed results. Startup SSD reserve is not continuous monitoring. A failed generation stops full mode; failed candidates remain available for inspection and retries. No automatic package installs in the factory launcher itself; the existing generator can download models on first setup. Do not change active checkout or clear locks mid-run.

Outputs under Z:\NightGrid-Afterhours\Visual:
- visual-001: original concepts, mesh candidates and manifests.
- refined-001: refined GLBs, baked basecolor PNGs, collision proxies, per-version manifest.
- refined-001\review-1024.json: source-matched, hash-verified review candidates and explicit pending/invalid statuses. All matching versions are presented rather than silently choosing a winner.

The review index is not a publication manifest. Commit-ready export remains a future stage: explicit selected version and hash, measured dimensions/orientation, reviewed PBR/rights/collision, native Godot import and real Forward+ screenshots/frametimes, approved paths, isolated staging diff and repository size budgets. No auto-commit to main. Retain raw models and rejected variants on NAS, only approved optimized outputs and required provenance in Git. Future PBR backend must have reviewed code/weight/output rights and run without metered cloud services; base-color bake is not a substitute for normal/roughness/metallic/AO maps.
