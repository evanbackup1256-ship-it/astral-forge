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


# --- per-boss acting ------------------------------------------------------------------------------
# Each boss plays the shared clips through its own temperament: speed, amplitude, a stepped
# (stop-motion) feel, and extra moves layered on (a lunge, a conducting hand, a hover...).

def add(pose, bone, p=0.0, y=0.0, r=0.0):
    cur = pose[bone]
    pose[bone] = [cur[0] + p, cur[1] + y, cur[2] + r]


def knight_mod(name, pose, t, length):
    w = TAU / 2.4
    if name == "idle":                         # a guarded fencer's stance, weight shifting
        pose["armL"] = [-0.55 + math.sin(w * t) * 0.05, 0, 0.35]
        pose["armR"] = [-0.8 + math.sin(w * t + 1) * 0.06, 0, 0.1]
        add(pose, "torso", 0.04, math.sin(w * 0.5 * t) * 0.12, 0)
        pose["legL"] = [-0.18, 0, 0.12]
        pose["legR"] = [0.12, 0, 0.1]
    elif name == "slam":                       # two-handed overhead chop with a lunge
        u = ease_in_out(t / 1.1)
        pose["armR"] = [pose["armL"][0], 0, 0.12]
        if t >= 1.1:
            v = ease_out((t - 1.1) / 0.25)
            pose["legL"] = [-0.55 * v, 0, 0.1]
            pose["legR"] = [0.35 * v, 0, 0.1]
        else:
            pose["legL"] = [0.1 * u, 0, 0.05]
    elif name == "thrust":                     # fencing lunge, off hand thrown back
        if t >= 0.9:
            v = ease_out((t - 0.9) / 0.18)
            pose["legL"] = [-0.8 * v, 0, 0.12]
            pose["legR"] = [0.45 * v, 0, 0.1]
            pose["armL"] = [0.5 * v, 0, 0.5 * v]
        add(pose, "torso", 0.0, 0.0, 0.0)
    elif name == "sweep":                      # slashing arcs: torso whips side to side
        add(pose, "torso", 0, math.sin(TAU * t / 2.0) * 0.9, 0)
        add(pose, "head", 0, -math.sin(TAU * t / 2.0) * 0.4, 0)
    elif name == "roar":
        pose["armR"] = [-1.9 * ease_out(t / 0.4), 0, 0.2]                  # sword salute
    return pose


def seraph_mod(name, pose, t, length):
    w = TAU / 1.6
    if name in ("idle", "forming"):            # hovering: slow bob, legs trailing, wings beating wide
        for bone in ("legL", "legR"):
            pose[bone] = [0.35 + math.sin(w * 0.5 * t) * 0.05, 0, 0.06]
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 0.25 + math.sin(w * t) * 0.32]
        add(pose, "torso", 0.05, 0, 0)
        for bone in ("armL", "armR"):
            pose[bone] = [-0.2, 0, 0.5]
    elif name == "slam":                       # wings sweep down with the blow
        u = ease_in_out(t / 1.1)
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 0.9 * u if t < 1.1 else lerp(0.9, -0.7, ease_out((t - 1.1) / 0.2))]
    elif name == "roar":
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 1.0 * ease_out(t / 0.4) + math.sin(TAU * 4 * t) * 0.06]
    elif name == "summon":
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 0.7 + math.sin(TAU * 2 * t) * 0.15]
    return pose


def regent_mod(name, pose, t, length):
    w = TAU / 3.4
    if name == "idle":                         # heavy breathing, arms hanging wide like a gorilla
        add(pose, "torso", math.sin(w * t) * 0.03, 0, 0)
        for bone in ("armL", "armR"):
            pose[bone] = [0.1 + math.sin(w * t) * 0.04, 0, 0.45]
        for bone in ("legL", "legR"):
            pose[bone] = [0, 0, 0.12]
    elif name == "slam":                       # both fists overhead then a ground-shaking pound
        pose["armR"] = list(pose["armL"])
        pose["armR"][2] = pose["armL"][2] + 0.1
        add(pose, "torso", -0.1 if t < 1.1 else 0.15, 0, 0)
    elif name == "pull":
        for bone in ("armL", "armR"):
            add(pose, bone, 0.2, 0, 0.2)
    elif name == "death":                      # sinks to its knees then topples forward
        k = ease_in_out(t / 1.6)
        for bone in ("legL", "legR"):
            pose[bone] = [-0.8 * k, 0, 0.1]
    return pose


def rime_mod(name, pose, t, length):
    if name in ("idle", "forming"):            # barely moving; ice settles with tiny shudders
        w = TAU / 4.5
        for bone in ("armL", "armR"):
            pose[bone] = [0.05 + math.sin(w * t) * 0.02, 0, 0.3]
        add(pose, "torso", 0, 0, math.sin(w * 2 * t) * 0.01)
    elif name == "slam":
        add(pose, "torso", -0.05 if t < 1.1 else 0.1, 0, 0)
    return pose


def warden_mod(name, pose, t, length):
    w = TAU / 3.6
    if name in ("idle", "forming"):            # hands float up as if holding something unseen
        pose["armL"] = [-0.7 + math.sin(w * t) * 0.12, 0, 0.55 + math.sin(w * t + 1) * 0.1]
        pose["armR"] = [-0.7 + math.sin(w * t + 2) * 0.12, 0, 0.55 + math.sin(w * t + 3) * 0.1]
        pose["head"] = [-0.1 + math.sin(w * 1.3 * t) * 0.05, math.sin(w * 0.5 * t) * 0.15, 0]
        for bone in ("legL", "legR"):
            pose[bone] = [0, 0, 0.02]
    elif name == "slam":
        add(pose, "head", -0.15 if t < 1.1 else 0.2, 0, 0)
    elif name == "summon":
        for bone in ("armL", "armR"):
            add(pose, bone, 0, 0, 0.4 * ease_out(t / 0.6))
    return pose


def choir_mod(name, pose, t, length):
    w = TAU / 2.0
    if name in ("idle", "forming", "pull", "sweep", "floor"):   # always conducting
        beat = TAU * t / 2.0
        pose["armR"] = [-1.1 + math.sin(beat) * 0.55, math.sin(beat * 2) * 0.3, 0.25 + math.cos(beat) * 0.35]
        pose["armL"] = [-0.6 + math.sin(beat + math.pi) * 0.35, 0, 0.55 + math.sin(beat * 2) * 0.2]
        pose["head"] = [0.05, math.sin(beat * 0.5) * 0.2, math.sin(beat) * 0.05]
        add(pose, "torso", 0, math.sin(beat * 0.5) * 0.12, 0)
    elif name == "slam":                       # the downbeat
        pose["armR"] = [pose["armL"][0], 0, 0.2]
    elif name == "roar":
        for bone in ("armL", "armR"):
            pose[bone] = [-1.7 * ease_out(t / 0.4), 0, 0.9]
    return pose


# kind -> (speed multiplier, stepped fps or 0, modifier)
VARIANTS = {
    "default": (1.0, 0, None),
    "Knight": (1.0, 0, knight_mod),
    "Seraph": (1.0, 0, seraph_mod),
    "Regent": (1.3, 0, regent_mod),
    "Rime": (1.5, 6, rime_mod),
    "Warden": (1.0, 0, warden_mod),
    "Choir": (1.0, 0, choir_mod),
}


def variant_pose(kind, name):
    speed, steps, mod = VARIANTS[kind]
    length, hit, loop, base = CLIPS[name]

    def pose(t):
        tt = t / speed
        if steps:
            tt = math.floor(tt * steps) / steps
        p = base(tt)
        if mod is not None:
            p = mod(name, p, tt, length)
        return p

    return pose


# --- Blender: the armature, the actions --------------------------------------------------------------

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


def key_and_sample(rig):
    """Key every boss's version of every clip on the armature and read it back out."""
    for action in list(bpy.data.actions):
        if action.name.startswith("boss_"):
            bpy.data.actions.remove(action)
    rig.animation_data_create()
    scene = bpy.context.scene
    result = {}
    for kind in VARIANTS:
        result[kind] = {}
        speed = VARIANTS[kind][0]
        for name, (length, hit, loop, _base) in CLIPS.items():
            pose_fn = variant_pose(kind, name)
            real_length = round(length * speed, 2)
            hit_time = round(hit * speed, 2)
            action = bpy.data.actions.new(f"boss_{kind}_{name}")
            action.use_fake_user = True
            rig.animation_data.action = action
            frames = int(round(real_length * FPS)) + 1
            for frame in range(frames):
                values = pose_fn(frame / FPS)
                for bone in BONES:
                    pb = rig.pose.bones[bone]
                    pb.rotation_euler = tuple(values[bone])
                    pb.keyframe_insert("rotation_euler", frame=frame + 1)
            tracks = {bone: [] for bone in BONES}
            for frame in range(frames):
                scene.frame_set(frame + 1)
                for bone in BONES:
                    e = rig.pose.bones[bone].rotation_euler
                    tracks[bone].extend([round(e.x, 2), round(e.y, 2), round(e.z, 2)])
            sparse = {b: v for b, v in tracks.items() if any(abs(x) > 0.004 for x in v)}
            result[kind][name] = {"fps": FPS, "length": real_length, "hit": hit_time, "loop": loop, "bones": sparse}
    scene.frame_set(1)
    return result


def lua_number(x):
    text = f"{x:.2f}".rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def write_block(all_clips):
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    newline = "\r\n" if "\r\n" in source else "\n"
    lines = [BEGIN + " (rewritten by tools/assetgen/blender_bossrig.py)", "SanctuaryConfig.BossClips = {"]
    for kind, clips in all_clips.items():
        lines.append(f"\t{kind} = {{")
        for name, clip in clips.items():
            lines.append(f"\t\t{name} = {{ fps = {clip['fps']}, length = {lua_number(clip['length'])}, hit = {lua_number(clip['hit'])}, loop = {'true' if clip['loop'] else 'false'}, bones = {{")
            for bone, values in clip["bones"].items():
                lines.append(f"\t\t\t{bone} = {{ " + ", ".join(lua_number(v) for v in values) + " },")
            lines.append("\t\t} },")
        lines.append("\t},")
    lines += ["}", END]
    body = newline.join(lines)
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        raise RuntimeError("BOSS-CLIPS block missing from SharedData.luau")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(pattern.sub(lambda _: body, source, count=1))


def main():
    rig = build_armature()
    all_clips = key_and_sample(rig)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "clips.json"), "w", encoding="utf-8") as handle:
        json.dump(all_clips, handle)
    write_block(all_clips)
    total = sum(len(v) for clips in all_clips.values() for clip in clips.values() for v in clip["bones"].values())
    print(f"{len(all_clips)} boss variants x {len(CLIPS)} clips, {total} numbers -> SharedData.luau")


main()