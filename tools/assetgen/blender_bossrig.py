"""Author the bosses' body animation in Blender and export it for the game.

Run inside a live Blender (BlenderMCP add-on) or headless:

    python tools/assetgen/blender_rpc.py run tools/assetgen/blender_bossrig.py
    blender -b --python tools/assetgen/blender_bossrig.py

Builds one armature ("BossRig": torso, head, armL, armR, legL, legR, wingL, wingR, cloth,
blades), keys eleven actions on it (idle, forming, slam, thrust, pull, sweep, floor, roar,
summon, hit, death), then samples every action back out of Blender at 15 fps and writes
them into SharedData.luau (BOSS-CLIPS) for the client's rig to play. The six bosses share
the skeleton; each mesh piece follows the bone its role names (an arm piece follows armL or
armR by side, a wing piece wingL or wingR, and so on), so a boss without wings or a cloak
simply has no pieces on those bones.

Channels are pitch (X), yaw (Y) and roll (Z) in radians. Pitch is negative to raise an arm
forward; roll is positive to swing a limb outward (the game mirrors it for the other side).
The armature also gets a .blend-friendly layout: open it and scrub the timeline to see the
motion.
"""

import json
import math
import os
import re

import bpy

try:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
except NameError:
    ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")
OUT = os.path.join(ROOT, "assets", "generated", "bossrig")
FPS = 15
BONES = ["torso", "head", "armL", "armR", "legL", "legR", "wingL", "wingR", "cloth", "blades"]
BEGIN, END = "-- BOSS-CLIPS-BEGIN", "-- BOSS-CLIPS-END"
TAU = math.tau


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_out(x):
    return 1 - (1 - clamp(x)) ** 3


def ease_in_out(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def lerp(a, b, k):
    return a + (b - a) * k


def zero():
    return {bone: [0.0, 0.0, 0.0] for bone in BONES}


# --- the clips: each is (length seconds, hit moment or 0, loops, pose(t) -> {bone: [p, y, r]}) ----

def idle_pose(t, phase=0.0):
    pose = zero()
    w = TAU / 3.0
    pose["torso"] = [math.sin(w * t) * 0.025, 0, math.sin(w * 0.8 * t) * 0.03]
    pose["head"] = [math.sin(w * 1.4 * t) * 0.04, 0, 0]
    for index, bone in enumerate(("armL", "armR")):
        pose[bone] = [-0.08 + math.sin(w * 1.2 * t + index * 2) * 0.07, 0, 0.14 + math.sin(w * 0.9 * t + index) * 0.04]
    for index, bone in enumerate(("legL", "legR")):
        pose[bone] = [math.sin(w * 1.6 * t + index * math.pi) * 0.12, 0, 0.04]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.12 + math.sin(w * 2.8 * t) * 0.2]
    pose["cloth"] = [0.1 + math.sin(w * 1.5 * t) * 0.07, 0, math.sin(w * t) * 0.05]
    pose["blades"] = [0, 0, math.sin(w * t) * 0.1]
    return pose


def forming_pose(t):
    pose = idle_pose(t)
    for bone in ("armL", "armR"):
        pose[bone] = [-0.75, 0, 0.25 * -1]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0.4, -0.5]
    pose["head"] = [0.1, 0, 0]
    return pose


def slam_pose(t):
    hit, strike = 1.1, 0.25
    pose = idle_pose(t)
    if t < hit:
        u = ease_in_out(t / hit)
        pose["armL"] = [-2.35 * u, 0, 0.1]
        pose["armR"] = [-0.7 * u, 0, 0.35 * u]
        pose["torso"] = [-0.32 * u, 0, 0]
        pose["head"] = [-0.25 * u, 0, 0]
        pose["legL"] = [0.15 * u, 0, 0.05]
        pose["legR"] = [0.15 * u, 0, 0.05]
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 0.12 + 0.35 * u]
    else:
        v = ease_out((t - hit) / strike)
        settle = ease_in_out((t - hit - strike) / 0.45)
        pose["armL"] = [lerp(-2.35, 0.35, v) * (1 - settle) - 0.08 * settle, 0, 0.1]
        pose["armR"] = [-0.3, 0, 0.3 * (1 - settle) + 0.14 * settle]
        pose["torso"] = [lerp(-0.32, 0.45, v) * (1 - settle), 0, 0]
        pose["head"] = [0.15 * (1 - settle), 0, 0]
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, lerp(0.5, -0.15, v) * (1 - settle) + 0.12 * settle]
    pose["cloth"] = [0.1 + (-0.3 if t < hit else 0.35 * (1 - clamp((t - hit) / 0.9))), 0, 0]
    return pose


def thrust_pose(t):
    hit = 0.9
    pose = idle_pose(t)
    if t < hit:
        u = ease_in_out(t / hit)
        for bone in ("armL", "armR"):
            pose[bone] = [-0.15, 0, 1.15 * u]
        pose["torso"] = [-0.15 * u, 0, 0]
    else:
        v = ease_out((t - hit) / 0.18)
        settle = ease_in_out((t - hit - 0.18) / 0.4)
        for bone in ("armL", "armR"):
            pose[bone] = [lerp(-0.15, -1.55, v) * (1 - settle) - 0.08 * settle, 0, lerp(1.15, 0.12, v) * (1 - settle) + 0.14 * settle]
        pose["torso"] = [0.35 * v * (1 - settle), 0, 0]
    return pose


def pull_pose(t):
    pose = idle_pose(t)
    w = TAU / 1.2
    for index, bone in enumerate(("armL", "armR")):
        drag = 0.5 + 0.5 * math.sin(w * t + index * math.pi)
        pose[bone] = [-1.0 - 0.5 * drag, 0, 0.3 - 0.2 * drag]
    pose["torso"] = [0.18 + math.sin(w * t) * 0.06, 0, 0]
    return pose


def sweep_pose(t):
    pose = idle_pose(t)
    pose["armL"] = [-1.55, 0, 0.05]
    pose["armR"] = [-0.4, 0, 0.5]
    pose["torso"] = [0, 0, 0.12]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.3 + math.sin(TAU * 2 * t) * 0.15]
    return pose


def floor_pose(t):
    pose = idle_pose(t)
    for index, bone in enumerate(("armL", "armR")):
        pose[bone] = [0.35 + math.sin(TAU * 1.3 * t + index) * 0.1, 0, 0.35]
    pose["torso"] = [0.3, 0, 0]
    return pose


def roar_pose(t):
    u = ease_out(t / 0.5)
    pose = idle_pose(t)
    for bone in ("armL", "armR"):
        pose[bone] = [-0.35 * u, 0, 1.3 * u]
    pose["head"] = [-0.5 * u, 0, 0]
    pose["torso"] = [-0.28 * u, 0, 0]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.12 + 0.58 * u + math.sin(TAU * 3 * t) * 0.05 * u]
    pose["cloth"] = [0.1 - 0.25 * u, 0, 0]
    return pose


def summon_pose(t):
    u = ease_out(t / 0.7)
    pose = idle_pose(t)
    pulse = math.sin(TAU * 2 * t) * 0.08
    for bone in ("armL", "armR"):
        pose[bone] = [-2.0 * u + pulse, 0, 0.5 * u]
    pose["head"] = [-0.3 * u, 0, 0]
    pose["torso"] = [-0.15 * u, 0, 0]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.12 + 0.4 * u]
    return pose


def hit_pose(t):
    decay = (1 - clamp(t / 0.5)) ** 2
    pose = zero()
    pose["torso"] = [-0.35 * decay, 0, 0.1 * decay]
    pose["head"] = [-0.3 * decay, 0, 0]
    for bone in ("armL", "armR"):
        pose[bone] = [-0.2 * decay, 0, 0.4 * decay]
    pose["cloth"] = [0.3 * decay, 0, 0]
    return pose


def death_pose(t):
    u = ease_in_out(t / 1.4)
    late = ease_in_out((t - 0.6) / 1.6)
    pose = zero()
    for bone in ("armL", "armR"):
        pose[bone] = [0.15 * u, 0, 0.12 * u]
    pose["torso"] = [0.65 * late, 0, 0.2 * late]
    pose["head"] = [0.7 * late, 0, 0.3 * late]
    for bone in ("legL", "legR"):
        pose[bone] = [0.5 * late, 0, 0.1 * u]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, -0.9 * u]
    pose["cloth"] = [0.3 * u, 0, 0]
    return pose


CLIPS = {
    "idle": (3.0, 0.0, True, idle_pose),
    "forming": (3.0, 0.0, True, forming_pose),
    "slam": (1.8, 1.1, False, slam_pose),
    "thrust": (1.6, 0.9, False, thrust_pose),
    "pull": (1.2, 0.0, True, pull_pose),
    "sweep": (2.0, 0.0, True, sweep_pose),
    "floor": (1.0, 0.0, True, floor_pose),
    "roar": (1.8, 0.0, False, roar_pose),
    "summon": (2.0, 0.0, False, summon_pose),
    "hit": (0.5, 0.0, False, hit_pose),
    "death": (2.4, 0.0, False, death_pose),
}


# --- Blender: the armature, the actions -----------------------------------------------------------

def build_armature():
    for obj in list(bpy.data.objects):
        if obj.name == "BossRig":
            bpy.data.objects.remove(obj, do_unlink=True)
    arm_data = bpy.data.armatures.new("BossRig")
    rig = bpy.data.objects.new("BossRig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit = arm_data.edit_bones

    def bone(name, head, tail, parent=None):
        b = edit.new(name)
        b.head, b.tail = head, tail
        if parent is not None:
            b.parent = edit[parent]
        return b

    bone("torso", (0, 0, 0), (0, 0, 1.4))
    bone("head", (0, 0, 1.4), (0, 0, 2.0), "torso")
    bone("armL", (0.9, 0, 1.2), (0.9, 0, 0.0), "torso")
    bone("armR", (-0.9, 0, 1.2), (-0.9, 0, 0.0), "torso")
    bone("legL", (0.35, 0, 0), (0.35, 0, -1.4), "torso")
    bone("legR", (-0.35, 0, 0), (-0.35, 0, -1.4), "torso")
    bone("wingL", (0.5, -0.2, 1.3), (1.8, -0.2, 1.3), "torso")
    bone("wingR", (-0.5, -0.2, 1.3), (-1.8, -0.2, 1.3), "torso")
    bone("cloth", (0, -0.3, 1.2), (0, -0.3, -0.8), "torso")
    bone("blades", (0, 0, 1.6), (0, 0, 2.4), "torso")
    bpy.ops.object.mode_set(mode="POSE")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    return rig


def key_actions(rig):
    for action in list(bpy.data.actions):
        if action.name.startswith("boss_"):
            bpy.data.actions.remove(action)
    rig.animation_data_create()
    for name, (length, _hit, _loop, pose) in CLIPS.items():
        action = bpy.data.actions.new(f"boss_{name}")
        rig.animation_data.action = action
        frames = int(round(length * FPS)) + 1
        for frame in range(frames):
            values = pose(frame / FPS)
            for bone in BONES:
                pb = rig.pose.bones[bone]
                pb.rotation_euler = tuple(values[bone])
                pb.keyframe_insert("rotation_euler", frame=frame + 1)
        action.use_fake_user = True
    return rig


def sample_actions(rig):
    """Read every action back out of Blender (what the game will play)."""
    scene = bpy.context.scene
    out = {}
    for name, (length, hit, loop, _pose) in CLIPS.items():
        action = bpy.data.actions[f"boss_{name}"]
        rig.animation_data.action = action
        frames = int(round(length * FPS)) + 1
        tracks = {bone: [] for bone in BONES}
        for frame in range(frames):
            scene.frame_set(frame + 1)
            for bone in BONES:
                e = rig.pose.bones[bone].rotation_euler
                tracks[bone].extend([round(e.x, 2), round(e.y, 2), round(e.z, 2)])
        out[name] = {"fps": FPS, "length": length, "hit": hit, "loop": loop, "bones": tracks}
    scene.frame_set(1)
    rig.animation_data.action = bpy.data.actions["boss_idle"]
    return out


def lua_number(x):
    text = f"{x:.2f}".rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def write_block(clips):
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    lines = [BEGIN + " (rewritten by tools/assetgen/blender_bossrig.py)", "SanctuaryConfig.BossClips = {"]
    for name, clip in clips.items():
        lines.append(f"\t{name} = {{ fps = {clip['fps']}, length = {lua_number(clip['length'])}, hit = {lua_number(clip['hit'])}, loop = {'true' if clip['loop'] else 'false'}, bones = {{")
        for bone, values in clip["bones"].items():
            lines.append(f"\t\t{bone} = {{ " + ", ".join(lua_number(v) for v in values) + " },")
        lines.append("\t} },")
    lines += ["}", END]
    body = newline.join(lines)
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        raise RuntimeError("BOSS-CLIPS block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main():
    rig = build_armature()
    key_actions(rig)
    clips = sample_actions(rig)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "clips.json"), "w", encoding="utf-8") as handle:
        json.dump(clips, handle)
    write_block(clips)
    total = sum(len(v) for clip in clips.values() for v in clip["bones"].values())
    print(f"{len(clips)} clips, {total} numbers -> SharedData.luau")


main()
