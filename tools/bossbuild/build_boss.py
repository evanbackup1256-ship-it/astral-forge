"""Build one boss end to end inside Blender.

    set BOSS=Knight  (or edit KIND below) then:
    python tools/assetgen/blender_rpc.py run tools/bossbuild/build_boss.py

Steps: model pieces -> armature + skinning -> procedural materials -> UV atlas -> bake ->
split back into pieces -> keyframe the eleven clips -> sample them out -> export the GLB, the
rig/animation JSON and a preview. Output goes to assets/generated/bosses/.
"""

import importlib
import json
import math
import os
import sys

import bpy

ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
sys.path.insert(0, os.path.join(ROOT, "tools", "bossbuild"))
KIND = os.environ.get("BOSS", "") or globals().get("KIND_OVERRIDE", "Knight")

import clips as clipmod
import lib

importlib.reload(clipmod)
importlib.reload(lib)
module_name = KIND.lower()
module = importlib.import_module(module_name)
importlib.reload(module)

FPS_KEYS = 12
FPS_TIMELINE = 24
STEP = FPS_TIMELINE // FPS_KEYS


def main():
    scene = bpy.context.scene
    lib.clear_boss(KIND)
    boss = module.build()
    objs = lib.make_objects(boss)
    rig = lib.make_armature(boss)
    materials = [lib.procedural_material(f"{KIND}_{name}", module.MATERIALS[name]) for name in module.ORDER]
    lib.assign_materials(objs, materials)
    atlas = lib.join_for_atlas(boss, objs)
    lib.unwrap(atlas)
    final, atlas_path = lib.bake_atlas(boss, atlas)
    lib.split_atlas(boss, atlas, objs, final)
    bpy.data.objects.remove(atlas, do_unlink=True)
    rest = lib.rest_data(boss, objs)

    # ---- animation: one action per clip, keyed at 12 fps on the pose bones ----
    rig.animation_data_create()
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    clips_out = {}
    for name, (length, hit, loop, pose_fn) in clipmod.CLIPS.items():
        action = bpy.data.actions.get(f"{KIND}_{name}")
        if action is not None:
            bpy.data.actions.remove(action)
        action = bpy.data.actions.new(f"{KIND}_{name}")
        action.use_fake_user = True
        rig.animation_data.action = action
        keys = int(round(length * FPS_KEYS)) + 1
        for k in range(keys):
            channels = pose_fn(k / FPS_KEYS)
            lib.apply_pose(boss, rig, module.map_pose(channels))
            lib.key_pose(boss, rig, 1 + k * STEP)
        tracks = lib.sample_clip(boss, rig, action, length, FPS_KEYS)
        sparse = {bone: values for bone, values in tracks.items() if any(abs(v) > 0.004 for v in values)}
        clips_out[name] = {"fps": FPS_KEYS, "length": length, "hit": hit, "loop": loop, "bones": sparse}
    bpy.ops.object.mode_set(mode="OBJECT")
    # leave the rig on its idle action, in rest pose, for whoever opens the file
    rig.animation_data.action = bpy.data.actions[f"{KIND}_idle"]
    scene.frame_set(1)

    path = lib.export_glb(boss, objs)
    with open(os.path.join(lib.OUT, f"{KIND}_rig.json"), "w", encoding="utf-8") as handle:
        json.dump({"rest": rest, "clips": clips_out, "order": boss.order}, handle)
    numbers = sum(len(v) for clip in clips_out.values() for v in clip["bones"].values())
    tris = sum(len(o.data.polygons) for o in objs.values())
    print(f"{KIND}: {len(objs)} pieces, {len(boss.order)} bones, {numbers} animation numbers, {tris} faces -> {path}")


main()
