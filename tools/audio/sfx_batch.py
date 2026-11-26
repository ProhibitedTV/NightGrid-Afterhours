#!/usr/bin/env python3
"""One-model-at-a-time Stable Audio SFX worker; provisional playtest intake."""
import argparse
import json
import math
from pathlib import Path
import shutil
import tempfile

import generate_sfx as sfx

OUT = sfx.ROOT / "dist/anubis-batch"
PINS = OUT / "sfx-model-pin.json"
CANDIDATES = sfx.ROOT / "dist/sfx-candidates"
REPO = "stabilityai/stable-audio-3-small-sfx"


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8", newline="\n")
    temp.replace(path)


def metrics(path, spec):
    pcm = sfx.read_pcm(path)
    duration = len(pcm)/sfx.RATE
    minimum = max(0.25, spec["duration"] - (0.5 if spec["loop"] else 0.15))
    if not minimum <= duration <= spec["duration"] + 0.05:
        raise ValueError(f"Unexpected duration {duration:.3f}s")
    peak = max(abs(x) for x in pcm)
    rms = math.sqrt(sum(x*x for x in pcm)/len(pcm))
    if peak > 23200 or peak < 100 or rms < 20:
        raise ValueError("Silence or excessive peak")
    return {"seconds":round(duration,4), "peak":peak, "rms":round(rms,3)}


def verify_candidate(wav, meta, spec, pin):
    record = json.loads(meta.read_text(encoding="utf-8"))
    if (record.get("spec") != spec or record.get("sha256") != sfx.digest(wav)
            or any(record.get("provenance", {}).get(k) != pin[k]
                   for k in ("repo","revision","upstream","steps","cfg_scale"))
            or record.get("metrics") != metrics(wav,spec)
            or record.get("machine_qc_passed") is not True):
        raise ValueError("Candidate manifest, provenance, hash or PCM mismatch")
    return record


def stage_candidate(wav, meta, spec, pin, destination=None):
    """Copy exact verified bytes; never replace an existing different asset."""
    destination = destination or sfx.DEST
    record = verify_candidate(wav,meta,spec,pin)
    record = dict(record, reviewed=False, playtest_accepted=True,
                  rights_checked=True, review_note="Machine QC only; human listening pending")
    destination.mkdir(parents=True, exist_ok=True)
    final = destination / wav.name
    sidecar = destination / meta.name
    if final.exists() and sfx.digest(final) != record["sha256"]:
        raise FileExistsError("Refusing to replace published SFX: " + str(final))
    if sidecar.exists():
        old = json.loads(sidecar.read_text(encoding="utf-8"))
        if old == record and final.exists():
            return
        if old != record:
            raise FileExistsError("Refusing to replace existing SFX metadata: " + str(sidecar))
    if not final.exists():
        with tempfile.TemporaryDirectory(dir=destination) as tmp:
            staged = Path(tmp)/wav.name
            shutil.copyfile(wav, staged)
            if sfx.digest(staged) != record["sha256"]:
                raise ValueError("SFX staging hash mismatch")
            staged.replace(final)
    write_json(sidecar,record)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", choices=("cuda","cpu"), default="cuda")
    parser.add_argument("--upstream-sha", required=True)
    parser.add_argument("--rights-checked", action="store_true")
    args = parser.parse_args()
    if not args.rights_checked:
        parser.error("Stable Audio model and output rights confirmation required")
    import re
    if not re.fullmatch(r"[0-9a-f]{40}", args.upstream_sha):
        parser.error("Exact upstream revision required")
    import importlib.metadata as md
    from huggingface_hub import HfApi, hf_hub_download
    from stable_audio_3 import StableAudioModel
    from stable_audio_3.model_configs import ModelConfig
    import torch
    import torchaudio
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA unavailable; rerun with --sfx-device cpu")
    manifest = json.loads(sfx.MANIFEST.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    CANDIDATES.mkdir(parents=True, exist_ok=True)
    if PINS.exists():
        saved = json.loads(PINS.read_text(encoding="utf-8"))
        if saved.get("repo") != REPO or not re.fullmatch(r"[0-9a-f]{40}", saved.get("revision","")):
            raise ValueError("Invalid SFX model pin")
        revision = saved["revision"]
    else:
        revision = HfApi().model_info(REPO).sha
        if not re.fullmatch(r"[0-9a-f]{40}", revision or ""):
            raise ValueError("Missing model revision")
        write_json(PINS, {"repo":REPO,"revision":revision})
    # Pin the primary diffusion weights/config. Auxiliary encoder acquisition
    # remains upstream-managed, so do not claim full reproducibility.
    original = ModelConfig.resolve
    def resolve(config):
        if config.repo_id != REPO:
            return original(config)
        return tuple(hf_hub_download(repo_id=REPO, filename=name, revision=revision)
                     for name in (config.config_path, config.ckpt_path))
    ModelConfig.resolve = resolve
    pin = {"repo":REPO,"revision":revision,"upstream":args.upstream_sha,"device":args.device,
           "steps":8,"cfg_scale":1.0,"auxiliary_encoder":"upstream-managed; not independently pinned",
           "packages":{name:md.version(name) for name in ("stable-audio-3","torch","torchaudio","transformers")}}
    results = []
    model = None
    engine_blocked = False
    for spec in manifest["assets"]:
        ident = spec["id"]
        wav = CANDIDATES / (ident+".wav")
        meta = CANDIDATES / (ident+".json")
        try:
            final = sfx.DEST / wav.name
            sidecar = sfx.DEST / meta.name
            if final.is_file() and sidecar.is_file():
                existing = verify_candidate(final,sidecar,spec,pin)
                if existing.get("playtest_accepted") is not True or existing.get("rights_checked") is not True:
                    raise ValueError("Existing effect is not a batch playtest asset")
                results.append({"id":ident,"state":"playtest_ready","sha256":sfx.digest(final)})
                write_json(OUT/"sfx-results.json",{"results":results,"total":len(manifest["assets"])})
                print("Verified existing staged SFX:", ident, flush=True)
                continue
            if wav.exists() or meta.exists():
                verify_candidate(wav,meta,spec,pin)
                print("Verified cached SFX:", ident, flush=True)
            else:
                if model is None:
                    # The initial download may require prior gated-model access.
                    # Failure here is systemic; stop rather than retry 37 times.
                    try:
                        model = StableAudioModel.from_pretrained(manifest["model"],device=args.device,
                                                                 model_half=args.device=="cuda")
                    except Exception as exc:
                        engine_blocked = True
                        results.append({"id":ident,"state":"engine blocked","error":str(exc)})
                        write_json(OUT/"sfx-results.json",{"results":results,"total":len(manifest["assets"])})
                        raise
                with tempfile.TemporaryDirectory(dir=CANDIDATES) as tmp:
                    tmp = Path(tmp)
                    raw = tmp / "raw.wav"
                    final = tmp / "prepared.wav"
                    audio = model.generate(prompt=spec["prompt"], duration=spec["duration"],
                                           steps=8,cfg_scale=1.0,seed=spec["seed"],
                                           sample_size=model.model_config["sample_size"])
                    torchaudio.save(str(raw),audio[0].cpu(),model.model.sample_rate)
                    sfx.prepare(raw,final,spec,"ffmpeg")
                    measured = metrics(final,spec)
                    record = {"spec":spec,"model":manifest["model"],"weights":manifest["weights"],
                              "license":manifest["license"],"device":args.device,
                              "sha256":sfx.digest(final),"reviewed":False,
                              "machine_qc_passed":True,"provenance":pin,"metrics":measured}
                    # Commit candidate bytes before metadata; a partial pair
                    # is refused on resume rather than silently overwritten.
                    final.replace(wav)
                    write_json(meta,record)
                print("SFX candidate:", ident, measured, flush=True)
            stage_candidate(wav,meta,spec,pin)
            results.append({"id":ident,"state":"playtest_ready","sha256":sfx.digest(wav)})
        except Exception as exc:
            if engine_blocked:
                raise
            results.append({"id":ident,"state":"failed","error":str(exc)})
            print("SFX failed:",ident,exc,flush=True)
            if args.device == "cuda":
                torch.cuda.empty_cache()
        write_json(OUT/"sfx-results.json",{"results":results,"total":len(manifest["assets"]),
                                          "note":"Provisional playtest assets; no human listening or final release approval"})
    return 0 if all(r["state"]=="playtest_ready" for r in results) else 2


if __name__ == "__main__":
    raise SystemExit(main())
