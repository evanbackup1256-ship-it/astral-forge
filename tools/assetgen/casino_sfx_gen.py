"""Synthesize the Astral Casino's sound effects (no samples, no licences: all maths).

    python tools/assetgen/casino_sfx_gen.py      # -> assets/generated/casinosfx/*.wav + sfx_names.json
    python tools/assetgen/upload_casino_sfx.py   # upload and write the ids into Shared/CasinoSfx.luau

casino_spin        reels whirring (loops)             casino_reel_stop   a reel landing: thump, click, ping
casino_chip        a chip or button press             casino_tick        a tiny UI tick
casino_win_small   a few coins                        casino_win_big     a rising arpeggio and a coin spill
casino_jackpot     the full fanfare                   casino_lose        a soft falling sigh
casino_card_flip   a card turning over                casino_coin_spin   a coin ringing in the air
casino_coin_land   the coin landing                   casino_ball_roll   the roulette ball rattling round (loops)
casino_ball_drop   the ball bouncing into a pocket    casino_scratch     a coin on a scratch card
casino_cash        a till opening                     casino_streak      a streak step, rising
casino_rank        a club rank fanfare                casino_buy         a purchase confirmation
"""

from __future__ import annotations

import json
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "casinosfx")
RATE = 44100
rng = np.random.default_rng(23)


def tt(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def lowpass(x, cutoff, order=4):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum *= 1 / (1 + (freqs / max(cutoff, 20.0)) ** order)
    return np.fft.irfft(spectrum, len(x))


def highpass(x, cutoff):
    return x - lowpass(x, cutoff, 2)


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, min(n // 2, int(attack * RATE)))
    r = max(1, min(n // 2, int(release * RATE)))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] = np.minimum(e[-r:], np.linspace(1, 0, r))
    return e


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def bell(freq, seconds=1.2, index=2.0, rate=3.0):
    t = tt(seconds)
    mod = np.sin(2 * np.pi * freq * 3.51 * t) * index * np.exp(-t * 2.0)
    return np.sin(2 * np.pi * freq * t + mod) * np.exp(-t * rate) * env(len(t), 0.002, 0.05)


def coin(freq=2600, seconds=0.35):
    """A coin ping: a bright metallic partial pair with a fast decay."""
    t = tt(seconds)
    out = np.sin(2 * np.pi * freq * t) + 0.6 * np.sin(2 * np.pi * freq * 1.52 * t) + 0.3 * np.sin(2 * np.pi * freq * 2.31 * t)
    return out * np.exp(-t * 14) * env(len(t), 0.001, 0.02)


def brass(freq, seconds=0.6):
    t = tt(seconds)
    s = 2 * ((t * freq) % 1.0) - 1 + 2 * ((t * freq * 1.005) % 1.0) - 1
    s = lowpass(s, 2200, 2) * np.minimum(1, t / 0.08)
    return np.tanh(s * 1.2) * env(len(t), 0.03, min(0.25, seconds * 0.5))


def place(buffer, sound, at, gain=1.0):
    i = int(at * RATE)
    if i >= len(buffer):
        return
    n = min(len(sound), len(buffer) - i)
    buffer[i : i + n] += sound[:n] * gain


def reverb(x, seconds=0.9, wet=0.22):
    n = int(seconds * RATE)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 6.0, n))
    size = len(x) + n
    wetsig = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    wetsig /= max(1e-6, np.abs(wetsig).max())
    wetsig *= np.abs(x).max()
    out = np.zeros(size)
    out[: len(x)] += x * (1 - wet)
    out += wetsig * wet
    return out


# ------------------------------------------------------------------------------------------- the sounds
def casino_spin():
    seconds = 1.2
    t = tt(seconds)
    whirr = bandpass(noise(seconds), 300, 2200) * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t))
    tone = np.sin(2 * np.pi * np.cumsum(180 + 60 * np.sin(2 * np.pi * 1.6 * t)) / RATE) * 0.3
    ticks = np.zeros_like(t)
    for k in range(int(seconds * 22)):
        place(ticks, highpass(noise(0.01), 3000) * np.exp(-tt(0.01) * 400), k / 22.0, 0.8)
    out = whirr + tone + ticks * 0.5
    # seamless loop: crossfade the end into the start
    fade = int(0.08 * RATE)
    out[:fade] = out[:fade] * np.linspace(0, 1, fade) + out[-fade:] * np.linspace(1, 0, fade)
    return out[:-fade]


def casino_reel_stop():
    t = tt(0.4)
    thump = np.sin(2 * np.pi * np.cumsum(110 * np.exp(-t * 14) + 48) / RATE) * np.exp(-t * 16)
    click = highpass(noise(0.4), 2500) * np.exp(-t * 90) * 0.7
    ping = bell(1760, 0.4, 1.2, 8) * 0.25
    return thump + click + ping


def casino_chip():
    t = tt(0.14)
    return (highpass(noise(0.14), 2200) * np.exp(-t * 70) * 0.7 + np.sin(2 * np.pi * 1900 * t) * np.exp(-t * 55) * 0.5)


def casino_tick():
    t = tt(0.06)
    return highpass(noise(0.06), 2800) * np.exp(-t * 120) * 0.6 + np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 90) * 0.4


def casino_win_small():
    out = np.zeros(int(1.1 * RATE))
    for k, note in enumerate((79, 83, 86)):
        place(out, bell(hz(note), 0.7, 1.6, 4.0), k * 0.09, 0.6)
    for k in range(7):
        place(out, coin(2300 + 400 * rng.random()), 0.25 + k * 0.07 + rng.random() * 0.03, 0.35)
    return reverb(out, 0.7, 0.18)


def casino_win_big():
    out = np.zeros(int(2.2 * RATE))
    for k, note in enumerate((72, 76, 79, 84, 88, 91, 96)):
        place(out, bell(hz(note), 1.1, 2.0, 3.0), k * 0.08, 0.5)
        place(out, brass(hz(note - 12), 0.3), k * 0.08, 0.12)
    for k in range(26):
        place(out, coin(2000 + 1200 * rng.random(), 0.3), 0.5 + k * 0.045 + rng.random() * 0.02, 0.3)
    place(out, np.sin(2 * np.pi * np.cumsum(np.linspace(200, 1200, int(0.55 * RATE))) / RATE) * 0.15, 0.0)
    return reverb(out, 1.1, 0.24)


def casino_jackpot():
    out = np.zeros(int(4.0 * RATE))
    riser = highpass(noise(1.0), 400) * np.linspace(0, 1, int(1.0 * RATE)) ** 2
    place(out, riser, 0.0, 0.35)
    chords = ((60, 64, 67), (65, 69, 72), (67, 71, 74), (72, 76, 79))
    for index, chord in enumerate(chords):
        for note in chord:
            place(out, brass(hz(note), 0.62), 1.0 + index * 0.5, 0.2)
            place(out, bell(hz(note + 24), 1.4, 2.4, 2.5), 1.0 + index * 0.5, 0.2)
    for k in range(70):
        place(out, coin(1800 + 1800 * rng.random(), 0.3), 1.6 + k * 0.03 + rng.random() * 0.02, 0.25)
    for k in range(6):
        place(out, bell(hz(96 + (k % 3) * 4), 1.0, 2.0, 3.0), 3.0 + k * 0.1, 0.3)
    return reverb(out, 1.6, 0.3)


def casino_lose():
    t = tt(0.8)
    fall = np.sin(2 * np.pi * np.cumsum(np.linspace(330, 130, len(t))) / RATE) * np.exp(-t * 4.0)
    thud = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 14) * 0.7
    return (fall * 0.5 + thud) * env(len(t), 0.005, 0.1)


def casino_card_flip():
    t = tt(0.28)
    swish = bandpass(noise(0.28), 1500, 7000) * np.sin(np.pi * t / 0.28) ** 2
    snap = highpass(noise(0.28), 3000) * np.exp(-np.maximum(0, t - 0.2) * 80) * (t > 0.2)
    return swish * 0.7 + snap * 0.5


def casino_coin_spin():
    seconds = 1.1
    t = tt(seconds)
    vib = 1 + 0.02 * np.sin(2 * np.pi * (9 + 8 * t) * t)
    ring = np.sin(2 * np.pi * 3100 * vib * t) * 0.5 + np.sin(2 * np.pi * 4700 * vib * t) * 0.25
    whoosh = bandpass(noise(seconds), 800, 4000) * 0.15
    return (ring + whoosh) * np.exp(-t * 1.2) * env(len(t), 0.01, 0.3)


def casino_coin_land():
    out = np.zeros(int(0.8 * RATE))
    for k, gap in enumerate((0.0, 0.11, 0.2, 0.26)):
        place(out, coin(2800 - k * 250, 0.3), gap, 0.9 - k * 0.2)
    place(out, np.sin(2 * np.pi * 95 * tt(0.2)) * np.exp(-tt(0.2) * 20) * 0.5, 0.0)
    return out


def casino_ball_roll():
    seconds = 1.6
    t = tt(seconds)
    rattle = bandpass(noise(seconds), 600, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 34 * t * (1 - 0.3 * t / seconds)))
    ticks = np.zeros_like(t)
    when = 0.0
    gap = 0.045
    while when < seconds - 0.02:
        place(ticks, highpass(noise(0.01), 2500) * np.exp(-tt(0.01) * 350), when, 0.9)
        when += gap
        gap *= 1.012
    out = rattle * 0.5 + ticks * 0.6
    fade = int(0.06 * RATE)
    out[:fade] = out[:fade] * np.linspace(0, 1, fade) + out[-fade:] * np.linspace(1, 0, fade)
    return out[:-fade]


def casino_ball_drop():
    out = np.zeros(int(1.0 * RATE))
    when, level = 0.0, 1.0
    for _ in range(9):
        place(out, highpass(noise(0.05), 1500) * np.exp(-tt(0.05) * 70) * level + np.sin(2 * np.pi * 900 * tt(0.05)) * np.exp(-tt(0.05) * 90) * level * 0.5, when, 0.8)
        when += 0.18 * (0.8 ** _)
        level *= 0.74
    place(out, coin(3300, 0.25), when + 0.04, 0.45)
    return out


def casino_scratch():
    t = tt(0.5)
    rasp = bandpass(noise(0.5), 1800, 9000) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t)) * np.sin(np.pi * t / 0.5) ** 0.6
    return rasp * 0.7


def casino_cash():
    out = np.zeros(int(1.2 * RATE))
    place(out, bandpass(noise(0.18), 600, 3000) * np.linspace(0, 1, int(0.18 * RATE)), 0.0, 0.5)
    place(out, bell(2093, 1.0, 1.4, 4.5), 0.18, 0.6)
    place(out, bell(3136, 1.0, 1.4, 4.5), 0.27, 0.6)
    place(out, np.sin(2 * np.pi * 120 * tt(0.15)) * np.exp(-tt(0.15) * 20) * 0.6, 0.18)
    return reverb(out, 0.5, 0.15)


def casino_streak():
    out = np.zeros(int(0.6 * RATE))
    place(out, bell(hz(84), 0.5, 1.3, 5), 0.0, 0.6)
    place(out, bell(hz(91), 0.5, 1.3, 5), 0.09, 0.6)
    return out


def casino_rank():
    out = np.zeros(int(2.4 * RATE))
    for index, chord in enumerate(((60, 64, 67), (62, 67, 71), (64, 67, 72), (67, 72, 76))):
        for note in chord:
            place(out, brass(hz(note), 0.5), index * 0.32, 0.2)
            place(out, bell(hz(note + 24), 1.2, 2.0, 3.0), index * 0.32, 0.15)
    for k in range(18):
        place(out, coin(2200 + 900 * rng.random(), 0.3), 1.0 + k * 0.05, 0.25)
    return reverb(out, 1.2, 0.26)


def casino_buy():
    out = np.zeros(int(0.7 * RATE))
    place(out, bell(hz(76), 0.5, 1.2, 5), 0.0, 0.6)
    place(out, bell(hz(83), 0.6, 1.2, 4.5), 0.1, 0.6)
    place(out, coin(2700), 0.2, 0.4)
    return out


SOUNDS = {
    "casino_spin": casino_spin, "casino_reel_stop": casino_reel_stop, "casino_chip": casino_chip, "casino_tick": casino_tick,
    "casino_win_small": casino_win_small, "casino_win_big": casino_win_big, "casino_jackpot": casino_jackpot, "casino_lose": casino_lose,
    "casino_card_flip": casino_card_flip, "casino_coin_spin": casino_coin_spin, "casino_coin_land": casino_coin_land,
    "casino_ball_roll": casino_ball_roll, "casino_ball_drop": casino_ball_drop, "casino_scratch": casino_scratch,
    "casino_cash": casino_cash, "casino_streak": casino_streak, "casino_rank": casino_rank, "casino_buy": casino_buy,
}


def finish(x):
    peak = max(1e-6, np.abs(x).max())
    x = x / peak * 0.92
    fade = int(0.01 * RATE)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in SOUNDS.items():
        data = finish(np.tanh(make() * 1.1))
        with wave.open(os.path.join(OUT, name + ".wav"), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
        print(f"{name}: {len(data) / RATE:.2f}s")
    with open(os.path.join(OUT, "sfx_names.json"), "w", encoding="utf-8") as handle:
        json.dump(sorted(SOUNDS), handle, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
