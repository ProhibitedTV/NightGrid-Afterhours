#!/usr/bin/env python3
"""Offline source/license, photoscan geometry and PBR road decal audit.

Verifies the two official CC0 Poly Haven glTF packages and original CC0
bitumen-derived static decal atlas. CI runs with no network and no Pillow.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath

ROOT = Path("assets/models/polyhaven")
DECALS = Path("assets/pbr/nightgrid/central_exchange")
ASSETS = ("metal_trash_can", "utility_box_01")


def checked(directory: Path, path: str) -> Path:
    safe = PurePosixPath(path)
    assert not safe.is_absolute() and safe.parts and ".." not in safe.parts and "\\" not in path
    return directory.joinpath(*safe.parts)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_model(asset: str) -> None:
    directory = ROOT / asset
    manifest = json.loads((directory / "SOURCE.json").read_text(encoding="utf-8"))
    assert manifest["asset"] == asset
    assert manifest["source_page"] == f"https://polyhaven.com/a/{asset}"
    assert manifest["license"] == "CC0 1.0"
    assert manifest["license_url"] == "https://polyhaven.com/license"
    assert manifest["resolution"] == "1k"
    assert manifest["runtime_download_required"] is False
    files = manifest["files"]
    assert 5 <= len(files) <= 14
    for name, info in files.items():
        target = checked(directory, name)
        assert target.is_file() and target.stat().st_size == info["bytes"]
        assert digest(target) == info["sha256"]
        assert info["source"].startswith("https://dl.polyhaven.org/")
    model = json.loads((directory / (asset + ".gltf")).read_text(encoding="utf-8"))
    assert model["asset"]["version"] == "2.0"
    assert len(model["meshes"]) == (8 if asset == "metal_trash_can" else 1)
    assert model.get("materials")
    assert sum(g["bytes"] for g in files.values()) < 12_000_000
    if asset == "metal_trash_can":
        assert any("rust" in (mesh.get("name") or "").lower() for mesh in model["meshes"])
    for reference in model.get("images", []) + model.get("buffers", []):
        uri = reference.get("uri")
        if uri:
            assert checked(directory, uri).is_file(), uri
    for mesh in model["meshes"]:
        for primitive in mesh["primitives"]:
            attr = primitive["attributes"]
            assert all(k in attr for k in ("POSITION", "NORMAL", "TEXCOORD_0"))
            assert model["accessors"][attr["POSITION"]]["count"] >= 100
    for material in model["materials"]:
        pbr = material.get("pbrMetallicRoughness", {})
        assert "baseColorTexture" in pbr and "metallicRoughnessTexture" in pbr
        assert "normalTexture" in material
    print("OFFICIAL_CC0_URBAN_PROP PASS:", asset, len(files), "verified source files")


def check_decals() -> None:
    manifest = json.loads((DECALS / "SOURCE.json").read_text(encoding="utf-8"))
    assert manifest["source_page"] == "https://polyhaven.com/a/bitumen"
    assert manifest["licensed_input"] == "Poly Haven Bitumen CC0 1.0"
    assert manifest["license_url"] == "https://polyhaven.com/license"
    assert manifest["resolution"] == 512
    assert manifest["runtime_download_required"] is False
    generator = Path("tools/author_exchange_grime_decals.py")
    assert digest(generator) == manifest["generator_sha256"]
    photo_root = Path("assets/pbr/polyhaven")
    for name, sha in manifest["input_sha256"].items():
        assert digest(photo_root / name) == sha, name
    files = manifest["files"]
    assert len(files) == 6
    for kind in ("oil", "grit"):
        for part in ("albedo", "orm", "normal"):
            filename = f"{kind}_{part}_512.png"
            record = files[filename]
            target = DECALS / filename
            assert target.is_file() and target.stat().st_size == record["bytes"]
            assert digest(target) == record["sha256"], filename
            assert target.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    assert sum(f["bytes"] for f in files.values()) < 8_000_000
    print("PHOTO_DECAL_ATLAS PASS: 2 variants, 6 CC0-derived PNG maps, offline, hash pinned")


def main() -> None:
    for asset in ASSETS:
        check_model(asset)
    check_decals()


if __name__ == "__main__":
    main()
