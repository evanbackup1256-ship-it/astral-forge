"""Upload only a completed, baked crate kit through Roblox Open Cloud."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assetgen"))
import upload

folder = ROOT / "assets/generated/crates"
status = json.loads((folder / "bake_status.json").read_text())
if status.get("completed") != 40 or not status.get("exported"):
    raise RuntimeError("The complete 40-part texture bake and export is required")
key = upload.saved("ROBLOX_API_KEY")
if not key:
    raise RuntimeError("Roblox Open Cloud key is unavailable")
asset_id = upload.upload(
    key, "Model", str(folder / "CrateKit.glb"), "model/gltf-binary",
    "Astral Forge Crate Workshop",
    "Twenty original animated body-and-lid crate rigs with baked Blender textures.",
)
(folder / "kit_id.json").write_text(json.dumps({"Id": asset_id}, indent=2))
print(f"Uploaded crate kit: {asset_id}")
