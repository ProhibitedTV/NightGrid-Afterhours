#!/usr/bin/env python3
"""Fetch the original Poly Haven CC0 exterior aircon model with 1K source PBR.

This deliberately does *not* scrape, hotlink at runtime, or download a third-
party paid "CC0 pack" with a different redistribution contract. All assets
originate from Poly Haven's public API with MD5 metadata and archived hashes.

Source: https://polyhaven.com/a/exterior_aircon_unit
License: https://polyhaven.com/license (CC0, redistribution permitted).
First production placement: West Docks -4,-1 service building rooftop.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import urllib.parse
import urllib.request

ASSET = "exterior_aircon_unit"
RESOLUTION = "1k"
ROOT = Path("assets/models/polyhaven") / ASSET
GLTF_OUTPUT = ROOT / (ASSET + ".gltf")
ALLOWED_HOSTS = {"api.polyhaven.com", "dl.polyhaven.org"}
MAX_FILE_BYTES = 30_000_000
MAX_TOTAL_BYTES = 48_000_000
USER_AGENT = "NightGrid-Afterhours-verified-CC0-asset-import/1.0"


def request_bytes(url: str, limit: int = MAX_FILE_BYTES) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError("Source is not an official Poly Haven HTTPS host: " + url)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=90) as response:
        target = urllib.parse.urlparse(response.geturl())
        if target.scheme != "https" or target.hostname not in ALLOWED_HOSTS:
            raise ValueError("Source redirected outside verified domains: " + response.geturl())
        data = response.read(limit + 1)
    if not data or len(data) > limit:
        raise ValueError(f"Download outside expected byte bounds: {len(data)}")
    return data


def safe_file(name: str) -> Path:
    pure = PurePosixPath(urllib.parse.unquote(name).replace("\\", "/"))
    if pure.is_absolute() or ".." in pure.parts or not pure.parts:
        raise ValueError("Unsafe glTF dependency: " + name)
    return Path(*pure.parts)


def source_file(filename: str, description: dict, destination: Path) -> dict:
    url = str(description.get("url", ""))
    data = request_bytes(url)
    expected_md5 = str(description.get("md5", "")).lower()
    if expected_md5 and hashlib.md5(data).hexdigest() != expected_md5:
        raise ValueError("Official Poly Haven MD5 mismatch for " + filename)
    expected_size = description.get("size")
    if expected_size is not None and int(expected_size) != len(data):
        raise ValueError("Official Poly Haven size mismatch for " + filename)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return {"source": url, "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data), "source_md5": expected_md5}


def included_entries(entry: dict) -> list[tuple[str, dict]]:
    raw = entry.get("include", {})
    out = []
    if isinstance(raw, dict):
        for name, info in raw.items():
            out.append((str(name), info if isinstance(info, dict) else {"url": str(info)}))
    elif isinstance(raw, list):
        for info in raw:
            if not isinstance(info, dict) or not info.get("url"):
                raise ValueError("Unexpected glTF include payload")
            name = str(info.get("name") or urllib.parse.urlparse(info["url"]).path.rsplit("/", 1)[-1])
            out.append((name, info))
    else:
        raise ValueError("Unexpected Poly Haven glTF dependency format")
    return out


def main() -> None:
    api = f"https://api.polyhaven.com/files/{ASSET}"
    listing = json.loads(request_bytes(api, 8_000_000).decode("utf-8"))
    entry = listing.get("gltf", {}).get(RESOLUTION, {}).get("gltf")
    if not isinstance(entry, dict) or not entry.get("url"):
        raise ValueError(f"Official asset has no {RESOLUTION} glTF distribution: {list(listing)}")
    if not str(urllib.parse.urlparse(entry["url"]).path).lower().endswith(".gltf"):
        raise ValueError("Expected glTF source, not a packaged unknown archive")
    ROOT.mkdir(parents=True, exist_ok=True)
    sources = {}
    sources[str(GLTF_OUTPUT.relative_to(ROOT))] = source_file(
        GLTF_OUTPUT.name, entry, GLTF_OUTPUT)
    for filename, dep in included_entries(entry):
        relative = safe_file(filename)
        if relative == Path(GLTF_OUTPUT.name):
            raise ValueError("Dependency may not overwrite source model")
        sources[relative.as_posix()] = source_file(filename, dep, ROOT / relative)
    if sum(v["bytes"] for v in sources.values()) > MAX_TOTAL_BYTES:
        raise ValueError("Original 1K exterior aircon asset exceeds bounded 48MB budget")
    document = json.loads(GLTF_OUTPUT.read_text(encoding="utf-8"))
    if document.get("asset", {}).get("version") != "2.0" or not document.get("meshes"):
        raise ValueError("Not a valid mesh-bearing glTF 2.0 street model")
    for kind in ("buffers", "images"):
        for obj in document.get(kind, []):
            uri = obj.get("uri")
            if not uri:
                continue
            if uri.startswith("data:"):
                raise ValueError("Non-auditable embedded texture/binary blob; reject")
            dep = (ROOT / safe_file(uri))
            if not dep.is_file():
                raise ValueError(f"Source {kind} URI missing from official include files: {uri}")
    if not any(path.lower().endswith((".png", ".jpg", ".jpeg")) for path in sources):
        raise ValueError("Missing actual source-provided photo maps")
    manifest = {
        "asset": ASSET,
        "description": "Weathered and clean exterior HVAC equipment mounted high on a permanent West Docks service roof",
        "source_page": f"https://polyhaven.com/a/{ASSET}",
        "source_api": api,
        "license": "CC0 1.0",
        "license_url": "https://polyhaven.com/license",
        "resolution": RESOLUTION,
        "model": GLTF_OUTPUT.as_posix(),
        "meshes": len(document["meshes"]),
        "materials": len(document.get("materials", [])),
        "files": dict(sorted(sources.items())),
        "runtime_download_required": False,
    }
    (ROOT / "SOURCE.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                       encoding="utf-8")
    print(f"CC0 AIRCON IMPORT PASS: {len(sources)} original files, "
          f"{manifest['meshes']} source mesh(es), "
          f"{sum(v['bytes'] for v in sources.values()) / 1e6:.2f} MB verified")


if __name__ == "__main__":
    main()
