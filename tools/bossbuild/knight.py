"""The Umbral Knight: a gaunt wraith in black plate with a torn cape and a violet-edged greatsword.
About 3.3 m tall, facing -Y. Armour is dark gunmetal with silver-violet trim; violet glow is kept to a
few places that matter (visor, chest rune, sword fuller, belt gem, gauntlet runes). The cape is five
simulated columns, the greatsword is held point-forward in the right fist."""

import math

import humanoid
import kit
from lib import V, Boss, box, ellipsoid, frustum, plate, ribbon_strip, sweep

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
    humanoid.skeleton(boss, hip_z=1.45, chest_z=2.3, neck_z=2.62, head_top=3.18, shoulder_x=0.84, shoulder_z=2.5, elbow_z=1.82, wrist_z=1.14, hand_z=0.84, hip_x=0.3, knee_z=0.8, ankle_z=0.15)
    # The greatsword: its bone sits in the right fist and points straight forward (-Y).
    boss.bone("sword", "handR", V(-0.88, -0.16, 1.02), V(-0.88, -2.4, 1.02))
    capes = kit.cape(boss, "cape", "spine", top_z=2.5, bottom_z=0.38, half_top=0.46, half_bottom=0.7, y_top=0.3, y_bottom=0.5,
                     columns=5, segments=3, mat=CLOTH, edge_mat=GLOW, bow=0.06, tatter=0.8, seed=7)

    # ---- hips: belt, tassets, groin guard ----
    bm = boss.piece("hips", "hips")
    box(bm, V(0, 0, 1.52), (1.0, 0.58, 0.2), ARMOR, bevel=0.03)
    box(bm, V(0, -0.31, 1.52), (0.3, 0.06, 0.26), TRIM, bevel=0.015)                       # belt buckle
    ellipsoid(bm, V(0, -0.33, 1.52), (0.075, 0.05, 0.075), GLOW, 10)
    for s in (1, -1):
        plate(bm, [(-0.18, 0), (0.18, 0), (0.14, -0.52), (-0.14, -0.52)], V(0.4 * s, -0.27, 1.42), (1, 0, 0), (0, 0.18, -1), 0.045, ARMOR, bevel=0.012)   # front tasset
        plate(bm, [(-0.16, 0), (0.16, 0), (0.11, -0.44), (-0.11, -0.44)], V(0.4 * s, 0.28, 1.42), (1, 0, 0), (0, -0.18, -1), 0.045, ARMOR, bevel=0.012)   # rear tasset
        ellipsoid(bm, V(0.3 * s, 0, 1.43), (0.17, 0.17, 0.17), TRIM, 10)                  # hip cap
    plate(bm, [(-0.15, 0), (0.15, 0), (0.0, -0.5)], V(0, -0.28, 1.4), (1, 0, 0), (0, 0.1, -1), 0.05, TRIM, bevel=0.01)   # codpiece plate

    # ---- spine: cuirass, lames, gorget, back plate ----
    bm = boss.piece("spine", "spine")
    frustum(bm, V(0, 0, 1.62), V(0, 0, 2.1), 0.4, 0.5, 14, ARMOR, squash=0.75)
    for k in range(3):                                                                      # abdomen lames
        frustum(bm, V(0, 0, 1.66 + k * 0.14), V(0, 0, 1.79 + k * 0.14), 0.45 + k * 0.025, 0.46 + k * 0.025, 14, TRIM if k == 1 else ARMOR, squash=0.78)
    ellipsoid(bm, V(0, 0.0, 2.36), (0.56, 0.37, 0.45), ARMOR, 18)                           # chest
    ellipsoid(bm, V(0.2, -0.15, 2.38), (0.3, 0.26, 0.36), ARMOR, 12)                         # breast plates
    ellipsoid(bm, V(-0.2, -0.15, 2.38), (0.3, 0.26, 0.36), ARMOR, 12)
    plate(bm, [(0, 0.2), (0.14, 0), (0.07, -0.16), (-0.07, -0.16), (-0.14, 0)], V(0, -0.41, 2.38), (1, 0, 0), (0, 0.05, 1), 0.02, GLOW)   # chest rune
    plate(bm, [(-0.022, 0.22), (0.022, 0.22), (0.022, -0.22), (-0.022, -0.22)], V(0, -0.415, 2.38), (1, 0, 0), (0, 0.05, 1), 0.02, GLOW)
    box(bm, V(0, 0.28, 2.38), (0.88, 0.12, 0.72), ARMOR, bevel=0.04)                        # back plate
    for k in range(3):
        box(bm, V(0, 0.38, 2.58 - k * 0.15), (0.54 - k * 0.09, 0.05, 0.09), TRIM, bevel=0.01)   # spine ridge
    frustum(bm, V(0, 0, 2.52), V(0, 0, 2.7), 0.32, 0.25, 14, TRIM)                          # gorget
    for s in (1, -1):                                                                       # clasps for the cape
        ellipsoid(bm, V(0.36 * s, 0.26, 2.52), (0.07, 0.05, 0.07), GLOW, 8)
    frustum(bm, V(-0.42, 0.27, 2.53), V(0.42, 0.27, 2.53), 0.032, 0.032, 8, TRIM)

    # ---- head: great helm with a visor slit and two swept horns ----
    bm = boss.piece("head", "head")
    ellipsoid(bm, V(0, 0.0, 2.92), (0.34, 0.38, 0.41), ARMOR, 18)
    plate(bm, [(-0.27, 0.18), (0.27, 0.18), (0.21, -0.2), (0, -0.29), (-0.21, -0.2)], V(0, -0.31, 2.94), (1, 0, 0), (0, 0.1, 1), 0.04, ARMOR, bevel=0.01)   # face plate
    plate(bm, [(-0.21, 0.026), (0.21, 0.026), (0.18, -0.026), (-0.18, -0.026)], V(0, -0.345, 2.96), (1, 0, 0), (0, 0.1, 1), 0.03, GLOW)                     # visor slit
    box(bm, V(0, -0.35, 2.8), (0.12, 0.07, 0.22), TRIM, bevel=0.01)                         # nasal bar
    frustum(bm, V(0, 0, 2.6), V(0, 0, 2.76), 0.28, 0.31, 12, TRIM)                          # neck guard
    for s in (1, -1):
        sweep(bm, [V(0.3 * s, 0.0, 3.06), V(0.52 * s, -0.05, 3.2), V(0.6 * s, -0.12, 3.52)], [0.075, 0.052, 0.012], 6, TRIM)   # swept horns
    box(bm, V(0, 0.05, 3.3), (0.06, 0.5, 0.06), ARMOR, bevel=0.012, rot=None)               # crest ridge

    # ---- arms: layered pauldrons, plated sleeves, gauntlets ----
    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperArm{n}", f"upperArm{n}")
        ellipsoid(bm, V(0.84 * s, 0, 2.5), (0.29, 0.29, 0.23), ARMOR, 16)                    # pauldron dome
        for k in range(3):                                                                  # stepped plates
            ellipsoid(bm, V(0.87 * s, 0, 2.44 - k * 0.11), (0.32 - k * 0.02, 0.3 - k * 0.02, 0.095), TRIM if k == 2 else ARMOR, 16)
        sweep(bm, [V(1.0 * s, 0, 2.7), V(1.14 * s, 0, 2.94), V(1.16 * s, 0, 3.2)], [0.065, 0.042, 0.01], 5, TRIM)   # a single shoulder spike
        frustum(bm, V(0.86 * s, 0, 2.36), V(0.88 * s, 0, 1.86), 0.17, 0.15, 14, ARMOR)
        frustum(bm, V(0.87 * s, 0, 2.18), V(0.88 * s, 0, 1.98), 0.2, 0.19, 14, TRIM, squash=0.9)
        ellipsoid(bm, V(0.88 * s, 0, 1.82), (0.17, 0.17, 0.17), TRIM, 12)                    # elbow cop

        bm = boss.piece(f"lowerArm{n}", f"lowerArm{n}")
        frustum(bm, V(0.88 * s, 0, 1.82), V(0.9 * s, -0.1, 1.16), 0.15, 0.12, 14, ARMOR)
        plate(bm, [(-0.08, 0), (0.08, 0), (0.1, -0.5), (0, -0.56), (-0.1, -0.5)], V(0.9 * s, -0.17, 1.78), (1, 0, 0), (0, -0.15, -1), 0.03, TRIM, bevel=0.008)   # vambrace
        for k in range(3):
            frustum(bm, V(0.89 * s, -0.04 - k * 0.025, 1.64 - k * 0.15), V(0.895 * s, -0.045 - k * 0.025, 1.6 - k * 0.15), 0.155 - k * 0.012, 0.155 - k * 0.012, 12, TRIM)

        bm = boss.piece(f"hand{n}", f"hand{n}")
        box(bm, V(0.9 * s, -0.16, 1.0), (0.19, 0.22, 0.21), ARMOR, bevel=0.03)              # fist
        for f in range(4):
            box(bm, V((0.83 + f * 0.045) * s, -0.28, 0.98), (0.04, 0.075, 0.18), TRIM, bevel=0.01)   # finger plates
        box(bm, V(0.8 * s, -0.18, 1.04), (0.055, 0.11, 0.13), TRIM, bevel=0.01)             # thumb
        ellipsoid(bm, V(0.9 * s, -0.11, 1.13), (0.115, 0.115, 0.115), TRIM, 10)             # wrist cuff
        plate(bm, [(-0.03, 0.04), (0.03, 0.04), (0.03, -0.04), (-0.03, -0.04)], V(0.9 * s, -0.27, 1.05), (1, 0, 0), (0, 0, 1), 0.015, GLOW)   # knuckle rune

    # ---- legs: plated, with rounded caps and no spikes ----
    for s, n in ((1, "L"), (-1, "R")):
        bm = boss.piece(f"upperLeg{n}", f"upperLeg{n}")
        frustum(bm, V(0.3 * s, 0, 1.42), V(0.32 * s, 0, 0.84), 0.22, 0.175, 14, ARMOR)
        plate(bm, [(-0.12, 0), (0.12, 0), (0.1, -0.52), (-0.1, -0.52)], V(0.31 * s, -0.21, 1.36), (1, 0, 0), (0, -0.05, -1), 0.04, TRIM, bevel=0.01)
        ellipsoid(bm, V(0.32 * s, -0.05, 0.82), (0.18, 0.18, 0.18), TRIM, 12)               # poleyn

        bm = boss.piece(f"lowerLeg{n}", f"lowerLeg{n}")
        frustum(bm, V(0.32 * s, 0, 0.82), V(0.32 * s, 0, 0.18), 0.165, 0.12, 14, ARMOR)
        plate(bm, [(-0.07, 0), (0.07, 0), (0.05, -0.56), (-0.05, -0.56)], V(0.32 * s, -0.18, 0.76), (1, 0, 0), (0, -0.05, -1), 0.035, TRIM, bevel=0.008)
        ellipsoid(bm, V(0.32 * s, 0, 0.17), (0.125, 0.125, 0.125), TRIM, 10)                # ankle cap

        bm = boss.piece(f"foot{n}", f"foot{n}")
        box(bm, V(0.32 * s, -0.1, 0.075), (0.21, 0.4, 0.13), ARMOR, bevel=0.03)
        sweep(bm, [V(0.32 * s, -0.28, 0.075), V(0.32 * s, -0.4, 0.065), V(0.32 * s, -0.5, 0.05)], [0.075, 0.05, 0.012], 6, TRIM, squash=0.7)   # sabaton toe
        box(bm, V(0.32 * s, 0.1, 0.1), (0.19, 0.1, 0.13), TRIM, bevel=0.015)                # heel

    # ---- the greatsword: grip, crossguard and a long blade, all pointing forward (-Y) ----
    bm = boss.piece("sword", "sword")
    ox, oz = -0.88, 1.02
    frustum(bm, V(ox, 0.0, oz), V(ox, -0.32, oz), 0.042, 0.042, 8, LEATHER)                 # grip
    ellipsoid(bm, V(ox, 0.02, oz), (0.065, 0.065, 0.065), GLOW, 8)                          # pommel gem
    box(bm, V(ox, -0.36, oz), (0.7, 0.08, 0.1), ARMOR, bevel=0.018)                         # crossguard
    for s in (1, -1):
        sweep(bm, [V(ox + 0.32 * s, -0.36, oz), V(ox + 0.46 * s, -0.4, oz + 0.08), V(ox + 0.5 * s, -0.46, oz + 0.3)], [0.045, 0.032, 0.008], 5, TRIM)   # swept quillons
    # blade: a flat plate lying in the XY plane, tapering to a point, 1.9 m long
    plate(bm, [(-0.11, 0), (0.11, 0), (0.115, 1.7), (0.0, 2.05), (-0.115, 1.7)], V(ox, -0.4, oz - 0.025), (1, 0, 0), (0, -1, 0), 0.05, TRIM, bevel=0.006)
    plate(bm, [(-0.028, 0.1), (0.028, 0.1), (0.028, 1.6), (0, 1.8), (-0.028, 1.6)], V(ox, -0.4, oz + 0.026), (1, 0, 0), (0, -1, 0), 0.012, GLOW)             # glowing fuller
    return boss


def map_pose(c):
    """Map the shared channels onto the knight's bones."""
    pose = humanoid.map_humanoid(c, arm_scale=0.85, elbow=-0.22, knee=0.55)
    cp, cy, cr = c["cloth"]
    for col in range(5):                                         # the first bone of each cape column; physics does the rest
        pose[f"cape{kit.LETTERS[col]}1"] = (cp * 0.9, cy, cr * 0.9)
    # the sword is gripped angled down from the fist, so a raised arm still leaves the blade pointing out and a little up
    pose["sword"] = (0.9 + c["armR"][0] * 0.05, 0, 0)
    return pose
