"""Author the dimensioned Synaxis wall kits and sign hardware with Blender 5."""
import math
from pathlib import Path
import sys

if __name__ == "__main__" and "--tone-paint" in sys.argv:
    from PIL import Image

    maps = Path(__file__).resolve().parents[2] / "assets/pbr/synaxis_architecture"
    plaster = Image.open(maps / "white_plaster_02_diff_1k.jpg").convert("RGB")
    paint = Image.new("RGB", plaster.size, (203, 202, 198))
    Image.blend(paint, plaster, .13).save(maps / "wall_paint_diff_1k.jpg", quality=94, subsampling=0)
    raise SystemExit(0)

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen2_synaxis import Kit, ROOT, surface

OUT = ROOT / "assets/models/nightgrid/synaxis_architecture"


def build(name, author, output=OUT):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = Kit(bevel_segments=2)
    kit.materials.update({
        key: surface(key, color, rough, metal)
        for key, color, rough, metal in (
            ("Stone", (.49, .47, .43), .42, 0),
            ("Fabric", (.38, .39, .37), .88, 0),
            ("Anodized", (.065, .081, .09), .46, .54),
            ("Satin", (.43, .47, .48), .36, .72),
            ("Enamel", (.028, .042, .054), .63, .08),
            ("Opal", (.84, .91, .87), .39, 0),
            ("Letter", (.76, .82, .79), .39, .52),
            ("CabinMetal", (.44, .48, .51), .39, .55),
            ("CabinDiffuser", (.86, .90, .89), .42, 0),
            ("PartitionGlass", (.57, .72, .73), .18, 0),
            ("EtchedBand", (.78, .84, .82), .71, 0),
        )
    })
    author(kit)
    kit.export(output, name, origin_baked=True)


def panel(kit, material):
    b = kit.slab
    b("Face", (0, 1.635, .027), (1.170, 2.93, .055), material, .005,
      repeat={"Stone": 1.50, "Fabric": .30, "Walnut": 1.18}[material])
    b("Trim", (0, .084, .019), (1.18, .168, .048), "Anodized", .0025)
    b("Trim", (0, 3.129, .019), (1.18, .053, .048), "Anodized", .0025)


def plaque(kit):
    # Centre datum is the mounting point. Back chassis reaches the substrate.
    b = kit.slab
    b("Housing", (0, 0, -.026), (1.7, .30, .086), "Anodized", .008)
    b("Border", (0, 0, .012), (1.68, .285, .016), "Satin", .006)
    b("PrintBed", (0, 0, .020), (1.63, .252, .010), "Enamel", .004)
    for x in (-.80, .80):
        for y in (-.107, .107):
            kit.rail("Fasteners", (x, y, .024), (x, y, .029), .0055, "Satin", vertices=12)


def notice(kit):
    b = kit.slab
    b("BackChassis", (0, 0, -.033), (2.42, 1.50, .080), "Anodized", .006)
    b("Perimeter", (0, 0, .010), (2.40, 1.48, .030), "Enamel", .005)


LETTERS = [
    [(34, 4), (6, 4), (2, 8), (2, 24), (6, 28), (30, 28), (34, 32), (34, 48), (30, 52), (2, 52)],
    [(2, 4), (18, 27), (34, 4), None, (18, 27), (18, 52)],
    [(2, 52), (2, 4), (34, 52), (34, 4)],
    [(2, 52), (2, 18), (18, 4), (34, 18), (34, 52), None, (2, 32), (34, 32)],
    [(2, 4), (34, 52), None, (34, 4), (2, 52)],
    [(4, 4), (32, 4), None, (18, 4), (18, 52), None, (4, 52), (32, 52)],
]


def reception(kit):
    b = kit.slab
    b("Panel", (0, .29, .058), (3.66, .95, .112), "Anodized", .014)
    b("Panel", (0, .29, .117), (3.53, .83, .022), "Enamel", .012)
    for x in (-1.80, 1.80):
        b("Trim", (x, .29, .121), (.017, .879, .027), "Satin", .003)
    for x in (-1.70, 1.70):
        b("LightReveal", (x, .29, .133), (.012, .71, .009), "Opal", .002)
    # Fabricated lettering derived from the brand's authored outline paths.
    for index, points in enumerate([*LETTERS, LETTERS[0]]):
        for start, end in zip(points, points[1:]):
            if start is None or end is None:
                continue
            a = Vector((.0067 * (start[0] + index * 47) - .98, .477 - start[1] * .0067))
            c = Vector((.0067 * (end[0] + index * 47) - .98, .477 - end[1] * .0067))
            center = (a + c) / 2
            obj = b("Lettering", (center.x, center.y, .155), ((a-c).length + .023, .041, .040), "Letter", .007)
            obj.rotation_euler.y = -math.atan2(c.y-a.y, c.x-a.x)
    emblem = [(0, .29), (.251, .145), (.251, -.145), (0, -.29), (-.251, -.145), (-.251, .145)]
    for start, end in zip(emblem, emblem[1:] + emblem[:1]):
        a, c = Vector(start), Vector(end)
        center = (a + c) / 2
        for z, width, material in ((.154, .058, "Opal"), (.181, .030, "Letter")):
            obj = b("Emblem", (center.x - 1.30, center.y + .29, z),
                    ((a-c).length + width * .44, width, .028), material, .004)
            obj.rotation_euler.y = -math.atan2(c.y-a.y, c.x-a.x)
    initial = [(-.076, .111), (.005, .155), (.096, .104), (-.085, .010), (.087, -.084), (.003, -.137), (-.090, -.085)]
    for start, end in zip(initial, initial[1:]):
        a, c = Vector(start), Vector(end)
        center = (a + c) / 2
        obj = b("Emblem", (center.x - 1.30, center.y + .29, .182),
                ((a-c).length + .016, .047, .034), "Letter", .006)
        obj.rotation_euler.y = -math.atan2(c.y-a.y, c.x-a.x)


def entrance_portal(kit):
    """Fit the existing 2.60 m clear opening at the street face."""
    b = kit.slab
    for side in (-1, 1):
        x = side * 1.38
        b("Jambs", (x, 1.40, -.07), (.16, 2.80, .42), "Anodized", .009)
        b("Reveals", (side * 1.318, 1.42, -.283), (.027, 2.73, .018), "Satin", .004)
        b("FootGuards", (x, .11, -.286), (.154, .22, .023), "Satin", .005)
        # Face-mounted rainscreen covers the two unlit baked wall returns.
        # The 12 mm vertical reveals expose the dark backer at each joint.
        for bay in range(4):
            x = side * (2.32 + bay * 1.72)
            b("StreetStone", (x, 1.75, -.164), (1.708, 2.94, .080), "Stone", .004,
              repeat=1.50)
        b("StreetPlinths", (side * 4.90, .15, -.16), (6.88, .28, .081), "Anodized", .006)
        b("StreetCaps", (side * 4.90, 3.27, -.159), (6.88, .10, .075), "Anodized", .004)
    b("Header", (0, 2.82, -.08), (2.92, .16, .44), "Anodized", .012)
    b("Soffit", (0, 2.745, -.220), (2.59, .012, .15), "Satin", .003)
    for x in (-.79, .79):
        b("Lens", (x, 2.735, -.225), (.64, .012, .035), "CabinDiffuser", .004)
    b("Threshold", (0, .007, -.07), (2.59, .014, .39), "Satin", .002)
    for z in (-.226, -.198, -.170, -.142):
        b("ThresholdGrooves", (0, .014, z), (2.54, .004, .007), "Anodized", .0015)


if __name__ == "__main__" and "--entrance-only" in sys.argv:
    build("entrance_portal", entrance_portal)
elif __name__ == "__main__":
    for material in ("Stone", "Walnut", "Fabric"):
        build(material.lower() + "_panel", lambda kit: panel(kit, material))
    build("plaque", plaque)
    build("notice", notice)
    build("reception_brand", reception)
