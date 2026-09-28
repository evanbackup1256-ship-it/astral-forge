"""Small, dependency-free DSP toolkit for Astral Forge's sound design.

Everything is mono float lists at 44.1 kHz. The pieces are deliberately
simple -- sine/FM/additive voices, filtered noise, envelopes, a Freeverb-style
room -- because the goal is clean, consistent game sound, not a DAW.

Used by sfx.py (one-shot effects) and ambience.py (seamless loops).
"""

from __future__ import annotations

import math
import random
import struct
import wave

SR = 44100
TAU = math.tau

Buf = list  # list[float]


def frames(seconds: float) -> int:
    return max(0, int(round(seconds * SR)))


def zeros(seconds: float) -> Buf:
    return [0.0] * frames(seconds)


def mix(dst: Buf, src: Buf, at: float = 0.0, gain: float = 1.0) -> Buf:
    """Add src into dst starting at `at` seconds, growing dst as needed."""
    offset = frames(at)
    need = offset + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, value in enumerate(src):
        dst[offset + i] += value * gain
    return dst


def scale(buf: Buf, gain: float) -> Buf:
    return [v * gain for v in buf]


def fade(buf: Buf, fade_in: float = 0.002, fade_out: float = 0.01) -> Buf:
    """Short linear fades so a sound never starts or stops with a click."""
    n = len(buf)
    a = min(n, frames(fade_in))
    b = min(n, frames(fade_out))
    for i in range(a):
        buf[i] *= i / max(1, a)
    for i in range(b):
        buf[n - 1 - i] *= i / max(1, b)
    return buf


def peak(buf: Buf) -> float:
    return max((abs(v) for v in buf), default=0.0)


def normalize(buf: Buf, target_db: float = -3.0) -> Buf:
    p = peak(buf)
    if p <= 1e-9:
        return buf
    gain = (10 ** (target_db / 20)) / p
    return [v * gain for v in buf]


def trim_tail(buf: Buf, floor_db: float = -62.0, keep: float = 0.02) -> Buf:
    """Drop the silent end of a sound (below floor_db), keeping a short pad."""
    threshold = 10 ** (floor_db / 20) * max(peak(buf), 1e-9)
    end = len(buf)
    while end > 0 and abs(buf[end - 1]) < threshold:
        end -= 1
    end = min(len(buf), end + frames(keep))
    return fade(buf[:end], 0.0, 0.015)


def softclip(buf: Buf, drive: float = 1.0) -> Buf:
    if drive <= 0:
        return buf
    norm = math.tanh(drive)
    return [math.tanh(v * drive) / norm for v in buf]


# ---------------------------------------------------------------------------
# Envelopes
# ---------------------------------------------------------------------------

def env_exp(seconds: float, decay: float, attack: float = 0.002) -> Buf:
    """Fast attack, exponential decay (decay = time to fall to 1/e)."""
    n = frames(seconds)
    a = max(1, frames(attack))
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        rise = min(1.0, i / a)
        out[i] = rise * math.exp(-t / max(decay, 1e-4))
    return out


def env_adsr(seconds: float, attack: float, decay: float, sustain: float, release: float) -> Buf:
    n = frames(seconds)
    out = [0.0] * n
    rel_start = max(0.0, seconds - release)
    for i in range(n):
        t = i / SR
        if t < attack:
            v = t / max(attack, 1e-5)
        elif t < attack + decay:
            k = (t - attack) / max(decay, 1e-5)
            v = 1.0 + (sustain - 1.0) * k
        else:
            v = sustain
        if t > rel_start:
            v *= max(0.0, 1.0 - (t - rel_start) / max(release, 1e-5))
        out[i] = v
    return out


def env_swell(seconds: float, peak_at: float = 0.6, curve: float = 2.0) -> Buf:
    """Rises to a peak at `peak_at` (fraction), then falls: a swell."""
    n = frames(seconds)
    out = [0.0] * n
    for i in range(n):
        x = i / max(1, n - 1)
        if x < peak_at:
            v = (x / peak_at) ** curve
        else:
            v = (1 - (x - peak_at) / (1 - peak_at)) ** (curve * 0.7)
        out[i] = v
    return out


def apply_env(buf: Buf, env: Buf) -> Buf:
    n = min(len(buf), len(env))
    return [buf[i] * env[i] for i in range(n)]


# ---------------------------------------------------------------------------
# Oscillators
# ---------------------------------------------------------------------------

def sine(freq: float, seconds: float, amp: float = 1.0, phase: float = 0.0) -> Buf:
    n = frames(seconds)
    w = TAU * freq / SR
    return [amp * math.sin(phase + w * i) for i in range(n)]


def glide(f0: float, f1: float, seconds: float, amp: float = 1.0, curve: str = "exp", wave_shape: str = "sine") -> Buf:
    """A tone whose pitch moves from f0 to f1 (exponential by default)."""
    n = frames(seconds)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        x = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** x if curve == "exp" else f0 + (f1 - f0) * x
        phase += TAU * f / SR
        if wave_shape == "sine":
            out[i] = amp * math.sin(phase)
        elif wave_shape == "tri":
            p = (phase / TAU) % 1.0
            out[i] = amp * (4 * abs(p - 0.5) - 1)
        else:  # soft saw: a few harmonics only, so nothing aliases
            out[i] = amp * sum(math.sin(phase * k) / k for k in range(1, 6)) * 0.6
    return out


def fm(carrier: float, ratio: float, index: float, seconds: float, index_decay: float = 0.3, amp: float = 1.0) -> Buf:
    """Two-operator FM: bright at the attack, mellowing as the index decays."""
    n = frames(seconds)
    wc = TAU * carrier / SR
    wm = TAU * carrier * ratio / SR
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        idx = index * math.exp(-t / max(index_decay, 1e-4))
        out[i] = amp * math.sin(wc * i + idx * math.sin(wm * i))
    return out


def additive(freq: float, partials: list, seconds: float, amp: float = 1.0) -> Buf:
    """Inharmonic additive voice. partials: (ratio, amplitude, decay)."""
    n = frames(seconds)
    out = [0.0] * n
    for ratio, level, decay in partials:
        w = TAU * freq * ratio / SR
        if freq * ratio >= SR * 0.45:
            continue
        for i in range(n):
            out[i] += level * math.sin(w * i) * math.exp(-(i / SR) / decay)
    return [v * amp for v in out]


GLASS = [(1.0, 1.0, 0.9), (2.76, 0.42, 0.45), (5.40, 0.22, 0.22), (8.93, 0.10, 0.12)]
BELL = [(1.0, 1.0, 1.4), (2.0, 0.55, 0.9), (2.4, 0.35, 0.7), (3.0, 0.3, 0.5), (4.16, 0.22, 0.35), (5.43, 0.12, 0.25)]
METAL = [(1.0, 1.0, 0.6), (1.59, 0.7, 0.45), (2.14, 0.55, 0.35), (2.65, 0.4, 0.3), (3.51, 0.3, 0.2), (4.87, 0.2, 0.14)]
COIN = [(1.0, 1.0, 0.35), (2.49, 0.6, 0.28), (4.18, 0.35, 0.18), (6.03, 0.18, 0.12)]


def bell(freq: float, seconds: float, amp: float = 1.0, kind=BELL, brightness: float = 1.0) -> Buf:
    partials = [(r, a * (brightness if i else 1.0), d) for i, (r, a, d) in enumerate(kind)]
    buf = additive(freq, partials, seconds, amp)
    # A short mallet transient on top of the partials.
    return mix(buf, apply_env(noise(0.006, 0.3), env_exp(0.006, 0.002)), 0.0, 0.25 * brightness)


# ---------------------------------------------------------------------------
# Noise and filters
# ---------------------------------------------------------------------------

_rng = random.Random(1337)


def seed(value: int) -> None:
    _rng.seed(value)


def noise(seconds: float, amp: float = 1.0) -> Buf:
    return [amp * (_rng.random() * 2 - 1) for _ in range(frames(seconds))]


def lowpass(buf: Buf, cutoff: float) -> Buf:
    a = 1 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for v in buf:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(buf: Buf, cutoff: float) -> Buf:
    low = lowpass(buf, cutoff)
    return [v - l for v, l in zip(buf, low)]


def svf(buf: Buf, cutoff, q: float = 0.7, mode: str = "band") -> Buf:
    """State-variable filter. `cutoff` is a number or a function of 0..1 progress."""
    n = len(buf)
    low = band = 0.0
    damp = 1.0 / max(q, 0.05)
    out = [0.0] * n
    for i, v in enumerate(buf):
        fc = cutoff(i / max(1, n - 1)) if callable(cutoff) else cutoff
        fc = min(fc, SR * 0.2)
        f = 2 * math.sin(math.pi * fc / SR)
        low += f * band
        high = v - low - damp * band
        band += f * high
        out[i] = band if mode == "band" else (low if mode == "low" else high)
    return out


def sweep(f0: float, f1: float):
    """An exponential cutoff sweep for svf()."""
    return lambda x: f0 * (f1 / f0) ** x


# ---------------------------------------------------------------------------
# Space
# ---------------------------------------------------------------------------

class _Comb:
    def __init__(self, size: int, feedback: float, damp: float):
        self.buf = [0.0] * size
        self.i = 0
        self.feedback = feedback
        self.damp = damp
        self.store = 0.0

    def tick(self, x: float) -> float:
        y = self.buf[self.i]
        self.store = y * (1 - self.damp) + self.store * self.damp
        self.buf[self.i] = x + self.store * self.feedback
        self.i = (self.i + 1) % len(self.buf)
        return y


class _Allpass:
    def __init__(self, size: int):
        self.buf = [0.0] * size
        self.i = 0

    def tick(self, x: float) -> float:
        b = self.buf[self.i]
        y = -x + b
        self.buf[self.i] = x + b * 0.5
        self.i = (self.i + 1) % len(self.buf)
        return y


def reverb(buf: Buf, room: float = 0.7, damp: float = 0.4, wet: float = 0.3, tail: float = 1.2, predelay: float = 0.012) -> Buf:
    """A Freeverb-style room: six damped combs into three allpasses."""
    combs = [_Comb(int(s * SR / 44100), 0.7 + 0.28 * room, damp) for s in (1116, 1188, 1277, 1356, 1422, 1491)]
    passes = [_Allpass(int(s * SR / 44100)) for s in (556, 441, 341)]
    pre = frames(predelay)
    src = [0.0] * pre + buf + [0.0] * frames(tail)
    out = [0.0] * len(src)
    for i, x in enumerate(src):
        x *= 0.015
        acc = 0.0
        for c in combs:
            acc += c.tick(x)
        for p in passes:
            acc = p.tick(acc)
        out[i] = acc
    dry = buf + [0.0] * (len(out) - len(buf))
    return [d * (1 - wet * 0.5) + w * wet for d, w in zip(dry, out)]


def delay(buf: Buf, seconds: float, feedback: float = 0.35, wet: float = 0.3, repeats_tail: float = 1.0) -> Buf:
    d = frames(seconds)
    out = buf + [0.0] * frames(repeats_tail)
    line = [0.0] * max(1, d)
    j = 0
    for i in range(len(out)):
        echoed = line[j]
        line[j] = out[i] + echoed * feedback
        out[i] += echoed * wet
        j = (j + 1) % len(line)
    return out


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def write_wav(path: str, buf: Buf) -> None:
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        data = bytearray()
        for v in buf:
            data += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767))
        w.writeframes(bytes(data))


def note(name: str) -> float:
    """'D5' -> Hz. Sharps as '#'."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    letter = name[:-1]
    octave = int(name[-1])
    return 440.0 * 2 ** ((names[letter] + (octave - 4) * 12) / 12)
