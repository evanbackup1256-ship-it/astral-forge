"""Upload the original soundtrack beds. Does not touch the SFX manifest."""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import upload  # noqa: E402

ROOT = upload.ROOT
OUT = os.path.join(ROOT, "assets", "generated", "soundtrack")
IDS = upload.IDS

TRACKS = (
    ("ForgePulse", "ForgePulse.wav", "Astral Forge — Forge Pulse", "Original Astral Forge soundtrack. Foundry pulse."),
    ("SanctuaryDrift", "SanctuaryDrift.wav", "Astral Forge — Sanctuary Drift", "Original Astral Forge soundtrack. Sanctuary drift."),
    ("AstralOrbit", "AstralOrbit.wav", "Astral Forge — Astral Orbit", "Original Astral Forge soundtrack. Astral orbit."),
    ("BossSurge", "BossSurge.wav", "Astral Forge — Boss Surge", "Original Astral Forge soundtrack. Boss surge."),
    ("StarlitAnvil", "StarlitAnvil.wav", "Astral Forge - Starlit Anvil", "Original Astral Forge soundtrack. Lo-fi forge."),
    ("NebulaMarket", "NebulaMarket.wav", "Astral Forge - Nebula Market", "Original Astral Forge soundtrack. Market day."),
    ("EmberDrive", "EmberDrive.wav", "Astral Forge - Ember Drive", "Original Astral Forge soundtrack. Synthwave drive."),
    ("QuietOrbit", "QuietOrbit.wav", "Astral Forge - Quiet Orbit", "Original Astral Forge soundtrack. Ambient orbit."),
)


def main():
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key.")
    print(f"uploading as {upload.creator()}")
    ids = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as handle:
            ids = json.load(handle)
    for field, file_name, name, description in TRACKS:
        if ids.get(field):
            print(f"  skip {field} = {ids[field]}")
            continue
        path = os.path.join(OUT, file_name)
        print(f"uploading {file_name} ...")
        ids[field] = upload.upload(key, "Audio", path, "audio/wav", name, description)
        print(f"  -> {field} = {ids[field]}")
        with open(IDS, "w", encoding="utf-8") as handle:
            json.dump(ids, handle, indent=2)
            handle.write("\n")


if __name__ == "__main__":
    main()
