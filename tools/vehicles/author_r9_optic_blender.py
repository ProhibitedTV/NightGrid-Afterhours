#!/usr/bin/env python3
"""Original editable Cinder R9 optical-module pilot, NOT an integrated game asset.

blender --background --python tools/vehicles/author_r9_optic_blender.py -- \
    --output-dir /tmp/nightgrid-r9-optic

Produces a Blender workbench collection, deliberately simplified UV-mapped
game mesh, GLB and SHA-256 manifest. Creator must approve actual R9 fit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

# Blender's --python invocation does not guarantee the recipe directory in sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from bezier_surface import tessellate

try:
    import bpy
except ImportError:
    bpy = None

# One right-side module in local metres. -Z is toward the road ahead.
OUTLINE = [(-0.355, -0.045), (-0.308, 0.090), (-0.195, 0.140),
           (0.065, 0.112), (0.303, 0.038), (0.354, -0.020),
           (0.195, -0.119), (-0.208, -0.119)]
SOCKETS = {
    "SocketHeadlampMount": (0.0, 0.0, 0.090),
    "SocketHeadlampBeam": (-0.070, -0.002, -0.073),
    "SocketIndicator": (0.290, -0.018, -0.069),
}


def _catmull(points, steps):
    """Closed Catmull-Rom interpolation creates a designer-editable contour."""
    out = []
    for i in range(len(points)):
        p0, p1, p2, p3 = [points[(i+j) % len(points)] for j in (-1, 0, 1, 2)]
        for k in range(steps):
            t = k / steps
            def interpolate(axis):
                a,b,c,d = (p[axis] for p in (p0,p1,p2,p3))
                return 0.5 * ((2*b) + (-a+c)*t +
                              (2*a-5*b+4*c-d)*t*t +
                              (-a+3*b-3*c+d)*t*t*t)
            out.append((interpolate(0), interpolate(1)))
    return out


def _material(name, color, metallic=0.0, roughness=0.45,
              alpha=1.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    # glTF requires an explicit transparent surface mode for optical glazing.
    if alpha < 1.0:
        if hasattr(mat, 'surface_render_method'):
            mat.surface_render_method = 'DITHERED'
        elif hasattr(mat, 'blend_method'):
            mat.blend_method = 'BLEND'
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color, alpha)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Alpha'].default_value = alpha
    if 'Coat Weight' in bsdf.inputs and metallic > 0.1:
        bsdf.inputs['Coat Weight'].default_value = 0.24
    if emission is not None:
        key = 'Emission Color' if 'Emission Color' in bsdf.inputs else 'Emission'
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = (*emission, 1)
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = 2.0
    return mat


def _mesh(name, verts, faces, material, collection):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    # Consistent provisional XY UV; production unwrap/normal bake is #231.
    uv = mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        for loop_id in poly.loop_indices:
            v = mesh.vertices[mesh.loops[loop_id].vertex_index].co
            uv.data[loop_id].uv = ((v.x + .40) / .80, (v.y + .20) / .40)
    return obj


def _loft(name, outline, rings, material, collection):
    """Closed annular solid with outer/inner, front/back surfaces."""
    n = len(outline)
    verts = [(x*sx, y*sy, z) for sx,sy,z in rings for x,y in outline]
    faces = []
    for r in range(len(rings)):
        nex = (r+1) % len(rings)
        for i in range(n):
            j=(i+1)%n
            faces.append((r*n+i, r*n+j, nex*n+j, nex*n+i))
    return _mesh(name, verts, faces, material, collection)


def _lens(name, outline, material, collection):
    n = len(outline)
    z_front, z_back = -.066, -.052
    verts = [(x*.88, y*.84, z) for z in (z_front,z_back) for x,y in outline]
    verts += [(0., 0., z_front), (0., 0., z_back)]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+i), (j,n+j,n+i), (2*n,i,j), (2*n+1,n+j,n+i)]
    return _mesh(name,verts,faces,material,collection)


def _reflector(name,outline,material,collection):
    n = len(outline)
    rings = [(0.82,.80,-.045), (0.67,.61,-.014), (0.46,.44,.034),
             (0.19,.18,.093), (0.08,.08,.103)]
    verts=[(x*sx,y*sy,z) for sx,sy,z in rings for x,y in outline]
    verts.append((0,0,.106))
    faces=[]
    for k in range(len(rings)-1):
        for i in range(n):
            j=(i+1)%n
            faces.append((k*n+i,k*n+j,(k+1)*n+j,(k+1)*n+i))
    for i in range(n):
        faces.append(((len(rings)-1)*n+i,(len(rings)-1)*n+(i+1)%n,len(verts)-1))
    return _mesh(name,verts,faces,material,collection)


def _light_guide(name,outline,material,collection):
    """Actual six-sided bent light-guide mesh; no extra realtime light."""
    count=len(outline)
    sample = outline[round(count*.14):round(count*.64)]
    if len(sample)<3:
        sample=outline[:count//2]
    verts=[]
    width=.0047
    for i,(x,y) in enumerate(sample):
        left=sample[max(0,i-1)]
        right=sample[min(len(sample)-1,i+1)]
        dx,dy=right[0]-left[0],right[1]-left[1]
        magnitude=max(math.hypot(dx,dy),1e-6)
        nx,ny=-dy/magnitude,dx/magnitude
        for j in range(6):
            t=2*math.pi*j/6
            verts.append((x*.85+width*nx*math.cos(t),
                          y*.79+width*ny*math.cos(t),-.072+width*math.sin(t)))
    faces=[]
    for i in range(len(sample)-1):
        for j in range(6):
            j2=(j+1)%6
            faces.append((i*6+j,i*6+j2,(i+1)*6+j2,(i+1)*6+j))
    return _mesh(name,verts,faces,material,collection)


def _socket(name, at, collection):
    obj=bpy.data.objects.new(name,None)
    obj.location=at
    obj.empty_display_size=.025
    collection.objects.link(obj)
    return obj


def _collection(name):
    collection=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def _build_lod(collection, high, mats):
    outline=_catmull(OUTLINE,8 if high else 3)
    label=lambda name: ("High_" + name) if high else name
    housing=_loft(label('Housing'),outline,[(1.0,1.0,-.056),(1.0,1.0,.08),
                                  (.80,.76,.075),(.81,.78,-.056)],
                  mats['housing'],collection)
    gasket=_loft(label('Gasket'),outline,[(.91,.86,-.067),(.91,.86,-.053),
                                 (.87,.83,-.054),(.87,.83,-.066)],
                 mats['gasket'],collection)
    lens=_lens(label('Lens'),outline,mats['lens'],collection)
    reflector=_reflector(label('Reflector'),outline,mats['reflector'],collection)
    light=_light_guide(label('LightGuide'),outline,mats['guide'],collection)
    for obj in (housing,gasket):
        if high:
            mod=obj.modifiers.new('Micro bevel, retained in editable master','BEVEL')
            mod.width=.0017
            mod.segments=3
            if hasattr(mod, 'affect'):
                mod.affect='EDGES'
    for socket_name,at in SOCKETS.items():
        _socket(('High_' + socket_name) if high else socket_name,at,collection)
    return (housing,gasket,lens,reflector,light)


def build(output_dir: Path) -> dict:
    if bpy is None:
        raise RuntimeError('Blender bpy is required; use blender --background --python ...')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        if c.name!='Collection' and not c.objects:
            bpy.data.collections.remove(c)
    mats={
      'housing':_material('R9GraphiteHousing',(0.031,.037,.045),.24,.43),
      'gasket':_material('R9BlackRubber',(.017,.020,.025),.0,.89),
      'lens':_material('R9OpticalPolycarbonate',(.22,.27,.32),.03,.09,.24),
      'reflector':_material('R9ReflectorMetal',(.56,.61,.68),.89,.12),
      'guide':_material('R9OriginalGuide',(0.65,.75,.9),.0,.22,1,(.35,.70,1.0)),
      'study_paint':_material('R9OriginalPaintControlStudy',(.38,.019,.045),.62,.27),
    }
    high=_collection('MASTER__HIGH_POLY__NOT_EXPORTED')
    low=_collection('GAME__LOW_POLY')
    _build_lod(high,True,mats)
    # Non-shipping bonnet/fender sculpt study: smooth cubic control cage, not a
    # substitute for creator-approved full-size R9 panel fit or UV bake.
    cage=tuple(tuple((-.38 + .76*i/3,
                      .14 + .028*(1-(2*i/3-1)**2) - .025*j/3,
                      .08 + .33*j/3) for j in range(4)) for i in range(4))
    sculpt=tessellate(cage,12,18)
    _mesh('High_BonnetSurfaceControlStudy',sculpt.positions,sculpt.triangles,
          mats['study_paint'],high)
    _build_lod(low,False,mats)
    output_dir.mkdir(parents=True,exist_ok=True)
    source=output_dir/'r9_optic_master.blend'
    exported=output_dir/'r9_optic_game.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in low.objects:
        ob.select_set(True)
    if low.objects:
        bpy.context.view_layer.objects.active=next(o for o in low.objects if o.type=='MESH')
    bpy.ops.export_scene.gltf(filepath=str(exported),export_format='GLB',
                              use_selection=True,export_apply=True,
                              export_materials='EXPORT')
    manifest={
        'asset':'nightgrid.cinder_r9.optical_module.prototype',
        'status':'review_candidate_not_game_integrated',
        'authoring':'editable high-poly Blender workbench + low-poly glTF',
        'unit':'metre','up':'+Y','forward':'-Z',
        'blender':bpy.app.version_string,
        'sockets':list(SOCKETS),
        'master_only_studies':['High_BonnetSurfaceControlStudy'],
        'files':{},
    }
    for file in (source,exported):
        manifest['files'][file.name]={
            'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
            'bytes':file.stat().st_size}
    (output_dir/'source.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    return manifest


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output-dir',type=Path,required=True)
    opt=ap.parse_args(args)
    print(json.dumps(build(opt.output_dir),indent=2))


if __name__=='__main__':
    main()
