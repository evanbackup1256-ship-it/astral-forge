"""Astral Forge brand artwork, v2: hand-built, hard-edged, no blur.

The first logo was glossy chrome with soft glows. This one is drawn the way a person would draw a
badge: a faceted hexagon plate, a low-poly night field, an anvil cut from four flat planes, and one
struck star. Letters are chamfered polygons with a hard extruded edge and two diagonal glint bands.
Nothing is blurred except the single glow sprite (a glow is soft by nature).

Layers are exported separately so the game can move them: the base badge, the star (pivots on its
own centre), a glow sprite, and the finished composites.

    python tools/assetgen/build_logo_v2.py            write PNGs to assets/generated/branding
    python tools/assetgen/build_logo_v2.py --preview  also write a contact sheet to the scratch folder
"""
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "assets" / "generated" / "branding"
SS = 3  # supersample on top of the output size; every edge is crisp after the downsample

# palette (plain flat colours; the faceting does the work)
INK = (8, 11, 26)
NAVY_HI = (34, 54, 112)
NAVY_MID = (20, 34, 80)
NAVY_LO = (9, 16, 44)
AMBER = [(255, 231, 168), (245, 195, 107), (217, 143, 43), (168, 97, 27), (199, 126, 38), (240, 181, 79)]
KEY = (42, 22, 8)
CREAM = (246, 241, 228)
STEEL_LIT = (203, 214, 234)
STEEL_MID = (150, 168, 200)
STEEL_SHADE = (104, 124, 164)
STEEL_DARK = (62, 78, 118)
SPARK = (255, 181, 71)
SPARK_HI = (255, 226, 160)
HOT = (255, 247, 226)

# the orbit ring, in the 1000-unit badge space; the game animates a bead along the same ellipse
RING = {"cx": 556, "cy": 392, "rx": 262, "ry": 62, "tilt": -16.0}
STAR = {"cx": 556, "cy": 392, "long": 150, "wide": 92, "diag": 54}
STRIKE = (556, 546)


# ---------------------------------------------------------------- helpers
def poly_mask(size, polys, holes=()):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon(p, fill=255)
    for p in holes:
        d.polygon(p, fill=0)
    return m


def fill(img, mask, rgb, alpha=255):
    layer = Image.new("RGBA", img.size, rgb + (alpha,))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
    img.alpha_composite(layer)


def shift(mask, dx, dy):
    return ImageChops.offset(mask, int(dx), int(dy))


def grow(mask, r):
    """square dilation by r pixels (a box blur and a threshold: fast at any radius)"""
    r = max(1, int(r))
    return mask.filter(ImageFilter.BoxBlur(r)).point(lambda v: 255 if v > 2 else 0)


def shrink(mask, r):
    r = max(1, int(r))
    return mask.filter(ImageFilter.BoxBlur(r)).point(lambda v: 255 if v > 252 else 0)


def rot(points, cx, cy, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in points]


def hexagon(cx, cy, r, start=-90):
    return [(cx + r * math.cos(math.radians(start + 60 * i)), cy + r * math.sin(math.radians(start + 60 * i))) for i in range(6)]


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def four_star(cx, cy, long_r, wide_r, waist=0.17):
    """vertical arm long, horizontal arm wide; returns the 8 outline points"""
    pts = []
    for i in range(8):
        a = math.radians(-90 + 45 * i)
        if i % 2 == 0:
            r = long_r if i in (0, 4) else wide_r
        else:
            r = long_r * waist
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def sparkle(cx, cy, long_r, wide_r, diag_r, waist=0.15):
    """a four-point star with four short diagonal points: reads as a star, never as a cross, even tiny"""
    pts = []
    for i in range(16):
        deg = -90 + 22.5 * i
        if i % 2 == 0:
            quarter = (i // 2) % 4  # 0 up, 1 up-right diagonal, 2 right, 3 down-right diagonal ... pattern repeats
            k = i // 2
            r = long_r if k % 4 == 0 and k in (0, 4) else wide_r if k in (2, 6) else diag_r
        else:
            r = long_r * waist
        a = math.radians(deg)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def ellipse_points(cx, cy, rx, ry, tilt, a0, a1, steps=220):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return rot(pts, cx, cy, tilt)


def line_mask(size, pts, width):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=max(1, int(width)), joint="curve")
    return m


# ---------------------------------------------------------------- the badge
def anvil_polys():
    """four planes cut from one silhouette, in the 1000-unit space"""
    top = [(300, 545), (830, 545), (826, 566), (338, 566), (312, 560)]
    horn_top = [(180, 576), (300, 545), (312, 560), (338, 566), (330, 612)]
    front = [(338, 566), (826, 566), (830, 600), (680, 622), (360, 622), (330, 612)]
    right_end = [(826, 566), (830, 545), (830, 600)]
    waist_l = [(360, 622), (610, 622), (610, 716), (430, 716), (430, 650)]
    waist_r = [(610, 622), (680, 622), (610, 650), (610, 716)]
    base_top = [(430, 716), (610, 716), (700, 746), (340, 746)]
    base_front = [(340, 746), (700, 746), (722, 802), (318, 802)]
    return {
        "top": top, "horn_top": horn_top, "front": front, "right_end": right_end,
        "waist_l": waist_l, "waist_r": waist_r, "base_top": base_top, "base_front": base_front,
    }


def silhouette_polys():
    return [[(180, 576), (300, 545), (830, 545), (830, 600), (680, 622), (610, 650), (610, 716), (700, 746), (722, 802),
             (318, 802), (340, 746), (430, 716), (430, 650), (360, 622), (330, 612)]]


def badge_layers(px, rng_seed=11):
    """returns (base, star_sprite) as RGBA images of size px"""
    S = px * SS
    k = S / 1000.0
    size = (S, S)
    P = lambda pts: [(x * k, y * k) for x, y in pts]
    rng = random.Random(rng_seed)
    base = Image.new("RGBA", size, (0, 0, 0, 0))

    # hexagon plate: six flat facets between the outer and inner hexagons, joined on the diagonals
    outer = hexagon(500, 500, 478)
    inner = hexagon(500, 500, 398)
    for i in range(6):
        quad = [outer[i], outer[(i + 1) % 6], inner[(i + 1) % 6], inner[i]]
        fill(base, poly_mask(size, [P(quad)]), AMBER[i])
    # a dark keyline between plate and field, and a thin lit line on the plate's outer edge
    fill(base, poly_mask(size, [P(hexagon(500, 500, 398))], [P(hexagon(500, 500, 384))]), KEY)
    rim = poly_mask(size, [P(outer)], [P(hexagon(500, 500, 470))])
    fill(base, rim, (255, 244, 214), 150)

    # the field: low-poly night. six large triangles, each split again, tones stepped by height
    field = hexagon(500, 500, 384)
    centre = (500, 500)
    for i in range(6):
        a, b = field[i], field[(i + 1) % 6]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        height = (500 - (a[1] + b[1] + 500) / 3) / 500  # +1 toward the top
        base_tone = mix(NAVY_MID, NAVY_HI, max(0.0, min(1.0, 0.5 + height * 0.7)))
        for j, tri in enumerate(([centre, a, mid], [centre, mid, b])):
            t = mix(base_tone, NAVY_LO, 0.12 * j + rng.uniform(0.0, 0.1))
            fill(base, poly_mask(size, [P(tri)]), t)
    # one big soft diagonal "horizon" facet low in the field gives the anvil something to stand on
    horizon = [(116, 640), (884, 590), (884, 700), (500, 884), (116, 700)]
    inside_field = poly_mask(size, [P(field)])
    h = poly_mask(size, [P(horizon)])
    fill(base, ImageChops.multiply(h, inside_field), (14, 24, 58), 150)

    # stars: tiny four-point diamonds, hand-seeded, none near the strike
    for _ in range(30):
        x, y = rng.uniform(150, 850), rng.uniform(150, 850)
        if math.hypot(x - 530, y - 430) < 190 or math.hypot(x - 500, y - 500) > 340 or y > 520:
            continue
        r = rng.choice([3, 3, 4, 5])
        fill(base, poly_mask(size, [P(four_star(x, y, r * 2.2, r * 2.2, 0.28))]), (225, 236, 255), rng.choice([110, 160, 220]))

    # cast shadow of the anvil on the field: one hard-edged plane
    fill(base, ImageChops.multiply(poly_mask(size, [P([(300, 806), (736, 806), (800, 842), (236, 842)])]), inside_field), (6, 11, 30), 200)

    # orbit ring around the strike star; the star sits on top of it
    ring = ellipse_points(RING["cx"], RING["cy"], RING["rx"], RING["ry"], RING["tilt"], 0, 360, 360)
    ring = [(x * k, y * k) for x, y in ring]
    fill(base, line_mask(size, ring, 8 * k), SPARK)
    fill(base, line_mask(size, ring, 2.2 * k), SPARK_HI)
    # four small ticks on the ring, like a bezel
    for ang in (0, 90, 180, 270):
        p0 = ellipse_points(RING["cx"], RING["cy"], RING["rx"] + 10, RING["ry"] + 6, RING["tilt"], ang, ang, 1)[0]
        p1 = ellipse_points(RING["cx"], RING["cy"], RING["rx"] + 24, RING["ry"] + 14, RING["tilt"], ang, ang, 1)[0]
        fill(base, line_mask(size, [(p0[0] * k, p0[1] * k), (p1[0] * k, p1[1] * k)], 5 * k), SPARK)

    # the anvil: planes
    planes = anvil_polys()
    tones = {
        "top": CREAM, "horn_top": STEEL_LIT, "front": STEEL_MID, "right_end": STEEL_SHADE,
        "waist_l": STEEL_SHADE, "waist_r": STEEL_DARK, "base_top": STEEL_LIT, "base_front": STEEL_MID,
    }
    sil = poly_mask(size, [P(p) for p in silhouette_polys()])
    fill(base, grow(sil, 2.2 * k), KEY)
    for name, poly in planes.items():
        fill(base, poly_mask(size, [P(poly)]), tones[name])
    # a dark under-edge on the base and the face, and one bright line along the working surface
    fill(base, poly_mask(size, [P([(318, 794), (722, 794), (722, 802), (318, 802)])]), STEEL_DARK)
    fill(base, poly_mask(size, [P([(338, 566), (826, 566), (826, 570), (340, 570)])]), STEEL_DARK, 120)
    # hardy hole
    fill(base, poly_mask(size, [P([(742, 545), (772, 545), (768, 558), (746, 558)])]), KEY)

    # the strike: three short bright facets where the hammer lands, flat and crisp
    sx, sy = STRIKE
    for ang, ln, wd in ((-90, 96, 8), (-62, 72, 7), (-118, 72, 7), (-36, 46, 6), (-144, 46, 6), (-16, 26, 4), (-164, 26, 4)):
        a = math.radians(ang)
        tip = (sx + ln * math.cos(a), sy + ln * math.sin(a))
        nx, ny = -math.sin(a), math.cos(a)
        tri = [(sx + nx * wd, sy + ny * wd), tip, (sx - nx * wd, sy - ny * wd)]
        fill(base, poly_mask(size, [P(tri)]), SPARK_HI)

    # flying sparks: small diamonds on a throw from the strike, shrinking as they go
    for (x, y, r, tone) in ((470, 478, 11, SPARK_HI), (648, 452, 9, SPARK), (420, 520, 7, SPARK), (712, 500, 7, SPARK_HI), (612, 486, 5, HOT)):
        d = [(x, y - r * 1.5), (x + r, y), (x, y + r * 1.5), (x - r, y)]
        fill(base, poly_mask(size, [P(d)]), tone)

    # six chisel notches at the middle of each plate facet, like a watch bezel
    outer_h = hexagon(500, 500, 478)
    inner_h = hexagon(500, 500, 398)
    for i in range(6):
        mx = (outer_h[i][0] + outer_h[(i + 1) % 6][0] + inner_h[i][0] + inner_h[(i + 1) % 6][0]) / 4
        my = (outer_h[i][1] + outer_h[(i + 1) % 6][1] + inner_h[i][1] + inner_h[(i + 1) % 6][1]) / 4
        ang = math.atan2(outer_h[(i + 1) % 6][1] - outer_h[i][1], outer_h[(i + 1) % 6][0] - outer_h[i][0])
        ca, sa = math.cos(ang), math.sin(ang)
        nx, ny = -sa, ca
        half_len, half_w = 12, 4
        notch = [
            (mx + ca * half_len + nx * half_w, my + sa * half_len + ny * half_w),
            (mx + ca * half_len - nx * half_w, my + sa * half_len - ny * half_w),
            (mx - ca * half_len - nx * half_w, my - sa * half_len - ny * half_w),
            (mx - ca * half_len + nx * half_w, my - sa * half_len + ny * half_w),
        ]
        fill(base, poly_mask(size, [P(notch)]), KEY, 200)

    base = base.resize((px, px), Image.LANCZOS)

    # the star on its own sprite, centred, so the game can pivot it
    sprite = int(px * 0.42)
    sk = sprite * SS / (STAR["long"] * 2 * 1.25)
    ss = (sprite * SS, sprite * SS)
    star_img = Image.new("RGBA", ss, (0, 0, 0, 0))
    c = ss[0] / 2
    pts = sparkle(c, c, STAR["long"] * sk, STAR["wide"] * sk, STAR["diag"] * sk)
    fill(star_img, poly_mask(ss, [pts]), SPARK)
    # lit halves: the left half of every arm is lighter, the right half darker: a cut gem, not a gradient
    left_half = poly_mask(ss, [[(0, 0), (c, 0), (c, ss[1]), (0, ss[1])]])
    lit = ImageChops.multiply(poly_mask(ss, [pts]), left_half)
    fill(star_img, lit, SPARK_HI)
    core = poly_mask(ss, [sparkle(c, c, STAR["long"] * sk * 0.46, STAR["wide"] * sk * 0.46, STAR["diag"] * sk * 0.46)])
    fill(star_img, core, HOT)
    # thin crossbar flare: a hairline that fades out toward both ends
    half = STAR["wide"] * sk * 1.22
    xs = np.arange(ss[0])
    fade = np.clip(1 - np.abs(xs - c) / half, 0, 1) ** 0.8
    band = np.zeros((ss[1], ss[0]), dtype=np.float32)
    row0, row1 = int(c - 1.8 * sk), int(c + 1.8 * sk)
    band[row0:row1, :] = fade[None, :]
    fl = Image.fromarray((band * 235).astype(np.uint8), "L")
    layer = Image.new("RGBA", ss, HOT + (255,))
    layer.putalpha(fl)
    star_img.alpha_composite(layer)
    star_img = star_img.resize((sprite, sprite), Image.LANCZOS)
    return base, star_img


def glow_sprite(px):
    """one soft sprite the game tints: warm centre, long falloff"""
    yy, xx = np.mgrid[0:px, 0:px]
    d = np.hypot(xx - px / 2, yy - px / 2) / (px / 2)
    a = np.clip(1 - d, 0, 1) ** 2.2
    arr = np.zeros((px, px, 4), dtype=np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = 255, 255, 255
    arr[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def composite_badge(px):
    base, star = badge_layers(px)
    out = base.copy()
    cx = int(STAR["cx"] / 1000 * px - star.width / 2)
    cy = int(STAR["cy"] / 1000 * px - star.height / 2)
    out.alpha_composite(star, (cx, cy))
    return out, base, star


# ---------------------------------------------------------------- letterforms
# 100-unit cap height, 45-degree chamfers; the O's counter is a hexagon like the badge
FORGE = {
    "F": (78, [[(0, 0), (78, 0), (78, 20), (22, 20), (22, 40), (66, 40), (66, 60), (22, 60), (22, 100), (0, 100)]], []),
    "O": (96, [[(18, 0), (78, 0), (96, 18), (96, 82), (78, 100), (18, 100), (0, 82), (0, 18)]],
          [[(48, 22), (74, 36), (74, 64), (48, 78), (22, 64), (22, 36)]]),
    "R": (88, [[(0, 0), (70, 0), (84, 14), (84, 46), (72, 58), (88, 100), (63, 100), (49, 60), (22, 60), (22, 100), (0, 100)]],
          [[(22, 20), (58, 20), (62, 24), (62, 36), (58, 40), (22, 40)]]),
    "G": (92, [[(18, 0), (86, 0), (86, 20), (28, 20), (22, 26), (22, 74), (28, 80), (62, 80), (68, 74), (68, 64), (48, 64),
                (48, 46), (92, 46), (92, 82), (74, 100), (18, 100), (0, 82), (0, 18)]], []),
    "E": (80, [[(0, 0), (80, 0), (80, 20), (22, 20), (22, 40), (66, 40), (66, 60), (22, 60), (22, 80), (80, 80), (80, 100), (0, 100)]], []),
}
# ASTRAL: centre-line strokes, flat caps, no curves
ASTRAL = {
    "A": (70, [[(2, 100), (35, 2), (68, 100)], [(16, 66), (54, 66)]]),
    "S": (60, [[(58, 16), (46, 2), (14, 2), (2, 14), (2, 36), (14, 50), (46, 50), (58, 62), (58, 86), (46, 98), (14, 98), (2, 84)]]),
    "T": (64, [[(2, 2), (62, 2)], [(32, 2), (32, 100)]]),
    "R": (62, [[(2, 100), (2, 2), (44, 2), (58, 14), (58, 38), (44, 50), (2, 50)], [(32, 50), (58, 100)]]),
    "L": (54, [[(2, 2), (2, 98), (52, 98)]]),
}


def forge_word(tracking):
    letters = "FORGE"
    width = sum(FORGE[c][0] for c in letters) + tracking * (len(letters) - 1)
    return letters, width


def draw_forge(img, ox, oy, scale, tracking, depth):
    """the heavy line: extrusion, keyline, faceted face, edge lights"""
    size = img.size
    polys, holes, x = [], [], 0.0
    for ch in "FORGE":
        w, ps, hs = FORGE[ch]
        polys += [[(ox + (x + px_) * scale, oy + py_ * scale) for px_, py_ in p] for p in ps]
        holes += [[(ox + (x + px_) * scale, oy + py_ * scale) for px_, py_ in p] for p in hs]
        x += w + tracking
    face = poly_mask(size, polys, holes)
    cap = 100 * scale
    # extrusion: hard slab, darkening toward the back (a few pixels per step; the strokes are far thicker)
    step = max(1, depth // 36)
    for i in range(depth, 0, -step):
        t = i / depth
        fill(img, shift(face, i * 0.55, i), mix((120, 56, 16), (52, 22, 6), t))
    fill(img, shift(face, 0.55, 1), (120, 56, 16))
    # keyline
    key = grow(face, max(2, int(cap * 0.028)))
    fill(img, ImageChops.subtract(key, face), INK)
    # face: light top band, amber body, base shade, two diagonal glint bands
    top = poly_mask(size, [[(0, oy), (size[0], oy), (size[0], oy + cap * 0.30), (0, oy + cap * 0.30)]])
    mid = poly_mask(size, [[(0, oy + cap * 0.30), (size[0], oy + cap * 0.30), (size[0], oy + cap * 0.72), (0, oy + cap * 0.72)]])
    low = poly_mask(size, [[(0, oy + cap * 0.72), (size[0], oy + cap * 0.72), (size[0], oy + cap + 4), (0, oy + cap + 4)]])
    fill(img, ImageChops.multiply(face, top), (255, 232, 170))
    fill(img, ImageChops.multiply(face, mid), (246, 188, 88))
    fill(img, ImageChops.multiply(face, low), (222, 142, 48))
    total_w = sum(FORGE[c][0] for c in "FORGE") + tracking * 4
    for off, wd, a in ((0.06, 0.045, 80), (0.125, 0.014, 64), (0.34, 0.045, 80), (0.405, 0.014, 64), (0.62, 0.045, 80), (0.685, 0.014, 64), (0.86, 0.045, 80), (0.925, 0.014, 64)):
        gx = ox + total_w * scale * off
        band = [(gx, oy - 4), (gx + wd * total_w * scale, oy - 4), (gx + wd * total_w * scale - cap * 0.38, oy + cap + 4), (gx - cap * 0.38, oy + cap + 4)]
        fill(img, ImageChops.multiply(face, poly_mask(size, [band])), (255, 250, 232), a)
    # edge lights: a bright line on every upward-facing edge, a dark one on every downward-facing edge
    lip = max(2, int(cap * 0.022))
    up = ImageChops.subtract(face, shift(face, 0, lip))
    down = ImageChops.subtract(face, shift(face, 0, -lip))
    fill(img, up, (255, 252, 240), 230)
    fill(img, down, (150, 78, 20), 200)
    return face


ASTRAL_X = 1.2  # the monoline letters are drawn narrow; this opens them up so the spacing reads as design


def draw_astral(img, ox, oy, scale, tracking, weight, depth):
    size = img.size
    strokes, x = [], 0.0
    for ch in "ASTRAL":
        w, paths = ASTRAL[ch]
        for p in paths:
            strokes.append([(ox + (x + px_ * ASTRAL_X) * scale, oy + py_ * scale) for px_, py_ in p])
        x += w * ASTRAL_X + tracking
    face = Image.new("L", size, 0)
    d = ImageDraw.Draw(face)
    for pts in strokes:
        d.line(pts, fill=255, width=int(weight * scale), joint="curve")
    cap = 100 * scale
    step = max(1, depth // 24)
    for i in range(depth, 0, -step):
        fill(img, shift(face, i * 0.5, i), mix((38, 54, 104), (16, 24, 56), i / depth))
    fill(img, shift(face, 0.5, 1), (38, 54, 104))
    key = grow(face, max(2, int(cap * 0.016)))
    fill(img, ImageChops.subtract(key, face), INK)
    top = poly_mask(size, [[(0, oy), (size[0], oy), (size[0], oy + cap * 0.5), (0, oy + cap * 0.5)]])
    low = poly_mask(size, [[(0, oy + cap * 0.5), (size[0], oy + cap * 0.5), (size[0], oy + cap + 4), (0, oy + cap + 4)]])
    fill(img, ImageChops.multiply(face, top), (240, 246, 255))
    fill(img, ImageChops.multiply(face, low), (176, 200, 232))
    return face


def wordmark(width, height):
    ss = 2  # the lettering is large and made of long straight edges: two-times is plenty
    W, H = width * ss, height * ss
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pad = H * 0.035
    usable = H - pad * 2
    f_depth_share = 0.085
    track_f = 12
    f_units_w = sum(FORGE[c][0] for c in "FORGE") + track_f * 4
    f_scale = min((W - pad * 2) / f_units_w, usable * 0.52 / 100)
    f_cap = 100 * f_scale
    f_depth = int(f_cap * f_depth_share)
    a_cap = f_cap * 0.46
    a_scale = a_cap / 100
    gap = f_cap * 0.17
    total_h = a_cap + gap + f_cap + f_depth
    top = (H - total_h) / 2
    fx = (W - f_units_w * f_scale) / 2
    # ASTRAL tracks out to the width of FORGE
    a_plain = sum(ASTRAL[c][0] for c in "ASTRAL") * ASTRAL_X
    a_track = (f_units_w * f_scale / a_scale - a_plain) / 5
    ax = (W - (a_plain + a_track * 5) * a_scale) / 2
    draw_astral(img, ax, top, a_scale, a_track, 17, int(a_cap * 0.05))
    draw_forge(img, fx, top + a_cap + gap, f_scale, track_f, f_depth)
    return img.resize((width, height), Image.LANCZOS)


# ---------------------------------------------------------------- composites
def lockup(width, height):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    e = int(height * 0.56)
    badge, _, _ = composite_badge(e)
    img.alpha_composite(badge, ((width - e) // 2, int(height * 0.02)))
    wm_h = int(height * 0.38)
    wm = wordmark(int(wm_h * 2.7), wm_h)
    img.alpha_composite(wm, ((width - wm.width) // 2, e + int(height * 0.005)))
    return img


def game_icon(px):
    S = px
    img = Image.new("RGBA", (S, S), INK + (255,))
    k = S / 1000.0
    rng = random.Random(5)
    # a low-poly field behind the badge: big triangles in two navies
    cols, rows = 5, 5
    pts = [[(c * S / cols + rng.uniform(-0.04, 0.04) * S * (0 < c < cols), r * S / rows + rng.uniform(-0.04, 0.04) * S * (0 < r < rows)) for c in range(cols + 1)] for r in range(rows + 1)]
    for r in range(rows):
        for c in range(cols):
            a, b, cc, d = pts[r][c], pts[r][c + 1], pts[r + 1][c + 1], pts[r + 1][c]
            t1 = mix(NAVY_LO, NAVY_MID, rng.uniform(0.1, 0.8) * (1 - r / rows * 0.6))
            t2 = mix(NAVY_LO, NAVY_MID, rng.uniform(0.0, 0.7) * (1 - r / rows * 0.6))
            ImageDraw.Draw(img).polygon([a, b, cc], fill=t1)
            ImageDraw.Draw(img).polygon([a, cc, d], fill=t2)
    e = int(S * 0.86)
    badge, _, _ = composite_badge(e)
    img.alpha_composite(badge, ((S - e) // 2, (S - e) // 2))
    return img


def main():
    out = OUT
    if "--out" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--out") + 1])
    only = [a for a in sys.argv[1:] if a in ("mark", "wordmark", "lockup", "icon")]
    out.mkdir(parents=True, exist_ok=True)
    if not only or "mark" in only:
        badge, base, star = composite_badge(1024)
        badge.save(out / "compact-mark.png")
        base.save(out / "mark-base.png")
        star.save(out / "mark-star.png")
        glow_sprite(256).save(out / "mark-glow.png")
    if not only or "wordmark" in only:
        wordmark(4096, 1536).save(out / "wordmark.png")
    if not only or "lockup" in only:
        lockup(4096, 2560).save(out / "lockup.png")
    if not only or "icon" in only:
        game_icon(2048).save(out / "game-icon.png")
    (out / "mark-layout.json").write_text(json.dumps({"ring": RING, "star": STAR, "strike": STRIKE}, indent=2), encoding="utf-8")
    print("wrote", out)


if __name__ == "__main__":
    main()
