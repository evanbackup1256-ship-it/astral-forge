"""Build the crate workshop in the connected Blender without resetting its file."""

from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(r"C:\Users\evanm\.codex\worktrees\ded6\Astral Forge v2")
OUT = ROOT / "assets/generated/crates"
OUT.mkdir(parents=True, exist_ok=True)
library = ROOT / "tools/casinobuild/build_casino.py"
helpers = {"__file__": str(library), "__name__": "crate_geometry"}
exec(library.read_text().rsplit("\nmain()", 1)[0], helpers)

previous = bpy.data.scenes.get("Astral Forge — Crate Workshop")
if previous:
    for obj in list(previous.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.scenes.remove(previous)
scene = bpy.data.scenes.new("Astral Forge — Crate Workshop")
bpy.context.window.scene = scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
world = bpy.data.worlds.new("Crate Studio Dome")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.14, 0.2, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.world = world

for name, position, energy, size in (
    ("Softbox Key", (-4, -5, 7), 700, 5),
    ("Softbox Fill", (5, -2, 4), 400, 4),
    ("Edge Light", (0, 5, 6), 650, 3),
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    light.location = position
    light.rotation_euler = (-Vector(position)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(light)

designs = [
    ("Classic", "Classic", 1.0, 1.0, "brace"),
    ("Crystal", "Crystal", 1.0, 1.0, "prism"),
    ("Frost", "Frost", 1.0, 1.0, "fins"),
    ("Molten", "Molten", 1.0, 1.0, "coil"),
    ("Nebula", "Nebula", 1.0, 1.0, "orbit"),
    ("Void", "Void", 1.0, 1.0, "seal"),
    ("Gilded", "Gilded", 1.0, 1.0, "crown"),
    ("Celestial", "Celestial", 1.0, 1.0, "halo"),
    ("Salvage", "Classic", 1.18, 0.82, "brace"),
    ("Reactor", "Molten", 0.88, 1.25, "coil"),
    ("Glacier", "Frost", 0.92, 1.15, "fins"),
    ("Solar", "Gilded", 1.22, 0.75, "solar"),
    ("Storm", "Crystal", 0.85, 1.3, "antenna"),
    ("Lunar", "Void", 1.1, 0.9, "orbit"),
    ("DeepSea", "Nebula", 0.9, 1.12, "pressure"),
    ("Prism", "Crystal", 1.15, 0.85, "prism"),
    ("Obsidian", "Molten", 1.18, 1.05, "seal"),
    ("Chrono", "Classic", 0.95, 1.18, "dial"),
    ("Aurora", "Celestial", 1.25, 0.9, "halo"),
    ("Titan", "Classic", 1.3, 1.2, "armor"),
]


def hardware(body, motif, ordinal):
    """Join manufactured hardware into the body; the lid stays independent."""
    parts = [body]
    trim = body.data.materials[1]
    glow = body.data.materials[2]
    front = min(vertex.co.y for vertex in body.data.vertices)

    def box(name, dimensions, position, material=trim, angle=0):
        if position[1] < -0.5:
            position = (position[0], front - 0.04 - abs(position[1] + 0.56), position[2])
        bpy.ops.mesh.primitive_cube_add(size=1, location=position)
        obj = bpy.context.object
        obj.name = name
        obj.scale = dimensions
        obj.rotation_euler.z = angle
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bevel = obj.modifiers.new("Machined edge", "BEVEL")
        bevel.width = 0.018
        bevel.segments = 3
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        obj.data.materials.append(material)
        parts.append(obj)
        return obj

    def ring(name, position, radius, material=trim):
        position = (position[0], front - 0.06 - abs(position[1] + 0.56), position[2])
        bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=0.025,
                                       major_segments=48, minor_segments=8, location=position)
        obj = bpy.context.object
        obj.name = name
        obj.rotation_euler.x = math.pi / 2
        obj.data.materials.append(material)
        parts.append(obj)
        return obj

    for side in (-1, 1):
        box("Corner Guard", (0.12, 0.12, 0.78), (side * 0.74, -0.53, 0.51))
        for z in (0.2, 0.5, 0.8):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6,
                                                radius=0.035, location=(side * 0.74, -0.61, z))
            obj = bpy.context.object
            obj.location.y = front - 0.075
            obj.data.materials.append(trim)
            parts.append(obj)
    box("Recessed Lock", (0.28, 0.06, 0.34), (0, -0.58, 0.6))
    box("Status Indicator", (0.035, 0.025, 0.18), (0, -0.62, 0.6), glow)
    for n in range(5):
        box("Engraved Vent", (0.2, 0.035, 0.025), (-0.4, -0.565, 0.3 + n * 0.07))

    if motif in ("coil", "pressure", "dial", "orbit", "seal"):
        count = {"coil": 3, "pressure": 4, "dial": 2, "orbit": 1, "seal": 5}[motif]
        for n in range(count):
            ring("Machined Concentric Ring", (0.4, -0.585 - n * 0.012, 0.58), 0.22 - n * 0.027)
    elif motif in ("fins", "solar", "armor", "brace"):
        count = {"fins": 6, "solar": 4, "armor": 3, "brace": 2}[motif]
        for n in range(count):
            box("Structural Rib", (0.06, 1.25, 0.08), (-0.55 + n * 1.1 / max(1, count - 1), 0, 0.17))
    elif motif in ("halo", "crown"):
        ring("Floating Crest", (0.4, -0.57, 0.74), 0.23, glow)
        for n in range(3):
            box("Crest Ray", (0.025, 0.06, 0.18), (0.24 + n * 0.16, -0.56, 0.87), trim)
    else:
        count = 3 if motif == "prism" else 2
        for n in range(count):
            box("Optical Rod", (0.1, 0.1, 0.32 + n * 0.08), (0.8, -0.35 + n * 0.28, 0.72), glow)

    # Each body carries a different arrangement of recessed serial markers.
    for n in range(ordinal % 5 + 1):
        box("Serial Inlay", (0.045, 0.025, 0.045), (-0.2 + n * 0.09, -0.565, 0.16))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()


def finish_lid(lid, name, ordinal):
    trim = lid.data.materials[1]
    glow = lid.data.materials[2]
    top = max(vertex.co.z for vertex in lid.data.vertices)
    parts = [lid]
    circular = name in ("Reactor", "Storm", "Lunar", "DeepSea", "Prism", "Chrono", "Glacier")
    if circular:
        for radius in (0.3, 0.43):
            bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=0.018,
                                           major_segments=48, minor_segments=8,
                                           location=(0, 0, top + 0.025))
            obj = bpy.context.object
            obj.data.materials.append(trim)
            parts.append(obj)
    else:
        for side in (-1, 1):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(side * 0.5, 0, top + 0.028))
            obj = bpy.context.object
            obj.scale = (0.045, 0.65, 0.035)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            obj.data.materials.append(trim)
            parts.append(obj)
    for n in range(6):
        angle = n * math.tau / 6
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.035,
            location=(math.cos(angle) * 0.36, math.sin(angle) * 0.36, top + 0.03))
        obj = bpy.context.object
        obj.scale.z = 0.5
        obj.data.materials.append(trim)
        parts.append(obj)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.16, depth=0.045,
                                      location=(0, 0, top + 0.035))
    emblem = bpy.context.object
    emblem.data.materials.append(glow)
    parts.append(emblem)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = lid
    bpy.ops.object.join()


def unique_chassis(name, base, ordinal):
    materials = helpers["crate_materials"](base)
    if name in ("Reactor", "Storm", "Lunar", "DeepSea", "Prism", "Chrono", "Glacier"):
        segments = {"Reactor": 48, "Storm": 6, "Lunar": 32, "DeepSea": 12,
                    "Prism": 8, "Chrono": 16, "Glacier": 10}[name]
        radius = {"Reactor": 0.65, "Storm": 0.72, "Lunar": 0.8, "DeepSea": 0.76,
                  "Prism": 0.82, "Chrono": 0.72, "Glacier": 0.8}[name]
        mesh = helpers["bmesh"].new()
        helpers["orient"](helpers["lathe"](mesh, [(0, 0.06), (radius * 0.92, 0.06),
            (radius, 0.16), (radius, 0.82), (radius * 0.92, 1.04), (0, 1.04)], segments, mat=0)[0])
        body = helpers["new_object"](f"Crate_{name}_Body", mesh, materials, smooth=False)
        lid_mesh = helpers["bmesh"].new()
        helpers["orient"](helpers["lathe"](lid_mesh, [(0, 1.03), (radius, 1.03),
            (radius * 1.06, 1.09), (radius * 0.94, 1.22), (0, 1.22)], segments, mat=1)[0])
        lid = helpers["new_object"](f"Crate_{name}_Lid", lid_mesh, materials, smooth=False)
    else:
        depths = {"Salvage": 1.25, "Solar": 0.95, "Obsidian": 1.4, "Aurora": 0.85, "Titan": 1.5}
        depth = depths[name]
        body = helpers["new_object"](f"Crate_{name}_Body",
            helpers["box_bm"](1.6, depth, 0.92, 0, (0, 0, 0.48)), materials, smooth=False)
        lid = helpers["new_object"](f"Crate_{name}_Lid",
            helpers["box_bm"](1.72, depth + 0.12, 0.2, 1, (0, 0, 1.04)), materials, smooth=False)
    for obj in (body, lid):
        helpers["modifiers"](obj, bevel=0.035, bevel_segments=3, angle=35)
    return body, lid


manifest = []
for ordinal, (name, base, width, height, motif) in enumerate(designs):
    if ordinal < 8:
        body = helpers["crate_body"](base)
        lid = helpers["crate_lid"](base)
    else:
        body, lid = unique_chassis(name, base, ordinal)
    helpers["apply_modifiers"](body)
    helpers["apply_modifiers"](lid)
    hardware(body, motif, ordinal)
    finish_lid(lid, name, ordinal)
    body.name = f"Crate_{name}_Body"
    lid.name = f"Crate_{name}_Lid"
    for obj in (body, lid):
        obj.scale = (width, 1 + (ordinal % 3) * 0.06, height)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.location = ((ordinal % 5) * 4, (ordinal // 5) * 4, 0)
        obj["crate_skin"] = name
        obj["motif"] = motif
    manifest.append({"Skin": name, "Body": body.name, "Lid": lid.name,
                     "Motif": motif, "Width": width, "Height": height})

camera_data = bpy.data.cameras.new("Crate Contact Sheet")
camera = bpy.data.objects.new("Crate Contact Sheet", camera_data)
scene.collection.objects.link(camera)
camera.location = (23, -23, 25)
target = Vector((8, 6, 0.5))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 25
scene.camera = camera
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.filepath = str(OUT / "CrateWorkshop.png")
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(OUT / "CrateWorkshop.blend"), {scene})
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
print(f"Built {len(manifest)} original crate rigs in a separate Blender scene.")
