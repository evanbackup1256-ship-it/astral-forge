"""Seamless ambient beds for the sanctuary's regions.

Each loop is rendered a little longer than it plays, then its tail is
crossfaded into its head, so the seam is inaudible when Roblox loops the
region (Sound.LoopRegion). Quiet by design: these sit under the soundtrack.
"""

from __future__ import annotations

import math
import random

from synth import (
    GLASS, BELL, SR, apply_env, bell, env_exp, frames, glide, lowpass, mix, noise, normalize, note, reverb, scale,
    seed, sine, svf, zeros,
)

LOOP_SECONDS = 16.0
XFADE = 2.0


def _lfo(seconds: float, rate: float, depth: float, center: float = 1.0, phase: float = 0.0):
    n = frames(seconds)
    return [center + depth * math.sin(math.tau * rate * i / SR + phase) for i in range(n)]


def _seamless(buf, seconds: float = LOOP_SECONDS, xfade: float = XFADE):
    """buf is seconds + xfade long; fold the extra tail over the head."""
    n = frames(seconds)
    x = frames(xfade)
    out = buf[:n]
    for i in range(x):
        k = i / x
        out[i] = out[i] * k + buf[n + i] * (1 - k)
    return out


def _wind(seconds: float, low: float, high: float, rate: float, seed_value: int):
    seed(seed_value)
    lfo = _lfo(seconds, rate, 0.5, 0.5)
    band = svf(noise(seconds), lambda x: low + (high - low) * (0.5 + 0.5 * math.sin(math.tau * rate * x * seconds)), 1.6)
    return [b * (0.35 + 0.65 * l) for b, l in zip(band, lfo)]


def _chimes(seconds: float, count: int, notes, seed_value: int, amp: float = 0.12, kind=GLASS):
    rng = random.Random(seed_value)
    out = zeros(seconds)
    for _ in range(count):
        at = rng.random() * (seconds - 1.5)
        f = note(rng.choice(notes))
        mix(out, apply_env(bell(f, 1.4, amp, kind, 0.6), env_exp(1.4, 0.5)), at)
    return out


def _crackle(seconds: float, rate: float, seed_value: int, cutoff: float = 3000, amp: float = 0.4):
    rng = random.Random(seed_value)
    out = zeros(seconds)
    t = 0.0
    while t < seconds - 0.05:
        t += rng.expovariate(rate)
        pop = apply_env(lowpass(noise(0.006), cutoff), env_exp(0.006, 0.0015))
        mix(out, pop, min(t, seconds - 0.01), amp * (0.3 + rng.random() * 0.7))
    return out


def heart():
    s = LOOP_SECONDS + XFADE
    out = zeros(s)
    hum = mix(sine(110, s, 0.25), sine(165, s, 0.12))
    mix(out, [h * l for h, l in zip(hum, _lfo(s, 0.11, 0.3, 0.7))])
    mix(out, lowpass(_crackle(s, 7, 3, 2200, 0.25), 2400))
    mix(out, _chimes(s, 3, ("D5", "A5", "F#5"), 4, 0.06, BELL))
    return _seamless(reverb(out, room=0.7, wet=0.3, tail=0.0))


def ember():
    s = LOOP_SECONDS + XFADE
    seed(21)
    out = scale(lowpass(noise(s), 170), 3.5)
    out = [v * l for v, l in zip(out, _lfo(s, 0.07, 0.35, 0.8))]
    mix(out, _crackle(s, 18, 22, 3400, 0.45))
    rng = random.Random(23)
    for _ in range(4):
        at = rng.random() * (s - 1.0)
        mix(out, apply_env(glide(70, 45, 0.6, 0.5), env_exp(0.6, 0.2)), at)
    return _seamless(reverb(out, room=0.6, wet=0.2, tail=0.0))


def hollows():
    s = LOOP_SECONDS + XFADE
    out = _wind(s, 500, 1300, 0.06, 31)
    mix(out, _chimes(s, 9, ("D6", "E6", "F#6", "A6", "B6", "D7"), 32, 0.1))
    return _seamless(reverb(out, room=0.85, wet=0.4, tail=0.0))


def spire():
    s = LOOP_SECONDS + XFADE
    out = _wind(s, 1300, 3200, 0.09, 41)
    mix(out, _wind(s, 300, 700, 0.05, 42), 0.0, 0.6)
    mix(out, _chimes(s, 4, ("D5", "A5", "D6"), 43, 0.1, BELL))
    return _seamless(reverb(out, room=0.9, wet=0.42, tail=0.0))


def riftmaw():
    s = LOOP_SECONDS + XFADE
    out = zeros(s)
    for f, amp in ((36.7, 0.5), (37.2, 0.5), (55.0, 0.25)):
        mix(out, sine(f, s, amp))
    pulse = _lfo(s, 0.5, 0.35, 0.65)
    out = [v * p for v, p in zip(out, pulse)]
    seed(51)
    mix(out, svf(noise(s), lambda x: 300 + 200 * math.sin(math.tau * 0.125 * x * s), 2.0), 0.0, 0.4)
    return _seamless(reverb(out, room=0.9, wet=0.35, tail=0.0))


LOOPS = {
    "amb_heart": heart,
    "amb_ember": ember,
    "amb_hollows": hollows,
    "amb_spire": spire,
    "amb_riftmaw": riftmaw,
}


def render(name: str):
    return normalize(LOOPS[name](), -9.0)
