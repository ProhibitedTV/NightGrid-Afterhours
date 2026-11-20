#!/usr/bin/env python3
"""Import ONE CC0 scanned fern from Poly Haven's official public model API.

Fetches the source-authored glTF plus its declared texture/buffer dependencies
at 2K, with hashes and exact file provenance. No runtime network calls.
Model: https://polyhaven.com/a/fern_02 ; license: CC0 1.0.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import urllib.parse
import urllib.request

from PIL import Image

ASSET = "fern_02"
RES = "2k"
ROOT = Path("assets/models/polyhaven/fern_02")
USER_AGENT = "NightGrid-Afterhours-CC0-Fern-Import/1.0 (github.com/ProhibitedTV/NightGrid-Afterhours)"
ALLOWED_HOSTS = {"api.polyhaven.com", "dl.polyhaven.org"}
MAX_FILE_BYTES = 40_000_000
MAX_TOTAL_BYTES = 95_000_000


def get_bytes(url: str, size: int = MAX_FILE_BYTES) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError(f"untrusted URL: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as response:
        target = urllib.parse.urlparse(response.geturl())
        if target.scheme != "https" or target.hostname not in ALLOWED_HOSTS:
            raise ValueError(f"untrusted redirected host: {target.hostname}")
        data = response.read(size + 1)
    if len(data) <= 0 or len(data) > size:
        raise ValueError(f"invalid download size {len(data)} for {url}")
    return data


def relative_path(name: str) -> Path:
    # Paths inside the downloaded glTF must remain relative and confined to
    # this one source-owned asset directory; no zipped or arbitrary assets.
    path = PurePosixPath(urllib.parse.unquote(name).replace("\\", "/"))
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise ValueError(f"unsafe glTF dependency path: {name}")
    return Path(*path.parts)


def include_entries(entry: dict) -> list[tuple[str, dict]]:
    raw = entry.get("include", {})
    result = []
    if isinstance(raw, dict):
        for name, meta in raw.items():
            if isinstance(meta, dict):
                result.append((str(name), meta))
            elif isinstance(meta, str):
                result.append((str(name), {"url": meta}))
    elif isinstance(raw, list):
        for meta in raw:
            if not isinstance(meta, dict) or not meta.get("url"):
                raise ValueError(f"unexpected included file: {meta}")
            result.append((str(meta.get("name") or urllib.parse.urlparse(meta["url"]).path.rsplit("/", 1)[-1]), meta))
    else:
        raise ValueError(f"unexpected include data type: {type(raw)}")
    return result


def fetch_entry(path_name: str, entry: dict) -> dict:
    path = relative_path(path_name)
    url = str(entry["url"])
    data = get_bytes(url)
    md5 = entry.get("md5")
    if md5 and hashlib.md5(data).hexdigest().lower() != str(md5).lower():
        raise ValueError(f"source MD5 mismatch for {path}")
    declared_size = entry.get("size")
    if declared_size is not None and int(declared_size) != len(data):
        raise ValueError(f"source byte count mismatch for {path}")
    out = ROOT / path
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    print(f"IMPORTED {out}: {len(data):,} bytes")
    return {"file": out.as_posix(), "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data), "source_url": url}


def build_leaf_alpha(root: Path, gltf_file: Path, api_data: dict, files: dict) -> dict:
    """Make the photographic leaf atlas an actual alpha-cutout PBR base map.

    Poly Haven's glTF supplies a JPEG diffuse atlas and alphaMode: MASK, but
    JPEG has NO alpha channel. Without explicitly merging the separately
    published mask, Godot draws background-colored cards around each frond.
    """
    alpha_sections = {str(k): v for k, v in api_data.items() if "alpha" in str(k).lower()}
    print("Available source map keys:", sorted(api_data.keys()))
    print("Alpha source resolutions:", {k: list(v.keys()) if isinstance(v, dict) else type(v).__name__ for k, v in alpha_sections.items()})
    alpha = None
    ext = ""
    for k, section in alpha_sections.items():
        if not isinstance(section, dict):
            continue
        for resolution in (RES, "4k", "1k", "8k"):
            formats = section.get(resolution, {})
            if not isinstance(formats, dict):
                continue
            for extension in ("png", "jpg"):
                if isinstance(formats.get(extension), dict) and formats[extension].get("url"):
                    alpha = formats[extension]
                    ext = extension
                    break
            if alpha:
                break
        if alpha:
            break
    if not isinstance(alpha, dict) or not alpha.get("url"):
        raise ValueError("Poly Haven did not expose a valid alpha map; rejecting opaque cards")
    filename = "textures/fern_02_alpha_source." + ext
    files[filename] = fetch_entry(filename, alpha)
    gltf = json.loads(gltf_file.read_text(encoding="utf-8"))
    material = gltf["materials"][0]
    tex_index = material["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    diffuse_image_index = gltf["textures"][tex_index]["source"]
    diffuse_uri = gltf["images"][diffuse_image_index]["uri"]
    diffuse_path = root / relative_path(diffuse_uri)
    mask_path = root / relative_path(filename)
    out_name = "textures/fern_02_diff_alpha_2k.png"
    out_path = root / out_name
    with Image.open(diffuse_path) as image, Image.open(mask_path) as mask_image:
        diffuse = image.convert("RGBA")
        alpha_mask = mask_image.convert("L")
        if alpha_mask.size != diffuse.size:
            raise ValueError(f"alpha mask {alpha_mask.size} doesn't match leaves {diffuse.size}")
        # Scan-derived alpha preserves thin pinnae and removes every atlas
        # rectangle; threshold in Godot is controlled by the source material.
        diffuse.putalpha(alpha_mask)
        diffuse.save(out_path, "PNG", optimize=True)
    # Keep the original unmodified JPEG and original alpha file for audit.
    gltf["images"][diffuse_image_index]["uri"] = out_name
    gltf["images"][diffuse_image_index]["mimeType"] = "image/png"
    gltf_file.write_text(json.dumps(gltf, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    result = {}
    for rel in [out_name, gltf_file.name]:
        path = root / rel
        payload = path.read_bytes()
        result[rel] = {"file": path.as_posix(), "sha256": hashlib.sha256(payload).hexdigest(),
                       "bytes": len(payload), "derived_from": [diffuse_uri, filename]}
    print(f"ALPHA CUTOUT PASS: {out_path} ({out_path.stat().st_size:,} bytes)")
    return result


def main() -> None:
    api = f"https://api.polyhaven.com/files/{ASSET}"
    manifest = json.loads(get_bytes(api, 8_000_000).decode("utf-8"))
    entry = manifest.get("gltf", {}).get(RES, {}).get("gltf")
    if not isinstance(entry, dict) or not entry.get("url"):
        raise ValueError(f"Poly Haven does not supply {ASSET} glTF {RES}: {list(manifest)}")
    main_name = urllib.parse.unquote(urllib.parse.urlparse(entry["url"]).path.rsplit("/", 1)[-1])
    if not main_name.endswith(".gltf"):
        raise ValueError(f"expected source glTF model, got {main_name}")
    ROOT.mkdir(parents=True, exist_ok=True)
    files = {}
    files[main_name] = fetch_entry(main_name, entry)
    dependencies = include_entries(entry)
    print(f"Poly Haven supplied {len(dependencies)} model dependencies")
    for name, info in dependencies:
        # Poly Haven's include map uses relative file path as the key.
        files[name] = fetch_entry(name, info)
    if sum(v["bytes"] for v in files.values()) > MAX_TOTAL_BYTES:
        raise ValueError("2K fern exceeded pilot resident asset size budget")
    gltf_path = ROOT / main_name
    derived = build_leaf_alpha(ROOT, gltf_path, manifest, files)
    files[main_name] = derived[main_name]
    files["textures/fern_02_diff_alpha_2k.png"] = derived["textures/fern_02_diff_alpha_2k.png"]
    doc = json.loads(gltf_path.read_text(encoding="utf-8"))
    if doc.get("asset", {}).get("version") != "2.0" or not doc.get("meshes"):
        raise ValueError("invalid or empty glTF 2.0 model")
    refs = [x.get("uri") for k in ("buffers", "images") for x in doc.get(k, [])]
    for ref in refs:
        if ref and not ref.startswith("data:") and not (ROOT / relative_path(ref)).is_file():
            raise ValueError(f"missing glTF texture/buffer {ref}")
    source = {
        "asset": ASSET, "resolution": RES, "model": main_name,
        "page": f"https://polyhaven.com/a/{ASSET}",
        "api": api, "license": "CC0 1.0", "license_url": "https://polyhaven.com/license",
        "author": "Rico Cilliers (model), Rob Tuytel (scanning)",
        "description": "Scanned source fern with separate official alpha map composited into real masked RGBA leaf atlas",
        "files": files,
        "gltf_meshes": len(doc["meshes"]),
        "gltf_nodes": len(doc.get("nodes", [])),
        "gltf_materials": len(doc.get("materials", [])),
        "gltf_buffers": len(doc.get("buffers", [])),
    }
    (ROOT / "SOURCE.json").write_text(json.dumps(source, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"ASSET IMPORT PASS: {len(files)} verified CC0 files, {source['gltf_meshes']} mesh group(s)")


if __name__ == "__main__":
    main()
