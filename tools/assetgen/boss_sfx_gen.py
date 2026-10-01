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


def band(x, lo, hi):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    mask = np.exp(-(((freqs - (lo + hi) / 2) / ((hi - lo) / 2 + 1e-6)) ** 4))
    return np.fft.irfft(spectrum * mask, len(x))


def chord(freqs, seconds, vibrato=5.0, depth=0.004, detune=0.003):
    t = t_axis(seconds)
    out = np.zeros(len(t))
    for index, f in enumerate(freqs):
        for d in (-detune, 0, detune):
            phase = rng.random() * 6.28
            out += np.sin(2 * np.pi * f * (1 + d) * t + depth * np.sin(2 * np.pi * vibrato * t + index) * f * 0.05 + phase)
    return out


# --- per-boss packs: roar (awake / phase), charge (wind-up), boom (a blow lands), death ----------

def roar_Warden():
    n = int(2.6 * RATE)
    t = t_axis(2.6)
    growl = band(noise(2.6), 70, 420) * (np.sin(2 * np.pi * 7 * t) * 0.35 + 0.65)
    sub = sweep(2.6, 48, 30) * 0.9
    tear = highpass(noise(2.6), 3000) * (rng.random(n) > 0.9993) * 6
    env = np.minimum(1, np.linspace(0, 1, n) * 6) * decay(n, 1.8)
    return norm(reverb(np.tanh((growl * 1.4 + sub) * env * 1.8) + tear * 0.3, 1.8, 0.4))


def charge_Warden():
    n = int(2.0 * RATE)
    swell_env = swell(n, 1.7)
    return norm(reverb(sweep(2.0, 90, 38) * swell_env + band(noise(2.0), 200, 900) * swell_env * 0.5 + highpass(noise(2.0), 4000) * (rng.random(n) > 0.9994) * 3, 1.4, 0.3))


def boom_Warden():
    n = int(2.2 * RATE)
    return norm(reverb(np.tanh(sweep(2.2, 130, 28) * decay(n, 4) * 3) + band(noise(2.2), 80, 600) * decay(n, 6) * 0.7, 1.6, 0.4))


def death_Warden():
    n = int(4.0 * RATE)
    t = t_axis(4.0)
    voice = band(noise(4.0), 60, 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 4 * t)) * decay(n, 2.2)
    return norm(reverb(np.tanh((voice * 2 + sweep(4.0, 80, 22) * decay(n, 1.6)) * 1.6), 2.4, 0.5))


def roar_Choir():
    n = int(3.0 * RATE)
    notes = chord([261.6, 329.6, 392.0, 523.3, 659.3], 3.0, 5.5, 0.01)
    return norm(reverb(notes * np.minimum(1, np.linspace(0, 1, n) * 4) * decay(n, 1.2) + highpass(noise(3.0), 6000) * decay(n, 4) * 0.08, 2.6, 0.5))


def charge_Choir():
    n = int(2.2 * RATE)
    return norm(reverb(chord([392.0, 493.9, 587.3, 784.0], 2.2, 6.0, 0.012) * swell(n, 1.5), 2.0, 0.45))


def boom_Choir():
    n = int(2.0 * RATE)
    t = t_axis(2.0)
    return norm(reverb((np.sin(2 * np.pi * 523.3 * t) + np.sin(2 * np.pi * 784.0 * t) * 0.7 + np.sin(2 * np.pi * 1318.5 * t) * 0.4) * decay(n, 5) + sweep(2.0, 200, 50) * decay(n, 8) * 0.6, 2.0, 0.5))


def death_Choir():
    n = int(4.5 * RATE)
    return norm(reverb(chord([261.6, 311.1, 392.0, 466.2], 4.5, 4.5, 0.02) * decay(n, 1.4), 3.4, 0.6))


def roar_Regent():
    n = int(2.8 * RATE)
    t = t_axis(2.8)
    rumble = band(noise(2.8), 50, 350) * (0.55 + 0.45 * np.sin(2 * np.pi * 9 * t))
    fire = highpass(noise(2.8), 800) * decay(n, 1.5) * 0.35
    return norm(np.tanh((rumble * 2.2 + sweep(2.8, 70, 40) * 0.8 + fire) * np.minimum(1, np.linspace(0, 1, n) * 5) * 2.2))


def charge_Regent():
    n = int(2.0 * RATE)
    crackle = (rng.random(n) > 0.9985).astype(float) * rng.standard_normal(n) * 2
    return norm(lowpass(noise(2.0), 600) * swell(n, 1.4) + highpass(crackle, 1500) * swell(n, 1.0) * 0.6 + sweep(2.0, 40, 120) * swell(n, 1.6) * 0.7)


def boom_Regent():
    n = int(2.4 * RATE)
    return norm(reverb(np.tanh(sweep(2.4, 110, 24) * decay(n, 3.5) * 3.2) + lowpass(noise(2.4), 2200) * decay(n, 4.5) * 0.9, 1.4, 0.35))


def death_Regent():
    n = int(4.2 * RATE)
    return norm(reverb(np.tanh(sweep(4.2, 90, 20) * decay(n, 1.4) * 2.5) + lowpass(noise(4.2), 900) * decay(n, 2.2) * 0.8, 2.2, 0.45))


def roar_Seraph():
    n = int(2.4 * RATE)
    thunder = lowpass(noise(2.4), 220) * decay(n, 2.0) * 1.4
    crack = highpass(noise(2.4), 1800) * decay(n, 30)
    shimmer = chord([1046.5, 1318.5, 1568.0], 2.4, 7.0, 0.01) * decay(n, 1.6) * 0.18
    return norm(reverb(np.tanh(thunder * 2 + crack * 1.2) + shimmer, 1.6, 0.4))


def charge_Seraph():
    n = int(1.8 * RATE)
    t = t_axis(1.8)
    return norm(sweep(1.8, 300, 2600) * swell(n, 2.0) * 0.5 + np.sign(np.sin(2 * np.pi * 50 * t)) * 0.25 * swell(n, 1.4) + highpass(noise(1.8), 3500) * swell(n, 3.0) * 0.3)


def boom_Seraph():
    n = int(2.2 * RATE)
    return norm(reverb(highpass(noise(2.2), 1500) * decay(n, 35) * 1.3 + lowpass(noise(2.2), 180) * decay(n, 3) * 1.5, 1.8, 0.4))


def death_Seraph():
    n = int(4.0 * RATE)
    return norm(reverb(chord([523.3, 659.3, 784.0, 1046.5], 4.0, 5.0, 0.014) * decay(n, 1.2) * 0.7 + lowpass(noise(4.0), 200) * decay(n, 2.5) * 0.6, 3.0, 0.55))


def roar_Rime():
    n = int(3.0 * RATE)
    t = t_axis(3.0)
    creak = band(noise(3.0), 250, 700) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 3.2 * t)))
    wind = band(noise(3.0), 400, 1800) * decay(n, 1.4) * 0.5
    return norm(reverb(np.tanh((creak * 2.2 + sweep(3.0, 60, 36) * 0.7) * np.minimum(1, np.linspace(0, 1, n) * 4)) + wind, 2.4, 0.5))


def charge_Rime():
    n = int(2.2 * RATE)
    return norm(reverb(band(noise(2.2), 1500, 6000) * swell(n, 1.6) * 0.5 + chord([1396.9, 1760.0, 2093.0], 2.2, 3.0, 0.004) * swell(n, 1.4) * 0.25, 1.8, 0.45))


def boom_Rime():
    n = int(2.2 * RATE)
    t = t_axis(2.2)
    shards = np.zeros(n)
    for _ in range(40):
        s = int(rng.random() * 0.35 * RATE)
        f = 1800 + rng.random() * 6000
        shards[s:] += np.sin(2 * np.pi * f * t[: n - s]) * decay(n - s, 10 + rng.random() * 14) * (0.1 + rng.random() * 0.2)
    return norm(reverb(sweep(2.2, 100, 30) * decay(n, 5) * 0.8 + shards + highpass(noise(2.2), 4500) * decay(n, 25) * 0.5, 1.6, 0.4))


def death_Rime():
    n = int(4.2 * RATE)
    return norm(reverb(band(noise(4.2), 200, 900) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 2 * t_axis(4.2)))) * decay(n, 1.6) * 1.4 + sweep(4.2, 120, 28) * decay(n, 1.8), 3.0, 0.55))


def roar_Knight():
    n = int(2.2 * RATE)
    t = t_axis(2.2)
    clang = (np.sin(2 * np.pi * 523 * t) + 0.6 * np.sin(2 * np.pi * 1187 * t) + 0.4 * np.sin(2 * np.pi * 2210 * t)) * decay(n, 6)
    whisper = band(noise(2.2), 800, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * t)) * decay(n, 2.2) * 0.4
    return norm(reverb(clang * 0.7 + whisper + sweep(2.2, 90, 45) * decay(n, 3) * 0.7, 1.2, 0.35))


def charge_Knight():
    n = int(1.8 * RATE)
    return norm(reverb(highpass(noise(1.8), 2500) * swell(n, 2.5) * 0.45 + sweep(1.8, 400, 1800) * swell(n, 2.2) * 0.3 + band(noise(1.8), 600, 2500) * swell(n, 1.6) * 0.3, 0.8, 0.3))


def boom_Knight():
    n = int(1.8 * RATE)
    t = t_axis(1.8)
    steel = (np.sin(2 * np.pi * 880 * t) + 0.7 * np.sin(2 * np.pi * 1760 * t * 1.01) + 0.5 * np.sin(2 * np.pi * 3320 * t)) * decay(n, 9)
    return norm(reverb(steel * 0.6 + highpass(noise(1.8), 3000) * decay(n, 50) + sweep(1.8, 140, 36) * decay(n, 6) * 0.9, 1.0, 0.3))


def death_Knight():
    n = int(3.6 * RATE)
    t = t_axis(3.6)
    return norm(reverb((np.sin(2 * np.pi * 440 * t) + 0.6 * np.sin(2 * np.pi * 988 * t)) * decay(n, 2.2) * 0.5 + band(noise(3.6), 500, 2500) * decay(n, 2.5) * 0.4 + sweep(3.6, 100, 30) * decay(n, 2.0), 2.4, 0.5))


SOUNDS = {
    "cast_Fire": cast_fire, "cast_Storm": cast_storm, "cast_Frost": cast_frost, "cast_Void": cast_void,
    "hit_Fire": hit_fire, "hit_Storm": hit_storm, "hit_Frost": hit_frost, "hit_Void": hit_void,
    "wisp_spawn": wisp_spawn, "wisp_blast": wisp_blast, "wisp_down": wisp_down, "impact": impact,
}
for _kind in ("Warden", "Choir", "Regent", "Seraph", "Rime", "Knight"):
    for _beat in ("roar", "charge", "boom", "death"):
        SOUNDS[f"{_beat}_{_kind}"] = globals()[f"{_beat}_{_kind}"]
# Astraeon, the mega boss, shares the Regent's furnace sounds until it gets its own.
for _beat in ("roar", "charge", "boom", "death"):
    SOUNDS[f"{_beat}_Astraeon"] = globals()[f"{_beat}_Regent"]

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
