# Private Windows creator build runner

After recovering and committing unique local integration work, stage the four reviewed NAS candidates with tools/stage_creator_cast.ps1. Preserve existing generated audio; this tool does not synthesize anything. Requires the strict office smoke (#510) and packaged verifier (#511) on the same checkout. Use the native Windows Godot 4.7.2 console executable and installed export templates.

    python tools/build_creator_playtest.py --godot "C:/path/to/Godot_v4.7.2-stable_win64_console.exe" --out "D:/private-playtests/new-candidate"

Use a new destination outside the checkout. The runner rejects dirty source and existing destinations, verifies offline audio contracts and required existing radio clips, imports, runs the strict cast installation smoke, temporarily stamps the exact source revision, exports, restores build-info bytes, and verifies actual packaged candidate hashes. It records logs, identity, candidate hashes, credits and payload checksums. No automatic asset generation, Git reset, public upload, or release promotion. Failed runs preserve the partial output and logs; choose a different new output directory on retry.

A clean source requirement means commit or otherwise preserve reviewed local edits first; never discard them just to satisfy the runner. The ignored private candidate binaries remain outside Git. Voice/SFX verification does not imply complete newly authored dialogue or human listening approval. A successful runner is not native gameplay or frame-time acceptance; test the delivered executable manually with a backed-up test profile, capture Chapter One and optional encounter evidence, and inspect RTX 3060 frame pacing.

## Protect normal game progress during creator QA

Launch the delivered Windows executable with ` .\NightGrid-Afterhours.exe -- --creator-qa-save` (omit the leading space when pasting). The title and pause menus identify the separate creator QA save slot; Continue, Load, and Save use `user://saves/afterhours_creator_qa_slot.json` instead of the normal slot. Normal launches do not read the QA slot. This isolates only the save file; settings and playtest evidence still share the application user directory. Back up valuable saves before testing, and do not overwrite a previous QA session if it is needed as evidence.
