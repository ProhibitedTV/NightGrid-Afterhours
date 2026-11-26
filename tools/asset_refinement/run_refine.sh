#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mountpoint -q /mnt/z || { mkdir -p /mnt/z; mount -t drvfs Z: /mnt/z; }
mountpoint -q /mnt/z
root=/mnt/z/NightGrid-Afterhours/Visual
[[ -d "$root/visual-001/candidates" ]] || { echo "Missing NAS candidate library"; exit 2; }
# Avoid a second installation of CUDA or neural models. Blender is CPU-only here.
command -v blender >/dev/null || { echo "Install Blender in Ubuntu first (sudo apt install blender)"; exit 2; }
exec blender -b -t 2 --python-exit-code 1 --python refine.py -- \
  --input "$root/visual-001" --output "$root/refined-001" "$@"
