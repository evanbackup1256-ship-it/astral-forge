"""Shared Blender tooling for building the bosses: modelling helpers, rig, texture bake, export.

A boss is built from *pieces*; every piece belongs to one bone (rigid skinning, with joint
caps overlapping the seams) and becomes one MeshPart in Roblox. All pieces of a boss share one
texture atlas baked from procedural materials. The armature, its actions and the textured
pieces live in the .blend; what the game receives is
  * a GLB of the pieces (names "<Kind>_<piece>"), each centred on its own bounds, and
  * the skeleton + animation as data (bone rest heads, parent links, and per-frame
    parent-relative rotations sampled out of Blender).

Units: metres, +Z up, the character faces -Y (Blender's front view).
"""

import json
import math
import os
import re

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
OUT = os.path.join(ROOT, "assets", "generated", "bosses")
os.makedirs(OUT, exist_ok=True)

# Blender (x, y, z) -> glTF/Roblox (x, z, -y)
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))


def V(x, y, z):
    return Vector((x, y, z))


# --------------------------------------------------------------------------------------------
# Modelling
# --------------------------------------------------------------------------------------------

def _tag(faces, mat, smooth):
    for f in faces:
        f.material_index = mat
        f.smooth = smooth


def _faces_of(verts):
    out = []
    seen = set()
    for v in verts:
        for f in v.link_faces:
            if f.index not in seen:
                seen.add(f.index)
                out.append(f)
    return out


def _bevel(bm, verts, offset, segments=2):
    if offset <= 0:
        return
    faces = _faces_of(verts)
    edges = list({e for f in faces for e in f.edges})
    bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segments, affect="EDGES", profile=0.5)


def _align(direction):
    """Matrix turning +Z onto `direction`."""
    direction = Vector(direction).normalized()
    return Vector((0, 0, 1)).rotation_difference(direction).to_matrix().to_4x4()


def box(bm, center, size, mat=0, bevel=0.0, rot=None, smooth=False):
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    m = Matrix.Translation(center) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1)))
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    faces = _faces_of(verts)
    _tag(faces, mat, smooth)
    _bevel(bm, verts, bevel)
    return verts


def frustum(bm, p0, p1, r0, r1, sides=12, mat=0, caps=True, smooth=True, squash=1.0):
    """A tapered cylinder from p0 to p1 (radius r0 at p0, r1 at p1). `squash` flattens it
    front-to-back for plates and bracers."""
    p0, p1 = Vector(p0), Vector(p1)
    length = (p1 - p0).length
    res = bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=sides, radius1=r0, radius2=r1, depth=length)
    verts = res["verts"]
    m = Matrix.Translation((p0 + p1) / 2) @ _align(p1 - p0)
    if squash != 1.0:
        bmesh.ops.transform(bm, matrix=Matrix.Diagonal((1, squash, 1, 1)), verts=verts)
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    _tag(_faces_of(verts), mat, smooth)
    return verts


def ellipsoid(bm, center, radii, mat=0, segs=14, smooth=True, rot=None):
    res = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=max(6, segs // 2 + 1), radius=1.0)
    verts = res["verts"]
    m = Matrix.Translation(center) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal(Vector((radii[0], radii[1], radii[2], 1)))
    bmesh.ops.transform(bm, matrix=m, verts=verts)
    _tag(_faces_of(verts), mat, smooth)
    return verts


def plate(bm, outline, origin, u, v, thickness, mat=0, bevel=0.0, smooth=False):
    """A flat outline (list of (a, b) in the plane spanned by unit vectors u, v at `origin`)
    extruded `thickness` along u x v."""
    u, v = Vector(u).normalized(), Vector(v).normalized()
    n = u.cross(v).normalized()
    verts = [bm.verts.new(Vector(origin) + u * a + v * b) for a, b in outline]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    new_verts = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=n * thickness, verts=new_verts)
    all_verts = verts + new_verts
    bmesh.ops.recalc_face_normals(bm, faces=_faces_of(all_verts))
    _tag(_faces_of(all_verts), mat, smooth)
    _bevel(bm, all_verts, bevel, 1)
    return all_verts


def sweep(bm, path, radii, sides=8, mat=0, smooth=True, squash=1.0, closed_tip=True):
    """A tube along a polyline with a radius per point."""
    loops = []
    for i, (p, r) in enumerate(zip(path, radii)):
        p = Vector(p)
        t = (Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
        helper = Vector((0, 1, 0)) if abs(t.z) > 0.9 else Vector((0, 0, 1))
        side = t.cross(helper).normalized()
        up = side.cross(t).normalized()
        loop = []
        for k in range(sides):
            a = k / sides * math.tau
            loop.append(bm.verts.new(p + side * math.cos(a) * r + up * math.sin(a) * r * squash))
        loops.append(loop)
    for a, b in zip(loops, loops[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((a[k], a[j], b[j], b[k]))
    start = bm.faces.new(list(reversed(loops[0])))
    allv = [v for loop in loops for v in loop]
    if closed_tip:
        tip = bm.verts.new(Vector(path[-1]) + (Vector(path[-1]) - Vector(path[-2])).normalized() * radii[-1] * 0.6)
        for k in range(sides):
            bm.faces.new((loops[-1][k], loops[-1][(k + 1) % sides], tip))
        allv.append(tip)
    else:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=_faces_of(allv))
    _tag(_faces_of(allv), mat, smooth)
    return allv


def ribbon_strip(bm, left, right, thickness=0.03, mat=0, smooth=True):
    """A thin double-sided strip between two matching polylines (capes, banners)."""
    n = len(left)
    tv = [bm.verts.new(Vector(left[i])) for i in range(n)] + [bm.verts.new(Vector(right[i])) for i in range(n)]
    off = Vector((0, thickness, 0))
    bv = [bm.verts.new(Vector(left[i]) + off) for i in range(n)] + [bm.verts.new(Vector(right[i]) + off) for i in range(n)]
    for i in range(n - 1):
        bm.faces.new((tv[i], tv[i + 1], tv[n + i + 1], tv[n + i]))
        bm.faces.new((bv[n + i], bv[n + i + 1], bv[i + 1], bv[i]))
    for i in range(n - 1):
        bm.faces.new((tv[i], bv[i], bv[i + 1], tv[i + 1]))
        bm.faces.new((tv[n + i + 1], bv[n + i + 1], bv[n + i], tv[n + i]))
    allv = tv + bv
    bmesh.ops.recalc_face_normals(bm, faces=_faces_of(allv))
    _tag(_faces_of(allv), mat, smooth)
    return allv


def mirror_x(bm, verts):
    """Duplicate `verts` mirrored across X (for left/right pairs built once)."""
    faces = _faces_of(verts)
    geom = list(verts) + list({e for f in faces for e in f.edges}) + faces
    dup = bmesh.ops.duplicate(bm, geom=geom)
    new_verts = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.scale(bm, vec=Vector((-1, 1, 1)), verts=new_verts)
    new_faces = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.reverse_faces(bm, faces=new_faces)
    return new_verts


# --------------------------------------------------------------------------------------------
# The rig description
# --------------------------------------------------------------------------------------------

class Boss:
    def __init__(self, kind, material_names, atlas=2048):
        self.kind = kind
        self.material_names = material_names
        self.atlas = atlas
        self.bones = {}      # name -> dict(parent, head, tail)
        self.order = []
        self.pieces = {}     # name -> dict(bone, bm)
        self.physics = []    # simulated chains: dict(Kind, Bones, Group, Column, Settings)

    def bone(self, name, parent, head, tail):
        self.bones[name] = {"parent": parent, "head": Vector(head), "tail": Vector(tail)}
        self.order.append(name)

    def piece(self, name, bone):
        bm = bmesh.new()
        self.pieces[name] = {"bone": bone, "bm": bm}
        return bm

    def chain(self, kind, bones, group=None, column=0, **settings):
        """Declare a run of bones the game simulates (kind: cloth | wing | heavy). Bones of one group, in
        adjacent columns, are cross-linked so a multi-column cape moves as one sheet. settings override
        the kind's defaults (Gravity, Drag, Pull, Wind, Collide)."""
        for name in bones:
            assert name in self.bones, f"{self.kind}: physics chain names unknown bone {name}"
        self.physics.append({"Kind": kind, "Bones": list(bones), "Group": group or re.sub(r"\d+$", "", bones[0]), "Column": column, "Settings": settings})


# --------------------------------------------------------------------------------------------
# Scene objects: pieces, armature
# --------------------------------------------------------------------------------------------

def clear_boss(kind):
    for obj in list(bpy.data.objects):
        if obj.name.startswith(f"{kind}_") or obj.name == f"{kind}Rig" or obj.name == f"{kind}_ATLAS":
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def make_objects(boss):
    """Turn each piece's bmesh into a scene object (vertex group = its bone)."""
    objs = {}
    for name, info in boss.pieces.items():
        bm = info["bm"]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(f"{boss.kind}_{name}")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(f"{boss.kind}_{name}", mesh)
        bpy.context.collection.objects.link(obj)
        group = obj.vertex_groups.new(name=info["bone"])
        group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
        obj["piece"] = name
        obj["bone"] = info["bone"]
        objs[name] = obj
    return objs

def detail_pass(objs, bevel=0.015, subdiv=0, noise=0.0, cap=19500):
    """Make the blocky construction read as sculpted: optional subdivision (more surface to work with),
    a noise displacement for rough stone and ice, a bevel so every edge catches light, smooth shading
    broken at hard angles, and a decimate if a piece goes over what Roblox accepts in one MeshPart."""
    tex = None
    if noise > 0:
        tex = bpy.data.textures.get("BossNoise") or bpy.data.textures.new("BossNoise", "CLOUDS")
        tex.noise_scale = 0.35
        tex.noise_depth = 2
    for obj in objs.values():
        for o in bpy.context.selected_objects:
            o.select_set(False)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        stack = []
        if subdiv:
            m = obj.modifiers.new("DetailSub", "SUBSURF")
            m.subdivision_type = "SIMPLE"
            m.levels = subdiv
            m.render_levels = subdiv
            stack.append(m)
        if noise > 0 and tex is not None:
            m = obj.modifiers.new("DetailNoise", "DISPLACE")
            m.texture = tex
            m.strength = noise
            m.mid_level = 0.5
            stack.append(m)
        if bevel > 0:
            m = obj.modifiers.new("DetailBevel", "BEVEL")
            m.width = bevel
            m.segments = 2
            m.limit_method = "ANGLE"
            m.angle_limit = math.radians(35)
            stack.append(m)
        for m in stack:
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except RuntimeError:
                obj.modifiers.remove(m)
        faces = sum(len(poly.vertices) - 2 for poly in obj.data.polygons)   # triangles: Roblox's limit per MeshPart
        if faces > cap:
            m = obj.modifiers.new("DetailDecimate", "DECIMATE")
            m.ratio = cap / faces
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except RuntimeError:
                obj.modifiers.remove(m)
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(42))
        except Exception:
            bpy.ops.object.shade_smooth()

def make_armature(boss):
    arm_data = bpy.data.armatures.new(f"{boss.kind}Rig")
    rig = bpy.data.objects.new(f"{boss.kind}Rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name in boss.order:
        info = boss.bones[name]
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = info["head"], info["tail"]
        if (eb.tail - eb.head).length < 0.05:
            eb.tail = eb.head + Vector((0, 0, 0.1))
        if info["parent"]:
            eb.parent = arm_data.edit_bones[info["parent"]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, info in boss.pieces.items():
        obj = bpy.data.objects[f"{boss.kind}_{name}"]
        obj.parent = rig
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    return rig


# --------------------------------------------------------------------------------------------
# Procedural materials -> baked atlas
# --------------------------------------------------------------------------------------------

def _node(nodes, kind, x, y, **props):
    n = nodes.new(kind)
    n.location = (x, y)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def procedural_material(name, spec):
    """spec: dict(base=(r,g,b) or (a,b) dark/light pair, rough, noise, scale, emit=(r,g,b,strength),
    scratches, veins=(r,g,b)). Builds a node tree whose Base Color and Emission carry the look."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = _node(nt.nodes, "ShaderNodeOutputMaterial", 900, 0)
    bsdf = _node(nt.nodes, "ShaderNodeBsdfPrincipled", 600, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    texcoord = _node(nt.nodes, "ShaderNodeTexCoord", -900, 0)
    mapping = _node(nt.nodes, "ShaderNodeMapping", -700, 0)
    mapping.inputs["Scale"].default_value = (spec.get("scale", 6),) * 3
    nt.links.new(texcoord.outputs["Object"], mapping.inputs["Vector"])
    noise = _node(nt.nodes, "ShaderNodeTexNoise", -450, 120)
    noise.inputs["Scale"].default_value = spec.get("noise_scale", 4.0)
    noise.inputs["Detail"].default_value = 8.0
    noise.inputs["Roughness"].default_value = 0.6
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    voro = _node(nt.nodes, "ShaderNodeTexVoronoi", -450, -140)
    voro.feature = "DISTANCE_TO_EDGE"
    voro.inputs["Scale"].default_value = spec.get("voro_scale", 5.0)
    nt.links.new(mapping.outputs["Vector"], voro.inputs["Vector"])
    ramp = _node(nt.nodes, "ShaderNodeValToRGB", -200, 120)
    dark = spec["base"][0] if isinstance(spec["base"][0], (tuple, list)) else spec["base"]
    light = spec["base"][1] if isinstance(spec["base"][0], (tuple, list)) else tuple(min(1, c * 1.6 + 0.02) for c in spec["base"])
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    color_out = ramp.outputs["Color"]
    if spec.get("veins"):
        vein_ramp = _node(nt.nodes, "ShaderNodeValToRGB", -200, -140)
        vein_ramp.color_ramp.elements[0].position = 0.0
        vein_ramp.color_ramp.elements[0].color = (*spec["veins"], 1)
        vein_ramp.color_ramp.elements[1].position = spec.get("vein_width", 0.06)
        vein_ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
        nt.links.new(voro.outputs["Distance"], vein_ramp.inputs["Fac"])
        mix = _node(nt.nodes, "ShaderNodeMix", 100, 60)
        mix.data_type = "RGBA"
        mix.blend_type = "ADD"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(color_out, mix.inputs["A"])
        nt.links.new(vein_ramp.outputs["Color"], mix.inputs["B"])
        color_out = mix.outputs["Result"]
        if spec.get("veins_glow", 0):
            nt.links.new(vein_ramp.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = spec["veins_glow"]
    nt.links.new(color_out, bsdf.inputs["Base Color"])
    # what the viewport / fast previews show (the bake replaces it with the real texture)
    swatch = spec["base"][1] if isinstance(spec["base"][0], (tuple, list)) else spec["base"]
    glow = spec.get("emit")
    mat.diffuse_color = ((*glow[:3], 1) if glow else (*[min(1.0, c * 1.1) for c in swatch], 1))
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.6)
    bsdf.inputs["Metallic"].default_value = 0.0  # albedo-only bake: metallic would turn the diffuse pass black
    if spec.get("emit"):
        r, g, b, s = spec["emit"]
        bsdf.inputs["Emission Color"].default_value = (r, g, b, 1)
        bsdf.inputs["Emission Strength"].default_value = s
    return mat


def assign_materials(objs, materials):
    for obj in objs.values():
        # (clearing slots would reset every face's material index, so only append)
        for mat in materials:
            obj.data.materials.append(mat)


def join_for_atlas(boss, objs):
    """Join copies of every piece, unwrap once, so all pieces share one UV layout."""
    copies = []
    for name, obj in objs.items():
        dup = obj.copy()
        dup.data = obj.data.copy()
        dup.modifiers.clear()
        dup.hide_render = False
        dup.hide_viewport = False
        dup.hide_set(False)
        bpy.context.collection.objects.link(dup)
        # remember which piece each face came from
        attr = dup.data.attributes.new("piece_id", "INT", "FACE")
        idx = list(objs).index(name)
        attr.data.foreach_set("value", [idx] * len(dup.data.polygons))
        copies.append(dup)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for c in copies:
        c.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    atlas = bpy.context.view_layer.objects.active
    atlas.name = f"{boss.kind}_ATLAS"
    return atlas


def unwrap(atlas):
    bpy.context.view_layer.objects.active = atlas
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, area_weight=0.0)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_atlas(boss, atlas, passes=("DIFFUSE", "EMIT", "AO")):
    """Bake colour, emission and AO of the atlas into numpy arrays and combine them."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    size = boss.atlas
    results = {}
    for kind in passes:
        img = bpy.data.images.get(f"{boss.kind}_{kind}") or bpy.data.images.new(f"{boss.kind}_{kind}", size, size, alpha=False)
        img.scale(size, size)
        # a target image node in every material
        for mat in atlas.data.materials:
            nt = mat.node_tree
            node = nt.nodes.get("BAKE_TARGET") or nt.nodes.new("ShaderNodeTexImage")
            node.name = "BAKE_TARGET"
            node.image = img
            nt.nodes.active = node
        bpy.context.view_layer.objects.active = atlas
        for o in bpy.context.selected_objects:
            o.select_set(False)
        atlas.select_set(True)
        if kind == "DIFFUSE":
            bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8, use_clear=True)
        elif kind == "EMIT":
            bpy.ops.object.bake(type="EMIT", margin=8, use_clear=True)
        else:
            scene.cycles.samples = 24
            bpy.ops.object.bake(type="AO", margin=8, use_clear=True)
            scene.cycles.samples = 12
        results[kind] = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)[..., :3]
    sample = next(iter(results.values()))
    diffuse = results.get("DIFFUSE", np.zeros_like(sample))
    ao = results.get("AO", np.ones_like(sample))
    emit = results.get("EMIT", np.zeros_like(sample))
    combined = np.clip(diffuse * (0.65 + 0.35 * ao) * 1.3 + emit, 0, 1)  # Roblox lights textures down, so bake bright
    # Roblox shows mesh textures at most 1024 across: bake big, hand over the 2x2-averaged copy
    half = size // 2
    combined = combined.reshape(half, 2, half, 2, 3).mean(axis=(1, 3))
    final = bpy.data.images.get(f"{boss.kind}_ATLAS_TEX") or bpy.data.images.new(f"{boss.kind}_ATLAS_TEX", half, half, alpha=False)
    final.scale(half, half)
    rgba = np.dstack([combined, np.ones(combined.shape[:2], dtype=np.float32)])
    final.pixels = rgba.flatten().tolist()
    path = os.path.join(OUT, f"{boss.kind}_atlas.png")
    final.filepath_raw = path
    final.file_format = "PNG"
    final.save()
    return final, path


def split_atlas(boss, atlas, objs, final_image):
    """Give each original piece its slice of the atlas UVs and the baked texture."""
    ids = list(objs)
    mat = bpy.data.materials.new(f"{boss.kind}_baked")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = final_image
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    bsdf.inputs["Metallic"].default_value = 0.0
    bm_all = bmesh.new()
    bm_all.from_mesh(atlas.data)
    uv_layer = bm_all.loops.layers.uv.active
    piece_layer = bm_all.faces.layers.int.get("piece_id")
    for idx, name in enumerate(ids):
        obj = objs[name]
        bm = bm_all.copy()
        pl = bm.faces.layers.int.get("piece_id")
        doomed = [f for f in bm.faces if f[pl] != idx]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.verts.ensure_lookup_table()
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        mesh = obj.data
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        # vertex group and material
        obj.vertex_groups.clear()
        group = obj.vertex_groups.new(name=obj["bone"])
        group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
        mesh.materials.clear()
        mesh.materials.append(mat)
        for poly in mesh.polygons:
            poly.material_index = 0
    bm_all.free()
    return mat


# --------------------------------------------------------------------------------------------
# Pose + animation
# --------------------------------------------------------------------------------------------

def rot_matrix(pitch, yaw, roll_out, side):
    """Semantic rotation (pitch about X, yaw about Z, roll about Y; roll_out > 0 swings
    outward, `side` = +1 for the +X (left) side, -1 for the right) as a 3x3 in Blender axes."""
    rx = Matrix.Rotation(pitch, 3, "X")
    rz = Matrix.Rotation(yaw, 3, "Z")
    ry = Matrix.Rotation(-side * roll_out, 3, "Y")
    return rz @ ry @ rx


def apply_pose(boss, rig, pose):
    """`pose` maps bone -> (pitch, yaw, roll_out) parent-relative. Forward kinematics: each
    bone rotates about its own rest head, inside its parent's motion."""
    arm = rig
    absolute = {}   # bone -> 4x4 armature-space delta transform
    for name in boss.order:
        info = boss.bones[name]
        head = info["head"]
        side = 1 if head.x >= 0 else -1
        p, y, r = pose.get(name, (0, 0, 0))
        local = Matrix.Translation(head) @ rot_matrix(p, y, r, side).to_4x4() @ Matrix.Translation(-head)
        parent = info["parent"]
        absolute[name] = (absolute[parent] @ local) if parent else local
    # Each bone's local transform is solved from the desired armature-space matrices of itself and its parent.
    # (Assigning pb.matrix bone by bone reads the parent's *stale* pose matrix until the dependency graph
    # refreshes, which scrambles every child; this does not depend on evaluation order.)
    for name in boss.order:
        pb = arm.pose.bones[name]
        rest = arm.data.bones[name].matrix_local
        wanted = absolute[name] @ rest
        parent = boss.bones[name]["parent"]
        if parent:
            parent_rest = arm.data.bones[parent].matrix_local
            parent_wanted = absolute[parent] @ parent_rest
            local_rest = parent_rest.inverted() @ rest
            local_pose = parent_wanted.inverted() @ wanted
            pb.matrix_basis = local_rest.inverted() @ local_pose
        else:
            pb.matrix_basis = rest.inverted() @ wanted


def key_pose(boss, rig, frame):
    for name in boss.order:
        pb = rig.pose.bones[name]
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def sample_clip(boss, rig, action, length, fps):
    """Read the action back out of Blender: parent-relative rotation (armature axes) of each
    bone per frame, converted to Roblox axes as Euler XYZ (CFrame.Angles order)."""
    scene = bpy.context.scene
    rig.animation_data.action = action
    frames = int(round(length * fps)) + 1
    tracks = {name: [] for name in boss.order}
    for f in range(frames):
        scene.frame_set(1 + int(round(f * 24 / fps)))
        abs_rot = {}
        for name in boss.order:
            pb = rig.pose.bones[name]
            rest = rig.data.bones[name].matrix_local
            abs_rot[name] = (pb.matrix @ rest.inverted()).to_3x3()
        for name in boss.order:
            parent = boss.bones[name]["parent"]
            rel = (abs_rot[parent].inverted() @ abs_rot[name]) if parent else abs_rot[name]
            rb = C @ rel @ C.inverted()
            e = rb.to_euler("ZYX")  # R = Rx * Ry * Rz, Roblox's CFrame.Angles order
            tracks[name].extend([round(e.x, 2), round(e.y, 2), round(e.z, 2)])
    scene.frame_set(1)
    return tracks


def rest_data(boss, objs):
    """Skeleton and piece placement in Roblox axes, relative to the first piece's centre."""
    ref = None
    centers = {}
    for name, obj in objs.items():
        pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        centers[name] = (lo + hi) / 2
    ref = centers[next(iter(objs))]
    def conv(v):
        r = C @ Vector(v)
        return [round(r.x, 3), round(r.y, 3), round(r.z, 3)]
    data = {"ref": next(iter(objs)), "bones": {}, "pieces": {}, "physics": {"chains": boss.physics}}
    for name in boss.order:
        info = boss.bones[name]
        data["bones"][name] = {"parent": info["parent"], "head": conv(info["head"] - ref)}
    for name, obj in objs.items():
        data["pieces"][name] = {"bone": obj["bone"], "center": conv(centers[name] - ref)}
    return data


# --------------------------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------------------------

def export_glb(boss, objs, path=None):
    for name, obj in objs.items():
        for o in bpy.context.selected_objects:
            o.select_set(False)
    # pieces at rest, origin at bounds centre, no armature / modifiers in the file
    export = []
    for name, obj in objs.items():
        obj.parent = None
        obj.modifiers.clear()
        obj.matrix_world = Matrix.Identity(4)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        export.append(obj)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in export:
        o.select_set(True)
    path = path or os.path.join(OUT, f"{boss.kind}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_materials="EXPORT", export_image_format="AUTO", export_yup=True)
    return path


# --------------------------------------------------------------------------------------------
# Preview renders (Workbench: needs no GPU, so it works in a headless run)
# --------------------------------------------------------------------------------------------

def render_preview(kind, objs, views=("front", "side", "back", "three"), size=(900, 1100), tag="", textured=False):
    """Render the posed pieces from a few angles into assets/generated/bosses/previews/."""
    scene = bpy.context.scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in objs.values():
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            p = ev.matrix_world @ v.co
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
        ev.to_mesh_clear()
    centre = (lo + hi) / 2
    extent = max(hi.x - lo.x, hi.z - lo.z, (hi.y - lo.y)) * 1.12
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE" if textured else "MATERIAL"
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_shadows = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.30, 0.31, 0.38)
    cam_data = bpy.data.cameras.get("PreviewCam") or bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = extent * (size[1] / size[0] if size[1] > size[0] else 1.0)
    cam_data.clip_end = 200
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    out_dir = os.path.join(OUT, "previews")
    os.makedirs(out_dir, exist_ok=True)
    spots = {
        "front": Vector((0, -1, 0.05)), "side": Vector((1, 0, 0.05)), "back": Vector((0, 1, 0.05)),
        "three": Vector((0.7, -0.7, 0.25)), "back34": Vector((-0.7, 0.7, 0.25)),
    }
    paths = []
    for view in views:
        direction = spots[view].normalized()
        cam.location = centre + direction * 60
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out_dir, f"{kind}{tag}_{view}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths
