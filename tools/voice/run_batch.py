#!/usr/bin/env python3
"""Unattended, resumable local Anubis production. Never pushes Git or claims human review."""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import anubis
import chapter
import production
import studio

ROOT = studio.ROOT
OUT = ROOT / "dist/anubis-batch"
UPSTREAM = "https://github.com/Stability-AI/stable-audio-3.git"
UPSTREAM_SHA = "4007b6f2987bcb760626c2b4ae3e3541753984e9"


def command(args, *, cwd=ROOT, timeout=7200, env=None):
    print("\n>>>", " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, check=True, stdin=subprocess.DEVNULL,
                   timeout=timeout, env=env)


def remaining(specs, library=production.PUBLISHED):
    return [ident for ident in specs if not (library / ident).is_dir()]


def chunks(items, size):
    return [items[i:i+size] for i in range(0, len(items), size)]


def voice_pass(specs, seeds, errors, device):
    production.verify_library(specs)
    for seed in seeds:
        missing = remaining(specs)
        if not missing:
            break
        print(f"Voice pass {seed}: {len(missing)} remaining", flush=True)
        for group in chunks(missing, 12):
            selectors = [v for ident in group for v in ("--id", ident)]
            args = [sys.executable, anubis.HERE / "anubis.py", "bake",
                    "--manifest", chapter.CATALOG, "--seed", seed,
                    "--device", device, "--auto-playtest", "--rights-checked"]
            try:
                command(args + selectors, timeout=5400)
            except (subprocess.SubprocessError, OSError) as exc:
                errors.append({"stage": "voice", "seed": seed, "ids": group, "error": str(exc)})
                # Cached successful renders are retained. The next seed pass
                # retries unpublished cues; do not loop forever on engine errors.
                print("Voice group failed; continuing:", exc, flush=True)
        production.verify_library(specs)


def sfx_environment():
    home = Path.home()
    source = home / "stable-audio-3-anubis"
    uv = shutil.which("uv") or str(home / "audio-bootstrap/bin/uv")
    if not Path(uv).is_file():
        raise FileNotFoundError("uv not found; batch 001 bootstrap environment is required")
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", UV_NO_PROGRESS="1",
               UV_NO_CONFIG="1", HF_HUB_DISABLE_PROGRESS_BARS="1")
    if not source.exists():
        command(["git", "clone", "--no-checkout", UPSTREAM, source], env=env, timeout=900)
    if subprocess.check_output(["git", "-C", str(source), "remote", "get-url", "origin"], text=True).strip() != UPSTREAM:
        raise ValueError("Unexpected SFX upstream remote; refusing to alter it")
    if subprocess.check_output(["git", "-C", str(source), "status", "--porcelain", "--untracked-files=no"], text=True).strip():
        # A new --no-checkout clone has an empty worktree until its first checkout.
        if (source / "pyproject.toml").exists():
            raise ValueError("SFX upstream checkout has local modifications")
    command(["git", "-C", source, "checkout", "--detach", UPSTREAM_SHA], env=env, timeout=900)
    command([uv, "sync", "--locked", "--python", "3.11"], cwd=source, env=env, timeout=3600)
    return source / ".venv/bin/python", env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rights-checked", action="store_true", help="Confirm original synthetic voice output rights")
    parser.add_argument("--sfx-rights-checked", action="store_true", help="Confirm separate Stable Audio license and gated model access")
    parser.add_argument("--voice-only", action="store_true")
    parser.add_argument("--sfx-only", action="store_true")
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--device", choices=("cuda", "cpu"), default="cuda")
    parser.add_argument("--sfx-device", choices=("cuda", "cpu"), default="cuda")
    parser.add_argument("--seeds", type=int, nargs="+", default=[312, 314, 316])
    args = parser.parse_args()
    if args.voice_only and args.sfx_only:
        parser.error("Choose at most one stage selector")
    if any(s < 0 for s in args.seeds):
        parser.error("Seeds must be nonnegative")
    specs = chapter.validate_catalog(chapter.CATALOG, ROOT / "scripts/opening_story.gd")
    production.verify_library(specs)
    missing = remaining(specs)
    print(f"Dialogue: {len(specs)-len(missing)}/{len(specs)} already verified; {len(missing)} queued")
    print(f"Effects catalog: {len(anubis.sfx_ids([], None))} cues")
    if args.plan:
        print("Queued dialogue:", ", ".join(missing))
        return 0
    if not args.sfx_only and not args.rights_checked:
        parser.error("Use --rights-checked after confirming voice model/output rights")
    OUT.mkdir(parents=True, exist_ok=True)
    started = datetime.now(timezone.utc).isoformat()
    clock = time.monotonic()
    errors = []
    sfx_status = "not requested" if args.voice_only else "not started"
    if not args.sfx_only:
        try:
            command([sys.executable, "-c",
                     "import torch; assert torch.cuda.is_available()" if args.device == "cuda" else "import torch"],
                    timeout=120)
            voice_pass(specs, args.seeds, errors, args.device)
        except (subprocess.SubprocessError, OSError, ValueError, KeyError) as exc:
            errors.append({"stage":"voice", "error":str(exc)})
    if not args.voice_only:
        if not args.sfx_rights_checked:
            sfx_status = "blocked: confirm Stable Audio license and gated model access"
        else:
            try:
                python, env = sfx_environment()
                command([python, ROOT / "tools/audio/sfx_batch.py", "--device", args.sfx_device,
                         "--upstream-sha", UPSTREAM_SHA, "--rights-checked"],
                        env=env, timeout=21600)
                sfx_status = "worker completed"
            except (subprocess.SubprocessError, OSError, ValueError) as exc:
                sfx_status = "incomplete: " + str(exc)
                errors.append({"stage":"sfx","error":str(exc)})
    try:
        count = production.verify_library(specs)
    except (OSError, ValueError, KeyError) as exc:
        count = None
        errors.append({"stage":"final voice verification", "error":str(exc)})
    report = {"started_utc":started, "elapsed_seconds":round(time.monotonic()-clock,1),
              "source":os.environ.get("ANUBIS_SOURCE_SHA", "unverified local checkout"),
              "dialogue_verified":count, "dialogue_total":len(specs),
              "remaining_dialogue":remaining(specs), "sfx_status":sfx_status,
              "errors":errors, "review":"provisional; human gameplay listening pending"}
    # WSL Git cannot necessarily resolve a Windows-created worktree; source
    # identity is supplied by the launcher when available, never guessed.
    sfx_report = OUT / "sfx-results.json"
    if sfx_report.is_file() and not args.voice_only:
        report["sfx_last_report"] = production.load(sfx_report)
    temp = OUT / "summary.json.tmp"
    studio.write_json(temp, report)
    temp.replace(OUT / "summary.json")
    print("\nANUBIS BATCH SUMMARY", flush=True)
    print((OUT / "summary.json").read_text(encoding="utf-8"), flush=True)
    print("No Git commit or push performed. Preserve validated assets; do not stage dist or environments.")
    incomplete = (not args.sfx_only and (count is None or count != len(specs))) or (
        not args.voice_only and sfx_status != "worker completed")
    return 2 if errors or incomplete else 0


if __name__ == "__main__":
    raise SystemExit(main())
