"""Author the Synaxis reception linear luminaire with Blender 5."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen2_synaxis_architecture import ROOT, build


def reception_luminaire(kit):
    b = kit.slab
    b("RecessedPan", (0,.045,0), (3.29,.066,.323), "Anodized", .006)
    for z in (-.159,.159):
        b("Perimeter", (0,.006,z), (3.28,.022,.033), "Satin", .003)
        b("Reflector", (0,.022,z*.81), (3.19,.040,.039), "Satin", .004)
    for x in (-1.627,1.627):
        b("Perimeter", (x,.006,0), (.036,.022,.305), "Satin", .003)
    b("Gasket", (0,.015,0), (3.208,.024,.247), "Enamel", .005)
    b("Diffuser", (0,.002,0), (3.160,.018,.218), "CabinDiffuser", .005)


def reception_bake_shell(kit):
    # Coordinates are relative to the real reception sign wall, in metres.
    b = kit.slab
    b("Floor", (0,-.15,-2.09), (5.30,.30,4.18), "Stone", .006, repeat=1.5)
    b("Ceiling", (0,3.485,-2.09), (5.30,.27,4.18), "White", .006)
    b("RearWall", (0,1.675,.122), (5.30,3.35,.244), "White", .005)
    b("EastWall", (-2.765,1.675,-2.09), (.23,3.35,4.18), "White", .005)
    for x in (-1.99, -.663, .663, 1.99):
        b("StoneCladding", (x,1.64,-.023), (1.312,2.93,.046), "Stone", .005, repeat=1.5)
    b("Skirting", (0,.084,-.026), (5.30,.168,.052), "Anodized", .004)


if __name__ == "__main__":
    if "--bake-shell" in sys.argv:
        build("reception_shell", reception_bake_shell, ROOT / "tools/lighting")
    else:
        build("reception_luminaire", reception_luminaire)
