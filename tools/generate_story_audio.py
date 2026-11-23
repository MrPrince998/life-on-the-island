#!/usr/bin/env python3
"""Synthesises the story-moment sounds (all original, no samples).

Story stings: shard_found (a Glowstone shard), memory_found (a page of Grandpa's journal),
restored (a building repaired), world_change (a path cleared, an orchard planted),
bloom (the great oak grown back), market_bell (Market Day), glow (magic awakening),
lighthouse_lit (the finale), gift (an important gift: Oliver's rod).
Work swings: work_hammer, work_wood, work_stone, work_brush.

Run from the project folder:  python3 tools/generate_story_audio.py
Writes to assets/audio/story/. Standard library only (uses the helpers in
generate_opening_audio.py, generate_footstep_audio.py and generate_ui_audio.py).
Deterministic (fixed seed).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_opening_audio as oa  # noqa: E402
import generate_footstep_audio as fs  # noqa: E402
import generate_ui_audio as ui  # noqa: E402

SR = oa.SR
TAU = oa.TAU
oa.OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "story")
rng = random.Random(7007)
fs.rng = rng
oa.rng = rng
ui.rng = rng
env, white, band, add, mul, fade_tail, thump, crackles = (
    fs.env, fs.white, fs.band, fs.add, fs.mul, fs.fade_tail, fs.thump, fs.crackles)
marimba, bell, m, at, silence = ui.marimba, ui.bell, ui.m, ui.at, ui.silence


def pad(notes, dur, attack=0.6, release=1.2, bright=0.3):
    """A soft, slow-breathing chord (like a quiet choir or strings)."""
    n = int(dur * SR)
    out = [0.0] * n
    for note in notes:
        f = m(note)
        for detune in (0.997, 1.003):
            ph = rng.uniform(0, TAU)
            for i in range(n):
                t = i / SR
                out[i] += (math.sin(TAU * f * detune * t + ph) + bright * math.sin(TAU * 2 * f * detune * t)) * 0.5
    a, r = int(attack * SR), int(release * SR)
    for i in range(n):
        g = min(1.0, i / a) * min(1.0, (n - i) / r)
        out[i] *= g / len(notes)
    return oa.lowpass(out, 3500)


def shimmer(dur, lo=2000, hi=9000, rise=True):
    """Airy glitter: high noise breathing up (or down), with tiny bell sparkles."""
    n = int(dur * SR)
    air = mul(band(white(n), lo, hi), [((i / n) if rise else (1 - i / n)) ** 1.5 * math.sin(math.pi * i / n) for i in range(n)])
    sparkle = [0.0] * n
    for _ in range(int(dur * 14)):
        s = rng.uniform(0.0, dur * 0.85)
        at(sparkle, bell(m(rng.choice((96, 98, 100, 103, 105, 108))), 0.5), s, rng.uniform(0.02, 0.07))
    return add((air, 0.25), (sparkle[:n], 1.0))


def finish(buf, wet=0.3):
    return fade_tail(oa.reverb(buf, wet=wet)[:len(buf)], 0.3)


# ---------------------------------------------------------------- stings

def shard_found():
    buf = silence(3.2)
    at(buf, shimmer(1.4), 0.0, 1.0)
    at(buf, pad([62, 69, 74, 78], 3.0, 0.3, 1.6), 0.1, 0.8)
    for k, note in enumerate((74, 78, 81, 86, 90)):
        at(buf, bell(m(note), 1.8), 0.25 + k * 0.11, 0.22)
    return finish(buf, 0.35)


def memory_found():
    """A music box playing a few wistful notes over a warm chord."""
    buf = silence(3.6)
    at(buf, ui.page(), 0.0, 0.5)
    at(buf, pad([50, 57, 62, 66], 3.4, 0.8, 1.6, 0.2), 0.15, 0.55)
    phrase = [(81, 0.3), (78, 0.62), (74, 0.94), (76, 1.26), (78, 1.58), (73, 1.9), (74, 2.3)]
    for note, s in phrase:
        at(buf, bell(m(note), 1.4), s, 0.28)
        at(buf, marimba(m(note + 12), 0.25, 0.3), s, 0.08)
    return finish(buf, 0.35)


def restored():
    buf = silence(3.4)
    for k, s in enumerate((0.0, 0.22, 0.44)):            # three last taps of the hammer
        at(buf, work_hammer(), s, 0.5 + 0.1 * k)
    at(buf, pad([55, 62, 67, 71, 74], 2.8, 0.25, 1.5, 0.4), 0.6, 0.7)
    for k, note in enumerate((67, 71, 74, 79)):           # a strummed "ta-da"
        at(buf, oa.pluck(m(note), 2.2, 0.6, 0.997), 0.62 + k * 0.035, 0.35)
    at(buf, bell(m(86), 2.0), 0.66, 0.18)
    at(buf, bell(m(91), 2.0), 0.8, 0.12)
    return finish(buf, 0.3)


def world_change():
    buf = silence(2.8)
    rustle = mul(band(white(int(1.0 * SR)), 1200, 6000), env(int(1.0 * SR), 0.15, 0.25))
    at(buf, rustle, 0.0, 0.35)
    at(buf, shimmer(1.6), 0.15, 0.8)
    at(buf, pad([60, 67, 72, 76], 2.4, 0.4, 1.3), 0.2, 0.6)
    for k, note in enumerate((72, 76, 79, 84)):
        at(buf, marimba(m(note), 0.5), 0.3 + k * 0.1, 0.35)
    return finish(buf, 0.3)


def bloom():
    """The great oak grows back: rising chord, birdsong, leaves."""
    buf = silence(4.2)
    at(buf, pad([53, 60, 65, 69, 72], 3.8, 1.0, 1.8, 0.35), 0.0, 0.9)
    at(buf, shimmer(2.4), 0.4, 0.8)
    leaves = mul(band(white(int(2.5 * SR)), 1500, 7000), env(int(2.5 * SR), 0.8, 0.5, 0.4))
    at(buf, leaves, 0.2, 0.25)
    for _ in range(6):                                   # birds join in
        s = rng.uniform(1.0, 3.2)
        f0 = rng.uniform(2600, 3800)
        chirp = []
        ph = 0.0
        d = rng.uniform(0.06, 0.12)
        for i in range(int(d * SR)):
            k = i / (d * SR)
            ph += TAU * f0 * (1 + 0.3 * math.sin(math.pi * k)) / SR
            chirp.append(math.sin(ph) * math.sin(math.pi * k))
        for rep in range(rng.randint(2, 4)):
            at(buf, chirp, s + rep * 0.13, 0.1)
    for k, note in enumerate((77, 81, 84, 89)):
        at(buf, bell(m(note), 2.0), 0.9 + k * 0.16, 0.16)
    return finish(buf, 0.3)


def handbell(hz, dur=2.2):
    n = int(dur * SR)
    parts = ((1.0, 1.0, 1.4), (2.0, 0.5, 1.0), (2.4, 0.4, 0.8), (3.0, 0.25, 0.6), (4.1, 0.15, 0.4))
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for ratio, amp, decay in parts:
            v += amp * math.sin(TAU * hz * ratio * t) * math.exp(-t / decay)
        out.append(v * min(1.0, i / (0.002 * SR)))
    return out


def market_bell():
    buf = silence(3.6)
    for k, (s, note) in enumerate(((0.0, 79), (0.35, 74), (0.7, 79), (1.05, 74), (1.4, 83))):
        at(buf, handbell(m(note)), s, 0.4)
    at(buf, pad([55, 62, 67, 71], 2.6, 0.3, 1.3), 0.9, 0.45)
    return finish(buf, 0.3)


def glow():
    buf = silence(3.0)
    n = int(2.6 * SR)
    hum = []
    for i in range(n):
        t = i / SR
        f = 110 + 110 * min(1.0, t / 1.8)
        hum.append(math.sin(TAU * f * t) * min(1.0, t / 1.0) * min(1.0, (n - i) / (0.8 * SR)))
    at(buf, hum, 0.0, 0.25)
    at(buf, shimmer(2.2), 0.2, 0.9)
    at(buf, pad([57, 64, 69, 76], 2.6, 0.9, 1.2), 0.1, 0.55)
    return finish(buf, 0.4)


def lighthouse_lit():
    """The finale: a deep swell, the lamp catching light, and a big warm chord."""
    buf = silence(6.5)
    n = int(1.6 * SR)
    swell = []
    for i in range(n):
        t = i / SR
        swell.append((math.sin(TAU * 55 * t) + 0.5 * math.sin(TAU * 82.5 * t)) * (t / 1.6) ** 2)
    at(buf, swell, 0.0, 0.5)
    whoosh = mul(band(white(n), 500, 5000), [(i / n) ** 3 for i in range(n)])
    at(buf, whoosh, 0.0, 0.3)
    at(buf, thump(int(1.0 * SR), 70, 0.3), 1.6, 0.7)    # the lamp catches
    at(buf, pad([50, 57, 62, 66, 69, 74], 4.6, 0.15, 2.6, 0.45), 1.6, 1.0)
    for k, note in enumerate((62, 66, 69, 74, 78, 81)):
        at(buf, oa.pluck(m(note), 3.0, 0.6, 0.998), 1.62 + k * 0.04, 0.3)
    for k, note in enumerate((86, 90, 93, 98)):
        at(buf, bell(m(note), 3.0), 1.7 + k * 0.22, 0.18)
    at(buf, shimmer(3.5), 1.8, 0.8)
    return finish(buf, 0.35)


def gift():
    buf = silence(2.4)
    for k, note in enumerate((67, 72, 76, 79)):
        at(buf, marimba(m(note), 0.6), k * 0.1, 0.5)
    at(buf, pad([60, 67, 72, 76], 2.0, 0.2, 1.2), 0.3, 0.5)
    at(buf, bell(m(88), 1.6), 0.4, 0.2)
    return finish(buf, 0.25)


# ---------------------------------------------------------------- work swings

def work_hammer():
    n = int(0.4 * SR)
    knock = [0.0] * n
    for f, a, d in ((rng.uniform(380, 440), 0.8, 0.05), (rng.uniform(950, 1100), 0.4, 0.02), (2300, 0.25, 0.008)):
        for i in range(n):
            t = i / SR
            knock[i] += a * math.sin(TAU * f * t) * math.exp(-t / d)
    clack = mul(band(white(n), 1500, 8000), env(n, 0.0005, 0.006))
    return fade_tail(add((knock, 0.9), (clack, 0.5), (thump(n, 140, 0.03), 0.4)))


def work_wood():
    n = int(0.55 * SR)
    buf = [0.0] * n
    at(buf, mul(band(white(n), 1500, 6000), env(n, 0.0008, 0.01)), 0.0, 0.7)   # a branch snaps
    for k in range(4):                                                         # sticks clatter
        f = rng.uniform(500, 900)
        s = 0.06 + k * rng.uniform(0.05, 0.09)
        stick = [math.sin(TAU * f * i / SR) * math.exp(-(i / SR) / 0.02) for i in range(int(0.08 * SR))]
        at(buf, stick, s, 0.35)
    at(buf, mul(band(white(n), 1000, 5000), env(n, 0.01, 0.08)), 0.03, 0.3)
    return fade_tail(buf)


def work_stone():
    n = int(0.5 * SR)
    buf = [0.0] * n
    at(buf, mul(band(white(n), 3000, 9000), env(n, 0.0005, 0.006)), 0.0, 0.9)
    for f, a, d in ((rng.uniform(1600, 1900), 0.4, 0.03), (rng.uniform(2700, 3100), 0.25, 0.02)):
        at(buf, [a * math.sin(TAU * f * i / SR) * math.exp(-(i / SR) / d) for i in range(n)], 0.0, 1.0)
    at(buf, crackles(n, 25, 0.05, 0.08, cutoff=6000), 0.0, 0.5)               # chips fall
    at(buf, thump(n, 120, 0.03), 0.0, 0.4)
    return fade_tail(buf)


def work_brush():
    n = int(0.55 * SR)
    buf = [0.0] * n
    at(buf, mul(band(white(n), 1500, 6500), env(n, 0.04, 0.09)), 0.0, 0.7)
    at(buf, crackles(n, 20, 0.04, 0.1, cutoff=7000), 0.0, 0.45)               # twigs snip
    return fade_tail(buf)


SOUNDS = {
    "shard_found": (shard_found, 0.7), "memory_found": (memory_found, 0.65), "restored": (restored, 0.75),
    "world_change": (world_change, 0.65), "bloom": (bloom, 0.7), "market_bell": (market_bell, 0.65),
    "glow": (glow, 0.65), "lighthouse_lit": (lighthouse_lit, 0.8), "gift": (gift, 0.65),
    "work_hammer": (work_hammer, 0.7), "work_wood": (work_wood, 0.65), "work_stone": (work_stone, 0.6),
    "work_brush": (work_brush, 0.6),
}


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    for name, (make, peak) in SOUNDS.items():
        oa.write_wav(name + ".wav", make(), peak)


if __name__ == "__main__":
    main()
