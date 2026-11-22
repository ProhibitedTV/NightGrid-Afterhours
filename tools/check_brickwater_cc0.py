#!/usr/bin/env python3
"""Audit the exact nine Brickwater source packages, optionally install from CI staging."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "assets/models/polyhaven"
CATALOG = json.loads((ROOT / "tools/brickwater_cc0_intake.json").read_text())
EXPECTED = {
    "modular_urban_apartments_facade": 16488693,
    "modular_fire_escape": 4806126,
    "modular_electric_cables": 6018719,
    "modular_pipes": 5815228,
    "industrial_caged_sconce": 3125535,
    "trashbag": 1699464,
    "cardboard_box_01": 2168437,
    "plastic_crate_01": 3188865,
    "hand_truck": 3179347,
}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def rel(name):
    p = PurePosixPath(name)
    require(name == p.as_posix() and not p.is_absolute() and bool(p.parts)
            and ".." not in p.parts and "\\" not in name and ":" not in name,
            f"Unsafe relative path: {name}")
    return Path(*p.parts)

def check(folder, item):
    asset = item["id"]
    require(folder.is_dir() and not folder.is_symlink(), f"Missing package: {asset}")
    for p in folder.rglob("*"):
        require(not p.is_symlink(), f"Unexpected symlink: {p}")
    manifest = json.loads((folder / "SOURCE.json").read_text())
    require(manifest["asset"] == asset and manifest["author"] == item["author"]
            and manifest["license"] == "CC0 1.0"
            and manifest["license_url"] == "https://polyhaven.com/license"
            and manifest["source_page"] == item["source"]
            and manifest["source_api"] == f"https://api.polyhaven.com/files/{asset}"
            and manifest["resolution"] == "1k"
            and manifest["runtime_download_required"] is False
            and manifest["native_approved"] is False, f"Source metadata mismatch: {asset}")
    files = manifest["files"]
    expected = {"SOURCE.json"}
    total = 0
    for name, rec in files.items():
        path = folder / rel(name)
        expected.add(name)
        require(path.suffix.lower() in (".gltf", ".bin", ".jpg", ".jpeg", ".png"),
                f"Unsupported source file: {name}")
        url = urlparse(rec["source"])
        require(url.scheme == "https" and url.hostname == "dl.polyhaven.org", f"Wrong source: {name}")
        require(path.is_file() and path.stat().st_size == rec["bytes"]
                and 0 < rec["bytes"] <= 32_000_000, f"Length failure: {name}")
        payload = path.read_bytes()
        require(hashlib.sha256(payload).hexdigest() == rec["sha256"]
                and hashlib.md5(payload).hexdigest() == rec["source_md5"], f"Hash failure: {name}")
        total += len(payload)
    require(total == EXPECTED[asset], f"Unexpected package size: {asset}: {total}")
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
    require(actual == expected, f"Unaudited file(s): {actual ^ expected}")
    model_name = asset + ".gltf"
    require(manifest["model"] == model_name and model_name in files, f"Missing glTF: {asset}")
    model = json.loads((folder / model_name).read_text())
    require(model["asset"]["version"] == "2.0" and model["meshes"], f"Invalid glTF: {asset}")
    deps = {model_name}
    for ref in model.get("buffers", []) + model.get("images", []):
        if "uri" in ref:
            name = rel(unquote(ref["uri"])).as_posix()
            require(name in files, f"Unverified glTF dependency: {name}")
            deps.add(name)
    require(deps == set(files), f"Unused source files: {asset}")
    print(f"BRICKWATER_CC0 PASS: {asset}: {total} bytes, {manifest['source_mesh_triangles']} source triangles")
    return total

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--stage", type=Path, help="Downloaded artifact parent (install after complete audit)")
    args = p.parse_args()
    items = CATALOG["assets"]
    require({i["id"] for i in items} == set(EXPECTED) and len(items) == len(EXPECTED), "Catalog changed")
    packages = []
    total = 0
    for item in items:
        aid = item["id"]
        folder = (args.stage / ("brickwater-cc0-" + item["batch"]) / aid
                  if args.stage else DEST / aid)
        total += check(folder, item)
        packages.append((folder, DEST / aid))
    if args.stage:
        for _, dest in packages:
            require(not dest.exists(), f"Refusing to overwrite existing package: {dest}")
        for src, dest in packages:
            shutil.copytree(src, dest)
    print(f"BRICKWATER_CC0 ALL PASS: {len(packages)} packages, {total} verified bytes")

if __name__ == "__main__":
    main()
