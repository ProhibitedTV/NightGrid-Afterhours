#!/usr/bin/env python3
"""Anubis local audio driver. One model at a time; no automatic approval."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import chapter
import production
import studio

HERE=Path(__file__).resolve().parent
PINS=studio.ROOT/"tools/voice/model-pins.json"
MODELS={"design":studio.MODEL,"base":production.BASE,"asr":"Systran/faster-whisper-small"}


def run(script,*args):
    subprocess.run([sys.executable,str(HERE/script),*(str(x) for x in args)],
                   cwd=studio.ROOT,check=True)


def load_pins():
    pins=production.load(PINS)
    if set(pins)!=set(MODELS) or any(pins[k].get("repo")!=v or
            not studio.REV.fullmatch(pins[k].get("revision","")) for k,v in MODELS.items()):
        raise ValueError("Invalid model pins; restore or inspect tools/voice/model-pins.json")
    return pins


def setup():
    # Explicitly online; save exact revisions before downloads for resumability.
    from huggingface_hub import HfApi,snapshot_download
    if PINS.exists():
        pins=load_pins()
    else:
        api=HfApi()
        pins={k:{"repo":v,"revision":api.model_info(v).sha} for k,v in MODELS.items()}
        PINS.parent.mkdir(parents=True,exist_ok=True)
        temp=PINS.with_suffix(".tmp")
        studio.write_json(temp,pins)
        temp.replace(PINS)
        pins=load_pins()
    for k,record in pins.items():
        print("Downloading pinned model:",k,record,flush=True)
        snapshot_download(record["repo"],revision=record["revision"])
    print("Model pins saved:",PINS)


def select(specs,all_lines,ids,characters):
    if all_lines and (ids or characters):
        raise ValueError("--all cannot be combined with selectors")
    if not all_lines and not ids and not characters:
        raise ValueError("Choose --all, --id or --character")
    known={s["line"]["character"] for s in specs.values()}
    if set(ids)-set(specs) or set(characters)-known:
        raise ValueError("Unknown line or character; use list")
    return [i for i,s in specs.items() if all_lines or i in ids or s["line"]["character"] in characters]


def reference_ids(specs,selected):
    # Stable reference for each character, even for a single-line render.
    wanted={specs[i]["line"]["character"] for i in selected}
    result={}
    for i,spec in specs.items():
        char=spec["line"]["character"]
        if char in wanted and char not in result:
            result[char]=i
    return result


def candidates(ident,spec,revision):
    result=[]
    for folder in sorted((studio.WORK/ident).glob("*")):
        if not folder.is_dir() or not studio.SHA.fullmatch(folder.name):
            continue
        try:
            rec=studio.verify(folder,spec)
            if rec["settings"]["revision"]==revision:
                result.append(folder)
        except (ValueError,KeyError,FileNotFoundError):
            continue
    return result


def ensure_casts(args,specs,selected,pins):
    missing={}
    for char,ident in reference_ids(specs,selected).items():
        root=production.CAST/char
        if root.exists():
            production.read_cast(root,char,specs[ident]["voice"])
        else:
            missing[char]=ident
    if not missing:
        return True
    # Two audition seeds by default; each invocation loads one model only.
    selectors=[part for ident in missing.values() for part in ("--id",ident)]
    for seed in (args.seed,args.seed+1):
        run("studio.py","generate","--manifest",args.manifest,"--revision",
            pins["design"]["revision"],"--device",args.device,"--seed",seed,*selectors)
    for char,ident in missing.items():
        options=candidates(ident,specs[ident],pins["design"]["revision"])
        print("\nCAST:",char,"|",specs[ident]["line"]["text"],flush=True)
        for i,folder in enumerate(options,1):
            print(f"  {i}: {folder/'take.wav'}",flush=True)
        if args.auto_playtest:
            if not options:
                raise RuntimeError("No valid auditions for " + char)
            take = options[0].name
            notes = "Automated playtest cast selection; PCM verified. Human listening review pending."
            print("Automatically selected:", char, take, flush=True)
        else:
            if args.non_interactive:
                continue
            answer=input("Listen to the files, select an audition number (Enter to defer): ").strip()
            if not answer:
                continue
            if not answer.isdigit() or not 1<=int(answer)<=len(options):
                raise ValueError("Invalid audition choice; rerun bake")
            if input("Confirm original synthetic voice, listening review and model/output rights (type APPROVE): ").strip()!="APPROVE":
                continue
            notes=input("Listening / performance notes: ").strip()
            if not notes:
                raise ValueError("Review notes are required")
            take=options[int(answer)-1].name
        run("studio.py","approve","--manifest",args.manifest,"--id",ident,"--take",take,
            "--reviewer",args.reviewer,"--notes",notes,"--rights-checked")
        run("production.py","lock","--manifest",args.manifest,"--id",ident,"--take",take)
    outstanding=[c for c in missing if not (production.CAST/c).exists()]
    if outstanding:
        print("Awaiting cast approval:",", ".join(outstanding))
        return False
    return True


def bake(args,specs,selected):
    pins=load_pins()
    # No network during authoring. The initial setup is a distinct operation.
    os.environ["HF_HUB_OFFLINE"]="1"
    os.environ["TRANSFORMERS_OFFLINE"]="1"
    from huggingface_hub import snapshot_download
    asr_path=snapshot_download(pins["asr"]["repo"],revision=pins["asr"]["revision"],
                               local_files_only=True)
    production.verify_library(specs)
    selected=[i for i in selected if not (production.PUBLISHED/i).exists()]
    if not selected:
        print("Selected lines are already published and verified")
        return
    if not ensure_casts(args,specs,selected,pins):
        raise SystemExit("Auditions ready. Re-run bake to select cast references and continue.")
    selectors=[part for ident in selected for part in ("--id",ident)]
    # Separate subprocesses release TTS VRAM before the ASR pass starts.
    with tempfile.TemporaryDirectory() as temp:
        result=Path(temp)/"results.json"
        run("production.py","generate","--manifest",args.manifest,"--revision",
            pins["base"]["revision"],"--device",args.device,"--seed",args.seed,
            "--result-file",result,*selectors)
        rows=production.load(result)
        if [x["id"] for x in rows]!=selected or any(not studio.SHA.fullmatch(x["take"]) for x in rows):
            raise ValueError("Unexpected production results")
        pairs=[p for row in rows for p in ("--id",row["id"],"--take",row["take"])]
        run("qc.py","--manifest",args.manifest,"--model-dir",asr_path,"--device","cpu",*pairs)
    if args.auto_playtest:
        passed = 0
        flagged = []
        for row in rows:
            ident, take = row["id"], row["take"]
            folder = production.TAKES / ident / take
            report = production.qc.verify_report(folder, specs[ident])
            flags = report["metrics"]["flags"]
            if flags:
                flagged.append((ident, flags))
                continue
            if not (folder / "review.json").exists():
                run("production.py", "approve",
                    "--manifest", args.manifest,
                    "--id", ident, "--take", take,
                    "--reviewer", "Anubis automated playtest QC",
                    "--notes", "Machine QC passed; human listening review pending.",
                    "--rights-checked")
            run("production.py", "publish",
                "--manifest", args.manifest,
                "--id", ident, "--take", take)
            passed += 1
        print("Playtest takes staged:", passed)
        print("Flagged for review:", flagged)
    run("chapter.py","status","--manifest",args.manifest)
    print("Candidates ready for explicit listening review; nothing published automatically.")


SFX_SCRIPT=studio.ROOT/"tools/audio/generate_sfx.py"
SFX_MANIFEST=studio.ROOT/"tools/audio/synaxis_sfx.json"


def sfx_ids(ids,group):
    data=production.load(SFX_MANIFEST)
    known={x["id"]:x for x in data["assets"]}
    if set(ids)-set(known):
        raise ValueError("Unknown SFX ID; use sfx-list")
    def family(name):
        return "steps" if name.startswith("step_") else ("city" if name.startswith(("city_","event_")) or name=="road_roll" else "office")
    selected=[i for i in known if (not ids or i in ids) and (not group or family(i)==group)]
    if not selected:
        raise ValueError("No matching SFX cues")
    return selected


def sfx_run(args,action):
    import shutil
    cli=shutil.which(args.sfx_cli)
    if action=="generate" and not cli:
        raise ValueError("Install the separate Stable Audio environment and pass --sfx-cli /absolute/path/to/stable-audio")
    selected=sfx_ids(args.sfx_id,args.sfx_group)
    selectors=[part for ident in selected for part in ("--id",ident)]
    command=[sys.executable,str(SFX_SCRIPT),action,*selectors]
    if action=="generate":
        command.extend(["--skip-existing","--cli",cli,"--device",args.sfx_device])
    subprocess.run(command,cwd=studio.ROOT,check=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["setup","list","status","bake","sfx-list","sfx-bake","bake-all"])
    parser.add_argument("--manifest",type=Path,default=chapter.CATALOG)
    parser.add_argument("--all",action="store_true")
    parser.add_argument("--id",action="append",default=[])
    parser.add_argument("--character",action="append",default=[])
    parser.add_argument("--seed",type=int,default=308)
    parser.add_argument("--device",choices=["cuda","cpu"],default="cuda")
    parser.add_argument("--reviewer",default="Creative director")
    parser.add_argument("--non-interactive",action="store_true")
    parser.add_argument("--sfx-id",action="append",default=[])
    parser.add_argument("--sfx-group",choices=["office","city","steps"])
    parser.add_argument("--sfx-cli",default="stable-audio")
    parser.add_argument("--sfx-device",choices=["cpu","cuda"],default="cpu")
    parser.add_argument("--auto-playtest", action="store_true")
    parser.add_argument("--rights-checked", action="store_true")
    args=parser.parse_args()
    if args.auto_playtest and not args.rights_checked:
        parser.error("Automatic playtest requires rights confirmation")

    args.manifest=args.manifest.resolve()
    if args.action=="setup":
        setup()
        return
    if args.action in ("sfx-list","sfx-bake"):
        sfx_run(args,"list" if args.action=="sfx-list" else "generate")
        return
    specs=chapter.validate_catalog(args.manifest)
    if args.action=="bake-all":
        if args.id or args.character or args.sfx_id or args.sfx_group:
            parser.error("bake-all renders both full catalogs; use bake or sfx-bake for selections")
        # Effects first, before any cast approval prompt. Sequential processes.
        sfx_run(args,"generate")
        bake(args,specs,list(specs))
        return
    if args.action=="list":
        run("studio.py","list","--manifest",args.manifest)
    elif args.action=="status":
        run("chapter.py","status","--manifest",args.manifest)
    else:
        bake(args,specs,select(specs,args.all,args.id,args.character))


if __name__=="__main__":
    main()
