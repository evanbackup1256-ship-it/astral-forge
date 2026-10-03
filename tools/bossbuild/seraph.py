"""The Stormbound Seraph: a slender celestial in pearl and gold plate with a cyan-white storm core, a
winged helm, a three-panel tabard, a spiked sunburst halo, and two great wings. Each wing is a stiff
three-bone arm with a fan of eleven flight feathers that the game simulates one by one, so the wing
ripples along its trailing edge as it beats. About 3.3 m tall (wings spread ~8 m), facing -Y."""

import math

import humanoid
import kit
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

KIND = "Seraph"
GOLD, PEARL, GLOW, CLOTH, FEATHER = 0, 1, 2, 3, 4
MATERIALS = {
    "gold": dict(base=((0.55, 0.38, 0.07), (1.0, 0.82, 0.35)), rough=0.3, metal=0.95, noise_scale=9.0, scale=5.0),
    "pearl": dict(base=((0.7, 0.72, 0.78), (0.97, 0.97, 1.0)), rough=0.35, metal=0.6, noise_scale=8.0, veins=(0.4, 0.8, 1.0), vein_width=0.02, voro_scale=3.0, veins_glow=0.5),
    "glow": dict(base=(0.7, 0.95, 1.0), rough=0.3, emit=(0.55, 0.9, 1.0, 1.1), noise_scale=5.0),
    "cloth": dict(base=((0.7, 0.62, 0.45), (0.98, 0.93, 0.8)), rough=0.85, noise_scale=14.0, scale=7.0),
    "feather": dict(base=((0.75, 0.88, 0.98), (1.0, 1.0, 1.0)), rough=0.7, noise_scale=20.0, scale=12.0, veins=(0.4, 0.85, 1.0), vein_width=0.015, voro_scale=14.0, veins_glow=0.3),
}
ORDER = ["gold", "pearl", "glow", "cloth", "feather"]
FEATHERS = 11


def build():
    boss = Boss(KIND, ORDER)
    humanoid.skeleton(boss, hip_z=1.5, chest_z=2.45, neck_z=2.75, head_top=3.25, shoulder_x=0.68, shoulder_z=2.62, elbow_z=1.95, wrist_z=1.3, hand_z=1.0, hip_x=0.22, knee_z=0.85, ankle_z=0.15)
    boss.bone("halo", "head", V(0, 0.18, 3.25), V(0, 0.18, 3.6))
    # a tabard in three simulated panels, hanging in front
    kit.cape(boss, "tabard", "hips", top_z=1.58, bottom_z=0.2, half_top=0.2, half_bottom=0.34, y_top=-0.24, y_bottom=-0.3,
             columns=3, segments=2, mat=CLOTH, edge_mat=GOLD, bow=0.03, tatter=0.0, seed=2, thickness=0.018, Pull=0.07)

    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.55), (0.7, 0.4, 0.2), PEARL, bevel=0.03)
    box(bm, V(0, -0.22, 1.55), (0.22, 0.05, 0.22), GOLD, bevel=0.015)
    ellipsoid(bm, V(0, -0.26, 1.55), (0.07, 0.04, 0.07), GLOW, 10)
    for s in (1, -1):
        ellipsoid(bm, V(0.22 * s, 0, 1.48), (0.13, 0.13, 0.13), GOLD, 10)
        plate(bm, [(-0.15, 0), (0.15, 0), (0.12, -0.42), (-0.12, -0.42)], V(0.3 * s, 0.2, 1.5), (1, 0, 0), (0, -0.12, -1), 0.035, GOLD, bevel=0.01)   # side faulds

    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.6), V(0, 0, 2.2), 0.3, 0.36, 14, PEARL, squash=0.72)
    ellipsoid(bm, V(0, 0, 2.45), (0.44, 0.28, 0.4), PEARL, 18)
    ellipsoid(bm, V(0.17, -0.1, 2.5), (0.22, 0.16, 0.26), PEARL, 12)
    ellipsoid(bm, V(-0.17, -0.1, 2.5), (0.22, 0.16, 0.26), PEARL, 12)
    plate(bm, [(0, 0.28), (0.1, 0.05), (0, -0.28), (-0.1, 0.05)], V(0, -0.3, 2.45), (1, 0, 0), (0, 0.1, 1), 0.02, GLOW)             # storm sigil
    plate(bm, [(-0.3, 0.02), (0.3, 0.02), (0.3, -0.02), (-0.3, -0.02)], V(0, -0.3, 2.45), (1, 0, 0), (0, 0.1, 1), 0.02, GLOW)
    box(bm, V(0, 0.28, 2.4), (0.62, 0.1, 0.6), PEARL, bevel=0.03)
    for k in range(3):
        box(bm, V(0, -0.2, 1.7 + k * 0.14), (0.5 - k * 0.02, 0.06, 0.07), GOLD, bevel=0.01)
    frustum(bm, V(0, 0, 2.66), V(0, 0, 2.8), 0.22, 0.17, 12, GOLD)
    # the wing roots: gold sockets on the back where each wing mounts
    for s in (1, -1):
        ellipsoid(bm, V(0.3 * s, 0.3, 2.72), (0.16, 0.12, 0.16), GOLD, 12)

    bm = boss.piece("head", "head")
    ellipsoid(bm, V(0, 0, 2.98), (0.27, 0.3, 0.33), PEARL, 18)
    plate(bm, [(-0.2, 0.18), (0.2, 0.18), (0.16, -0.2), (0, -0.28), (-0.16, -0.2)], V(0, -0.24, 3.0), (1, 0, 0), (0, 0.1, 1), 0.03, GOLD, bevel=0.008)
    plate(bm, [(-0.15, 0.02), (0.15, 0.02), (0.13, -0.02), (-0.13, -0.02)], V(0, -0.28, 3.02), (1, 0, 0), (0, 0.1, 1), 0.02, GLOW)
    for s in (1, -1):                                                           # winged crest
        for k in range(3):
            kit.feather(bm, (0.26 * s, 0.0, 3.1 + k * 0.05), (s * 0.9, 0.0, 0.3 + 0.28 * k), 0.5 - 0.06 * k, 0.07, GOLD, 0.02)

    bm = boss.piece("halo", "halo")
    count = 18
    for k in range(count):
        a = k / count * math.tau
        long = k % 2 == 0
        r = 0.55
        c = V(math.cos(a) * r, 0.18, 3.62 + math.sin(a) * r)
        tip = V(math.cos(a) * (r + (0.55 if long else 0.3)), 0.18, 3.62 + math.sin(a) * (r + (0.55 if long else 0.3)))
        frustum(bm, c, tip, 0.04 if long else 0.03, 0.004, 4, GLOW, smooth=False)
    for k in range(32):
        a = k / 32 * math.tau
        ellipsoid(bm, V(math.cos(a) * 0.55, 0.18, 3.62 + math.sin(a) * 0.55), (0.035, 0.035, 0.035), GLOW, 6)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        ellipsoid(bm, V(0.68 * s, 0, 2.62), (0.22, 0.22, 0.18), GOLD, 14)
        for k in range(3):
            kit.feather(bm, (0.7 * s, 0, 2.62 - k * 0.05), (s * 0.7, 0.0, 0.05 - 0.3 * k), 0.42 - 0.05 * k, 0.07, GOLD, 0.02)
        frustum(bm, V(0.68 * s, 0, 2.5), V(0.72 * s, 0, 1.98), 0.12, 0.1, 12, PEARL)
        ellipsoid(bm, V(0.72 * s, 0, 1.96), (0.11, 0.11, 0.11), GOLD, 10)
        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(0.72 * s, 0, 1.96), V(0.74 * s, -0.1, 1.3), 0.1, 0.075, 12, PEARL)
        plate(bm, [(-0.06, 0), (0.06, 0), (0.08, -0.5), (0, -0.6), (-0.08, -0.5)], V(0.74 * s, -0.16, 1.9), (1, 0, 0), (0, -0.15, -1), 0.025, GOLD, bevel=0.007)
        bm = boss.piece(f"hand{n}", f"hand{n}")
        box(bm, V(0.74 * s, -0.14, 1.2), (0.12, 0.14, 0.14), PEARL, bevel=0.02)
        for f in range(4):
            sweep(bm, [V((0.7 + f * 0.03) * s, -0.2, 1.16), V((0.7 + f * 0.03) * s, -0.3, 1.04), V((0.7 + f * 0.03) * s, -0.34, 0.92)], [0.018, 0.014, 0.005], 4, GOLD)
        ellipsoid(bm, V(0.74 * s, -0.32, 1.1), (0.1, 0.1, 0.1), GLOW, 8)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.22 * s, 0, 1.48), V(0.24 * s, 0, 0.9), 0.15, 0.115, 12, PEARL)
        ellipsoid(bm, V(0.24 * s, -0.02, 0.88), (0.12, 0.12, 0.12), GOLD, 10)
        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.24 * s, 0, 0.88), V(0.24 * s, 0, 0.18), 0.115, 0.08, 12, PEARL)
        plate(bm, [(-0.05, 0), (0.05, 0), (0.035, -0.55), (-0.035, -0.55)], V(0.24 * s, -0.11, 0.82), (1, 0, 0), (0, -0.05, -1), 0.025, GOLD, bevel=0.007)
        for k in range(3):                                                         # ankle wings
            kit.feather(bm, (0.24 * s + 0.08 * s, 0.05, 0.22), (s * 0.4, 0.8, 0.1 - 0.3 * k), 0.34 - 0.05 * k, 0.05, FEATHER, 0.015)
        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.24 * s, -0.08, 0.07), (0.15, 0.32, 0.1), PEARL, bevel=0.02)
        sweep(bm, [V(0.24 * s, -0.22, 0.07), V(0.24 * s, -0.36, 0.05), V(0.24 * s, -0.5, 0.02)], [0.05, 0.035, 0.008], 5, GOLD, squash=0.6)

    # ---- the wings: arm bones + a fan of simulated flight feathers ----
    for s, n in ((1, "L"), (-1, "R")):
        kit.wing(boss, s, f"wing{n}", "spine", root=(0.3 * s, 0.32, 2.72), elbow=(1.5 * s, 0.5, 3.15), tip=(3.1 * s, 0.62, 3.1),
                 feathers=FEATHERS, arm_mat=GOLD, feather_mat=FEATHER, covert_mat=PEARL, under_mat=PEARL, lengths=(1.1, 2.6), width=0.22, fan=0.55, seed=11 if s > 0 else 12)
    return boss


def map_pose(c):
    pose = humanoid.map_humanoid(c, arm_scale=0.9, elbow=-0.3)
    for col in range(3):
        cp, cy, cr = c["cloth"]
        pose[f"tabard{kit.LETTERS[col]}1"] = (cp * 0.8, cy, cr * 0.8)
    for chan, n in (("wingL", "L"), ("wingR", "R")):
        p, y, r = c[chan]
        pose[f"wing{n}1"] = (p, y, r)
        pose[f"wing{n}2"] = (p * 0.8, y * 0.7, r * 0.8 + 0.06)
        pose[f"wing{n}3"] = (p * 0.6, y * 0.6, r * 0.7 + 0.12)
    pose["halo"] = (c["blades"][0], 0, c["blades"][2])
    return pose
