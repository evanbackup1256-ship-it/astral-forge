"""How each boss acts: the shared clips (clips.py) played through the boss's own temperament.

Speed, a stepped stop-motion feel, and extra moves layered on top (a lunge, a conducting hand, a
hover...). `channels(kind, clip, t)` returns the ten semantic channels for that boss at time t;
rigs.py maps those onto the bones of the boss's real skeleton.
"""

import math

import clips
from clips import CLIPS, TAU, ease_in_out, ease_out, lerp


def add(pose, bone, p=0.0, y=0.0, r=0.0):
    cur = pose[bone]
    pose[bone] = [cur[0] + p, cur[1] + y, cur[2] + r]


def knight(name, pose, t):
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
    elif name == "sweep":                      # slashing arcs: torso whips side to side
        add(pose, "torso", 0, math.sin(TAU * t / 2.0) * 0.9, 0)
        add(pose, "head", 0, -math.sin(TAU * t / 2.0) * 0.4, 0)
    elif name == "roar":
        pose["armR"] = [-1.9 * ease_out(t / 0.4), 0, 0.2]
    return pose


def seraph(name, pose, t):
    w = TAU / 1.6
    if name in ("idle", "forming"):            # hovering: legs trailing, wings beating wide
        for bone in ("legL", "legR"):
            pose[bone] = [0.35 + math.sin(w * 0.5 * t) * 0.05, 0, 0.06]
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 0.25 + math.sin(w * t) * 0.32]
        add(pose, "torso", 0.05, 0, 0)
        for bone in ("armL", "armR"):
            pose[bone] = [-0.2, 0, 0.5]
    elif name == "slam":
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


def regent(name, pose, t):
    w = TAU / 3.4
    if name == "idle":                         # heavy breathing, arms hanging wide
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
    elif name == "death":
        k = ease_in_out(t / 1.6)
        for bone in ("legL", "legR"):
            pose[bone] = [-0.8 * k, 0, 0.1]
    return pose


def rime(name, pose, t):
    if name in ("idle", "forming"):            # barely moving; ice settles with tiny shudders
        w = TAU / 4.5
        for bone in ("armL", "armR"):
            pose[bone] = [0.05 + math.sin(w * t) * 0.02, 0, 0.3]
        add(pose, "torso", 0, 0, math.sin(w * 2 * t) * 0.01)
    elif name == "slam":
        add(pose, "torso", -0.05 if t < 1.1 else 0.1, 0, 0)
    return pose


def warden(name, pose, t):
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


def choir(name, pose, t):
    if name in ("idle", "forming", "pull", "sweep", "floor"):   # always conducting
        beat = TAU * t / 2.0
        pose["armR"] = [-1.1 + math.sin(beat) * 0.55, math.sin(beat * 2) * 0.3, 0.25 + math.cos(beat) * 0.35]
        pose["armL"] = [-0.6 + math.sin(beat + math.pi) * 0.35, 0, 0.55 + math.sin(beat * 2) * 0.2]
        pose["head"] = [0.05, math.sin(beat * 0.5) * 0.2, math.sin(beat) * 0.05]
        add(pose, "torso", 0, math.sin(beat * 0.5) * 0.12, 0)
    elif name == "slam":
        pose["armR"] = [pose["armL"][0], 0, 0.2]
    elif name == "roar":
        for bone in ("armL", "armR"):
            pose[bone] = [-1.7 * ease_out(t / 0.4), 0, 0.9]
    return pose


# kind -> (speed multiplier, stepped fps or 0, modifier)
TEMPERAMENT = {
    "Knight": (1.0, 0, knight),
    "Seraph": (1.0, 0, seraph),
    "Regent": (1.3, 0, regent),
    "Rime": (1.5, 6, rime),
    "Warden": (1.0, 0, warden),
    "Choir": (1.0, 0, choir),
}


def clip_info(kind, name):
    speed = TEMPERAMENT[kind][0]
    length, hit, loop, _ = CLIPS[name]
    return round(length * speed, 2), round(hit * speed, 2), loop


def channels(kind, name, t):
    speed, steps, mod = TEMPERAMENT[kind]
    base = CLIPS[name][3]
    tt = t / speed
    if steps:
        tt = math.floor(tt * steps) / steps
    pose = base(tt)
    return mod(name, pose, tt)
