# Anubis next run — integrated creator build, then targeted production

Source snapshot when written: e81851f63828f060094de6727310d0c71378cfca. Fetch latest main when beginning; #524–528 and this change may still be under CI. Integrate only validated main plus reviewed unique local commits. Do not reset, clean, overwrite or restart the interrupted Codex worktree. Read AGENTS.md and docs/CODEX_CREATOR_RESUME_2026_11_26.md first.

## 1. Recover existing local work

In Windows PowerShell, from the existing NightGrid-Afterhours checkout:

    git worktree list --porcelain
    git status --short --branch
    git fetch origin
    git log --left-right --cherry-pick --oneline HEAD...origin/main

Run the status/log commands again in the interrupted integration worktree. Preserve unique local edits, exact hashes, logs, and successful NAS outputs. Use a new isolated integration worktree if necessary. Record its final clean source commit. The runner allows only the known generated radio WAV/import sidecars as untracked files; report other source changes rather than deleting them. Do not stage private candidate files.

## 2. Stage and build on native Windows

From the chosen integration checkout, after checking Z: and confirming available disk space:

    $cast = 'Z:\NightGrid-Afterhours\Visual\Evidence\synaxis-cast-inputs-002'
    if (!(Test-Path -LiteralPath $cast)) { throw 'Resolve the existing NAS candidate directory first' }
    & .\tools\stage_creator_cast.ps1 -Source $cast
    $godot = Read-Host 'Full path to installed Godot 4.7.2 Windows console exe'
    & $godot --version
    $out = Join-Path "$env:USERPROFILE\Desktop\NightGrid-Playtests" ("creator-" + (Get-Date -Format yyyyMMdd-HHmmss))
    $rev = (git rev-parse HEAD).Trim()
    python tools/build_creator_playtest.py --godot "$godot" --out "$out"
    if ($LASTEXITCODE -ne 0) { throw 'Preserve logs, inspect the failed gate, do not blindly repeat' }
    python tools/verify_creator_delivery.py "$out" --revision "$rev"

Use existing twelve radio clips if available, copying only missing files from a verified prior checkout. If all twelve are absent and eSpeak NG is already installed in Ubuntu, run from the integration checkout:

    wsl -d Ubuntu -- python3 tools/generate_mbpd_radio.py

This generator overwrites its output paths: do NOT run over an existing or partial bank; preserve it and generate in a separate clean worktree instead. Record radio hashes. Preserve any other locally generated Godot metadata; inspect the runner's exact dirty-path report before further action. Check the stage, strict cast, imported audio and packaged PCK pass markers. A failure is not a successful package.

## 3. Native acceptance first

Launch the delivered executable, not the source editor. Once #524 is merged, use the dedicated save flag below. Otherwise back up normal saves before testing.

    & "$out\NightGrid-Afterhours.exe" -- --creator-qa-save

Test New World, security request, B1 IT, elevator directions and express travel, executive conversations, offboarding and street transition, the optional Static Room encounter and save/reload. Verify $75 only once. F7 marks incidents, F10 captures actual gameplay PNG+JSON, F8 records frame intervals. Capture fixed-camera stationary samples in ground, B1, executive and outdoors, plus matched cold/warm driving. Run:

    python tools/analyze_stationary_trace.py "FULL_PATH_TO_F8_CSV"

Keep source commit, resolution, rendering profile, clock/weather, F8 sidecars and evidence paths. 60 FPS remains a target, not a claim.

## 4. Targeted production after the first playable build

Do not start all generation engines concurrently. Review cached candidates, compare #464/#471 and NAS, avoid recreating existing good assets. With #527 merged, preview the four remaining named staff queue in WSL from the integrated source checkout:

    wsl -d Ubuntu -- python3 tools/asset_refinement/character_candidates.py --batch remaining-staff --out /mnt/z/NightGrid-Afterhours/Characters/remaining-staff-001

Only if missing suitable prior candidates, NAS mounted, rights/cache checked, and other jobs inactive, repeat with --execute. Use a fresh output directory for retries. With #528 merged, run native matched comparisons:

    & $godot --path . --script res://tools/review_synaxis_remaining_staff.gd -- "Z:/NightGrid-Afterhours/Characters/remaining-staff-001" "Z:/NightGrid-Afterhours/Visual/Evidence/remaining-staff-review-001"

Inspect all four pairs, fit role-specific badge/radio/tablet/uniform, preserve anchors and test animation/interaction/performance. Candidate-only until explicit acceptance; do not alter the existing private four-cast pins for this initial package.

## 5. Audio and environment follow-through

Check remaining dialogue before invoking any model:

    python tools/voice/chapter.py status --source scripts/opening_story.gd
    python tools/voice/production.py verify-library --manifest tools/voice/synaxis_chapter.json
    python tools/audio/generate_sfx.py verify-staged

If genuinely missing voice takes and rights are confirmed, use the existing Windows launcher with --voice-only --rights-checked, after inspecting cached recovery and ensuring no competing GPU job. Do not regenerate the 37 already staged effects merely because they are provisional. See docs/ANUBIS_BATCH_002.md.

Use the existing dimensioned Brickwater grate and authored copier before neural variants; compare six views, fit actual drain footprint, preserve steam/collision, and capture matched native frames. Recover appropriate NAS prop/material candidates, not a new full factory run by default. See docs/ANUBIS_GEN2_STUDIO.md and docs/ANUBIS_FACTORY.md. Each meaningful change should have an isolated branch, actual runtime integration, review evidence, regression checks and a clear acceptance blocker if incomplete. No release publication, no automatic approvals.

## Deliverables

One private package with logs, manifest, checksums, exact source commit and delivered EXE/PCK, a native acceptance report with real evidence, and one targeted next asset integration if evidence and rights permit. If a blocker occurs, record exact command and paths and keep all successful outputs; do not exhaust credits on blind regeneration.
