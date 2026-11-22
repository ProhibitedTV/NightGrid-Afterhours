"""Trim the licensed public preview recordings into game loops and footfalls."""

from array import array
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import wave


RATE = 32000
SOURCES = {
    "traffic": 223093, "harbor": 254125, "stone": 521590,
    "tile": 834027, "gravel": 521588,
}
CLIPS = {
    "stone": ((0.00, 0.31), (0.665, 0.97), (1.23, 1.53), (1.78, 2.08)),
    "tile": ((0.00, 0.28), (0.885, 1.15), (2.728, 3.04), (4.563, 4.85)),
    "gravel": ((0.00, 0.49), (0.826, 1.19), (1.53, 1.88), (2.204, 2.56)),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode(encoder, path, channels, filters):
    samples = subprocess.run(
        [encoder, "-nostdin", "-hide_banner", "-loglevel", "error", "-i", str(path),
         "-af", filters, "-f", "s16le", "-ac", str(channels), "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return array("h", samples)


def write_loop(encoder, source, path, channels, minimum_seconds):
    samples = decode(encoder, source, channels, "highpass=f=42")
    blend = int(0.8 * RATE)
    result = samples[blend * channels:]
    end = len(result) - blend * channels
    for frame in range(blend):
        ratio = frame / (blend - 1)
        for channel in range(channels):
            offset = frame * channels + channel
            result[end + offset] = round(
                result[end + offset] * (1.0 - ratio) + samples[offset] * ratio
            )
    if len(result) / (RATE * channels) < minimum_seconds:
        raise ValueError(f"Source loop is truncated for {path.name}")
    subprocess.run(
        [encoder, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-f", "s16le",
         "-ac", str(channels), "-ar", str(RATE), "-i", "-", "-map_metadata", "-1",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", "4",
         str(path)],
        check=True, input=result.tobytes(),
    )


def write_steps(samples, surface, destination, peak):
    paths = []
    for index, (start, end) in enumerate(CLIPS["stone" if surface == "asphalt" else surface], 1):
        clip = samples[round(start * RATE):round(end * RATE)]
        amplitude = max(abs(sample) for sample in clip)
        if amplitude < 100:
            raise ValueError(f"No transient in {surface} cue {index}")
        gain = 32767 * peak / amplitude
        result = array("h")
        for frame, sample in enumerate(clip):
            fade = min(1.0, frame / (0.004 * RATE), (len(clip) - frame - 1) / (0.022 * RATE))
            result.append(round(sample * gain * fade))
        path = destination / f"{surface}_{index}.wav"
        with wave.open(str(path), "wb") as file:
            file.setparams((1, 2, RATE, len(result), "NONE", "not compressed"))
            file.writeframes(result.tobytes())
        paths.append(path)
    return paths


def verify(destination):
    manifest = json.loads((destination / "MANIFEST.json").read_text(encoding="utf-8"))
    if manifest["license"] != "CC0-1.0" or manifest["sample_rate_hz"] != RATE:
        raise ValueError("Unexpected field-audio manifest format")
    if len(manifest["files"]) != 18 or set(manifest["public_previews"]) != set(SOURCES):
        raise ValueError("The field bank must contain both loops and all sixteen footsteps")
    for name, expected in manifest["files"].items():
        path = destination / name
        if digest(path) != expected:
            raise ValueError(f"Field-audio hash mismatch for {name}")
        if path.suffix == ".wav":
            with wave.open(str(path), "rb") as clip:
                if (clip.getframerate(), clip.getnchannels(), clip.getsampwidth()) != (RATE, 1, 2):
                    raise ValueError(f"Invalid footfall format for {name}")
    print("MORROW_BAY_FIELD_BANK PASS: eighteen verified field-recording derivatives")


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("source", type=Path, nargs="?", help="Folder with the five *-preview.mp3 files")
    cli.add_argument("out", type=Path, default=Path("assets/audio/morrow_bay"), nargs="?")
    cli.add_argument("--ffmpeg", default="ffmpeg")
    config = cli.parse_args()
    if config.source is None:
        verify(config.out)
        raise SystemExit(0)
    steps = config.out / "steps"
    steps.mkdir(parents=True, exist_ok=True)
    derivatives = {}
    for key, channels, seconds in (("traffic", 2, 28), ("harbor", 1, 58)):
        path = config.out / f"{key}.ogg"
        write_loop(config.ffmpeg, config.source / f"{key}-preview.mp3", path, channels, seconds)
        derivatives[path.name] = digest(path)
    for surface in ("stone", "tile", "gravel", "asphalt"):
        source = config.source / f"{'stone' if surface == 'asphalt' else surface}-preview.mp3"
        response = "highpass=f=90,lowpass=f=1650" if surface == "asphalt" else "highpass=f=75"
        samples = decode(config.ffmpeg, source, 1, response)
        for path in write_steps(samples, surface, steps, 0.59 if surface == "gravel" else 0.67):
            derivatives[f"steps/{path.name}"] = digest(path)
    manifest = {
        "sample_rate_hz": RATE,
        "license": "CC0-1.0",
        "public_previews": {
            key: {"id": number, "sha256": digest(config.source / f"{key}-preview.mp3")}
            for key, number in SOURCES.items()
        },
        "files": derivatives,
    }
    (config.out / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify(config.out)
