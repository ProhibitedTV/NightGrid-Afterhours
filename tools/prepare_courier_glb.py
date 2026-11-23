"""Finish the pinned courier export with stable clip names and a fitted dispatch patch."""

import argparse
import json
import struct
import zlib
from pathlib import Path


CLIPS = {
    "Idle": "idle",
    "Walk": "walk",
    "Run": "run",
    "Walk backwards": "walk_back",
    "Strafe left": "strafe_left",
    "Strafe right": "strafe_right",
    "Turn left 45°": "turn_left",
    "Turn right 45°": "turn_right",
    "Jump start": "jump_start",
    "Jump (in air)": "jump_air",
    "Jump land": "jump_land",
    "Use / press": "interact",
    "Open door": "open_door",
    "Pick up (ground)": "pick_up",
    "Sit down (chair)": "sit_down",
    "Sit idle (chair)": "sit",
    "Stand up (chair)": "stand_up",
    "Pistol idle (low ready)": "weapon_idle",
    "Pistol aim": "aim",
    "Pistol fire": "fire",
    "Pistol walk": "aim_walk",
    "Pistol run": "aim_run",
    "Pistol strafe left": "aim_left",
    "Pistol strafe right": "aim_right",
    "Rifle reload": "reload",
    "Board convertible (driver)": "board_car",
    "Drive car": "drive_car",
    "Alight from convertible (driver)": "alight_car",
}

GL_FLOAT = 5126
GL_USHORT = 5123
GL_UINT = 5125
FORMATS = {GL_FLOAT: "f", GL_USHORT: "H", GL_UINT: "I"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
GLYPHS = {
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "W": ("10001", "10001", "10001", "10101", "10101", "11011", "10001"),
}


def patch_image() -> bytes:
    width, height = 192, 96
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            fiber = ((x * 7 + y * 37 + (x ^ y) * 11) % 13) - 6
            stitch = (5 <= x <= 186 and y in (7, 88) and x % 7 < 4) or (
                7 <= y <= 88 and x in (5, 186) and y % 7 < 4
            )
            inside_mark = 22 <= x < 166 and 37 <= y < 65
            letter = False
            if inside_mark:
                slot, col = divmod((x - 22) // 4, 6)
                if col < 5:
                    letter = GLYPHS["MORROW"[slot]][(y - 37) // 4][col] == "1"
            bar = 23 <= y <= 26 and (24 <= x <= 74 or 81 <= x <= 102)
            color = (180, 185, 158) if letter else (144, 111, 66) if bar else (
                (92, 97, 80) if stitch else (36, 46, 43)
            )
            rows.extend(channel + fiber for channel in color)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


def fit_patch(gltf, binary) -> None:
    """Project into the existing backpack and interpolate the pack's joint weights."""
    parts = gltf["meshes"][0]["primitives"]
    bag = next(part for part in parts if gltf["materials"][part["material"]]["name"] == "Backpack")

    def read(accessor_index, vertex):
        item = gltf["accessors"][accessor_index]
        shape = "<" + FORMATS[item["componentType"]] * WIDTHS[item["type"]]
        view = gltf["bufferViews"][item["bufferView"]]
        start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
        return struct.unpack_from(shape, binary, start + vertex * view.get("byteStride", struct.calcsize(shape)))

    positions = bag["attributes"]["POSITION"]
    flat = [read(bag["indices"], i)[0] for i in range(gltf["accessors"][bag["indices"]]["count"])]
    vertices = {index: read(positions, index) for index in set(flat)}
    triangles = [[(index, vertices[index]) for index in flat[i : i + 3]] for i in range(0, len(flat), 3)]
    geometry, normals, texcoords, joints, weights = [], [], [], [], []
    for row in range(4):
        y = 1.325 + row * 0.021
        for col in range(5):
            x = -0.07 + col * 0.035
            nearest = None
            for triangle in triangles:
                a, b, c = [position for _, position in triangle]
                determinant = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
                if abs(determinant) < 1e-9:
                    continue
                u = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / determinant
                v = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / determinant
                barycentric = (u, v, 1 - u - v)
                if min(barycentric) < -1e-6:
                    continue
                depth = sum(point[2] * factor for (_, point), factor in zip(triangle, barycentric))
                if nearest is None or depth < nearest[0]:
                    nearest = (depth, triangle, barycentric)
            if nearest is None:
                raise ValueError("Dispatch patch must fit entirely on the backpack")
            depth, triangle, barycentric = nearest
            influence = {}
            for (index, _), factor in zip(triangle, barycentric):
                for joint, amount in zip(read(bag["attributes"]["JOINTS_0"], index), read(bag["attributes"]["WEIGHTS_0"], index)):
                    influence[joint] = influence.get(joint, 0) + amount * factor
            strongest = sorted(influence.items(), key=lambda item: item[1], reverse=True)[:4]
            strongest += [(0, 0)] * (4 - len(strongest))
            total = sum(amount for _, amount in strongest)
            joints.append(tuple(joint for joint, _ in strongest))
            weights.append(tuple(max(0, amount) / total for _, amount in strongest))
            geometry.append((x, y, depth - 0.002))
            normals.append((0, 0, -1))
            texcoords.append((1 - col / 4, 1 - row / 3))

    def append_view(payload):
        binary.extend(b"\0" * (-len(binary) % 4))
        result = len(gltf["bufferViews"])
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload)})
        binary.extend(payload)
        return result

    def append_accessor(values, component, kind):
        pack = struct.Struct("<" + FORMATS[component] * WIDTHS[kind])
        view = append_view(b"".join(pack.pack(*row) for row in values))
        accessor = {"bufferView": view, "componentType": component, "count": len(values), "type": kind}
        if component == GL_FLOAT and kind == "VEC3":
            accessor["min"] = [min(axis) for axis in zip(*values)]
            accessor["max"] = [max(axis) for axis in zip(*values)]
        gltf["accessors"].append(accessor)
        return len(gltf["accessors"]) - 1

    image_index = len(gltf["images"])
    gltf["images"].append({"bufferView": append_view(patch_image()), "mimeType": "image/png"})
    texture_index = len(gltf["textures"])
    gltf["textures"].append({"source": image_index})
    material_index = len(gltf["materials"])
    gltf["materials"].append({"name": "Morrow Dispatch woven patch", "pbrMetallicRoughness": {
        "baseColorTexture": {"index": texture_index}, "metallicFactor": 0, "roughnessFactor": 0.94
    }})
    indices = []
    for row in range(3):
        for col in range(4):
            bottom = row * 5 + col
            indices.extend(((bottom,), (bottom + 5,), (bottom + 1,)))
            indices.extend(((bottom + 1,), (bottom + 5,), (bottom + 6,)))
    parts.append({"material": material_index, "indices": append_accessor(indices, GL_USHORT, "SCALAR"),
        "attributes": {
            "POSITION": append_accessor(geometry, GL_FLOAT, "VEC3"),
            "NORMAL": append_accessor(normals, GL_FLOAT, "VEC3"),
            "TEXCOORD_0": append_accessor(texcoords, GL_FLOAT, "VEC2"),
            "JOINTS_0": append_accessor(joints, GL_USHORT, "VEC4"),
            "WEIGHTS_0": append_accessor(weights, GL_FLOAT, "VEC4"),
        }})


def prepare(source: Path, destination: Path) -> None:
    raw = source.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", raw)
    json_size, json_type = struct.unpack_from("<I4s", raw, 12)
    if (magic, version, total, json_type) != (b"glTF", 2, len(raw), b"JSON"):
        raise ValueError("Expected a complete glTF 2 binary export")
    gltf = json.loads(raw[20 : 20 + json_size])
    if len(gltf.get("skins", [])) != 1 or len(gltf["skins"][0].get("joints", [])) < 60:
        raise ValueError("Expected the full game rig with finger joints")
    names = {item["name"] for item in gltf["animations"]}
    if names != CLIPS.keys():
        raise ValueError(f"Unexpected animation set: {sorted(names ^ CLIPS.keys())}")
    for item in gltf["animations"]:
        item["name"] = CLIPS[item["name"]]
    bin_offset = 20 + json_size
    size, kind = struct.unpack_from("<I4s", raw, bin_offset)
    if kind != b"BIN\0":
        raise ValueError("Expected one embedded geometry buffer")
    binary = bytearray(raw[bin_offset + 8 : bin_offset + 8 + size])
    parts = gltf["meshes"][0]["primitives"]
    parts[:] = [part for part in parts if gltf["materials"][part["material"]]["name"] != "Neck scarf knot and ends"]
    fit_patch(gltf, binary)
    gltf["buffers"][0]["byteLength"] = len(binary)
    binary.extend(b"\0" * (-len(binary) % 4))
    bin_header = struct.pack("<I4s", len(binary), b"BIN\0")
    clean = json.dumps(gltf, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    clean += b" " * (-len(clean) % 4)
    header = struct.pack("<4sIII4s", b"glTF", 2, 28 + len(clean) + len(binary), len(clean), b"JSON")
    destination.write_bytes(header + clean + bin_header + binary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    prepare(args.source, args.destination)
