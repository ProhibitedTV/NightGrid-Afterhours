"""Verify the formalwear candidate shares the shipped courier's humanoid rig."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path("assets/models/nightgrid/courier")

def read_glb(path):
    raw = path.read_bytes()
    magic, version, size, json_size, chunk = struct.unpack_from("<4sIIII", raw)
    assert magic == b"glTF" and version == 2 and size == len(raw) and chunk == 0x4E4F534A
    return json.loads(raw[20:20+json_size]), raw

def rig(doc):
    assert len(doc["skins"]) == 1
    nodes = doc["nodes"]
    return [(nodes[i]["name"], nodes[i].get("translation",[0,0,0]),
             nodes[i].get("rotation",[0,0,0,1]),nodes[i].get("scale",[1,1,1]),
             nodes[i].get("matrix")) for i in doc["skins"][0]["joints"]]

if __name__ == "__main__":
    street, _ = read_glb(ROOT/"morrow_courier.glb")
    suit, raw = read_glb(ROOT/"synaxis_suit.glb")
    assert rig(street) == rig(suit), "Formalwear changed the skeleton rest pose or joint order"
    names = [m.get("name","").lower() for m in suit["materials"]]
    for required in ("suit jacket","shirt and tie","suit trousers"):
        assert any(required in n for n in names), (required, names)
    assert not any("backpack" in n or "cargo" in n or "gloves" in n for n in names), names
    assert any("oxford" in n or "shoe" in n for n in names), names
    assert any("skin" in n for n in names), names
    manifest = {"source":"ara3d@0.13.0","source_revision":"9d3b9f9933cbeb9529630a270ffc7fe01bd05511",
                "sha256":hashlib.sha256(raw).hexdigest(),"bytes":len(raw),"joints":len(rig(suit)),
                "materials":names}
    (ROOT/"synaxis_suit_source.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("SYNAXIS_SUIT PASS",manifest)
