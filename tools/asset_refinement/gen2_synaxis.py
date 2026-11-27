"""Build the Synaxis room kit offline with Blender 5.0.

blender -b --python-exit-code 1 --python tools/asset_refinement/gen2_synaxis.py
Dimensions are in Godot metres. The shipped GLBs use shared external photo maps
bound by the game's material slots. Collision remains separately authored.
"""
from math import pi
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/models/nightgrid/synaxis_breakroom"


def coordinates(value):
    x, y, z = value
    return Vector((x, -z, y))


def surface(name, rgb, roughness, metallic=0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*rgb, 1)
    material.use_nodes = True
    node = material.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*rgb, 1)
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Metallic"].default_value = metallic
    return material


def materials():
    return {key: surface(key, rgb, roughness, metallic) for key, rgb, roughness, metallic in [
        ("Terrazzo", (.45, .43, .40), .5, 0),
        ("Walnut", (.26, .15, .085), .45, 0),
        ("Tile", (.74, .75, .72), .48, 0),
        ("Steel", (.47, .51, .54), .36, .8),
        ("Counter", (.22, .26, .28), .43, 0),
        ("Powder", (.050, .068, .073), .49, .28),
        ("Charcoal", (.024, .037, .038), .54, .03),
        ("Teal", (.044, .14, .147), .48, 0),
        ("Seat", (.065, .245, .245), .53, 0),
        ("White", (.75, .78, .76), .46, 0),
        ("Acoustic", (.68, .69, .65), .93, 0),
        ("Glass", (.039, .056, .061), .21, .29),
        ("Display", (.065, .20, .18), .3, .02),
        ("Diffuser", (.84, .91, .88), .42, 0),
        ("Kraft", (.33, .21, .101), .83, 0),
        ("Crust", (.58, .28, .07), .68, 0),
        ("Paper", (.82, .79, .71), .78, 0),
        ("Coffee", (.034, .016, .011), .3, 0),
    ]}


class Kit:
    def __init__(self):
        self.materials = materials()
        self.pieces = {}

    def finish(self, group, material, radius):
        obj = bpy.context.object
        obj.data.materials.append(self.materials[material])
        if radius:
            mod = obj.modifiers.new("Manufactured radius", "BEVEL")
            mod.width = radius
            mod.segments = 3
            mod.harden_normals = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        self.pieces.setdefault(group, []).append(obj)
        return obj

    def slab(self, group, at, size, material, radius=.008, tilt=0, repeat=1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=coordinates(at))
        obj = bpy.context.object
        obj.dimensions = (size[0], size[2], size[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj = self.finish(group, material, radius)
        self.unwrap(obj, repeat, material)
        obj.rotation_euler.x = tilt
        return obj

    @staticmethod
    def unwrap(obj, repeat, material):
        triangles = obj.modifiers.new("Tangent triangles", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=triangles.name)
        uv = obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            drop = max(range(3), key=lambda i: abs(face.normal[i]))
            u, v = [i for i in range(3) if i != drop]
            if material == "Walnut" and drop == 0:
                u, v = v, u
            for li in face.loop_indices:
                vertex = obj.data.vertices[obj.data.loops[li].vertex_index].co
                uv[li].uv = ((vertex[u] + obj.location[u]) / repeat,
                             (vertex[v] + obj.location[v]) / repeat)

    def rail(self, group, start, end, radius, material, vertices=18):
        start, end = coordinates(start), coordinates(end)
        length = (end - start).length
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length,
                                          location=(start + end) * .5)
        obj = bpy.context.object
        obj.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
        for face in obj.data.polygons:
            face.use_smooth = len(face.vertices) == 4
        obj = self.finish(group, material, min(radius * .13, .003))
        self.unwrap(obj, 1, material)
        return obj

    def ring(self, group, at, major, minor, material):
        bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8, major_radius=major,
                                        minor_radius=minor, location=coordinates(at))
        obj = self.finish(group, material, 0)
        self.unwrap(obj, 1, material)

    def export(self, folder, asset):
        folder.mkdir(parents=True, exist_ok=True)
        for group, pieces in self.pieces.items():
            bpy.ops.object.select_all(action="DESELECT")
            for piece in pieces:
                piece.select_set(True)
            bpy.context.view_layer.objects.active = pieces[0]
            bpy.ops.object.join()
            bpy.context.object.name = group
            bpy.context.object.data.name = group
        bpy.ops.export_scene.gltf(filepath=str(folder / f"{asset}.glb"), export_format="GLB",
                                  export_texcoords=True, export_normals=True, export_tangents=True)


def dining(kit):
    b, r = kit.slab, kit.rail
    b("Table", (-4.2, .728, 8.12), (3.40, .064, 1.02), "Walnut", .024, repeat=.98)
    b("Table", (-4.2, .661, 8.12), (2.96, .074, .70), "Powder", .014)
    for x in (-5.65, -2.75):
        for side in (-1, 1):
            z = 8.12 + .355 * side
            r("Table", (x, .027, z + .081 * side), (x, .69, z), .023, "Powder")
            r("Table", (x, .009, z + .081 * side), (x, .035, z + .081 * side), .028, "Charcoal")
    for i, x in enumerate((-5.36, -3.04)):
        z = 7.27
        group = f"DiningChair{i+1}"
        b(group, (x, .447, z), (.459, .066, .43), "Seat", .031)
        b(group, (x, .685, z-.202), (.435, .303, .047), "Seat", .023, tilt=-.15)
        for side in (-1, 1):
            xx = x + side * .19
            r(group, (xx, .426, z+.15), (xx+side*.043, .014, z+.196), .014, "Powder")
            r(group, (xx, .79, z-.22), (xx + side*.043, .014, z-.218), .014, "Powder")
        r(group, (x-.185, .417, z-.11), (x+.185, .417, z-.11), .013, "Powder")
    b("Catering", (-5.13, .787, 8.09), (.57, .051, .48), "Kraft", .008)
    b("Catering", (-4.33, .774, 8.10), (.51, .025, .47), "Kraft", .005)
    b("Catering", (-4.33, .956, 8.328), (.51, .367, .020), "Kraft", .005, tilt=-.12)
    b("Catering", (-2.92, .778, 8.19), (.217, .035, .211), "Paper", .008)
    for x, z in [(-3.49, 8.02), (-3.20, 8.10), (-4.73, 8.41)]:
        r("Catering", (x,.765,z), (x,.855,z), .045, "White", 32)
        kit.ring("Catering", (x,.857,z), .039, .0045, "White")
        r("Catering", (x,.855,z), (x,.858,z), .035, "Coffee", 32)
    for x in (-4.42,-4.26):
        r("Catering", (x,.787,8.07), (x,.806,8.07), .074, "Crust", 3)


def counters(kit):
    b, r = kit.slab, kit.rail
    b("Casework", (-8.01,.081,8.0), (.58,.16,3.24), "Charcoal")
    for row in range(4):
        z = 6.795 + row*.803
        body_top = .716 if row == 1 else .861
        b("Casework", (-8.029,(.081 + body_top)*.5,z), (.63,body_top-.081,.794), "Charcoal")
        b("Casework", (-7.696,.50,z), (.030,.708,.786), "Walnut", repeat=.98)
        b("Casework", (-7.671,.782,z), (.036,.030,.27), "Steel", .007)
    for center, length in ((6.80,.80), (8.675,1.83)):
        b("Casework", (-7.992,.907,center), (.749,.06,length), "Counter")
    for x in (-8.314,-7.688):
        b("Casework", (x,.907,7.48), (.104,.060,.56), "Counter")
    # The rim surrounds a recessed steel basin with a visible drain.
    b("Sink", (-8.001,.746,7.48), (.528,.025,.543), "Steel")
    for z in (7.218,7.743):
        b("Sink", (-8.001,.818,z), (.53,.164,.018), "Steel")
    for x in (-8.261,-7.738):
        b("Sink", (x,.818,7.48), (.018,.164,.531), "Steel")
    kit.ring("Sink", (-7.99,.76,7.49), .041,.006, "Charcoal")
    for start, end in [
            ((-8.298,.94,7.50),(-8.298,1.163,7.50)),
            ((-8.298,1.163,7.50),(-8.22,1.24,7.50)),
            ((-8.22,1.24,7.50),(-8.09,1.24,7.50)),
            ((-8.09,1.24,7.50),(-8.06,1.178,7.50))]:
        r("Sink", start,end,.011,"Steel")
    b("Backsplash",(-8.35,1.295,8.0),(.028,.72,3.29),"Tile",.002,repeat=1.26)
    b("Backsplash",(-8.218,1.669,8.15),(.275,.037,2.80),"Walnut",.005,repeat=.98)
    for z in (7.01,9.22):
        b("Backsplash",(-8.30,1.56,z),(.15,.19,.033),"Powder")
    b("Microwave",(-8.061,1.109,9.178),(.49,.337,.548),"Steel",.022)
    b("Microwave",(-7.803,1.112,9.245),(.031,.279,.399),"Charcoal",.014)
    b("Microwave",(-7.781,1.113,9.250),(.006,.210,.32),"Glass",.002)
    b("Microwave",(-7.786,1.202,8.966),(.012,.058,.091),"Display",.005)
    r("Microwave",(-7.768,1.026,8.967),(-7.751,1.026,8.967),.031,"Steel")
    for i in range(8):
        b("Microwave",(-8.14+i*.032,1.276,9.446),(.016,.006,.015),"Charcoal",.002)
    b("Espresso",(-8.075,1.235,8.405),(.49,.51,.558),"Steel",.025)
    b("Espresso",(-7.899,1.217,8.405),(.212,.257,.479),"Charcoal",.011)
    b("Espresso",(-7.923,1.409,8.405),(.353,.122,.575),"Powder",.015)
    b("Espresso",(-7.867,.987,8.405),(.35,.048,.564),"Steel",.014)
    for i in range(9):
        b("Espresso",(-7.866,1.013,8.163+.061*i),(.269,.007,.018),"Charcoal",.003)
    for z in (8.275,8.54):
        r("Espresso",(-7.82,1.309,z),(-7.82,1.196,z),.044,"Steel")
        r("Espresso",(-7.82,1.23,z),(-7.655,1.23,z-.061),.016,"Powder")
        r("Espresso",(-7.83,1.014,z),(-7.83,1.089,z),.038,"White",32)
        kit.ring("Espresso",(-7.83,1.091,z),.032,.0035,"White")
    b("Espresso",(-7.739,1.427,8.406),(.012,.039,.172),"Display",.004)


def finish_room(kit):
    b = kit.slab
    b("Floor",(-5.135,.003,7.950),(6.36,.010,3.79),"Terrazzo",0,repeat=2.0)
    b("RearWall",(-5.135,1.69,9.858),(6.36,3.34,.028),"Teal",.004)
    b("RearWall",(-5.135,.079,9.819),(6.36,.147,.037),"Powder",.003)
    for x in (-7.79,-6.73,-5.67,-4.61,-3.55,-2.49):
        for z in (6.525,7.475,8.425,9.375):
            b("CeilingGrid",(x,3.288,z),(1.049,.055,.939),"Acoustic",.003)
    for x in (-6.15,-3.66):
        for z in (6.97,8.95):
            b("Luminaires",(x,3.246,z),(1.14,.062,.285),"Powder",.012)
            b("Luminaires",(x,3.212,z),(1.077,.018,.216),"Diffuser",.007)
    b("NoticeFrames",(-4.7,1.98,9.834),(3.266,1.666,.025),"Powder",.012)
    b("NoticeFrames",(-4.2,2.98,9.836),(4.72,.72,.026),"Powder",.012)
    b("TableNotice",(-2.88,.872,8.02),(.32,.222,.027),"Powder",.009)
    b("TableNotice",(-2.88,.776,8.06),(.34,.036,.13),"Steel",.006)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = Kit()
    dining(kit)
    counters(kit)
    finish_room(kit)
    kit.export(ART, "breakroom")


if __name__ == "__main__":
    main()
