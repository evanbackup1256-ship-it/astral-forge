"""Upload the boss fight soundtracks (from boss_music_gen.py) and wire them in.

    python tools/assetgen/upload_boss_music.py

Skips what is already uploaded (assets/generated/bossmusic/music_ids.json) and rewrites the BOSS-MUSIC
block in SharedData.luau; each boss's Music.Id picks its track up from there.
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
FOLDER = os.path.join(ROOT, "assets", "generated", "bossmusic")
NAMES = os.path.join(FOLDER, "music_names.json")
IDS = os.path.join(FOLDER, "music_ids.json")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
BEGIN, END = "-- BOSS-MUSIC-BEGIN", "-- BOSS-MUSIC-END"


def write_block(ids: dict) -> None:
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    entries = [f"\t{name.replace('music_', '')} = {int(asset)}," for name, asset in sorted(ids.items()) if asset]
    body = newline.join([BEGIN + " (rewritten by tools/assetgen/upload_boss_music.py)", "SanctuaryConfig.BossMusic = {"] + entries + ["}", END])
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-MUSIC block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main() -> None:
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key. Run tools/assetgen/set-key.ps1 first.")
    with open(NAMES, "r", encoding="utf-8") as handle:
        names = json.load(handle)
    ids = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as handle:
            ids = json.load(handle)
    print(f"uploading as {upload.creator()}")
    for name in names:
        if ids.get(name):
            continue
        try:
            ids[name] = upload.upload(key, "Audio", os.path.join(FOLDER, name + ".wav"), "audio/wav", f"Astral Forge boss music {name}", "Original Astral Forge boss soundtrack.")
            print(f"  {name} -> {ids[name]}")
        except Exception as problem:
            print(f"  {name} FAILED: {problem}")
            continue
        with open(IDS, "w", encoding="utf-8") as handle:
            json.dump(ids, handle, indent=2)
            handle.write("\n")
    write_block(ids)
    print(f"{len(ids)}/{len(names)} uploaded; SharedData.luau updated")


if __name__ == "__main__":
    main()