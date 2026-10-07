"""Purpose: Beveled, palette-bound mesh primitives for bespoke arcade assets.
Owner: Astral Forge art. Dependencies: Blender bpy/mathutils. Last-reviewed: 2026-10-05.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PALETTE = json.loads((ROOT / "audit/baseline/color-inventory.json").read_text())["basePalette"]
MATERIALS: dict[str, bpy.types.Material] = {}


def linear(channel: int) -> float:
    value = channel / 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def material(color: str, metal: bool = False, glow: bool = False) -> bpy.types.Material:
    key = f"{color}:{metal}:{glow}"
    if key in MATERIALS:
        return MATERIALS[key]
    value = bpy.data.materials.new(key)
    value.use_nodes = True
    rgb = tuple(linear(channel) for channel in PALETTE[color])
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = 0.72 if metal else 0
    shader.inputs["Roughness"].default_value = 0.24 if metal else 0.42
    if glow:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = 2.0
    value.diffuse_color = (*rgb, 1)
    MATERIALS[key] = value
    return value


def finish(obj: bpy.types.Object, name: str, color: str, bevel: float = 0,
           metal: bool = False, glow: bool = False, group: str = "Body") -> bpy.types.Object:
    obj.name = name
    obj["rig_group"] = group
    obj.data.materials.append(material(color, metal, glow))
    if bevel:
        modifier = obj.modifiers.new("Machined edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def box(name: str, at: tuple[float, float, float], size: tuple[float, float, float],
        color: str, bevel: float = 0.06, metal: bool = False,
        glow: bool = False, group: str = "Body") -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, color, bevel, metal, glow, group)


def cylinder(name: str, at: tuple[float, float, float], radius: float, depth: float,
             color: str, rotation: tuple[float, float, float] = (0, 0, 0),
             group: str = "Body", metal: bool = False, vertices: int = 32) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=at, rotation=rotation)
    return finish(bpy.context.object, name, color, 0.025, metal, False, group)


def sphere(name: str, at: tuple[float, float, float], radius: float, color: str,
           group: str = "Body", metal: bool = False) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=at)
    return finish(bpy.context.object, name, color, 0, metal, False, group)


def ring(name: str, at: tuple[float, float, float], radius: float, thickness: float,
         color: str, rotation: tuple[float, float, float] = (0, 0, 0),
         group: str = "Body") -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=8, location=at,
                                  major_radius=radius, minor_radius=thickness, rotation=rotation)
    return finish(bpy.context.object, name, color, 0, True, False, group)


def beam(name: str, start: tuple[float, float, float], end: tuple[float, float, float],
         radius: float, color: str, group: str = "Body", glow: bool = False) -> bpy.types.Object:
    a, b = Vector(start), Vector(end)
    center = (a + b) / 2
    obj = cylinder(name, tuple(center), radius, (b - a).length, color, group=group, vertices=12)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    if glow:
        obj.data.materials.clear()
        obj.data.materials.append(material(color, glow=True))
    return obj


def text(name: str, value: str, at: tuple[float, float, float], size: float, color: str,
         rotation: tuple[float, float, float] = (math.pi / 2, 0, 0), group: str = "Body") -> bpy.types.Object:
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = value
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.003
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location, obj.rotation_euler = at, rotation
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    return finish(obj, name, color, 0, False, False, group)


def chip(name: str, at: tuple[float, float, float], radius: float, color: str, group: str = "Body") -> None:
    cylinder(name, at, radius, 0.10, color, group=group)
    ring(name + " rim", (at[0], at[1], at[2] + 0.06), radius * 0.80, 0.015, "cream", group=group)


def card(name: str, at: tuple[float, float, float], rank: str, suit: str,
         color: str = "coral", group: str = "Body", angle: float = 0) -> None:
    slab = box(name, at, (0.82, 1.12, 0.025), "cream", 0.035, group=group)
    slab.rotation_euler.z = angle
    # Mesh lettering remains visible inside ViewportFrames, unlike SurfaceGui text.
    text(name + " rank", rank, (at[0] - 0.25, at[1] + 0.38, at[2] + 0.02), 0.16, color, rotation=(0, 0, angle), group=group)
    text(name + " suit", suit, (at[0], at[1], at[2] + 0.025), 0.34, color, rotation=(0, 0, angle), group=group)
