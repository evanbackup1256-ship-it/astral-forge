"""Upload the v2 brand art, turn each Decal into its image id, and point the game at it.

    python tools/assetgen/upload_logo.py upload                      Open Cloud upload (as Decals); safe to re-run
    python tools/assetgen/upload_logo.py resolve path/to/studio.py   ask a running Studio for each Decal's image id
    python tools/assetgen/upload_logo.py activate                    write the ids into ArtKit/Icon.tsx

The key comes from tools/assetgen/set-key.ps1 (the saved ROBLOX_API_KEY). Uploads are skipped for any
image whose bytes have not changed since the id in assets/asset_ids.json was recorded.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import upload  # noqa: E402

ROOT = HERE.parents[1]
IDS = ROOT / "assets" / "asset_ids.json"
ART = ROOT / "assets" / "generated" / "branding"
ICON_TSX = ROOT / "src" / "Client" / "AstralForge" / "ArtKit" / "Icon.tsx"

# id key -> (file, constant in ArtKit/Icon.tsx, display name)
ASSETS = {
    "BrandV2Wordmark": ("wordmark.png", "WORDMARK_ASSET", "Astral Forge wordmark"),
    "BrandV2Mark": ("compact-mark.png", "COMPACT_MARK_ASSET", "Astral Forge badge"),
    "BrandV2Lockup": ("lockup.png", "LOCKUP_ASSET", "Astral Forge lockup"),
    "BrandV2GameIcon": ("game-icon.png", "GAME_ICON_ASSET", "Astral Forge game icon"),
    "BrandV2MarkBase": ("mark-base.png", "MARK_BASE_ASSET", "Astral Forge badge, base layer"),
    "BrandV2MarkStar": ("mark-star.png", "MARK_STAR_ASSET", "Astral Forge badge, star layer"),
    "BrandV2MarkGlow": ("mark-glow.png", "MARK_GLOW_ASSET", "Astral Forge badge, glow sprite"),
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def load_ids() -> dict:
    return json.loads(IDS.read_text(encoding="utf-8")) if IDS.exists() else {}


def do_upload():
    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key yet: run  powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1")
    ids = load_ids()
    print("uploading as", upload.creator())
    for name, (file, _const, label) in ASSETS.items():
        path = ART / file
        h = digest(path)
        if ids.get(name) and ids.get(name + "Hash") == h:
            print(f"{file}: already uploaded ({ids[name]})")
            continue
        print(f"uploading {file} ...")
        ids[name] = upload.upload(key, "Decal", str(path), "image/png", label, "Astral Forge brand artwork.")
        ids[name + "Hash"] = h
        ids.pop(name + "Image", None)
        IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")
        print("  ->", ids[name], "(decal id; run resolve next)")


def ask_studio(studio: str, decals: list[int], datamodel: str) -> list[str]:
    code = (
        "local out = {} local ids = {" + ",".join(str(d) for d in decals) + "} "
        "for i, id in ids do local ok, model = pcall(function() return game:GetService('InsertService'):LoadAsset(id) end) "
        "local tex = '' if ok and model then local d = model:FindFirstChildWhichIsA('Decal', true) tex = d and d.Texture or '' model:Destroy() end "
        "out[i] = tex end return table.concat(out, ',')"
    )
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump({"datamodel_type": datamodel, "code": code}, f)
        args = f.name
    result = subprocess.run([sys.executable, studio, "execute_luau", "@" + args], capture_output=True, text=True, encoding="utf-8")
    return result.stdout.strip().split(",")


def do_resolve(studio: str, datamodel: str):
    ids = load_ids()
    names = [n for n in ASSETS if ids.get(n)]
    textures = ask_studio(studio, [ids[n] for n in names], datamodel)
    for name, tex in zip(names, textures):
        digits = "".join(ch for ch in tex if ch.isdigit())
        if digits:
            ids[name + "Image"] = int(digits)
            print(f"{ASSETS[name][0]}: decal {ids[name]} -> image {digits}")
        else:
            print(f"{ASSETS[name][0]}: no image yet ({tex!r}); the decal may still be in moderation, run resolve again in a minute")
    IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")


def do_activate():
    ids = load_ids()
    text = ICON_TSX.read_text(encoding="utf-8")
    crlf = "\r\n" in text
    text = text.replace("\r\n", "\n")
    missing = []
    for name, (file, const, _label) in ASSETS.items():
        image = ids.get(name + "Image")
        if not image:
            missing.append(file)
            continue
        pattern = re.compile(r'(export const %s = )"[^"]*";' % const)
        if not pattern.search(text):
            sys.exit(f"{const} not found in {ICON_TSX}")
        text = pattern.sub(lambda m: f'{m.group(1)}"rbxassetid://{image}";', text)
    if missing:
        sys.exit("no image id yet for: " + ", ".join(missing) + " (upload, then resolve)")
    if crlf:
        text = text.replace("\n", "\r\n")
    ICON_TSX.write_text(text, encoding="utf-8", newline="")
    print("ArtKit/Icon.tsx now points at the v2 brand art")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "upload":
        do_upload()
    elif command == "resolve":
        do_resolve(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "Server")
    elif command == "activate":
        do_activate()
    else:
        sys.exit(__doc__)
