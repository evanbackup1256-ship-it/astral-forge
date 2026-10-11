"""Offline regression checks for native 4K atlas packing and sharp alpha edges."""

from __future__ import annotations

import tempfile
from pathlib import Path
from unittest.mock import patch
import json

from PIL import Image

import build_elements_hq as hq
import build_elements as base
import build_elements_parallel as parallel


def main() -> None:
    assert base.FRAME == 682 and len(base.ELEMENTS) == 57
    layer = Image.new("RGBA", (682, 682))
    layer.putpixel((341, 341), (255, 100, 0, 255))
    result = base.glow(layer, 2, 0.5)
    assert result.getpixel((341, 341)) == (255, 100, 0, 255)
    assert result.getchannel("A").getextrema() == (0, 255)
    original_out = hq.OUT

    def fixture() -> list[Image.Image]:
        return [
            Image.new("RGBA", (682, 682), (index * 7, 255 - index * 7, 50, 255))
            for index in range(36)
        ]

    try:
        with tempfile.TemporaryDirectory() as folder:
            hq.OUT = Path(folder)
            base.ELEMENTS["fixture"] = fixture
            path = hq.render("fixture")
            with Image.open(path) as atlas:
                assert atlas.size == (4096, 4096) and atlas.mode == "RGBA"
                for index in range(36):
                    x, y = (index % 6) * 682 + 341, (index // 6) * 682 + 341
                    assert atlas.getpixel((x, y)) == (index * 7, 255 - index * 7, 50, 255)
                assert atlas.getpixel((4095, 4095)) == (0, 0, 0, 0)
            destination = Path(folder) / "manifest.json"
            replace = Path.replace
            attempts = 0

            def locked_once(path: Path, target: Path) -> Path:
                nonlocal attempts
                attempts += 1
                if attempts == 1:
                    raise PermissionError("simulated Windows sharing lock")
                return replace(path, target)

            with patch.object(Path, "replace", locked_once), patch.object(parallel.time, "sleep"):
                parallel.save_manifest({"fire": {"assetId": 123}}, destination)
            assert attempts == 2 and json.loads(destination.read_text())["fire"]["assetId"] == 123
            with patch.object(Path, "replace", side_effect=PermissionError("persistent lock")), patch.object(parallel.time, "sleep"):
                try:
                    parallel.save_manifest({}, destination)
                except PermissionError:
                    pass
                else:
                    raise AssertionError("persistent manifest lock must surface explicitly")
    finally:
        hq.OUT = original_out
        base.ELEMENTS.pop("fixture", None)
    print("[TEST] native 4K resolution, all 57 designs, sharp alpha core, 36 frame crops and bounded manifest lock retries passed")


if __name__ == "__main__":
    main()
