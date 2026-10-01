"""Compose one original fight soundtrack per boss (no samples, no licences: all synthesis).

    python tools/assetgen/boss_music_gen.py            # every boss
    python tools/assetgen/boss_music_gen.py --only Knight

Each track is about a minute of music in its own key, tempo and instrumentation, laid out in eight-bar
sections (intro -> build -> full -> climax) so the fight feels like it builds, and rendered to loop
seamlessly (the reverb tail is folded back onto the start). Writes assets/generated/bossmusic/<Kind>.wav
plus music_names.json; upload with tools/assetgen/upload_boss_music.py.
"""

from __future__ import annotations

import argparse
import json
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "bossmusic")
RATE = 32000
rng = np.random.default_rng(7)


# ---------------------------------------------------------------------------------- DSP helpers
def tt(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, cutoff, order=4):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum *= 1 / (1 + (freqs / max(cutoff, 20.0)) ** order)
    return np.fft.irfft(spectrum, len(x))


def highpass(x, cutoff):
    return x - lowpass(x, cutoff, 2)


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def env(n, attack, release, sustain=1.0):
    e = np.ones(n) * sustain
    a = max(1, min(n // 2, int(attack * RATE)))
    r = max(1, min(n // 2, int(release * RATE)))
    e[:a] = np.linspace(0, sustain, a)
    e[-r:] = np.minimum(e[-r:], np.linspace(sustain, 0, r))
    return e


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def saw(freq, seconds, detune=0.0):
    t = tt(seconds)
    f = freq * (1 + detune)
    return 2 * ((t * f) % 1.0) - 1


def reverb(x, seconds=1.8, wet=0.25):
    n = int(seconds * RATE)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 6.5, n))
    ir = lowpass(ir, 5500, 2)
    size = len(x) + n
    wetsig = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    wetsig /= max(1e-6, np.abs(wetsig).max())
    wetsig *= np.abs(x).max()
    out = np.zeros(size)
    out[: len(x)] += x * (1 - wet)
    out += wetsig * wet
    return out


# ---------------------------------------------------------------------------------- instruments
def pluck(freq, seconds=1.2, bright=3.0):
    t = tt(seconds)
    out = np.zeros_like(t)
    for h in range(1, 14):
        if freq * h > 9000:
            break
        out += np.sin(2 * np.pi * freq * h * t + h) / h * np.exp(-t * (1.5 + h * bright * 0.5))
    return out * env(len(t), 0.003, 0.05)


def bell(freq, seconds=2.4, index=2.5):
    t = tt(seconds)
    mod = np.sin(2 * np.pi * freq * 3.51 * t) * index * np.exp(-t * 1.4)
    return np.sin(2 * np.pi * freq * t + mod) * np.exp(-t * 1.1) * env(len(t), 0.002, 0.2)


def pad(freq, seconds, cutoff=1400, voices=3):
    out = np.zeros(int(seconds * RATE))
    for v in range(voices):
        out += saw(freq, seconds, (v - voices // 2) * 0.004)
    out = lowpass(out / voices, cutoff, 2)
    return out * env(len(out), min(1.2, seconds * 0.4), min(1.6, seconds * 0.5))


def choir(freq, seconds, vowel=(700, 1100, 2600)):
    t = tt(seconds)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t + freq)
    out = np.zeros_like(t)
    for h in range(1, 28):
        f = freq * h
        if f > 6000:
            break
        gain = sum(np.exp(-((f - c) / (c * 0.28)) ** 2) * w for c, w in zip(vowel, (1.0, 0.6, 0.25)))
        out += np.sin(2 * np.pi * f * vib * t + rng.random() * 6) * gain / h**0.4
    return out * env(len(t), min(0.9, seconds * 0.4), min(1.1, seconds * 0.5))


def bass(freq, seconds=0.5, cutoff=420, drive=1.0):
    out = lowpass(saw(freq, seconds) + 0.5 * saw(freq * 0.5, seconds), cutoff, 2)
    out = np.tanh(out * drive * 1.5)
    return out * env(len(out), 0.005, min(0.12, seconds * 0.4))


def brass(freq, seconds=0.5, push=1.0):
    t = tt(seconds)
    out = saw(freq, seconds) + saw(freq, seconds, 0.006)
    sweep = lowpass(out, 500 + 3200 * push, 2)
    return np.tanh(sweep * 1.2) * env(len(t), 0.04, min(0.2, seconds * 0.5))


def kick(seconds=0.4, deep=1.0):
    t = tt(seconds)
    f = 130 * np.exp(-t * 18) + 42 * deep
    return np.tanh(np.sin(2 * np.pi * np.cumsum(f) / RATE) * 1.6) * np.exp(-t * 9)


def snare(seconds=0.3):
    t = tt(seconds)
    n = bandpass(rng.standard_normal(len(t)), 1500, 8000) * np.exp(-t * 18)
    return n * 0.8 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28) * 0.5


def hat(seconds=0.08):
    t = tt(seconds)
    return highpass(rng.standard_normal(len(t)), 7000) * np.exp(-t * 55) * 0.5


def taiko(seconds=1.0):
    t = tt(seconds)
    f = 85 * np.exp(-t * 3) + 48
    return (np.sin(2 * np.pi * np.cumsum(f) / RATE) + 0.3 * lowpass(rng.standard_normal(len(t)), 600, 2)) * np.exp(-t * 4.5)


def rumble(seconds, depth=0.6):
    n = rng.standard_normal(int(seconds * RATE))
    slow = 0.6 + 0.4 * np.sin(2 * np.pi * 0.17 * tt(seconds))
    return lowpass(n, 140, 4) * slow * depth


def wind(seconds, depth=0.5):
    n = rng.standard_normal(int(seconds * RATE))
    sweep = lowpass(n, 900, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * tt(seconds)))
    return highpass(sweep, 150) * depth


def drone(freq, seconds, depth=1.0):
    t = tt(seconds)
    out = np.zeros_like(t)
    for h, g in ((1, 1.0), (2, 0.6), (3, 0.35), (5, 0.18)):
        out += np.sin(2 * np.pi * freq * h * t * (1 + 0.0015 * np.sin(0.3 * t * h))) * g
    return out * (0.7 + 0.3 * np.sin(2 * np.pi * 0.09 * t)) * depth * env(len(t), 2.0, 2.0)


# ---------------------------------------------------------------------------------- the composer
class Song:
    def __init__(self, bpm, bars, root, chords, scale):
        self.bpm, self.bars, self.root, self.chords, self.scale = bpm, bars, root, chords, scale
        self.beat = 60.0 / bpm
        self.bar = self.beat * 4
        self.length = self.bar * bars
        self.mix = np.zeros(int((self.length + 4.0) * RATE))

    def put(self, sound, at, gain=1.0):
        i = int(at * RATE)
        if i >= len(self.mix):
            return
        n = min(len(sound), len(self.mix) - i)
        self.mix[i : i + n] += sound[:n] * gain

    def chord_at(self, bar):
        degrees = self.chords[(bar // 2) % len(self.chords)]
        return [self.root + d for d in degrees]

    def finish(self):
        loopable = reverb(self.mix, 2.2, 0.28)
        head = int(self.length * RATE)
        tail = loopable[head:]
        loopable = loopable[:head]
        loopable[: min(len(tail), len(loopable))] += tail[: len(loopable)]                    # fold the reverb tail onto the start: seamless loop
        loopable = np.tanh(loopable * 0.9)
        peak = np.abs(loopable).max()
        return loopable / max(peak, 1e-6) * 0.92


def section(bar):
    """0 intro, 1 build, 2 full, 3 climax (eight bars each, repeating)."""
    return (bar // 8) % 4


def compose(kind: str) -> np.ndarray:
    return COMPOSERS[kind]()


# Each composer lays its own instruments and patterns on a Song.
def warden():
    s = Song(66, 32, 38, [[0, 7, 12, 15], [-2, 5, 10, 14], [-4, 3, 8, 12], [-5, 2, 7, 10]], "minor")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        s.put(drone(hz(chord[0] - 12), s.bar, 0.5), t0, 0.5)
        if sec >= 1 and bar % 2 == 0:
            for n in chord[1:]:
                s.put(pad(hz(n), s.bar * 2, 900), t0, 0.28)
        if bar % 4 == 0:
            s.put(bell(hz(chord[0] + 24), 4.0, 3.0), t0, 0.35)
        if sec >= 1:
            for step in (0, 2):
                s.put(taiko(1.2), t0 + step * s.beat, 0.5 if step == 0 else 0.3)
        if sec >= 2:
            for step in range(8):
                s.put(hat(), t0 + step * s.beat / 2, 0.16)
            for step in (1, 3):
                s.put(snare(), t0 + step * s.beat, 0.3)
        if sec == 3:
            for k, n in enumerate(chord):
                s.put(choir(hz(n + 12), s.bar, (500, 900, 2400)), t0 + k * s.beat * 0.25, 0.22)
        s.put(rumble(s.bar, 0.5), t0, 0.6)
    return s.finish()


def choir_boss():
    s = Song(84, 32, 55, [[0, 4, 7, 11], [2, 6, 9, 14], [-3, 0, 4, 9], [-1, 2, 7, 11]], "lydian")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        for n in chord:
            s.put(choir(hz(n), s.bar, (650, 1080, 2700)), t0, 0.22)
        if sec >= 1:
            for k in range(8):
                s.put(bell(hz(chord[k % 4] + 24), 1.6, 2.0), t0 + k * s.beat / 2, 0.22)
        if sec >= 2:
            for k, n in enumerate(chord):
                s.put(pluck(hz(n - 12), 1.0), t0 + k * s.beat, 0.4)
            s.put(kick(0.4, 0.8), t0, 0.45)
            s.put(kick(0.4, 0.8), t0 + 2 * s.beat, 0.35)
        if sec == 3:
            for k in range(4):
                s.put(snare(), t0 + k * s.beat + s.beat * 0.5, 0.18)
            s.put(choir(hz(chord[0] + 24), s.bar * 2, (800, 1250, 2800)), t0, 0.2)
    return s.finish()


def regent():
    s = Song(100, 32, 33, [[0, 7, 12, 15], [-4, 3, 8, 12], [-2, 5, 10, 14], [-5, 2, 7, 10]], "phrygian")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        for step in range(8):
            s.put(bass(hz(chord[0]), s.beat / 2, 380, 1.4 + 0.3 * sec), t0 + step * s.beat / 2, 0.55)
        for step in (0, 2):
            s.put(kick(0.45, 1.0), t0 + step * s.beat, 0.7)
        s.put(snare(), t0 + s.beat, 0.55)
        s.put(snare(), t0 + 3 * s.beat, 0.55)
        if sec >= 1:
            for step in (0, 1.5, 2, 3.5):
                s.put(taiko(0.9), t0 + step * s.beat, 0.4)
            for n in chord[1:3]:
                s.put(brass(hz(n + 12), s.beat * 1.4, 0.6 + 0.2 * sec), t0, 0.28)
        if sec >= 2:
            for step in range(16):
                s.put(hat(), t0 + step * s.beat / 4, 0.14)
            for n in chord:
                s.put(brass(hz(n + 12), s.beat * 0.7, 1.0), t0 + 2 * s.beat, 0.22)
        if sec == 3:
            s.put(rumble(s.bar, 0.8), t0, 0.5)
            s.put(taiko(1.4), t0 + 3.5 * s.beat, 0.5)
    return s.finish()


def seraph():
    s = Song(138, 32, 57, [[0, 3, 7, 12], [-4, -1, 3, 8], [-2, 1, 5, 10], [-7, -4, 0, 5]], "minor")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        for n in chord:
            s.put(pad(hz(n), s.bar, 3200, 4), t0, 0.2)
        for step in range(16):
            n = chord[(step * 3) % 4] + 12 * (1 + (step // 4) % 2)
            s.put(pluck(hz(n), 0.5, 2.0), t0 + step * s.beat / 4, 0.28 if sec >= 1 else 0.14)
        s.put(kick(0.35, 0.9), t0, 0.5)
        if sec >= 1:
            s.put(kick(0.35, 0.9), t0 + 2 * s.beat, 0.4)
            for step in range(8):
                s.put(hat(), t0 + step * s.beat / 2, 0.18)
        if sec >= 2:
            s.put(snare(), t0 + s.beat, 0.4)
            s.put(snare(), t0 + 3 * s.beat, 0.4)
            s.put(bass(hz(chord[0] - 12), s.bar, 600, 1.2), t0, 0.4)
        if bar % 4 == 1 and sec >= 1:
            s.put(lowpass(rng.standard_normal(int(s.bar * RATE)), 700, 2) * env(int(s.bar * RATE), 0.01, 1.4), t0, 0.6)
        s.put(wind(s.bar, 0.4), t0, 0.5)
    return s.finish()


def rime():
    s = Song(60, 32, 62, [[0, 7, 12, 19], [-3, 4, 9, 16], [-5, 2, 7, 14], [-7, 0, 5, 12]], "aeolian")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        s.put(wind(s.bar, 0.6), t0, 0.7)
        s.put(drone(hz(chord[0] - 24), s.bar, 0.4), t0, 0.5)
        for k, n in enumerate(chord):
            if (bar + k) % 2 == 0 or sec >= 2:
                s.put(bell(hz(n + 12), 3.2, 3.2), t0 + k * s.beat * 1.0, 0.3)
        if sec >= 1:
            s.put(pad(hz(chord[1]), s.bar * 2, 1800), t0, 0.22) if bar % 2 == 0 else None
            s.put(taiko(1.6), t0, 0.35)
        if sec >= 2:
            for step in (1, 3):
                s.put(bell(hz(chord[step % 4] + 24), 1.4, 2.6), t0 + step * s.beat + s.beat * 0.5, 0.2)
            s.put(bass(hz(chord[0] - 12), s.bar, 300, 1.0), t0, 0.35)
        if sec == 3:
            s.put(taiko(1.6), t0 + 2 * s.beat, 0.4)
            s.put(choir(hz(chord[2]), s.bar * 2, (480, 900, 2300)), t0, 0.18) if bar % 2 == 0 else None
    return s.finish()


def knight():
    s = Song(116, 32, 50, [[0, 3, 7, 11], [5, 8, 12, 15], [7, 11, 14, 17], [0, 3, 7, 12]], "harmonic")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        for step in (0, 1.5, 2, 3.5):
            s.put(pluck(hz(chord[0] - 24), 0.5, 2.5), t0 + step * s.beat, 0.55)
        s.put(snare(0.2), t0 + 0.5 * s.beat, 0.12)
        if sec >= 1:
            for k in range(8):
                n = chord[(k * 2) % 4] + 12 * (k % 2)
                s.put(pluck(hz(n + 12), 0.4, 3.0), t0 + k * s.beat / 2, 0.3)
            for step in (1, 3):
                s.put(snare(0.25), t0 + step * s.beat, 0.35)
        if sec >= 2:
            for n in chord:
                s.put(brass(hz(n), s.beat * 0.5, 0.7), t0, 0.16)
            for step in range(16):
                s.put(hat(0.05), t0 + step * s.beat / 4, 0.1)
            s.put(kick(0.35, 0.9), t0, 0.4)
        if sec == 3:
            for k in range(4):
                s.put(snare(0.15), t0 + 3 * s.beat + k * s.beat / 4, 0.3)
            s.put(pad(hz(chord[0] + 12), s.bar, 2400), t0, 0.2)
    return s.finish()


def astraeon():
    s = Song(88, 32, 45, [[0, 7, 12, 16], [-3, 4, 9, 12], [-5, 2, 7, 11], [-7, 0, 5, 9]], "major")
    for bar in range(s.bars):
        t0, sec, chord = bar * s.bar, section(bar), s.chord_at(bar)
        for n in chord:
            s.put(pad(hz(n), s.bar, 1600 + 400 * sec, 4), t0, 0.22 + 0.04 * sec)
        s.put(drone(hz(chord[0] - 24), s.bar, 0.5), t0, 0.5)
        if sec >= 1:
            s.put(taiko(1.4), t0, 0.5)
            for k, n in enumerate(chord):
                s.put(choir(hz(n + 12), s.beat * 2, (700, 1100, 2600)), t0 + k * s.beat, 0.2)
        if sec >= 2:
            for step in (0, 2):
                s.put(kick(0.45, 1.2), t0 + step * s.beat, 0.55)
            for step in (1, 3):
                s.put(snare(), t0 + step * s.beat, 0.4)
            for k in range(8):
                s.put(bell(hz(chord[k % 4] + 24), 1.8, 2.2), t0 + k * s.beat / 2, 0.2)
            for n in chord[:3]:
                s.put(brass(hz(n + 12), s.beat * 1.6, 0.9), t0, 0.2)
        if sec == 3:
            s.put(choir(hz(chord[3] + 24), s.bar, (800, 1300, 2900)), t0, 0.25)
            s.put(rumble(s.bar, 0.8), t0, 0.5)
            for k in range(16):
                s.put(hat(), t0 + k * s.beat / 4, 0.12)
    return s.finish()


COMPOSERS = {"Warden": warden, "Choir": choir_boss, "Regent": regent, "Seraph": seraph, "Rime": rime, "Knight": knight, "Astraeon": astraeon}


def write(name: str, data: np.ndarray) -> None:
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only")
    args = parser.parse_args()
    names = []
    for kind in COMPOSERS:
        if args.only and args.only != kind:
            continue
        data = compose(kind)
        write(f"music_{kind}", data / max(1e-6, np.abs(data).max()) * 0.92)
        names.append(f"music_{kind}")
        print(f"{kind}: {len(data) / RATE:.1f}s")
    path = os.path.join(OUT, "music_names.json")
    existing = []
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as handle:
            existing = json.load(handle)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(sorted(set(existing) | set(names)), handle, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
