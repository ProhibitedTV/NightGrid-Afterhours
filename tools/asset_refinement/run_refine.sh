#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mountpoint -q /mnt/z || { mkdir -p /mnt/z; mount -t drvfs Z: /mnt/z; }
mountpoint -q /mnt/z
root=/mnt/z/NightGrid-Afterhours/Visual
input="${ANUBIS_VISUAL_OUT:-$root/visual-001}"
output="${ANUBIS_REFINED_OUT:-$root/refined-001}"
[[ -d "$input/candidates" ]] || { echo "Missing NAS candidate library"; exit 2; }
# Avoid a second installation of CUDA or neural models. Blender is CPU-only here.
command -v blender >/dev/null || { echo "Install Blender in Ubuntu first (sudo apt install blender python3-numpy)"; exit 2; }
if [[ $(command -v blender) == /usr/bin/blender ]]; then
  export PYTHONPATH=/usr/lib/python3/dist-packages
fi
exec blender -b -t 2 --python-use-system-env --python-exit-code 1 --python refine.py -- \
  --input "$input" --output "$output" "$@"
