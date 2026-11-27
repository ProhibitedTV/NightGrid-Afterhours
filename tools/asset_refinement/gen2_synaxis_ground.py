"""Build the fixed, lightmapped Synaxis ground-floor envelope in lot-local metres."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen2_synaxis_architecture import build


def ground(kit):
    slab = kit.slab
    slab("Floor", (0, -.15, 0), (17, .30, 20), "Stone", .003)
    slab("Ceiling", (0, 3.50, 0), (17, .30, 20), "White", .003)
    walls = [
        ((0, 1.75, 10), (17, 3.50, .25)),
        ((-8.50, 1.75, -3.25), (.25, 3.50, 13.50)),
        ((-8.50, 1.75, 7.75), (.25, 3.50, 4.50)),
        ((-8.50, 3.05, 4.50), (.25, .90, 2.00)),
        ((8.50, 1.75, 0), (.25, 3.50, 20.00)),
        ((0, 3.15, -10), (2.60, .70, .25)),
        ((0, 3.15, -7.65), (2.60, .70, .24)),
        ((0, 1.50, -3.175), (.18, 3.00, 5.55)),
    ]
    for x in (-4.90, 4.90):
        walls.extend((
            ((x, 1.75, -10), (7.20, 3.50, .25)),
            ((x, 1.75, -7.65), (7.20, 3.50, .24)),
        ))
    for center, size in walls:
        slab("Walls", center, size, "White", .004)
    for z in (-7.50, -2.50, 2.50, 7.50):
        for x in (-3.70, 3.70):
            if (x, z) != (3.70, 7.50):
                slab("Practicals", (x, 3.28, z), (3.20, .035, .28), "CabinDiffuser", .004)
    pitch = 5.30 / 4
    for panel in range(4):
        x = 5.20 + (panel - 1.5) * pitch
        slab("ReceptionStone", (x, 1.635, 9.848), (1.17 * pitch / 1.18, 2.93, .055),
             "Stone", .005, repeat=1.50)
    slab("ReceptionTrim", (5.20, .084, 9.856), (5.30, .168, .048), "Anodized", .003)
    slab("ReceptionTrim", (5.20, 3.129, 9.856), (5.30, .053, .048), "Anodized", .003)


if __name__ == "__main__":
    build("ground_envelope", ground)
