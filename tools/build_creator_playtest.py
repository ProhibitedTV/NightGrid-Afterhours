#!/usr/bin/env python3
"""Build a private creator playtest from a clean, already staged Windows checkout.

No generation, publishing, git reset, or overwrite. Requires #510 and #511.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT_VERSION = "4.7.2"
MARKER = b'const REVISION = "development"'
RADIO_NAMES = ("report", "assigned", "ack", "contact", "search", "closed", "released",
               "unavailable", "available", "civicmotorist", "civictraffic", "civicpublic")
RADIO_GENERATED = {f"?? assets/audio/mbpd/{name}.wav{suffix}"
                   for name in RADIO_NAMES for suffix in ("", ".import")}
CREDITS = {
    "assets/models/nightgrid/courier/SOURCE.md": "COURIER-ASSET-CREDITS.md",
    "assets/audio/nightgrid_fm/README.md": "NIGHTGRID-FM-CREDITS.md",
    "assets/audio/morrow_bay/SOURCE.md": "MORROW-BAY-AUDIO-CREDITS.md",
    "docs/PLAYTEST_MAIN_ACCEPTANCE.md": "PLAYTEST-GUIDE.md",
}

def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def require_clean(*, after_import=False):
    changes = git("status", "--porcelain", "--untracked-files=all").splitlines()
    tracked = set(git("ls-files").splitlines()) if after_import else set()
    unexpected = []
    for line in changes:
        if line in RADIO_GENERATED:
            continue
        # A clean checkout gains sidecars on the first native Godot import.
        # Only new sidecars of tracked sources are allowed after that import.
        # Tracked metadata edits and unrelated untracked files still fail.
        path = line[3:]
        if after_import and line.startswith("?? "):
            if path.endswith(".import") and path[:-7] in tracked:
                continue
            if path.endswith((".gd.uid", ".gdshader.uid")) and path[:-4] in tracked:
                continue
        unexpected.append(line)
    if unexpected:
        raise RuntimeError("Commit or preserve unique local source changes first; refusing dirty checkout: "
                           + "; ".join(unexpected[:8]))

def radio_inventory():
    hashes = {}
    for name in RADIO_NAMES:
        clip = ROOT / "assets/audio/mbpd" / (name + ".wav")
        if not clip.is_file() or clip.is_symlink():
            raise RuntimeError(f"Missing existing MBPD radio clip: {clip}")
        with wave.open(str(clip), "rb") as audio:
            if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or audio.getnframes() <= 0:
                raise RuntimeError(f"Invalid MBPD radio PCM: {clip}")
        hashes[name + ".wav"] = sha256(clip)
    return hashes

def fresh_output(path):
    path = path.resolve()
    source = ROOT.resolve()
    if path == source or source in path.parents:
        raise RuntimeError("Choose an artifact directory outside the source checkout")
    path.mkdir(parents=True, exist_ok=False)
    return path

def step(logs, label, argv, cwd=ROOT, marker=None, timeout=900):
    print("RUN", label, flush=True)
    with (logs / (label + ".log")).open("wb") as log:
        result = subprocess.run([str(arg) for arg in argv], cwd=cwd, stdout=log,
                                stderr=subprocess.STDOUT, timeout=timeout)
    data = (logs / (label + ".log")).read_bytes()
    if (result.returncode or b"SCRIPT ERROR:" in data or b"Parse Error:" in data
            or (marker and marker.encode() not in data)):
        raise RuntimeError(f"{label} failed; inspect {logs / (label + '.log')}")
    return data.decode("utf-8", errors="replace")

def audio_inventory(voice_output, sfx_output):
    """Parse the same provenance verifier outputs used by Windows CI."""
    match = re.fullmatch(r"Verified published lines: (\d+)", voice_output.strip())
    if match is None:
        raise RuntimeError("Unexpected voice verification result")
    bank = json.loads(sfx_output)
    if not isinstance(bank, list):
        raise RuntimeError("Expected verified SFX inventory")
    ids = set()
    for entry in bank:
        if (not isinstance(entry, dict) or not isinstance(entry.get("id"), str)
                or not entry["id"] or entry["id"] in ids
                or type(entry.get("loop")) is not bool or type(entry.get("reviewed")) is not bool):
            raise RuntimeError("Invalid or duplicate verified SFX entry")
        ids.add(entry["id"])
    return int(match.group(1)), bank

def stamp(original, revision):
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or original.count(MARKER) != 1:
        raise RuntimeError("Unexpected source identity; refusing to stamp")
    if original.count(b'const CHANNEL = "development"') != 1:
        raise RuntimeError("Not a development-channel checkout")
    return original.replace(MARKER, f'const REVISION = "{revision}"'.encode())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path, help="Godot 4.7.2 Windows console executable")
    parser.add_argument("--out", required=True, type=Path, help="New private artifact directory outside checkout")
    args = parser.parse_args()
    if sys.platform != "win32":
        raise RuntimeError("Run in native Windows on Anubis, not WSL")
    engine = args.godot.resolve(strict=True)
    require_clean()
    revision = git("rev-parse", "HEAD")
    if not (ROOT / "tests/synaxis_creator_cast_smoke.gd").is_file():
        raise RuntimeError("Strict creator cast smoke is missing; integrate #510 first")
    if "--verify-creator-pck" not in (ROOT / "scripts/studio_intro.gd").read_text(encoding="utf-8"):
        raise RuntimeError("Packaged candidate verifier missing; integrate #511 first")
    # Require the existing radio bank, not an implicit generation run.
    radio_hashes = radio_inventory()
    out = fresh_output(args.out)
    logs = out / "logs"
    logs.mkdir()
    version = step(logs, "engine-version", [engine, "--version"], timeout=30).strip()
    if not version.startswith(GODOT_VERSION + "."):
        raise RuntimeError("Expected Godot 4.7.2, got " + version)
    step(logs, "voice-contract", [sys.executable, "tools/voice/chapter.py", "validate",
                                 "--source", "scripts/opening_story.gd"])
    voice_output = step(logs, "voice-library", [sys.executable, "tools/voice/production.py", "verify-library",
                                "--manifest", "tools/voice/synaxis_chapter.json"])
    sfx_output = step(logs, "sfx-library", [sys.executable, "tools/audio/generate_sfx.py", "verify-staged"])
    voice_count, sfx_bank = audio_inventory(voice_output, sfx_output)
    print(f"Verified source audio inventory: {voice_count} spoken lines, {len(sfx_bank)} SFX")
    if not voice_count or not sfx_bank:
        raise RuntimeError("Creator package requires nonempty existing voice and SFX banks; recover, do not regenerate blindly")
    info = ROOT / "scripts/build_info.gd"
    original = info.read_bytes()
    stamped = stamp(original, revision)
    exe = out / "NightGrid-Afterhours.exe"
    pck = exe.with_suffix(".pck")
    # Restore exact bytes even after failed import, test or export. Never use git reset.
    try:
        info.write_bytes(stamped)
        import_output = step(logs, "import", [engine, "--headless", "--path", ROOT, "--import", "--quit"])
        if "Cannot generate mipmaps from compressed image formats" in import_output:
            raise RuntimeError("Import reported compressed-image mipmap failure")
        step(logs, "voice-import", [engine, "--headless", "--path", ROOT, "--script",
                                    "res://tests/voiced_asset_bank_smoke.gd", "--", voice_count],
             marker="VOICED_ASSET_BANK PASS:", timeout=180)
        step(logs, "sfx-import", [engine, "--headless", "--path", ROOT, "--script",
                                  "res://tests/generated_sfx_bank_smoke.gd", "--",
                                  json.dumps(sfx_bank, separators=(",", ":"))],
             marker="GENERATED_SFX_BANK PASS:", timeout=180)
        step(logs, "strict-cast", [engine, "--headless", "--path", ROOT, "--script",
                                  "res://tests/synaxis_creator_cast_smoke.gd", "--", "--require-cast"],
             marker="SYNAXIS_CREATOR_CAST PASS: all four staged actors", timeout=180)
        step(logs, "windows-export", [engine, "--headless", "--path", ROOT,
                                     "--export-release", "Windows Desktop", exe])
    finally:
        if info.read_bytes() == stamped:
            info.write_bytes(original)
        else:
            raise RuntimeError("Build-info changed during export; preserve it and inspect manually")
    require_clean(after_import=True)
    if git("rev-parse", "HEAD") != revision:
        raise RuntimeError("Source revision moved during packaging")
    if radio_inventory() != radio_hashes:
        raise RuntimeError("Generated MBPD radio bank changed during packaging")
    for path in (exe, pck):
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError("Missing export payload: " + str(path))
    step(logs, "packaged-cast", [exe, "--headless", "--", "--verify-creator-pck"], cwd=out,
         marker="CREATOR_PCK PASS: all four exact candidate hashes", timeout=120)
    # Ordinary launch is deliberately left to native QA to avoid touching existing saves.
    for src, dest in CREDITS.items():
        shutil.copyfile(ROOT / src, out / dest)
    (out / "BUILD-INFO.txt").write_text(
        f"NightGrid: Afterhours PRIVATE creator playtest\nSource commit: {revision}\n"
        f"Channel: development\nGodot: {version}\nNative visual acceptance pending. Not for publication.\n",
        encoding="utf-8")
    cast = ROOT / "assets/creator_playtest_cast"
    manifest = {"revision": revision, "godot": version, "channel": "development",
                "candidate_hashes": {name: sha256(cast / name) for name in
                                     ("dev.glb.bin", "rina.glb.bin", "dana.glb.bin", "jetson.glb.bin")},
                "audio_inventory": {"local_mbpd_radio_hashes": radio_hashes,
                                    "verified_source_voice_lines": voice_count,
                                    "verified_source_sfx": sfx_bank,
                                    "complete_or_human_reviewed": "not asserted"},
                "checks": ["voice-contract", "voice-library", "sfx-library", "import",
                           "voice-import", "sfx-import", "strict-cast", "windows-export", "packaged-cast"],
                "native_acceptance": "pending"}
    (out / "CREATOR-MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    payload = [exe, pck, out / "BUILD-INFO.txt", out / "CREATOR-MANIFEST.json"]
    payload += [out / name for name in CREDITS.values()]
    (out / "SHA256SUMS.txt").write_text(
        "".join(f"{sha256(path)}  {path.name}\n" for path in payload), encoding="utf-8")
    print("CREATOR_BUILD PASS:", out)
    print("Native gameplay, rights and performance acceptance remain pending.")

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, EOFError, wave.Error, subprocess.SubprocessError) as exc:
        sys.exit(f"CREATOR_BUILD FAIL: {exc}")
