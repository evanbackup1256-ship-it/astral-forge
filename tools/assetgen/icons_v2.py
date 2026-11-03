"""Astral Forge icons, version 2: composed from parts, unique per thing, built for the game's dark UI.

The first generator baked a random frame, material and ornaments into every icon id, so the same
concept looked different everywhere and nothing could be learned by shape or colour. This one builds
an icon from a few parts, drawn once each, that the game stacks at runtime:

    plate     one grayscale sprite, multiplied by the thing's accent: a near-black base stays dark and
              tinted, the white rim becomes the accent. Dark glass with a coloured edge, like the UI.
    glyph     the concept or noun pictogram: cream, with a dark outline. (Control icons are white and
              plate-less: the game tints them with the label beside them.)
    emblem    a small badge for the modifier (Aether, Folded ...), top right
    pips      tier marks along the bottom

Every generated machine and research study is NOUN + MODIFIER + tier with its own colour, so each one
is unique by construction. Numbered ids ("Forge.7") share the concept plate and glyph and differ by
emblem. Everything lives on two small sheets instead of ~100.

    python tools/assetgen/icons_v2.py --preview    # contact sheets (parts, and composed samples)
    python tools/assetgen/icons_v2.py --build      # sheets + manifest into assets/generated/icons_v2/
    python tools/assetgen/icons_v2.py --check      # every thing unique, every part present and different
    python tools/assetgen/icons_v2.py --emit       # write src/Client/AstralForge/IconParts.ts (empty sheets)

Going live (the game keeps its current icons until the last step):
    python tools/assetgen/icons_v2.py --upload                      # Open Cloud, uses the saved key
    python tools/assetgen/icons_v2.py --resolve path/to/studio.py   # decal id -> image id, via a running Studio
    python tools/assetgen/icons_v2.py --activate                    # rewrites src/Client/AstralForge/IconManifest.ts
"""
from __future__ import annotations

import colorsys
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
import icon_parts as parts  # noqa: E402
import icons as v1  # noqa: E402  (glyph shapes and drawing helpers)

ROOT = v1.ROOT
OUT = ROOT / "assets" / "generated" / "icons_v2"
CELL, S, SHEET, PER_ROW = v1.CELL, v1.S, v1.SHEET, v1.PER_ROW
Mask = v1.Mask
PX = S / CELL  # one output pixel, in working pixels

INK = (8, 6, 14)
CREAM_TOP = (255, 252, 244)
CREAM_BOTTOM = (222, 212, 196)
DETAIL = (70, 62, 86)


# Glyphs redrawn for this set. The originals for these concepts read as something else at 24 px
# (the artifact looked like a padlock, the crate like a flat card, the visit door like a blank slab).
def g_artifact(m, d):
    m.rect(0.27, 0.42, 0.73, 0.88, 0.04)
    m.circle(0.5, 0.42, 0.23)
    d.ngon(0.5, 0.58, 0.15, 4, -90)


def g_crate(m, d):
    m.rect(0.13, 0.25, 0.87, 0.83, 0.06)
    d.line([(0.13, 0.44), (0.87, 0.44)], 0.05)
    d.line([(0.34, 0.44), (0.34, 0.83)], 0.045)
    d.line([(0.66, 0.44), (0.66, 0.83)], 0.045)
    d.rect(0.43, 0.38, 0.57, 0.56, 0.025)


def g_domain(m, d):
    for cx, cy in ((0.5, 0.31), (0.29, 0.66), (0.71, 0.66)):
        m.ngon(cx, cy, 0.185, 6, -90)
        d.ngon(cx, cy, 0.06, 6, -90)


def g_pilot(m, d):
    m.circle(0.5, 0.45, 0.31)
    m.rect(0.19, 0.45, 0.81, 0.76, 0.09)
    d.rect(0.28, 0.37, 0.72, 0.57, 0.08)


def g_visit(m, d):
    m.circle(0.5, 0.40, 0.255)
    m.poly([(0.285, 0.50), (0.715, 0.50), (0.5, 0.90)])
    d.circle(0.5, 0.40, 0.10)


GLYPHS = dict(v1.GLYPHS)
GLYPHS.update(Artifact=g_artifact, Crate=g_crate, Domain=g_domain, Pilot=g_pilot, Visit=g_visit)
CHROME = v1.CHROME

# the game's accent family for each concept (ArtKit/Icon semanticIconColor), as Palette names
FAMILY_OF = {}
for _family, _concepts in {
    "mango": "Dust Forge Milestone Wheel Gift Shop Jackpot Collect Code Calendar",
    "violet": "Core Research StarGrid Anomaly Artifact Rebirth Continuum Inventory Crate",
    "coral": "Close Hide Lock Admin",
    "mint": "Check Crew Guild Games Boost Play Visit",
    "pink": "Brand Mission Guide Settings Credits Story Lab Rewards Domain Wave",
}.items():
    for _c in _concepts.split():
        FAMILY_OF[_c] = _family
DEFAULT_FAMILY = "cyan"
PALETTE = {  # Base palette (Shared/ForgeTheme.ts)
    "cyan": (96, 206, 222), "mint": (120, 214, 170), "coral": (238, 116, 100),
    "mango": (242, 176, 72), "violet": (170, 146, 240), "pink": (232, 122, 172),
}
# resources and currencies sit on a circle; every page and feature on a squircle
ROUND = {"Flux", "Core", "Dust", "Credits", "Jackpot", "Ember", "Overcharge", "Vault", "Production"}
GLYPH_SCALE = 0.72
CHROME_SCALE = 0.86
NOUN_SCALE = 0.72


def family_of(concept):
    return FAMILY_OF.get(concept, DEFAULT_FAMILY)


# ------------------------------------------------------------------ compositing helpers
def gradient(top, bottom, mask):
    t = np.linspace(0, 1, S)[:, None, None]
    rgb = np.array(top, dtype=np.float32) * (1 - t) + np.array(bottom, dtype=np.float32) * t
    img = Image.fromarray(np.broadcast_to(rgb, (S, S, 3)).astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(mask)
    return img


def tint(rgb, mask, alpha=255):
    img = Image.new("RGBA", (S, S), (*rgb, 0))
    a = (np.array(mask, dtype=np.float32) * (alpha / 255)).clip(0, 255).astype(np.uint8)
    img.putalpha(Image.fromarray(a))
    return img


def grow(mask, px):
    return mask.filter(ImageFilter.MaxFilter(int(px) * 2 + 1)) if px > 0 else mask


def shrink(mask, px):
    return mask.filter(ImageFilter.MinFilter(int(px) * 2 + 1)) if px > 0 else mask


def blur(mask, r):
    return mask.filter(ImageFilter.GaussianBlur(r))


def shift(mask, dx, dy):
    return ImageChops.offset(mask, int(dx), int(dy))


def cut(a, b):
    return ImageChops.subtract(a, b)


def scale_about_centre(mask, scale):
    if abs(scale - 1) < 1e-3:
        return mask
    w = max(2, int(S * scale))
    small = mask.resize((w, w), Image.LANCZOS)
    canvas = Image.new("L", (S, S), 0)
    canvas.paste(small, ((S - w) // 2, (S - w) // 2))
    return canvas


def finish(img):
    return img.resize((CELL, CELL), Image.LANCZOS)


# ------------------------------------------------------------------ the parts
def plate_mask(round_):
    m = Mask()
    if round_:
        m.circle(0.5, 0.5, 0.46)
    else:
        m.rect(0.05, 0.05, 0.95, 0.95, 0.27)
    return m.img


def render_plate(round_):
    """grayscale; the game multiplies it by the accent. Base stays dark, the white rim becomes the accent."""
    plate = plate_mask(round_)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(tint((0, 0, 0), blur(shift(plate, 0, 2.4 * PX), 2.6 * PX), 110))
    img.alpha_composite(tint((0, 0, 0), plate))  # outline: pure black stays black under any tint
    inner = shrink(plate, 2.2 * PX)
    img.alpha_composite(gradient((104, 104, 104), (44, 44, 44), inner))
    # the rim: white, brighter on top (light from above), the part the game tints
    rim = cut(inner, shrink(inner, 2.4 * PX))
    top_fade = Mask().rect(0, 0, 1, 1, 0).img
    ramp = np.linspace(255, 120, S, dtype=np.float32)[:, None] * np.ones((1, S), dtype=np.float32)
    rim_a = ImageChops.multiply(rim, Image.fromarray(ramp.astype(np.uint8), "L"))
    img.alpha_composite(tint((255, 255, 255), rim_a))
    # soft light from the top, and a faint reflected light along the foot
    sheen = Mask().rect(0.0, 0.0, 1.0, 0.45, 0.0).img
    img.alpha_composite(tint((255, 255, 255), ImageChops.multiply(blur(sheen, 12 * PX), shrink(inner, 2.4 * PX)), 46))
    foot = Mask().rect(0.0, 0.78, 1.0, 1.0, 0.0).img
    img.alpha_composite(tint((255, 255, 255), ImageChops.multiply(blur(foot, 10 * PX), shrink(inner, 2.4 * PX)), 26))
    return finish(img)


def glyph_layers(fn, scale):
    body, detail = Mask(), Mask()
    fn(body, detail) if fn.__code__.co_argcount >= 2 else fn(body)
    g = scale_about_centre(body.img, scale)
    d = scale_about_centre(detail.img, scale)
    return g, ImageChops.multiply(d, g)


def render_glyph(fn, scale, white=False):
    """cream pictogram with a dark outline and a soft drop shadow. White and plate-less for controls."""
    g, d = glyph_layers(fn, scale)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    reach = (2.0 if white else 1.25) * PX
    outline = grow(g, reach)
    img.alpha_composite(tint((0, 0, 0), blur(shift(outline, 0, 1.8 * PX), 1.8 * PX), 150))
    img.alpha_composite(tint(INK, outline))
    img.alpha_composite(gradient((255, 255, 255) if white else CREAM_TOP, (232, 232, 236) if white else CREAM_BOTTOM, g))
    if d.getbbox():
        img.alpha_composite(tint((120, 116, 136) if white else DETAIL, ImageChops.multiply(grow(d, 0.4 * PX), g), 235))
    img.alpha_composite(tint((255, 255, 255), blur(cut(g, shift(g, 1.1 * PX, 1.4 * PX)), 0.5 * PX), 220))
    img.alpha_composite(tint((0, 0, 0), blur(cut(g, shift(g, -1.1 * PX, -1.4 * PX)), 0.6 * PX), 50))
    return finish(img)


def render_emblem(fn):
    """a dark badge with a cream symbol; the game shows it at ~42% of the icon, top right"""
    m = Mask()
    fn(m)
    sym = scale_about_centre(m.img, 0.78)
    badge = Mask().circle(0.5, 0.5, 0.47).img
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(tint((0, 0, 0), blur(shift(badge, 0, 2.2 * PX), 2.2 * PX), 150))
    img.alpha_composite(tint(INK, badge))
    inner = shrink(badge, 2.0 * PX)
    img.alpha_composite(gradient((52, 48, 66), (22, 20, 32), inner))
    img.alpha_composite(tint((200, 192, 216), cut(inner, shrink(inner, 1.6 * PX)), 200))
    img.alpha_composite(tint(CREAM_TOP, sym))
    return finish(img)


def render_pips(n):
    """n cream diamonds along the foot of the icon (tier 2 -> 1, 3 -> 2, 4 -> 3)"""
    m = Mask()
    gap = 0.115
    for i in range(n):
        x = 0.5 + (i - (n - 1) / 2) * gap
        m.ngon(x, 0.905, 0.052, 4, 0)
    p = m.img
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(tint(INK, grow(p, 1.6 * PX)))
    img.alpha_composite(tint(CREAM_TOP, p))
    return finish(img)


# ------------------------------------------------------------------ the thing registry (from the game's config)
def read_things():
    """machines and studies from GameConfigGenerated.ts: (id, icon id, noun, modifier, tier, hue 0..359)"""
    src = (ROOT / "src" / "Shared" / "AstralForge" / "Shared" / "GameConfigGenerated.ts").read_text(encoding="utf-8")
    out = []
    for block in re.split(r"\n\t\t\{\n", src):
        icon = re.search(r'Icon: "([^"]+)"', block)
        name = re.search(r'\bName: "([^"]+)"', block)
        hsv = re.search(r"Color: Color3\.fromHSV\(([\d.]+), ([\d.]+), ([\d.]+)\)", block)
        if not (icon and name):
            continue
        words = name.group(1).split()
        tier = 1
        if words[-1].isdigit():
            tier = int(words[-1])
            words = words[:-1]
        if len(words) < 2:
            continue
        hue = round(float(hsv.group(1)) * 360) % 360 if hsv else 0
        out.append((icon.group(1), words[0], words[-1], tier, hue))
    return out


# ------------------------------------------------------------------ sheets, manifest
def part_list():
    """(key, image) for every part sprite, in sheet order"""
    items = []
    items.append(("plate:square", render_plate(False)))
    items.append(("plate:round", render_plate(True)))
    for n in (1, 2, 3):
        items.append((f"pips:{n}", render_pips(n)))
    for concept in sorted(GLYPHS):
        if concept in CHROME:
            items.append((f"ctrl:{concept}", render_glyph(GLYPHS[concept], CHROME_SCALE, white=True)))
        else:
            items.append((f"glyph:{concept}", render_glyph(GLYPHS[concept], GLYPH_SCALE)))
    for noun, fn in parts.NOUNS.items():
        items.append((f"noun:{noun}", render_glyph(fn, NOUN_SCALE)))
    for mark, fn in parts.MARKS.items():
        items.append((f"mark:{mark}", render_emblem(fn)))
    return items


def build(out_dir=OUT):
    out_dir.mkdir(parents=True, exist_ok=True)
    items = part_list()
    per_sheet = PER_ROW * PER_ROW
    sheets, cells = [], {}
    for start in range(0, len(items), per_sheet):
        sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
        n = len(sheets)
        for k, (key, img) in enumerate(items[start:start + per_sheet]):
            x, y = (k % PER_ROW) * CELL, (k // PER_ROW) * CELL
            sheet.paste(img, (x, y))
            cells[key] = [n, x, y]
        name = f"icons_v2_{n:03d}.png"
        sheet.save(out_dir / name, optimize=True)
        sheets.append(name)
    things = read_things()
    manifest = {"sheets": sheets, "cells": cells, "round": sorted(c for c in GLYPHS if c in ROUND_SET()), "things": things}
    (out_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    write_ts(manifest, out_dir / "IconParts.next.ts")
    print(f"{len(items)} parts on {len(sheets)} sheets, {len(things)} things -> {out_dir}")
    return manifest


def ROUND_SET():
    return ROUND


IDS = ROOT / "assets" / "asset_ids.json"
# separate from IconManifest.ts (the old icons): the game switches to these only once their sheets have image ids
TS_OUT = ROOT / "src" / "Client" / "AstralForge" / "IconParts.ts"


def sheet_hash(path):
    import hashlib

    with Image.open(path) as img:
        return hashlib.sha1(img.convert("RGBA").tobytes()).hexdigest()


def write_ts(manifest, path):
    """the game's icon table. Sheets stay empty until uploaded and resolved, so the game keeps drawing
    the old icons until --activate (nothing here changes the game by itself)."""
    ids = json.loads(IDS.read_text(encoding="utf-8")) if IDS.exists() else {}
    cells = manifest["cells"]
    kinds = {"plate": {}, "pips": {}, "glyph": {}, "ctrl": {}, "noun": {}, "mark": {}}
    for key, cell in cells.items():
        kind, _, name = key.partition(":")
        kinds[kind][name] = cell
    marks = list(parts.MARKS)
    nouns = list(parts.NOUNS)
    lines = [
        "// Generated by tools/assetgen/icons_v2.py. Do not edit by hand.",
        "// An icon is stacked from parts: plate (tinted), glyph or noun pictogram, modifier emblem, tier pips.",
        "// Control icons (close, back, check ...) are one white sprite the game tints with its label.",
        "// While Sheets[0] is empty the game keeps drawing the icons from IconManifest.ts.",
        "",
        "type IconCell = [sheet: number, x: number, y: number];",
        "// [noun, modifier emblem, tier, hue 0-359, 1 for a round plate]",
        "type Thing = [string, string, number, number, number];",
        "",
        "interface IconParts {",
        "\tCell: number;",
        "\tSheets: string[];",
        "\tPlate: { [shape: string]: IconCell | undefined };",
        "\tPips: { [count: number]: IconCell | undefined };",
        "\tGlyph: { [concept: string]: IconCell | undefined };",
        "\tControl: { [concept: string]: IconCell | undefined };",
        "\tNoun: { [noun: string]: IconCell | undefined };",
        "\tMark: { [modifier: string]: IconCell | undefined };",
        "\tMarkOrder: string[];",
        "\tRound: { [concept: string]: boolean | undefined };",
        "\tThings: { [icon: string]: Thing | undefined };",
        "}",
        "",
        "const IconParts: IconParts = {",
        f"\tCell: {CELL},",
        "\tSheets: [",
    ]
    for idx, name in enumerate(manifest["sheets"]):
        image = ids.get(f"IconImageV2{idx:03d}", 0)
        lines.append(f'\t\t"{"rbxassetid://" + str(image) if image else ""}", // {name}')
    lines += ["\t],"]

    def table(label, mapping, numeric=False):
        lines.append(f"\t{label}: {{")
        for name in sorted(mapping, key=lambda k: (str(k))):
            c = mapping[name]
            key = name if numeric else f'"{name}"'
            lines.append(f"\t\t{key}: [{c[0]}, {c[1]}, {c[2]}],")
        lines.append("\t},")

    table("Plate", kinds["plate"])
    table("Pips", kinds["pips"], numeric=True)
    table("Glyph", kinds["glyph"])
    table("Control", kinds["ctrl"])
    table("Noun", kinds["noun"])
    table("Mark", kinds["mark"])
    lines.append("\tMarkOrder: [" + ", ".join(f'"{m}"' for m in marks) + "],")
    lines.append("\tRound: { " + ", ".join(f"{c}: true" for c in sorted(ROUND)) + " },")
    lines.append("\tThings: {")
    for icon, mod, noun, tier, hue in manifest["things"]:
        if noun not in parts.NOUNS or mod not in parts.MARKS:
            continue
        round_ = 1 if "HorizonStudy" in icon else 0
        lines.append(f'\t\t"{icon}": ["{noun}", "{mod}", {tier}, {hue}, {round_}],')
    lines += ["\t},", "};", "", "export = IconParts;", ""]
    path.write_text("\n".join(lines), encoding="utf-8")
    return all(ids.get(f"IconImageV2{i:03d}") for i in range(len(manifest["sheets"])))


def check():
    """prove the set does what it claims: every generated thing is unique, and every part exists and differs"""
    import hashlib

    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    cells = manifest["cells"]
    problems = []
    things = manifest["things"]
    machines = [t for t in things if "HorizonForge" in t[0]]
    studies = [t for t in things if "HorizonStudy" in t[0]]
    print(f"machines {len(machines)}, studies {len(studies)}")
    if len(machines) != 2800 or len(studies) != 1400:
        problems.append(f"expected 2800 machines and 1400 studies, found {len(machines)} and {len(studies)}")
    for label, group in (("machine", machines), ("study", studies)):
        seen = {}
        for icon, mod, noun, tier, hue in group:
            key = (noun, mod, tier)
            if noun not in parts.NOUNS:
                problems.append(f"{icon}: no pictogram for noun {noun}")
            if mod not in parts.MARKS:
                problems.append(f"{icon}: no emblem for modifier {mod}")
            if key in seen:
                problems.append(f"{icon} repeats {seen[key]} ({noun} / {mod} / tier {tier})")
            seen[key] = icon
        print(f"  {label}: {len(seen)} distinct noun+modifier+tier looks for {len(group)} things")
    # every part has a cell inside its sheet
    for key, (n, x, y) in cells.items():
        if not (0 <= x <= SHEET - CELL and 0 <= y <= SHEET - CELL and n < len(manifest["sheets"])):
            problems.append(f"part {key} is outside its sheet")
    # no two pictograms or emblems are the same picture
    sheets = [Image.open(OUT / name).convert("RGBA") for name in manifest["sheets"]]
    for prefix in ("noun", "mark", "glyph"):
        digests = {}
        for key, (n, x, y) in cells.items():
            if key.startswith(prefix + ":"):
                tile = sheets[n].crop((x, y, x + CELL, y + CELL))
                h = hashlib.sha1(tile.tobytes()).hexdigest()
                if h in digests:
                    problems.append(f"{key} is identical to {digests[h]}")
                digests[h] = key
        print(f"  {prefix}: {len(digests)} distinct sprites")
    # control icons are tinted by the game, so they must be white-ish with no colour of their own
    for key, (n, x, y) in cells.items():
        if key.startswith("ctrl:"):
            arr = np.array(sheets[n].crop((x, y, x + CELL, y + CELL)))
            solid = arr[arr[..., 3] > 200][:, :3].astype(int)
            # a pixel with its own hue (channels far apart) would not follow the tint
            chroma = solid.max(axis=1) - solid.min(axis=1)
            if len(chroma) and chroma.max() > 24:
                problems.append(f"{key} has a coloured pixel: the game would tint it unevenly")
    if problems:
        print(f"{len(problems)} problems:")
        for p in problems[:30]:
            print("  -", p)
        sys.exit(1)
    print("icon set check: ok")


def upload_sheets():
    """Open Cloud upload of the sheets (as Decals, like the old sheets). Run by hand."""
    import upload

    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key yet: run  powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1")
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    ids = json.loads(IDS.read_text(encoding="utf-8")) if IDS.exists() else {}
    for idx, name in enumerate(manifest["sheets"]):
        digest = sheet_hash(OUT / name)
        if ids.get(f"IconSheetV2{idx:03d}") and ids.get(f"IconSheetV2Hash{idx:03d}") == digest:
            print(name, "is already uploaded:", ids[f"IconSheetV2{idx:03d}"])
            continue
        print("uploading", name, "...")
        ids[f"IconSheetV2{idx:03d}"] = upload.upload(key, "Decal", str(OUT / name), "image/png", f"Astral Forge icons v2 {idx:03d}", "Astral Forge interface icon parts.")
        ids[f"IconSheetV2Hash{idx:03d}"] = digest
        ids.pop(f"IconImageV2{idx:03d}", None)
        IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")
        print("  ->", ids[f"IconSheetV2{idx:03d}"], "(now run --resolve to turn the decal into its image id)")


def resolve_sheets(studio):
    """ask a running Studio (through the MCP bridge script) for the image inside each uploaded decal"""
    import resolve_icon_images as r

    r.DATAMODEL = "Edit"
    ids = json.loads(IDS.read_text(encoding="utf-8"))
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    for idx in range(len(manifest["sheets"])):
        decal = ids.get(f"IconSheetV2{idx:03d}")
        if not decal:
            sys.exit("upload first (--upload)")
        tex = r.ask_studio(studio, [int(decal)])[0]
        digits = "".join(ch for ch in tex if ch.isdigit())
        if not digits:
            sys.exit(f"no image yet for sheet {idx} ({tex!r}); the decal may still be in moderation, try again in a minute")
        ids[f"IconImageV2{idx:03d}"] = int(digits)
        print(f"sheet {idx}: decal {decal} -> image {digits}")
    IDS.write_text(json.dumps(ids, indent=2), encoding="utf-8")


def activate():
    """point the game at the new icons (only once every sheet has a resolved image id)"""
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    if not write_ts(manifest, TS_OUT):
        sys.exit("a sheet has no image id yet: --upload, then --resolve, then --activate")
    print("IconParts.ts now has the image ids: the game draws the v2 icons")


# ------------------------------------------------------------------ preview (mirrors the game's runtime stacking)
def tint_image(img, rgb):
    r, g, b, a = img.split()
    return Image.merge("RGBA", (r.point(lambda p: p * rgb[0] // 255), g.point(lambda p: p * rgb[1] // 255), b.point(lambda p: p * rgb[2] // 255), a))


def hsv_rgb(hue, s=0.5, v=0.95):
    r, g, b = colorsys.hsv_to_rgb(hue / 360, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def stack(plate_round, accent, glyph, mark=None, pips=0, size=CELL, cache={}):
    """what the game draws: plate (tinted), glyph, emblem top right, pips"""
    def get(key, build_):
        if key not in cache:
            cache[key] = build_()
        return cache[key]

    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    plate = get(("plate", plate_round), lambda: render_plate(plate_round))
    out.alpha_composite(tint_image(plate, accent))
    out.alpha_composite(glyph)
    if pips:
        out.alpha_composite(get(("pips", pips), lambda: render_pips(pips)))
    if mark is not None:
        badge = mark.resize((int(CELL * 0.44), int(CELL * 0.44)), Image.LANCZOS)
        out.alpha_composite(badge, (int(CELL * 0.60), int(CELL * 0.0)))
    return out if size == CELL else out.resize((size, size), Image.LANCZOS)


def preview(path):
    OUT.mkdir(parents=True, exist_ok=True)
    glyph_cache, mark_cache = {}, {}

    def g(concept):
        if concept not in glyph_cache:
            chrome = concept in CHROME
            glyph_cache[concept] = render_glyph(GLYPHS[concept], CHROME_SCALE if chrome else GLYPH_SCALE, white=chrome)
        return glyph_cache[concept]

    def noun(n):
        key = ("n", n)
        if key not in glyph_cache:
            glyph_cache[key] = render_glyph(parts.NOUNS[n], NOUN_SCALE)
        return glyph_cache[key]

    def mark(mk):
        if mk not in mark_cache:
            mark_cache[mk] = render_emblem(parts.MARKS[mk])
        return mark_cache[mk]

    bg = (23, 24, 34)
    rows = []
    # row 1: concepts on their family plate
    concepts = [c for c in sorted(GLYPHS) if c not in CHROME][:24]
    # row 2: machines: 3 nouns x modifiers x tiers, their own hue
    machines = [("Loom", "Aether", 1, 47), ("Anvil", "Quark", 2, 94), ("Kiln", "Helix", 3, 141), ("Array", "Nova", 4, 188), ("Engine", "Prism", 1, 235), ("Well", "Void", 2, 282),
                ("Core", "Solar", 3, 329), ("Lattice", "Lunar", 1, 16), ("Dynamo", "Chrono", 2, 63), ("Press", "Pulse", 3, 110), ("Sieve", "Nexus", 4, 157), ("Relay", "Flux", 1, 204),
                ("Crown", "Halo", 2, 251), ("Gate", "Rift", 3, 298), ("Heart", "Storm", 1, 345), ("Spire", "Ember", 2, 32), ("Forge", "Frost", 3, 79), ("Drive", "Glass", 4, 126),
                ("Matrix", "Iron", 1, 173), ("Loom", "Myth", 2, 220), ("Anvil", "Omega", 3, 267), ("Spindle", "Sigma", 1, 314), ("Kiln", "Delta", 2, 1), ("Array", "Astra", 3, 48)]
    studies = [("Lattice", "Folded", 1, 20), ("Manifold", "Silent", 2, 70), ("Circuit", "Bound", 3, 120), ("Protocol", "Hollow", 1, 170), ("Doctrine", "Lucent", 2, 220), ("Axiom", "Prime", 3, 270),
               ("Theorem", "Deep", 1, 320), ("Pattern", "High", 2, 10), ("Vector", "Inner", 3, 60), ("Field", "Outer", 1, 110), ("Lens", "True", 2, 160), ("Codec", "Wild", 3, 210),
               ("Harmonic", "Keen", 1, 260), ("Ledger", "Vast", 2, 310), ("Cipher", "Fine", 3, 0), ("Orbit", "Dark", 1, 50), ("Thread", "Bright", 2, 100), ("Index", "Swift", 3, 150),
               ("Loom", "Still", 1, 200), ("Spindle", "Live", 2, 250)]
    controls = [c for c in sorted(CHROME)]
    cols = 12
    cell = CELL + 10
    # sizes: big (96) for the first rows, then 48 and 24 on the same dark ground
    tile_rows = []
    for c in concepts:
        pal = PALETTE[family_of(c)]
        tile_rows.append(stack(c in ROUND, pal, g(c)))
    for nn, mk, tr, hue in machines:
        tile_rows.append(stack(False, hsv_rgb(hue), noun(nn), mark(mk), tr - 1))
    for nn, mk, tr, hue in studies:
        tile_rows.append(stack(True, hsv_rgb(hue), noun(nn), mark(mk), tr - 1))
    n = len(tile_rows)
    big_rows = math.ceil(n / cols)
    small_rows = math.ceil(n / 16)
    width = cols * cell + 10
    height = big_rows * cell + small_rows * 56 + 40 + 120
    img = Image.new("RGBA", (width, height), bg + (255,))
    for i, tile in enumerate(tile_rows):
        img.alpha_composite(tile, ((i % cols) * cell + 8, (i // cols) * cell + 8))
    y0 = big_rows * cell + 20
    for i, tile in enumerate(tile_rows):
        x = (i % 16) * 68 + 8
        y = y0 + (i // 16) * 56
        img.alpha_composite(tile.resize((40, 40), Image.LANCZOS), (x, y))
        img.alpha_composite(tile.resize((24, 24), Image.LANCZOS), (x + 42, y + 8))
    # controls tinted on four button fills
    y1 = y0 + small_rows * 56 + 14
    fills = [((30, 120, 210), (246, 238, 224)), ((214, 148, 36), (11, 12, 18)), ((47, 48, 65), (246, 238, 224)), ((46, 172, 128), (11, 12, 18))]
    from PIL import ImageDraw

    draw = ImageDraw.Draw(img)
    for r, (fill, ink) in enumerate(fills):
        for i, c in enumerate(controls[:14]):
            x = 8 + i * 74
            yy = y1 + r * 26
            draw.rounded_rectangle([x, yy, x + 68, yy + 24], radius=6, fill=fill)
            art = tint_image(g(c), ink)
            img.alpha_composite(art.resize((20, 20), Image.LANCZOS), (x + 4, yy + 2))
            img.alpha_composite(art.resize((14, 14), Image.LANCZOS), (x + 40, yy + 5))
    img.save(path)
    print("preview", path, img.size)


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(OUT / "preview_v2.png")
    elif "--build" in sys.argv:
        build()
    elif "--check" in sys.argv:
        check()
    elif "--emit" in sys.argv:
        # write src/.../IconParts.ts as it stands (empty sheets until activated): the game compiles against it
        write_ts(json.loads((OUT / "manifest.json").read_text(encoding="utf-8")), TS_OUT)
        print("wrote", TS_OUT)
    elif "--upload" in sys.argv:
        upload_sheets()
    elif "--resolve" in sys.argv:
        resolve_sheets(sys.argv[sys.argv.index("--resolve") + 1])
    elif "--activate" in sys.argv:
        activate()
    else:
        print(__doc__)
