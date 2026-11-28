#!/usr/bin/env bash
# Run from the existing botanical worktree; no clone or package installation.
set -euo pipefail
cd "$(dirname "$0")/../.."
batch=coastal-001
godot=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --batch) batch="$2"; shift 2 ;;
    --godot) godot="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 2 ;;
  esac
done
[[ "$batch" =~ ^coastal-[a-z0-9][a-z0-9-]{0,30}$ ]] || { echo "Invalid batch"; exit 2; }
[[ -f "$godot" && "$godot" == *.exe ]] || { echo "Pass exact native Godot console executable with --godot"; exit 2; }
mountpoint -q /mnt/z || mount -t drvfs Z: /mnt/z
nas=/mnt/z/NightGrid-Afterhours/Visual/Botanical
mkdir -p "$nas"
home="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
[[ -d "$home" ]] || { echo "Existing factory home unavailable"; exit 2; }
exec 8>>"$home/factory.lock"
flock -n 8 || { echo "Factory busy; no concurrent production"; exit 2; }
exec 9>>"$home/run.lock"
flock -n 9 || { echo "Visual factory busy"; exit 2; }
[[ ! -e /mnt/z/NightGrid-Afterhours/Audio/factory-001/.audio.lock ]] || { echo "Audio stage lock exists; inspect"; exit 2; }
export PYTHONPATH="$PWD/tools/asset_refinement${PYTHONPATH:+:$PYTHONPATH}"
python3 -m unittest discover -s tools/asset_refinement -p test_botanical_candidates.py -v
python3 tools/asset_refinement/botanical_candidates.py --out "$nas/$batch" --execute
python3 - "$nas/$batch" <<'PY'
from pathlib import Path
import hashlib, json, shutil, sys, tempfile
source = Path(sys.argv[1])
target = Path("assets/models/nightgrid/botanical")
manifest = json.loads((source/"SOURCE.json").read_text())
def verify(path):
    if json.loads((path/"SOURCE.json").read_text()) != manifest:
        raise ValueError("Manifest mismatch")
    for name, rec in manifest["files"].items():
        f = path/name
        if f.is_symlink() or f.stat().st_size != rec["bytes"] or hashlib.sha256(f.read_bytes()).hexdigest() != rec["sha256"]:
            raise ValueError("Asset mismatch: " + name)
verify(source)
if target.exists():
    verify(target)
else:
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".botanical-stage-", dir=target.parent) as tmp:
        stage=Path(tmp)/"bank"
        shutil.copytree(source,stage)
        verify(stage)
        stage.rename(target)
print("BOTANICAL_STAGE PASS:", len(manifest["files"]), "verified meshes")
PY
logs="$nas/$batch-validation"
mkdir -p "$logs"
project="$(wslpath -w "$PWD")"
"$godot" --headless --path "$project" --import --quit 2>&1 | tee "$logs/import.log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load' "$logs/import.log"; then exit 1; fi
"$godot" --headless --path "$project" --script res://tests/botanical_bank_smoke.gd -- --require-bank 2>&1 | tee "$logs/coverage.log"
grep -q 'BOTANICAL PASS:' "$logs/coverage.log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|BOTANICAL FAIL:' "$logs/coverage.log"; then exit 1; fi
git.exe rev-parse HEAD > "$logs/source-revision.txt"
echo "BOTANICAL PRODUCTION PASS — originals on NAS, verified native assets in current worktree"
echo "Review $logs; no automatic commit or publish."
