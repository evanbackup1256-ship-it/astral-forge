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

import acting
import clips as clipmod
import lib

importlib.reload(acting)
importlib.reload(clipmod)
importlib.reload(lib)
module_name = KIND.lower()
module = importlib.import_module(module_name)
importlib.reload(module)

# Per-boss surface detail (lib.detail_pass) and walk cycle (clips.GAIT).
DETAIL = {
    "Knight": dict(bevel=0.02), "Warden": dict(bevel=0.02, subdiv=1, noise=0.02), "Choir": dict(bevel=0.012),
    "Regent": dict(bevel=0.03, subdiv=1, noise=0.05), "Seraph": dict(bevel=0.015), "Rime": dict(bevel=0.03, subdiv=1, noise=0.06),
    "Astraeon": dict(bevel=0.02, subdiv=1, noise=0.02),
}
GAITS = {
    "Knight": dict(length=0.8, stride=0.7, knee=0.9, arm=0.25, lean=0.12, twist=0.15, sway=0.04),
    "Warden": dict(length=1.4, stride=0.45, knee=0.5, arm=0.18, lean=0.05, twist=0.08, sway=0.03),
    "Choir": dict(length=1.2, stride=0.5, knee=0.6, arm=0.35, lean=0.03, twist=0.2, sway=0.05),
    "Regent": dict(length=1.6, stride=0.6, knee=0.7, arm=0.3, lean=0.08, twist=0.12, sway=0.1),
    "Seraph": dict(length=1.2, stride=0.3, knee=0.3, arm=0.15, lean=0.04, twist=0.05, sway=0.02),
    "Rime": dict(length=2.0, stride=0.45, knee=0.4, arm=0.2, lean=0.06, twist=0.06, sway=0.08),
    "Astraeon": dict(length=1.5, stride=0.4, knee=0.4, arm=0.15, lean=0.04, twist=0.06, sway=0.03),
}
FAST = os.environ.get("FAST", "") == "1"      # no bake, no clips, no export: just model, pose and render previews
CLIPS_ONLY = os.environ.get("CLIPS_ONLY", "") == "1"   # no bake, no GLB: re-sample the clips and rewrite the rig JSON (about a minute)
VIEWS = tuple(v for v in os.environ.get("VIEWS", "front,side,back,three").split(",") if v)
FPS_KEYS = 12
FPS_TIMELINE = 24
STEP = FPS_TIMELINE // FPS_KEYS


def main():
    scene = bpy.context.scene
    for stray in ("Cube", "Light"):
        if stray in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[stray], do_unlink=True)
    lib.clear_boss(KIND)
    boss = module.build()
    objs = lib.make_objects(boss)
    lib.detail_pass(objs, **DETAIL.get(KIND, {}))
    clipmod.GAIT.update(GAITS.get(KIND, {}))
    rig = lib.make_armature(boss)
    materials = [lib.procedural_material(f"{KIND}_{name}", module.MATERIALS[name]) for name in module.ORDER]
    lib.assign_materials(objs, materials)
    if not FAST and not CLIPS_ONLY:
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
    if FAST:
        if os.environ.get("POSE", "idle") != "rest":
            clip_name, _, clip_time = os.environ.get("CLIP", "idle:0").partition(":")
            lib.apply_pose(boss, rig, module.map_pose(acting.channels(KIND, clip_name, float(clip_time or 0))))
        bpy.context.view_layer.update()
        bpy.ops.object.mode_set(mode="OBJECT")
        paths = lib.render_preview(KIND, objs, views=VIEWS, tag="_fast" + os.environ.get("TAG", ""))
        print(f"{KIND}: {len(objs)} pieces, {len(boss.order)} bones, {len(boss.physics)} physics chains (fast preview) -> {paths}")
        return
    clips_out = {}
    for name, (length, hit, loop, pose_fn) in clipmod.CLIPS.items():
        action = bpy.data.actions.get(f"{KIND}_{name}")
        if action is not None:
            bpy.data.actions.remove(action)
        action = bpy.data.actions.new(f"{KIND}_{name}")
        action.use_fake_user = True
        rig.animation_data.action = action
        fps, step = FPS_KEYS, STEP
        if name in ("walk", "run"):          # a stride loops exactly, and is keyed finely
            length = clipmod.GAIT["length"] / (1.0 if name == "walk" else 1.8)
            fps, step = 24, 1
        else:                                # every boss plays the shared clips in its own temperament
            length, hit, loop = acting.clip_info(KIND, name)
            pose_fn = lambda t, name=name: acting.channels(KIND, name, t)
        keys = int(round(length * fps)) + 1
        for k in range(keys):
            channels = pose_fn(k / fps)
            lib.apply_pose(boss, rig, module.map_pose(channels))
            lib.key_pose(boss, rig, 1 + k * step)
        tracks = lib.sample_clip(boss, rig, action, length, fps)
        sparse = {bone: values for bone, values in tracks.items() if any(abs(v) > 0.004 for v in values)}
        clips_out[name] = {"fps": fps, "length": round(length, 3), "hit": hit, "loop": loop, "bones": sparse}
    bpy.ops.object.mode_set(mode="OBJECT")
    # leave the rig on its idle action, in rest pose, for whoever opens the file
    rig.animation_data.action = bpy.data.actions[f"{KIND}_idle"]
    scene.frame_set(1)

    if CLIPS_ONLY:
        with open(os.path.join(lib.OUT, f"{KIND}_rig.json"), "w", encoding="utf-8") as handle:
            json.dump({"rest": rest, "clips": clips_out, "order": boss.order}, handle)
        print(f"{KIND}: clips re-sampled, rig json rewritten")
        return
    bpy.context.view_layer.update()
    lib.render_preview(KIND, objs, views=VIEWS, textured=True)
    path = lib.export_glb(boss, objs)
    with open(os.path.join(lib.OUT, f"{KIND}_rig.json"), "w", encoding="utf-8") as handle:
        json.dump({"rest": rest, "clips": clips_out, "order": boss.order}, handle)
    numbers = sum(len(v) for clip in clips_out.values() for v in clip["bones"].values())
    tris = sum(len(o.data.polygons) for o in objs.values())
    print(f"{KIND}: {len(objs)} pieces, {len(boss.order)} bones, {numbers} animation numbers, {tris} faces -> {path}")


main()
