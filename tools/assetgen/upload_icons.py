"""Upload the icon atlas sheets (assets/generated/icons/icons_###.png) and point the manifest at them.

    python tools/assetgen/upload_icons.py          # uploads sheets that are new or changed since their upload
    python tools/assetgen/upload_icons.py --all    # re-upload every sheet
    python tools/assetgen/upload_icons.py --adopt  # record the sheets on disk as the ones already uploaded

A changed sheet loses its IconImage id; run resolve_icon_images.py afterwards.

Uses the same Open Cloud key and creator as upload.py. Sheets go up as Decals; the id Open Cloud
returns is the image the game draws. Ids are kept in assets/asset_ids.json as IconSheet000...
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import upload  # noqa: E402
import icons  # noqa: E402

ROOT = HERE.parents[1]
IDS = ROOT / "assets" / "asset_ids.json"
SHEETS = ROOT / "assets" / "generated" / "icons"


def main():
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key yet: run  powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1")
    ids = json.loads(IDS.read_text(encoding="utf-8")) if IDS.exists() else {}
    manifest = json.loads((SHEETS / "manifest.json").read_text(encoding="utf-8"))
    every = "--all" in sys.argv
    hashes = manifest.get("hashes") or [icons.sheet_hash(SHEETS / name) for name in manifest["sheets"]]
    if "--adopt" in sys.argv:
        for index in range(len(manifest["sheets"])):
            if ids.get(f"IconSheet{index:03d}"):
                ids[f"IconSheetHash{index:03d}"] = hashes[index]
        IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")
        print("recorded the sheets on disk as uploaded")
        return
    for index, name in enumerate(manifest["sheets"]):
        field = f"IconSheet{index:03d}"
        if ids.get(field) and ids.get(f"IconSheetHash{index:03d}") == hashes[index] and not every:
            continue
        print(f"uploading {name} ...")
        ids[field] = upload.upload(key, "Decal", str(SHEETS / name), "image/png", f"Astral Forge icons {index:03d}", "Astral Forge interface icons.")
        ids[f"IconSheetHash{index:03d}"] = hashes[index]
        ids.pop(f"IconImage{index:03d}", None)
        print(f"  -> {field} = {ids[field]}")
        IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")
    icons.write_luau(manifest["sheets"], manifest["icons"])
    print("manifest updated")


if __name__ == "__main__":
    main()
