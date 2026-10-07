"""Bake the saved Blender workshop into viewport-ready texture atlases."""
from pathlib import Path
import json
import bpy

print("Initializing Blender texture baker", flush=True)

ROOT = Path(r"C:\Users\evanm\.codex\worktrees\ded6\Astral Forge v2")
OUT = ROOT / "assets/generated/crates"
library = ROOT / "tools/casinobuild/build_casino.py"
helpers = {"__file__": str(library), "__name__": "crate_baking"}
source = library.read_text().rsplit("\nmain()", 1)[0]
source = source.replace('bpy.ops.uv.pack_islands(margin=0.006)',
                        'bpy.ops.uv.pack_islands(margin=0.006, shape_method="AABB")')
preferences = bpy.context.preferences.addons["cycles"].preferences
preferences.compute_device_type = "OPTIX"
preferences.get_devices()
gpu_available = False
for device in preferences.devices:
    device.use = device.type == "OPTIX"
    gpu_available = gpu_available or device.use
if gpu_available:
    source = source.replace('scene.cycles.device = "CPU"', 'scene.cycles.device = "GPU"')
exec(source, helpers)
print("Using OptiX GPU" if gpu_available else "Using CPU", flush=True)
helpers["OUT"] = str(OUT)
helpers["SAMPLES"] = 16
scene = bpy.data.scenes.get("Astral Forge — Crate Workshop")
if scene is None:
    raise RuntimeError("Crate workshop scene is missing")
bpy.context.window.scene = scene
meshes = [obj for obj in scene.objects if obj.type == "MESH"]
if len(meshes) != 40:
    raise RuntimeError(f"Expected 40 body/lid meshes, found {len(meshes)}")
print(f"Loaded {len(meshes)} crate meshes", flush=True)
status = OUT / "bake_status.json"

for index, obj in enumerate(meshes):
    for other in meshes:
        other.hide_render = other is not obj
    original_location = obj.location.copy()
    obj.location = (0, 0, 0)
    print(f"Unwrapping {obj.name}", flush=True)
    helpers["unwrap"](obj)
    texture_path = OUT / f"{obj.name}.png"
    if texture_path.exists():
        image = bpy.data.images.load(str(texture_path), check_existing=True)
        if tuple(image.size) != (1024, 1024):
            raise RuntimeError(f"Invalid completed texture dimensions: {obj.name}")
        material = bpy.data.materials.new(f"{obj.name}_resumed")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        shader = nodes["Principled BSDF"]
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = 0.6
        shader.inputs["Metallic"].default_value = 0
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
        print(f"Resumed completed texture: {obj.name}", flush=True)
    else:
        print(f"Baking {obj.name}", flush=True)
        helpers["bake"](obj, obj.name, 1024)
    triangles = helpers["triangles"](obj)
    if triangles > 19500:
        raise RuntimeError(f"{obj.name} exceeds Roblox's triangle limit: {triangles}")
    obj.location = original_location
    status.write_text(json.dumps({"completed": index + 1, "total": len(meshes),
                                  "last": obj.name, "triangles": triangles}))
    print(f"Baked {index + 1}/{len(meshes)}: {obj.name} ({triangles} triangles)", flush=True)

for obj in meshes:
    obj.hide_render = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.location = (0, 0, 0)
for obj in scene.objects:
    if obj.type != "MESH":
        obj.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(OUT / "CrateKit.glb"), export_format="GLB",
                          use_selection=True, export_apply=True, export_materials="EXPORT",
                          export_image_format="AUTO", export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "CrateKit.blend"))
status.write_text(json.dumps({"completed": len(meshes), "total": len(meshes), "exported": True}))
print("Exported complete textured crate kit.", flush=True)
