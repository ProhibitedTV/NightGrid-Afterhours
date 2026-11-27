# Synaxis creator playtest

Run `tools/stage_creator_cast.ps1 -Source <candidate-folder>` using the NAS folder `Visual/Evidence/synaxis-cast-inputs-002`. Import and export with Godot 4.7.2. The script verifies all four files before staging. The Windows export includes the staged candidates inside its PCK. The Git branch carries the source integration and checksums.

The authored copier takes precedence over the earlier reconstruction trial. The Brickwater grate stays at review status while the recessed surround is pending. The four Synaxis actors are creator-playtest candidates. Final wardrobe rights review, seated transition fit, character and environment art acceptance, and the stationary frame-time investigation remain open.

## Strict local cast check before exporting

After staging and importing, run:

    godot --headless --path . --script res://tests/synaxis_creator_cast_smoke.gd -- --require-cast

Require the `SYNAXIS_CREATOR_CAST PASS: all four staged actors` marker and exit code 0. The check uses the real office actor installation path, verifies all four staged hashes and imported skeletons, and checks their selected clips and Dev's attached cup. Without the flag, CI checks the clean-checkout fallback contract; partial staging fails in either mode. This is structural evidence only, not native visual or exported PCK verification. Never stage private binaries in Git. If any existing staged candidate differs, the staging script refuses to copy anything; preserve the old files and use a clean local worktree.

The private staging directory must not contain unreviewed `.bin` files, including nested directories. The staging script and strict source/package verifiers reject unexpected binaries; move unique assets to a separate preserved location instead of deleting them. Only the four pinned filenames may be exported by the candidate wildcard. The stage copy also refuses overwriting a file that appears between precheck and copy.
