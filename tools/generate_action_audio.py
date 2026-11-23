#!/usr/bin/env python3
"""Synthesises the fishing and farming action sounds (all original, no samples).

Fishing: rod_out, rod_away, cast_swish, reel_click, drag_click, bobber_plop, bite_plunk,
fish_splash, catch_splash, catch_jingle, line_snap, fish_escape, line_strain (loop).
Farming: dig, plant, water_pour (loop), fertilize, harvest, harvest_jingle, seed_rattle.

Run from the project folder:  python3 tools/generate_action_audio.py
Writes to assets/audio/actions/. Standard library only (uses the helpers in
generate_opening_audio.py and generate_footstep_audio.py). Deterministic (fixed seed).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_opening_audio as oa  # noqa: E402
import generate_footstep_audio as fs  # noqa: E402

SR = oa.SR
TAU = oa.TAU
oa.OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "actions")
rng = random.Random(5005)
fs.rng = rng
env, white, band, thump, crackles, add, mul, fade_tail = (
    fs.env, fs.white, fs.band, fs.thump, fs.crackles, fs.add, fs.mul, fs.fade_tail)


def silence(seconds):
    return [0.0] * int(seconds * SR)


def at(buf, sound, start_s, gain=1.0):
    oa.mix_into(buf, sound, start_s, gain)
    return buf


def sweep_noise(n, lo0, hi0, lo1, hi1, attack, decay, hold=0.0):
    """Band-passed noise whose band glides (a whoosh), built from short chunks."""
    out = []
    chunk = int(0.02 * SR)
    src = white(n + chunk)
    for c in range(0, n, chunk):
        k = c / max(1, n)
        lo = lo0 + (lo1 - lo0) * k
        hi = hi0 + (hi1 - hi0) * k
        out += band(src[c:c + chunk * 2], lo, hi)[chunk // 2: chunk // 2 + chunk]
    return mul(out[:n], env(n, attack, decay, hold))


def chirp(dur, f0, f1, decay):
    """A sine gliding from f0 to f1: the 'bloop' of a drop of water."""
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        k = i / n
        phase += TAU * (f0 + (f1 - f0) * k * k) / SR
        out.append(math.sin(phase) * math.exp(-(i / SR) / decay) * min(1.0, i / (0.002 * SR)))
    return out


def droplets(n, count, start, spread, lo=900, hi=2600):
    buf = [0.0] * n
    for _ in range(count):
        s = start + rng.uniform(0.0, spread)
        f = rng.uniform(lo, hi)
        oa.mix_into(buf, chirp(rng.uniform(0.02, 0.05), f, f * rng.uniform(1.3, 1.9), 0.015), s, rng.uniform(0.1, 0.35))
    return buf[:n]


# ---------------------------------------------------------------- fishing

def rod_out():
    n = int(0.45 * SR)
    rustle = mul(band(white(n), 1500, 6000), env(n, 0.04, 0.08, 0.05))
    tap = [0.0] * n
    for f, a, d in ((420, 0.5, 0.03), (1050, 0.25, 0.015)):
        for i in range(int(0.16 * SR), n):
            t = i / SR - 0.16
            tap[i] += a * math.sin(TAU * f * t) * math.exp(-t / d)
    return fade_tail(add((rustle, 0.45), (tap, 0.8)))


def rod_away():
    n = int(0.45 * SR)
    rustle = mul(band(white(n), 1200, 5000), env(n, 0.06, 0.1, 0.04))
    tap = [0.0] * n
    for f, a, d in ((360, 0.5, 0.035), (900, 0.2, 0.015)):
        for i in range(int(0.22 * SR), n):
            t = i / SR - 0.22
            tap[i] += a * math.sin(TAU * f * t) * math.exp(-t / d)
    return fade_tail(add((rustle, 0.45), (tap, 0.7)))


def cast_swish():
    n = int(0.55 * SR)
    whoosh = sweep_noise(n, 300, 900, 1800, 5500, 0.12, 0.12, 0.05)
    whistle = []
    phase = 0.0
    for i in range(n):
        k = i / n
        phase += TAU * (900 + 900 * k) / SR
        whistle.append(math.sin(phase) * math.sin(math.pi * k) ** 2)
    return fade_tail(add((whoosh, 1.0), (whistle, 0.04)))


def reel_click():
    n = int(0.03 * SR)
    tick = mul(band(white(n), 2500, 9000), env(n, 0.0005, 0.003))
    ring = [math.sin(TAU * 3100 * i / SR) * math.exp(-(i / SR) / 0.004) for i in range(n)]
    return fade_tail(add((tick, 1.0), (ring, 0.35)), 0.005)


def drag_click():
    n = int(0.04 * SR)
    tick = mul(band(white(n), 1200, 5000), env(n, 0.0008, 0.005))
    ring = [math.sin(TAU * 1700 * i / SR) * math.exp(-(i / SR) / 0.006) for i in range(n)]
    return fade_tail(add((tick, 1.0), (ring, 0.45)), 0.005)


def bobber_plop():
    n = int(0.5 * SR)
    buf = [0.0] * n
    at(buf, chirp(0.09, 380, 1100, 0.03), 0.0, 0.8)
    at(buf, mul(band(white(n), 600, 3500), env(n, 0.004, 0.05)), 0.0, 0.5)
    at(buf, droplets(n, 5, 0.06, 0.2), 0.0, 0.8)
    return fade_tail(buf)


def bite_plunk():
    n = int(0.45 * SR)
    buf = [0.0] * n
    at(buf, chirp(0.12, 220, 640, 0.045), 0.0, 1.0)
    at(buf, chirp(0.08, 300, 800, 0.03), 0.11, 0.6)
    at(buf, mul(band(white(n), 400, 2500), env(n, 0.005, 0.06)), 0.0, 0.45)
    return fade_tail(buf)


def fish_splash():
    n = int(0.6 * SR)
    buf = [0.0] * n
    for k in range(3):
        s = k * rng.uniform(0.07, 0.12)
        at(buf, mul(band(white(n), 500, 3800), env(n, 0.008, 0.06)), s, rng.uniform(0.5, 0.9))
        at(buf, chirp(0.07, rng.uniform(250, 400), rng.uniform(700, 1000), 0.025), s, 0.4)
    at(buf, droplets(n, 8, 0.05, 0.35), 0.0, 0.8)
    return fade_tail(buf)


def catch_splash():
    n = int(1.0 * SR)
    buf = [0.0] * n
    at(buf, sweep_noise(n, 300, 2000, 800, 6000, 0.03, 0.15, 0.03), 0.0, 1.0)
    at(buf, chirp(0.12, 200, 700, 0.05), 0.0, 0.6)
    at(buf, thump(n, 80, 0.05), 0.0, 0.3)
    at(buf, droplets(n, 22, 0.15, 0.6, 1000, 3200), 0.0, 1.0)
    return fade_tail(oa.reverb(buf, wet=0.15)[:n])


def jingle(notes, step, dur=0.9):
    """A little rising pluck-and-bell flourish."""
    total = step * len(notes) + dur
    buf = silence(total)
    for k, m in enumerate(notes):
        at(buf, oa.pluck(oa.midi_hz(m), dur, 0.7, 0.995), k * step, 0.5)
        at(buf, oa.chime_strike(oa.midi_hz(m + 12), dur), k * step, 0.12)
    return fade_tail(oa.reverb(buf, wet=0.2)[:len(buf)], 0.1)


def line_snap():
    n = int(0.7 * SR)
    buf = [0.0] * n
    at(buf, mul(band(white(n), 2000, 9000), env(n, 0.0005, 0.01)), 0.0, 1.0)
    tw = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 520 * math.exp(-t * 3.0) + 140
        phase += TAU * f / SR
        tw.append((math.sin(phase) + 0.3 * math.sin(3 * phase)) * math.exp(-t / 0.18))
    at(buf, tw, 0.005, 0.5)
    return fade_tail(buf)


def fish_escape():
    n = int(0.55 * SR)
    buf = [0.0] * n
    at(buf, mul(band(white(n), 500, 2500), env(n, 0.02, 0.09)), 0.0, 0.6)
    at(buf, chirp(0.1, 300, 900, 0.04), 0.03, 0.4)
    at(buf, droplets(n, 4, 0.08, 0.25), 0.0, 0.6)
    return fade_tail(buf)


def line_strain():
    """A taut line humming and creaking: seamless 2 s loop (every tone fits the loop)."""
    length = 2.0
    n = int(length * SR)

    def fit(f):
        return round(f * length) / length

    out = []
    for i in range(n):
        t = i / SR
        wob = 0.6 + 0.4 * math.sin(TAU * t * 2.5)
        v = 0.5 * math.sin(TAU * fit(330) * t + 0.8 * math.sin(TAU * fit(6.5) * t))
        v += 0.25 * math.sin(TAU * fit(661) * t) + 0.12 * math.sin(TAU * fit(990) * t)
        out.append(v * wob)
    grit = band(white(n), 1500, 4000)
    grit = oa.crossfade_loop(grit + grit[: int(0.1 * SR)], 0.1)[:n]
    return [a + 0.12 * g for a, g in zip(out, grit)]


# ---------------------------------------------------------------- farming

def dig():
    n = int(0.6 * SR)
    buf = [0.0] * n
    at(buf, mul(band(white(n), 2000, 7000), env(n, 0.001, 0.012)), 0.0, 0.5)   # blade bites
    at(buf, thump(n, 95, 0.06), 0.0, 0.9)
    at(buf, mul(band(white(n), 250, 1500), env(n, 0.01, 0.08)), 0.0, 0.8)     # soil heaves
    at(buf, crackles(n, 40, 0.12, 0.12, cutoff=4000), 0.0, 0.45)              # crumbs fall
    return fade_tail(buf)


def plant():
    n = int(0.7 * SR)
    buf = [0.0] * n
    at(buf, crackles(n, 18, 0.0, 0.05, cutoff=6000), 0.0, 0.35)               # seeds drop
    for s in (0.2, 0.42):                                                     # two pats
        at(buf, thump(n, 120, 0.03), s, 0.6)
        at(buf, mul(band(white(n), 300, 1800), env(n, 0.003, 0.03)), s, 0.5)
    return fade_tail(buf)


def water_pour():
    """Water sprinkling onto leaves and soil: seamless 1.5 s loop."""
    length = 1.5
    n = int(length * SR)
    pad = int(0.15 * SR)
    m = n + pad
    hiss = band(white(m), 900, 5500)
    hiss = [h * (0.8 + 0.2 * math.sin(TAU * 7 * i / SR)) for i, h in enumerate(hiss)]
    drops = droplets(m, 60, 0.0, length + 0.1, 700, 2400)
    patter = crackles(m, 120, 0.0, length * 0.6, width_s=0.001, cutoff=5000)
    body = add((hiss, 0.5), (drops, 0.9), (patter, 0.3))
    return oa.crossfade_loop(body, 0.15)[:n]


def fertilize():
    n = int(0.7 * SR)
    buf = [0.0] * n
    at(buf, crackles(n, 160, 0.03, 0.18, width_s=0.0012, cutoff=6500), 0.0, 0.8)
    at(buf, mul(band(white(n), 2000, 6000), env(n, 0.04, 0.15, 0.1)), 0.0, 0.25)
    return fade_tail(buf)


def harvest():
    n = int(0.75 * SR)
    buf = [0.0] * n
    at(buf, sweep_noise(int(0.25 * SR), 200, 900, 600, 2500, 0.15, 0.03), 0.0, 0.7)  # roots tear
    at(buf, crackles(n, 30, 0.05, 0.08, cutoff=3500), 0.0, 0.4)
    at(buf, chirp(0.06, 260, 520, 0.02), 0.24, 0.6)                                  # pop!
    at(buf, mul(band(white(n), 1500, 6000), env(n, 0.02, 0.09)), 0.26, 0.4)          # leaves
    at(buf, crackles(n, 25, 0.3, 0.12, cutoff=4000), 0.0, 0.35)                     # soil shakes off
    return fade_tail(buf)


def seed_rattle():
    n = int(0.45 * SR)
    buf = [0.0] * n
    for s in (0.0, 0.16):
        at(buf, crackles(n, 30, 0.0, 0.03, width_s=0.0009, cutoff=7000), s, 0.7)
        at(buf, mul(band(white(n), 2500, 7000), env(n, 0.01, 0.04)), s, 0.2)
    return fade_tail(buf)


SOUNDS = {
    "rod_out": (rod_out, 0.6), "rod_away": (rod_away, 0.6), "cast_swish": (cast_swish, 0.7),
    "reel_click": (reel_click, 0.5), "drag_click": (drag_click, 0.55),
    "bobber_plop": (bobber_plop, 0.7), "bite_plunk": (bite_plunk, 0.8),
    "fish_splash": (fish_splash, 0.75), "catch_splash": (catch_splash, 0.85),
    "catch_jingle": (lambda: jingle([67, 71, 74, 79], 0.09), 0.6),
    "line_snap": (line_snap, 0.75), "fish_escape": (fish_escape, 0.65),
    "line_strain": (line_strain, 0.5),
    "dig": (dig, 0.8), "plant": (plant, 0.7), "water_pour": (water_pour, 0.6),
    "fertilize": (fertilize, 0.6), "harvest": (harvest, 0.75),
    "harvest_jingle": (lambda: jingle([72, 76, 79], 0.1), 0.55), "seed_rattle": (seed_rattle, 0.6),
}


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    for name, (make, peak) in SOUNDS.items():
        oa.write_wav(name + ".wav", make(), peak)


if __name__ == "__main__":
    main()
