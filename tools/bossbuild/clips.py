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


# How each boss walks: seconds per full stride (both legs), leg swing, knee flex, arm swing, forward lean,
# torso twist and side-to-side weight shift (radians). build_boss.py sets GAIT for the boss being built.
GAIT = dict(length=1.2, stride=0.55, knee=0.7, arm=0.28, lean=0.08, twist=0.1, sway=0.04)


def _gait_pose(t, scale):
    """A real walk/run cycle at phase t / length: legs swing in opposition and the knee folds as each
    leg comes forward; arms counter-swing; the torso twists against the hips and rocks side to side;
    the head stays level; cloth trails a beat behind. `scale` > 1 turns it into a run."""
    g = GAIT
    length = g["length"] / (1.0 if scale == 1 else 1.8)
    phase = TAU * (t / length)
    s, c = math.sin(phase), math.cos(phase)
    pose = zero()
    stride = g["stride"] * (1.0 if scale == 1 else 1.35)
    knee = g["knee"] * (1.0 if scale == 1 else 1.4)
    arm = g["arm"] * (1.0 if scale == 1 else 1.7)
    lean = g["lean"] + (0.0 if scale == 1 else 0.2)
    # legs: pitch is the swing; the yaw slot carries the knee flex (the skeleton mapping reads it that way)
    pose["legL"] = [stride * s, max(1e-3, max(0.0, -c) * knee + 0.06), 0.04]
    pose["legR"] = [-stride * s, max(1e-3, max(0.0, c) * knee + 0.06), 0.04]
    pose["armL"] = [-arm * s - (0.0 if scale == 1 else 0.5), 0, 0.14]
    pose["armR"] = [arm * s - (0.0 if scale == 1 else 0.5), 0, 0.14]
    pose["torso"] = [lean + 0.02 * math.sin(2 * phase), g["twist"] * s, g["sway"] * s]
    pose["head"] = [-lean * 0.6, -g["twist"] * 0.6 * s, -g["sway"] * 0.6 * s]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.15 + 0.12 * math.sin(phase - 0.8)]
    pose["cloth"] = [0.12 + 0.1 * math.sin(phase - 1.1) + (0.0 if scale == 1 else 0.25), 0, 0.04 * s]
    pose["blades"] = [0, 0, 0.08 * s]
    return pose


def walk_pose(t):
    return _gait_pose(t, 1)


def run_pose(t):
    return _gait_pose(t, 2)
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
    "walk": (1.2, 0.0, True, walk_pose),
    "run": (0.67, 0.0, True, run_pose),
    "hit": (0.5, 0.0, False, hit_pose),
    "death": (2.4, 0.0, False, death_pose),
}
