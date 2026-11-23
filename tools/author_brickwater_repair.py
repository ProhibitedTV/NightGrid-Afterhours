#!/usr/bin/env python3
"""Author the Night Shift Repairs room and hinged leaf as offline glTF assets."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct

from author_exchange_storefronts import quad
import author_exchange_storefronts as mesh


OUT = Path("assets/models/nightgrid/night_shift_repairs")
PALETTE = {
    # Finish, tint, roughness, metallic. Photo textures are shared in place.
    "brick": ("masonry", (0.83, 0.74, 0.66), 1.0, 1.0),
    "floor": ("concrete", (0.68, 0.65, 0.59), 1.0, 1.0),
    "plaster": ("plaster", (0.76, 0.72, 0.62), 1.0, 1.0),
    "steel": ("steel", (0.56, 0.62, 0.62), 0.81, 1.0),
    "enamel": ("steel", (0.25, 0.66, 0.59), 0.75, 1.0),
    "tool_red": (None, (0.32, 0.043, 0.026), 0.52, 0.27),
    "rubber": (None, (0.035, 0.036, 0.037), 0.91, 0),
    "metal": (None, (0.52, 0.51, 0.47), 0.41, 0.8),
    "light": (None, (0.9, 0.83, 0.68), 0.35, 0),
    "glass": (None, (0.44, 0.69, 0.62), 0.22, 0),
    "label": (None, (0.62, 0.38, 0.10), 0.72, 0),
}


def box(material, x0, x1, y0, y1, z0, z1):
    mesh.box(material, x0, x1, y0, y1, z0, z1)


def round_y(material, x, z, y0, y1, radius, sides=12):
    """Wall and bevel rings with flat ends for stocked cans and feet."""
    rings = [(y0, radius * 0.86), (y0 + 0.012, radius),
             (y1 - 0.012, radius), (y1, radius * 0.86)]
    for i in range(sides):
        a, b = math.tau * i / sides, math.tau * (i + 1) / sides
        for (low, inner), (high, outer) in zip(rings, rings[1:]):
            quad(material, (x + inner * math.cos(a), low, z + inner * math.sin(a)),
                 (x + outer * math.cos(a), high, z + outer * math.sin(a)),
                 (x + outer * math.cos(b), high, z + outer * math.sin(b)),
                 (x + inner * math.cos(b), low, z + inner * math.sin(b)))
    for y, direction in ((y0, -1), (y1, 1)):
        ring = [(x + radius * 0.86 * math.cos(math.tau * i / sides), y,
                 z - direction * radius * 0.86 * math.sin(math.tau * i / sides)) for i in range(sides)]
        for i in range(1, sides - 1, 2):
            quad(material, ring[0], ring[i], ring[i + 1], ring[i + 2])


def shelf(x0, x1, z0, z1):
    for x in (x0, x1 - 0.04):
        for z in (z0, z1 - 0.045):
            box("steel", x, x + 0.04, 0.04, 2.1, z, z + 0.045)
            box("rubber", x - 0.012, x + 0.051, 0, 0.055, z - 0.01, z + 0.056)
    for y in (0.22, 0.82, 1.37, 1.92):
        box("enamel", x0, x1, y - 0.04, y, z0, z1)
        box("steel", x1 - 0.028, x1, y - 0.075, y - 0.035, z0, z1)

def tool_arc(x, y, z, radius, thickness, half_angle):
    for i in range(10):
        low = -half_angle + 2 * half_angle * i / 10
        high = -half_angle + 2 * half_angle * (i + 1) / 10
        def corner(depth, angle, rad):
            return (x + depth, y + math.cos(angle) * rad, z + math.sin(angle) * rad)
        a, b = [corner(0.02, angle, radius) for angle in (low, high)]
        c, d = [corner(0.02, angle, radius - thickness) for angle in (high, low)]
        quad("metal", d, c, b, a)
        for start, end in ((a, b), (c, d)):
            quad("metal", start, end, (end[0] - 0.034, *end[1:]),
                 (start[0] - 0.034, *start[1:]))


def room():
    # X runs west (negative) through the room, Z along the existing alley.
    box("floor", -5.78, 0.28, -0.15, 0, -8.10, 1.50)
    box("plaster", -5.78, 0.0, 3.10, 3.26, -8.10, 1.50)
    box("brick", -5.78, -5.57, 0, 3.10, -8.10, 1.50)
    box("brick", -5.57, -0.26, 0, 3.10, -8.10, -7.90)
    box("plaster", -5.57, -0.26, 0, 3.10, 1.31, 1.50)
    # Front enclosure behind the retained display glazing and masonry.
    box("plaster", -0.27, -0.01, 0, 3.10, -5.10, -1.50)
    # Three-metre inset former service aperture, now with a usable frame.
    for a, b in [(-1.50, -0.61), (0.61, 1.50)]:
        box("brick", -0.26, 0.27, 0, 3.10, a, b)
    box("brick", -0.26, 0.27, 2.36, 3.10, -0.61, 0.61)
    for z in (-0.61, 0.55):
        box("enamel", 0.14, 0.28, 0, 2.36, z, z + 0.06)
    box("enamel", 0.14, 0.28, 2.29, 2.36, -0.55, 0.55)
    box("metal", 0.01, 0.28, 0, 0.018, -0.55, 0.55)
    box("steel", 0.269, 0.291, 2.53, 2.79, -0.74, 0.74)
    for y in (2.556, 2.759):
        for z in (-0.716, 0.693):
            box("metal", 0.290, 0.299, y, y + 0.017, z, z + 0.017)
    # Service counter with steel plinth, chamfered trim, register and folio.
    box("enamel", -4.68, -3.88, 0.08, 0.99, -1.88, 0.28)
    box("rubber", -4.62, -3.94, 0.015, 0.09, -1.83, 0.23)
    box("steel", -4.73, -3.82, 0.99, 1.046, -1.94, 0.34)
    box("metal", -3.845, -3.816, 1.006, 1.032, -1.92, 0.32)
    box("steel", -3.844, -3.819, 0.57, 0.81, -1.38, -0.30)
    box("rubber", -4.54, -4.12, 1.046, 1.078, -0.28, 0.02)
    box("enamel", -4.49, -4.37, 1.078, 1.36, -0.30, 0.04)
    box("light", -4.36, -4.355, 1.15, 1.33, -0.267, 0.007)
    for index in range(4):
        y = 1.046 + index * 0.009
        box("label", -4.11, -3.88, y, y + 0.007, -1.34, -1.03)
    # Wall-side bench with heavy vice, pegboard and raised task-light trunk.
    box("steel", -5.56, -4.81, 0.96, 1.04, -6.64, -2.47)
    for z in (-6.60, -4.60, -2.60):
        box("enamel", -5.50, -4.88, 0.06, 0.96, z, z + 0.15)
    box("enamel", -5.53, -5.46, 1.10, 2.27, -6.59, -2.54)
    box("rubber", -5.456, -5.44, 1.23, 2.22, -6.52, -2.61)
    for r in range(6):
        for c in range(24):
            y, z = 1.30 + r * 0.16, -6.41 + c * 0.16
            box("metal", -5.438, -5.434, y, y + 0.015, z, z + 0.015)
    for i, length in enumerate((0.36, 0.54, 0.47, 0.65, 0.28, 0.41, 0.58, 0.50)):
        z = -6.27 + i * 0.42
        box("metal", -5.43, -5.39, 1.98 - length, 1.98, z, z + 0.036)
        if i % 3 == 0:
            tool_arc(-5.389, 1.97, z + 0.018, 0.074, 0.023, math.pi)
            box("metal", -5.44, -5.38, 1.96 - length, 2.02 - length, z - 0.014, z + 0.05)
        elif i % 3 == 1:
            box("tool_red", -5.44, -5.38, 1.98 - length, 2.18 - length, z - 0.012, z + 0.048)
            box("metal", -5.45, -5.38, 1.97, 2.025, z - 0.071, z + 0.093)
        else:
            tool_arc(-5.389, 1.98 - length, z + 0.016, 0.056, 0.018, math.pi * 0.68)
            box("enamel", -5.44, -5.375, 1.73, 1.92, z - 0.014, z + 0.05)
    for i in range(4):
        box("tool_red", -5.48, -4.96, 0.19 + i * 0.13, 0.30 + i * 0.13, -4.24, -3.47)
        box("metal", -4.966, -4.932, 0.25 + i * 0.13, 0.28 + i * 0.13, -4.09, -3.62)
    round_y("metal", -5.07, -5.80, 1.04, 1.14, 0.15)
    box("tool_red", -5.23, -4.91, 1.13, 1.32, -5.95, -5.65)
    for z in (-5.92, -5.72):
        box("metal", -5.23, -4.91, 1.31, 1.35, z, z + 0.049)
    # Merchandise racks face the display window with walking space between.
    shelf(-3.41, -2.79, -7.83, -5.69)
    shelf(-1.02, -0.49, -4.88, -2.94)
    for i in range(13):
        x = -3.20 + 0.21 * (i % 2)
        z = -7.68 + 0.29 * (i % 7)
        y = (0.82, 1.37, 1.92)[i % 3]
        round_y("tool_red" if i % 2 else "enamel", x, z, y, y + 0.22, 0.073)
        round_y("label", x, z, y + 0.075, y + 0.15, 0.074)
        round_y("metal", x, z, y + 0.218, y + 0.25, 0.052)
    for i in range(8):
        z, y = -4.68 + 0.43 * (i % 4), 0.82 + 0.55 * (i // 4)
        box("label" if i % 2 else "rubber", -0.93, -0.55, y, y + 0.17, z, z + 0.32)
        box("metal", -0.94, -0.93, y + 0.07, y + 0.115, z + 0.06, z + 0.24)
    # A display table and spools occupy the actual depth seen from the alley.
    box("steel", -1.52, -0.42, 0.78, 0.85, -7.58, -5.60)
    for x in (-1.49, -0.48):
        for z in (-7.54, -5.66):
            box("enamel", x, x + 0.055, 0, 0.79, z, z + 0.055)
    for z in (-7.29, -6.49, -5.94):
        round_y("label", -0.96, z, 0.85, 0.91, 0.22)
        round_y("rubber", -0.96, z, 0.91, 1.12, 0.168)
        round_y("label", -0.96, z, 1.12, 1.16, 0.22)
        round_y("metal", -0.96, z, 1.16, 1.19, 0.07)
    # Suspended luminaires with visible conduit and structure-to-housing mounts.
    for z in (-6.55, -3.55, -0.61):
        box("steel", -4.50, -1.08, 2.99, 3.10, z - 0.08, z + 0.08)
        for x in (-4.16, -1.41):
            round_y("metal", x, z, 2.88, 3.02, 0.029, 8)
        box("steel", -4.23, -1.34, 2.85, 2.93, z - 0.10, z + 0.10)
        box("light", -4.16, -1.41, 2.842, 2.854, z - 0.067, z + 0.067)
    box("metal", -4.61, -4.56, 3.04, 3.09, -7.85, 1.27)
    box("enamel", -0.45, -0.25, 2.43, 2.59, -0.38, 0.38)
    box("light", -0.454, -0.449, 2.47, 2.55, -0.33, 0.33)


def door():
    # Local origin is the hinge, with the leaf extending towards -Z.
    for z in (-1.105, -0.073):
        box("enamel", -0.031, 0.031, 0.028, 2.27, z, z + 0.073)
    for y0, y1 in [(0.028, 0.12), (0.94, 1.035), (2.18, 2.27)]:
        box("enamel", -0.034, 0.034, y0, y1, -1.032, -0.073)
    box("steel", -0.022, 0.022, 0.12, 0.94, -1.032, -0.073)
    box("glass", -0.008, 0.008, 1.035, 2.18, -1.032, -0.073)
    for x in (-0.085, 0.085):
        for y in (0.97, 1.19):
            box("metal", min(x, -0.035), max(x, 0.035), y, y + 0.034, -1.01, -0.956)
        round_y("metal", x, -0.98, 0.963, 1.234, 0.020)
    for y in (0.26, 1.96):
        round_y("metal", 0, -0.007, y, y + 0.13, 0.039)


def emit(name, make_geometry, *, output=OUT, palette=PALETTE, emission=None, generator="NightGrid original Night Shift Repairs"):
    mesh.KINDS = list(palette)
    mesh.begin()
    make_geometry()
    binary = bytearray()
    views, accessors, materials, primitives = [], [], [], []
    images, texture_lookup = [], {}

    def pack(values, code, dimensions, type_id, target):
        data = struct.pack(f"<{len(values)}{code}", *values)
        views.append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(data), "target": target})
        binary.extend(data)
        entry = {"bufferView": len(views) - 1, "componentType": type_id, "count": len(values) // dimensions,
                 "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}[dimensions]}
        if target == 34962 and dimensions == 3:
            entry["min"] = [min(values[i::3]) for i in range(3)]
            entry["max"] = [max(values[i::3]) for i in range(3)]
        accessors.append(entry)
        return len(accessors) - 1

    def texture(finish, channel):
        suffix = ".png" if channel == "arm" else ".jpg"
        if finish == "plaster":
            source = {"base": "diff", "normal": "nor_gl", "arm": "arm"}[channel]
            package = "modular_urban_apartments_facade"
            path = f"../../polyhaven/{package}/textures/{package}_plaster_{source}_1k.jpg"
        else:
            path = f"../central_exchange_storefront/textures/{finish}_{channel}_1k{suffix}"
        if path not in texture_lookup:
            assert (output / path).is_file(), path
            texture_lookup[path] = len(images)
            images.append({"uri": path})
        return {"index": texture_lookup[path]}

    triangles = 0
    for kind, buffers in mesh.ART.items():
        if not buffers["i"]:
            continue
        finish, color, rough, metallic = palette[kind]
        pbr = {"baseColorFactor": [*color, 0.22 if kind == "glass" else 1],
               "roughnessFactor": rough, "metallicFactor": metallic}
        material = {"name": kind, "pbrMetallicRoughness": pbr}
        if finish:
            pbr.update(baseColorTexture=texture(finish, "base"), metallicRoughnessTexture=texture(finish, "arm"))
            material["normalTexture"] = {**texture(finish, "normal"), "scale": 0.66}
        if emission is not None and kind in emission:
            material["emissiveFactor"] = emission[kind]
        elif kind == "light":
            material["emissiveFactor"] = [0.82, 0.76, 0.63]
        if kind == "glass":
            material.update(alphaMode="BLEND", doubleSided=True)
        primitives.append({
            "attributes": {"POSITION": pack(buffers["p"], "f", 3, 5126, 34962),
                           "NORMAL": pack(buffers["n"], "f", 3, 5126, 34962),
                           "TANGENT": pack(buffers["t"], "f", 4, 5126, 34962),
                           "TEXCOORD_0": pack(buffers["uv"], "f", 2, 5126, 34962)},
            "indices": pack(buffers["i"], "I", 1, 5125, 34963), "material": len(materials),
        })
        materials.append(material)
        triangles += len(buffers["i"]) // 3
    doc = {"asset": {"version": "2.0", "generator": generator},
           "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "mesh": 0}],
           "meshes": [{"primitives": primitives}], "buffers": [{"uri": name + ".bin", "byteLength": len(binary)}],
           "bufferViews": views, "accessors": accessors, "materials": materials,
           "images": images, "textures": [{"source": i} for i in range(len(images))]}
    (output / (name + ".bin")).write_bytes(binary)
    (output / (name + ".gltf")).write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return {"name": name, "triangles": triangles, "materials": len(materials), "textures": list(texture_lookup)}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "license": "Original NightGrid Afterhours geometry and arrangement. Shared Poly Haven maps are CC0.",
        "poly_haven_license": "https://polyhaven.com/license",
        "shared_texture_sources": [
            "https://polyhaven.com/a/brick_wall_001",
            "https://polyhaven.com/a/blue_metal_plate",
            "https://polyhaven.com/a/concrete_floor_01",
            "https://polyhaven.com/a/modular_urban_apartments_facade",
        ],
        "generator": __file__.replace("\\", "/").split("/")[-1],
        "models": [emit("workshop", room), emit("hinged_leaf", door)],
    }
    paths = sorted([*OUT.glob("*.gltf"), *OUT.glob("*.bin")])
    manifest["files"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    (OUT / "SOURCE.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(manifest["models"])


if __name__ == "__main__":
    main()
