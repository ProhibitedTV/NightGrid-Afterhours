#!/usr/bin/env python3
"""Private music review ledger: generate pending template or verify decisions.

No audio edits, exports, approvals on behalf of a person, or runtime staging.
"""
import argparse
import json
from pathlib import Path
import re
import sys

from music_candidate_intake import validate, sha256

TAKE = re.compile(r"^(.+)\.take-([0-9]{2})$")
DECISIONS = {"pending", "alternate", "rejected", "selected"}
RIGHTS = {"pending", "blocked", "cleared"}
HASH = re.compile(r"^[0-9a-f]{64}$")


def require_text(row, key):
    value = row.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Missing review field: " + key)


def inputs(manifest_path, qc_path, source):
    manifest_hash, qc_hash = sha256(manifest_path), sha256(qc_path)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    qc = json.loads(qc_path.read_text(encoding="utf-8"))
    verified = validate(manifest, source)["verified_candidates"]
    masters = {x["id"]: x for x in manifest["candidates"]}
    if (qc.get("schema") != 1 or qc.get("mode") != "read-only; no approval or publish"
            or not isinstance(qc.get("candidates"), list)):
        raise ValueError("Invalid technical QC report")
    require_text(qc, "measurement_engine")
    rows = {}
    for row in qc["candidates"]:
        ident = row["id"]
        if ident in rows:
            raise ValueError("Duplicate QC candidate")
        rows[ident] = row
    if set(rows) != set(masters) or qc.get("candidate_count") != len(masters):
        raise ValueError("QC candidate inventory does not match manifest")
    for item in verified:
        ident = item["id"]
        row = rows[ident]
        if (not isinstance(row.get("measurements"), dict)
                or not {"integrated_lufs", "true_peak_dbtp", "full_scale_samples_left",
                        "full_scale_samples_right", "wrap_sample_jump_fraction"} <= set(row["measurements"])
                or not isinstance(row.get("flags"), list)
                or any(not isinstance(flag, str) for flag in row["flags"])):
            raise ValueError("Incomplete technical QC: " + ident)
        for key in ("sha256", "model", "duration_seconds", "sample_rate", "bits"):
            if row.get(key) != item[key]:
                raise ValueError("QC source mismatch: " + ident + " " + key)
    if sha256(manifest_path) != manifest_hash or sha256(qc_path) != qc_hash:
        raise ValueError("Input report changed during verification")
    return manifest_hash, qc_hash, masters, rows


def cue_id(ident):
    match = TAKE.fullmatch(ident)
    if not match or int(match.group(2)) < 1:
        raise ValueError("Expected production take ID: " + ident)
    return match.group(1)


def template(manifest_hash, qc_hash, masters, rows):
    return {"schema": 1, "manifest_sha256": manifest_hash, "qc_sha256": qc_hash,
            "reviews": [{"id": ident, "cue": cue_id(ident),
                         "sha256": master["sha256"], "checkpoint": master["checkpoint"],
                         "decision": "pending", "listening_notes": "", "reviewer": "",
                         "qc_flags_reviewed": [],
                         "rights": "pending", "rights_reviewer": "",
                         "rights_evidence_sha256": "", "rights_notes": ""}
                        for ident, master in sorted(masters.items())]}


def verify_ledger(ledger, manifest_hash, qc_hash, masters, rows, evidence_root=None):
    if (ledger.get("schema") != 1 or ledger.get("manifest_sha256") != manifest_hash
            or ledger.get("qc_sha256") != qc_hash):
        raise ValueError("Ledger input hashes stale or invalid")
    if not isinstance(ledger.get("reviews"), list):
        raise ValueError("Expected reviews array")
    seen, selected, ready = set(), {}, []
    counts = {k: 0 for k in sorted(DECISIONS)}
    for row in ledger["reviews"]:
        ident = row["id"]
        if ident in seen or ident not in masters:
            raise ValueError("Unknown or duplicate review: " + ident)
        seen.add(ident)
        master = masters[ident]
        if (row.get("cue") != cue_id(ident) or row.get("sha256") != master["sha256"]
                or row.get("checkpoint") != master["checkpoint"]):
            raise ValueError("Review source mismatch: " + ident)
        decision, rights = row.get("decision"), row.get("rights")
        if decision not in DECISIONS or rights not in RIGHTS:
            raise ValueError("Unknown review status: " + ident)
        counts[decision] += 1
        if decision != "pending":
            require_text(row, "listening_notes")
            require_text(row, "reviewer")
        if rights != "pending":
            require_text(row, "rights_notes")
            require_text(row, "rights_reviewer")
        if rights == "cleared":
            if master["model"] == "audiocraft-musicgen":
                raise ValueError("Noncommercial MusicGen lane is research only")
            checksum = row.get("rights_evidence_sha256")
            if not isinstance(checksum, str) or not HASH.fullmatch(checksum):
                raise ValueError("Missing rights evidence hash: " + ident)
            if evidence_root is None:
                raise ValueError("Private rights evidence root required for cleared records")
            root = evidence_root.resolve(strict=True)
            evidence = (root / (checksum + ".json")).resolve(strict=True)
            if not evidence.is_relative_to(root) or not evidence.is_file() or sha256(evidence) != checksum:
                raise ValueError("Rights evidence file mismatch: " + ident)
            record = json.loads(evidence.read_text(encoding="utf-8"))
            if (record.get("candidate_sha256") != master["sha256"]
                    or record.get("checkpoint") != master["checkpoint"]):
                raise ValueError("Rights evidence not bound to master/checkpoint")
            for key in ("license_reference", "output_rights_basis", "review_date"):
                require_text(record, key)
        if decision == "selected":
            cue = row["cue"]
            if cue in selected:
                raise ValueError("Multiple selected takes: " + cue)
            selected[cue] = ident
            flags = row.get("qc_flags_reviewed")
            if not isinstance(flags, list) or any(not isinstance(x, str) for x in flags) or sorted(set(flags)) != sorted(set(rows[ident]["flags"])):
                raise ValueError("Selected take must acknowledge all QC flags: " + ident)
            if rights == "cleared":
                ready.append(ident)
    if seen != set(masters):
        raise ValueError("Ledger does not cover complete candidate inventory")
    return {"schema": 1, "manifest_sha256": manifest_hash, "qc_sha256": qc_hash,
            "decision_counts": counts, "selected": selected,
            "documented_selection_and_rights": sorted(ready),
            "mode": "record validation only; no publication authorization"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("template", "verify"))
    for key in ("manifest", "qc", "source"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--ledger", type=Path)
    parser.add_argument("--evidence-root", type=Path)
    args = parser.parse_args(argv)
    try:
        data = inputs(args.manifest, args.qc, args.source)
        if args.mode == "template":
            if args.ledger is not None:
                raise ValueError("Template writes stdout only; never overwrite an existing ledger")
            result = template(*data)
        else:
            if args.ledger is None:
                raise ValueError("--ledger required for verify")
            ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
            result = verify_ledger(ledger, *data, evidence_root=args.evidence_root)
        print(json.dumps(result, indent=2, sort_keys=True, allow_nan=False))
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as exc:
        print("MUSIC REVIEW FAILED:", exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
