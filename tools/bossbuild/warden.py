"""The Rift Warden: a hooded void sentinel in black obsidian, seams of violet rift light, a single
burning eye under a deep hood, tattered robe and cloak, and gauntlets with long hooked claws
ringed by floating rune shards. About 3.4 m tall, facing -Y."""

import math

import humanoid
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

KIND = "Warden"
OBSIDIAN, STEEL, GLOW, CLOTH, SHARD = 0, 1, 2, 3, 4
MATERIALS = {
    "obsidian": dict(base=((0.012, 0.01, 0.02), (0.08, 0.06, 0.12)), rough=0.25, metal=0.6, noise_scale=6.0, scale=4.0, veins=(0.35, 0.06, 0.8), vein_width=0.03, voro_scale=2.6, veins_glow=2.0),
    "steel": dict(base=((0.06, 0.055, 0.08), (0.24, 0.22, 0.32)), rough=0.4, metal=0.9, noise_scale=9.0),
    "glow": dict(base=(0.45, 0.1, 0.9), rough=0.4, emit=(0.6, 0.15, 1.0, 1.3), noise_scale=5.0),
    "cloth": dict(base=((0.015, 0.008, 0.03), (0.09, 0.04, 0.15)), rough=0.95, noise_scale=16.0, scale=9.0),
    "shard": dict(base=((0.02, 0.012, 0.04), (0.14, 0.07, 0.24)), rough=0.2, metal=0.5, noise_scale=8.0, veins=(0.3, 0.05, 0.7), vein_width=0.05, voro_scale=3.0, veins_glow=1.5),
}
ORDER = ["obsidian", "steel", "glow", "cloth", "shard"]


def claw(bm, base, s, spread, length=0.55):
    """A hooked claw finger starting at `base`."""
    return sweep(bm, [base, base + V(0.05 * spread, -0.14, -0.1), base + V(0.09 * spread, -0.3, -0.22), base + V(0.08 * spread, -0.44, -0.2 - 0.05 * length)], [0.035, 0.03, 0.02, 0.005], 5, SHARD)


def build():
    boss = Boss(KIND, ORDER)
    d = humanoid.skeleton(boss, hip_z=1.5, chest_z=2.4, neck_z=2.75, head_top=3.3, shoulder_x=0.85, shoulder_z=2.65, elbow_z=1.95, wrist_z=1.25, hand_z=0.95, hip_x=0.28, knee_z=0.85, ankle_z=0.16)
    robe = humanoid.chain(boss, "robe", "hips", V(0, 0, 1.55), V(0, 0, 0.1), 3, y=-0.02, dy=0.04)
    cloak = humanoid.chain(boss, "cloak", "spine", V(0, 0.3, 2.7), V(0, 0.3, 0.2), 3, y=0.3, dy=0.07)

    # ---- hips: pelvis plates, rift seal buckle, belt chains ----
    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.55), (1.0, 0.55, 0.22), OBSIDIAN, bevel=0.03)
    ellipsoid(bm, V(0, -0.3, 1.55), (0.14, 0.05, 0.14), GLOW, 12)
    for k in range(5):
        a = (k - 2) * 0.26
        sweep(bm, [V(a, -0.28, 1.46), V(a * 1.1, -0.31, 1.2), V(a * 1.2, -0.3, 0.95)], [0.025, 0.02, 0.012], 5, STEEL)
    for s in (1, -1):
        ellipsoid(bm, V(0.3 * s, 0, 1.48), (0.18, 0.18, 0.18), STEEL, 10)

    # ---- spine: ribbed obsidian cuirass with glowing cracks, collar shards, hood base ----
    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.6), V(0, 0, 2.1), 0.42, 0.52, 14, OBSIDIAN, squash=0.75)
    ellipsoid(bm, V(0, 0, 2.4), (0.6, 0.38, 0.5), OBSIDIAN, 16)
    for k in range(5):                                                           # ribs
        frustum(bm, V(0, -0.04, 1.75 + k * 0.13), V(0, -0.04, 1.82 + k * 0.13), 0.5 - k * 0.01, 0.52 - k * 0.01, 14, STEEL if k % 2 else OBSIDIAN, squash=0.8)
    for sgn in (-1, 1):                                                          # glowing rift cracks across the chest
        plate(bm, [(-0.02, 0.4), (0.02, 0.4), (0.05, 0.0), (0.0, -0.1), (-0.04, 0.0)], V(0.14 * sgn, -0.38, 2.4), (1, 0, 0), (0.0, 0.08, 1), 0.02, GLOW)
    plate(bm, [(-0.03, 0.34), (0.03, 0.34), (0.03, -0.34), (-0.03, -0.34)], V(0, -0.38, 2.4), (1, 0, 0), (0, 0.05, 1), 0.02, GLOW)
    for s in (1, -1):
        sweep(bm, [V(0.34 * s, -0.1, 2.85), V(0.5 * s, -0.12, 3.1), V(0.62 * s, -0.12, 3.4)], [0.09, 0.06, 0.01], 5, SHARD)   # collar shards
        sweep(bm, [V(0.22 * s, 0.3, 2.8), V(0.36 * s, 0.4, 3.0), V(0.4 * s, 0.48, 3.35)], [0.07, 0.045, 0.01], 5, SHARD)
    frustum(bm, V(0, 0, 2.7), V(0, 0, 2.85), 0.32, 0.26, 12, STEEL)

    # ---- head: deep hood, void face, one burning eye, floating broken halo ----
    bm = boss.piece("head", "head")
    ellipsoid(bm, V(0, 0.02, 3.0), (0.42, 0.46, 0.5), CLOTH, 16)
    sweep(bm, [V(0, 0.1, 3.3), V(0, 0.32, 3.55), V(0, 0.62, 3.5)], [0.2, 0.14, 0.02], 8, CLOTH)                 # hood peak
    ellipsoid(bm, V(0, -0.2, 2.98), (0.27, 0.22, 0.34), SHARD, 12)                                          # shadowed face
    ellipsoid(bm, V(0, -0.34, 3.02), (0.07, 0.03, 0.05), GLOW, 10)                                           # the eye
    ellipsoid(bm, V(0, -0.32, 3.02), (0.13, 0.03, 0.1), GLOW, 10)
    for k in range(9):                                                                                       # broken halo behind the head
        a = (k / 9) * math.tau + 0.2
        if 0.5 < (a % math.tau) < 1.1:
            continue
        r = 0.78
        sweep(bm, [V(math.cos(a) * r, 0.42, 3.05 + math.sin(a) * r), V(math.cos(a + 0.18) * r * 1.05, 0.44, 3.05 + math.sin(a + 0.18) * r * 1.05)], [0.05, 0.025], 5, GLOW)

    # ---- arms: crystal pauldrons, banded sleeves, clawed gauntlets ringed by runes ----
    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        ellipsoid(bm, V(0.85 * s, 0, 2.7), (0.3, 0.3, 0.24), OBSIDIAN, 14)
        for k, (dx, dz, h) in enumerate(((0.2, 0.18, 0.7), (0.34, 0.0, 0.55), (0.12, 0.3, 0.5))):
            sweep(bm, [V((0.85 + dx * 0.4) * s, 0.0, 2.74 + dz), V((0.9 + dx) * s, 0.0, 2.9 + dz + h * 0.4), V((0.92 + dx) * s, 0.04 * k, 2.95 + dz + h)], [0.1, 0.06, 0.012], 5, SHARD)
        frustum(bm, V(0.85 * s, 0, 2.55), V(0.89 * s, 0, 1.98), 0.2, 0.16, 12, CLOTH)
        for k in range(3):
            frustum(bm, V(0.86 * s, 0, 2.3 - k * 0.14), V(0.87 * s, 0, 2.26 - k * 0.14), 0.205 - k * 0.01, 0.205 - k * 0.01, 12, STEEL)
        ellipsoid(bm, V(0.89 * s, 0, 1.95), (0.15, 0.15, 0.15), STEEL, 10)

        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(0.89 * s, 0, 1.95), V(0.91 * s, -0.1, 1.25), 0.16, 0.12, 12, OBSIDIAN)
        plate(bm, [(-0.07, 0), (0.07, 0), (0.08, -0.55), (0, -0.62), (-0.08, -0.55)], V(0.91 * s, -0.17, 1.9), (1, 0, 0), (0, -0.15, -1), 0.03, STEEL, bevel=0.008)
        plate(bm, [(-0.02, 0), (0.02, 0), (0.02, -0.5), (-0.02, -0.5)], V(0.91 * s, -0.2, 1.84), (1, 0, 0), (0, -0.15, -1), 0.02, GLOW)

        bm = boss.piece(f"hand{n}", f"hand{n}")
        box(bm, V(0.91 * s, -0.16, 1.1), (0.24, 0.26, 0.24), OBSIDIAN, bevel=0.03)
        for f in range(4):
            claw(bm, V((0.84 + f * 0.05) * s, -0.26, 1.05), s, 1)
        sweep(bm, [V(0.98 * s, -0.2, 1.1), V(1.05 * s, -0.34, 1.0), V(1.04 * s, -0.46, 0.88)], [0.04, 0.03, 0.006], 5, SHARD)
        for k in range(8):                                                                                  # floating rune ring around the hand
            a = k / 8 * math.tau
            ellipsoid(bm, V(0.91 * s + math.cos(a) * 0.42, -0.16, 1.1 + math.sin(a) * 0.42), (0.045, 0.02, 0.07), GLOW, 6, rot=None)

    # ---- legs (mostly hidden by the robe) ----
    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.28 * s, 0, 1.48), V(0.3 * s, 0, 0.88), 0.2, 0.15, 10, CLOTH)
        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.3 * s, 0, 0.85), V(0.3 * s, 0, 0.18), 0.15, 0.1, 10, OBSIDIAN)
        plate(bm, [(-0.06, 0), (0.06, 0), (0.04, -0.5), (-0.04, -0.5)], V(0.3 * s, -0.14, 0.8), (1, 0, 0), (0, -0.05, -1), 0.03, STEEL, bevel=0.008)
        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.3 * s, -0.1, 0.07), (0.2, 0.4, 0.12), OBSIDIAN, bevel=0.025)
        sweep(bm, [V(0.3 * s, -0.28, 0.07), V(0.3 * s, -0.42, 0.05), V(0.3 * s, -0.55, 0.02)], [0.07, 0.045, 0.01], 6, SHARD, squash=0.6)

    # ---- robe (hips) and cloak (back): ragged tongues ----
    heights = [(1.55, 1.05), (1.05, 0.55), (0.55, 0.04)]
    for index in range(3):
        bm = boss.piece(f"robe{index + 1}", f"robe{index + 1}")
        z0, z1 = heights[index]
        r0, r1 = 0.55 + 0.1 * index, 0.7 + 0.1 * index
        count = 7 if index == 2 else 5
        for c in range(count):
            a0, a1 = c / count * math.tau, (c + 1) / count * math.tau
            drop = (0.0, 0.1, 0.22, 0.05, 0.16, 0.08, 0.2)[c % 7] if index == 2 else 0.0
            left = [V(math.sin(a0) * r0, -math.cos(a0) * r0 * 0.7, z0), V(math.sin(a0) * (r0 + r1) / 2, -math.cos(a0) * (r0 + r1) / 2 * 0.7, (z0 + z1) / 2), V(math.sin(a0) * r1, -math.cos(a0) * r1 * 0.7, z1 + drop * 0.3)]
            right = [V(math.sin(a1) * r0, -math.cos(a1) * r0 * 0.7, z0), V(math.sin(a1) * (r0 + r1) / 2, -math.cos(a1) * (r0 + r1) / 2 * 0.7, (z0 + z1) / 2), V(math.sin(a1) * r1, -math.cos(a1) * r1 * 0.7, z1 + drop * 0.3 - (0.06 if c % 2 else 0))]
            ribbon_strip(bm, left, right, 0.03, CLOTH)
    cheights = [(2.7, 1.95), (1.95, 1.2), (1.2, 0.2)]
    for index in range(3):
        bm = boss.piece(f"cloak{index + 1}", f"cloak{index + 1}")
        z0, z1 = cheights[index]
        y0 = 0.3 + 0.07 * index
        w0, w1 = 0.62 + 0.08 * index, 0.7 + 0.1 * index
        count = 5 if index == 2 else 1
        for c in range(count):
            a, b = -w1 + c * 2 * w1 / count, -w1 + (c + 1) * 2 * w1 / count
            drop = (0.0, 0.14, 0.3, 0.06, 0.2)[c] if index == 2 else 0.0
            left = [V(a * w0 / w1, y0, z0), V(a, y0 + 0.03, (z0 + z1) / 2), V(a * 0.95, y0 + 0.07, z1 + drop * 0.3)]
            right = [V(b * w0 / w1, y0, z0), V(b, y0 + 0.03, (z0 + z1) / 2), V(b * 0.95, y0 + 0.07, z1 + drop * 0.3 - (0.07 if c % 2 else 0.0))]
            ribbon_strip(bm, left, right, 0.03, CLOTH)
    return boss


def map_pose(c):
    pose = humanoid.map_humanoid(c, arm_scale=0.9, elbow=-0.3)
    humanoid.map_chain(pose, c, "robe", 3, "cloth", 0.85)
    humanoid.map_chain(pose, c, "cloak", 3, "cloth", 0.88)
    return pose
