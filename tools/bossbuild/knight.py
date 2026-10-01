"""The Umbral Knight: a gaunt wraith in black plate with a torn cape and a violet-edged greatsword.
About 3 m tall, facing -Y. Armour is dark gunmetal with silver-violet trim; glowing violet runes
and a visor slit; a ragged cloth cape on a three-bone chain; the sword hangs in the right hand."""

import math

from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep
from mathutils import Matrix

KIND = "Knight"
ARMOR, TRIM, GLOW, CLOTH, LEATHER = 0, 1, 2, 3, 4
MATERIALS = {
    "armor": dict(base=((0.03, 0.028, 0.045), (0.14, 0.13, 0.19)), rough=0.45, metal=0.8, noise_scale=7.0, scale=5.0, veins=(0.09, 0.02, 0.2), vein_width=0.035, voro_scale=3.5, veins_glow=1.5),
    "trim": dict(base=((0.2, 0.19, 0.28), (0.55, 0.52, 0.72)), rough=0.35, metal=0.9, noise_scale=10.0),
    "glow": dict(base=(0.4, 0.1, 0.85), rough=0.4, emit=(0.5, 0.12, 1.0, 1.3), noise_scale=6.0),
    "cloth": dict(base=((0.035, 0.015, 0.06), (0.15, 0.06, 0.22)), rough=0.95, noise_scale=14.0, scale=9.0),
    "leather": dict(base=((0.025, 0.02, 0.025), (0.09, 0.075, 0.085)), rough=0.8, noise_scale=12.0),
}
ORDER = ["armor", "trim", "glow", "cloth", "leather"]


def build():
    boss = Boss(KIND, ORDER)
    # ---- skeleton (metres; Z up; facing -Y) ----
    boss.bone("hips", None, V(0, 0, 1.40), V(0, 0, 1.60))
    boss.bone("spine", "hips", V(0, 0, 1.60), V(0, 0, 2.20))
    boss.bone("head", "spine", V(0, 0, 2.52), V(0, 0, 3.05))
    for s, n in ((1, "L"), (-1, "R")):
        boss.bone(f"upperArm{n}", "spine", V(0.80 * s, 0, 2.42), V(0.84 * s, 0, 1.78))
        boss.bone(f"lowerArm{n}", f"upperArm{n}", V(0.84 * s, 0, 1.78), V(0.86 * s, -0.10, 1.12))
        boss.bone(f"hand{n}", f"lowerArm{n}", V(0.86 * s, -0.10, 1.12), V(0.86 * s, -0.14, 0.82))
        boss.bone(f"upperLeg{n}", "hips", V(0.30 * s, 0, 1.38), V(0.32 * s, 0, 0.78))
        boss.bone(f"lowerLeg{n}", f"upperLeg{n}", V(0.32 * s, 0, 0.78), V(0.32 * s, 0, 0.14))
        boss.bone(f"foot{n}", f"lowerLeg{n}", V(0.32 * s, 0, 0.14), V(0.32 * s, -0.32, 0.05))
    boss.bone("cape1", "spine", V(0, 0.26, 2.44), V(0, 0.32, 1.75))
    boss.bone("cape2", "cape1", V(0, 0.32, 1.75), V(0, 0.38, 1.05))
    boss.bone("cape3", "cape2", V(0, 0.38, 1.05), V(0, 0.44, 0.38))
    boss.bone("sword", "handR", V(-0.86, -0.14, 1.02), V(-0.86, -2.2, 1.02))

    # ---- hips: belt, tassets, groin guard ----
    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.48), (0.98, 0.56, 0.2), ARMOR, bevel=0.025)
    box(bm, V(0, -0.29, 1.48), (0.28, 0.06, 0.26), TRIM, bevel=0.015)          # belt buckle
    ellipsoid(bm, V(0, -0.30, 1.48), (0.07, 0.05, 0.07), GLOW, 10)
    for s in (1, -1):
        plate(bm, [(-0.17, 0), (0.17, 0), (0.13, -0.5), (-0.13, -0.5)], V(0.4 * s, -0.26, 1.38), (1, 0, 0), (0, 0.18, -1), 0.045, ARMOR, bevel=0.012)   # tasset
        plate(bm, [(-0.15, 0), (0.15, 0), (0.1, -0.42), (-0.1, -0.42)], V(0.4 * s, 0.27, 1.38), (1, 0, 0), (0, -0.18, -1), 0.045, ARMOR, bevel=0.012)
        ellipsoid(bm, V(0.3 * s, 0, 1.38), (0.17, 0.17, 0.17), TRIM, 10)         # hip joint cap
    plate(bm, [(-0.14, 0), (0.14, 0), (0.0, -0.46)], V(0, -0.27, 1.36), (1, 0, 0), (0, 0.1, -1), 0.05, TRIM, bevel=0.01)

    # ---- spine: abdomen, cuirass, collar, runes ----
    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.58), V(0, 0, 2.0), 0.4, 0.5, 14, ARMOR, squash=0.75)
    for k in range(3):                                                      # lames
        frustum(bm, V(0, 0, 1.64 + k * 0.13), V(0, 0, 1.76 + k * 0.13), 0.44 + k * 0.025, 0.45 + k * 0.025, 14, TRIM if k == 1 else ARMOR, squash=0.78)
    ellipsoid(bm, V(0, 0.0, 2.28), (0.55, 0.36, 0.44), ARMOR, 16)           # chest
    ellipsoid(bm, V(0.2, -0.14, 2.3), (0.3, 0.26, 0.36), ARMOR, 12)         # breast plates
    ellipsoid(bm, V(-0.2, -0.14, 2.3), (0.3, 0.26, 0.36), ARMOR, 12)
    plate(bm, [(-0.05, 0), (0.05, 0), (0.07, -0.55), (0, -0.62), (-0.07, -0.55)], V(0, -0.36, 2.58), (1, 0, 0), (0, 0.1, -1), 0.05, TRIM, bevel=0.01)  # sternum ridge
    plate(bm, [(0, 0.18), (0.13, 0), (0.07, -0.14), (-0.07, -0.14), (-0.13, 0)], V(0, -0.4, 2.3), (1, 0, 0), (0, 0.05, 1), 0.02, GLOW)            # chest rune
    plate(bm, [(-0.02, 0.2), (0.02, 0.2), (0.02, -0.2), (-0.02, -0.2)], V(0, -0.405, 2.3), (1, 0, 0), (0, 0.05, 1), 0.02, GLOW)
    box(bm, V(0, 0.27, 2.3), (0.85, 0.12, 0.7), ARMOR, bevel=0.04)          # back plate
    frustum(bm, V(0, 0, 2.46), V(0, 0, 2.62), 0.3, 0.24, 14, TRIM)          # gorget
    for k in range(3):
        box(bm, V(0, 0.37, 2.5 - k * 0.14), (0.5 - k * 0.08, 0.05, 0.09), TRIM, bevel=0.01)
    for s in (1, -1):                                                       # spine blades
        sweep(bm, [V(0.12 * s, 0.34, 2.55), V(0.2 * s, 0.5, 2.85), V(0.24 * s, 0.62, 3.1)], [0.06, 0.04, 0.01], 5, TRIM)

    # ---- head: helm, visor, horns, plume ----
    bm = boss.piece("head", "head")
    ellipsoid(bm, V(0, 0.0, 2.85), (0.33, 0.37, 0.4), ARMOR, 16)
    plate(bm, [(-0.26, 0.18), (0.26, 0.18), (0.2, -0.2), (0, -0.28), (-0.2, -0.2)], V(0, -0.3, 2.88), (1, 0, 0), (0, 0.1, 1), 0.04, ARMOR, bevel=0.01)   # faceplate
    plate(bm, [(-0.2, 0.025), (0.2, 0.025), (0.17, -0.025), (-0.17, -0.025)], V(0, -0.34, 2.9), (1, 0, 0), (0, 0.1, 1), 0.03, GLOW)                         # visor slit
    box(bm, V(0, -0.34, 2.74), (0.12, 0.07, 0.22), TRIM, bevel=0.01)       # nasal
    frustum(bm, V(0, 0, 2.55), V(0, 0, 2.7), 0.27, 0.3, 12, TRIM)           # neck guard
    for s in (1, -1):
        sweep(bm, [V(0.28 * s, 0.0, 3.0), V(0.5 * s, -0.04, 3.18), V(0.55 * s, -0.1, 3.5)], [0.07, 0.05, 0.012], 6, TRIM)   # horns
    sweep(bm, [V(0, 0.2, 3.1), V(0, 0.45, 3.14), V(0, 0.72, 2.92)], [0.05, 0.045, 0.01], 6, ARMOR, squash=0.4)              # crest

    # ---- arms, pauldrons, gauntlets ----
    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        ellipsoid(bm, V(0.8 * s, 0, 2.42), (0.27, 0.27, 0.22), ARMOR, 14)    # pauldron
        for k in range(3):
            ellipsoid(bm, V(0.83 * s, 0, 2.36 - k * 0.11), (0.3 - k * 0.02, 0.28 - k * 0.02, 0.09), TRIM if k == 2 else ARMOR, 14)
        sweep(bm, [V(0.96 * s, 0, 2.62), V(1.1 * s, 0, 2.86), V(1.12 * s, 0, 3.12)], [0.06, 0.04, 0.01], 5, TRIM)          # spike
        frustum(bm, V(0.82 * s, 0, 2.28), V(0.84 * s, 0, 1.8), 0.17, 0.15, 12, ARMOR)
        frustum(bm, V(0.83 * s, 0, 2.1), V(0.84 * s, 0, 1.9), 0.2, 0.19, 12, TRIM, squash=0.9)
        ellipsoid(bm, V(0.84 * s, 0, 1.78), (0.17, 0.17, 0.17), TRIM, 10)  # elbow cop
        sweep(bm, [V(0.84 * s, 0.1, 1.78), V(0.84 * s, 0.26, 1.7), V(0.84 * s, 0.4, 1.56)], [0.05, 0.035, 0.008], 5, TRIM)  # elbow spike

        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(0.84 * s, 0, 1.78), V(0.86 * s, -0.10, 1.12), 0.15, 0.12, 12, ARMOR)
        plate(bm, [(-0.08, 0), (0.08, 0), (0.1, -0.5), (0, -0.56), (-0.1, -0.5)], V(0.86 * s, -0.17, 1.74), (1, 0, 0), (0, -0.15, -1), 0.03, TRIM, bevel=0.008)   # vambrace
        for k in range(3):
            frustum(bm, V(0.85 * s, -0.04 - k * 0.025, 1.6 - k * 0.15), V(0.855 * s, -0.045 - k * 0.025, 1.56 - k * 0.15), 0.155 - k * 0.012, 0.155 - k * 0.012, 12, TRIM)

        bm = boss.piece(f"hand{n}", f"hand{n}")
        box(bm, V(0.86 * s, -0.15, 0.98), (0.17, 0.2, 0.2), ARMOR, bevel=0.025)    # fist
        for f in range(4):
            box(bm, V((0.8 + f * 0.04) * s, -0.26, 0.96), (0.035, 0.07, 0.17), TRIM, bevel=0.008)
        box(bm, V(0.77 * s, -0.17, 1.02), (0.05, 0.1, 0.12), TRIM, bevel=0.008)
        ellipsoid(bm, V(0.86 * s, -0.1, 1.1), (0.11, 0.11, 0.11), TRIM, 10)         # wrist cuff

    # ---- legs ----
    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.3 * s, 0, 1.36), V(0.32 * s, 0, 0.8), 0.22, 0.17, 12, ARMOR)
        plate(bm, [(-0.12, 0), (0.12, 0), (0.1, -0.52), (-0.1, -0.52)], V(0.31 * s, -0.2, 1.3), (1, 0, 0), (0, -0.05, -1), 0.04, TRIM, bevel=0.01)
        ellipsoid(bm, V(0.32 * s, -0.04, 0.78), (0.17, 0.17, 0.17), TRIM, 10)        # poleyn
        sweep(bm, [V(0.32 * s, -0.16, 0.78), V(0.32 * s, -0.3, 0.76), V(0.32 * s, -0.46, 0.68)], [0.05, 0.035, 0.008], 5, TRIM)

        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.32 * s, 0, 0.78), V(0.32 * s, 0, 0.16), 0.16, 0.115, 12, ARMOR)
        plate(bm, [(-0.07, 0), (0.07, 0), (0.05, -0.55), (-0.05, -0.55)], V(0.32 * s, -0.17, 0.72), (1, 0, 0), (0, -0.05, -1), 0.035, TRIM, bevel=0.008)
        ellipsoid(bm, V(0.32 * s, 0, 0.15), (0.12, 0.12, 0.12), TRIM, 10)            # ankle cap

        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.32 * s, -0.1, 0.07), (0.2, 0.38, 0.12), ARMOR, bevel=0.025)
        sweep(bm, [V(0.32 * s, -0.28, 0.07), V(0.32 * s, -0.4, 0.06), V(0.32 * s, -0.52, 0.04)], [0.07, 0.05, 0.012], 6, TRIM, squash=0.7)
        box(bm, V(0.32 * s, 0.1, 0.1), (0.18, 0.1, 0.12), TRIM, bevel=0.015)

    # ---- cape: three bone segments, five ragged tongues across ----
    widths = [(0.62, 0.7), (0.7, 0.78), (0.78, 0.84)]
    tops = [2.44, 1.75, 1.05]
    for index in range(3):
        bm = boss.piece(f"cape{index + 1}", f"cape{index + 1}")
        y0 = 0.26 + 0.06 * index
        z0, z1 = tops[index], tops[index] - 0.7
        w0, w1 = widths[index]
        columns = 5 if index == 2 else 1
        for c in range(columns):
            a, b = (-w1 + c * 2 * w1 / columns), (-w1 + (c + 1) * 2 * w1 / columns)
            drop = [0.0, 0.08, 0.2, 0.04, 0.14][c] if index == 2 else 0.0
            left = [V(a * w0 / w1, y0, z0), V(a, y0 + 0.03, (z0 + z1) / 2), V(a * 0.96, y0 + 0.06, z1 + drop * 0.3)]
            right = [V(b * w0 / w1, y0, z0), V(b, y0 + 0.03, (z0 + z1) / 2), V(b * 0.96, y0 + 0.06, z1 + drop * 0.3 - (0.05 if c % 2 else 0.0))]
            ribbon_strip(bm, left, right, 0.025, CLOTH)
        if index == 0:
            for s in (1, -1):                                              # cape clasps
                ellipsoid(bm, V(0.34 * s, 0.24, 2.46), (0.07, 0.05, 0.07), GLOW, 8)
            frustum(bm, V(-0.4, 0.25, 2.47), V(0.4, 0.25, 2.47), 0.035, 0.035, 8, TRIM)

    # ---- sword: held by the right hand, point forward ----
    bm = boss.piece("sword", "sword")
    ax = V(1, 0, 0)
    plate(bm, [(0, -0.28), (0.1, -0.34), (0.11, -1.9), (0, -2.35), (-0.11, -1.9), (-0.1, -0.34)], V(-0.86, 0, 1.0), (1, 0, 0), (0, -1, 0), 0.05, TRIM, bevel=0.006)
    plate(bm, [(-0.03, -0.4), (0.03, -0.4), (0.03, -1.95), (0, -2.1), (-0.03, -1.95)], V(-0.86, 0, 1.026), (1, 0, 0), (0, -1, 0), 0.012, GLOW)        # glowing fuller
    box(bm, V(-0.86, -0.3, 1.02), (0.62, 0.07, 0.09), ARMOR, bevel=0.015)       # crossguard
    for s in (1, -1):
        sweep(bm, [V(-0.86 + 0.3 * s, -0.3, 1.02), V(-0.86 + 0.42 * s, -0.32, 1.1), V(-0.86 + 0.46 * s, -0.36, 1.28)], [0.04, 0.03, 0.008], 5, TRIM)
    frustum(bm, V(-0.86, -0.1, 1.02), V(-0.86, -0.3, 1.02), 0.04, 0.04, 8, LEATHER)
    ellipsoid(bm, V(-0.86, -0.04, 1.02), (0.06, 0.06, 0.06), GLOW, 8)
    return boss


def map_pose(c):
    """Map the shared channels onto the knight's bones."""
    pose = {}
    pose["spine"] = tuple(c["torso"])
    pose["head"] = tuple(c["head"])
    for chan, n in (("armL", "L"), ("armR", "R")):
        p, y, r = c[chan]
        pose[f"upperArm{n}"] = (p * 0.85, y * 0.85, r * 0.85)
        pose[f"lowerArm{n}"] = (-0.22 + min(0.0, p) * 0.4 + max(0.0, p) * 0.1, 0, 0)
        pose[f"hand{n}"] = (p * 0.08, 0, 0)
    for chan, n in (("legL", "L"), ("legR", "R")):
        p, y, r = c[chan]
        pose[f"upperLeg{n}"] = (p, y, r)
        pose[f"lowerLeg{n}"] = (abs(p) * 0.55 + 0.04, 0, 0)
        pose[f"foot{n}"] = (-abs(p) * 0.3, 0, 0)
    cp, cy, cr = c["cloth"]
    pose["cape1"] = (cp, cy, cr)
    pose["cape2"] = (cp * 0.9 + 0.05, cy, cr * 0.9)
    pose["cape3"] = (cp * 0.8 + 0.1, cy, cr * 0.8)
    pose["sword"] = (c["armR"][0] * 0.1 + 0.05, 0, 0)
    return pose
