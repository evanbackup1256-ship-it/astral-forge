"""Draw the 2D enamel wheel face from the game's prize palette."""
import argparse
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "generated" / "wheel"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upload", action="store_true")
    args = parser.parse_args()
    config = (ROOT / "src/Shared/AstralForge/Shared/GameConfig.luau").read_text(encoding="utf-8")
    start = config.index("\tWheel = {")
    end = config.index("\n\t},", start) + 4
    entries = re.findall(r'Id = "(\w+)".*?Color = Color3.fromRGB\((\d+), (\d+), (\d+)\)', config[start:end], re.S)
    if not entries:
        raise ValueError("No prize palette found")
    edge, center, radius = 2048, 1024, 970
    image = Image.new("RGBA", (edge, edge))
    draw = ImageDraw.Draw(image)
    for index, (_, red, green, blue) in enumerate(entries):
        base = tuple(map(int, (red, green, blue)))
        half = 180 / len(entries)
        a, b = -90 + index * 2 * half - half, -90 + index * 2 * half + half
        for r in range(radius, 0, -2):
            light = 0.45 + 0.3 * (r / radius) + 0.06 * math.sin(r / radius * math.pi)
            color = tuple(round(channel * light) for channel in base) + (255,)
            draw.pieslice((center - r, center - r, center + r, center + r), a, b, fill=color)
        angle = math.radians(a)
        draw.line((center, center, center + math.cos(angle) * radius, center + math.sin(angle) * radius),
                  fill=(31, 35, 41, 255), width=6)
        for band in (0.57, 0.89):
            r = radius * band
            draw.arc((center - r, center - r, center + r, center + r), a + 2, b - 2,
                     fill=tuple(round(c * 0.85) for c in base) + (255,), width=3)
    for r, color, width in ((985, (51, 44, 35), 26), (975, (191, 158, 94), 16),
                            (963, (242, 212, 152), 4), (950, (85, 69, 49), 7),
                            (925, (173, 140, 86), 3), (545, (220, 197, 143), 3)):
        draw.ellipse((center - r, center - r, center + r, center + r), outline=color + (255,), width=width)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "enamel_face.png"
    image.save(path)
    metadata = {"size": edge, "prizes": [entry[0] for entry in entries]}
    if args.upload:
        import upload
        key = upload.saved("ROBLOX_API_KEY")
        if not key:
            raise RuntimeError("No Open Cloud key configured")
        metadata["assetId"] = upload.upload(key, "Image", str(path), "image/png",
                                           "AF Enamel Prize Wheel", "Original 2048px illustrated enamel prize wheel face.")
    (OUT / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Drawn {len(entries)} enamel prize sectors" + (f"; uploaded {metadata['assetId']}" if args.upload else ""))


if __name__ == "__main__":
    main()
