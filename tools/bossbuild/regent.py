"""The Cinder Regent: a molten colossus. Cracked black basalt armour with seams of lava, a crown of
flame spikes, slit-eyes burning, stacked slab pauldrons, enormous fists and pillar legs, and vents
of fire down the back. Broad and heavy: about 3 m tall, facing -Y."""

import math

import humanoid
import kit
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

KIND = "Regent"
BASALT, IRON, LAVA, SPIKE, ASH, BANNER = 0, 1, 2, 3, 4, 5
MATERIALS = {
    "basalt": dict(base=((0.02, 0.018, 0.02), (0.11, 0.095, 0.1)), rough=0.8, metal=0.1, noise_scale=7.0, scale=4.0, veins=(0.85, 0.2, 0.02), vein_width=0.045, voro_scale=2.4, veins_glow=0.45),
    "iron": dict(base=((0.04, 0.035, 0.04), (0.2, 0.17, 0.17)), rough=0.5, metal=0.85, noise_scale=10.0),
    "lava": dict(base=(0.9, 0.28, 0.03), rough=0.5, emit=(1.0, 0.28, 0.03, 0.9), noise_scale=5.0, veins=(1.0, 0.45, 0.08), vein_width=0.1, voro_scale=3.0),
    "spike": dict(base=((0.05, 0.03, 0.03), (0.35, 0.12, 0.05)), rough=0.4, metal=0.7, noise_scale=8.0, emit=(1.0, 0.3, 0.05, 0.5)),
    "ash": dict(base=((0.03, 0.025, 0.025), (0.12, 0.1, 0.1)), rough=0.95, noise_scale=16.0),
    "banner": dict(base=((0.05, 0.015, 0.012), (0.22, 0.06, 0.03)), rough=0.95, noise_scale=14.0, scale=8.0, veins=(0.9, 0.25, 0.03), vein_width=0.02, voro_scale=6.0, veins_glow=0.25),
}
ORDER = ["basalt", "iron", "lava", "spike", "ash", "banner"]


def fist(bm, c, s, size):
    box(bm, c, (size, size * 0.95, size), BASALT, bevel=0.05)
    for k in range(4):
        box(bm, c + V((k - 1.5) * size * 0.22 * s, -size * 0.55, size * 0.05), (size * 0.2, size * 0.18, size * 0.34), IRON, bevel=0.02)
    plate(bm, [(-size * 0.4, 0), (size * 0.4, 0), (size * 0.3, size * 0.5), (-size * 0.3, size * 0.5)], c + V(0, -size * 0.5, size * 0.1), (1, 0, 0), (0, 0, 1), 0.03, LAVA)


def build():
    boss = Boss(KIND, ORDER)
    humanoid.skeleton(boss, hip_z=1.1, chest_z=2.0, neck_z=2.38, head_top=2.9, shoulder_x=1.1, shoulder_z=2.1, elbow_z=1.28, wrist_z=0.62, hand_z=0.22, hip_x=0.42, knee_z=0.62, ankle_z=0.14, foot_len=0.5)
    boss.bone("vents", "spine", V(0, 0.4, 2.0), V(0, 0.5, 2.7))
    # a scorched war cloak down the back and a banner-tabard in front, both simulated
    kit.cape(boss, "cloak", "spine", top_z=2.15, bottom_z=0.25, half_top=0.75, half_bottom=1.15, y_top=0.55, y_bottom=0.72, columns=5, segments=3, mat=BANNER, edge_mat=LAVA, bow=0.08, tatter=1.0, seed=6, thickness=0.04, kind="heavy")
    kit.cape(boss, "banner", "hips", top_z=1.2, bottom_z=0.12, half_top=0.32, half_bottom=0.5, y_top=-0.5, y_bottom=-0.64, columns=3, segments=3, mat=BANNER, edge_mat=LAVA, bow=0.04, tatter=0.8, seed=7, thickness=0.035, kind="heavy")

    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.15), (1.5, 0.8, 0.34), BASALT, bevel=0.06)
    box(bm, V(0, -0.42, 1.15), (0.5, 0.1, 0.36), IRON, bevel=0.03)
    plate(bm, [(-0.18, 0.14), (0.18, 0.14), (0.0, -0.18)], V(0, -0.48, 1.15), (1, 0, 0), (0, 0.1, 1), 0.03, LAVA)
    for s in (1, -1):
        ellipsoid(bm, V(0.42 * s, 0, 1.08), (0.26, 0.26, 0.26), IRON, 10)
        plate(bm, [(-0.22, 0), (0.22, 0), (0.18, -0.55), (-0.18, -0.55)], V(0.5 * s, -0.4, 1.0), (1, 0, 0), (0, 0.15, -1), 0.06, BASALT, bevel=0.02)

    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.2), V(0, 0, 1.9), 0.55, 0.78, 14, BASALT, squash=0.75)
    ellipsoid(bm, V(0, 0, 2.15), (0.95, 0.56, 0.6), BASALT, 16)                          # barrel chest
    ellipsoid(bm, V(0.34, -0.2, 2.2), (0.42, 0.34, 0.42), BASALT, 12)
    ellipsoid(bm, V(-0.34, -0.2, 2.2), (0.42, 0.34, 0.42), BASALT, 12)
    plate(bm, [(0, 0.36), (0.2, 0.0), (0.12, -0.3), (0, -0.46), (-0.12, -0.3), (-0.2, 0.0)], V(0, -0.56, 2.15), (1, 0, 0), (0, 0.05, 1), 0.03, LAVA)   # molten heart
    for k in range(4):                                                                   # belly plates with lava gaps
        box(bm, V(0, -0.38, 1.35 + k * 0.17), (0.7 - k * 0.02, 0.14, 0.12), IRON, bevel=0.02)
        box(bm, V(0, -0.38, 1.43 + k * 0.17), (0.6, 0.1, 0.03), LAVA)
    box(bm, V(0, 0.4, 2.1), (1.5, 0.2, 0.9), BASALT, bevel=0.06)                          # back slab
    frustum(bm, V(0, 0, 2.5), V(0, 0, 2.7), 0.5, 0.36, 12, IRON)

    bm = boss.piece("head", "head")
    box(bm, V(0, 0, 2.62), (0.62, 0.6, 0.56), BASALT, bevel=0.07)
    box(bm, V(0, -0.2, 2.5), (0.5, 0.3, 0.2), IRON, bevel=0.04)                            # jaw
    plate(bm, [(-0.22, 0.05), (0.22, 0.05), (0.2, -0.05), (-0.2, -0.05)], V(0, -0.32, 2.7), (1, 0, 0), (0, 0.1, 1), 0.03, LAVA)   # burning eyes
    for k in range(9):                                                                     # crown of flame spikes
        a = (k - 4) / 4 * 1.4
        sweep(bm, [V(math.sin(a) * 0.3, 0.0, 2.88), V(math.sin(a) * 0.45, -0.02, 3.15 + 0.1 * math.cos(a)), V(math.sin(a) * 0.58, -0.06, 3.5 + 0.28 * math.cos(a))], [0.085, 0.055, 0.01], 6, SPIKE)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        for k in range(3):                                                                 # stacked slab pauldron
            box(bm, V(1.12 * s, 0, 2.38 - k * 0.15), (0.78 - k * 0.06, 0.7 - k * 0.04, 0.16), IRON if k == 1 else BASALT, bevel=0.04)
        for k in range(4):
            sweep(bm, [V((1.0 + 0.1 * k) * s, (k - 1.5) * 0.14, 2.55), V((1.04 + 0.12 * k) * s, (k - 1.5) * 0.15, 2.9 + 0.08 * k), V((1.06 + 0.12 * k) * s, (k - 1.5) * 0.15, 3.15 + 0.14 * k)], [0.07, 0.045, 0.01], 5, SPIKE)
        frustum(bm, V(1.1 * s, 0, 2.2), V(1.14 * s, 0, 1.3), 0.34, 0.3, 12, BASALT)
        for k in range(3):
            box(bm, V(1.12 * s, 0, 1.95 - k * 0.2), (0.7, 0.62, 0.08), LAVA if k == 1 else IRON, bevel=0.01)
        ellipsoid(bm, V(1.14 * s, 0, 1.28), (0.3, 0.3, 0.3), IRON, 10)

        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(1.14 * s, 0, 1.28), V(1.18 * s, -0.1, 0.66), 0.32, 0.38, 12, BASALT)
        box(bm, V(1.18 * s, -0.2, 0.95), (0.7, 0.14, 0.42), IRON, bevel=0.03)
        plate(bm, [(-0.28, 0), (0.28, 0), (0.28, -0.4), (-0.28, -0.4)], V(1.18 * s, -0.3, 1.15), (1, 0, 0), (0, 0, -1), 0.02, LAVA)

        bm = boss.piece(f"hand{n}", f"hand{n}")
        fist(bm, V(1.18 * s, -0.12, 0.38), s, 0.7)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.42 * s, 0, 1.08), V(0.44 * s, 0, 0.64), 0.34, 0.3, 12, BASALT)
        box(bm, V(0.44 * s, -0.28, 0.9), (0.5, 0.1, 0.5), IRON, bevel=0.03)
        ellipsoid(bm, V(0.44 * s, -0.04, 0.62), (0.28, 0.28, 0.28), IRON, 10)
        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.44 * s, 0, 0.62), V(0.44 * s, 0, 0.18), 0.3, 0.32, 12, BASALT)
        plate(bm, [(-0.14, 0), (0.14, 0), (0.12, -0.38), (-0.12, -0.38)], V(0.44 * s, -0.3, 0.58), (1, 0, 0), (0, -0.05, -1), 0.03, LAVA)
        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.44 * s, -0.14, 0.09), (0.5, 0.78, 0.18), BASALT, bevel=0.05)
        for k in range(3):
            box(bm, V((0.34 + k * 0.1) * s, -0.5, 0.1), (0.1, 0.14, 0.14), IRON, bevel=0.015)

    bm = boss.piece("vents", "vents")                                                       # fire vents on the back
    for s in (1, -1):
        for k in range(3):
            sweep(bm, [V((0.3 + k * 0.2) * s, 0.46, 2.0 + k * 0.1), V((0.36 + k * 0.2) * s, 0.58, 2.35 + k * 0.1), V((0.4 + k * 0.2) * s, 0.7, 2.75 + k * 0.1)], [0.1, 0.07, 0.012], 6, LAVA)
    return boss


def map_pose(c):
    pose = humanoid.map_humanoid(c, arm_scale=0.85, elbow=-0.15, knee=0.4)
    pose["vents"] = (c["cloth"][0] * 0.5, 0, c["cloth"][2] * 0.5)
    cp, cy, cr = c["cloth"]
    for col in range(5):
        pose[f"cloak{kit.LETTERS[col]}1"] = (cp * 0.7, cy, cr * 0.7)
    for col in range(3):
        pose[f"banner{kit.LETTERS[col]}1"] = (-cp * 0.3, cy, cr * 0.3)
    return pose
