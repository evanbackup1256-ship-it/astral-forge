"""Extra one-shots so pages, ores, waystones and button families each have a voice.

These stay short and dry on purpose: the monthly upload is one sheet, and a
reverb pass on every new voice would make the pack too slow and too long.
Neighboring names use different recipes and pitches so they do not read as
the same click transposed.
"""

from __future__ import annotations

import math

SR = 44100

PAGES = (
    "Overview", "Workshop", "Inventory", "Research", "Shop", "Settings",
    "Worlds", "Missions", "Rewards", "Boosts", "StarGrid", "Echoes", "Continuum",
    "Lab", "Anomaly", "Wheel", "Command", "Story", "Mail", "Chat", "Crew",
    "Milestones", "Convergence", "Guild", "Leaderboards", "Trade", "Credits",
    "Admin", "ForgePath", "Foundry",
)

ORES = ("Emberite", "Voidglass", "Starsteel")
STONES = ("Heart", "Emberreach", "Hollows", "Spire", "Riftmaw")

# Press cues that still shared one hover. Each gets its own pointer voice.
PRESSES = (
    "click", "confirm", "settings", "purchasePress", "claimPress", "codeSubmit",
    "zoneSelect", "labRoute", "playerlistAction", "playerlistSelect", "puzzleTap",
    "sanctuaryClick", "equip", "dangerPress", "close", "tick", "open", "tabSwitch",
    "mail", "story", "toggleOn", "toggleOff", "locked", "error", "prestige",
    "domainCharge", "cardEndTurn", "cardPower", "cardEnergy", "vaultBank",
    "guildCreate", "guildJoin", "invite", "travel", "gameResume", "gamePause",
    "queueStop", "queueStart", "boost", "reactorPulse", "crateOpen", "wheelStart",
    "reward", "rebirthCharge", "missionClaim", "leaderboardSwitch", "adminArm",
    "memberRemove", "roleChange", "preview", "reset", "chatSend", "boostOpen",
    "vaultDeposit",
)

# Icons that used to fall through to the generic click.
ICON_PRESSES = (
    "forgePress", "corePress", "wavePress", "labPress", "commandPress",
    "adminPress", "creditsPress", "chatPress", "continuumPress", "missionPress",
    "overviewPress",
)

RECIPES = 18


def _n(seconds: float) -> int:
    return max(8, int(seconds * SR))


def _freq(slot: int) -> float:
    # Golden-ratio walk so adjacent slots sit in different octaves.
    return 170.0 * (2 ** (((slot * 0.6180339887) % 1.0) * 3.4))


def _env(i: int, n: int, attack: float, curve: float) -> float:
    t = i / n
    if t < attack:
        return t / attack
    rest = max(1e-6, 1 - attack)
    return (1 - (t - attack) / rest) ** curve


def _render(slot: int, family: str, seconds: float):
    n = _n(seconds)
    recipe = slot % RECIPES
    f = _freq(slot + (0 if family == "hover" else 3))
    if family == "mine":
        f *= 0.55
        seconds = max(seconds, 0.26)
        n = _n(seconds)
    elif family == "collect":
        f *= 1.35
    elif family == "travel":
        f *= 0.8
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        e = _env(i, n, 0.04 if family != "hover" else 0.02, 1.4 + (recipe % 5) * 0.35)
        if recipe == 0:
            s = math.sin(math.tau * f * t) * 0.7 + math.sin(math.tau * f * 2.01 * t) * 0.25
        elif recipe == 1:
            g = f * (1.4 - 0.7 * (i / n))
            s = math.sin(math.tau * g * t)
        elif recipe == 2:
            noise = ((i * 1103515245 + slot * 17) & 65535) / 32768.0 - 1.0
            s = noise * 0.45 + math.sin(math.tau * f * 0.5 * t) * 0.55
        elif recipe == 3:
            p = (f * t) % 1.0
            s = (1.0 if p < 0.18 else -0.35) * math.sin(math.tau * f * t)
        elif recipe == 4:
            mod = math.sin(math.tau * f * 1.5 * t)
            s = math.sin(math.tau * f * t + 2.2 * mod)
        elif recipe == 5:
            s = (
                math.sin(math.tau * f * t) * 0.55
                + math.sin(math.tau * f * 2.76 * t) * 0.28
                + math.sin(math.tau * f * 5.2 * t) * 0.12
            )
        elif recipe == 6:
            g = f * (0.6 + 1.1 * (i / n))
            s = math.sin(math.tau * g * t) * 0.8 + math.sin(math.tau * g * 3 * t) * 0.15
        elif recipe == 7:
            g = f * (1.8 - 1.2 * (i / n))
            s = math.sin(math.tau * g * t) * 0.75
        elif recipe == 8:
            burst = 1.0 if (i % int(SR * 0.045)) < int(SR * 0.008) else 0.15
            s = math.sin(math.tau * f * 2 * t) * burst
        elif recipe == 9:
            s = (
                math.sin(math.tau * f * 1.0 * t)
                + math.sin(math.tau * f * 2.37 * t) * 0.4
                + math.sin(math.tau * f * 4.1 * t) * 0.2
            ) * 0.55
        elif recipe == 10:
            noise = ((i * 1664525 + slot * 97) & 65535) / 32768.0 - 1.0
            band = math.sin(math.tau * f * 3.2 * t)
            s = noise * band * 0.7
        elif recipe == 11:
            s = math.sin(math.tau * f * t) * 0.5 + math.sin(math.tau * f * 1.26 * t) * 0.4
        elif recipe == 12:
            s = math.sin(math.tau * (f * 0.5) * t) * (1 - i / n) + math.sin(math.tau * f * 4 * t) * e * 0.3
        elif recipe == 13:
            p = (f * 0.5 * t) % 1.0
            s = (2 * p - 1) * 0.45 + math.sin(math.tau * f * t) * 0.35
        elif recipe == 14:
            s = math.sin(math.tau * f * t) * (i / n) * 0.9
        elif recipe == 15:
            s = math.sin(math.tau * f * t) * 0.5 + math.sin(math.tau * f * 1.015 * t) * 0.5
        elif recipe == 16:
            s = math.sin(math.tau * f * t) * math.sin(math.tau * (f * 0.37) * t)
        else:
            gate = 1.0 if ((i // int(SR * 0.02)) % 2) == 0 else 0.25
            s = math.sin(math.tau * f * 1.5 * t) * gate
        out[i] = s * e
    # Tiny unique transient so two voices on the same recipe still separate.
    click = min(n, int(0.004 * SR))
    for i in range(click):
        noise = ((i * 2246822519 + slot * 131) & 65535) / 32768.0 - 1.0
        out[i] += noise * (1 - i / click) * (0.15 + (slot % 7) * 0.03)
    peak = max((abs(v) for v in out), default=1.0) or 1.0
    gain = 0.72 / peak
    fade = min(n // 5, int(0.012 * SR))
    for i in range(n):
        v = out[i] * gain
        if i < fade:
            v *= i / fade
        if i > n - fade:
            v *= (n - i) / fade
        out[i] = v
    return out


def extra_voices():
    voices = {}
    slot = 0

    def add(name: str, family: str, seconds: float):
        nonlocal slot
        captured = slot
        voices[name] = lambda captured=captured, family=family, seconds=seconds: _render(captured, family, seconds)
        slot += 1

    for page in PAGES:
        add(f"navOpen{page}", "open", 0.2)
        add(f"navHover{page}", "hover", 0.07)
    for ore in ORES:
        add(f"oreMine{ore}", "mine", 0.32)
        add(f"oreCollect{ore}", "collect", 0.36)
    for stone in STONES:
        add(f"waystone{stone}", "travel", 0.22)
    add("sanctuaryRecall", "open", 0.26)
    add("sanctuaryMenu", "hover", 0.09)
    add("sanctuarySheetClose", "open", 0.14)
    for press in PRESSES:
        add(f"{press}Hover", "hover", 0.065)
    for name in ICON_PRESSES:
        add(name, "press", 0.13)
    return voices


def _loudness(buf):
    top = max((abs(v) for v in buf), default=0.0)
    floor = top * 0.01
    active = [v for v in buf if abs(v) > floor] or buf
    rms = math.sqrt(sum(v * v for v in active) / max(1, len(active)))
    return round(20 * math.log10(max(rms, 1e-9)), 2)


def append_to_sheet():
    """Pack only the new voices onto the end of the existing sheet."""
    import json
    import os
    import wave
    from array import array

    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", ".."))
    wav_path = os.path.join(root, "assets", "generated", "AstralForgeSFX.wav")
    build_path = os.path.join(root, "assets", "generated", "build.json")
    with open(build_path, "r", encoding="utf-8") as handle:
        build = json.load(handle)
    regions = build["sfx"]["regions"]
    levels = build["sfx"].setdefault("loudness", {})
    gap = int(0.3 * SR)
    with wave.open(wav_path, "rb") as handle:
        if handle.getnchannels() != 1 or handle.getframerate() != SR or handle.getsampwidth() != 2:
            raise SystemExit(f"unexpected wav format: {handle.getparams()}")
        frames = array("h")
        frames.frombytes(handle.readframes(handle.getnframes()))
    added = 0
    for name, render in extra_voices().items():
        if name in regions:
            continue
        buf = render()
        start = len(frames) / SR
        for sample in buf:
            frames.append(int(max(-1.0, min(1.0, sample)) * 32767))
        regions[name] = [round(start, 4), round(len(buf) / SR, 4)]
        levels[name] = _loudness(buf)
        frames.extend([0] * gap)
        added += 1
        print(f"  {name:<22} {len(buf) / SR:5.2f}s")
    with wave.open(wav_path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(frames.tobytes())
    build["sfx"]["length"] = round(len(frames) / SR, 3)
    with open(build_path, "w", encoding="utf-8") as handle:
        json.dump(build, handle, indent=2)
    print(f"added {added} voices; sheet {build['sfx']['length']}s; regions {len(regions)}")


if __name__ == "__main__":
    append_to_sheet()
