#!/usr/bin/env python3
"""Synthesises the weather sounds (all original, no samples). Writes to
assets/audio/ambience/:

Loops (seamless):
  rain_roof    rain drumming on the roof above you, heard indoors
  rain_water   raindrops plinking on the lake or the sea
  rain_leaves  fat drops falling from the forest canopy
  drips        the island dripping after the rain has stopped
  snow_wind    a soft, airy whistle while snow falls
One-shots:
  thunder      a far-off, gentle roll of thunder (never close, never startling)
  wind_gust    a gust of wind sweeping past
  snow_whump   snow sliding off a branch or a roof

Run from the project folder:  python3 tools/generate_weather_audio.py
Natural sounds only from shaped noise (no pure tones, which sound beepy).
Standard library only (uses the other generators' helpers). Deterministic (fixed seed).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_opening_audio as oa  # noqa: E402
import generate_footstep_audio as fs  # noqa: E402
import generate_village_audio as va  # noqa: E402

SR = oa.SR
TAU = oa.TAU
oa.OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambience")
rng = random.Random(9009)
for module in (fs, oa, va):
    module.rng = rng
env, white, band, add, mul, fade_tail = fs.env, fs.white, fs.band, fs.add, fs.mul, fs.fade_tail
mix_wrap = va.mix_wrap


def drop(dur, f0, f1, decay, q=0.08):
    """A water drop made from noise (no pure tones): a short burst through a narrow,
    gliding resonance, so it sounds wet rather than beepy."""
    n = int(dur * SR)
    low = bp = 0.0
    out = []
    for i in range(n):
        k = i / n
        f = 2.0 * math.sin(math.pi * (f0 + (f1 - f0) * k) / SR)
        x = (rng.random() * 2.0 - 1.0) * math.exp(-(i / SR) / (decay * 0.5))
        high = x - low - q * bp
        bp += f * high
        low += f * bp
        out.append(bp * math.exp(-(i / SR) / decay) * min(1.0, i / (0.0008 * SR)))
    return out


def tick(width_s, cutoff_lo, cutoff_hi):
    w = max(4, int(width_s * SR))
    return mul(band(white(w), cutoff_lo, cutoff_hi), [math.exp(-k / (w * 0.3)) for k in range(w)])


def looped_noise(seconds, lo, hi, fade=0.4):
    n = int(seconds * SR)
    raw = band(white(n + int(fade * SR)), lo, hi)
    return oa.crossfade_loop(raw, fade)[:n]


# ---------------------------------------------------------------- loops

def rain_roof():
    """Indoors: a steady drumming on the roof, deeper and softer than rain outside."""
    length = 9.0
    n = int(length * SR)
    buf = [0.0] * n
    for _ in range(int(length * 260)):           # many small taps on the tiles
        mix_wrap(buf, tick(rng.uniform(0.002, 0.006), 300, rng.uniform(1500, 3000)), rng.uniform(0, length), rng.uniform(0.05, 0.25))
    for _ in range(int(length * 3)):              # now and then a heavier drop from the gutter
        w = int(0.08 * SR)
        mix_wrap(buf, mul(oa.lowpass(oa.lowpass(white(w), 400), 400), env(w, 0.002, 0.02)), rng.uniform(0, length), 1.2)
    bed = looped_noise(length, 150, 900)
    return [a + 0.25 * b for a, b in zip(buf, bed)]


def rain_water():
    """Raindrops on open water: countless tiny bright plinks over a hiss."""
    length = 8.0
    n = int(length * SR)
    buf = [0.0] * n
    for _ in range(int(length * 70)):
        f = rng.uniform(900, 2600)
        mix_wrap(buf, drop(rng.uniform(0.012, 0.03), f, f * rng.uniform(1.1, 1.5), 0.008, 0.18), rng.uniform(0, length), rng.uniform(0.3, 0.9))
    hiss = looped_noise(length, 2500, 9000)
    return [a + 0.2 * b for a, b in zip(buf, hiss)]


def rain_leaves():
    """Under the trees: big, slow drops smacking leaves, with the canopy's roar above."""
    length = 10.0
    n = int(length * SR)
    buf = [0.0] * n
    for _ in range(int(length * 9)):
        mix_wrap(buf, tick(rng.uniform(0.006, 0.014), 600, rng.uniform(2500, 5000)), rng.uniform(0, length), rng.uniform(0.3, 0.8))
    roar = looped_noise(length, 500, 3000)
    roar = [v * (0.75 + 0.25 * math.sin(TAU * i / SR / (length / 2))) for i, v in enumerate(roar)]
    return [a + 0.35 * b for a, b in zip(buf, roar)]


def drips():
    """After the rain: water dripping from eaves and leaves, slow and irregular."""
    length = 12.0
    n = int(length * SR)
    buf = [0.0] * n
    for _ in range(40):
        f = rng.uniform(700, 1900)
        mix_wrap(buf, drop(rng.uniform(0.03, 0.07), f, f * rng.uniform(1.2, 1.6), 0.018, 0.12), rng.uniform(0, length), rng.uniform(0.6, 1.6))
    for _ in range(14):
        mix_wrap(buf, tick(0.008, 400, 2500), rng.uniform(0, length), 0.3)
    return buf


def snow_wind():
    """A soft, airy hush while snow falls: two bands of breathy air swelling in turn
    (pure noise, no whistle tone; the swells fit the 12 s loop)."""
    length = 12.0
    n = int(length * SR)
    air_hi = looped_noise(length, 1800, 5500, 0.5)
    air_lo = looped_noise(length, 400, 1400, 0.5)
    out = []
    for i in range(n):
        t = i / SR
        a = 0.55 + 0.45 * math.sin(TAU * t / 6.0)
        b = 0.55 + 0.45 * math.sin(TAU * t / 4.0 + 1.3)
        out.append(air_hi[i] * 0.45 * a + air_lo[i] * 0.35 * b)
    return out


# ---------------------------------------------------------------- one-shots

def thunder():
    """Far away and gentle: a low, rolling rumble with no sharp crack."""
    length = 6.5
    n = int(length * SR)
    rumble = oa.lowpass(oa.lowpass(oa.lowpass(white(n), 160), 160), 220)
    shape = []
    for i in range(n):
        t = i / SR
        rolls = 0.6 + 0.4 * math.sin(TAU * t * 0.9 + 1.0) * math.sin(TAU * t * 0.37)
        shape.append(min(1.0, t / 0.6) * math.exp(-max(0.0, t - 0.8) / 1.8) * rolls)
    body = mul(rumble, shape)
    return fade_tail(oa.reverb(body, wet=0.35)[:n], 0.6)


def wind_gust():
    length = 4.0
    n = int(length * SR)
    out = []
    chunk = int(0.02 * SR)
    src = white(n + chunk * 2)
    for c in range(0, n, chunk):
        k = c / n
        lo = 200 + 500 * math.sin(math.pi * k)
        hi = 900 + 2200 * math.sin(math.pi * k)
        out += band(src[c:c + chunk * 2], lo, hi)[chunk // 2: chunk // 2 + chunk]
    out = out[:n]
    swell = [math.sin(math.pi * i / n) ** 2 * (0.85 + 0.15 * math.sin(TAU * 1.3 * i / SR)) for i in range(n)]
    return fade_tail(mul(out, swell), 0.2)


def snow_whump():
    length = 1.4
    n = int(length * SR)
    slide = mul(band(white(n), 600, 3000), env(n, 0.25, 0.12, 0.1))
    fall = mul(oa.lowpass(white(n), 500), [0.0] * int(0.45 * SR) + env(n - int(0.45 * SR), 0.005, 0.12))
    thud = [0.0] * int(0.45 * SR) + mul(oa.lowpass(oa.lowpass(white(n - int(0.45 * SR)), 160), 160), env(n - int(0.45 * SR), 0.004, 0.1))
    return fade_tail(add((slide, 0.35), (fall, 1.0), (thud, 3.0)), 0.1)


SOUNDS = {
    "rain_roof": (rain_roof, 0.6), "rain_water": (rain_water, 0.55), "rain_leaves": (rain_leaves, 0.6),
    "drips": (drips, 0.5), "snow_wind": (snow_wind, 0.5),
    "thunder": (thunder, 0.75), "wind_gust": (wind_gust, 0.6), "snow_whump": (snow_whump, 0.6),
}


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    for name, (make, peak) in SOUNDS.items():
        oa.write_wav(name + ".wav", make(), peak)


if __name__ == "__main__":
    main()
