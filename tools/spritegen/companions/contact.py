"""Contact sheet of every companion still, at the size players see (python -m ...contact OUT.png)."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

from .build import OUT, colors_for


def main() -> None:
    names = sorted(colors_for())
    cell, columns = 150, 10
    rows = (len(names) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell, rows * (cell + 18)), (34, 38, 54, 255))
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(names):
        still = Image.open(OUT / f"{name.lower()}_still.png").resize((cell, cell), Image.LANCZOS)
        x, y = index % columns * cell, index // columns * (cell + 18)
        sheet.alpha_composite(still, (x, y))
        draw.text((x + 6, y + cell + 2), name, fill=(220, 224, 240, 255))
    out = Path(sys.argv[1])
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
