#!/usr/bin/env python3
"""Private, explicitly selected music derivative export. Never publishes to Godot."""
import argparse
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys

from music_candidate_intake import sha256
from music_review_ledger import inputs, verify_ledger
from music_technical_qc import measure


def choose_gain(metrics, target=-18.0, ceiling=-2.0):
    loudness, peak = metrics.get("integrated_lufs"), metrics.get("true_peak_dbtp")
    if (not all(isinstance(x, (int, float)) and not isinstance(x, bool)
                and math.isfinite(x) for x in (loudness, peak))):
        raise ValueError("Cannot master a cue without measured loudness and peak")
    # Preserve dynamics: constant gain only, no limiter or compression.
    # Leave an extra dB for possible lossy codec overshoot.
    return round(min(target - loudness, ceiling - peak, 6.0), 3)


def export(manifest, qc, ledger_path, source, evidence_root, output, binary):
    source = source.resolve(strict=True)
    output = output.resolve()
    if output.parent != source or not output.name.startswith("derivatives-"):
        raise ValueError("Output must be a new derivatives-* directory inside the private batch")
    if output.exists():
        raise ValueError("Output exists; choose a new derivative revision")
    data = inputs(manifest, qc, source)
    ledger_hash = sha256(ledger_path)
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    verified = verify_ledger(ledger, *data, evidence_root=evidence_root)
    selected = verified["selected"]
    ready = set(verified["documented_selection_and_rights"])
    if not selected or set(selected.values()) != ready:
        raise ValueError("Every selected take must have documented clearance; no partial export")
    _, _, masters, rows = data
    reviews = {row["id"]: row for row in ledger["reviews"]}
    version = subprocess.check_output([binary, "-version"], text=True, timeout=10).splitlines()[0]
    records = []
    output.mkdir(exist_ok=False)
    created = []
    try:
        for cue, ident in sorted(selected.items()):
            master = masters[ident]
            path = (source / master["file"]).resolve(strict=True)
            if not path.is_relative_to(source) or sha256(path) != master["sha256"]:
                raise ValueError("Source changed before export: " + ident)
            gain = choose_gain(rows[ident]["measurements"])
            destination = output / (cue + ".ogg")
            created.append(destination)
            subprocess.run([binary, "-nostdin", "-hide_banner", "-loglevel", "error",
                            "-n", "-i", str(path), "-map", "0:a:0", "-map_metadata", "-1",
                            "-af", f"volume={gain}dB", "-ar", "48000", "-ac", "2",
                            "-c:a", "libvorbis", "-q:a", "7", str(destination)],
                           timeout=300, check=True)
            if sha256(path) != master["sha256"]:
                raise ValueError("Source changed during export: " + ident)
            metrics = measure(destination, binary)
            peak = metrics.get("true_peak_dbtp")
            if peak is None or peak > -1.0 or metrics.get("integrated_lufs") is None:
                raise ValueError("Decoded derivative exceeds peak guard or is silent: " + ident)
            records.append(dict(cue=cue, candidate=ident, source_sha256=master["sha256"],
                                checkpoint=master["checkpoint"],
                                rights_evidence_sha256=reviews[ident]["rights_evidence_sha256"],
                                file=destination.name, sha256=sha256(destination),
                                gain_db=gain, decoded_measurements=metrics))
        if sha256(ledger_path) != ledger_hash:
            raise ValueError("Ledger changed during export")
        # Revalidate manifest/QC, source and evidence immediately before handoff.
        fresh = inputs(manifest, qc, source)
        if fresh[:2] != data[:2]:
            raise ValueError("Manifest or QC changed during export")
        verify_ledger(ledger, *fresh, evidence_root=evidence_root)
        report = dict(schema=1, mode="private derivative; native listening and release authorization pending",
                      manifest_sha256=data[0], qc_sha256=data[1], ledger_sha256=ledger_hash,
                      encoder=version, codec="vorbis", quality=7, sample_rate=48000, channels=2,
                      target_lufs=-18.0, gain_cap_db=6.0, source_peak_ceiling_dbtp=-2.0,
                      decoded_peak_ceiling_dbtp=-1.0, derivatives=records)
        report_path = output / "derivatives.json"
        created.append(report_path)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False)+"\n",
                               encoding="utf-8")
    except BaseException:
        for path in created:
            path.unlink(missing_ok=True)
        output.rmdir()
        raise
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("manifest", "qc", "ledger", "source", "evidence-root", "output"):
        parser.add_argument("--" + key, type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        binary = shutil.which("ffmpeg")
        if not binary:
            raise ValueError("Existing FFmpeg with libvorbis required")
        report = export(args.manifest, args.qc, args.ledger, args.source,
                        args.evidence_root, args.output, binary)
        print(json.dumps(report, indent=2, sort_keys=True, allow_nan=False))
    except (ValueError, OSError, KeyError, TypeError, AttributeError, subprocess.SubprocessError) as exc:
        print("MUSIC EXPORT FAILED:", exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
