"""Texture the boss VFX meshes in Blender and re-export BossVfxKit.glb with one baked atlas.

    python tools/assetgen/blender_rpc.py run tools/bossbuild/vfx_bake.py

Starts from the 18 meshes of blender_bossvfx.py (loaded from assets/generated/BossVfxKit.glb if
the scene does not already hold them), gives each boss's three meshes a pattern of its own,
unwraps them into one atlas and bakes it. The patterns are bright, near-greyscale detail so the
game can still tint every effect with the boss colour:

  Warden  dark rift cracks      Choir   streaked glass light     Regent  ember gradient, bright tips
  Seraph  fine storm striping   Rime    faceted crystal cells    Knight  hard edge highlights
"""

import importlib
import math
import os
import sys

import bpy

ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
sys.path.insert(0, os.path.join(ROOT, "tools", "bossbuild"))
import lib

importlib.reload(lib)

PREFIX_STYLE = {"W": "cracks", "C": "streaks", "R": "ember", "S": "storm", "I": "cells", "K": "edge"}
STYLES = ["cracks", "streaks", "ember", "storm", "cells", "edge"]


def style_material(style):
    mat = bpy.data.materials.get(f"VFX_{style}") or bpy.data.materials.new(f"VFX_{style}")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")

    def noise(scale, detail=6.0, stretch=None):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        if stretch is not None:
            mp = nt.nodes.new("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = stretch
            nt.links.new(coord.outputs["Object"], mp.inputs["Vector"])
            nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        else:
            nt.links.new(coord.outputs["Object"], n.inputs["Vector"])
        return n

    if style == "cracks":
        v = nt.nodes.new("ShaderNodeTexVoronoi")
        v.feature = "DISTANCE_TO_EDGE"
        v.inputs["Scale"].default_value = 0.9
        nt.links.new(coord.outputs["Object"], v.inputs["Vector"])
        ramp.color_ramp.elements[0].position = 0.0
        ramp.color_ramp.elements[0].color = (0.12, 0.12, 0.12, 1)
        ramp.color_ramp.elements[1].position = 0.12
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(v.outputs["Distance"], ramp.inputs["Fac"])
    elif style == "streaks":
        n = noise(2.0, 5.0, stretch=(0.15, 3.0, 0.15))
        ramp.color_ramp.elements[0].color = (0.55, 0.62, 0.7, 1)
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(n.outputs["Fac"], ramp.inputs["Fac"])
    elif style == "ember":
        # dark at the base of the shape, white-hot at the tips, flicker through it
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = -5.0
        mr.inputs["From Max"].default_value = 5.0
        nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
        n = noise(1.5, 4.0)
        mix = nt.nodes.new("ShaderNodeMath")
        mix.operation = "ADD"
        nt.links.new(mr.outputs["Result"], mix.inputs[0])
        nt.links.new(n.outputs["Fac"], mix.inputs[1])
        mix.inputs[1].default_value = 0.0
        scale = nt.nodes.new("ShaderNodeMath")
        scale.operation = "MULTIPLY"
        scale.inputs[1].default_value = 0.7
        nt.links.new(mix.outputs["Value"], scale.inputs[0])
        ramp.color_ramp.elements[0].color = (0.25, 0.2, 0.2, 1)
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(scale.outputs["Value"], ramp.inputs["Fac"])
    elif style == "storm":
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.inputs["Scale"].default_value = 3.0
        wave.inputs["Distortion"].default_value = 4.0
        nt.links.new(coord.outputs["Object"], wave.inputs["Vector"])
        ramp.color_ramp.elements[0].color = (0.45, 0.55, 0.7, 1)
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    elif style == "cells":
        v = nt.nodes.new("ShaderNodeTexVoronoi")
        v.feature = "F1"
        v.inputs["Scale"].default_value = 0.8
        nt.links.new(coord.outputs["Object"], v.inputs["Vector"])
        ramp.color_ramp.elements[0].color = (0.5, 0.65, 0.8, 1)
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(v.outputs["Distance"], ramp.inputs["Fac"])
    else:  # edge
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = -5.0
        mr.inputs["From Max"].default_value = 5.0
        nt.links.new(sep.outputs["X"], mr.inputs["Value"])
        absn = nt.nodes.new("ShaderNodeMath")
        absn.operation = "SUBTRACT"
        absn.inputs[1].default_value = 0.5
        nt.links.new(mr.outputs["Result"], absn.inputs[0])
        ab = nt.nodes.new("ShaderNodeMath")
        ab.operation = "ABSOLUTE"
        nt.links.new(absn.outputs["Value"], ab.inputs[0])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = 2.0
        nt.links.new(ab.outputs["Value"], mul.inputs[0])
        ramp.color_ramp.elements[0].color = (0.4, 0.38, 0.45, 1)
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(mul.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    emit.inputs["Strength"].default_value = 1.0
    return mat


def load_meshes():
    names = [o.name for o in bpy.data.objects if o.type == "MESH" and len(o.name) > 2 and o.name[1] == "_" and o.name[0] in PREFIX_STYLE]
    if len(names) >= 18:
        return {n: bpy.data.objects[n] for n in sorted(names)}
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "generated", "BossVfxKit.glb"))
    objs = {o.name: o for o in bpy.data.objects if o.type == "MESH" and len(o.name) > 2 and o.name[1] == "_" and o.name[0] in PREFIX_STYLE}
    for o in objs.values():
        o.parent = None
    return dict(sorted(objs.items()))


def main():
    objs = load_meshes()
    boss = lib.Boss("VfxKit", STYLES)
    materials = [style_material(s) for s in STYLES]
    for name, obj in objs.items():
        obj.data.materials.clear()
        for m in materials:
            obj.data.materials.append(m)
        style = STYLES.index(PREFIX_STYLE[name[0]])
        for poly in obj.data.polygons:
            poly.material_index = style
        obj["bone"] = "x"
        obj["piece"] = name
    for o in bpy.data.objects:
        o.hide_set(False)
    atlas = lib.join_for_atlas(boss, objs)
    lib.unwrap(atlas)
    final, path = lib.bake_atlas(boss, atlas, passes=("EMIT",))
    lib.split_atlas(boss, atlas, objs, final)
    bpy.data.objects.remove(atlas, do_unlink=True)
    glb = lib.export_glb(boss, objs, os.path.join(ROOT, "assets", "generated", "BossVfxKit.glb"))
    print("textured VFX kit ->", glb)


main()
