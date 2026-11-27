"""Candidate-only standing character export using the existing pinned Ara route."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PROFILES = Path(__file__).with_name("character_profiles")
PACKAGE = "ara3d@0.13.0"
REVISION = "9d3b9f9933cbeb9529630a270ffc7fe01bd05511"
ACTORS = {"dev_rao": "Dev Rao", "rina_vale": "Rina Vale"}
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
    return raw


def inspect_glb(path):
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
    if (not weighted or not CLIPS <= clips or
            not any("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in materials) or
            not any("normalTexture" in m for m in materials)):
        raise ValueError("Missing weighted geometry, required clips or textured materials")
    return {"sha256": sha(raw), "bytes": len(raw), "joints": len(joints),
            "weighted_primitives": weighted, "clips": sorted(clips)}


def plan(actor, out):
    folder = out / actor
    return ["npx", "--yes", PACKAGE, "export", "--params", str(folder/"profile.json"),
            "--out", str(folder/"export"), "--animations", "idle,walk"]


def run(out, actors, execute=False):
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
    out.mkdir(parents=True, exist_ok=False)
    for actor in actors:
        folder = out / actor
        folder.mkdir()
        (folder/"profile.json").write_bytes(profiles[actor])
        subprocess.run(plan(actor, out), cwd=folder, check=True, timeout=900)
        models = sorted((folder/"export").glob("*.glb"))
        if len(models) != 1:
            raise ValueError("Expected exactly one exported GLB for " + actor)
        model = models[0]
        evidence = inspect_glb(model)
        (folder/"candidate.json").write_text(json.dumps({
            "schema": 1, "status": "candidate-only", "actor": actor,
            "profile_sha256": sha(profiles[actor]), "package": PACKAGE,
            "documented_source_revision": REVISION, "command": plan(actor, out),
            "model": model.relative_to(folder).as_posix(), "structural": evidence,
            "review_pending": ["rights", "appearance", "physical scale", "weight deformation",
                               "animation", "native Godot import", "Windows performance"]
        }, indent=2, sort_keys=True)+"\n", encoding="utf-8")
        print("Candidate only:", actor, evidence)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--actor", action="append", choices=ACTORS)
    p.add_argument("--execute", action="store_true", help="Actually invoke local Node exporter; first run may download")
    args = p.parse_args()
    run(args.out, args.actor or list(ACTORS), args.execute)
