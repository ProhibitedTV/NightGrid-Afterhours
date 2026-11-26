#!/usr/bin/env python3
"""Check tracked documentation art containers without modifying original evidence.

This is structural validation, not a complete image decoder or provenance check.
"""
from pathlib import Path
import struct
import subprocess
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
PNG = b"\x89PNG\r\n\x1a\n"
FORMATS = {".png", ".jpg", ".jpeg", ".webp"}


def validate_png(data):
    if not data.startswith(PNG):
        raise ValueError("expected PNG signature")
    pos = len(PNG)
    seen_header = seen_data = False
    while pos + 12 <= len(data):
        size, kind = struct.unpack_from(">I4s", data, pos)
        end = pos + 12 + size
        if end > len(data):
            raise ValueError("truncated PNG chunk")
        payload = data[pos + 8:end - 4]
        crc = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(kind + payload) != crc:
            raise ValueError("PNG chunk CRC mismatch")
        if not seen_header:
            if kind != b"IHDR" or size != 13:
                raise ValueError("missing PNG IHDR")
            width, height = struct.unpack_from(">II", payload)
            if not width or not height:
                raise ValueError("invalid PNG dimensions")
            seen_header = True
        elif kind == b"IHDR":
            raise ValueError("duplicate PNG IHDR")
        if kind == b"IDAT":
            seen_data = True
        if kind == b"IEND":
            if size or not seen_data or end != len(data):
                raise ValueError("invalid PNG IEND or missing IDAT")
            return
        pos = end
    raise ValueError("missing PNG IEND")


def validate_webp(data):
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError("expected WebP RIFF signature")
    if struct.unpack_from("<I", data, 4)[0] + 8 != len(data):
        raise ValueError("WebP RIFF size mismatch")
    pos = 12
    seen_image = False
    while pos < len(data):
        if pos + 8 > len(data):
            raise ValueError("truncated WebP chunk header")
        kind, size = struct.unpack_from("<4sI", data, pos)
        end = pos + 8 + size + (size & 1)
        if end > len(data):
            raise ValueError("truncated WebP chunk")
        if kind in (b"VP8 ", b"VP8L", b"ANMF") and size:
            seen_image = True
        pos = end
    if not seen_image:
        raise ValueError("missing WebP image chunk")


def validate(extension, data):
    if extension == ".png":
        validate_png(data)
    elif extension == ".webp":
        validate_webp(data)
    elif extension in (".jpg", ".jpeg"):
        if not data.startswith(b"\xff\xd8\xff") or not data.endswith(b"\xff\xd9"):
            raise ValueError("expected JPEG start and end markers")


def main():
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z", "--", "docs/art"], cwd=ROOT
    ).split(b"\0")
    count = 0
    failures = []
    for name in tracked:
        if not name:
            continue
        path = ROOT / name.decode("utf-8")
        extension = path.suffix.lower()
        if extension not in FORMATS:
            continue
        count += 1
        try:
            validate(extension, path.read_bytes())
        except (OSError, ValueError) as error:
            failures.append(f"{path.relative_to(ROOT)}: {error}")
    if not count:
        failures.append("No tracked documentation raster art found")
    for failure in failures:
        print(f"DOC_ART ERROR: {failure}", file=sys.stderr)
    if failures:
        return 1
    print(f"DOC_ART PASS: {count} tracked raster containers")
    return 0


def png_chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))


class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.png = PNG + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0))
        self.png += png_chunk(b"IDAT", zlib.compress(b"\x00\xff")) + png_chunk(b"IEND", b"")
        self.jpeg = b"\xff\xd8\xff\xe0\x00\x02\xff\xd9"
        chunks = b"WEBP" + b"VP8L" + struct.pack("<I", 5) + b"\x2f\x00\x00\x00\x00\x00"
        self.webp = b"RIFF" + struct.pack("<I", len(chunks)) + chunks

    def test_containers(self):
        for ext, data in ((".png", self.png), (".jpg", self.jpeg), (".webp", self.webp)):
            with self.subTest(ext=ext):
                validate(ext, data)

    def test_mislabeled_jpeg(self):
        with self.assertRaisesRegex(ValueError, "PNG signature"):
            validate(".png", self.jpeg)

    def test_truncation(self):
        for ext, data in ((".png", self.png), (".jpg", self.jpeg), (".webp", self.webp)):
            with self.subTest(ext=ext), self.assertRaises(ValueError):
                validate(ext, data[:-1])

    def test_png_crc(self):
        damaged = bytearray(self.png)
        damaged[20] ^= 1
        with self.assertRaisesRegex(ValueError, "CRC"):
            validate(".png", damaged)

    def test_webp_missing_image(self):
        with self.assertRaisesRegex(ValueError, "missing WebP image"):
            validate(".webp", b"RIFF\x04\x00\x00\x00WEBP")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        unittest.main(argv=[sys.argv[0]])
    else:
        sys.exit(main())
