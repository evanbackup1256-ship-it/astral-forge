"""Every one-shot sound in Astral Forge, designed from scratch.

Each voice is a small recipe over synth.py. The palette sits in D major
pentatonic (D E F# A B) so chimes, rewards and the sanctuary all agree with
one another and with the soundtrack's key.

Voices are packed into one sound sheet (see build.py): Roblox caps audio
uploads per month, so the whole set ships as a single file and the game plays
each voice as a PlaybackRegion slice of it.
"""

from __future__ import annotations

import math

from synth import (
    BELL, COIN, GLASS, METAL, SR, apply_env, bell, delay, env_adsr, env_exp, env_swell, fade, fm, frames, glide,
    highpass, lowpass, mix, noise, normalize, note, reverb, scale, seed, sine, softclip, svf, sweep, trim_tail, zeros,
)

PENTA_HIGH = [note(n) for n in ("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7")]


def click_transient(center: float = 3200, seconds: float = 0.006, amp: float = 0.5):
    return apply_env(svf(noise(seconds), center, 1.4), env_exp(seconds, seconds * 0.35))


def thump(f0: float = 180, f1: float = 60, seconds: float = 0.12, amp: float = 0.8):
    return apply_env(glide(f0, f1, seconds, amp), env_exp(seconds, seconds * 0.3))


# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------

def ui_hover():
    body = apply_env(bell(note("A6"), 0.12, 0.55, GLASS, 0.5), env_exp(0.12, 0.028))
    return reverb(body, room=0.3, wet=0.12, tail=0.2)


def ui_click():
    out = zeros(0.1)
    mix(out, click_transient(3400, 0.005), 0.0, 0.7)
    mix(out, apply_env(glide(1046, 930, 0.07, 0.55), env_exp(0.07, 0.018)))
    mix(out, thump(210, 90, 0.05, 0.5))
    return out


def ui_tick():
    out = apply_env(sine(note("D7"), 0.035, 0.5), env_exp(0.035, 0.007))
    return mix(out, click_transient(5200, 0.003), 0.0, 0.35)


def ui_confirm():
    out = zeros(0.5)
    mix(out, apply_env(bell(note("D6"), 0.4, 0.7, GLASS), env_exp(0.4, 0.14)))
    mix(out, apply_env(bell(note("A6"), 0.45, 0.8, GLASS), env_exp(0.45, 0.18)), 0.065)
    return reverb(out, room=0.45, wet=0.22, tail=0.5)


def ui_open():
    air = apply_env(svf(noise(0.32), sweep(700, 5200), 1.1), env_swell(0.32, 0.55))
    out = scale(air, 0.55)
    mix(out, apply_env(bell(note("F#6"), 0.3, 0.45, GLASS), env_exp(0.3, 0.12)), 0.12)
    return reverb(out, room=0.4, wet=0.2, tail=0.4)


def ui_close():
    air = apply_env(svf(noise(0.26), sweep(4200, 520), 1.1), env_swell(0.26, 0.35))
    out = scale(air, 0.5)
    mix(out, apply_env(bell(note("D6"), 0.25, 0.3, GLASS), env_exp(0.25, 0.08)), 0.02)
    return reverb(out, room=0.35, wet=0.15, tail=0.3)


def ui_toggle_on():
    out = zeros(0.16)
    mix(out, apply_env(sine(note("A5"), 0.06, 0.6), env_exp(0.06, 0.02)))
    mix(out, apply_env(sine(note("E6"), 0.09, 0.6), env_exp(0.09, 0.03)), 0.05)
    return mix(out, click_transient(4000, 0.003), 0.0, 0.3)


def ui_toggle_off():
    out = zeros(0.16)
    mix(out, apply_env(sine(note("E6"), 0.06, 0.55), env_exp(0.06, 0.02)))
    mix(out, apply_env(sine(note("A5"), 0.09, 0.55), env_exp(0.09, 0.03)), 0.05)
    return mix(out, click_transient(2600, 0.003), 0.0, 0.3)


def ui_error():
    out = zeros(0.34)
    for i, f in enumerate((note("A3"), note("A3") * 0.97)):
        tone = lowpass(glide(f, f * 0.98, 0.11, 0.7, wave_shape="saw"), 1400)
        mix(out, apply_env(tone, env_adsr(0.11, 0.004, 0.03, 0.6, 0.05)), i * 0.12)
    return reverb(out, room=0.3, wet=0.1, tail=0.2)


def ui_locked():
    out = zeros(0.25)
    mix(out, thump(170, 80, 0.14, 0.9))
    mix(out, lowpass(apply_env(noise(0.02), env_exp(0.02, 0.006)), 1800), 0.0, 0.5)
    mix(out, apply_env(sine(note("D4"), 0.18, 0.25), env_exp(0.18, 0.05)), 0.01)
    return out


def ui_notify():
    out = zeros(0.8)
    for i, n in enumerate(("D6", "F#6", "A6")):
        mix(out, apply_env(bell(note(n), 0.6, 0.6, GLASS), env_exp(0.6, 0.22)), i * 0.075)
    return reverb(out, room=0.55, wet=0.28, tail=0.7)


def ui_warn():
    out = zeros(0.5)
    mix(out, apply_env(fm(note("F#5"), 2.0, 1.4, 0.25, 0.1, 0.6), env_exp(0.25, 0.1)))
    mix(out, apply_env(fm(note("D5"), 2.0, 1.4, 0.3, 0.1, 0.6), env_exp(0.3, 0.12)), 0.14)
    return reverb(out, room=0.4, wet=0.18, tail=0.4)


def ui_page():
    air = apply_env(svf(noise(0.2), sweep(1600, 4600), 1.3), env_swell(0.2, 0.4))
    return reverb(scale(air, 0.6), room=0.3, wet=0.12, tail=0.2)


def ui_pop():
    out = apply_env(glide(520, 1500, 0.08, 0.8), env_adsr(0.08, 0.004, 0.02, 0.6, 0.05))
    return mix(out, click_transient(3000, 0.003), 0.0, 0.2)


def ui_slider():
    return apply_env(sine(note("F#6"), 0.03, 0.5), env_exp(0.03, 0.006))


def ui_type():
    out = click_transient(2400, 0.004)
    return mix(out, apply_env(sine(1600, 0.02, 0.3), env_exp(0.02, 0.005)))


def chat_ping():
    out = apply_env(fm(note("E6"), 2.0, 2.4, 0.3, 0.05, 0.7), env_exp(0.3, 0.09))
    return reverb(out, room=0.4, wet=0.18, tail=0.35)


def card_flip():
    out = apply_env(svf(noise(0.05), 3200, 1.0), env_exp(0.05, 0.012))
    return mix(scale(out, 0.8), thump(260, 120, 0.04, 0.3))


def wheel_tick():
    out = apply_env(sine(1250, 0.03, 0.6), env_exp(0.03, 0.006))
    return mix(out, click_transient(3800, 0.003), 0.0, 0.5)


# ---------------------------------------------------------------------------
# Currency and rewards
# ---------------------------------------------------------------------------

def sparkle(seconds: float, density: int, amp: float = 0.25, low: int = 2, seed_value: int = 7):
    seed(seed_value)
    import random as _r
    rng = _r.Random(seed_value)
    out = zeros(seconds + 0.3)
    for k in range(density):
        at = seconds * (k / density) + rng.random() * 0.02
        f = PENTA_HIGH[rng.randrange(low, len(PENTA_HIGH))]
        mix(out, apply_env(bell(f, 0.25, amp * (1 - 0.5 * k / density), GLASS, 0.6), env_exp(0.25, 0.06)), at)
    return out


def coin():
    out = zeros(0.6)
    mix(out, apply_env(bell(note("B6"), 0.45, 0.8, COIN), env_exp(0.45, 0.16)))
    mix(out, apply_env(bell(note("E7"), 0.4, 0.55, COIN), env_exp(0.4, 0.12)), 0.055)
    return reverb(out, room=0.4, wet=0.18, tail=0.4)


def collect():
    out = zeros(0.6)
    for i, n in enumerate(("D6", "E6", "F#6", "A6", "B6", "D7")):
        mix(out, apply_env(bell(note(n), 0.3, 0.45, GLASS), env_exp(0.3, 0.09)), i * 0.034)
    return reverb(out, room=0.5, wet=0.25, tail=0.6)


def reward():
    out = zeros(1.8)
    for i, n in enumerate(("D5", "F#5", "A5", "D6")):
        mix(out, apply_env(bell(note(n), 1.6, 0.55, BELL, 0.8), env_exp(1.6, 0.6)), i * 0.022)
    pad = zeros(1.6)
    for n in ("D4", "A4", "F#5"):
        mix(pad, glide(note(n), note(n) * 1.002, 1.6, 0.18))
    mix(out, apply_env(pad, env_swell(1.6, 0.25, 1.4)))
    mix(out, sparkle(0.8, 10, 0.18, seed_value=11), 0.12)
    return reverb(out, room=0.75, wet=0.32, tail=1.4)


def unlock():
    out = zeros(1.4)
    for i, n in enumerate(("A4", "D5", "F#5", "A5", "D6")):
        mix(out, apply_env(bell(note(n), 0.9, 0.5, BELL, 0.7), env_exp(0.9, 0.35)), i * 0.06)
    mix(out, sparkle(0.6, 8, 0.16, low=3, seed_value=23), 0.3)
    return reverb(out, room=0.7, wet=0.3, tail=1.2)


def purchase():
    out = coin()
    mix(out, thump(140, 60, 0.12, 0.6))
    mix(out, sparkle(0.25, 4, 0.12, low=4, seed_value=31), 0.08)
    return out


def claim():
    out = zeros(1.0)
    mix(out, apply_env(bell(note("D6"), 0.8, 0.6, BELL, 0.9), env_exp(0.8, 0.3)))
    mix(out, apply_env(bell(note("A6"), 0.8, 0.5, BELL, 0.9), env_exp(0.8, 0.3)), 0.01)
    mix(out, sparkle(0.45, 6, 0.16, low=3, seed_value=41), 0.1)
    return reverb(out, room=0.6, wet=0.26, tail=0.9)


def prestige():
    seconds = 2.6
    pad = zeros(seconds)
    for n in ("D3", "A3", "D4", "F#4", "A4"):
        f = note(n)
        mix(pad, lowpass(glide(f, f * 1.003, seconds, 0.22, wave_shape="saw"), 1800))
        mix(pad, lowpass(glide(f * 1.004, f, seconds, 0.12, wave_shape="saw"), 1500))
    out = apply_env(pad, env_swell(seconds, 0.55, 1.6))
    for i, n in enumerate(("D5", "A5", "D6", "F#6")):
        mix(out, apply_env(bell(note(n), 1.4, 0.4, BELL), env_exp(1.4, 0.55)), 1.3 + i * 0.03)
    mix(out, apply_env(glide(90, 40, 1.0, 0.7), env_exp(1.0, 0.3)), 1.3)
    mix(out, sparkle(1.0, 12, 0.14, seed_value=53), 1.35)
    return reverb(out, room=0.85, wet=0.34, tail=2.0)


# ---------------------------------------------------------------------------
# Forge and machines
# ---------------------------------------------------------------------------

def hammer():
    out = zeros(0.9)
    mix(out, apply_env(bell(520, 0.8, 0.8, METAL, 1.0), env_exp(0.8, 0.22)))
    mix(out, apply_env(highpass(noise(0.03), 1800), env_exp(0.03, 0.008)), 0.0, 0.8)
    mix(out, thump(160, 70, 0.18, 0.8))
    return reverb(softclip(out, 1.3), room=0.5, wet=0.2, tail=0.6)


def machine():
    out = zeros(0.7)
    mix(out, thump(150, 55, 0.16, 0.9))
    mix(out, apply_env(bell(310, 0.3, 0.4, METAL, 0.6), env_exp(0.3, 0.07)))
    whir = lowpass(glide(170, 420, 0.42, 0.35, wave_shape="saw"), 1200)
    mix(out, apply_env(whir, env_swell(0.42, 0.5)), 0.1)
    return reverb(out, room=0.4, wet=0.14, tail=0.4)


def whoosh():
    air = apply_env(svf(noise(0.5), sweep(380, 3200), 0.9), env_swell(0.5, 0.6, 1.6))
    return reverb(scale(air, 0.9), room=0.5, wet=0.2, tail=0.5)


def rumble():
    body = lowpass(noise(1.5), 140)
    out = apply_env(scale(body, 3.2), env_swell(1.5, 0.3, 1.2))
    mix(out, apply_env(glide(48, 38, 1.5, 0.5), env_swell(1.5, 0.3)))
    return softclip(out, 1.2)


def impact():
    out = zeros(1.4)
    mix(out, apply_env(glide(130, 32, 1.0, 1.0), env_exp(1.0, 0.28)))
    mix(out, apply_env(lowpass(noise(0.3), 900), env_exp(0.3, 0.06)), 0.0, 1.2)
    mix(out, apply_env(bell(140, 0.6, 0.35, METAL, 0.5), env_exp(0.6, 0.2)))
    return reverb(softclip(out, 1.6), room=0.7, wet=0.22, tail=1.0)


def charge():
    seconds = 1.2
    rise = apply_env(svf(noise(seconds), sweep(300, 6200), 1.4), env_swell(seconds, 0.92, 2.2))
    tone = glide(220, 880, seconds, 0.3)
    trem = [0.6 + 0.4 * math.sin(math.tau * (4 + 16 * (i / frames(seconds))) * i / SR) for i in range(frames(seconds))]
    tone = apply_env(apply_env(tone, trem), env_swell(seconds, 0.95, 1.8))
    out = mix(scale(rise, 0.7), tone)
    return reverb(out, room=0.5, wet=0.2, tail=0.5)


def spark():
    import random as _r
    rng = _r.Random(99)
    out = zeros(0.45)
    for _ in range(14):
        at = rng.random() * 0.35
        burst = apply_env(highpass(noise(0.008), 2800), env_exp(0.008, 0.002))
        mix(out, burst, at, 0.5 + rng.random() * 0.5)
    return reverb(out, room=0.3, wet=0.12, tail=0.25)


def boot_ignite():
    seconds = 1.3
    roar = apply_env(svf(noise(seconds), sweep(200, 2400), 0.8), env_swell(seconds, 0.35, 1.5))
    out = scale(roar, 1.1)
    mix(out, spark(), 0.2, 0.6)
    mix(out, apply_env(glide(90, 40, 0.9, 0.8), env_exp(0.9, 0.3)), 0.3)
    return reverb(softclip(out, 1.3), room=0.6, wet=0.2, tail=0.8)


# ---------------------------------------------------------------------------
# The sanctuary: crystals, the rift, the Warden
# ---------------------------------------------------------------------------

def crystal_mine():
    import random as _r
    rng = _r.Random(5)
    out = zeros(0.9)
    mix(out, apply_env(highpass(noise(0.015), 3500), env_exp(0.015, 0.004)), 0.0, 0.7)
    for i in range(4):
        f = PENTA_HIGH[rng.randrange(1, len(PENTA_HIGH))]
        mix(out, apply_env(bell(f, 0.7, 0.45, GLASS, 0.9), env_exp(0.7, 0.2)), i * 0.028 + rng.random() * 0.01)
    mix(out, thump(300, 140, 0.05, 0.35))
    return reverb(out, room=0.6, wet=0.3, tail=0.7)


def crystal_collect():
    out = zeros(0.6)
    for i, n in enumerate(("F#6", "A6", "D7")):
        mix(out, apply_env(bell(note(n), 0.35, 0.5, GLASS), env_exp(0.35, 0.1)), i * 0.045)
    mix(out, sparkle(0.25, 5, 0.12, low=4, seed_value=61), 0.1)
    return reverb(out, room=0.55, wet=0.28, tail=0.6)


def rift_open():
    seconds = 1.8
    out = zeros(seconds)
    drone = mix(sine(55, seconds, 0.6), sine(82.4, seconds, 0.35))
    mix(out, apply_env(drone, env_swell(seconds, 0.45, 1.5)))
    wash = apply_env(svf(noise(seconds), sweep(900, 3600), 1.8), env_swell(seconds, 0.5, 1.4))
    mix(out, wash, 0.0, 0.35)
    mix(out, sparkle(1.0, 9, 0.14, seed_value=71), 0.5)
    return reverb(out, room=0.85, wet=0.36, tail=1.6)


def warden_forming():
    seconds = 2.8
    out = zeros(seconds)
    for f, amp in ((73.42, 0.35), (73.9, 0.35), (110.0, 0.2)):
        mix(out, lowpass(glide(f, f * 1.01, seconds, amp, wave_shape="saw"), 420))
    voice = zeros(seconds)
    for n in ("A3", "D4"):
        f = note(n)
        vib = [math.sin(math.tau * f * (i / SR) + 0.004 * f * math.sin(math.tau * 5.2 * i / SR)) for i in range(frames(seconds))]
        mix(voice, scale(vib, 0.14))
    mix(out, voice)
    mix(out, svf(noise(seconds), sweep(300, 1600), 2.0), 0.0, 0.25)
    out = apply_env(out, env_swell(seconds, 0.8, 1.4))
    return reverb(out, room=0.9, wet=0.38, tail=2.0)


def warden_awake():
    out = zeros(2.0)
    growl = apply_env(fm(55, 1.5, 6.0, 1.6, 0.8, 0.8), env_swell(1.6, 0.25, 1.2))
    mix(out, softclip(lowpass(growl, 900), 2.0))
    roar = apply_env(svf(noise(1.4), sweep(1400, 380), 0.9), env_swell(1.4, 0.2, 1.3))
    mix(out, roar, 0.05, 0.6)
    mix(out, impact(), 0.0, 0.7)
    return reverb(out, room=0.85, wet=0.3, tail=1.4)


def warden_strike():
    out = zeros(0.45)
    mix(out, apply_env(svf(noise(0.04), 2600, 1.2), env_exp(0.04, 0.01)), 0.0, 0.9)
    mix(out, apply_env(bell(880, 0.35, 0.55, METAL, 0.9), env_exp(0.35, 0.08)))
    mix(out, apply_env(bell(note("D7"), 0.3, 0.25, GLASS), env_exp(0.3, 0.07)), 0.01)
    mix(out, thump(240, 90, 0.08, 0.6))
    return reverb(out, room=0.5, wet=0.18, tail=0.35)


def warden_crit():
    out = zeros(0.8)
    mix(out, warden_strike(), 0.0, 1.0)
    mix(out, thump(210, 60, 0.3, 1.0))
    mix(out, apply_env(bell(660, 0.6, 0.45, METAL), env_exp(0.6, 0.18)), 0.01)
    for i, n in enumerate(("D7", "A7")):
        mix(out, apply_env(bell(note(n), 0.5, 0.3, GLASS), env_exp(0.5, 0.14)), 0.03 + i * 0.04)
    return reverb(softclip(out, 1.4), room=0.6, wet=0.22, tail=0.6)


def slam_charge():
    seconds = 1.6
    n = frames(seconds)
    whine = glide(110, 440, seconds, 0.45)
    trem = [0.5 + 0.5 * math.sin(math.tau * (3 + 18 * (i / n) ** 2) * i / SR) for i in range(n)]
    out = apply_env(apply_env(whine, trem), env_swell(seconds, 0.97, 2.0))
    mix(out, apply_env(svf(noise(seconds), sweep(200, 2600), 1.6), env_swell(seconds, 0.97, 2.2)), 0.0, 0.45)
    mix(out, apply_env(lowpass(noise(seconds), 120), env_swell(seconds, 0.9)), 0.0, 1.6)
    return reverb(out, room=0.7, wet=0.25, tail=0.6)


def slam():
    import random as _r
    rng = _r.Random(17)
    out = zeros(1.8)
    mix(out, apply_env(glide(92, 26, 1.3, 1.2), env_exp(1.3, 0.4)))
    mix(out, apply_env(lowpass(noise(0.5), 1100), env_exp(0.5, 0.1)), 0.0, 1.4)
    for _ in range(26):
        at = 0.05 + rng.random() * 0.9
        chip = apply_env(lowpass(noise(0.012), 2600), env_exp(0.012, 0.004))
        mix(out, chip, at, 0.2 + rng.random() * 0.4)
    return reverb(softclip(out, 1.9), room=0.9, wet=0.28, tail=1.6)


def warden_defeat():
    import random as _r
    rng = _r.Random(29)
    out = zeros(3.2)
    for _ in range(34):
        at = rng.random() ** 1.7 * 0.6
        f = PENTA_HIGH[rng.randrange(0, len(PENTA_HIGH))] * (1 + rng.random() * 0.01)
        mix(out, apply_env(bell(f, 0.5, 0.22, GLASS, 1.0), env_exp(0.5, 0.12)), at)
    mix(out, apply_env(highpass(noise(0.9), 2500), env_exp(0.9, 0.18)), 0.0, 0.6)
    mix(out, impact(), 0.0, 0.8)
    for i, n in enumerate(("D4", "A4", "D5", "F#5", "A5")):
        mix(out, apply_env(bell(note(n), 2.2, 0.35, BELL), env_exp(2.2, 0.8)), 0.45 + i * 0.05)
    pad = zeros(2.4)
    for n in ("D3", "A3", "F#4"):
        mix(pad, lowpass(glide(note(n), note(n) * 1.002, 2.4, 0.18, wave_shape="saw"), 1600))
    mix(out, apply_env(pad, env_swell(2.4, 0.3, 1.2)), 0.45)
    return reverb(out, room=0.92, wet=0.36, tail=2.2)


def warden_escape():
    seconds = 1.9
    n = frames(seconds)
    swell = apply_env(svf(noise(seconds), sweep(3000, 300), 1.2), env_swell(seconds, 0.7, 2.4))
    out = scale(swell, 0.8)
    fall = apply_env(glide(440, 50, seconds, 0.5), env_swell(seconds, 0.6, 1.6))
    mix(out, fall)
    return reverb(out, room=0.85, wet=0.34, tail=1.4)


def waystone():
    seconds = 1.2
    out = zeros(seconds)
    for i, n in enumerate(("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7")):
        mix(out, apply_env(bell(note(n), 0.4, 0.28, GLASS), env_exp(0.4, 0.1)), i * 0.06)
    mix(out, apply_env(svf(noise(seconds), sweep(500, 8000), 1.2), env_swell(seconds, 0.75, 1.8)), 0.0, 0.5)
    mix(out, thump(120, 45, 0.4, 0.7), 0.85)
    return reverb(out, room=0.75, wet=0.32, tail=1.2)


def region_enter():
    seconds = 1.8
    pad = zeros(seconds)
    for n in ("A3", "D4", "F#4", "A4"):
        mix(pad, sine(note(n), seconds, 0.18))
        mix(pad, sine(note(n) * 1.003, seconds, 0.1))
    out = apply_env(pad, env_swell(seconds, 0.4, 1.3))
    mix(out, apply_env(bell(note("D6"), 1.0, 0.35, BELL, 0.7), env_exp(1.0, 0.4)), 0.55)
    return reverb(out, room=0.85, wet=0.34, tail=1.4)


VOICES = {
    "ui_hover": ui_hover,
    "ui_click": ui_click,
    "ui_tick": ui_tick,
    "ui_confirm": ui_confirm,
    "ui_open": ui_open,
    "ui_close": ui_close,
    "ui_toggle_on": ui_toggle_on,
    "ui_toggle_off": ui_toggle_off,
    "ui_error": ui_error,
    "ui_locked": ui_locked,
    "ui_notify": ui_notify,
    "ui_warn": ui_warn,
    "ui_page": ui_page,
    "ui_pop": ui_pop,
    "ui_slider": ui_slider,
    "ui_type": ui_type,
    "chat_ping": chat_ping,
    "card_flip": card_flip,
    "wheel_tick": wheel_tick,
    "coin": coin,
    "collect": collect,
    "reward": reward,
    "unlock": unlock,
    "purchase": purchase,
    "claim": claim,
    "prestige": prestige,
    "hammer": hammer,
    "machine": machine,
    "whoosh": whoosh,
    "rumble": rumble,
    "impact": impact,
    "charge": charge,
    "spark": spark,
    "boot_ignite": boot_ignite,
    "crystal_mine": crystal_mine,
    "crystal_collect": crystal_collect,
    "rift_open": rift_open,
    "warden_forming": warden_forming,
    "warden_awake": warden_awake,
    "warden_strike": warden_strike,
    "warden_crit": warden_crit,
    "slam_charge": slam_charge,
    "slam": slam,
    "warden_defeat": warden_defeat,
    "warden_escape": warden_escape,
    "waystone": waystone,
    "region_enter": region_enter,
}


def render(name: str):
    """One voice, finished: tail trimmed, faded and peak-normalised to -3 dBFS."""
    buf = VOICES[name]()
    return normalize(trim_tail(fade(buf, 0.001, 0.01)), -3.0)
