"""The Rimeheart: a glacier given a body. Slabs of blue-white ice over dark frozen rock, crystal
clusters on the shoulders and back, a caged cyan heart burning in the chest, a crown of ice
spikes and blank glowing eyes, huge crystalline fists and icicle-hung legs. About 3 m tall,
facing -Y."""

import math

import humanoid
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

KIND = "Rime"
ICE, ROCK, GLOW, CRYSTAL, FROST = 0, 1, 2, 3, 4
MATERIALS = {
    "ice": dict(base=((0.35, 0.58, 0.78), (0.85, 0.95, 1.0)), rough=0.15, metal=0.15, noise_scale=4.0, scale=3.5, veins=(0.9, 0.97, 1.0), vein_width=0.04, voro_scale=2.8, veins_glow=0.5),
    "rock": dict(base=((0.03, 0.04, 0.07), (0.14, 0.17, 0.24)), rough=0.85, noise_scale=9.0, scale=5.0, veins=(0.2, 0.55, 0.9), vein_width=0.02, voro_scale=3.0, veins_glow=0.4),
    "glow": dict(base=(0.5, 0.9, 1.0), rough=0.3, emit=(0.3, 0.8, 1.0, 1.5), noise_scale=5.0),
    "crystal": dict(base=((0.4, 0.75, 0.95), (0.85, 1.0, 1.0)), rough=0.08, metal=0.1, noise_scale=6.0, emit=(0.25, 0.6, 0.9, 0.5)),
    "frost": dict(base=((0.75, 0.85, 0.92), (1.0, 1.0, 1.0)), rough=0.9, noise_scale=22.0, scale=14.0),
}
ORDER = ["ice", "rock", "glow", "crystal", "frost"]


def cluster(bm, base, spread, height, count=5, r=0.1, mat=CRYSTAL, tilt=0.35, seed=0):
    for k in range(count):
        a = (k * 2.399 + seed) % math.tau
        reach = spread * (0.2 + 0.8 * ((k * 0.37 + seed) % 1))
        top = base + V(math.cos(a) * reach * (1 + tilt), math.sin(a) * reach * (1 + tilt), height * (1.0 - 0.45 * ((k % 3) / 2)))
        frustum(bm, base + V(math.cos(a) * reach * 0.4, math.sin(a) * reach * 0.4, 0), top, r * (1 - 0.1 * (k % 3)), 0.006, 6, mat, smooth=False)


def build():
    boss = Boss(KIND, ORDER)
    humanoid.skeleton(boss, hip_z=1.2, chest_z=2.15, neck_z=2.5, head_top=3.0, shoulder_x=1.0, shoulder_z=2.2, elbow_z=1.4, wrist_z=0.72, hand_z=0.34, hip_x=0.4, knee_z=0.7, ankle_z=0.14, foot_len=0.5)
    boss.bone("back", "spine", V(0, 0.38, 2.1), V(0, 0.5, 3.0))

    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.25), (1.35, 0.78, 0.32), ROCK, bevel=0.06)
    box(bm, V(0, -0.4, 1.25), (0.9, 0.1, 0.3), ICE, bevel=0.04)
    for s in (1, -1):
        ellipsoid(bm, V(0.4 * s, 0, 1.18), (0.24, 0.24, 0.24), ICE, 10)
        cluster(bm, V(0.62 * s, 0, 1.3), 0.12, 0.5, 3, 0.07, seed=s)

    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.3), V(0, 0, 1.95), 0.52, 0.72, 14, ROCK, squash=0.78)
    ellipsoid(bm, V(0, 0, 2.2), (0.85, 0.56, 0.56), ICE, 16)
    ellipsoid(bm, V(0.3, -0.2, 2.25), (0.38, 0.3, 0.4), ICE, 12)
    ellipsoid(bm, V(-0.3, -0.2, 2.25), (0.38, 0.3, 0.4), ICE, 12)
    ellipsoid(bm, V(0, -0.3, 2.2), (0.2, 0.14, 0.2), GLOW, 12)                           # the heart
    for k in range(5):                                                                    # ribs cage the heart
        a = (k - 2) * 0.26
        sweep(bm, [V(a - 0.05, -0.3, 2.55), V(a * 1.2, -0.46, 2.2), V(a - 0.05, -0.3, 1.85)], [0.04, 0.045, 0.04], 6, ICE)
    for k in range(3):
        box(bm, V(0, -0.36, 1.45 + k * 0.17), (0.7 - k * 0.04, 0.12, 0.11), ROCK, bevel=0.02)
    box(bm, V(0, 0.38, 2.15), (1.4, 0.22, 0.85), ROCK, bevel=0.06)
    frustum(bm, V(0, 0, 2.5), V(0, 0, 2.66), 0.42, 0.3, 12, ROCK)

    bm = boss.piece("head", "head")
    box(bm, V(0, 0, 2.82), (0.56, 0.54, 0.5), ICE, bevel=0.06)
    box(bm, V(0, -0.18, 2.7), (0.44, 0.26, 0.18), ROCK, bevel=0.03)
    plate(bm, [(-0.2, 0.06), (0.2, 0.06), (0.17, -0.04), (-0.17, -0.04)], V(0, -0.29, 2.88), (1, 0, 0), (0, 0.1, 1), 0.03, GLOW)
    for k in range(7):
        a = (k - 3) / 3 * 1.2
        frustum(bm, V(math.sin(a) * 0.25, 0.0, 3.04), V(math.sin(a) * 0.4, -0.02, 3.5 + 0.18 * math.cos(a)), 0.07, 0.006, 6, CRYSTAL, smooth=False)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        ellipsoid(bm, V(1.0 * s, 0, 2.28), (0.42, 0.4, 0.34), ICE, 12)
        cluster(bm, V(1.02 * s, 0, 2.5), 0.28, 0.95, 6, 0.1, seed=1.0 if n == "L" else 2.0)
        frustum(bm, V(1.0 * s, 0, 2.1), V(1.04 * s, 0, 1.42), 0.3, 0.26, 12, ICE)
        for k in range(3):
            box(bm, V(1.02 * s, 0, 1.9 - k * 0.2), (0.62, 0.58, 0.07), ROCK, bevel=0.015)
        ellipsoid(bm, V(1.04 * s, 0, 1.4), (0.27, 0.27, 0.27), ROCK, 10)
        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(1.04 * s, 0, 1.4), V(1.08 * s, -0.1, 0.72), 0.28, 0.3, 12, ICE)
        box(bm, V(1.08 * s, -0.2, 1.0), (0.58, 0.12, 0.4), ROCK, bevel=0.03)
        sweep(bm, [V(1.2 * s, 0, 1.2), V(1.3 * s, 0.0, 1.0), V(1.34 * s, 0.0, 0.7)], [0.08, 0.055, 0.01], 5, CRYSTAL)
        bm = boss.piece(f"hand{n}", f"hand{n}")
        box(bm, V(1.08 * s, -0.12, 0.46), (0.62, 0.58, 0.62), ICE, bevel=0.06)
        for k in range(4):
            frustum(bm, V((1.0 + k * 0.07) * s, -0.4, 0.52), V((1.0 + k * 0.07) * s, -0.62, 0.38 - 0.02 * k), 0.07, 0.015, 5, CRYSTAL, smooth=False)
        cluster(bm, V(1.08 * s, -0.1, 0.74), 0.2, 0.5, 4, 0.08, seed=1.0)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.4 * s, 0, 1.2), V(0.42 * s, 0, 0.72), 0.3, 0.26, 12, ICE)
        box(bm, V(0.42 * s, -0.24, 1.0), (0.42, 0.1, 0.46), ROCK, bevel=0.03)
        ellipsoid(bm, V(0.42 * s, -0.04, 0.7), (0.26, 0.26, 0.26), ROCK, 10)
        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.42 * s, 0, 0.7), V(0.42 * s, 0, 0.18), 0.26, 0.3, 12, ICE)
        for k in range(4):                                                                 # icicles hanging from the greave
            a = k / 4 * math.tau
            frustum(bm, V(0.42 * s + math.cos(a) * 0.24, math.sin(a) * 0.24, 0.5), V(0.42 * s + math.cos(a) * 0.27, math.sin(a) * 0.27, 0.12), 0.04, 0.004, 5, CRYSTAL, smooth=False)
        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.42 * s, -0.14, 0.09), (0.5, 0.78, 0.18), ROCK, bevel=0.05)
        box(bm, V(0.42 * s, -0.5, 0.12), (0.42, 0.2, 0.24), ICE, bevel=0.04)

    bm = boss.piece("back", "back")                                                         # crystal spine
    cluster(bm, V(0, 0.5, 2.2), 0.5, 1.4, 9, 0.12, seed=2.0, tilt=0.15)
    for s in (1, -1):
        cluster(bm, V(0.55 * s, 0.48, 2.2), 0.25, 0.95, 4, 0.09, seed=3.0 + s)
    return boss


def map_pose(c):
    pose = humanoid.map_humanoid(c, arm_scale=0.85, elbow=-0.15, knee=0.4)
    pose["back"] = (c["cloth"][0] * 0.4, 0, c["cloth"][2] * 0.4)
    return pose
