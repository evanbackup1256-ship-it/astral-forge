"""Render the bosses' particle textures in Blender.

Run inside a live Blender (BlenderMCP add-on) or headless:

    python tools/assetgen/blender_rpc.py run tools/assetgen/blender_bosstex.py
    blender -b --python tools/assetgen/blender_bosstex.py

Twelve soft-glow sprites, two per boss, rendered as transparent PNGs in
assets/generated/bosstex/ (plus bosstex_sheet.png, a contact sheet to look at):

  Warden  rune_glyph, void_wisp      Choir  note, ripple        Regent  flame_lick, ember
  Seraph  spark_streak, feather      Rime   snowflake, ice_shard   Knight  slash, shadow_wisp

Each shape is modelled as flat geometry, rendered white on transparent with the workbench
engine, then given its glow in numpy (a wide and a tight blur added back into the alpha).
Upload with upload_boss_tex.py.
"""

import math
import os

import bmesh
import bpy
import numpy as np

ROOT = r"C:\Users\evanm\OneDrive\Desktop\Astral Forge v2\.claude\worktrees\zealous-tu-ff9875"
try:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
except NameError:
    pass
OUT = os.path.join(ROOT, "assets", "generated", "bosstex")
SIZE = 256
TAU = math.tau
os.makedirs(OUT, exist_ok=True)


# --- geometry helpers (everything lives in the XY plane, roughly -5..5) -----------------------

def polygon(points, name="TMP"):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0)) for x, y in points]
    try:
        bm.faces.new(verts)
    except ValueError:
        pass
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def rot(point, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (point[0] * c - point[1] * s, point[0] * s + point[1] * c)


def bar(cx, cy, length, width, angle):
    half_l, half_w = length / 2, width / 2
    pts = [(-half_l, -half_w), (half_l, -half_w), (half_l, half_w), (-half_l, half_w)]
    return polygon([(rot(p, angle)[0] + cx, rot(p, angle)[1] + cy) for p in pts])


def ring(radius, width, start=0.0, end=TAU, steps=64):
    outer = [(math.cos(start + (end - start) * i / steps) * radius, math.sin(start + (end - start) * i / steps) * radius) for i in range(steps + 1)]
    inner = [(math.cos(start + (end - start) * i / steps) * (radius - width), math.sin(start + (end - start) * i / steps) * (radius - width)) for i in range(steps, -1, -1)]
    return polygon(outer + inner)


def ribbon(path, widths):
    left, right = [], []
    for i, (x, y) in enumerate(path):
        nx, ny = path[min(i + 1, len(path) - 1)]
        px, py = path[max(i - 1, 0)]
        dx, dy = nx - px, ny - py
        length = math.hypot(dx, dy) or 1
        ox, oy = -dy / length * widths[i], dx / length * widths[i]
        left.append((x + ox, y + oy))
        right.append((x - ox, y - oy))
    return polygon(left + list(reversed(right)))


def ellipse(cx, cy, rx, ry, angle=0.0, steps=32):
    return polygon([(rot((math.cos(i / steps * TAU) * rx, math.sin(i / steps * TAU) * ry), angle)[0] + cx, rot((math.cos(i / steps * TAU) * rx, math.sin(i / steps * TAU) * ry), angle)[1] + cy) for i in range(steps)])


# --- the twelve shapes -------------------------------------------------------------------------

def rune_glyph():
    ring(4.6, 0.28)
    ring(3.3, 0.2)
    for k in range(8):
        a = k / 8 * TAU
        bar(math.cos(a) * 3.95, math.sin(a) * 3.95, 0.7, 0.16, a)
    bar(0, 0, 3.0, 0.3, math.pi / 2)
    bar(0, 0.6, 2.0, 0.26, 0)
    bar(-0.9, -1.0, 1.6, 0.24, math.radians(50))
    bar(0.9, -1.0, 1.6, 0.24, math.radians(-50))


def void_wisp():
    path = [(math.cos(t * 3.2 + 1.0) * (3.8 * (1 - t) + 0.2), math.sin(t * 3.2 + 1.0) * (3.8 * (1 - t) + 0.2) * 0.9) for t in [i / 40 for i in range(41)]]
    ribbon(path, [0.05 + 0.75 * math.sin(i / 40 * math.pi) ** 0.7 * (1 - i / 60) for i in range(41)])
    ellipse(0, 0, 0.9, 0.9)


def note():
    ellipse(-1.4, -3.0, 1.45, 1.05, math.radians(20))
    bar(0.0, -0.4, 5.6, 0.34, math.pi / 2)
    ribbon([(0.0, 2.4), (1.2, 1.7), (2.2, 0.5), (2.4, -0.9)], [0.2, 0.55, 0.5, 0.18])


def ripple():
    for radius, width in ((4.7, 0.35), (3.5, 0.25), (2.4, 0.2), (1.4, 0.16)):
        ring(radius, width)


def flame_lick():
    steps = 36
    path = [(math.sin(i / steps * 2.8) * 1.1 * (i / steps) ** 1.4, -4.6 + i / steps * 9.6) for i in range(steps + 1)]
    widths = [2.3 * (1 - i / steps) ** 0.75 * math.sin(min(i / steps * 1.8, 1.0) * math.pi / 2) + 0.02 for i in range(steps + 1)]
    ribbon(path, widths)
    side = [(-1.5 + math.sin(i / 20 * 2.0) * 0.5, -3.6 + i / 20 * 5.0) for i in range(21)]
    ribbon(side, [1.0 * (1 - i / 20) ** 0.8 * math.sin(min(i / 20 * 2.0, 1.0) * math.pi / 2) + 0.02 for i in range(21)])

def ember():
    polygon([(0, 4.8), (0.45, 0.45), (3.0, 0), (0.45, -0.45), (0, -4.8), (-0.45, -0.45), (-3.0, 0), (-0.45, 0.45)])
    ellipse(0, 0, 1.0, 1.0)


def spark_streak():
    pts = [(-4.8, 0.0), (-3.2, 0.8), (-2.0, -0.6), (-0.8, 0.9), (0.4, -0.7), (1.8, 0.7), (3.0, -0.3), (4.8, 0.0)]
    ribbon(pts, [0.04, 0.2, 0.3, 0.34, 0.3, 0.22, 0.12, 0.03])
    ribbon([(-0.8, 0.9), (0.0, 2.4), (0.6, 3.6)], [0.18, 0.12, 0.03])


def feather():
    pts = []
    for i in range(24):
        t = i / 23
        pts.append((t * 9.0 - 4.5, math.sin(t * math.pi) ** 0.8 * 1.6 * (1 - 0.3 * t) + 0.05 * math.sin(t * 30)))
    polygon(pts + [(x, -y) for x, y in reversed(pts)])
    bar(0.3, 0, 9.4, 0.12, 0)


def snowflake():
    ellipse(0, 0, 0.7, 0.7, steps=6)
    for arm in range(6):
        a = arm / 6 * TAU
        bar(math.cos(a) * 2.5, math.sin(a) * 2.5, 5.0, 0.28, a)
        for at, length in ((1.7, 1.7), (3.0, 1.2)):
            for sign in (-1, 1):
                direction = a + sign * math.radians(55)
                bar(math.cos(a) * at + math.cos(direction) * length / 2, math.sin(a) * at + math.sin(direction) * length / 2, length, 0.2, direction)


def ice_shard():
    polygon([(0, 4.9), (1.1, 1.2), (0.7, -3.2), (0, -4.9), (-0.7, -3.2), (-1.1, 1.2)])
    bar(0, 0.4, 0.14, 7.0, 0)


def slash():
    outer = [(math.cos(math.radians(-105 + 210 * i / 30)) * 5, math.sin(math.radians(-105 + 210 * i / 30)) * 5) for i in range(31)]
    inner = [(math.cos(math.radians(-105 + 210 * i / 30)) * (5 - 2.2 * math.sin(i / 30 * math.pi) ** 0.9), math.sin(math.radians(-105 + 210 * i / 30)) * (5 - 2.2 * math.sin(i / 30 * math.pi) ** 0.9)) for i in range(30, -1, -1)]
    polygon(outer + inner[1:-1])


def shadow_wisp():
    path = [(math.cos(t * 5.0) * (0.4 + 3.4 * t), math.sin(t * 5.0) * (0.4 + 3.4 * t) - 1.0) for t in [i / 50 for i in range(51)]]
    ribbon(path, [0.5 * (1 - i / 50) ** 0.8 + 0.03 for i in range(51)])
    ribbon([(0, 0), (-1.0, 2.4), (-0.4, 4.4)], [0.5, 0.25, 0.03])


SHAPES = [
    ("rune_glyph", rune_glyph), ("void_wisp", void_wisp), ("note", note), ("ripple", ripple),
    ("flame_lick", flame_lick), ("ember", ember), ("spark_streak", spark_streak), ("feather", feather),
    ("snowflake", snowflake), ("ice_shard", ice_shard), ("slash", slash), ("shadow_wisp", shadow_wisp),
]


# --- rendering ---------------------------------------------------------------------------------

def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1, 1, 1)
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.get("TEXCAM")
    if cam is None:
        cam = bpy.data.objects.new("TEXCAM", bpy.data.cameras.new("TEXCAM"))
        bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 11.0
    cam.location = (0, 0, 30)
    cam.rotation_euler = (0, 0, 0)
    scene.camera = cam


def gaussian(image, sigma):
    spectrum = np.fft.rfft2(image)
    fy = np.fft.fftfreq(image.shape[0])[:, None]
    fx = np.fft.rfftfreq(image.shape[1])[None, :]
    kernel = np.exp(-2 * (math.pi * sigma) ** 2 * (fx**2 + fy**2))
    return np.fft.irfft2(spectrum * kernel, s=image.shape)


def render_shape(name, build):
    # nothing but this sprite may be in the picture (the open scene may hold other models)
    for obj in bpy.data.objects:
        if not obj.name.startswith("TMP") and obj.type in {"MESH", "LIGHT"}:
            obj.hide_render = True
    for obj in [o for o in bpy.data.objects if o.name.startswith("TMP")]:
        bpy.data.objects.remove(obj, do_unlink=True)
    build()
    path = os.path.join(OUT, f"_{name}.png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    pixels = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    alpha = pixels[..., 3]
    glow = gaussian(alpha, 9) * 0.9 + gaussian(alpha, 3.5) * 0.6
    out_alpha = np.clip(alpha * 0.92 + glow, 0, 1)
    if name == "ripple":
        yy, xx = np.mgrid[0:SIZE, 0:SIZE]
        radius = np.hypot(xx - SIZE / 2, yy - SIZE / 2) / (SIZE / 2)
        out_alpha *= np.clip(1.15 - radius, 0, 1) ** 0.6
    # keep the edge of the image clear so a sprite never shows a square
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    edge = np.minimum.reduce([xx, yy, SIZE - 1 - xx, SIZE - 1 - yy]) / 10.0
    out_alpha *= np.clip(edge, 0, 1)
    rgba = np.dstack([np.ones_like(out_alpha), np.ones_like(out_alpha), np.ones_like(out_alpha), out_alpha])
    final = bpy.data.images.new(f"bosstex_{name}", SIZE, SIZE, alpha=True)
    final.pixels = rgba.flatten().tolist()
    final.filepath_raw = os.path.join(OUT, f"{name}.png")
    final.file_format = "PNG"
    final.save()
    bpy.data.images.remove(final)
    return out_alpha


def main():
    setup_scene()
    sheets = []
    for name, build in SHAPES:
        sheets.append(render_shape(name, build))
        print("rendered", name)
    for obj in [o for o in bpy.data.objects if o.name.startswith("TMP")]:
        bpy.data.objects.remove(obj, do_unlink=True)
    # contact sheet (white on dark) so the set can be looked at in one go
    cols = 4
    rows = math.ceil(len(sheets) / cols)
    sheet = np.full((rows * SIZE, cols * SIZE, 4), 0.08, dtype=np.float32)
    sheet[..., 3] = 1
    for index, alpha in enumerate(sheets):
        r, c = divmod(index, cols)
        block = sheet[r * SIZE : (r + 1) * SIZE, c * SIZE : (c + 1) * SIZE]
        for channel in range(3):
            block[..., channel] = 0.08 + alpha * 0.92
    image = bpy.data.images.new("bosstex_sheet", cols * SIZE, rows * SIZE, alpha=True)
    image.pixels = sheet.flatten().tolist()
    image.filepath_raw = os.path.join(OUT, "bosstex_sheet.png")
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    print("done ->", OUT)


main()
