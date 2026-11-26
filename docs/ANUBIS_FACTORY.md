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

## Experimental geometry ambient occlusion

Set ANUBIS_BAKE_AO=1 to bake each LOD self-occlusion through a Cycles ambient-occlusion shader (16 samples, ray distance 8% of maximum source extent, only-local). Outputs are linear grayscale AO candidates, with coverage/range checks and recorded parameters. These are standalone maps, not automatically wired into GLBs or exported for runtime use. They are based on geometry, not luminance guesses, but cannot restore occlusion removed by decimation. Human review and explicit material integration are required. Opt-in until fixture and native asset validation complete.

## Texture budget report

Every factory run writes budgets-<size>.json, estimating per-LOD and all-LOD resident RGBA8 texture bytes including full mip chains. Provisional warning threshold 16 MiB per prop across all LODs. This is an uncompressed estimate, not measured RTX 3060 VRAM; mesh buffers, render targets, standalone AO, surface library, compression, streaming and runtime copies are excluded. Alternative versions are listed separately, never summed as a live scene. Use native Godot measurements before selecting budgets.

## Optional unified audio stage

Set ANUBIS_AUDIO_PYTHON to the existing absolute WSL voice venv Python path, ANUBIS_AUDIO_REPO to an audio checkout with the NAS overrides (defaults to this checkout), and optionally ANUBIS_SFX_CLI to the existing Stable Audio executable. Factory full/existing schedules audio after visual work while holding the factory and visual locks; smoke skips audio. No setup/download or automatic approvals: offline flags, noninteractive candidate-only speech, optional SFX CPU by default (ANUBIS_SFX_DEVICE=cuda if explicitly chosen), no auto-playtest, no changes to published paths. Missing cast approvals remain blocked. Separate audio lock, preflight of all output overrides, append-only stage logs and atomic audio-run.json under Audio/factory-001. An old audio checkout without overrides fails preflight rather than filling SSD. Existing local dist candidates are NOT migrated automatically. Independent manual audio processes must not be running; they do not honor this new lock. Existing SFX CLI may have separate cache behavior; offline flags do not prove that every backend honors them. Actual voice/SFX environment and full NAS execution pending. No model installations or paid services introduced.

## Run ledger and recovery

Every factory invocation after NAS mounting and lock acquisition creates a unique Visual/FactoryRuns/<UTC timestamp>-<random id>/run.json and per-stage logs. Atomic ledger updates distinguish pending, running, completed, failed, skipped and interrupted. Stage exit codes propagate; failures stop the sequence, leaving later stages pending. Re-run the same factory command after correcting the error: each asset tool's content-hash cache is authoritative, not a stale stage status. SIGINT/TERM mark the run failed when the shell can execute its exit trap. Hard power loss may leave a running record; never assume the old process is alive or clear locks without checking. No external scheduler or daemon. The read-only status command does not acquire the factory lock: tools\\asset_refinement\\run_factory.cmd status. It reads the latest factory ledger, not the original independent generation batch. Process success is not asset review or coverage approval. Logs contain tool output; keep them on NAS, not in Git. Startup/individual stage mount guards are not continuous network monitoring.

## Multiple visual batches and persistent queue

Requires the updated generation branch PR #475 for custom catalogs. Set ANUBIS_BATCH=visual-002 and ANUBIS_VISUAL_CATALOG to the absolute custom catalog path. The factory isolates raw, refined, material, preview and run-ledger directories by batch suffix; batch 001 retains existing paths. New material IDs still require explicit profiles. Audio remains a shared independent stage and is disabled during a visual queue to avoid repeating it for each catalog.

Queue manifest example (catalog path relative to queue file): {"schema":1,"id":"overnight-001","batches":[{"batch":"visual-001","mode":"existing"},{"batch":"visual-002","catalog":"architecture.json","mode":"full"}]}. Run from WSL with bash tools/asset_refinement/run_queue.sh /mnt/z/path/to/queue.json. Queue state lives in Visual/FactoryQueues/<id>.json; catalog hashes and plan are frozen, failed/interrupted entries retry on rerun, completed process entries are skipped. To revalidate completed entries, create a new queue ID or invoke the factory separately. No daemon or scheduled execution. Do not launch independent generator/audio tasks alongside the queue. A lock prevents two queues; the factory also locks each run. Queue completion indicates process success, not game-ready approval. Existing-mode or material-only catalogs may need individual stages disabled if no prop import/preview candidates exist.

Stage start/end ledger records now include best-effort physical Windows SSD and NAS disk-space snapshots, NVIDIA GPU name, temperature, utilization and memory when nvidia-smi is available. Missing/failed telemetry is explicitly unavailable and does not stop a production stage. These are point-in-time samples, not peaks or continuous thermal protection.

## Private local dashboard

Run `tools\\asset_refinement\\run_factory.cmd dashboard` from the refinement checkout to refresh `Z:\\NightGrid-Afterhours\\Visual\\FactoryDashboard.html`; open the HTML directly in a browser. Uses stdlib only, no server, no JavaScript, no external resources, no network listener, no credentials. Automatically refreshed at factory exit when NAS is still mounted. Includes saved per-batch concept/mesh counts, review/material/import counts, last stage status, last boundary disk free space and queue attempts. Saved reports may lag and are not revalidated by this display; absent data stays not reported. The dashboard cannot start jobs, publish assets or change approvals. Do not expose the private production share to the internet. Live refresh and authenticated hosting are not implemented.

## Integrated-checkout readiness

After #475/#476 merge, generation defaults to the same factory checkout; ANUBIS_GENERATION_REPO is only needed for an explicitly updated external checkout. The active detached generation checkout should remain untouched. Before expensive work the factory checks the mesh Python executable, exact catalog identity and known material profiles, and configured Godot version. After acquiring the generation lock, full requires every raw job to be verified complete; existing/smoke require at least one complete candidate. This is raw coverage, not downstream or release approval. A lost NAS mount prevents stage-end/exit ledger writes; a stale running ledger can remain after loss. Custom-batch status does not require its catalog path. The existing mesh venv is required even before full generation; initial model/environment installation remains a separate explicit setup/smoke operation. Native end-to-end validation pending.

## Explicit Git staging

After handoff.py creates an operator-reviewed bundle, run stage_bundle.py with --bundle <absolute bundle directory> --repo <clean dedicated review checkout root>. Default previews exact additions; add --apply only after reviewing. Requires the mesh Python environment (same dependencies as handoff). Verifies bundle identity, exact file set, hashes, review records, source metadata and prop import evidence before copying; refuses main/master, detached HEAD, dirty checkout, existing/ignored targets (git add must succeed), symlinks and oversized files. Stages only new paths under assets/art/approved/anubis; no commit, push or gameplay integration. Use a separate worktree, not a running generator. Approval manifest must use exactly schema/assets to preserve identity. Tests exercise a synthetic material bundle and actual temporary Git index. Do not run concurrent writers in the review checkout; rollback is best effort on process exceptions, not power loss.

## Stage resource guard

Each factory stage runs under a WSL process-group supervisor. Samples before launch and every 15 seconds (ANUBIS_MONITOR_INTERVAL, 5–300), checking Windows free space >=25 GiB, NAS free space >=10 GiB, and available NVIDIA GPU temperature below 85 C (ANUBIS_MAX_GPU_TEMP, 60–95). Missing disk mounts/measurements stop the stage; unavailable GPU telemetry remains unknown rather than inventing a temperature. Threshold breaches return 75 and stop only the stage process group with TERM then KILL after up to 20 seconds. The next run reuses verified outputs; an abrupt stop may leave temporary files or stale locks requiring inspection. JSONL resource samples are kept in the local visual home guard-logs, copied to each NAS run directory if mounted. No daemon, automatic restart, fan control or guaranteed thermal protection. SMB filesystem stalls can delay measurements; the supervisor is not a hardware safety mechanism. Current independent generator runs do not use this guard. Native Anubis testing remains necessary.

## Technical triage and raw throughput

Factory triage writes refined-<batch>/triage-<size>.json using verified raw inventory and refinement versions. It lists missing image/mesh work, missing refinement, raw open-mesh flags, unresolved physical height, low baked UV coverage, LOD ordering and provisional texture budget warnings. Priority is incomplete first, technical review second, other candidates third; it is not artistic ranking or automatic rejection. Every version remains separately identified. Successful raw metadata provides per-stage sample count, summed recorded job seconds, median seconds, observed peak PyTorch allocated bytes and remaining serial job-seconds estimate only with >=5 successful measurements. Estimates exclude model startup, packaging, retries, other stages and external workloads; not elapsed wall-clock or runtime VRAM. Dashboard shows median and pending raw jobs. Old ledger records display new stage as not recorded. No native run or visual quality claim.
