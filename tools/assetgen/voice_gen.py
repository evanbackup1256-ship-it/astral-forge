"""Generate the bosses' spoken lines.

Reads every boss's Dialogue from SharedData.luau, speaks each line with the Windows
text-to-speech voices already on the machine (no downloads, no licences to worry about),
then turns the plain voice into something monstrous with numpy: pitch, chorus, ring
modulation, distortion and reverb, each boss with its own recipe.

    python tools/assetgen/voice_gen.py            # all bosses
    python tools/assetgen/voice_gen.py --only Knight

Output: assets/generated/voice/<Kind>_<n>.wav plus voice_lines.json (the text of each file).
Then upload with upload_voice.py.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
OUT = os.path.join(ROOT, "assets", "generated", "voice")
RATE = 22050

# voice: SAPI voice, rate: SAPI speed (-10..10), pitch: resample ratio (<1 deeper),
# chorus: extra detuned copies, ring: ring-mod frequency (Hz, 0 = off), drive: distortion,
# reverb: tail seconds and wet mix, low: low-pass strength.
PROFILES = {
    "Warden": dict(voice="Microsoft David Desktop", rate=-3, pitch=0.78, chorus=2, ring=0, drive=1.6, reverb=(1.6, 0.35), low=0.3),
    "Choir": dict(voice="Microsoft Zira Desktop", rate=-1, pitch=1.22, chorus=4, ring=0, drive=1.0, reverb=(2.2, 0.45), low=0.0),
    "Regent": dict(voice="Microsoft David Desktop", rate=-2, pitch=0.66, chorus=1, ring=0, drive=3.2, reverb=(0.9, 0.25), low=0.35),
    "Seraph": dict(voice="Microsoft Zira Desktop", rate=2, pitch=1.08, chorus=2, ring=95, drive=2.0, reverb=(1.0, 0.3), low=0.0),
    "Rime": dict(voice="Microsoft Zira Desktop", rate=-4, pitch=0.82, chorus=3, ring=0, drive=1.0, reverb=(3.0, 0.5), low=0.55),
    "Knight": dict(voice="Microsoft David Desktop", rate=-1, pitch=0.6, chorus=1, ring=60, drive=2.2, reverb=(0.7, 0.22), low=0.25),
}


def boss_lines(text: str) -> dict[str, list[str]]:
    """{Kind: [line, ...]} in file order, from each boss's Dialogue table."""
    lines: dict[str, list[str]] = {}
    for match in re.finditer(r'Kind = "(\w+)",\s*\n(?:(?!\n\}\)|\n\}\n).)*?Dialogue = \{', text, re.S):
        kind = match.group(1)
        start = match.end()
        depth, index = 1, start
        while depth > 0 and index < len(text):
            char = text[index]
            depth += (char == "{") - (char == "}")
            index += 1
        block = text[start : index - 1]
        found = re.findall(r'"((?:[^"\\]|\\.)*)"', block)
        if kind in PROFILES and found:
            lines[kind] = list(dict.fromkeys(found))
    return lines


def speak(line: str, voice: str, rate: int, path: str) -> None:
    safe = line.replace("'", "''")
    script = (
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        f"$s.SelectVoice('{voice}'); $s.Rate = {rate};"
        f"$s.SetOutputToWaveFile('{path}'); $s.Speak('{safe}'); $s.Dispose()"
    )
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True, capture_output=True)


def read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as handle:
        frames = handle.readframes(handle.getnframes())
        width, channels, rate = handle.getsampwidth(), handle.getnchannels(), handle.getframerate()
    data = np.frombuffer(frames, dtype=np.int16 if width == 2 else np.uint8).astype(np.float64)
    if width == 1:
        data = (data - 128) * 256
    if channels > 1:
        data = data.reshape(-1, channels).mean(axis=1)
    data /= 32768.0
    if rate != RATE:
        data = resample(data, RATE / rate)
    return data


def resample(x: np.ndarray, ratio: float) -> np.ndarray:
    """Playing back `ratio` times faster/slower (ratio > 1 shortens)."""
    if len(x) < 2:
        return x
    n = max(2, int(len(x) / ratio))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def lowpass(x: np.ndarray, amount: float) -> np.ndarray:
    if amount <= 0:
        return x
    window = int(2 + amount * 10)
    kernel = np.ones(window) / window
    return np.convolve(x, kernel, mode="same")


def reverb(x: np.ndarray, seconds: float, wet: float) -> np.ndarray:
    rng = np.random.default_rng(7)
    n = int(seconds * RATE)
    tail = rng.standard_normal(n) * np.exp(-np.linspace(0, 6, n))
    tail[0] = 0
    size = len(x) + n
    spectrum = np.fft.rfft(x, size) * np.fft.rfft(tail, size)
    wetted = np.fft.irfft(spectrum, size)
    wetted /= max(1e-9, np.max(np.abs(wetted))) / max(1e-9, np.max(np.abs(x)))
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - wet * 0.5) + wetted * wet


def process(x: np.ndarray, profile: dict) -> np.ndarray:
    x = x / max(1e-9, np.max(np.abs(x)))
    voices = [resample(x, 1 / profile["pitch"])]
    for k in range(profile["chorus"]):
        detune = profile["pitch"] * (1 + (k + 1) * 0.012 * (-1 if k % 2 else 1))
        copy = resample(x, 1 / detune)
        voices.append(np.concatenate([np.zeros(int(0.012 * RATE * (k + 1))), copy]))
    length = max(len(v) for v in voices)
    mix = np.zeros(length)
    for index, v in enumerate(voices):
        mix[: len(v)] += v * (1.0 if index == 0 else 0.45)
    if profile["ring"]:
        t = np.arange(length) / RATE
        mix = mix * (0.55 + 0.45 * np.sin(2 * np.pi * profile["ring"] * t))
    mix = np.tanh(mix * profile["drive"]) / np.tanh(profile["drive"])
    mix = lowpass(mix, profile["low"])
    seconds, wet = profile["reverb"]
    mix = reverb(mix, seconds, wet)
    mix = np.concatenate([mix, np.zeros(int(0.15 * RATE))])
    fade = int(0.01 * RATE)
    mix[:fade] *= np.linspace(0, 1, fade)
    mix /= max(1e-9, np.max(np.abs(mix)))
    return mix * 0.9


def write_wav(path: str, x: np.ndarray) -> None:
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="one boss kind, e.g. Knight")
    args = parser.parse_args()
    with open(DATA, "r", encoding="utf-8") as handle:
        lines = boss_lines(handle.read())
    if not lines:
        sys.exit("found no boss dialogue in SharedData.luau")
    os.makedirs(OUT, exist_ok=True)
    manifest_path = os.path.join(OUT, "voice_lines.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as handle:
            manifest = json.load(handle)
    for kind, spoken in lines.items():
        if args.only and args.only != kind:
            continue
        profile = PROFILES[kind]
        print(f"{kind}: {len(spoken)} lines")
        for index, line in enumerate(spoken, 1):
            name = f"{kind}_{index:02d}"
            raw = os.path.join(tempfile.gettempdir(), f"{name}_raw.wav")
            speak(line, profile["voice"], profile["rate"], raw)
            write_wav(os.path.join(OUT, name + ".wav"), process(read_wav(raw), profile))
            os.remove(raw)
            manifest[name] = {"kind": kind, "text": line}
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(f"wrote {len(manifest)} lines to {OUT}")


if __name__ == "__main__":
    main()
