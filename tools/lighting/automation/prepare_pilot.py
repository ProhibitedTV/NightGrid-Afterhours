"""Build a tiny isolated Godot editor project from tracked reception inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT=Path(__file__).resolve().parents[3]
SCENE="tools/lighting/synaxis_reception_bake.tscn"
VALIDATOR="tools/lighting/validate_synaxis_reception.gd"

def prepare(out):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents or out.exists():
        raise ValueError("Use a new scratch directory outside checkout")
    source=(ROOT/SCENE).read_text(encoding="utf-8")
    paths=re.findall(r'path="res://([^"]+)"',source)
    if not paths or not any(x.endswith(".lmbake") for x in paths):
        raise ValueError("Pilot scene dependencies changed")
    source=re.sub(r'^\[ext_resource type="LightmapGIData"[^\n]*\]\n','',source,flags=re.M)
    source=re.sub(r'^light_data = ExtResource\("[^"]+"\)\n','',source,flags=re.M)
    out.mkdir(parents=True)
    hashes={}
    for relative in [*paths,VALIDATOR,"tools/lighting/capture_synaxis_reception_bake.gd"]:
        if relative.endswith(".lmbake"): continue
        src=ROOT/relative
        if not src.is_file() or ROOT not in src.resolve().parents:
            raise ValueError("Missing or unsafe dependency "+relative)
        for p in (src,src.with_name(src.name+".import")):
            if p.is_file():
                rel=p.relative_to(ROOT)
                dest=out/rel; dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(p,dest); hashes[str(rel)]=hashlib.sha256(p.read_bytes()).hexdigest()
    scene=out/SCENE; scene.parent.mkdir(parents=True,exist_ok=True)
    scene.write_text(source,encoding="utf-8")
    plugin=out/"addons/nightgrid_bake"; plugin.mkdir(parents=True)
    shutil.copy2(Path(__file__).with_name("pilot_plugin.gd.txt"),plugin/"pilot_plugin.gd")
    (plugin/"plugin.cfg").write_text('[plugin]\nname="NightGrid Bake Pilot"\ndescription="Isolated editor lightmap automation"\nauthor="BitRiver"\nversion="1.0"\nscript="pilot_plugin.gd"\n',encoding="utf-8")
    (out/"project.godot").write_text('config_version=5\n[application]\nconfig/name="NightGrid Isolated Bake Pilot"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/nightgrid_bake/plugin.cfg")\n[rendering]\nrenderer/rendering_method="forward_plus"\n',encoding="utf-8")
    (out/"nightgrid_bake_pilot.marker").write_text("isolated candidate\n",encoding="utf-8")
    (out/"inputs.json").write_text(json.dumps({"scene_sha256":hashlib.sha256((ROOT/SCENE).read_bytes()).hexdigest(),"dependencies":hashes,"unbaked_scene_sha256":hashlib.sha256(scene.read_bytes()).hexdigest()},indent=2)+"\n",encoding="utf-8")
    print(out)

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    prepare(p.parse_args().out)
