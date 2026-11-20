# Generated next-playtest screenshots

This directory is intentionally tracked so the repository's resource-reference
preflight recognizes the output location.

`tools/capture_playtest_evidence.gd` saves **real** Godot render frames here
when the dedicated X11/Mesa GitHub Action is run. Its eight PNGs and
`manifest.json` are uploaded to the workflow run as an artifact; the generated
files are **not committed to the source tree**. Source-control identity belongs
in the manifest. See `docs/NEXT_PLAYTEST.md` for the runtime Windows QA steps.

Please do not substitute mockups, AI art, stock images, or generated stand-ins
for actual renderer frames.
