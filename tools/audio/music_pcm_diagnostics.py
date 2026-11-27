"""Bounded-memory integer PCM diagnostics for original stereo music masters."""
from array import array
import math
import struct
import sys

from music_pcm import pcm_info


def dbfs(power):
    return round(10 * math.log10(power), 3) if power > 0 else None


def samples(raw, bits):
    if bits == 16:
        result = array("h", raw)
    else:
        # Sign-preserving 24-bit to left-aligned signed 32-bit conversion.
        expanded = bytearray(len(raw) // 3 * 4)
        expanded[1::4] = raw[0::3]
        expanded[2::4] = raw[1::3]
        expanded[3::4] = raw[2::3]
        result = array("i", expanded)
    if sys.byteorder != "little":
        result.byteswap()
    return result


def analyze(path):
    info = pcm_info(path)
    bits = info["bit_depth"]
    scale = 32768 if bits == 16 else 2147483648
    maximum = scale - (1 if bits == 16 else 256)
    align = bits // 8 * 2
    window = max(1, round(info["sample_rate"] * 0.05))
    squares = [0, 0]
    clipped = [0, 0]
    frames = 0
    first = None
    last = None
    head = [[], []]
    tail = [[], []]
    with open(path, "rb") as handle:
        handle.seek(12)
        while True:
            tag, size = struct.unpack("<4sI", handle.read(8))
            if tag == b"data":
                break
            handle.seek(size + (size & 1), 1)
        remaining = size
        while remaining:
            length = min(remaining, 16384 * align)
            raw = handle.read(length)
            if len(raw) != length:
                raise ValueError("PCM payload changed during analysis")
            remaining -= length
            values = samples(raw, bits)
            for ch in range(2):
                channel = values[ch::2]
                squares[ch] += sum(x*x for x in channel)
                clipped[ch] += sum(x == maximum or x == -scale for x in channel)
                if len(head[ch]) < window:
                    head[ch].extend(channel[:window - len(head[ch])])
                tail[ch] = (tail[ch] + list(channel[-window:]))[-window:]
            if first is None:
                first = values[:2]
            last = values[-2:]
            frames += len(values) // 2
    rms = [dbfs(s / frames / scale**2) for s in squares]
    balance = round(rms[0] - rms[1], 3) if all(x is not None for x in rms) else None
    def window_rms(channels):
        return [dbfs(sum(x*x for x in ch) / len(ch) / scale**2) for ch in channels]
    return {
        "sample_frames": frames,
        "full_scale_samples_left": clipped[0],
        "full_scale_samples_right": clipped[1],
        "rms_dbfs_left": rms[0],
        "rms_dbfs_right": rms[1],
        "left_minus_right_rms_db": balance,
        "head_50ms_rms_dbfs": window_rms(head),
        "tail_50ms_rms_dbfs": window_rms(tail),
        "wrap_sample_jump_fraction": round(max(abs(first[c]-last[c]) for c in range(2)) / scale, 6),
    }
