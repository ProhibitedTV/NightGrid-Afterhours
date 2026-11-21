#!/usr/bin/env python3
"""Verify the original, already-committed Crane & Gear glTF/PBR source bundle.

This is an offline integrity/geometry/material gate, independent of Pillow or
a workstation asset-download process. The original source generator is pinned.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path, PurePosixPath

ROOT = Path("assets/models/nightgrid/crane_gear")
ASSET = ROOT / "crane_gear_warehouse.gltf"


def safe(relative: str) -> Path:
    path = PurePosixPath(relative)
    assert not path.is_absolute() and path.parts and ".." not in path.parts and "\\" not in relative, relative
    return ROOT.joinpath(*path.parts)


def main() -> None:
    source = json.loads((ROOT / "SOURCE.json").read_text(encoding="utf-8"))
    assert source["name"] == "crane_gear_warehouse"
    assert source["origin"].startswith("Original NightGrid")
    assert source["runtime_download_required"] is False
    author = Path(source["authoring_source"])
    assert author.is_file()
    assert hashlib.sha256(author.read_bytes()).hexdigest() == source["source_generator_sha256"]
    for photo in source["source_material_assets"]:
        assert photo["license"] == "CC0 1.0"
        assert photo["url"].startswith("https://polyhaven.com/a/")
    assert len(source["source_material_assets"]) == 3
    files = source["files"]
    assert len(files) == 11, files.keys()
    for relative, record in files.items():
        data = safe(relative).read_bytes()
        assert data and len(data) <= 8_000_000
        assert len(data) == record["bytes"]
        assert hashlib.sha256(data).hexdigest() == record["sha256"], relative
    assert sum(f["bytes"] for f in files.values()) < 8_000_000
    shape=source["design_features"]
    assert shape["dock_bays"] == 2
    assert shape["front_windows"] >= 12
    assert shape["side_windows"] >= 18
    assert shape["roof_quads"] >= 4
    assert shape["structural_projections"] >= 150

    gltf = json.loads(ASSET.read_text(encoding="utf-8"))
    assert gltf["asset"]["version"] == "2.0"
    assert len(gltf["meshes"]) == 1 and len(gltf["meshes"][0]["primitives"]) == 6
    assert len(gltf["materials"]) == 6
    assert len(gltf["images"]) == 9
    assert gltf["buffers"][0]["uri"] == "crane_gear_warehouse.bin"
    assert gltf["buffers"][0]["byteLength"] == files["crane_gear_warehouse.bin"]["bytes"]
    assert source["model"]["triangles"] >= 2500
    assert source["model"]["vertices"] >= 6000
    for item in gltf["buffers"] + gltf["images"]:
        assert safe(item["uri"]).is_file(), item["uri"]
    for material in gltf["materials"][:3]:
        pbr = material["pbrMetallicRoughness"]
        assert "baseColorTexture" in pbr and "metallicRoughnessTexture" in pbr
        assert "normalTexture" in material
    for primitive in gltf["meshes"][0]["primitives"]:
        attrs=primitive["attributes"]
        assert all(x in attrs for x in ("POSITION","NORMAL","TANGENT","TEXCOORD_0"))
        assert primitive["mode"] == 4
        assert gltf["accessors"][attrs["POSITION"]]["count"] >= 100
    print("ORIGINAL_CRANE_GEAR_GLTF PASS:",source["model"],shape,
          len(files),"hash-verified committed files / original authored glTF + CC0 PBR")


if __name__ == "__main__":
    main()
