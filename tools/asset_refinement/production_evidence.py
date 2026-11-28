"""Hash-bound production evidence index; no approval, copy or publication."""
import argparse
import json
from pathlib import Path
from refine import sha
from factory_ledger import atomic


def checked(root, name, expected):
    rel = Path(name)
    if rel.is_absolute() or ".." in rel.parts:
        raise ValueError("Unsafe evidence path")
    path = root / rel
    if not path.is_file() or root.resolve() not in path.resolve().parents or any(
            p.is_symlink() for p in (path, *path.parents) if p != root and root in p.parents):
        raise ValueError("Missing or unsafe evidence: " + str(path))
    if sha(path) != expected:
        raise ValueError("Evidence hash mismatch: " + str(path))
    return {"file": str(path), "bytes": path.stat().st_size, "sha256": expected}


def manifest(folder, filename, output_key):
    path = folder / filename
    if not path.is_file() or path.is_symlink():
        raise ValueError("Missing candidate manifest: " + str(path))
    data = json.loads(path.read_text())
    files = data[output_key]
    if not files:
        raise ValueError("Empty candidate manifest")
    return {"manifest": str(path), "manifest_sha256": sha(path),
            "files": [checked(folder, name, rec["sha256"]) for name, rec in sorted(files.items())]}


def index(nas, run):
    state = json.loads((run / "production.json").read_text())
    entries = state["entries"]
    batch = run.name
    post = "postmusic-" + batch
    results = []
    bot = nas / "Visual/Botanical" / ("coastal-" + batch)
    record = manifest(bot, "SOURCE.json", "files")
    if len(record["files"]) != 14:
        raise ValueError("Expected all 14 botanical meshes")
    results.append(dict(record, lane="botanical"))
    from botanical_candidates import SPECIES
    for species in SPECIES:
        folder = nas / "Visual/Impostors" / batch / species
        record = manifest(folder, "candidate.json", "outputs")
        settings = json.loads((folder / "candidate.json").read_text())["settings"]
        if settings["source_sha256"] != sha(bot / (species + "_lod0.glb")) or settings["species"] != species:
            raise ValueError("Impostor source mismatch")
        results.append(dict(record, lane="impostors", species=species))
    from urban_layout_candidates import PARCELS, INTERIORS
    record=manifest(nas/"Visual/UrbanLayouts"/batch/"urban-layouts","candidate.json","outputs")
    if {Path(f["file"]).name for f in record["files"]}!={n+ext for n in (*PARCELS,*INTERIORS) for ext in (".json",".svg")}:
        raise ValueError("Incomplete urban layout candidates")
    results.append(dict(record,lane="layouts"))
    for family in ("B1", "B2", "B3", "B4"):
        record=manifest(nas / "Visual/Architecture" / post / family,"candidate.json","outputs")
        if {Path(f["file"]).name for f in record["files"]}!={"lod0.glb","lod1.glb","lod2.glb","occluder.json"}:
            raise ValueError("Incomplete architecture derivatives")
        results.append(dict(record,lane="architecture",family=family))
    from environment_candidates import PRESETS
    for preset in PRESETS:
        folder=nas / "Visual/Environments" / batch / preset
        record=manifest(folder,"candidate.json","outputs")
        if {Path(f["file"]).name for f in record["files"]}!={"environment.hdr","preview.jpg"}:
            raise ValueError("Incomplete HDR derivatives")
        results.append(dict(record,lane="environments",preset=preset))
    from decal_candidates import OUTPUTS
    folder=nas / "Visual/Decals" / batch / "street-weathering"
    record=manifest(folder,"candidate.json","outputs")
    if {Path(f["file"]).name for f in record["files"]}!=set(OUTPUTS):
        raise ValueError("Incomplete decal derivatives")
    results.append(dict(record,lane="decals"))
    from character_candidates import BATCHES
    for actor in BATCHES["all"]:
        folder = nas / "Characters" / post / actor
        path = folder / "candidate.json"
        data = json.loads(path.read_text())
        if data["actor"] != actor or data["status"] != "candidate-only":
            raise ValueError("Wrong character manifest")
        results.append({"lane": "character", "actor": actor, "manifest": str(path),
                        "manifest_sha256": sha(path),
                        "files": [checked(folder, data["model"], data["structural"]["sha256"])]})
    for profile in ("reception", "synaxis-ground"):
        folder = Path(entries[profile]["candidate"])
        if (nas / "Visual/Lighting").resolve() not in folder.resolve().parents:
            raise ValueError("Unsafe lighting folder")
        report = folder / "validated-bake.json"
        data = json.loads(report.read_text(encoding="utf-8-sig"))
        if data["status"] != "candidate-only" or not data["engine"].startswith("4.7.2"):
            raise ValueError("Invalid native bake evidence")
        inputs = json.loads((folder / "inputs.json").read_text())
        if inputs["profile"] != profile:
            raise ValueError("Wrong bake profile")
        base = (folder / inputs["scene"]).parent
        results.append({"lane": "lighting", "profile": profile, "manifest": str(report),
                        "manifest_sha256": sha(report),
                        "files": [checked(base, rec["file"], rec["sha256"]) for rec in data["outputs"]]})
    for name in ("review_packet", "review_detail", "inventory"):
        entry = entries[name]
        path = run / entry["artifact"]
        results.append(dict(checked(run, entry["artifact"], entry["artifact_sha256"]), lane=name))
    return {"schema": 1, "status": "review-required",
            "scope": "candidate integrity and review evidence only; no runtime approval",
            "source": state["signature"]["source"], "records": results}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--nas", required=True, type=Path)
    p.add_argument("--run", required=True, type=Path)
    a = p.parse_args()
    run = a.run.resolve()
    atomic(run / "candidate-index.json", index(a.nas.resolve(), run))
    print("Candidate evidence:", run / "candidate-index.json")


if __name__ == "__main__":
    main()
