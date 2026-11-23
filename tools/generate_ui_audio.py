#!/usr/bin/env python3
"""Synthesises the interface sounds (all original, no samples), in one soft, wooden,
marimba-and-bell style:

hover, click, back, deny, slider, open, close, book_open, book_close, page,
coin_gain, coin_spend, quest_new, quest_step, quest_done, heart, notify, talk.

Run from the project folder:  python3 tools/generate_ui_audio.py
Writes to assets/audio/ui/. Standard library only (uses the helpers in
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
oa.OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ui")
rng = random.Random(6006)
fs.rng = rng
oa.rng = rng
env, white, band, add, mul, fade_tail = fs.env, fs.white, fs.band, fs.add, fs.mul, fs.fade_tail


def silence(seconds):
    return [0.0] * int(seconds * SR)


def at(buf, sound, start_s, gain=1.0):
    oa.mix_into(buf, sound, start_s, gain)
    return buf


def marimba(hz, dur=0.35, bright=1.0):
    """A soft wooden bar: the marimba's partials (1, 3.9, 9.2) dying away fast."""
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(TAU * hz * t) * math.exp(-t / (dur * 0.32))
        v += 0.25 * bright * math.sin(TAU * hz * 3.9 * t) * math.exp(-t / (dur * 0.08))
        v += 0.08 * bright * math.sin(TAU * hz * 9.2 * t) * math.exp(-t / (dur * 0.03))
        out.append(v * min(1.0, i / (0.0015 * SR)))
    return out


def bell(hz, dur=1.2):
    return oa.chime_strike(hz, dur)


def m(note):
    return oa.midi_hz(note)


def tail(buf, wet=0.18):
    return fade_tail(oa.reverb(buf, wet=wet)[:len(buf)], 0.05)


# ---------------------------------------------------------------- buttons

def hover():
    return fade_tail(marimba(m(88), 0.08, 0.4), 0.01)


def click():
    buf = silence(0.22)
    at(buf, marimba(m(79), 0.2), 0.0, 1.0)
    at(buf, mul(band(white(len(buf)), 2000, 7000), env(len(buf), 0.0005, 0.004)), 0.0, 0.25)
    return tail(buf, 0.1)


def back():
    buf = silence(0.24)
    at(buf, marimba(m(72), 0.22), 0.0, 1.0)
    at(buf, mul(band(white(len(buf)), 1500, 5000), env(len(buf), 0.0005, 0.004)), 0.0, 0.2)
    return tail(buf, 0.1)


def deny():
    buf = silence(0.3)
    at(buf, marimba(m(55), 0.16, 0.3), 0.0, 1.0)
    at(buf, marimba(m(54), 0.16, 0.3), 0.1, 0.8)
    return fade_tail(oa.lowpass(buf, 1800))


def slider():
    return fade_tail(marimba(m(84), 0.06, 0.6), 0.01)


def open_panel():
    buf = silence(0.55)
    at(buf, mul(band(white(len(buf)), 800, 4000), env(len(buf), 0.06, 0.06)), 0.0, 0.18)
    at(buf, marimba(m(74), 0.35), 0.02, 0.8)
    at(buf, marimba(m(79), 0.4), 0.09, 0.9)
    return tail(buf)


def close_panel():
    buf = silence(0.5)
    at(buf, mul(band(white(len(buf)), 700, 3500), env(len(buf), 0.04, 0.05)), 0.0, 0.15)
    at(buf, marimba(m(79), 0.3), 0.0, 0.75)
    at(buf, marimba(m(72), 0.35), 0.07, 0.8)
    return tail(buf)


def page():
    """A paper page flipping over: a rustling sweep and a soft flap."""
    n = int(0.42 * SR)
    buf = [0.0] * n
    chunk = int(0.015 * SR)
    src = white(n + chunk * 2)
    rustle = []
    for c in range(0, n, chunk):
        k = c / n
        lo, hi = 1200 + 2500 * k, 4500 + 3000 * k
        rustle += band(src[c:c + chunk * 2], lo, hi)[chunk // 2: chunk // 2 + chunk]
    rustle = mul(rustle[:n], env(n, 0.12, 0.06, 0.08))
    at(buf, rustle, 0.0, 0.7)
    at(buf, mul(band(white(n), 300, 1500), env(n, 0.003, 0.03)), 0.27, 0.6)
    at(buf, fs.crackles(n, 12, 0.05, 0.12, cutoff=7000), 0.0, 0.25)
    return fade_tail(buf)


def book_open():
    buf = silence(0.8)
    at(buf, page(), 0.0, 0.8)
    at(buf, mul(band(white(len(buf)), 200, 900), env(len(buf), 0.004, 0.05)), 0.3, 0.6)  # cover thud
    at(buf, bell(m(86), 0.6), 0.32, 0.12)
    return tail(buf, 0.12)


def book_close():
    buf = silence(0.5)
    at(buf, mul(band(white(len(buf)), 1500, 5000), env(len(buf), 0.05, 0.04)), 0.0, 0.3)
    at(buf, mul(band(white(len(buf)), 150, 800), env(len(buf), 0.003, 0.06)), 0.1, 0.9)
    at(buf, fs.thump(len(buf), 110, 0.04), 0.1, 0.5)
    return fade_tail(buf)


# ---------------------------------------------------------------- money

def coin(hz, decay=0.35):
    """One small coin: a few bright, inharmonic rings."""
    n = int(0.6 * SR)
    out = []
    parts = ((1.0, 1.0), (2.41, 0.6), (3.87, 0.35), (5.3, 0.2))
    for i in range(n):
        t = i / SR
        v = 0.0
        for ratio, amp in parts:
            v += amp * math.sin(TAU * hz * ratio * t) * math.exp(-t / (decay / ratio ** 0.5))
        out.append(v * min(1.0, i / (0.0008 * SR)))
    return out


def coin_gain():
    buf = silence(0.9)
    for k, (s, f) in enumerate(((0.0, 2350), (0.06, 2800), (0.11, 2600), (0.19, 3150))):
        at(buf, coin(f * rng.uniform(0.98, 1.02)), s, 0.6 - k * 0.07)
    at(buf, bell(m(91), 0.6), 0.2, 0.1)
    return tail(buf, 0.12)


def coin_spend():
    buf = silence(0.7)
    for k, (s, f) in enumerate(((0.0, 1900), (0.07, 1750), (0.15, 1650))):
        at(buf, coin(f * rng.uniform(0.98, 1.02), 0.2), s, 0.55 - k * 0.1)
    at(buf, mul(band(white(len(buf)), 400, 1800), env(len(buf), 0.002, 0.03)), 0.2, 0.25)  # onto the counter
    return tail(buf, 0.08)


# ---------------------------------------------------------------- story moments

def quest_new():
    buf = silence(1.4)
    at(buf, marimba(m(74), 0.4), 0.0, 0.6)
    at(buf, bell(m(86), 1.1), 0.0, 0.25)
    at(buf, marimba(m(81), 0.5), 0.16, 0.7)
    at(buf, bell(m(93), 1.1), 0.16, 0.25)
    return tail(buf, 0.22)


def quest_step():
    buf = silence(1.0)
    at(buf, marimba(m(84), 0.35), 0.0, 0.6)
    at(buf, bell(m(96), 0.9), 0.0, 0.25)
    for k in range(4):
        at(buf, bell(m(rng.choice((96, 98, 100, 103))) * 1.0, 0.4), 0.08 + k * 0.05, 0.06)
    return tail(buf, 0.2)


def quest_done():
    buf = silence(2.2)
    notes = (67, 71, 74, 79, 83)
    for k, n in enumerate(notes):
        at(buf, marimba(m(n), 0.6), k * 0.09, 0.55)
    at(buf, oa.pluck(m(55), 1.8, 0.4, 0.997), 0.0, 0.35)
    for n in (79, 83, 86, 91):
        at(buf, bell(m(n), 1.6), 0.45, 0.13)
    return tail(buf, 0.25)


def heart():
    buf = silence(1.2)
    phase = 0.0
    n = int(0.18 * SR)
    swoop = []
    for i in range(n):
        k = i / n
        phase += TAU * (520 + 520 * k * k) / SR
        swoop.append(math.sin(phase) * math.sin(math.pi * k) ** 0.8)
    at(buf, swoop, 0.0, 0.35)
    at(buf, marimba(m(84), 0.45), 0.15, 0.5)
    at(buf, bell(m(88), 1.0), 0.15, 0.2)
    at(buf, bell(m(91), 1.0), 0.27, 0.2)
    return tail(buf, 0.22)


def notify():
    buf = silence(0.3)
    at(buf, marimba(m(81), 0.18, 0.5), 0.0, 0.6)
    at(buf, marimba(m(86), 0.2, 0.5), 0.05, 0.5)
    return tail(buf, 0.1)


def talk():
    """A soft 'mm' for each line of dialogue: a hummed, rounded vowel."""
    n = int(0.14 * SR)
    out = []
    phase = 0.0
    for i in range(n):
        k = i / n
        phase += TAU * 220 * (1.0 + 0.06 * math.sin(math.pi * k)) / SR
        v = math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.12 * math.sin(3 * phase)
        out.append(v * math.sin(math.pi * k) ** 1.5)
    return fade_tail(oa.lowpass(out, 1800), 0.01)


SOUNDS = {
    "hover": (hover, 0.35), "click": (click, 0.6), "back": (back, 0.6), "deny": (deny, 0.55),
    "slider": (slider, 0.4), "open": (open_panel, 0.6), "close": (close_panel, 0.55),
    "book_open": (book_open, 0.65), "book_close": (book_close, 0.6), "page": (page, 0.55),
    "coin_gain": (coin_gain, 0.6), "coin_spend": (coin_spend, 0.55),
    "quest_new": (quest_new, 0.6), "quest_step": (quest_step, 0.55), "quest_done": (quest_done, 0.65),
    "heart": (heart, 0.6), "notify": (notify, 0.45), "talk": (talk, 0.5),
}


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    for name, (make, peak) in SOUNDS.items():
        oa.write_wav(name + ".wav", make(), peak)


if __name__ == "__main__":
    main()
