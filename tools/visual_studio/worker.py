"""One GPU model per process. Outputs are unapproved raw candidates."""
import gc
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
import types
from batch import HOME, digest, verified, write_json, guard_storage

IMAGE_MODEL = "stabilityai/stable-diffusion-xl-base-1.0"
MESH_MODEL = "stabilityai/TripoSR"
SOURCE = "107cefdc244c39106fa830359024f6a2f1c78871"

def revision(model):
    from huggingface_hub import HfApi
    path = HOME / (model.replace("/", "--") + ".revision")
    if path.exists():
        return path.read_text().strip()
    sha = HfApi().model_info(model).sha
    if not sha or len(sha) != 40:
        raise RuntimeError("Unable to lock model revision")
    path.write_text(sha + "\n")
    return sha

def image_backend():
    import torch
    from diffusers import StableDiffusionXLPipeline
    sha = revision(IMAGE_MODEL)
    ready = HOME / "sdxl-ready"
    pipe = StableDiffusionXLPipeline.from_pretrained(
        IMAGE_MODEL, revision=sha, variant="fp16", torch_dtype=torch.float16,
        use_safetensors=True, local_files_only=ready.exists())
    ready.touch()
    pipe.enable_model_cpu_offload()
    pipe.enable_vae_slicing()
    def generate(job, folder):
        if job["kind"] == "prop":
            prompt = ("Photoreal industrial product catalog photograph of a single original "
                + job["subject"] + ", believable contemporary near-future Morrow Bay design, "
                "functional engineering, physically plausible detail, entire object centered, "
                "three quarter view, isolated on uniform neutral gray studio backdrop, diffuse light, no shadows on background, no lettering")
        else:
            prompt = ("Photoreal flat orthographic material reference of " + job["subject"] +
                ", uniform diffuse illumination, surface fills entire square, realistic fine detail, no perspective, no objects, no lettering, no directional shadows")
        image = pipe(prompt, negative_prompt="cartoon, illustration, logo, watermark, text, multiple objects, cropped, dramatic shadows, blurry, deformed",
                     width=768, height=768, num_inference_steps=28, guidance_scale=6.5,
                     generator=torch.Generator(device="cpu").manual_seed(job["seed"])).images[0]
        tmp = folder / "concept.tmp.png"
        image.save(tmp)
        tmp.replace(folder / "concept.png")
        return {"model":IMAGE_MODEL,"revision":sha,"license":"CreativeML Open RAIL++-M; review use restrictions","prompt":prompt,"size":768,"steps":28,"guidance":6.5}
    return generate

def mesh_backend():
    import numpy as np
    import torch
    from huggingface_hub import hf_hub_download, snapshot_download
    from skimage.measure import marching_cubes
    # Upstream torchmcubes is a compiled extension requiring a CUDA toolkit.
    # Explicit CPU adapter returns the same ZYX coordinates expected by TSR's
    # subsequent axis reversal. GPU remains in use for neural reconstruction.
    adapter = types.ModuleType("torchmcubes")
    def mc(volume, level):
        vertices, faces, _, _ = marching_cubes(volume.detach().cpu().numpy(), level=level)
        return torch.from_numpy(vertices[:, ::-1].copy()), torch.from_numpy(faces.copy()).long()
    adapter.marching_cubes = mc
    sys.modules["torchmcubes"] = adapter
    upstream = HOME / "TripoSR"
    actual = subprocess.check_output(["git","-C",str(upstream),"rev-parse","HEAD"],text=True).strip()
    if actual != SOURCE:
        raise RuntimeError("TripoSR source revision mismatch")
    sys.path.insert(0,str(upstream))
    from tsr.system import TSR
    from tsr.utils import remove_background, resize_foreground
    from PIL import Image
    import rembg
    sha = revision(MESH_MODEL)
    ready = HOME / "triposr-ready"
    snapshot = snapshot_download(MESH_MODEL, revision=sha, allow_patterns=["config.yaml","model.ckpt"], local_files_only=ready.exists())
    # Upstream tokenizer requests the DINO configuration by default ref.
    dino = hf_hub_download("facebook/dino-vitb16","config.json",local_files_only=ready.exists())
    session = rembg.new_session("u2net", providers=["CPUExecutionProvider"])
    mask_weights = Path(os.environ["U2NET_HOME"]) / "u2net.onnx"
    if not mask_weights.is_file():
        raise RuntimeError("Missing segmentation weights")
    model = TSR.from_pretrained(snapshot, config_name="config.yaml", weight_name="model.ckpt")
    model.renderer.set_chunk_size(8192)
    model.to("cuda:0").eval()
    ready.touch()
    def generate(job, folder):
        image = remove_background(Image.open(folder / "concept.png").convert("RGB"),session)
        image = resize_foreground(image,0.85)
        pixels = np.array(image).astype(np.float32)/255
        pixels = pixels[:,:,:3]*pixels[:,:,3:4]+0.5*(1-pixels[:,:,3:4])
        rgb = Image.fromarray((pixels*255).astype(np.uint8))
        with torch.no_grad():
            codes = model([rgb], device="cuda:0")
            mesh = model.extract_mesh(codes, True, resolution=192)[0]
        if len(mesh.faces)==0 or not np.isfinite(mesh.vertices).all():
            raise RuntimeError("Empty or nonfinite mesh")
        mesh.fix_normals()
        tmp = folder / "mesh.tmp.glb"
        mesh.export(tmp, file_type="glb")
        if tmp.stat().st_size < 100:
            raise RuntimeError("Invalid GLB")
        tmp.replace(folder / "mesh.glb")
        return {"model":MESH_MODEL,"revision":sha,"source_commit":SOURCE,"license":"MIT; review ancillary models and outputs","dino_config_sha256":digest(Path(dino)),"rembg_u2net_sha256":digest(mask_weights),"resolution":192,"marching_cubes":"scikit-image CPU adapter","vertices":len(mesh.vertices),"triangles":len(mesh.faces),"watertight":bool(mesh.is_watertight),"input_sha256":digest(folder/"concept.png"),"vertex_color":True,"scale":"unresolved","pbr":"not generated"}
    return generate

def main():
    stage, plan, output = sys.argv[1:]
    output = Path(output)
    jobs = json.loads(Path(plan).read_text())
    import torch
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA required")
    filename = "concept.png" if stage=="image" else "mesh.glb"
    meta_name = stage+".json"
    selected = []
    for job in jobs:
        folder = output/"candidates"/job["key"]
        if stage=="mesh" and (job["kind"]!="prop" or not verified(folder/"concept.png",folder/"image.json",job)):
            continue
        if verified(folder/filename,folder/meta_name,job):
            if stage=="image" or json.loads((folder/meta_name).read_text()).get("input_sha256")==digest(folder/"concept.png"):
                continue
        selected.append(job)
    if not selected:
        print(stage+": all eligible candidates cached")
        return 0
    guard_storage(output)
    generate = image_backend() if stage=="image" else mesh_backend()
    failures = 0
    for index,job in enumerate(selected,1):
        guard_storage(output)
        folder=output/"candidates"/job["key"]
        folder.mkdir(parents=True,exist_ok=True)
        print(f"{stage} {index}/{len(selected)}: {job['key']}",flush=True)
        started=time.monotonic()
        try:
            torch.cuda.reset_peak_memory_stats()
            info=generate(job,folder)
            write_json(folder/meta_name,dict(info,job=job,sha256=digest(folder/filename),status="unapproved",seconds=round(time.monotonic()-started,2),peak_allocated_bytes=torch.cuda.max_memory_allocated(),torch=torch.__version__,device=torch.cuda.get_device_name(0),environment_freeze_sha256=digest(HOME/(stage+".freeze.txt"))))
        except Exception:
            failures+=1
            with (output/(stage+"-errors.log")).open("a",encoding="utf-8") as f:
                f.write(job["key"]+"\n"+traceback.format_exc()+"\n")
            traceback.print_exc()
        finally:
            gc.collect()
            torch.cuda.empty_cache()
    return int(bool(failures))

if __name__=="__main__":
    sys.exit(main())
