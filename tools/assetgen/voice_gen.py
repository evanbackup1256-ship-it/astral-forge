"""Generate the bosses' spoken lines, timed to the on-screen text.

Uses Piper (a small neural text-to-speech that runs offline on the CPU) with the
LibriTTS-R voice model (CC BY 4.0, 904 speakers: each boss gets a different real speaker),
then makes it monstrous with numpy: sub-octave layers, chorus, ring modulation,
distortion and reverb, each boss with its own recipe.

Every line is spoken clause by clause, so the exact moment each word begins is known.
Those times are written into SharedData.luau (BOSS-VOICE-TIMING) and the client drives
the typewriter text from them, so the words appear as they are spoken.

    pip install piper-tts
    python tools/assetgen/voice_gen.py            # all bosses
    python tools/assetgen/voice_gen.py --only Knight

Output: assets/generated/voice/<Kind>_<NN>_<hash>.wav, voice_lines.json, and the timing
block in SharedData.luau. Then upload with upload_voice.py.

Voice model credit: LibriTTS-R (https://www.openslr.org/141/), CC BY 4.0.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
OUT = os.path.join(ROOT, "assets", "generated", "voice")
MODEL = os.path.join(ROOT, "assets", "generated", "piper", "libritts_r.onnx")
RATE = 22050
TIMING_BEGIN, TIMING_END = "-- BOSS-VOICE-TIMING-BEGIN", "-- BOSS-VOICE-TIMING-END"

# speaker: LibriTTS-R speaker id (picked by pitch: low ones for the deep bosses)
# pitch: resample ratio (<1 deeper, also slows); sub: mix of a one-octave-down layer;
# up: mix of a one-octave-up layer; chorus: detuned copies; ring: (Hz, depth) ring mod;
# drive: distortion; reverb: (tail seconds, wet); low: low-pass; air: breath/hiss mix.
PROFILES = {
    "Warden": dict(speaker=36, pitch=0.86, sub=0.32, up=0.0, chorus=2, ring=(0, 0), drive=1.5, reverb=(1.8, 0.35), low=0.2, air=0.02),
    "Choir": dict(speaker=315, pitch=1.0, sub=0.0, up=0.22, chorus=4, ring=(0, 0), drive=1.0, reverb=(2.6, 0.5), low=0.0, air=0.03),
    "Regent": dict(speaker=594, pitch=0.88, sub=0.4, up=0.0, chorus=1, ring=(0, 0), drive=3.0, reverb=(0.9, 0.25), low=0.3, air=0.0),
    "Seraph": dict(speaker=207, pitch=1.04, sub=0.0, up=0.12, chorus=2, ring=(120, 0.28), drive=1.8, reverb=(1.1, 0.3), low=0.0, air=0.025),
    "Rime": dict(speaker=342, pitch=0.93, sub=0.2, up=0.0, chorus=3, ring=(0, 0), drive=1.0, reverb=(3.2, 0.5), low=0.45, air=0.06),
    "Astraeon": dict(speaker=90, pitch=0.82, sub=0.35, up=0.15, chorus=3, ring=(30, 0.12), drive=1.6, reverb=(1.2, 0.35), low=0.25, air=0.3),
    "Knight": dict(speaker=90, pitch=0.9, sub=0.28, up=0.0, chorus=1, ring=(42, 0.2), drive=2.0, reverb=(0.7, 0.22), low=0.2, air=0.0),
}

# What each text effect does to how a clause is spoken: length_scale (<1 faster),
# volume, and whether it gets glitched.
SPOKEN = {
    "slow": dict(length=1.45, volume=1.0),
    "whisper": dict(length=1.15, volume=0.5),
    "shake": dict(length=0.92, volume=1.3),
    "big": dict(length=1.05, volume=1.35),
    "wave": dict(length=1.18, volume=0.9),
    "glitch": dict(length=1.0, volume=1.0, glitch=True),
    "pulse": dict(length=1.1, volume=1.0),
    "hot": dict(length=1.05, volume=1.1),
}
GAPS = {",": 0.14, ";": 0.2, ":": 0.2, "—": 0.2, "-": 0.1, ".": 0.32, "!": 0.32, "?": 0.34, "…": 0.3}
BEAT = 0.42
TAG = re.compile(r"\[(/?)(\w*)\]")


def boss_lines(text: str) -> dict[str, list[str]]:
    lines: dict[str, list[str]] = {}
    for match in re.finditer(r'Kind = "(\w+)",\s*\n(?:(?!\n\}\)|\n\}\n).)*?Dialogue = \{', text, re.S):
        kind = match.group(1)
        start = match.end()
        depth, index = 1, start
        while depth > 0 and index < len(text):
            char = text[index]
            depth += (char == "{") - (char == "}")
            index += 1
        found = re.findall(r'"((?:[^"\\]|\\.)*)"', text[start : index - 1])
        if kind in PROFILES and found:
            lines[kind] = [line for line in dict.fromkeys(found) if "{name}" not in line]  # lines with a name are typed, not voiced
    return lines


def parse(markup: str):
    """-> [(word, fx_tuple, False, beat_after)] from marked-up text. Words are the
    whitespace-separated pieces of the text with the tags removed, exactly as the client
    splits them, so word times line up with what is on screen."""
    chars: list[tuple[str, tuple]] = []
    beats: set[int] = set()
    active: list[str] = []
    position = 0
    for match in TAG.finditer(markup):
        chars.extend((ch, tuple(active)) for ch in markup[position : match.start()])
        position = match.end()
        closing, name = match.group(1) == "/", match.group(2)
        if name == "beat":
            beats.add(len(chars))
        elif closing:
            if active:
                active.pop()
        else:
            active.append(name)
    chars.extend((ch, tuple(active)) for ch in markup[position:])
    plain = "".join(ch for ch, _ in chars)
    spans = list(re.finditer(r"\S+", plain))
    words = []
    for index, span in enumerate(spans):
        following = spans[index + 1].start() if index + 1 < len(spans) else len(plain)
        beat_after = any(span.end() <= b <= following for b in beats)
        words.append((span.group(0), chars[span.start()][1], False, beat_after))
    return words

def chunks_of(words):
    """Group words into clauses that end at punctuation (or a [beat]). A clause is
    [(index_in_words, ...)], its trailing gap in seconds."""
    clauses, current = [], []
    for index, entry in enumerate(words):
        word, _fx, _x, beat_after = entry
        current.append(index)
        mark = word.rstrip("\"')]}")[-1:] if word else ""
        gap = GAPS.get(mark)
        if beat_after:
            gap = (gap or 0) + BEAT
        if gap is not None and (gap >= 0.14 or beat_after):
            clauses.append((current, gap))
            current = []
    if current:
        clauses.append((current, 0.0))
    return clauses


def trim(x: np.ndarray, floor: float = 0.012) -> tuple[np.ndarray, float]:
    """Cut leading/trailing near-silence; returns (audio, seconds cut from the front)."""
    loud = np.where(np.abs(x) > floor)[0]
    if len(loud) == 0:
        return x, 0.0
    start = max(0, loud[0] - int(0.02 * RATE))
    end = min(len(x), loud[-1] + int(0.03 * RATE))
    return x[start:end], start / RATE


def synth_line(voice, markup: str, profile: dict):
    from piper import SynthesisConfig

    words = parse(markup)
    plain = [w[0] for w in words]
    clauses = chunks_of(words)
    pieces: list[np.ndarray] = []
    starts = [0.0] * len(words)
    clock = 0.0
    glitches: list[tuple[int, int]] = []
    for indexes, gap in clauses:
        text = " ".join(plain[i] for i in indexes)
        text = re.sub(r"[\[\]]", "", text)
        fx_sets = [words[i][1] for i in indexes]
        flat = [name for fx in fx_sets for name in fx]
        pick = next((name for name in ("whisper", "slow", "shake", "big", "wave", "glitch", "pulse", "hot") if name in flat), None)
        spec = SPOKEN.get(pick, dict(length=1.0, volume=1.0))
        config = SynthesisConfig(speaker_id=profile["speaker"], length_scale=spec["length"], volume=1.0, noise_scale=0.8 if pick == "whisper" else 0.667, noise_w_scale=0.9)
        audio = np.concatenate([c.audio_float_array for c in voice.synthesize(text, config)]) if text.strip() else np.zeros(1)
        audio, lead = trim(audio)
        audio = audio * spec["volume"]
        # distribute the clause's words over its audio by letter count
        weights = np.array([max(1, len(plain[i])) for i in indexes], dtype=float)
        weights /= weights.sum()
        begin = 0.0
        duration = len(audio) / RATE
        for index, weight in zip(indexes, weights):
            starts[index] = clock + begin
            begin += weight * duration
        if spec.get("glitch"):
            glitches.append((int(clock * RATE), int((clock + duration) * RATE)))
        pieces.append(audio)
        clock += duration
        silence = np.zeros(int(gap * RATE)) if gap else np.zeros(int(0.04 * RATE))
        pieces.append(silence)
        clock += len(silence) / RATE
    mix = np.concatenate(pieces)
    return mix, starts, glitches


def resample(x: np.ndarray, ratio: float) -> np.ndarray:
    if len(x) < 2:
        return x
    n = max(2, int(len(x) / ratio))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def lowpass(x: np.ndarray, amount: float) -> np.ndarray:
    if amount <= 0:
        return x
    window = int(2 + amount * 10)
    return np.convolve(x, np.ones(window) / window, mode="same")


def reverb(x: np.ndarray, seconds: float, wet: float) -> np.ndarray:
    rng = np.random.default_rng(7)
    n = int(seconds * RATE)
    tail = rng.standard_normal(n) * np.exp(-np.linspace(0, 6, n))
    tail[0] = 0
    size = len(x) + n
    wetted = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(tail, size), size)
    wetted *= np.max(np.abs(x)) / max(1e-9, np.max(np.abs(wetted)))
    return np.concatenate([x, np.zeros(n)]) * (1 - wet * 0.5) + wetted * wet


def glitch(x: np.ndarray, spans) -> np.ndarray:
    """Bit-crush and stutter the glitched clauses."""
    rng = np.random.default_rng(3)
    out = x.copy()
    for start, end in spans:
        end = min(end, len(out))
        if end - start < 400:
            continue
        seg = out[start:end]
        seg = np.round(seg * 24) / 24
        for _ in range(max(1, (end - start) // 5000)):
            at = int(rng.integers(0, max(1, len(seg) - 900)))
            seg[at : at + 900] = np.tile(seg[at : at + 300], 3)[:900]
        out[start:end] = seg
    return out


def ola_stretch(x: np.ndarray, factor: float, grain: int = 1024) -> np.ndarray:
    """Make `x` `factor` times longer without changing its pitch (overlap-add of windowed grains)."""
    if abs(factor - 1) < 1e-3 or len(x) < grain * 2:
        return x
    hop_out = grain // 2
    hop_in = hop_out / factor
    window = np.hanning(grain)
    count = int((len(x) - grain) / hop_in) + 1
    out = np.zeros(int(count * hop_out + grain))
    norm = np.zeros_like(out)
    for k in range(count):
        a = int(k * hop_in)
        b = k * hop_out
        out[b : b + grain] += x[a : a + grain] * window
        norm[b : b + grain] += window
    return out / np.maximum(norm, 1e-3)


def shift(x: np.ndarray, ratio: float) -> np.ndarray:
    """Pitch-shift by `ratio` keeping the length (and so every word's timing)."""
    if abs(ratio - 1) < 1e-3:
        return x
    shifted = ola_stretch(resample(x, ratio), ratio)
    if len(shifted) < len(x):
        shifted = np.pad(shifted, (0, len(x) - len(shifted)))
    return shifted[: len(x)]


def process(x: np.ndarray, spans, p: dict) -> np.ndarray:
    x = x / max(1e-9, np.max(np.abs(x)))
    x = glitch(x, spans)
    base = shift(x, p["pitch"])
    length = len(base)
    mix = base.copy()
    if p["sub"]:
        mix += shift(base, 0.5) * p["sub"]
    if p["up"]:
        mix += shift(base, 2.0) * p["up"]
    for k in range(p["chorus"]):
        detune = 1 + (k + 1) * 0.011 * (-1 if k % 2 else 1)
        copy = np.concatenate([np.zeros(int(0.013 * RATE * (k + 1))), shift(base, detune)])[:length]
        mix[: len(copy)] += copy * 0.4
    freq, depth = p["ring"]
    if freq:
        t = np.arange(length) / RATE
        mix *= 1 - depth + depth * np.sin(2 * np.pi * freq * t)
    if p["air"]:
        rng = np.random.default_rng(5)
        mix += rng.standard_normal(length) * np.abs(lowpass(base, 0.5)) * p["air"] * 6
    mix = np.tanh(mix * p["drive"]) / np.tanh(p["drive"])
    mix = lowpass(mix, p["low"])
    seconds, wet = p["reverb"]
    mix = reverb(mix, seconds, wet)
    mix = np.concatenate([mix, np.zeros(int(0.12 * RATE))])
    fade = int(0.008 * RATE)
    mix[:fade] *= np.linspace(0, 1, fade)
    mix /= max(1e-9, np.max(np.abs(mix)))
    return mix * 0.92

def write_wav(path: str, x: np.ndarray) -> None:
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_timing_block(manifest: dict) -> None:
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    rows = []
    for info in manifest.values():
        times = ", ".join(f"{t:.2f}" for t in info["words"])
        rows.append(f"\t[{lua_string(info['text'])}] = {{ d = {info['duration']:.2f}, w = {{ {times} }} }},")
    body = newline.join(
        [TIMING_BEGIN + " (rewritten by tools/assetgen/voice_gen.py)", "SanctuaryConfig.BossVoiceTiming = {"]
        + sorted(set(rows))
        + ["}", TIMING_END]
    )
    pattern = re.compile(re.escape(TIMING_BEGIN) + r".*?" + re.escape(TIMING_END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-VOICE-TIMING block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="one boss kind, e.g. Knight")
    args = parser.parse_args()
    with open(DATA, "r", encoding="utf-8") as handle:
        lines = boss_lines(handle.read())
    if not lines:
        sys.exit("found no boss dialogue in SharedData.luau")
    from piper import PiperVoice

    voice = PiperVoice.load(MODEL)
    os.makedirs(OUT, exist_ok=True)
    manifest_path = os.path.join(OUT, "voice_lines.json")
    manifest: dict = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as handle:
            manifest = json.load(handle)
    # forget lines that are no longer in the script
    live = {line for spoken in lines.values() for line in spoken}
    manifest = {name: info for name, info in manifest.items() if info["text"] in live and "words" in info}
    for kind, spoken in lines.items():
        if args.only and args.only != kind:
            continue
        profile = PROFILES[kind]
        print(f"{kind}: {len(spoken)} lines")
        for index, line in enumerate(spoken, 1):
            digest = hashlib.sha1((line + json.dumps(profile, sort_keys=True)).encode("utf-8")).hexdigest()[:8]
            name = f"{kind}_{index:02d}_{digest}"
            if name in manifest and os.path.exists(os.path.join(OUT, name + ".wav")):
                continue
            raw, starts, spans = synth_line(voice, line, profile)
            audio = process(raw, spans, profile)
            manifest = {n: i for n, i in manifest.items() if not (i["kind"] == kind and i["text"] == line)}
            write_wav(os.path.join(OUT, name + ".wav"), audio)
            manifest[name] = {"kind": kind, "text": line, "words": [round(s, 3) for s in starts], "duration": round(len(audio) / RATE, 3)}
            print(f"  {name}: {len(audio) / RATE:.1f}s")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    write_timing_block(manifest)
    print(f"wrote {len(manifest)} lines to {OUT}")


if __name__ == "__main__":
    main()
