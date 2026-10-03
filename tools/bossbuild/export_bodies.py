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
MODULE = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "BossBodies.luau")
BEGIN, END = "-- BOSS-BODIES-BEGIN", "-- BOSS-BODIES-END"
SCALE = {"Knight": 6.6, "Warden": 6.6, "Choir": 6.6, "Regent": 6.0, "Seraph": 6.6, "Rime": 6.0, "Astraeon": 7.0}


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
    chains = rig['rest'].get('physics', {}).get('chains', [])
    if chains:
        lines.append("\t\tphysics = { chains = {")
        for chain in chains:
            settings = ", ".join(f"{key} = {num(value) if isinstance(value, (int, float)) and not isinstance(value, bool) else str(value).lower()}" for key, value in chain.get('Settings', {}).items())
            bones = ", ".join(f'"{b}"' for b in chain['Bones'])
            lines.append(f"\t\t\t{{ Kind = \"{chain['Kind']}\", Group = \"{chain['Group']}\", Column = {chain['Column']}, Bones = {{ {bones} }}, Settings = {{ {settings} }} }},")
        lines.append("\t\t} },")
    lines.append("\t\tclips = {")
    for name, clip in rig["clips"].items():
        lines.append(f"\t\t\t{name} = {{ fps = {clip['fps']}, length = {num(clip['length'])}, hit = {num(clip['hit'])}, loop = {'true' if clip['loop'] else 'false'}, bones = {{")
        for bone, values in clip["bones"].items():
            lines.append(f"\t\t\t\t{bone} = {{ " + ", ".join(num(v) for v in values) + " },")
        lines.append("\t\t\t} },")
    lines.append("\t\t},")
    lines.append("\t},")
    return lines


LOADER = '''--!nocheck
-- The Blender-built boss bodies: skeleton, piece placement, physics chains and animation clips.
-- Written by tools/bossbuild/export_bodies.py. Each boss is its own module (BossBody_<Kind>) because a
-- single module would pass Roblox's script size limit; this loads them on first use, so
-- `BossBodies[kind]` works as it always did. SanctuaryKit requires it when a boss is set to wear its
-- Blender body (SanctuaryConfig.BossBodyStyle).

local loaded = {}

return setmetatable({}, {
	__index = function(_, kind)
		if loaded[kind] == nil then
			local module = script.Parent:FindFirstChild("BossBody_" .. tostring(kind))
			loaded[kind] = if module ~= nil and module:IsA("ModuleScript") then require(module) else false
		end
		return loaded[kind] or nil
	end,
})
'''


def main():
    kinds = []
    folder = os.path.dirname(MODULE)
    for path in sorted(os.listdir(FOLDER)):
        match = re.fullmatch(r"(\w+)_rig\.json", path)
        if not match:
            continue
        kind = match.group(1)
        with open(os.path.join(FOLDER, path), "r", encoding="utf-8") as handle:
            rig = json.load(handle)
        block = body_block(kind, rig)
        inner = [line[1:] if line.startswith("\t") else line for line in block[1:-1]]
        text = "\n".join(["--!nocheck", f"-- The Blender-built {kind} body (written by tools/bossbuild/export_bodies.py). Data only.", "", "return {"] + inner + ["}", ""])
        target = os.path.join(folder, f"BossBody_{kind}.luau")
        with open(target, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print(f"  {kind}: {len(text) / 1024:.0f} KB")
        kinds.append(kind)
    with open(MODULE, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(LOADER)
    print("bodies written:", ", ".join(kinds), "->", folder)


if __name__ == "__main__":
    main()