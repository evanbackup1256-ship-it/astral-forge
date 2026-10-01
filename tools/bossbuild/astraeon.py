"""Astraeon, the Unmade Star: a colossal celestial. Cracked white marble armour veined with gold,
a chest that is open to a burning star core, a crown of radiant blades, a halo ring behind the head,
two orbiting rings, shard legs that taper to nothing, and a cape of woven light. About 4.6 m tall,
facing -Y."""

import math

import humanoid
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

KIND = "Astraeon"
MARBLE, GOLD, STAR, VOID = 0, 1, 2, 3
MATERIALS = {
    "marble": dict(base=((0.55, 0.52, 0.48), (0.92, 0.89, 0.82)), rough=0.35, metal=0.05, noise_scale=6.0, scale=3.0, veins=(1.0, 0.72, 0.25), vein_width=0.03, voro_scale=2.0, veins_glow=0.9),
    "gold": dict(base=((0.6, 0.42, 0.1), (1.0, 0.76, 0.28)), rough=0.25, metal=0.95, noise_scale=9.0),
    "star": dict(base=(1.0, 0.92, 0.65), rough=0.4, emit=(1.0, 0.86, 0.5, 2.2), noise_scale=4.0, veins=(1.0, 1.0, 0.9), vein_width=0.1, voro_scale=3.0),
    "void": dict(base=((0.01, 0.02, 0.06), (0.05, 0.08, 0.2)), rough=0.6, noise_scale=10.0, emit=(0.25, 0.5, 1.0, 0.6), veins=(0.3, 0.6, 1.0), vein_width=0.05, voro_scale=2.5),
}
ORDER = ["marble", "gold", "star", "void"]
CAPE = 5


def ring(bm, centre, radius, tilt_x, beads, size, mat):
    """A ring of overlapping beads (no torus helper), tilted about X."""
    for k in range(beads):
        a = k / beads * math.tau
        x, y, z = math.cos(a) * radius, math.sin(a) * radius, 0.0
        y2 = y * math.cos(tilt_x) - z * math.sin(tilt_x)
        z2 = y * math.sin(tilt_x) + z * math.cos(tilt_x)
        ellipsoid(bm, centre + V(x, y2, z2), (size, size, size), mat, 8)


def blade_crown(bm, centre, count, inner, height, mat):
    for k in range(count):
        a = (k + 0.5) / count * math.tau
        dx, dy = math.cos(a), math.sin(a)
        h = height * (1.0 if k % 2 == 0 else 0.62)
        sweep(bm, [centre + V(dx * inner, dy * inner, 0), centre + V(dx * inner * 1.25, dy * inner * 1.25, h * 0.5), centre + V(dx * inner * 1.5, dy * inner * 1.5, h)], [0.07, 0.045, 0.008], 6, mat)


def build():
    boss = Boss(KIND, ORDER)
    humanoid.skeleton(boss, hip_z=1.9, chest_z=3.0, neck_z=3.45, head_top=4.2, shoulder_x=1.25, shoulder_z=3.25, elbow_z=2.4, wrist_z=1.65, hand_z=1.25, hip_x=0.3, knee_z=1.05, ankle_z=0.2, foot_len=0.3)
    cape = humanoid.chain(boss, "cape", "spine", V(0, 0.4, 3.2), V(0, 0.75, 0.5), CAPE, y=0.35, dy=0.04)
    boss.bone("halo", "spine", V(0, 0.3, 3.8), V(0, 0.3, 4.4))
    boss.bone("ringA", "hips", V(0, 0, 2.6), V(0, 0, 3.0))
    boss.bone("ringB", "hips", V(0, 0, 2.2), V(0, 0, 2.6))

    bm = boss.piece("hips", "hips")
    frustum(bm, V(0, 0, 1.75), V(0, 0, 2.15), 0.62, 0.52, 14, MARBLE, squash=0.8)
    box(bm, V(0, -0.4, 1.95), (0.5, 0.1, 0.34), GOLD, bevel=0.03)
    plate(bm, [(-0.14, 0.14), (0.14, 0.14), (0.0, -0.2)], V(0, -0.46, 1.95), (1, 0, 0), (0, 0.1, 1), 0.03, STAR)
    for s in (1, -1):
        ellipsoid(bm, V(0.32 * s, 0, 1.88), (0.24, 0.24, 0.24), GOLD, 10)

    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 2.1), V(0, 0, 2.95), 0.5, 0.78, 16, MARBLE, squash=0.7)
    ellipsoid(bm, V(0, 0, 3.1), (0.98, 0.56, 0.62), MARBLE, 18)                      # chest
    ellipsoid(bm, V(0, -0.5, 3.0), (0.38, 0.2, 0.42), VOID, 14)                       # the opened chest
    ellipsoid(bm, V(0, -0.56, 3.0), (0.24, 0.17, 0.26), STAR, 14)                      # the star core
    for k in range(7):                                                                  # gold ribs framing the core
        a = (k - 3) / 3 * 0.9
        sweep(bm, [V(math.sin(a) * 0.12, -0.42, 3.3), V(math.sin(a) * 0.38, -0.5, 3.0), V(math.sin(a) * 0.18, -0.44, 2.65)], [0.035, 0.04, 0.02], 6, GOLD)
    box(bm, V(0, 0.38, 3.1), (1.4, 0.2, 0.9), MARBLE, bevel=0.06)
    for k in range(4):
        box(bm, V(0, -0.3, 2.3 + k * 0.14), (0.5 - k * 0.02, 0.12, 0.08), GOLD, bevel=0.015)

    bm = boss.piece("head", "head")
    ellipsoid(bm, V(0, 0, 3.85), (0.34, 0.32, 0.4), MARBLE, 16)                        # faceless head
    plate(bm, [(-0.2, 0.04), (0.2, 0.04), (0.16, -0.04), (-0.16, -0.04)], V(0, -0.3, 3.9), (1, 0, 0), (0, 0.1, 1), 0.02, STAR)   # one line of light for eyes
    box(bm, V(0, -0.08, 3.55), (0.3, 0.2, 0.18), GOLD, bevel=0.04)                     # gorget
    blade_crown(bm, V(0, 0, 4.1), 14, 0.2, 0.95, GOLD)

    bm = boss.piece("halo", "halo")
    ring(bm, V(0, 0.34, 4.15), 0.85, math.pi / 2, 40, 0.05, STAR)
    ring(bm, V(0, 0.34, 4.15), 1.05, math.pi / 2, 52, 0.035, GOLD)
    for k in range(12):
        a = k / 12 * math.tau
        sweep(bm, [V(math.cos(a) * 1.05, 0.34, 4.15 + math.sin(a) * 1.05), V(math.cos(a) * 1.3, 0.34, 4.15 + math.sin(a) * 1.3)], [0.04, 0.006], 5, STAR)

    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        ellipsoid(bm, V(1.32 * s, 0, 3.3), (0.5, 0.46, 0.4), MARBLE, 14)                # pauldron
        for k in range(4):                                                              # gold pauldron blades
            sweep(bm, [V((1.15 + 0.1 * k) * s, (k - 1.5) * 0.14, 3.5), V((1.3 + 0.14 * k) * s, (k - 1.5) * 0.15, 3.9 + 0.08 * k), V((1.4 + 0.16 * k) * s, (k - 1.5) * 0.16, 4.25 + 0.12 * k)], [0.07, 0.04, 0.008], 6, GOLD)
        frustum(bm, V(1.3 * s, 0, 3.1), V(1.34 * s, 0, 2.4), 0.3, 0.26, 12, MARBLE)
        box(bm, V(1.32 * s, -0.1, 2.85), (0.5, 0.06, 0.5), GOLD, bevel=0.02)
        ellipsoid(bm, V(1.34 * s, 0, 2.4), (0.27, 0.27, 0.27), GOLD, 10)

        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(1.34 * s, 0, 2.4), V(1.38 * s, -0.1, 1.65), 0.27, 0.34, 12, MARBLE)
        plate(bm, [(-0.1, 0), (0.1, 0), (0.08, -0.6), (-0.08, -0.6)], V(1.38 * s, -0.3, 2.3), (1, 0, 0), (0, 0, -1), 0.02, VOID)
        box(bm, V(1.38 * s, -0.12, 1.85), (0.56, 0.5, 0.18), GOLD, bevel=0.03)

        bm = boss.piece(f"hand{n}", f"hand{n}")
        ellipsoid(bm, V(1.4 * s, -0.14, 1.45), (0.3, 0.26, 0.36), MARBLE, 12)
        for k in range(4):                                                              # long star-light claws
            sweep(bm, [V((1.3 + k * 0.07) * s, -0.2, 1.3), V((1.32 + k * 0.07) * s, -0.3, 0.95), V((1.34 + k * 0.07) * s, -0.36, 0.6)], [0.05, 0.035, 0.006], 6, STAR)
        ellipsoid(bm, V(1.4 * s, -0.3, 1.5), (0.14, 0.14, 0.14), STAR, 10)               # a star in the palm

        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.3 * s, 0, 1.88), V(0.32 * s, 0, 1.05), 0.3, 0.2, 10, MARBLE)
        ellipsoid(bm, V(0.32 * s, -0.04, 1.05), (0.21, 0.21, 0.21), GOLD, 10)
        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.32 * s, 0, 1.05), V(0.32 * s, 0, 0.25), 0.2, 0.06, 8, MARBLE)
        plate(bm, [(-0.05, 0), (0.05, 0), (0.04, -0.6), (-0.04, -0.6)], V(0.32 * s, -0.16, 1.0), (1, 0, 0), (0, 0, -1), 0.02, STAR)
        bm = boss.piece(f"foot{n}", f"foot{n}")
        sweep(bm, [V(0.32 * s, 0, 0.25), V(0.32 * s, -0.1, 0.1), V(0.32 * s, -0.3, 0.05)], [0.07, 0.05, 0.008], 6, GOLD)

    for i, name in enumerate(cape):                                                     # a cape of woven light, in segments
        bm = boss.piece(name, name)
        z0 = 3.2 - 2.7 * i / CAPE
        z1 = 3.2 - 2.7 * (i + 1) / CAPE
        w0 = 0.9 + 0.35 * i
        w1 = 0.9 + 0.35 * (i + 1)
        y0 = 0.35 + 0.04 * i
        y1 = 0.35 + 0.04 * (i + 1)
        left = [V(-w0, y0, z0), V(-(w0 + w1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), V(-w1, y1, z1)]
        right = [V(w0, y0, z0), V(0.0 + (w0 + w1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), V(w1, y1, z1)]
        ribbon_strip(bm, left, right, 0.02, VOID)
        sweep(bm, [V(-w1, y1, z1), V(w1, y1, z1)], [0.03, 0.03], 5, STAR)

    bm = boss.piece("ringA", "ringA")
    ring(bm, V(0, 0, 2.8), 1.9, math.radians(70), 64, 0.07, GOLD)
    for k in range(6):
        a = k / 6 * math.tau
        ellipsoid(bm, V(math.cos(a) * 1.9, math.sin(a) * 1.9 * math.cos(math.radians(70)), 2.8 + math.sin(a) * 1.9 * math.sin(math.radians(70))), (0.15, 0.15, 0.15), STAR, 10)
    bm = boss.piece("ringB", "ringB")
    ring(bm, V(0, 0, 2.4), 2.4, math.radians(-55), 76, 0.055, STAR)
    ring(bm, V(0, 0, 2.4), 2.55, math.radians(-55), 80, 0.04, VOID)
    return boss


def map_pose(c):
    pose = humanoid.map_humanoid(c, arm_scale=0.85, elbow=-0.2, knee=0.2)
    humanoid.map_chain(pose, c, "cape", CAPE, "cloth", 0.88)
    t = c["torso"]
    pose["halo"] = (0, c["head"][1] * 0.5, c["cloth"][2] * 0.4)
    pose["ringA"] = (0.25 * c["torso"][0], c["torso"][1] * 2 + c["cloth"][1], 0.3 + c["cloth"][2])
    pose["ringB"] = (-0.2 * c["torso"][0], -c["torso"][1] * 2 + c["cloth"][1], -0.4 - c["cloth"][2])
    return pose
