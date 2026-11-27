#!/usr/bin/env python3
"""Read-only, candidate-only intake for original locally generated music masters.

Never synthesizes, installs models, publishes, copies, or modifies user audio.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import wave

ID = re.compile(r"^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$")
HASH = re.compile(r"^[0-9a-f]{64}$")
ALLOWED = {"ace-step", "audiocraft-musicgen", "other-local"}
MAX_BYTES = 512 * 1024 * 1024


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(data, source_root):
    if not isinstance(data, dict) or data.get("schema") != 1:
        raise ValueError("Expected schema 1 manifest")
    entries = data.get("candidates")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Expected nonempty candidates array")
    if not source_root.is_dir():
        raise ValueError("Source directory missing")
    ids = set()
    verified = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("Candidate must be an object")
        ident = entry.get("id")
        if not isinstance(ident, str) or not ID.fullmatch(ident) or ident in ids:
            raise ValueError("Invalid or duplicate candidate ID")
        ids.add(ident)
        relative = entry.get("file")
        if not isinstance(relative, str) or not relative or "\\" in relative:
            raise ValueError("Invalid relative source path")
        rel = Path(relative)
        if rel.is_absolute() or rel.suffix.lower() != ".wav" or ".." in rel.parts:
            raise ValueError("Only local relative WAV paths are allowed")
        path = (source_root / rel).resolve(strict=True)
        if not path.is_relative_to(source_root.resolve()):
            raise ValueError("Source resolves outside input directory")
        if not path.is_file() or path.stat().st_size > MAX_BYTES:
            raise ValueError("Missing/oversized WAV: " + ident)
        checksum = entry.get("sha256")
        if not isinstance(checksum, str) or not HASH.fullmatch(checksum):
            raise ValueError("Missing valid SHA-256: " + ident)
        if sha256(path) != checksum:
            raise ValueError("WAV checksum mismatch: " + ident)
        model = entry.get("model")
        if model not in ALLOWED:
            raise ValueError("Unknown model identifier: " + ident)
        for field in ("checkpoint", "scene", "direction", "rights_notes"):
            value = entry.get(field)
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Missing " + field + ": " + ident)
        if entry.get("reviewed") is not False:
            raise ValueError("Intake only accepts unreviewed candidates: " + ident)
        try:
            with wave.open(str(path), "rb") as reader:
                nch = reader.getnchannels()
                sample_width = reader.getsampwidth()
                rate = reader.getframerate()
                frames = reader.getnframes()
                if reader.getcomptype() != "NONE":
                    raise ValueError("Expected uncompressed PCM")
        except (wave.Error, EOFError) as exc:
            raise ValueError("Invalid PCM WAV: " + ident) from exc
        # wave.open parses headers, but a truncated data chunk may still claim
        # more frames than the file contains. Require the complete PCM payload.
        if frames <= 0 or frames * nch * sample_width > path.stat().st_size - 44:
            raise ValueError("Incomplete PCM data: " + ident)
        duration = frames / rate if rate else 0.0
        if nch != 2 or sample_width not in (2, 3) or rate not in (44100, 48000):
            raise ValueError("Expected stereo PCM16/24, 44.1/48 kHz: " + ident)
        if not 1.0 <= duration <= 600.0:
            raise ValueError("Duration outside 1..600 seconds: " + ident)
        verified.append({"id": ident, "model": model, "scene": entry["scene"],
                         "duration_seconds": round(duration, 3),
                         "sample_rate": rate, "bits": sample_width * 8,
                         "sha256": checksum,
                         "commercial_status": "blocked-noncommercial-model" if model == "audiocraft-musicgen" else "blocked-pending-rights-review",
                         "status": "verified-candidate; listening and rights review pending"})
    return {"schema": 1, "mode": "read-only; no automatic publish",
            "verified_candidates": verified}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = validate(json.loads(args.manifest.read_text(encoding="utf-8")), args.source)
        print(json.dumps(result, indent=2, sort_keys=True))
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print("MUSIC INTAKE FAILED:", exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
