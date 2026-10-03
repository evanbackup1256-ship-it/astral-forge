"""A shared humanoid skeleton and the mapping from the eleven shared clip channels onto it, so
each boss script only has to model its own pieces. Metres, +Z up, facing -Y; left = +X."""

from lib import V

DEFAULT = dict(
    hip_z=1.40, chest_z=2.2, neck_z=2.52, head_top=3.05,
    shoulder_x=0.80, shoulder_z=2.42, elbow_z=1.78, wrist_z=1.12, hand_z=0.82,
    hip_x=0.30, knee_z=0.78, ankle_z=0.14, foot_len=0.32,
)


def skeleton(boss, **over):
    d = dict(DEFAULT)
    d.update(over)
    boss.bone("hips", None, V(0, 0, d["hip_z"]), V(0, 0, d["hip_z"] + 0.2))
    boss.bone("spine", "hips", V(0, 0, d["hip_z"] + 0.2), V(0, 0, d["chest_z"]))
    boss.bone("head", "spine", V(0, 0, d["neck_z"]), V(0, 0, d["head_top"]))
    for s, n in ((1, "L"), (-1, "R")):
        sx = d["shoulder_x"] * s
        boss.bone(f"upperArm{n}", "spine", V(sx, 0, d["shoulder_z"]), V(sx + 0.04 * s, 0, d["elbow_z"]))
        boss.bone(f"lowerArm{n}", f"upperArm{n}", V(sx + 0.04 * s, 0, d["elbow_z"]), V(sx + 0.06 * s, -0.10, d["wrist_z"]))
        boss.bone(f"hand{n}", f"lowerArm{n}", V(sx + 0.06 * s, -0.10, d["wrist_z"]), V(sx + 0.06 * s, -0.14, d["hand_z"]))
        hx = d["hip_x"] * s
        boss.bone(f"upperLeg{n}", "hips", V(hx, 0, d["hip_z"] - 0.02), V(hx + 0.02 * s, 0, d["knee_z"]))
        boss.bone(f"lowerLeg{n}", f"upperLeg{n}", V(hx + 0.02 * s, 0, d["knee_z"]), V(hx + 0.02 * s, 0, d["ankle_z"]))
        boss.bone(f"foot{n}", f"lowerLeg{n}", V(hx + 0.02 * s, 0, d["ankle_z"]), V(hx + 0.02 * s, -d["foot_len"], 0.05))
    return d


def chain(boss, prefix, parent, top, bottom, count, y=0.0, dy=0.06):
    """A hanging chain of `count` bones from `top` down to `bottom` (cloaks, skirts, coats)."""
    names = []
    for i in range(count):
        a = top + (bottom - top) * (i / count)
        b = top + (bottom - top) * ((i + 1) / count)
        name = f"{prefix}{i + 1}"
        boss.bone(name, parent if i == 0 else names[-1], V(a.x, y + dy * i, a.z), V(b.x, y + dy * (i + 1), b.z))
        names.append(name)
    return names


def map_humanoid(c, arm_scale=0.85, elbow=-0.22, knee=0.55):
    pose = {}
    pose["hips"] = tuple(c["hips"])
    pose["spine"] = tuple(c["torso"])
    pose["head"] = tuple(c["head"])
    for chan, n in (("armL", "L"), ("armR", "R")):
        p, y, r = c[chan]
        pose[f"upperArm{n}"] = (p * arm_scale, y * arm_scale, r * arm_scale)
        pose[f"lowerArm{n}"] = (elbow + min(0.0, p) * 0.4 + max(0.0, p) * 0.1, 0, 0)
        pose[f"hand{n}"] = (p * 0.08, 0, 0)
    for chan, n in (("legL", "L"), ("legR", "R")):
        p, y, r = c[chan]
        if y > 0:                              # gait clips: the yaw slot is the knee flex
            pose[f"upperLeg{n}"] = (p, 0, r)
            pose[f"lowerLeg{n}"] = (y, 0, 0)
            pose[f"foot{n}"] = (-y * 0.35 + p * 0.15, 0, 0)
        else:
            pose[f"upperLeg{n}"] = (p, y, r)
            pose[f"lowerLeg{n}"] = (abs(p) * knee + 0.04, 0, 0)
            pose[f"foot{n}"] = (-abs(p) * 0.3, 0, 0)
    return pose


def map_chain(pose, c, prefix, count, base_channel="cloth", lag=0.9):
    cp, cy, cr = c[base_channel]
    for i in range(count):
        k = lag ** i
        pose[f"{prefix}{i + 1}"] = (cp * k + 0.05 * i, cy, cr * k)
    return pose
