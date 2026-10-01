"""Synthesize the boss element sound effects (no samples, no licences: all maths).

    python tools/assetgen/boss_sfx_gen.py      # -> assets/generated/bosssfx/*.wav + sfx_names.json
    python tools/assetgen/upload_boss_sfx.py   # upload and wire the ids into SharedData.luau

cast_<Element>  the wind-up before an elemental blow lands
hit_<Element>   the blow landing
wisp_spawn / wisp_blast / wisp_down   the summoned wisps
impact          the hard punctuation of an impact frame
"""

from __future__ import annotations

import json
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "bosssfx")
RATE = 44100
rng = np.random.default_rng(11)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def lowpass(x, cutoff):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(x))


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def sweep(seconds, f0, f1):
    t = t_axis(seconds)
    freq = f0 * (f1 / f0) ** (t / seconds)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def swell(n, power=2.0):
    return np.linspace(0, 1, n) ** power


def decay(n, rate):
    return np.exp(-np.linspace(0, rate, n))


def reverb(x, seconds=0.9, wet=0.3):
    n = int(seconds * RATE)
    tail = rng.standard_normal(n) * decay(n, 7)
    size = len(x) + n
    out = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(tail, size), size)
    out *= np.max(np.abs(x)) / max(1e-9, np.max(np.abs(out)))
    return np.concatenate([x, np.zeros(n)]) * (1 - wet * 0.5) + out * wet


def norm(x, peak=0.9):
    return x / max(1e-9, np.max(np.abs(x))) * peak


def fade_out(x, seconds=0.05):
    n = int(seconds * RATE)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def cast_fire():
    n = int(1.4 * RATE)
    body = lowpass(noise(1.4), 900) * swell(n, 1.6)
    crackle = (rng.random(n) > 0.9992).astype(float) * rng.standard_normal(n) * 3
    crackle = lowpass(crackle, 6000) * swell(n, 1.0)
    return norm(body * 1.0 + crackle * 0.6 + sweep(1.4, 70, 180) * 0.4 * swell(n))


def cast_storm():
    n = int(1.2 * RATE)
    t = t_axis(1.2)
    buzz = np.sign(np.sin(2 * np.pi * 55 * t)) * 0.3 * swell(n, 1.4)
    zap = sweep(1.2, 400, 3200) * swell(n, 2.2)
    return norm(buzz + zap * 0.6 + highpass(noise(1.2), 3000) * 0.2 * swell(n, 3))


def cast_frost():
    n = int(1.4 * RATE)
    t = t_axis(1.4)
    out = np.zeros(n)
    for f in (2093, 2637, 3136, 4186, 5274):
        out += np.sin(2 * np.pi * f * t + rng.random() * 6) * (1 + 0.5 * np.sin(2 * np.pi * (4 + f % 5) * t))
    return norm(reverb(out * swell(n, 1.8) * 0.3 + highpass(noise(1.4), 6000) * 0.1 * swell(n, 2), 1.0, 0.4))


def cast_void():
    n = int(1.6 * RATE)
    drone = sweep(1.6, 220, 36) * (1 - 0.5 * swell(n, 1.0))
    pulse = np.sin(2 * np.pi * 48 * t_axis(1.6)) * swell(n, 2.5)
    return norm(np.tanh((drone * 0.7 + pulse) * 1.8) + lowpass(noise(1.6), 300) * 0.4 * swell(n, 1.5))


def hit_fire():
    n = int(1.1 * RATE)
    boom = lowpass(noise(1.1), 1400) * decay(n, 5)
    thump = sweep(1.1, 140, 38) * decay(n, 6)
    return norm(reverb(boom * 0.8 + thump * 1.2, 0.8, 0.25))


def hit_storm():
    n = int(1.6 * RATE)
    crack = highpass(noise(1.6), 1500) * decay(n, 40)
    rumble = lowpass(noise(1.6), 200) * decay(n, 3.5) * 1.4
    return norm(reverb(crack * 1.2 + rumble, 1.2, 0.35))


def hit_frost():
    n = int(1.3 * RATE)
    t = t_axis(1.3)
    out = highpass(noise(1.3), 4000) * decay(n, 25) * 0.6
    for _ in range(28):
        start = int(rng.random() * 0.25 * RATE)
        f = 2500 + rng.random() * 5500
        ping = np.sin(2 * np.pi * f * t[: n - start]) * decay(n - start, 14 + rng.random() * 10)
        out[start:] += ping * (0.15 + rng.random() * 0.25)
    return norm(reverb(out, 0.9, 0.3))


def hit_void():
    n = int(1.6 * RATE)
    drop = sweep(1.6, 160, 24) * decay(n, 2.5)
    crush = np.tanh(drop * 3.2)
    return norm(reverb(crush + lowpass(noise(1.6), 500) * decay(n, 4) * 0.5, 1.4, 0.4))


def wisp_spawn():
    n = int(0.7 * RATE)
    return norm(reverb(sweep(0.7, 300, 1800) * swell(n, 0.8) * decay(n, 2.5) + highpass(noise(0.7), 5000) * 0.05, 0.6, 0.3))


def wisp_blast():
    n = int(0.9 * RATE)
    thump = sweep(0.9, 190, 45) * decay(n, 7)
    pop = highpass(noise(0.9), 800) * decay(n, 18)
    return norm(reverb(thump * 1.2 + pop * 0.7, 0.6, 0.2))


def wisp_down():
    n = int(0.6 * RATE)
    t = t_axis(0.6)
    ping = (np.sin(2 * np.pi * 1320 * t) + 0.5 * np.sin(2 * np.pi * 1980 * t)) * decay(n, 7)
    return norm(reverb(ping + sweep(0.6, 1800, 400) * 0.3 * decay(n, 5), 0.5, 0.25))


def impact():
    n = int(0.45 * RATE)
    thump = sweep(0.45, 120, 30) * decay(n, 8)
    click = highpass(noise(0.45), 2000) * decay(n, 60)
    return norm(np.tanh((thump * 1.4 + click * 0.8) * 1.5))


SOUNDS = {
    "cast_Fire": cast_fire, "cast_Storm": cast_storm, "cast_Frost": cast_frost, "cast_Void": cast_void,
    "hit_Fire": hit_fire, "hit_Storm": hit_storm, "hit_Frost": hit_frost, "hit_Void": hit_void,
    "wisp_spawn": wisp_spawn, "wisp_blast": wisp_blast, "wisp_down": wisp_down, "impact": impact,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in SOUNDS.items():
        data = fade_out(norm(make()))
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
