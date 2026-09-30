"""Original Astral Forge soundtrack beds.

Four mono tracks, dark-cyber forge rather than library reuse:
  ForgePulse      idle foundry, metered pulse
  SanctuaryDrift  slow voidglass tension
  AstralOrbit     cooler astral drift
  BossSurge       denser Warden pressure

Writes assets/generated/soundtrack/*.wav
"""

from __future__ import annotations

import array
import math
import os
import wave

from synth import (
    SR,
    apply_env,
    bell,
    env_exp,
    fade,
    frames,
    lowpass,
    mix,
    noise,
    normalize,
    note,
    pulse,
    sine,
    softclip,
    zeros,
)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "soundtrack")


def write_wav(path: str, buf) -> None:
    data = array.array("h", (int(max(-1.0, min(1.0, v)) * 32767) for v in buf))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(data.tobytes())


def hit(freq: float, seconds: float, amp: float, decay: float):
    return apply_env(sine(freq, seconds, amp), env_exp(seconds, decay, 0.004))


def place_hits(dst, freq, every, amp, decay, length, skip=0.0):
    t = skip
    while t < length - decay:
        mix(dst, hit(freq, decay * 3, amp, decay), t)
        t += every
    return dst


def arp(dst, notes, step, amp, length, voice="bell"):
    i = 0
    t = 0.15
    while t < length - 0.4:
        freq = note(notes[i % len(notes)])
        if voice == "bell":
            tone = apply_env(bell(freq, 0.55, amp, brightness=0.7), env_exp(0.55, 0.22))
        else:
            tone = apply_env(pulse(freq, 0.28, amp, 0.18), env_exp(0.28, 0.09))
        mix(dst, tone, t)
        i += 1
        t += step
    return dst


def bed(seconds: float, drones):
    out = zeros(seconds)
    for freq, amp in drones:
        mix(out, sine(freq, seconds, amp))
        mix(out, sine(freq * 1.002, seconds, amp * 0.35))
    return out


def forge_pulse():
    length = 64.0
    out = bed(length, [(note("D1"), 0.22), (note("A1"), 0.1)])
    place_hits(out, note("D1"), 0.6, 0.55, 0.12, length)
    place_hits(out, 1800, 0.3, 0.04, 0.02, length, skip=0.3)
    arp(out, ["D3", "F3", "A3", "C4", "A3", "F3"], 0.3, 0.11, length, "pulse")
    air = lowpass(noise(length, 0.08), 900)
    mix(out, air, 0, 0.35)
    return finish(out)


def sanctuary_drift():
    length = 72.0
    out = bed(length, [(note("E1"), 0.2), (note("B1"), 0.12), (note("E2"), 0.05)])
    arp(out, ["E4", "F4", "B3", "E4", "G3", "B3"], 1.5, 0.16, length, "bell")
    air = lowpass(noise(length, 0.05), 1400)
    mix(out, air, 0, 0.5)
    return finish(out, slap_s=0.11, slap=0.22)


def astral_orbit():
    length = 68.0
    out = bed(length, [(note("A1"), 0.16), (note("E2"), 0.08)])
    arp(out, ["A3", "C4", "E4", "G4", "E4", "C4", "A3", "G3"], 0.42, 0.1, length, "bell")
    place_hits(out, note("A2"), 1.26, 0.18, 0.2, length)
    return finish(out, slap_s=0.09, slap=0.16)


def boss_surge():
    length = 60.0
    out = bed(length, [(note("F#1"), 0.28), (note("C2"), 0.08)])
    place_hits(out, note("F#1"), 0.375, 0.7, 0.08, length)
    place_hits(out, note("C2"), 0.75, 0.35, 0.06, length, skip=0.375)
    arp(out, ["F#3", "G3", "C4", "F#3", "C#4", "G3"], 0.1875, 0.12, length, "pulse")
    stab = apply_env(sine(note("G3"), 0.2, 0.2), env_exp(0.2, 0.05))
    t = 4.0
    while t < length - 1:
        mix(out, stab, t, 0.8)
        t += 8.0
    return finish(out, slap_s=0.06, slap=0.1)


def finish(buf, slap_s=0.08, slap=0.14):
    delay = frames(slap_s)
    spaced = buf[:]
    for i in range(delay, len(buf)):
        spaced[i] += buf[i - delay] * slap
    spaced = softclip(spaced, 1.15)
    spaced = normalize(spaced, -3.0)
    spaced = [v * 0.82 for v in spaced]
    return fade(spaced, 1.2, 2.4)


def main():
    os.makedirs(OUT, exist_ok=True)
    tracks = {
        "ForgePulse.wav": forge_pulse,
        "SanctuaryDrift.wav": sanctuary_drift,
        "AstralOrbit.wav": astral_orbit,
        "BossSurge.wav": boss_surge,
    }
    for name, build in tracks.items():
        path = os.path.join(OUT, name)
        print(f"rendering {name} ...", flush=True)
        buf = build()
        write_wav(path, buf)
        print(f"  {os.path.getsize(path) / 1_000_000:.1f} MB  {len(buf) / SR:.1f}s", flush=True)


if __name__ == "__main__":
    main()
