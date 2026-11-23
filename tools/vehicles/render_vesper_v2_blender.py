#!/usr/bin/env python3
"""Render labeled offline Vesper study frames from an existing editable Blender source.

A separate process keeps EGL/driver failures away from geometry generation.
Output is Blender Workbench inspection imagery, not Godot gameplay.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
# Blender's --python invocation doesn't include the script directory on sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from author_vesper_v2_blender import cameras_and_preview, collection, render_views
import author_vesper_v2_blender as author


def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",required=True,type=Path)
    parser.add_argument("--output-dir",required=True,type=Path)
    opts=parser.parse_args(args)
    source=opts.input.resolve()
    output_dir=opts.output_dir.resolve()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    author.MATERIALS={m.name:m for m in bpy.data.materials}
    for name in ("GAME__LOD0", "GAME__LOD1"):
        bpy.data.collections[name].hide_render=True
    bpy.data.collections["MASTER__DETAIL__NONSHIPPING"].hide_render=False
    preview=collection("OFFLINE_PREVIEW_ONLY")
    camera=cameras_and_preview(preview)
    # Two identical camera passes: material colors and untextured neutral clay.
    # Clay removes paint/color distractions and exposes sculpting, silhouette,
    # normal winding and split-panel highlight defects more directly.
    render_views(camera,output_dir)
    shading=bpy.context.scene.display.shading
    shading.color_type="SINGLE"
    shading.single_color=(0.65,0.67,0.69)
    render_views(camera,output_dir,prefix="clay_")
    path=output_dir/"source.json"
    manifest=json.loads(path.read_text(encoding="utf-8"))
    for img in sorted(output_dir.glob("*.png")):
        manifest["files"][img.name]={
            "sha256":hashlib.sha256(img.read_bytes()).hexdigest(),
            "bytes":img.stat().st_size,
            "capture":"Blender Workbench offline preview, not Godot",
        }
    path.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("Created", len(list(output_dir.glob("*.png"))), "offline Blender review frames")


if __name__=="__main__":
    main()
