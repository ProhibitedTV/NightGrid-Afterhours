#!/usr/bin/env bash
# Operator entry point. Reuse existing installations; no download or inference in setup.
set -euo pipefail
cd "$(dirname "$0")/../.."
mode="${1:-}"
if [[ $# -gt 0 ]]; then shift; fi
[[ "$mode" == setup || "$mode" == run || "$mode" == status ]] || { echo "Use setup, run or status"; exit 2; }
[[ "$EUID" == 0 ]] || { echo "Use the Windows CMD launcher or Ubuntu WSL as root"; exit 2; }
export ANUBIS_VISUAL_HOME="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
export PATH="$ANUBIS_VISUAL_HOME/node24/bin:/root/.local/share/nightgrid-python/bin:/usr/lib/wsl/lib:$PATH"
# Translate a linked worktree registered by Git for Windows for this process.
if [[ -f .git ]]; then
  git_link=$(<.git)
  git_link=${git_link%$'\r'}
  if [[ "$git_link" =~ ^gitdir:\ [A-Za-z]:[/\\] ]]; then
    export GIT_DIR="$(wslpath -u "${git_link#gitdir: }")"
    export GIT_WORK_TREE="$PWD"
    # Match the Git for Windows line-ending policy on this CRLF checkout.
    # Keep the real tracked-dirty guard and leave all repository config alone.
    git_option=${GIT_CONFIG_COUNT:-0}
    export "GIT_CONFIG_KEY_$git_option=core.autocrlf" "GIT_CONFIG_VALUE_$git_option=true"
    export GIT_CONFIG_COUNT=$((git_option + 1))
  fi
fi
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
