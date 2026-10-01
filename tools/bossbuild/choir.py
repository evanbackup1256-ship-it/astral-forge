"""The Hollow Choir: a tall, slender conductor of cyan glass. A featureless mask with a thin
glowing seam under a crown of seven crystals, a long split coat of glass shards, a white singing
core in a lattice at the chest, a baton in the right hand, and seven tuning-fork blades fanned
out behind. About 3.4 m tall, facing -Y."""

import math

import humanoid
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

KIND = "Choir"
GLASS, SILVER, CORE, COAT, CRYSTAL = 0, 1, 2, 3, 4
MATERIALS = {
    "glass": dict(base=((0.35, 0.65, 0.8), (0.8, 0.95, 1.0)), rough=0.12, metal=0.2, noise_scale=5.0, scale=4.0, veins=(0.6, 0.95, 1.0), vein_width=0.03, voro_scale=3.0, veins_glow=0.6),
    "silver": dict(base=((0.35, 0.4, 0.46), (0.8, 0.86, 0.92)), rough=0.3, metal=0.9, noise_scale=9.0),
    "core": dict(base=(0.9, 0.98, 1.0), rough=0.3, emit=(0.7, 0.95, 1.0, 1.4), noise_scale=4.0),
    "coat": dict(base=((0.25, 0.45, 0.6), (0.65, 0.85, 0.95)), rough=0.6, noise_scale=12.0, scale=7.0, veins=(0.5, 0.9, 1.0), vein_width=0.025, voro_scale=4.5, veins_glow=0.5),
    "crystal": dict(base=((0.3, 0.75, 0.95), (0.7, 1.0, 1.0)), rough=0.1, metal=0.1, noise_scale=6.0, emit=(0.35, 0.85, 1.0, 0.6)),
}
ORDER = ["glass", "silver", "core", "coat", "crystal"]


def crystal_spike(bm, base, tip, r, mat=CRYSTAL):
    return frustum(bm, base, tip, r, 0.004, 6, mat, smooth=False)


def build():
    boss = Boss(KIND, ORDER)
    humanoid.skeleton(boss, hip_z=1.5, chest_z=2.45, neck_z=2.8, head_top=3.3, shoulder_x=0.62, shoulder_z=2.68, elbow_z=1.98, wrist_z=1.3, hand_z=0.98, hip_x=0.2, knee_z=0.86, ankle_z=0.14)
    coat = humanoid.chain(boss, "coat", "hips", V(0, 0.05, 1.6), V(0, 0.05, 0.12), 3, y=0.04, dy=0.05)
    boss.bone("blades", "spine", V(0, 0.32, 2.7), V(0, 0.32, 3.4))

    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.55), (0.62, 0.36, 0.2), GLASS, bevel=0.03)
    box(bm, V(0, -0.2, 1.55), (0.18, 0.05, 0.2), SILVER, bevel=0.015)
    for s in (1, -1):
        crystal_spike(bm, V(0.3 * s, 0, 1.55), V(0.46 * s, 0, 1.8), 0.06)
        ellipsoid(bm, V(0.2 * s, 0, 1.48), (0.12, 0.12, 0.12), SILVER, 10)

    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.6), V(0, 0, 2.2), 0.28, 0.34, 14, GLASS, squash=0.7)
    ellipsoid(bm, V(0, 0, 2.45), (0.4, 0.26, 0.4), GLASS, 16)
    for k in range(3):                                                         # lattice ring round the core
        frustum(bm, V(0, -0.1 - k * 0.0, 2.4 + (k - 1) * 0.16), V(0, -0.1, 2.4 + (k - 1) * 0.16 + 0.02), 0.22 - abs(k - 1) * 0.04, 0.22 - abs(k - 1) * 0.04, 12, SILVER)
    ellipsoid(bm, V(0, -0.2, 2.4), (0.12, 0.08, 0.12), CORE, 12)               # the singing core
    plate(bm, [(0, 0.3), (0.07, 0), (0, -0.3), (-0.07, 0)], V(0, -0.27, 2.4), (1, 0, 0), (0, 0.1, 1), 0.02, CORE)
    for s in (1, -1):                                                          # shoulder crystal clusters
        for k, (dx, h) in enumerate(((0.0, 0.7), (0.14, 0.5), (-0.12, 0.45))):
            crystal_spike(bm, V((0.6 + dx) * s, 0, 2.7), V((0.66 + dx * 1.4) * s, 0.02 * k, 2.7 + h), 0.07)
    for k in range(7):                                                         # coat collar
        a = (k - 3) * 0.17
        crystal_spike(bm, V(a, 0.18, 2.74), V(a * 1.6, 0.28, 3.0 + 0.1 * (3 - abs(k - 3))), 0.04)
    frustum(bm, V(0, 0, 2.7), V(0, 0, 2.86), 0.2, 0.16, 12, SILVER)

    bm = boss.piece("head", "head")
    ellipsoid(bm, V(0, 0, 3.06), (0.27, 0.3, 0.34), GLASS, 16)                  # blank mask
    plate(bm, [(-0.012, 0.28), (0.012, 0.28), (0.012, -0.24), (-0.012, -0.24)], V(0, -0.29, 3.06), (1, 0, 0), (0, 0.05, 1), 0.012, CORE)
    for k in range(7):                                                         # crown of seven
        a = (k - 3) * 0.21
        crystal_spike(bm, V(a * 0.9, 0, 3.32), V(a * 1.9, 0.0, 3.62 + 0.18 * (3 - abs(k - 3)) / 3), 0.05)
    for k in range(14):                                                        # floating halo
        a = k / 14 * math.tau
        ellipsoid(bm, V(math.cos(a) * 0.55, 0.1, 3.5 + math.sin(a) * 0.12), (0.035, 0.035, 0.035), CORE, 6)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        frustum(bm, V(0.62 * s, 0, 2.62), V(0.66 * s, 0, 2.0), 0.1, 0.085, 10, GLASS)
        frustum(bm, V(0.63 * s, 0, 2.5), V(0.64 * s, 0, 2.38), 0.13, 0.13, 10, SILVER)
        ellipsoid(bm, V(0.66 * s, 0, 1.98), (0.1, 0.1, 0.1), SILVER, 8)
        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(0.66 * s, 0, 1.98), V(0.68 * s, -0.1, 1.3), 0.085, 0.065, 10, GLASS)
        plate(bm, [(-0.06, 0), (0.06, 0), (0.05, -0.5), (0, -0.56), (-0.05, -0.5)], V(0.68 * s, -0.15, 1.92), (1, 0, 0), (0, -0.15, -1), 0.02, SILVER, bevel=0.006)
        bm = boss.piece(f"hand{n}", f"hand{n}")
        box(bm, V(0.68 * s, -0.14, 1.2), (0.11, 0.13, 0.13), GLASS, bevel=0.015)
        for f in range(4):
            sweep(bm, [V((0.64 + f * 0.03) * s, -0.2, 1.16), V((0.64 + f * 0.03) * s, -0.3, 1.04 - f * 0.01), V((0.64 + f * 0.03) * s, -0.34, 0.9 - f * 0.02)], [0.016, 0.013, 0.005], 4, GLASS)
        if n == "R":                                                           # baton
            sweep(bm, [V(0.68 * s, -0.16, 1.2), V(0.68 * s, -0.7, 1.28), V(0.68 * s, -1.5, 1.45)], [0.02, 0.015, 0.006], 5, CRYSTAL)
            ellipsoid(bm, V(0.68 * s, -1.55, 1.46), (0.045, 0.045, 0.045), CORE, 8)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.2 * s, 0, 1.48), V(0.22 * s, 0, 0.88), 0.14, 0.11, 10, GLASS)
        ellipsoid(bm, V(0.22 * s, -0.02, 0.86), (0.11, 0.11, 0.11), SILVER, 8)
        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.22 * s, 0, 0.86), V(0.22 * s, 0, 0.16), 0.11, 0.075, 10, GLASS)
        plate(bm, [(-0.05, 0), (0.05, 0), (0.035, -0.55), (-0.035, -0.55)], V(0.22 * s, -0.1, 0.8), (1, 0, 0), (0, -0.05, -1), 0.02, SILVER, bevel=0.006)
        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.22 * s, -0.08, 0.06), (0.14, 0.3, 0.09), GLASS, bevel=0.02)
        crystal_spike(bm, V(0.22 * s, -0.2, 0.06), V(0.22 * s, -0.5, 0.03), 0.045, GLASS)

    cheights = [(1.6, 1.1), (1.1, 0.6), (0.6, 0.06)]                           # split glass coat: front and back panels
    for index in range(3):
        bm = boss.piece(f"coat{index + 1}", f"coat{index + 1}")
        z0, z1 = cheights[index]
        w0, w1 = 0.34 + 0.06 * index, 0.44 + 0.09 * index
        for side_y, flare in ((-0.22, -0.12), (0.26, 0.12)):
            for half in (-1, 1):
                a0, a1 = (0.04 if half > 0 else -w1), (w1 if half > 0 else -0.04)
                left = [V(a0 * w0 / w1, side_y, z0), V(a0, side_y + flare * 0.3, (z0 + z1) / 2), V(a0 * 1.05, side_y + flare * 0.6, z1)]
                right = [V(a1 * w0 / w1, side_y, z0), V(a1, side_y + flare * 0.3, (z0 + z1) / 2), V(a1 * 1.05, side_y + flare * 0.6, z1 + (0.1 if index == 2 else 0))]
                ribbon_strip(bm, left, right, 0.025, COAT)
        if index == 2:
            for k in range(6):
                a = (k - 2.5) * 0.2
                crystal_spike(bm, V(a, 0.3, 0.14), V(a * 1.1, 0.34, -0.1), 0.035)

    bm = boss.piece("blades", "blades")                                         # seven tuning-fork blades, fanned
    for k in range(7):
        a = (k - 3) / 3 * 1.0
        base = V(math.sin(a) * 0.5, 0.36, 3.0 + 0.0)
        tip = V(math.sin(a) * 1.9, 0.5, 3.0 + math.cos(a) * 1.5)
        frustum(bm, base, tip, 0.05, 0.03, 6, CRYSTAL, smooth=False)
        for side in (-1, 1):
            p0 = base + (tip - base) * 0.78
            sweep(bm, [p0, p0 + (tip - base) * 0.12 + V(0.1 * side, 0, 0), tip + V(0.14 * side, 0, 0.1)], [0.03, 0.024, 0.008], 5, GLASS)
        ellipsoid(bm, base, (0.07, 0.07, 0.07), CORE, 8)
    return boss


def map_pose(c):
    pose = humanoid.map_humanoid(c, arm_scale=0.9, elbow=-0.3)
    humanoid.map_chain(pose, c, "coat", 3, "cloth", 0.85)
    bp, by, br = c["blades"]
    pose["blades"] = (bp, by, br)
    return pose
