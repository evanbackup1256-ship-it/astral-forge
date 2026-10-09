"""The interface voice set: one clean, glassy family for every pointer, press, page and panel sound.

Everything sits on the D major pentatonic (D E F# A B), so any UI sounds that overlap stay consonant.
The voices are pure tones with soft attacks (no noise grit, square waves or buzz) and all end inside
half a second. sfx.py lays these over its own voices of the same name, replacing the old pointer
chrome and the per-page blips from sfx_bank.

    python tools/assetgen/ui_voices.py      # render every voice here to assets/generated/ui_preview/
"""

from __future__ import annotations

import math
import os

import numpy as np

from sfx_bank import ICON_PRESSES, PAGES, PRESSES

SR = 44100
SCALE = ("D", "E", "F#", "A", "B")
SEMITONE = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def hz(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((SEMITONE[pitch] + (octave - 4) * 12) / 12)


# D5 .. B7, the ladder every generated figure picks from
STEPS = [hz(f"{p}{octave}") for octave in (5, 6, 7) for p in SCALE]


def clock(seconds: float):
    return np.arange(max(1, int(seconds * SR))) / SR


def envelope(seconds: float, attack: float, decay: float):
    """A smoothstep attack (no click) into an exponential decay with time constant `decay`."""
    t = clock(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * a * (3 - 2 * a) * np.exp(-t / decay)


def glass(freq: float, seconds: float, decay: float, amp: float = 1.0, bright: float = 0.35):
    """A pure glassy tone: the fundamental, a soft octave and a faint inharmonic shimmer that fades first."""
    t = clock(seconds)
    body = np.sin(2 * np.pi * freq * t)
    body += bright * 0.6 * np.sin(2 * np.pi * freq * 2.0 * t)
    body += bright * 0.25 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (decay * 0.4))
    return amp * body * envelope(seconds, 0.0015, decay)


def thock(freq: float = 190, seconds: float = 0.05, amp: float = 0.6):
    """The tactile body of a press: a short low sine that settles a little in pitch."""
    t = clock(seconds)
    f = freq * (1 + 0.25 * np.exp(-t / 0.01))
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * envelope(seconds, 0.001, 0.014)


def glide(f0: float, f1: float, seconds: float, decay: float, amp: float = 1.0):
    """A tone that slides from f0 to f1 over the first 60% of its life."""
    t = clock(seconds)
    f = f0 * (f1 / f0) ** np.clip(t / (seconds * 0.6), 0, 1)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return amp * (np.sin(phase) + 0.2 * np.sin(2 * phase)) * envelope(seconds, 0.002, decay)


def bandpass_sweep(x, f0: float, f1: float, q: float = 3.2):
    """A Chamberlin state-variable band-pass whose centre glides from f0 to f1."""
    n = len(x)
    centre = f0 * (f1 / f0) ** (np.arange(n) / max(1, n - 1))
    low = band = 0.0
    damp = 1 / q
    out = np.empty(n)
    for i in range(n):
        f = 2 * math.sin(math.pi * min(centre[i], SR / 6) / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        out[i] = band
    return out


def air(seconds: float, f0: float, f1: float, amp: float = 0.2, seed: int = 1):
    """A soft breath of band-passed noise sweeping f0 -> f1, swelling and settling (panels moving)."""
    rng = np.random.default_rng(seed)
    # two passes of a narrow band-pass keep the breath a soft coloured hiss, not broadband noise
    shaped = bandpass_sweep(bandpass_sweep(rng.standard_normal(int(seconds * SR)), f0, f1), f0, f1)
    t = clock(seconds)
    swell = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 1.6
    return amp * 0.65 * shaped / (np.max(np.abs(shaped)) or 1) * swell


def bonk(freq: float, amp: float = 1.0):
    """A rounded, low 'no': a sine with a hollow fifth above it. Firm, never a buzz."""
    t = clock(0.14)
    body = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 1.5 * t) + 0.15 * np.sin(2 * np.pi * freq * 2 * t)
    return amp * 0.8 * body * envelope(0.14, 0.004, 0.035)


def place(*parts):
    """Mix (offset seconds, buffer) parts into one buffer."""
    end = max(int(at * SR) + len(buf) for at, buf in parts)
    out = np.zeros(end)
    for at, buf in parts:
        i = int(at * SR)
        out[i:i + len(buf)] += buf
    return out


def room(x, wet: float = 0.16):
    """A small bright room: a few early reflections give a chime air without a long tail."""
    out = np.concatenate([x, np.zeros(int(0.08 * SR))])
    for delay, gain in ((0.011, 0.5), (0.019, 0.38), (0.029, 0.28), (0.043, 0.2), (0.061, 0.13)):
        d = int(delay * SR)
        out[d:d + len(x)] += x * gain * wet
    return out


def tick(freq: float, seconds: float = 0.035, amp: float = 1.0):
    """Pointer chatter: a tiny glass tap, softer and shorter than any press."""
    return glass(freq, seconds, 0.008, amp, bright=0.2)


def press(freq: float, weight: float = 1.0):
    """A committed press: a tactile thock under a short glass tap."""
    return place((0, thock(170 + freq * 0.02, 0.05, 0.55 * weight)), (0.002, glass(freq, 0.09, 0.022, 0.8)))


def chime(notes, spacing: float = 0.055, decay: float = 0.08, amp: float = 0.8):
    return room(place(*[(i * spacing, glass(hz(n), decay * 4, decay, amp * (1 - 0.12 * i))) for i, n in enumerate(notes)]))


def sparkle(seconds: float, count: int, seed: int):
    rng = np.random.default_rng(seed)
    parts = [(seconds * k / count + rng.uniform(0, 0.015), glass(STEPS[int(rng.integers(7, 14))], 0.12, 0.03, 0.35 * (1 - 0.1 * k))) for k in range(count)]
    return place(*parts)


def nav_open(index: int):
    """A page opening: a breath of air under a rising two-note figure that belongs to that page."""
    root = 3 + (index * 2) % 7
    leap = (2, 3, 4)[index % 3]
    a, b = STEPS[root], STEPS[min(root + leap, len(STEPS) - 1)]
    return room(place((0, air(0.13, 800, 2600, 0.12, 20 + index)), (0.02, glass(a, 0.13, 0.03, 0.7)), (0.07, glass(b, 0.15, 0.035, 0.55))), 0.12)


def _voices():
    V = {}
    # pointer chatter
    V["hover"] = lambda: tick(hz("A6"), 0.04, 0.8)
    V["hoverTick"] = lambda: tick(hz("B6"), 0.035, 0.8)
    V["navHover"] = lambda: tick(hz("F#6"), 0.04, 0.8)
    V["sanctuaryHover"] = lambda: tick(hz("D6"), 0.045, 0.8)
    V["tick"] = lambda: tick(hz("D7"), 0.03)
    V["scroll"] = lambda: tick(hz("E7"), 0.025, 0.7)
    V["sliderStep"] = lambda: tick(hz("A6"), 0.025, 0.8)
    V["amountChange"] = lambda: tick(hz("B6"), 0.03)
    V["filterPick"] = lambda: place((0, tick(hz("F#6"), 0.04)), (0.03, tick(hz("A6"), 0.04, 0.6)))
    V["inputFocus"] = lambda: glass(hz("E6"), 0.08, 0.02, 0.8, bright=0.15)
    V["inputClear"] = lambda: glide(hz("E6"), hz("A5"), 0.08, 0.02, 0.7)
    V["playerlistSelect"] = lambda: tick(hz("E6"), 0.045)
    # presses
    V["click"] = lambda: press(hz("D6"))
    V["sanctuaryClick"] = lambda: press(hz("A5"))
    V["settings"] = lambda: press(hz("E6"), 0.9)
    V["tabSwitch"] = lambda: place((0, thock(220, 0.04, 0.4)), (0, glass(hz("B6"), 0.07, 0.016, 0.75)))
    V["playerlistAction"] = lambda: press(hz("F#6"))
    V["purchasePress"] = lambda: place((0, press(hz("A6"))), (0.04, glass(hz("D7"), 0.14, 0.035, 0.5)))
    V["claimPress"] = lambda: place((0, press(hz("D6"))), (0.035, glass(hz("A6"), 0.16, 0.04, 0.6)), (0.07, glass(hz("D7"), 0.18, 0.045, 0.4)))
    V["sliderCommit"] = lambda: place((0, glass(hz("D6"), 0.1, 0.025, 0.8)), (0.03, glass(hz("A6"), 0.12, 0.03, 0.5)))
    # toggles and pickers
    V["toggleOn"] = lambda: place((0, thock(200, 0.035, 0.35)), (0, glide(hz("A5"), hz("E6"), 0.1, 0.03, 0.8)))
    V["toggleOff"] = lambda: place((0, thock(170, 0.035, 0.3)), (0, glide(hz("E6"), hz("A5"), 0.1, 0.03, 0.65)))
    V["filterOpen"] = lambda: glide(hz("D6"), hz("A6"), 0.09, 0.025, 0.7)
    # panels
    V["open"] = lambda: room(place((0, air(0.16, 700, 2600, 0.18, 3)), (0.03, glass(hz("F#6"), 0.14, 0.035, 0.7)), (0.075, glass(hz("A6"), 0.16, 0.04, 0.5))))
    V["close"] = lambda: place((0, air(0.14, 2400, 700, 0.16, 4)), (0.02, glass(hz("D6"), 0.12, 0.03, 0.55)))
    V["modalOpen"] = lambda: room(place((0, air(0.2, 600, 2800, 0.18, 5)), (0.04, glass(hz("A5"), 0.2, 0.05, 0.6)), (0.09, glass(hz("E6"), 0.22, 0.055, 0.55))))
    V["modalPop"] = lambda: glass(hz("A6"), 0.08, 0.02, 0.8)
    V["modalDismiss"] = lambda: place((0, air(0.14, 2200, 650, 0.15, 6)), (0.015, glass(hz("D6"), 0.1, 0.025, 0.5)))
    V["purchaseExit"] = lambda: place((0, air(0.12, 2000, 700, 0.14, 7)), (0.01, glass(hz("A5"), 0.09, 0.022, 0.4)))
    V["playerlistOpen"] = lambda: place((0, air(0.12, 800, 2400, 0.13, 8)), (0.02, glass(hz("E6"), 0.1, 0.025, 0.5)))
    V["playerlistClose"] = lambda: place((0, air(0.11, 2300, 800, 0.12, 9)), (0.01, glass(hz("B5"), 0.08, 0.02, 0.4)))
    V["page"] = lambda: place((0, air(0.12, 1800, 3600, 0.12, 10)), (0.02, glass(hz("E6"), 0.1, 0.025, 0.55)))
    V["curtainOpen"] = lambda: room(place((0, air(0.38, 400, 3000, 0.22, 11)), (0.1, chime(("D6", "A6"), 0.07, 0.06, 0.55))))
    V["curtainClose"] = lambda: place((0, air(0.34, 3000, 400, 0.2, 12)), (0.05, glass(hz("D5"), 0.2, 0.06, 0.45)))
    V["velocitySlide"] = lambda: air(0.16, 900, 2800, 0.15, 13)
    # results
    V["confirm"] = lambda: chime(("D6", "A6"), 0.06, 0.07, 0.8)
    V["successChime"] = lambda: chime(("D6", "F#6", "A6", "D7"), 0.05, 0.08, 0.75)
    V["error"] = lambda: place((0, bonk(hz("A3"))), (0.1, bonk(hz("F#3"), 0.8)))
    V["errorBuzz"] = lambda: place((0, bonk(hz("E3"))), (0.09, bonk(hz("E3"), 0.85)), (0.18, bonk(hz("D3"), 0.7)))
    V["locked"] = lambda: place((0, thock(150, 0.07, 0.6)), (0.005, glass(hz("D5"), 0.12, 0.03, 0.35, bright=0.1)))
    # notices
    V["noticeInfo"] = lambda: room(glass(hz("A6"), 0.2, 0.05, 0.75))
    V["noticeSuccess"] = lambda: chime(("F#6", "B6"), 0.06, 0.07, 0.75)
    V["noticeWarning"] = lambda: place((0, glass(hz("E6"), 0.12, 0.03, 0.75)), (0.12, glass(hz("E6"), 0.14, 0.035, 0.7)))
    V["noticeError"] = lambda: place((0, bonk(hz("A4"), 0.9)), (0.1, bonk(hz("D4"), 0.85)))
    V["noticeSpecial"] = lambda: room(place((0, chime(("D6", "F#6", "A6", "D7"), 0.045, 0.07, 0.7)), (0.2, sparkle(0.25, 5, 41))))
    V["noticeClose"] = lambda: glide(hz("B6"), hz("E6"), 0.07, 0.018, 0.5)
    # mail, story and chat
    V["mail"] = lambda: room(place((0, glass(hz("A6"), 0.22, 0.06, 0.75)), (0.11, glass(hz("F#6"), 0.26, 0.07, 0.7))))
    V["story"] = lambda: room(place((0, glass(hz("D6"), 0.3, 0.08, 0.6)), (0, glass(hz("A5"), 0.32, 0.09, 0.4, bright=0.1)), (0.08, glass(hz("F#6"), 0.28, 0.075, 0.5))))
    V["chatSend"] = lambda: place((0, glide(hz("E6"), hz("A6"), 0.08, 0.022, 0.7)), (0, air(0.08, 1200, 3400, 0.08, 14)))
    V["chatReceive"] = lambda: glass(hz("B6"), 0.12, 0.03, 0.6)
    # every page opens with its own figure from the same scale; hovers are single taps
    for index, page in enumerate(PAGES):
        V[f"navOpen{page}"] = lambda i=index: nav_open(i)
        V[f"navHover{page}"] = lambda i=index: tick(STEPS[3 + (i * 3) % 9], 0.04, 0.8)
    for index, name in enumerate(PRESSES):
        V[f"{name}Hover"] = lambda i=index: tick(STEPS[2 + (i * 2) % 10], 0.035, 0.75)
    for index, name in enumerate(ICON_PRESSES):
        V[name] = lambda i=index: press(STEPS[3 + (i * 3) % 8])
    _second_wave(V)
    return V


def sub(freq: float, seconds: float, decay: float, amp: float = 0.6, drop: float = 0.5):
    """A low body under a big moment: a sine that sinks by `drop` of its pitch as it settles."""
    t = clock(seconds)
    f = freq * (1 - drop * (1 - np.exp(-t / (seconds * 0.35))))
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * envelope(seconds, 0.004, decay)


def swell(seconds: float, f0: float, f1: float, amp: float = 0.5, seed: int = 90):
    """A long rising breath with a tone riding on top, for charges and builds."""
    t = clock(seconds)
    rise = np.clip(t / seconds, 0, 1) ** 2.2
    tone = glide(f0, f1, seconds, seconds * 2.5, 0.5) * rise
    return amp * (tone + air(seconds, f0 * 2, f1 * 2, 0.5, seed) * rise)


def _second_wave(V):
    """Twenty-eight newer cues: menus, drag, ratings, reports, counters, artifacts, the crate
    reveal and the rebirth sequence. Same scale and same glass so they sit with everything else."""
    # menus and editing
    V["dropdownOpen"] = lambda: place((0, glide(hz("A5"), hz("E6"), 0.09, 0.025, 0.6)), (0.03, tick(hz("B6"), 0.04, 0.6)))
    V["dropdownClose"] = lambda: place((0, glide(hz("E6"), hz("A5"), 0.08, 0.022, 0.55)), (0, thock(180, 0.03, 0.25)))
    V["copyDone"] = lambda: place((0, tick(hz("D7"), 0.035)), (0.045, glass(hz("A6"), 0.1, 0.025, 0.6)))
    V["dragGrab"] = lambda: place((0, thock(210, 0.04, 0.45)), (0.004, glass(hz("F#6"), 0.06, 0.014, 0.45, bright=0.1)))
    V["dragDrop"] = lambda: place((0, thock(150, 0.06, 0.6)), (0.006, glass(hz("D6"), 0.1, 0.024, 0.55)))
    V["dragSnap"] = lambda: tick(hz("B6"), 0.03, 0.75)
    V["favoriteOn"] = lambda: room(place((0, glass(hz("A6"), 0.1, 0.025, 0.7)), (0.05, glass(hz("D7"), 0.16, 0.04, 0.6)), (0.08, sparkle(0.12, 3, 51))))
    V["favoriteOff"] = lambda: glide(hz("D7"), hz("A6"), 0.08, 0.02, 0.5)
    V["ratingStar"] = lambda: place((0, tick(hz("F#6"), 0.035)), (0.02, glass(hz("A6"), 0.09, 0.02, 0.5)))
    V["searchType"] = lambda: tick(hz("E7"), 0.022, 0.55)
    V["countTick"] = lambda: tick(hz("A7"), 0.02, 0.5)
    V["stepNext"] = lambda: place((0, air(0.09, 1400, 3200, 0.08, 52)), (0.01, glass(hz("E6"), 0.08, 0.02, 0.55)), (0.04, glass(hz("A6"), 0.09, 0.022, 0.45)))
    V["stepBack"] = lambda: place((0, air(0.09, 3200, 1400, 0.08, 53)), (0.01, glass(hz("A6"), 0.08, 0.02, 0.5)), (0.04, glass(hz("E6"), 0.09, 0.022, 0.4)))
    # reports, feedback, guild
    V["reportSubmit"] = lambda: room(place((0, press(hz("D6"))), (0.05, glass(hz("F#6"), 0.14, 0.035, 0.55)), (0.1, glass(hz("D6"), 0.2, 0.05, 0.4, bright=0.1))))
    V["feedbackSubmit"] = lambda: room(place((0, press(hz("A6"))), (0.05, chime(("D6", "A6", "B6"), 0.05, 0.06, 0.6))))
    V["guildAnnounce"] = lambda: room(place((0, glass(hz("D6"), 0.3, 0.08, 0.6)), (0, glass(hz("A5"), 0.3, 0.09, 0.4)), (0.12, glass(hz("F#6"), 0.3, 0.08, 0.55)), (0.24, glass(hz("A6"), 0.36, 0.1, 0.55))), 0.22)
    V["badgeEarn"] = lambda: room(place((0, chime(("A6", "D7"), 0.05, 0.07, 0.7)), (0.12, sparkle(0.2, 4, 54))))
    # artifacts
    V["artifactEquip"] = lambda: room(place((0, thock(160, 0.06, 0.5)), (0.01, glide(hz("A5"), hz("D6"), 0.14, 0.05, 0.6)), (0.07, glass(hz("A6"), 0.22, 0.06, 0.5))))
    V["artifactUpgrade"] = lambda: room(place((0, swell(0.22, hz("D5"), hz("A6"), 0.35, 55)), (0.2, chime(("D6", "F#6", "A6", "D7"), 0.04, 0.07, 0.7))), 0.2)
    # crate reveal: seal breaks, the orbit whirls, each rarity step climbs, then the reveal lands
    V["crateSeal"] = lambda: room(place((0, sub(110, 0.28, 0.09, 0.6, 0.35)), (0, thock(240, 0.05, 0.5)), (0.01, glass(hz("D6"), 0.18, 0.05, 0.45, bright=0.5)), (0.03, sparkle(0.16, 4, 56))), 0.2)
    V["crateOrbit"] = lambda: place((0, swell(0.6, hz("D5"), hz("D6"), 0.45, 57)))
    V["crateRarityStep"] = lambda: place((0, glass(hz("A6"), 0.14, 0.035, 0.7)), (0.02, glass(hz("D7"), 0.12, 0.03, 0.4)))
    V["crateRevealEpic"] = lambda: room(place((0, sub(90, 0.4, 0.14, 0.55)), (0.02, chime(("D6", "F#6", "A6", "D7"), 0.045, 0.1, 0.75)), (0.2, sparkle(0.3, 6, 58))), 0.25)
    V["crateRevealMythic"] = lambda: room(place((0, sub(70, 0.6, 0.2, 0.7)), (0, air(0.4, 500, 4200, 0.2, 59)), (0.04, chime(("D5", "A5", "D6", "F#6", "A6", "D7"), 0.05, 0.14, 0.75)), (0.32, sparkle(0.4, 9, 60))), 0.3)
    # rebirth: the ignite, the shockwave, the tier climb and the final ascent
    V["rebirthIgnite"] = lambda: room(place((0, swell(0.9, hz("D4") * 2, hz("A6"), 0.55, 61)), (0.86, glass(hz("D7"), 0.2, 0.05, 0.6))), 0.2)
    V["rebirthShockwave"] = lambda: room(place((0, sub(80, 0.7, 0.22, 0.85, 0.6)), (0, air(0.5, 3600, 400, 0.3, 62)), (0.01, glass(hz("D6"), 0.3, 0.08, 0.5, bright=0.6))), 0.3)
    V["rebirthTierUp"] = lambda: room(place((0, glass(hz("A6"), 0.2, 0.05, 0.7)), (0.05, glass(hz("D7"), 0.24, 0.06, 0.6)), (0.1, sparkle(0.16, 3, 63))))
    V["rebirthAscend"] = lambda: room(place((0, sub(60, 0.9, 0.3, 0.6, 0.2)), (0, chime(("D5", "F#5", "A5", "D6"), 0.07, 0.2, 0.6)), (0.3, chime(("A6", "D7", "F#7"), 0.08, 0.16, 0.6)), (0.5, sparkle(0.5, 10, 64))), 0.32)


def voices():
    """Name -> renderer returning a plain list of floats, the format the sheet packer mixes."""
    return {name: (lambda make=make: [float(v) for v in make()]) for name, make in _voices().items()}


if __name__ == "__main__":
    import wave

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "generated", "ui_preview")
    os.makedirs(out, exist_ok=True)
    for name, make in _voices().items():
        buf = make()
        peak = float(np.max(np.abs(buf))) or 1.0
        data = (np.clip(buf / peak * 0.7, -1, 1) * 32767).astype("<i2")
        with wave.open(os.path.join(out, f"{name}.wav"), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(data.tobytes())
    print(f"rendered {len(_voices())} interface voices to {os.path.abspath(out)}")
