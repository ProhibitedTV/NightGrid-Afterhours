# Anubis Visual Studio — Batch 001 (candidate-only)

Extends #175 and #474. Start from a Windows CMD prompt in the repository root.
Requires WSL2 Ubuntu (default distro), Python 3.11+ with venv support, git, flock, WSL-visible NVIDIA driver/CUDA, network for first dependency/model acquisition, and ample disk/RAM. No sudo in runner. If Python venv is missing install python3-venv in WSL. Reserve at least 40 GiB on the WSL volume and 10 GiB on the repo drive; actual use depends on cache and output. Close other GPU workloads. First run downloads weights/dependencies; subsequent cached generation is local. No API key required for these public models.

    tools\visual_studio\run_anubis_visual.cmd plan
    tools\visual_studio\run_anubis_visual.cmd smoke
    tools\visual_studio\run_anubis_visual.cmd full

Smoke produces one prop image + mesh and one material reference. Full includes smoke jobs and resumes by job metadata and SHA256. Interrupt with Ctrl+C and re-run full. The script returns nonzero on incomplete requested jobs; read image-errors.log and mesh-errors.log. Run status or pack to inspect/rebuild handoff without loading models. Each successful stage writes metadata atomically; no approval implied.

Output: dist/anubis-visual/visual-001/candidates/<id>.v<n>/concept.png, image.json, optional mesh.glb and mesh.json. Inventory: inventory.json. Portable handoff: handoff/index.json and numbered ZIPs (75 MiB uncompressed target, single oversized candidate stays intact). Attach the index and packs to ChatGPT or transfer to a separate review workflow; do not git add dist. A pack contains complete candidate folders and SHA256 metadata. No files are published into assets or committed automatically. Model cache/envs are in ~/.local/share/nightgrid-visual-v1; override ANUBIS_VISUAL_HOME in WSL if needed. Do not remove active caches while running.

SDXL base fp16 + CPU model offload is the conservative first image backend; SDXL Open RAIL++-M has usage restrictions. TripoSR is MIT (code and checkpoint); source commit pinned, model revisions locked at first acquisition, package versions recorded in environment freezes. DINO config and U2Net weights are hashed, not blanket license-approved. TripoSR emits **vertex-colored raw geometry**, not calibrated PBR, retopology, correct axes/metre scale, collision or LODs. Material images are references, not seamless or validated PBR maps. The CPU marching-cubes adapter avoids compiling a CUDA extension; it requires native comparison against upstream. No asset is licensed or visually accepted by this generator alone. No model files ship in the game. TripoSG, ComfyUI, Blender processing and actual in-engine review remain follow-ups.

After smoke: review actual mesh from several angles, check segmentation, GPU peak, source terms, orientation and material response. Compare native models with authored/CC0 equivalents before accepting. Process selected candidates through Asset Forge (#176–185), including UV/PBR, LOD, collision, actual native Windows screenshot and profiling. Preserve existing world geometry and gameplay. This tooling-only branch does not alter runtime or release assets.
