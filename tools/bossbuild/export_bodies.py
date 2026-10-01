"""Write the Blender-built boss skeletons and animation into SharedData.luau (BOSS-BODIES).

    python tools/bossbuild/export_bodies.py

Reads assets/generated/bosses/<Kind>_rig.json (made by build_boss.py inside Blender) for every
boss that has one, and rewrites the block. `SCALE` is studs per metre of the Blender model.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
FOLDER = os.path.join(ROOT, "assets", "generated", "bosses")
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
BEGIN, END = "-- BOSS-BODIES-BEGIN", "-- BOSS-BODIES-END"
SCALE = {"Knight": 6.6, "Warden": 6.6, "Choir": 6.6, "Regent": 6.0, "Seraph": 6.6, "Rime": 6.0}


def num(x):
    text = f"{x:.2f}".rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def vec(v):
    return "{ " + ", ".join(num(c) for c in v) + " }"


def body_block(kind, rig):
    lines = [f"\t{kind} = {{", f"\t\tscale = {SCALE.get(kind, 6.6)},", f"\t\tref = \"{rig['rest']['ref']}\","]
    lines.append("\t\torder = { " + ", ".join(f'"{b}"' for b in rig["order"]) + " },")
    lines.append("\t\tbones = {")
    for name in rig["order"]:
        bone = rig["rest"]["bones"][name]
        parent = f' parent = "{bone["parent"]}",' if bone["parent"] else ""
        lines.append(f"\t\t\t{name} = {{{parent} head = {vec(bone['head'])} }},")
    lines.append("\t\t},")
    lines.append("\t\tpieces = {")
    for name, piece in rig["rest"]["pieces"].items():
        lines.append(f"\t\t\t{name} = {{ bone = \"{piece['bone']}\", center = {vec(piece['center'])} }},")
    lines.append("\t\t},")
    lines.append("\t\tclips = {")
    for name, clip in rig["clips"].items():
        lines.append(f"\t\t\t{name} = {{ fps = {clip['fps']}, length = {num(clip['length'])}, hit = {num(clip['hit'])}, loop = {'true' if clip['loop'] else 'false'}, bones = {{")
        for bone, values in clip["bones"].items():
            lines.append(f"\t\t\t\t{bone} = {{ " + ", ".join(num(v) for v in values) + " },")
        lines.append("\t\t\t} },")
    lines.append("\t\t},")
    lines.append("\t},")
    return lines


def main():
    kinds = []
    out = [BEGIN + " (rewritten by tools/bossbuild/export_bodies.py)", "SanctuaryConfig.BossBodies = {"]
    for path in sorted(os.listdir(FOLDER)):
        match = re.fullmatch(r"(\w+)_rig\.json", path)
        if not match:
            continue
        kind = match.group(1)
        with open(os.path.join(FOLDER, path), "r", encoding="utf-8") as handle:
            rig = json.load(handle)
        out.extend(body_block(kind, rig))
        kinds.append(kind)
    out += ["}", END]
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        sys.exit("BOSS-BODIES block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: newline.join(out), source, count=1))
    print("bodies written:", ", ".join(kinds))


if __name__ == "__main__":
    main()
