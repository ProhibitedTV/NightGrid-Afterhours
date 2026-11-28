"""Offline cache readiness probe. Does not load models or install anything."""
import os
from pathlib import Path
import re
import subprocess

HOME=Path(os.environ.get("ANUBIS_VISUAL_HOME","/root/.local/share/nightgrid-visual-py311"))
SDXL="stabilityai/stable-diffusion-xl-base-1.0"
TRIPO="stabilityai/TripoSR"
SOURCE="107cefdc244c39106fa830359024f6a2f1c78871"

def revision(home,model):
    p=home/(model.replace("/","--")+".revision")
    rev=p.read_text().strip()
    if not re.fullmatch(r"[0-9a-f]{40}",rev):
        raise ValueError("Invalid existing revision: "+model)
    return rev

def check(home=HOME):
    for marker in ("setup-v1.ok","sdxl-ready","triposr-ready"):
        if not (home/marker).is_file():
            raise ValueError("Existing readiness marker missing: "+marker)
    for stage in ("image","mesh"):
        if not (home/stage/"bin/python").is_file() or not (home/(stage+".freeze.txt")).is_file():
            raise ValueError("Existing worker or environment record missing: "+stage)
    if not (home/"rembg/u2net.onnx").is_file():
        raise ValueError("Existing U2Net checkpoint missing")
    actual=subprocess.check_output(["git","-C",str(home/"TripoSR"),"rev-parse","HEAD"],text=True).strip()
    if actual!=SOURCE:raise ValueError("TripoSR checkout revision differs")
    env=dict(os.environ,HF_HOME=str(home/"hf"),U2NET_HOME=str(home/"rembg"),
        HF_HUB_OFFLINE="1",TRANSFORMERS_OFFLINE="1",PIP_NO_INDEX="1")
    def probe(stage,model,files):
        snippet=("import sys; from huggingface_hub import hf_hub_download; "
            "[hf_hub_download(sys.argv[1],f,revision=sys.argv[2],local_files_only=True) for f in sys.argv[3:]]")
        subprocess.run([str(home/stage/"bin/python"),"-c",snippet,model,revision(home,model),*files],
                       env=env,check=True,timeout=60)
    probe("image",SDXL,["model_index.json","unet/config.json","vae/config.json",
        "text_encoder/config.json","text_encoder_2/config.json"])
    probe("mesh",TRIPO,["config.yaml","model.ckpt"])
    subprocess.run([str(home/"mesh/bin/python"),"-c",
        "from huggingface_hub import hf_hub_download; hf_hub_download('facebook/dino-vitb16','config.json',local_files_only=True)"],
        env=env,check=True,timeout=60)
    print("Existing visual worker cache probes passed (configuration and selected weight files; not a complete model-load test).")

if __name__=="__main__":check()
