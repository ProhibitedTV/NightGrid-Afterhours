"""One-shot Anubis candidate production. Run from the existing Factory checkout."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import shutil
import sys

from factory_ledger import atomic, now
from resource_guard import violation
from telemetry import snapshot

ROOT = Path(__file__).resolve().parents[2]
NAS = Path("/mnt/z/NightGrid-Afterhours")
HOME = Path(os.environ.get("ANUBIS_VISUAL_HOME", "/root/.local/share/nightgrid-visual-py311"))
NATIVE = "/mnt/c/Users/RhythmicCarnage/AppData/Local/Temp/nightgrid-godot-472/Godot_v4.7.2-stable_win64_console.exe"
MUSIC = "music-neon-grunge-studio-002"
# Deliver cheap independent candidates first. Long-running inference is last
# among the asset producers; final review still requires every selected lane.
STAGES = ("music", "layouts", "street_plan", "regional_plan", "buildings", "district_buildings",
          "botanical", "environments", "decals", "characters", "impostors",
          "reception", "synaxis-ground", "visual", "visual_detail",
          "inventory", "review_packet", "review_detail", "evidence", "dashboard")


def git(*args):
    return subprocess.check_output(["git", "-c", f"safe.directory={ROOT}", *args], cwd=ROOT, text=True).strip()


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


def preflight(godot, linux_godot, visual_mode):
    if os.geteuid() != 0:
        raise RuntimeError("Launch from Ubuntu WSL as root")
    if not os.path.ismount("/mnt/z") or not (NAS / "Visual").is_dir():
        raise RuntimeError("Mount existing Z: NAS before production")
    if not HOME.is_dir() or not (HOME / "mesh/bin/python").is_file():
        raise RuntimeError("Existing Factory mesh environment missing")
    if visual_mode == "full" and not (HOME / "setup-v1.ok").is_file():
        raise RuntimeError("Existing visual setup marker missing; refusing implicit installation")
    for command in ("blender", "flock", "powershell.exe", "wslpath", "node", "npx"):
        if not shutil.which(command):
            raise RuntimeError("Existing dependency missing: " + command)
    if not subprocess.check_output(["node","--version"],text=True).startswith("v24."):
        raise RuntimeError("Existing Node 24 required")
    if not Path(linux_godot).is_file() or not os.access(linux_godot,os.X_OK):
        raise RuntimeError("Set --linux-godot to existing Linux Godot executable")
    linux_version = subprocess.check_output([linux_godot,"--version"],text=True,timeout=30).strip()
    if not re.match(r"^4\.7\.2([.\-+]|$)",linux_version):
        raise RuntimeError("Linux Godot 4.7.2 required: " + linux_version)
    if not (NAS / "Characters").is_dir():
        raise RuntimeError("Existing NAS character library missing")
    if not music_complete(NAS / "Music" / MUSIC) and not Path("/home/anubis/AI/ACE-Step-1.5/.venv/bin/python").is_file():
        raise RuntimeError("Existing music environment missing")
    if (NAS / "Audio/factory-001/.audio.lock").exists():
        raise RuntimeError("Audio lock present; inspect before production")
    subprocess.run([str(HOME / "mesh/bin/python"),"-c","import PIL, numpy"],check=True)
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
    return {"native":version,"linux":linux_version}


def build_plan(batch, godot, visual_mode, linux_godot="/usr/local/bin/godot"):
    post = "postmusic-" + batch
    visual_env = {"ANUBIS_PROJECT_NORMALS": "1", "ANUBIS_BAKE_AO": "1",
                  "ANUBIS_PREVIEWS": "1", "ANUBIS_SKIP_AUDIO": "1", "ANUBIS_BATCH": "visual-001",
                  "ANUBIS_GODOT": linux_godot}
    base = ["bash", "tools/asset_refinement/run_post_music.sh", "--execute"]
    jobs = {
        "music": (["bash", "tools/audio/run_anubis_music.sh", "--palette", "neon-grunge-v1",
                   "--profile", "studio", "--batch", MUSIC], {}),
        "visual": (["bash", "tools/asset_refinement/run_factory.sh", visual_mode], visual_env),
        "visual_detail": (["bash", "tools/asset_refinement/run_factory.sh", visual_mode],
                          dict(visual_env, ANUBIS_BATCH="visual-coastal-detail-001",
                               ANUBIS_VISUAL_CATALOG=str(ROOT / "tools/visual_studio/catalog_coastal_detail.json"))),
        "botanical": ([sys.executable, "tools/asset_refinement/botanical_candidates.py", "--execute",
                       "--out", str(NAS / "Visual/Botanical" / ("coastal-" + batch))], {}),
        "impostors": ([str(HOME / "mesh/bin/python"), "tools/asset_refinement/impostor_candidates.py",
                       "--bank", str(NAS / "Visual/Botanical" / ("coastal-" + batch)),
                       "--out", str(NAS / "Visual/Impostors" / batch), "--size", "512", "--samples", "32"], {}),
        "layouts": ([sys.executable, "tools/asset_refinement/urban_layout_candidates.py",
                     "--out", str(NAS / "Visual/UrbanLayouts" / batch)], {}),
        "street_plan": ([sys.executable, "tools/asset_refinement/street_network_candidates.py",
                         "--out", str(NAS / "Visual/UrbanLayouts" / batch)], {}),
        "regional_plan": ([sys.executable, "tools/asset_refinement/regional_candidates.py",
                           "--out", str(NAS / "Visual/UrbanLayouts" / batch)], {}),
        "buildings": (base + ["--lane", "buildings", "--batch", post], {}),
        "district_buildings": ([sys.executable, "tools/asset_refinement/district_building_candidates.py",
                               "--out", str(NAS / "Visual/DistrictArchitecture" / batch)], {}),
        "environments": ([str(HOME / "mesh/bin/python"), "tools/asset_refinement/environment_candidates.py",
                          "--out", str(NAS / "Visual/Environments" / batch), "--width", "1024"], {}),
        "decals": ([str(HOME / "mesh/bin/python"), "tools/asset_refinement/decal_candidates.py",
                    "--out", str(NAS / "Visual/Decals" / batch), "--size", "512"], {}),
        "characters": (base + ["--lane", "characters", "--batch", post], {}),
        **{profile: (base + ["--lane", "lighting", "--lighting-profile", profile,
                             "--godot", godot], {})
           for profile in ("reception", "synaxis-ground")},
        "inventory": ([str(HOME / "mesh/bin/python"), "tools/asset_refinement/render_inventory.py"], {}),
        "review_packet": ([sys.executable, "tools/asset_refinement/review_packet.py",
                           "--refined", str(NAS / "Visual/refined-001"),
                           "--previews", str(NAS / "Visual/Previews")], {}),
        "review_detail": ([sys.executable, "tools/asset_refinement/review_packet.py",
                           "--refined", str(NAS / "Visual/refined-coastal-detail-001"),
                           "--previews", str(NAS / "Visual/Previews/visual-coastal-detail-001")], {}),
        "evidence": ([str(HOME / "mesh/bin/python"), "tools/asset_refinement/production_evidence.py",
                      "--nas", str(NAS)], {}),
        "dashboard": ([sys.executable, "tools/asset_refinement/dashboard.py",
                       "--root", str(NAS / "Visual")], {}),
    }
    return {name:jobs[name] for name in STAGES}


def status(run):
    """Read-only view, safe to invoke while the foreground dispatcher runs."""
    path=run/"production.json"
    if not path.is_file():
        return {"batch":run.name,"status":"not-started","completed":0,"total":len(STAGES)}
    state=json.loads(path.read_text())
    entries=state["entries"]
    completed=sum(e["status"]=="completed" for e in entries.values())
    current=next((n for n in state["signature"]["stages"] if entries[n]["status"]!="completed"),None)
    return {"batch":run.name,"status":"process-complete" if current is None else entries[current]["status"],
            "completed":completed,"total":len(entries),"current_stage":current,
            "pause_requested":(run/"PAUSE").exists(),"source":state["signature"]["source"],
            "current_log":entries[current].get("log") if current else None,
            "entries":entries,"approval":"review-required"}


def dispatch(args):
    run = NAS / "Visual/ProductionRuns" / args.batch
    if args.status:
        if not os.path.ismount("/mnt/z"):
            raise RuntimeError("NAS not mounted; refusing misleading status")
        print(json.dumps(status(run),indent=2))
        return 0
    plan = build_plan(args.batch, args.godot, args.visual_mode, args.linux_godot)
    if args.check or args.execute:
        os.environ["PATH"]="/root/.local/share/nightgrid-python/bin:/usr/lib/wsl/lib:"+os.environ.get("PATH","")
    if args.check:
        print(json.dumps(preflight(args.godot,args.linux_godot,args.visual_mode),indent=2))
        return 0
    if not args.execute:
        for profile, short in (("reception", "rec"), ("synaxis-ground", "ground")):
            plan[profile][0].extend(["--batch", f"postmusic-{args.batch}-{short}-1"])
        plan["inventory"][0].extend(["--output", str(NAS / "Visual/ProductionRuns" / args.batch / "inventory.json")])
        run = NAS / "Visual/ProductionRuns" / args.batch
        plan["review_packet"][0].extend(["--output", str(run / "review-1.zip")])
        plan["review_detail"][0].extend(["--output", str(run / "review-detail-1.zip")])
        plan["evidence"][0].extend(["--run", str(run)])
        print(json.dumps({name: {"argv": argv, "env": env} for name, (argv, env) in plan.items()}, indent=2))
        return 0
    version = preflight(args.godot,args.linux_godot,args.visual_mode)
    source = git("rev-parse", "HEAD")
    run = NAS / "Visual/ProductionRuns" / args.batch
    run.mkdir(parents=True, exist_ok=True)
    if run.is_symlink():
        raise RuntimeError("Unsafe run directory")
    state_path = run / "production.json"
    env = dict(os.environ, ANUBIS_VISUAL_HOME=str(HOME), HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1",
               NPM_CONFIG_OFFLINE="true", PIP_NO_INDEX="1", ANUBIS_REQUIRE_EXISTING_SETUP="1",
               PYTHONDONTWRITEBYTECODE="1", PYTHONUNBUFFERED="1")
    env["PATH"] = env.get("PATH", "") + ":/usr/lib/wsl/lib"
    for key in ("ANUBIS_VISUAL_CATALOG", "ANUBIS_GENERATION_REPO", "ANUBIS_VISUAL_NAS", "ANUBIS_VISUAL_OUT", "ANUBIS_REFINED_OUT"):
        env.pop(key, None)
    signature = {"source": source, "godot": version, "godot_path": args.godot, "linux_godot_path": args.linux_godot, "factory_home": str(HOME),
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
        # Operator pause is cooperative, never kills a running native bake.
        # A stage bound is a scheduling choice, not a change to job settings.
        for name in STAGES:
            if (run/"PAUSE").exists():
                print("PAUSED at stage boundary; remove PAUSE and rerun unchanged command.",flush=True)
                return 0
            if args.until and STAGES.index(name)>STAGES.index(args.until):
                print("Requested stage boundary reached; rerun without --until to continue.",flush=True)
                return 0
            entry = state["entries"][name]
            if entry["status"] == "completed":
                if name == "music" and not music_complete(NAS / "Music" / MUSIC):
                    raise RuntimeError("Completed music checkpoint no longer verifies; inspect existing batch")
                if name in ("reception", "synaxis-ground") and not (Path(entry["candidate"]) / "validated-bake.json").is_file():
                    raise RuntimeError("Completed lighting checkpoint missing; inspect existing candidate")
                if not (run / entry["log"]).is_file():
                    raise RuntimeError("Completed stage log missing; inspect run")
                if name in ("inventory","review_packet","review_detail") and sha(run / entry["artifact"]) != entry["artifact_sha256"]:
                    raise RuntimeError("Completed artifact changed; inspect run")
                if name == "evidence":
                    # Reverify all indexed outputs when resuming a finished run.
                    # Use the existing mesh venv (NumPy/Pillow-dependent generators).
                    output = subprocess.check_output([str(HOME / "mesh/bin/python"), "-c",
                        "import sys; from pathlib import Path; from production_evidence import index; "
                        "import json; print(json.dumps(index(Path(sys.argv[1]),Path(sys.argv[2])),sort_keys=True))",
                        str(NAS), str(run)], cwd=ROOT/"tools/asset_refinement", env=env, text=True)
                    if json.loads(output) != json.loads((run/"candidate-index.json").read_text()):
                        raise RuntimeError("Completed evidence changed; inspect run")
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
            elif name in ("inventory", "review_packet", "review_detail"):
                artifact = ("inventory.json" if name == "inventory" else
                            f"review-detail-{attempt}.zip" if name == "review_detail" else f"review-{attempt}.zip")
                entry["artifact"] = artifact
                argv += ["--output", str(run / artifact)]
            elif name == "evidence":
                argv += ["--run", str(run)]
            if name in ("layouts", "street_plan", "regional_plan", "botanical", "impostors", "environments", "decals", "district_buildings", "evidence", "inventory", "review_packet", "review_detail"):
                guard_logs = HOME / "guard-logs"
                guard_logs.mkdir(exist_ok=True)
                argv = [sys.executable, "tools/asset_refinement/resource_guard.py",
                        "--log", str(guard_logs / f"{args.batch}-{name}-{attempt}.jsonl"), "--", *argv]
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
                                            stdout=out, stderr=subprocess.STDOUT,
                                            pass_fds=(lease.fileno(),)).returncode
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
            if rc == 0 and name in ("inventory","review_packet","review_detail"):
                try:
                    entry["artifact_sha256"] = sha(run / entry["artifact"])
                except OSError as exc:
                    entry["error"] = str(exc)
                    rc=1
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
    mode=p.add_mutually_exclusive_group()
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--check", action="store_true",help="Check existing dependencies and storage without launching jobs")
    mode.add_argument("--status",action="store_true",help="Read existing run ledger without launching jobs")
    p.add_argument("--until",choices=STAGES,help="Execute through this stage then stop; rerun without to continue")
    p.add_argument("--batch", default="render-001")
    p.add_argument("--godot", default=NATIVE)
    p.add_argument("--linux-godot", default=os.environ.get("ANUBIS_GODOT","/usr/local/bin/godot"))
    p.add_argument("--visual-mode", choices=("full", "existing"), default="full")
    a = p.parse_args()
    if a.until and not a.execute:
        p.error("--until requires --execute")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,15}", a.batch):
        p.error("batch must be 1–16 lowercase letters/digits/hyphens")
    return dispatch(a)


if __name__ == "__main__":
    sys.exit(main())
