#!/usr/bin/env python3
"""Sound generator: synthesises the version 1 sound effects and ambience by manifest id.

Writes App/Resources/GeneratedAudio/<id>.wav (44.1 kHz, mono, 16 bit). Everything is made
from sine waves and filtered noise, so there is nothing to license. Synthesised club strikes
and crowds sound a bit thin; free CC0 recordings are the upgrade if that bothers us (log them).

Standard library only:  python3 art/audio.py   (or: make assets)
"""

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources", "GeneratedAudio")
RATE = 44100


# ---------- building blocks ----------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def noise(seconds, rng):
    return [rng.uniform(-1, 1) for _ in range(int(seconds * RATE))]


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def bandpass(samples, low, high):
    return lowpass(highpass(samples, low), high)


def envelope(samples, attack, decay, curve=4.0):
    """Quick attack, exponential decay over `decay` seconds."""
    out = []
    a, d = max(1, int(attack * RATE)), max(1, int(decay * RATE))
    for i, x in enumerate(samples):
        if i < a:
            g = i / a
        else:
            g = math.exp(-curve * (i - a) / d)
        out.append(x * g)
    return out


def tone(freq, seconds, sweep_to=None, phase=0.0):
    n = int(seconds * RATE)
    out, p = [], phase
    for i in range(n):
        f = freq if sweep_to is None else freq + (sweep_to - freq) * i / n
        p += 2 * math.pi * f / RATE
        out.append(math.sin(p))
    return out


def mix(*tracks):
    n = max(len(t) for t, _ in tracks)
    out = [0.0] * n
    for t, gain in tracks:
        for i, x in enumerate(t):
            out[i] += x * gain
    return out


def place(track, clip, at, gain=1.0):
    start = int(at * RATE)
    if start + len(clip) > len(track):
        track.extend([0.0] * (start + len(clip) - len(track)))
    for i, x in enumerate(clip):
        track[start + i] += x * gain


def normalise(samples, peak=0.85):
    top = max(1e-9, max(abs(x) for x in samples))
    return [x * peak / top for x in samples]


def fade_ends(samples, seconds=0.004):
    n = int(seconds * RATE)
    for i in range(min(n, len(samples))):
        samples[i] *= i / n
        samples[-1 - i] *= i / n
    return samples


def seamless(samples, overlap_seconds=1.0):
    """Crossfades the end into the start so the file loops without a click."""
    n = int(overlap_seconds * RATE)
    body, tail = samples[:-n], samples[-n:]
    for i in range(n):
        g = i / n
        body[i] = body[i] * g + tail[i] * (1 - g)
    return body


def write(name, samples, peak=0.85, loop=False):
    samples = normalise(samples, peak)
    if not loop:
        samples = fade_ends(samples)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in samples))


# ---------- sound effects ----------

def strike(rng, ping, whoosh_cutoff, length):
    click = envelope(highpass(noise(0.02, rng), 3000), 0.0005, 0.006)
    ring = envelope(mix((tone(ping, 0.12), 1.0), (tone(ping * 2.7, 0.12), 0.35)), 0.0005, 0.04)
    whoosh = envelope(bandpass(noise(length, rng), 400, whoosh_cutoff), 0.06, length * 0.6, curve=3)
    out = silence(0.0)
    place(out, whoosh, 0.0, 0.25)
    place(out, click, 0.12, 1.0)
    place(out, ring, 0.12, 0.5)
    return out


def sfx(rng):
    write("sfx_drive", strike(rng, 2300, 2500, 0.35))
    write("sfx_iron", strike(rng, 3100, 3500, 0.25))
    wedge = strike(rng, 3600, 3000, 0.18)
    place(wedge, envelope(bandpass(noise(0.15, rng), 200, 1200), 0.002, 0.08), 0.12, 0.6)  # a bit of turf
    write("sfx_wedge", wedge)
    write("sfx_putt", mix((envelope(tone(820, 0.15), 0.0005, 0.03), 1.0),
                          (envelope(lowpass(noise(0.05, rng), 900), 0.0005, 0.01), 0.4)))

    cup = silence(0.0)
    for at, f, g in [(0.0, 1500, 1.0), (0.11, 1350, 0.7), (0.19, 1250, 0.5), (0.24, 1100, 0.35)]:
        place(cup, envelope(mix((tone(f, 0.08), 1.0), (tone(f * 2.3, 0.08), 0.3)), 0.0005, 0.02), at, g)
    place(cup, envelope(lowpass(noise(0.12, rng), 600), 0.002, 0.05), 0.27, 0.5)
    write("sfx_cup", cup)

    splash_body = bandpass(noise(0.9, rng), 300, 3500)
    bubbles = [x * (0.6 + 0.4 * math.sin(i / RATE * 2 * math.pi * 18)) for i, x in enumerate(splash_body)]
    write("sfx_splash", envelope(bubbles, 0.004, 0.45, curve=3.5))
    write("sfx_sand", envelope(bandpass(noise(0.4, rng), 500, 5000), 0.003, 0.2, curve=3))

    trees = silence(0.7)
    for _ in range(14):
        place(trees, envelope(bandpass(noise(0.03, rng), 800, 4000), 0.0005, 0.01), rng.uniform(0, 0.6), rng.uniform(0.4, 1))
    write("sfx_trees", trees)

    claps = silence(2.8)
    for _ in range(90):
        at = rng.uniform(0, 2.2) ** 1.2
        place(claps, envelope(bandpass(noise(0.025, rng), 900, 3500), 0.0005, 0.008), at, rng.uniform(0.3, 1))
    write("sfx_applause_polite", envelope(claps, 0.15, 2.4, curve=2))

    write("sfx_ui_tap", envelope(tone(1900, 0.03), 0.0005, 0.01))
    chime = silence(0.0)
    place(chime, envelope(tone(880, 0.3), 0.002, 0.12), 0.0, 0.8)
    place(chime, envelope(tone(1320, 0.4), 0.002, 0.15), 0.08, 0.8)
    write("sfx_ui_confirm", chime)
    write("sfx_ui_error", envelope(mix((tone(220, 0.25), 1.0), (tone(233, 0.25), 1.0)), 0.003, 0.12))

    till = silence(0.0)
    place(till, envelope(lowpass(noise(0.18, rng), 1500), 0.005, 0.08), 0.0, 0.5)  # drawer
    bell = mix((tone(2637, 0.9), 1.0), (tone(5274, 0.9), 0.3), (tone(3950, 0.9), 0.15))
    place(till, envelope(bell, 0.001, 0.35), 0.12, 0.7)
    write("sfx_till", till)

    write("sfx_build_paint", envelope(bandpass(noise(0.2, rng), 150, 1500), 0.01, 0.1))


# ---------- ambience (20 second seamless loops) ----------

def ambience(rng):
    length = 21.0
    wind = lowpass(noise(length, rng), 500)
    wind = [x * (0.55 + 0.45 * math.sin(i / RATE * 2 * math.pi / 7.0) ** 2) for i, x in enumerate(wind)]
    write("amb_wind", seamless(wind), peak=0.5, loop=True)

    sea = lowpass(noise(length, rng), 900)
    sea = [x * (0.25 + 0.75 * max(0.0, math.sin(i / RATE * 2 * math.pi / 5.0)) ** 3) for i, x in enumerate(sea)]
    write("amb_sea", seamless(sea), peak=0.55, loop=True)

    birds = [x * 0.15 for x in lowpass(noise(length, rng), 300)]
    t = 0.3
    while t < length - 2:
        base = rng.uniform(2500, 4500)
        for k in range(rng.randint(2, 6)):
            chirp = envelope(tone(base, 0.07, sweep_to=base * rng.uniform(1.15, 1.5)), 0.005, 0.04)
            place(birds, chirp, t + k * rng.uniform(0.09, 0.14), rng.uniform(0.25, 0.6))
        t += rng.uniform(0.6, 2.4)
    write("amb_birdsong", seamless(birds), peak=0.45, loop=True)


def main():
    rng = random.Random(1874)
    sfx(rng)
    ambience(rng)
    print("Sounds written to", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
