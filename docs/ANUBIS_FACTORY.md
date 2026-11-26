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

## Material candidate library

The factory now uses the existing mesh Python environment (NumPy and Pillow) to generate seven PNG maps per completed material reference. 24 explicit artistic profiles; crossfade tiling, reconstructed color, luminance-derived height/normal, estimated roughness, profile metallic, neutral AO packed in ORM and a separate review-only cavity estimate. Output `Visual/Materials/material-001/<candidate>/<signature>` with hash-bound manifest. No additional model, paid service or GPU allocation. These are estimated material candidates, not measured PBR, and require tile, physical scale, de-lighting, mask and native shading review. Smoke limits both mesh and material processing to one new candidate; full material target 48 sets (336 maps).

## Reviewed handoff (implemented, validation pending)

After reviewing exact candidate versions, an operator creates an approval JSON:
- schema: 1, assets: nonempty array.
- Each row: kind (prop/material), candidate, signature, manifest_sha256 (from review index), reviewer, rights_notes, review.
- Review is an object whose keys exactly match the gate names in handoff.py. Each value is {"passed": true, "evidence": "actual review reference, screenshot/frametime/import record or rights decision"}. Prop gates: visual, scale_orientation, materials, rights, godot_import, native_performance, collision. Material gates: visual, physical_scale, tile_seams, maps, rights, native_shading, native_performance. These are operator attestations, not verified external evidence. Never create them automatically. Prop height must be explicitly specified during refinement. Include collision only with include_collision: true, if suitable.

Run in the mounted WSL session using the existing mesh Python environment:

    /root/.local/share/nightgrid-visual-py311/mesh/bin/python tools/asset_refinement/handoff.py --raw /mnt/z/NightGrid-Afterhours/Visual/visual-001 --refined /mnt/z/NightGrid-Afterhours/Visual/refined-001 --materials /mnt/z/NightGrid-Afterhours/Visual/Materials/material-001 --output /mnt/z/NightGrid-Afterhours/Visual/CommitReady --approval /path/to/approved.json

The tool refuses missing gates, changed manifest/source/output hashes, unscaled props and smoke-resolution outputs. It creates a new hash-addressed bundle with repo-tree/assets/art/approved/anubis/<candidate>, runtime payload and source provenance, approval and bundle hashes. No automatic copy into checkout or commit. Default max 20 MiB per file, 100 MiB per bundle. This path is proposed for new approved assets and still requires scene integration and Git diff review. Final publication remains manual; the factory's full command cannot bypass approvals.

## Godot structural evidence

Set ANUBIS_GODOT to an absolute Linux Godot 4.7.2 executable in WSL before the factory command, or invoke godot_gate.py separately with --raw, --refined, --size, --godot and --output (refined-001/godot-1024.json). It copies one GLB at a time to an isolated temporary project and runs a bounded headless import; validates finite nonempty vertex arrays and records engine, script, manifest and file hashes. No game checkout or Godot import cache is modified. Missing executable leaves this stage pending; a failed enabled gate exits nonzero. For prop export add godot_report_sha256 (hash of matching report) to the approval row. The handoff requires exact per-file import evidence and includes a selected record. Headless Linux validation is NOT Windows Forward+/Vulkan visual/performance evidence; human review gates remain mandatory.

## Review previews

Optional ANUBIS_PREVIEWS=1 in WSL enables three neutral CPU Cycles orthographic studio views per verified LOD0, hash-bound preview manifests, and eight-asset paginated contact sheets pairing source concepts with actual refined geometry. Smoke uses 128px/four samples; full uses 256px/eight samples. Previews go to Visual/Previews; no changes to the candidate manifests. This adds CPU time and is disabled by default until tested on Anubis. These are studio renders, not Godot screenshots or quality approval. Source orientation is unresolved, so view labels describe camera directions, not semantic object fronts. CI renders a synthetic fixture.

The factory also creates a duplicate-concepts.json report using exact SHA-256 and 64-bit difference hashes (distance <=6). It compares only matching asset kinds, records both source hashes, and never deletes, rejects or chooses between variants. Similar low-detail images can be false positives.

## Experimental dense-to-LOD normal projection

Set ANUBIS_PROJECT_NORMALS=1 for selected-to-active Cycles tangent normal baking. A dense cleaned source is retained before decimation; each LOD uses its own UVs and matching normal/base-color resolution. Normal maps are Non-Color/OpenGL +Y, embedded in the GLBs with tangents and retained separately on the NAS. Relative cage extrusion 2% and ray distance 8% of maximum source extent are first-pass defaults. Coverage and vector-length checks reject obvious empty/invalid bakes, not all ray misses. Thin parts, shading seams, silhouette and projection accuracy still need visual review. Disabled by default until CI and native candidate tests pass; versions are immutable. No paid service.
