"""Deduplicate voice_ids.json while preserving the first ID for each key."""

from __future__ import annotations

import json
from collections import OrderedDict
from pathlib import Path

VOICE_DIR = Path(__file__).resolve().parents[1] / "assets" / "generated" / "voice"
SOURCE = VOICE_DIR / "voice_ids.json"
DUPLICATES = VOICE_DIR / "voice_ids_duplicates.json"


def main() -> None:
    pairs = json.loads(SOURCE.read_text(encoding="utf-8"), object_pairs_hook=list)
    unique: OrderedDict[str, int] = OrderedDict()
    duplicates: list[dict[str, int]] = []

    for key, asset_id in pairs:
        if key in unique:
            # Keep later IDs reviewable without allowing ambiguous JSON keys.
            duplicates.append({"Key": key, "DuplicateId": asset_id, "KeptId": unique[key]})
        else:
            unique[key] = asset_id

    SOURCE.write_text(json.dumps(unique, indent=2) + "\n", encoding="utf-8")
    DUPLICATES.write_text(json.dumps(duplicates, indent=2) + "\n", encoding="utf-8")
    print(f"Kept {len(unique)} IDs; moved {len(duplicates)} duplicate entries.")


if __name__ == "__main__":
    main()
