# Anubis asset refinement v1

Independent offline stage for the output of visual batch 001 (#474 / #475). No changes to runtime scenes, no neural inference, no modification of source assets. Separate branch/worktree can be used while generation continues. Prefer running after the GPU batch, or use a one-mesh smoke test with two CPU threads.

## Windows CMD / WSL

From the original repo, fetch the refinement branch and create a separate worktree. Install Blender in Ubuntu (distribution package, Blender 3.6+ required; 4.x recommended). Do not install another CUDA stack.

    git fetch origin tools/anubis-refinement-v1
    git -c core.autocrlf=false worktree add --detach "%USERPROFILE%\Desktop\NightGrid-Refine" FETCH_HEAD
    cd /d "%USERPROFILE%\Desktop\NightGrid-Refine"
    wsl -d Ubuntu -- sudo apt install blender python3-numpy
    wsl -d Ubuntu -- bash tools/asset_refinement/run_refine.sh --limit 1

After reviewing the smoke result, repeat without --limit for the available completed meshes. No completed mesh is regenerated if the input hashes, script, settings, Blender version and output hashes match. Re-running picks up newly completed candidates. No automatic watcher. Do not remove a stale .refinement.lock until no refinement process is active.

Input: Z:\NightGrid-Afterhours\Visual\visual-001\candidates
Output: Z:\NightGrid-Afterhours\Visual\refined-001\<candidate>\<signature>\

Each committed result contains lod0/1/2.glb (maximum 12k/5k/1.5k triangles), collision.glb, refinement.json. All are unapproved. LOD budgets are first-pass defaults, not measured in-engine targets. Files stage on the output volume and publish as a directory only after structural verification; source hashes are rechecked before publication. No overwrite of an existing invalid result. At least 5 GiB NAS reserve is required.

Optional --dimensions /path/to/heights.json supplies a JSON object keyed by candidate ID with a measured target height in metres. Without an explicit height the raw reconstruction scale stays unresolved. Even measured height alone does not establish correct width/depth or front orientation. Anchors are ground-centered.

## Gate and known limitations

- Removes loose and degenerate geometry, welds near-duplicates, recalculates normals; rejects empty/nonfinite input and multi-object meshes. Does not promise watertight visual geometry or semantic reconstruction.
- Smart UV projection, retained vertex colors and decimated LODs. No authentic normal/roughness/metalness maps yet; material scalar defaults are provisional and not inferred physical properties. Material-reference images are not seamless or approved PBR textures. UV distortion/overlap and color quality require visual review.
- Convex proxy can fill gaps. Do not use it blindly for doorways, seating, moving parts or architecture; authored compound/trimesh collision and interaction anchors remain necessary.
- Structural glTF header, triangle, UV, normal and color checks plus hashes; does not prove appearance. Optional native Godot headless test (run from Windows with your installed executable and a separate empty project): godot --headless --path <empty-project> --script <absolute-path-to-validate.gd> -- <absolute-path-to-lod0.glb>. Repeat for each LOD and collision. Manifest deliberately keeps Godot import pending until external evidence is recorded. Real Windows Forward+/Vulkan screenshots and frametimes are mandatory before art acceptance per AGENTS.md.
- No copying into res://, no automated publication, no rights approval. Review source model terms and preserve provenance before integration.
- Next: vertex-color-to-albedo bake with seam padding and projection QC, authored material assignments and actual PBR maps, texture atlas/mip budgets, Godot validation reports, thumbnails/review queue, targeted scene integration. These are not implemented by v1.
