"""Headless check of the pose maths: raise a boss's left arm forward by a known angle and verify the
hand really goes forward and up, by the amount geometry says.

    blender -b --python tools/bossbuild/test_pose.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
sys.path.insert(0, os.path.join(ROOT, "tools", "bossbuild"))

import importlib

import lib

importlib.reload(lib)
import knight

for stray in ("Cube", "Light", "Camera"):
    if stray in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[stray], do_unlink=True)
lib.clear_boss("Knight")
boss = knight.build()
objs = lib.make_objects(boss)
rig = lib.make_armature(boss)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")


def centre(name):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    obj = objs[name].evaluated_get(depsgraph)
    mesh = obj.to_mesh()
    pts = [obj.matrix_world @ v.co for v in mesh.vertices]
    obj.to_mesh_clear()
    return sum(pts, Vector()) / len(pts)


def settle(pose):
    lib.apply_pose(boss, rig, pose)
    bpy.context.view_layer.update()


settle({})
rest = {name: centre(name) for name in ("handL", "lowerArmL", "sword", "handR", "footL")}
head = boss.bones["upperArmL"]["head"]
angle = -1.0                          # pitch is negative to raise an arm forward
settle({"upperArmL": (angle, 0, 0)})
after = {name: centre(name) for name in rest}
hand = after["handL"] - head
was = rest["handL"] - head
# rotating about X by `angle`: y' = y cos - z sin ; z' = y sin + z cos
expect = Vector((was.x, was.y * math.cos(angle) - was.z * math.sin(angle), was.y * math.sin(angle) + was.z * math.cos(angle)))
error = (hand - expect).length
print(f"[pose test] hand moved {rest['handL']} -> {after['handL']}; expected offset {expect}, got {hand}, error {error:.4f} m")
forward = after["handL"].y < rest["handL"].y - 0.3
up = after["handL"].z > rest["handL"].z + 0.3
print(f"[pose test] forward={forward} up={up}")
other = (after["footL"] - rest["footL"]).length
print(f"[pose test] untouched bones stay put: footL moved {other:.5f} m")
# the sword hangs off the right hand: pitch the RIGHT arm and the sword must follow the hand rigidly
settle({"upperArmR": (-1.2, 0, 0), "lowerArmR": (-0.5, 0, 0)})
hand_r = centre("handR")
sword_r = centre("sword")
settle({})
hand0, sword0 = centre("handR"), centre("sword")
print(f"[pose test] sword-to-hand distance at rest {(sword0 - hand0).length:.3f}, posed {(sword_r - hand_r).length:.3f} (should match: rigid)")
ok = error < 0.02 and forward and up and other < 1e-3 and abs((sword_r - hand_r).length - (sword0 - hand0).length) < 0.02
print("[pose test] PASS" if ok else "[pose test] FAIL")
