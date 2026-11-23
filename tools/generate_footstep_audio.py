#!/usr/bin/env python3
"""Synthesises the footstep sounds (all original, no samples): four variations each for
grass, dirt (earth paths), sand, wood (docks, jetty, bridge, floors), stone, shallow water
and snow. Files are named <surface>_<n>.wav, e.g. grass_1.wav. Built only from shaped noise
(no sine tones) with a heel-then-toe double touch, so the steps sound soft and natural.

Run from the project folder:  python3 tools/generate_footstep_audio.py
Writes to assets/audio/footsteps/. Standard library only (uses the helpers in
generate_opening_audio.py). Deterministic (fixed seed).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_opening_audio as oa  # noqa: E402

SR = oa.SR
TAU = oa.TAU
oa.OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "footsteps")
rng = random.Random(4004)
VARIANTS = 4


def env(n, attack, decay, hold=0.0):
    """Quick rise, optional hold, then an exponential fall (times in seconds)."""
    a = max(1, int(attack * SR))
    h = int(hold * SR)
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i < a + h:
            out.append(1.0)
        else:
            out.append(math.exp(-(i - a - h) / (decay * SR)))
    return out


def white(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def band(samples, lo, hi):
    return oa.lowpass(oa.lowpass(oa.highpass(samples, lo), hi), hi)


def thump(n, hz, decay, drop=0.4):
    """A soft low body thud: a sine that sags in pitch as it dies away."""
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = hz * (1.0 - drop * min(1.0, t / 0.06))
        phase += TAU * f / SR
        out.append(math.sin(phase) * math.exp(-t / decay))
    return out


def crackles(n, count, start, spread, width_s=0.0015, cutoff=5000):
    """Scattered tiny clicks: grit, dry stems, grains of snow."""
    buf = [0.0] * n
    w = max(2, int(width_s * SR))
    for _ in range(count):
        at = int((start + abs(rng.gauss(0.0, spread))) * SR)
        g = rng.uniform(0.3, 1.0) * rng.choice((-1, 1))
        for k in range(w):
            if at + k < n:
                buf[at + k] += g * math.exp(-k / (w * 0.35)) * rng.uniform(0.4, 1.0)
    return oa.lowpass(buf, cutoff)


def add(*layers):
    n = max(len(layer) for layer, _ in layers)
    out = [0.0] * n
    for layer, gain in layers:
        for i, s in enumerate(layer):
            out[i] += s * gain
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def fade_tail(samples, fade_s=0.02):
    f = int(fade_s * SR)
    n = len(samples)
    for i in range(f):
        samples[n - f + i] *= 1.0 - i / f
    return samples


# ---------------------------------------------------------------- natural-step helpers
# The footsteps below are built only from shaped noise: no pure sine tones, which made
# the old steps sound beepy. (thump() and the helpers above stay as they were: the other
# generators import them.)

def norm(samples):
    """Scale to a peak of 1 so layers can be mixed by their gains alone."""
    top = max(1e-9, max(abs(s) for s in samples))
    return [s / top for s in samples]


def smooth(samples, cutoff, passes=3):
    """A steeper low-pass: several gentle passes in a row."""
    for _ in range(passes):
        samples = oa.lowpass(samples, cutoff)
    return samples


def resonate(samples, hz, q):
    """Band-pass with a low Q: gives noise a hollow 'body' colour without becoming a note."""
    w0 = TAU * hz / SR
    alpha = math.sin(w0) / (2.0 * q)
    a0 = 1.0 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2.0 * math.cos(w0) / a0, (1.0 - alpha) / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in samples:
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def thud(n, cutoff, decay, attack=0.003):
    """The weight of the foot: a burst of deep, muffled noise (no pitch)."""
    return norm(mul(smooth(white(n), cutoff, 4), env(n, attack, decay)))


def shifted(samples, delay_s, n):
    """The same sound starting later, cut to n samples."""
    d = int(delay_s * SR)
    return ([0.0] * d + samples)[:n]


def heel_toe(n, make):
    """A real step is two touches: the heel, then the ball of the foot a moment later."""
    heel = make(n)
    toe = make(n)
    gap = rng.uniform(0.045, 0.085)
    return add((heel, 1.0), (shifted(toe, gap, n), rng.uniform(0.45, 0.65)))


def finish(samples):
    """Round off harsh top end and the tail."""
    return fade_tail(smooth(samples, 7000, 1))


# ---------------------------------------------------------------- surfaces

def grass():
    n = int(0.34 * SR)

    def touch(m):
        swish = norm(mul(band(white(m), 700, 3800), env(m, 0.02, 0.06, 0.015)))
        stems = norm(crackles(m, rng.randint(5, 9), 0.012, 0.035, cutoff=3500))
        return add((thud(m, 160, 0.03), 0.55), (swish, 0.6), (stems, 0.15))
    return finish(heel_toe(n, touch))


def dirt():
    n = int(0.28 * SR)

    def touch(m):
        scuff = norm(mul(band(white(m), 250, 1400), env(m, 0.006, 0.04)))
        grit = norm(crackles(m, rng.randint(8, 14), 0.008, 0.025, cutoff=3000))
        return add((thud(m, 180, 0.035), 0.9), (scuff, 0.5), (grit, 0.2))
    return finish(heel_toe(n, touch))


def sand():
    n = int(0.4 * SR)

    def touch(m):
        crunch = norm(crackles(m, rng.randint(40, 60), 0.02, 0.045, width_s=0.001, cutoff=3200))
        shh = norm(mul(band(white(m), 500, 2600), env(m, 0.03, 0.08, 0.02)))
        return add((thud(m, 140, 0.03, attack=0.008), 0.45), (crunch, 0.45), (shh, 0.5))
    return finish(heel_toe(n, touch))


def wood():
    n = int(0.32 * SR)
    hollow_hz = rng.uniform(150, 210)

    def touch(m):
        hit = env(m, 0.001, 0.03)
        hollow = norm(mul(resonate(white(m), hollow_hz * rng.uniform(0.95, 1.05), 2.2), hit))
        knock = norm(mul(resonate(white(m), rng.uniform(420, 560), 1.6), env(m, 0.001, 0.015)))
        tap = norm(mul(band(white(m), 1200, 4500), env(m, 0.0008, 0.004)))
        return add((thud(m, 200, 0.03), 0.7), (hollow, 0.75), (knock, 0.35), (tap, 0.2))
    return finish(heel_toe(n, touch))


def stone():
    n = int(0.26 * SR)

    def touch(m):
        tick = norm(mul(band(white(m), 1800, 6000), env(m, 0.0008, 0.006)))
        body = norm(mul(resonate(white(m), rng.uniform(500, 700), 1.4), env(m, 0.001, 0.018)))
        scrape = norm(mul(band(white(m), 700, 2500), env(m, 0.01, 0.035)))
        return add((thud(m, 220, 0.025), 0.8), (tick, 0.35), (body, 0.4), (scrape, 0.2))
    return finish(heel_toe(n, touch))


def water():
    n = int(0.5 * SR)
    splash = norm(mul(band(white(n), 400, 2400), env(n, 0.012, 0.1, 0.02)))
    spray = norm(mul(band(white(n), 2000, 6000), env(n, 0.02, 0.05)))
    # Sloshing: noise that swells and dips a few times as the water settles.
    slosh = [0.0] * n
    for _ in range(rng.randint(3, 5)):
        at = rng.uniform(0.04, 0.25)
        dur = rng.uniform(0.05, 0.1)
        hz = rng.uniform(350, 650)
        burst = mul(resonate(white(n), hz, 3.0),
                    [math.sin(math.pi * min(1.0, max(0.0, (i / SR - at) / dur))) if at <= i / SR <= at + dur else 0.0
                     for i in range(n)])
        slosh = add((slosh, 1.0), (burst, rng.uniform(0.5, 1.0)))
    slosh = norm(slosh)
    return finish(add((thud(n, 150, 0.05), 0.5), (splash, 0.8), (spray, 0.15), (slosh, 0.35)))


def snow():
    n = int(0.38 * SR)

    def touch(m):
        crunch = norm(crackles(m, rng.randint(70, 100), 0.02, 0.05, width_s=0.0012, cutoff=2800))
        pack = norm(mul(band(white(m), 300, 1500), env(m, 0.025, 0.06, 0.02)))
        return add((thud(m, 150, 0.03, attack=0.01), 0.5), (crunch, 0.7), (pack, 0.35))
    return finish(heel_toe(n, touch))


# Each surface's peak level, so they sit together before the in-game volumes.
SURFACES = {
    "grass": (grass, 0.6), "dirt": (dirt, 0.7), "sand": (sand, 0.55), "wood": (wood, 0.8),
    "stone": (stone, 0.6), "water": (water, 0.7), "snow": (snow, 0.6),
}


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    for name, (make, peak) in SURFACES.items():
        for v in range(1, VARIANTS + 1):
            oa.write_wav("%s_%d.wav" % (name, v), make(), peak)


if __name__ == "__main__":
    main()
