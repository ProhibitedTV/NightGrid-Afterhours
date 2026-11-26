#!/usr/bin/env python3
"""Offline candidate generation and explicit reviewed asset publishing."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/audio/synaxis_sfx.json"
CANDIDATES = ROOT / "dist/sfx-candidates"
DEST = ROOT / "assets/audio/generated/synaxis"
RATE = 48000


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    subprocess.run([str(x) for x in args], check=True)


def read_pcm(path):
    with wave.open(str(path), "rb") as stream:
        if (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) != (1, 2, RATE):
            raise ValueError("Expected mono PCM16 at 48 kHz")
        samples = array.array("h", stream.readframes(stream.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def prepare(raw, output, spec, ffmpeg):
    with tempfile.TemporaryDirectory() as tmp:
        mono = Path(tmp) / "mono.wav"
        run([ffmpeg, "-nostdin", "-v", "error", "-y", "-i", raw, "-ac", "1", "-ar", RATE,
             "-t", str(spec["duration"]), "-c:a", "pcm_s16le", mono])
        data = read_pcm(mono)
    if len(data) < RATE * .25:
        raise ValueError("Sound is too short")
    if spec["loop"]:
        # Overlap tail with head; rotate loop so boundary follows original adjacent samples.
        overlap = min(RATE // 4, len(data) // 8)
        cross = array.array("h", (round(data[-overlap+i]*(1-i/overlap)+data[i]*(i/overlap))
                                  for i in range(overlap)))
        data = data[overlap:-overlap] + cross
    else:
        fade = min(RATE // 100, len(data) // 4)
        for i in range(fade):
            data[i] = round(data[i]*i/fade)
            data[-1-i] = round(data[-1-i]*i/fade)
    peak = max(abs(x) for x in data)
    rms = math.sqrt(sum(float(x)*x for x in data)/len(data))
    if peak < 100 or rms < 20:
        raise ValueError("Silent or nearly silent candidate")
    # Conservative RMS target with peak cap; never clip.
    gain = min(10**(-20/20)*32767/rms, 10**(-3/20)*32767/peak)
    result = array.array("h", (round(x*gain) for x in data))
    if sys.byteorder != "little":
        result.byteswap()
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(result.tobytes())


def verify_staged_library(manifest, destination=DEST):
    """Validate a partial playtest bank, not an assertion of full coverage."""
    known = {spec["id"]: spec for spec in manifest["assets"]}
    if len(known) != len(manifest["assets"]):
        raise ValueError("Duplicate SFX cue ID")
    if not destination.exists():
        return []
    files = list(destination.iterdir())
    present = {p.stem for p in files if p.suffix in (".wav",".json")}
    unknown = present - set(known)
    if unknown:
        raise ValueError("Unknown staged SFX: " + ", ".join(sorted(unknown)))
    results = []
    for ident in sorted(present):
        spec = known[ident]
        wav, meta = destination/(ident+".wav"), destination/(ident+".json")
        if not wav.is_file() or not meta.is_file():
            raise ValueError("Incomplete SFX pair: " + ident)
        record = json.loads(meta.read_text(encoding="utf-8"))
        if (record.get("spec") != spec or record.get("sha256") != digest(wav)
                or record.get("model") != manifest["model"]
                or record.get("weights") != manifest["weights"]
                or record.get("license") != manifest["license"]):
            raise ValueError("SFX provenance mismatch: " + ident)
        if record.get("reviewed") is not True:
            if not (record.get("reviewed") is False
                    and record.get("playtest_accepted") is True
                    and record.get("rights_checked") is True
                    and record.get("machine_qc_passed") is True):
                raise ValueError("Missing playtest acceptance: " + ident)
            import re
            provenance = record.get("provenance", {})
            if (provenance.get("repo") != "stabilityai/stable-audio-3-small-sfx"
                    or not re.fullmatch(r"[0-9a-f]{40}", provenance.get("revision",""))
                    or not re.fullmatch(r"[0-9a-f]{40}", provenance.get("upstream",""))):
                raise ValueError("Unpinned provisional effect: " + ident)
        # Match the batch worker's measured PCM and duration gate.
        pcm = read_pcm(wav)
        seconds = len(pcm)/RATE
        minimum = max(.25, spec["duration"] - (.5 if spec["loop"] else .15))
        if not minimum <= seconds <= spec["duration"] + .05:
            raise ValueError("SFX duration mismatch: " + ident)
        peak = max(abs(x) for x in pcm)
        rms = math.sqrt(sum(x*x for x in pcm)/len(pcm))
        if not 100 <= peak <= 23200 or rms < 20:
            raise ValueError("SFX acoustic gate: " + ident)
        if record.get("reviewed") is not True and record.get("metrics") != {
            "seconds":round(seconds,4),"peak":peak,"rms":round(rms,3)
        }:
            raise ValueError("Stale SFX metrics: " + ident)
        results.append({"id":ident,"loop":spec["loop"],"reviewed":record["reviewed"]})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["list", "generate", "publish", "verify", "verify-playtest", "verify-staged"])
    parser.add_argument("--id", action="append", help="Select one or more IDs; defaults to all")
    parser.add_argument("--group", choices=["office","city","steps"], help="Select a sound family")
    parser.add_argument("--skip-existing", action="store_true", help="Resume candidate generation")
    parser.add_argument("--cli", default="stable-audio", help="Path to upstream executable")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--device", choices=["cpu", "cuda"], default="cpu")
    parser.add_argument("--reviewed", action="store_true", help="Confirm listening review and license compliance")
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.action == "verify-staged":
        if args.id or args.group:
            parser.error("verify-staged always checks the entire partial library")
        print(json.dumps(verify_staged_library(manifest), separators=(",",":")))
        return
    known = {x["id"]: x for x in manifest["assets"]}
    if args.id and any(x not in known for x in args.id):
        parser.error("Unknown asset ID")
    selected = [known[x] for x in args.id] if args.id else list(known.values())
    if args.group:
        def family(spec):
            name = spec["id"]
            return "steps" if name.startswith("step_") else ("city" if name.startswith(("city_", "event_")) or name == "road_roll" else "office")
        selected = [x for x in selected if family(x) == args.group]
    if not selected:
        parser.error("No selected assets")
    if args.action == "publish" and not args.reviewed:
        parser.error("Listen to candidates and confirm model license eligibility with --reviewed")
    for spec in selected:
        name = spec["id"]
        candidate = CANDIDATES / (name + ".wav")
        metadata = CANDIDATES / (name + ".json")
        final = DEST / (name + ".wav")
        sidecar = DEST / (name + ".json")
        if args.action == "list":
            print(name, spec["duration"], "loop" if spec["loop"] else "one-shot", spec["prompt"])
        elif args.action == "generate":
            if candidate.exists() and not args.replace:
                if args.skip_existing and metadata.exists():
                    existing = json.loads(metadata.read_text(encoding="utf-8"))
                    if existing["spec"] == spec and existing["sha256"] == digest(candidate):
                        print("Existing candidate:", candidate)
                        continue
                raise FileExistsError(f"{candidate}; use --replace")
            with tempfile.TemporaryDirectory() as tmp:
                raw = Path(tmp) / "raw.wav"
                run([args.cli, "--model", manifest["model"], "--device", args.device,
                     "--seed", str(spec["seed"]), "-p", spec["prompt"],
                     "--duration", str(spec["duration"]), "-o", raw])
                prepare(raw, candidate, spec, args.ffmpeg)
            record = {"spec": spec, "model": manifest["model"], "weights": manifest["weights"],
                      "license": manifest["license"], "device": args.device, "sha256": digest(candidate),
                      "reviewed": False}
            metadata.write_text(json.dumps(record, indent=2)+"\n", encoding="utf-8")
            print("Candidate:", candidate)
        elif args.action == "publish":
            record = json.loads(metadata.read_text(encoding="utf-8"))
            if record["spec"] != spec or record["sha256"] != digest(candidate):
                raise ValueError("Candidate manifest/hash mismatch; regenerate")
            read_pcm(candidate)
            if (final.exists() or sidecar.exists()) and not args.replace:
                raise FileExistsError(f"{final}; use --replace")
            DEST.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(candidate, final)
            record["reviewed"] = True
            sidecar.write_text(json.dumps(record, indent=2)+"\n", encoding="utf-8")
            print("Published:", final)
        else:
            record = json.loads(sidecar.read_text(encoding="utf-8"))
            data = read_pcm(final)
            accepted = record.get("reviewed") is True
            if args.action == "verify-playtest":
                accepted = accepted or (record.get("playtest_accepted") is True
                    and record.get("rights_checked") is True
                    and record.get("machine_qc_passed") is True)
            if record["spec"] != spec or not accepted or record["sha256"] != digest(final) or not data:
                raise ValueError(f"Invalid published sound: {name}")
            print("Verified:", final)


if __name__ == "__main__":
    main()
