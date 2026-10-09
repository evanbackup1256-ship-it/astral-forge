"""Upload generated element sprite sheets to Roblox as images.

Usage:  python tools/spritegen/upload_sprites.py [names...]
Ids are kept in assets/generated/sprites/ids.json so reruns only upload what is missing.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SPRITES = os.path.join(ROOT, "assets", "generated", "sprites")
IDS = os.path.join(SPRITES, "ids.json")

sys.path.insert(0, os.path.join(ROOT, "tools", "assetgen"))
import upload as up  # noqa: E402


def main():
    key = up.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key: run tools/assetgen/set-key.ps1")
    ids = {}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as f:
            ids = json.load(f)
    names = sys.argv[1:]
    if not names:
        import build_elements_ext as ext

        names = list(ext.WAVE.keys())
    for name in names:
        if ids.get(name):
            continue
        path = os.path.join(SPRITES, f"{name}.png")
        print(f"uploading {name} ...", flush=True)
        ids[name] = up.upload(key, "Image", path, "image/png", f"AF Element {name}", f"Astral Forge {name} element sprite sheet.")
        print(f"  -> {ids[name]}", flush=True)
        with open(IDS, "w", encoding="utf-8") as f:
            json.dump(ids, f, indent=2)


if __name__ == "__main__":
    main()
