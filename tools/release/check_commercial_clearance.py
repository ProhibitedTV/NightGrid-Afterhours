#!/usr/bin/env python3
"""Fail-closed commercial asset ledger checker; does not certify legal rights."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

CATEGORIES = {"original", "third-party", "generated", "engine", "dependency"}

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def verify(root, inventory, ledger):
    if not isinstance(inventory, dict) or inventory.get("schema") != 1:
        raise ValueError("Invalid inventory schema")
    if not isinstance(ledger, dict) or ledger.get("schema") != 1:
        raise ValueError("Invalid ledger schema")
    files = inventory.get("files")
    entries = ledger.get("entries")
    if not isinstance(files, list) or not files or not isinstance(entries, list):
        raise ValueError("Nonempty release inventory and ledger array required")
    if any(not isinstance(x, str) or not x for x in files) or len(set(files)) != len(files):
        raise ValueError("Invalid or duplicate inventory path")
    by_path = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise ValueError("Invalid ledger entry")
        if entry["path"] in by_path:
            raise ValueError("Duplicate ledger entry")
        by_path[entry["path"]] = entry
    errors = []
    root = root.resolve()
    for name in sorted(files):
        rel = Path(name)
        if rel.is_absolute() or ".." in rel.parts or "\\" in name or rel.as_posix() != name or ":" in name:
            errors.append(name + ": unsafe path")
            continue
        path = (root / rel).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            errors.append(name + ": missing or outside release root")
            continue
        entry = by_path.get(name)
        if entry is None:
            errors.append(name + ": missing clearance")
            continue
        if entry.get("sha256") != digest(path):
            errors.append(name + ": hash mismatch")
        if entry.get("status") != "commercial-approved" or entry.get("category") not in CATEGORIES:
            errors.append(name + ": not commercially approved")
        for key in ("source", "license", "evidence", "reviewer", "review_date"):
            if not isinstance(entry.get(key), str) or not entry[key].strip():
                errors.append(name + ": missing " + key)
        if entry.get("category") == "generated":
            for key in ("model", "checkpoint", "output_rights_evidence", "human_review"):
                if not isinstance(entry.get(key), str) or not entry[key].strip():
                    errors.append(name + ": missing " + key)
    return errors

def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ("root", "inventory", "ledger"):
        p.add_argument("--" + key, type=Path, required=True)
    a = p.parse_args()
    try:
        errors = verify(a.root, json.loads(a.inventory.read_text(encoding="utf-8")),
                        json.loads(a.ledger.read_text(encoding="utf-8")))
    except (OSError, ValueError, TypeError) as exc:
        errors = [str(exc)]
    print(json.dumps({"status": "blocked" if errors else "ledger-check-passed",
                      "scope": "supplied inventory only; not legal certification",
                      "errors": errors}, indent=2))
    return int(bool(errors))

if __name__ == "__main__":
    sys.exit(main())
