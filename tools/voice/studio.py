#!/usr/bin/env python3
"""Offline voice auditions: generation, mastering, explicit review, verification."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/voice/auditions.json"
WORK = ROOT / "dist/voice-candidates"
MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
RATE = 48000
ID = re.compile(r"[a-z][a-z0-9_.-]{0,100}\Z")
SHA = re.compile(r"[a-f0-9]{64}\Z")
REV = re.compile(r"[a-f0-9]{40}\Z")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def key(obj):
    return hashlib.sha256(canonical(obj)).hexdigest()


def read_manifest(path=MANIFEST):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data["schema"] != 1:
        raise ValueError("Unsupported manifest")
    result = {}
    for line in data["lines"]:
        ident = line["id"]
        if not ID.fullmatch(ident) or ident in result:
            raise ValueError("Invalid or duplicate line ID: " + ident)
        if line["language"] not in ("English", "Chinese"):
            raise ValueError("Unsupported audition language")
        for field in ("text", "direction"):
            if not isinstance(line[field], str) or not line[field].strip():
                raise ValueError("Empty " + field)
        if line["language"] != "English" and not line.get("caption"):
            raise ValueError("Translation required")
        result[ident] = {"line": line, "voice": data["characters"][line["character"]]}
    return result


def inspect_pcm(path):
    with wave.open(str(path), "rb") as f:
        if (f.getnchannels(), f.getsampwidth(), f.getframerate()) != (1, 2, RATE):
            raise ValueError("Expected mono PCM16 at 48 kHz")
        n = f.getnframes()
        if not RATE // 4 <= n <= 45 * RATE:
            raise ValueError("Invalid duration (0.25–45 seconds)")
        raw = f.readframes(n)
    if len(raw) != n * 2:
        raise ValueError("Truncated PCM")
    samples = struct.unpack("<" + "h" * n, raw)
    peak = max(abs(x) for x in samples)
    rms = math.sqrt(sum(x*x for x in samples) / n)
    if peak < 100 or rms < 20:
        raise ValueError("Silent candidate")
    return {"frames": n, "peak": peak, "rms": round(rms, 2)}


def master(raw, out, ffmpeg):
    # No hard truncation, loop processing or aggressive silence removal.
    with tempfile.TemporaryDirectory() as temp:
        pcm = Path(temp) / "mono.wav"
        subprocess.run([ffmpeg, "-nostdin", "-v", "error", "-y", "-i", str(raw),
                        "-ac", "1", "-ar", str(RATE), "-c:a", "pcm_s16le", str(pcm)],
                       check=True)
        stats = inspect_pcm(pcm)
        with wave.open(str(pcm), "rb") as f:
            samples = struct.unpack("<" + "h"*stats["frames"], f.readframes(stats["frames"]))
    # Initial audition targets, not LUFS measurement. Preserve intentional dynamics.
    gain = min(32767 * 10**(-22/20) / stats["rms"],
               32767 * 10**(-3/20) / stats["peak"], 4)
    with wave.open(str(out), "wb") as f:
        f.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        f.writeframes(struct.pack("<" + "h"*len(samples), *(round(x*gain) for x in samples)))
    return inspect_pcm(out)


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def verify(folder, spec, reviewed=False):
    record = json.loads((folder / "take.json").read_text(encoding="utf-8"))
    wav = folder / "take.wav"
    if record["spec"] != spec or record["sha256"] != digest(wav):
        raise ValueError("Stale text/direction or changed audio")
    if record["settings"]["model"] != MODEL or not REV.fullmatch(record["settings"]["revision"]):
        raise ValueError("Unpinned model")
    if record["settings"]["reference"] != "original synthetic voice design":
        raise ValueError("Unexpected reference origin")
    if folder.name != key({"spec": spec, "settings": record["settings"]}):
        raise ValueError("Candidate identity mismatch")
    stats = inspect_pcm(wav)
    if stats != record["stats"] or stats["peak"] > 23200:
        raise ValueError("Mastering stats mismatch or peak exceeds ceiling")
    if reviewed:
        approval = json.loads((folder / "review.json").read_text(encoding="utf-8"))
        if (approval["take_sha256"] != record["sha256"]
                or approval["record_sha256"] != digest(folder / "take.json")
                or not approval["reviewer"].strip()
                or not approval["notes"].strip()
                or approval["license_and_reference_checked"] is not True):
            raise ValueError("Review missing, stale or incomplete")
    return record


def generate(args, specs):
    if not args.revision or not REV.fullmatch(args.revision):
        raise ValueError("Use an exact 40-character Hugging Face checkpoint revision")
    # Offline by default; checkpoint acquisition is a separate explicit operation.
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    import importlib.metadata as metadata
    import torch
    import soundfile as sf
    from huggingface_hub import snapshot_download
    from qwen_tts import Qwen3TTSModel
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA unavailable; select cpu explicitly")
    settings = {"model": MODEL, "revision": args.revision, "seed": args.seed,
                "device": args.device, "dtype": "float32" if args.device == "cpu" else "bfloat16",
                "reference": "original synthetic voice design",
                "packages": {name: metadata.version(name) for name in
                             ("qwen-tts", "torch", "soundfile", "transformers")},
                "ffmpeg": subprocess.check_output([args.ffmpeg, "-version"], text=True).splitlines()[0]}
    model = None
    for spec in specs:
        ident = key({"spec": spec, "settings": settings})
        folder = WORK / spec["line"]["id"] / ident
        if folder.exists():
            verify(folder, spec)
            print("Verified cached take:", folder)
            continue
        if model is None:
            model = Qwen3TTSModel.from_pretrained(
                snapshot_download(MODEL, revision=args.revision, local_files_only=True), local_files_only=True,
                device_map=args.device, dtype=torch.float32 if args.device == "cpu" else torch.bfloat16,
                attn_implementation="sdpa")
        torch.manual_seed(args.seed)
        if args.device == "cuda":
            torch.cuda.manual_seed_all(args.seed)
        line = spec["line"]
        wavs, rate = model.generate_voice_design(
            text=line["text"], language=line["language"],
            instruct=spec["voice"]["direction"] + " " + line["direction"])
        folder.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=folder.parent) as temp:
            stage = Path(temp) / ident
            stage.mkdir()
            raw = Path(temp) / "raw.wav"
            sf.write(raw, wavs[0], rate, subtype="FLOAT")
            stats = master(raw, stage / "take.wav", args.ffmpeg)
            write_json(stage / "take.json", {"spec": spec, "settings": settings,
                       "sha256": digest(stage / "take.wav"), "stats": stats})
            verify(stage, spec)
            stage.rename(folder)
        print("Candidate:", folder)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["list", "generate", "verify", "approve"])
    parser.add_argument("--id", action="append")
    parser.add_argument("--revision")
    parser.add_argument("--seed", type=int, default=308)
    parser.add_argument("--device", choices=["cpu", "cuda"], default="cuda")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--take", help="Exact candidate fingerprint")
    parser.add_argument("--reviewer")
    parser.add_argument("--notes")
    parser.add_argument("--rights-checked", action="store_true")
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    args = parser.parse_args()
    specs = read_manifest(args.manifest)
    selected = args.id or list(specs)
    if any(i not in specs for i in selected):
        parser.error("Unknown line ID")
    if args.action == "list":
        for i in selected:
            print(i, specs[i]["line"]["language"], specs[i]["line"]["text"])
    elif args.action == "generate":
        generate(args, [specs[i] for i in selected])
    else:
        if len(selected) != 1 or not args.take or not SHA.fullmatch(args.take):
            parser.error("Select exactly one --id and exact --take fingerprint")
        folder = WORK / selected[0] / args.take
        record = verify(folder, specs[selected[0]])
        if args.action == "approve":
            if not args.rights_checked or not (args.reviewer or "").strip() or not (args.notes or "").strip():
                parser.error("Require listening review, reviewer, notes and rights confirmation")
            write_json(folder / "review.json", {"take_sha256": record["sha256"],
                       "record_sha256": digest(folder / "take.json"), "reviewer": args.reviewer,
                       "notes": args.notes, "license_and_reference_checked": True})
            verify(folder, specs[selected[0]], reviewed=True)
        elif (folder / "review.json").exists():
            verify(folder, specs[selected[0]], reviewed=True)
        print("Verified:", folder)


if __name__ == "__main__":
    main()
