#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"
mode="${1:-full}"
[[ "$mode" == full || "$mode" == existing || "$mode" == smoke ]] || { echo "Use full, existing, or smoke"; exit 2; }
if [[ $# -gt 0 ]]; then shift; fi
export PATH="/root/.local/share/nightgrid-python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/wsl/lib"
export ANUBIS_VISUAL_HOME="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
mkdir -p "$ANUBIS_VISUAL_HOME"
exec 8>"$ANUBIS_VISUAL_HOME/factory.lock"
flock -n 8 || { echo "Factory already running"; exit 2; }
mkdir -p /mnt/z
mountpoint -q /mnt/z || mount -t drvfs Z: /mnt/z
mountpoint /mnt/z
root=/mnt/z/NightGrid-Afterhours/Visual
export ANUBIS_VISUAL_OUT="$root/visual-001"
[[ -d "$root" ]] || { echo "NAS library missing"; exit 2; }
df -h /mnt/c /mnt/z
python3 -c 'import shutil; assert shutil.disk_usage("/mnt/c").free >= 25*1024**3, "Windows SSD reserve: 25 GiB"; assert shutil.disk_usage("/mnt/z").free >= 10*1024**3, "NAS reserve: 10 GiB"'
command -v blender >/dev/null || { echo "Install Blender and python3-numpy in Ubuntu first"; exit 2; }
if [[ "$mode" == full ]]; then
  generation="${ANUBIS_GENERATION_REPO:-$(dirname "$repo")/NightGrid-Visual}"
  [[ -f "$generation/tools/visual_studio/batch.py" ]] || { echo "Missing generation checkout: $generation"; exit 2; }
  (cd "$generation/tools/visual_studio"; python3 -c 'import os,batch; from pathlib import Path; assert batch.OUT.resolve() == Path(os.environ["ANUBIS_VISUAL_OUT"]).resolve(), "Generation checkout lacks NAS output override"')
  (cd "$generation"; bash tools/visual_studio/run_anubis_visual.sh full)
fi
exec 9>"$ANUBIS_VISUAL_HOME/run.lock"
flock -n 9 || { echo "Generation still running; retry after it finishes"; exit 2; }
extra=()
size=1024
if [[ "$mode" == smoke ]]; then extra=(--limit 1); size=128; fi
bash tools/asset_refinement/run_refine.sh --bake-size "$size" "${extra[@]}" "$@"
material_python="$ANUBIS_VISUAL_HOME/mesh/bin/python"
[[ -x "$material_python" ]] || { echo "Existing mesh Python environment required for materials"; exit 2; }
"$material_python" tools/asset_refinement/materials.py --raw "$ANUBIS_VISUAL_OUT" --output "$root/Materials/material-001" --size "$size" "${extra[@]}"
python3 tools/asset_refinement/review_queue.py --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --size "$size" --output "$root/refined-001/review-$size.json"
if [[ -n "${ANUBIS_GODOT:-}" ]]; then
  python3 tools/asset_refinement/godot_gate.py --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --size "$size" --godot "$ANUBIS_GODOT" --output "$root/refined-001/godot-$size.json"
else
  echo "Godot import gate pending: set ANUBIS_GODOT to an absolute Linux Godot 4.7.2 executable."
fi
if [[ "${ANUBIS_PREVIEWS:-0}" == 1 ]]; then
  preview_size=256
  samples=8
  if [[ "$mode" == smoke ]]; then preview_size=128; samples=4; fi
  if [[ "$(command -v blender)" == /usr/bin/blender ]]; then
    export PYTHONPATH=/usr/lib/python3/dist-packages
  fi
  blender -b -t 2 --python-use-system-env --python-exit-code 1 --python tools/asset_refinement/previews.py -- --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --output "$root/Previews" --bake-size "$size" --size "$preview_size" --samples "$samples" "${extra[@]}"
  env -u PYTHONPATH "$material_python" tools/asset_refinement/contact_sheet.py --raw "$ANUBIS_VISUAL_OUT" --previews "$root/Previews" --size "$size"
fi
echo "Factory output is on the NAS. Review queue is not approval or a Git commit."
