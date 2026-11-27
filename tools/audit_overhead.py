"""Read-only repository inventory. Findings are candidates, never deletion instructions."""
import argparse
import collections
import hashlib
import json
import re
from pathlib import Path

def inventory(root):
    sizes = collections.Counter()
    hashes = collections.defaultdict(list)
    scripts = []
    references = collections.defaultdict(set)
    assets = []
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if any(p.startswith(".") or p in {"builds", "dist", "__pycache__"} for p in rel.parts):
            continue
        if not path.is_file() or path.is_symlink():
            continue
        if rel.parts[0] not in {"scripts", "scenes", "assets", "shaders", "tools", "tests"}:
            continue
        size = path.stat().st_size
        sizes[rel.parts[0]] += size
        if path.suffix in {".gd", ".tscn", ".tres", ".godot", ".gdshader", ".json", ".cfg"}:
            source = path.read_text(encoding="utf-8", errors="replace")
            for target in re.findall(r'res://[^"\'\s<>]+', source):
                references[target.removeprefix("res://")].add(rel.as_posix())
        if rel.parts[0] == "assets" and size:
            assets.append(rel.as_posix())
            digest = hashlib.sha256()
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            hashes[(size, digest.hexdigest())].append(rel.as_posix())
        if path.suffix == ".gd":
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
            scripts.append({"path": rel.as_posix(), "lines": len(lines),
                "frame_callbacks": [line.strip() for line in lines if line.lstrip().startswith(("func _process(", "func _physics_process("))]})
    return {"bytes_by_tree": dict(sizes), "scripts": sorted(scripts, key=lambda s: (-s["lines"], s["path"])),
            "identical_asset_candidates": [{"bytes_each": k[0], "sha256": k[1], "paths": v} for k,v in sorted(hashes.items()) if len(v)>1],
            "asset_reference_candidates": [{"path": a, "literal_referrers": sorted(references[a])} for a in assets],
            "limitations": "Literal references omit dynamic paths, UID references, imported dependencies and export rules. Disk inventory only; not runtime memory, reachability, or proof of safe deletion."}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    print(json.dumps(inventory(args.root.resolve()), indent=2))
