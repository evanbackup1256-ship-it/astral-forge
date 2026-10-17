"""Render a few frames of chosen companions into one contact strip for inspection.

python -m tools.spritegen.companions.preview OUT.png Fire Abyss ... [--frames 0,9,18,27] [--small]
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image

from . import core
from .build import colors_for, canvas_for
from .registry import DESIGNS, load_all


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("names", nargs="*")
    parser.add_argument("--frames", default="0,9,18,27")
    parser.add_argument("--small", action="store_true", help="also show the 170px delivered size")
    args = parser.parse_args()
    load_all()
    names = args.names or list(DESIGNS)
    frames = [int(v) for v in args.frames.split(",")]
    colors = colors_for()
    cell = 256
    rows = []
    for name in names:
        row = []
        for index in frames:
            canvas = canvas_for(name, index, colors)
            DESIGNS[name](canvas)
            image = core.render(canvas)
            row.append(image.resize((cell, cell), Image.LANCZOS))
            if args.small:
                row.append(image.resize((85, 85), Image.LANCZOS).resize((cell, cell), Image.NEAREST))
        rows.append(row)
    width = max(len(r) for r in rows) * cell
    sheet = Image.new("RGBA", (width, len(rows) * cell), (40, 44, 62, 255))
    for y, row in enumerate(rows):
        for x, image in enumerate(row):
            sheet.alpha_composite(image, (x * cell, y * cell))
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
