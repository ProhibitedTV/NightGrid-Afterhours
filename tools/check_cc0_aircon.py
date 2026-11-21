#!/usr/bin/env python3
"""Audit the *committed*, original Poly Haven CC0 exterior HVAC asset.

CI has no download step: verifies every source byte, official provenance and
retained glTF normals/UVs/photo textures before any Windows export.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath

ROOT = Path("assets/models/polyhaven/exterior_aircon_unit")
ASSET = "exterior_aircon_unit"


def checked(relative: str) -> Path:
    target = PurePosixPath(relative)
    if target.is_absolute() or not target.parts or ".." in target.parts or "\\" in relative:
        raise AssertionError(f"Unsafe source dependency: {relative!r}")
    return ROOT.joinpath(*target.parts)


def main() -> None:
    source = json.loads((ROOT / "SOURCE.json").read_text(encoding="utf-8"))
    assert source["asset"] == ASSET
    assert source["license"] == "CC0 1.0"
    assert source["license_url"] == "https://polyhaven.com/license"
    assert source["source_page"] == "https://polyhaven.com/a/exterior_aircon_unit"
    assert source["resolution"] == "1k"
    assert source["runtime_download_required"] is False
    files = source["files"]
    assert 8 <= len(files) <= 25
    total = 0
    for relative, info in files.items():
        path = checked(relative)
        data = path.read_bytes()
        assert data and len(data) <= 30_000_000, path
        assert len(data) == int(info["bytes"]), path
        assert hashlib.sha256(data).hexdigest() == info["sha256"], path
        assert info["source"].startswith("https://dl.polyhaven.org/"), path
        total += len(data)
    assert total < 48_000_000
    model = json.loads((ROOT / (ASSET + ".gltf")).read_text(encoding="utf-8"))
    assert model["asset"]["version"] == "2.0"
    assert len(model["meshes"]) == 2, "Expected clean and rusted source variants"
    assert len(model["materials"]) == 4
    for element in model.get("buffers", []) + model.get("images", []):
        if element.get("uri"):
            assert checked(element["uri"]).is_file()
    for mesh in model["meshes"]:
        assert len(mesh["primitives"]) >= 2
        for primitive in mesh["primitives"]:
            attrs = primitive["attributes"]
            assert "POSITION" in attrs and "NORMAL" in attrs and "TEXCOORD_0" in attrs
    for material in model["materials"]:
        pbr = material["pbrMetallicRoughness"]
        assert "baseColorTexture" in pbr
        assert "metallicRoughnessTexture" in pbr
        assert "normalTexture" in material
    print("POLYHAVEN_AIRCON_SOURCE PASS: two source meshes, four genuine PBR materials,",
          len(files), "hashed official files,", total, "bytes")


if __name__ == "__main__":
    main()
