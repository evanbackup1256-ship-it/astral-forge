"""Turn the uploaded icon decals into the image ids the game draws, then rewrite the manifest.

Open Cloud returns a Decal id for an image upload; an ImageLabel needs the Image inside it. Studio
can read that (InsertService:LoadAsset on your own decal), so this asks the running Studio through
the MCP bridge (the scratch studio.py) to load each decal and report its Texture.

    python tools/assetgen/resolve_icon_images.py path/to/studio.py [Edit|Server]
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import icons  # noqa: E402

ROOT = HERE.parents[1]
IDS = ROOT / "assets" / "asset_ids.json"
SHEETS = ROOT / "assets" / "generated" / "icons"
# Edit when Studio is idle; Server works too while a Play session is running
DATAMODEL = sys.argv[2] if len(sys.argv) > 2 else "Edit"


def ask_studio(studio: str, decals: list[int]) -> list[str]:
    code = (
        "local out = {} local ids = {" + ",".join(str(d) for d in decals) + "} "
        "for i, id in ids do local ok, model = pcall(function() return game:GetService('InsertService'):LoadAsset(id) end) "
        "local tex = '' if ok and model then local d = model:FindFirstChildWhichIsA('Decal', true) tex = d and d.Texture or '' model:Destroy() end "
        "out[i] = tex end return table.concat(out, ',')"
    )
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump({"datamodel_type": DATAMODEL, "code": code}, f)
        args = f.name
    result = subprocess.run([sys.executable, studio, "execute_luau", "@" + args], capture_output=True, text=True, encoding="utf-8")
    return result.stdout.strip().split(",")


def main():
    studio = sys.argv[1]
    ids = json.loads(IDS.read_text(encoding="utf-8"))
    manifest = json.loads((SHEETS / "manifest.json").read_text(encoding="utf-8"))
    pending = [i for i in range(len(manifest["sheets"])) if ids.get(f"IconSheet{i:03d}") and not ids.get(f"IconImage{i:03d}")]
    for start in range(0, len(pending), 20):
        batch = pending[start:start + 20]
        textures = ask_studio(studio, [ids[f"IconSheet{i:03d}"] for i in batch])
        for i, tex in zip(batch, textures):
            digits = "".join(ch for ch in tex if ch.isdigit())
            if digits:
                ids[f"IconImage{i:03d}"] = int(digits)
                print(f"sheet {i:03d}: decal {ids[f'IconSheet{i:03d}']} -> image {digits}")
            else:
                print(f"sheet {i:03d}: no image yet ({tex!r})")
        IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")
    icons.write_luau(manifest["sheets"], manifest["icons"])
    missing = [i for i in range(len(manifest["sheets"])) if not ids.get(f"IconImage{i:03d}")]
    print(f"manifest updated; {len(manifest['sheets']) - len(missing)} sheets live, {len(missing)} missing")


if __name__ == "__main__":
    main()
