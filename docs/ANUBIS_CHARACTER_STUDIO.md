# Anubis standing character pilot

Separate from static props: humans need coherent skinned geometry, texture maps and joint-preserving animation. Do not decimate skinned humans with the prop refinement pipeline. The four Codex staff imports in #464 use Ara 0.13.0 with MakeHuman assets and Idle/Walk; this candidate-only pilot follows that documented route. It does not alter those four binaries.

Two original profile proposals: Dev Rao (platform engineer) and Rina Vale (QA analyst), existing standing cast IDs in scripts/synaxis_cast.gd. Distinct seeds, body/head parameters and office colors; reuse known suit/hair preset IDs rather than guess new ones. Hair/accessories, glasses, facial animation, hand props, seated poses and detailed wardrobe are outstanding. The authoring profile is not a likeness of an actual person.

From a separate up-to-date WSL checkout with Node 24 and Python 3.11, preview jobs:

    python3 tools/asset_refinement/character_candidates.py --out /mnt/z/NightGrid-Afterhours/Characters/standing-001

After current factory work and confirming NAS mount, add --execute to run the pinned local Node CLI. First use may download the npm package and its data archive; no guaranteed offline cache or paid service is assumed. This is not a factory stage; avoid running concurrently with other heavy jobs. The output directory must not already exist. Failure preserves the partial batch; rerun in a new directory. Each successful export gets a candidate.json with hash-bound profile and GLB identity, recorded package and documented revision. Package/version pin is not an independent integrity or installed-data verification. Structural validation checks header, embedded resources, joint IDs, weighted attributes, textured material presence and Idle/Walk names only; it does not verify actual accessor bytes, bind poses, animation tracks or physical appearance.

See assets/models/nightgrid/courier/SOURCE.md for existing source notices, pinned package integrity, and licensing context. Review all candidate-specific clothing, texture and clip rights separately. Native Godot rig/animation/close-range screenshots, placement, scale, performance, and release review still required. No automatic Git staging, runtime replacement, approval or claim of new generated binaries.
