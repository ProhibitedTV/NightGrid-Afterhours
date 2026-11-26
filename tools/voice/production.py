#!/usr/bin/env python3
"""Lock original synthetic cast references, render and publish reviewed dialogue.

Auditions use studio.py. Production uses the pinned Qwen Base model, never
the VoiceDesign model independently on each line.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import studio
import qc

BASE = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"
CAST = studio.ROOT / "tools/voice/cast-library"
TAKES = studio.ROOT / "dist/voice-production"
PUBLISHED = studio.ROOT / "assets/audio/voiced"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def atomic_directory(dest, writer):
    """Single-writer authoring; refuse accidental replacement."""
    if dest.exists():
        raise FileExistsError(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest.parent) as temp:
        stage = Path(temp) / "stage"
        stage.mkdir()
        writer(stage)
        if dest.exists():
            raise FileExistsError(dest)
        stage.rename(dest)


def check_cast_record(record, character, voice):
    audition = record["audition"]
    review = record["review"]
    if record["schema"] != 1 or record["character"] != character:
        raise ValueError("Wrong cast identity")
    if audition["spec"]["line"]["character"] != character or audition["spec"]["voice"] != voice:
        raise ValueError("Stale cast direction or wrong speaker")
    if audition["settings"]["model"] != studio.MODEL or not studio.REV.fullmatch(audition["settings"]["revision"]):
        raise ValueError("Invalid audition model revision")
    if audition["settings"]["reference"] != "original synthetic voice design":
        raise ValueError("Non-synthetic cast reference")
    if not studio.SHA.fullmatch(audition["sha256"]):
        raise ValueError("Invalid reference hash")
    if (review["take_sha256"] != audition["sha256"]
            or not review["reviewer"].strip() or not review["notes"].strip()
            or review["license_and_reference_checked"] is not True):
        raise ValueError("Unreviewed cast reference")
    if record["transcript"] != audition["spec"]["line"]["text"]:
        raise ValueError("Reference transcript mismatch")
    return record


def read_cast(folder, character, voice):
    record = check_cast_record(load(folder / "cast.json"), character, voice)
    if studio.digest(folder / "reference.wav") != record["audition"]["sha256"]:
        raise ValueError("Changed reference WAV")
    if studio.inspect_pcm(folder / "reference.wav") != record["audition"]["stats"]:
        raise ValueError("Invalid reference PCM")
    if studio.digest(folder / "audition.json") != record["review"]["record_sha256"]:
        raise ValueError("Changed audition metadata")
    if load(folder / "audition.json") != record["audition"]:
        raise ValueError("Cast metadata mismatch")
    return record


def lock_cast(spec, audition, dest):
    record = studio.verify(audition, spec, reviewed=True)
    character = spec["line"]["character"]
    cast = {"schema": 1, "character": character, "transcript": spec["line"]["text"],
            "audition": record, "review": load(audition / "review.json")}

    def write(stage):
        shutil.copyfile(audition / "take.wav", stage / "reference.wav")
        shutil.copyfile(audition / "take.json", stage / "audition.json")
        studio.write_json(stage / "cast.json", cast)
        read_cast(stage, character, spec["voice"])

    atomic_directory(dest, write)
    return cast


def verify_take(folder, spec, cast, approved=False, published=False):
    record = load(folder / "take.json")
    settings = record["settings"]
    character = spec["line"]["character"]
    check_cast_record(cast, character, spec["voice"])
    if record["spec"] != spec or record["cast"] != cast:
        raise ValueError("Changed line or cast")
    if (settings["model"] != BASE or not studio.REV.fullmatch(settings["revision"])
            or settings["cast_sha256"] != studio.key(cast)):
        raise ValueError("Unpinned model or incorrect cast fingerprint")
    fingerprint = studio.key({"spec": spec, "settings": settings})
    if record["fingerprint"] != fingerprint or (not published and folder.name != fingerprint):
        raise ValueError("Wrong take identity")
    wav = folder / "take.wav"
    stats = studio.inspect_pcm(wav)
    if record["sha256"] != studio.digest(wav) or record["stats"] != stats or stats["peak"] > 23200:
        raise ValueError("Invalid production PCM")
    if approved:
        report = qc.verify_report(folder, spec)
        review = load(folder / "review.json")
        if (review["take_sha256"] != record["sha256"]
                or review["record_sha256"] != studio.digest(folder / "take.json")
                or review.get("qc_sha256") != studio.digest(folder / "qc.json")
                or (report["metrics"]["flags"] and not str(review.get("qc_override","")).strip())
                or not review["reviewer"].strip() or not review["notes"].strip()
                or review["license_and_reference_checked"] is not True):
            raise ValueError("Review missing or stale")
    return record


def publish(folder, dest, spec, cast):
    verify_take(folder, spec, cast, approved=True)

    def write(stage):
        for name in ("take.wav", "take.json", "qc.json", "review.json"):
            shutil.copyfile(folder / name, stage / name)
        verify_take(stage, spec, cast, approved=True, published=True)

    atomic_directory(dest, write)


def verify_library(specs, root=PUBLISHED):
    if not root.exists():
        return 0
    count = 0
    casts = {}
    for folder in sorted(root.iterdir()):
        if not folder.is_dir() or folder.name not in specs:
            raise ValueError("Unknown published asset: " + str(folder))
        spec = specs[folder.name]
        cast = load(folder / "take.json")["cast"]
        verify_take(folder, spec, cast, approved=True, published=True)
        character = spec["line"]["character"]
        if character in casts and casts[character] != cast:
            raise ValueError("Multiple locked voices for " + character)
        casts[character] = cast
        count += 1
    return count


def provisional_review(review):
    """Recognize the original batch and future unattended playtest reviews."""
    return (review.get("reviewer") == "Anubis automated playtest QC"
            or "human listening review pending" in review.get("notes", "").casefold())


def verify_release_reviews(specs, root=PUBLISHED):
    """Never confuse machine acceptance with human release approval."""
    count = verify_library(specs, root)
    for folder in sorted(root.iterdir()) if root.exists() else ():
        record = load(folder / "take.json")
        if provisional_review(load(folder / "review.json")) or provisional_review(record["cast"]["review"]):
            raise ValueError("Provisional playtest dialogue is not release-reviewed: " + folder.name)
    return count


def generate(args, specs):
    if not args.revision or not studio.REV.fullmatch(args.revision):
        raise ValueError("Use exact Base model revision")
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    import importlib.metadata as metadata
    import soundfile as sf
    import torch
    from huggingface_hub import snapshot_download
    from qwen_tts import Qwen3TTSModel
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA unavailable")
    dtype = "float32" if args.device == "cpu" else "bfloat16"
    settings_base = {"model": BASE, "revision": args.revision, "seed": args.seed,
                     "device": args.device, "dtype": dtype,
                     "packages": {name: metadata.version(name) for name in
                                  ("qwen-tts", "torch", "soundfile", "transformers")},
                     "ffmpeg": subprocess.check_output([args.ffmpeg, "-version"], text=True).splitlines()[0]}
    model = None
    results = []
    for spec in specs:
        line = spec["line"]
        ref = CAST / line["character"]
        cast = read_cast(ref, line["character"], spec["voice"])
        settings = dict(settings_base, cast_sha256=studio.key(cast))
        fingerprint = studio.key({"spec": spec, "settings": settings})
        folder = TAKES / line["id"] / fingerprint
        if folder.exists():
            verify_take(folder, spec, cast)
            print("Verified cached production take:", folder)
            results.append({"id":line["id"],"take":fingerprint})
            continue
        if model is None:
            model = Qwen3TTSModel.from_pretrained(
                snapshot_download(BASE, revision=args.revision, local_files_only=True), local_files_only=True, device_map=args.device,
                dtype=torch.float32 if dtype == "float32" else torch.bfloat16,
                attn_implementation="sdpa")
        torch.manual_seed(args.seed)
        if args.device == "cuda":
            torch.cuda.manual_seed_all(args.seed)
        # Base supports reference-conditioned speech, not VoiceDesign-style
        # acting instructions. Direction remains a review requirement.
        wavs, rate = model.generate_voice_clone(
            text=line["text"], language=line["language"],
            ref_audio=str(ref / "reference.wav"), ref_text=cast["transcript"],
            x_vector_only_mode=False)

        def write(stage):
            with tempfile.TemporaryDirectory() as temp:
                raw = Path(temp) / "raw.wav"
                sf.write(raw, wavs[0], rate, subtype="FLOAT")
                stats = studio.master(raw, stage / "take.wav", args.ffmpeg)
            studio.write_json(stage / "take.json", {"spec": spec, "settings": settings,
                              "cast": cast, "fingerprint": fingerprint,
                              "sha256": studio.digest(stage / "take.wav"), "stats": stats})
            verify_take(stage, spec, cast, published=True)

        atomic_directory(folder, write)
        print("Production candidate:", folder)
        results.append({"id":line["id"],"take":fingerprint})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["lock", "generate", "approve", "publish", "verify-library"])
    parser.add_argument("--id", action="append")
    parser.add_argument("--take")
    parser.add_argument("--revision")
    parser.add_argument("--seed", type=int, default=308)
    parser.add_argument("--device", choices=["cpu", "cuda"], default="cuda")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--reviewer")
    parser.add_argument("--notes")
    parser.add_argument("--rights-checked", action="store_true")
    parser.add_argument("--qc-override", help="Specific listening-based justification for QC flags")
    parser.add_argument("--manifest", type=Path, default=studio.MANIFEST)
    parser.add_argument("--release-reviewed", action="store_true", help="Reject provisional machine acceptance when verifying a library")
    parser.add_argument("--result-file", type=Path, help="Write exact generated candidate IDs and fingerprints")
    args = parser.parse_args()
    specs = studio.read_manifest(args.manifest)
    if args.action == "verify-library":
        print("Verified published lines:", (verify_release_reviews if args.release_reviewed else verify_library)(specs))
        return
    if not args.id or any(i not in specs for i in args.id):
        parser.error("Select known --id values")
    if args.action == "generate":
        results = generate(args, [specs[i] for i in args.id])
        if args.result_file:
            args.result_file.parent.mkdir(parents=True, exist_ok=True)
            tmp=args.result_file.with_suffix(".tmp")
            studio.write_json(tmp, results)
            tmp.replace(args.result_file)
        return
    if len(args.id) != 1 or not args.take or not studio.SHA.fullmatch(args.take):
        parser.error("Select exactly one --id and exact --take fingerprint")
    ident = args.id[0]
    spec = specs[ident]
    char = spec["line"]["character"]
    if args.action == "lock":
        lock_cast(spec, studio.WORK / ident / args.take, CAST / char)
        print("Locked synthetic voice:", char)
        return
    cast = read_cast(CAST / char, char, spec["voice"])
    folder = TAKES / ident / args.take
    record = verify_take(folder, spec, cast)
    if args.action == "approve":
        if not args.rights_checked or not (args.reviewer or "").strip() or not (args.notes or "").strip():
            parser.error("Require performance listening, rights confirmation and review notes")
        report = qc.verify_report(folder, spec)
        if report["metrics"]["flags"] and not (args.qc_override or "").strip():
            parser.error("QC flagged this take: regenerate or supply a specific listening-based override")
        studio.write_json(folder / "review.json", {"take_sha256": record["sha256"],
                          "record_sha256": studio.digest(folder / "take.json"),
                          "reviewer": args.reviewer, "notes": args.notes,
                          "qc_sha256": studio.digest(folder / "qc.json"),
                          "qc_override": args.qc_override or "",
                          "license_and_reference_checked": True})
        verify_take(folder, spec, cast, approved=True)
        print("Approved:", folder)
    else:
        # Reject mixed casts before writing another asset to the library.
        verify_library(specs)
        for old in PUBLISHED.glob("*/take.json"):
            existing = load(old)["cast"]
            if existing["character"] == char and existing != cast:
                raise ValueError("Existing published lines use a different locked cast")
        publish(folder, PUBLISHED / ident, spec, cast)
        print("Published:", PUBLISHED / ident)


if __name__ == "__main__":
    main()
