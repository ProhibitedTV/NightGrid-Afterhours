"""Fetch only pinned CC0 pedestrian candidates into a review staging directory."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from urllib.request import urlopen

MANIFEST = Path(__file__).resolve().parent / "pedestrian_asset_sources.json"

def inspect_glb(data, entry):
    if len(data) != entry["bytes"] or hashlib.sha256(data).hexdigest() != entry["sha256"]:
        raise ValueError("Source length or SHA-256 mismatch: " + entry["id"])
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("Invalid GLB header")
    chunk_size, chunk_type = struct.unpack_from("<I4s", data, 12)
    if chunk_type != b"JSON" or not 0 < chunk_size <= len(data)-20:
        raise ValueError("Invalid GLB JSON chunk")
    model = json.loads(data[20:20+chunk_size])
    if model["asset"]["version"] != "2.0":
        raise ValueError("Expected glTF 2.0")
    # A GLB candidate must be self contained, not retrieve external resources.
    if any("uri" in item for key in ("images", "buffers") for item in model.get(key, [])):
        raise ValueError("External or embedded URI references require manual review")
    clips = {clip.get("name") for clip in model.get("animations", [])}
    if not set(entry["clips"]).issubset(clips):
        raise ValueError("Missing expected animation names")
    skins = model.get("skins", [])
    if not skins or max(len(skin["joints"]) for skin in skins) < 20:
        raise ValueError("Missing humanoid skeleton")
    primitives = [p for mesh in model.get("meshes", []) for p in mesh.get("primitives", [])]
    if not any({"JOINTS_0", "WEIGHTS_0"}.issubset(p.get("attributes", {})) for p in primitives):
        raise ValueError("Missing weighted mesh")
    return {"id": entry["id"], "sha256": entry["sha256"], "bytes": len(data),
            "clips": sorted(clips), "skin_joints": [len(s["joints"]) for s in skins],
            "extensions_required": model.get("extensionsRequired", []),
            "extensions_used": model.get("extensionsUsed", []),
            "godot_import_validated": False}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--offline", action="store_true", help="Verify previously downloaded files")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest["license"] != "CC0-1.0":
        raise ValueError("Unexpected source license")
    args.out.mkdir(parents=True, exist_ok=True)
    report = []
    for entry in manifest["assets"]:
        path = args.out / (entry["id"] + ".glb")
        if args.offline or path.exists():
            data = path.read_bytes()
        else:
            with urlopen(entry["url"], timeout=45) as response:
                data = response.read(entry["bytes"] + 1)
        result = inspect_glb(data, entry)
        if not path.exists():
            path.write_bytes(data)
        report.append(result)
        print(json.dumps(result))
    (args.out / "intake-report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")

if __name__ == "__main__":
    main()
