#!/usr/bin/env python3
"""Synthesises the story's place sounds (all original, no samples):
market_tune.wav (a cheerful folk waltz that loops), market_chatter.wav (a murmur of
voices), well_hum.wav (the soft magical hum of the glowing well), moonwell.wav (the
shimmer of the light under Moonlit Lake) and lighthouse_hum.wav (the lit lamp's warm drone).

Run from the project folder:  python3 tools/generate_village_audio.py
Writes to assets/audio/ambience/. Standard library only (uses the helpers in
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
oa.OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambience")
rng = random.Random(3003)


def mix_wrap(buf, sound, start_s, gain=1.0):
    """Mixes a sound in, wrapping anything past the end round to the start (for loops)."""
    i0 = int(start_s * SR)
    n = len(buf)
    for i, s in enumerate(sound):
        buf[(i0 + i) % n] += s * gain


# ---------------------------------------------------------------- market waltz

BPM = 132.0
BEAT = 60.0 / BPM
BAR = BEAT * 3
CHORDS = {
    "G": (43, [55, 59, 62]), "C": (48, [55, 60, 64]), "D": (50, [54, 57, 62]),
    "Em": (40, [55, 59, 64]), "Am": (45, [57, 60, 64]),
}
PROGRESSION = ["G", "G", "C", "G", "G", "D", "D", "G", "C", "C", "G", "Em", "Am", "D", "G", "G"]
# (bar, beat, midi, beats): a lilting tune in G
MELODY = [
    (1, 0, 74, 1), (1, 1, 71, 1), (1, 2, 74, 1),
    (2, 0, 79, 2), (2, 2, 78, 1),
    (3, 0, 76, 1), (3, 1, 72, 1), (3, 2, 76, 1),
    (4, 0, 74, 3),
    (5, 0, 71, 1), (5, 1, 74, 1), (5, 2, 79, 1),
    (6, 0, 78, 1.5), (6, 1.5, 76, 0.5), (6, 2, 74, 1),
    (7, 0, 72, 1), (7, 1, 69, 1), (7, 2, 72, 1),
    (8, 0, 71, 3),
    (9, 0, 72, 1), (9, 1, 76, 1), (9, 2, 79, 1),
    (10, 0, 81, 2), (10, 2, 79, 1),
    (11, 0, 78, 1), (11, 1, 79, 1), (11, 2, 74, 1),
    (12, 0, 71, 2), (12, 2, 74, 1),
    (13, 0, 72, 1), (13, 1, 76, 1), (13, 2, 72, 1),
    (14, 0, 69, 1), (14, 1, 74, 1), (14, 2, 78, 1),
    (15, 0, 79, 1), (15, 1, 74, 1), (15, 2, 71, 1),
    (16, 0, 67, 2), (16, 2, 62, 1),
]


def accordion(hz, dur, vel=1.0):
    """A reedy, slightly detuned squeeze-box note with a gentle tremolo."""
    n = int((dur + 0.08) * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.03) * min(1.0, max(0.0, (dur + 0.08 - t) / 0.08))
        trem = 1.0 + 0.06 * math.sin(TAU * 5.5 * t)
        s = 0.0
        for detune in (0.997, 1.003):
            f = hz * detune
            s += math.sin(TAU * f * t) + 0.5 * math.sin(TAU * 2 * f * t) + 0.32 * math.sin(TAU * 3 * f * t) + 0.18 * math.sin(TAU * 4 * f * t) + 0.1 * math.sin(TAU * 5 * f * t)
        out.append(s * env * trem * vel * 0.5)
    return out


def market_tune():
    length = len(PROGRESSION) * BAR
    buf = [0.0] * int(length * SR)
    for b, name in enumerate(PROGRESSION):
        start = b * BAR
        bass, chord = CHORDS[name]
        # oom-pah-pah: bass on 1, chord strums on 2 and 3
        mix_wrap(buf, oa.pluck(oa.midi_hz(bass), 1.4, 0.45, 0.995), start, 0.6)
        for beat in (1, 2):
            for k, m in enumerate(chord):
                mix_wrap(buf, oa.pluck(oa.midi_hz(m), 0.6, 0.6, 0.993), start + beat * BEAT + k * 0.012, 0.28)
    for bar, beat, m, beats in MELODY:
        mix_wrap(buf, accordion(oa.midi_hz(m), beats * BEAT * 0.92, 0.42), (bar - 1) * BAR + beat * BEAT)
    # Light reverb, wrapped so the loop stays seamless.
    wet = oa.reverb(buf + buf[: int(1.5 * SR)], wet=0.22)
    n = len(buf)
    out = wet[:n]
    for i in range(len(wet) - n):
        out[i] = wet[n + i] * 0.6 + out[i] * 0.4 if i < int(0.05 * SR) else out[i]
    return oa.lowpass(out, 6000)


# ---------------------------------------------------------------- chatter

VOWELS = [(800, 1200), (500, 1900), (320, 2300), (520, 900), (360, 800), (650, 1700)]


def formant(samples, centre, q=0.12):
    f = 2.0 * math.sin(math.pi * centre / SR)
    low = band = 0.0
    out = []
    for s in samples:
        high = s - low - q * band
        band += f * high
        low += f * band
        out.append(band)
    return out


def syllable(f0, dur):
    n = int(dur * SR)
    src = []
    phase = 0.0
    contour = rng.uniform(-0.15, 0.15)
    for i in range(n):
        k = i / n
        f = f0 * (1.0 + contour * k) * (1.0 + 0.01 * rng.uniform(-1, 1))
        phase = (phase + f / SR) % 1.0
        src.append(phase * 2.0 - 1.0)
    a, b = rng.choice(VOWELS)
    voiced = [x + 0.6 * y for x, y in zip(formant(src, a), formant(src, b))]
    out = []
    for i in range(n):
        k = i / n
        out.append(voiced[i] * math.sin(math.pi * k) ** 0.7)
    return out


def voice_phrase(f0):
    out = []
    for w in range(rng.randint(3, 9)):
        out += syllable(f0 * rng.uniform(0.92, 1.1), rng.uniform(0.07, 0.2))
        out += [0.0] * int(rng.uniform(0.01, 0.12) * SR)
    return out


def market_chatter():
    length = 20.0
    buf = [0.0] * int(length * SR)
    voices = [rng.uniform(100, 140) for _ in range(4)] + [rng.uniform(190, 240) for _ in range(4)]
    for f0 in voices:
        t = rng.uniform(0, 3)
        loud = rng.uniform(0.25, 0.9)
        while t < length:
            phrase = voice_phrase(f0)
            mix_wrap(buf, phrase, t, loud * rng.uniform(0.7, 1.0))
            t += len(phrase) / SR + rng.uniform(0.4, 2.5)
    # Distant and soft: rounded off and placed in a little space.
    soft = oa.lowpass(oa.lowpass(buf, 2200), 2200)
    wet = oa.reverb(soft + soft[: int(1.0 * SR)], wet=0.4)
    n = len(soft)
    return wet[:n]


# ---------------------------------------------------------------- well hum

def well_hum():
    """A soft glassy hum. Every frequency fits the 12 s loop exactly, so it loops seamlessly."""
    length = 12.0
    n = int(length * SR)

    def fit(f):
        return round(f * length) / length

    drones = [(fit(110.0), 0.5), (fit(110.25), 0.35), (fit(165.0), 0.3), (fit(220.0), 0.22)]
    glass = [(fit(880.0), 0.07, 3.0), (fit(1320.0), 0.05, 4.0), (fit(1760.0), 0.035, 6.0), (fit(2093.0), 0.03, 2.0)]
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, a in drones:
            s += a * math.sin(TAU * f * t)
        for f, a, period in glass:
            s += a * (0.5 + 0.5 * math.sin(TAU * t / period)) * math.sin(TAU * f * t)
        s *= 0.85 + 0.15 * math.sin(TAU * t / 6.0)
        out.append(s)
    return out


# ---------------------------------------------------------------- the finale

def moonwell():
    """A glassy shimmer: slow-breathing high tones with little sparkles. Every tone fits
    the 16 s loop exactly and the sparkles wrap round, so it loops seamlessly."""
    length = 16.0
    n = int(length * SR)

    def fit(f):
        return round(f * length) / length

    buf = [0.0] * n
    pads = [(fit(440.0), 0.30, 16.0, 0.0), (fit(523.25), 0.22, 8.0, 1.3), (fit(659.25), 0.26, 16.0, 2.1),
            (fit(783.99), 0.16, 5.333333, 0.7), (fit(880.0), 0.18, 8.0, 3.9), (fit(220.0), 0.20, 16.0, 4.4)]
    for i in range(n):
        t = i / SR
        v = 0.0
        for f, a, period, ph in pads:
            v += a * (0.55 + 0.45 * math.sin(TAU * t / period + ph)) * math.sin(TAU * f * t)
        buf[i] = v
    sparkle_notes = [81, 84, 88, 91, 93, 96]  # A5 C6 E6 G6 A6 C7
    t = 0.2
    while t < length:
        strike = oa.chime_strike(oa.midi_hz(rng.choice(sparkle_notes)) * 2.0, 2.5)
        mix_wrap(buf, strike, t, rng.uniform(0.05, 0.14))
        t += rng.uniform(0.6, 1.8)
    return buf


def lighthouse_hum():
    """The lit lamp: a deep, warm drone with a faint glassy ring (15 s seamless loop)."""
    length = 15.0
    n = int(length * SR)

    def fit(f):
        return round(f * length) / length

    tones = [(fit(73.4), 0.55), (fit(73.6), 0.4), (fit(110.0), 0.32), (fit(146.8), 0.2),
             (fit(220.0), 0.08), (fit(587.3), 0.03)]
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for f, a in tones:
            v += a * math.sin(TAU * f * t)
        out.append(v * (0.9 + 0.1 * math.sin(TAU * t / 7.5)))
    return out


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    oa.write_wav("market_tune.wav", market_tune(), 0.8)
    oa.write_wav("market_chatter.wav", market_chatter(), 0.7)
    oa.write_wav("well_hum.wav", well_hum(), 0.7)
    oa.write_wav("moonwell.wav", moonwell(), 0.7)
    oa.write_wav("lighthouse_hum.wav", lighthouse_hum(), 0.75)


if __name__ == "__main__":
    main()
