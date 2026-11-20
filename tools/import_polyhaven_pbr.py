#!/usr/bin/env python3
"""Download approved CC0 photographed masonry, metal and roof texture sets.

Upstream assets: https://polyhaven.com/a/brick_wall_001
https://polyhaven.com/a/blue_metal_plate\nand https://polyhaven.com/a/bitumen
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

ASSETS = {
    "brick_wall_001": "Aged brick for Central Exchange's Brickwater frontage",
    "blue_metal_plate": "Scratched blue steel for structural fascia and Glassline frontage",
    "bitumen": "Real weathered bitumen roofing for one Brickwater flat-roof building",
}
DIRECTORY = pathlib.Path("assets/pbr/polyhaven")
MATERIALS = {
    "diffuse": ("jpg", "diffuse_2k.jpg", ("diffuse", "diff", "albedo", "col", "color")),
    "nor_gl": ("png", "nor_gl_2k.png", ("nor_gl", "normal_gl", "normalgl")),
    "rough": ("png", "rough_2k.png", ("rough", "roughness")),
}
USER_AGENT = "NightGrid-Afterhours-CC0-asset-importer/1.0 (github.com/ProhibitedTV/NightGrid-Afterhours)"
# Some genuine 2K 16-bit PNG normals exceed 25 MB (notably bitumen).
# Bound each download well below GitHub's individual-file limit.
MAX_BYTES = 50_000_000


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


def find_map(data: dict, aliases: tuple[str, ...], extension: str, asset_id: str) -> dict:
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
    raise ValueError(f"Poly Haven {asset_id} lacks 2K {extension} map aliases {aliases}")


def import_material(asset: str, description: str) -> dict:
    api = f"https://api.polyhaven.com/files/{asset}"
    data = json.loads(get_bytes(api).decode("utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Unexpected Poly Haven API schema for {asset}")
    sources = {}
    for semantic, (extension, out_name, aliases) in MATERIALS.items():
        file_info = find_map(data, aliases, extension, asset)
        url = file_info["url"]
        payload = get_bytes(url)
        if extension == "png" and not payload.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"{asset}/{semantic} response was not PNG")
        if extension == "jpg" and not payload.startswith(b"\xff\xd8"):
            raise ValueError(f"{asset}/{semantic} response was not JPEG")
        expected_md5 = file_info.get("md5")
        if expected_md5 and hashlib.md5(payload).hexdigest() != expected_md5.lower():
            raise ValueError(f"{asset}/{semantic} MD5 disagreed with Poly Haven API")
        target = DIRECTORY / f"{asset}_{out_name}"
        target.write_bytes(payload)
        sources[semantic] = {
            "file": target.as_posix(),
            "source_url": url,
            "sha256": hashlib.sha256(payload).hexdigest(),
            "bytes": len(payload),
        }
        print(f"Imported {asset}/{semantic}: {target} ({len(payload)} bytes)")
    return {
        "asset": asset,
        "page": f"https://polyhaven.com/a/{asset}",
        "api": api,
        "description": description,
        "license": "CC0 1.0",
        "files": sources,
    }


def main() -> None:
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    manifest = {
        "license": "CC0 1.0",
        "license_url": "https://polyhaven.com/license",
        "assets": {},
    }
    for asset, description in ASSETS.items():
        manifest["assets"][asset] = import_material(asset, description)
    (DIRECTORY / "SOURCE.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{len(ASSETS) * len(MATERIALS)} photographed 2K PBR maps with source hashes imported.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ASSET_IMPORT_ERROR: {error}", file=sys.stderr)
        raise
