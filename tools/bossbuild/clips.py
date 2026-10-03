"""The body clips every boss shares, as eleven semantic channels (pitch, yaw, roll_out in radians):
hips, torso, head, armL, armR, legL, legR, wingL, wingR, cloth, blades. Each boss maps these onto its own
bones (knight.py etc.) and plays them through its own temperament (acting.py), so the same acting reads
differently on a knight, a seraph or a glacier. Pitch is negative to raise an arm forward; roll is
positive to swing a limb outward.

What makes these clips read as acting rather than interpolation:
  * anticipation: every strike dips and coils BEFORE it launches;
  * overshoot and settle: a launched limb passes its mark and rings down (damped oscillation);
  * weight: the hips lead, the torso follows, the head and arms trail, and the feet stay planted;
  * follow-through: wings and cloth keep moving after the body stops;
  * loops close exactly: every periodic term has a whole number of cycles in the clip.
Strike times (`hit`) and clip lengths are unchanged from the original set, so the game's timing holds.
"""

import math

TAU = math.tau
CHANNELS = ["hips", "torso", "head", "armL", "armR", "legL", "legR", "wingL", "wingR", "cloth", "blades"]


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_out(x):
    return 1 - (1 - clamp(x)) ** 3


def ease_in(x):
    x = clamp(x)
    return x * x * x


def ease_in_out(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def ease_out_back(x, overshoot=1.7):
    x = clamp(x)
    c3 = overshoot + 1
    return 1 + c3 * (x - 1) ** 3 + overshoot * (x - 1) ** 2


def lerp(a, b, k):
    return a + (b - a) * k


def ring(t, freq, decay):
    """A damped oscillation: 1 at t=0, ringing at `freq` Hz and dying away at rate `decay`."""
    if t < 0:
        return 0.0
    return math.exp(-decay * t) * math.cos(TAU * freq * t)


def zero():
    return {c: [0.0, 0.0, 0.0] for c in CHANNELS}


def idle_pose(t):
    """Breathing, a slow shift of weight from one foot to the other, a head that wanders, arms that hang
    with a little life in them. Every frequency is a whole number of cycles per 3 s."""
    pose = zero()
    w = TAU / 3.0
    breath = math.sin(w * 2 * t)                       # two breaths per loop
    shift = math.sin(w * t)                            # one weight shift per loop
    pose["hips"] = [0.012 * breath, 0.035 * shift, 0.045 * shift]
    pose["torso"] = [0.02 * breath + 0.015, -0.03 * shift, -0.025 * shift + 0.006 * math.sin(w * 3 * t)]
    pose["head"] = [0.025 * math.sin(w * 3 * t + 0.6) - 0.01, 0.07 * math.sin(w * t + 1.2), 0.02 * shift]
    for index, bone in enumerate(("armL", "armR")):
        lag = 0.5 + index * 0.35
        pose[bone] = [-0.08 + 0.05 * math.sin(w * 2 * t - lag) + 0.02 * breath, 0.02 * shift, 0.14 + 0.04 * math.sin(w * t - lag)]
    pose["legL"] = [0.07 * shift, 0, 0.04 + 0.02 * max(0.0, shift)]
    pose["legR"] = [-0.07 * shift, 0, 0.04 + 0.02 * max(0.0, -shift)]
    for bone, ph in (("wingL", 0.0), ("wingR", 0.25)):
        pose[bone] = [0.03 * math.sin(w * 2 * t + ph), 0, 0.14 + 0.16 * math.sin(w * 3 * t + ph)]
    pose["cloth"] = [0.1 + 0.06 * math.sin(w * 2 * t - 0.8), 0, 0.05 * math.sin(w * t - 0.5)]
    pose["blades"] = [0, 0, 0.1 * math.sin(w * t)]
    return pose


def looped_idle(t, length):
    """The idle rhythm squeezed to fit a shorter loop, so a clip built on it still closes its seam."""
    return idle_pose(t * 3.0 / length)


def forming_pose(t):
    """Rising out of the rift: curled and head-down, then unfolding, arms drawn up and open."""
    pose = idle_pose(t)
    w = TAU / 3.0
    swell = 0.5 - 0.5 * math.cos(w * t)                # 0 -> 1 -> 0 over the loop
    pose["hips"] = [0.1 - 0.08 * swell, 0.04 * math.sin(w * t), 0]
    pose["torso"] = [0.28 - 0.3 * swell, 0, 0.03 * math.sin(w * 2 * t)]
    pose["head"] = [0.4 - 0.5 * swell, 0.12 * math.sin(w * t), 0]
    for bone, side in (("armL", 1), ("armR", -1)):
        pose[bone] = [-0.35 - 0.5 * swell, 0, -0.1 + 0.4 * swell]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0.4 - 0.2 * swell, -0.5 + 0.6 * swell]
    pose["cloth"] = [0.25 - 0.3 * swell, 0, 0.1 * math.sin(w * t)]
    return pose


def slam_pose(t):
    """Anticipation (a dip and a coil), a slow overhead gather, a held breath, then a fast strike that
    overshoots and rings down. Strike at t = 1.1."""
    hit, strike = 1.1, 0.25
    pose = idle_pose(t)
    if t < hit:
        dip = ease_in_out(t / 0.3) * (1 - ease_in_out((t - 0.3) / 0.3))     # a small crouch before the gather
        u = ease_in_out((t - 0.2) / (hit - 0.2))
        hold = ease_in_out((t - 0.85) / 0.25)                                # the last breath held at the top
        pose["hips"] = [0.1 * dip - 0.06 * u, 0.0, 0.0]
        pose["armL"] = [-2.35 * u - 0.12 * hold, 0, 0.1]
        pose["armR"] = [-0.7 * u, 0, 0.35 * u]
        pose["torso"] = [-0.32 * u + 0.1 * dip, -0.1 * u, 0]
        pose["head"] = [-0.25 * u - 0.05 * hold, 0, 0]
        pose["legL"] = [0.15 * u + 0.12 * dip, 0, 0.05]
        pose["legR"] = [0.15 * u + 0.12 * dip, 0, 0.05]
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, 0.12 + 0.35 * u]
    else:
        v = ease_out((t - hit) / strike)
        settle = ease_in_out((t - hit - strike) / 0.45)
        ringing = ring(t - hit - strike, 3.5, 5.0)                           # the blow shudders through the body
        pose["hips"] = [0.18 * v * (1 - settle) + 0.03 * ringing, 0.0, 0.0]
        pose["armL"] = [lerp(-2.35, 0.35, v) * (1 - settle) - 0.08 * settle - 0.12 * ringing * (1 - settle), 0, 0.1]
        pose["armR"] = [-0.3, 0, 0.3 * (1 - settle) + 0.14 * settle]
        pose["torso"] = [lerp(-0.32, 0.45, v) * (1 - settle) + 0.04 * ringing, 0.08 * (1 - settle), 0]
        pose["head"] = [0.15 * (1 - settle) + 0.05 * ringing, 0, 0]
        pose["legL"] = [0.12 * (1 - settle), 0, 0.08]
        pose["legR"] = [0.12 * (1 - settle), 0, 0.08]
        for bone in ("wingL", "wingR"):
            pose[bone] = [0, 0, lerp(0.5, -0.15, v) * (1 - settle) + 0.12 * settle + 0.06 * ringing]
    # cloth is thrown forward by the gather and snaps back late (follow-through)
    pose["cloth"] = [0.1 + (-0.3 if t < hit else 0.35 * (1 - clamp((t - hit) / 0.9)) + 0.08 * ring(t - hit, 2.0, 3.0)), 0, 0]
    return pose


def thrust_pose(t):
    """Coil away from the target, hold, then lance forward and recover with a rebound. Strike at 0.9."""
    hit = 0.9
    pose = idle_pose(t)
    if t < hit:
        u = ease_in_out(t / hit)
        coil = ease_in_out(t / 0.45) * (1 - 0.4 * ease_in_out((t - 0.45) / 0.45))
        for bone in ("armL", "armR"):
            pose[bone] = [-0.15 + 0.1 * coil, 0, 1.15 * u]
        pose["torso"] = [-0.15 * u, 0.3 * coil, 0]
        pose["hips"] = [0.05 * u, 0.12 * coil, 0]
        pose["legL"] = [-0.1 * u, 0, 0.06]
        pose["legR"] = [0.18 * u, 0, 0.06]
    else:
        v = ease_out_back((t - hit) / 0.18, 1.2)
        settle = ease_in_out((t - hit - 0.18) / 0.4)
        rebound = ring(t - hit - 0.18, 3.0, 5.0)
        for bone in ("armL", "armR"):
            pose[bone] = [lerp(-0.15, -1.55, v) * (1 - settle) - 0.08 * settle, 0, lerp(1.15, 0.12, clamp(v)) * (1 - settle) + 0.14 * settle]
        pose["torso"] = [0.35 * v * (1 - settle) + 0.03 * rebound, lerp(0.3, -0.12, clamp(v)) * (1 - settle), 0]
        pose["hips"] = [0.16 * clamp(v) * (1 - settle), lerp(0.12, -0.1, clamp(v)) * (1 - settle), 0]
        pose["legL"] = [-0.5 * clamp(v) * (1 - settle), 0, 0.1]
        pose["legR"] = [0.3 * clamp(v) * (1 - settle), 0, 0.1]
    pose["cloth"] = [0.12 + 0.12 * ring(t - hit, 2.5, 3.0), 0, 0]
    return pose


def pull_pose(t):
    pose = looped_idle(t, 1.2)
    w = TAU / 1.2
    for index, bone in enumerate(("armL", "armR")):
        drag = 0.5 + 0.5 * math.sin(w * t + index * math.pi)
        pose[bone] = [-1.0 - 0.5 * drag, 0, 0.3 - 0.2 * drag]
    pose["torso"] = [0.18 + 0.06 * math.sin(w * t), 0.06 * math.sin(w * t + 1.0), 0]
    pose["hips"] = [0.08, 0, 0.04 * math.sin(w * t)]
    pose["head"] = [-0.1, 0, 0]
    pose["legL"] = [0.12, 0, 0.1]
    pose["legR"] = [-0.1, 0, 0.1]
    return pose


def sweep_pose(t):
    pose = looped_idle(t, 2.0)
    w = TAU * 2 / 2.0
    pose["armL"] = [-1.55, 0, 0.05 + 0.04 * math.sin(w * t)]
    pose["armR"] = [-0.4, 0, 0.5]
    pose["torso"] = [0.0, 0.14 * math.sin(w * t / 2), 0.12]
    pose["hips"] = [0.04, -0.08 * math.sin(w * t / 2), 0.03]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.3 + 0.15 * math.sin(TAU * 2 * t)]
    return pose


def floor_pose(t):
    pose = looped_idle(t, 1.0)
    for index, bone in enumerate(("armL", "armR")):
        pose[bone] = [0.35 + 0.1 * math.sin(TAU * t + index * 2), 0, 0.35]
    pose["torso"] = [0.3, 0, 0]
    pose["hips"] = [0.1, 0, 0.05 * math.sin(TAU * t)]
    pose["head"] = [-0.12, 0, 0]
    return pose


def roar_pose(t):
    """Lean in, then throw the head back and open the body; a tremor runs through the held pose."""
    u = ease_out_back(t / 0.5, 1.1)
    pre = ease_in_out(t / 0.2) * (1 - ease_in_out((t - 0.2) / 0.3))          # a quick lean in before the roar
    pose = idle_pose(t)
    shake = math.sin(TAU * 7 * t) * 0.025 * clamp(t / 0.5)
    for bone in ("armL", "armR"):
        pose[bone] = [-0.35 * u + shake, 0, 1.3 * u]
    pose["head"] = [-0.5 * u + 0.12 * pre, shake, 0]
    pose["torso"] = [-0.28 * u + 0.15 * pre, 0, shake * 0.6]
    pose["hips"] = [0.06 * u, 0, 0]
    pose["legL"] = [0.05 * u, 0, 0.08 * u]
    pose["legR"] = [0.05 * u, 0, 0.08 * u]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.12 + 0.58 * u + math.sin(TAU * 3 * t) * 0.05 * u]
    pose["cloth"] = [0.1 - 0.25 * u + 0.1 * ring(t - 0.3, 2.0, 2.0), 0, 0]
    return pose


def summon_pose(t):
    u = ease_out(t / 0.7)
    pose = idle_pose(t)
    pulse = math.sin(TAU * 2 * t) * 0.08
    for index, bone in enumerate(("armL", "armR")):
        pose[bone] = [-2.0 * u + pulse * (1 if index == 0 else -1), 0, 0.5 * u]
    pose["head"] = [-0.3 * u, 0.05 * math.sin(TAU * t), 0]
    pose["torso"] = [-0.15 * u, 0, 0]
    pose["hips"] = [-0.04 * u, 0, 0]
    pose["legL"] = [-0.04 * u, 0, 0.05]
    pose["legR"] = [-0.04 * u, 0, 0.05]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, 0.12 + 0.4 * u]
    pose["cloth"] = [0.1 - 0.2 * u, 0, 0]
    return pose


def hit_pose(t):
    """A sharp flinch that rebounds once and settles, rather than a flat decay."""
    decay = (1 - clamp(t / 0.5)) ** 2
    rebound = ring(t, 4.0, 6.0)
    pose = zero()
    pose["torso"] = [-0.35 * decay * (0.6 + 0.4 * rebound), 0, 0.1 * decay]
    pose["hips"] = [0.1 * decay, 0, 0]
    pose["head"] = [-0.3 * decay * (0.5 + 0.5 * rebound), 0.06 * decay, 0]
    for bone in ("armL", "armR"):
        pose[bone] = [-0.2 * decay, 0, 0.4 * decay]
    pose["cloth"] = [0.3 * decay, 0, 0]
    return pose


def death_pose(t):
    """The knees go first, the torso follows, the head last; the arms swing then drop; a small bounce at the end."""
    knees = ease_in_out(t / 0.9)
    u = ease_in_out(t / 1.4)
    late = ease_in_out((t - 0.6) / 1.6)
    bounce = ring(t - 2.0, 2.5, 4.0) * 0.04 * ease_in_out((t - 1.9) / 0.1) if t > 1.9 else 0.0
    pose = zero()
    pose["hips"] = [0.35 * knees + bounce, 0, 0.1 * late]
    for index, bone in enumerate(("armL", "armR")):
        pose[bone] = [0.15 * u - 0.3 * math.sin(clamp(t / 0.8) * math.pi) * (1 - late), 0, 0.12 * u + 0.2 * math.sin(clamp(t / 0.8) * math.pi)]
    pose["torso"] = [0.65 * late + bounce, 0, 0.2 * late]
    pose["head"] = [0.7 * ease_in_out((t - 0.9) / 1.4), 0, 0.3 * late]
    for bone in ("legL", "legR"):
        pose[bone] = [0.5 * knees, 0, 0.1 * u]
    for bone in ("wingL", "wingR"):
        pose[bone] = [0, 0, -0.9 * u]
    pose["cloth"] = [0.3 * u, 0, 0]
    return pose


# How each boss walks: seconds per full stride (both legs), leg swing, knee flex, arm swing, forward lean,
# torso twist and side-to-side weight shift (radians). build_boss.py sets GAIT for the boss being built.
GAIT = dict(length=1.2, stride=0.55, knee=0.7, arm=0.28, lean=0.08, twist=0.1, sway=0.04)


def _gait_pose(t, scale):
    """A real walk/run cycle at phase t / length: legs swing in opposition and the knee folds as each
    leg comes forward; the hips counter-rotate against the shoulders and drop onto the planted foot; arms
    counter-swing; the head stays level; cloth trails a beat behind. `scale` > 1 turns it into a run."""
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
    pose["hips"] = [0.015 * math.sin(2 * phase + 0.4), -g["twist"] * 0.8 * s, g["sway"] * 1.2 * s]
    pose["torso"] = [lean + 0.02 * math.sin(2 * phase), g["twist"] * s, g["sway"] * s]
    pose["head"] = [-lean * 0.6, -g["twist"] * 0.6 * s, -g["sway"] * 0.6 * s]
    for bone, lag in (("wingL", 0.0), ("wingR", 0.3)):
        pose[bone] = [0, 0, 0.15 + 0.12 * math.sin(phase - 0.8 - lag)]
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
