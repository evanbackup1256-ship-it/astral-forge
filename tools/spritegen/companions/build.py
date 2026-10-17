"""Build, verify, upload and activate the 57 elemental companion atlases.

python -m tools.spritegen.companions.build [names...]      render + verify (parallel)
python -m tools.spritegen.companions.build --upload        upload any atlas without an asset id
python -m tools.spritegen.companions.build --apply         point ElementSprites at the companions

Each atlas is 4096 square: 6 x 6 frames of 682 px, a seamless 36-frame loop. The aura is lit
into the frames themselves, so activation removes the separate AuraImage layer.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import zlib
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

from . import core
from .registry import CONCEPTS, DESIGNS, load_all

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "generated" / "sprites" / "companions"
MODULE = ROOT / "src" / "Shared" / "AstralForge" / "Shared" / "ElementSprites.luau"
ENTRY = re.compile(r"\t(\w+) = \{ Image = \"rbxassetid://\d+\"(?:, AuraImage = \"[^\"]+\")?, "
                   r"Color = Color3\.fromRGB\(([^)]+)\), Glow = Color3\.fromRGB\(([^)]+)\)")


def colors_for() -> dict[str, tuple[tuple[int, int, int], tuple[int, int, int]]]:
    source = MODULE.read_text(encoding="utf-8")
    out = {}
    for name, color, glow in ENTRY.findall(source):
        out[name] = (tuple(map(int, color.split(","))), tuple(map(int, glow.split(","))))
    return out


def blink_frame(name: str) -> int:
    # spread blinks so a grid of companions never blinks in unison
    return 4 + zlib.crc32(name.encode()) % 26


def canvas_for(name: str, index: int, colors) -> core.Canvas:
    color, glow = colors[name]
    start = blink_frame(name)
    return core.Canvas(name=name, t=index / core.COUNT, index=index, blink=index in (start, start + 1),
                       color=color, glow=glow)


def _save(image: Image.Image, path: Path, **options) -> None:
    # OneDrive briefly locks files it is syncing; write aside, then swap in with retries
    temporary = path.with_name(path.stem + ".partial.png")
    image.save(temporary, **options)
    for attempt in range(20):
        try:
            temporary.replace(path)
            return
        except OSError:
            time.sleep(0.5 * (attempt + 1))
    raise OSError(f"could not replace {path} (locked)")


def _render_atlas(name: str) -> tuple[str, str]:
    load_all()
    colors = colors_for()
    atlas = Image.new("RGBA", (core.EDGE, core.EDGE))
    for index in range(core.COUNT):
        canvas = canvas_for(name, index, colors)
        DESIGNS[name](canvas)
        frame = core.render(canvas)
        atlas.paste(frame, (index % core.COLUMNS * core.FRAME, index // core.COLUMNS * core.FRAME))
        if index == 0:
            _save(frame, OUT / f"{name.lower()}_still.png")
    path = OUT / f"{name.lower()}.png"
    _save(atlas, path, compress_level=6)
    return name, hashlib.sha256(path.read_bytes()).hexdigest()


def verify(name: str, record: dict) -> None:
    path = OUT / f"{name.lower()}.png"
    if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        raise ValueError(f"{name}: manifest hash mismatch")
    with Image.open(path) as atlas:
        if atlas.size != (core.EDGE, core.EDGE) or atlas.mode != "RGBA":
            raise ValueError(f"{name}: invalid atlas")
        hashes = set()
        for index in range(core.COUNT):
            x, y = index % core.COLUMNS * core.FRAME, index // core.COLUMNS * core.FRAME
            frame = atlas.crop((x, y, x + core.FRAME, y + core.FRAME))
            alpha = frame.getchannel("A")
            # visible content must stay off the frame edge (halo fades before it)
            solid = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
            if solid is None or min(solid) <= 2 or max(solid) >= core.FRAME - 2:
                raise ValueError(f"{name}: empty or clipped frame {index} {solid}")
            hashes.add(hashlib.sha256(frame.tobytes()).digest())
        if len(hashes) < 24:
            raise ValueError(f"{name}: idle loop is not animated ({len(hashes)} distinct frames)")


def save_manifest(records: dict) -> None:
    temporary = OUT / "manifest.tmp"
    temporary.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for attempt in range(12):
        try:
            temporary.replace(OUT / "manifest.json")
            return
        except PermissionError:
            time.sleep(0.5 * (attempt + 1))
    raise PermissionError("manifest locked")


def generator_hash() -> str:
    digest = hashlib.sha256()
    for path in sorted(Path(__file__).parent.glob("*.py")):
        digest.update(path.read_bytes())
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*")
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--jobs", type=int, default=10)
    args = parser.parse_args()
    load_all()
    colors = colors_for()
    if set(colors) != set(DESIGNS) or len(colors) != 57:
        missing = sorted(set(colors) - set(DESIGNS))
        extra = sorted(set(DESIGNS) - set(colors))
        if not args.names:
            raise ValueError(f"every element needs exactly one design; missing {missing} extra {extra}")
    selected = args.names or sorted(colors)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = OUT / "manifest.json"
    records = json.loads(manifest.read_text()) if manifest.exists() else {}
    generator = generator_hash()
    stale = [n for n in selected if records.get(n, {}).get("generator") != generator
             or not (OUT / f"{n.lower()}.png").exists()]
    if stale and not args.apply:
        with ProcessPoolExecutor(max_workers=args.jobs) as pool:
            for name, digest in pool.map(_render_atlas, stale):
                previous = records.get(name, {})
                records[name] = {"generator": generator, "sha256": digest, "size": core.EDGE, "frame": core.FRAME,
                                 "count": core.COUNT, "concept": CONCEPTS[name]}
                if previous.get("sha256") == digest and previous.get("assetId"):
                    records[name]["assetId"] = previous["assetId"]
                save_manifest(records)
                print(f"[COMPANION] {name}: rendered", flush=True)
    failures = []
    for name in selected:
        try:
            verify(name, records[name])
        except ValueError as error:
            failures.append(str(error))
    if failures:
        raise ValueError("verification failed:\n  " + "\n  ".join(failures))
    print(f"[COMPANION] verified {len(selected)}", flush=True)
    if args.upload:
        sys.path.insert(0, str(ROOT / "tools" / "assetgen"))
        import upload

        key = upload.saved("ROBLOX_API_KEY")
        if not key:
            raise RuntimeError("No Open Cloud key configured (tools/assetgen/set-key.ps1)")
        for name in selected:
            if records[name].get("assetId"):
                continue
            records[name]["assetId"] = upload.upload(
                key, "Image", str(OUT / f"{name.lower()}.png"), "image/png", f"AF {name} Companion",
                f"Astral Forge {name} companion: original character with its elemental light lit into every frame.")
            save_manifest(records)
            print(f"[COMPANION] {name}: uploaded {records[name]['assetId']}", flush=True)
    if args.apply:
        if set(records) != set(colors):
            raise ValueError("Do not activate a partial companion collection")
        for name, record in records.items():
            verify(name, record)
            if not str(record.get("assetId", "")).isdigit():
                raise ValueError(f"{name}: not uploaded")
        source = MODULE.read_text(encoding="utf-8")
        pattern = r'(\t(\w+) = \{ Image = ")rbxassetid://\d+"(?:, AuraImage = "[^"]+")?'
        source, count = re.subn(pattern, lambda m: m[1] + "rbxassetid://" + str(records[m[2]]["assetId"]) + '"', source)
        if count != 57:
            raise ValueError("expected 57 sprite entries")
        MODULE.write_text(source, encoding="utf-8", newline="\n")
        print("[COMPANION] activated 57 lit companions; separate aura layers removed")


if __name__ == "__main__":
    main()
