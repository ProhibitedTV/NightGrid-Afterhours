#!/usr/bin/env bash
# Separate GPU lane, no model installation or publication.
set -euo pipefail
cd "$(dirname "$0")/../.."
runner="$PWD/tools/audio/nightgrid_music_batch.py"
python=/home/anubis/AI/ACE-Step-1.5/.venv/bin/python
if [[ "${1:-}" == --plan ]]; then
  exec python3 "$runner" "$@"
fi
[[ "$EUID" == 0 ]] || { echo "Run with sudo to coordinate existing Factory locks"; exit 2; }
mountpoint -q /mnt/z || { echo "Mount Windows Z: to /mnt/z first"; exit 2; }
[[ -x "$python" ]] || { echo "Existing ACE-Step environment missing"; exit 2; }
visual_home="${ANUBIS_VISUAL_HOME:-/root/.local/share/nightgrid-visual-py311}"
[[ -d "$visual_home" ]] || { echo "Existing visual Factory home required"; exit 2; }
exec 8>>"$visual_home/factory.lock"
flock -n 8 || { echo "Factory busy"; exit 2; }
exec 9>>"$visual_home/run.lock"
flock -n 9 || { echo "Visual generation busy"; exit 2; }
[[ ! -e /mnt/z/NightGrid-Afterhours/Audio/factory-001/.audio.lock ]] || { echo "Audio stage busy or stale lock; inspect"; exit 2; }
runuser -u anubis -- "$python" "$runner" "$@"
