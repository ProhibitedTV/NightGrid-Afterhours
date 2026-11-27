"""Author the passenger cabin, suspended wayfinding and glazing with Blender 5."""
from pathlib import Path
import sys

if __name__ == "__main__" and "--tone-metal" in sys.argv:
    from PIL import Image, ImageOps

    root = Path(__file__).resolve().parents[2]
    scan = root / "assets/models/nightgrid/central_exchange_storefront/textures/steel_base_1k.jpg"
    luminance = ImageOps.grayscale(Image.open(scan))
    neutral = ImageOps.colorize(luminance, (112, 122, 126), (175, 184, 187))
    neutral.save(root / "assets/pbr/synaxis_architecture/cabin_satin_metal_1k.jpg", quality=94, subsampling=0)
    raise SystemExit(0)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen2_synaxis_architecture import build


def cabin(kit):
    b, r = kit.slab, kit.rail
    b("Deck", (0, -.035, 0), (2.26, .07, 2.35), "Stone", .008, repeat=1.50)
    b("Ceiling", (0, 2.68, 0), (2.26, .09, 2.35), "Anodized", .012)
    for x in (-1.105, 1.105):
        b("WallBacking", (x, 1.34, 0), (.065, 2.68, 2.35), "Anodized", .006)
        for z in (-.762, 0, .762):
            b("Veneer", (x * .96, 1.62, z), (.032, 1.52, .752), "Walnut", .0035, repeat=1.18)
            b("Kicks", (x * .959, .48, z), (.034, .68, .752), "CabinMetal", .0035)
        b("Skirting", (x * .954, .075, 0), (.04, .15, 2.33), "Anodized", .003)
        b("Recess", (x * .906, 2.56, 0), (.16, .082, 2.18), "Enamel", .005)
        b("CeilingDiffusers", (x * .906, 2.516, 0), (.087, .014, 2.10), "CabinDiffuser", .003)
        r("Handrails", (x * .892, .91, -.86), (x * .892, .91, .86), .020, "Satin")
        for z in (-.81, .81):
            r("RailStandoffs", (x * .948, .91, z), (x * .892, .91, z), .016, "Satin", vertices=12)
    b("RearWall", (0, 1.34, 1.14), (2.23, 2.68, .08), "Walnut", .007, repeat=1.18)
    b("DoorBacking", (0, 1.33, -1.14), (2.23, 2.66, .085), "Anodized", .009)
    for x in (-.362, .362):
        b("DoorLeaves", (x, 1.077, -1.083), (.718, 2.154, .039), "CabinMetal", .005, repeat=.92)
    for x in (-.762, .762):
        b("DoorJambs", (x, 1.106, -1.043), (.074, 2.21, .066), "Satin", .005)
    b("DoorJambs", (0, 2.186, -1.043), (1.6, .071, .066), "Satin", .005)
    b("DoorThreshold", (0, .011, -1.032), (1.47, .020, .142), "Satin", .002)
    for z in (-1.074, -1.049, -1.025):
        b("GuideGrooves", (0, .022, z), (1.45, .002, .006), "Enamel", .0008)
    b("IndicatorBezel", (0, 2.386, -1.067), (1.05, .29, .061), "Satin", .008)
    b("IndicatorGlass", (0, 2.386, -1.033), (.981, .231, .016), "Enamel", .004)
    b("Controls", (.961, 1.12, -1.056), (.264, .94, .065), "Satin", .009)
    b("Controls", (.961, 1.53, -1.02), (.199, .067, .019), "Enamel", .004)
    for y in (.92, 1.04, 1.16, 1.28, 1.40):
        for x in (.923, .998):
            r("Buttons", (x, y, -1.021), (x, y, -1.012), .024, "Anodized", vertices=16)
    for x in (.867, 1.055):
        for y in (.69, 1.54):
            r("ControlFasteners", (x, y, -1.025), (x, y, -1.019), .007, "Enamel", vertices=12)


def suspended_sign(kit):
    b, r = kit.slab, kit.rail
    b("Chassis", (0, 0, 0), (2.54, .32, .087), "Anodized", .011)
    for z in (-.048, .048):
        b("Bezel", (0, 0, z), (2.48, .268, .023), "Satin", .005)
        b("PrintFace", (0, 0, z * 1.25), (2.40, .226, .013), "Enamel", .004)
    for x in (-.87, .87):
        r("Suspension", (x, .14, 0), (x, .48, 0), .014, "Satin", vertices=16)
        b("CeilingFlange", (x, .477, 0), (.145, .023, .114), "Anodized", .004)


def partition(kit):
    # Three glazed bays at 600 mm centers. Separate lites avoid overlapping alpha.
    b = kit.slab
    for x in (-.6, 0, .6):
        for y, height, material in ((.49, .89, "PartitionGlass"), (1.18, .49, "EtchedBand"),
                                    (2.04, 1.23, "PartitionGlass")):
            b("Glazing", (x, y, 0), (.560, height, .013), material, .0018)
    for x in (-.88, -.3, .3, .88):
        b("Mullions", (x, 1.35, 0), (.040, 2.655, .076), "Anodized", .004)
        b("Mullions", (x, 1.35, .037), (.021, 2.63, .006), "Satin", .002)
    for y, h in ((.023, .046), (2.677, .046)):
        b("Perimeter", (0, y, 0), (1.8, h, .080), "Anodized", .004)


if __name__ == "__main__":
    build("lift_cabin", cabin)
    build("lift_direction_sign", suspended_sign)
    build("executive_glazing", partition)
