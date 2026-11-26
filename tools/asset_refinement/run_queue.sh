#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 ]] || { echo "Pass one WSL path to queue JSON"; exit 2; }
mkdir -p /mnt/z
mountpoint -q /mnt/z || mount -t drvfs Z: /mnt/z
mountpoint -q /mnt/z
root=/mnt/z/NightGrid-Afterhours/Visual
[[ -d "$root" ]] || { echo "NAS library missing"; exit 2; }
python=/root/.local/share/nightgrid-python/bin/python3
[[ -x "$python" ]] || python=python3
exec "$python" "$(dirname "$0")/batch_queue.py" "$1" --root "$root/FactoryQueues"
