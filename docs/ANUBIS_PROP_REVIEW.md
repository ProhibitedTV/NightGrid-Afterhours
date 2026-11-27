# Anubis prop comparisons

The two prop placements are local debug review fixtures. The Windows release continues to use the existing meshes. Both candidates remain in the NAS review library.

Copy these NAS LOD1 files to a review-only directory. The loader requires their recorded SHA-256.

| Filename | Candidate | Refinement signature |
| --- | --- | --- |
| grate.glb | brickwater.metal-street-drainage-grate.v1 | 1338df3102f831909c33281a93d12faf37aeb0a134d5f119eff19cb89654fee2 |
| copier.glb | synaxis.enterprise-laser-printer-copier.v1 | fc5b5b0f13e52cbf8d36638e18c96f65ae1369b8f7c4e33907a62961a85f8d6f |

Set `NIGHTGRID_ANUBIS_REVIEW_PROPS` to that absolute directory and launch the game from source in native Godot 4.7.2 Forward+/Vulkan. Clear the variable for the matched baseline. Use the same seed, display mode, graphics settings and camera harness for both runs.

- Brickwater uses the existing `tools/capture_brickwater_alley.gd` fixture with `-- --measure --walk`. Give each run a new `NIGHTGRID_ALLEY_CAPTURE_DIR`. The close shot and walking CSVs use the real playable alley. The 0.32 × 0.021 × 0.72 m grate fits the original footprint and retains the old steam location and floor collision.
- Set `NIGHTGRID_SYNAXIS_REVIEW` to a new absolute output directory and run `tools/review_synaxis_anubis_prop.gd`. It boots the current game, streams the headquarters, positions a fixed camera by the first-floor printer and checks the existing print interaction. The 0.55 × 0.40 × 0.65 m copier body sits on the original cabinet. The cabinet collider, output tray, printed sheet, interaction and mission anchors remain with the original scene.
- Native structural validation for the whole batch can run independently of WSL. Run `tools/asset_refinement/run_godot_gate.ps1` with the local Windows Godot 4.7.2 console executable and Python executable. It writes the per-GLB import report inside the NAS refinement library.

Both selected LOD1s use the embedded reconstructed base color, tangent normals and provisional roughness. Rights review, material authoring and visual acceptance remain open. The fragmented Brickwater grate v2 stays in the NAS review library.
