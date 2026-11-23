#!/usr/bin/env python3
"""Synthesises the island's ambient sounds (all original, no samples):
coast surf, lake lapping, wind, daytime birds, night crickets, frogs, rain, an owl,
and two seasonal layers: summer cicadas and autumn's rustling dry leaves.

Run from the project folder:  python3 tools/generate_ambient_audio.py
Writes WAV files to assets/audio/ambience/. Uses only the Python standard library and
the helpers in generate_opening_audio.py. Deterministic (fixed seed).
Loops are made seamless by cross-fading their tail into their head.
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
rng = random.Random(1122)


def noise(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def bandpass(samples, centre, q=0.7):
    """A state-variable band-pass with a fixed centre."""
    f = 2.0 * math.sin(math.pi * centre / SR)
    low = band = 0.0
    out = []
    for s in samples:
        high = s - low - q * band
        band += f * high
        low += f * band
        out.append(band)
    return out


# ---------------------------------------------------------------- loops

def coast_waves():
    """Surf on the beach: irregular waves (7 to 10 s apart) breaking and washing back."""
    length = 25.0
    n = int(length * SR)
    rumble = oa.lowpass(oa.lowpass(noise(n), 180), 180)
    hiss = oa.lowpass(oa.highpass(noise(n), 700), 4500)
    env_r = [0.0] * n
    env_h = [0.0] * n
    t = 0.3
    while t < length:
        size = rng.uniform(0.7, 1.0)
        for i in range(int(t * SR), min(n, int((t + 7.0) * SR))):
            k = i / SR - t
            # the swell builds, breaks (crash), then the foam washes back
            env_r[i] += size * math.exp(-((k - 1.2) ** 2) / 1.2)
            env_h[i] += size * (math.exp(-((k - 1.6) ** 2) / 0.12) + 0.45 * math.exp(-((k - 3.2) ** 2) / 1.6))
        t += rng.uniform(7.0, 10.0)
    out = [rumble[i] * 2.6 * (0.35 + env_r[i]) + hiss[i] * 0.6 * (0.08 + env_h[i]) for i in range(n)]
    return oa.crossfade_loop(out, 2.0)


def lake_lap():
    """Small ripples lapping at the shore and the dock posts."""
    length = 13.0
    n = int(length * SR)
    out = [0.0] * n
    bed = oa.lowpass(noise(n), 500)
    for i in range(n):
        out[i] = bed[i] * 0.25 * (0.6 + 0.4 * math.sin(TAU * i / SR / 3.1))
    t = 0.05
    while t < length - 0.4:
        dur = rng.uniform(0.12, 0.3)
        m = int(dur * SR)
        burst = bandpass(noise(m), rng.uniform(450, 1100), 0.5)
        amp = rng.uniform(0.25, 0.8)
        for j in range(m):
            k = j / m
            idx = int(t * SR) + j
            if idx < n:
                out[idx] += burst[j] * amp * math.sin(math.pi * k) ** 2
        t += rng.uniform(0.12, 0.6)
    return oa.crossfade_loop(oa.reverb(out, wet=0.2), 1.0)


def wind():
    """A soft breeze with slow gusts (the band of the noise moves with each gust)."""
    length = 21.0
    n = int(length * SR)
    src = noise(n)
    out = []
    low = band = 0.0
    phases = [rng.uniform(0, TAU) for _ in range(3)]
    for i in range(n):
        t = i / SR
        gust = 0.5 + 0.25 * math.sin(TAU * t / 9.0 + phases[0]) + 0.15 * math.sin(TAU * t / 4.3 + phases[1]) + 0.1 * math.sin(TAU * t / 2.1 + phases[2])
        fc = 260 + 420 * gust
        f = 2.0 * math.sin(math.pi * fc / SR)
        high = src[i] - low - 0.9 * band
        band += f * high
        low += f * band
        out.append((band * 0.8 + low * 0.25) * gust)
    return oa.crossfade_loop(out, 2.0)


def chirp_sweep(f0, f1, dur, amp=1.0):
    m = int(dur * SR)
    out = []
    phase = 0.0
    for j in range(m):
        k = j / m
        f = f0 + (f1 - f0) * k
        phase += TAU * f / SR
        env = math.sin(math.pi * k) ** 1.5
        out.append((math.sin(phase) + 0.15 * math.sin(2 * phase)) * env * amp)
    return out


def bird_trill(base):
    """A warbler-like trill: quick little upward sweeps."""
    out = []
    count = rng.randint(6, 11)
    for c in range(count):
        f = base * (1.0 + 0.04 * math.sin(c))
        out += chirp_sweep(f * 0.85, f * 1.15, 0.045)
        out += [0.0] * int(0.025 * SR)
    return out


def bird_whistle(base):
    """A two-note whistle, 'tee-oo'."""
    return chirp_sweep(base, base * 1.05, 0.22) + [0.0] * int(0.06 * SR) + chirp_sweep(base * 0.78, base * 0.72, 0.3)


def bird_chips(base):
    out = []
    for c in range(rng.randint(2, 4)):
        out += chirp_sweep(base * 1.2, base * 0.9, 0.06)
        out += [0.0] * int(rng.uniform(0.08, 0.16) * SR)
    return out


def birds_day():
    """Morning-to-evening birdsong: a few voices near and far, never too busy."""
    length = 26.0
    n = int(length * SR)
    out = [0.0] * n
    t = 0.3
    voices = [(bird_trill, 3600), (bird_whistle, 2700), (bird_chips, 4200), (bird_trill, 4800), (bird_whistle, 2200)]
    while t < length - 2.0:
        maker, base = rng.choice(voices)
        call = maker(base * rng.uniform(0.94, 1.06))
        oa.mix_into(out, call, t, rng.uniform(0.2, 0.75))
        # a reply from another bird now and then
        if rng.random() < 0.35:
            oa.mix_into(out, maker(base * rng.uniform(0.9, 1.1)), t + rng.uniform(0.7, 1.4), rng.uniform(0.15, 0.4))
        t += rng.uniform(0.9, 2.6)
    out = oa.lowpass(out, 7000)
    return oa.crossfade_loop(oa.reverb(out, wet=0.3), 1.5)


def crickets():
    """Several crickets chirping at their own rates."""
    length = 12.0
    n = int(length * SR)
    out = [0.0] * n
    for c in range(5):
        carrier = rng.uniform(4100, 5200)
        period = rng.uniform(0.42, 0.75)
        amp = rng.uniform(0.25, 0.7)
        t = rng.uniform(0, period)
        while t < length - 0.3:
            # three quick pulses per chirp
            for p in range(3):
                start = int((t + p * 0.032) * SR)
                m = int(0.022 * SR)
                for j in range(m):
                    idx = start + j
                    if idx < n:
                        out[idx] += math.sin(TAU * carrier * idx / SR) * math.sin(math.pi * j / m) * amp
            t += period * rng.uniform(0.95, 1.05)
    return oa.crossfade_loop(oa.reverb(out, wet=0.25), 1.0)


def frog_croak(base):
    out = []
    for p in range(2):
        m = int(0.13 * SR)
        for j in range(m):
            t = j / SR
            k = j / m
            buzz = 0.5 + 0.5 * math.sin(TAU * 32 * t)  # the rasp
            tone = math.sin(TAU * base * t) + 0.6 * math.sin(TAU * base * 2 * t) + 0.3 * math.sin(TAU * base * 3 * t)
            out.append(tone * buzz * math.sin(math.pi * k))
        out += [0.0] * int(0.07 * SR)
    return out


def frogs():
    length = 15.0
    n = int(length * SR)
    out = [0.0] * n
    t = 0.2
    while t < length - 1.0:
        oa.mix_into(out, frog_croak(rng.uniform(170, 290)), t, rng.uniform(0.3, 0.8))
        t += rng.uniform(0.6, 2.2)
    out = oa.lowpass(out, 2500)
    return oa.crossfade_loop(oa.reverb(out, wet=0.35), 1.0)


def rain():
    """Steady rain: a soft hiss with drops pattering on leaves and roofs."""
    length = 12.0
    n = int(length * SR)
    hiss = oa.lowpass(oa.highpass(noise(n), 1200), 6500)
    body = oa.lowpass(noise(n), 900)
    out = [hiss[i] * 0.5 + body[i] * 0.35 for i in range(n)]
    for d in range(int(length * 45)):
        start = rng.randrange(n - 400)
        f = rng.uniform(1800, 5000)
        amp = rng.uniform(0.1, 0.45)
        for j in range(300):
            out[start + j] += math.sin(TAU * f * j / SR) * math.exp(-j / 40.0) * amp
    return oa.crossfade_loop(out, 1.0)


def owl():
    """A distant 'hoo, hoo-hoo'."""
    out = [0.0] * int(3.2 * SR)
    for start, dur, f in ((0.1, 0.42, 390), (0.9, 0.22, 370), (1.2, 0.5, 365)):
        m = int(dur * SR)
        hoo = []
        for j in range(m):
            k = j / m
            t = j / SR
            env = min(1.0, k / 0.25) * (1.0 - k) ** 0.8
            hoo.append((math.sin(TAU * f * t) + 0.2 * math.sin(TAU * 2 * f * t)) * env)
        oa.mix_into(out, oa.lowpass(hoo, 1200), start)
    return oa.reverb(out, wet=0.5, room=0.86)


def cicadas():
    """Summer cicadas: a few insects buzzing in long swells, high and soft."""
    length = 16.0
    n = int(length * SR)
    out = [0.0] * n
    for c in range(4):
        carrier = rng.uniform(5200, 6800)
        pulse = rng.uniform(140, 210)
        period = rng.uniform(4.0, 8.0)
        phase = rng.uniform(0, TAU)
        amp = rng.uniform(0.3, 0.8)
        buzz = oa.highpass(noise(n), 3500)
        for i in range(n):
            t = i / SR
            swell = max(0.0, math.sin(TAU * t / period + phase)) ** 1.5
            am = 0.5 + 0.5 * math.sin(TAU * pulse * t)
            out[i] += (math.sin(TAU * carrier * t) * 0.6 + buzz[i] * 0.4) * am * swell * amp
    out = oa.lowpass(out, 9000)
    return oa.crossfade_loop(out, 2.0)


def dry_leaves():
    """Autumn: wind through dry leaves, crisp little rustles in gusts."""
    length = 18.0
    n = int(length * SR)
    hiss = oa.highpass(noise(n), 1800)
    out = [0.0] * n
    phases = [rng.uniform(0, TAU) for _ in range(2)]
    for i in range(n):
        t = i / SR
        gust = max(0.0, 0.45 + 0.35 * math.sin(TAU * t / 7.0 + phases[0]) + 0.2 * math.sin(TAU * t / 2.9 + phases[1]))
        out[i] = hiss[i] * 0.25 * gust
    # crackles: tiny bursts, more of them when the gust is strong
    for k in range(int(length * 70)):
        start = rng.randrange(n - 500)
        t = start / SR
        gust = max(0.0, 0.45 + 0.35 * math.sin(TAU * t / 7.0 + phases[0]) + 0.2 * math.sin(TAU * t / 2.9 + phases[1]))
        if rng.random() > gust:
            continue
        m = rng.randint(80, 400)
        amp = rng.uniform(0.1, 0.5)
        for j in range(m):
            out[start + j] += rng.uniform(-1, 1) * amp * (1.0 - j / m) ** 2
    out = oa.lowpass(oa.highpass(out, 900), 8000)
    return oa.crossfade_loop(out, 1.5)


def main():
    os.makedirs(oa.OUT, exist_ok=True)
    oa.write_wav("coast_waves.wav", coast_waves(), 0.8)
    oa.write_wav("lake_lap.wav", lake_lap(), 0.7)
    oa.write_wav("wind.wav", wind(), 0.75)
    oa.write_wav("birds_day.wav", birds_day(), 0.75)
    oa.write_wav("crickets.wav", crickets(), 0.6)
    oa.write_wav("frogs.wav", frogs(), 0.7)
    oa.write_wav("rain.wav", rain(), 0.75)
    oa.write_wav("owl.wav", owl(), 0.75)
    oa.write_wav("cicadas.wav", cicadas(), 0.6)
    oa.write_wav("leaves.wav", dry_leaves(), 0.7)


if __name__ == "__main__":
    main()
