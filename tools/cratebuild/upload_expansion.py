"""Upload the baked expansion crate kit through Roblox Open Cloud and print its asset id.

    python tools/cratebuild/upload_expansion.py

Needs the Open Cloud key saved by tools/assetgen/set-key.ps1. Refuses to upload unless
build_expansion.py finished a full bake and export. Afterwards paste the id into the
Expansions entry of src/Shared/AstralForge/Shared/CrateKit.luau.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "assetgen"))
import upload  # noqa: E402

folder = ROOT / "assets" / "generated" / "crates"
status = json.loads((folder / "expansion_status.json").read_text(encoding="utf-8"))
if not status.get("exported") or status.get("completed") != 22:
    sys.exit("Run tools/cratebuild/build_expansion.py to a full bake + export first (22 meshes).")
key = upload.saved("ROBLOX_API_KEY")
if not key:
    sys.exit("No Open Cloud key yet: run  powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1")
asset_id = upload.upload(
    key, "Model", str(folder / "CrateKitExpansion.glb"), "model/gltf-binary",
    "Astral Forge Crate Expansion",
    "Eleven original body-and-lid crate rigs (Cinder to Halo) with baked textures.",
)
(folder / "expansion_kit_id.json").write_text(json.dumps({"Id": asset_id}, indent=2), encoding="utf-8")
print(f"Uploaded crate expansion kit: {asset_id}")
print("Paste it into Expansions[1].Id in src/Shared/AstralForge/Shared/CrateKit.luau")
