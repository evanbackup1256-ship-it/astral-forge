"""Original Astral Forge soundtrack.

Four stereo tracks composed for an incremental forge game -- driving enough to
feel like progress, restrained enough to sit under UI for hours:

  ForgePulse      118 BPM  D minor   foundry groove: kick, offbeat hats, saw bass,
                                     pad chords, plucked arp, anvil accents, lead
  SanctuaryDrift   76 BPM  E minor   the walkable hub: heartbeat pulse, wide pads,
                                     glass bells, no hard drums
  AstralOrbit      96 BPM  A minor   between peaks: light beat, warm arps, melody
  BossSurge       150 BPM  F# minor  the Warden: pounding 16th bass, snare, stabs,
                                     risers

Every track is built from a real chord progression with a bass line, sections
that add and drop layers, sidechain pumping from the kick, ping-pong delay and a
shared stereo reverb. All synthesis is numpy; nothing is sampled.

Run:  python tools/assetgen/soundtrack_gen.py
Writes assets/generated/soundtrack/*.wav (44.1 kHz stereo 16-bit).
"""

from __future__ import annotations

import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "soundtrack")

RNG = np.random.default_rng(51)

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name: str) -> int:
    """'F#3' -> 54."""
    pitch = name[:-1]
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# --------------------------------------------------------------------------
# DSP building blocks
# --------------------------------------------------------------------------

def tvec(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def env_ad(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-t / max(decay, 1e-4))


def env_pad(n: int, attack: float, release: float) -> np.ndarray:
    t = np.arange(n) / SR
    total = n / SR
    up = np.minimum(1.0, t / max(attack, 1e-4)) ** 1.5
    down = np.minimum(1.0, (total - t) / max(release, 1e-4)) ** 1.5
    return up * np.clip(down, 0.0, 1.0)


def fft_filter(x: np.ndarray, low: float | None = None, high: float | None = None, order: int = 2) -> np.ndarray:
    """Zero-phase Butterworth-shaped filter. `high` = low-pass cutoff, `low` = high-pass cutoff."""
    n = len(x)
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    gain = np.ones_like(freqs)
    if high is not None:
        gain *= 1.0 / np.sqrt(1.0 + (freqs / high) ** (2 * order))
    if low is not None:
        ratio = np.where(freqs > 0, low / np.maximum(freqs, 1e-6), 1e6)
        gain *= 1.0 / np.sqrt(1.0 + ratio ** (2 * order))
    return np.fft.irfft(spectrum * gain, n)


_harm_cache: dict = {}


def saw(freq: float, n: int, cutoff: float = 4000.0, phase: float = 0.0) -> np.ndarray:
    """Band-limited saw: additive harmonics up to `cutoff` (no aliasing)."""
    count = int(max(1, min(60, cutoff / freq, (SR / 2 - 200) / freq)))
    t = np.arange(n) / SR
    k = np.arange(1, count + 1)
    out = np.zeros(n)
    # chunked to keep memory small for long pads
    for start in range(0, n, 65536):
        tt = t[start:start + 65536, None]
        out[start:start + 65536] = (np.sin(2 * np.pi * freq * tt * k[None, :] + phase) / k[None, :]).sum(axis=1)
    return out * (2.0 / np.pi)


def square(freq: float, n: int, cutoff: float = 3000.0) -> np.ndarray:
    count = int(max(1, min(40, cutoff / freq)))
    t = np.arange(n)[:, None] / SR
    k = np.arange(1, 2 * count, 2)[None, :]
    return (np.sin(2 * np.pi * freq * t * k) / k).sum(axis=1) * (4.0 / np.pi)


def sine(freq: float, n: int) -> np.ndarray:
    return np.sin(2 * np.pi * freq * np.arange(n) / SR)


def noise(n: int) -> np.ndarray:
    return RNG.standard_normal(n)


def pan(mono: np.ndarray, position: float):
    """position -1..1, equal power."""
    angle = (position + 1) * np.pi / 4
    return mono * np.cos(angle), mono * np.sin(angle)


class Mix:
    """Stereo buses: dry, reverb send, delay send."""

    def __init__(self, seconds: float):
        self.n = int(seconds * SR)
        self.dry = np.zeros((2, self.n))
        self.verb = np.zeros((2, self.n))
        self.echo = np.zeros((2, self.n))

    def add(self, bus: str, mono: np.ndarray, at: float, gain: float = 1.0, position: float = 0.0):
        start = int(at * SR)
        if start >= self.n or start < 0:
            return
        end = min(self.n, start + len(mono))
        chunk = mono[: end - start] * gain
        left, right = pan(chunk, position)
        target = getattr(self, bus)
        target[0, start:end] += left
        target[1, start:end] += right

    def add_stereo(self, bus: str, left: np.ndarray, right: np.ndarray, at: float, gain: float = 1.0):
        start = int(at * SR)
        if start >= self.n or start < 0:
            return
        end = min(self.n, start + len(left))
        target = getattr(self, bus)
        target[0, start:end] += left[: end - start] * gain
        target[1, start:end] += right[: end - start] * gain


def make_reverb_ir(seconds: float, damp: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.zeros((2, n))
    for ch in range(2):
        x = rng.standard_normal(n) * np.exp(-t / (seconds / 4.6))
        # tilt darker over time
        x = fft_filter(x, high=damp)
        ir[ch] = x
    ir[:, : int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    return ir / np.sqrt((ir ** 2).sum(axis=1, keepdims=True))


def convolve(sig: np.ndarray, ir: np.ndarray) -> np.ndarray:
    size = 1
    while size < len(sig) + len(ir):
        size *= 2
    return np.fft.irfft(np.fft.rfft(sig, size) * np.fft.rfft(ir, size), size)[: len(sig)]


def pingpong(bus: np.ndarray, beat_seconds: float, feedback: float, fraction: float = 0.75) -> np.ndarray:
    step = int(beat_seconds * fraction * SR)
    out = np.zeros_like(bus)
    mono = bus.sum(axis=0) * 0.5
    tap = mono.copy()
    gain = 1.0
    for i in range(1, 7):
        gain *= feedback
        shifted = np.zeros_like(mono)
        if i * step < len(mono):
            shifted[i * step:] = tap[: len(mono) - i * step] * gain
        out[i % 2] += shifted
    return out


def sidechain(kick_times, n: int, depth: float, tau: float) -> np.ndarray:
    duck = np.ones(n)
    length = int(tau * 5 * SR)
    x = np.arange(length) / SR
    curve = 1.0 - depth * np.exp(-x / tau)
    for t in kick_times:
        start = int(t * SR)
        if start >= n:
            continue
        end = min(n, start + length)
        duck[start:end] = np.minimum(duck[start:end], curve[: end - start])
    return duck


def moving_average(x: np.ndarray, window: int) -> np.ndarray:
    """Centered box average in O(n) (np.convolve would be O(n*window))."""
    half = window // 2
    padded = np.concatenate([np.full(half, x[0]), x, np.full(window - half, x[-1])])
    csum = np.concatenate([[0.0], np.cumsum(padded)])
    return (csum[window:window + len(x)] - csum[:len(x)]) / window


def softclip(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


# --------------------------------------------------------------------------
# Instruments (all return mono arrays)
# --------------------------------------------------------------------------

def kick(power: float = 1.0, length: float = 0.42) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    freq = 46 + 130 * np.exp(-t / 0.028)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t / 0.20)
    click = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.004) * 0.25
    return softclip((body + click) * power * 1.25, 1.4)


def snare(length: float = 0.28, tone: float = 185.0) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * (tone + 60 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.07) * 0.6
    hiss = fft_filter(noise(n), low=1400, high=9000) * np.exp(-t / 0.085)
    return softclip(body + hiss * 0.9, 1.3)


def clap(length: float = 0.3) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    bursts = np.zeros(n)
    for d in (0.0, 0.011, 0.023):
        i = int(d * SR)
        bursts[i:] += np.exp(-(t[: n - i]) / 0.012)
    tail = np.exp(-t / 0.11) * 0.55
    return fft_filter(noise(n), low=900, high=6500) * (bursts * 0.55 + tail) * 0.8


def hat(open_: bool = False) -> np.ndarray:
    length = 0.24 if open_ else 0.06
    n = int(length * SR)
    t = np.arange(n) / SR
    return fft_filter(noise(n), low=7500) * np.exp(-t / (0.09 if open_ else 0.016)) * 0.55


def shaker() -> np.ndarray:
    n = int(0.11 * SR)
    t = np.arange(n) / SR
    return fft_filter(noise(n), low=5000, high=11000) * env_ad(n, 0.02, 0.035) * 0.5


def anvil(freq: float = 1180.0) -> np.ndarray:
    """Struck metal: inharmonic partials plus a noisy transient."""
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, decay in ((1.0, 1.0, 0.55), (2.76, 0.6, 0.35), (5.4, 0.45, 0.22), (8.93, 0.25, 0.12)):
        out += np.sin(2 * np.pi * freq * ratio * t) * amp * np.exp(-t / decay)
    out += fft_filter(noise(n), low=2500) * np.exp(-t / 0.012) * 0.7
    return out * 0.34


def bell(freq: float, length: float = 3.0, bright: float = 1.0) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, decay in ((1.0, 1.0, 1.6), (2.0, 0.5, 1.1), (2.4, 0.33 * bright, 0.8), (3.0, 0.28, 0.7), (4.16, 0.2 * bright, 0.45), (5.43, 0.12 * bright, 0.3)):
        out += np.sin(2 * np.pi * freq * ratio * t) * amp * np.exp(-t / decay)
    return out * env_ad(n, 0.003, 10) * 0.3


def pluck(freq: float, length: float = 0.35, bright: float = 1.0) -> np.ndarray:
    n = int(length * SR)
    body = saw(freq, n, cutoff=min(6000.0, 1500 + 2500 * bright))
    body += 0.6 * sine(freq * 2, n)
    return body * env_ad(n, 0.002, length * 0.32) * 0.35


def sub_bass(freq: float, length: float) -> np.ndarray:
    n = int(length * SR)
    body = sine(freq, n) * 0.85 + saw(freq, n, cutoff=520) * 0.55
    return body * env_pad(n, 0.006, min(0.09, length * 0.4))


def growl_bass(freq: float, length: float) -> np.ndarray:
    n = int(length * SR)
    body = saw(freq, n, cutoff=1500) * 0.8 + square(freq * 0.5, n, cutoff=300) * 0.5
    return softclip(body * 1.6, 1.8) * env_pad(n, 0.004, min(0.06, length * 0.4)) * 0.55


def pad_chord(notes, length: float, cutoff: float, attack: float, release: float):
    """Detuned super-saw pad for one chord; returns (left, right)."""
    n = int(length * SR)
    left = np.zeros(n)
    right = np.zeros(n)
    for m in notes:
        f = hz(m)
        for detune, side in ((-0.09, -0.9), (0.0, 0.0), (0.11, 0.9), (0.05, 0.4)):
            voice = saw(f * 2 ** (detune / 12.0), n, cutoff=cutoff, phase=float(RNG.uniform(0, 6.28)))
            l, r = pan(voice, side)
            left += l
            right += r
    envelope = env_pad(n, attack, release)
    scale = 0.06
    return left * envelope * scale, right * envelope * scale


def lead(freq: float, length: float, vibrato: float = 0.0) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    wob = 1.0 + vibrato * 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.35)
    phase = 2 * np.pi * np.cumsum(freq * wob) / SR
    body = np.zeros(n)
    for k in range(1, 12):
        body += np.sin(phase * k) / k
    return body * env_pad(n, 0.012, min(0.18, length * 0.5)) * 0.32


def stab(freqs, length: float = 0.22) -> np.ndarray:
    n = int(length * SR)
    out = np.zeros(n)
    for f in freqs:
        out += saw(f, n, cutoff=3200) + saw(f * 1.006, n, cutoff=3200)
    return softclip(out * 0.16, 1.6) * env_ad(n, 0.003, length * 0.4)


def riser(length: float, lo: float = 300.0, hi: float = 9000.0) -> np.ndarray:
    n = int(length * SR)
    x = noise(n)
    out = np.zeros(n)
    steps = 24
    seg = n // steps
    for i in range(steps):
        cut = lo * (hi / lo) ** (i / (steps - 1))
        chunk = x[i * seg:(i + 1) * seg]
        out[i * seg:(i + 1) * seg] = fft_filter(chunk, low=cut * 0.5, high=cut * 1.6)
    return out * (np.linspace(0, 1, n) ** 2) * 0.5


# --------------------------------------------------------------------------
# Arrangement helpers
# --------------------------------------------------------------------------

class Song:
    def __init__(self, bpm: float, bars: int):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.seconds = bars * 4 * self.beat
        self.mix = Mix(self.seconds + 3.5)  # tail room, trimmed at the end
        self.kicks: list[float] = []

    def at(self, bar: int, beat: float) -> float:
        return (bar * 4 + beat) * self.beat

    def sections(self, plan: dict[str, tuple[int, int]]):
        self.plan = plan

    def on(self, layer: str, bar: int) -> bool:
        start, end = self.plan.get(layer, (0, 0))
        return start <= bar < end


def progression_notes(chords, bar: int):
    return chords[bar % len(chords)]


def finish(song: Song, verb_ir, verb_amount: float, echo_amount: float, duck_depth: float, ducked_seconds=None, drive: float = 1.1, target_rms: float = -13.0) -> np.ndarray:
    mix = song.mix
    n = mix.n
    echo = pingpong(mix.echo, song.beat, 0.5)
    verb_in = mix.verb + echo * 0.6
    wet = np.stack([convolve(verb_in[0], verb_ir[0]), convolve(verb_in[1], verb_ir[1])])
    out = mix.dry + echo * echo_amount + wet * verb_amount
    # Trim to song length, folding the reverb tail back over the start so the
    # track loops without a hole.
    length = int(song.seconds * SR)
    tail = out[:, length:]
    out = out[:, :length].copy()
    fold = min(tail.shape[1], length)
    out[:, :fold] += tail[:, :fold]
    out = softclip(out, drive)
    # Glue: one slow-ish leveler so sections sit together.
    window = int(0.35 * SR)
    energy = np.sqrt(moving_average((out ** 2).mean(axis=0), window)) + 1e-5
    reference = 10 ** (target_rms / 20)
    gain = np.clip(reference / energy, 0.6, 1.6)
    gain = moving_average(gain, window)
    out = out * gain[None, :]
    rms = np.sqrt((out ** 2).mean())
    out *= reference / rms
    peak = np.abs(out).max()
    if peak > 0.89:
        out *= 0.89 / peak
    # Loop-safe edges: the crossfade covers the hand-over; this only removes clicks.
    ramp = int(0.05 * SR)
    out[:, :ramp] *= np.linspace(0, 1, ramp)
    out[:, -ramp:] *= np.linspace(1, 0, ramp)
    return out


def write_wav(path: str, stereo: np.ndarray) -> None:
    data = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(data.tobytes())


# --------------------------------------------------------------------------
# The four tracks
# --------------------------------------------------------------------------

def chord(root: str, quality: str, octave_shift: int = 0):
    base = midi(root) + 12 * octave_shift
    shapes = {"m": (0, 3, 7, 10), "M": (0, 4, 7, 11), "5": (0, 7, 12), "M7": (0, 4, 7, 11), "7": (0, 4, 7, 10)}
    return [base + i for i in shapes[quality]]


def forge_pulse() -> np.ndarray:
    song = Song(118, 32)
    m = song.mix
    song.sections({
        "kick": (2, 30), "hat": (4, 30), "clap": (8, 30), "bass": (2, 30),
        "pad": (0, 32), "arp": (6, 28), "lead": (16, 28), "anvil": (4, 30),
    })
    chords = [chord("D3", "m"), chord("A#2", "M"), chord("F3", "M"), chord("C3", "M")]
    roots = [midi("D2"), midi("A#1"), midi("F2"), midi("C2")]
    arp_shapes = [[0, 7, 12, 15, 12, 7, 15, 12], [0, 7, 12, 16, 12, 7, 16, 12]]
    lead_phrases = [
        [(0.0, "A4", 1.5), (2.0, "F4", 0.5), (2.5, "G4", 0.5), (3.0, "A4", 1.0)],
        [(0.0, "A#4", 1.0), (1.5, "A4", 0.5), (2.0, "F4", 1.5), (3.5, "D4", 0.5)],
        [(0.0, "C5", 1.5), (2.0, "A4", 0.5), (2.5, "F4", 0.5), (3.0, "A4", 1.0)],
        [(0.0, "G4", 1.0), (1.0, "A4", 1.0), (2.0, "D5", 1.5), (3.5, "C5", 0.5)],
    ]
    k = kick()
    sn_clap = clap()
    hats = hat()
    hat_open = hat(True)
    anv = [anvil(1180), anvil(1570)]
    kick_times = []
    for bar in range(song.bars):
        idx = bar % 4
        if song.on("pad", bar):
            l, r = pad_chord(chords[idx], 4 * song.beat + 0.5, 1300 if bar < 16 else 2100, 0.9, 1.2)
            m.add_stereo("dry", l, r, song.at(bar, 0), 0.9)
            m.add_stereo("verb", l, r, song.at(bar, 0), 0.5)
        for beat in range(4):
            if song.on("kick", bar):
                t = song.at(bar, beat)
                m.add("dry", k, t, 0.95)
                kick_times.append(t)
            if song.on("hat", bar):
                m.add("dry", hats, song.at(bar, beat + 0.5), 0.5 + 0.1 * (beat % 2), 0.25)
                if beat == 3:
                    m.add("dry", hat_open, song.at(bar, 3.5), 0.45, -0.25)
                for sixteenth in (0.25, 0.75):
                    if bar >= 12:
                        m.add("dry", hats, song.at(bar, beat + sixteenth), 0.22, -0.3 if beat % 2 else 0.3)
            if song.on("clap", bar) and beat in (1, 3):
                m.add("dry", sn_clap, song.at(bar, beat), 0.62)
                m.add("verb", sn_clap, song.at(bar, beat), 0.35)
        if song.on("bass", bar):
            root = roots[idx]
            pattern = [0, 0, 12, 0, 0, 7, 0, 10] if idx in (0, 2) else [0, 0, 12, 0, 0, 5, 0, 12]
            for step, semis in enumerate(pattern):
                t = song.at(bar, step * 0.5)
                length = song.beat * 0.46
                m.add("dry", growl_bass(hz(root + semis), length) if bar >= 8 else sub_bass(hz(root + semis), length), t, 0.9)
        if song.on("arp", bar):
            shape = arp_shapes[(bar // 4) % 2]
            for step, semis in enumerate(shape):
                t = song.at(bar, step * 0.5)
                f = hz(chords[idx][0] + 12 + semis)
                pl = pluck(f, 0.32, bright=0.6 + 0.4 * (bar >= 12))
                m.add("dry", pl, t, 0.55, -0.55 if step % 2 else 0.55)
                m.add("echo", pl, t, 0.5, 0.0)
        if song.on("lead", bar):
            for beat_pos, name, dur in lead_phrases[idx]:
                ld = lead(hz(midi(name)), dur * song.beat * 0.98, vibrato=1.0)
                m.add("dry", ld, song.at(bar, beat_pos), 0.55, 0.1)
                m.add("echo", ld, song.at(bar, beat_pos), 0.4, 0.0)
                m.add("verb", ld, song.at(bar, beat_pos), 0.4, 0.0)
        if song.on("anvil", bar) and bar % 2 == 1:
            m.add("dry", anv[(bar // 2) % 2], song.at(bar, 3.5), 0.5, 0.3)
            m.add("verb", anv[(bar // 2) % 2], song.at(bar, 3.5), 0.7, 0.3)
    duck = sidechain(kick_times, m.n, 0.5, 0.13)
    m.dry *= duck[None, :]
    # keep kicks/hats un-ducked would need stems; ducking the whole bus is the
    # classic pump, and the kicks are added back below.
    for t in kick_times:
        m.add("dry", k, t, 0.45)
    return finish(song, make_reverb_ir(2.4, 5200, 1), 0.34, 0.5, 0.5)


def sanctuary_drift() -> np.ndarray:
    song = Song(76, 24)
    m = song.mix
    song.sections({"pad": (0, 24), "bell": (2, 22), "sub": (0, 24), "pulse": (6, 22), "shim": (10, 24), "melody": (12, 22)})
    chords = [chord("E3", "m"), chord("C3", "M"), chord("G3", "M"), chord("D3", "M")]
    roots = [midi("E1"), midi("C2"), midi("G1"), midi("D2")]
    bell_notes = [
        ["B4", None, "G4", None, "E5", None, "D5", None],
        ["G4", None, "E4", None, "C5", None, "B4", None],
        ["D5", None, "B4", None, "G5", None, "E5", None],
        ["A4", None, "F#4", None, "D5", None, "C#5", None],
    ]
    melody = [
        [(0.0, "E5", 3.5)], [(0.0, "G5", 2.0), (2.0, "E5", 2.0)],
        [(0.0, "D5", 2.0), (2.0, "B4", 2.0)], [(0.0, "F#5", 3.5)],
    ]
    heart = kick(0.55, 0.5)
    for bar in range(song.bars):
        idx = bar % 4
        l, r = pad_chord(chords[idx] + [chords[idx][0] + 24], 4 * song.beat + 1.2, 900, 1.6, 2.4)
        m.add_stereo("dry", l, r, song.at(bar, 0), 1.0)
        m.add_stereo("verb", l, r, song.at(bar, 0), 0.7)
        sub = sub_bass(hz(roots[idx]), 4 * song.beat * 0.98)
        m.add("dry", sub * 0.9, song.at(bar, 0), 0.75)
        if song.on("pulse", bar):
            m.add("dry", heart, song.at(bar, 0), 0.4)
            m.add("dry", heart, song.at(bar, 1.75), 0.22)
        if song.on("bell", bar):
            for step, name in enumerate(bell_notes[idx]):
                if name is None:
                    continue
                b = bell(hz(midi(name)), 3.2)
                t = song.at(bar, step * 0.5)
                m.add("dry", b, t, 0.5, -0.5 if step % 4 == 0 else 0.5)
                m.add("echo", b, t, 0.5)
                m.add("verb", b, t, 0.6)
        if song.on("shim", bar) and bar % 2 == 0:
            n = int(3.0 * SR)
            air = fft_filter(noise(n), low=3000, high=9000) * env_pad(n, 1.4, 1.4) * 0.05
            m.add("dry", air, song.at(bar, 0), 0.8, -0.2 if (bar // 2) % 2 else 0.2)
        if song.on("melody", bar):
            for beat_pos, name, dur in melody[idx]:
                ld = lead(hz(midi(name)), dur * song.beat, vibrato=1.0) * 0.5
                m.add("dry", ld, song.at(bar, beat_pos), 0.4, 0.15)
                m.add("echo", ld, song.at(bar, beat_pos), 0.55)
                m.add("verb", ld, song.at(bar, beat_pos), 0.75)
    return finish(song, make_reverb_ir(4.2, 4200, 2), 0.5, 0.55, 0.0, drive=0.95, target_rms=-15.5)


def astral_orbit() -> np.ndarray:
    song = Song(96, 28)
    m = song.mix
    song.sections({
        "pad": (0, 28), "kick": (4, 26), "shaker": (4, 26), "snare": (8, 26), "bass": (4, 26),
        "arp": (2, 26), "melody": (12, 24), "pluck": (8, 26),
    })
    chords = [chord("A2", "m"), chord("F3", "M"), chord("C3", "M"), chord("G3", "M")]
    roots = [midi("A1"), midi("F1"), midi("C2"), midi("G1")]
    arp_shapes = [[0, 7, 12, 16, 19, 16, 12, 7], [0, 7, 11, 16, 19, 16, 11, 7]]
    melody = [
        [(0.0, "E5", 1.0), (1.0, "C5", 1.0), (2.0, "D5", 1.0), (3.0, "E5", 1.0)],
        [(0.0, "C5", 2.0), (2.0, "A4", 1.0), (3.0, "C5", 1.0)],
        [(0.0, "E5", 1.5), (1.5, "G5", 0.5), (2.0, "E5", 2.0)],
        [(0.0, "D5", 1.0), (1.0, "B4", 1.0), (2.0, "G4", 2.0)],
    ]
    k = kick(0.85, 0.4)
    sn = snare()
    sh = shaker()
    kick_times = []
    for bar in range(song.bars):
        idx = bar % 4
        l, r = pad_chord(chords[idx] + [chords[idx][0] + 12], 4 * song.beat + 0.7, 1500, 1.1, 1.6)
        m.add_stereo("dry", l, r, song.at(bar, 0), 0.9)
        m.add_stereo("verb", l, r, song.at(bar, 0), 0.5)
        for beat in range(4):
            t = song.at(bar, beat)
            if song.on("kick", bar) and beat in (0, 2):
                m.add("dry", k, t, 0.8)
                kick_times.append(t)
            if song.on("shaker", bar):
                m.add("dry", sh, song.at(bar, beat + 0.5), 0.6, 0.35)
                if bar >= 12:
                    m.add("dry", sh, song.at(bar, beat + 0.25), 0.25, -0.35)
            if song.on("snare", bar) and beat in (1, 3):
                m.add("dry", sn, t, 0.42)
                m.add("verb", sn, t, 0.4)
        if song.on("bass", bar):
            for step in range(8):
                semis = (0, 0, 12, 0, 7, 0, 12, 10)[step] if idx != 1 else (0, 0, 12, 0, 5, 0, 12, 7)[step]
                m.add("dry", sub_bass(hz(roots[idx] + semis), song.beat * 0.42), song.at(bar, step * 0.5), 0.85)
        if song.on("arp", bar):
            shape = arp_shapes[(bar // 8) % 2]
            for step, semis in enumerate(shape):
                pl = pluck(hz(chords[idx][0] + 12 + semis), 0.4, 0.5)
                t = song.at(bar, step * 0.5)
                m.add("dry", pl, t, 0.4, -0.6 if step % 2 else 0.6)
                m.add("echo", pl, t, 0.55)
        if song.on("melody", bar):
            for beat_pos, name, dur in melody[idx]:
                ld = lead(hz(midi(name)), dur * song.beat * 0.97, vibrato=1.0)
                t = song.at(bar, beat_pos)
                m.add("dry", ld, t, 0.5, 0.1)
                m.add("echo", ld, t, 0.45)
                m.add("verb", ld, t, 0.5)
        if song.on("pluck", bar) and bar % 2 == 0:
            for beat_pos, semis in ((1.5, 12), (3.5, 19)):
                b = bell(hz(chords[idx][0] + 24 + (semis - 12)), 2.4, 0.7)
                m.add("dry", b, song.at(bar, beat_pos), 0.4, 0.4)
                m.add("verb", b, song.at(bar, beat_pos), 0.6)
    duck = sidechain(kick_times, m.n, 0.35, 0.12)
    m.dry *= duck[None, :]
    for t in kick_times:
        m.add("dry", k, t, 0.35)
    return finish(song, make_reverb_ir(3.2, 5000, 3), 0.42, 0.5, 0.35, target_rms=-14.0)


def boss_surge() -> np.ndarray:
    song = Song(150, 40)
    m = song.mix
    song.sections({
        "kick": (2, 38), "snare": (4, 38), "hat": (2, 38), "bass": (0, 38),
        "stab": (8, 36), "pad": (0, 40), "lead": (16, 36), "riser": (0, 40),
    })
    chords = [chord("F#2", "m"), chord("D3", "M"), chord("A2", "M"), chord("E3", "M")]
    roots = [midi("F#1"), midi("D2"), midi("A1"), midi("E2")]
    stab_hits = [(0.0, 0), (0.75, 0), (1.5, 7), (2.5, 0), (3.25, 3)]
    lead_phr = [
        [(0.0, "C#5", 0.75), (0.75, "F#5", 0.75), (1.5, "E5", 0.5), (2.0, "C#5", 2.0)],
        [(0.0, "D5", 0.75), (0.75, "F#5", 0.75), (1.5, "A5", 0.5), (2.0, "F#5", 2.0)],
        [(0.0, "E5", 0.75), (0.75, "C#5", 0.75), (1.5, "A4", 0.5), (2.0, "C#5", 2.0)],
        [(0.0, "B4", 0.75), (0.75, "D#5", 0.75), (1.5, "G#5", 0.5), (2.0, "E5", 2.0)],
    ]
    k = kick(1.1, 0.34)
    sn = snare(tone=200)
    hats = hat()
    kick_times = []
    for bar in range(song.bars):
        idx = bar % 4
        if song.on("pad", bar):
            l, r = pad_chord(chords[idx], 4 * song.beat + 0.3, 1900, 0.4, 0.6)
            m.add_stereo("dry", l, r, song.at(bar, 0), 0.85)
        for beat in range(4):
            t = song.at(bar, beat)
            if song.on("kick", bar):
                m.add("dry", k, t, 1.0)
                kick_times.append(t)
                if bar >= 24 and beat == 3:
                    m.add("dry", k, song.at(bar, beat + 0.5), 0.75)
                    kick_times.append(song.at(bar, beat + 0.5))
            if song.on("hat", bar):
                for sixteenth in range(4):
                    louder = 0.5 if sixteenth == 2 else 0.28
                    m.add("dry", hats, song.at(bar, beat + sixteenth * 0.25), louder, 0.3 if sixteenth % 2 else -0.3)
            if song.on("snare", bar) and beat in (1, 3):
                m.add("dry", sn, t, 0.7)
                m.add("verb", sn, t, 0.5)
        if song.on("bass", bar):
            root = roots[idx]
            for step in range(16):
                semis = 0
                if step % 8 == 6:
                    semis = 12
                elif step % 4 == 3:
                    semis = 7 if idx % 2 == 0 else 5
                if step in (0, 3, 6, 10, 12, 14) or bar < 4:
                    m.add("dry", growl_bass(hz(root + semis), song.beat * 0.22), song.at(bar, step * 0.25), 0.95)
        if song.on("stab", bar):
            for beat_pos, semis in stab_hits:
                s = stab([hz(chords[idx][0] + 12 + semis), hz(chords[idx][0] + 19 + semis)])
                m.add("dry", s, song.at(bar, beat_pos), 0.6, 0.0)
                m.add("verb", s, song.at(bar, beat_pos), 0.4)
        if song.on("lead", bar):
            for beat_pos, name, dur in lead_phr[idx]:
                ld = lead(hz(midi(name)), dur * song.beat * 0.95, vibrato=1.0)
                m.add("dry", ld, song.at(bar, beat_pos), 0.5, 0.05)
                m.add("echo", ld, song.at(bar, beat_pos), 0.35)
        if song.on("riser", bar) and bar % 8 == 7:
            rs = riser(4 * song.beat)
            m.add("dry", rs, song.at(bar, 0), 0.7)
            m.add("verb", rs, song.at(bar, 0), 0.3)
    duck = sidechain(kick_times, m.n, 0.45, 0.09)
    m.dry *= duck[None, :]
    for t in kick_times:
        m.add("dry", k, t, 0.5)
    return finish(song, make_reverb_ir(1.8, 6000, 4), 0.28, 0.32, 0.45, drive=1.35, target_rms=-12.5)


# --------------------------------------------------------------------------
# Four more: calmer, warmer beds for long sessions (7.2)
# --------------------------------------------------------------------------

def rhodes(freq: float, length: float, velocity: float = 1.0) -> np.ndarray:
    """FM electric piano: a bell-ish attack that mellows, a faint tine, slow tremolo."""
    n = int(length * SR)
    t = np.arange(n) / SR
    index = 1.6 * velocity * np.exp(-t / 0.35) + 0.25
    body = np.sin(2 * np.pi * freq * t + index * np.sin(2 * np.pi * freq * t))
    tine = np.sin(2 * np.pi * freq * 13.9 * t) * np.exp(-t / 0.018) * 0.12 * velocity
    trem = 1.0 + 0.12 * np.sin(2 * np.pi * 4.6 * t)
    return (body * 0.5 + tine) * trem * env_ad(n, 0.003, length * 0.55 + 0.4) * 0.3 * velocity


def marimba(freq: float, length: float = 0.6, velocity: float = 1.0) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.32)
    out += np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / 0.07) * 0.35
    out += np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t / 0.02) * 0.15
    return out * env_ad(n, 0.002, 10) * 0.32 * velocity


def felt_piano(freq: float, length: float, velocity: float = 1.0) -> np.ndarray:
    """A soft, felted piano note: fundamental and gentle partials, rounded by a low-pass."""
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k, amp, decay in ((1, 1.0, 2.2), (2, 0.42, 1.2), (3, 0.18, 0.7), (4, 0.08, 0.4)):
        out += np.sin(2 * np.pi * freq * k * t * (1 + 0.0004 * k)) * amp * np.exp(-t / decay)
    out += fft_filter(noise(n), low=300, high=2400) * np.exp(-t / 0.01) * 0.08
    return fft_filter(out, high=2600) * env_ad(n, 0.006, 10) * 0.26 * velocity


def warm_bass(freq: float, length: float) -> np.ndarray:
    n = int(length * SR)
    body = sine(freq, n) * 0.9 + sine(freq * 2, n) * 0.18 + saw(freq, n, cutoff=380) * 0.25
    return body * env_pad(n, 0.01, min(0.12, length * 0.4)) * 0.8


def rim() -> np.ndarray:
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * 1700 * t) * np.exp(-t / 0.012)
    click = fft_filter(noise(n), low=2000, high=8000) * np.exp(-t / 0.008)
    return (tone * 0.5 + click * 0.6) * 0.5


def soft_kick() -> np.ndarray:
    return fft_filter(kick(0.75, 0.38), high=2200)


def vinyl_bed(seconds: float, amount: float = 1.0) -> np.ndarray:
    """Quiet hiss with the odd crackle: the room a lo-fi track sits in."""
    n = int(seconds * SR)
    hiss = fft_filter(noise(n), low=1800, high=9000) * 0.012
    crackle = np.zeros(n)
    for at in RNG.integers(0, n - 200, int(seconds * 7)):
        crackle[at:at + 60] += RNG.uniform(-1, 1) * np.exp(-np.arange(60) / 9.0) * RNG.uniform(0.05, 0.22)
    return (hiss + fft_filter(crackle, low=900)) * amount


def swung(song: Song, bar: int, eighth: int, swing: float = 0.16) -> float:
    beat = eighth * 0.5 + (swing if eighth % 2 == 1 else 0.0)
    return song.at(bar, beat)


def starlit_anvil() -> np.ndarray:
    """Lo-fi: swung Rhodes in D, soft kick and rim, warm bass, vinyl air, a bell line on top."""
    song = Song(82, 28)
    m = song.mix
    song.sections({"keys": (0, 28), "drums": (2, 26), "bass": (2, 26), "bell": (10, 24), "vinyl": (0, 28)})
    chords = [
        [midi(x) for x in ("D3", "F#3", "A3", "C#4", "E4")],
        [midi(x) for x in ("B2", "D3", "F#3", "A3", "C#4")],
        [midi(x) for x in ("E3", "G3", "B3", "D4", "F#4")],
        [midi(x) for x in ("A2", "C#3", "E3", "G3", "B3")],
    ]
    roots = [midi("D2"), midi("B1"), midi("E2"), midi("A1")]
    bell_line = [
        [(0.5, "F#5", 1.0), (2.0, "A5", 1.5)],
        [(1.0, "D5", 1.0), (2.5, "C#5", 1.0)],
        [(0.0, "B4", 1.5), (2.0, "D5", 1.0), (3.0, "E5", 1.0)],
        [(1.0, "C#5", 2.0)],
    ]
    k, rm, hh = soft_kick(), rim(), hat()
    kick_times = []
    m.add("dry", vinyl_bed(song.seconds), 0.0, 1.0)
    for bar in range(song.bars):
        idx = bar % 4
        if song.on("keys", bar):
            # a stab on 1 and a softer push on the "and" of 2, notes slightly rolled
            for hit, vel in ((0.0, 1.0), (1.5 + 0.16, 0.7)):
                for order, note_ in enumerate(chords[idx]):
                    t = song.at(bar, hit) + order * 0.012
                    r = rhodes(hz(note_), 2.4 * song.beat, vel)
                    m.add("dry", r, t, 0.55, (order - 2) * 0.22)
                    m.add("verb", r, t, 0.25)
        if song.on("drums", bar):
            for beat in (0, 2):
                m.add("dry", k, song.at(bar, beat), 0.8)
                kick_times.append(song.at(bar, beat))
            if bar % 2 == 1:
                m.add("dry", k, swung(song, bar, 5), 0.45)
            for beat in (1, 3):
                m.add("dry", rm, song.at(bar, beat), 0.55, 0.15)
                m.add("verb", rm, song.at(bar, beat), 0.3)
            for eighth in range(8):
                m.add("dry", hh, swung(song, bar, eighth), 0.22 if eighth % 2 else 0.32, -0.3)
        if song.on("bass", bar):
            for beat_pos, semis, dur in ((0.0, 0, 1.4), (1.66, 7, 0.4), (2.0, 12, 0.9), (3.16, 10, 0.6)):
                m.add("dry", warm_bass(hz(roots[idx] + semis), dur * song.beat), song.at(bar, beat_pos), 0.7)
        if song.on("bell", bar):
            for beat_pos, name, dur in bell_line[idx]:
                b = bell(hz(midi(name)), 2.2, 0.5)
                m.add("dry", b, song.at(bar, beat_pos), 0.32, 0.35)
                m.add("echo", b, song.at(bar, beat_pos), 0.45)
                m.add("verb", b, song.at(bar, beat_pos), 0.5)
    duck = sidechain(kick_times, m.n, 0.18, 0.15)
    m.dry *= duck[None, :]
    out = finish(song, make_reverb_ir(2.4, 4200, 11), 0.36, 0.4, 0.2, drive=1.05, target_rms=-16.0)
    return fft_filter_stereo(out, high=11000)


def nebula_market() -> np.ndarray:
    """Bright and bouncy: marimba ostinato in F, pluck bass, clap and shaker, glass bells."""
    song = Song(104, 36)
    m = song.mix
    song.sections({"marimba": (0, 36), "kick": (4, 34), "clap": (8, 34), "shaker": (4, 34), "bass": (4, 34), "bells": (12, 32), "pad": (0, 36)})
    chords = [chord("F3", "M"), chord("A2", "m"), chord("A#2", "M"), chord("C3", "M")]
    roots = [midi("F1"), midi("A1"), midi("A#1"), midi("C2")]
    pattern = [0, 12, 7, 12, 4, 12, 7, 16]
    bells = [
        [(0.0, "C6", 1.0), (1.5, "A5", 0.5), (2.0, "F5", 2.0)],
        [(0.0, "E5", 1.0), (1.0, "G5", 1.0), (2.0, "A5", 2.0)],
        [(0.0, "D6", 1.5), (1.5, "C6", 0.5), (2.0, "A#5", 2.0)],
        [(0.0, "G5", 1.0), (1.0, "A5", 1.0), (2.0, "C6", 2.0)],
    ]
    k, cl, sh = kick(0.8, 0.34), clap(), shaker()
    kick_times = []
    for bar in range(song.bars):
        idx = bar % 4
        if song.on("pad", bar):
            l, r = pad_chord(chords[idx], 4 * song.beat + 0.5, 1300, 0.6, 1.0)
            m.add_stereo("dry", l, r, song.at(bar, 0), 0.5)
            m.add_stereo("verb", l, r, song.at(bar, 0), 0.4)
        if song.on("marimba", bar):
            for step, semis in enumerate(pattern):
                note_ = chords[idx][0] + 12 + semis
                mb = marimba(hz(note_), 0.55, 1.0 if step % 4 == 0 else 0.75)
                t = song.at(bar, step * 0.5)
                m.add("dry", mb, t, 0.5, 0.5 if step % 2 else -0.5)
                m.add("echo", mb, t, 0.25)
        for beat in range(4):
            t = song.at(bar, beat)
            if song.on("kick", bar) and beat in (0, 2):
                m.add("dry", k, t, 0.8)
                kick_times.append(t)
            if song.on("clap", bar) and beat in (1, 3):
                m.add("dry", cl, t, 0.5)
                m.add("verb", cl, t, 0.35)
            if song.on("shaker", bar):
                m.add("dry", sh, song.at(bar, beat + 0.5), 0.45, 0.4)
                m.add("dry", sh, song.at(bar, beat + 0.75), 0.2, -0.4)
        if song.on("bass", bar):
            for step in range(8):
                semis = (0, 12, 0, 7, 0, 12, 10, 7)[step]
                pl = pluck(hz(roots[idx] + 12 + semis), 0.28, 0.25)
                m.add("dry", pl, song.at(bar, step * 0.5), 0.75)
        if song.on("bells", bar):
            for beat_pos, name, dur in bells[idx]:
                b = bell(hz(midi(name)), 1.8, 0.8)
                m.add("dry", b, song.at(bar, beat_pos), 0.3, -0.25)
                m.add("verb", b, song.at(bar, beat_pos), 0.45)
    duck = sidechain(kick_times, m.n, 0.3, 0.11)
    m.dry *= duck[None, :]
    return finish(song, make_reverb_ir(2.0, 5200, 12), 0.34, 0.4, 0.3, target_rms=-14.5)


def ember_drive() -> np.ndarray:
    """Warm synthwave: gated pads in E minor, octave bass, a big roomy snare, a singing lead."""
    song = Song(100, 32)
    m = song.mix
    song.sections({"pad": (0, 32), "kick": (4, 30), "snare": (4, 30), "hat": (8, 30), "bass": (2, 30), "lead": (12, 28), "arp": (8, 30)})
    chords = [chord("E3", "m"), chord("C3", "M"), chord("G3", "M"), chord("D3", "M")]
    roots = [midi("E1"), midi("C2"), midi("G1"), midi("D2")]
    lead_line = [
        [(0.0, "B4", 1.5), (1.5, "E5", 0.5), (2.0, "D5", 2.0)],
        [(0.0, "C5", 1.0), (1.0, "E5", 1.0), (2.0, "G5", 2.0)],
        [(0.0, "B4", 1.0), (1.0, "D5", 1.0), (2.0, "G5", 1.5), (3.5, "F#5", 0.5)],
        [(0.0, "F#5", 2.0), (2.0, "A5", 1.0), (3.0, "F#5", 1.0)],
    ]
    k, sn, hh = kick(1.0, 0.4), snare(0.34, 175), hat()
    kick_times = []
    for bar in range(song.bars):
        idx = bar % 4
        if song.on("pad", bar):
            # sixteenth gate on the pad: the pulse synthwave runs on
            l, r = pad_chord(chords[idx] + [chords[idx][0] + 12], 4 * song.beat + 0.3, 2400, 0.05, 0.3)
            n = len(l)
            step = int(song.beat / 4 * SR)
            gate = np.ones(n)
            for i in range(0, n, step):
                gate[i + int(step * 0.6): i + step] = 0.35
            gate = moving_average(gate, 220)
            m.add_stereo("dry", l * gate, r * gate, song.at(bar, 0), 0.7)
            m.add_stereo("verb", l, r, song.at(bar, 0), 0.25)
        for beat in range(4):
            t = song.at(bar, beat)
            if song.on("kick", bar) and beat in (0, 2):
                m.add("dry", k, t, 0.9)
                kick_times.append(t)
            if song.on("snare", bar) and beat in (1, 3):
                m.add("dry", sn, t, 0.55)
                m.add("verb", sn, t, 0.9)
            if song.on("hat", bar):
                m.add("dry", hh, song.at(bar, beat + 0.5), 0.3, 0.25)
        if song.on("bass", bar):
            for step in range(8):
                semis = 12 if step % 2 else 0
                m.add("dry", sub_bass(hz(roots[idx] + 12 + semis), song.beat * 0.45), song.at(bar, step * 0.5), 0.75)
        if song.on("arp", bar):
            for step in range(16):
                semis = (0, 7, 12, 7)[step % 4] + (3 if idx == 0 and step >= 8 else 0)
                pl = pluck(hz(chords[idx][0] + 12 + semis), 0.2, 0.8)
                m.add("dry", pl, song.at(bar, step * 0.25), 0.22, -0.55 if step % 2 else 0.55)
                m.add("echo", pl, song.at(bar, step * 0.25), 0.3)
        if song.on("lead", bar):
            for beat_pos, name, dur in lead_line[idx]:
                ld = lead(hz(midi(name)), dur * song.beat * 0.96, vibrato=1.4)
                m.add("dry", ld, song.at(bar, beat_pos), 0.45, 0.05)
                m.add("echo", ld, song.at(bar, beat_pos), 0.5)
                m.add("verb", ld, song.at(bar, beat_pos), 0.55)
    duck = sidechain(kick_times, m.n, 0.4, 0.13)
    m.dry *= duck[None, :]
    return finish(song, make_reverb_ir(2.8, 4800, 13), 0.42, 0.45, 0.4, drive=1.15, target_rms=-14.0)


def quiet_orbit() -> np.ndarray:
    """Ambient: slow A major pads, sparse felt piano, sub swells; no drums."""
    song = Song(68, 24)
    m = song.mix
    song.sections({"pad": (0, 24), "piano": (2, 24), "sub": (4, 22), "glass": (8, 20)})
    chords = [
        [midi(x) for x in ("A2", "E3", "B3", "C#4", "G#4")],
        [midi(x) for x in ("F#2", "C#3", "E3", "A3", "G#4")],
        [midi(x) for x in ("D3", "A3", "C#4", "E4", "F#4")],
        [midi(x) for x in ("E2", "B2", "D3", "A3", "B3")],
    ]
    motif = [[(0.0, 4), (1.5, 3), (2.5, 2)], [(0.5, 4), (2.0, 3)], [(0.0, 3), (1.0, 4), (3.0, 2)], [(1.0, 4), (2.5, 3)]]
    for bar in range(song.bars):
        idx = bar % 4
        if song.on("pad", bar):
            l, r = pad_chord(chords[idx][:4], 4 * song.beat + 2.5, 900, 2.0, 2.5)
            m.add_stereo("dry", l, r, song.at(bar, 0), 0.75)
            m.add_stereo("verb", l, r, song.at(bar, 0), 0.8)
        if song.on("piano", bar):
            for beat_pos, which in motif[idx]:
                note_ = chords[idx][which] + 12
                fp = felt_piano(hz(note_), 4.0, 0.9)
                t = song.at(bar, beat_pos)
                m.add("dry", fp, t, 0.6, (which - 2.5) * 0.2)
                m.add("verb", fp, t, 0.7)
                m.add("echo", fp, t, 0.25)
        if song.on("sub", bar):
            n = int(4 * song.beat * SR)
            swell = sine(hz(chords[idx][0] - 12), n) * env_pad(n, 1.6, 2.0) * 0.35
            m.add("dry", swell, song.at(bar, 0), 1.0)
        if song.on("glass", bar) and bar % 2 == 1:
            b = bell(hz(chords[idx][4] + 12), 4.0, 0.4)
            m.add("verb", b, song.at(bar, 2.0), 0.6)
            m.add("dry", b, song.at(bar, 2.0), 0.15, -0.5)
    return finish(song, make_reverb_ir(4.5, 3600, 14), 0.6, 0.35, 0.0, drive=1.0, target_rms=-17.0)


def fft_filter_stereo(stereo: np.ndarray, low=None, high=None) -> np.ndarray:
    return np.stack([fft_filter(stereo[0], low=low, high=high), fft_filter(stereo[1], low=low, high=high)])


NEW_TRACKS = {
    "StarlitAnvil.wav": starlit_anvil,
    "NebulaMarket.wav": nebula_market,
    "EmberDrive.wav": ember_drive,
    "QuietOrbit.wav": quiet_orbit,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    import sys

    tracks = {
        "ForgePulse.wav": forge_pulse,
        "SanctuaryDrift.wav": sanctuary_drift,
        "AstralOrbit.wav": astral_orbit,
        "BossSurge.wav": boss_surge,
    }
    tracks.update(NEW_TRACKS)
    if "--new" in sys.argv:
        # only the 7.2 additions; the first four are already uploaded
        tracks = dict(NEW_TRACKS)
    for name, build in tracks.items():
        path = os.path.join(OUT, name)
        print(f"rendering {name} ...", flush=True)
        buf = build()
        write_wav(path, buf)
        print(f"  {os.path.getsize(path) / 1_000_000:.1f} MB  {buf.shape[1] / SR:.1f}s  peak {np.abs(buf).max():.2f}", flush=True)


if __name__ == "__main__":
    main()
