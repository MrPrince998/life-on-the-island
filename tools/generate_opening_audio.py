#!/usr/bin/env python3
"""Synthesises the opening scene's sounds (all original, no samples):
sea loop, gulls, ship horn, whoosh, wind chimes, the lake bell and the music.

Run from the project folder:  python3 tools/generate_opening_audio.py
Writes WAV files to assets/audio/opening/. Uses only the Python standard library.
Deterministic (fixed random seed), so re-running gives the same files.
"""
import math
import os
import random
import struct
import wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "opening")
TAU = 2.0 * math.pi
rng = random.Random(20261121)


# ---------------------------------------------------------------- helpers

def silence(seconds):
    return [0.0] * int(seconds * SR)


def write_wav(name, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    gain = peak / top
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * gain)) * 32767)
        data += struct.pack("<h", v)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))
    print("wrote %s (%.1f s)" % (path, len(samples) / SR))


def mix_into(buf, sound, start_s, gain=1.0):
    i0 = int(start_s * SR)
    for i, s in enumerate(sound):
        j = i0 + i
        if j >= len(buf):
            break
        buf[j] += s * gain


def lowpass(samples, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, low)]


def noise(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def reverb(samples, wet=0.28, room=0.82):
    """A small Schroeder reverb: four combs then two all-passes."""
    combs = [int(SR * t) for t in (0.0297, 0.0371, 0.0411, 0.0437)]
    out = [0.0] * len(samples)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        filt = 0.0
        for i, s in enumerate(samples):
            y = buf[idx]
            filt = y * 0.7 + filt * 0.3  # damping
            buf[idx] = s + filt * room
            idx = (idx + 1) % d
            out[i] += y * 0.25
    for d, g in ((int(SR * 0.005), 0.7), (int(SR * 0.0017), 0.7)):
        buf = [0.0] * d
        idx = 0
        for i in range(len(out)):
            b = buf[idx]
            x = out[i]
            y = -g * x + b
            buf[idx] = x + g * y
            idx = (idx + 1) % d
            out[i] = y
    return [d * (1.0 - wet) + w * wet for d, w in zip(samples, out)]


def crossfade_loop(samples, fade_s):
    """Makes a seamless loop: the tail is faded into the head and cut off."""
    f = int(fade_s * SR)
    body = samples[:-f]
    tail = samples[-f:]
    for i in range(f):
        k = i / f
        body[i] = body[i] * k + tail[i] * (1.0 - k)
    return body


# ---------------------------------------------------------------- sounds

def sea_loop():
    """12 s of gentle waves: a low swell plus the hiss of breaking foam."""
    length = 13.0
    n = int(length * SR)
    rumble = lowpass(lowpass(noise(n), 260), 260)
    hiss = lowpass(highpass(noise(n), 900), 3800)
    out = []
    for i in range(n):
        t = i / SR
        swell = 0.55 + 0.45 * math.sin(TAU * t / 6.0)
        # foam peaks just after each swell, then washes out
        phase = (t / 6.0 + 0.85) % 1.0
        foam = math.exp(-((phase - 0.15) ** 2) / 0.02) + 0.25 * math.exp(-((phase - 0.4) ** 2) / 0.05)
        out.append(rumble[i] * 3.2 * swell + hiss[i] * 0.55 * (0.15 + foam))
    return crossfade_loop(out, 1.0)


def gull_call(start_hz, peak_hz, end_hz, dur):
    n = int(dur * SR)
    out = []
    phase = 0.0
    rasp = lowpass(noise(n), 400)
    for i in range(n):
        k = i / n
        if k < 0.3:
            f = start_hz + (peak_hz - start_hz) * (k / 0.3)
        else:
            f = peak_hz + (end_hz - peak_hz) * ((k - 0.3) / 0.7)
        phase += TAU * f / SR
        env = min(1.0, k / 0.06) * (1.0 - k) ** 1.4
        tone = math.sin(phase) + 0.45 * math.sin(2 * phase) + 0.2 * math.sin(3 * phase) + 0.08 * math.sin(4 * phase)
        out.append(tone * env * (0.75 + 1.6 * rasp[i]))
    return out


def gulls():
    buf = silence(6.0)
    calls = [
        (0.10, 1300, 1750, 1000, 0.32, 1.0),
        (0.55, 1350, 1800, 1050, 0.30, 0.9),
        (1.00, 1250, 1700, 800, 0.55, 1.0),
        (2.60, 1500, 1950, 1150, 0.26, 0.55),
        (2.95, 1450, 1900, 900, 0.48, 0.6),
        (4.30, 1200, 1650, 950, 0.34, 0.45),
    ]
    for start, a, b, c, d, g in calls:
        mix_into(buf, gull_call(a, b, c, d), start, g)
    return reverb(lowpass(buf, 5000), wet=0.35)


def horn():
    """Two blasts of a mellow ship's horn (a low fifth)."""
    buf = silence(4.2)
    for start in (0.15, 1.55):
        dur = 1.0
        n = int(dur * SR)
        blast = []
        for i in range(n):
            t = i / SR
            env = min(1.0, t / 0.09) * min(1.0, (dur - t) / 0.22)
            vib = 1.0 + 0.004 * math.sin(TAU * 5.0 * t)
            s = 0.0
            for f0 in (98.0, 147.0):
                for h in range(1, 14):
                    s += math.sin(TAU * f0 * h * vib * t) / (h ** 1.15)
            blast.append(s * env)
        mix_into(buf, lowpass(lowpass(blast, 1400), 1400), start)
    return reverb(buf, wet=0.4, room=0.86)


def whoosh():
    """A soft rush of air under the flyover: band-passed noise sweeping up and down."""
    dur = 3.2
    n = int(dur * SR)
    src = noise(n)
    out = []
    low = band = 0.0
    for i in range(n):
        k = i / n
        fc = 350 + 1300 * math.sin(math.pi * k) ** 1.5
        f = 2.0 * math.sin(math.pi * fc / SR)
        q = 0.6
        high = src[i] - low - q * band
        band += f * high
        low += f * band
        env = math.sin(math.pi * k) ** 2
        out.append(band * env)
    return out


def chime_strike(hz, dur=3.5):
    n = int(dur * SR)
    partials = ((1.0, 1.0, 1.6), (2.76, 0.45, 2.6), (5.4, 0.22, 4.0), (8.93, 0.1, 6.0))
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for ratio, amp, decay in partials:
            s += amp * math.sin(TAU * hz * ratio * t) * math.exp(-t * decay)
        out.append(s * min(1.0, t / 0.002))
    return out


def chimes():
    buf = silence(6.5)
    notes = [84, 86, 88, 91, 93, 96]  # C6 D6 E6 G6 A6 C7 (pentatonic)
    t = 0.05
    while t < 3.2:
        mix_into(buf, chime_strike(midi_hz(rng.choice(notes))), t, rng.uniform(0.35, 0.8))
        t += rng.uniform(0.18, 0.55)
    return reverb(buf, wet=0.3)


def lake_bell():
    """A deep, soft singing-bowl tone for the light in the lake."""
    dur = 6.5
    n = int(dur * SR)
    base = 196.0  # G3
    partials = ((0.5, 0.35, 0.5), (1.0, 1.0, 0.6), (1.19, 0.3, 0.9), (1.5, 0.35, 0.8),
                (2.0, 0.4, 1.1), (2.74, 0.18, 1.6), (3.0, 0.12, 1.8), (4.07, 0.06, 2.6))
    out = []
    for i in range(n):
        t = i / SR
        shimmer = 1.0 + 0.12 * math.sin(TAU * 0.9 * t)
        s = 0.0
        for ratio, amp, decay in partials:
            s += amp * math.sin(TAU * base * ratio * t) * math.exp(-t * decay)
        out.append(s * min(1.0, t / 0.35) * shimmer)
    return reverb(out, wet=0.45, room=0.88)


# ---------------------------------------------------------------- music

BPM = 72.0
BEAT = 60.0 / BPM
BAR = BEAT * 4

# One chord per bar. Bar 1 starts at 0 s (the scene starts the music 0.5 s in).
# 1-4 sea and deck, 5-8 the village, 9-12 the lake (thinner), 13-15 the villagers,
# 16-18 the arrival (fuller), 19 the final chord under the title.
CHORDS = {
    "D": [50, 57, 62, 66, 69], "Bm": [47, 54, 59, 62, 66], "G": [43, 50, 55, 59, 62],
    "A": [45, 52, 57, 61, 64], "Em": [40, 47, 52, 55, 59],
}
PROGRESSION = ["D", "Bm", "G", "A", "D", "Bm", "G", "A", "Bm", "G", "D", "A",
               "G", "D", "A", "D", "G", "A", "D"]
# (bar, beat, midi, beats)
MELODY = [
    (5, 0, 69, 1), (5, 1, 74, 1), (5, 2, 78, 2),
    (6, 0, 76, 1), (6, 1, 74, 1), (6, 2, 71, 2),
    (7, 0, 74, 1), (7, 1, 71, 1), (7, 2, 67, 1), (7, 3, 71, 1),
    (8, 0, 73, 2), (8, 2, 76, 2),
    (9, 0, 78, 1.5), (9, 1.5, 76, 0.5), (9, 2, 74, 2),
    (10, 0, 71, 4),
    (11, 2, 69, 2),
    (12, 0, 76, 2), (12, 2, 73, 2),
    (13, 0, 71, 1), (13, 1, 74, 1), (13, 2, 79, 2),
    (14, 0, 78, 1), (14, 1, 76, 1), (14, 2, 74, 2),
    (15, 0, 76, 2), (15, 2, 69, 2),
    (16, 0, 74, 1), (16, 1, 78, 1), (16, 2, 81, 2),
    (17, 0, 83, 1), (17, 1, 81, 1), (17, 2, 79, 2),
    (18, 0, 78, 1), (18, 1, 76, 1), (18, 2, 73, 1), (18, 3, 76, 1),
    (19, 0, 74, 4),
]


def pluck(hz, dur, brightness=0.5, decay=0.996):
    """Karplus-Strong plucked string (a soft nylon guitar)."""
    period = max(2, int(SR / hz))
    buf = lowpass(noise(period), 1500 + 4000 * brightness)
    n = int(dur * SR)
    out = []
    idx = 0
    prev = 0.0
    for i in range(n):
        v = buf[idx]
        nxt = buf[(idx + 1) % period]
        buf[idx] = decay * 0.5 * (v + nxt)
        out.append(v)
        idx = (idx + 1) % period
        prev = v
    fade = int(0.05 * SR)
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    return out


def piano(hz, dur, vel=1.0):
    n = int((dur + 1.6) * SR)
    partials = ((1, 1.0, 1.1), (2, 0.42, 1.8), (3, 0.2, 2.6), (4, 0.09, 3.4), (5, 0.05, 4.2))
    out = []
    for i in range(n):
        t = i / SR
        release = 1.0 if t < dur else math.exp(-(t - dur) * 3.5)
        s = 0.0
        for h, amp, decay in partials:
            s += amp * math.sin(TAU * hz * h * t) * math.exp(-t * decay)
        out.append(s * vel * release * min(1.0, t / 0.004))
    return out


def pad(notes, dur):
    n = int(dur * SR)
    out = [0.0] * n
    for m in notes:
        hz = midi_hz(m)
        for detune in (-0.003, 0.0, 0.003):
            f = hz * (1.0 + detune)
            for i in range(n):
                t = i / SR
                env = min(1.0, t / 2.0) * min(1.0, (dur - t) / 2.5)
                out[i] += (math.sin(TAU * f * t) + 0.25 * math.sin(TAU * 2 * f * t)) * env
    return lowpass(out, 1800)


def music():
    total = len(PROGRESSION) * BAR + 5.0
    buf = silence(total)
    for b, name in enumerate(PROGRESSION, start=1):
        start = (b - 1) * BAR
        tones = CHORDS[name]
        if b == len(PROGRESSION):
            # The final chord: a slow strum that rings out.
            for k, m in enumerate(tones):
                mix_into(buf, pluck(midi_hz(m), 6.0, 0.55, 0.9985), start + k * 0.07, 0.55)
            continue
        if 9 <= b <= 12:
            pattern = [(0, 0), (1, 2), (2, 3), (3, 2)]  # the lake: quarter notes, sparser
            gain = 0.38
        else:
            pattern = [(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 4), (2.5, 3), (3, 2), (3.5, 1)]
            gain = 0.32 if b <= 4 else 0.42
            if b >= 16:
                gain = 0.5
        for beat, tone in pattern:
            m = tones[tone]
            mix_into(buf, pluck(midi_hz(m), 2.2, 0.4 + 0.1 * (tone / 4.0)), start + beat * BEAT, gain * (1.15 if tone == 0 else 1.0))
    for bar, beat, m, beats in MELODY:
        vel = 0.5 if bar < 16 else 0.62
        if bar in (10, 11):
            vel = 0.38
        mix_into(buf, piano(midi_hz(m), beats * BEAT * 0.95, vel), (bar - 1) * BAR + beat * BEAT, 0.5)
    # The swell for the arrival: a soft pad under bars 16-19.
    swell = []
    for b in range(16, 20):
        name = PROGRESSION[b - 1]
        notes = [CHORDS[name][1] + 12, CHORDS[name][2] + 12, CHORDS[name][3] + 12]
        dur = BAR + (4.0 if b == 19 else 0.8)
        mix_into(buf, pad(notes, dur), (b - 1) * BAR, 0.05)
    # Fade in over the first two seconds.
    for i in range(int(2.0 * SR)):
        buf[i] *= i / (2.0 * SR)
    return reverb(buf, wet=0.26, room=0.8)


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("sea_loop.wav", sea_loop(), 0.8)
    write_wav("gulls.wav", gulls(), 0.75)
    write_wav("horn.wav", horn(), 0.85)
    write_wav("whoosh.wav", whoosh(), 0.7)
    write_wav("chimes.wav", chimes(), 0.7)
    write_wav("lake_bell.wav", lake_bell(), 0.8)
    write_wav("music.wav", music(), 0.85)


if __name__ == "__main__":
    main()
