"""Render and validate the baked asset kit independently of the open Blender file."""
from pathlib import Path
import json
import bpy
import numpy as np
import sys

ROOT = Path(r"C:\Users\evanm\.codex\worktrees\ded6\Astral Forge v2")
OUT = ROOT / "assets/generated/crates"
arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
label = arguments[0] if arguments else "Baked"
if label not in ("Baked", "Before", "After"):
    raise RuntimeError("Unsupported evidence label")
scene = bpy.data.scenes.get("Astral Forge — Crate Workshop")
if scene is None:
    raise RuntimeError("The baked workshop scene is missing")
bpy.context.window.scene = scene
manifest = json.loads((OUT / "manifest.json").read_text())
evidence = []
for index, entry in enumerate(manifest):
    body = scene.objects.get(entry["Body"])
    lid = scene.objects.get(entry["Lid"])
    if body is None or lid is None:
        raise RuntimeError(f"Incomplete rig: {entry['Skin']}")
    body_height = body.dimensions.z
    for role in ("Body", "Lid"):
        name = entry[role]
        obj = scene.objects.get(name)
        if obj is None:
            raise RuntimeError(f"Missing exported part: {name}")
        obj.hide_render = False
        height = body_height * 0.5 if role == "Body" else body_height + lid.dimensions.z * 0.5 - 0.01
        obj.location = ((index % 5) * 4, (index // 5) * 4, height)
        texture = bpy.data.images.load(str(OUT / f"{name}.png"), check_existing=True)
        pixels = np.array(texture.pixels[:], dtype=np.float32)
        if not np.isfinite(pixels).all() or tuple(texture.size) != (1024, 1024):
            raise RuntimeError(f"Invalid texture data: {name}")
        evidence.append({"name": name, "textureSize": list(texture.size),
                         "hasUvs": len(obj.data.uv_layers) > 0,
                         "polygons": len(obj.data.polygons)})
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_cavity = False
scene.render.resolution_x = 1600
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.filepath = str(OUT / f"CrateWorkshop_{label}.png")
bpy.ops.render.render(write_still=True)
(OUT / "texture-validation.json").write_text(json.dumps(evidence, indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"CrateWorkshop_{label}Preview.blend"))
print("Validated and rendered 40 baked crate parts.", flush=True)
