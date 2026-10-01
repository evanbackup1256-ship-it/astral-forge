"""Upload the boss VFX meshes (made by blender_bossvfx.py) as one model and wire the id in.

    python tools/assetgen/upload_boss_vfx.py

The server loads the model at boot (RiftBossService:_loadVfxKit) and publishes each mesh
for clients. The game owner must own the uploaded asset. Re-running skips if already uploaded.
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
GLB = os.path.join(ROOT, "assets", "generated", "BossVfxKit.glb")
IDS = os.path.join(ROOT, "assets", "generated", "bossvfxkit_id.json")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
BEGIN, END = "-- BOSS-VFXKIT-BEGIN", "-- BOSS-VFXKIT-END"


def write_block(asset: int) -> None:
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    body = newline.join([BEGIN + " (rewritten by tools/assetgen/upload_boss_vfx.py)", f"SanctuaryConfig.BossVfxKit = {{ Id = {int(asset)} }}", END])
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-VFXKIT block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main() -> None:
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key. Run tools/assetgen/set-key.ps1 first.")
    if not os.path.exists(GLB):
        sys.exit("Run blender_bossvfx.py first.")
    stored = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as handle:
            stored = json.load(handle)
    if not stored.get("Id"):
        print(f"uploading as {upload.creator()}")
        stored["Id"] = upload.upload(key, "Model", GLB, "model/gltf-binary", "Astral Forge Boss VFX", "Original Astral Forge boss VFX meshes (Blender).")
        with open(IDS, "w", encoding="utf-8") as handle:
            json.dump(stored, handle)
    write_block(stored["Id"])
    print(f"boss VFX kit = {stored['Id']}; SharedData.luau updated")


if __name__ == "__main__":
    main()