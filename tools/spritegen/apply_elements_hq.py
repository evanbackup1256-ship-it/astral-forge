"""Wire a complete, verified 57-element 4K manifest; never switch a partial upload."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "assets" / "generated" / "sprites" / "hq"
MODULE = ROOT / "src" / "Shared" / "AstralForge" / "Shared" / "ElementSprites.luau"


def main() -> None:
    manifest = json.loads((ATLAS / "manifest.json").read_text())
    source = MODULE.read_text(encoding="utf-8")
    pattern = re.compile(r'(\t(\w+) = \{ Image = "rbxassetid://)\d+(")')
    names = [match[1].lower() for match in pattern.findall(source)]
    if len(names) != 57 or set(manifest) != set(names):
        raise ValueError("The complete 57-element replacement manifest is required")
    for name in names:
        record = manifest[name]
        if not str(record.get("assetId", "")).isdigit():
            raise ValueError(f"{name}: missing uploaded asset ID")
        path = ATLAS / f"{name}.png"
        if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
            raise ValueError(f"{name}: uploaded image hash does not match the source")
        with Image.open(path) as image:
            if image.size != (4096, 4096) or image.mode != "RGBA":
                raise ValueError(f"{name}: not a lossless 4K atlas")
            frame_hashes = set()
            for index in range(36):
                x, y = (index % 6) * 682, (index // 6) * 682
                frame = image.crop((x, y, x + 682, y + 682))
                if frame.getchannel("A").getbbox() is None:
                    raise ValueError(f"{name}: frame {index} is empty")
                frame_hashes.add(hashlib.sha256(frame.tobytes()).digest())
            with Image.open(ATLAS.parent / f"{name}.png") as legacy:
                legacy_hashes = {
                    hashlib.sha256(legacy.crop(((index % 6) * 170, (index // 6) * 170,
                                              (index % 6 + 1) * 170, (index // 6 + 1) * 170)).tobytes()).digest()
                    for index in range(36)
                }
            if len(frame_hashes) < len(legacy_hashes):
                raise ValueError(f"{name}: animation lost its distinct frames")
    source = pattern.sub(lambda match: match[1] + str(manifest[match[2].lower()]["assetId"]) + match[3], source)
    source, count = re.subn(
        r"\tFRAME = (?:170|682|682 \* 1024 / 4096),",
        "\tFRAME = 682 * 1024 / 4096,", source,
    )
    if count != 1:
        raise ValueError("Expected exactly one elemental frame-size declaration")
    if "\tSOURCE_FRAME = 682," not in source:
        source = source.replace("\tFRAME = 682 * 1024 / 4096,",
                                "\tSOURCE_FRAME = 682,\n\tSOURCE_EDGE = 4096,\n\tUI_EDGE = 1024,\n\tFRAME = 682 * 1024 / 4096,")
    source = source.replace("Every sheet is 6 x 6 frames of 170 px", "Every 4096-square sheet contains 6 x 6 native frames of 682 px")
    MODULE.write_text(source, encoding="utf-8", newline="\n")
    print("[4K] all 57 atlases verified and wired, 2052 nonempty native frames")


if __name__ == "__main__":
    main()
