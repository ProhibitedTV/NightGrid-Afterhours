"""Build and verify game Oggs from the creator's local NightGrid FM masters."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def catalog():
    source = Path("scripts/nightgrid_fm.gd").read_text(encoding="utf-8")
    tracks = source.split("const TRACKS = {", 1)[1].split("}", 1)[0]
    result = dict(re.findall(r'"([a-z_]+)": "([^"]+)"', tracks))
    if len(result) != 20:
        raise ValueError("Expected twenty catalog tracks")
    return result


def sha256(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def probe(path, ffprobe):
    response = subprocess.run(
        [ffprobe, "-v", "error", "-select_streams", "a:0", "-show_entries",
         "stream=codec_name,sample_rate,channels:format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    metadata = json.loads(response.stdout)
    stream = metadata["streams"][0]
    return stream["codec_name"], int(stream["sample_rate"]), stream["channels"], float(metadata["format"]["duration"])


def prepare(source, output, ffmpeg, ffprobe):
    albums = ("Afterimage", "Free Play Until Dawn")
    masters = {}
    for album in albums:
        for path in (source / album).glob("*.wav"):
            name = path.stem.casefold()
            if name in masters:
                raise ValueError(f"Duplicate source title {path.name}")
            masters[name] = path
    tracks = catalog()
    if set(masters) != {title.casefold() for title in tracks.values()}:
        raise ValueError("The two master albums do not match the complete game catalog")
    output.mkdir(parents=True, exist_ok=True)
    results = {}
    for track, title in tracks.items():
        master = masters[title.casefold()]
        _, rate, channels, duration = probe(master, ffprobe)
        if rate != 48000 or channels != 2:
            raise ValueError(f"Unexpected master format for {master.name}")
        encoded = output / f"{track}.ogg"
        subprocess.run(
            [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-n", "-i", str(master),
             "-vn", "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
             "-ac", "2", "-ar", "48000", "-c:a", "libvorbis", "-q:a", "5", str(encoded)],
            check=True,
        )
        codec, rate, channels, encoded_duration = probe(encoded, ffprobe)
        if (codec, rate, channels) != ("vorbis", 48000, 2) or abs(encoded_duration - duration) > 0.025:
            raise ValueError(f"Encoded format or length changed for {title}")
        results[track] = {
            "title": title,
            "album": master.parent.name,
            "source_file": master.name,
            "source_bytes": master.stat().st_size,
            "source_sha256": sha256(master),
            "duration_seconds": round(encoded_duration, 6),
            "bytes": encoded.stat().st_size,
            "sha256": sha256(encoded),
        }
        print(f"{track} {encoded_duration:.3f}s {results[track]['sha256']}", flush=True)
    if len({item["sha256"] for item in results.values()}) != len(tracks):
        raise ValueError("Duplicate encoded audio")
    manifest = {"schema": 1, "format": "Ogg Vorbis", "sample_rate_hz": 48000, "channels": 2,
                "vorbis_quality": 5, "tracks": results}
    (output / "NIGHTGRID_FM_AUDIO_MANIFEST.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def verify(output):
    manifest = json.loads((output / "NIGHTGRID_FM_AUDIO_MANIFEST.json").read_text(encoding="utf-8"))
    tracks = manifest["tracks"]
    titles = catalog()
    if {key: row["title"] for key, row in tracks.items()} != titles:
        raise ValueError("Manifest and game playlist catalog differ")
    if {path.stem for path in output.glob("*.ogg")} != set(titles):
        raise ValueError("Ogg directory does not contain exactly the twenty catalog IDs")
    if (manifest["format"], manifest["sample_rate_hz"], manifest["channels"]) != ("Ogg Vorbis", 48000, 2):
        raise ValueError("Incorrect soundtrack format")
    for track, row in tracks.items():
        path = output / f"{track}.ogg"
        if path.stat().st_size != row["bytes"] or sha256(path) != row["sha256"]:
            raise ValueError(f"Pack hash mismatch for {track}")
        with path.open("rb") as file:
            if file.read(4) != b"OggS":
                raise ValueError(f"Invalid Ogg header for {track}")
    print(f"NIGHTGRID_FM_PACK PASS: {len(tracks)} distinct catalog tracks with verified Ogg hashes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Chipwave folder containing both master albums")
    parser.add_argument("--out", type=Path, default=Path("assets/audio/nightgrid_fm"))
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--ffprobe", default="ffprobe")
    options = parser.parse_args()
    if options.source:
        prepare(options.source, options.out, options.ffmpeg, options.ffprobe)
    verify(options.out)
