#!/usr/bin/env bash
# Operator entry point. Reuse existing installations; no download or inference in setup.
set -euo pipefail
cd "$(dirname "$0")/../.."
mode="${1:-}"
if [[ $# -gt 0 ]]; then shift; fi
[[ "$mode" == setup || "$mode" == run || "$mode" == status ]] || { echo "Use setup, run or status"; exit 2; }
[[ "$EUID" == 0 ]] || { echo "Use the Windows CMD launcher or Ubuntu WSL as root"; exit 2; }
export PATH="/root/.local/share/nightgrid-python/bin:/usr/lib/wsl/lib:$PATH"
export ANUBIS_VISUAL_HOME="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 PIP_NO_INDEX=1 NPM_CONFIG_OFFLINE=true
if [[ "$mode" == setup ]]; then
  mkdir -p /mnt/z
  mountpoint -q /mnt/z || mount -t drvfs Z: /mnt/z -o "uid=$(id -u anubis),gid=$(id -g anubis)"
  mountpoint -q /mnt/z || { echo "Existing mapped Windows Z: is unavailable"; exit 2; }
  [[ -d "$ANUBIS_VISUAL_HOME" ]] || { echo "Existing Factory environment not found; no install attempted"; exit 2; }
  exec 7>>"$ANUBIS_VISUAL_HOME/production-dispatch.lock"
  flock -n 7 || { echo "Production already active; use status"; exit 2; }
  exec 8>>"$ANUBIS_VISUAL_HOME/factory.lock"
  flock -n 8 || { echo "Factory active; use status"; exit 2; }
  exec 9>>"$ANUBIS_VISUAL_HOME/run.lock"
  flock -n 9 || { echo "Visual worker active; use status"; exit 2; }
  python3 tools/asset_refinement/run_production.py --check "$@"
  python3 tools/asset_refinement/check_worker_cache.py
  echo "SETUP READY: existing environment and cache probes passed. Native end-to-end production still unverified."
elif [[ "$mode" == run ]]; then
  exec python3 tools/asset_refinement/run_production.py --execute "$@"
else
  exec python3 tools/asset_refinement/run_production.py --status "$@"
fi
