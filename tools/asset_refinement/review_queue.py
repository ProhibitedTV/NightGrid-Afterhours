"""Scan verified refinement outputs; atomically publish review queue."""
import argparse
import json
from pathlib import Path
import tempfile
from refine import load, sha, source, verified


def scan(raw, refined, size):
    rows = []
    for folder in sorted((raw / "candidates").iterdir()):
        if not folder.is_dir():
            continue
        try:
            hashes = source(folder)
        except (ValueError, OSError, KeyError, TypeError) as exc:
            rows.append({"candidate": folder.name, "status": "invalid-source", "error": str(exc)})
            continue
        if hashes is None:
            rows.append({"candidate": folder.name, "status": "no-complete-mesh"})
            continue
        versions = []
        parent = refined / folder.name
        if parent.is_dir() and not parent.is_symlink():
            for version in sorted(parent.iterdir()):
                if not version.is_dir() or version.is_symlink() or len(version.name) != 64:
                    continue
                try:
                    manifest = version / "refinement.json"
                    info = load(manifest)
                    if (info["candidate"] != folder.name
                            or info["settings"]["source"] != hashes
                            or info["settings"]["bake_size"] != size
                            or not verified(version, version.name)):
                        continue
                    versions.append({"signature": version.name,
                                     "manifest_sha256": sha(manifest),
                                     "scale_status": info["scale_status"],
                                     "outputs": info["outputs"],
                                     "review": info["review"],
                                     "normal_projection_exception": info["settings"].get("normal_projection_exception"),
                                     "godot_import": info["godot_import"]})
                except (ValueError, OSError, KeyError, TypeError):
                    continue
        rows.append({"candidate": folder.name, "status": "review-required" if versions else "pending-refinement",
                     "versions": versions})
    return rows


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw", type=Path, required=True)
    p.add_argument("--refined", type=Path, required=True)
    p.add_argument("--size", type=int, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    if args.output.resolve().parent != args.refined.resolve():
        p.error("Review index must be written inside refinement root")
    rows = scan(args.raw, args.refined, args.size)
    result = {"schema": 1, "status": "unapproved", "bake_size": args.size,
              "ready_for_review": sum(row["status"] == "review-required" for row in rows),
              "rows": rows}
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=args.refined,
                                     prefix=".review-", delete=False) as handle:
        tmp = Path(handle.name)
        json.dump(result, handle, indent=2, sort_keys=True)
    try:
        tmp.replace(args.output)
    finally:
        tmp.unlink(missing_ok=True)
    print("Review candidates:", result["ready_for_review"], "index:", args.output)
    return int(any(r["status"] == "invalid-source" for r in rows))


if __name__ == "__main__":
    raise SystemExit(main())
