"""Build the casino's 3D kit in Blender, headless, and export it as one textured GLB.

    blender -b -t 4 --python tools/casinobuild/build_casino.py
    (env FAST=1: no bake, quick Workbench previews; PIECES=Coin,Star: only those)

Every piece is modelled from code (bevels, subdivision, smooth or crisp facets), gets procedural
materials, and has its look baked by Cycles into its own 1024 px texture under a studio light rig:
the casino draws these in ViewportFrames, which have one flat light and no reflections, so the
gold's shine, the gems' sheen and the soft occlusion all live in the texture.

Output, in assets/generated/casino/:
  CasinoKit.glb          the pieces (Roblox MeshParts named "Casino_<Piece>")
  previews/<Piece>.png   a three-quarter render of each piece

Units: studs (1 Blender unit = 1 stud). +Z up; a piece's face looks along -Y (Blender's front).
After import that face looks along Roblox +Z; PagesCasino turns each piece to face its camera.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "casino")
PREVIEWS = os.path.join(OUT, "previews")
os.makedirs(PREVIEWS, exist_ok=True)
FAST = os.environ.get("FAST") == "1"
ONLY = {p.strip() for p in os.environ.get("PIECES", "").split(",") if p.strip()}
TEX = 1024
SAMPLES = 32  # with the denoiser; plenty for a bake that is shown at a few hundred pixels
# Reel symbols are drawn 60-120 px tall: half-size textures are sharper than the screen can show.
SMALL = {"Ember", "Dust", "Core", "Comet", "Star", "Nova", "Ball"}
TAU = math.tau


def srgb(r, g, b):
    """0-255 sRGB -> Blender linear."""
    def lin(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b))


# The game's palette (CoreKit theme), so baked colours match the UI around them.
CORAL = srgb(255, 104, 112)
MANGO = srgb(255, 184, 52)
CYAN = srgb(70, 218, 242)
MINT = srgb(86, 236, 178)
VIOLET = srgb(178, 134, 255)
PINK = srgb(250, 104, 178)
CREAM = srgb(252, 247, 240)
BRASS = srgb(250, 190, 72)
BRASS_DEEP = srgb(140, 92, 30)
GOLD = srgb(255, 196, 86)
NIGHT = srgb(19, 14, 20)
PLUM = srgb(52, 30, 58)
SLATE = srgb(46, 40, 54)
RED = srgb(214, 48, 64)
BLACK = srgb(24, 20, 28)
GREEN = srgb(40, 178, 112)
IVORY = srgb(250, 244, 230)


# ------------------------------------------------------------------------------------------------
# scene
# ------------------------------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    coords = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    # A studio dome: bright warm top, a cool horizon band, a dark floor. Metal reflects this.
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.015, 0.012, 0.02, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (1.0, 0.94, 0.86, 1)
    mid = ramp.color_ramp.elements.new(0.52)
    mid.color = (0.22, 0.24, 0.32, 1)
    hi = ramp.color_ramp.elements.new(0.78)
    hi.color = (0.75, 0.72, 0.7, 1)
    maprange = nt.nodes.new("ShaderNodeMapRange")
    maprange.inputs["From Min"].default_value = -1
    maprange.inputs["From Max"].default_value = 1
    nt.links.new(coords.outputs["Generated"], sep.inputs["Vector"])
    norm = nt.nodes.new("ShaderNodeVectorMath")
    norm.operation = "NORMALIZE"
    nt.links.new(coords.outputs["Generated"], norm.inputs[0])
    sep2 = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(norm.outputs["Vector"], sep2.inputs["Vector"])
    nt.links.new(sep2.outputs["Z"], maprange.inputs["Value"])
    nt.links.new(maprange.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.7
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    # Key, fill and rim area lights (they show up as soft highlights on the metal).
    for name, loc, energy, size in (("Key", (-3.5, -4.0, 5.0), 520, 3.0), ("Fill", (4.5, -2.5, 1.5), 140, 4.0), ("Rim", (1.0, 5.0, 3.5), 300, 2.0)):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.size = size
        obj = bpy.data.objects.new(name, light)
        obj.location = loc
        obj.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)
    return scene


# ------------------------------------------------------------------------------------------------
# materials: procedural looks (baked to textures afterwards)
# ------------------------------------------------------------------------------------------------

def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for key, value in inputs.items():
        n.inputs[key].default_value = value
    return n


def mixer(nt, blend="MIX"):
    """A colour Mix node. Its float, vector and colour sockets share the names "A"/"B", so they are picked
    by identifier. Returns (factor, a, b, result)."""
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    ins = {s.identifier: s for s in m.inputs}
    outs = {s.identifier: s for s in m.outputs}
    return ins["Factor_Float"], ins["A_Color"], ins["B_Color"], outs["Result_Color"]


def material(name, base, metal=0.0, rough=0.4, emit=None, emit_strength=0.0, noise=0.0, noise_scale=18.0,
             base2=None, gradient_z=None, veins=None, vein_scale=6.0, vein_glow=1.0, fresnel_glow=None, coat=0.0):
    """A Principled material: base colour (optionally a noise or height blend to base2), metal, roughness,
    emission, glowing voronoi veins, and a fresnel rim glow."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if coat > 0:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.08
    coords = nt.nodes.new("ShaderNodeTexCoord")
    color = None
    if base2 is not None and gradient_z is not None:
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(coords.outputs["Object"], sep.inputs["Vector"])
        rng = node(nt, "ShaderNodeMapRange")
        rng.inputs["From Min"].default_value = gradient_z[0]
        rng.inputs["From Max"].default_value = gradient_z[1]
        nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
        fac, a, b, result = mixer(nt)
        a.default_value = (*base, 1)
        b.default_value = (*base2, 1)
        nt.links.new(rng.outputs["Result"], fac)
        color = result
    elif base2 is not None:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 6
        nt.links.new(coords.outputs["Object"], tex.inputs["Vector"])
        fac, a, b, result = mixer(nt)
        a.default_value = (*base, 1)
        b.default_value = (*base2, 1)
        nt.links.new(tex.outputs["Fac"], fac)
        color = result
    if color is None:
        bsdf.inputs["Base Color"].default_value = (*base, 1)
    else:
        nt.links.new(color, bsdf.inputs["Base Color"])
    if noise > 0:
        # Fine brushed / grain variation in the roughness.
        grain = nt.nodes.new("ShaderNodeTexNoise")
        grain.inputs["Scale"].default_value = noise_scale * 4
        grain.inputs["Detail"].default_value = 10
        nt.links.new(coords.outputs["Object"], grain.inputs["Vector"])
        rmap = node(nt, "ShaderNodeMapRange")
        rmap.inputs["To Min"].default_value = max(0.02, rough - noise)
        rmap.inputs["To Max"].default_value = min(1.0, rough + noise)
        nt.links.new(grain.outputs["Fac"], rmap.inputs["Value"])
        nt.links.new(rmap.outputs["Result"], bsdf.inputs["Roughness"])
    glow_terms = []
    if emit is not None:
        glow_terms.append(("flat", emit, emit_strength))
    if veins is not None:
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.feature = "DISTANCE_TO_EDGE"
        vor.inputs["Scale"].default_value = vein_scale
        nt.links.new(coords.outputs["Object"], vor.inputs["Vector"])
        vramp = nt.nodes.new("ShaderNodeValToRGB")
        vramp.color_ramp.elements[0].position = 0.0
        vramp.color_ramp.elements[0].color = (*veins, 1)
        vramp.color_ramp.elements[1].position = 0.035
        vramp.color_ramp.elements[1].color = (0, 0, 0, 1)
        nt.links.new(vor.outputs["Distance"], vramp.inputs["Fac"])
        # Emission adds straight onto the baked colour: keep it low or it clips to white.
        glow_terms.append(("veins", vramp.outputs["Color"], vein_glow))
    if fresnel_glow is not None:
        fres = nt.nodes.new("ShaderNodeLayerWeight")
        fres.inputs["Blend"].default_value = 0.35
        fac, a, b, result = mixer(nt)
        a.default_value = (0, 0, 0, 1)
        b.default_value = (*fresnel_glow, 1)
        nt.links.new(fres.outputs["Facing"], fac)
        glow_terms.append(("fresnel", result, 0.6))
    if glow_terms:
        total = None
        for kind, value, strength in glow_terms:
            if kind == "flat":
                rgb = nt.nodes.new("ShaderNodeRGB")
                rgb.outputs["Color"].default_value = (*value, 1)
                socket = rgb.outputs["Color"]
            else:
                socket = value
            fac, a, b, scaled = mixer(nt, "MULTIPLY")
            fac.default_value = 1.0
            nt.links.new(socket, a)
            b.default_value = (strength, strength, strength, 1)
            if total is None:
                total = scaled
            else:
                fac2, a2, b2, summed = mixer(nt, "ADD")
                fac2.default_value = 1.0
                nt.links.new(total, a2)
                nt.links.new(scaled, b2)
                total = summed
        nt.links.new(total, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    mat.diffuse_color = (*(emit or base), 1)
    mat.metallic = metal
    mat.roughness = rough
    return mat


# ------------------------------------------------------------------------------------------------
# modelling helpers (bmesh)
# ------------------------------------------------------------------------------------------------

def new_object(name, bm, materials, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for mat in materials:
        mesh.materials.append(mat)
    if smooth is True:
        for poly in mesh.polygons:
            poly.use_smooth = True
    return obj


def tag(faces, mat_index, smooth):
    for f in faces:
        f.material_index = mat_index
        f.smooth = smooth


def lathe(bm, profile, segments, mat=0, smooth=True, angle=TAU, cap=True):
    """Revolve a (radius, z) profile around Z. Returns the new faces."""
    rings = []
    closed = abs(angle - TAU) < 1e-6
    count = segments if closed else segments + 1
    for i in range(count):
        a = angle * i / segments
        ring = [bm.verts.new((r * math.sin(a), r * math.cos(a), z)) for r, z in profile]
        rings.append(ring)
    faces = []
    for i in range(segments):
        ring_a = rings[i]
        ring_b = rings[(i + 1) % count]
        for j in range(len(profile) - 1):
            quad = (ring_a[j], ring_b[j], ring_b[j + 1], ring_a[j + 1])
            try:
                faces.append(bm.faces.new(quad))
            except ValueError:
                pass
    tag(faces, mat, smooth)
    return faces, rings


def orient(faces, mode="outup"):
    """Point the faces of a lathed surface the right way: mostly-flat faces up ("outup") or down ("down"),
    walls away from the axis. A lathe's winding depends on its profile's direction, so it is fixed here."""
    for f in faces:
        f.normal_update()
        n = f.normal
        c = f.calc_center_median()
        if abs(n.z) >= 0.35:
            want_up = mode != "down"
            if (n.z > 0) != want_up:
                f.normal_flip()
        else:
            radial = Vector((c.x, c.y, 0))
            if radial.length > 1e-4 and n.dot(radial) < 0:
                f.normal_flip()


def transform(bm, verts, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=verts)


def add_mesh_from(bm, other_bm, matrix=None, mat=None, smooth=None):
    """Append other_bm's geometry into bm (optionally transformed / re-tagged)."""
    temp = bpy.data.meshes.new("tmp")
    other_bm.to_mesh(temp)
    other_bm.free()
    before = set(bm.faces)
    bm.from_mesh(temp)
    bpy.data.meshes.remove(temp)
    new_faces = [f for f in bm.faces if f not in before]
    new_verts = list({v for f in new_faces for v in f.verts})
    if matrix is not None:
        transform(bm, new_verts, matrix)
    for f in new_faces:
        if mat is not None:
            f.material_index = mat
        if smooth is not None:
            f.smooth = smooth
    return new_faces


def ico(radius, subdiv, mat=0, smooth=True):
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=subdiv, radius=radius)
    tag(b.faces, mat, smooth)
    return b


def uvsphere(radius, segs=32, rings=16, mat=0, smooth=True):
    b = bmesh.new()
    bmesh.ops.create_uvsphere(b, u_segments=segs, v_segments=rings, radius=radius)
    tag(b.faces, mat, smooth)
    return b


def torus(major, minor, segs=64, sides=16, mat=0, smooth=True, squash=1.0):
    b = bmesh.new()
    rings = []
    for i in range(segs):
        a = TAU * i / segs
        center = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        ring = []
        for j in range(sides):
            t = TAU * j / sides
            p = center + out * math.cos(t) * minor + Vector((0, 0, math.sin(t) * minor * squash))
            ring.append(b.verts.new(p))
        rings.append(ring)
    for i in range(segs):
        for j in range(sides):
            b.faces.new((rings[i][j], rings[(i + 1) % segs][j], rings[(i + 1) % segs][(j + 1) % sides], rings[i][(j + 1) % sides]))
    tag(b.faces, mat, smooth)
    return b


def prism(radius, height, sides=6, tip=0.0, mat=0, smooth=False, taper=1.0):
    """A column along +Z from 0 to height, optionally ending in a point `tip` above it."""
    b = bmesh.new()
    bottom = [b.verts.new((math.cos(TAU * i / sides) * radius, math.sin(TAU * i / sides) * radius, 0)) for i in range(sides)]
    top = [b.verts.new((math.cos(TAU * i / sides) * radius * taper, math.sin(TAU * i / sides) * radius * taper, height)) for i in range(sides)]
    for i in range(sides):
        b.faces.new((bottom[i], bottom[(i + 1) % sides], top[(i + 1) % sides], top[i]))
    b.faces.new(list(reversed(bottom)))
    if tip > 0:
        apex = b.verts.new((0, 0, height + tip))
        for i in range(sides):
            b.faces.new((top[i], top[(i + 1) % sides], apex))
    else:
        b.faces.new(top)
    tag(b.faces, mat, smooth)
    return b


def modifiers(obj, bevel=0.0, bevel_segments=2, subdiv=0, weighted=True, angle=None):
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = bevel_segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle or 35)
        mod.harden_normals = False
    if subdiv > 0:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    if weighted:
        mod = obj.modifiers.new("Weighted", "WEIGHTED_NORMAL")
        mod.keep_sharp = True


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def text_mesh(body, size, depth, bevel=0.0):
    """A letter as a bmesh: lies in XY reading left to right, extruded along +Z (0..depth)."""
    curve = bpy.data.curves.new("glyph", "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = depth / 2
    curve.bevel_depth = bevel
    curve.bevel_resolution = 2
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new("glyph", curve)
    bpy.context.scene.collection.objects.link(obj)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    b = bmesh.new()
    b.from_mesh(mesh)
    bmesh.ops.translate(b, verts=b.verts, vec=(0, 0, depth / 2))
    bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-5)
    bpy.data.objects.remove(obj)
    bpy.data.curves.remove(curve)
    bpy.data.meshes.remove(mesh)
    return b


def rot(axis, degrees):
    return Matrix.Rotation(math.radians(degrees), 4, axis)


def at(x, y, z):
    return Matrix.Translation((x, y, z))


# ------------------------------------------------------------------------------------------------
# the pieces (each returns one object)
# ------------------------------------------------------------------------------------------------

def piece_ember():
    body = material("EmberBody", CORAL, base2=MANGO, gradient_z=(-0.4, 0.55), rough=0.22, coat=0.6,
                    fresnel_glow=srgb(255, 150, 90))
    heart = material("EmberHeart", srgb(255, 210, 110), emit=srgb(255, 196, 70), emit_strength=0.55, rough=0.3)
    bm = bmesh.new()
    # A flame lathed from a teardrop profile, then flattened, curled and twisted.
    profile = []
    steps = 22
    for i in range(steps + 1):
        t = i / steps
        z = -0.42 + t * 1.0
        r = 0.4 * math.sin(math.pi * min(1, t * 1.05)) ** 0.75 * (1 - 0.55 * t)
        profile.append((max(0.0005, r), z))
    faces, rings = lathe(bm, profile, 22, mat=0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    for v in bm.verts:
        t = (v.co.z + 0.42) / 1.0
        v.co.y *= 0.62
        twist = 0.9 * t * t
        x, y = v.co.x, v.co.y
        v.co.x = x * math.cos(twist) - y * math.sin(twist) + 0.22 * t ** 2.2
        v.co.y = x * math.sin(twist) + y * math.cos(twist)
    # two licks of flame either side
    for side in (-1, 1):
        lick = bmesh.new()
        p2 = []
        for i in range(13):
            t = i / 12
            p2.append((max(0.0005, 0.17 * math.sin(math.pi * t) ** 0.8 * (1 - 0.5 * t)), t * 0.5))
        lathe(lick, p2, 16, mat=0)
        bmesh.ops.remove_doubles(lick, verts=lick.verts, dist=1e-4)
        for v in lick.verts:
            v.co.y *= 0.6
            v.co.x += 0.16 * side * (v.co.z / 0.5) ** 1.5
        add_mesh_from(bm, lick, at(side * 0.26, 0.02, -0.28) @ rot("Y", side * 28))
    # the glowing heart: a smaller flame set flush into the front face
    core = bmesh.new()
    p3 = []
    for i in range(15):
        t = i / 14
        p3.append((max(0.0005, 0.17 * math.sin(math.pi * min(1, t * 1.05)) ** 0.75 * (1 - 0.5 * t)), -0.32 + t * 0.55))
    lathe(core, p3, 18, mat=1)
    bmesh.ops.remove_doubles(core, verts=core.verts, dist=1e-4)
    for v in core.verts:
        t = (v.co.z + 0.32) / 0.55
        v.co.y *= 0.4
        v.co.x += 0.08 * t ** 2
    add_mesh_from(bm, core, at(0.0, -0.16, 0.0))
    obj = new_object("Casino_Ember", bm, [body, heart])
    modifiers(obj, subdiv=1)
    return obj


def piece_dust():
    crystal = material("DustCrystal", CYAN, base2=srgb(170, 240, 255), noise_scale=4, rough=0.12, coat=0.8,
                       fresnel_glow=srgb(120, 230, 255))
    rock = material("DustRock", SLATE, base2=srgb(80, 70, 96), noise_scale=9, rough=0.85)
    bm = bmesh.new()
    shards = [
        (0.0, 0.0, 0.17, 0.7, 0.2, 0, 0), (0.24, 0.05, 0.12, 0.48, 0.15, 24, 10), (-0.25, 0.02, 0.13, 0.52, 0.16, -26, -8),
        (0.12, -0.12, 0.09, 0.36, 0.12, 18, -26), (-0.12, -0.1, 0.1, 0.4, 0.12, -14, 24), (0.04, 0.16, 0.1, 0.42, 0.13, 6, 30),
        (0.36, -0.06, 0.07, 0.26, 0.1, 44, -12), (-0.36, -0.04, 0.075, 0.28, 0.1, -42, 14),
    ]
    for x, y, r, h, tip, roll, pitch in shards:
        p = prism(r, h, 6, tip=tip, mat=0, smooth=False, taper=0.92)
        add_mesh_from(bm, p, at(x, y, -0.3) @ rot("Y", roll) @ rot("X", pitch) @ rot("Z", (x * 97) % 60))
    base = ico(0.34, 2, mat=1, smooth=True)
    for v in base.verts:
        v.co.z *= 0.42
        n = math.sin(v.co.x * 17) * math.cos(v.co.y * 13) * 0.03
        v.co += v.co.normalized() * n
    add_mesh_from(bm, base, at(0, 0, -0.34))
    obj = new_object("Casino_Dust", bm, [crystal, rock], smooth=None)
    modifiers(obj, bevel=0.012, bevel_segments=2, angle=25)
    return obj


def piece_core():
    gem = material("CoreGem", MINT, base2=srgb(30, 150, 110), noise_scale=3, rough=0.16, coat=0.7,
                   veins=srgb(150, 255, 210), vein_scale=5, vein_glow=0.45)
    ring = material("CoreRing", BRASS, base2=BRASS_DEEP, noise_scale=30, metal=1.0, rough=0.28, noise=0.08)
    bm = bmesh.new()
    # A brilliant-cut gem with its table facing the camera (-Y): table, crown, girdle and pavilion.
    gem_bm = bmesh.new()
    n = 16
    girdle_r, table_r, crown_h, pav_h, gird_t = 0.38, 0.22, 0.13, 0.3, 0.025
    table = [gem_bm.verts.new((math.sin(TAU * (i + 0.5) / 8) * table_r, -crown_h - gird_t, math.cos(TAU * (i + 0.5) / 8) * table_r)) for i in range(8)]
    star_ring = [gem_bm.verts.new((math.sin(TAU * i / 8) * girdle_r * 0.78, -gird_t - crown_h * 0.45, math.cos(TAU * i / 8) * girdle_r * 0.78)) for i in range(8)]
    girdle_f = [gem_bm.verts.new((math.sin(TAU * i / n) * girdle_r, -gird_t, math.cos(TAU * i / n) * girdle_r)) for i in range(n)]
    girdle_b = [gem_bm.verts.new((math.sin(TAU * i / n) * girdle_r, gird_t, math.cos(TAU * i / n) * girdle_r)) for i in range(n)]
    culet = gem_bm.verts.new((0, gird_t + pav_h, 0))
    gem_bm.faces.new(list(reversed(table)))
    for i in range(8):
        # crown: kite and star facets between the table, the star ring and the girdle
        gem_bm.faces.new((table[i], table[(i + 1) % 8], star_ring[(i + 1) % 8]))
        gem_bm.faces.new((table[i], star_ring[(i + 1) % 8], star_ring[i]))
        gem_bm.faces.new((star_ring[i], star_ring[(i + 1) % 8], girdle_f[(2 * i + 2) % n], girdle_f[2 * i + 1], girdle_f[2 * i]))
    for i in range(n):
        gem_bm.faces.new((girdle_f[i], girdle_f[(i + 1) % n], girdle_b[(i + 1) % n], girdle_b[i]))
        gem_bm.faces.new((girdle_b[i], girdle_b[(i + 1) % n], culet))
    bmesh.ops.recalc_face_normals(gem_bm, faces=gem_bm.faces)
    tag(gem_bm.faces, 0, False)
    add_mesh_from(bm, gem_bm)
    # a studded brass setting ring round the girdle, in the face plane
    band = torus(0.43, 0.045, 72, 12, mat=1)
    add_mesh_from(bm, band, rot("X", 90))
    for i in range(8):
        a = TAU * (i + 0.5) / 8
        stud = uvsphere(0.04, 12, 8, mat=1)
        add_mesh_from(bm, stud, at(math.sin(a) * 0.43, -0.04, math.cos(a) * 0.43))
    obj = new_object("Casino_Core", bm, [gem, ring], smooth=None)
    modifiers(obj, bevel=0.01, bevel_segments=2, angle=30)
    return obj


def piece_comet():
    rock = material("CometHead", srgb(96, 80, 126), base2=srgb(52, 42, 70), noise_scale=7, rough=0.7,
                    veins=srgb(190, 140, 255), vein_scale=7, vein_glow=0.6)
    tail = material("CometTail", VIOLET, base2=PINK, gradient_z=(0.0, 0.7), rough=0.3,
                    emit=srgb(170, 120, 255), emit_strength=0.22)
    bm = bmesh.new()
    head = ico(0.27, 3, mat=0)
    for v in head.verts:
        d = v.co.normalized()
        n = (math.sin(d.x * 9.1 + d.y * 3.7) * math.cos(d.z * 7.3) + 0.6 * math.sin(d.y * 14 + d.z * 5)) * 0.025
        v.co += d * n
    add_mesh_from(bm, head, at(-0.22, 0, -0.2))
    # three swept strands that wrap the head and stream away up and right, flaring then tapering
    for k, (offset, width, bend) in enumerate(((0.0, 1.3, 0.0), (0.26, 0.7, 0.3), (-0.24, 0.62, -0.26))):
        strand = bmesh.new()
        path = []
        for i in range(29):
            t = 0.08 + 0.92 * i / 28
            ang = 0.8 + 0.42 * t + bend * t * (1 - t)
            px = -0.22 + math.cos(ang) * t * 1.12 + offset * t
            pz = -0.2 + math.sin(ang) * t * 1.05 - offset * 0.4 * t
            py = math.sin(t * 6 + k * 2) * 0.035 + 0.04
            r = 0.27 * width * (1 - t) ** 0.95 + 0.004
            path.append((Vector((px, py, pz)), r))
        rings = []
        for i, (p, r) in enumerate(path):
            nxt = path[min(i + 1, len(path) - 1)][0]
            prv = path[max(i - 1, 0)][0]
            tangent = (nxt - prv).normalized()
            side = tangent.cross(Vector((0, 1, 0))).normalized()
            up = side.cross(tangent).normalized()
            ring = [strand.verts.new(p + (side * math.cos(TAU * j / 10) + up * math.sin(TAU * j / 10) * 0.6) * r) for j in range(10)]
            rings.append(ring)
        for i in range(len(rings) - 1):
            for j in range(10):
                strand.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % 10], rings[i][(j + 1) % 10]))
        tag(strand.faces, 1, True)
        add_mesh_from(bm, strand)
    obj = new_object("Casino_Comet", bm, [rock, tail], smooth=None)
    modifiers(obj, subdiv=1)
    return obj


def piece_star():
    gold = material("StarGold", MANGO, base2=srgb(255, 226, 140), noise_scale=12, metal=1.0, rough=0.22, noise=0.06)
    bm = bmesh.new()
    outer, inner, depth = 0.56, 0.24, 0.17
    rim = []
    for i in range(10):
        a = TAU * i / 10
        r = outer if i % 2 == 0 else inner
        rim.append(bm.verts.new((math.sin(a) * r, 0, math.cos(a) * r)))
    front = bm.verts.new((0, -depth, 0))
    back = bm.verts.new((0, depth, 0))
    for i in range(10):
        bm.faces.new((rim[i], rim[(i + 1) % 10], front))
        bm.faces.new((rim[(i + 1) % 10], rim[i], back))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tag(bm.faces, 0, False)
    obj = new_object("Casino_Star", bm, [gold], smooth=None)
    modifiers(obj, bevel=0.022, bevel_segments=3, angle=20)
    return obj


def piece_nova():
    orb = material("NovaOrb", PINK, base2=srgb(255, 200, 236), noise_scale=5, rough=0.2, coat=0.6,
                   emit=srgb(255, 120, 200), emit_strength=0.12, veins=srgb(255, 170, 220), vein_scale=4, vein_glow=0.4)
    ring = material("NovaRing", CREAM, base2=srgb(255, 214, 160), noise_scale=24, metal=1.0, rough=0.2)
    bm = bmesh.new()
    sphere = uvsphere(0.31, 48, 24, mat=0)
    for v in sphere.verts:
        d = v.co.normalized()
        v.co += d * 0.012 * math.sin(math.atan2(d.y, d.x) * 6 + d.z * 8)
    add_mesh_from(bm, sphere)
    add_mesh_from(bm, torus(0.5, 0.032, 96, 12, mat=1), rot("X", 72) @ rot("Y", 20))
    for i in range(8):
        a = TAU * i / 8 + 0.2
        sparkle = bmesh.new()
        pts = [sparkle.verts.new(p) for p in ((0.07, 0, 0), (0, 0.07, 0), (-0.07, 0, 0), (0, -0.07, 0))]
        top = sparkle.verts.new((0, 0, 0.09))
        bottom = sparkle.verts.new((0, 0, -0.09))
        for j in range(4):
            sparkle.faces.new((pts[j], pts[(j + 1) % 4], top))
            sparkle.faces.new((pts[(j + 1) % 4], pts[j], bottom))
        tag(sparkle.faces, 1, False)
        add_mesh_from(bm, sparkle, at(math.sin(a) * 0.66, -0.05, math.cos(a) * 0.66) @ rot("Y", i * 25))
    obj = new_object("Casino_Nova", bm, [orb, ring], smooth=None)
    modifiers(obj, bevel=0.006, bevel_segments=1, angle=40)
    return obj


CYCLE = 18


def piece_drum():
    lacquer = material("DrumLacquer", PLUM, base2=srgb(82, 46, 92), noise_scale=3, rough=0.18, coat=1.0)
    brass = material("DrumBrass", BRASS, base2=BRASS_DEEP, noise_scale=40, metal=1.0, rough=0.26, noise=0.08)
    bm = bmesh.new()
    radius, half = 1.66, 0.59
    # Body: a cylinder along X with a shallow groove at every cell boundary.
    segs = CYCLE * 8
    rings = []
    for i in range(segs):
        a = TAU * i / segs
        cell = (i % 8) / 8
        groove = 0.035 if cell == 0 else (0.012 if cell in (1 / 8, 7 / 8) else 0.0)
        r = radius - groove
        ring = [bm.verts.new((x, math.sin(a) * r, math.cos(a) * r)) for x in (-half, -half * 0.86, half * 0.86, half)]
        rings.append(ring)
    for i in range(segs):
        a, b = rings[i], rings[(i + 1) % segs]
        for j in range(3):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    for side, idx in ((-half, 0), (half, 3)):
        cap = [ring[idx] for ring in rings]
        centre = bm.verts.new((side, 0, 0))
        for i in range(segs):
            quad = (cap[i], cap[(i + 1) % segs], centre) if side < 0 else (cap[(i + 1) % segs], cap[i], centre)
            bm.faces.new(quad)
    tag(bm.faces, 0, True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Brass rims with studs, and a thin pinstripe ring inboard of each.
    for x in (-half - 0.02, half + 0.02):
        rim = torus(radius + 0.02, 0.075, 96, 10, mat=1)
        add_mesh_from(bm, rim, at(x, 0, 0) @ rot("Y", 90))
        stripe = torus(radius + 0.004, 0.012, 96, 6, mat=1)
        add_mesh_from(bm, stripe, at(x * 0.8, 0, 0) @ rot("Y", 90))
        for i in range(CYCLE):
            a = TAU * (i + 0.5) / CYCLE
            stud = uvsphere(0.045, 8, 6, mat=1)
            add_mesh_from(bm, stud, at(x * 1.02, math.sin(a) * (radius + 0.02), math.cos(a) * (radius + 0.02)))
    obj = new_object("Casino_Drum", bm, [lacquer, brass], smooth=None)
    # Only the cap edges are sharp enough to need a bevel; the tori and studs are already round.
    modifiers(obj, bevel=0.012, bevel_segments=2, angle=70)
    return obj


def piece_coin():
    field = material("CoinField", GOLD, base2=srgb(214, 150, 50), noise_scale=60, metal=1.0, rough=0.34, noise=0.12)
    relief = material("CoinRelief", srgb(255, 222, 140), base2=GOLD, noise_scale=20, metal=1.0, rough=0.14)
    bm = bmesh.new()
    radius, reeds = 1.05, 90
    # Profile (radius, y) from the centre of the front face out over the rim and back: the face is recessed,
    # the rim stands proud, the edge is reeded.
    prof = [(0.0, -0.11), (0.86, -0.11), (0.88, -0.125), (0.9, -0.145), (0.98, -0.145), (radius, -0.12),
            (radius, 0.12), (0.98, 0.145), (0.9, 0.145), (0.88, 0.125), (0.86, 0.11), (0.0, 0.11)]
    segs = reeds * 2
    rings = []
    for i in range(segs):
        a = TAU * i / segs
        reed = 0.012 if i % 2 == 0 else -0.006
        ring = []
        for r, y in prof:
            rr = r + (reed if abs(r - radius) < 1e-6 else 0)
            ring.append(bm.verts.new((math.sin(a) * rr, y, math.cos(a) * rr)))
        rings.append(ring)
    for i in range(segs):
        a, b = rings[i], rings[(i + 1) % segs]
        for j in range(len(prof) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tag(bm.faces, 0, True)
    # beaded border on both faces
    for y, sign in ((-0.11, -1), (0.11, 1)):
        for i in range(40):
            a = TAU * i / 40
            bead = uvsphere(0.028, 8, 5, mat=1)
            add_mesh_from(bm, bead, at(math.sin(a) * 0.78, y, math.cos(a) * 0.78))
    # heads: a star and an H (front, -Y); tails: a laurel and a T (back, +Y), drawn so it reads after a flip
    star = bmesh.new()
    rim = []
    for i in range(10):
        a = TAU * i / 10
        r = 0.2 if i % 2 == 0 else 0.085
        rim.append(star.verts.new((math.sin(a) * r, 0, math.cos(a) * r)))
    apex = star.verts.new((0, -0.05, 0))
    floor = star.verts.new((0, 0.01, 0))
    for i in range(10):
        star.faces.new((rim[i], rim[(i + 1) % 10], apex))
        star.faces.new((rim[(i + 1) % 10], rim[i], floor))
    bmesh.ops.recalc_face_normals(star, faces=star.faces)
    tag(star.faces, 1, False)
    add_mesh_from(bm, star, at(0, -0.11, 0.42))
    letter_h = text_mesh("H", 0.62, 0.045, bevel=0.008)
    tag(letter_h.faces, 1, True)
    add_mesh_from(bm, letter_h, at(0, -0.11, -0.1) @ rot("X", 90))
    letter_t = text_mesh("T", 0.62, 0.045, bevel=0.008)
    tag(letter_t.faces, 1, True)
    add_mesh_from(bm, letter_t, at(0, 0.11, 0.1) @ rot("X", -90))
    for side in (-1, 1):
        for i in range(9):
            t = i / 8
            a = math.radians(200 - 140 * t) if side < 0 else math.radians(-20 + 140 * t)
            leaf = uvsphere(0.05, 12, 8, mat=1)
            for v in leaf.verts:
                v.co.z *= 1.9
                v.co.y *= 0.5
            add_mesh_from(bm, leaf, at(math.cos(a) * 0.6, 0.12, -math.sin(a) * 0.6) @ rot("Y", math.degrees(-a) + 90))
    obj = new_object("Casino_Coin", bm, [field, relief], smooth=None)
    # A steep angle limit: the rim and relief get a soft bevel, the hundreds of edge reeds don't.
    modifiers(obj, bevel=0.006, bevel_segments=1, angle=70)
    return obj


def piece_card():
    face = material("CardFace", CREAM, base2=srgb(236, 226, 210), noise_scale=40, rough=0.42, coat=0.4)
    back = material("CardBack", VIOLET, base2=srgb(120, 80, 200), noise_scale=6, rough=0.3, coat=0.7)
    trim = material("CardTrim", BRASS, base2=BRASS_DEEP, noise_scale=40, metal=1.0, rough=0.24, noise=0.06)
    bm = bmesh.new()
    w, h, t, corner = 2.0, 2.8, 0.07, 0.2
    # A rounded rectangle outline in XZ, extruded through Y.
    outline = []
    for cx, cz, start in ((w / 2 - corner, h / 2 - corner, 0), (-(w / 2 - corner), h / 2 - corner, 90), (-(w / 2 - corner), -(h / 2 - corner), 180), (w / 2 - corner, -(h / 2 - corner), 270)):
        for i in range(9):
            a = math.radians(start + 90 * i / 8)
            outline.append((cx + math.cos(a) * corner, cz + math.sin(a) * corner))
    front = [bm.verts.new((x, -t / 2, z)) for x, z in outline]
    rear = [bm.verts.new((x, t / 2, z)) for x, z in outline]
    n = len(outline)
    ff = bm.faces.new(list(reversed(front)))
    rf = bm.faces.new(rear)
    sides = [bm.faces.new((front[i], front[(i + 1) % n], rear[(i + 1) % n], rear[i])) for i in range(n)]
    ff.material_index = 0
    rf.material_index = 1
    for f in sides:
        f.material_index = 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Face: an inset gold border and four diamond pips; back: a brass lattice in a frame and an emblem.
    def frame_bars(y, inset, thick, mat, height):
        bars = []
        for x0, z0, x1, z1 in ((-w / 2 + inset, h / 2 - inset, w / 2 - inset, h / 2 - inset), (-w / 2 + inset, -h / 2 + inset, w / 2 - inset, -h / 2 + inset),
                               (-w / 2 + inset, -h / 2 + inset, -w / 2 + inset, h / 2 - inset), (w / 2 - inset, -h / 2 + inset, w / 2 - inset, h / 2 - inset)):
            b = bmesh.new()
            bmesh.ops.create_cube(b, size=1)
            sx = max(abs(x1 - x0), thick)
            sz = max(abs(z1 - z0), thick)
            bmesh.ops.scale(b, vec=(sx, height, sz), verts=b.verts)
            tag(b.faces, mat, False)
            add_mesh_from(bm, b, at((x0 + x1) / 2, y, (z0 + z1) / 2))
    frame_bars(-t / 2 - 0.006, 0.16, 0.04, 2, 0.014)
    frame_bars(t / 2 + 0.006, 0.16, 0.04, 2, 0.014)
    for x, z in ((-0.68, 1.02), (0.68, -1.02), (0.68, 1.02), (-0.68, -1.02)):
        pip = bmesh.new()
        pts = [pip.verts.new(p) for p in ((0.09, 0, 0), (0, 0, 0.13), (-0.09, 0, 0), (0, 0, -0.13))]
        apex = pip.verts.new((0, -0.03, 0))
        for j in range(4):
            pip.faces.new((pts[j], pts[(j + 1) % 4], apex))
        tag(pip.faces, 2, False)
        add_mesh_from(bm, pip, at(x, -t / 2, z))
    # A diamond lattice clipped to the inside of the back frame.
    half_x, half_z = w / 2 - 0.2, h / 2 - 0.2
    for direction in (1, -1):
        angle = math.radians(34) * direction
        d = Vector((math.sin(angle), math.cos(angle)))
        normal = Vector((d.y, -d.x))
        for i in range(-9, 10):
            origin = normal * (i * 0.19)
            # clip the infinite line origin + s*d to the rectangle (Liang-Barsky)
            s0, s1 = -10.0, 10.0
            for p, q in ((-d.x, origin.x + half_x), (d.x, half_x - origin.x), (-d.y, origin.y + half_z), (d.y, half_z - origin.y)):
                if abs(p) < 1e-9:
                    if q < 0:
                        s0, s1 = 1, 0
                    continue
                r = q / p
                if p < 0:
                    s0 = max(s0, r)
                else:
                    s1 = min(s1, r)
            if s1 - s0 < 0.05:
                continue
            a = origin + d * s0
            b = origin + d * s1
            mid = (a + b) / 2
            bar = bmesh.new()
            bmesh.ops.create_cube(bar, size=1)
            bmesh.ops.scale(bar, vec=(0.018, 0.012, (b - a).length), verts=bar.verts)
            tag(bar.faces, 2, False)
            add_mesh_from(bm, bar, at(mid.x, t / 2 + 0.006, mid.y) @ rot("Y", math.degrees(angle)))
    emblem = torus(0.26, 0.03, 48, 10, mat=2)
    add_mesh_from(bm, emblem, at(0, t / 2 + 0.01, 0) @ rot("X", 90))
    gem = ico(0.12, 1, mat=1, smooth=False)
    add_mesh_from(bm, gem, at(0, t / 2 + 0.03, 0))
    obj = new_object("Casino_Card", bm, [face, back, trim], smooth=None)
    modifiers(obj, bevel=0.008, bevel_segments=2, angle=35)
    return obj


WHEEL = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
REDS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


def piece_wheel():
    wood = material("WheelWood", srgb(92, 46, 34), base2=srgb(56, 26, 20), noise_scale=2.5, rough=0.3, coat=0.9)
    brass = material("WheelBrass", BRASS, base2=BRASS_DEEP, noise_scale=40, metal=1.0, rough=0.22, noise=0.06)
    track = material("WheelTrack", srgb(40, 30, 48), base2=srgb(58, 44, 68), noise_scale=8, rough=0.35, coat=0.5)
    red = material("PocketRed", RED, rough=0.3, coat=0.6)
    black = material("PocketBlack", BLACK, rough=0.3, coat=0.6)
    green = material("PocketGreen", GREEN, rough=0.3, coat=0.6)
    bm = bmesh.new()
    # The bowl, turned: wooden rim, brass lip, sloping ball track down to the pocket ring.
    profile = [(2.86, -0.14), (2.88, 0.06), (2.84, 0.2), (2.74, 0.26), (2.62, 0.22), (2.5, 0.16), (2.3, 0.12), (2.12, 0.1), (2.02, 0.08)]
    orient(lathe(bm, profile[:5], 96, mat=0)[0])
    orient(lathe(bm, profile[4:], 96, mat=2)[0])
    orient(lathe(bm, [(2.88, -0.14), (2.0, -0.16), (0.0, -0.16)], 48, mat=0)[0], "down")
    rim_band = torus(2.78, 0.035, 96, 8, mat=1)
    add_mesh_from(bm, rim_band, at(0, 0, 0.255))
    # pocket floors, coloured by number, between brass frets
    inner, outer = 1.3, 2.02
    count = len(WHEEL)
    for index, number in enumerate(WHEEL):
        a0 = TAU * (index - 0.5) / count
        a1 = TAU * (index + 0.5) / count
        mat = 5 if number == 0 else (3 if number in REDS else 4)
        quad = []
        for r, a in ((inner, a0), (outer, a0), (outer, a1), (inner, a1)):
            quad.append(bm.verts.new((math.sin(a) * r, math.cos(a) * r, 0.04)))
        f = bm.faces.new(quad)
        f.material_index = mat
        f.smooth = False
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
        # fret on the leading edge of every pocket
        fret = bmesh.new()
        bmesh.ops.create_cube(fret, size=1)
        bmesh.ops.scale(fret, vec=(0.03, outer - inner, 0.1), verts=fret.verts)
        tag(fret.faces, 1, False)
        mid = (inner + outer) / 2
        add_mesh_from(bm, fret, Matrix.Rotation(-a0, 4, "Z") @ at(0, mid, 0.09))
    # pocket ring walls and the inner cone
    orient(lathe(bm, [(1.3, 0.04), (1.28, 0.16), (1.2, 0.2), (0.9, 0.34), (0.55, 0.42)], 72, mat=0)[0])
    orient(lathe(bm, [(0.55, 0.42), (0.42, 0.44), (0.3, 0.6), (0.18, 0.66), (0.12, 0.86), (0.06, 0.92), (0.0005, 0.93)], 48, mat=1)[0])
    for i in range(4):
        arm = bmesh.new()
        bmesh.ops.create_cube(arm, size=1)
        bmesh.ops.scale(arm, vec=(0.05, 0.5, 0.05), verts=arm.verts)
        tag(arm.faces, 1, True)
        add_mesh_from(bm, arm, rot("Z", 45 + 90 * i) @ at(0, 0.32, 0.7))
        knob = uvsphere(0.055, 14, 8, mat=1)
        add_mesh_from(bm, knob, rot("Z", 45 + 90 * i) @ at(0, 0.58, 0.7))
    obj = new_object("Casino_Wheel", bm, [wood, brass, track, red, black, green], smooth=None)
    modifiers(obj, bevel=0.008, bevel_segments=2, angle=35)
    return obj


def piece_ball():
    ivory = material("BallIvory", IVORY, base2=srgb(236, 228, 210), noise_scale=8, rough=0.12, coat=1.0)
    obj = new_object("Casino_Ball", uvsphere(0.15, 40, 20, mat=0), [ivory])
    return obj


# ------------------------------------------------------------------------------------------------
# crate skins: every skin is a body and a lid (the lid is its own mesh so it can swing open). The
# box is 1.6 wide, 1.1 deep and 1.0 tall (studs); the lid sits on top, its hinge along the back edge.
# ------------------------------------------------------------------------------------------------

CRATE_W, CRATE_D, CRATE_H, LID_H = 1.6, 1.1, 1.0, 0.34

CRATE_STYLES = {
    # base: (colour, colour2, metal, rough, coat), trim: (colour, colour2, metal, rough), glow: colour or None
    "Classic": dict(base=(srgb(70, 52, 44), srgb(96, 72, 58), 0.0, 0.7, 0.0), trim=(BRASS, BRASS_DEEP, 1.0, 0.3), glow=srgb(255, 140, 60), extra="rivets"),
    "Crystal": dict(base=(srgb(120, 220, 255), srgb(200, 245, 255), 0.0, 0.1, 1.0), trim=(srgb(220, 230, 240), srgb(150, 160, 175), 1.0, 0.2), glow=srgb(160, 240, 255), extra="crystals"),
    "Frost": dict(base=(srgb(150, 200, 230), srgb(205, 235, 250), 0.0, 0.35, 0.6), trim=(srgb(230, 245, 255), srgb(170, 200, 220), 1.0, 0.25), glow=srgb(170, 230, 255), extra="icicles"),
    "Molten": dict(base=(srgb(40, 30, 30), srgb(70, 50, 44), 0.0, 0.85, 0.0), trim=(srgb(90, 70, 60), srgb(50, 40, 36), 1.0, 0.5), glow=srgb(255, 120, 40), extra="cracks"),
    "Nebula": dict(base=(srgb(36, 22, 60), srgb(90, 50, 130), 0.0, 0.08, 1.0), trim=(GOLD, BRASS_DEEP, 1.0, 0.25), glow=srgb(250, 120, 220), extra="nebula"),
    "Void": dict(base=(srgb(20, 16, 28), srgb(40, 30, 56), 0.0, 0.6, 0.3), trim=(srgb(70, 50, 110), srgb(30, 20, 50), 1.0, 0.35), glow=srgb(180, 110, 255), extra="runes"),
    "Gilded": dict(base=(srgb(250, 244, 230), srgb(230, 220, 200), 0.0, 0.3, 0.8), trim=(GOLD, srgb(214, 150, 50), 1.0, 0.18), glow=srgb(255, 236, 170), extra="stars"),
    "Celestial": dict(base=(srgb(235, 250, 255), srgb(170, 230, 255), 0.0, 0.15, 1.0), trim=(srgb(255, 236, 170), srgb(200, 170, 110), 1.0, 0.15), glow=srgb(120, 240, 255), extra="halo"),
}


def crate_materials(skin):
    style = CRATE_STYLES[skin]
    b, t, g = style["base"], style["trim"], style["glow"]
    veins = g if style["extra"] in ("cracks", "runes", "nebula") else None
    base = material(f"{skin}Base", b[0], base2=b[1], noise_scale=6, metal=b[2], rough=b[3], coat=b[4],
                    veins=veins, vein_scale=4 if style["extra"] == "cracks" else 7, vein_glow=0.9 if style["extra"] == "cracks" else 0.5)
    trim = material(f"{skin}Trim", t[0], base2=t[1], noise_scale=40, metal=t[2], rough=t[3], noise=0.06)
    glow = material(f"{skin}Glow", g, emit=g, emit_strength=0.8, rough=0.3)
    return [base, trim, glow]


def box_bm(sx, sy, sz, mat, center=(0, 0, 0)):
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1)
    bmesh.ops.scale(b, vec=(sx, sy, sz), verts=b.verts)
    bmesh.ops.translate(b, vec=center, verts=b.verts)
    tag(b.faces, mat, False)
    return b


def crate_body(skin):
    style = CRATE_STYLES[skin]
    bm = bmesh.new()
    add_mesh_from(bm, box_bm(CRATE_W, CRATE_D, CRATE_H, 0, (0, 0, CRATE_H / 2)))
    # trim: bottom band, top rim, vertical corner posts
    add_mesh_from(bm, box_bm(CRATE_W + 0.06, CRATE_D + 0.06, 0.12, 1, (0, 0, 0.06)))
    add_mesh_from(bm, box_bm(CRATE_W + 0.05, CRATE_D + 0.05, 0.08, 1, (0, 0, CRATE_H - 0.04)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_mesh_from(bm, box_bm(0.12, 0.12, CRATE_H, 1, (sx * (CRATE_W / 2), sy * (CRATE_D / 2), CRATE_H / 2)))
    # the front lock plate and a glowing seam just under the lid
    add_mesh_from(bm, box_bm(0.34, 0.06, 0.32, 1, (0, -CRATE_D / 2 - 0.03, CRATE_H - 0.24)))
    add_mesh_from(bm, box_bm(0.14, 0.04, 0.14, 2, (0, -CRATE_D / 2 - 0.065, CRATE_H - 0.24)))
    add_mesh_from(bm, box_bm(CRATE_W - 0.1, CRATE_D - 0.1, 0.03, 2, (0, 0, CRATE_H + 0.005)))
    extra = style["extra"]
    if extra == "rivets":
        for sx in (-1, 1):
            for z in (0.2, 0.5, 0.8):
                for sy in (-1, 1):
                    add_mesh_from(bm, uvsphere(0.025, 8, 5, mat=1), at(sx * (CRATE_W / 2 + 0.06), sy * (CRATE_D / 2 - 0.02), z))
        for x in (-0.45, 0, 0.45):
            add_mesh_from(bm, box_bm(0.03, 0.02, CRATE_H - 0.2, 1, (x, -CRATE_D / 2 - 0.01, CRATE_H / 2)))
    elif extra == "icicles":
        for sx in (-1, 1):
            for sy in (-1, 1):
                for k in range(3):
                    p = prism(0.03 + 0.01 * k, 0.12, 6, tip=0.0, mat=2, taper=0.0)
                    add_mesh_from(bm, p, at(sx * (CRATE_W / 2 - 0.1 - k * 0.12), sy * (CRATE_D / 2 + 0.03), 0.02) @ rot("X", 180))
        for x in (-0.5, 0.5):
            add_mesh_from(bm, box_bm(0.26, 0.015, 0.03, 2, (x, -CRATE_D / 2 - 0.005, 0.5)))
            add_mesh_from(bm, box_bm(0.03, 0.015, 0.26, 2, (x, -CRATE_D / 2 - 0.005, 0.5)))
    elif extra == "stars":
        for x in (-0.5, 0.5):
            for z in (0.3, 0.7):
                star = ico(0.035, 1, mat=1, smooth=False)
                add_mesh_from(bm, star, at(x, -CRATE_D / 2 - 0.03, z))
    elif extra == "halo":
        for x in (-0.55, -0.2, 0.2, 0.55):
            add_mesh_from(bm, box_bm(0.02, 0.015, CRATE_H - 0.26, 2, (x, -CRATE_D / 2 - 0.006, CRATE_H / 2)))
    elif extra == "crystals":
        for x in (-0.55, 0.55):
            add_mesh_from(bm, box_bm(0.36, 0.015, 0.6, 2, (x, -CRATE_D / 2 - 0.006, 0.5)))
    elif extra == "nebula":
        add_mesh_from(bm, box_bm(CRATE_W - 0.4, 0.015, 0.56, 2, (0, -CRATE_D / 2 - 0.006, 0.44)))
    obj = new_object(f"Crate_{skin}_Body", bm, crate_materials(skin), smooth=None)
    modifiers(obj, bevel=0.018, bevel_segments=2, angle=40)
    return obj


def barrel(half_w, half_d, rise, mat, base_z, segs=20, inflate=0.0):
    """A treasure-chest lid: a half-cylinder along X (an arch over the depth), closed at both ends."""
    b = bmesh.new()
    rings = []
    for x in (-half_w, half_w):
        ring = []
        for i in range(segs + 1):
            a = math.pi * i / segs
            ring.append(b.verts.new((x, math.cos(a) * (half_d + inflate), base_z + math.sin(a) * (rise + inflate))))
        rings.append(ring)
    for i in range(segs):
        b.faces.new((rings[0][i], rings[0][i + 1], rings[1][i + 1], rings[1][i]))
    b.faces.new(list(reversed(rings[0])))
    b.faces.new(rings[1])
    bottom = [rings[0][0], rings[0][segs], rings[1][segs], rings[1][0]]
    b.faces.new(bottom)
    bmesh.ops.recalc_face_normals(b, faces=b.faces)
    tag(b.faces, mat, True)
    return b


def crate_lid(skin):
    style = CRATE_STYLES[skin]
    bm = bmesh.new()
    base_z = CRATE_H + 0.02
    half_w, half_d = CRATE_W / 2 + 0.04, CRATE_D / 2 + 0.04
    # the arched lid, a rim along its base, and two trim straps that wrap over the arch
    add_mesh_from(bm, barrel(half_w, half_d, LID_H, 0, base_z))
    add_mesh_from(bm, box_bm(CRATE_W + 0.1, CRATE_D + 0.1, 0.06, 1, (0, 0, base_z + 0.03)))
    for sx in (-1, 1):
        add_mesh_from(bm, barrel(0.06, half_d, LID_H, 1, base_z, inflate=0.02), at(sx * (half_w - 0.16), 0, 0))
    add_mesh_from(bm, barrel(0.035, half_d, LID_H, 2, base_z, inflate=0.012))
    # handle / emblem by style, sitting on the crown of the arch
    extra = style["extra"]
    emblem_z = base_z + LID_H + 0.02
    if extra == "crystals":
        for k, (x, y, r, h, tilt, lean) in enumerate(((0, 0, 0.1, 0.5, 0, 0), (0.17, 0.04, 0.08, 0.36, 22, 6), (-0.17, -0.03, 0.08, 0.34, -24, -8), (0.06, -0.14, 0.065, 0.26, 10, -22), (-0.05, 0.13, 0.06, 0.24, -8, 20))):
            add_mesh_from(bm, prism(r, h, 6, tip=r * 1.3, mat=2, taper=0.94), at(x, y, emblem_z - 0.06) @ rot("Y", tilt) @ rot("X", lean))
    elif extra == "halo":
        add_mesh_from(bm, torus(0.32, 0.025, 64, 10, mat=1), at(0, 0, emblem_z + 0.22) @ rot("X", 90))
        add_mesh_from(bm, ico(0.09, 2, mat=2), at(0, 0, emblem_z + 0.22))
    elif extra == "icicles":
        for k in range(5):
            add_mesh_from(bm, prism(0.035, 0.18 + 0.05 * (k % 2), 6, tip=0.05, mat=2), at(-0.36 + k * 0.18, 0, emblem_z - 0.04))
    elif extra == "runes" or extra == "nebula":
        add_mesh_from(bm, torus(0.16, 0.02, 48, 8, mat=1), at(0, 0, emblem_z - 0.02))
        add_mesh_from(bm, ico(0.08, 2, mat=2), at(0, 0, emblem_z + 0.02))
    elif extra == "stars":
        star = bmesh.new()
        rim = [star.verts.new((math.sin(TAU * i / 10) * (0.18 if i % 2 == 0 else 0.08), 0, math.cos(TAU * i / 10) * (0.18 if i % 2 == 0 else 0.08))) for i in range(10)]
        f1 = star.verts.new((0, -0.05, 0))
        f2 = star.verts.new((0, 0.05, 0))
        for i in range(10):
            star.faces.new((rim[i], rim[(i + 1) % 10], f1))
            star.faces.new((rim[(i + 1) % 10], rim[i], f2))
        bmesh.ops.recalc_face_normals(star, faces=star.faces)
        tag(star.faces, 1, False)
        add_mesh_from(bm, star, at(0, 0, emblem_z + 0.12))
    else:
        # a forged handle with ember gems in its feet
        add_mesh_from(bm, box_bm(0.5, 0.06, 0.05, 1, (0, 0, emblem_z + 0.08)))
        for sx in (-1, 1):
            add_mesh_from(bm, box_bm(0.06, 0.06, 0.12, 1, (sx * 0.22, 0, emblem_z + 0.02)))
            add_mesh_from(bm, ico(0.04, 1, mat=2), at(sx * 0.22, -0.05, emblem_z - 0.02))
        if extra == "cracks":
            for x in (-0.4, 0.4):
                add_mesh_from(bm, ico(0.07, 1, mat=2, smooth=False), at(x, 0.1, emblem_z - 0.05))
    obj = new_object(f"Crate_{skin}_Lid", bm, crate_materials(skin), smooth=None)
    modifiers(obj, bevel=0.016, bevel_segments=2, angle=40)
    return obj


def crate_piece(skin):
    def make():
        return [crate_body(skin), crate_lid(skin)]
    return make


PIECES = {
    "Ember": piece_ember, "Dust": piece_dust, "Core": piece_core, "Comet": piece_comet, "Star": piece_star,
    "Nova": piece_nova, "Drum": piece_drum, "Coin": piece_coin, "Card": piece_card, "Wheel": piece_wheel, "Ball": piece_ball,
}
for _skin in CRATE_STYLES:
    PIECES["Crate" + _skin] = crate_piece(_skin)


# ------------------------------------------------------------------------------------------------
# bake, preview, export
# ------------------------------------------------------------------------------------------------

def triangles(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(depsgraph).to_mesh()
    count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    obj.evaluated_get(depsgraph).to_mesh_clear()
    return count


def unwrap(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006, area_weight=0.0)
    bpy.ops.uv.pack_islands(margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(obj, name, size=TEX):
    """Bake the lit look (COMBINED under the studio dome and lights) into one texture, then swap the
    object's materials for a single material that shows it."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 2
    scene.cycles.transmission_bounces = 2
    scene.render.bake.margin = 8
    image = bpy.data.images.new(f"{name}_tex", size, size, alpha=False)
    for mat in obj.data.materials:
        nt = mat.node_tree
        target = nt.nodes.new("ShaderNodeTexImage")
        target.image = image
        nt.nodes.active = target
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.ops.object.bake(type="COMBINED", use_clear=True)
    # Roblox lights the texture again in its viewport: keep highlights off white and the colour saturated.
    px = np.array(image.pixels[:], dtype=np.float32).reshape(size, size, 4)
    rgb = px[..., :3]
    rgb = np.clip(rgb * 1.12, 0, 0.97)
    px[..., :3] = rgb
    image.pixels = px.flatten().tolist()
    path = os.path.join(OUT, f"{name}.png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    baked = bpy.data.materials.new(f"{name}_baked")
    baked.use_nodes = True
    nt = baked.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(baked)
    for poly in obj.data.polygons:
        poly.material_index = 0
    return path


def preview(obj, name, textured):
    scene = bpy.context.scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(depsgraph)
    mesh = ev.to_mesh()
    pts = [ev.matrix_world @ v.co for v in mesh.vertices]
    ev.to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    extent = max((hi - lo).length, 0.5)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = 640
    shading = scene.display.shading
    # Baked pieces are previewed flat (the bake already holds the lighting, as in a viewport); raw ones in studio light.
    shading.light = "FLAT" if textured else "STUDIO"
    shading.color_type = "TEXTURE" if textured else "MATERIAL"
    shading.show_cavity = not textured
    shading.show_specular_highlight = True
    cam_data = bpy.data.cameras.new(f"{name}_cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new(f"{name}_cam", cam_data)
    scene.collection.objects.link(cam)
    direction = Vector((0.45, -1.0, 0.35)).normalized()
    cam.location = centre + direction * extent * 2.6
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    hidden = []
    for other in scene.objects:
        if other.type == "MESH" and other is not obj and not other.hide_render:
            other.hide_render = True
            hidden.append(other)
    path = os.path.join(PREVIEWS, f"{name}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for other in hidden:
        other.hide_render = False
    bpy.data.objects.remove(cam)
    return path


def export(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for obj in objs:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        obj.location = (0, 0, 0)
    path = os.path.join(OUT, "CasinoKit.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_materials="EXPORT", export_image_format="AUTO", export_yup=True)
    return path


def main():
    reset()
    built = []
    spacing = 0
    for name, make in PIECES.items():
        if ONLY and name not in ONLY:
            continue
        made = make()
        objs = made if isinstance(made, list) else [made]
        for obj in objs:
            obj.location = (spacing, 0, 0)
            apply_modifiers(obj)
            tris = triangles(obj)
            label = obj.name.replace("Casino_", "")
            print(f"[casino] {label}: {tris} triangles", flush=True)
            if tris > 19500:
                print(f"[casino] WARNING {label} is over Roblox's per-mesh triangle cap", flush=True)
            built.append((label, obj))
        spacing += 8
    for name, obj in built:
        if not FAST:
            unwrap(obj)
            # crate parts keep their own names (Crate_<Skin>_Body/_Lid); everything else is Casino_<Piece>
            texture_name = obj.name if obj.name.startswith("Crate_") else f"Casino_{name}"
            small = name in SMALL or obj.name.startswith("Crate_")
            bake(obj, texture_name, TEX // 2 if small else TEX)
            print(f"[casino] baked {name}", flush=True)
        preview(obj, name, textured=not FAST)
    if not FAST and not ONLY:
        path = export([obj for _, obj in built])
        print(f"[casino] exported {path}", flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "CasinoKit.blend"))


main()
