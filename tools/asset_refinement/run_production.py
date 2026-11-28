"""One-shot Anubis candidate production. Run from the existing Factory checkout."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from factory_ledger import atomic, now
from resource_guard import violation
from telemetry import snapshot

ROOT = Path(__file__).resolve().parents[2]
NAS = Path("/mnt/z/NightGrid-Afterhours")
HOME = Path(os.environ.get("ANUBIS_VISUAL_HOME", "/root/.local/share/nightgrid-visual-py311"))
NATIVE = "/mnt/c/Users/RhythmicCarnage/AppData/Local/Temp/nightgrid-godot-472/Godot_v4.7.2-stable_win64_console.exe"
MUSIC = "music-neon-grunge-studio-002"
STAGES = ("music", "visual", "botanical", "buildings", "characters",
          "reception", "synaxis-ground", "inventory", "review_packet", "evidence", "dashboard")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def sha(path):
    with path.open("rb") as f:
        digest = hashlib.sha256()
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
        return digest.hexdigest()


def music_complete(folder):
    """Do not reload models for an intact completed 48-take candidate batch."""
    try:
        rows = json.loads((folder / "manifest.json").read_text())["candidates"]
        if len(rows) != 48 or len({r["file"] for r in rows}) != 48:
            return False
        return all(Path(r["file"]).name == r["file"]
                   and not (folder / r["file"]).is_symlink()
                   and sha(folder / r["file"]) == r["sha256"] for r in rows)
    except (OSError, ValueError, TypeError, KeyError):
        return False


def preflight(godot):
    if os.geteuid() != 0:
        raise RuntimeError("Launch from Ubuntu WSL as root")
    if not os.path.ismount("/mnt/z") or not (NAS / "Visual").is_dir():
        raise RuntimeError("Mount existing Z: NAS before production")
    if not HOME.is_dir():
        raise RuntimeError("Existing Factory environments missing")
    if not Path(godot).is_file() or not godot.endswith(".exe"):
        raise RuntimeError("Set --godot to the native 4.7.2 console executable")
    version = subprocess.check_output([godot, "--version"], text=True, timeout=30).strip()
    if not re.match(r"^4\.7\.2([.\-+]|$)", version):
        raise RuntimeError("Native Godot 4.7.2 required: " + version)
    if git("status", "--porcelain", "--untracked-files=no"):
        raise RuntimeError("Tracked checkout changes; commit or preserve before production")
    bad = violation(snapshot(), 25, 10, 85, require_gpu=True)
    if bad:
        raise RuntimeError(bad)
    return version


def build_plan(batch, godot, visual_mode):
    post = "postmusic-" + batch
    visual_env = {"ANUBIS_PROJECT_NORMALS": "1", "ANUBIS_BAKE_AO": "1",
                  "ANUBIS_PREVIEWS": "1", "ANUBIS_SKIP_AUDIO": "1", "ANUBIS_BATCH": "visual-001",
                  "ANUBIS_GODOT": "/usr/local/bin/godot"}
    base = ["bash", "tools/asset_refinement/run_post_music.sh", "--execute"]
    return {
        "music": (["bash", "tools/audio/run_anubis_music.sh", "--palette", "neon-grunge-v1",
                   "--profile", "studio", "--batch", MUSIC], {}),
        "visual": (["bash", "tools/asset_refinement/run_factory.sh", visual_mode], visual_env),
        "botanical": ([sys.executable, "tools/asset_refinement/botanical_candidates.py", "--execute",
                       "--out", str(NAS / "Visual/Botanical" / ("coastal-" + batch))], {}),
        "buildings": (base + ["--lane", "buildings", "--batch", post], {}),
        "characters": (base + ["--lane", "characters", "--batch", post], {}),
        **{profile: (base + ["--lane", "lighting", "--lighting-profile", profile,
                             "--godot", godot], {})
           for profile in ("reception", "synaxis-ground")},
        "inventory": ([str(HOME / "mesh/bin/python"), "tools/asset_refinement/render_inventory.py"], {}),
        "review_packet": ([sys.executable, "tools/asset_refinement/review_packet.py",
                           "--refined", str(NAS / "Visual/refined-001"),
                           "--previews", str(NAS / "Visual/Previews")], {}),
        "evidence": ([sys.executable, "tools/asset_refinement/production_evidence.py",
                      "--nas", str(NAS)], {}),
        "dashboard": ([sys.executable, "tools/asset_refinement/dashboard.py",
                       "--root", str(NAS / "Visual")], {}),
    }


def dispatch(args):
    plan = build_plan(args.batch, args.godot, args.visual_mode)
    if not args.execute:
        for profile, short in (("reception", "rec"), ("synaxis-ground", "ground")):
            plan[profile][0].extend(["--batch", f"postmusic-{args.batch}-{short}-1"])
        plan["inventory"][0].extend(["--output", str(NAS / "Visual/ProductionRuns" / args.batch / "inventory.json")])
        run = NAS / "Visual/ProductionRuns" / args.batch
        plan["review_packet"][0].extend(["--output", str(run / "review-1.zip")])
        plan["evidence"][0].extend(["--run", str(run)])
        print(json.dumps({name: {"argv": argv, "env": env} for name, (argv, env) in plan.items()}, indent=2))
        return 0
    version = preflight(args.godot)
    source = git("rev-parse", "HEAD")
    run = NAS / "Visual/ProductionRuns" / args.batch
    run.mkdir(parents=True, exist_ok=True)
    if run.is_symlink():
        raise RuntimeError("Unsafe run directory")
    state_path = run / "production.json"
    env = dict(os.environ, HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1",
               NPM_CONFIG_OFFLINE="true", PYTHONDONTWRITEBYTECODE="1")
    env["PATH"] = env.get("PATH", "") + ":/usr/lib/wsl/lib"
    for key in ("ANUBIS_VISUAL_CATALOG", "ANUBIS_GENERATION_REPO"):
        env.pop(key, None)
    signature = {"source": source, "godot": version, "godot_path": args.godot,
                 "visual_mode": args.visual_mode, "stages": list(STAGES)}
    # Separate orchestration lock; existing launchers retain their own GPU leases.
    with (HOME / "production-dispatch.lock").open("a") as lease:
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if state_path.exists():
            state = json.loads(state_path.read_text())
            if state["signature"] != signature:
                raise RuntimeError("Run inputs changed; choose a new --batch")
        else:
            state = {"schema": 1, "signature": signature, "review": "pending",
                     "entries": {n: {"status": "pending", "attempts": 0} for n in STAGES}}
        atomic(state_path, state)
        for name in STAGES:
            entry = state["entries"][name]
            if entry["status"] == "completed":
                if name == "music" and not music_complete(NAS / "Music" / MUSIC):
                    raise RuntimeError("Completed music checkpoint no longer verifies; inspect existing batch")
                if name in ("reception", "synaxis-ground") and not (Path(entry["candidate"]) / "validated-bake.json").is_file():
                    raise RuntimeError("Completed lighting checkpoint missing; inspect existing candidate")
                if not (run / entry["log"]).is_file():
                    raise RuntimeError("Completed stage log missing; inspect run")
                print("CHECKPOINT", name, flush=True)
                continue
            bad = violation(snapshot(), 25, 10, 85, require_gpu=True)
            if bad:
                raise RuntimeError(bad)
            if git("rev-parse", "HEAD") != source or git("status", "--porcelain", "--untracked-files=no"):
                raise RuntimeError("Checkout changed during production")
            argv, extra = plan[name]
            argv = list(argv)
            entry.update(status="running", attempts=entry["attempts"] + 1, started=now())
            attempt = entry["attempts"]
            if name in ("reception", "synaxis-ground"):
                short = "rec" if name == "reception" else "ground"
                candidate = f"postmusic-{args.batch}-{short}-{attempt}"
                argv += ["--batch", candidate]
                entry["candidate"] = str(NAS / "Visual/Lighting" / candidate)
            elif name in ("inventory", "review_packet"):
                artifact = "inventory.json" if name == "inventory" else f"review-{attempt}.zip"
                entry["artifact"] = artifact
                argv += ["--output", str(run / artifact)]
            elif name == "evidence":
                argv += ["--run", str(run)]
            log = run / f"{name}-{attempt}.log"
            entry["log"] = log.name
            atomic(state_path, state)
            print(f"START {name} -> {log}", flush=True)
            try:
                if name == "music" and music_complete(NAS / "Music" / MUSIC):
                    log.write_text("Existing 48 candidate WAV hashes verified; no inference needed.\n")
                    rc = 0
                else:
                    with log.open("x", encoding="utf-8") as out:
                        # CPU-only botanical stage does not need a GPU lease; existing
                        # visual, music and post-music launchers own their GPU locks.
                        rc = subprocess.run(argv, cwd=ROOT, env=dict(env, **extra),
                                            stdout=out, stderr=subprocess.STDOUT).returncode
                    if rc == 0 and name == "music" and not music_complete(NAS / "Music" / MUSIC):
                        rc = 1
                    if rc == 0 and name in ("reception", "synaxis-ground"):
                        if not (Path(entry["candidate"]) / "validated-bake.json").is_file():
                            rc = 1
            except KeyboardInterrupt:
                entry.update(status="interrupted", finished=now(), exit_code=130)
                atomic(state_path, state)
                return 130
            except Exception as exc:
                entry.update(status="failed", finished=now(), error=str(exc))
                atomic(state_path, state)
                raise
            entry.update(status="completed" if rc == 0 else "failed", finished=now(), exit_code=rc)
            atomic(state_path, state)
            if rc:
                print(f"PAUSED {name}: see {log}; rerun same command to resume.", flush=True)
                return rc if rc > 0 else 1
            print("DONE", name, flush=True)
        print("Production process complete; candidate-only, visual/rights/native gameplay approval pending.")
        print(state_path)
        return 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--execute", action="store_true")
    p.add_argument("--batch", default="render-001")
    p.add_argument("--godot", default=NATIVE)
    p.add_argument("--visual-mode", choices=("full", "existing"), default="full")
    a = p.parse_args()
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,15}", a.batch):
        p.error("batch must be 1–16 lowercase letters/digits/hyphens")
    return dispatch(a)


if __name__ == "__main__":
    sys.exit(main())
