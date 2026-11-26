#!/usr/bin/env python3
"""Synthesises the shipping and notice-board sounds (all original, no samples).

assets/audio/actions/ (heard from the player):
  crate_lift      lifting a packed crate: a scrape, the contents shifting
  crate_set_wood  setting it on planks (table, jetty, a dock): a hollow wooden thud
  crate_set_soft  setting it on grass or earth: a duller thump
  crate_on_cart   loading it onto the hand-cart: a thud and the cart's planks rattling
  cart_grab       taking the cart's handles: a creak as its legs lift
  cart_release    letting go: the legs knock down
  cart_roll       loop: wheels rumbling and crunching over a path, an axle creak
  cart_roll_wood  loop: wheels drumming over jetty planks
  pack_crate      packing an order: twine, the lid, three nail taps
assets/audio/ui/:
  board_open      the notice board / orders sheet: paper lifting and rustling
  board_close     the paper settling back
  board_pin       taking a request: the pin pulled from the cork, the note folded
  ship_bell       6 PM: Captain Marlow's ship's bell, twice, across the water

Run from the project folder:  python3 tools/generate_shipping_audio.py
Natural sounds from shaped noise (no pure tones, which sound beepy); only the bell
has a pitch. Standard library only (uses the other generators' helpers). Deterministic.
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
HERE = os.path.dirname(__file__)
ACTIONS = os.path.join(HERE, "..", "assets", "audio", "actions")
UI = os.path.join(HERE, "..", "assets", "audio", "ui")
rng = random.Random(7117)
for module in (fs, oa, va):
    module.rng = rng
env, white, band, add, mul, fade_tail = fs.env, fs.white, fs.band, fs.add, fs.mul, fs.fade_tail
norm, smooth, resonate, thud, crackles = fs.norm, fs.smooth, fs.resonate, fs.thud, fs.crackles


def silence(seconds):
    return [0.0] * int(seconds * SR)


def at(buf, sound, start_s, gain=1.0):
    oa.mix_into(buf, sound, start_s, gain)
    return buf


def knock(dur, hz, q, decay, bright=0.3):
    """A wooden knock: a noise burst through a low-Q body resonance, plus a tiny tick."""
    n = int(dur * SR)
    body = norm(mul(resonate(white(n), hz, q), env(n, 0.0008, decay)))
    tick = norm(mul(band(white(n), 1500, 5000), env(n, 0.0005, 0.003)))
    return add((body, 1.0), (tick, bright))


def creak(dur, rate0, rate1, centre, q=3.0):
    """Wood creaking: a stick-slip train of tiny impulses (its rate glides) through a
    hollow resonance. Rough and woody, never a clean tone."""
    n = int(dur * SR)
    imp = [0.0] * n
    t = 0.0
    while t < dur:
        k = t / dur
        rate = rate0 + (rate1 - rate0) * k
        i = int(t * SR)
        if i < n:
            imp[i] = rng.uniform(0.5, 1.0)
        t += (1.0 / rate) * rng.uniform(0.8, 1.25)
    grain = mul(white(n), [0.15] * n)
    src = [a + b for a, b in zip(imp, grain)]
    out = add((resonate(src, centre, q), 1.0), (resonate(src, centre * 2.3, q), 0.35))
    shape = [math.sin(math.pi * min(1.0, i / n)) ** 0.7 for i in range(n)]
    return norm(mul(out, shape))


def rattle(dur, count, lo=450, hi=950):
    """Loose planks or crate contents settling: a few small knocks close together."""
    n = int(dur * SR)
    buf = [0.0] * n
    for _ in range(count):
        k = knock(0.06, rng.uniform(lo, hi), 2.5, 0.012, 0.2)
        at(buf, k, abs(rng.gauss(0.0, dur * 0.3)), rng.uniform(0.25, 0.7))
    return buf


def rustle(dur, lo0, hi0, lo1, hi1, a, d, hold):
    """Paper moving: band-passed noise whose band slides, with crisp crackles."""
    n = int(dur * SR)
    chunk = int(0.015 * SR)
    src = white(n + chunk * 2)
    out = []
    for c in range(0, n, chunk):
        k = c / n
        lo, hi = lo0 + (lo1 - lo0) * k, hi0 + (hi1 - hi0) * k
        out += band(src[c:c + chunk * 2], lo, hi)[chunk // 2: chunk // 2 + chunk]
    out = norm(mul(out[:n], env(n, a, d, hold)))
    crisp = norm(crackles(n, int(dur * 40), a * 0.5, dur * 0.25, width_s=0.0008, cutoff=8000))
    return add((out, 0.8), (crisp, 0.22))


# ---------------------------------------------------------------- crates

def crate_lift():
    buf = silence(0.7)
    n = int(0.25 * SR)
    at(buf, norm(mul(band(white(n), 250, 1400), env(n, 0.04, 0.06, 0.05))), 0.0, 0.45)   # scrape off
    at(buf, knock(0.12, 160, 2.0, 0.03, 0.15), 0.02, 0.5)                                 # hands on the box
    at(buf, creak(0.22, 70, 45, 700, 4.0), 0.12, 0.18)                                    # boards flex
    at(buf, rattle(0.3, 6), 0.2, 0.6)                                                     # contents shift
    return fade_tail(smooth(buf, 7000, 1), 0.05)


def crate_thud(floor_hz, floor_q, weight, n_s=0.6):
    buf = silence(n_s)
    m = int(0.35 * SR)
    at(buf, thud(m, 170, 0.045), 0.0, weight)
    at(buf, norm(mul(resonate(white(m), floor_hz, floor_q), env(m, 0.001, 0.05))), 0.0, 0.7)
    at(buf, norm(mul(resonate(white(m), 135, 2.2), env(m, 0.001, 0.07))), 0.004, 0.55)    # the hollow box
    at(buf, rattle(0.3, 5), 0.03, 0.4)
    return buf


def crate_set_wood():
    return fade_tail(smooth(crate_thud(190, 2.4, 0.8), 7000, 1), 0.05)


def crate_set_soft():
    buf = crate_thud(110, 1.2, 1.0)
    m = int(0.2 * SR)
    at(buf, norm(mul(band(white(m), 600, 3000), env(m, 0.01, 0.04))), 0.0, 0.25)          # grass flattens
    return fade_tail(smooth(buf, 4500, 2), 0.05)


def crate_on_cart():
    buf = crate_thud(220, 2.6, 0.7, 0.8)
    at(buf, rattle(0.4, 9, 380, 800), 0.02, 0.7)                                          # cart boards
    at(buf, creak(0.18, 60, 40, 520, 3.5), 0.05, 0.25)                                    # springs a little
    return fade_tail(smooth(buf, 7000, 1), 0.06)


# ---------------------------------------------------------------- the cart

def cart_grab():
    buf = silence(0.6)
    at(buf, knock(0.1, 420, 2.0, 0.015, 0.3), 0.0, 0.5)          # hands close on the handles
    at(buf, creak(0.32, 55, 38, 600, 3.5), 0.06, 0.45)            # the frame flexes as it tips
    at(buf, rattle(0.3, 4, 350, 700), 0.15, 0.4)
    return fade_tail(smooth(buf, 7000, 1), 0.05)


def cart_release():
    buf = silence(0.55)
    at(buf, creak(0.15, 50, 40, 560, 3.5), 0.0, 0.25)
    at(buf, knock(0.25, 230, 1.8, 0.04, 0.25), 0.12, 0.9)         # the legs touch down
    at(buf, knock(0.25, 250, 1.8, 0.035, 0.2), 0.155, 0.6)
    at(buf, rattle(0.25, 4, 380, 800), 0.15, 0.4)
    return fade_tail(smooth(buf, 6500, 1), 0.05)


def cart_roll():
    """Loop (4 s): the wheels rumble and crunch over a path, the axle creaking once a turn."""
    length = 4.0
    n = int(length * SR)
    rumble = oa.crossfade_loop(smooth(band(white(n + SR // 2), 50, 380), 380, 2), 0.5)[:n]
    bumps = [0.0] * n
    for _ in range(int(length * 7)):                              # stones under the wheel
        va.mix_wrap(bumps, mul(thud(int(0.08 * SR), 140, 0.02), [1.0] * int(0.08 * SR)), rng.uniform(0, length), rng.uniform(0.2, 0.6))
    grit = [0.0] * n
    for _ in range(int(length * 70)):
        w = int(0.0012 * SR)
        va.mix_wrap(grit, [rng.uniform(-1, 1) * math.exp(-k / (w * 0.35)) for k in range(w)], rng.uniform(0, length), rng.uniform(0.1, 0.5))
    grit = smooth(grit + grit, 3500, 1)[n:]                       # filtered round the loop: no seam
    turn = [0.0] * n
    for i in range(3):                                            # one axle creak per wheel turn (~0.7 turns/s)
        va.mix_wrap(turn, creak(0.16, 70, 50, 900, 4.0), i * length / 3 + rng.uniform(-0.02, 0.02), 0.25)
    sway = [0.85 + 0.15 * math.sin(TAU * 2 * i / n) for i in range(n)]
    return mul(add((norm(rumble), 0.6), (norm(bumps), 0.55), (norm(grit), 0.35), (norm(turn), 0.3)), sway)


def cart_roll_wood():
    """Loop (4 s): over jetty planks, the wheels drum on every joint of the hollow deck."""
    length = 4.0
    n = int(length * SR)
    rumble = oa.crossfade_loop(resonate(smooth(band(white(n + SR // 2), 70, 500), 500, 2), 160, 1.5), 0.5)[:n]
    joints = [0.0] * n
    step = length / 16
    for i in range(16):
        t = i * step + rng.uniform(-0.01, 0.01)
        va.mix_wrap(joints, knock(0.12, rng.uniform(170, 210), 2.2, 0.03, 0.25), t, rng.uniform(0.7, 1.0))
    turn = [0.0] * n
    for i in range(3):
        va.mix_wrap(turn, creak(0.16, 70, 50, 900, 4.0), i * length / 3 + 0.05, 0.2)
    return add((norm(rumble), 0.5), (norm(joints), 0.8), (norm(turn), 0.25))


def pack_crate():
    """Packing an order: the goods settle, twine pulled tight, the lid, three nail taps."""
    buf = silence(2.0)
    at(buf, rattle(0.35, 8), 0.0, 0.5)
    at(buf, rustle(0.35, 900, 3000, 1800, 5000, 0.05, 0.06, 0.12), 0.25, 0.35)          # twine
    at(buf, crate_thud(200, 2.4, 0.6, 0.45), 0.62, 0.7)                                  # the lid goes on
    for t in (0.98, 1.26, 1.52):                                                         # tap, tap, tap
        at(buf, knock(0.2, rng.uniform(820, 900), 3.0, 0.02, 0.6), t, 0.8)
        at(buf, knock(0.2, 190, 2.0, 0.04, 0.0), t, 0.5)
    return fade_tail(smooth(buf, 8000, 1), 0.1)


# ---------------------------------------------------------------- the board (ui)

def board_open():
    buf = silence(0.55)
    at(buf, rustle(0.45, 700, 2800, 1500, 6000, 0.06, 0.08, 0.1), 0.0, 0.8)
    at(buf, mul(band(white(int(0.1 * SR)), 300, 1400), env(int(0.1 * SR), 0.003, 0.025)), 0.3, 0.35)
    return fade_tail(buf, 0.05)


def board_close():
    buf = silence(0.4)
    at(buf, rustle(0.25, 1500, 5000, 700, 2500, 0.02, 0.06, 0.03), 0.0, 0.6)
    at(buf, mul(band(white(int(0.1 * SR)), 250, 1200), env(int(0.1 * SR), 0.003, 0.03)), 0.14, 0.5)
    return fade_tail(buf, 0.05)


def board_pin():
    """A pin drawn out of the cork, a little metal tick, the note folded away."""
    buf = silence(0.75)
    n = int(0.09 * SR)
    at(buf, norm(mul(band(white(n), 2500, 7000), env(n, 0.02, 0.02, 0.03))), 0.0, 0.25)    # pin squeaks out
    m = int(0.12 * SR)
    tick = norm(mul(resonate(white(m), 5200, 18.0), env(m, 0.0004, 0.018)))                 # metal, tiny
    at(buf, tick, 0.09, 0.55)
    at(buf, norm(mul(resonate(white(m), 3100, 12.0), env(m, 0.0004, 0.012))), 0.092, 0.3)
    at(buf, rustle(0.3, 1200, 4500, 800, 3000, 0.03, 0.06, 0.06), 0.18, 0.7)                # the note comes off
    at(buf, rustle(0.18, 900, 3500, 600, 2500, 0.01, 0.04, 0.02), 0.45, 0.45)               # and is folded
    return fade_tail(buf, 0.05)


def ship_bell():
    """Two rings of a ship's brass bell, heard across the water (the only pitched sound
    here; a real bell's uneven partials and a noisy clapper strike keep it un-beepy)."""
    buf = silence(3.2)
    hz = 640.0
    partials = ((0.5, 0.35, 1.3), (1.0, 1.0, 1.6), (1.19, 0.55, 2.0), (1.5, 0.3, 2.4),
                (2.0, 0.35, 2.8), (2.51, 0.18, 3.5), (3.0, 0.12, 4.5))
    for start, vel in ((0.0, 1.0), (0.42, 0.85)):
        n = int(2.6 * SR)
        ring = []
        for i in range(n):
            t = i / SR
            s = 0.0
            for ratio, amp, decay in partials:
                s += amp * math.sin(TAU * hz * ratio * t + ratio) * math.exp(-t * decay)
            ring.append(s * min(1.0, t / 0.003))
        strike = norm(mul(band(white(n), 1500, 6000), env(n, 0.0005, 0.006)))
        at(buf, add((norm(ring), 1.0), (strike, 0.35)), start, vel)
    far = smooth(buf, 3200, 2)                                     # distance softens the top
    return fade_tail(oa.reverb(far, wet=0.4, room=0.86)[:len(buf)], 0.4)


ACTION_SOUNDS = {
    "crate_lift": (crate_lift, 0.7), "crate_set_wood": (crate_set_wood, 0.8),
    "crate_set_soft": (crate_set_soft, 0.75), "crate_on_cart": (crate_on_cart, 0.8),
    "cart_grab": (cart_grab, 0.7), "cart_release": (cart_release, 0.75),
    "cart_roll": (cart_roll, 0.6), "cart_roll_wood": (cart_roll_wood, 0.6),
    "pack_crate": (pack_crate, 0.75),
}
UI_SOUNDS = {
    "board_open": (board_open, 0.6), "board_close": (board_close, 0.55),
    "board_pin": (board_pin, 0.65), "ship_bell": (ship_bell, 0.7),
}


def main():
    for folder, sounds in ((ACTIONS, ACTION_SOUNDS), (UI, UI_SOUNDS)):
        oa.OUT = folder
        os.makedirs(folder, exist_ok=True)
        for name, (make, peak) in sounds.items():
            oa.write_wav(name + ".wav", make(), peak)


if __name__ == "__main__":
    main()
