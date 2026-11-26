#!/usr/bin/env python3
"""Re-evaluate verified, unpublished cached takes without GPU inference."""
import argparse
from pathlib import Path
import anubis
import chapter
import production
import qc
import studio


def recover(specs, manifest, model_fingerprint, base_revision, *, publish=False):
    production.verify_library(specs)
    accepted = []
    remaining = []
    for ident,spec in specs.items():
        if (production.PUBLISHED/ident).exists():
            continue
        char = spec["line"]["character"]
        if not (production.CAST/char).exists():
            remaining.append(ident)
            continue
        cast = production.read_cast(production.CAST/char,char,spec["voice"])
        viable = []
        for folder in sorted((production.TAKES/ident).glob("*")):
            if not folder.is_dir() or not studio.SHA.fullmatch(folder.name):
                continue
            try:
                take = production.verify_take(folder,spec,cast)
                if take["settings"]["revision"] != base_revision:
                    continue
                old = qc.verify_report(folder,spec)
                if old["model_sha256"] != model_fingerprint:
                    continue
                if (folder/"review.json").exists():
                    # Never silently change a prior hash-bound review.
                    production.verify_take(folder,spec,cast,approved=True)
                    if old["metrics"]["flags"]:
                        continue
                    report = old
                else:
                    report = qc.create_report(folder,spec,old["transcript"],old["model_sha256"],old["packages"])
                if report["metrics"]["flags"]:
                    continue
                acoustic = report["metrics"]["acoustic"]
                viable.append((acoustic["leading_quiet_seconds"],acoustic["trailing_quiet_seconds"],folder.name,folder,report))
            except (OSError,ValueError,KeyError,TypeError):
                continue
        if not viable:
            remaining.append(ident)
            continue
        _,_,_,folder,report=min(viable,key=lambda row:row[:3])
        print("Recoverable:",ident,folder.name,flush=True)
        if publish:
            if not (folder/"review.json").exists():
                temp=folder/"qc.json.tmp"
                studio.write_json(temp,report)
                temp.replace(folder/"qc.json")
                anubis.run("production.py","approve","--manifest",manifest,"--id",ident,"--take",folder.name,
                           "--reviewer","Anubis automated playtest QC",
                           "--notes","Verified cached ASR and PCM under versioned QC; human listening review pending.",
                           "--rights-checked")
            production.publish(folder,production.PUBLISHED/ident,spec,cast)
        accepted.append(ident)
    count=production.verify_library(specs)
    print("Recoverable:",len(accepted),"Published:",count,"/",len(specs),"Still flagged or missing:",remaining,flush=True)
    return accepted,remaining


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rights-checked",action="store_true",help="Publish technically accepted provisional takes; otherwise report only")
    parser.add_argument("--manifest",type=Path,default=chapter.CATALOG)
    args=parser.parse_args()
    specs=chapter.validate_catalog(args.manifest,studio.ROOT/"scripts/opening_story.gd")
    pins=anubis.load_pins()
    from huggingface_hub import snapshot_download
    model=Path(snapshot_download(pins["asr"]["repo"],revision=pins["asr"]["revision"],local_files_only=True))
    recover(specs,args.manifest,qc.model_digest(model),pins["base"]["revision"],publish=args.rights_checked)


if __name__=="__main__":
    main()
