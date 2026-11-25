"""Bake an original, seamless water-bead tangent normal for the fleet."""

from math import hypot, sqrt
from pathlib import Path
from random import Random

from PIL import Image


def main():
    size = 256
    height = [0.0] * (size * size)
    random = Random(48450)
    for _ in range(186):
        x, y = random.randrange(size), random.randrange(size)
        radius = random.uniform(1.3, 4.0)
        length = radius * random.uniform(1.0, 1.62)
        reach = int(length) + 1
        for j in range(-reach, reach + 1):
            for i in range(-reach, reach + 1):
                distance = hypot(i / radius, j / length)
                if distance < 1.0:
                    address = ((y + j) % size) * size + (x + i) % size
                    height[address] = max(height[address], (1.0 - distance**2)**1.5 * radius * .43)

    def at(x, y):
        return height[(y % size) * size + x % size]

    normals = []
    for y in range(size):
        for x in range(size):
            dx = (at(x - 1, y) - at(x + 1, y)) * .5
            dy = (at(x, y + 1) - at(x, y - 1)) * .5
            length = sqrt(dx * dx + dy * dy + 1)
            normals.append(tuple(round(127.5 * (1.0 + value / length)) for value in (dx, dy, 1.0)))
    image = Image.new("RGB", (size, size))
    image.putdata(normals)
    asset = Path(__file__).resolve().parents[2] / "assets/models/nightgrid/road_cars/rain_beads.png"
    image.save(asset, optimize=True)


if __name__ == "__main__":
    main()
