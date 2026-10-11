"""Redraw all 57 elemental animations natively into lossless 4096-square atlases.

Run: python tools/spritegen/build_elements_hq.py [names...]
Add --upload to upload changed sheets using the existing Open Cloud credentials.
The legacy atlas/IDs remain untouched until every replacement has been verified.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

os.environ["AF_ELEMENT_FRAME"] = "682"

import build_elements as base
import build_elements_ext  # Registers the remaining elemental designs.
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "generated" / "sprites" / "hq"
MANIFEST = OUT / "manifest.json"
EDGE = 4096


def render(name: str) -> Path:
    path = OUT / f"{name}.png"
    frames = base.ELEMENTS[name]()
    if len(frames) != 36 or any(frame.size != (682, 682) or frame.mode != "RGBA" for frame in frames):
        raise ValueError(f"{name}: expected 36 native 682-square RGBA frames")
    sheet = Image.new("RGBA", (EDGE, EDGE))
    for index, frame in enumerate(frames):
        sheet.paste(frame, ((index % 6) * 682, (index // 6) * 682))
    sheet.save(path, compress_level=6)
    preview = frames[14]
    preview.save(OUT / f"{name}_still.png", compress_level=6)
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*", choices=sorted(base.ELEMENTS))
    parser.add_argument("--upload", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    uploader = None
    key = None
    if args.upload:
        import sys

        sys.path.insert(0, str(ROOT / "tools" / "assetgen"))
        import upload

        uploader = upload
        key = uploader.saved("ROBLOX_API_KEY")
        if not key:
            raise RuntimeError("No Open Cloud key configured; no assets uploaded")
    generator_hash = hashlib.sha256(
        Path(base.__file__).read_bytes()
        + Path(build_elements_ext.__file__).read_bytes()
        + Path(__file__).read_bytes()
    ).hexdigest()
    for name in args.names or base.ELEMENTS:
        record = manifest.get(name, {})
        path = OUT / f"{name}.png"
        if not path.exists() or record.get("generator") != generator_hash:
            print(f"[4K] redrawing {name}", flush=True)
            path = render(name)
        with Image.open(path) as image:
            if image.size != (EDGE, EDGE) or image.mode != "RGBA":
                raise ValueError(f"{name}: invalid 4K image")
            image.verify()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if record.get("sha256") != digest:
            record = {"sha256": digest, "generator": generator_hash, "size": EDGE, "frame": 682, "count": 36}
        record["generator"] = generator_hash
        if uploader is not None and not record.get("assetId"):
            print(f"[4K] uploading {name}", flush=True)
            record["assetId"] = uploader.upload(
                key, "Image", str(path), "image/png", f"AF Element {name} 4K",
                f"Native 4096x4096 Astral Forge {name} animation atlas, 36 high-detail frames.",
            )
        manifest[name] = record
        temporary = MANIFEST.with_suffix(".tmp")
        temporary.write_text(json.dumps(manifest, indent=2) + "\n")
        temporary.replace(MANIFEST)
        print(f"[4K] {name}: verified 4096x4096, 36 native frames", flush=True)


if __name__ == "__main__":
    main()
