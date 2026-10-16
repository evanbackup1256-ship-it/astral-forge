"""Astral Forge sound design, 7.2: every voice on the sheet, written from scratch.

One palette for the whole game, so nothing sounds borrowed:

  tactile   a small filtered click on top and a soft low thump under it -- the physical "press"
  mallet    a felt mallet on a tuned bar (marimba-like modes, rounder than a sine)
  kalimba   a plucked tine: bright attack, quick bloom, short ring
  bell      a struck bell for news and rewards (FM, inharmonic shimmer that fades first)
  air       breath that sweeps up (opening) or down (closing)
  sub       a low body that sinks under big moments
  shimmer   a scatter of tiny high tines over rewards

Everything tonal sits on D major pentatonic (D E F# A B), so overlapping sounds stay consonant
with each other and with the D/F#/A-centred soundtrack. Sizes follow the motion they play
with: pointer chatter < 50 ms, presses ~ 90 ms, panels ~ 200 ms, rewards 0.4-0.9 s, big
moments up to 1.6 s. sfx.py takes every voice from here; build fails on any name left over.

    python tools/assetgen/sound_design.py      # render every voice to assets/generated/ui_preview/
"""

from __future__ import annotations

import os

import numpy as np

SR = 44100
SCALE = ("D", "E", "F#", "A", "B")
SEMI = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
RNG = np.random.default_rng(72)


def hz(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((SEMI[pitch] + (octave - 4) * 12) / 12)


LADDER = [hz(f"{p}{o}") for o in (4, 5, 6, 7) for p in SCALE]  # D4 .. B7


def note(step: int) -> float:
    return LADDER[max(0, min(len(LADDER) - 1, step))]


def t_of(seconds: float):
    return np.arange(max(1, int(seconds * SR))) / SR


def env(seconds: float, attack: float, decay: float):
    t = t_of(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * a * (3 - 2 * a) * np.exp(-t / max(decay, 1e-4))


def place(*parts):
    parts = [(at, np.asarray(buf, dtype=float)) for at, buf in parts if buf is not None]
    end = max(int(at * SR) + len(buf) for at, buf in parts)
    out = np.zeros(end)
    for at, buf in parts:
        i = int(at * SR)
        out[i:i + len(buf)] += buf
    return out


def fft_band(x, low=None, high=None):
    n = len(x)
    if n < 4:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if high:
        g *= 1 / np.sqrt(1 + (f / high) ** 4)
    if low:
        g *= 1 / np.sqrt(1 + (low / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(spec * g, n)


# ------------------------------------------------------------------ instruments

def tactile(weight: float = 1.0, pitch: float = 1.0):
    """The physical part of a press: a 4 ms filtered click and a short thump that settles in pitch."""
    n = int(0.006 * SR)
    click = fft_band(RNG.standard_normal(n), 2500 * pitch, 7000 * pitch) * np.exp(-np.arange(n) / (0.0012 * SR))
    t = t_of(0.05)
    f = 150 * pitch * (1 + 0.6 * np.exp(-t / 0.006))
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(0.05, 0.0008, 0.011)
    return place((0, click * 0.35 * weight), (0, thump * 0.7 * weight))


def mallet(freq: float, decay: float = 0.08, hard: float = 0.5, amp: float = 1.0):
    """Tuned bar under a felt mallet: modes at 1, 3.99 and 9.1 with the upper ones dying first."""
    seconds = decay * 5 + 0.02
    t = t_of(seconds)
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)
    body += hard * 0.5 * np.sin(2 * np.pi * freq * 3.99 * t) * np.exp(-t / (decay * 0.35))
    body += hard * 0.18 * np.sin(2 * np.pi * freq * 9.1 * t) * np.exp(-t / (decay * 0.15))
    felt = fft_band(RNG.standard_normal(len(t)), 600, 4000) * np.exp(-t / 0.002) * 0.12 * hard
    a = np.clip(t / 0.0012, 0, 1)
    return amp * (body + felt) * a


def kalimba(freq: float, decay: float = 0.12, amp: float = 1.0):
    """A plucked tine: bright pluck, slightly sharp first partial settling, short shimmer."""
    seconds = decay * 5 + 0.02
    t = t_of(seconds)
    bend = freq * (1 + 0.004 * np.exp(-t / 0.01))
    phase = 2 * np.pi * np.cumsum(bend) / SR
    body = np.sin(phase) * np.exp(-t / decay)
    body += 0.32 * np.sin(phase * 5.4) * np.exp(-t / (decay * 0.18))
    body += 0.12 * np.sin(phase * 2.0) * np.exp(-t / (decay * 0.6))
    return amp * body * np.clip(t / 0.0008, 0, 1)


def bell(freq: float, decay: float = 0.4, amp: float = 1.0, bright: float = 0.6):
    seconds = decay * 4 + 0.05
    t = t_of(seconds)
    idx = 2.2 * bright * np.exp(-t / (decay * 0.25))
    body = np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * 3.5 * t))
    body += 0.25 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t / (decay * 0.6))
    return amp * body * env(seconds, 0.002, decay)


def air(seconds: float, f0: float, f1: float, amp: float = 0.25):
    """Breath: noise through a band that slides f0 -> f1 (STFT-free: blocks of filtered noise)."""
    n = int(seconds * SR)
    out = np.zeros(n)
    blocks = 12
    size = n // blocks + 1
    noise = RNG.standard_normal(n + size)
    for b in range(blocks):
        centre = f0 * (f1 / f0) ** (b / (blocks - 1))
        seg = fft_band(noise[b * size:(b + 2) * size], centre * 0.6, centre * 1.6)
        win = np.hanning(len(seg))
        start = b * size
        end = min(n, start + len(seg))
        out[start:end] += (seg * win)[: end - start]
    swell = np.sin(np.pi * np.clip(np.arange(n) / max(1, n), 0, 1)) ** 1.4
    return amp * out / (np.max(np.abs(out)) or 1) * swell


def sub(freq: float, seconds: float, drop: float = 0.45, amp: float = 0.7):
    t = t_of(seconds)
    f = freq * (1 - drop * (1 - np.exp(-t / (seconds * 0.3))))
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.003, seconds * 0.35)


def shimmer(seconds: float, count: int, low: int = 13, high: int = 19, amp: float = 0.35):
    parts = []
    for k in range(count):
        at = seconds * k / max(1, count) + RNG.uniform(0, 0.02)
        parts.append((at, kalimba(note(int(RNG.integers(low, high + 1))), 0.04, amp * (1 - 0.06 * k))))
    return place(*parts)


def rise(seconds: float, f0: float, f1: float, amp: float = 0.5):
    t = t_of(seconds)
    f = f0 * (f1 / f0) ** (t / seconds)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    grow = (t / seconds) ** 2
    return amp * (tone * 0.5 + air(seconds, f0 * 2, f1 * 3, 0.6)) * grow


def chord(steps, spacing=0.04, voice=kalimba, decay=0.1, amp=0.8):
    return place(*[(i * spacing, voice(note(s), decay, amp * (1 - 0.1 * i))) for i, s in enumerate(steps)])


def room(x, size: float = 0.25, wet: float = 0.2):
    """A small room: a decaying noise impulse response, darker as it goes."""
    n = int(size * SR)
    t = np.arange(n) / SR
    ir = fft_band(RNG.standard_normal(n), 200, 6000) * np.exp(-t / (size / 5))
    ir[: int(0.006 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) or 1
    wetted = np.convolve(x, ir)
    out = np.concatenate([x, np.zeros(len(wetted) - len(x))])
    return out + wet * wetted


def finish(x, low_cut: float = 70):
    """Common polish: no rumble below the voice, no fizz above 9 kHz, a touch of glue."""
    x = fft_band(np.asarray(x, dtype=float), low_cut, 9500)
    return np.tanh(x * 1.15) / np.tanh(1.15)


# ------------------------------------------------------------------ families

PAGES = (
    "Overview", "Workshop", "Inventory", "Research", "Shop", "Settings", "Worlds", "Missions", "Rewards",
    "Boosts", "StarGrid", "Echoes", "Continuum", "Lab", "Anomaly", "Wheel", "Command", "Story", "Mail",
    "Chat", "Crew", "Milestones", "Convergence", "Guild", "Leaderboards", "Trade", "Credits", "Admin",
    "ForgePath", "Foundry",
)


def hover(step: int, amp: float = 0.6):
    """Pointer chatter: the lightest mallet tap, high and very short."""
    return mallet(note(step), 0.012, 0.25, amp)


def press(step: int, weight: float = 1.0, tail: int | None = None):
    parts = [(0, tactile(weight)), (0.003, mallet(note(step), 0.035, 0.6, 0.75))]
    if tail is not None:
        parts.append((0.045, kalimba(note(tail), 0.05, 0.45)))
    return place(*parts)


def page_open(index: int):
    root = 6 + (index * 3) % 8
    leap = (2, 3, 4)[index % 3]
    return room(place((0, air(0.16, 700, 2600, 0.16)), (0.02, kalimba(note(root), 0.05, 0.7)),
                      (0.065, kalimba(note(root + leap), 0.07, 0.55))), 0.2, 0.18)


def panel(up: bool, step: int, amp: float = 0.7):
    sweep = air(0.17, 650, 2800, 0.17) if up else air(0.15, 2600, 650, 0.15)
    tone = kalimba(note(step), 0.06, amp * 0.8) if up else mallet(note(step), 0.04, 0.4, amp * 0.6)
    return room(place((0, sweep), (0.025 if up else 0.01, tone)), 0.18, 0.15)


def no(step: int = 3, twice: bool = True):
    """A firm, rounded 'no': low mallet with a hollow fifth, never a buzz."""
    one = place((0, tactile(0.8, 0.8)), (0, mallet(note(step), 0.05, 0.3, 0.8)), (0, mallet(note(step) * 1.5, 0.04, 0.2, 0.3)))
    return place((0, one), (0.11, one * 0.8)) if twice else one


def coin(step: int = 15, amp: float = 0.8):
    return place((0, bell(note(step), 0.12, amp * 0.7, 0.9)), (0.03, kalimba(note(step + 2), 0.06, amp * 0.5)))


def reward(steps, size: float = 0.5, sparkles: int = 6, low: float | None = None):
    parts = [(0, chord(steps, 0.05, kalimba, 0.12, 0.8)), (0.12, shimmer(size, sparkles))]
    if low:
        parts.append((0, sub(low, size + 0.2, 0.3, 0.45)))
    return room(place(*parts), 0.35, 0.25)


def design():
    V = {}
    # --- pointer chatter -------------------------------------------------
    V["hover"] = lambda: hover(13)
    V["hoverTick"] = lambda: hover(14, 0.5)
    V["navHover"] = lambda: hover(12)
    V["tick"] = lambda: hover(16, 0.55)
    V["scroll"] = lambda: hover(17, 0.4)
    V["sliderStep"] = lambda: hover(13, 0.5)
    V["amountChange"] = lambda: hover(14, 0.55)
    V["countTick"] = lambda: kalimba(note(18), 0.012, 0.45)
    V["searchType"] = lambda: hover(17, 0.4)
    V["filterPick"] = lambda: place((0, hover(12)), (0.03, hover(14, 0.45)))
    V["inputFocus"] = lambda: mallet(note(11), 0.03, 0.3, 0.6)
    V["inputClear"] = lambda: place((0, mallet(note(12), 0.02, 0.3, 0.5)), (0.03, mallet(note(9), 0.025, 0.3, 0.45)))
    V["playerlistSelect"] = lambda: hover(11)
    V["dragSnap"] = lambda: hover(14, 0.6)
    # --- presses -------------------------------------------------------------
    V["click"] = lambda: press(10)
    V["confirm"] = lambda: room(place((0, press(10)), (0.05, chord((13, 15), 0.05, kalimba, 0.07, 0.6))), 0.2, 0.15)
    V["settings"] = lambda: press(11, 0.9)
    V["tabSwitch"] = lambda: place((0, tactile(0.6, 1.2)), (0, mallet(note(14), 0.025, 0.5, 0.7)))
    V["playerlistAction"] = lambda: press(12)
    V["purchasePress"] = lambda: press(13, 1.0, 16)
    V["claimPress"] = lambda: press(10, 1.0, 15)
    V["sliderCommit"] = lambda: place((0, mallet(note(10), 0.03, 0.5, 0.7)), (0.03, kalimba(note(13), 0.04, 0.45)))
    V["dangerPress"] = lambda: place((0, tactile(1.1, 0.8)), (0, mallet(note(5), 0.05, 0.4, 0.8)))
    V["equip"] = lambda: place((0, tactile(0.9)), (0.004, kalimba(note(11), 0.05, 0.6)), (0.04, kalimba(note(14), 0.05, 0.4)))
    V["zoneSelect"] = lambda: press(9, 1.0, 12)
    V["labRoute"] = lambda: press(12, 0.9, 14)
    V["preview"] = lambda: press(13, 0.8)
    V["reset"] = lambda: place((0, tactile(0.9, 0.9)), (0, mallet(note(12), 0.03, 0.4, 0.6)), (0.04, mallet(note(9), 0.04, 0.4, 0.55)))
    V["invite"] = lambda: press(11, 1.0, 14)
    V["roleChange"] = lambda: press(12, 0.9, 13)
    V["memberRemove"] = lambda: place((0, tactile(1.0, 0.85)), (0, mallet(note(9), 0.04, 0.4, 0.65)), (0.05, mallet(note(6), 0.05, 0.3, 0.55)))
    V["guildCreate"] = lambda: room(place((0, press(10)), (0.05, chord((12, 15, 17), 0.05, kalimba, 0.08, 0.6))), 0.25, 0.2)
    V["guildJoin"] = lambda: room(place((0, press(11)), (0.05, chord((13, 16), 0.05, kalimba, 0.08, 0.6))), 0.2, 0.18)
    V["codeSubmit"] = lambda: press(12, 1.0, 15)
    V["queueStart"] = lambda: place((0, tactile(0.8)), (0, kalimba(note(10), 0.04, 0.5)), (0.04, kalimba(note(14), 0.05, 0.5)))
    V["queueStop"] = lambda: place((0, tactile(0.8, 0.9)), (0, kalimba(note(14), 0.04, 0.5)), (0.04, kalimba(note(10), 0.05, 0.45)))
    V["leaderboardSwitch"] = lambda: place((0, tactile(0.6, 1.2)), (0, mallet(note(15), 0.025, 0.5, 0.65)))
    V["adminArm"] = lambda: place((0, tactile(1.0, 0.9)), (0, mallet(note(8), 0.05, 0.6, 0.7)), (0.05, mallet(note(8), 0.04, 0.6, 0.5)))
    V["adminPress"] = lambda: press(8, 1.0)
    V["adminExecute"] = lambda: room(place((0, tactile(1.2, 0.8)), (0, sub(120, 0.25, 0.4, 0.5)), (0.02, mallet(note(10), 0.08, 0.7, 0.7))), 0.2, 0.15)
    V["toggleOn"] = lambda: place((0, tactile(0.7)), (0, kalimba(note(10), 0.03, 0.55)), (0.035, kalimba(note(14), 0.05, 0.6)))
    V["toggleOff"] = lambda: place((0, tactile(0.7, 0.9)), (0, kalimba(note(14), 0.03, 0.5)), (0.035, kalimba(note(10), 0.05, 0.5)))
    V["filterOpen"] = lambda: place((0, mallet(note(10), 0.025, 0.4, 0.6)), (0.03, mallet(note(13), 0.03, 0.4, 0.55)))
    V["dropdownOpen"] = lambda: place((0, mallet(note(9), 0.025, 0.4, 0.55)), (0.03, mallet(note(12), 0.03, 0.4, 0.55)))
    V["dropdownClose"] = lambda: place((0, mallet(note(12), 0.025, 0.4, 0.5)), (0.03, mallet(note(9), 0.03, 0.4, 0.45)))
    V["copyDone"] = lambda: place((0, hover(15)), (0.045, kalimba(note(13), 0.06, 0.6)))
    V["dragGrab"] = lambda: place((0, tactile(0.7, 1.1)), (0, mallet(note(11), 0.02, 0.3, 0.4)))
    V["dragDrop"] = lambda: place((0, tactile(1.0, 0.8)), (0.005, mallet(note(9), 0.05, 0.5, 0.6)))
    V["favoriteOn"] = lambda: room(place((0, kalimba(note(13), 0.05, 0.7)), (0.05, kalimba(note(16), 0.08, 0.6)), (0.08, shimmer(0.12, 3))), 0.2, 0.2)
    V["favoriteOff"] = lambda: place((0, kalimba(note(16), 0.03, 0.45)), (0.04, kalimba(note(12), 0.04, 0.4)))
    V["ratingStar"] = lambda: place((0, hover(12)), (0.02, kalimba(note(15), 0.05, 0.5)))
    V["stepNext"] = lambda: place((0, air(0.09, 1400, 3200, 0.1)), (0.01, kalimba(note(11), 0.04, 0.55)), (0.04, kalimba(note(13), 0.05, 0.45)))
    V["stepBack"] = lambda: place((0, air(0.09, 3200, 1400, 0.1)), (0.01, kalimba(note(13), 0.04, 0.5)), (0.04, kalimba(note(11), 0.05, 0.4)))
    # --- panels ---------------------------------------------------------------
    V["open"] = lambda: panel(True, 12)
    V["close"] = lambda: panel(False, 9)
    V["page"] = lambda: panel(True, 11, 0.55)
    V["modalOpen"] = lambda: room(place((0, air(0.22, 550, 3000, 0.2)), (0.04, kalimba(note(9), 0.08, 0.6)), (0.09, kalimba(note(13), 0.1, 0.55))), 0.25, 0.2)
    V["modalPop"] = lambda: kalimba(note(14), 0.04, 0.6)
    V["modalDismiss"] = lambda: panel(False, 10, 0.5)
    V["purchaseExit"] = lambda: panel(False, 8, 0.45)
    V["playerlistOpen"] = lambda: panel(True, 11, 0.55)
    V["playerlistClose"] = lambda: panel(False, 9, 0.45)
    V["offlineOpen"] = lambda: room(place((0, air(0.3, 400, 2800, 0.2)), (0.06, chord((8, 10, 13), 0.06, kalimba, 0.1, 0.55))), 0.3, 0.22)
    V["storyOpen"] = lambda: room(place((0, air(0.28, 400, 2400, 0.18)), (0.05, bell(note(8), 0.3, 0.45, 0.3)), (0.12, kalimba(note(12), 0.12, 0.45))), 0.4, 0.25)
    V["storyPage"] = lambda: place((0, air(0.12, 1800, 3600, 0.12)), (0.02, kalimba(note(13), 0.04, 0.4)))
    V["storyBeat"] = lambda: room(bell(note(10), 0.25, 0.55, 0.3), 0.35, 0.25)
    V["storyReveal"] = lambda: room(place((0, sub(90, 0.5, 0.3, 0.4)), (0.02, chord((8, 10, 12, 15), 0.07, bell, 0.25, 0.5))), 0.45, 0.3)
    V["story"] = lambda: room(place((0, bell(note(10), 0.25, 0.5, 0.3)), (0.08, kalimba(note(12), 0.1, 0.5))), 0.35, 0.25)
    V["mail"] = lambda: room(place((0, kalimba(note(13), 0.08, 0.6)), (0.1, kalimba(note(12), 0.1, 0.55))), 0.25, 0.2)
    V["mailRead"] = lambda: place((0, air(0.1, 1400, 3000, 0.1)), (0.02, kalimba(note(12), 0.05, 0.5)))
    V["mailClaim"] = lambda: reward((10, 13, 15), 0.3, 4)
    # --- social ------------------------------------------------------------------
    V["chatSend"] = lambda: place((0, air(0.08, 1200, 3400, 0.1)), (0, kalimba(note(12), 0.03, 0.5)), (0.03, kalimba(note(14), 0.04, 0.45)))
    V["chatReceive"] = lambda: kalimba(note(14), 0.06, 0.55)
    V["crewNudge"] = lambda: place((0, kalimba(note(15), 0.04, 0.55)), (0.06, kalimba(note(15), 0.05, 0.5)))
    V["guildAnnounce"] = lambda: room(chord((8, 10, 12, 13), 0.12, bell, 0.3, 0.5), 0.45, 0.3)
    V["guildDeposit"] = lambda: place((0, tactile(0.8)), (0.01, coin(13, 0.7)))
    V["guildLeave"] = lambda: place((0, panel(False, 9, 0.5)), (0.05, mallet(note(6), 0.06, 0.3, 0.45)))
    V["itemLink"] = lambda: place((0, tactile(0.7)), (0, kalimba(note(11), 0.04, 0.5)), (0.03, kalimba(note(14), 0.05, 0.45)))
    V["itemUnlink"] = lambda: place((0, tactile(0.7, 0.9)), (0, kalimba(note(14), 0.03, 0.45)), (0.03, kalimba(note(11), 0.04, 0.4)))
    V["reportSubmit"] = lambda: room(place((0, press(10)), (0.05, kalimba(note(12), 0.08, 0.5))), 0.2, 0.15)
    V["feedbackSubmit"] = lambda: room(place((0, press(13)), (0.05, chord((10, 13, 14), 0.05, kalimba, 0.07, 0.55))), 0.25, 0.2)
    # --- results and notices ----------------------------------------------------
    V["successChime"] = lambda: room(chord((10, 12, 13, 15), 0.05, kalimba, 0.1, 0.75), 0.25, 0.2)
    V["error"] = lambda: no(4)
    V["errorBuzz"] = lambda: place((0, no(3, False)), (0.1, no(3, False) * 0.85), (0.2, no(2, False) * 0.7))
    V["locked"] = lambda: place((0, tactile(1.0, 0.75)), (0.005, mallet(note(5), 0.04, 0.2, 0.5)))
    V["requestBlocked"] = lambda: no(5, False)
    V["requestTimeout"] = lambda: place((0, mallet(note(9), 0.06, 0.3, 0.55)), (0.12, mallet(note(6), 0.08, 0.3, 0.5)))
    V["systemAlert"] = lambda: place((0, bell(note(12), 0.15, 0.6, 0.4)), (0.15, bell(note(12), 0.15, 0.55, 0.4)))
    V["notification"] = lambda: room(kalimba(note(13), 0.1, 0.6), 0.25, 0.2)
    V["noticeInfo"] = lambda: room(kalimba(note(13), 0.09, 0.6), 0.25, 0.2)
    V["noticeSuccess"] = lambda: room(chord((12, 15), 0.06, kalimba, 0.09, 0.65), 0.25, 0.2)
    V["noticeWarning"] = lambda: place((0, mallet(note(11), 0.05, 0.4, 0.65)), (0.12, mallet(note(11), 0.06, 0.4, 0.6)))
    V["noticeError"] = lambda: no(7)
    V["noticeSpecial"] = lambda: reward((10, 12, 13, 15), 0.3, 5)
    # --- currency and rewards ----------------------------------------------------
    V["purchase"] = lambda: place((0, coin(14)), (0.06, coin(16, 0.55)))
    V["purchaseResult"] = lambda: reward((11, 13, 15), 0.3, 4)
    V["collect"] = lambda: place((0, coin(13, 0.7)), (0.04, coin(15, 0.55)), (0.08, coin(17, 0.45)))
    V["offlineCollect"] = lambda: reward((8, 10, 13, 15, 17), 0.5, 7, 110)
    V["vaultDeposit"] = lambda: place((0, tactile(0.9)), (0.01, coin(12, 0.65)))
    V["vaultBank"] = lambda: place((0, tactile(1.0, 0.85)), (0, sub(140, 0.2, 0.3, 0.4)), (0.02, coin(11, 0.7)), (0.07, coin(13, 0.5)))
    V["reward"] = lambda: reward((10, 13, 15), 0.4, 5)
    V["dailyClaim"] = lambda: reward((8, 10, 13, 15), 0.45, 6, 120)
    V["timedClaim"] = lambda: reward((10, 12, 15), 0.35, 5)
    V["missionClaim"] = lambda: reward((11, 13, 16), 0.35, 5)
    V["seasonClaim"] = lambda: reward((8, 10, 12, 15, 17), 0.5, 7, 110)
    V["achievementClaim"] = lambda: reward((10, 12, 13, 15, 18), 0.55, 8, 100)
    V["badgeEarn"] = lambda: reward((13, 15, 18), 0.35, 5)
    V["codeReward"] = lambda: reward((10, 13, 15, 17), 0.45, 6)
    V["discovery"] = lambda: room(place((0, bell(note(12), 0.35, 0.6, 0.7)), (0.1, shimmer(0.35, 6))), 0.4, 0.3)
    V["unlock"] = lambda: room(place((0, tactile(0.9)), (0.02, rise(0.2, note(5), note(10), 0.35)), (0.2, chord((10, 13, 15), 0.05, kalimba, 0.1, 0.7))), 0.3, 0.22)
    V["researchUnlock"] = lambda: room(place((0, rise(0.18, note(6), note(11), 0.3)), (0.17, chord((11, 13, 16), 0.05, kalimba, 0.1, 0.7))), 0.3, 0.22)
    V["zoneUnlock"] = lambda: room(place((0, sub(90, 0.6, 0.3, 0.5)), (0, rise(0.3, note(5), note(12), 0.4)), (0.28, chord((8, 10, 12, 15, 17), 0.06, bell, 0.25, 0.6))), 0.5, 0.3)
    V["machineInstall"] = lambda: place((0, tactile(1.2, 0.7)), (0, sub(160, 0.18, 0.4, 0.5)), (0.04, mallet(note(8), 0.06, 0.7, 0.7)), (0.09, kalimba(note(13), 0.06, 0.5)))
    V["comboMilestone"] = lambda: place((0, kalimba(note(15), 0.05, 0.7)), (0.04, kalimba(note(18), 0.07, 0.6)))
    V["autoForge"] = lambda: place((0, tactile(0.7, 0.9)), (0, mallet(note(9), 0.04, 0.6, 0.55)), (0.06, mallet(note(12), 0.04, 0.6, 0.45)))
    V["salvage"] = lambda: place((0, tactile(1.0, 0.8)), (0, fft_band(RNG.standard_normal(int(0.12 * SR)), 800, 5000) * env(0.12, 0.002, 0.03) * 0.4), (0.04, kalimba(note(11), 0.06, 0.5)))
    V["salvageCrunch"] = lambda: place((0, tactile(1.2, 0.7)), (0, fft_band(RNG.standard_normal(int(0.18 * SR)), 400, 4000) * env(0.18, 0.002, 0.05) * 0.5), (0.06, coin(12, 0.5)))
    V["travel"] = lambda: room(place((0, air(0.3, 500, 3200, 0.22)), (0.08, chord((9, 12, 14), 0.06, kalimba, 0.09, 0.55))), 0.35, 0.25)
    V["expeditionLaunch"] = lambda: room(place((0, rise(0.35, note(4), note(10), 0.4)), (0.3, kalimba(note(13), 0.1, 0.6))), 0.35, 0.25)
    V["expeditionReturn"] = lambda: reward((9, 12, 14, 16), 0.45, 6, 110)
    # --- boosts ------------------------------------------------------------------
    V["boost"] = lambda: room(place((0, rise(0.22, note(8), note(14), 0.4)), (0.2, kalimba(note(16), 0.08, 0.6))), 0.3, 0.2)
    V["boostOpen"] = lambda: panel(True, 13)
    V["boostActivate"] = lambda: room(place((0, sub(120, 0.35, 0.3, 0.45)), (0, rise(0.25, note(8), note(15), 0.45)), (0.24, chord((13, 15, 18), 0.05, kalimba, 0.1, 0.7)), (0.3, shimmer(0.3, 5))), 0.35, 0.25)
    V["boostReady"] = lambda: place((0, kalimba(note(14), 0.06, 0.6)), (0.07, kalimba(note(17), 0.08, 0.55)))
    # --- wheel ------------------------------------------------------------------
    V["wheel"] = lambda: panel(True, 12)
    V["wheelCharge"] = lambda: rise(0.4, note(4), note(9), 0.4)
    V["wheelStart"] = lambda: place((0, tactile(1.1, 0.8)), (0, air(0.25, 600, 3000, 0.22)), (0.02, kalimba(note(10), 0.06, 0.6)))
    V["wheelTick"] = lambda: place((0, tactile(0.45, 1.4)), (0, mallet(note(16), 0.008, 0.6, 0.35)))
    V["wheelSlow"] = lambda: place((0, tactile(0.6, 1.1)), (0, mallet(note(13), 0.015, 0.6, 0.45)))
    V["wheelBrake"] = lambda: air(0.4, 2400, 600, 0.18)
    V["wheelLand"] = lambda: room(place((0, tactile(1.2, 0.8)), (0, sub(110, 0.4, 0.3, 0.45)), (0.03, chord((10, 13, 15, 17), 0.05, bell, 0.2, 0.6)), (0.15, shimmer(0.3, 5))), 0.4, 0.28)
    # --- crates -----------------------------------------------------------------
    V["crate"] = lambda: panel(True, 11)
    V["crateOpen"] = lambda: place((0, tactile(1.2, 0.75)), (0, sub(130, 0.2, 0.4, 0.5)), (0.02, mallet(note(9), 0.06, 0.8, 0.6)))
    V["crateCharge"] = lambda: rise(0.5, note(4), note(11), 0.45)
    V["crateSeal"] = lambda: room(place((0, sub(110, 0.3, 0.35, 0.55)), (0, tactile(1.1, 0.8)), (0.01, bell(note(10), 0.15, 0.5, 0.8)), (0.03, shimmer(0.15, 4))), 0.25, 0.2)
    V["crateOrbit"] = lambda: rise(0.6, note(5), note(10), 0.4)
    V["crateTick"] = lambda: place((0, tactile(0.4, 1.4)), (0, mallet(note(15), 0.008, 0.6, 0.3)))
    V["crateBrake"] = lambda: air(0.35, 2200, 700, 0.16)
    V["crateNear"] = lambda: place((0, kalimba(note(14), 0.04, 0.5)), (0.05, kalimba(note(15), 0.04, 0.45)))
    V["crateLand"] = lambda: place((0, tactile(1.0, 0.8)), (0.01, kalimba(note(12), 0.08, 0.6)))
    V["crateRarityStep"] = lambda: place((0, kalimba(note(14), 0.05, 0.6)), (0.02, kalimba(note(17), 0.04, 0.4)))
    V["crateRare"] = lambda: room(place((0, chord((12, 15, 17), 0.05, kalimba, 0.1, 0.7)), (0.1, shimmer(0.25, 4))), 0.3, 0.22)
    V["crateRevealEpic"] = lambda: room(place((0, sub(90, 0.45, 0.35, 0.55)), (0.02, chord((10, 12, 13, 15, 17), 0.045, bell, 0.22, 0.65)), (0.2, shimmer(0.35, 7))), 0.45, 0.28)
    V["crateRevealMythic"] = lambda: room(place((0, sub(70, 0.7, 0.4, 0.7)), (0, air(0.45, 500, 4200, 0.2)), (0.04, chord((5, 8, 10, 12, 15, 17, 20), 0.05, bell, 0.3, 0.6)), (0.32, shimmer(0.5, 10))), 0.6, 0.32)
    V["crateClaim"] = lambda: reward((10, 13, 15), 0.35, 5)
    # --- domain, echoes, reactor, prestige --------------------------------------
    V["domainCharge"] = lambda: rise(0.7, note(3), note(10), 0.5)
    V["domainBind"] = lambda: room(place((0, sub(80, 0.5, 0.3, 0.5)), (0.02, bell(note(8), 0.4, 0.55, 0.9))), 0.45, 0.3)
    V["domainCrack"] = lambda: place((0, tactile(1.4, 0.6)), (0, fft_band(RNG.standard_normal(int(0.3 * SR)), 300, 6000) * env(0.3, 0.001, 0.06) * 0.5), (0.02, bell(note(13), 0.3, 0.45, 1.0)))
    V["domainImpact"] = lambda: room(place((0, sub(60, 0.9, 0.5, 0.85)), (0, tactile(1.5, 0.5)), (0.01, air(0.6, 3600, 300, 0.25)), (0.05, chord((3, 5, 8, 10), 0.03, bell, 0.4, 0.5))), 0.7, 0.32)
    V["domainReward"] = lambda: reward((5, 8, 10, 12, 15, 17), 0.7, 9, 80)
    V["artifactEquip"] = lambda: room(place((0, tactile(1.0, 0.8)), (0.01, bell(note(10), 0.15, 0.5, 0.6)), (0.06, kalimba(note(13), 0.08, 0.5))), 0.25, 0.2)
    V["artifactUpgrade"] = lambda: room(place((0, rise(0.22, note(5), note(12), 0.35)), (0.2, chord((10, 12, 13, 15), 0.04, kalimba, 0.08, 0.7))), 0.3, 0.22)
    V["echoCapture"] = lambda: room(place((0, rise(0.2, note(8), note(13), 0.35)), (0.18, bell(note(15), 0.25, 0.5, 0.7))), 0.35, 0.25)
    V["echoEquip"] = lambda: place((0, tactile(0.9)), (0.01, bell(note(12), 0.12, 0.5, 0.6)))
    V["echoTune"] = lambda: place((0, kalimba(note(11), 0.04, 0.5)), (0.04, kalimba(note(13), 0.05, 0.5)), (0.08, kalimba(note(16), 0.06, 0.45)))
    V["echoDismantle"] = lambda: place((0, tactile(1.0, 0.8)), (0.02, bell(note(13), 0.1, 0.4, 0.6)), (0.06, bell(note(9), 0.12, 0.35, 0.5)))
    V["echoClaim"] = lambda: reward((11, 13, 16), 0.35, 5)
    V["reactor"] = lambda: panel(True, 9)
    V["reactorPulse"] = lambda: place((0, tactile(0.9, 0.8)), (0, sub(100, 0.25, 0.3, 0.55)), (0.02, mallet(note(10), 0.05, 0.7, 0.55)))
    V["reactorReady"] = lambda: place((0, kalimba(note(13), 0.06, 0.6)), (0.07, kalimba(note(16), 0.09, 0.55)))
    V["reactorStabilize"] = lambda: room(place((0, sub(90, 0.4, 0.2, 0.5)), (0.02, chord((8, 10, 13), 0.06, bell, 0.22, 0.55))), 0.4, 0.25)
    V["reactorSurge"] = lambda: room(place((0, rise(0.4, note(4), note(13), 0.5)), (0.38, chord((10, 13, 15, 18), 0.04, kalimba, 0.1, 0.7)), (0.4, shimmer(0.3, 6))), 0.4, 0.25)
    V["prestige"] = lambda: room(place((0, sub(80, 0.6, 0.4, 0.6)), (0.02, chord((5, 8, 10, 13), 0.08, bell, 0.3, 0.55))), 0.5, 0.3)
    V["rebirthCharge"] = lambda: rise(0.8, note(3), note(11), 0.5)
    V["rebirthBloom"] = lambda: reward((5, 8, 10, 12, 15), 0.6, 8, 90)
    V["rebirthIgnite"] = lambda: room(place((0, rise(0.9, note(3), note(13), 0.55)), (0.86, bell(note(15), 0.2, 0.6, 0.8))), 0.4, 0.25)
    V["rebirthShockwave"] = lambda: room(place((0, sub(70, 0.8, 0.6, 0.9)), (0, tactile(1.6, 0.5)), (0, air(0.6, 3600, 300, 0.3)), (0.02, bell(note(10), 0.35, 0.5, 0.9))), 0.7, 0.32)
    V["rebirthTierUp"] = lambda: room(place((0, kalimba(note(14), 0.08, 0.7)), (0.05, kalimba(note(17), 0.1, 0.6)), (0.1, shimmer(0.18, 3))), 0.3, 0.22)
    V["rebirthAscend"] = lambda: room(place((0, sub(60, 1.0, 0.25, 0.6)), (0, chord((3, 5, 8, 10), 0.08, bell, 0.4, 0.55)), (0.32, chord((13, 15, 18), 0.09, bell, 0.3, 0.55)), (0.5, shimmer(0.6, 11))), 0.8, 0.34)
    # --- boot and tutorial ------------------------------------------------------
    V["boot"] = lambda: room(place((0, air(0.5, 300, 2400, 0.18)), (0.1, bell(note(5), 0.5, 0.45, 0.4))), 0.6, 0.3)
    V["bootStart"] = lambda: room(place((0, sub(70, 0.8, 0.2, 0.5)), (0.05, air(0.7, 250, 2600, 0.18)), (0.3, bell(note(5), 0.5, 0.45, 0.4))), 0.7, 0.32)
    V["bootReady"] = lambda: room(chord((5, 8, 10, 13), 0.08, bell, 0.3, 0.55), 0.6, 0.3)
    V["bootFinaleBang"] = lambda: room(place((0, sub(55, 1.0, 0.5, 0.9)), (0, tactile(1.6, 0.5)), (0.02, chord((3, 5, 8, 10, 13), 0.03, bell, 0.45, 0.5)), (0.2, shimmer(0.6, 10))), 0.8, 0.34)
    V["tutorialStep"] = lambda: place((0, kalimba(note(12), 0.05, 0.55)), (0.05, kalimba(note(14), 0.06, 0.5)))
    V["tutorialFinish"] = lambda: reward((8, 10, 12, 15, 17), 0.55, 8, 110)
    # --- every page has its own two-note figure; every hover family a single tap -
    for index, page in enumerate(PAGES):
        V[f"navOpen{page}"] = lambda i=index: page_open(i)
        V[f"navHover{page}"] = lambda i=index: hover(11 + (i * 3) % 7, 0.55)
    # icon presses
    for index, name in enumerate(("forgePress", "corePress", "wavePress", "labPress", "commandPress", "adminPress",
                                  "creditsPress", "chatPress", "continuumPress", "missionPress", "overviewPress")):
        V[name] = lambda i=index: press(9 + (i * 2) % 8)
    return V


def voices(names=None):
    """Name -> renderer returning a list of floats (what the sheet packer mixes). Any name ending in
    Hover that has no voice of its own gets a pointer tap pitched from its name."""
    V = design()
    if names is not None:
        for name in names:
            if name not in V and name.endswith("Hover"):
                step = 11 + sum(map(ord, name)) % 7
                V[name] = lambda s=step: hover(s, 0.55)
    return {name: (lambda make=make: [float(v) for v in finish(make())]) for name, make in V.items()}


if __name__ == "__main__":
    import wave

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "generated", "ui_preview")
    os.makedirs(out, exist_ok=True)
    made = voices()
    for name, make in made.items():
        buf = np.asarray(make())
        peak = float(np.max(np.abs(buf))) or 1.0
        data = (np.clip(buf / peak * 0.7, -1, 1) * 32767).astype("<i2")
        with wave.open(os.path.join(out, f"{name}.wav"), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(data.tobytes())
    print(f"rendered {len(made)} voices to {os.path.abspath(out)}")
