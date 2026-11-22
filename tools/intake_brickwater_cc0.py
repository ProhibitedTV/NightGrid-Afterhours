#!/usr/bin/env python3
"""Explicit offline art intake, never called by Godot or normal builds.

Download only glTF dependencies referenced by the original 1K glTF; verify
publisher MD5 and lengths and write SHA256 provenance. Stage outside game.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
from pathlib import Path

from import_polyhaven_urban_props import request_bytes, safe_relative, includes

CATALOG = Path(__file__).with_name("brickwater_cc0_intake.json")
MAX_ASSET = 64_000_000
MAX_BATCH = 160_000_000


def verified(info: dict, remaining: int) -> tuple[bytes, dict]:
    url = info["url"]
    size = info["size"]
    md5 = str(info["md5"]).lower()
    if not isinstance(size, int) or not 0 < size <= min(32_000_000, remaining):
        raise ValueError(f"Unacceptable source length: {url}")
    if not re.fullmatch(r"[0-9a-f]{32}", md5):
        raise ValueError(f"Missing publisher checksum: {url}")
    payload = request_bytes(url, size)
    if len(payload) != size or hashlib.md5(payload).hexdigest() != md5:
        raise ValueError(f"Publisher checksum/length mismatch: {url}")
    return payload, {"source": url, "source_md5": md5, "bytes": size,
                     "sha256": hashlib.sha256(payload).hexdigest()}


def acquire(item: dict, root: Path, budget: int) -> int:
    asset = item["id"]
    if not re.fullmatch(r"[a-z0-9_]+", asset):
        raise ValueError("Invalid asset ID")
    api = f"https://api.polyhaven.com/files/{asset}"
    listing = json.loads(request_bytes(api, 8_000_000))
    entry = listing["gltf"][item["resolution"]]["gltf"]
    budget = min(budget, MAX_ASSET)
    raw, meta = verified(entry, budget)
    model = json.loads(raw)
    if model.get("asset", {}).get("version") != "2.0" or not model.get("meshes"):
        raise ValueError("Expected authored glTF 2.0 mesh")
    model_name = asset + ".gltf"
    dependencies = {}
    for name, info in includes(entry):
        path = safe_relative(name).as_posix()
        if path in dependencies or path in (model_name, "SOURCE.json"):
            raise ValueError(f"Duplicate/reserved dependency: {path}")
        dependencies[path] = info
    wanted = set()
    for ref in model.get("buffers", []) + model.get("images", []):
        uri = ref.get("uri")
        if uri is None:
            continue
        if ":" in uri or "?" in uri or "#" in uri:
            raise ValueError(f"Non-local glTF URI: {uri}")
        name = safe_relative(uri).as_posix()
        if name not in dependencies:
            raise ValueError(f"Unaudited dependency: {name}")
        wanted.add(name)
    triangles = 0
    for mesh in model["meshes"]:
        for primitive in mesh["primitives"]:
            attrs = primitive["attributes"]
            if not all(k in attrs for k in ("POSITION", "NORMAL", "TEXCOORD_0")):
                raise ValueError("Mesh lacks position, normal or UV")
            if primitive.get("mode", 4) != 4:
                raise ValueError("Expected triangle geometry")
            accessors = model["accessors"]
            index = primitive.get("indices", attrs["POSITION"])
            triangles += accessors[index]["count"] // 3
    materials = model.get("materials", [])
    if not any(m.get("pbrMetallicRoughness", {}).get("baseColorTexture") is not None
               for m in materials):
        raise ValueError("No textured PBR color material")
    if not any(m.get("normalTexture") is not None for m in materials):
        raise ValueError("No PBR normal material")
    total = len(raw)
    # Refuse oversized packages before fetching any binary dependencies.
    if total + sum(dependencies[name]["size"] for name in wanted) > budget:
        raise ValueError(f"{asset} exceeds source budget {budget}")
    dest = root / asset
    if dest.exists():
        raise FileExistsError(dest)
    with tempfile.TemporaryDirectory(prefix=".intake-", dir=root) as tmp:
        folder = Path(tmp) / asset
        folder.mkdir()
        (folder / model_name).write_bytes(raw)
        files = {model_name: meta}
        for name in sorted(wanted):
            payload, record = verified(dependencies[name], budget - total)
            path = folder / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
            files[name] = record
            total += len(payload)
        manifest = {
            "asset": asset, "author": item["author"], "source_page": item["source"],
            "source_api": api, "license": "CC0 1.0",
            "license_url": "https://polyhaven.com/license",
            "resolution": item["resolution"], "model": model_name,
            "files": files, "mesh_count": len(model["meshes"]),
            "materials": len(materials), "source_mesh_triangles": triangles,
            "node_names": [n.get("name", "") for n in model.get("nodes", [])],
            "runtime_download_required": False, "native_approved": False,
        }
        (folder / "SOURCE.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        folder.rename(dest)
    print(f"{asset}: {total} verified bytes, {triangles} source triangles")
    return total


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", choices=("architecture", "utilities", "clutter"), required=True)
    parser.add_argument("--out", type=Path, required=True, help="New staging directory outside the game")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    out = args.out.resolve()
    if out == repo or repo in out.parents:
        parser.error("Stage outside the repository (e.g. /tmp/brickwater-clutter)")
    out.mkdir(parents=True, exist_ok=False)
    items = [x for x in json.loads(CATALOG.read_text(encoding="utf-8"))["assets"] if x["batch"] == args.batch]
    total = 0
    for item in items:
        total += acquire(item, out, MAX_BATCH - total)
    print(f"Intake complete: {len(items)} assets, {total} bytes. Native approval still required.")


if __name__ == "__main__":
    main()
