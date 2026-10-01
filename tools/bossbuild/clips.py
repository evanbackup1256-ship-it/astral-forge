"""The eleven body clips every boss shares, as ten semantic channels (pitch, yaw, roll_out in
radians): torso, head, armL, armR, legL, legR, wingL, wingR, cloth, blades. Each boss maps
these onto its own bones (knight.py etc.), so the same acting reads differently on a knight,
a seraph or a glacier. Pitch is negative to raise an arm forward; roll is positive to swing a
limb outward.
"""

import math

TAU = math.tau
CHANNELS = ["torso", "head", "armL", "armR", "legL", "legR", "wingL", "wingR", "cloth", "blades"]


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
    return {c: [0.0, 0.0, 0.0] for c in CHANNELS}


def idle_pose(t):
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
        pose[bone] = [-0.75, 0, -0.25]
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


# name -> (length seconds, strike moment or 0, loops, pose function)
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
