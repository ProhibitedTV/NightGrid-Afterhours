#!/usr/bin/env python3
"""Offline original 3D storefront glTF/PBR/license and walk-in portal audit.

No network or Pillow in CI. The authoring branch pins the actual binaries
plus source-photo fingerprints, so every Windows export ships the same kit.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
from pathlib import PurePosixPath

ROOT = Path("assets/models/nightgrid/central_exchange_storefront")
MODELS = ("brickwater_retail", "afterhours_repair")
SOURCES = {
    "https://polyhaven.com/a/brick_wall_001",
    "https://polyhaven.com/a/blue_metal_plate",
    "https://polyhaven.com/a/bitumen",
    "https://polyhaven.com/a/concrete_floor_01",
}

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def safe_path(text):
    rel = PurePosixPath(text)
    assert not rel.is_absolute() and rel.parts and ".." not in rel.parts and "\\" not in text
    return ROOT.joinpath(*rel.parts)

def check_model(source):
    name = source["name"]
    assert source["room_depth_m"] == 3.35 and source["portal_half_width_m"] == 1.42
    assert source["portal_clear_height_m"] == 3.17 and source["display_windows"] == 2
    assert source["physical_stock_items"] >= 25
    assert source["materials"] == 6 and source["added_dynamic_lights"] == 0
    assert source["triangles"] > 1700 and source["vertices"] > 3400
    gltf = json.loads((ROOT/(name+".gltf")).read_text(encoding="utf-8"))
    assert gltf["asset"]["version"] == "2.0"
    assert len(gltf["meshes"]) == 1 and len(gltf["meshes"][0]["primitives"]) == 6
    assert len(gltf["materials"]) == 6 and len(gltf["images"]) == 12
    assert gltf["buffers"][0]["uri"] == name+".bin"
    assert gltf["buffers"][0]["byteLength"] == (ROOT/(name+".bin")).stat().st_size
    tris = 0
    for index, p in enumerate(gltf["meshes"][0]["primitives"]):
        a = p["attributes"]
        assert all(k in a for k in ("POSITION","NORMAL","TANGENT","TEXCOORD_0"))
        assert gltf["accessors"][a["POSITION"]]["count"] > 6
        assert gltf["accessors"][a["NORMAL"]]["count"] == gltf["accessors"][a["POSITION"]]["count"]
        assert gltf["accessors"][a["TANGENT"]]["count"] == gltf["accessors"][a["POSITION"]]["count"]
        tris += gltf["accessors"][p["indices"]]["count"]//3
        material = gltf["materials"][p["material"]]
        if index < 4:
            props = material["pbrMetallicRoughness"]
            assert "baseColorTexture" in props and "metallicRoughnessTexture" in props
            assert "normalTexture" in material
        elif index == 4:
            assert material["alphaMode"] == "BLEND"
            assert material["pbrMetallicRoughness"]["baseColorFactor"][3] < 0.5
        else:
            assert "emissiveFactor" in material
    assert tris == source["triangles"]
    for img in gltf["images"]:
        assert safe_path(img["uri"]).is_file(),img["uri"]
    print("ORIGINAL_WALKIN_SHOP_GLTF_PASS:",name,source["triangles"],
          "triangles / 4 photographic material groups, real transparent glass and practical lenses")

def main():
    document = json.loads((ROOT/"SOURCE.json").read_text(encoding="utf-8"))
    assert document["runtime_download_required"] is False
    assert document["license_url"] == "https://polyhaven.com/license"
    assert set(document["sources"]) == SOURCES
    assert document["permanent_parcels"] == [
        {"ix":-1,"iz":0,"which":1}, {"ix":0,"iz":0,"which":0}]
    assert document["source_saved_world_version_unchanged"] is True
    author=Path(document["source_generator"])
    assert author.is_file() and sha256(author)==document["generator_sha256"]
    assert len(document["source_sha256"])==12
    for path,expected in document["source_sha256"].items():
        assert sha256(Path(path)) == expected, path
    files = document["files"]
    assert len(files) == 16
    assert sum(int(entry["bytes"]) for entry in files.values()) < 9_000_000
    for name,entry in files.items():
        path=safe_path(name)
        assert path.is_file() and path.stat().st_size == entry["bytes"]
        assert sha256(path)==entry["sha256"],name
    assert {p["name"] for p in document["models"]} == set(MODELS)
    for item in document["models"]:
        check_model(item)
    print("SOURCE_AUTHORED_STOREFRONT_AUDIT_PASS: 2 original 3D walk-in models,",
          "4 licensed CC0 photographic materials, 12 photo maps,",
          "16 bundled SHA256-verified source files and unchanged saved-city address")

if __name__ == "__main__":
    main()
