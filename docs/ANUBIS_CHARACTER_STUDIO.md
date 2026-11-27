# Anubis standing character pilot

Separate from static props: humans need coherent skinned geometry, texture maps and joint-preserving animation. Do not decimate skinned humans with the prop refinement pipeline. The four Codex staff imports in #464 use Ara 0.13.0 with MakeHuman assets and Idle/Walk; this candidate-only pilot follows that documented route. It does not alter those four binaries.

The profile catalog includes the standing cast Dev Rao and Rina Vale, and the executive-floor seated cast Dana Mercer and Jetson Wang. Each candidate keeps its existing gameplay identity and uses an original fictional appearance profile. The revised Dev and Rina profiles use separate hair, tailoring and accessories. The seated profiles add chair entry, idle and stand clips from the existing Ara library.

From a separate up-to-date WSL checkout with Node 24 and Python 3.11, preview jobs:

    python3 tools/asset_refinement/character_candidates.py --out /mnt/z/NightGrid-Afterhours/Characters/standing-001

After current factory work and confirming NAS mount, add --execute to run the pinned local Node CLI. First use may download the npm package and its data archive; no guaranteed offline cache or paid service is assumed. This is not a factory stage; avoid running concurrently with other heavy jobs. The output directory must not already exist. Failure preserves the partial batch; rerun in a new directory. Each successful export gets a candidate.json with hash-bound profile and GLB identity, recorded package and documented revision. Package/version pin is not an independent integrity or installed-data verification. Structural validation checks header, embedded resources, joint IDs, weighted attributes, textured material presence and each profile's required clip names; it does not verify actual accessor bytes, bind poses, animation tracks or physical appearance.

See assets/models/nightgrid/courier/SOURCE.md for existing source notices, pinned package integrity, and licensing context. Review all candidate-specific clothing, texture and clip rights separately. Native Godot rig/animation/close-range screenshots, placement, scale, performance, and release review still required. No automatic Git staging, runtime replacement, approval or claim of new generated binaries.

For a native scene comparison, stage the reviewed candidates as `dev.glb` and `rina.glb` in a local directory. Run the game with Godot 4.7.2 Forward+/Vulkan and `--script res://tools/review_synaxis_anubis_cast.gd -- <candidate-directory> <new-evidence-directory>`. The fixture imports the two hash-pinned GLBs with the existing pedestrian rig adapter, captures the real headquarters and compares both proximity remarks at the original cast anchors. Use \`--social\` for the second standing exports. The fixture layers the right-arm carry pose onto Dev’s idle, attaches the existing cup to the hand bone, and plays Rina’s conversation gestures. Use \`--seated\` with \`dana.glb\` and \`jetson.glb\` for the executive chair comparison. Their fitted seated idles preserve the original actor and dialogue anchors. The separate native rig verifier also accepted their sit-down and stand-up animations. The scene comparison covers the seated idle, while transition fit and candidate rights review remain pending.

## Remaining story cast — targeted production batch

The original four profiles and default queue remain unchanged. After the first self-contained creator build succeeds, inspect existing #464/ #471 candidate files and NAS evidence before producing any replacement. If the four remaining identities lack acceptable candidates, preview the separate queue:

    python3 tools/asset_refinement/character_candidates.py --batch remaining-staff --out /mnt/z/NightGrid-Afterhours/Characters/remaining-staff-001

Add --execute only when the NAS is mounted, exporter/cache and rights are checked, and other heavy jobs are finished. For independent retries use --actor mika_torres, --actor eli_brooks, --actor owen_pike, or --actor nina_bell with a new output directory. The four profiles use known garment IDs from the previous pilot and distinct body/face/hair/color parameters. Owen's dark business suit is a candidate uniform base, not a final security uniform; badge, radio, technician tablet and role-specific wardrobe require fitted authoring and native review. All remain candidate-only; do not expand the current four-hash private package before fitting, review and explicit integration.
