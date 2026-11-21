#!/usr/bin/env python3
"""Generate original fictional MBPD dialogue with offline eSpeak NG + radio DSP.
The words and processing are original; no sampled police recordings."""
from pathlib import Path
import math, random, struct, subprocess, tempfile, wave
# Use the game's captions as the canonical source of spoken dialogue.
# Explicit pronunciation avoids a TTS engine treating 10-4 as subtraction.
import re
source_text = Path("scripts/police_radio.gd").read_text(encoding="utf-8")
block = source_text.split("const LINES = {", 1)[1].split("}", 1)[0]
LINES = {key.lower(): (phrase, key in {"REPORT", "ASSIGNED", "CLOSED"} or key.startswith("CIVIC"))
         for key, phrase in re.findall(r'"([A-Z]+)": "([^"]+)"', block)}
assert set(LINES) == {"report", "assigned", "ack", "contact", "search", "closed", "released", "unavailable", "available", "civicmotorist", "civictraffic", "civicpublic"}
out = Path("assets/audio/mbpd")
out.mkdir(parents=True, exist_ok=True)
for name, (phrase, control) in LINES.items():
    spoken_codes = {"4": "four", "7": "seven", "8": "eight", "17": "seventeen", "19": "nineteen"}
    phrase = re.sub(r"\b10-(\d+)\b", lambda match: "ten " + spoken_codes[match.group(1)], phrase)
    with tempfile.TemporaryDirectory() as temp:
        source = Path(temp) / "voice.wav"
        subprocess.run(["espeak-ng", "-v", "en-us", "-s", "153" if control else "168",
                        "-p", "43" if control else "32", "-w", str(source), phrase], check=True)
        with wave.open(str(source), "rb") as f:
            assert f.getnchannels() == 1 and f.getsampwidth() == 2
            rate = f.getframerate()
            audio = struct.unpack("<" + "h" * f.getnframes(), f.readframes(f.getnframes()))
    rng = random.Random(117 + len(name))
    low, high, prev = 0., 0., 0.
    samples = []
    # Short radio key-up/down chirp with static; speech is band-limited and
    # lightly saturated, with distinct dispatch / unit vocal timbres.
    for j in range(int(rate * .14)):
        t = j / rate
        samples.append(int(4200 * math.sin(2*math.pi*1050*t)*math.exp(-14*t) + rng.uniform(-500,500)))
    for raw in audio:
        x = raw / 32768.
        high = .92 * (high + x - prev)
        prev = x
        low += .36 * (high - low)
        samples.append(int(19000 * math.tanh(low * 2.6 + rng.uniform(-.013,.013))))
    for j in range(int(rate * .12)):
        samples.append(int(rng.uniform(-1100,1100)*math.exp(-j/rate*35)))
    with wave.open(str(out / (name + ".wav")), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
        f.writeframes(struct.pack("<" + "h"*len(samples), *samples))
print("MBPD: generated twelve original, offline spoken radio clips")
