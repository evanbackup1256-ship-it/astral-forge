"""Upload the Blender-built boss bodies and wire the model ids in.

    python tools/bossbuild/upload_bodies.py

Each boss is its own GLB in assets/generated/bosses/ (textured pieces named "<Kind>_<piece>").
Roblox takes every GLB as a separate model, so each is uploaded on its own; the ids go into
BOSS-BODYKIT in SharedData.luau as { Kind = id } and the server publishes all the pieces for
clients. Bosses already uploaded are skipped (bodykit_ids.json). The game owner must own them.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "assetgen"))

import upload  # noqa: E402

FOLDER = os.path.join(ROOT, "assets", "generated", "bosses")
IDS = os.path.join(FOLDER, "bodykit_ids.json")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
BEGIN, END = "-- BOSS-BODYKIT-BEGIN", "-- BOSS-BODYKIT-END"


def write_block(ids):
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    rows = [f"\t{kind} = {int(asset)}," for kind, asset in sorted(ids.items()) if asset]
    body = newline.join([BEGIN + " (rewritten by tools/bossbuild/upload_bodies.py)", "SanctuaryConfig.BossBodyKit = {"] + rows + ["}", END])
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-BODYKIT block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main():
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key. Run tools/assetgen/set-key.ps1 first.")
    ids = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as handle:
            ids = json.load(handle)
    print(f"uploading as {upload.creator()}")
    for name in sorted(os.listdir(FOLDER)):
        match = re.fullmatch(r"(\w+)\.glb", name)
        if not match:
            continue
        kind = match.group(1)
        if ids.get(kind):
            continue
        try:
            ids[kind] = upload.upload(key, "Model", os.path.join(FOLDER, name), "model/gltf-binary", f"Astral Forge boss body {kind}", "Original Astral Forge boss body (Blender).")
            print(f"  {kind} -> {ids[kind]}")
        except Exception as problem:
            print(f"  {kind} FAILED: {problem}")
            continue
        with open(IDS, "w", encoding="utf-8") as handle:
            json.dump(ids, handle, indent=2)
    write_block(ids)
    print(f"{len(ids)} bodies uploaded; SharedData.luau updated")


if __name__ == "__main__":
    main()
