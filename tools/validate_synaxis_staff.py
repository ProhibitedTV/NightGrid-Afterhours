"""Validate the generated fictional supervisor asset before binary intake."""
import hashlib
import json
from pathlib import Path
from validate_synaxis_suit import read_glb

ROOT = Path("assets/models/nightgrid/synaxis_staff")
MODEL = ROOT / "mika_torres.glb"
PROFILE = ROOT / "mika_torres.json"

def verify():
    doc, raw = read_glb(MODEL)
    assert len(doc["skins"]) == 1 and len(doc["skins"][0]["joints"]) >= 55
    assert not any("uri" in image and not image["uri"].startswith("data:") for image in doc.get("images", []))
    assert not any("uri" in buffer and not buffer["uri"].startswith("data:") for buffer in doc["buffers"])
    weighted = [p for mesh in doc["meshes"] for p in mesh["primitives"] if {"POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"} <= p["attributes"].keys()]
    assert weighted, "No weighted textured geometry"
    names = [m.get("name", "").lower() for m in doc["materials"]]
    for required in ("suit jacket", "shirt and tie", "suit trousers", "skin"):
        assert any(required in name for name in names), (required, names)
    assert any("oxford" in name or "shoe" in name for name in names)
    assert not any("backpack" in name or "cargo" in name or "gloves" in name for name in names)
    assert any("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in doc["materials"])
    assert any("normalTexture" in m for m in doc["materials"])
    clips = {a["name"] for a in doc["animations"] if a.get("channels")}
    assert {"Idle", "Walk"} <= clips, clips
    manifest = {"model": MODEL.name, "sha256": hashlib.sha256(raw).hexdigest(),
                "profile_sha256": hashlib.sha256(PROFILE.read_bytes()).hexdigest(),
                "bytes": len(raw), "joints": len(doc["skins"][0]["joints"]),
                "weighted_primitives": len(weighted), "clips": sorted(clips),
                "source": "ara3d@0.13.0", "source_revision": "9d3b9f9933cbeb9529630a270ffc7fe01bd05511",
                "license_notes": "See ../courier/SOURCE.md; original fictional character profile"}
    (ROOT / "mika_torres_source.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("SYNAXIS STAFF PILOT PASS", manifest)

if __name__ == "__main__":
    verify()
