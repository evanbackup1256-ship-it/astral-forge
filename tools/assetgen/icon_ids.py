"""Give every icon use in the game its own id, so no icon is drawn twice.

Rewrites icon names in the source ("Forge" -> "Forge.7", a generated machine's "Domain" ->
"Domain.OriginPress") and writes the full list to assets/generated/icons/ids.json for icons.py.
Only real icon spots are touched: `icon =` / `Icon =` data fields, `kind =` inside an Icon
element, and the two icon lookup tables. Plain concept names stay valid at runtime as a fallback
for icons chosen in code, so their base id is always rendered too.

    python tools/assetgen/icon_ids.py --dry     # count what would change
    python tools/assetgen/icon_ids.py           # rewrite and write ids.json
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from icons import GLYPHS  # noqa: E402

CONCEPTS = set(GLYPHS)
LIT = re.compile(r'"([A-Z][A-Za-z]+)(\.[A-Za-z0-9_]+)?"')
FIELD = re.compile(r'\b(?:icon|Icon)\s*=(?!=)\s*')
KIND = re.compile(r'\bkind\s*=(?!=)\s*')
TABLES = ("local ITEM_ICONS = {", "local KIND_ICON = {", "local REBIRTH_ICONS = {")
# ids chosen in code rather than written as a field (ArtKit's reward/item/player helpers)
EXTRA = [f"{c}.reward" for c in ("Core", "Dust", "Boost", "Wheel", "Crate", "Flux", "Command", "Artifact", "Gift")] + ["Forge.item", "Research.item", "Pilot.mark"]


def files():
    for path in sorted((ROOT / "src").rglob("*.luau")):
        if "Stories" in path.parts:
            continue
        yield path
    # The generated config is TypeScript now; its icon ids are rewritten the same way.
    yield ROOT / "src/Shared/AstralForge/Shared/GameConfigGenerated.ts"


def main(dry):
    counters = defaultdict(int)
    used = set()
    ids = set(CONCEPTS) | set(EXTRA)
    changes = defaultdict(int)

    def fresh(concept, hint=None):
        if hint:
            base = f"{concept}.{hint}"
            candidate, n = base, 1
            while candidate in used:
                n += 1
                candidate = f"{base}{n}"
        else:
            while True:
                counters[concept] += 1
                candidate = f"{concept}.{counters[concept]}"
                if candidate not in used:
                    break
        used.add(candidate)
        ids.add(candidate)
        return candidate

    for path in files():
        raw = path.read_bytes().decode("utf-8")
        nl = "\r\n" if "\r\n" in raw else "\n"
        lines = raw.replace("\r\n", "\n").split("\n")
        in_table = False
        out = []
        for i, line in enumerate(lines):
            stripped = line.strip()
            if any(stripped.startswith(t) for t in TABLES):
                in_table = True
            elif in_table and stripped.startswith("}"):
                in_table = False
            start = None
            if in_table and re.match(r'^\s*\w+\s*=\s*"', line):
                start = line.index("=") + 1
            else:
                m = FIELD.search(line)
                if m:
                    start = m.end()
                else:
                    m = KIND.search(line)
                    if m:
                        context = "\n".join(lines[max(0, i - 3):i + 1])
                        if re.search(r'\(Icon\s*,|Icon\s*,\s*\{|BrandArt\.Icon', context):
                            start = m.end()
                    else:
                        # island messages take their icon as a positional argument
                        b = re.search(r'\b(?:banner|moment)\(', line)
                        if b:
                            start = b.end()
            if start is None:
                out.append(line)
                continue

            def swap(match):
                concept, suffix = match.group(1), match.group(2)
                if concept not in CONCEPTS:
                    return match.group(0)
                if suffix:
                    used.add(concept + suffix)
                    ids.add(concept + suffix)
                    return match.group(0)
                hint = None
                if path.name == "GameConfigGenerated.ts":
                    for ahead in lines[i + 1:i + 3]:
                        h = re.search(r'\bId\s*[=:]\s*"([A-Za-z0-9_]+)"', ahead)
                        if h:
                            hint = h.group(1)
                            break
                changes[path.name] += 1
                return f'"{fresh(concept, hint)}"'

            out.append(line[:start] + LIT.sub(swap, line[start:]))
        if changes[path.name] and not dry:
            path.write_bytes(nl.join(out).encode("utf-8"))
    total = sum(changes.values())
    for name, n in sorted(changes.items(), key=lambda kv: -kv[1]):
        print(f"{n:6d}  {name}")
    print(f"{total} rewrites, {len(ids)} ids")
    if not dry:
        out_dir = ROOT / "assets" / "generated" / "icons"
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "ids.json").write_text(json.dumps(sorted(ids), indent=0), encoding="utf-8")


if __name__ == "__main__":
    main("--dry" in sys.argv)
