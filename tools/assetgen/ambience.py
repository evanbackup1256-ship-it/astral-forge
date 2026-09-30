"""Seamless ambient beds for the sanctuary's regions.

Each loop is rendered a little longer than it plays, then its tail is
crossfaded into its head, so the seam is inaudible when Roblox loops the
region (Sound.LoopRegion). Quiet by design: these sit under the soundtrack.

Tone: dark-cyber forge — sub drones, neon grit, voidglass chimes — not soft
nature pads.
"""

from __future__ import annotations

import math
import random

from synth import (
    BELL, CRYSTAL, GLASS, IRON, NEON, PLASMA, SR, VOID, apply_env, bell, env_exp,
    frames, glide, grit, lowpass, mix, noise, normalize, note, pulse, reverb,
    ring_mod, scale, seed, sine, softclip, svf, zeros,
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


def _sub_drone(seconds: float, freqs, pulse_hz: float = 0.0):
    out = zeros(seconds)
    for f, amp in freqs:
        mix(out, sine(f, seconds, amp))
        mix(out, sine(f * 1.003, seconds, amp * 0.45))
    if pulse_hz > 0:
        gate = _lfo(seconds, pulse_hz, 0.28, 0.72)
        out = [v * g for v, g in zip(out, gate)]
    return out


def heart():
    """Forge altar — slow neon pulse + iron grit under a low D drone."""
    s = LOOP_SECONDS + XFADE
    out = _sub_drone(s, ((55.0, 0.35), (82.5, 0.18), (110.0, 0.12)), pulse_hz=0.55)
    mix(out, scale(pulse(55.0, s, 0.12, 0.2), 0.55))
    mix(out, grit(lowpass(_crackle(s, 9, 3, 1800, 0.22), 2000), 0.2), 0.0, 0.8)
    mix(out, _chimes(s, 2, ("D5", "A5", "F#5"), 4, 0.05, NEON))
    return _seamless(reverb(out, room=0.72, wet=0.28, tail=0.0))


def ember():
    """Ember fields — heat rumble, forge crackle, occasional iron sigh."""
    s = LOOP_SECONDS + XFADE
    seed(21)
    out = scale(lowpass(noise(s), 150), 3.8)
    out = [v * l for v, l in zip(out, _lfo(s, 0.08, 0.38, 0.78))]
    mix(out, grit(_crackle(s, 22, 22, 3200, 0.5), 0.25))
    mix(out, _sub_drone(s, ((41.2, 0.22), (61.7, 0.12)), pulse_hz=0.35), 0.0, 0.7)
    rng = random.Random(23)
    for _ in range(5):
        at = rng.random() * (s - 1.0)
        mix(out, apply_env(glide(78, 42, 0.7, 0.55), env_exp(0.7, 0.22)), at)
        mix(out, apply_env(bell(220, 0.4, 0.12, IRON, 0.5), env_exp(0.4, 0.1)), at + 0.05)
    return _seamless(reverb(softclip(out, 1.15), room=0.58, wet=0.18, tail=0.0))


def hollows():
    """Crystal hollows — voidglass wind + sparse high chimes."""
    s = LOOP_SECONDS + XFADE
    out = scale(_wind(s, 450, 1400, 0.055, 31), 0.9)
    mix(out, ring_mod(_wind(s, 900, 2400, 0.09, 33), 37.5, 0.18), 0.0, 0.35)
    mix(out, _chimes(s, 11, ("C#6", "F#6", "A6", "C#7", "E7"), 32, 0.09, VOID))
    mix(out, _sub_drone(s, ((36.7, 0.18),), pulse_hz=0.2), 0.0, 0.5)
    return _seamless(reverb(out, room=0.88, wet=0.42, tail=0.0))


def spire():
    """Voidglass spires — thin high wind, distant neon bells."""
    s = LOOP_SECONDS + XFADE
    out = _wind(s, 1400, 3600, 0.1, 41)
    mix(out, _wind(s, 280, 680, 0.045, 42), 0.0, 0.55)
    mix(out, _chimes(s, 5, ("D5", "A5", "D6", "F#6"), 43, 0.09, CRYSTAL))
    mix(out, scale(pulse(73.4, s, 0.08, 0.15), 0.35))
    return _seamless(reverb(out, room=0.9, wet=0.44, tail=0.0))


def riftmaw():
    """Rift maw — beating sub pair, plasma wash, sparse void ticks."""
    s = LOOP_SECONDS + XFADE
    out = _sub_drone(s, ((36.7, 0.55), (37.4, 0.55), (55.0, 0.22), (73.4, 0.1)), pulse_hz=0.62)
    seed(51)
    mix(out, svf(noise(s), lambda x: 280 + 260 * math.sin(math.tau * 0.12 * x * s), 2.2), 0.0, 0.42)
    mix(out, grit(lowpass(_crackle(s, 4, 52, 1600, 0.18), 1400), 0.35), 0.0, 0.55)
    mix(out, _chimes(s, 2, ("A4", "C#5"), 53, 0.04, PLASMA))
    return _seamless(reverb(ring_mod(out, 18.5, 0.08), room=0.9, wet=0.36, tail=0.0))


LOOPS = {
    "amb_heart": heart,
    "amb_ember": ember,
    "amb_hollows": hollows,
    "amb_spire": spire,
    "amb_riftmaw": riftmaw,
}


def render(name: str):
    return normalize(LOOPS[name](), -9.0)
