#!/usr/bin/env python3
"""Offline chapter coverage and production planning. Never auto-approve."""
import argparse
import json
from pathlib import Path
import re

import studio
import production
import qc

CATALOG = studio.ROOT / "tools/voice/synaxis_chapter.json"
SPEAKERS = {"Jetson Wang":"jetson","Lin Xue":"lin","林雪":"lin","Player":"player",
            "HR":"hr","Dev":"dev","Rina":"rina"}
SCENES = ("CONFERENCE","CALL_MANDARIN","CONFERENCE_END","OFFBOARDING",
          "BREAKROOM_PARTY","BREAKROOM_PHOTO","BREAKROOM_DECLINE")


def source_constants(path):
    return {m[1]:json.loads(m[2]) for m in re.finditer(
        r'^const (\w+) = ("(?:[^"\\]|\\.)*")$',path.read_text(encoding="utf-8"),re.M)}


def validate_catalog(path, source=None):
    catalog = production.load(path)
    specs = studio.read_manifest(path)
    pinned = catalog["source"]
    if not studio.REV.fullmatch(pinned["revision"]) or not studio.REV.fullmatch(pinned["blob_sha"]):
        raise ValueError("Unpinned source snapshot")
    constants = pinned["constants"]
    if set(constants) != set(SCENES) | {"CALL_SUBTITLES"}:
        raise ValueError("Missing or unexpected scene constants")
    if source is not None:
        current = source_constants(source)
        if any(current.get(k) != v for k,v in constants.items()):
            raise ValueError("Mission dialogue changed; reconcile IDs and regenerate catalog")
    expected = {}
    for scene in SCENES:
        chinese = scene == "CALL_MANDARIN"
        sep = "：" if chinese else ": "
        for index,row in enumerate(constants[scene].splitlines()):
            speaker, delim, spoken = row.partition(sep)
            if speaker not in SPEAKERS or not delim:
                if scene == "OFFBOARDING":
                    continue  # written UI, not an utterance
                raise ValueError("Unknown speaker: "+row)
            ident = f"synaxis.{scene.lower()}.{index+1:02d}"
            line = {"id":ident,"character":SPEAKERS[speaker],"language":"Chinese" if chinese else "English",
                    "text":spoken,"source":{"constant":scene,"row":index}}
            if chinese:
                cap = constants["CALL_SUBTITLES"].splitlines()[index]
                if not cap.startswith("Lin Xue: "):
                    raise ValueError("Caption speaker mismatch")
                line["caption"] = cap[len("Lin Xue: "):]
            expected[ident] = line
    # Runtime GDScript literal is the canonical ambient street source.
    # Use the actual checked-out script for both snapshot and live validation.
    street_path=studio.ROOT/"scripts/street_satire.gd"
    raw=street_path.read_text(encoding="utf-8")
    match=re.search(r"^const LINES = (\[.*?\])\nconst CAST =",raw,re.M|re.S)
    if not match:
        raise ValueError("Missing canonical street dialogue array")
    street=json.loads(match[1])
    for row in street:
        ident=row["id"]
        if ident in expected or not ident.startswith("street."):
            raise ValueError("Duplicate or invalid street line")
        expected[ident]={"id":ident,"character":row["character"],"language":"English","text":row["text"]}
        if "context" in row:
            if row["context"] not in ("incident","urgent","traffic"):
                raise ValueError("Unknown street event context")
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],"context":row["context"]}
        if "exchange" in row:
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],
                                      "exchange":row["exchange"],"turn":row["turn"]}
        if "topic" in row:
            allowed_topics = range(8) if row["character"]=="daddy_stanky" else (0,1)
            if row["topic"] not in allowed_topics or not row["question"].strip():
                raise ValueError("Invalid player conversation topic")
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],
                                      "topic":row["topic"],"question":row["question"]}
        if "stanky_show" in row:
            set_id = row.get("stanky_set","classic")
            limits = {"classic":7,"fight":7,"family":8}
            if row["character"] not in ("daddy_stanky","night_regular") or set_id not in limits or row["stanky_show"] not in range(limits[set_id]):
                raise ValueError("Invalid Stanky show cue")
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],"stanky_show":row["stanky_show"]}
            if "stanky_set" in row:
                expected[ident]["source"]["stanky_set"]=set_id
        if "stanky_rumor" in row:
            if row["character"]!="night_regular" or row["stanky_rumor"] not in (0,1,2):
                raise ValueError("Invalid Stanky fan cue")
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],"stanky_rumor":row["stanky_rumor"]}
        if "quest" in row:
            if row["quest"] not in ("accept","complete") or row["character"]!="robot_romantic":
                raise ValueError("Invalid Cal quest cue")
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],"quest":row["quest"]}
        if "venue_job" in row:
            if row["venue_job"]!="soundcheck_pass" or (row["beat"],row["character"]) not in (("brief","nyx"),("ending","rae")):
                raise ValueError("Invalid music contact cue")
            expected[ident]["source"]={"catalog":"street_satire","character":row["character"],"venue_job":row["venue_job"],"beat":row["beat"]}
    exchanges={}
    for row in street:
        if "exchange" in row:
            exchanges.setdefault(row["exchange"],[]).append(row)
    for name,beats in exchanges.items():
        if ([b["turn"] for b in beats]!=[0,1,2]
                or beats[0]["character"]!=beats[2]["character"]
                or beats[0]["character"]==beats[1]["character"]):
            raise ValueError("Invalid alternating exchange: "+name)
    if set(expected) != set(specs):
        raise ValueError("Catalog coverage differs from spoken script")
    for ident, fields in expected.items():
        if any(specs[ident]["line"].get(k) != v for k,v in fields.items()):
            raise ValueError("Canonical text or speaker mismatch: "+ident)
    return specs


def status(specs, cast_root=production.CAST, take_root=production.TAKES,
           library=production.PUBLISHED):
    # Existing published assets must pass full verification, not just exist.
    production.verify_library(specs, library)
    casts = {}
    rows = []
    for ident,spec in specs.items():
        char = spec["line"]["character"]
        if (library/ident).is_dir():
            rows.append({"id":ident,"character":char,"state":"published","takes":[]})
            continue
        if char not in casts:
            try:
                casts[char] = production.read_cast(cast_root/char,char,spec["voice"])
            except (FileNotFoundError,ValueError,KeyError):
                casts[char] = None
        cast = casts[char]
        if cast is None:
            rows.append({"id":ident,"character":char,"state":"needs_cast","takes":[]})
            continue
        candidates = []
        for folder in sorted((take_root/ident).glob("*")):
            if not folder.is_dir() or not studio.SHA.fullmatch(folder.name):
                continue
            try:
                production.verify_take(folder,spec,cast)
                state = "needs_qc"
                try:
                    report = qc.verify_report(folder,spec)
                    state = "needs_review"
                    if report["metrics"]["flags"]:
                        state = "flagged"
                    try:
                        production.verify_take(folder,spec,cast,approved=True)
                        state = "approved"
                    except (FileNotFoundError,ValueError,KeyError):
                        pass
                except (FileNotFoundError,ValueError,KeyError):
                    pass
                candidates.append({"take":folder.name,"state":state})
            except (FileNotFoundError,ValueError,KeyError):
                candidates.append({"take":folder.name,"state":"invalid"})
        ranking = ["approved","needs_review","flagged","needs_qc"]
        available = {x["state"] for x in candidates}
        state = next((s for s in ranking if s in available),"needs_render")
        rows.append({"id":ident,"character":char,"state":state,"takes":candidates})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["validate","status","require-complete"])
    parser.add_argument("--manifest",type=Path,default=CATALOG)
    parser.add_argument("--source",type=Path,help="Actual checked-out mission script")
    parser.add_argument("--json",action="store_true")
    args=parser.parse_args()
    if args.action=="require-complete" and args.source is None:
        parser.error("Release coverage requires the actual checked-out --source")
    specs=validate_catalog(args.manifest,args.source)
    if args.action=="validate":
        print(f"Validated {len(specs)} spoken lines (source {'checked' if args.source else 'snapshot only'})")
        return
    rows=status(specs)
    counts={}
    for row in rows:
        counts[row["state"]]=counts.get(row["state"],0)+1
    if args.json:
        print(json.dumps({"source_checked":args.source is not None,"counts":counts,"lines":rows},indent=2))
    else:
        for row in rows:
            print(row["state"].ljust(14),row["id"],row["character"])
        print("Coverage:",counts)
    if args.action=="require-complete":
        if counts.get("published",0)!=len(specs):
            raise SystemExit("Required chapter dialogue is incomplete")
        production.verify_release_reviews(specs)


if __name__=="__main__":
    main()
