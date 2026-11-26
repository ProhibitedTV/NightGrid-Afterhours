"""Report actual joint names and local rest transforms before fitting staff props.

Run from the repository root: python tools/inspect_synaxis_staff_sockets.py
Read only; never changes a model or provenance manifest.
"""
import json
import re
from validate_synaxis_staff import ROOT, ACTORS
from validate_synaxis_suit import read_glb

def compact(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())

def inspect(actor):
    gltf, _ = read_glb(ROOT / f"{actor}.glb")
    nodes = gltf["nodes"]
    joints = gltf["skins"][0]["joints"]
    parents = {child: i for i, node in enumerate(nodes) for child in node.get("children", [])}
    result = {"actor": actor, "joint_count": len(joints), "candidates": []}
    for index in joints:
        node = nodes[index]
        name = node.get("name", "")
        key = compact(name)
        if not any(term in key for term in ("spine", "chest", "clavicle", "collar", "hand", "wrist", "head", "pelvis", "hips")):
            continue
        result["candidates"].append({
            "index": index, "name": name,
            "parent": nodes[parents[index]].get("name", "") if index in parents else None,
            "local_transform": {k: node[k] for k in ("matrix", "translation", "rotation", "scale") if k in node},
        })
    result["clips"] = [a.get("name", "") for a in gltf.get("animations", [])]
    return result

if __name__ == "__main__":
    print(json.dumps([inspect(actor) for actor in ACTORS], indent=2))
