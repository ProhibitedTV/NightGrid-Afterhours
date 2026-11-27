#!/usr/bin/env python3
"""Offline, read-only musical cue briefing and local model readiness inspection.

No installation, execution, network calls, GPU reservation, source rewriting or release.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys

ID = re.compile(r"^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$")
MODEL = {"ace-step", "audiocraft-musicgen"}
ROLES = {"non-diegetic cinematic underscore", "diegetic cabinet loop", "diegetic venue performance"}
REQUIRED = ("id", "model_preference", "scene", "direction", "role", "start_event", "stop_event", "mix_notes")


def validate_briefs(value):
    if not isinstance(value, dict) or value.get("schema") != 1 or value.get("generation_mode") != "offline_candidate_only":
        raise ValueError("Cue brief must be schema 1, candidate-only")
    cues = value.get("cues")
    if not isinstance(cues, list) or not cues:
        raise ValueError("Nonempty cues required")
    ids = set()
    for cue in cues:
        if not isinstance(cue, dict):
            raise ValueError("Cue must be an object")
        for name in REQUIRED:
            if not isinstance(cue.get(name), str) or not cue[name].strip():
                raise ValueError("Invalid " + name)
        if not ID.fullmatch(cue["id"]) or cue["id"] in ids:
            raise ValueError("Invalid or repeated cue ID")
        ids.add(cue["id"])
        if cue["model_preference"] not in MODEL or cue["role"] not in ROLES:
            raise ValueError("Unknown model or cue role")
        if type(cue.get("duration_target_seconds")) is not int or not 1 <= cue["duration_target_seconds"] <= 600:
            raise ValueError("Cue duration must be 1..600 seconds")
    return cues


def readiness(env):
    """Presence is all we can infer without running the isolated model envs."""
    reported = {}
    for model, key in (("ace-step", "ANUBIS_ACE_STEP_PYTHON"),
                       ("audiocraft-musicgen", "ANUBIS_AUDIOCRAFT_PYTHON")):
        value = env.get(key, "")
        path = Path(value).expanduser() if value else None
        ok = bool(path and path.is_absolute() and path.is_file())
        reported[model] = {"configured": bool(value), "python_present": ok,
                           "ready": False,
                           "reason": "Environment existence alone does not validate model weights, GPU, rights or runtime"}
    return reported


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--briefs", type=Path, default=Path(__file__).with_name("anubis_music_cue_briefs.json"))
    p.add_argument("--check-local", action="store_true", help="Inspect optional local Python paths without launching them")
    a = p.parse_args(argv)
    try:
        cues = validate_briefs(json.loads(a.briefs.read_text(encoding="utf-8")))
        report = {"schema": 1, "mode": "planning-only",
                  "cues": [{"id": c["id"], "model_preference": c["model_preference"],
                            "scene": c["scene"], "duration_target_seconds": c["duration_target_seconds"],
                            "status": "not generated"} for c in cues]}
        if a.check_local:
            report["model_readiness"] = readiness(os.environ)
        print(json.dumps(report, sort_keys=True, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print("MUSIC BRIEF FAILED:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
