"""Upload the boss particle sprites (made by blender_bosstex.py) and wire the ids in.

    python tools/assetgen/upload_boss_tex.py

Uploads each PNG in assets/generated/bosstex/ as a decal, skips ones already uploaded
(bosstex_ids.json) and rewrites the BOSS-TEX block in SharedData.luau.
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
FOLDER = os.path.join(ROOT, "assets", "generated", "bosstex")
IDS = os.path.join(FOLDER, "bosstex_ids.json")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
BEGIN, END = "-- BOSS-TEX-BEGIN", "-- BOSS-TEX-END"
NAMES = ["rune_glyph", "void_wisp", "note", "ripple", "flame_lick", "ember", "spark_streak", "feather", "snowflake", "ice_shard", "slash", "shadow_wisp"]


def write_block(ids: dict) -> None:
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    rows = [f'\t["{name}"] = {int(asset)},' for name, asset in sorted(ids.items()) if asset]
    body = newline.join([BEGIN + " (rewritten by tools/assetgen/upload_boss_tex.py)", "SanctuaryConfig.BossTex = {"] + rows + ["}", END])
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-TEX block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main() -> None:
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key. Run tools/assetgen/set-key.ps1 first.")
    ids = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as handle:
            ids = json.load(handle)
    print(f"uploading as {upload.creator()}")
    for name in NAMES:
        if ids.get(name):
            continue
        path = os.path.join(FOLDER, name + ".png")
        if not os.path.exists(path):
            print(f"  {name}: missing, run blender_bosstex.py")
            continue
        try:
            ids[name] = upload.upload(key, "Decal", path, "image/png", f"Astral Forge boss sprite {name}", "Original Astral Forge boss particle sprite (Blender).")
            print(f"  {name} -> {ids[name]}")
        except Exception as problem:
            print(f"  {name} FAILED: {problem}")
            continue
        with open(IDS, "w", encoding="utf-8") as handle:
            json.dump(ids, handle, indent=2)
            handle.write("\n")
    write_block(ids)
    print(f"{len(ids)}/{len(NAMES)} uploaded; SharedData.luau updated")


if __name__ == "__main__":
    main()