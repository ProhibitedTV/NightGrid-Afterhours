"""CPU studio renders of actual refined GLBs, never gameplay screenshots."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile

from refine import sha, load, write, png_size
from review_queue import scan

VIEWS = {"front-quarter":(1,-2,.9), "rear-quarter":(-1,2,.9), "side":(2,0,.3)}


def render_views(path, dest, size, samples):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH"]
    points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    if not points or not all(math.isfinite(v) for p in points for v in p):
        raise ValueError("Empty/nonfinite render bounds")
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    center = (low+high)*.5
    radius = max((p-center).length for p in points)
    if radius <= 0:
        raise ValueError("Zero extent")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    for layer in scene.view_layers:
        if hasattr(layer.cycles,"use_denoising"):
            layer.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.world = bpy.data.worlds.new("Neutral review studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.22,.22,.22,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .6
    for name, direction, power in [("Key",(2,-3,4),80),("Fill",(-3,-1,2),45),("Rim",(1,3,3),65)]:
        data = bpy.data.lights.new(name,"AREA")
        data.energy = power * radius**2
        data.shape = "DISK"
        data.size = radius*2
        obj = bpy.data.objects.new(name,data)
        scene.collection.objects.link(obj)
        obj.location = center + Vector(direction)*radius
        obj.rotation_euler = (center-obj.location).to_track_quat("-Z","Y").to_euler()
    camera_data = bpy.data.cameras.new("Review")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.35*radius
    camera_data.clip_start = max(radius*.001,1e-6)
    camera_data.clip_end = radius*20
    camera = bpy.data.objects.new("Review",camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    outputs = {}
    import numpy as np
    for name,direction in VIEWS.items():
        camera.location = center + Vector(direction).normalized()*radius*4
        camera.rotation_euler = (center-camera.location).to_track_quat("-Z","Y").to_euler()
        file = dest/(name+".png")
        scene.render.filepath = str(file)
        result = bpy.ops.render.render(write_still=True)
        if "FINISHED" not in result or png_size(file)!=(size,size):
            raise ValueError("Render failed")
        image = bpy.data.images.load(str(file),check_existing=False)
        try:
            pixels = np.empty(size*size*4,dtype=np.float32)
            image.pixels.foreach_get(pixels)
            coverage = float((pixels[3::4]>.5).mean())
            if not np.isfinite(pixels).all() or not .005 < coverage < .95:
                raise ValueError("Empty or clipped preview")
        finally:
            bpy.data.images.remove(image)
        outputs[file.name] = {"sha256":sha(file),"coverage":coverage,"size":[size,size]}
    return outputs


def valid(folder, settings):
    try:
        info=load(folder/"preview.json")
        return (info["settings"]==settings and info["status"]=="review-only"
                and set(info["outputs"])=={v+".png" for v in VIEWS}
                and all(sha(folder/name)==meta["sha256"] and png_size(folder/name)==tuple(meta["size"])
                        for name,meta in info["outputs"].items()))
    except (OSError,ValueError,KeyError,TypeError):
        return False


def run(raw, refined, out, bake_size, size, samples, limit=0):
    import bpy
    if any(a==b or a in b.parents or b in a.parents for a,b in ((raw,out),(refined,out))):
        raise ValueError("Preview output must be separate from source libraries")
    out.mkdir(parents=True,exist_ok=True)
    lock=out/".preview.lock"
    lock.mkdir()
    rows=[]
    failed=attempted=0
    try:
        for row in scan(raw,refined,bake_size):
            for item in row.get("versions",[]):
                if limit and attempted>=limit:
                    break
                key,sig=row["candidate"],item["signature"]
                source=refined/key/sig/"lod0.glb"
                settings={"candidate":key,"refinement":sig,"manifest_sha256":item["manifest_sha256"],
                          "glb_sha256":item["outputs"]["lod0.glb"]["sha256"],
                          "blender":bpy.app.version_string,"script":sha(Path(__file__)),
                          "size":size,"samples":samples}
                version=hashlib.sha256(json.dumps(settings,sort_keys=True).encode()).hexdigest()
                parent=out/key
                final=parent/version
                try:
                    if not valid(final,settings):
                        if final.exists():
                            raise ValueError("Corrupt preview; quarantine manually")
                        attempted+=1
                        if shutil.disk_usage(out).free<5*1024**3:
                            raise RuntimeError("NAS reserve below 5 GiB")
                        parent.mkdir(exist_ok=True)
                        stage=Path(tempfile.mkdtemp(prefix=".stage-",dir=parent))
                        try:
                            if sha(source)!=settings["glb_sha256"]:
                                raise ValueError("Source changed")
                            outputs=render_views(source,stage,size,samples)
                            if sha(source)!=settings["glb_sha256"]:
                                raise ValueError("Source changed")
                            write(stage/"preview.json",{"settings":settings,"outputs":outputs,
                                  "status":"review-only","scope":"Blender studio render, not in-game"})
                            if not valid(stage,settings):
                                raise ValueError("Preview verification failed")
                            stage.rename(final)
                        finally:
                            if stage.exists():
                                shutil.rmtree(stage)
                    rows.append({"candidate":key,"refinement":sig,"preview":version,
                                 "manifest_sha256":sha(final/"preview.json"),"status":"review-only"})
                except Exception as exc:
                    failed+=1
                    rows.append({"candidate":key,"refinement":sig,"status":"failed","error":str(exc)})
                    print("Preview failed",key,exc,file=sys.stderr)
        temp=out/(".review-%d.tmp"%bake_size)
        write(temp,{"schema":1,"scope":"Blender preview only","partial":bool(limit),"rows":rows})
        temp.replace(out/("review-%d.json"%bake_size))
    finally:
        lock.rmdir()
    print("Preview attempted=%d failed=%d"%(attempted,failed),flush=True)
    return int(bool(failed) or not rows)


if __name__=="__main__":
    p=argparse.ArgumentParser()
    for flag in ("raw","refined","output"):
        p.add_argument("--"+flag,required=True,type=Path)
    p.add_argument("--bake-size",type=int,default=1024)
    p.add_argument("--size",type=int,choices=[128,256,512],default=256)
    p.add_argument("--samples",type=int,choices=[4,8,16,32],default=8)
    p.add_argument("--limit",type=int,default=0)
    a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    if a.limit<0:
        p.error("Negative limit")
    if run(a.raw.resolve(),a.refined.resolve(),a.output.resolve(),a.bake_size,a.size,a.samples,a.limit):
        raise RuntimeError("Preview stage incomplete")
