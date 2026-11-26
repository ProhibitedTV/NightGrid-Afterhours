#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"
mode="${1:-full}"
[[ "$mode" == full || "$mode" == existing || "$mode" == smoke || "$mode" == status ]] || { echo "Use full, existing, smoke, or status"; exit 2; }
if [[ $# -gt 0 ]]; then shift; fi
export PATH="/root/.local/share/nightgrid-python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/wsl/lib"
export ANUBIS_VISUAL_HOME="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
mkdir -p /mnt/z
mountpoint -q /mnt/z || mount -t drvfs Z: /mnt/z
mountpoint /mnt/z
root=/mnt/z/NightGrid-Afterhours/Visual
export ANUBIS_VISUAL_OUT="$root/visual-001"
[[ -d "$root" ]] || { echo "NAS library missing"; exit 2; }
ledger="$repo/tools/asset_refinement/factory_ledger.py"
runs="$root/FactoryRuns"
if [[ "$mode" == status ]]; then
  python3 "$ledger" status --root "$runs"
  exit
fi
mkdir -p "$ANUBIS_VISUAL_HOME"
exec 8>"$ANUBIS_VISUAL_HOME/factory.lock"
flock -n 8 || { echo "Factory already running"; exit 2; }
run_dir="$(python3 "$ledger" start --root "$runs" --mode "$mode")"
finish() {
  local rc=$?
  trap - EXIT
  python3 "$ledger" finish --run "$run_dir" --code "$rc" || true
  exit "$rc"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
stage() {
  local name="$1"
  shift
  mountpoint -q /mnt/z || { echo "NAS mount lost"; return 2; }
  python3 "$ledger" begin --run "$run_dir" --stage "$name"
  local -a result
  set +e
  "$@" 2>&1 | tee "$run_dir/$name.log"
  result=("${PIPESTATUS[@]}")
  set -e
  local rc="${result[0]}"
  if [[ "${result[1]}" != 0 && "$rc" == 0 ]]; then rc=74; fi
  python3 "$ledger" end --run "$run_dir" --stage "$name" --code "$rc"
  return "$rc"
}
skip() { python3 "$ledger" skip --run "$run_dir" --stage "$1" --reason "$2"; }
echo "Factory run: $run_dir"
df -h /mnt/c /mnt/z
python3 -c 'import shutil; assert shutil.disk_usage("/mnt/c").free >= 25*1024**3, "Windows SSD reserve: 25 GiB"; assert shutil.disk_usage("/mnt/z").free >= 10*1024**3, "NAS reserve: 10 GiB"'
command -v blender >/dev/null || { echo "Install Blender and python3-numpy in Ubuntu first"; exit 2; }
if [[ "$mode" == full ]]; then
  generation="${ANUBIS_GENERATION_REPO:-$(dirname "$repo")/NightGrid-Visual}"
  [[ -f "$generation/tools/visual_studio/batch.py" ]] || { echo "Missing generation checkout: $generation"; exit 2; }
  (cd "$generation/tools/visual_studio"; python3 -c 'import os,batch; from pathlib import Path; assert batch.OUT.resolve() == Path(os.environ["ANUBIS_VISUAL_OUT"]).resolve(), "Generation checkout lacks NAS output override"')
  stage generation bash -c 'set -e; cd "$1"; bash tools/visual_studio/run_anubis_visual.sh full' _ "$generation"
else
  skip generation "existing/smoke mode"
fi
exec 9>"$ANUBIS_VISUAL_HOME/run.lock"
flock -n 9 || { echo "Generation still running; retry after it finishes"; exit 2; }
extra=()
size=1024
if [[ "$mode" == smoke ]]; then extra=(--limit 1); size=128; fi
normal_args=()
if [[ "${ANUBIS_PROJECT_NORMALS:-0}" == 1 ]]; then normal_args=(--project-normals); fi
if [[ "${ANUBIS_BAKE_AO:-0}" == 1 ]]; then normal_args+=(--bake-ao); fi
stage refinement bash tools/asset_refinement/run_refine.sh --bake-size "$size" "${normal_args[@]}" "${extra[@]}" "$@"
material_python="$ANUBIS_VISUAL_HOME/mesh/bin/python"
[[ -x "$material_python" ]] || { echo "Existing mesh Python environment required for materials"; exit 2; }
stage materials "$material_python" tools/asset_refinement/materials.py --raw "$ANUBIS_VISUAL_OUT" --output "$root/Materials/material-001" --size "$size" "${extra[@]}"
stage review python3 tools/asset_refinement/review_queue.py --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --size "$size" --output "$root/refined-001/review-$size.json"
stage budgets python3 tools/asset_refinement/budgets.py --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --size "$size" --output "$root/refined-001/budgets-$size.json"
if [[ -n "${ANUBIS_GODOT:-}" ]]; then
  stage godot python3 tools/asset_refinement/godot_gate.py --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --size "$size" --godot "$ANUBIS_GODOT" --output "$root/refined-001/godot-$size.json"
else
  skip godot "no configured Godot executable"
  echo "Godot import gate pending: set ANUBIS_GODOT to an absolute Linux Godot 4.7.2 executable."
fi
if [[ "${ANUBIS_PREVIEWS:-0}" == 1 ]]; then
  preview_size=256
  samples=8
  if [[ "$mode" == smoke ]]; then preview_size=128; samples=4; fi
  if [[ "$(command -v blender)" == /usr/bin/blender ]]; then
    export PYTHONPATH=/usr/lib/python3/dist-packages
  fi
  stage previews blender -b -t 2 --python-use-system-env --python-exit-code 1 --python tools/asset_refinement/previews.py -- --raw "$ANUBIS_VISUAL_OUT" --refined "$root/refined-001" --output "$root/Previews" --bake-size "$size" --size "$preview_size" --samples "$samples" "${extra[@]}"
  stage contact-sheets env -u PYTHONPATH "$material_python" tools/asset_refinement/contact_sheet.py --raw "$ANUBIS_VISUAL_OUT" --previews "$root/Previews" --size "$size"
else
  skip previews "disabled"
  skip contact-sheets "previews disabled"
fi
stage duplicates env -u PYTHONPATH "$material_python" tools/asset_refinement/duplicates.py --raw "$ANUBIS_VISUAL_OUT" --output "$root/refined-001/duplicate-concepts.json"
if [[ -n "${ANUBIS_AUDIO_PYTHON:-}" ]]; then
  audio_args=()
  if [[ -n "${ANUBIS_SFX_CLI:-}" ]]; then audio_args=(--sfx-cli "$ANUBIS_SFX_CLI"); fi
  if [[ "$mode" == smoke ]]; then
    skip audio "visual smoke mode"
  else
    stage audio python3 tools/asset_refinement/audio_stage.py --checkout "${ANUBIS_AUDIO_REPO:-$repo}" --python "$ANUBIS_AUDIO_PYTHON" --output /mnt/z/NightGrid-Afterhours/Audio/factory-001 --seed "${ANUBIS_AUDIO_SEED:-308}" --sfx-device "${ANUBIS_SFX_DEVICE:-cpu}" "${audio_args[@]}"
  fi
else
  skip audio "no configured voice Python"
  echo "Audio stage pending: set ANUBIS_AUDIO_PYTHON to existing voice venv executable."
fi
echo "Factory output is on the NAS. Review queue is not approval or a Git commit."
