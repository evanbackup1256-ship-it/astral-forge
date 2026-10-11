"""Pair the uploaded companion characters with their original elemental effects."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "src" / "Shared" / "AstralForge" / "Shared" / "ElementSprites.luau"


def main() -> None:
    atlases = ROOT / "assets" / "generated" / "sprites"
    effects = json.loads((atlases / "hq" / "manifest.json").read_text())
    characters = json.loads((atlases / "characters" / "manifest.json").read_text())
    if len(characters) != 57 or {name.lower() for name in characters} != set(effects):
        raise ValueError("Complete matching character and effect collections are required")
    for name, character in characters.items():
        if not str(character.get("assetId", "")).isdigit() or not str(effects[name.lower()].get("assetId", "")).isdigit():
            raise ValueError(f"{name}: both layers must be uploaded")
    source = MODULE.read_text(encoding="utf-8")
    pattern = r'(\t(\w+) = \{ Image = ")rbxassetid://\d+("(?:, AuraImage = "[^"]+")?)'
    source, count = re.subn(
        pattern,
        lambda match: match[1] + "rbxassetid://" + str(characters[match[2]]["assetId"])
        + '", AuraImage = "rbxassetid://' + str(effects[match[2].lower()]["assetId"]) + '"',
        source,
    )
    if count != 57:
        raise ValueError("Expected 57 companion entries")
    MODULE.write_text(source, encoding="utf-8", newline="\n")
    print("[CHARACTER] All 57 companions paired with their original animated elemental auras")


if __name__ == "__main__":
    main()
