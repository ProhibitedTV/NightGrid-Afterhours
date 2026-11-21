#!/usr/bin/env python3
"""Pin two ORIGINAL Poly Haven Hidden Alley urban prop glTFs and 1K PBR.

One-time art-branch-only importer. No asset downloads in gameplay or the normal
Windows/Linux build. HTTPS host allowlist, official Poly Haven MD5 checks, path
safety, bounded sizes, auditable per-file SHA-256; never uses third-party packs.
Sources: https://polyhaven.com/a/metal_trash_can
         https://polyhaven.com/a/utility_box_01
License: https://polyhaven.com/license (CC0 1.0).
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path, PurePosixPath
import urllib.parse
import urllib.request

ASSETS = ("metal_trash_can", "utility_box_01")
ROOT = Path("assets/models/polyhaven")
ALLOWED_HOSTS = {"api.polyhaven.com", "dl.polyhaven.org"}
MAX_FILE = 32_000_000
MAX_ASSET = 64_000_000
USER_AGENT = "NightGrid-Afterhours-CC0-urban-props-import/1.0"


def request_bytes(url: str, limit: int = MAX_FILE) -> bytes:
    u = urllib.parse.urlparse(url)
    if u.scheme != "https" or u.hostname not in ALLOWED_HOSTS:
        raise ValueError("Not an official HTTPS Poly Haven source: " + url)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=90) as response:
        redirect = urllib.parse.urlparse(response.geturl())
        if redirect.scheme != "https" or redirect.hostname not in ALLOWED_HOSTS:
            raise ValueError("Redirect left official Poly Haven: " + response.geturl())
        payload = response.read(limit + 1)
    if not payload or len(payload) > limit:
        raise ValueError(f"Source file size outside {limit} byte budget: {url}")
    return payload


def safe_relative(filename: str) -> Path:
    posix = PurePosixPath(urllib.parse.unquote(filename).replace("\\", "/"))
    if posix.is_absolute() or not posix.parts or ".." in posix.parts:
        raise ValueError("Unsafe glTF source relative file: " + filename)
    return Path(*posix.parts)


def source_file(info: dict, output: Path) -> dict:
    url = str(info.get("url", ""))
    payload = request_bytes(url)
    md5 = str(info.get("md5", "")).lower()
    if md5 and hashlib.md5(payload).hexdigest() != md5:
        raise ValueError("Official MD5 mismatch: " + url)
    if info.get("size") is not None and len(payload) != int(info["size"]):
        raise ValueError("Official byte-length mismatch: " + url)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    return {"source": url, "source_md5": md5, "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)}


def includes(entry: dict):
    raw = entry.get("include", {})
    if isinstance(raw, dict):
        return [(str(name), value if isinstance(value, dict) else {"url": str(value)})
                for name, value in raw.items()]
    if isinstance(raw, list):
        return [(str(item.get("name") or urllib.parse.urlparse(item["url"]).path.rsplit("/", 1)[-1]), item)
                for item in raw if isinstance(item, dict) and item.get("url")]
    raise ValueError("Unexpected source dependency container")


def fetch_asset(asset: str) -> None:
    folder = ROOT / asset
    api = f"https://api.polyhaven.com/files/{asset}"
    listing = json.loads(request_bytes(api, 8_000_000).decode("utf-8"))
    entry = listing.get("gltf", {}).get("1k", {}).get("gltf")
    if not isinstance(entry, dict) or not str(entry.get("url", "")).lower().endswith(".gltf"):
        raise ValueError("No original official 1K glTF for " + asset)
    folder.mkdir(parents=True, exist_ok=True)
    gltf_path = folder / (asset + ".gltf")
    sources = {gltf_path.name: source_file(entry, gltf_path)}
    for name, info in includes(entry):
        path = safe_relative(name)
        if path == Path(gltf_path.name):
            raise ValueError("Dependency overwrites original glTF")
        sources[path.as_posix()] = source_file(info, folder / path)
    total = sum(item["bytes"] for item in sources.values())
    if total > MAX_ASSET:
        raise ValueError(f"{asset}: source package exceeds {MAX_ASSET / 1e6} MB")
    model = json.loads(gltf_path.read_text(encoding="utf-8"))
    if model.get("asset", {}).get("version") != "2.0" or not model.get("meshes"):
        raise ValueError(asset + " is not an authored glTF mesh")
    for kind in ("buffers", "images"):
        for item in model.get(kind, []):
            uri = item.get("uri")
            if uri:
                if uri.startswith("data:") or not (folder / safe_relative(uri)).is_file():
                    raise ValueError(asset + ": unaudited glTF dependency: " + uri)
    for mesh in model["meshes"]:
        for primitive in mesh["primitives"]:
            attrs = primitive["attributes"]
            if not all(key in attrs for key in ("POSITION", "NORMAL", "TEXCOORD_0")):
                raise ValueError(asset + ": missing real UVs or normals")
    for material in model.get("materials", []):
        if "baseColorTexture" not in material.get("pbrMetallicRoughness", {}):
            raise ValueError(asset + ": no original photographed albedo")
    record = {
        "asset": asset,
        "source_page": f"https://polyhaven.com/a/{asset}",
        "source_api": api,
        "license": "CC0 1.0",
        "license_url": "https://polyhaven.com/license",
        "resolution": "1k",
        "model": gltf_path.as_posix(),
        "mesh_count": len(model["meshes"]),
        "materials": len(model.get("materials", [])),
        "files": dict(sorted(sources.items())),
        "runtime_download_required": False,
        "placement": "Central Exchange original urban street-level art kit"
    }
    (folder / "SOURCE.json").write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"POLYHAVEN URBAN ASSET PASS: {asset}, {record['mesh_count']} real mesh(es), "
          f"{len(sources)} SHA256 verified source files, {total} bytes")


def main() -> None:
    for asset in ASSETS:
        fetch_asset(asset)


if __name__ == "__main__":
    main()
