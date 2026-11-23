#!/usr/bin/env python3
"""Synthesises each building's restoration sounds (all original, no samples).

The moment it is restored (assets/audio/story/restored_<id>.wav):
  market      awnings snap open and a squeeze-box tune starts
  windmill    the old wood groans, the sails catch and whoosh round, the gearbox glows
  bridge      planks thud into place, stones settle, the creek runs on underneath
  greenhouse  glass panes clink into their frames and sparkle
  lighthouse  the lens frame set in stone, the five Glowstones ring together (not lit yet!)
  inn         the door creaks open, the fire whooshes alight, cups clink
  boathouse   ropes creak, water slaps the hull, a little sea-shanty

Its sound of life afterwards (seamless loops, assets/audio/ambience/):
  windmill_turn    sails creaking round (one turn of the sails = 11.4 s, 4 sails)
  greenhouse_mist  drips and a soft mist spray under warm glass
  inn_fire         the inn's fireplace crackling
  boathouse_ropes  mooring ropes creaking, a hull knocking, water lapping
  workshop         Theo at work: sawing, then a few hammer taps

Run from the project folder:  python3 tools/generate_restoration_audio.py
Standard library only (uses the other generators' helpers). Deterministic (fixed seed).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_opening_audio as oa  # noqa: E402
import generate_footstep_audio as fs  # noqa: E402
import generate_ui_audio as ui  # noqa: E402
import generate_village_audio as va  # noqa: E402
import generate_story_audio as st  # noqa: E402

SR = oa.SR
TAU = oa.TAU
HERE = os.path.dirname(__file__)
STORY_OUT = os.path.join(HERE, "..", "assets", "audio", "story")
AMBIENCE_OUT = os.path.join(HERE, "..", "assets", "audio", "ambience")
rng = random.Random(8008)
for module in (fs, oa, ui, va, st):
    module.rng = rng
env, white, band, add, mul, fade_tail, thump, crackles = (
    fs.env, fs.white, fs.band, fs.add, fs.mul, fs.fade_tail, fs.thump, fs.crackles)
marimba, bell, m, at, silence = ui.marimba, ui.bell, ui.m, ui.at, ui.silence
pad, shimmer, finish = st.pad, st.shimmer, st.finish
mix_wrap = va.mix_wrap


# ---------------------------------------------------------------- building blocks

def creak(dur, f0, f1, rough=0.6):
    """Old wood or rope under strain: a slow, rough, gliding groan."""
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        k = i / n
        f = f0 + (f1 - f0) * k + 6 * math.sin(TAU * 13 * k * dur)
        phase += TAU * f / SR
        v = math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.3 * math.sin(3 * phase + 0.4)
        v *= 1.0 + rough * (rng.random() - 0.5)
        out.append(v * math.sin(math.pi * k) ** 0.6)
    return oa.lowpass(oa.highpass(out, 120), 2200)


def wood_knock(hz, decay=0.06):
    n = int(0.35 * SR)
    out = [0.0] * n
    for ratio, amp, d in ((1.0, 1.0, decay), (2.3, 0.5, decay * 0.6), (4.1, 0.25, decay * 0.3)):
        for i in range(n):
            t = i / SR
            out[i] += amp * math.sin(TAU * hz * ratio * t) * math.exp(-t / d)
    return add((out, 0.8), (mul(band(white(n), 1500, 6000), env(n, 0.0005, 0.005)), 0.4))


def cloth_flap():
    n = int(0.25 * SR)
    return mul(band(white(n), 300, 2500), env(n, 0.004, 0.03, 0.01))


def glass_clink(hz):
    n = int(1.2 * SR)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * hz * t) * math.exp(-t / 0.35) + 0.5 * math.sin(TAU * hz * 2.76 * t) * math.exp(-t / 0.2)
             + 0.25 * math.sin(TAU * hz * 5.4 * t) * math.exp(-t / 0.1))
        out.append(v * min(1.0, i / (0.0005 * SR)))
    return out


def water_slap():
    n = int(0.4 * SR)
    return add((mul(band(white(n), 300, 2000), env(n, 0.01, 0.06)), 0.8), (ui_chirp(0.06, 250, 600), 0.3))


def ui_chirp(dur, f0, f1):
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        k = i / n
        phase += TAU * (f0 + (f1 - f0) * k) / SR
        out.append(math.sin(phase) * math.sin(math.pi * k))
    return out


def fire_bed(n):
    """A fireplace: a soft low roar with crackles and pops."""
    roar = oa.lowpass(oa.lowpass(white(n), 500), 500)
    roar = [r * (0.8 + 0.2 * math.sin(TAU * 0.4 * i / SR)) for i, r in enumerate(roar)]
    pops = [0.0] * n
    for _ in range(int(n / SR * 9)):
        s = rng.uniform(0, n / SR)
        w = int(rng.uniform(0.001, 0.004) * SR)
        g = rng.uniform(0.2, 1.0)
        for k in range(w):
            j = (int(s * SR) + k) % n
            pops[j] += g * (rng.random() * 2 - 1) * math.exp(-k / (w * 0.4))
    pops = oa.lowpass(pops, 6000)
    return add((roar, 1.2), (pops, 0.5))


def chord_tail(buf, notes, start, gain=0.55):
    at(buf, pad(notes, 2.6, 0.25, 1.4, 0.4), start, gain)
    for k, note in enumerate(notes[1:]):
        at(buf, oa.pluck(m(note + 12), 2.0, 0.6, 0.997), start + 0.02 + k * 0.035, 0.25)
    return buf


# ---------------------------------------------------------------- the moment of restoration

def restored_market():
    buf = silence(3.6)
    for s in (0.0, 0.18, 0.36, 0.54):
        at(buf, cloth_flap(), s, 0.6)
    for k, (note, beats) in enumerate(((74, 1), (79, 1), (83, 1), (86, 2))):
        at(buf, va.accordion(m(note), beats * 0.22, 0.5), 0.75 + k * 0.22)
    chord_tail(buf, [55, 62, 67, 71, 74], 0.75)
    return finish(buf, 0.25)


def restored_windmill():
    buf = silence(4.2)
    at(buf, creak(1.1, 70, 95), 0.0, 0.7)
    for k, s in enumerate((0.9, 1.6, 2.15, 2.6)):                # sails catch, faster and faster
        n = int(0.6 * SR)
        at(buf, mul(band(white(n), 250, 1400), [math.sin(math.pi * i / n) ** 2 for i in range(n)]), s, 0.45 + 0.1 * k)
    at(buf, wood_knock(160, 0.09), 1.0, 0.5)                    # the gearbox engages
    at(buf, wood_knock(120, 0.09), 1.12, 0.4)
    at(buf, st.glow(), 1.6, 0.5)                                 # something inside glows
    chord_tail(buf, [53, 60, 65, 69, 72], 1.8, 0.45)
    return finish(buf, 0.25)


def restored_bridge():
    buf = silence(4.0)
    for k, (s, f) in enumerate(((0.0, 210), (0.25, 190), (0.5, 175))):
        at(buf, wood_knock(f, 0.08), s, 0.7)                     # planks
    at(buf, thump(int(0.6 * SR), 80, 0.08), 0.8, 0.8)           # a stone settles
    at(buf, crackles(int(0.8 * SR), 40, 0.02, 0.1, cutoff=3500), 0.8, 0.4)
    n = int(2.6 * SR)
    babble = mul(band(white(n), 400, 2600), [0.5 + 0.5 * math.sin(TAU * 3.1 * i / SR) * math.sin(TAU * 0.7 * i / SR) for i in range(n)])
    babble = mul(babble, env(n, 0.5, 0.9, 0.8))
    at(buf, babble, 1.1, 0.25)                                   # the creek runs on beneath
    chord_tail(buf, [50, 57, 62, 66, 69], 1.2)
    at(buf, bell(m(86), 2.0), 1.25, 0.15)
    return finish(buf, 0.3)


def restored_greenhouse():
    buf = silence(3.8)
    for k in range(7):
        at(buf, glass_clink(rng.uniform(2400, 3600)), k * 0.11 + rng.uniform(0, 0.03), 0.25)
    at(buf, shimmer(1.6), 0.7, 0.8)
    chord_tail(buf, [57, 64, 69, 73, 76], 0.85)
    return finish(buf, 0.3)


def restored_lighthouse():
    """The lens is ready but not yet lit: five Glowstones humming together, waiting."""
    buf = silence(4.4)
    at(buf, thump(int(0.8 * SR), 65, 0.12), 0.0, 0.9)            # the stone base
    at(buf, wood_knock(140, 0.1), 0.25, 0.6)                    # the wooden frame
    at(buf, glass_clink(1900), 0.55, 0.4)                       # the lens
    for k, note in enumerate((74, 76, 78, 79, 81)):              # the five shards' notes
        at(buf, bell(m(note), 2.8), 0.9 + k * 0.18, 0.2)
    at(buf, pad([50, 55, 57, 62], 3.2, 0.8, 1.8, 0.3), 0.9, 0.6)  # a hopeful, unresolved chord
    at(buf, shimmer(2.0), 1.4, 0.5)
    return finish(buf, 0.35)


def restored_inn():
    buf = silence(3.8)
    at(buf, creak(0.7, 220, 160, 0.4), 0.0, 0.5)                 # the door
    n = int(0.8 * SR)
    whoosh = mul(oa.lowpass(white(n), 900), [min(1.0, (i / n) * 4) * math.exp(-(i / SR) / 0.35) for i in range(n)])
    at(buf, whoosh, 0.55, 0.8)                                   # the fire takes
    at(buf, fire_bed(int(2.6 * SR)), 0.6, 0.25)
    at(buf, glass_clink(2100), 1.25, 0.2)                        # cups clink
    at(buf, glass_clink(2350), 1.32, 0.18)
    chord_tail(buf, [55, 62, 67, 71], 1.1, 0.5)
    return finish(buf, 0.25)


def restored_boathouse():
    buf = silence(4.0)
    at(buf, creak(0.9, 140, 190, 0.8), 0.0, 0.45)               # a rope pulls tight
    at(buf, water_slap(), 0.5, 0.6)
    at(buf, wood_knock(110, 0.1), 0.62, 0.6)                    # the hull bumps the jetty
    shanty = [(62, 0.0), (66, 0.25), (69, 0.5), (66, 0.75), (71, 1.0), (69, 1.25), (74, 1.6)]
    for note, s in shanty:
        at(buf, oa.pluck(m(note), 1.0, 0.6, 0.996), 0.9 + s, 0.4)
    chord_tail(buf, [50, 57, 62, 66], 2.5, 0.4)
    return finish(buf, 0.25)


# ---------------------------------------------------------------- sounds of life (loops)

def windmill_turn():
    length = 2 * math.pi / 0.55         # one turn of the sails (spinning_sails.gd speed)
    n = int(length * SR)
    buf = [0.0] * n
    for k in range(4):                  # each sail sweeping past
        s = k * length / 4
        w = int(1.4 * SR)
        swish = mul(band(white(w), 200, 1100), [math.sin(math.pi * i / w) ** 2 for i in range(w)])
        mix_wrap(buf, swish, s, 0.35)
        mix_wrap(buf, creak(rng.uniform(0.5, 0.8), rng.uniform(80, 110), rng.uniform(90, 130), 0.7), s + 0.6, 0.35)
    for k in range(9):                  # the gearbox's wooden teeth
        mix_wrap(buf, wood_knock(rng.uniform(95, 120), 0.05), k * length / 9 + rng.uniform(0, 0.1), 0.15)
    return buf


def greenhouse_mist():
    length = 10.0
    n = int(length * SR)
    buf = [0.0] * n
    for _ in range(26):                  # drips
        f = rng.uniform(800, 1800)
        mix_wrap(buf, ui_chirp(rng.uniform(0.03, 0.06), f, f * 1.7), rng.uniform(0, length), rng.uniform(0.08, 0.2))
    for s in (1.0, 6.0):                 # a soft spray of mist
        w = int(1.8 * SR)
        mix_wrap(buf, mul(band(white(w), 3000, 9000), env(w, 0.3, 0.5, 0.6)), s, 0.12)
    for i in range(n):                   # the warmth (fits the loop)
        t = i / SR
        buf[i] += 0.05 * math.sin(TAU * 98.0 * t) * (0.7 + 0.3 * math.sin(TAU * t / 5.0))
    return buf


def inn_fire():
    length = 8.0
    n = int(length * SR)
    pad_n = int(0.4 * SR)
    fire = fire_bed(n + pad_n)
    return oa.crossfade_loop(fire, 0.4)[:n]


def boathouse_ropes():
    length = 12.0
    n = int(length * SR)
    buf = [0.0] * n
    for s in (0.5, 4.8, 8.6):
        mix_wrap(buf, creak(rng.uniform(0.9, 1.4), rng.uniform(120, 160), rng.uniform(150, 200), 0.9), s, 0.25)
    for s in (2.6, 7.1, 10.4):
        mix_wrap(buf, wood_knock(rng.uniform(90, 120), 0.1), s, 0.3)
        mix_wrap(buf, water_slap(), s - 0.08, 0.35)
    lap = band(white(n + int(0.3 * SR)), 250, 1400)
    lap = [v * (0.5 + 0.5 * math.sin(TAU * i / SR / 2.4)) for i, v in enumerate(lap)]
    lap = oa.crossfade_loop(lap, 0.3)[:n]
    return [a + 0.12 * b for a, b in zip(buf, lap)]


def workshop():
    length = 14.0
    n = int(length * SR)
    buf = [0.0] * n
    for k in range(8):                   # sawing: push and pull
        s = 0.6 + k * 0.55
        w = int(0.5 * SR)
        hi = 2600 if k % 2 == 0 else 3200
        stroke = mul(band(white(w), 900, hi), [math.sin(math.pi * i / w) ** 1.5 for i in range(w)])
        mix_wrap(buf, stroke, s, 0.4)
    for k in range(5):                   # then a few hammer taps
        mix_wrap(buf, st.work_hammer(), 6.6 + k * 0.5 + rng.uniform(0, 0.05), 0.45)
    for k in range(3):                   # and a plank set down
        mix_wrap(buf, wood_knock(rng.uniform(140, 180), 0.08), 10.5 + k * 0.4, 0.3)
    return buf


STINGS = {
    "restored_market": (restored_market, 0.75), "restored_windmill": (restored_windmill, 0.75),
    "restored_bridge": (restored_bridge, 0.75), "restored_greenhouse": (restored_greenhouse, 0.7),
    "restored_lighthouse": (restored_lighthouse, 0.75), "restored_inn": (restored_inn, 0.7),
    "restored_boathouse": (restored_boathouse, 0.7),
}
LOOPS = {
    "windmill_turn": (windmill_turn, 0.6), "greenhouse_mist": (greenhouse_mist, 0.55),
    "inn_fire": (inn_fire, 0.6), "boathouse_ropes": (boathouse_ropes, 0.6), "workshop": (workshop, 0.65),
}


def main():
    os.makedirs(STORY_OUT, exist_ok=True)
    oa.OUT = STORY_OUT
    for name, (make, peak) in STINGS.items():
        oa.write_wav(name + ".wav", make(), peak)
    oa.OUT = AMBIENCE_OUT
    for name, (make, peak) in LOOPS.items():
        oa.write_wav(name + ".wav", make(), peak)


if __name__ == "__main__":
    main()
