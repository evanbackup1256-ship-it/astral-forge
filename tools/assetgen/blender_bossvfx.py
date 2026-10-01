"""Build the bosses' signature VFX meshes in Blender (headless) and export them as one GLB.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python tools/assetgen/blender_bossvfx.py

Six bosses, three meshes each, every shape unique to its boss:

  Warden  W_RiftTear (jagged portal ring)   W_VoidClaw (three hooked claws)   W_SealGlyph (hexagram seal)
  Choir   C_NoteRing (ring of seven notes)  C_TuningSpear (forked glass spear) C_ResonanceSpiral (spiral ribbon)
  Regent  R_FlameCrown (ring of flames)     R_EmberSpike (hooked horn)         R_FireSpiral (flame vortex)
  Seraph  S_FeatherBlade (storm feather)    S_HaloSpikes (sunburst halo)       S_BoltZig (lightning bolt)
  Rime    I_CrystalCluster (ice crystals)   I_Snowflake (six-armed flake)      I_SpikeFan (fan of ice spikes)
  Knight  K_Crescent (slash crescent)       K_SwordRain (falling sword)        K_RuneRing (broken rune ring)

Output: assets/generated/BossVfxKit.glb  (upload with upload_boss_vfx.py).
Each mesh is centred on its origin and about 10 units across; the game scales and tints them.
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "BossVfxKit.glb")
TAU = math.tau
rng = random.Random(2026)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_object(name, bm):
    """Finish a bmesh into a scene object: centred, normalised to ~10 units, flat shaded."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    lo = Vector((min(v.co.x for v in mesh.vertices), min(v.co.y for v in mesh.vertices), min(v.co.z for v in mesh.vertices)))
    hi = Vector((max(v.co.x for v in mesh.vertices), max(v.co.y for v in mesh.vertices), max(v.co.z for v in mesh.vertices)))
    centre = (lo + hi) / 2
    largest = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, 1e-6)
    for v in mesh.vertices:
        v.co = (v.co - centre) * (10.0 / largest)
    for poly in mesh.polygons:
        poly.use_smooth = False
    return obj


def new_bm():
    return bmesh.new()


def add_quad_strip(bm, loop_a, loop_b, close=True):
    """Join two vertex loops of equal length with quads."""
    n = len(loop_a)
    top = n if close else n - 1
    for i in range(top):
        j = (i + 1) % n
        try:
            bm.faces.new((loop_a[i], loop_a[j], loop_b[j], loop_b[i]))
        except ValueError:
            pass


def cap(bm, loop, flip=False):
    try:
        bm.faces.new(list(reversed(loop)) if flip else loop)
    except ValueError:
        pass


def ring_mesh(radius_fn, thickness_fn, height, segments):
    """A flat ring: outer radius radius_fn(a), inner radius radius_fn(a) - thickness_fn(a)."""
    bm = new_bm()
    loops = {k: [] for k in ("ot", "it", "ob", "ib")}
    for i in range(segments):
        a = i / segments * TAU
        ro = radius_fn(a)
        ri = max(0.05, ro - thickness_fn(a))
        c, s = math.cos(a), math.sin(a)
        loops["ot"].append(bm.verts.new((c * ro, s * ro, height / 2)))
        loops["it"].append(bm.verts.new((c * ri, s * ri, height / 2)))
        loops["ob"].append(bm.verts.new((c * ro, s * ro, -height / 2)))
        loops["ib"].append(bm.verts.new((c * ri, s * ri, -height / 2)))
    add_quad_strip(bm, loops["ot"], loops["it"])
    add_quad_strip(bm, loops["ib"], loops["ob"])
    add_quad_strip(bm, loops["ob"], loops["ot"])
    add_quad_strip(bm, loops["it"], loops["ib"])
    return bm


def extrude_polygon(points, thickness):
    """A flat 2D outline (any simple polygon, even concave) pushed out into a slab."""
    bm = new_bm()
    top = [bm.verts.new((x, y, thickness / 2)) for x, y in points]
    bottom = [bm.verts.new((x, y, -thickness / 2)) for x, y in points]
    face_top = bm.faces.new(top)
    face_bottom = bm.faces.new(list(reversed(bottom)))
    add_quad_strip(bm, bottom, top)
    bmesh.ops.triangulate(bm, faces=[face_top, face_bottom], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    return bm


def ribbon(outer_points, inner_points, thickness):
    """A flat curved band between two matching point lists (safe for spirals and crescents)."""
    bm = new_bm()
    ot = [bm.verts.new((x, y, thickness / 2)) for x, y in outer_points]
    it = [bm.verts.new((x, y, thickness / 2)) for x, y in inner_points]
    ob = [bm.verts.new((x, y, -thickness / 2)) for x, y in outer_points]
    ib = [bm.verts.new((x, y, -thickness / 2)) for x, y in inner_points]
    add_quad_strip(bm, ot, it, close=False)
    add_quad_strip(bm, ib, ob, close=False)
    add_quad_strip(bm, ob, ot, close=False)
    add_quad_strip(bm, it, ib, close=False)
    for a, b, c, d in ((ot[0], it[0], ib[0], ob[0]), (it[-1], ot[-1], ob[-1], ib[-1])):
        try:
            bm.faces.new((a, b, c, d))
        except ValueError:
            pass
    return bm


def tube(path, radii, sides=6, closed_tip=True):
    """A tube swept along `path` (list of Vector) with a radius per point."""
    bm = new_bm()
    loops = []
    for index, (point, radius) in enumerate(zip(path, radii)):
        if index < len(path) - 1:
            tangent = (path[index + 1] - point).normalized()
        else:
            tangent = (point - path[index - 1]).normalized()
        helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
        side = tangent.cross(helper).normalized()
        up = side.cross(tangent).normalized()
        loop = []
        for k in range(sides):
            a = k / sides * TAU
            loop.append(bm.verts.new(point + side * math.cos(a) * radius + up * math.sin(a) * radius))
        loops.append(loop)
    for a, b in zip(loops, loops[1:]):
        add_quad_strip(bm, a, b)
    cap(bm, loops[0])
    if closed_tip:
        tip = bm.verts.new(path[-1] + (path[-1] - path[-2]).normalized() * radii[-1] * 0.5)
        for k in range(sides):
            try:
                bm.faces.new((loops[-1][k], loops[-1][(k + 1) % sides], tip))
            except ValueError:
                pass
    else:
        cap(bm, loops[-1], flip=True)
    return bm


def merge(*bms):
    out = new_bm()
    for source in bms:
        mapping = {}
        for v in source.verts:
            mapping[v] = out.verts.new(v.co)
        for f in source.faces:
            try:
                out.faces.new([mapping[v] for v in f.verts])
            except ValueError:
                pass
        source.free()
    return out


def transform(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def pointed_prism(sides, radius, length, tip_length):
    """A crystal: a prism with a pointed top, base at z = 0."""
    bm = new_bm()
    base = [bm.verts.new((math.cos(k / sides * TAU) * radius, math.sin(k / sides * TAU) * radius, 0)) for k in range(sides)]
    mid = [bm.verts.new((math.cos(k / sides * TAU) * radius, math.sin(k / sides * TAU) * radius, length)) for k in range(sides)]
    tip = bm.verts.new((0, 0, length + tip_length))
    add_quad_strip(bm, base, mid)
    cap(bm, base, flip=True)
    for k in range(sides):
        bm.faces.new((mid[k], mid[(k + 1) % sides], tip))
    return bm


def bezier(p0, p1, p2, t):
    return p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t**2


# --- Warden ------------------------------------------------------------------------------------

def rift_tear():
    phases = [rng.uniform(0, TAU) for _ in range(5)]

    def radius(a):
        wobble = sum(math.sin(a * (k + 3) + phases[k]) * (0.28 / (k + 1)) for k in range(5))
        spike = 0.35 * max(0, math.sin(a * 7 + 1.3)) ** 3
        return 5 + wobble * 5 + spike * 5

    return ring_mesh(radius, lambda a: 0.7 + 0.5 * abs(math.sin(a * 5)), 0.35, 96)


def void_claw():
    claws = []
    for index in range(3):
        a = index / 3 * TAU
        path = []
        for step in range(9):
            t = step / 8
            reach = 1.0 + t * 4.4
            hook = t**2 * 2.2
            path.append(Vector((math.cos(a) * reach - math.sin(a) * hook, math.sin(a) * reach + math.cos(a) * hook, math.sin(t * math.pi) * 0.6)))
        radii = [0.75 * (1 - t / 8) + 0.05 for t in range(9)]
        claws.append(tube(path, radii, 5))
    return merge(*claws)


def seal_glyph():
    parts = [ring_mesh(lambda a: 5.0, lambda a: 0.35, 0.2, 64), ring_mesh(lambda a: 3.7, lambda a: 0.25, 0.2, 48)]
    for turn in (0, math.pi / 6):
        tri = [(math.cos(turn + k * TAU / 3) * 5.0, math.sin(turn + k * TAU / 3) * 5.0) for k in range(3)]
        for k in range(3):
            a, b = Vector(tri[k]), Vector(tri[(k + 1) % 3])
            along = (b - a)
            normal = Vector((-along.y, along.x)).normalized() * 0.18
            parts.append(extrude_polygon([a - normal, b - normal, b + normal, a + normal], 0.2))
    return merge(*parts)


# --- Choir -------------------------------------------------------------------------------------

def note_ring():
    notes = 7

    def radius(a):
        k = (a / TAU * notes) % 1.0
        return 5 + 1.1 * math.exp(-((k - 0.5) ** 2) * 60)

    ring = ring_mesh(radius, lambda a: 0.5, 0.25, 140)
    bulbs = []
    for k in range(notes):
        a = (k + 0.5) / notes * TAU
        bulb = pointed_prism(6, 0.55, 0.3, 0.9)
        transform(bulb, Matrix.Translation((math.cos(a) * 6.5, math.sin(a) * 6.5, 0)) @ Matrix.Rotation(a - math.pi / 2, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"))
        bulbs.append(bulb)
    return merge(ring, *bulbs)


def tuning_spear():
    shaft = tube([Vector((0, 0, z)) for z in (-5, -2.5, 0, 1.0)], [0.35, 0.4, 0.45, 0.5], 6, closed_tip=False)
    prongs = []
    for side in (-1, 1):
        path = [Vector((side * x, 0, z)) for x, z in ((0.0, 1.0), (0.5, 2.2), (0.8, 3.8), (0.5, 5.6))]
        prongs.append(tube(path, [0.4, 0.34, 0.3, 0.22], 6))
    bridge = tube([Vector((-0.5, 0, 1.0)), Vector((0.5, 0, 1.0))], [0.35, 0.35], 6, closed_tip=False)
    return merge(shaft, bridge, *prongs)


def resonance_spiral():
    outer, inner = [], []
    turns, steps = 2.4, 110
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * TAU
        r = 0.8 + t * 4.2
        width = 0.1 + 0.3 * math.sin(t * math.pi)
        outer.append((math.cos(a) * (r + width), math.sin(a) * (r + width)))
        inner.append((math.cos(a) * (r - width), math.sin(a) * (r - width)))
    return ribbon(outer, inner, 0.2)


# --- Regent ------------------------------------------------------------------------------------

def flame_spike(height, lean, width):
    path = [Vector((lean * t * t * height * 0.35, math.sin(t * 3 + lean) * 0.25 * t, t * height)) for t in [i / 7 for i in range(8)]]
    radii = [width * (1 - t / 7) ** 0.8 + 0.04 for t in range(8)]
    return tube(path, radii, 5)


def flame_crown():
    spikes = [ring_mesh(lambda a: 4.4, lambda a: 0.9, 0.5, 48)]
    count = 9
    for k in range(count):
        a = k / count * TAU
        spike = flame_spike(4.0 + 1.6 * (k % 3) / 2, 0.8 if k % 2 else -0.8, 0.7)
        transform(spike, Matrix.Translation((math.cos(a) * 4.0, math.sin(a) * 4.0, 0.2)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.radians(12), 4, "Y"))
        spikes.append(spike)
    return merge(*spikes)


def ember_spike():
    path = []
    for i in range(11):
        t = i / 10
        path.append(Vector((t * 1.5, 0, t * 7.0)) + Vector((math.sin(t * math.pi) * 1.6, 0, 0)) + Vector((t**3 * 2.4, 0, 0)))
    radii = [1.1 * (1 - i / 10) ** 0.9 + 0.05 for i in range(11)]
    return tube(path, radii, 6)


def fire_spiral():
    tongues = []
    for k in range(3):
        base = k / 3 * TAU
        path = []
        for i in range(14):
            t = i / 13
            a = base + t * TAU * 1.5
            r = 3.4 * (1 - t * 0.55)
            path.append(Vector((math.cos(a) * r, math.sin(a) * r, t * 9)))
        radii = [0.8 * (1 - i / 13) ** 0.7 + 0.04 for i in range(14)]
        tongues.append(tube(path, radii, 5))
    return merge(*tongues)


# --- Seraph ------------------------------------------------------------------------------------

def feather_blade():
    outline = []
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        width = math.sin(t * math.pi) ** 0.8 * 1.5 * (1 - 0.35 * t)
        outline.append((t * 10 - 5, width + 0.06 * math.sin(t * 30)))
    for i in range(steps, -1, -1):
        t = i / steps
        width = math.sin(t * math.pi) ** 0.8 * 1.5 * (1 - 0.35 * t)
        outline.append((t * 10 - 5, -width - 0.06 * math.sin(t * 30)))
    blade = extrude_polygon(outline[:-1], 0.18)
    spine = tube([Vector((x, 0, 0.0)) for x in (-5, -2, 1, 4, 5.4)], [0.18, 0.2, 0.18, 0.12, 0.06], 5)
    bend = Matrix.Translation((0, 0, 0))
    for v in blade.verts:
        v.co.z += (v.co.x / 5) ** 2 * 0.8
    for v in spine.verts:
        v.co.z += (v.co.x / 5) ** 2 * 0.8
    return merge(blade, spine)


def halo_spikes():
    parts = [ring_mesh(lambda a: 4.0, lambda a: 0.5, 0.3, 80)]
    count = 16
    for k in range(count):
        a = k / count * TAU
        long = k % 2 == 0
        length = 5.0 if long else 2.6
        spike = pointed_prism(4, 0.34 if long else 0.26, length * 0.35, length * 0.65)
        transform(spike, Matrix.Translation((math.cos(a) * 4.1, math.sin(a) * 4.1, 0)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"))
        parts.append(spike)
    return merge(*parts)


def bolt_zig():
    points = [Vector((0, 0, 5))]
    for i in range(1, 9):
        points.append(Vector((rng.uniform(-1.2, 1.2) * (1 - i / 12), rng.uniform(-0.8, 0.8), 5 - i * 1.25)))
    radii = [0.35 + 0.25 * math.sin(i / 8 * math.pi) for i in range(9)]
    segments = []
    for i in range(8):
        segments.append(tube([points[i], points[i + 1]], [radii[i], radii[i + 1]], 4, closed_tip=False))
    forks = []
    for at in (2, 5):
        origin = points[at]
        end = origin + Vector((rng.choice((-1, 1)) * 2.4, rng.uniform(-0.6, 0.6), -2.2))
        forks.append(tube([origin, (origin + end) / 2 + Vector((0.3, 0, 0)), end], [0.22, 0.16, 0.06], 4))
    return merge(*segments, *forks)


# --- Rime --------------------------------------------------------------------------------------

def crystal_cluster():
    parts = []
    seeds = [(0, 0, 0, 0.9, 7.0, 0), (1.3, 0.4, 0.3, 0.6, 4.6, 0.35), (-1.2, 0.5, -0.2, 0.55, 4.0, -0.4), (0.4, -1.2, 0.2, 0.5, 3.6, 0.5), (-0.5, -1.0, -0.1, 0.45, 3.2, -0.55), (1.0, -0.9, 0.0, 0.4, 2.6, 0.7), (-1.5, -0.2, 0.0, 0.38, 2.2, -0.8)]
    for x, y, _z, radius, length, tilt in seeds:
        crystal = pointed_prism(6, radius, length * 0.7, length * 0.3)
        transform(crystal, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Rotation(tilt * 0.6, 4, "X"))
        parts.append(crystal)
    return merge(*parts)


def snowflake():
    parts = [ring_mesh(lambda a: 0.9, lambda a: 0.9, 0.2, 6)]
    for arm in range(6):
        a = arm / 6 * TAU
        direction = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-direction.y, direction.x, 0))
        pieces = [extrude_polygon([(0, -0.28), (5, -0.16), (5.4, 0), (5, 0.16), (0, 0.28)], 0.22)]
        for at, length in ((2.0, 1.8), (3.3, 1.3)):
            for sign in (-1, 1):
                pieces.append(extrude_polygon([(at, 0), (at + length * 0.7, sign * length), (at + length * 0.7 + 0.25, sign * length), (at + 0.3, 0)], 0.2))
        for piece in pieces:
            transform(piece, Matrix.Rotation(a, 4, "Z"))
            parts.append(piece)
    return merge(*parts)


def spike_fan():
    parts = []
    count = 7
    for k in range(count):
        t = k / (count - 1)
        a = math.radians(-65 + 130 * t)
        length = 4.0 + 3.6 * math.sin(t * math.pi)
        spike = pointed_prism(4, 0.5, length * 0.4, length * 0.6)
        transform(spike, Matrix.Rotation(a, 4, "Y") @ Matrix.Translation((0, 0, 0.2)))
        parts.append(spike)
    return merge(*parts)


# --- Knight ------------------------------------------------------------------------------------

def crescent():
    outer, inner = [], []
    steps = 30
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(-105 + 210 * t)
        outer.append((math.cos(a) * 5, math.sin(a) * 5))
        r = 5 - 2.4 * math.sin(t * math.pi) ** 0.9
        inner.append((math.cos(a) * r, math.sin(a) * r))
    return ribbon(outer, inner, 0.22)

def sword_rain():
    blade = extrude_polygon([(-0.55, 0), (-0.45, 6.4), (0, 7.4), (0.45, 6.4), (0.55, 0)], 0.22)
    ridge = extrude_polygon([(-0.08, 0.2), (-0.05, 6.5), (0, 7.0), (0.05, 6.5), (0.08, 0.2)], 0.4)
    guard = extrude_polygon([(-1.7, -0.4), (-1.9, -0.05), (-1.7, 0.3), (1.7, 0.3), (1.9, -0.05), (1.7, -0.4)], 0.35)
    grip = tube([Vector((0, 0, -0.4)), Vector((0, 0, -2.3))], [0.22, 0.22], 6, closed_tip=False)
    pommel = pointed_prism(6, 0.4, 0.2, 0.3)
    transform(pommel, Matrix.Translation((0, 0, -2.8)) @ Matrix.Rotation(math.pi, 4, "X"))
    return merge(blade, ridge, guard, grip, pommel)


def rune_ring():
    gaps = [(0.2, 0.55), (1.6, 1.95), (3.0, 3.4), (4.4, 4.7)]
    ring_parts = []
    boundaries = [0] + [edge for gap in gaps for edge in gap] + [TAU]
    for start, end in zip(boundaries[0::2], boundaries[1::2]):
        points = []
        steps = max(4, int((end - start) * 12))
        for i in range(steps + 1):
            a = start + (end - start) * i / steps
            points.append((math.cos(a) * 5.0, math.sin(a) * 5.0))
        for i in range(steps, -1, -1):
            a = start + (end - start) * i / steps
            points.append((math.cos(a) * 4.1, math.sin(a) * 4.1))
        ring_parts.append(extrude_polygon(points, 0.22))
    for k, (start, end) in enumerate(gaps):
        a = (start + end) / 2
        mark = extrude_polygon([(-0.12, -0.9), (0.12, -0.9), (0.12, 0.9), (-0.12, 0.9)], 0.22)
        diagonal = extrude_polygon([(-0.12, -0.4), (0.12, -0.4), (0.6, 0.6), (0.36, 0.6)], 0.22)
        for piece in (mark, diagonal):
            transform(piece, Matrix.Translation((math.cos(a) * 3.0, math.sin(a) * 3.0, 0)) @ Matrix.Rotation(a, 4, "Z"))
            ring_parts.append(piece)
    return merge(*ring_parts)


BUILDERS = [
    ("W_RiftTear", rift_tear), ("W_VoidClaw", void_claw), ("W_SealGlyph", seal_glyph),
    ("C_NoteRing", note_ring), ("C_TuningSpear", tuning_spear), ("C_ResonanceSpiral", resonance_spiral),
    ("R_FlameCrown", flame_crown), ("R_EmberSpike", ember_spike), ("R_FireSpiral", fire_spiral),
    ("S_FeatherBlade", feather_blade), ("S_HaloSpikes", halo_spikes), ("S_BoltZig", bolt_zig),
    ("I_CrystalCluster", crystal_cluster), ("I_Snowflake", snowflake), ("I_SpikeFan", spike_fan),
    ("K_Crescent", crescent), ("K_SwordRain", sword_rain), ("K_RuneRing", rune_ring),
]


def main():
    clear_scene()
    for name, build in BUILDERS:
        obj = make_object(name, build())
        print(f"{name}: {len(obj.data.vertices)} verts, {len(obj.data.polygons)} faces")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True, export_materials="NONE" if False else "EXPORT")
    print("wrote", OUT, os.path.getsize(OUT), "bytes")


main()
