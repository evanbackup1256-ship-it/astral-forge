"""Modelling kit for the bosses: cloth that the game simulates, wings with real feathers, and the
armour pieces the knights share. Metres, +Z up, the character faces -Y, left = +X.

Everything here builds bones, pieces AND the physics description together, so a cape built with
`cape()` arrives in the game as a sheet of simulated columns, and a wing built with `wing()` as an arm
chain with a fan of simulated feathers hanging off it (see src/Shared/AstralForge/Shared/BossPhysics).
"""

import math
import random

from lib import V, box, ellipsoid, frustum, plate, ribbon_strip, sweep

LETTERS = "ABCDEFGHIJKLMNOP"


def _smooth(u):
    return u * u * (3 - 2 * u)


def cape(boss, prefix, parent, top_z, bottom_z, half_top, half_bottom, y_top, y_bottom, columns, segments,
         mat, edge_mat=None, bow=0.05, tatter=0.0, seed=1, x_center=0.0, thickness=0.02, kind="cloth", **settings):
    """A hanging sheet: `columns` side-by-side strips, each a chain of `segments` bones.

    The sheet runs from (top_z, y_top, half_top wide) at the shoulders to (bottom_z, y_bottom,
    half_bottom wide) at the hem. `bow` curves the sheet outward across its width, `tatter` ragged-cuts
    the hem (0..1 of one segment). Columns overlap their neighbours slightly so the cloth never shows a
    gap while it moves. Returns the bone names, column by column.
    """
    rng = random.Random(seed)
    names = []
    seg_h = (top_z - bottom_z) / segments
    for col in range(columns):
        u0, u1 = col / columns, (col + 1) / columns
        um = (u0 + u1) / 2
        column = []
        for seg in range(segments):
            t0, t1 = seg / segments, (seg + 1) / segments
            z0, z1 = top_z - seg_h * seg, top_z - seg_h * (seg + 1)
            # the sheet's own centre line at this height
            def half(t):
                return half_top + (half_bottom - half_top) * t

            def yline(t):
                return y_top + (y_bottom - y_top) * t

            def xat(u, t):
                return x_center + (u * 2 - 1) * half(t)

            name = f"{prefix}{LETTERS[col]}{seg + 1}"
            head = V(xat(um, t0), yline(t0), z0)
            tail = V(xat(um, t1), yline(t1), z1)
            parent_bone = parent if seg == 0 else column[-1]
            boss.bone(name, parent_bone, head, tail)
            column.append(name)
            bm = boss.piece(name, name)
            # three rows of points per edge so the strip can bow
            rows = (t0, (t0 + t1) / 2, t1)
            left, right = [], []
            overlap = 0.5 * (half(t0) * 2 / columns) * 0.12
            for k, t in enumerate(rows):
                curve = bow * (1 - (2 * um - 1) ** 2)            # centre of the sheet stands proud of its edges
                zz = top_z - seg_h * (seg + (0, 0.5, 1)[k])
                if seg == segments - 1 and k == 2 and tatter > 0:
                    zz -= tatter * seg_h * rng.uniform(-0.4, 0.9)
                left.append(V(xat(u0, t) - overlap, yline(t) + curve * 0.6 + 0.0, zz))
                right.append(V(xat(u1, t) + overlap, yline(t) + curve * 0.6, zz))
            ribbon_strip(bm, left, right, thickness, mat)
            if edge_mat is not None and seg == segments - 1:
                hem = 0.045
                ribbon_strip(bm, [left[2] + V(0, -0.004, hem), left[2] + V(0, -0.004, 0)], [right[2] + V(0, -0.004, hem), right[2] + V(0, -0.004, 0)], thickness * 1.5, edge_mat)
        boss.chain(kind, column, group=prefix, column=col, **settings)
        names.append(column)
    return names


def feather(bm, base, direction, length, width, mat, thick=0.02, droop=0.0, rachis=None, rachis_mat=None):
    """A leaf-shaped feather with a central shaft, lying in the plane spanned by `direction` and the
    vertical, fanning backward by `droop`."""
    d = V(*direction).normalized()
    up = V(0, 0, 1)
    side = d.cross(up)
    if side.length < 1e-4:
        side = V(1, 0, 0)
    side = side.normalized()
    normal = d.cross(side).normalized()
    u = d
    v = side
    outline = [(0, 0), (0.18 * length, width * 0.62), (0.55 * length, width), (0.88 * length, width * 0.55), (length, 0),
               (0.88 * length, -width * 0.55), (0.55 * length, -width), (0.18 * length, -width * 0.62)]
    plate(bm, outline, V(*base), u, v, thick, mat)
    if rachis is not None:
        sweep(bm, [V(*base), V(*base) + u * (length * 0.5), V(*base) + u * length], [0.012, 0.009, 0.003], 4, rachis_mat if rachis_mat is not None else mat)
    return normal


def wing(boss, side, prefix, parent, root, elbow, tip, feathers, arm_mat, feather_mat, covert_mat=None,
         lengths=(1.5, 2.3), width=0.18, fan=0.5, seed=3, under_mat=None):
    """One wing: a three-bone arm (shoulder -> elbow -> wrist) and a trailing fan of two-bone feathers.

    root / elbow / tip are the arm's three joint positions (metres). `feathers` flight feathers hang off
    the arm, longest at the tip; each is a short simulated chain, so the wing ripples along its edge as it
    beats. The arm itself is a stiff chain with a little lag. Returns (arm bones, feather chains).
    """
    rng = random.Random(seed)
    s = side
    root, elbow, tip = V(*root), V(*elbow), V(*tip)
    mid = (elbow + tip) / 2
    joints = [root, elbow, mid, tip]
    arm = []
    for k in range(3):
        name = f"{prefix}{k + 1}"
        boss.bone(name, parent if k == 0 else arm[-1], joints[k], joints[k + 1])
        arm.append(name)
        bm = boss.piece(name, name)
        frustum(bm, joints[k], joints[k + 1], 0.09 - 0.02 * k, 0.075 - 0.02 * k, 8, arm_mat)
        ellipsoid(bm, joints[k + 1], (0.07 - 0.015 * k,) * 3, arm_mat, 8)
    boss.chain("wing", arm, group=prefix, column=0, Pull=0.5, Drag=0.9, Gravity=4)
    chains = []
    count = max(2, feathers)
    # layer 1 is the long flight feathers; layer 2 is a shorter row between them, slightly lower, that fills the gaps
    layers = [("F", 1.0, 0.0, feather_mat, 0.0)]
    if under_mat is not None:
        layers.append(("G", 0.62, 0.5, under_mat, -0.05))
    for tag, scale, shift, layer_mat, drop in layers:
        for k in range(count):
            t = min(1.0, (k + shift) / (count - 1))
            along = t * 2.97                                             # 0..3 over the three arm segments
            seg = min(2, int(along))
            local = along - seg
            base = joints[seg] + (joints[seg + 1] - joints[seg]) * local + V(0, 0, drop)
            length = (lengths[0] + (lengths[1] - lengths[0]) * (0.25 + 0.75 * t) + rng.uniform(-0.05, 0.05)) * scale
            # each feather points out and back; the further out the wing, the further it fans downward
            spread = 0.25 + fan * t
            direction = V(s * (0.28 + 0.45 * t), 0.55 + 0.3 * t, -spread * (0.55 + 0.5 * t)).normalized()
            a, b = f"{prefix}{tag}{k + 1}a", f"{prefix}{tag}{k + 1}b"
            mid_pt = base + direction * (length * 0.5)
            end_pt = base + direction * length
            boss.bone(a, arm[seg], base, mid_pt)
            boss.bone(b, a, mid_pt, end_pt)
            bm = boss.piece(a, a)
            feather(bm, tuple(base), direction, length * 0.52, width * scale ** 0.5 * (0.8 + 0.2 * t), layer_mat, 0.018, rachis=True)
            bm = boss.piece(b, b)
            feather(bm, tuple(mid_pt), direction, length * 0.5, width * scale ** 0.5 * (0.95 + 0.1 * t), layer_mat, 0.016, rachis=True)
            boss.chain("wing", [a, b], group=f"{prefix}{tag}{k + 1}", column=0, Pull=0.16 + (0.08 if tag == "G" else 0), Drag=0.9, Gravity=6)
            chains.append([a, b])
    if covert_mat is not None:
        # short covert feathers laid over the arm (rigid with it)
        for seg in range(3):
            bm = boss.pieces[arm[seg]]["bm"]
            for k in range(5):
                base = joints[seg] + (joints[seg + 1] - joints[seg]) * (k / 5)
                direction = V(s * 0.35, 0.8, -0.25).normalized()
                feather(bm, tuple(base + V(0, 0.05, -0.03)), direction, 0.55 - 0.03 * seg, width * 0.7, covert_mat, 0.015)
    return arm, chains


def skirt(boss, prefix, parent, top_z, bottom_z, r_top, r_bottom, columns, segments, mat, edge_mat=None,
          squash=0.7, tatter=0.0, seed=1, thickness=0.025, y_center=0.0, **settings):
    """A hanging skirt or robe: `columns` strips around a ring (front at -Y), each a chain of `segments`
    bones. The ring is closed in the simulation (the last column is linked back to the first), so the
    whole robe swings together. `squash` flattens the ring front-to-back."""
    rng = random.Random(seed)
    seg_h = (top_z - bottom_z) / segments
    names = []
    for col in range(columns):
        a0, a1 = col / columns * math.tau, (col + 1) / columns * math.tau
        am = (a0 + a1) / 2
        column = []
        for seg in range(segments):
            t0, t1 = seg / segments, (seg + 1) / segments

            def radius(t):
                return r_top + (r_bottom - r_top) * t

            def at(a, t, z):
                r = radius(t)
                return V(math.sin(a) * r, y_center - math.cos(a) * r * squash, z)

            name = f"{prefix}{LETTERS[col]}{seg + 1}"
            z0, z1 = top_z - seg_h * seg, top_z - seg_h * (seg + 1)
            parent_bone = parent if seg == 0 else column[-1]
            boss.bone(name, parent_bone, at(am, t0, z0), at(am, t1, z1))
            column.append(name)
            bm = boss.piece(name, name)
            overlap = 0.04
            left, right = [], []
            for k, t in enumerate((t0, (t0 + t1) / 2, t1)):
                zz = top_z - seg_h * (seg + (0, 0.5, 1)[k])
                if seg == segments - 1 and k == 2 and tatter > 0:
                    zz -= tatter * seg_h * rng.uniform(-0.3, 0.9)
                left.append(at(a0 - overlap, t, zz))
                right.append(at(a1 + overlap, t, zz))
            ribbon_strip(bm, left, right, thickness, mat)
            if edge_mat is not None and seg == segments - 1:
                ribbon_strip(bm, [left[2] + V(0, 0, 0.04), left[2]], [right[2] + V(0, 0, 0.04), right[2]], thickness * 1.5, edge_mat)
        boss.chain("cloth", column, group=prefix, column=col, Ring=True, **settings)
        names.append(column)
    return names
