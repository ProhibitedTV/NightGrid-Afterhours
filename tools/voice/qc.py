#!/usr/bin/env python3
"""Offline speech QC; transcript agreement is a triage signal, not proof."""
import argparse
import hashlib
import importlib.metadata
import os
from pathlib import Path
import unicodedata
import wave
from array import array
import sys

import studio

SCHEMA = 1
LANG = {"English": "en", "Chinese": "zh"}


def tokens(text, language):
    text = unicodedata.normalize("NFKC", text).casefold().replace("’", "'")
    # English contractions stay intact; Mandarin is measured by characters.
    if language == "Chinese":
        return [c for c in text if unicodedata.category(c)[0] in "LN"]
    clean = "".join(c if c.isalnum() or c == "'" else " " for c in text)
    return clean.split()


def distance(a, b):
    row = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        nxt = [i]
        for j, y in enumerate(b, 1):
            nxt.append(min(row[j]+1, nxt[-1]+1, row[j-1]+(x != y)))
        row = nxt
    return row[-1]


def acoustic(path):
    stats = studio.inspect_pcm(path)
    with wave.open(str(path), "rb") as f:
        pcm = array("h", f.readframes(stats["frames"]))
    if sys.byteorder != "little":
        pcm.byteswap()
    # 20ms RMS windows, -45dBFS quiet threshold; preserve intended pauses.
    step = studio.RATE // 50
    quiet = []
    for i in range(0, len(pcm), step):
        chunk = pcm[i:i+step]
        quiet.append(sum(x*x for x in chunk) / len(chunk) < (32768*10**(-45/20))**2)
    lead = next((i for i, q in enumerate(quiet) if not q), len(quiet))
    tail = next((i for i, q in enumerate(reversed(quiet)) if not q), len(quiet))
    return {"seconds":round(len(pcm)/studio.RATE, 3),
            "leading_quiet_seconds":round(lead/50, 2),
            "trailing_quiet_seconds":round(tail/50, 2),
            "quiet_fraction":round(sum(quiet)/len(quiet), 3),
            "peak":stats["peak"], "rms":stats["rms"]}


def assess(path, line, transcript):
    expected = tokens(line["text"], line["language"])
    observed = tokens(transcript, line["language"])
    if not expected or len(expected) > 2000 or len(observed) > 4000:
        raise ValueError("Invalid transcript length")
    edits = distance(expected, observed)
    metrics = acoustic(path)
    flags = []
    if not observed:
        flags.append("no_transcript")
    if edits:
        flags.append("transcript_difference")
    if metrics["leading_quiet_seconds"] > .75:
        flags.append("long_leading_silence")
    if metrics["trailing_quiet_seconds"] > 1.0:
        flags.append("long_trailing_silence")
    if metrics["quiet_fraction"] > .6:
        flags.append("mostly_quiet")
    if metrics["peak"] > 23200:
        flags.append("peak_ceiling")
    return {"unit":"characters" if line["language"]=="Chinese" else "words",
            "expected_units":len(expected), "observed_units":len(observed),
            "edits":edits, "error_rate":round(edits/len(expected), 4),
            "acoustic":metrics, "flags":flags}


def model_digest(root):
    required = ("model.bin", "config.json", "tokenizer.json")
    if not root.is_dir() or any(not (root / f).is_file() for f in required):
        raise ValueError("Use a complete local CTranslate2 multilingual Whisper model")
    h = hashlib.sha256()
    for p in sorted(root.iterdir(), key=lambda p:p.name):
        if p.is_file() and not p.name.startswith("."):
            h.update(studio.canonical(p.name))
            with p.open("rb") as f:
                for block in iter(lambda:f.read(1024*1024), b""):
                    h.update(block)
            h.update(b"\0")
    return h.hexdigest()


def create_report(folder, spec, transcript, model, packages):
    return {"schema":SCHEMA, "wav_sha256":studio.digest(folder/"take.wav"),
            "take_sha256":studio.digest(folder/"take.json"),
            "line_sha256":studio.key(spec["line"]), "model_sha256":model,
            "packages":packages, "transcript":transcript,
            "metrics":assess(folder/"take.wav",spec["line"],transcript)}


def verify_report(folder, spec):
    import json
    report = json.loads((folder/"qc.json").read_text(encoding="utf-8"))
    if report["schema"] != SCHEMA or not studio.SHA.fullmatch(report["model_sha256"]):
        raise ValueError("Invalid QC provenance")
    if not all(isinstance(report["packages"].get(k),str) and report["packages"][k]
               for k in ("faster-whisper","ctranslate2")):
        raise ValueError("Missing ASR package provenance")
    actual = create_report(folder,spec,report["transcript"],report["model_sha256"],report["packages"])
    if report != actual:
        raise ValueError("Stale or modified QC report")
    return report


def main():
    import production
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", action="append", required=True)
    parser.add_argument("--take", action="append", required=True)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--device", choices=["cpu","cuda"], default="cpu")
    parser.add_argument("--manifest", type=Path, default=studio.MANIFEST)
    args = parser.parse_args()
    specs = studio.read_manifest(args.manifest)
    if (len(args.id)!=len(args.take) or len(set(zip(args.id,args.take)))!=len(args.id)
            or any(i not in specs for i in args.id)
            or any(not studio.SHA.fullmatch(t) for t in args.take)):
        parser.error("Supply matching, unique --id and --take pairs")
    jobs=[]
    for ident,take in zip(args.id,args.take):
        spec=specs[ident]
        char=spec["line"]["character"]
        cast=production.read_cast(production.CAST/char,char,spec["voice"])
        folder=production.TAKES/ident/take
        production.verify_take(folder,spec,cast)
        jobs.append((folder,spec))
    fingerprint = model_digest(args.model_dir)
    os.environ["HF_HUB_OFFLINE"]="1"
    os.environ["TRANSFORMERS_OFFLINE"]="1"
    from faster_whisper import WhisperModel
    packages = {k:importlib.metadata.version(k) for k in ("faster-whisper","ctranslate2")}
    packages.update({"device":args.device,"compute_type":"int8" if args.device=="cpu" else "float16", "decode_contract":"beam5-temp0-no-context-no-vad-v1"})
    model=None
    for folder,spec in jobs:
        # Reuse reports only when the exact model and dependency versions match.
        try:
            previous=verify_report(folder,spec)
            if previous["model_sha256"]==fingerprint and previous["packages"]==packages:
                print("Verified cached QC:",folder)
                continue
        except (FileNotFoundError,ValueError,KeyError):
            pass
        if model is None:
            model = WhisperModel(str(args.model_dir.resolve()),device=args.device,
                                 compute_type="int8" if args.device=="cpu" else "float16",
                                 local_files_only=True)
        segments, _ = model.transcribe(str(folder/"take.wav"),language=LANG[spec["line"]["language"]],
                                      beam_size=5,condition_on_previous_text=False,
                                      vad_filter=False,temperature=0.0)
        # No expected-text prompt; avoid biasing recognition.
        transcript = " ".join(s.text.strip() for s in segments)
        report = create_report(folder,spec,transcript,fingerprint,packages)
        temp=folder/"qc.json.tmp"
        studio.write_json(temp,report)
        temp.replace(folder/"qc.json")
        verify_report(folder,spec)
        print("QC:",folder,report["metrics"])
        print("Recognized:",transcript)


if __name__=="__main__":
    main()
