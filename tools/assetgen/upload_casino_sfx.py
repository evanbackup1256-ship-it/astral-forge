"""Upload the Astral Casino sound effects (from casino_sfx_gen.py) and write the ids into Shared/CasinoSfx.luau.

    python tools/assetgen/upload_casino_sfx.py

Skips what is already uploaded (assets/generated/bosssfx/sfx_ids.json) and rewrites the
BOSS-SFX block in SharedData.luau. Until then the bosses use their existing cues.
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
FOLDER = os.path.join(ROOT, "assets", "generated", "casinosfx")
NAMES = os.path.join(FOLDER, "sfx_names.json")
IDS = os.path.join(FOLDER, "sfx_ids.json")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "CasinoSfx.luau")
BEGIN, END = "-- BOSS-SFX-BEGIN", "-- BOSS-SFX-END"


def write_block(ids: dict) -> None:
    entries = [f"\t{name} = {int(asset)}," for name, asset in sorted(ids.items()) if asset]
    text = "\n".join(["--!strict", "-- Uploaded casino sound effects: name -> audio id. Rewritten by tools/assetgen/upload_casino_sfx.py; a missing", "-- name just plays nothing.", "return table.freeze({"] + entries + ["})", ""])
    with open(DATA, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


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
            ids[name] = upload.upload(key, "Audio", os.path.join(FOLDER, name + ".wav"), "audio/wav", f"Astral Forge casino sfx {name}", "Original Astral Forge casino effect.")
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