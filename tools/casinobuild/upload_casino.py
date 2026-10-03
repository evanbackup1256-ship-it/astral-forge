"""Upload the Blender-built casino kit and wire its model id into Shared/CasinoKit.luau.

    python tools/casinobuild/upload_casino.py           # uploads assets/generated/casino/CasinoKit.glb
    python tools/casinobuild/upload_casino.py --force   # upload again even if an id is saved

Roblox turns the GLB into a model of textured MeshParts ("Casino_<Piece>"); the server loads it with
InsertService at boot (CasinoKitLoader), so the game owner must own it. The id is kept in
assets/generated/casino/kit_id.json so a rebuild without --force does not upload twice.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "assetgen"))

import upload  # noqa: E402

FOLDER = os.path.join(ROOT, "assets", "generated", "casino")
GLB = os.path.join(FOLDER, "CasinoKit.glb")
SAVED = os.path.join(FOLDER, "kit_id.json")
MODULE = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "CasinoKit.luau")
ID_LINE = re.compile(r"(\bId\s*=\s*)\d+")


def write_module(asset_id):
    with open(MODULE, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    if not ID_LINE.search(source):
        sys.exit("No `Id = <number>` field in CasinoKit.luau")
    with open(MODULE, "w", encoding="utf-8", newline="") as handle:
        handle.write(ID_LINE.sub(lambda match: match.group(1) + str(int(asset_id)), source, count=1))


def main():
    if not os.path.exists(GLB):
        sys.exit("Build the kit first: blender -b --python tools/casinobuild/build_casino.py")
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key. Run tools/assetgen/set-key.ps1 first.")
    saved = {}
    if os.path.exists(SAVED):
        with open(SAVED, "r", encoding="utf-8") as handle:
            saved = json.load(handle)
    if saved.get("Id") and "--force" not in sys.argv:
        print(f"already uploaded as {saved['Id']} (use --force to upload again)")
        write_module(saved["Id"])
        return
    print(f"uploading as {upload.creator()}")
    asset_id = upload.upload(key, "Model", GLB, "model/gltf-binary", "Astral Forge casino kit",
                             "Original Astral Forge casino models (Blender): reel symbols, drum, coin, card, roulette wheel.")
    print(f"  CasinoKit -> {asset_id}")
    with open(SAVED, "w", encoding="utf-8") as handle:
        json.dump({"Id": asset_id}, handle, indent=2)
    write_module(asset_id)
    print("CasinoKit.luau updated")


if __name__ == "__main__":
    main()
