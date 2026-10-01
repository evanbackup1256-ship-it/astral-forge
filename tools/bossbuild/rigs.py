"""Rig and animate the six generated boss models in Blender, and export the result for the game.

    python tools/assetgen/blender_rpc.py run tools/bossbuild/rigs.py

The boss meshes are the textured models generated from your Studio place (SanctuaryKit.luau
BOSS_MESHES). Each piece of a model gets its own bone with a real joint at its pivot (shoulder,
hip, neck, wing root, elbow...), parented into a hierarchy (arm hangs from shoulder hangs from
torso). For every boss this script:

  1. builds the armature in Blender (a visible rig, one per boss, named <Kind>Rig),
  2. keys the eleven clips on it with that boss's own acting (acting.py): rotations about each
     bone's joint plus translation for floating parts,
  3. samples every clip back out of Blender, and writes src/Shared/AstralForge/Shared/BossRigs.luau
     (bone heads, parents, and per-frame parent-relative rotation + offset in Roblox axes).

Coordinates below are the model's own rest space (the offsets in BOSS_MESHES, +Y up, front +Z).
"""

import importlib
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
sys.path.insert(0, os.path.join(ROOT, "tools", "bossbuild"))
import acting
import clips as clipmod
import lib

for module in (clipmod, acting, lib):
    importlib.reload(module)

OUT_MODULE = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "BossRigs.luau")
KEY_FPS = 12
TIMELINE_FPS = 24
C = lib.C


def P(p=0.0, y=0.0, r=0.0, tx=0.0, ty=0.0, tz=0.0):
    return (p, y, r, tx, ty, tz)


def scaled(c, k):
    return P(c[0] * k, c[1] * k, c[2] * k)


def bob(t, amount, speed=1.3, phase=0.0):
    return math.sin(t * speed + phase) * amount


# --- skeletons: bone -> (parent, head) in rest space -----------------------------------------------

SPECS = {
    "Knight": [
        ("torso", None, (0, -1, 0)), ("head", "torso", (0, 5.4, 1.78)),
        ("armL", "torso", (2.45, 5.9, 1.03)), ("armR", "torso", (-2.45, 5.9, 2.75)),
        ("legL", "torso", (1.54, 1.2, 1.22)), ("legR", "torso", (-1.54, 1.2, 1.25)),
    ],
    "Seraph": [
        ("torso", None, (0, -1.5, 0)), ("head", "torso", (0, 5.4, 0.27)),
        ("wingL", "torso", (2.7, 5.7, -0.3)), ("wingR", "torso", (-2.4, 5.7, -0.3)),
        ("armL", "torso", (3.64, 2.4, -0.16)),
    ],
    "Regent": [
        ("torso", None, (0, 0, 0)), ("head", "torso", (0, 4.0, 1.3)),
        ("shoulderL", "torso", (4.2, 7.2, -0.6)), ("shoulderR", "torso", (-4.2, 7.0, -0.6)),
        ("elbowL", "shoulderL", (5.8, 3.0, 0.2)), ("elbowR", "shoulderR", (-6.0, 2.0, 0.4)),
        ("hipL", "torso", (2.38, -0.1, 0.95)), ("hipR", "torso", (-2.4, -0.1, 0.93)),
    ],
    "Warden": [
        ("torso", None, (0, -1, 0)), ("cloak", "torso", (0, 6.2, -0.3)), ("head", "torso", (0.01, 5.4, 0.98)),
        ("shoulderL", "torso", (3.86, 5.5, 0.16)), ("shoulderR", "torso", (-3.87, 5.8, 0.16)),
        ("armL", "torso", (3.9, 5.2, 0.3)), ("armR", "torso", (-3.9, 5.4, 0.3)),
    ],
    "Choir": [
        ("torso", None, (-0.45, -1, -0.6)), ("coat", "torso", (-0.34, 5.0, -1.29)), ("head", "torso", (-0.38, 4.3, -0.72)),
        ("armL", "torso", (2.26, 5.3, 0.44)), ("armR", "torso", (-3.23, 3.9, 0.34)), ("blades", "torso", (0, 3.83, 2.23)),
    ],
    "Rime": [
        ("torso", None, (0, 0, 0)), ("head", "torso", (0, 4.2, 0.19)),
        ("shoulderL", "torso", (4.0, 6.5, -0.6)), ("shoulderR", "torso", (-3.95, 6.5, -0.6)),
        ("armL", "shoulderL", (5.0, 6.4, -0.57)), ("armR", "shoulderR", (-5.1, 6.4, -0.5)),
        ("legL", "torso", (2.35, -0.1, 0.58)), ("legR", "torso", (-2.33, -0.1, 0.59)),
    ],
}


# --- channels -> bones --------------------------------------------------------------------------------

def common(c, t, hover=0.15):
    return {"torso": P(*c["torso"], ty=bob(t, hover)), "head": P(*c["head"])}


def map_knight(c, t):
    pose = common(c, t)
    for ch in ("armL", "armR", "legL", "legR"):
        pose[ch] = P(*c[ch])
    return pose


def map_seraph(c, t):
    pose = common(c, t, 0.45)
    pose["wingL"], pose["wingR"] = P(*c["wingL"]), P(*c["wingR"])
    pose["armL"] = P(*c["armL"])
    return pose


def map_regent(c, t):
    pose = common(c, t, 0.08)
    for side in ("L", "R"):
        p, y, r = c[f"arm{side}"]
        pose[f"shoulder{side}"] = scaled((p, y, r), 0.7)
        pose[f"elbow{side}"] = P(-0.25 + min(0.0, p) * 0.35 + max(0.0, p) * 0.1)
        pose[f"hip{side}"] = P(*c[f"leg{side}"])
    return pose


def map_warden(c, t):
    pose = common(c, t, 0.3)
    pose["cloak"] = P(*c["cloth"])
    for index, side in enumerate(("L", "R")):
        pose[f"shoulder{side}"] = scaled(c[f"arm{side}"], 0.4)
        pose[f"arm{side}"] = P(*c[f"arm{side}"], ty=bob(t, 0.35, 1.6, index * 2.1))
    return pose


def map_choir(c, t):
    pose = common(c, t, 0.2)
    pose["coat"] = P(*c["cloth"])
    pose["armL"], pose["armR"] = P(*c["armL"]), P(*c["armR"])
    pose["blades"] = P(*c["blades"], ty=bob(t, 0.3, 1.1))
    return pose


def map_rime(c, t):
    pose = common(c, t, 0.05)
    for side in ("L", "R"):
        pose[f"shoulder{side}"] = scaled(c[f"arm{side}"], 0.35)
        pose[f"arm{side}"] = scaled(c[f"arm{side}"], 0.65)
        pose[f"leg{side}"] = P(*c[f"leg{side}"])
    return pose


MAPS = {"Knight": map_knight, "Seraph": map_seraph, "Regent": map_regent, "Warden": map_warden, "Choir": map_choir, "Rime": map_rime}


# --- Blender ----------------------------------------------------------------------------------------------

def to_blender(v):
    x, y, z = v
    return Vector((x, -z, y))


def build_rig(kind):
    name = f"{kind}Rig"
    for obj in list(bpy.data.objects):
        if obj.name == name:
            bpy.data.objects.remove(obj, do_unlink=True)
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, parent, head in SPECS[kind]:
        eb = data.edit_bones.new(bone)
        eb.head = to_blender(head)
        eb.tail = eb.head + Vector((0, 0, 0.7))
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return rig


def apply_pose(kind, rig, pose):
    absolute = {}
    for bone, parent, head in SPECS[kind]:
        h = to_blender(head)
        side = 1 if head[0] >= 0 else -1
        p, y, r, tx, ty, tz = pose.get(bone, P())
        off = Vector((tx, -tz, ty))
        local = Matrix.Translation(h) @ Matrix.Translation(off) @ lib.rot_matrix(p, y, r, side).to_4x4() @ Matrix.Translation(-h)
        absolute[bone] = (absolute[parent] @ local) if parent else local
    for bone, _parent, _head in SPECS[kind]:
        pb = rig.pose.bones[bone]
        pb.matrix = absolute[bone] @ rig.data.bones[bone].matrix_local


def sample(kind, rig, action, length):
    scene = bpy.context.scene
    rig.animation_data.action = action
    frames = int(round(length * KEY_FPS)) + 1
    tracks = {bone: [] for bone, _p, _h in SPECS[kind]}
    for f in range(frames):
        scene.frame_set(1 + f * (TIMELINE_FPS // KEY_FPS))
        absolute = {}
        for bone, parent, head in SPECS[kind]:
            pb = rig.pose.bones[bone]
            absolute[bone] = pb.matrix @ rig.data.bones[bone].matrix_local.inverted()
        for bone, parent, head in SPECS[kind]:
            local = (absolute[parent].inverted() @ absolute[bone]) if parent else absolute[bone]
            h = to_blender(head)
            rot = local.to_3x3()
            off = local.translation - h + rot @ h
            rb_rot = C @ rot @ C.inverted()
            e = rb_rot.to_euler("ZYX")
            rb_off = C @ off
            tracks[bone].extend([round(e.x, 2), round(e.y, 2), round(e.z, 2), round(rb_off.x, 2), round(rb_off.y, 2), round(rb_off.z, 2)])
    scene.frame_set(1)
    return tracks


def num(x):
    text = f"{x:.2f}".rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def build_kind(kind):
    rig = build_rig(kind)
    rig.animation_data_create()
    mapper = MAPS[kind]
    clips_out = {}
    for name in clipmod.CLIPS:
        length, hit, loop = acting.clip_info(kind, name)
        for old in [a for a in bpy.data.actions if a.name == f"{kind}_{name}"]:
            bpy.data.actions.remove(old)
        action = bpy.data.actions.new(f"{kind}_{name}")
        action.use_fake_user = True
        rig.animation_data.action = action
        keys = int(round(length * KEY_FPS)) + 1
        for k in range(keys):
            t = k / KEY_FPS
            apply_pose(kind, rig, mapper(acting.channels(kind, name, t), t))
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=1 + k * (TIMELINE_FPS // KEY_FPS))
                pb.keyframe_insert("location", frame=1 + k * (TIMELINE_FPS // KEY_FPS))
        tracks = sample(kind, rig, action, length)
        clips_out[name] = {"length": length, "hit": hit, "loop": loop, "bones": {b: v for b, v in tracks.items() if any(abs(x) > 0.004 for x in v)}}
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.animation_data.action = bpy.data.actions[f"{kind}_idle"]
    return clips_out


def write_module(all_clips):
    out = ["--!nocheck", "-- Skeletons and animation for the six generated boss models, authored in Blender (tools/bossbuild/rigs.py).", "-- Per boss: bones { parent, head } in the model's rest space, and clips whose tracks hold, per frame", "-- and bone: pitch, yaw, roll (Roblox Euler, CFrame.Angles order) then an x, y, z offset.", "", "local BossRigs = {"]
    for kind, clips_out in all_clips.items():
        out.append(f"\t{kind} = {{")
        out.append("\t\torder = { " + ", ".join(f'"{b}"' for b, _p, _h in SPECS[kind]) + " },")
        out.append("\t\tbones = {")
        for bone, parent, head in SPECS[kind]:
            parent_text = f' parent = "{parent}",' if parent else ""
            out.append(f"\t\t\t{bone} = {{{parent_text} head = {{ {num(head[0])}, {num(head[1])}, {num(head[2])} }} }},")
        out.append("\t\t},")
        out.append("\t\tclips = {")
        for name, clip in clips_out.items():
            out.append(f"\t\t\t{name} = {{ fps = {KEY_FPS}, stride = 6, length = {num(clip['length'])}, hit = {num(clip['hit'])}, loop = {'true' if clip['loop'] else 'false'}, bones = {{")
            for bone, values in clip["bones"].items():
                out.append(f"\t\t\t\t{bone} = {{ " + ", ".join(num(v) for v in values) + " },")
            out.append("\t\t\t} },")
        out.append("\t\t},")
        out.append("\t},")
    out += ["}", "", "return BossRigs", ""]
    with open(OUT_MODULE, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out))


def main():
    all_clips = {}
    for kind in SPECS:
        all_clips[kind] = build_kind(kind)
        print(kind, "rigged:", len(SPECS[kind]), "bones")
    write_module(all_clips)
    numbers = sum(len(v) for clips_out in all_clips.values() for clip in clips_out.values() for v in clip["bones"].values())
    print(f"{numbers} animation numbers -> {OUT_MODULE}")


main()
