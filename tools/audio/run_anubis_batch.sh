#!/usr/bin/env bash
# Windows worktree / Linux voice environment. No interactive stdin.
set -euo pipefail
cd "$(dirname "$0")/../.."
PY="$HOME/afterhours-voice/bin/python"
if [[ ! -x "$PY" ]]; then
  echo "Missing batch-001 voice environment: $PY" >&2
  exit 1
fi
mkdir -p dist/anubis-batch
exec 9>"$HOME/.anubis-audio.lock"
flock -n 9 || { echo "Another Anubis audio job is already running." >&2; exit 1; }
export PYTHONUNBUFFERED=1 GIT_TERMINAL_PROMPT=0 HF_HUB_DISABLE_PROGRESS_BARS=1
LOG="dist/anubis-batch/run-$(date -u +%Y%m%dT%H%M%SZ).log"
echo "Anubis log: $LOG"
"$PY" tools/voice/run_batch.py "$@" </dev/null 2>&1 | tee "$LOG"
