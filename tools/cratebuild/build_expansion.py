"""Build the eleven expansion crates (Cinder ... Halo) headless and export CrateKitExpansion.glb.

    blender -b --python tools/cratebuild/build_expansion.py
    env FAST=1          no bake: quick Workbench previews only
    env SKINS=Cinder,Halo   only those crates (previews only; the export needs all eleven)

Shares the modelling, material and bake helpers in tools/casinobuild/build_casino.py, and keeps the
first crate kit's conventions: studs, +Z up, the front faces -Y, and every crate is two meshes,
Crate_<Skin>_Body and Crate_<Skin>_Lid. The game stacks the lid on the body by their bounding boxes
and hinges it along its back edge, so nothing on a lid may hang below the lid's base plane.

Output, in assets/generated/crates/:
  CrateKitExpansion.glb          the 22 meshes, each with its own baked texture
  Crate_<Skin>_<Part>.png        the baked textures
  previews/expansion_<Skin>.png  body + lid together, and expansion_sheet.png with all of them
"""

import faulthandler
import json
import math
import os

if os.environ.get("HANG_TRACE"):
    # diagnose a stalled headless run: dump every thread's Python stack periodically
    _trace = open(os.environ["HANG_TRACE"], "w", encoding="utf-8")
    faulthandler.dump_traceback_later(30, repeat=True, file=_trace)

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "crates")
PREVIEWS = os.path.join(OUT, "previews")
os.makedirs(PREVIEWS, exist_ok=True)
FAST = os.environ.get("FAST") == "1"
ONLY = {s.strip() for s in os.environ.get("SKINS", "").split(",") if s.strip()}
TEX = int(os.environ.get("TEX", "1024"))
# CPU=1 skips the GPU (OptiX and the Workbench previews can stall while Roblox holds the GPU);
# NOPREVIEW=1 skips the preview renders; THREADS caps Cycles so the machine stays usable
FORCE_CPU = os.environ.get("CPU") == "1"
NOPREVIEW = os.environ.get("NOPREVIEW") == "1"
THREADS = int(os.environ.get("THREADS", "0"))

# the shared helpers (everything in build_casino.py except its main() call)
LIBRARY = os.path.join(ROOT, "tools", "casinobuild", "build_casino.py")
with open(LIBRARY, encoding="utf-8") as handle:
    source = handle.read().rsplit("\nmain()", 1)[0]


def gpu_ready():
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        found = False
        for device in prefs.devices:
            device.use = device.type == "OPTIX"
            found = found or device.use
        return found
    except Exception:
        return False


GPU = not FAST and not FORCE_CPU and gpu_ready()
if GPU:
    source = source.replace('scene.cycles.device = "CPU"', 'scene.cycles.device = "GPU"')
lib = {"__file__": LIBRARY, "__name__": "crate_expansion"}
exec(source, lib)
lib["OUT"] = OUT
lib["PREVIEWS"] = PREVIEWS
lib["SAMPLES"] = int(os.environ.get("SAMPLES", "32"))

srgb, material = lib["srgb"], lib["material"]
new_object, tag, lathe, orient = lib["new_object"], lib["tag"], lib["lathe"], lib["orient"]
add, ico, uvsphere, torus, prism = lib["add_mesh_from"], lib["ico"], lib["uvsphere"], lib["torus"], lib["prism"]
modifiers, apply_modifiers, box_bm = lib["modifiers"], lib["apply_modifiers"], lib["box_bm"]
rot, at, triangles, unwrap, bake = lib["rot"], lib["at"], lib["triangles"], lib["unwrap"], lib["bake"]
GOLD, BRASS, BRASS_DEEP = lib["GOLD"], lib["BRASS"], lib["BRASS_DEEP"]
TAU = math.tau


# ------------------------------------------------------------------------------------------------
# small modelling vocabulary on top of the library
# ------------------------------------------------------------------------------------------------

def scale(sx, sy, sz):
    return Matrix.Diagonal((sx, sy, sz, 1.0))


def box(bm, sx, sy, sz, mat, center, matrix=None):
    piece = box_bm(sx, sy, sz, mat, (0, 0, 0))
    m = at(*center) if matrix is None else at(*center) @ matrix
    return add(bm, piece, m)


def turned(bm, profile, segments, mat, matrix=None, smooth=True):
    """A lathed solid around Z from (radius, z) points, appended to bm. Profiles that start and end on
    the axis close into a solid; its normals are recomputed outward so lid undersides are not culled
    when the game swings a lid open (the library's orient() points every flat face up)."""
    temp = bmesh.new()
    lathe(temp, profile, segments, mat=mat, smooth=smooth)
    bmesh.ops.remove_doubles(temp, verts=temp.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(temp, faces=temp.faces)
    return add(bm, temp, matrix)


def disc(bm, radius, depth, segments, mat, matrix):
    """A flat cylinder along Z (0..depth), placed by matrix."""
    return turned(bm, [(0, 0), (radius, 0), (radius, depth), (0, depth)], segments, mat, matrix, smooth=False)


def ring(bm, major, minor, mat, matrix, segs=48, sides=10, squash=1.0):
    return add(bm, torus(major, minor, segs, sides, mat=mat, squash=squash), matrix)


def arc_tube(bm, radius, thickness, a0, a1, mat, matrix, segs=24, sides=8):
    """Part of a torus in the XZ plane: angle 0 is +X, 90 is +Z."""
    temp = bmesh.new()
    rings = []
    for i in range(segs + 1):
        a = math.radians(a0 + (a1 - a0) * i / segs)
        centre = Vector((math.cos(a) * radius, 0, math.sin(a) * radius))
        out = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((0, 1, 0))
        rings.append([temp.verts.new(centre + out * math.cos(TAU * j / sides) * thickness + side * math.sin(TAU * j / sides) * thickness) for j in range(sides)])
    for i in range(segs):
        for j in range(sides):
            temp.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % sides], rings[i][(j + 1) % sides]))
    for end in (rings[0], list(reversed(rings[-1]))):
        temp.faces.new(end)
    bmesh.ops.recalc_face_normals(temp, faces=temp.faces)
    tag(temp.faces, mat, True)
    return add(bm, temp, matrix)


def spike(bm, radius, length, mat, matrix, sides=4, tip=None):
    return add(bm, prism(radius, length, sides, tip=tip if tip is not None else length * 0.45, mat=mat), matrix)


def twist(bm, verts, degrees, z0, z1):
    """Rotate verts about Z by an amount that grows from 0 at z0 to `degrees` at z1."""
    for v in verts:
        t = min(1.0, max(0.0, (v.co.z - z0) / max(1e-6, z1 - z0)))
        a = math.radians(degrees * t)
        x, y = v.co.x, v.co.y
        v.co.x = x * math.cos(a) - y * math.sin(a)
        v.co.y = x * math.sin(a) + y * math.cos(a)


def finish(name, bm, mats, bevel=0.012):
    obj = new_object(name, bm, mats, smooth=None)
    modifiers(obj, bevel=bevel, bevel_segments=2, angle=40)
    return obj


def palette(base, trim, glow, extra):
    """Material slots shared by a crate's body and lid: 0 base, 1 trim, 2 glow, 3 accent."""
    return [material(*base[0], **base[1]), material(*trim[0], **trim[1]),
            material(*glow[0], **glow[1]), material(*extra[0], **extra[1])]


def m(name, color, **kw):
    return ((name, color), kw)


def glow(name, color, strength=1.2):
    return m(name, color, emit=color, emit_strength=strength, rough=0.3)


# ------------------------------------------------------------------------------------------------
# the eleven crates. Each returns (body, lid). Body footprint ~1.6 x 1.1 x 1.0; lid on top.
# ------------------------------------------------------------------------------------------------

def cinder():
    mats = palette(
        m("CinderSoot", srgb(30, 26, 26), base2=srgb(58, 46, 42), noise_scale=7, rough=0.85, veins=srgb(255, 110, 40), vein_scale=5, vein_glow=0.55),
        m("CinderIron", srgb(78, 68, 62), base2=srgb(42, 36, 34), noise_scale=30, metal=1.0, rough=0.45, noise=0.08),
        glow("CinderEmber", srgb(255, 140, 60), 1.4),
        m("CinderCoal", srgb(22, 20, 20), base2=srgb(40, 34, 32), noise_scale=12, rough=0.9, veins=srgb(255, 150, 70), vein_scale=9, vein_glow=0.9),
    )
    b = bmesh.new()
    box(b, 1.5, 1.0, 0.95, 0, (0, 0, 0.475))
    box(b, 1.64, 1.14, 0.1, 1, (0, 0, 0.05))
    box(b, 1.58, 1.08, 0.07, 1, (0, 0, 0.915))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(b, 0.13, 0.13, 0.95, 1, (sx * 0.75, sy * 0.5, 0.475))
            for z in (0.22, 0.48, 0.74):
                add(b, uvsphere(0.03, 8, 5, mat=1), at(sx * 0.75, sy * 0.5 + sy * 0.07, z))
    # the furnace mouth: a glowing bed behind a forged grille
    box(b, 0.92, 0.03, 0.44, 2, (0, -0.505, 0.42))
    for i in range(7):
        box(b, 0.05, 0.07, 0.5, 1, (-0.42 + i * 0.14, -0.53, 0.42))
    for z in (0.17, 0.67):
        box(b, 1.04, 0.08, 0.07, 1, (0, -0.53, z))
    for x in (-0.5, 0.5):
        box(b, 0.07, 0.08, 0.57, 1, (x, -0.53, 0.42))
    for sx in (-1, 1):
        for z in (0.56, 0.66, 0.76):
            box(b, 0.02, 0.52, 0.045, 2, (sx * 0.755, 0, z))
    body = finish("Crate_Cinder_Body", b, mats)

    l = bmesh.new()
    box(l, 1.62, 1.12, 0.14, 1, (0, 0, 0.07))
    box(l, 1.5, 1.0, 0.1, 0, (0, 0, 0.19))
    for sx, sy, w, d in ((0, -0.46, 1.3, 0.05), (0, 0.46, 1.3, 0.05), (-0.62, 0, 0.05, 0.9), (0.62, 0, 0.05, 0.9)):
        box(l, w, d, 0.1, 1, (sx, sy, 0.29))
    lumps = ((-0.4, -0.15, 0.13), (-0.12, 0.12, 0.15), (0.18, -0.12, 0.12), (0.42, 0.14, 0.1), (-0.32, 0.22, 0.1),
             (0.05, -0.28, 0.1), (0.3, 0.3, 0.09), (-0.5, -0.32, 0.08), (0.48, -0.3, 0.09))
    for i, (x, y, r) in enumerate(lumps):
        add(l, ico(r, 1, mat=3, smooth=False), at(x, y, 0.24 + r * 0.6) @ rot("Z", i * 37) @ scale(1.15, 1.0, 0.8))
    turned(l, [(0, 0), (0.1, 0), (0.1, 0.3), (0.13, 0.33), (0.13, 0.38), (0.0, 0.38)], 16, 1, at(0.52, 0.28, 0.24))
    ring(l, 0.1, 0.022, 2, at(0.52, 0.28, 0.63), segs=24, sides=8)
    lid = finish("Crate_Cinder_Lid", l, mats)
    return body, lid


def verdant():
    mats = palette(
        m("VerdantBronze", srgb(120, 84, 46), base2=srgb(74, 52, 30), noise_scale=10, metal=0.9, rough=0.35, noise=0.06),
        m("VerdantPatina", srgb(76, 168, 136), base2=srgb(40, 110, 90), noise_scale=14, metal=0.5, rough=0.55),
        glow("VerdantBloom", srgb(170, 255, 160), 1.2),
        m("VerdantGlass", srgb(150, 230, 190), rough=0.05, coat=1.0, fresnel_glow=srgb(210, 255, 225)),
    )
    leaf_mat = 1
    b = bmesh.new()
    turned(b, [(0, 0), (0.6, 0), (0.64, 0.07), (0.58, 0.13), (0.68, 0.76), (0.73, 0.8), (0.69, 0.86), (0, 0.86)], 8, 0, rot("Z", 22.5), smooth=False)
    turned(b, [(0.66, 0.38), (0.7, 0.4), (0.7, 0.46), (0.66, 0.48)], 8, 1, rot("Z", 22.5), smooth=False)
    # a moss bed with glowing buds; kept below the rim, because the game seats the lid on the
    # body's bounding box and anything taller would float the dome
    turned(b, [(0, 0.8), (0.6, 0.8), (0.6, 0.85), (0, 0.85)], 24, 1, None)
    for i in range(7):
        a = TAU * i / 7
        r = 0.16 + 0.14 * (i % 2)
        add(b, ico(0.045 + 0.01 * (i % 3), 1, mat=2), at(math.cos(a) * r, math.sin(a) * r, 0.83) @ scale(1.0, 1.0, 0.45))
    # leaf fins on the four diagonal faces
    for i in range(4):
        a = 45 + 90 * i
        rad = math.radians(a)
        spike(b, 0.12, 0.45, leaf_mat, at(math.cos(rad) * 0.62, math.sin(rad) * 0.62, 0.18) @ rot("Z", a - 90) @ rot("X", -14) @ scale(1.0, 0.22, 1.0), sides=4, tip=0.22)
    box(b, 0.26, 0.02, 0.16, 2, (0, -0.64, 0.5), rot("X", 6))
    body = finish("Crate_Verdant_Body", b, mats)

    l = bmesh.new()
    turned(l, [(0, 0), (0.7, 0), (0.72, 0.03), (0.7, 0.07), (0, 0.07)], 32, 1, None)
    dome = [(0.66 * math.cos(math.radians(t)), 0.07 + 0.6 * math.sin(math.radians(t))) for t in range(0, 91, 10)]
    turned(l, [(0, 0.07)] + dome, 24, 3, None)
    for i in range(8):
        arc_tube(l, 0.665, 0.022, 2, 88, 1, at(0, 0, 0.07) @ rot("Z", 22.5 * i) @ scale(1.0, 1.0, 0.6 / 0.665), segs=18, sides=6)
    band = math.radians(48)
    ring(l, 0.66 * math.cos(band) + 0.012, 0.02, 1, at(0, 0, 0.07 + 0.6 * math.sin(band)), segs=40, sides=6)
    turned(l, [(0, 0.66), (0.06, 0.66), (0.08, 0.72), (0.04, 0.78), (0, 0.79)], 16, 1, None)
    for i in range(5):
        a = TAU * i / 5
        spike(l, 0.04, 0.16, 1, at(math.cos(a) * 0.05, math.sin(a) * 0.05, 0.76) @ rot("Z", math.degrees(a)) @ rot("Y", 40) @ scale(1.0, 0.35, 1.0))
    add(l, uvsphere(0.05, 12, 8, mat=2), at(0, 0, 0.82))
    lid = finish("Crate_Verdant_Lid", l, mats)
    return body, lid


def tidal():
    mats = palette(
        m("TidalHull", srgb(38, 96, 128), base2=srgb(22, 62, 88), noise_scale=8, metal=0.7, rough=0.38, coat=0.3),
        m("TidalBrass", BRASS, base2=BRASS_DEEP, noise_scale=36, metal=1.0, rough=0.3, noise=0.06),
        glow("TidalLight", srgb(120, 230, 255), 1.2),
        m("TidalSeaGlass", srgb(90, 220, 200), rough=0.05, coat=1.0, fresnel_glow=srgb(170, 255, 240)),
    )
    b = bmesh.new()
    for y in (-0.4, 0.4):
        box(b, 1.5, 0.12, 0.08, 1, (0, y, 0.04))
    for x in (-0.48, 0.48):
        box(b, 0.18, 0.96, 0.24, 1, (x, 0, 0.2))
        arc_tube(b, 0.44, 0.04, 200, 340, 1, at(x, 0, 0.62) @ rot("Z", 90), segs=16, sides=6)
    profile = [(0, -0.76), (0.2, -0.73), (0.33, -0.65), (0.4, -0.52), (0.42, -0.38), (0.42, 0.38), (0.4, 0.52), (0.33, 0.65), (0.2, 0.73), (0, 0.76)]
    turned(b, profile, 32, 0, at(0, 0, 0.62) @ rot("Y", 90))
    for x in (-0.46, 0.0, 0.46):
        ring(b, 0.43, 0.03, 1, at(x, 0, 0.62) @ rot("Y", 90), segs=40, sides=8)
    for x in (-0.25, 0.25):
        ring(b, 0.11, 0.025, 1, at(x, -0.41, 0.62) @ rot("X", 90), segs=28, sides=8)
        disc(b, 0.095, 0.03, 24, 3, at(x, -0.4, 0.62) @ rot("X", 90))
    for x in (-0.66, 0.66):
        disc(b, 0.08, 0.04, 16, 2, at(x * 1.13, 0, 0.62) @ rot("Y", 90 if x > 0 else -90))
    body = finish("Crate_Tidal_Body", b, mats)

    l = bmesh.new()
    disc(l, 0.3, 0.06, 32, 1, None)
    disc(l, 0.27, 0.05, 32, 0, at(0, 0, 0.06))
    ring(l, 0.18, 0.026, 1, at(0, 0, 0.2), segs=36, sides=8)
    for i in range(4):
        box(l, 0.36, 0.03, 0.03, 1, (0, 0, 0.2), rot("Z", 45 * i))
    disc(l, 0.04, 0.12, 12, 1, at(0, 0, 0.11))
    for i in range(6):
        a = TAU * i / 6
        add(l, uvsphere(0.025, 8, 5, mat=1), at(math.cos(a) * 0.25, math.sin(a) * 0.25, 0.115))
    turned(l, [(0, 0), (0.045, 0), (0.045, 0.2), (0, 0.2)], 12, 1, at(0.3, 0.2, 0))
    arc_tube(l, 0.07, 0.045, 0, 180, 1, at(0.23, 0.2, 0.2), segs=12, sides=8)
    disc(l, 0.05, 0.02, 12, 2, at(0.16, 0.2, 0.2) @ rot("X", 180))
    lid = finish("Crate_Tidal_Lid", l, mats)
    return body, lid


def rune_glyphs(bm, mat, centre, count, spacing, size, seed, face="front"):
    """Carved glyphs: three or four strokes each, chosen by a fixed seed so every build is identical."""
    angles = (0, 45, 90, 135)
    state = seed
    for g in range(count):
        cx = (g - (count - 1) / 2) * spacing
        for s in range(3 + (g + seed) % 2):
            state = (state * 1103515245 + 12345) % 2147483648
            angle = angles[state % 4]
            length = size * (0.5 + (state >> 8) % 5 * 0.12)
            dx = ((state >> 12) % 3 - 1) * size * 0.25
            dz = ((state >> 16) % 3 - 1) * size * 0.3
            if face == "front":
                box(bm, 0.022, 0.012, length, mat, (centre[0] + cx + dx, centre[1], centre[2] + dz), rot("Y", angle))
            else:
                sign = 1 if face == "right" else -1
                box(bm, 0.012, 0.022, length, mat, (centre[0], centre[1] + cx + dx, centre[2] + dz), rot("X", angle * sign))


def runic():
    mats = palette(
        m("RunicStone", srgb(98, 104, 122), base2=srgb(64, 68, 84), noise_scale=5, rough=0.85, veins=srgb(130, 180, 255), vein_scale=3, vein_glow=0.18),
        m("RunicIron", srgb(60, 62, 72), base2=srgb(34, 36, 44), noise_scale=30, metal=1.0, rough=0.5, noise=0.08),
        glow("RunicLight", srgb(130, 180, 255), 1.5),
        m("RunicSilver", srgb(210, 216, 232), base2=srgb(160, 168, 190), noise_scale=40, metal=0.9, rough=0.28),
    )
    b = bmesh.new()
    box(b, 1.64, 1.14, 0.08, 0, (0, 0, 0.04))
    box(b, 1.56, 1.06, 0.06, 0, (0, 0, 0.11))
    box(b, 1.48, 0.98, 0.82, 0, (0, 0, 0.55))
    for sx in (-1, 1):
        for sy in (-1, 1):
            spike(b, 0.1, 0.92, 0, at(sx * 0.76, sy * 0.51, 0.06) @ rot("Z", 45), sides=4, tip=0.14)
    rune_glyphs(b, 2, (0, -0.495, 0.36), 5, 0.22, 0.17, 7)
    rune_glyphs(b, 2, (0.745, 0, 0.55), 3, 0.24, 0.17, 19, face="right")
    rune_glyphs(b, 2, (-0.745, 0, 0.55), 3, 0.24, 0.17, 31, face="left")
    box(b, 0.3, 0.05, 0.3, 1, (0, -0.51, 0.72))
    ring(b, 0.08, 0.018, 2, at(0, -0.54, 0.72) @ rot("X", 90), segs=24, sides=6)
    for x in (-0.45, 0.45):
        box(b, 0.18, 0.05, 0.56, 1, (x, 0.505, 0.6))
        disc(b, 0.06, 0.24, 16, 1, at(x - 0.12, 0.53, 0.92) @ rot("Y", 90))
    body = finish("Crate_Runic_Body", b, mats, bevel=0.02)

    l = bmesh.new()
    box(l, 1.6, 1.1, 0.12, 0, (0, 0, 0.06))
    box(l, 1.3, 0.85, 0.1, 0, (0, 0, 0.17))
    box(l, 1.0, 0.6, 0.08, 0, (0, 0, 0.26))
    for sx, sy, w, d in ((0, -0.545, 1.5, 0.012), (0, 0.545, 1.5, 0.012), (-0.795, 0, 0.012, 1.0), (0.795, 0, 0.012, 1.0)):
        box(l, w, d, 0.025, 2, (sx, sy, 0.06))
    disc(l, 0.2, 0.05, 32, 3, at(0, 0, 0.3))
    ring(l, 0.2, 0.02, 2, at(0, 0, 0.35), segs=32, sides=6)
    rune_glyphs(l, 2, (0, -0.425, 0.17), 4, 0.24, 0.07, 53)
    lid = finish("Crate_Runic_Lid", l, mats, bevel=0.02)
    return body, lid


def comet():
    mats = palette(
        m("CometHull", srgb(222, 236, 250), base2=srgb(172, 200, 230), noise_scale=6, metal=0.3, rough=0.25, coat=0.8),
        m("CometScorch", srgb(44, 46, 62), base2=srgb(96, 72, 60), noise_scale=9, rough=0.7, metal=0.4),
        glow("CometTrail", srgb(200, 240, 255), 1.4),
        m("CometFrost", srgb(150, 210, 255), rough=0.08, coat=1.0, fresnel_glow=srgb(220, 245, 255)),
    )
    b = bmesh.new()
    turned(b, [(0, 0.1), (0.3, 0.08), (0.5, 0.14), (0.62, 0.32), (0.66, 0.56), (0.64, 0.82), (0, 0.82)], 32, 0, None)
    turned(b, [(0.655, 0.42), (0.675, 0.46), (0.675, 0.54), (0.66, 0.58)], 32, 1, None)
    for z in (0.28, 0.72):
        ring(b, 0.63 if z < 0.5 else 0.645, 0.01, 1, at(0, 0, z), segs=48, sides=6)
    for i in range(3):
        a = 90 + 120 * i
        rad = math.radians(a)
        box(b, 0.06, 0.42, 0.5, 1, (math.cos(rad) * 0.62, math.sin(rad) * 0.62, 0.3), rot("Z", a - 90) @ rot("X", -18))
        disc(b, 0.1, 0.04, 16, 1, at(math.cos(rad) * 0.78, math.sin(rad) * 0.78, 0.0))
    ring(b, 0.13, 0.025, 1, at(0, -0.645, 0.56) @ rot("X", 90), segs=28, sides=8)
    disc(b, 0.115, 0.03, 24, 3, at(0, -0.63, 0.56) @ rot("X", 90))
    for i in range(4):
        box(b, 0.022, 0.012, 0.22, 2, (-0.3 + i * 0.2, -0.6, 0.36 - (i % 2) * 0.06), rot("Y", 62))
    body = finish("Crate_Comet_Body", b, mats)

    l = bmesh.new()
    turned(l, [(0, 0), (0.645, 0), (0.6, 0.15), (0.5, 0.32), (0.34, 0.48), (0.17, 0.58), (0, 0.62)], 32, 0, None)
    turned(l, [(0.175, 0.57), (0.11, 0.61), (0, 0.635)], 32, 1, None)
    ring(l, 0.64, 0.018, 2, at(0, 0, 0.02), segs=48, sides=6)
    for i in range(3):
        a = 30 + 120 * i
        rad = math.radians(a)
        box(l, 0.035, 0.24, 0.2, 3, (math.cos(rad) * 0.46, math.sin(rad) * 0.46, 0.28), rot("Z", a - 90) @ rot("X", 30))
    spike(l, 0.012, 0.3, 1, at(0.1, 0.0, 0.58), sides=6, tip=0.0)
    add(l, uvsphere(0.03, 10, 6, mat=2), at(0.1, 0.0, 0.9))
    lid = finish("Crate_Comet_Lid", l, mats)
    return body, lid


def mirage():
    mats = palette(
        m("MirageMirror", srgb(242, 206, 232), base2=srgb(184, 166, 226), noise_scale=4, metal=1.0, rough=0.08),
        m("MiragePearl", srgb(255, 238, 248), rough=0.2, coat=1.0, fresnel_glow=srgb(255, 170, 240)),
        glow("MirageShimmer", srgb(255, 190, 240), 1.3),
        m("MirageLens", srgb(200, 240, 255), rough=0.02, coat=1.0, fresnel_glow=srgb(150, 220, 255)),
    )
    b = bmesh.new()
    hull = bmesh.new()
    add(hull, prism(0.56, 0.84, 6, mat=0), at(0, 0, 0.06))
    twist(hull, hull.verts, 14, 0.06, 0.9)
    bmesh.ops.transform(hull, matrix=scale(1.45, 1.0, 1.0), verts=hull.verts)
    add(b, hull)
    for z, r in ((0.0, 0.6), (0.86, 0.6)):
        band = bmesh.new()
        add(band, prism(r, 0.07, 6, mat=1), at(0, 0, z))
        twist(band, band.verts, 14 if z > 0 else 0, -1, 0)
        bmesh.ops.transform(band, matrix=scale(1.45, 1.0, 1.0), verts=band.verts)
        add(b, band)
    for x in (-0.36, 0.36):
        ring(b, 0.15, 0.022, 1, at(x, -0.56, 0.46) @ rot("X", 90), segs=28, sides=6)
        disc(b, 0.135, 0.025, 24, 3, at(x, -0.545, 0.46) @ rot("X", 90))
    for i in range(6):
        a = math.radians(60 * i)  # the hexagon's corners, where light catches the mirror seams
        box(b, 0.018, 0.018, 0.76, 2, (math.cos(a) * 0.565 * 1.45, math.sin(a) * 0.565, 0.48))
    body = finish("Crate_Mirage_Body", b, mats)

    l = bmesh.new()
    rim = bmesh.new()
    add(rim, prism(0.6, 0.08, 6, mat=1), None)
    bmesh.ops.transform(rim, matrix=rot("Z", 14) @ scale(1.45, 1.0, 1.0), verts=rim.verts)
    add(l, rim)
    roof = bmesh.new()
    add(roof, prism(0.56, 0.1, 6, tip=0.34, mat=0, taper=0.6), at(0, 0, 0.08))
    twist(roof, roof.verts, -24, 0.08, 0.52)
    bmesh.ops.transform(roof, matrix=rot("Z", 14) @ scale(1.45, 1.0, 1.0), verts=roof.verts)
    add(l, roof)
    add(l, prism(0.06, 0.16, 6, tip=0.12, mat=2), at(0, 0, 0.46))
    for i in range(3):
        a = TAU * i / 3
        add(l, ico(0.04, 1, mat=3, smooth=False), at(math.cos(a) * 0.12, math.sin(a) * 0.12, 0.5))
    lid = finish("Crate_Mirage_Lid", l, mats)
    return body, lid


def quasar():
    mats = palette(
        m("QuasarHousing", srgb(62, 50, 100), base2=srgb(36, 28, 66), noise_scale=8, metal=0.8, rough=0.35, coat=0.4),
        m("QuasarChrome", srgb(204, 200, 224), metal=1.0, rough=0.18, noise=0.04, noise_scale=40),
        glow("QuasarCore", srgb(200, 150, 255), 1.5),
        m("QuasarBlade", srgb(124, 114, 156), base2=srgb(84, 76, 110), noise_scale=30, metal=1.0, rough=0.3),
    )
    b = bmesh.new()
    turned(b, [(0, 0), (0.58, 0), (0.66, 0.06), (0.66, 0.14), (0.6, 0.18), (0.62, 0.72), (0.7, 0.78), (0.7, 0.86), (0, 0.86)], 32, 0, None)
    for z in (0.3, 0.5, 0.68):
        ring(b, 0.62, 0.032, 1, at(0, 0, z), segs=48, sides=8)
    for i in range(18):
        a = 360 * i / 18
        if a < 40 or a > 320:
            continue  # a = 0 is the front (-Y), where the intake sits
        rad = math.radians(a - 90)
        box(b, 0.03, 0.1, 0.38, 3, (math.cos(rad) * 0.64, math.sin(rad) * 0.64, 0.48), rot("Z", a))
    ring(b, 0.27, 0.042, 1, at(0, -0.62, 0.46) @ rot("X", 90), segs=36, sides=8)
    disc(b, 0.24, 0.03, 32, 2, at(0, -0.58, 0.46) @ rot("X", 90))
    for i in range(10):
        box(b, 0.035, 0.012, 0.21, 3, (0, -0.6, 0.46), rot("Y", 36 * i) @ at(0, 0, 0.11) @ rot("Z", 25))
    add(b, uvsphere(0.06, 12, 8, mat=1), at(0, -0.62, 0.46))
    for sx in (-1, 1):
        turned(b, [(0, 0), (0.14, 0), (0.18, 0.08), (0.16, 0.16), (0.1, 0.18), (0, 0.18)], 20, 1, at(sx * 0.66, 0, 0.46) @ rot("Y", 90 * sx))
        disc(b, 0.09, 0.02, 16, 2, at(sx * 0.845, 0, 0.46) @ rot("Y", 90 * sx))
    body = finish("Crate_Quasar_Body", b, mats)

    l = bmesh.new()
    turned(l, [(0, 0), (0.7, 0), (0.68, 0.06), (0.55, 0.16), (0.32, 0.24), (0, 0.26)], 32, 0, None)
    for i in range(8):
        a = 360 * i / 8
        rad = math.radians(a)
        box(l, 0.16, 0.03, 0.2, 1, (math.cos(rad) * 0.42, math.sin(rad) * 0.42, 0.2), rot("Z", a + 90) @ rot("X", -38))
    add(l, uvsphere(0.13, 20, 12, mat=2), at(0, 0, 0.36))
    ring(l, 0.18, 0.016, 1, at(0, 0, 0.36) @ rot("X", 90), segs=32, sides=6)
    ring(l, 0.18, 0.016, 1, at(0, 0, 0.36) @ rot("Y", 90), segs=32, sides=6)
    lid = finish("Crate_Quasar_Lid", l, mats)
    return body, lid


def bastion():
    mats = palette(
        m("BastionArmor", srgb(150, 156, 172), base2=srgb(110, 116, 132), noise_scale=8, metal=0.9, rough=0.4, noise=0.06),
        m("BastionGunmetal", srgb(54, 58, 66), base2=srgb(32, 34, 40), noise_scale=30, metal=1.0, rough=0.45, noise=0.08),
        glow("BastionAmber", srgb(255, 190, 80), 1.0),
        m("BastionHazard", srgb(24, 24, 28), rough=0.6),
    )
    b = bmesh.new()
    box(b, 1.5, 1.0, 0.9, 0, (0, 0, 0.45))
    for sx in (-1, 1):
        box(b, 0.08, 0.96, 0.66, 0, (sx * 0.79, 0, 0.42), rot("Y", -12 * sx))
        for sy in (-1, 1):
            box(b, 0.14, 0.14, 0.92, 1, (sx * 0.74, sy * 0.49, 0.46))
            for z in (0.18, 0.46, 0.74):
                add(b, uvsphere(0.028, 8, 5, mat=1), at(sx * 0.74, sy * 0.57, z))
        box(b, 0.05, 0.05, 0.3, 1, (sx * 0.9, -0.15, 0.6))
        box(b, 0.05, 0.05, 0.3, 1, (sx * 0.9, 0.15, 0.6))
        box(b, 0.05, 0.35, 0.05, 1, (sx * 0.9, 0, 0.75))
    for i in range(10):
        box(b, 0.08, 0.02, 0.19, 2 if i % 2 == 0 else 3, (-0.62 + i * 0.137, -0.505, 0.13), rot("Y", 35))
    for x in (-0.42, 0.42):
        box(b, 0.2, 0.06, 0.24, 1, (x, -0.53, 0.66))
        box(b, 0.06, 0.07, 0.3, 1, (x, -0.57, 0.6), rot("Y", 18))
        box(b, 0.05, 0.02, 0.05, 2, (x, -0.565, 0.74))
    for i in range(5):
        box(b, 0.05, 0.015, 0.1, 2, (-0.12 + i * 0.06, -0.505, 0.44))
    body = finish("Crate_Bastion_Body", b, mats, bevel=0.018)

    l = bmesh.new()
    box(l, 1.62, 1.12, 0.16, 1, (0, 0, 0.08))
    box(l, 1.4, 0.9, 0.1, 0, (0, 0, 0.21))
    for x in (-0.46, 0.46):
        box(l, 0.12, 1.18, 0.12, 1, (x, 0, 0.22))
        for sy in (-1, 1):
            box(l, 0.14, 0.04, 0.16, 1, (x, sy * 0.59, 0.12))
    add(l, uvsphere(0.1, 16, 8, mat=2), at(0, 0, 0.26) @ scale(1, 1, 0.8))
    for i in range(3):
        box(l, 0.025, 0.025, 0.2, 1, (0, 0, 0.34), rot("Z", 60 * i) @ rot("X", 90) @ at(0, 0, 0))
    lid = finish("Crate_Bastion_Lid", l, mats, bevel=0.018)
    return body, lid


def eclipse():
    mats = palette(
        m("EclipseObsidian", srgb(22, 18, 26), base2=srgb(46, 34, 52), noise_scale=6, rough=0.22, coat=1.0, veins=srgb(255, 130, 50), vein_scale=4, vein_glow=0.25),
        m("EclipseBronze", srgb(96, 64, 42), base2=srgb(52, 34, 24), noise_scale=30, metal=1.0, rough=0.4),
        glow("EclipseCorona", srgb(255, 170, 80), 1.6),
        m("EclipseVoid", srgb(8, 6, 10), rough=0.15, coat=1.0, fresnel_glow=srgb(255, 140, 60)),
    )
    b = bmesh.new()
    turned(b, [(0, 0), (0.62, 0), (0.68, 0.05), (0.66, 0.12), (0.56, 0.2), (0.56, 0.74), (0.66, 0.8), (0.68, 0.88), (0, 0.88)], 48, 0, None)
    ring(b, 0.665, 0.03, 2, at(0, 0, 0.865), segs=56, sides=8)
    ring(b, 0.66, 0.03, 1, at(0, 0, 0.06), segs=56, sides=8)
    disc(b, 0.25, 0.035, 40, 3, at(0, -0.56, 0.47) @ rot("X", 90))
    ring(b, 0.275, 0.02, 2, at(0, -0.55, 0.47) @ rot("X", 90), segs=48, sides=8)
    for i in range(12):
        a = 360 * i / 12
        long = 0.14 if i % 2 == 0 else 0.08
        spike(b, 0.02, long, 2, at(0, -0.548, 0.47) @ rot("Y", a) @ at(0, 0, 0.29) , sides=4, tip=long * 0.5)
    for sx in (-1, 1):
        ring(b, 0.12, 0.018, 1, at(sx * 0.565, 0, 0.47) @ rot("Y", 90), segs=28, sides=6)
        disc(b, 0.1, 0.02, 24, 3, at(sx * 0.56, 0, 0.47) @ rot("Y", 90 * sx))
    body = finish("Crate_Eclipse_Body", b, mats)

    l = bmesh.new()
    turned(l, [(0, 0), (0.6, 0), (0.56, 0.1), (0.44, 0.22), (0.25, 0.3), (0, 0.32)], 40, 0, None)
    ring(l, 0.62, 0.025, 2, at(0, 0, 0.13), segs=56, sides=8)
    for i in range(4):
        a = TAU * i / 4 + TAU / 8
        box(l, 0.04, 0.04, 0.14, 1, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.08))
    disc(l, 0.04, 0.08, 12, 1, at(0, 0, 0.3))
    add(l, uvsphere(0.1, 20, 12, mat=3), at(0, 0, 0.46))
    ring(l, 0.14, 0.014, 2, at(0, 0, 0.46) @ rot("X", 90), segs=32, sides=6)
    lid = finish("Crate_Eclipse_Lid", l, mats)
    return body, lid


def nova():
    mats = palette(
        m("NovaGold", GOLD, base2=BRASS_DEEP, noise_scale=36, metal=1.0, rough=0.24, noise=0.06),
        m("NovaCap", srgb(42, 36, 50), base2=srgb(66, 54, 74), noise_scale=10, metal=0.6, rough=0.4),
        glow("NovaStar", srgb(255, 240, 190), 1.7),
        m("NovaGlass", srgb(255, 228, 160), rough=0.05, coat=1.0, fresnel_glow=srgb(255, 244, 210)),
    )
    b = bmesh.new()
    turned(b, [(0, 0), (0.54, 0), (0.58, 0.05), (0.58, 0.18), (0.52, 0.22), (0, 0.22)], 32, 1, None)
    turned(b, [(0, 0.22), (0.34, 0.22), (0.37, 0.4), (0.37, 0.74), (0.34, 0.9), (0, 0.9)], 32, 2, None)
    for i in range(10):
        a = TAU * i / 10
        box(b, 0.045, 0.045, 0.7, 0, (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.56))
    for z in (0.3, 0.56, 0.82):
        ring(b, 0.46, 0.028, 0, at(0, 0, z), segs=40, sides=8)
    turned(b, [(0.44, 0.9), (0.56, 0.92), (0.58, 0.98), (0, 0.98)], 32, 1, None)
    for i in range(4):
        a = 45 + 90 * i
        rad = math.radians(a)
        box(b, 0.05, 0.2, 0.2, 0, (math.cos(rad) * 0.62, math.sin(rad) * 0.62, 0.1), rot("Z", a - 90))
    box(b, 0.22, 0.02, 0.1, 3, (0, -0.58, 0.12))
    body = finish("Crate_Nova_Body", b, mats)

    l = bmesh.new()
    turned(l, [(0, 0), (0.58, 0), (0.56, 0.08), (0.42, 0.14), (0, 0.16)], 32, 1, None)
    for i in range(8):
        a = 360 * i / 8
        rad = math.radians(a)
        length = 0.3 if i % 2 == 0 else 0.2
        spike(l, 0.045, length, 0, at(math.cos(rad) * 0.18, math.sin(rad) * 0.18, 0.15) @ rot("Z", a) @ rot("Y", 70), sides=4)
    for i in range(4):
        a = 45 + 90 * i
        spike(l, 0.03, 0.18, 0, at(0, 0, 0.16) @ rot("Z", a) @ rot("Y", 28), sides=4)
    add(l, ico(0.1, 2, mat=2, smooth=False), at(0, 0, 0.26))
    lid = finish("Crate_Nova_Lid", l, mats)
    return body, lid


def halo():
    mats = palette(
        m("HaloAlabaster", srgb(250, 244, 232), base2=srgb(224, 214, 196), noise_scale=6, rough=0.3, coat=0.8),
        m("HaloGold", GOLD, base2=BRASS_DEEP, noise_scale=36, metal=1.0, rough=0.2, noise=0.05),
        glow("HaloLight", srgb(170, 238, 255), 1.5),
        m("HaloSapphire", srgb(64, 124, 224), rough=0.08, coat=1.0, fresnel_glow=srgb(150, 230, 255)),
    )
    centre = 0.98
    radius = 0.47
    b = bmesh.new()
    turned(b, [(0, 0), (0.62, 0), (0.66, 0.06), (0.62, 0.12), (0.42, 0.2), (0.32, 0.36), (0.36, 0.42), (0.5, 0.5), (0.56, 0.56), (0, 0.56)], 40, 0, None)
    bowl = [(radius * math.cos(math.radians(t)), centre + radius * math.sin(math.radians(t))) for t in range(-90, 1, 10)]
    turned(b, [(0, 0.5)] + bowl[1:], 32, 3, None)
    ring(b, radius + 0.02, 0.032, 1, at(0, 0, centre - 0.02), segs=48, sides=8)
    ring(b, 0.6, 0.02, 1, at(0, 0, 0.13), segs=48, sides=6)
    for i in range(8):
        a = TAU * i / 8
        add(b, ico(0.035, 1, mat=2), at(math.cos(a) * 0.61, math.sin(a) * 0.61, 0.07))
    for i in range(4):
        a = TAU * i / 4
        arc_tube(b, 0.42, 0.018, 200, 330, 1, at(0, 0, 0.62) @ rot("Z", math.degrees(a)), segs=12, sides=6)
    body = finish("Crate_Halo_Body", b, mats)

    l = bmesh.new()
    dome = [(radius * math.cos(math.radians(t)), radius * math.sin(math.radians(t))) for t in range(0, 91, 10)]
    turned(l, [(0, 0)] + dome, 32, 3, None)
    ring(l, radius + 0.02, 0.03, 1, at(0, 0, 0.03), segs=48, sides=8)
    ring(l, 0.6, 0.022, 1, at(0, 0, 0.2) @ rot("X", 14), segs=56, sides=8)
    ring(l, 0.52, 0.02, 2, at(0, 0, 0.27) @ rot("Y", -18), segs=56, sides=8)
    ring(l, 0.4, 0.018, 1, at(0, 0, 0.36) @ rot("X", -22) @ rot("Y", 12), segs=48, sides=8)
    ring(l, 0.1, 0.016, 1, at(0, 0, radius + 0.1) @ rot("X", 90), segs=28, sides=6)
    add(l, ico(0.05, 2, mat=2), at(0, 0, radius + 0.1))
    lid = finish("Crate_Halo_Lid", l, mats)
    return body, lid


CRATES = {
    "Cinder": cinder,
    "Verdant": verdant,
    "Tidal": tidal,
    "Runic": runic,
    "Comet": comet,
    "Mirage": mirage,
    "Quasar": quasar,
    "Bastion": bastion,
    "Eclipse": eclipse,
    "Nova": nova,
    "Halo": halo,
}


# ------------------------------------------------------------------------------------------------
# previews, bake, export
# ------------------------------------------------------------------------------------------------

def bounds(objs):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    pts = []
    for obj in objs:
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        pts.extend(ev.matrix_world @ v.co for v in mesh.vertices)
        ev.to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def stack(body, lid, x, y):
    """Seat the lid on the body as the game does: both centred on X/Y, the lid flush on the body top."""
    body.location = (0, 0, 0)
    lid.location = (0, 0, 0)
    bpy.context.view_layer.update()
    blo, bhi = bounds([body])
    llo, lhi = bounds([lid])
    bc = (blo + bhi) / 2
    lc = (llo + lhi) / 2
    body.location = (x - bc.x, y - bc.y, -blo.z)
    lid.location = (x - lc.x, y - lc.y, bhi.z - blo.z - llo.z)
    bpy.context.view_layer.update()


def render(objs, path, textured, size=720, direction=(0.55, -1.0, 0.42), lens=70):
    scene = bpy.context.scene
    lo, hi = bounds(objs)
    centre = (lo + hi) / 2
    extent = max((hi - lo).length, 0.5)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = size
    shading = scene.display.shading
    shading.light = "FLAT" if textured else "STUDIO"
    shading.color_type = "TEXTURE" if textured else "MATERIAL"
    shading.show_cavity = not textured
    shading.background_type = "VIEWPORT"
    shading.background_color = (0.035, 0.03, 0.05)
    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = centre + Vector(direction).normalized() * extent * 2.4
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    keep = set(objs)
    hidden = []
    for other in scene.objects:
        if other.type == "MESH" and other not in keep and not other.hide_render:
            other.hide_render = True
            hidden.append(other)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for other in hidden:
        other.hide_render = False
    bpy.data.objects.remove(cam)


def main():
    lib["reset"]()
    # reset() loads factory settings, which also wipes the Cycles device preferences: enable the GPU again
    if GPU and not gpu_ready():
        print("[crates] GPU unavailable after reset; baking on the CPU", flush=True)
    if THREADS > 0:
        bpy.context.scene.render.threads_mode = "FIXED"
        bpy.context.scene.render.threads = THREADS
    print(f"[crates] device={'GPU' if GPU else 'CPU'} tex={TEX} samples={lib['SAMPLES']} threads={THREADS or 'auto'}", flush=True)
    built = []
    for index, (name, make) in enumerate(CRATES.items()):
        if ONLY and name not in ONLY:
            continue
        body, lid = make()
        for obj in (body, lid):
            apply_modifiers(obj)
            tris = triangles(obj)
            print(f"[crates] {obj.name}: {tris} triangles", flush=True)
            if tris > 19500:
                raise RuntimeError(f"{obj.name} is over Roblox's per-mesh triangle cap ({tris})")
            obj["crate_skin"] = name
        slot = len(built)
        stack(body, lid, (slot % 4) * 2.6, -(slot // 4) * 2.6)
        built.append((name, body, lid))
    if not FAST:
        status = os.path.join(OUT, "expansion_status.json")
        done = 0
        for name, body, lid in built:
            for obj in (body, lid):
                unwrap(obj)
                bake(obj, obj.name, TEX)
                done += 1
                with open(status, "w", encoding="utf-8") as handle:
                    json.dump({"completed": done, "total": len(built) * 2, "last": obj.name, "gpu": GPU}, handle)
                print(f"[crates] baked {obj.name} ({done}/{len(built) * 2})", flush=True)
    every = [obj for _, body, lid in built for obj in (body, lid)]
    if not NOPREVIEW:
        for name, body, lid in built:
            render([body, lid], os.path.join(PREVIEWS, f"expansion_{name}.png"), textured=not FAST)
        render(every, os.path.join(PREVIEWS, "expansion_sheet.png"), textured=not FAST, size=1400, direction=(0.35, -1.0, 0.9), lens=50)
    if not FAST and not ONLY:
        for o in bpy.context.selected_objects:
            o.select_set(False)
        for obj in every:
            obj.data.name = obj.name
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
            obj.location = (0, 0, 0)
        path = os.path.join(OUT, "CrateKitExpansion.glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_materials="EXPORT", export_image_format="AUTO", export_yup=True)
        with open(os.path.join(OUT, "expansion_status.json"), "w", encoding="utf-8") as handle:
            json.dump({"completed": len(every), "total": len(every), "exported": True, "skins": [n for n, _, _ in built]}, handle)
        print(f"[crates] exported {path}", flush=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "CrateKitExpansion.blend"))


main()
