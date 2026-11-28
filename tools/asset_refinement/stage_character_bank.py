"""Stage the complete approved local creator batch without publishing private assets."""
import argparse
import json
from pathlib import Path
import shutil
import tempfile

import character_candidates as candidates

TARGET = candidates.ROOT / "assets/creator_character_bank"


def stage(source, target=TARGET):
    source = source.resolve(strict=True)
    records = {}
    files = {}
    for actor in candidates.ACTORS:
        record, model = candidates.verified_candidate(
            source / actor, actor, candidates.profile(actor))
        records[actor] = record["structural"]
        files[actor] = model
    manifest = {"schema": 1, "package": candidates.PACKAGE,
                "source_revision": candidates.REVISION, "actors": records}
    if target.exists():
        if target.is_symlink() or not target.is_dir():
            raise ValueError("Unsafe destination")
        if json.loads((target / "bank.json").read_text(encoding="utf-8")) != manifest:
            raise ValueError("Existing bank differs; preserve it outside the project")
        if {p.name for p in target.glob("*.glb")} != {a + ".glb" for a in files}:
            raise ValueError("Unexpected model inventory")
        for actor in files:
            if candidates.inspect_glb(target / (actor + ".glb"), candidates.ANIMATIONS[actor]) != records[actor]:
                raise ValueError("Staged model differs: " + actor)
        return manifest
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".character-bank-", dir=target.parent) as tmp:
        pending = Path(tmp) / "bank"
        pending.mkdir()
        for actor, model in files.items():
            output = pending / (actor + ".glb")
            shutil.copyfile(model, output)
            if candidates.inspect_glb(output, candidates.ANIMATIONS[actor]) != records[actor]:
                raise ValueError("Copied model differs: " + actor)
        (pending / "bank.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        pending.rename(target)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    args = parser.parse_args()
    bank = stage(args.source)
    print("CHARACTER_BANK_STAGE PASS:", len(bank["actors"]), "verified GLBs")
