#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
export ANUBIS_VISUAL_HOME="${ANUBIS_VISUAL_HOME:-$HOME/.local/share/nightgrid-visual-v1}"
mkdir -p "$ANUBIS_VISUAL_HOME"
exec 9>"$ANUBIS_VISUAL_HOME/run.lock"
flock -n 9 || { echo "Another visual studio run is active."; exit 2; }
export HF_HOME="$ANUBIS_VISUAL_HOME/hf"
export U2NET_HOME="$ANUBIS_VISUAL_HOME/rembg"
export PYTHONUNBUFFERED=1
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
mode="${1:-full}"
if [[ "$mode" == plan || "$mode" == pack || "$mode" == status ]]; then
  exec python3 tools/visual_studio/batch.py "$@"
fi
[[ "$mode" == full || "$mode" == smoke ]] || { echo "Use full, smoke, plan, status or pack"; exit 2; }
command -v python3 >/dev/null
command -v git >/dev/null
command -v nvidia-smi >/dev/null || { echo "WSL NVIDIA CUDA driver not visible"; exit 2; }
nvidia-smi
# Separate dependency stacks; use no system-wide installation.
if [[ ! -f "$ANUBIS_VISUAL_HOME/setup-v1.ok" ]]; then
  for env in image mesh; do
    python3 -m venv "$ANUBIS_VISUAL_HOME/$env"
    "$ANUBIS_VISUAL_HOME/$env/bin/python" -m pip install --upgrade pip
    "$ANUBIS_VISUAL_HOME/$env/bin/python" -m pip install torch==2.5.1 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cu124
  done
  "$ANUBIS_VISUAL_HOME/image/bin/python" -m pip install diffusers==0.32.2 transformers==4.48.3 accelerate==1.3.0 huggingface-hub==0.28.1 safetensors==0.5.2 Pillow==11.1.0
  "$ANUBIS_VISUAL_HOME/mesh/bin/python" -m pip install numpy==1.26.4 scipy==1.13.1 scikit-image==0.24.0 omegaconf==2.3.0 einops==0.7.0 transformers==4.35.0 trimesh==4.0.5 "rembg[cpu]==2.0.60" onnxruntime==1.20.1 huggingface-hub==0.28.1 Pillow==10.4.0 imageio==2.36.1
  if [[ ! -d "$ANUBIS_VISUAL_HOME/TripoSR/.git" ]]; then
    git clone https://github.com/VAST-AI-Research/TripoSR.git "$ANUBIS_VISUAL_HOME/TripoSR"
  fi
  git -C "$ANUBIS_VISUAL_HOME/TripoSR" checkout --detach 107cefdc244c39106fa830359024f6a2f1c78871
  for env in image mesh; do
    "$ANUBIS_VISUAL_HOME/$env/bin/python" -m pip freeze > "$ANUBIS_VISUAL_HOME/$env.freeze.txt"
    "$ANUBIS_VISUAL_HOME/$env/bin/python" -c 'import torch; assert torch.cuda.is_available(), "CUDA unavailable"; print(torch.cuda.get_device_name(0))'
  done
  touch "$ANUBIS_VISUAL_HOME/setup-v1.ok"
fi
if [[ $# == 0 ]]; then set -- full; fi
exec python3 "$ROOT/tools/visual_studio/batch.py" "$@"
