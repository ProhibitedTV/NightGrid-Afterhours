"""Strict classic and extensible integer PCM validation."""
import os
import struct

def pcm_info(path):
    """Validate classic and extensible little-endian integer PCM RIFF WAVs.

    FFmpeg writes 24-bit PCM as WAVE_FORMAT_EXTENSIBLE, which Python's
    wave module cannot read before Python 3.12. No model dependencies.
    """
    pcm_guid = bytes.fromhex('0100000000001000800000aa00389b71')
    with open(path, 'rb') as f:
        size = os.fstat(f.fileno()).st_size
        header = f.read(12)
        if len(header) != 12 or header[:4] != b'RIFF' or header[8:] != b'WAVE':
            raise ValueError('Expected RIFF/WAVE master')
        end = 8 + struct.unpack_from('<I', header, 4)[0]
        if end != size:
            raise ValueError('Truncated or inconsistent RIFF master')
        fmt = None; data_bytes = None
        while f.tell() < end:
            chunk = f.read(8)
            if len(chunk) != 8:
                raise ValueError('Truncated WAV chunk header')
            name, length = struct.unpack('<4sI', chunk)
            start = f.tell(); next_chunk = start + length + (length & 1)
            if next_chunk > end:
                raise ValueError('Truncated WAV chunk payload')
            if name == b'fmt ':
                if fmt is not None or length < 16:
                    raise ValueError('Invalid or duplicate WAV format chunk')
                raw = f.read(min(length, 40))
                tag, ch, sr, byte_rate, align, bits = struct.unpack_from('<HHIIHH', raw)
                if tag == 0xfffe:
                    if (length < 40 or struct.unpack_from('<H', raw, 16)[0] < 22
                            or 18 + struct.unpack_from('<H', raw, 16)[0] > length
                            or raw[24:40] != pcm_guid
                            or struct.unpack_from('<H', raw, 18)[0] != bits):
                        raise ValueError('Expected extensible integer PCM')
                elif tag != 1:
                    raise ValueError('Expected integer PCM')
                if (ch != 2 or sr not in (44100, 48000) or bits not in (16, 24)
                        or align != ch * (bits // 8) or byte_rate != sr * align):
                    raise ValueError('Invalid PCM master format')
                fmt = (ch, sr, bits, align)
            elif name == b'data':
                if data_bytes is not None:
                    raise ValueError('Duplicate WAV data chunk')
                data_bytes = length
            f.seek(next_chunk)
        if fmt is None or data_bytes is None:
            raise ValueError('Missing WAV format or data chunk')
        ch, sr, bits, align = fmt
        if data_bytes <= 0 or data_bytes % align:
            raise ValueError('Incomplete PCM frames')
        n = data_bytes // align
    return {'seconds':n/sr,'sample_rate':sr,'channels':ch,'bit_depth':bits}

