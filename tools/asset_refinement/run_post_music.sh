#!/usr/bin/env bash
# Candidate-only, one job at a time, using the existing Anubis checkout.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"
batch="postmusic-001"
mode=plan
godot=""
lane=all
while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) mode=execute; shift ;;
    --batch) batch="$2"; shift 2 ;;
    --godot) godot="$2"; shift 2 ;;
    --lane) lane="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 2 ;;
  esac
done
[[ "$batch" =~ ^postmusic-[a-z0-9][a-z0-9-]{0,30}$ ]] || { echo "Invalid batch name"; exit 2; }
[[ "$lane" =~ ^(all|buildings|characters|lighting)$ ]] || { echo "Invalid lane"; exit 2; }
root=/mnt/z/NightGrid-Afterhours
build="$root/Visual/Architecture/$batch"
cast="$root/Characters/$batch"
lighting="$root/Visual/Lighting/$batch"
if [[ "$mode" == plan ]]; then
  python3 tools/asset_refinement/building_candidates.py --out "$build"
  python3 tools/asset_refinement/character_candidates.py --batch all --out "$cast"
  echo "Lighting pilot: $lighting (requires explicit Windows Godot 4.7.2 console exe with --godot)"
  exit
fi
[[ "$EUID" == 0 ]] || { echo "Use existing root WSL terminal"; exit 2; }
mountpoint -q /mnt/z && [[ -d "$root/Visual" && -d "$root/Characters" ]] || { echo "NAS unavailable; mount Z: first"; exit 2; }
export PATH="/usr/lib/wsl/lib:$PATH"
visual_home="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
[[ -d "$visual_home" ]] || { echo "Existing factory home required"; exit 2; }
exec 8>>"$visual_home/factory.lock"
flock -n 8 || { echo "Music/visual factory busy: do not start another job"; exit 2; }
exec 9>>"$visual_home/run.lock"
flock -n 9 || { echo "Visual generation busy"; exit 2; }
[[ ! -e "$root/Audio/factory-001/.audio.lock" ]] || { echo "Audio stage lock exists; inspect"; exit 2; }
guard="$repo/tools/asset_refinement/resource_guard.py"
logs="$visual_home/guard-logs"
mkdir -p "$logs"
guarded() {
  local label="$1"; shift
  python3 "$guard" --log "$logs/$batch-$label-$(date -u +%Y%m%dT%H%M%S)-$$.jsonl" --require-gpu -- "$@"
}
if [[ "$lane" == all || "$lane" == buildings ]]; then
  guarded buildings python3 tools/asset_refinement/building_candidates.py --out "$build" --execute
fi
if [[ "$lane" == all || "$lane" == characters ]]; then
  command -v npx >/dev/null && [[ "$(node --version)" =~ ^v24\. ]] || { echo "Use existing Node 24/npx installation; no automatic install"; exit 2; }
  guarded characters python3 tools/asset_refinement/character_candidates.py --out "$cast" --batch all --resume --execute
fi
if [[ "$lane" == all || "$lane" == lighting ]]; then
  if [[ -z "$godot" ]]; then
    if [[ "$lane" == lighting ]]; then echo "Pass --godot /mnt/c/.../Godot_v4.7.2-stable_win64_console.exe"; exit 2; fi
    echo "Lighting not launched; rerun --lane lighting --godot /mnt/c/.../Godot_v4.7.2-stable_win64_console.exe"
  else
    [[ -f "$godot" && "$godot" == *.exe ]] || { echo "Provide exact Windows Godot console executable in WSL path syntax"; exit 2; }
    # Native PowerShell monitors and terminates its own editor PID on safety failure.
    # Keep the existing WSL factory locks for the duration of this foreground run.
    python3 tools/lighting/automation/prepare_pilot.py --out "$lighting"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$repo/tools/lighting/automation/run_pilot.ps1")" -Godot "$(wslpath -w "$godot")" -Project "$(wslpath -w "$lighting")"
  fi
fi
echo "Candidate directories (not published): $build ; $cast ; $lighting"
