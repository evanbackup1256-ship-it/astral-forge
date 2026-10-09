"""Every one-shot sound in Astral Forge, designed from scratch.

Each game cue gets its own voice on the sound sheet (Roblox caps monthly
audio uploads, so everything ships as one file and plays as a PlaybackRegion).

The palette sits in a dark D / F# / A / C# cluster with neon accents so UI,
forge metal, sanctuary voidglass and boss pressure stay in one universe while
remaining distinct from each other.
"""

from __future__ import annotations

import math
import random as _random

from synth import (
    BELL, COIN, CRYSTAL, GLASS, IRON, METAL, NEON, PLASMA, SR, VOID,
    apply_env, bell, env_adsr, env_exp, env_swell, fade, fm, frames,
    glide, grit, highpass, lowpass, mix, noise, normalize, note, pulse,
    reverb, ring_mod, scale, seed, sine, softclip, svf, sweep, trim_tail, zeros,
)

# Re-declare local helpers used heavily (kept next to recipes for readability).


def click_transient(center: float = 3200, seconds: float = 0.006, amp: float = 0.5):
    return apply_env(svf(noise(seconds), center, 1.4), env_exp(seconds, seconds * 0.35))


def thump(f0: float = 180, f1: float = 60, seconds: float = 0.12, amp: float = 0.8):
    return apply_env(glide(f0, f1, seconds, amp), env_exp(seconds, seconds * 0.3))


PENTA_HIGH = [note(n) for n in ("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7")]
DARK_HIGH = [note(n) for n in ("C#6", "F#6", "A6", "C#7", "E7", "F#7", "A7")]
VOID_MID = [note(n) for n in ("A3", "C#4", "F#4", "A4", "C#5", "F#5")]


def sparkle(seconds: float, density: int, amp: float = 0.25, low: int = 2, seed_value: int = 7, palette=None):
    seed(seed_value)
    rng = _random.Random(seed_value)
    palette = palette or PENTA_HIGH
    out = zeros(seconds + 0.3)
    for k in range(density):
        at = seconds * (k / max(1, density)) + rng.random() * 0.02
        f = palette[rng.randrange(low, len(palette))]
        mix(out, apply_env(bell(f, 0.25, amp * (1 - 0.5 * k / max(1, density)), GLASS, 0.6), env_exp(0.25, 0.06)), at)
    return out


# ---------------------------------------------------------------------------
# Family recipes — each cue picks a unique param set so nothing aliases.
# ---------------------------------------------------------------------------

def chrome_blip(pitch: float, seconds: float = 0.05, neon: float = 0.4, seed_value: int = 1):
    """Thin pointer chrome: hover / tick / scroll / slider."""
    seed(seed_value)
    body = apply_env(pulse(pitch, seconds, 0.55, 0.18), env_exp(seconds, seconds * 0.22))
    mix(body, apply_env(sine(pitch * 2.01, seconds * 0.7, 0.25), env_exp(seconds * 0.7, seconds * 0.15)))
    if neon > 0:
        mix(body, apply_env(bell(pitch * 1.5, seconds * 1.4, neon * 0.35, NEON, 0.8), env_exp(seconds * 1.4, seconds * 0.35)))
    mix(body, click_transient(pitch * 2.2, 0.003, 0.35))
    return body


def ui_press(f0: float, f1: float, thump_f: float = 200, metal: float = 0.0, seed_value: int = 2):
    """Committed UI press with optional iron edge."""
    seed(seed_value)
    out = zeros(0.14)
    mix(out, click_transient(f0 * 2.8, 0.005, 0.75))
    mix(out, apply_env(glide(f0, f1, 0.08, 0.6), env_exp(0.08, 0.02)))
    mix(out, thump(thump_f, thump_f * 0.42, 0.06, 0.55))
    if metal > 0:
        mix(out, apply_env(bell(f0 * 0.55, 0.12, metal * 0.45, IRON, 0.7), env_exp(0.12, 0.03)))
    return out


def ui_chime(notes, room: float = 0.45, kind=GLASS, spacing: float = 0.06, amp: float = 0.65):
    out = zeros(0.15 + len(notes) * spacing + 0.5)
    for i, n in enumerate(notes):
        f = note(n) if isinstance(n, str) else n
        mix(out, apply_env(bell(f, 0.45, amp * (1 - i * 0.08), kind), env_exp(0.45, 0.16)), i * spacing)
    return reverb(out, room=room, wet=0.18 + room * 0.15, tail=0.4 + room * 0.4)


def panel_air(up: bool, bright: float = 1.0, chime: str | None = None, seed_value: int = 3):
    seed(seed_value)
    seconds = 0.28 if up else 0.24
    f0, f1 = (700 * bright, 5200 * bright) if up else (4200 * bright, 480 * bright)
    air = apply_env(svf(noise(seconds), sweep(f0, f1), 1.1), env_swell(seconds, 0.55 if up else 0.35))
    out = scale(air, 0.55)
    if chime:
        mix(out, apply_env(bell(note(chime), 0.28, 0.4, NEON if up else GLASS), env_exp(0.28, 0.1)), 0.08 if up else 0.02)
    return reverb(out, room=0.38, wet=0.18, tail=0.35)


def deny_buzz(base: float, beats: int = 2, grit_amt: float = 0.35):
    out = zeros(0.14 * beats + 0.12)
    for i in range(beats):
        tone = lowpass(glide(base, base * 0.97, 0.1, 0.7, wave_shape="saw"), 1400)
        mix(out, apply_env(grit(tone, grit_amt), env_adsr(0.1, 0.004, 0.03, 0.55, 0.05)), i * 0.12)
    return reverb(out, room=0.28, wet=0.1, tail=0.18)


def lock_thud(f0: float = 170, ring: float = 0.0):
    out = zeros(0.28)
    mix(out, thump(f0, f0 * 0.45, 0.14, 0.9))
    mix(out, lowpass(apply_env(noise(0.02), env_exp(0.02, 0.006)), 1800), 0.0, 0.5)
    if ring > 0:
        mix(out, apply_env(sine(ring, 0.18, 0.28), env_exp(0.18, 0.05)), 0.01)
    return out


def coin_voice(high: str, spark: int = 0, body: float = 0.6, seed_value: int = 11):
    out = zeros(0.65)
    mix(out, apply_env(bell(note(high), 0.45, 0.8, COIN), env_exp(0.45, 0.16)))
    mix(out, apply_env(bell(note(high) * 1.5, 0.4, 0.5, COIN), env_exp(0.4, 0.12)), 0.05)
    mix(out, thump(140, 60, 0.1, body * 0.5))
    if spark:
        mix(out, sparkle(0.25, spark, 0.12, low=4, seed_value=seed_value), 0.06)
    return reverb(out, room=0.4, wet=0.18, tail=0.4)


def collect_run(notes, spacing: float = 0.034, kind=GLASS):
    out = zeros(0.2 + len(notes) * spacing + 0.4)
    for i, n in enumerate(notes):
        mix(out, apply_env(bell(note(n), 0.3, 0.45, kind), env_exp(0.3, 0.09)), i * spacing)
    return reverb(out, room=0.5, wet=0.25, tail=0.55)


def reward_bloom(notes, pad_notes=None, spark_n: int = 8, seconds: float = 1.6, seed_value: int = 21):
    out = zeros(seconds + 0.4)
    for i, n in enumerate(notes):
        mix(out, apply_env(bell(note(n), seconds * 0.9, 0.55, BELL, 0.8), env_exp(seconds * 0.9, seconds * 0.35)), i * 0.022)
    if pad_notes:
        pad = zeros(seconds)
        for n in pad_notes:
            mix(pad, glide(note(n), note(n) * 1.002, seconds, 0.16))
        mix(out, apply_env(pad, env_swell(seconds, 0.25, 1.4)))
    if spark_n:
        mix(out, sparkle(0.8, spark_n, 0.16, seed_value=seed_value), 0.1)
    return reverb(out, room=0.72, wet=0.3, tail=1.2)


def claim_chime(a: str, b: str, spark_n: int = 5, seed_value: int = 41):
    out = zeros(1.0)
    mix(out, apply_env(bell(note(a), 0.8, 0.6, BELL, 0.9), env_exp(0.8, 0.3)))
    mix(out, apply_env(bell(note(b), 0.8, 0.5, CRYSTAL, 0.9), env_exp(0.8, 0.3)), 0.012)
    mix(out, sparkle(0.4, spark_n, 0.15, low=3, seed_value=seed_value, palette=DARK_HIGH), 0.08)
    return reverb(out, room=0.58, wet=0.26, tail=0.85)


def metal_hit(fund: float, grit_amt: float = 0.4, thump_f: float = 160, room: float = 0.5):
    out = zeros(0.85)
    mix(out, apply_env(bell(fund, 0.75, 0.8, IRON if grit_amt > 0.3 else METAL, 1.0), env_exp(0.75, 0.2)))
    mix(out, apply_env(highpass(noise(0.03), 1600), env_exp(0.03, 0.008)), 0.0, 0.75 + grit_amt)
    mix(out, thump(thump_f, thump_f * 0.4, 0.16, 0.8))
    return reverb(softclip(out, 1.2 + grit_amt * 0.4), room=room, wet=0.18, tail=0.55)


def machine_clunk(f0: float = 150, whir_to: float = 420, saw: bool = True):
    out = zeros(0.7)
    mix(out, thump(f0, f0 * 0.35, 0.16, 0.9))
    mix(out, apply_env(bell(f0 * 2.1, 0.28, 0.4, METAL, 0.6), env_exp(0.28, 0.07)))
    whir = lowpass(glide(f0 * 1.1, whir_to, 0.42, 0.35, wave_shape="saw" if saw else "tri"), 1200)
    mix(out, apply_env(whir, env_swell(0.42, 0.5)), 0.1)
    return reverb(out, room=0.4, wet=0.14, tail=0.35)


def whoosh_air(f0: float, f1: float, seconds: float = 0.5, wet: float = 0.2):
    air = apply_env(svf(noise(seconds), sweep(f0, f1), 0.9), env_swell(seconds, 0.6, 1.6))
    return reverb(scale(air, 0.9), room=0.5, wet=wet, tail=0.45)


def rumble_bed(seconds: float = 1.5, low: float = 140, tone: float = 48):
    body = lowpass(noise(seconds), low)
    out = apply_env(scale(body, 3.2), env_swell(seconds, 0.3, 1.2))
    mix(out, apply_env(glide(tone, tone * 0.8, seconds, 0.5), env_swell(seconds, 0.3)))
    return softclip(out, 1.2)


def impact_hit(f0: float = 130, cutoff: float = 900, metal_f: float = 140):
    out = zeros(1.35)
    mix(out, apply_env(glide(f0, f0 * 0.25, 1.0, 1.0), env_exp(1.0, 0.28)))
    mix(out, apply_env(lowpass(noise(0.3), cutoff), env_exp(0.3, 0.06)), 0.0, 1.2)
    mix(out, apply_env(bell(metal_f, 0.55, 0.35, METAL, 0.5), env_exp(0.55, 0.18)))
    return reverb(softclip(out, 1.55), room=0.68, wet=0.22, tail=0.95)


def charge_rise(f0: float, f1: float, seconds: float = 1.15, noise_hi: float = 6200):
    rise = apply_env(svf(noise(seconds), sweep(300, noise_hi), 1.4), env_swell(seconds, 0.92, 2.2))
    tone = glide(f0, f1, seconds, 0.3)
    n = frames(seconds)
    trem = [0.6 + 0.4 * math.sin(math.tau * (4 + 16 * (i / n)) * i / SR) for i in range(n)]
    tone = apply_env(apply_env(tone, trem), env_swell(seconds, 0.95, 1.8))
    out = mix(scale(rise, 0.7), tone)
    return reverb(out, room=0.48, wet=0.2, tail=0.45)


def spark_burst(count: int = 14, seed_value: int = 99, hi: float = 2800):
    rng = _random.Random(seed_value)
    out = zeros(0.45)
    for _ in range(count):
        at = rng.random() * 0.35
        burst = apply_env(highpass(noise(0.008), hi), env_exp(0.008, 0.002))
        mix(out, burst, at, 0.5 + rng.random() * 0.5)
    return reverb(out, room=0.28, wet=0.12, tail=0.22)


def void_swell(seconds: float, drones, wash=(900, 3600), spark_n: int = 0, seed_value: int = 71):
    out = zeros(seconds)
    drone = zeros(seconds)
    for f, amp in drones:
        mix(drone, sine(f, seconds, amp))
    mix(out, apply_env(drone, env_swell(seconds, 0.45, 1.5)))
    wash_buf = apply_env(svf(noise(seconds), sweep(wash[0], wash[1]), 1.8), env_swell(seconds, 0.5, 1.4))
    mix(out, wash_buf, 0.0, 0.32)
    if spark_n:
        mix(out, sparkle(1.0, spark_n, 0.12, seed_value=seed_value, palette=DARK_HIGH), 0.4)
    return reverb(ring_mod(out, 37.5, 0.12), room=0.85, wet=0.34, tail=1.5)


def crystal_shatter(seed_value: int = 5, hits: int = 4, palette=None):
    rng = _random.Random(seed_value)
    palette = palette or PENTA_HIGH
    out = zeros(0.9)
    mix(out, apply_env(highpass(noise(0.015), 3500), env_exp(0.015, 0.004)), 0.0, 0.7)
    for i in range(hits):
        f = palette[rng.randrange(1, len(palette))]
        mix(out, apply_env(bell(f, 0.65, 0.45, CRYSTAL, 0.9), env_exp(0.65, 0.18)), i * 0.028 + rng.random() * 0.01)
    mix(out, thump(300, 140, 0.05, 0.32))
    return reverb(out, room=0.6, wet=0.3, tail=0.65)


def mechanism_tick(pitch: float, click_hz: float = 3800):
    out = apply_env(sine(pitch, 0.03, 0.6), env_exp(0.03, 0.006))
    return mix(out, click_transient(click_hz, 0.003), 0.0, 0.5)


def soft_blip(pitch: float, seconds: float = 0.07, shimmer: float = 0.25):
    """A rounded pointer blip: a sine with a 3 ms attack and a quiet octave, no click edge."""
    body = apply_env(sine(pitch, seconds, 0.5), env_adsr(seconds, 0.003, seconds * 0.4, 0.3, seconds * 0.5))
    mix(body, apply_env(sine(pitch * 2.0, seconds * 0.6, 0.12), env_exp(seconds * 0.6, seconds * 0.15)))
    if shimmer > 0:
        mix(body, apply_env(bell(pitch * 1.5, seconds * 1.6, shimmer * 0.25, GLASS, 0.7), env_exp(seconds * 1.6, seconds * 0.4)), 0.004)
    return highpass(body, 60)


def tactile_press(pitch: float = 900, weight: float = 1.0, ring: float = 0.25):
    """A key press you can feel: a tight top click, a short low knock, a hint of glass ring."""
    out = zeros(0.18)
    mix(out, click_transient(3600, 0.004, 0.6))
    mix(out, apply_env(glide(pitch * 0.36, pitch * 0.2, 0.05, 0.75 * weight), env_exp(0.05, 0.012)))
    mix(out, apply_env(sine(pitch, 0.04, 0.35), env_exp(0.04, 0.008)), 0.002)
    if ring > 0:
        mix(out, apply_env(bell(pitch * 2.0, 0.12, ring * 0.4, GLASS, 0.6), env_exp(0.12, 0.03)), 0.006)
    return highpass(out, 40)


def peg_clack(pitch: float, weight: float = 1.0):
    """A wheel peg flicking the pointer: a woody band-passed snap with a pitched knock."""
    out = zeros(0.1)
    mix(out, apply_env(svf(noise(0.018), 2600, 3.2), env_exp(0.018, 0.004)), 0.0, 0.9)
    mix(out, apply_env(glide(pitch, pitch * 0.82, 0.035, 0.55 * weight), env_exp(0.035, 0.008)))
    mix(out, thump(260, 140, 0.03, 0.25 * weight))
    return out


def ratchet_launch():
    """The wind-up: four ratchet clicks speeding up, then the release whoosh."""
    out = zeros(1.0)
    at = 0.0
    for k in range(4):
        mix(out, peg_clack(1500 - k * 120, 0.7), at)
        at += 0.075 - k * 0.012
    mix(out, whoosh_air(320, 3400, 0.5, 0.2), 0.24)
    mix(out, thump(160, 70, 0.12, 0.5), 0.24)
    return out


def friction_brake(seconds: float = 0.7):
    rub = apply_env(svf(noise(seconds), sweep(2200, 700), 2.2), env_swell(seconds, 0.12, 0.9))
    hum = apply_env(lowpass(glide(150, 90, seconds, 0.3, wave_shape="saw"), 900), env_swell(seconds, 0.2))
    return reverb(mix(scale(rub, 0.45), hum), room=0.3, wet=0.12, tail=0.25)


def win_fanfare(root: str = "D5", seed_value: int = 515):
    """A bright stab of the tonic chord, a coin shower, and a rising sparkle tail."""
    out = zeros(1.9)
    chord = [note(root) * r for r in (1.0, 1.26, 1.5, 2.0)]
    for i, f in enumerate(chord):
        mix(out, apply_env(bell(f, 1.0, 0.5, BELL, 0.85), env_exp(1.0, 0.36)), i * 0.012)
        mix(out, apply_env(lowpass(glide(f * 0.5, f * 0.5, 0.5, 0.18, wave_shape="saw"), 2400), env_adsr(0.5, 0.01, 0.1, 0.5, 0.3)))
    mix(out, thump(150, 55, 0.18, 0.7))
    for k in range(6):
        mix(out, apply_env(bell(note(root) * (3 + k * 0.5), 0.3, 0.22, COIN), env_exp(0.3, 0.08)), 0.08 + k * 0.05)
    mix(out, sparkle(0.9, 12, 0.14, seed_value=seed_value), 0.25)
    return reverb(out, room=0.66, wet=0.28, tail=1.1)


def card_snap(noise_hz: float = 3200, thump_f: float = 260):
    out = apply_env(svf(noise(0.05), noise_hz, 1.0), env_exp(0.05, 0.012))
    return mix(scale(out, 0.8), thump(thump_f, thump_f * 0.45, 0.04, 0.3))


def social_ping(carrier: float, ratio: float = 2.0, index: float = 2.4):
    out = apply_env(fm(carrier, ratio, index, 0.28, 0.05, 0.7), env_exp(0.28, 0.09))
    return reverb(out, room=0.4, wet=0.18, tail=0.32)


def warn_fm(a: float, b: float):
    out = zeros(0.5)
    mix(out, apply_env(fm(a, 2.0, 1.4, 0.25, 0.1, 0.6), env_exp(0.25, 0.1)))
    mix(out, apply_env(fm(b, 2.0, 1.4, 0.3, 0.1, 0.6), env_exp(0.3, 0.12)), 0.14)
    return reverb(out, room=0.4, wet=0.18, tail=0.35)


def prestige_rise(seconds: float = 2.5, seed_value: int = 53):
    pad = zeros(seconds)
    for n in ("D3", "A3", "D4", "F#4", "A4"):
        f = note(n)
        mix(pad, lowpass(glide(f, f * 1.003, seconds, 0.22, wave_shape="saw"), 1800))
        mix(pad, lowpass(glide(f * 1.004, f, seconds, 0.12, wave_shape="saw"), 1500))
    out = apply_env(pad, env_swell(seconds, 0.55, 1.6))
    for i, n in enumerate(("D5", "A5", "D6", "F#6")):
        mix(out, apply_env(bell(note(n), 1.4, 0.4, BELL), env_exp(1.4, 0.55)), 1.2 + i * 0.03)
    mix(out, apply_env(glide(90, 40, 1.0, 0.7), env_exp(1.0, 0.3)), 1.2)
    mix(out, sparkle(1.0, 12, 0.14, seed_value=seed_value, palette=DARK_HIGH), 1.25)
    return reverb(out, room=0.85, wet=0.34, tail=1.9)


# ---------------------------------------------------------------------------
# Cue -> unique voice. Nearly 1:1 with game cues so nothing is heavily reused.
# ---------------------------------------------------------------------------

def _build_voices():
    V = {}

    # -- Interface chrome ----------------------------------------------------
    V["hover"] = lambda: soft_blip(note("A5") * 1.5, 0.07, 0.2)
    V["hoverTick"] = lambda: chrome_blip(note("B6"), 0.06, 0.2, 102)
    V["tick"] = lambda: chrome_blip(note("D7"), 0.035, 0.15, 103)
    V["scroll"] = lambda: chrome_blip(note("F#6") * 1.02, 0.04, 0.1, 104)
    V["sliderStep"] = lambda: chrome_blip(note("F#6"), 0.03, 0.05, 105)
    V["amountChange"] = lambda: chrome_blip(note("E6"), 0.028, 0.08, 106)
    V["filterPick"] = lambda: chrome_blip(note("A6") * 0.97, 0.04, 0.22, 107)
    V["sanctuaryHover"] = lambda: chrome_blip(note("C#6"), 0.08, 0.55, 108)
    V["navHover"] = lambda: soft_blip(note("F#6"), 0.06, 0.15)

    V["click"] = lambda: tactile_press(920, 1.0, 0.22)
    V["settings"] = lambda: ui_press(980, 860, 190, 0.35, 202)
    V["purchasePress"] = lambda: ui_press(1180, 990, 230, 0.2, 203)
    V["claimPress"] = lambda: ui_press(1120, 940, 200, 0.1, 204)
    V["codeSubmit"] = lambda: ui_press(900, 780, 170, 0.45, 205)
    V["zoneSelect"] = lambda: ui_press(1080, 920, 220, 0.25, 206)
    V["labRoute"] = lambda: ui_press(860, 740, 160, 0.5, 207)
    V["playerlistAction"] = lambda: ui_press(1020, 880, 200, 0.2, 208)
    V["playerlistSelect"] = lambda: ui_press(1280, 1080, 240, 0.08, 210)
    V["puzzleTap"] = lambda: ui_press(1400, 1100, 260, 0.05, 209)
    V["sanctuaryClick"] = lambda: ui_press(880, 720, 150, 0.55, 211)
    V["curtainOpen"] = lambda: whoosh_air(280, 4200, 0.72, 0.26)
    V["curtainClose"] = lambda: whoosh_air(3600, 220, 0.68, 0.24)

    V["confirm"] = lambda: ui_chime(("D6", "A6"), 0.45, GLASS, 0.065)
    V["successChime"] = lambda: ui_chime(("E6", "B6", "E7"), 0.5, NEON, 0.05, 0.55)
    V["equip"] = lambda: ui_chime(("F#5", "C#6"), 0.35, NEON, 0.04, 0.55)
    V["itemLink"] = lambda: ui_chime(("A5", "E6"), 0.32, GLASS, 0.035, 0.5)
    V["tutorialStep"] = lambda: ui_chime(("D6", "F#6"), 0.4, GLASS, 0.05, 0.5)
    V["roleChange"] = lambda: ui_chime(("A5", "D6", "F#6"), 0.42, BELL, 0.055, 0.5)
    V["reactorStabilize"] = lambda: ui_chime(("F#5", "A5", "C#6"), 0.48, PLASMA, 0.07, 0.45)

    V["toggleOn"] = lambda: mix(
        apply_env(sine(note("A5"), 0.06, 0.6), env_exp(0.06, 0.02)),
        apply_env(sine(note("E6"), 0.09, 0.6), env_exp(0.09, 0.03)),
        0.05,
    )
    V["toggleOff"] = lambda: mix(
        apply_env(sine(note("E6"), 0.06, 0.55), env_exp(0.06, 0.02)),
        apply_env(sine(note("A5"), 0.09, 0.55), env_exp(0.09, 0.03)),
        0.05,
    )
    V["queueStart"] = lambda: mix(V["toggleOn"](), apply_env(bell(note("C#6"), 0.2, 0.3, NEON), env_exp(0.2, 0.06)), 0.04)
    V["queueStop"] = lambda: mix(V["toggleOff"](), thump(140, 70, 0.08, 0.4))

    V["open"] = lambda: panel_air(True, 1.0, "F#6", 301)
    V["modalOpen"] = lambda: panel_air(True, 0.92, "A6", 302)
    V["filterOpen"] = lambda: panel_air(True, 1.1, "E6", 303)
    V["boostOpen"] = lambda: panel_air(True, 1.05, "D6", 304)
    V["offlineOpen"] = lambda: panel_air(True, 0.88, "F#5", 305)
    V["playerlistOpen"] = lambda: panel_air(True, 0.95, "C#6", 306)
    V["story"] = lambda: panel_air(True, 0.75, "A5", 307)
    V["storyOpen"] = lambda: panel_air(True, 0.7, "D5", 308)
    V["crate"] = lambda: panel_air(True, 0.85, "F#5", 309)

    V["close"] = lambda: panel_air(False, 1.0, "D6", 321)
    V["modalDismiss"] = lambda: panel_air(False, 0.9, "A5", 322)
    V["purchaseExit"] = lambda: panel_air(False, 0.95, "E5", 323)
    V["playerlistClose"] = lambda: panel_air(False, 0.92, "C#5", 324)
    V["noticeClose"] = lambda: panel_air(False, 1.05, "B5", 325)
    V["itemUnlink"] = lambda: panel_air(False, 0.85, "F#5", 326)
    V["reset"] = lambda: panel_air(False, 0.8, None, 327)
    V["memberRemove"] = lambda: panel_air(False, 0.7, "A4", 328)
    V["guildLeave"] = lambda: panel_air(False, 0.75, "D5", 329)
    V["gamePause"] = lambda: panel_air(False, 0.65, "A4", 330)
    V["gameExit"] = lambda: panel_air(False, 0.6, None, 331)

    V["page"] = lambda: reverb(scale(apply_env(svf(noise(0.18), sweep(1600, 4600), 1.3), env_swell(0.18, 0.4)), 0.6), room=0.3, wet=0.12, tail=0.18)
    V["tabSwitch"] = lambda: reverb(mix(tactile_press(1180, 0.6, 0.0), apply_env(bell(note("F#6"), 0.18, 0.3, NEON, 0.7), env_exp(0.18, 0.05)), 0.012), room=0.25, wet=0.1, tail=0.15)
    V["preview"] = lambda: reverb(scale(apply_env(svf(noise(0.2), sweep(1200, 4000), 1.2), env_swell(0.2, 0.45)), 0.55), room=0.32, wet=0.14, tail=0.2)
    V["storyBeat"] = lambda: reverb(scale(apply_env(svf(noise(0.14), sweep(900, 2800), 1.1), env_swell(0.14, 0.5)), 0.5), room=0.35, wet=0.16, tail=0.22)
    V["storyPage"] = lambda: mix(V["page"](), apply_env(bell(note("F#5"), 0.2, 0.2, VOID), env_exp(0.2, 0.07)), 0.04)
    V["mailRead"] = lambda: mix(V["page"](), apply_env(bell(note("A5"), 0.18, 0.22, NEON), env_exp(0.18, 0.05)), 0.03)
    V["leaderboardSwitch"] = lambda: mix(V["tabSwitch"](), click_transient(4200, 0.003, 0.4))
    V["cardEndTurn"] = lambda: mix(V["page"](), thump(180, 90, 0.06, 0.35))

    V["modalPop"] = lambda: mix(apply_env(glide(520, 1500, 0.08, 0.8), env_adsr(0.08, 0.004, 0.02, 0.6, 0.05)), click_transient(3000, 0.003), 0.0, 0.2)
    V["sliderCommit"] = lambda: mix(apply_env(glide(600, 1400, 0.07, 0.7), env_adsr(0.07, 0.003, 0.02, 0.55, 0.04)), click_transient(3400, 0.003), 0.0, 0.25)
    V["inputClear"] = lambda: mix(apply_env(glide(900, 400, 0.07, 0.65), env_exp(0.07, 0.02)), click_transient(2200, 0.003), 0.0, 0.3)
    V["chatSend"] = lambda: mix(apply_env(glide(700, 1600, 0.06, 0.7), env_exp(0.06, 0.018)), social_ping(note("E6"), 2.2, 1.8), 0.02, 0.45)
    V["inputFocus"] = lambda: mix(click_transient(2400, 0.004), apply_env(sine(1600, 0.02, 0.3), env_exp(0.02, 0.005)))

    V["error"] = lambda: deny_buzz(note("A3"), 2, 0.4)
    V["errorBuzz"] = lambda: deny_buzz(note("G3"), 3, 0.55)
    V["noticeError"] = lambda: deny_buzz(note("A#3"), 2, 0.45)
    V["dangerPress"] = lambda: mix(deny_buzz(note("F3"), 1, 0.5), thump(120, 50, 0.1, 0.7))
    V["locked"] = lambda: lock_thud(170, note("D4"))
    V["requestBlocked"] = lambda: lock_thud(150, note("C4"))
    V["cardBlock"] = lambda: lock_thud(190, note("E4"))

    V["noticeWarning"] = lambda: warn_fm(note("E5"), note("C5"))
    V["systemAlert"] = lambda: warn_fm(note("G5"), note("D#5"))
    V["requestTimeout"] = lambda: warn_fm(note("F5"), note("C#5"))
    V["adminArm"] = lambda: mix(warn_fm(note("A4"), note("F4")), thump(100, 40, 0.12, 0.6))

    V["mail"] = lambda: ui_chime(("D6", "F#6", "A6"), 0.55, NEON, 0.07, 0.55)
    V["notification"] = lambda: ui_chime(("E6", "G#6", "B6"), 0.52, GLASS, 0.065, 0.55)
    V["noticeInfo"] = lambda: ui_chime(("C#6", "F#6"), 0.48, NEON, 0.05, 0.5)
    V["noticeSuccess"] = lambda: ui_chime(("D6", "A6", "D7"), 0.5, GLASS, 0.055, 0.55)
    V["noticeSpecial"] = lambda: reward_bloom(("A4", "D5", "F#5"), ("D3", "A3"), 6, 1.2, 61)
    V["boostReady"] = lambda: ui_chime(("F#6", "A6", "C#7"), 0.5, CRYSTAL, 0.05, 0.5)
    V["reactorReady"] = lambda: mix(ui_chime(("A5", "C#6"), 0.4, PLASMA, 0.06, 0.45), spark_burst(8, 401, 3200), 0.05, 0.4)
    V["crewNudge"] = lambda: social_ping(note("F#6"), 2.4, 2.0)
    V["invite"] = lambda: social_ping(note("E6"), 1.8, 2.6)
    V["chatReceive"] = lambda: social_ping(note("D6"), 2.0, 2.2)

    V["gameResume"] = lambda: panel_air(True, 0.8, "A5", 340)
    V["velocitySlide"] = lambda: whoosh_air(500, 2800, 0.4, 0.16)
    V["travel"] = lambda: whoosh_air(380, 3200, 0.55, 0.22)

    # -- Currency / rewards --------------------------------------------------
    V["purchase"] = lambda: coin_voice("B6", 4, 0.7, 501)
    V["purchaseResult"] = lambda: coin_voice("E7", 6, 0.55, 502)
    V["vaultDeposit"] = lambda: coin_voice("A6", 3, 0.8, 503)
    V["vaultBank"] = lambda: coin_voice("F#6", 2, 0.9, 504)
    V["guildDeposit"] = lambda: coin_voice("D6", 3, 0.75, 505)

    V["collect"] = lambda: collect_run(("D6", "E6", "F#6", "A6", "B6", "D7"))
    V["boost"] = lambda: collect_run(("F#6", "A6", "C#7", "E7"), 0.04, NEON)
    V["boostActivate"] = lambda: collect_run(("A5", "D6", "F#6", "A6", "D7"), 0.038, CRYSTAL)
    V["offlineCollect"] = lambda: collect_run(("D5", "F#5", "A5", "D6", "F#6"), 0.04, GLASS)
    V["puzzleClear"] = lambda: collect_run(("E6", "G#6", "B6", "E7"), 0.045, NEON)
    V["oreCollect"] = lambda: collect_run(("F#6", "A6", "D7"), 0.045, CRYSTAL)

    V["reward"] = lambda: reward_bloom(("D5", "F#5", "A5", "D6"), ("D4", "A4", "F#5"), 10, 1.7, 511)
    V["codeReward"] = lambda: reward_bloom(("E5", "G#5", "B5", "E6"), ("E4", "B4"), 8, 1.4, 512)
    V["tutorialFinish"] = lambda: reward_bloom(("D5", "A5", "D6"), ("A3", "D4"), 7, 1.5, 513)
    V["domainReward"] = lambda: reward_bloom(("A4", "C#5", "E5", "A5"), ("A3", "E4"), 9, 1.8, 514)
    V["wheelLand"] = lambda: win_fanfare("D5", 515)

    V["unlock"] = lambda: reward_bloom(("A4", "D5", "F#5", "A5", "D6"), None, 8, 1.3, 521)
    V["researchUnlock"] = lambda: reward_bloom(("G4", "B4", "D5", "G5"), None, 6, 1.2, 522)
    V["achievementClaim"] = lambda: reward_bloom(("D5", "F#5", "A5", "C#6"), None, 7, 1.25, 523)
    V["seasonClaim"] = lambda: reward_bloom(("E5", "G#5", "B5", "E6"), None, 8, 1.35, 524)
    V["comboMilestone"] = lambda: reward_bloom(("A4", "E5", "A5", "E6"), ("A3",), 9, 1.4, 525)
    V["discovery"] = lambda: reward_bloom(("C#5", "F#5", "A5", "C#6"), None, 7, 1.3, 526)
    V["zoneUnlock"] = lambda: reward_bloom(("D5", "A5", "D6", "F#6"), ("D4",), 10, 1.5, 527)
    V["guildCreate"] = lambda: reward_bloom(("F#4", "A4", "C#5", "F#5"), None, 6, 1.2, 528)
    V["echoCapture"] = lambda: reward_bloom(("A4", "C#5", "F#5"), ("A3", "C#4"), 8, 1.4, 529)
    V["storyReveal"] = lambda: reward_bloom(("D4", "F#4", "A4", "D5"), ("D3",), 5, 1.5, 530)

    V["missionClaim"] = lambda: claim_chime("D6", "A6", 6, 541)
    V["dailyClaim"] = lambda: claim_chime("E6", "B6", 5, 542)
    V["timedClaim"] = lambda: claim_chime("F#6", "C#7", 5, 543)
    V["mailClaim"] = lambda: claim_chime("A5", "E6", 6, 544)
    V["crateClaim"] = lambda: claim_chime("D6", "F#6", 7, 545)
    V["echoClaim"] = lambda: claim_chime("C#6", "G#6", 6, 546)
    V["guildJoin"] = lambda: claim_chime("A5", "D6", 4, 547)
    V["expeditionReturn"] = lambda: claim_chime("F#5", "C#6", 5, 548)

    V["prestige"] = lambda: prestige_rise(2.6, 551)
    V["rebirthBloom"] = lambda: prestige_rise(2.4, 552)
    V["crateRare"] = lambda: mix(prestige_rise(1.8, 553), sparkle(0.6, 10, 0.2, seed_value=554, palette=DARK_HIGH), 0.3)

    # -- Forge / machines / spectacle ----------------------------------------
    V["salvage"] = lambda: metal_hit(520, 0.45, 160, 0.5)
    V["salvageCrunch"] = lambda: metal_hit(440, 0.7, 140, 0.45)
    V["echoDismantle"] = lambda: metal_hit(380, 0.55, 130, 0.55)
    V["autoForge"] = lambda: metal_hit(560, 0.35, 170, 0.4)
    V["bootStrike"] = lambda: metal_hit(600, 0.5, 180, 0.55)
    V["bootClang"] = lambda: metal_hit(720, 0.3, 200, 0.35)
    V["bootAnvilSplit"] = lambda: metal_hit(480, 0.85, 120, 0.65)
    V["wardenStrike"] = lambda: mix(
        apply_env(svf(noise(0.04), 2600, 1.2), env_exp(0.04, 0.01)),
        apply_env(bell(880, 0.35, 0.55, METAL, 0.9), env_exp(0.35, 0.08)),
        0.0,
        0.9,
    )
    V["wardenCrit"] = lambda: mix(
        V["wardenStrike"](),
        thump(210, 60, 0.28, 1.0),
        0.0,
        1.0,
    )

    V["machineInstall"] = lambda: machine_clunk(150, 420, True)
    V["wheelBrake"] = lambda: friction_brake(0.7)
    V["crateBrake"] = lambda: machine_clunk(160, 360, False)

    V["wheel"] = lambda: whoosh_air(420, 2600, 0.35, 0.14)
    V["wheelStart"] = lambda: ratchet_launch()
    V["crateOpen"] = lambda: whoosh_air(500, 3400, 0.48, 0.2)
    V["expeditionLaunch"] = lambda: whoosh_air(280, 3600, 0.65, 0.24)
    V["bootStart"] = lambda: whoosh_air(320, 2800, 0.5, 0.2)
    V["bootWhoosh"] = lambda: whoosh_air(400, 4000, 0.55, 0.22)
    V["bootFinaleFlip"] = lambda: whoosh_air(600, 4500, 0.4, 0.18)
    V["bootSlamAir"] = lambda: whoosh_air(200, 2200, 0.7, 0.25)

    V["reactor"] = lambda: rumble_bed(1.2, 130, 42)
    V["bootRumble"] = lambda: rumble_bed(1.4, 120, 38)
    V["bootFractureTail"] = lambda: rumble_bed(1.6, 100, 32)
    V["bootGravity"] = lambda: rumble_bed(1.5, 90, 28)
    V["bootAftershock"] = lambda: rumble_bed(1.3, 110, 35)

    V["reactorSurge"] = lambda: impact_hit(120, 850, 130)
    V["adminExecute"] = lambda: impact_hit(110, 700, 100)
    V["crateLand"] = lambda: impact_hit(140, 1000, 160)
    V["domainImpact"] = lambda: impact_hit(100, 800, 90)
    V["bootImpact"] = lambda: impact_hit(125, 920, 145)
    V["bootFinaleBang"] = lambda: impact_hit(95, 750, 85)

    V["reactorChannel"] = lambda: charge_rise(220, 880, 1.2, 6200)
    V["rebirthCharge"] = lambda: charge_rise(180, 720, 1.4, 5000)
    V["wheelCharge"] = lambda: charge_rise(260, 960, 1.0, 7000)
    V["crateCharge"] = lambda: charge_rise(240, 900, 1.1, 6500)
    V["domainCharge"] = lambda: charge_rise(160, 640, 1.5, 4800)
    V["cardPower"] = lambda: charge_rise(300, 1100, 0.9, 7500)
    V["bootTension"] = lambda: charge_rise(200, 800, 1.25, 5500)

    V["reactorPulse"] = lambda: spark_burst(12, 601, 2600)
    V["domainCrack"] = lambda: spark_burst(18, 602, 3000)
    V["cardEnergy"] = lambda: spark_burst(10, 603, 3400)
    V["bootSpark"] = lambda: spark_burst(16, 604, 2900)
    V["bootFizz"] = lambda: spark_burst(20, 605, 3800)
    V["bootDebris"] = lambda: spark_burst(22, 606, 2200)

    V["domainBind"] = lambda: void_swell(1.6, ((55, 0.55), (82.4, 0.32), (110, 0.18)), (800, 3400), 7, 611)
    V["boot"] = lambda: void_swell(1.7, ((48, 0.6), (72, 0.3), (96, 0.2)), (700, 3000), 6, 612)

    V["wheelTick"] = lambda: peg_clack(1700, 0.8)
    V["wheelSlow"] = lambda: peg_clack(1250, 1.15)
    V["crateTick"] = lambda: mechanism_tick(1100, 3600)
    V["crateNear"] = lambda: mechanism_tick(1350, 4200)

    V["cardPlay"] = lambda: card_snap(3000, 240)
    V["cardDraw"] = lambda: card_snap(3400, 280)

    # -- Boot ceremony (keep distinct so boot path never collapses) ----------
    V["bootIgnite"] = lambda: (
        lambda: (
            lambda seconds=1.3: reverb(
                softclip(
                    mix(
                        mix(
                            scale(apply_env(svf(noise(seconds), sweep(200, 2400), 0.8), env_swell(seconds, 0.35, 1.5)), 1.1),
                            spark_burst(14, 701, 2800),
                            0.2,
                            0.6,
                        ),
                        apply_env(glide(90, 40, 0.9, 0.8), env_exp(0.9, 0.3)),
                        0.3,
                    ),
                    1.3,
                ),
                room=0.6,
                wet=0.2,
                tail=0.8,
            )
        )()
    )()
    # Fix bootIgnite - the above is overly nested. Redefine cleanly below.

    V["bootReady"] = lambda: reward_bloom(("A4", "D5", "F#5", "A5"), ("D3", "A3"), 8, 1.35, 702)
    V["bootSlamCharge"] = lambda: (
        lambda seconds=1.55: (
            lambda n=frames(seconds): reverb(
                mix(
                    mix(
                        apply_env(apply_env(glide(110, 440, seconds, 0.45), [0.5 + 0.5 * math.sin(math.tau * (3 + 18 * (i / n) ** 2) * i / SR) for i in range(n)]), env_swell(seconds, 0.97, 2.0)),
                        apply_env(svf(noise(seconds), sweep(200, 2600), 1.6), env_swell(seconds, 0.97, 2.2)),
                        0.0,
                        0.45,
                    ),
                    apply_env(lowpass(noise(seconds), 120), env_swell(seconds, 0.9)),
                    0.0,
                    1.6,
                ),
                room=0.7,
                wet=0.25,
                tail=0.55,
            )
        )()
    )()

    # -- Sanctuary / Warden --------------------------------------------------
    V["oreMine"] = lambda: crystal_shatter(801, 4, PENTA_HIGH)
    V["wardenForming"] = lambda: (
        lambda seconds=2.7: reverb(
            apply_env(
                mix(
                    mix(
                        lowpass(glide(73.42, 74.1, seconds, 0.35, wave_shape="saw"), 420),
                        lowpass(glide(73.9, 74.5, seconds, 0.35, wave_shape="saw"), 420),
                    ),
                    mix(
                        scale([math.sin(math.tau * note("A3") * (i / SR) + 0.004 * note("A3") * math.sin(math.tau * 5.2 * i / SR)) for i in range(frames(seconds))], 0.14),
                        svf(noise(seconds), sweep(300, 1600), 2.0),
                        0.0,
                        0.25,
                    ),
                ),
                env_swell(seconds, 0.8, 1.4),
            ),
            room=0.9,
            wet=0.38,
            tail=1.9,
        )
    )()
    V["wardenAwake"] = lambda: reverb(
        mix(
            softclip(lowpass(apply_env(fm(55, 1.5, 6.0, 1.6, 0.8, 0.8), env_swell(1.6, 0.25, 1.2)), 900), 2.0),
            apply_env(svf(noise(1.4), sweep(1400, 380), 0.9), env_swell(1.4, 0.2, 1.3)),
            0.05,
            0.6,
        ),
        room=0.85,
        wet=0.3,
        tail=1.35,
    )
    V["wardenSlam"] = lambda: (
        lambda: (
            lambda rng=_random.Random(17), out=zeros(1.8): (
                mix(out, apply_env(glide(92, 26, 1.3, 1.2), env_exp(1.3, 0.4))),
                mix(out, apply_env(lowpass(noise(0.5), 1100), env_exp(0.5, 0.1)), 0.0, 1.4),
                [mix(out, apply_env(lowpass(noise(0.012), 2600), env_exp(0.012, 0.004)), 0.05 + rng.random() * 0.9, 0.2 + rng.random() * 0.4) for _ in range(26)],
                reverb(softclip(out, 1.9), room=0.9, wet=0.28, tail=1.55),
            )[-1]
        )()
    )()
    V["wardenDefeat"] = lambda: (
        lambda rng=_random.Random(29), out=zeros(3.1): (
            [mix(out, apply_env(bell(PENTA_HIGH[rng.randrange(0, len(PENTA_HIGH))] * (1 + rng.random() * 0.01), 0.5, 0.22, GLASS, 1.0), env_exp(0.5, 0.12)), rng.random() ** 1.7 * 0.6) for _ in range(34)],
            mix(out, apply_env(highpass(noise(0.9), 2500), env_exp(0.9, 0.18)), 0.0, 0.6),
            mix(out, impact_hit(130, 900, 140), 0.0, 0.75),
            [mix(out, apply_env(bell(note(n), 2.2, 0.35, BELL), env_exp(2.2, 0.8)), 0.45 + i * 0.05) for i, n in enumerate(("D4", "A4", "D5", "F#5", "A5"))],
            reverb(out, room=0.92, wet=0.36, tail=2.1),
        )[-1]
    )()
    V["wardenEscape"] = lambda: reverb(
        mix(
            scale(apply_env(svf(noise(1.85), sweep(3000, 300), 1.2), env_swell(1.85, 0.7, 2.4)), 0.8),
            apply_env(glide(440, 50, 1.85, 0.5), env_swell(1.85, 0.6, 1.6)),
        ),
        room=0.85,
        wet=0.34,
        tail=1.35,
    )
    V["waystoneTravel"] = lambda: (
        lambda seconds=1.15, out=zeros(1.15): (
            [mix(out, apply_env(bell(note(n), 0.4, 0.28, VOID), env_exp(0.4, 0.1)), i * 0.06) for i, n in enumerate(("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7"))],
            mix(out, apply_env(svf(noise(seconds), sweep(500, 8000), 1.2), env_swell(seconds, 0.75, 1.8)), 0.0, 0.5),
            mix(out, thump(120, 45, 0.4, 0.7), 0.85),
            reverb(out, room=0.75, wet=0.32, tail=1.15),
        )[-1]
    )()
    V["regionEnter"] = lambda: (
        lambda seconds=1.7, pad=zeros(1.7): (
            [mix(pad, sine(note(n), seconds, 0.18)) or mix(pad, sine(note(n) * 1.003, seconds, 0.1)) for n in ("A3", "D4", "F#4", "A4")],
            reverb(
                mix(apply_env(pad, env_swell(seconds, 0.4, 1.3)), apply_env(bell(note("D6"), 1.0, 0.35, BELL, 0.7), env_exp(1.0, 0.4)), 0.55),
                room=0.85,
                wet=0.34,
                tail=1.35,
            ),
        )[-1]
    )()

    # Echo / misc gameplay
    V["echoEquip"] = lambda: ui_chime(("C#5", "F#5"), 0.35, VOID, 0.04, 0.5)
    V["echoTune"] = lambda: chrome_blip(note("G#6"), 0.04, 0.45, 901)
    V["echoDismantle"] = V["echoDismantle"]

    # Clean bootIgnite / wardenStrike extras
    def boot_ignite():
        seconds = 1.3
        roar = apply_env(svf(noise(seconds), sweep(200, 2400), 0.8), env_swell(seconds, 0.35, 1.5))
        out = scale(roar, 1.1)
        mix(out, spark_burst(14, 701, 2800), 0.2, 0.6)
        mix(out, apply_env(glide(90, 40, 0.9, 0.8), env_exp(0.9, 0.3)), 0.3)
        return reverb(softclip(out, 1.3), room=0.6, wet=0.2, tail=0.8)

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
        return reverb(softclip(out, 1.4), room=0.6, wet=0.22, tail=0.55)

    def boot_slam_charge():
        seconds = 1.55
        n = frames(seconds)
        whine = glide(110, 440, seconds, 0.45)
        trem = [0.5 + 0.5 * math.sin(math.tau * (3 + 18 * (i / n) ** 2) * i / SR) for i in range(n)]
        out = apply_env(apply_env(whine, trem), env_swell(seconds, 0.97, 2.0))
        mix(out, apply_env(svf(noise(seconds), sweep(200, 2600), 1.6), env_swell(seconds, 0.97, 2.2)), 0.0, 0.45)
        return reverb(out, room=0.7, wet=0.25, tail=0.55)

    def warden_slam_charge():
        seconds = 1.7
        n = frames(seconds)
        whine = glide(72, 310, seconds, 0.5, wave_shape="saw")
        trem = [0.45 + 0.55 * math.sin(math.tau * (2 + 14 * (i / n) ** 2) * i / SR) for i in range(n)]
        out = apply_env(apply_env(lowpass(whine, 900), trem), env_swell(seconds, 0.96, 2.0))
        mix(out, apply_env(svf(noise(seconds), sweep(120, 1800), 1.8), env_swell(seconds, 0.96, 2.2)), 0.0, 0.55)
        mix(out, apply_env(lowpass(noise(seconds), 90), env_swell(seconds, 0.9)), 0.0, 1.8)
        mix(out, ring_mod(apply_env(sine(55, seconds, 0.25), env_swell(seconds, 0.9)), 18.5, 0.35))
        return reverb(softclip(out, 1.25), room=0.82, wet=0.3, tail=0.7)

    def warden_slam():
        rng = _random.Random(17)
        out = zeros(1.8)
        mix(out, apply_env(glide(92, 26, 1.3, 1.2), env_exp(1.3, 0.4)))
        mix(out, apply_env(lowpass(noise(0.5), 1100), env_exp(0.5, 0.1)), 0.0, 1.4)
        for _ in range(26):
            at = 0.05 + rng.random() * 0.9
            chip = apply_env(lowpass(noise(0.012), 2600), env_exp(0.012, 0.004))
            mix(out, chip, at, 0.2 + rng.random() * 0.4)
        return reverb(softclip(out, 1.9), room=0.9, wet=0.28, tail=1.55)

    def warden_defeat():
        rng = _random.Random(29)
        out = zeros(3.1)
        for _ in range(34):
            at = rng.random() ** 1.7 * 0.6
            f = PENTA_HIGH[rng.randrange(0, len(PENTA_HIGH))] * (1 + rng.random() * 0.01)
            mix(out, apply_env(bell(f, 0.5, 0.22, GLASS, 1.0), env_exp(0.5, 0.12)), at)
        mix(out, apply_env(highpass(noise(0.9), 2500), env_exp(0.9, 0.18)), 0.0, 0.6)
        mix(out, impact_hit(), 0.0, 0.75)
        for i, n in enumerate(("D4", "A4", "D5", "F#5", "A5")):
            mix(out, apply_env(bell(note(n), 2.2, 0.35, BELL), env_exp(2.2, 0.8)), 0.45 + i * 0.05)
        pad = zeros(2.4)
        for n in ("D3", "A3", "F#4"):
            mix(pad, lowpass(glide(note(n), note(n) * 1.002, 2.4, 0.18, wave_shape="saw"), 1600))
        mix(out, apply_env(pad, env_swell(2.4, 0.3, 1.2)), 0.45)
        return reverb(out, room=0.92, wet=0.36, tail=2.1)

    def warden_forming():
        seconds = 2.7
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
        return reverb(out, room=0.9, wet=0.38, tail=1.9)

    def waystone():
        seconds = 1.15
        out = zeros(seconds)
        for i, n in enumerate(("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7")):
            mix(out, apply_env(bell(note(n), 0.4, 0.28, VOID), env_exp(0.4, 0.1)), i * 0.06)
        mix(out, apply_env(svf(noise(seconds), sweep(500, 8000), 1.2), env_swell(seconds, 0.75, 1.8)), 0.0, 0.5)
        mix(out, thump(120, 45, 0.4, 0.7), 0.85)
        return reverb(out, room=0.75, wet=0.32, tail=1.15)

    def region_enter():
        seconds = 1.7
        pad = zeros(seconds)
        for n in ("A3", "D4", "F#4", "A4"):
            mix(pad, sine(note(n), seconds, 0.18))
            mix(pad, sine(note(n) * 1.003, seconds, 0.1))
        out = apply_env(pad, env_swell(seconds, 0.4, 1.3))
        mix(out, apply_env(bell(note("D6"), 1.0, 0.35, BELL, 0.7), env_exp(1.0, 0.4)), 0.55)
        return reverb(out, room=0.85, wet=0.34, tail=1.35)

    V["bootIgnite"] = boot_ignite
    V["bootSlamCharge"] = boot_slam_charge
    V["wardenSlamCharge"] = warden_slam_charge
    V["wardenStrike"] = warden_strike
    V["wardenCrit"] = warden_crit
    V["wardenSlam"] = warden_slam
    V["wardenDefeat"] = warden_defeat
    V["wardenForming"] = warden_forming
    V["waystoneTravel"] = waystone
    V["regionEnter"] = region_enter

    # Fix toggle helpers that used mix incorrectly
    def toggle_on():
        out = zeros(0.16)
        mix(out, apply_env(sine(note("A5"), 0.06, 0.6), env_exp(0.06, 0.02)))
        mix(out, apply_env(sine(note("E6"), 0.09, 0.6), env_exp(0.09, 0.03)), 0.05)
        return mix(out, click_transient(4000, 0.003), 0.0, 0.3)

    def toggle_off():
        out = zeros(0.16)
        mix(out, apply_env(sine(note("E6"), 0.06, 0.55), env_exp(0.06, 0.02)))
        mix(out, apply_env(sine(note("A5"), 0.09, 0.55), env_exp(0.09, 0.03)), 0.05)
        return mix(out, click_transient(2600, 0.003), 0.0, 0.3)

    V["toggleOn"] = toggle_on
    V["toggleOff"] = toggle_off
    V["queueStart"] = lambda: mix(toggle_on(), apply_env(bell(note("C#6"), 0.2, 0.3, NEON), env_exp(0.2, 0.06)), 0.04)
    V["queueStop"] = lambda: mix(toggle_off(), thump(140, 70, 0.08, 0.4))

    from sfx_bank import extra_voices
    from ui_voices import voices as interface_voices

    V.update(extra_voices())
    # the interface family (pointer, press, page and panel sounds) replaces both sets above
    V.update(interface_voices())
    return V


VOICES = _build_voices()


def render(name: str):
    """One voice, finished: tail trimmed, faded and peak-normalised to -3 dBFS."""
    buf = VOICES[name]()
    return normalize(trim_tail(fade(buf, 0.001, 0.01)), -3.0)
