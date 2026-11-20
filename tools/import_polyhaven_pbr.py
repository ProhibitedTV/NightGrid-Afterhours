#!/usr/bin/env python3
"""Download a specifically approved CC0 material using Poly Haven's public API.

Exact upstream asset: https://polyhaven.com/a/brick_wall_001
License: https://polyhaven.com/license (CC0, including redistribution).
This script is intentionally an explicit opt-in source-import step, not a
runtime dependency, build-time hotlink or unlicensed web scrape.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import urllib.parse
import urllib.request

ASSET = "brick_wall_001"
API = f"https://api.polyhaven.com/files/{ASSET}"
DIRECTORY = pathlib.Path("assets/pbr/polyhaven")
MATERIALS = {
    "diffuse": ("jpg", "diffuse_2k.jpg", ("diffuse", "diff", "albedo", "col", "color")),
    "nor_gl": ("png", "nor_gl_2k.png", ("nor_gl", "normal_gl", "normalgl")),
    "rough": ("png", "rough_2k.png", ("rough", "roughness")),
}
USER_AGENT = "NightGrid-Afterhours-CC0-asset-importer/1.0 (github.com/ProhibitedTV/NightGrid-Afterhours)"
MAX_BYTES = 25_000_000


def get_bytes(url: str) -> bytes:
    host = urllib.parse.urlparse(url)
    if host.scheme != "https" or host.hostname not in {"api.polyhaven.com", "dl.polyhaven.org"}:
        raise ValueError(f"Unexpected asset host: {host.hostname}")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        final_url = urllib.parse.urlparse(response.geturl())
        if final_url.scheme != "https" or final_url.hostname not in {
            "api.polyhaven.com", "dl.polyhaven.org"
        }:
            raise ValueError("Asset redirect went to an unapproved host")
        payload = response.read(MAX_BYTES + 1)
    if not payload or len(payload) > MAX_BYTES:
        raise ValueError(f"Invalid asset size: {len(payload)}")
    return payload


def find_map(data: dict, aliases: tuple[str, ...], extension: str) -> dict:
    for alias in aliases:
        for name, formats in data.items():
            if str(name).lower() != alias:
                continue
            if not isinstance(formats, dict):
                continue
            for resolution in ("2k", "2K"):
                opts = formats.get(resolution, {})
                if not isinstance(opts, dict):
                    continue
                for file_type in (extension, extension.upper()):
                    file_info = opts.get(file_type)
                    if isinstance(file_info, dict) and file_info.get("url"):
                        return file_info
    raise ValueError(f"Poly Haven {ASSET} lacks 2K {extension} map aliases {aliases}")


def main() -> None:
    data = json.loads(get_bytes(API).decode("utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Unexpected Poly Haven response schema")
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    sources = {}
    for semantic, (extension, out_name, aliases) in MATERIALS.items():
        file_info = find_map(data, aliases, extension)
        url = file_info["url"]
        payload = get_bytes(url)
        if extension == "png" and not payload.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"{semantic} response was not PNG")
        if extension == "jpg" and not payload.startswith(b"\xff\xd8"):
            raise ValueError(f"{semantic} response was not JPEG")
        expected_md5 = file_info.get("md5")
        if expected_md5 and hashlib.md5(payload).hexdigest() != expected_md5.lower():
            raise ValueError(f"{semantic} MD5 disagreed with Poly Haven API")
        target = DIRECTORY / f"{ASSET}_{out_name}"
        target.write_bytes(payload)
        sources[semantic] = {
            "file": target.as_posix(),
            "source_url": url,
            "sha256": hashlib.sha256(payload).hexdigest(),
            "bytes": len(payload),
        }
        print(f"Imported {semantic}: {target} ({len(payload)} bytes)")
    manifest = {
        "asset": ASSET,
        "page": f"https://polyhaven.com/a/{ASSET}",
        "api": API,
        "license": "CC0 1.0",
        "license_url": "https://polyhaven.com/license",
        "description": "Photographed UV-brick masonry for Central Exchange's Brickwater frontage",
        "files": sources,
    }
    (DIRECTORY / "SOURCE.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("All three genuine 2K scanned material maps downloaded and provenance written.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ASSET_IMPORT_ERROR: {error}", file=sys.stderr)
        raise
