"""Portable studio review packet; no raw meshes, approvals or gameplay changes."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

HEX = re.compile(r"[a-f0-9]{64}")
KEY = re.compile(r"[a-z0-9][a-z0-9.-]{0,159}")
PAGE = re.compile(r"page-[0-9]{3,6}\.jpg")
DEFAULT_LIMIT = 50 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def valid_id(value, pattern):
    if not isinstance(value, str) or not pattern.fullmatch(value) or ".." in value:
        raise ValueError("Invalid review identifier")
    return value


def read(root, relative, limit):
    path = root / relative
    if (root not in path.resolve().parents or
            any(p.is_symlink() for p in (path, *path.parents) if p != root) or
            not path.is_file()):
        raise ValueError("Unsafe or missing review file: " + str(relative))
    with path.open("rb") as handle:
        data = handle.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Review packet size limit exceeded")
    return data


def export(refined, previews, size, output, limit=DEFAULT_LIMIT):
    if size not in (128, 1024) or not 0 < limit <= 200 * 1024 * 1024:
        raise ValueError("Unsupported bake size or archive limit")
    refined, previews = refined.resolve(), previews.resolve()
    if refined == previews or refined in previews.parents or previews in refined.parents:
        raise ValueError("Review roots must be separate")
    target = output.resolve()
    if any(root == target or root in target.parents for root in (refined, previews)):
        raise ValueError("Output must be separate from input roots")
    files = {}
    total = 0

    def collect(root, relative, archive_name, expected=None):
        nonlocal total
        if archive_name in files:
            raise ValueError("Duplicate archive path")
        data = read(root, relative, limit - total)
        if expected is not None and digest(data) != valid_id(expected, HEX):
            raise ValueError("Review hash mismatch: " + archive_name)
        total += len(data)
        files[archive_name] = data
        return data

    review_name = f"review-{size}.json"
    review = json.loads(collect(refined, review_name, "refined/" + review_name))
    pbytes = collect(previews, review_name, "previews/" + review_name)
    preview = json.loads(pbytes)
    if (review["schema"] != 1 or review["status"] != "unapproved" or
            review["bake_size"] != size or preview["schema"] != 1 or
            preview["scope"] != "Blender preview only"):
        raise ValueError("Unexpected review schema")
    versions = {}
    for row in review["rows"]:
        key = valid_id(row["candidate"], KEY)
        for version in row.get("versions", []):
            sig = valid_id(version["signature"], HEX)
            ident = (key, sig)
            if ident in versions or row["status"] != "review-required":
                raise ValueError("Duplicate or invalid refinement version")
            versions[ident] = version["manifest_sha256"]
    if not versions:
        raise ValueError("No reviewable versions")

    seen = set()
    for row in preview["rows"]:
        if row["status"] != "review-only":
            raise ValueError("Preview incomplete; repair before exporting")
        key = valid_id(row["candidate"], KEY)
        sig = valid_id(row["refinement"], HEX)
        pid = valid_id(row["preview"], HEX)
        ident = (key, sig)
        if ident in seen or ident not in versions:
            raise ValueError("Stale or duplicate preview version")
        seen.add(ident)
        rpath = f"{key}/{sig}/refinement.json"
        pp = f"{key}/{pid}/preview.json"
        manifest = json.loads(collect(refined, rpath, "refined/" + rpath, versions[ident]))
        pinfo = json.loads(collect(previews, pp, "previews/" + pp, row["manifest_sha256"]))
        settings = pinfo["settings"]
        if (manifest["candidate"] != key or manifest["settings"]["bake_size"] != size or
                pinfo["status"] != "review-only" or settings["candidate"] != key or
                settings["refinement"] != sig or settings["manifest_sha256"] != versions[ident] or
                settings["glb_sha256"] != manifest["outputs"]["lod0.glb"]["sha256"]):
            raise ValueError("Preview/refinement binding mismatch")
    if seen != set(versions) or (size == 1024 and preview["partial"]):
        raise ValueError("Preview coverage incomplete")

    sheet_dir = "sheets-" + digest(pbytes)
    sheet_index = json.loads(collect(previews, sheet_dir + "/index.json", "sheets/index.json"))
    pages = sheet_index["pages"]
    if (sheet_index["source_sha256"] != digest(pbytes) or sheet_index["scope"] != "review-only" or
            set(pages) != {f"page-{i:03d}.jpg" for i in range(1, (len(seen)+7)//8+1)}):
        raise ValueError("Contact sheet index stale or incomplete")
    for name, expected in sorted(pages.items()):
        valid_id(name, PAGE)
        collect(previews, sheet_dir + "/" + name, "sheets/" + name, expected)

    index = {"schema": 1, "status": "review-only", "bake_size": size,
             "partial": bool(preview["partial"]), "versions": len(seen),
             "scope": "Studio contact sheets and source-bound metadata; not native evidence or approval",
             "files": {name: digest(data) for name, data in sorted(files.items())}}
    payload = io.BytesIO()
    with zipfile.ZipFile(payload, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=3) as archive:
        for name, data in sorted(files.items()):
            archive.writestr(name, data)
        archive.writestr("packet.json", json.dumps(index, indent=2, sort_keys=True))
    if payload.tell() > limit:
        raise ValueError("Review packet size limit exceeded")
    # Exclusive creation: never replace an earlier packet.
    handle = output.open("xb")
    try:
        with handle:
            handle.write(payload.getbuffer())
    except BaseException:
        output.unlink(missing_ok=True)
        raise
    print("Review packet:", output, "versions:", len(seen), "pages:", len(pages))
    return index


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("refined", "previews", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--max-mib", type=int, default=50)
    args = parser.parse_args()
    export(args.refined, args.previews, args.size, args.output, args.max_mib * 1024 * 1024)
