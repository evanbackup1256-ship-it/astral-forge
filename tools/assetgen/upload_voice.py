"""Upload the bosses' voice lines (made by voice_gen.py) and wire them into the game.

Run after voice_gen.py, with your Open Cloud key saved (see README / set-key.ps1):

    python tools/assetgen/upload_voice.py

Already-uploaded lines are skipped (ids live in assets/generated/voice/voice_ids.json), so
it is safe to re-run. When it finishes it rewrites the BOSS-VOICE block in SharedData.luau
so the client plays each line's voice as it is spoken. Roblox moderates every upload; a
line that is rejected simply stays silent (the subtitle still shows).
"""

from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import upload  # noqa: E402

ROOT = upload.ROOT
VOICE = os.path.join(ROOT, "assets", "generated", "voice")
LINES = os.path.join(VOICE, "voice_lines.json")
IDS = os.path.join(VOICE, "voice_ids.json")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
BEGIN, END = "-- BOSS-VOICE-BEGIN", "-- BOSS-VOICE-END"


def lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_block(lines: dict, ids: dict) -> None:
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    entries = []
    for name, info in lines.items():
        asset = ids.get(name)
        if asset:
            entries.append(f"\t[{lua_string(info['text'])}] = {int(asset)},")
    body = newline.join(
        [BEGIN + " (rewritten by tools/assetgen/upload_voice.py)", "SanctuaryConfig.BossVoice = {"]
        + sorted(set(entries))
        + ["}", END]
    )
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-VOICE block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main() -> None:
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key. Run tools/assetgen/set-key.ps1 first.")
    with open(LINES, "r", encoding="utf-8") as handle:
        lines = json.load(handle)
    ids = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as handle:
            ids = json.load(handle)
    print(f"uploading as {upload.creator()}")
    for name, info in lines.items():
        if ids.get(name):
            continue
        path = os.path.join(VOICE, name + ".wav")
        try:
            ids[name] = upload.upload(key, "Audio", path, "audio/wav", f"Astral Forge boss voice {name}", info["text"][:100])
            print(f"  {name} -> {ids[name]}")
        except Exception as problem:  # keep going: one rejected line must not stop the rest
            print(f"  {name} FAILED: {problem}")
            continue
        with open(IDS, "w", encoding="utf-8") as handle:
            json.dump(ids, handle, indent=2)
            handle.write("\n")
    write_block(lines, ids)
    print(f"{len(ids)}/{len(lines)} voiced; SharedData.luau updated")


if __name__ == "__main__":
    main()