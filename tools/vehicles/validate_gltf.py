#!/usr/bin/env python3
"""Strict, dependency-free geometry gate for NightGrid-authored glTF/GLB assets.

Run on an authored game mesh, not a Blender high-poly reference. This gate
checks structural safety and geometry contracts; it does not judge artistic
quality, performance, or successful Godot rendering.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import struct
from pathlib import Path
from urllib.parse import unquote

COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
              5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
SHAPES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
          "MAT2": 4, "MAT3": 9, "MAT4": 16}


class AssetError(ValueError):
    """Actionable geometry/metadata validation failure."""


def _load_asset(path: Path) -> tuple[dict, list[bytes]]:
    raw = path.read_bytes()
    packed = b""
    if path.suffix.lower() == ".glb":
        if len(raw) < 20:
            raise AssetError("GLB header is truncated")
        magic, version, total = struct.unpack_from("<4sII", raw)
        if magic != b"glTF" or version != 2 or total != len(raw):
            raise AssetError("GLB magic/version/total length is invalid")
        pos = 12
        doc = None
        while pos < len(raw):
            if pos + 8 > len(raw):
                raise AssetError("GLB chunk header is truncated")
            count, tag = struct.unpack_from("<I4s", raw, pos)
            pos += 8
            if pos + count > len(raw):
                raise AssetError("GLB chunk exceeds file length")
            chunk = raw[pos:pos + count]
            pos += count
            if tag == b"JSON":
                if doc is not None:
                    raise AssetError("Duplicate GLB JSON chunk")
                doc = json.loads(chunk.decode("utf-8"))
            elif tag == b"BIN\x00":
                packed = chunk
        if doc is None:
            raise AssetError("Missing GLB JSON chunk")
    elif path.suffix.lower() == ".gltf":
        doc = json.loads(raw.decode("utf-8"))
    else:
        raise AssetError("Expected .gltf or .glb")

    if doc.get("asset", {}).get("version") != "2.0":
        raise AssetError("Only glTF 2.0 assets are supported")
    buffers = []
    for i, record in enumerate(doc.get("buffers", [])):
        uri = record.get("uri")
        if uri is None:
            if path.suffix.lower() != ".glb" or i != 0:
                raise AssetError(f"Buffer {i} has no URI")
            data = packed
        elif uri.startswith("data:application/octet-stream;base64,"):
            try:
                data = base64.b64decode(uri.split(",", 1)[1], validate=True)
            except ValueError as exc:
                raise AssetError(f"Invalid base64 buffer {i}") from exc
        else:
            if ":" in uri or uri.startswith("/") or "\\" in uri:
                raise AssetError(f"Buffer {i} has unsafe URI")
            rel = Path(unquote(uri))
            if not rel.parts or ".." in rel.parts:
                raise AssetError(f"Buffer {i} escapes asset directory")
            base = path.parent.resolve()
            target = (base / rel).resolve()
            if not target.is_relative_to(base):
                raise AssetError(f"Buffer {i} escapes asset directory")
            data = target.read_bytes()
        if len(data) < int(record["byteLength"]):
            raise AssetError(f"Buffer {i} is shorter than declared")
        buffers.append(data)
    return doc, buffers


def _accessor(doc: dict, buffers: list[bytes], index: int) -> list[tuple]:
    try:
        a = doc["accessors"][index]
        if "sparse" in a:
            raise AssetError(f"Sparse accessor {index} needs explicit bake before approval")
        view = doc["bufferViews"][a["bufferView"]]
        data = buffers[view["buffer"]]
        layout, width = COMPONENTS[a["componentType"]]
        channels = SHAPES[a["type"]]
        count = int(a["count"])
        size = channels * width
        stride = int(view.get("byteStride", size))
        if stride < size or stride % width:
            raise AssetError(f"Accessor {index} has invalid stride")
        start = int(view.get("byteOffset", 0)) + int(a.get("byteOffset", 0))
        end = start + (count - 1) * stride + size if count else start
        view_start = int(view.get("byteOffset", 0))
        view_end = view_start + int(view["byteLength"])
        if count < 0 or start < view_start or end > view_end or end > len(data):
            raise AssetError(f"Accessor {index} extends beyond its buffer view")
        fmt = "<" + layout * channels
        return [struct.unpack_from(fmt, data, start + i * stride) for i in range(count)]
    except (KeyError, IndexError, TypeError, struct.error) as exc:
        raise AssetError(f"Accessor {index} has corrupt metadata") from exc


def inspect(path: Path, *, max_triangles: int = 20000,
            required_nodes: tuple[str, ...] = ()) -> dict:
    doc, buffers = _load_asset(path)
    if max_triangles < 1:
        raise AssetError("max_triangles must be positive")
    names = {str(n.get("name", "")) for n in doc.get("nodes", [])}
    absent = sorted(set(required_nodes) - names)
    if absent:
        raise AssetError(f"Missing required sockets/nodes: {', '.join(absent)}")
    if not doc.get("meshes"):
        raise AssetError("No mesh primitives in glTF")
    count_tri = 0
    count_vert = 0
    bounds_min = [math.inf] * 3
    bounds_max = [-math.inf] * 3
    for m_idx, mesh in enumerate(doc["meshes"]):
        for p_idx, primitive in enumerate(mesh.get("primitives", [])):
            tag = f"mesh {m_idx} primitive {p_idx}"
            if primitive.get("mode", 4) != 4:
                raise AssetError(f"{tag}: only triangles supported")
            attr = primitive.get("attributes", {})
            if not {"POSITION", "NORMAL", "TEXCOORD_0"}.issubset(attr):
                raise AssetError(f"{tag}: requires position, normals and UV0")
            if "material" not in primitive or not 0 <= primitive["material"] < len(doc.get("materials", [])):
                raise AssetError(f"{tag}: requires an assigned material")
            positions = _accessor(doc, buffers, attr["POSITION"])
            normals = _accessor(doc, buffers, attr["NORMAL"])
            uvs = _accessor(doc, buffers, attr["TEXCOORD_0"])
            if not positions or len(positions) != len(normals) or len(normals) != len(uvs):
                raise AssetError(f"{tag}: mismatched vertex streams")
            if any(len(v) != 3 or any(not math.isfinite(float(x)) for x in v) for v in positions):
                raise AssetError(f"{tag}: invalid position")
            if any(len(n) != 3 or not all(math.isfinite(float(x)) for x in n) or
                   not 0.7 < math.sqrt(sum(float(x)**2 for x in n)) < 1.3 for n in normals):
                raise AssetError(f"{tag}: missing/invalid unit normals")
            if any(len(v) != 2 or not all(math.isfinite(float(x)) for x in v) for v in uvs):
                raise AssetError(f"{tag}: invalid UVs")
            if "indices" not in primitive:
                raise AssetError(f"{tag}: indexed triangles required")
            indices = [v[0] for v in _accessor(doc, buffers, primitive["indices"])]
            if len(indices) % 3 != 0 or any(v >= len(positions) for v in indices):
                raise AssetError(f"{tag}: invalid triangle indices")
            for j in range(0, len(indices), 3):
                a, b, c = (positions[indices[j+k]] for k in range(3))
                u = [b[k]-a[k] for k in range(3)]
                v = [c[k]-a[k] for k in range(3)]
                area4 = sum(x*x for x in (u[1]*v[2]-u[2]*v[1],
                                           u[2]*v[0]-u[0]*v[2],
                                           u[0]*v[1]-u[1]*v[0]))
                if area4 < 1e-18:
                    raise AssetError(f"{tag}: degenerate triangle {j//3}")
            for pos in positions:
                for dim in range(3):
                    bounds_min[dim] = min(bounds_min[dim], pos[dim])
                    bounds_max[dim] = max(bounds_max[dim], pos[dim])
            count_tri += len(indices)//3
            count_vert += len(positions)
    if not count_tri:
        raise AssetError("No triangles")
    if count_tri > max_triangles:
        raise AssetError(f"Triangle budget exceeded: {count_tri} > {max_triangles}")
    if any(not -100.0 < x < 100.0 for x in bounds_min + bounds_max):
        raise AssetError("Asset exceeds 100 m local extent; check units/origin")
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "triangles": count_tri, "vertices": count_vert,
            "bounds_min": bounds_min, "bounds_max": bounds_max,
            "node_count": len(names), "material_count": len(doc.get("materials", []))}


def verify_manifest(path: Path, output: Path) -> None:
    spec = json.loads(path.read_text(encoding="utf-8"))
    expected = spec.get("files", {}).get(output.name, {}).get("sha256")
    if not isinstance(expected, str):
        raise AssetError("Manifest must contain exported asset sha256")
    if expected != hashlib.sha256(output.read_bytes()).hexdigest():
        raise AssetError("Manifest hash does not match exported asset")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("asset", type=Path, help="Game-ready glTF 2.0 or GLB")
    ap.add_argument("--max-triangles", type=int, default=20000)
    ap.add_argument("--require-node", action="append", default=[])
    ap.add_argument("--manifest", type=Path)
    args = ap.parse_args()
    try:
        report = inspect(args.asset, max_triangles=args.max_triangles,
                         required_nodes=tuple(args.require_node))
        if args.manifest:
            verify_manifest(args.manifest, args.asset)
    except (AssetError, OSError, json.JSONDecodeError) as exc:
        ap.exit(2, f"Asset rejected: {exc}\n")
    print(json.dumps(report, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
