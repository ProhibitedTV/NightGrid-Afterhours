"""Candidate-only standing character export using the existing pinned Ara route."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import time
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROFILES = Path(__file__).with_name("character_profiles")
PACKAGE = "ara3d@0.13.0"
REVISION = "9d3b9f9933cbeb9529630a270ffc7fe01bd05511"
CORE_CAST = {"dev_rao": "Dev Rao", "rina_vale": "Rina Vale",
             "dana_mercer": "Dana Mercer", "jetson_wang": "Jetson Wang"}
REMAINING_STAFF = {"mika_torres": "Mika Torres", "eli_brooks": "Eli Brooks",
                   "owen_pike": "Owen Pike", "nina_bell": "Nina Bell"}
STREET_PILOT = {
    "brickwater_resident_01": "Brickwater resident 01",
    "brickwater_resident_02": "Brickwater resident 02",
    "brickwater_night_worker_01": "Brickwater night worker 01",
    "brickwater_night_worker_02": "Brickwater night worker 02",
    "vesper_market_visitor_01": "Vesper market visitor 01",
    "vesper_market_visitor_02": "Vesper market visitor 02",
    "afterhours_patron_01": "Afterhours patron 01",
    "afterhours_patron_02": "Afterhours patron 02",
    "dock_worker_01": "Dock worker 01",
    "dock_worker_02": "Dock worker 02",
    "horizon_visitor_01": "Horizon visitor 01",
    "horizon_visitor_02": "Horizon visitor 02",
    "security_base_01": "Security uniform base 01",
    "security_base_02": "Security uniform base 02",
    "service_staff_01": "Service staff 01",
    "service_staff_02": "Service staff 02"
}
ACTORS = {**CORE_CAST, **REMAINING_STAFF, **STREET_PILOT}
BATCHES = {"core": tuple(CORE_CAST), "remaining-staff": tuple(REMAINING_STAFF), "street-pilot": tuple(STREET_PILOT), "all": tuple(ACTORS)}
ANIMATIONS = {
    "dev_rao": ("idle", "walk", "carry_idle", "talk_gestures"),
    "rina_vale": ("idle", "walk", "talk_gestures"),
    "dana_mercer": ("idle", "walk", "sit_down", "sit_idle", "stand_up"),
    "jetson_wang": ("idle", "walk", "sit_down", "sit_idle", "stand_up"),
    "mika_torres": ("idle", "walk", "talk_gestures"),
    "eli_brooks": ("idle", "walk", "carry_idle", "talk_gestures"),
    "owen_pike": ("idle", "walk", "talk_gestures"),
    "nina_bell": ("idle", "walk", "talk_gestures"),
}
ANIMATIONS.update({actor: ("idle", "walk", "talk_gestures") for actor in STREET_PILOT})
CLIPS = {"Idle", "Walk"}
MAX_BYTES = 18_000_000


def sha(data):
    return hashlib.sha256(data).hexdigest()


def profile(actor):
    raw = (PROFILES / (actor + ".json")).read_bytes().replace(b"\r\n", b"\n")
    doc = json.loads(raw)
    p = doc["params"]
    if (doc["kind"] != "ara-character" or doc["version"] != 1 or
            p["name"] != ACTORS[actor] or p["rig"] != "game" or p["restPose"] != "A" or
            p["carry"] != "none" or p["weapon"] != "none" or p["vehicle"] != "none"):
        raise ValueError("Unexpected standing cast profile")
    rectangular = p.get("modifiers", {}).get("head/head-rectangular", 0)
    if type(rectangular) not in (float, int) or not 0 <= rectangular <= 1:
        raise ValueError("The Ara head/head-rectangular modifier must be between 0 and 1")
    return raw


def inspect_glb(path, required_clips=CLIPS):
    if not path.is_file() or path.is_symlink() or not 20 <= path.stat().st_size <= MAX_BYTES:
        raise ValueError("Missing, unsafe or oversized GLB")
    raw = path.read_bytes()
    magic, version, length, n, kind = struct.unpack_from("<4sIIII", raw)
    if (magic != b"glTF" or version != 2 or length != len(raw) or
            kind != 0x4E4F534A or not 0 < n <= len(raw)-20):
        raise ValueError("Invalid GLB header")
    doc = json.loads(raw[20:20+n])
    if any("uri" in row for key in ("buffers", "images") for row in doc.get(key, [])):
        raise ValueError("External or inline URI not accepted; require embedded GLB")
    skins = doc.get("skins", [])
    nodes = doc.get("nodes", [])
    if len(skins) != 1:
        raise ValueError("Require one character skin")
    joints = skins[0]["joints"]
    if (len(joints) < 55 or len(set(joints)) != len(joints) or
            any(type(j) is not int or not 0 <= j < len(nodes) for j in joints)):
        raise ValueError("Invalid or incomplete character joint set")
    required = {"POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"}
    meshes = doc.get("meshes", [])
    accessors = doc.get("accessors", [])
    weighted = 0
    for node in nodes:
        if node.get("skin") != 0 or "mesh" not in node:
            continue
        for p in meshes[node["mesh"]]["primitives"]:
            attrs = p["attributes"]
            if required <= attrs.keys():
                if any(type(attrs[k]) is not int or not 0 <= attrs[k] < len(accessors)
                       or accessors[attrs[k]].get("count", 0) <= 0 for k in required):
                    raise ValueError("Invalid weighted geometry accessors")
                if len({accessors[attrs[k]]["count"] for k in required}) != 1:
                    raise ValueError("Weighted attribute count mismatch")
                weighted += 1
    materials = doc.get("materials", [])
    clips = {a["name"] for a in doc.get("animations", []) if a.get("channels")}
    def normalize(clip):
        key = "".join(c for c in clip.lower() if c.isalnum())
        aliases = {"talkwithgestures": "talkgestures", "sitdownchair": "sitdown",
                   "sitidlechair": "sitidle", "standupchair": "standup"}
        return aliases.get(key, key)
    if (not weighted or not {normalize(clip) for clip in required_clips} <= {normalize(clip) for clip in clips} or
            not any("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in materials) or
            not any("normalTexture" in m for m in materials)):
        raise ValueError("Missing weighted geometry, required clips or textured materials")
    return {"sha256": sha(raw), "bytes": len(raw), "joints": len(joints),
            "weighted_primitives": weighted, "clips": sorted(clips)}


def plan(actor, out):
    folder = out / actor
    executable = "npx"
    if os.name == "nt":
        executable = shutil.which("npx.cmd") or "npx.cmd"
    return [executable, "--yes", PACKAGE, "export", "--params", str(folder/"profile.json"),
            "--out", str(folder/"export"), "--animations", ",".join(ANIMATIONS[actor])]


def verified_candidate(folder, actor, profile_bytes):
    if (folder.is_symlink() or (folder/"export").is_symlink()
            or (folder/"candidate.json").is_symlink()):
        raise ValueError("Unsafe candidate path")
    record = json.loads((folder/"candidate.json").read_text(encoding="utf-8"))
    models = sorted((folder/"export").glob("*.glb"))
    if (len(models) != 1 or record.get("actor") != actor
            or record.get("profile_sha256") != sha(profile_bytes)
            or record.get("package") != PACKAGE
            or record.get("documented_source_revision") != REVISION
            or record.get("model") != models[0].relative_to(folder).as_posix()
            or record.get("structural") != inspect_glb(models[0], ANIMATIONS[actor])):
        raise ValueError("Existing candidate mismatch; preserve and inspect: " + actor)
    return record, models[0]


def reuse_candidate(out, actor, profile_bytes):
    # Reuse only an exact profile + model hash with the required clips; no
    # assumption that a previous candidate was artistically approved.
    matches = {}
    for batch in sorted(out.parent.iterdir()):
        if batch == out or batch.is_symlink() or not batch.is_dir():
            continue
        candidate = batch/actor
        if not (candidate/"candidate.json").is_file():
            continue
        try:
            record, model = verified_candidate(candidate, actor, profile_bytes)
        except (OSError, ValueError, KeyError, TypeError, struct.error):
            continue
        matches.setdefault(record["structural"]["sha256"], (candidate, record, model))
    if len(matches) != 1:
        if matches:
            print("Multiple exact-profile candidates; retaining all and generating fresh:", actor, flush=True)
        return False
    source, record, model = next(iter(matches.values()))
    stage = Path(tempfile.mkdtemp(prefix="."+actor+".reuse-",dir=out))
    (stage/"export").mkdir()
    (stage/"profile.json").write_bytes(profile_bytes)
    shutil.copy2(model, stage/"export"/model.name)
    record["reused_from"] = str(source)
    (stage/"candidate.json").write_text(json.dumps(record,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    verified_candidate(stage,actor,profile_bytes)
    if (out/actor).exists(): raise FileExistsError(out/actor)
    stage.rename(out/actor)
    print("REUSE verified candidate", actor, "from", source, flush=True)
    return True


def run(out, actors, execute=False, resume=False, reuse=False):
    out = out.resolve()
    if ROOT == out or ROOT in out.parents or out in ROOT.parents:
        raise ValueError("Use a separate candidate library outside the game checkout")
    if len(set(actors)) != len(actors):
        raise ValueError("Duplicate actor")
    profiles = {a: profile(a) for a in actors}
    if len({json.loads(raw)["params"]["seed"] for raw in profiles.values()}) != len(actors):
        raise ValueError("Duplicate character seed")
    if not execute:
        for actor in actors:
            print(json.dumps({"actor": actor, "profile_sha256": sha(profiles[actor]),
                              "command": plan(actor, out), "status": "planned-only"}))
        return
    out.mkdir(parents=True, exist_ok=resume)
    for actor in actors:
        folder = out / actor
        if folder.exists():
            if not resume or folder.is_symlink() or not folder.is_dir():
                raise ValueError("Unexpected existing actor path: " + str(folder))
            if (folder/"candidate.json").exists():
                verified_candidate(folder, actor, profiles[actor])
                print("SKIP verified", actor, flush=True)
                continue
            preserved = out/(actor + ".partial.previous-" + str(time.time_ns()))
            folder.rename(preserved)
            print("Preserved incomplete export:", preserved, flush=True)
        if reuse and reuse_candidate(out, actor, profiles[actor]):
            continue
        folder.mkdir()
        (folder/"profile.json").write_bytes(profiles[actor])
        subprocess.run(plan(actor, out), cwd=ROOT, check=True, timeout=900)
        record_candidate(folder, actor, profiles[actor], plan(actor, out))


def record_candidate(folder, actor, profile_bytes, command):
    models = sorted((folder/"export").glob("*.glb"))
    if len(models) != 1:
        raise ValueError("Expected exactly one exported GLB for " + actor)
    model = models[0]
    evidence = inspect_glb(model, ANIMATIONS[actor])
    tmp = folder/"candidate.json.partial"
    tmp.write_text(json.dumps({
        "schema": 1, "status": "candidate-only", "actor": actor,
        "profile_sha256": sha(profile_bytes), "package": PACKAGE,
        "documented_source_revision": REVISION, "command": command,
        "model": model.relative_to(folder).as_posix(), "structural": evidence,
        "review_pending": ["rights", "appearance", "physical scale", "weight deformation",
                           "animation", "native Godot import", "Windows performance"]
    }, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    os.replace(tmp, folder/"candidate.json")
    print("Candidate only:", actor, evidence, flush=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", type=Path, required=True)
    selection = p.add_mutually_exclusive_group()
    selection.add_argument("--actor", action="append", choices=ACTORS)
    selection.add_argument("--batch", choices=BATCHES, default="core",
                           help="Default preserves the original four-actor queue")
    p.add_argument("--execute", action="store_true", help="Actually invoke local Node exporter; first run may download")
    p.add_argument("--resume", action="store_true", help="Verify completed actors and preserve interrupted ones")
    p.add_argument("--reuse-existing", action="store_true", help="Reuse a uniquely hash-verified exact-profile candidate from sibling batches")
    args = p.parse_args()
    run(args.out, args.actor or list(BATCHES[args.batch]), args.execute, args.resume, args.reuse_existing)
