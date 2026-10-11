"""Author elemental companions as clean, outlined character animation atlases.

No old effect image is sampled. Each silhouette is drawn at native resolution.
Run with --upload to publish the complete set, then --apply to activate it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "generated" / "sprites" / "characters"
MODULE = ROOT / "src" / "Shared" / "AstralForge" / "Shared" / "ElementSprites.luau"
FRAME, EDGE, COUNT = 682, 4096, 36
INK = (26, 30, 43, 255)
CREAM = (255, 245, 218, 255)

# Each family has a different body, gait and material treatment, not a diamond
# with a face. Accessories identify individual companions within each family.
FAMILIES = {
    "flame": "Fire Magma Solar Plasma Frostfire",
    "cloud": "Steam Wind Blizzard Tempest Smoke Sonic",
    "drop": "Water Blood Poison Ink Abyss Vital",
    "stone": "Earth Steel Gold Amber Magnet Gravity",
    "crystal": "Ice Crystal Prism Mirror Hologram Quantum",
    "sprout": "Nature Thorn Spore Bloom Feather",
    "spirit": "Void Shadow Spirit Arcane Rift Necrotic Rune Dream Aether Glitch",
    "moth": "Cosmic Nebula Aurora Lunar Comet Eclipse Starlight Celestial Radiance Chrono Lightning Neon Sand",
}
FAMILY = {name: family for family, names in FAMILIES.items() for name in names.split()}


def palette() -> dict[str, tuple[int, int, int]]:
    source = MODULE.read_text(encoding="utf-8")
    return {
        name: tuple(map(int, channels.split(",")))
        for name, channels in re.findall(r"\t(\w+) = \{ Image = .*?Color = Color3.fromRGB\(([^)]+)\)", source)
    }


def blend(color: tuple[int, ...], other: tuple[int, ...], amount: float) -> tuple[int, int, int, int]:
    return tuple(round(color[i] * (1 - amount) + other[i] * amount) for i in range(3)) + (255,)


def draw_frame(name: str, color: tuple[int, int, int], index: int) -> Image.Image:
    phase = index / COUNT * math.tau
    bob = math.sin(phase) * 0.009
    sway = math.sin(phase + 0.5) * 0.012
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    base = color + (255,)
    light = blend(color, CREAM, 0.48)
    dark = blend(color, INK, 0.25)
    identity = sum((i + 1) * ord(c) for i, c in enumerate(name))
    family = FAMILY[name]

    def xy(x: float, y: float) -> tuple[int, int]:
        return round((x + sway) * FRAME), round((y + bob) * FRAME)

    def ellipse(box: tuple[float, float, float, float], fill: tuple[int, ...], outline: bool = True) -> None:
        draw.ellipse((*xy(box[0], box[1]), *xy(box[2], box[3])), fill=fill,
                     outline=INK if outline else None, width=8)

    def polygon(points: list[tuple[float, float]], fill: tuple[int, ...], outline: bool = True) -> None:
        pts = [xy(x, y) for x, y in points]
        draw.polygon(pts, fill=fill)
        if outline:
            draw.line(pts + pts[:1], fill=INK, width=8, joint="curve")

    def line(points: list[tuple[float, float]], fill: tuple[int, ...] = INK, width: int = 7) -> None:
        draw.line([xy(x, y) for x, y in points], fill=fill, width=width, joint="curve")

    # Contact shadow is modest and fixed; it is not a bloom or particle field.
    draw.ellipse((round(FRAME * 0.27), round(FRAME * 0.81), round(FRAME * 0.74), round(FRAME * 0.85)),
                 fill=(16, 20, 32, 28))
    ellipse((0.28, 0.73, 0.45, 0.83), dark)
    ellipse((0.55, 0.73, 0.72, 0.83), dark)
    left_hand_y = 0.57 + math.sin(phase) * 0.012
    ellipse((0.18, left_hand_y, 0.34, left_hand_y + 0.14), base)
    ellipse((0.67, 0.56, 0.82, 0.7), base)
    face_y = 0.52

    if family == "flame":
        polygon([(0.25, 0.66), (0.22, 0.51), (0.29, 0.32), (0.35, 0.42),
                 (0.47 + math.sin(phase) * 0.03, 0.15), (0.59, 0.3), (0.6, 0.42),
                 (0.71, 0.33), (0.79, 0.53), (0.73, 0.73), (0.58, 0.79), (0.4, 0.79)], base)
        polygon([(0.34, 0.68), (0.36, 0.5), (0.47, 0.38), (0.51, 0.49),
                 (0.62, 0.41), (0.69, 0.61), (0.62, 0.74), (0.42, 0.75)], light, False)
        if name == "Magma":
            line([(0.29, 0.48), (0.36, 0.56), (0.29, 0.62)], dark, 12)
        if name == "Frostfire":
            polygon([(0.58, 0.3), (0.69, 0.42), (0.73, 0.58), (0.65, 0.7), (0.61, 0.51)],
                    (150, 226, 255, 255), False)
    elif family == "cloud":
        ellipse((0.25, 0.39, 0.74, 0.79), base)
        ellipse((0.23, 0.3, 0.51, 0.59), base)
        ellipse((0.4, 0.23, 0.66, 0.55), light)
        ellipse((0.57, 0.34, 0.81, 0.62), base)
        # One brow tuft, not constant surrounding swirls.
        line([(0.32, 0.37), (0.38, 0.34), (0.42, 0.36)], dark, 10)
        if name in {"Tempest", "Sonic"}:
            polygon([(0.69, 0.39), (0.74, 0.45), (0.69, 0.54), (0.74, 0.51)], CREAM)
    elif family == "drop":
        polygon([(0.29, 0.48), (0.47, 0.21), (0.55, 0.28), (0.68, 0.43),
                 (0.75, 0.57), (0.73, 0.72), (0.64, 0.79), (0.37, 0.79),
                 (0.27, 0.68), (0.25, 0.57)], base)
        ellipse((0.32, 0.38, 0.44, 0.55), light, False)
        ellipse((0.32, 0.66, 0.69, 0.77), light, False)
        if name in {"Poison", "Ink"}:
            ellipse((0.59, 0.32, 0.69, 0.41), dark)
    elif family == "stone":
        polygon([(0.27, 0.37), (0.4, 0.27), (0.66, 0.3), (0.77, 0.44),
                 (0.75, 0.72), (0.65, 0.8), (0.35, 0.79), (0.24, 0.68)], base)
        polygon([(0.28, 0.37), (0.4, 0.28), (0.65, 0.31), (0.69, 0.4), (0.34, 0.43)], light, False)
        line([(0.28, 0.58), (0.34, 0.61), (0.29, 0.7)], dark)
        line([(0.66, 0.32), (0.63, 0.4), (0.7, 0.45)], dark)
        if name == "Magnet":
            polygon([(0.28, 0.37), (0.39, 0.32), (0.42, 0.41), (0.31, 0.46)], (120, 180, 255, 255))
    elif family == "crystal":
        polygon([(0.28, 0.44), (0.38, 0.28), (0.45, 0.39), (0.52, 0.16),
                 (0.62, 0.36), (0.73, 0.26), (0.75, 0.53), (0.7, 0.77),
                 (0.33, 0.78), (0.25, 0.63)], base)
        polygon([(0.4, 0.39), (0.52, 0.18), (0.56, 0.4), (0.45, 0.47)], light, False)
        line([(0.3, 0.67), (0.38, 0.7), (0.35, 0.76)], dark)
        polygon([(0.64, 0.4), (0.72, 0.3), (0.71, 0.53)], CREAM, False)
    elif family == "sprout":
        ellipse((0.26, 0.35, 0.76, 0.8), base)
        line([(0.51, 0.38), (0.52, 0.25)], dark, 15)
        polygon([(0.52, 0.29), (0.35, 0.18), (0.31, 0.2), (0.38, 0.31), (0.51, 0.33)], light)
        polygon([(0.51, 0.28), (0.64, 0.17), (0.74, 0.18), (0.64, 0.3), (0.52, 0.33)], base)
        ellipse((0.33, 0.62, 0.68, 0.77), light, False)
        if name == "Spore":
            ellipse((0.24, 0.25, 0.79, 0.45), (228, 207, 154, 255))
            for x, y in [(0.36, 0.32), (0.52, 0.3), (0.67, 0.35)]:
                ellipse((x - 0.03, y - 0.02, x + 0.03, y + 0.02), CREAM, False)
        if name == "Bloom":
            for petal in range(5):
                angle = petal * math.tau / 5
                x, y = 0.56 + math.cos(angle) * 0.06, 0.29 + math.sin(angle) * 0.06
                ellipse((x - 0.045, y - 0.04, x + 0.045, y + 0.04), light)
            ellipse((0.53, 0.26, 0.59, 0.32), CREAM, False)
    elif family == "spirit":
        polygon([(0.24, 0.76), (0.26, 0.46), (0.33, 0.28), (0.49, 0.23),
                 (0.67, 0.29), (0.75, 0.47), (0.77, 0.76), (0.66, 0.69),
                 (0.58, 0.78), (0.48, 0.7), (0.36, 0.78)], base)
        ellipse((0.33, 0.37, 0.67, 0.7), light, False)
        # A stitched cowl gives the spirit an authored, tactile identity.
        line([(0.3, 0.5), (0.29, 0.64)], dark)
        for y in [0.53, 0.58, 0.63]:
            line([(0.27, y), (0.31, y + 0.01)], light, 5)
        if name in {"Rune", "Arcane", "Chrono"}:
            polygon([(0.5, 0.27), (0.54, 0.32), (0.5, 0.36), (0.46, 0.32)], CREAM)
    else:
        wing = math.sin(phase) * 0.025
        polygon([(0.37, 0.42), (0.2 + wing, 0.3), (0.17, 0.5),
                 (0.27, 0.66), (0.36, 0.65)], light)
        polygon([(0.64, 0.42), (0.8 - wing, 0.3), (0.83, 0.5),
                 (0.73, 0.66), (0.64, 0.65)], light)
        ellipse((0.31, 0.31, 0.7, 0.8), base)
        line([(0.41, 0.34), (0.36, 0.2), (0.32, 0.18)], INK, 8)
        line([(0.59, 0.34), (0.64, 0.2), (0.68, 0.18)], INK, 8)
        ellipse((0.28, 0.14, 0.36, 0.22), light)
        ellipse((0.64, 0.14, 0.72, 0.22), light)
        ellipse((0.35, 0.63, 0.66, 0.77), light, False)
        if name in {"Lightning", "Neon"}:
            polygon([(0.48, 0.33), (0.55, 0.33), (0.5, 0.4), (0.55, 0.4), (0.45, 0.47)], CREAM)
        elif name in {"Lunar", "Eclipse"}:
            ellipse((0.43, 0.32, 0.57, 0.45), CREAM, False)
            ellipse((0.48, 0.3, 0.6, 0.43), base, False)
        elif name == "Chrono":
            ellipse((0.44, 0.32, 0.57, 0.45), CREAM)
            line([(0.505, 0.34), (0.505, 0.385), (0.54, 0.39)], INK, 4)

    # A small signature mark and asymmetric expression make relatives distinct.
    mark = identity % 3
    if mark == 0:
        for x in [0.33, 0.35, 0.37]:
            ellipse((x, 0.6, x + 0.014, 0.615), dark, False)
    elif mark == 1:
        line([(0.65, 0.61), (0.68, 0.6)], dark, 6)
    else:
        ellipse((0.64, 0.61, 0.67, 0.64), light, False)

    gaze = math.sin(phase) * 0.008
    blink = index in {27, 28}
    sleepy = name in {"Dream", "Smoke", "Gravity"}
    for x in [0.405, 0.595]:
        if blink:
            line([(x - 0.037, face_y + 0.015), (x, face_y + 0.025), (x + 0.037, face_y + 0.015)], INK, 9)
        else:
            ellipse((x - 0.04, face_y - (0.02 if sleepy else 0.04), x + 0.04, face_y + 0.048), INK, False)
            ellipse((x - 0.014 + gaze, face_y - 0.018, x + 0.006 + gaze, face_y + 0.005), CREAM, False)
    line([(0.465, face_y + 0.09), (0.5, face_y + 0.105), (0.535, face_y + 0.09)], INK, 6)
    return image


def save_manifest(records: dict) -> None:
    temporary = OUT / "manifest.tmp"
    temporary.write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    for attempt in range(12):
        try:
            temporary.replace(OUT / "manifest.json")
            return
        except PermissionError:
            if attempt == 11:
                raise
            time.sleep(0.5 * (attempt + 1))


def verify(name: str, record: dict) -> None:
    path = OUT / f"{name.lower()}.png"
    if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        raise ValueError(f"{name}: manifest hash mismatch")
    with Image.open(path) as atlas:
        if atlas.size != (EDGE, EDGE) or atlas.mode != "RGBA":
            raise ValueError(f"{name}: invalid native atlas")
        hashes = set()
        for index in range(COUNT):
            x, y = index % 6 * FRAME, index // 6 * FRAME
            frame = atlas.crop((x, y, x + FRAME, y + FRAME))
            box = frame.getchannel("A").getbbox()
            if box is None or min(box) <= 0 or max(box) >= FRAME:
                raise ValueError(f"{name}: empty or clipped character frame {index}")
            hashes.add(hashlib.sha256(frame.tobytes()).digest())
        if len(hashes) < 24:
            raise ValueError(f"{name}: missing idle animation")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*")
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    colors = palette()
    if set(colors) != set(FAMILY) or len(colors) != 57:
        raise ValueError("Character definitions must cover every element exactly once")
    selected = args.names or list(colors)
    if any(name not in colors for name in selected):
        raise ValueError("Unknown character selection")
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "manifest.json"
    records = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    generator = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    uploader, key = None, None
    if args.upload:
        sys.path.insert(0, str(ROOT / "tools" / "assetgen"))
        import upload
        uploader = upload
        key = upload.saved("ROBLOX_API_KEY")
        if not key:
            raise RuntimeError("No Open Cloud key configured")
    for name in selected:
        record = records.get(name, {})
        path = OUT / f"{name.lower()}.png"
        if record.get("generator") != generator or not path.exists():
            atlas = Image.new("RGBA", (EDGE, EDGE))
            for index in range(COUNT):
                frame = draw_frame(name, colors[name], index)
                atlas.paste(frame, (index % 6 * FRAME, index // 6 * FRAME))
                if index == 14:
                    frame.save(OUT / f"{name.lower()}_still.png")
            atlas.save(path, compress_level=6)
            record = {"generator": generator, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                      "size": EDGE, "frame": FRAME, "count": COUNT, "family": FAMILY[name]}
        verify(name, record)
        if uploader is not None and not record.get("assetId"):
            record["assetId"] = uploader.upload(
                key, "Image", str(path), "image/png", f"AF {name} Companion",
                f"Original animated {name} companion: idle, expression and blink. Native 4096 atlas.",
            )
        records[name] = record
        save_manifest(records)
        print(f"[CHARACTER] {name}: verified" + (" and uploaded" if record.get("assetId") else ""), flush=True)
    if args.apply:
        if set(records) != set(colors):
            raise ValueError("Do not activate a partial character collection")
        for name, record in records.items():
            verify(name, record)
            if not str(record.get("assetId", "")).isdigit():
                raise ValueError(f"{name}: character not uploaded")
        source = MODULE.read_text(encoding="utf-8")
        source, count = re.subn(r'(\t(\w+) = \{ Image = "rbxassetid://)\d+(")',
                                lambda m: m[1] + str(records[m[2]]["assetId"]) + m[3], source)
        if count != 57:
            raise ValueError("Expected 57 sprite entries")
        MODULE.write_text(source, encoding="utf-8", newline="\n")
        print("[CHARACTER] Activated all 57 companions; delivered-image crop mapping preserved")


if __name__ == "__main__":
    main()
