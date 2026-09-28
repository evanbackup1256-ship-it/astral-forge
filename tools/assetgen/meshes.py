"""Procedural models for Astral Forge, exported as one binary glTF (.glb).

Everything here is faceted and flat-shaded on purpose: it matches the game's
neon-and-glass look and keeps triangle counts low. Each model is a named node
in the file, so importing or uploading the .glb gives one Model holding a
MeshPart per model, named as below. The game sets each MeshPart's Size, colour
and material at runtime, so the native scale here only fixes proportions.

    Crystal       CrystalShard   RockA  RockB  RockC   BasaltCluster
    VoidSpire     Obelisk        Plinth Lantern        ArenaPillar
    Star          WardenCore     WardenPlate           WardenBlade
    Halo          BridgeDeck
"""

from __future__ import annotations

import json
import math
import random
import struct

Vec = tuple  # (x, y, z)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def length(a):
    return math.sqrt(dot(a, a))


def norm(a):
    l = length(a)
    return (a[0] / l, a[1] / l, a[2] / l) if l > 1e-12 else (0.0, 1.0, 0.0)


def rot_y(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def rot_x(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


def rot_z(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


class Mesh:
    """A soup of triangles. Winding is fixed per part against a centre point."""

    def __init__(self):
        self.tris = []

    def tri(self, a, b, c, center=None):
        if center is not None:
            n = cross(sub(b, a), sub(c, a))
            mid = mul(add(add(a, b), c), 1 / 3)
            if dot(n, sub(mid, center)) < 0:
                b, c = c, b
        if length(cross(sub(b, a), sub(c, a))) > 1e-10:
            self.tris.append((a, b, c))

    def quad(self, a, b, c, d, center=None):
        self.tri(a, b, c, center)
        self.tri(a, c, d, center)

    def merge(self, other, transform=None):
        for a, b, c in other.tris:
            if transform:
                a, b, c = transform(a), transform(b), transform(c)
            self.tris.append((a, b, c))
        return self

    def transformed(self, transform):
        return Mesh().merge(self, transform)

    def bounds(self):
        xs = [p[0] for t in self.tris for p in t]
        ys = [p[1] for t in self.tris for p in t]
        zs = [p[2] for t in self.tris for p in t]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    def centered(self):
        lo, hi = self.bounds()
        c = mul(add(lo, hi), 0.5)
        return self.transformed(lambda p: sub(p, c))


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def ring(sides, radius, y, twist=0.0, jitter=0.0, rng=None, squash=1.0):
    pts = []
    for i in range(sides):
        a = twist + math.tau * i / sides
        r = radius * (1 + (rng.uniform(-jitter, jitter) if rng else 0))
        pts.append((math.cos(a) * r, y, math.sin(a) * r * squash))
    return pts


def loft(rings, cap_bottom=True, cap_top=True, top_point=None, bottom_point=None):
    """Stitch rings (same vertex count) into a closed solid."""
    m = Mesh()
    all_pts = [p for r in rings for p in r] + [p for p in (top_point, bottom_point) if p]
    center = mul(tuple(sum(c) for c in zip(*all_pts)), 1 / len(all_pts))
    for r0, r1 in zip(rings, rings[1:]):
        n = len(r0)
        # Orient each band against the axis point at its own height, so a
        # ledge far above the solid's centre still faces outward.
        band = r0 + r1
        local = mul(tuple(sum(c) for c in zip(*band)), 1 / len(band))
        for i in range(n):
            j = (i + 1) % n
            m.quad(r0[i], r0[j], r1[j], r1[i], local)
    first, last = rings[0], rings[-1]
    if bottom_point:
        for i in range(len(first)):
            m.tri(first[i], first[(i + 1) % len(first)], bottom_point, center)
    elif cap_bottom:
        c = mul(tuple(sum(v) for v in zip(*first)), 1 / len(first))
        for i in range(len(first)):
            m.tri(first[i], first[(i + 1) % len(first)], c, center)
    if top_point:
        for i in range(len(last)):
            m.tri(last[i], last[(i + 1) % len(last)], top_point, center)
    elif cap_top:
        c = mul(tuple(sum(v) for v in zip(*last)), 1 / len(last))
        for i in range(len(last)):
            m.tri(last[i], last[(i + 1) % len(last)], c, center)
    return m


def box(sx, sy, sz, bevel=0.0):
    """A box, optionally with chamfered vertical and horizontal edges."""
    if bevel <= 0:
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        corners = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]
        top = [(x, hy, z) for x, _, z in corners]
        return loft([corners, top])
    # An octagonal section (chamfered sides) lofted over chamfered top/bottom.
    def section(y, inset):
        hx, hz = sx / 2 - inset, sz / 2 - inset
        b = bevel
        return [(-hx + b, y, -hz), (hx - b, y, -hz), (hx, y, -hz + b), (hx, y, hz - b),
                (hx - b, y, hz), (-hx + b, y, hz), (-hx, y, hz - b), (-hx, y, -hz + b)]
    hy = sy / 2
    return loft([section(-hy, bevel), section(-hy + bevel, 0), section(hy - bevel, 0), section(hy, bevel)])


def icosphere(subdivisions=1):
    t = (1 + math.sqrt(5)) / 2
    verts = [norm(v) for v in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
                               (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
             (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
             (8, 6, 7), (9, 8, 1)]
    cache = {}

    def mid(i, j):
        key = (min(i, j), max(i, j))
        if key not in cache:
            verts.append(norm(mul(add(verts[i], verts[j]), 0.5)))
            cache[key] = len(verts) - 1
        return cache[key]

    for _ in range(subdivisions):
        nxt = []
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nxt += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = nxt
    return verts, faces


def rock(seed_value, subdivisions=2, roughness=0.22, flatten=0.35, stretch=(1.0, 0.72, 1.0)):
    rng = random.Random(seed_value)
    verts, faces = icosphere(subdivisions)
    bumps = [(norm((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))), rng.uniform(0.3, 1.0)) for _ in range(9)]
    shaped = []
    strata = rng.uniform(0.16, 0.24)
    for v in verts:
        d = 1.0 + sum(w * roughness * max(0.0, dot(v, b)) ** 3 for b, w in bumps) - roughness * 0.35
        d += rng.uniform(-roughness, roughness) * 0.25
        p = (v[0] * d * stretch[0], v[1] * d * stretch[1], v[2] * d * stretch[2])
        if p[1] < -flatten:
            p = (p[0], -flatten + (p[1] + flatten) * 0.15, p[2])
        # Weathered strata: heights pull toward terraces, so the rock reads as
        # layered stone rather than a lump.
        terrace = round(p[1] / strata) * strata
        p = (p[0], p[1] + (terrace - p[1]) * 0.45, p[2])
        shaped.append(p)
    m = Mesh()
    for a, b, c in faces:
        m.tri(shaped[a], shaped[b], shaped[c], (0.0, 0.0, 0.0))
    return m


def crystal(radius=0.5, height=2.2, tip=0.8, sides=6, seed_value=1, lean=0.0):
    """A natural crystal: flared root, faceted body with a slight twist, a
    chamfered shoulder and a two-stage point, every ring a little irregular."""
    rng = random.Random(seed_value)
    twist = rng.uniform(0, 1)
    turn = rng.uniform(-0.12, 0.12)
    rings = [
        ring(sides, radius * 0.8, 0.0, twist, 0.08, rng),
        ring(sides, radius * 1.02, height * 0.1, twist, 0.05, rng),
        ring(sides, radius * 0.98, height * 0.45, twist + turn * 0.5, 0.04, rng),
        ring(sides, radius * 0.95, height * 0.86, twist + turn, 0.04, rng),
        # The shoulder: a short chamfer before the point.
        ring(sides, radius * 0.82, height, twist + turn, 0.03, rng),
        ring(sides, radius * 0.38, height + tip * 0.55, twist + turn + 0.08, 0.06, rng),
    ]
    top = (rng.uniform(-0.1, 0.1) * radius, height + tip, rng.uniform(-0.1, 0.1) * radius)
    m = loft(rings, top_point=top)
    if lean:
        m = m.transformed(lambda p: rot_z(p, lean))
    return m


def bipyramid(sides=6, radius=0.5, up=1.6, down=0.7, seed_value=3):
    rng = random.Random(seed_value)
    mid = ring(sides, radius, 0.0, rng.uniform(0, 1), 0.1, rng)
    return loft([mid], cap_bottom=False, cap_top=False, top_point=(0, up, 0), bottom_point=(0, -down, 0))


def torus(major=1.0, minor=0.12, segments=28, sides=6):
    m = Mesh()
    grid = []
    for i in range(segments):
        a = math.tau * i / segments
        ca, sa = math.cos(a), math.sin(a)
        row = []
        for j in range(sides):
            b = math.tau * j / sides
            r = major + minor * math.cos(b)
            row.append((r * ca, minor * math.sin(b), r * sa))
        grid.append(row)
    for i in range(segments):
        i2 = (i + 1) % segments
        a = math.tau * (i + 0.5) / segments
        tube_center = (major * math.cos(a), 0.0, major * math.sin(a))
        for j in range(sides):
            j2 = (j + 1) % sides
            m.quad(grid[i][j], grid[i2][j], grid[i2][j2], grid[i][j2], tube_center)
    return m


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

def model_crystal():
    return crystal(0.5, 2.2, 0.85, 6, 11)


def model_crystal_shard():
    return bipyramid(6, 0.42, 1.7, 0.75, 12)


def model_basalt_cluster():
    rng = random.Random(21)
    m = Mesh()
    spots = [(0, 0, 1.0), (1.05, 0.25, 0.8), (-0.95, 0.4, 0.72), (0.2, -1.0, 0.85), (-0.3, 1.0, 0.6), (0.95, -0.85, 0.55)]
    for x, z, h in spots:
        height = 4.0 * h + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.5, 0.62)
        rings = [ring(6, r, 0.0, 0.3, 0.02, rng), ring(6, r, height, 0.3, 0.02, rng)]
        # A slanted, broken top.
        top = [(p[0], p[1] + rng.uniform(-0.25, 0.25), p[2]) for p in rings[1]]
        col = loft([rings[0], top])
        m.merge(col, lambda p, x=x, z=z: (p[0] + x, p[1], p[2] + z))
    return m


def model_void_spire():
    m = Mesh()
    parts = [(0.0, 0.0, 0.0, 1.0, 0.0), (0.55, 0.2, 0.5, 0.62, -0.32), (-0.5, -0.25, 1.9, 0.55, 0.36), (0.1, 0.55, 4.1, 0.45, 0.22)]
    for x, z, yaw, scale_value, lean in parts:
        c = crystal(0.5 * scale_value * 1.3, 5.0 * scale_value, 1.6 * scale_value, 5, int(yaw * 10) + 3, lean)
        m.merge(c, lambda p, x=x, z=z, yaw=yaw: add(rot_y(p, yaw), (x, 0, z)))
    return m


def model_obelisk():
    # Square section with chamfered corners, tapering, banded, with a pyramid cap.
    def section(y, half, chamfer):
        h, c = half, chamfer
        return [(-h + c, y, -h), (h - c, y, -h), (h, y, -h + c), (h, y, h - c), (h - c, y, h), (-h + c, y, h), (-h, y, h - c), (-h, y, -h + c)]

    levels = [(0.0, 0.62), (0.35, 0.62), (0.42, 0.55), (3.6, 0.48), (3.7, 0.54), (3.85, 0.54), (3.95, 0.47), (6.2, 0.4), (6.3, 0.46), (6.45, 0.46)]
    rings = [section(y, half, half * 0.28) for y, half in levels]
    return loft(rings, top_point=(0.0, 7.5, 0.0))


def model_plinth():
    rings = []
    for y0, y1, r in ((0.0, 0.5, 3.3), (0.5, 0.95, 2.6), (0.95, 1.35, 1.9)):
        rings.append(ring(8, r, y0, math.pi / 8))
        rings.append(ring(8, r, y1, math.pi / 8))
    m = Mesh()
    for i in range(0, len(rings), 2):
        m.merge(loft([rings[i], rings[i + 1]]))
    return m


def model_lantern():
    m = Mesh()
    m.merge(box(0.9, 0.3, 0.9, 0.08), lambda p: add(p, (0, 0.15, 0)))
    m.merge(loft([ring(8, 0.14, 0.3, 0.2), ring(8, 0.1, 5.2, 0.2)]))
    # Cage: four bars and a roof.
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        x, z = math.cos(a) * 0.42, math.sin(a) * 0.42
        m.merge(box(0.07, 1.25, 0.07), lambda p, x=x, z=z: add(p, (x, 5.85, z)))
    m.merge(box(1.0, 0.1, 1.0, 0.03), lambda p: add(p, (0, 5.2, 0)))
    m.merge(loft([ring(4, 0.78, 6.45, math.pi / 4), ring(4, 0.5, 6.6, math.pi / 4)], top_point=(0, 7.1, 0)))
    return m


def model_arena_pillar():
    m = Mesh()
    m.merge(box(3.2, 1.2, 3.2, 0.2), lambda p: add(p, (0, 0.6, 0)))
    sides = 16
    fluted = []
    for y in (1.2, 22.8):
        fluted.append([(math.cos(math.tau * i / sides) * (1.35 if i % 2 == 0 else 1.18), y, math.sin(math.tau * i / sides) * (1.35 if i % 2 == 0 else 1.18)) for i in range(sides)])
    m.merge(loft(fluted))
    m.merge(loft([ring(8, 1.6, 22.8, math.pi / 8), ring(8, 2.1, 23.9, math.pi / 8), ring(8, 2.1, 24.6, math.pi / 8), ring(8, 1.7, 25.0, math.pi / 8)]))
    return m


def model_star():
    verts = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    faces = [(0, 2, 4), (4, 2, 1), (1, 2, 5), (5, 2, 0), (0, 4, 3), (4, 1, 3), (1, 5, 3), (5, 0, 3)]
    m = Mesh()
    for a, b, c in faces:
        pa, pb, pc = verts[a], verts[b], verts[c]
        n = norm(cross(sub(pb, pa), sub(pc, pa)))
        center = mul(add(add(pa, pb), pc), 1 / 3)
        apex = add(center, mul(n, 0.9))
        # A spike on every face: the stellated octahedron.
        for p, q in ((pa, pb), (pb, pc), (pc, pa)):
            m.tri(p, q, apex, (0, 0, 0))
    return m


def model_warden_core():
    verts, faces = icosphere(1)
    m = Mesh()
    for a, b, c in faces:
        m.tri(verts[a], verts[b], verts[c], (0, 0, 0))
    return m


def model_warden_plate():
    # A curved armour plate: a patch of a sphere shell, pointed top and bottom.
    m = Mesh()
    cols, rows = 7, 9
    outer, inner = 3.0, 2.72

    def point(r, u, v):
        # u across (-1..1), v down the plate (-1..1); width narrows to points.
        width = 0.55 * (1 - v * v) ** 0.6
        theta = u * width
        phi = v * 0.75
        return (r * math.sin(theta) * math.cos(phi), r * math.sin(phi), r * math.cos(theta) * math.cos(phi))

    grid_o = [[point(outer, -1 + 2 * i / (cols - 1), -1 + 2 * j / (rows - 1)) for i in range(cols)] for j in range(rows)]
    grid_i = [[point(inner, -1 + 2 * i / (cols - 1), -1 + 2 * j / (rows - 1)) for i in range(cols)] for j in range(rows)]

    def facing(a, b, c, outward: bool):
        # Outer shell faces away from the sphere centre, inner shell toward it.
        n = cross(sub(b, a), sub(c, a))
        mid = mul(add(add(a, b), c), 1 / 3)
        if (dot(n, mid) < 0) == outward:
            b, c = c, b
        m.tri(a, b, c)

    for j in range(rows - 1):
        for i in range(cols - 1):
            for grid, outward in ((grid_o, True), (grid_i, False)):
                a, b, c, d = grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]
                facing(a, b, c, outward)
                facing(a, c, d, outward)
    # Rims joining the two shells.
    edge = []
    for i in range(cols):
        edge.append((0, i))
    for j in range(1, rows):
        edge.append((j, cols - 1))
    for i in range(cols - 2, -1, -1):
        edge.append((rows - 1, i))
    for j in range(rows - 2, 0, -1):
        edge.append((j, 0))
    mid_center = point((outer + inner) / 2, 0, 0)
    for k in range(len(edge)):
        j0, i0 = edge[k]
        j1, i1 = edge[(k + 1) % len(edge)]
        o0, o1 = grid_o[j0][i0], grid_o[j1][i1]
        n0, n1 = grid_i[j0][i0], grid_i[j1][i1]
        m.quad(o0, o1, n1, n0, mid_center)
    return m


def model_warden_blade():
    m = bipyramid(5, 0.45, 4.2, 0.9, 7)
    return m.transformed(lambda p: rot_z(p, 0.06 * p[1]))


def model_halo():
    return torus(1.0, 0.07, 36, 6)


def model_bridge_deck():
    return box(1.0, 1.0, 1.0, 0.08)


MODELS = {
    "Crystal": model_crystal,
    "CrystalShard": model_crystal_shard,
    "RockA": lambda: rock(101),
    "RockB": lambda: rock(202, roughness=0.28, stretch=(1.15, 0.65, 0.9)),
    "RockC": lambda: rock(303, roughness=0.18, flatten=0.5, stretch=(1.0, 0.9, 1.1)),
    "BasaltCluster": model_basalt_cluster,
    "VoidSpire": model_void_spire,
    "Obelisk": model_obelisk,
    "Plinth": model_plinth,
    "Lantern": model_lantern,
    "ArenaPillar": model_arena_pillar,
    "Star": model_star,
    "WardenCore": model_warden_core,
    "WardenPlate": model_warden_plate,
    "WardenBlade": model_warden_blade,
    "Halo": model_halo,
    "BridgeDeck": model_bridge_deck,
}


# ---------------------------------------------------------------------------
# Binary glTF
# ---------------------------------------------------------------------------

def write_glb(path, named_meshes):
    """Write meshes as nodes of one .glb. Returns {name: (sx, sy, sz)}."""
    buffer = bytearray()
    views, accessors, meshes, nodes = [], [], [], []
    sizes = {}

    def pad4():
        while len(buffer) % 4:
            buffer.append(0)

    for index, (name, mesh) in enumerate(named_meshes):
        mesh = mesh.centered()
        lo, hi = mesh.bounds()
        sizes[name] = tuple(round(h - l, 4) for l, h in zip(lo, hi))
        positions, normals = [], []
        for a, b, c in mesh.tris:
            n = norm(cross(sub(b, a), sub(c, a)))
            for p in (a, b, c):
                positions.append(p)
                normals.append(n)
        count = len(positions)
        # POSITION
        pad4()
        pos_offset = len(buffer)
        for p in positions:
            buffer += struct.pack("<3f", *p)
        views.append({"buffer": 0, "byteOffset": pos_offset, "byteLength": count * 12, "target": 34962})
        accessors.append({"bufferView": len(views) - 1, "componentType": 5126, "count": count, "type": "VEC3",
                          "min": list(lo), "max": list(hi)})
        pos_accessor = len(accessors) - 1
        # NORMAL
        pad4()
        nrm_offset = len(buffer)
        for nrm in normals:
            buffer += struct.pack("<3f", *nrm)
        views.append({"buffer": 0, "byteOffset": nrm_offset, "byteLength": count * 12, "target": 34962})
        accessors.append({"bufferView": len(views) - 1, "componentType": 5126, "count": count, "type": "VEC3"})
        nrm_accessor = len(accessors) - 1
        # Indices (flat shading: every triangle has its own three vertices).
        pad4()
        idx_offset = len(buffer)
        wide = count > 65535
        for i in range(count):
            buffer += struct.pack("<I" if wide else "<H", i)
        views.append({"buffer": 0, "byteOffset": idx_offset, "byteLength": count * (4 if wide else 2), "target": 34963})
        accessors.append({"bufferView": len(views) - 1, "componentType": 5125 if wide else 5123, "count": count, "type": "SCALAR"})
        idx_accessor = len(accessors) - 1
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": pos_accessor, "NORMAL": nrm_accessor}, "indices": idx_accessor, "material": 0}]})
        # Lay the models out in a row so the imported file reads cleanly.
        nodes.append({"name": name, "mesh": index, "translation": [index * 8.0, 0.0, 0.0]})

    pad4()
    doc = {
        "asset": {"version": "2.0", "generator": "Astral Forge assetgen"},
        "scene": 0,
        "scenes": [{"name": "AstralForgeKit", "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [{"name": "Kit", "pbrMetallicRoughness": {"baseColorFactor": [0.8, 0.8, 0.85, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.7}}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(buffer)}],
    }
    json_bytes = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4:
        json_bytes += b" "
    total = 12 + 8 + len(json_bytes) + 8 + len(buffer)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
        f.write(json_bytes)
        f.write(struct.pack("<I4s", len(buffer), b"BIN\x00"))
        f.write(bytes(buffer))
    return sizes


def triangle_counts():
    return {name: len(build().tris) for name, build in MODELS.items()}
