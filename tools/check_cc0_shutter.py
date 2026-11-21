#!/usr/bin/env python3
"""Offline licensing and integrity gate for the imported Poly Haven CC0 model.

This is deliberately separate from fetching: an ordinary PR/Windows build
must never require a network connection or download art silently.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath

ROOT = Path("assets/models/polyhaven/rollershutter_window_01")
SOURCE = ROOT / "SOURCE.json"
MODEL = ROOT / "rollershutter_window_01.gltf"


def checked_path(name: str) -> Path:
    value = PurePosixPath(name)
    if value.is_absolute() or not value.parts or ".." in value.parts:
        raise AssertionError("Unsafe glTF relative path: " + name)
    return ROOT / Path(*value.parts)


def main() -> None:
    manifest = json.loads(SOURCE.read_text(encoding="utf-8"))
    assert manifest["asset"] == "rollershutter_window_01"
    assert manifest["license"] == "CC0 1.0"
    assert manifest["license_url"] == "https://polyhaven.com/license"
    assert manifest["source_page"] == "https://polyhaven.com/a/rollershutter_window_01"
    assert manifest["resolution"] == "1k"
    assert manifest["runtime_download_required"] is False
    files = manifest["files"]
    assert 4 <= len(files) <= 10
    for relative, spec in files.items():
        target = checked_path(relative)
        data = target.read_bytes()
        assert 0 < len(data) <= 24_000_000, target
        assert len(data) == int(spec["bytes"]), target
        assert hashlib.sha256(data).hexdigest() == spec["sha256"], target
        assert spec["source"].startswith("https://dl.polyhaven.org/"), target
    model = json.loads(MODEL.read_text(encoding="utf-8"))
    assert model["asset"]["version"] == "2.0"
    assert len(model["meshes"]) == 2
    assert len(model["materials"]) == 2
    assert len(model["images"]) >= 4
    assert len(model["accessors"]) >= 8
    for item in model.get("images", []) + model.get("buffers", []):
        assert checked_path(item["uri"]).is_file(), item["uri"]
    materials = model["materials"]
    for material in materials:
        assert "baseColorTexture" in material["pbrMetallicRoughness"]
        assert "metallicRoughnessTexture" in material["pbrMetallicRoughness"]
        assert "normalTexture" in material
    for mesh in model["meshes"]:
        for primitive in mesh["primitives"]:
            assert "TEXCOORD_0" in primitive["attributes"]
            assert "NORMAL" in primitive["attributes"]
    print("POLYHAVEN_SHUTTER_SOURCE PASS: 1K official CC0 photographic glTF,"
          f" {len(files)} SHA256-verified files, two modeled PBR shutter variants")


if __name__ == "__main__":
    main()
