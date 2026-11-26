#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
# Preserve the Python 3.11 cache already proven on Anubis.
default_home="$HOME/.local/share/nightgrid-visual-v1"
if [[ -f "$HOME/.local/share/nightgrid-visual-py311/setup-v1.ok" ]]; then
  default_home="$HOME/.local/share/nightgrid-visual-py311"
fi
export ANUBIS_VISUAL_HOME="${ANUBIS_VISUAL_HOME:-$default_home}"
if [[ "${ANUBIS_VISUAL_NAS:-0}" == 1 ]]; then
  mkdir -p /mnt/z
  mountpoint -q /mnt/z || mount -t drvfs Z: /mnt/z
  mountpoint -q /mnt/z
  [[ -d /mnt/z/NightGrid-Afterhours/Visual ]] || { echo "NAS library missing"; exit 2; }
  export ANUBIS_VISUAL_OUT=/mnt/z/NightGrid-Afterhours/Visual/visual-001
fi
python="${ANUBIS_VISUAL_PYTHON:-}"
if [[ -z "$python" ]]; then
  for candidate in "$HOME/.local/share/nightgrid-python/bin/python3" python3.11 python3; do
    if command -v "$candidate" >/dev/null && "$candidate" -c 'import sys; assert sys.version_info[:2] == (3,11)' 2>/dev/null; then
      python="$candidate"
      break
    fi
  done
fi
[[ -n "$python" ]] || { echo "Python 3.11 required; install locally with uv python install 3.11 or set ANUBIS_VISUAL_PYTHON"; exit 2; }
"$python" -c 'import sys; assert sys.version_info[:2] == (3,11), "Python 3.11 required"'

mode="${1:-full}"
if [[ "$mode" == plan || "$mode" == status ]]; then
  exec "$python" tools/visual_studio/batch.py "$@"
fi
mkdir -p "$ANUBIS_VISUAL_HOME"
exec 9>"$ANUBIS_VISUAL_HOME/run.lock"
flock -n 9 || { echo "Another visual studio run is active."; exit 2; }
export HF_HOME="$ANUBIS_VISUAL_HOME/hf"
export U2NET_HOME="$ANUBIS_VISUAL_HOME/rembg"
export PYTHONUNBUFFERED=1
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
mode="${1:-full}"
if [[ "$mode" == plan || "$mode" == pack || "$mode" == status ]]; then
  exec "$python" tools/visual_studio/batch.py "$@"
fi
[[ "$mode" == full || "$mode" == smoke || "$mode" == retry ]] || { echo "Use full, smoke, plan, status, pack or retry"; exit 2; }
command -v python3 >/dev/null
command -v git >/dev/null
command -v nvidia-smi >/dev/null || { echo "WSL NVIDIA CUDA driver not visible"; exit 2; }
nvidia-smi
"$python" -c 'from tools.visual_studio.batch import guard_storage; guard_storage()'
# Separate dependency stacks; use no system-wide installation.
if [[ ! -f "$ANUBIS_VISUAL_HOME/setup-v1.ok" ]]; then
  "$python" -c 'import shutil,os; assert shutil.disk_usage(os.environ["ANUBIS_VISUAL_HOME"]).free >= 25*1024**3, "At least 25 GiB free required for initial setup"'
  for env in image mesh; do
    "$python" -m venv "$ANUBIS_VISUAL_HOME/$env"
    "$ANUBIS_VISUAL_HOME/$env/bin/python" -m pip install --upgrade pip
    "$ANUBIS_VISUAL_HOME/$env/bin/python" -m pip install torch==2.5.1 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cu124
  done
  "$ANUBIS_VISUAL_HOME/image/bin/python" -m pip install diffusers==0.32.2 transformers==4.48.3 accelerate==1.3.0 huggingface-hub==0.28.1 safetensors==0.5.2 Pillow==11.1.0
  "$ANUBIS_VISUAL_HOME/mesh/bin/python" -m pip install numpy==1.26.4 scipy==1.13.1 scikit-image==0.24.0 omegaconf==2.3.0 einops==0.7.0 transformers==4.35.2 tokenizers==0.15.2 trimesh==4.0.5 "rembg[cpu]==2.0.60" onnxruntime==1.20.1 opencv-python-headless==4.11.0.86 huggingface-hub==0.28.1 Pillow==10.4.0 imageio==2.36.1
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
exec "$python" "$ROOT/tools/visual_studio/batch.py" "$@"
