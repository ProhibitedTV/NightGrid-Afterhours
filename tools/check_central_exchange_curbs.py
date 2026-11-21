#!/usr/bin/env python3
"""Offline auditable source/licensing and glTF geometry gate for original curbs.

Never runs Pillow or makes network requests in CI; source 1K official Poly Haven
concrete and photographed existing 2K steel/bitumen are committed and hashed.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path, PurePosixPath

ROOT = Path("assets/models/nightgrid/central_exchange_curb")
PBR = Path("assets/pbr/polyhaven")
NAMES = ("central_curb_outer_minus","central_curb_outer_plus")

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def safe_file(relative: str) -> Path:
    path=PurePosixPath(relative)
    assert not path.is_absolute() and path.parts and ".." not in path.parts and "\\" not in relative, relative
    return ROOT.joinpath(*path.parts)

def main() -> None:
    info=json.loads((ROOT/"SOURCE.json").read_text(encoding="utf-8"))
    generator=Path(info["authoring_source"])
    assert generator.is_file() and digest(generator)==info["authoring_sha256"]
    assert info["original_asset"].startswith("NightGrid authored beveled 36m")
    assert info["runtime_download_required"] is False
    assert info["license"].startswith("CC0 1.0 source photo texture")
    official=info["source_concrete"]
    assert official["api"]=="https://api.polyhaven.com/files/concrete_floor_01"
    assert official["license"]=="CC0 1.0"
    assert official["original_gltf"].startswith("https://dl.polyhaven.org/")
    assert len(official["texture_sources"])==3
    for name, item in official["texture_sources"].items():
        assert item["url"].startswith("https://dl.polyhaven.org/")
        assert len(item["source_md5"])==32 and len(item["source_sha256"])==64
        assert digest(safe_file("textures/"+name))==item["derived_sha256"]
        assert item["source_bytes"]>0 and item["derived_bytes"]>0
    # Concrete roughness photograph is ORIGINAL, but glTF's B=metallic
    # channel must be zero for asphalt/concrete. The generated ARM is packed
    # PNG, not the upstream grayscale roughness JPG mistakenly mapped to B.
    assert "concrete_arm_1k.png" in official["texture_sources"]
    assert not (ROOT/"textures/concrete_arm_1k.jpg").exists()
    assert (ROOT/"textures/concrete_arm_1k.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    assert len(info["source_existing_2k"])==6
    for relative, sha in info["source_existing_2k"].items():
        assert digest(PBR/relative)==sha
    files=info["files"]
    assert len(files)==13
    assert sum(item["bytes"] for item in files.values())<12_000_000
    for relative, record in files.items():
        file=safe_file(relative)
        assert file.is_file() and file.stat().st_size==record["bytes"]
        assert digest(file)==record["sha256"],relative
    models=info["model_variants"]
    assert len(models)==2
    for name,contract in zip(NAMES,models):
        assert contract["name"]==name
        assert contract["triangles"]>=1500 and contract["vertices"]>=3000
        assert contract["surfaces"]==3 and contract["curb_stones"]==12
        assert contract["steel_grate_frames"]==6 and contract["steel_grate_slots"]==54
        assert contract["concrete_expansion_joints"]==11
        doc=json.loads((ROOT/(name+".gltf")).read_text(encoding="utf-8"))
        assert doc["asset"]["version"]=="2.0"
        assert len(doc["meshes"])==1 and len(doc["meshes"][0]["primitives"])==3
        assert len(doc["materials"])==3 and len(doc["images"])==9
        assert doc["buffers"][0]["uri"]==name+".bin"
        assert doc["buffers"][0]["byteLength"]==(ROOT/(name+".bin")).stat().st_size
        assert sum(doc["accessors"][p["indices"]]["count"]//3 for p in doc["meshes"][0]["primitives"])==contract["triangles"]
        for image in doc["images"]:
            assert safe_file(image["uri"]).is_file(),image["uri"]
        for primitive in doc["meshes"][0]["primitives"]:
            attrs=primitive["attributes"]
            assert all(key in attrs for key in ("POSITION","NORMAL","TANGENT","TEXCOORD_0"))
            assert doc["accessors"][attrs["POSITION"]]["count"]>=100
        for mat in doc["materials"]:
            assert "baseColorTexture" in mat["pbrMetallicRoughness"]
            assert "metallicRoughnessTexture" in mat["pbrMetallicRoughness"]
            assert "normalTexture" in mat
    print("SOURCE_AUTHORED_CENTRAL_CURB_PASS: two original 36m glTF profiles,",
          "9 CC0 PBR maps, 12 slabs and 6 physical gratings each,",
          "13 SHA256-checked files / official concrete license+source")

if __name__=="__main__":
    main()
