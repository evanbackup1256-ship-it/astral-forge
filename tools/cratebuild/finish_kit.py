"""Remove unsupported lid ornaments and export the finished baked Blender rigs."""
from pathlib import Path
import bpy
import bmesh

ROOT = Path(r"C:\Users\evanm\.codex\worktrees\ded6\Astral Forge v2")
OUT = ROOT / "assets/generated/crates"
library = ROOT / "tools/casinobuild/build_casino.py"
helpers = {"__file__": str(library), "__name__": "crate_finishing"}
exec(library.read_text().rsplit("\nmain()", 1)[0], helpers)
scene = bpy.data.scenes.get("Astral Forge — Crate Workshop")
bpy.context.window.scene = scene
for skin in ("Classic", "Crystal", "Frost", "Molten", "Nebula", "Void", "Gilded", "Celestial"):
    lid = scene.objects[f"Crate_{skin}_Lid"]
    source = helpers["crate_lid"](skin)
    helpers["apply_modifiers"](source)
    original_count = len(source.data.vertices)
    bpy.data.objects.remove(source, do_unlink=True)
    if original_count >= len(lid.data.vertices):
        raise RuntimeError(f"Unexpected source geometry for {skin}")
    mesh = bmesh.new()
    mesh.from_mesh(lid.data)
    mesh.verts.ensure_lookup_table()
    mesh.verts.index_update()
    additions = [vertex for vertex in mesh.verts if vertex.index >= original_count]
    bmesh.ops.delete(mesh, geom=additions, context="VERTS")
    mesh.to_mesh(lid.data)
    mesh.free()
    bpy.ops.object.select_all(action="DESELECT")
    lid.select_set(True)
    bpy.context.view_layer.objects.active = lid
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    lid.location = (0, 0, 0)
    print(f"Removed unsupported ornaments: {skin}", flush=True)
meshes = [obj for obj in scene.objects if obj.type == "MESH"]
assert len(meshes) == 40
bpy.ops.object.select_all(action="DESELECT")
for obj in meshes:
    obj.data.name = obj.name
    obj.location = (0, 0, 0)
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / "CrateKit.glb"), export_format="GLB",
                          use_selection=True, export_apply=True, export_materials="EXPORT",
                          export_image_format="AUTO", export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "CrateKit_Finished.blend"))
print("Exported corrected baked crate kit.", flush=True)
