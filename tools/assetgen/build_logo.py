"""Astral Forge brand artwork.

Everything is drawn from hand-placed polygons (no font files): a hexagonal
forge badge and chiseled letterforms with metal fills, bevels and shadows.
Run: python tools/assetgen/build_logo.py
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "assets" / "generated" / "branding"
SS = 2  # supersample factor on top of the target resolution

GOLD = [(0.0, (255, 243, 196)), (0.42, (240, 186, 82)), (0.5, (150, 82, 28)), (0.56, (212, 132, 46)), (1.0, (255, 214, 120))]
SILVER = [(0.0, (246, 251, 255)), (0.45, (168, 204, 232)), (0.52, (72, 102, 146)), (0.6, (140, 178, 214)), (1.0, (214, 234, 250))]
STEEL = [(0.0, (196, 210, 228)), (0.35, (122, 140, 168)), (0.6, (58, 68, 92)), (1.0, (30, 36, 54))]
WOOD = [(0.0, (150, 92, 54)), (0.5, (98, 54, 30)), (1.0, (58, 30, 18))]
INK = (12, 14, 28)
RIM = [(0.0, (255, 240, 192)), (0.3, (232, 176, 78)), (0.55, (186, 116, 42)), (0.75, (238, 186, 96)), (1.0, (204, 138, 54))]


# ---------------------------------------------------------------- helpers
def ramp(stops, n):
    xs = np.linspace(0, 1, n)
    out = np.zeros((n, 3))
    for c in range(3):
        out[:, c] = np.interp(xs, [s[0] for s in stops], [s[1][c] for s in stops])
    return out


def vgrad(size, stops, y0=0, y1=None):
    w, h = size
    y1 = h if y1 is None else y1
    col = ramp(stops, 512)
    t = np.clip((np.arange(h) - y0) / max(1, y1 - y0), 0, 1)
    rows = col[(t * 511).astype(int)]
    arr = np.repeat(rows[:, None, :], w, axis=1).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def radial(size, center, radius, inner, outer):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.clip(np.hypot(xx - center[0], yy - center[1]) / radius, 0, 1)[..., None]
    arr = np.array(inner) * (1 - d) + np.array(outer) * d
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def poly_mask(size, polys, holes=()):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon(p, fill=255)
    for p in holes:
        d.polygon(p, fill=0)
    return m


def shift(mask, dx, dy):
    return ImageChops.offset(mask, int(dx), int(dy))


def grow(mask, r):
    r = max(1, int(r))
    return mask.filter(ImageFilter.BoxBlur(r)).point(lambda v: min(255, v * 10))


def paint(base, fill, mask):
    layer = fill.copy()
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
    base.alpha_composite(layer)


def solid(size, rgb, alpha=255):
    return Image.new("RGBA", size, rgb + (alpha,))


def bevel(base, mask, depth, light=(255, 250, 230), dark=(20, 10, 4), strength=(150, 140)):
    hi = ImageChops.subtract(mask, shift(mask, depth * 0.6, depth))
    lo = ImageChops.subtract(mask, shift(mask, -depth * 0.6, -depth))
    hi = hi.filter(ImageFilter.GaussianBlur(depth * 0.45))
    lo = lo.filter(ImageFilter.GaussianBlur(depth * 0.45))
    hi = ImageChops.multiply(hi, mask).point(lambda v: v * strength[0] // 255)
    lo = ImageChops.multiply(lo, mask).point(lambda v: v * strength[1] // 255)
    paint(base, solid(base.size, light), hi)
    paint(base, solid(base.size, dark), lo)


def grain(base, mask, amount=10, seed=7):
    rng = np.random.default_rng(seed)
    w, h = base.size
    n = rng.normal(0, amount, (h // 2 + 1, w // 2 + 1)).clip(-40, 40)
    n = np.kron(n, np.ones((2, 2)))[:h, :w]
    arr = np.asarray(base).astype(np.int16)
    m = (np.asarray(mask) / 255.0)
    for c in range(3):
        arr[..., c] = np.clip(arr[..., c] + n * m, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def shadow(base, mask, dx, dy, blur, alpha=170, rgb=(0, 0, 0)):
    s = shift(mask, dx, dy).filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
    paint(base, solid(base.size, rgb), s)


def glow(base, mask, blur, rgb, alpha=255):
    g = mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: min(255, v * alpha // 255))
    layer = solid(base.size, rgb)
    layer.putalpha(g)
    base.alpha_composite(layer)


def rot(points, cx, cy, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in points]


def tx(points, s, ox, oy):
    return [(ox + x * s, oy + y * s) for x, y in points]


# ---------------------------------------------------------------- letterforms
# 100-unit cap height, chamfered "forge-cut" construction.
GLYPHS = {
    "A": (100, [[(0, 100), (34, 0), (66, 0), (100, 100), (76, 100), (69, 78), (31, 78), (24, 100)]],
          [[(37, 60), (63, 60), (50, 22)]]),
    "S": (82, [[(14, 0), (82, 0), (82, 20), (26, 20), (24, 22), (24, 38), (26, 40), (68, 40), (82, 54), (82, 86), (68, 100),
                (0, 100), (0, 80), (56, 80), (58, 78), (58, 62), (56, 60), (14, 60), (0, 46), (0, 14)]], []),
    "T": (86, [[(0, 0), (86, 0), (86, 20), (54, 20), (54, 100), (32, 100), (32, 20), (0, 20)]], []),
    "R": (86, [[(0, 0), (68, 0), (82, 14), (82, 46), (70, 58), (86, 100), (61, 100), (47, 60), (22, 60), (22, 100), (0, 100)]],
          [[(22, 20), (56, 20), (60, 24), (60, 36), (56, 40), (22, 40)]]),
    "L": (76, [[(0, 0), (22, 0), (22, 80), (76, 80), (76, 100), (0, 100)]], []),
    "F": (78, [[(0, 0), (78, 0), (78, 20), (22, 20), (22, 40), (66, 40), (66, 60), (22, 60), (22, 100), (0, 100)]], []),
    "O": (92, [[(18, 0), (74, 0), (92, 18), (92, 82), (74, 100), (18, 100), (0, 82), (0, 18)]],
          [[(28, 20), (64, 20), (70, 26), (70, 74), (64, 80), (28, 80), (22, 74), (22, 26)]]),
    "G": (90, [[(18, 0), (84, 0), (84, 20), (28, 20), (22, 26), (22, 74), (28, 80), (62, 80), (68, 74), (68, 64), (48, 64),
                (48, 46), (90, 46), (90, 82), (72, 100), (18, 100), (0, 82), (0, 18)]], []),
    " ": (34, [], []),
    "E": (80, [[(0, 0), (80, 0), (80, 20), (22, 20), (22, 40), (66, 40), (66, 60), (22, 60), (22, 80), (80, 80), (80, 100),
                (0, 100)]], []),
}


def word_polys(text, scale, ox, oy, tracking):
    polys, holes, x = [], [], 0.0
    for ch in text:
        w, ps, hs = GLYPHS[ch]
        polys += [tx(p, scale, ox + x * scale, oy) for p in ps]
        holes += [tx(p, scale, ox + x * scale, oy) for p in hs]
        x += w + tracking
    return polys, holes, (x - tracking) * scale


def word_width(text, tracking):
    return sum(GLYPHS[c][0] for c in text) + tracking * (len(text) - 1)


def render_text(base, polys, holes, height, fill_stops, top, outline=INK, rim=None):
    size = base.size
    m = poly_mask(size, polys, holes)
    sw = max(2, height * 0.075)
    shadow(base, grow(m, sw), height * 0.02, height * 0.07, height * 0.05, 190)
    paint(base, solid(size, outline), grow(m, sw))
    if rim:
        paint(base, solid(size, rim), grow(m, sw * 0.38))
    paint(base, vgrad(size, fill_stops, top, top + height), m)
    bevel(base, m, max(2, height * 0.045))
    return m


def star_points(cx, cy, r_long, r_short, n=4, rot_deg=-90, waist=0.18):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot_deg + i * 180 / n)
        r = r_long if i % 2 == 0 else r_short * waist / 0.18
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------- emblem
def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(-90 + 60 * i)), cy + r * math.sin(math.radians(-90 + 60 * i))) for i in range(6)]


def ellipse_arc(cx, cy, rx, ry, tilt, a0, a1, steps=180):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return rot(pts, cx, cy, tilt)


def stroke_mask(size, pts, width):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=int(width), joint="curve")
    r = width / 2
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    return m


def emblem(px, with_banner=False, seed=11):
    """Hexagonal forge badge, drawn in a 1000-unit design space."""
    S = px * SS
    k = S / 1000.0
    size = (S, S)
    P = lambda pts: [(x * k, y * k) for x, y in pts]
    rng = random.Random(seed)
    img = Image.new("RGBA", size, (0, 0, 0, 0))

    outer = P(hexagon(500, 500, 486))
    rim_in = P(hexagon(500, 500, 446))
    field = P(hexagon(500, 500, 426))
    m_outer = poly_mask(size, [outer])
    m_field = poly_mask(size, [field])

    shadow(img, m_outer, 0, 14 * k, 18 * k, 150)
    paint(img, solid(size, INK), grow(m_outer, 8 * k))
    paint(img, vgrad(size, RIM, 30 * k, 970 * k), m_outer)
    m_rim_in = poly_mask(size, [rim_in])
    paint(img, solid(size, (60, 30, 10)), m_rim_in)
    paint(img, vgrad(size, list(reversed([(1 - t, c) for t, c in RIM])), 60 * k, 940 * k), poly_mask(size, [P(hexagon(500, 500, 438))]))
    bevel(img, m_outer, 9 * k, strength=(170, 150))
    rivets = Image.new("L", size, 0)
    rd = ImageDraw.Draw(rivets)
    for vx, vy in hexagon(500, 500, 466):
        rd.ellipse([(vx - 11) * k, (vy - 11) * k, (vx + 11) * k, (vy + 11) * k], fill=255)
    shadow(img, rivets, 2 * k, 3 * k, 3 * k, 160)
    paint(img, radial(size, (500 * k, 500 * k), 520 * k, (255, 236, 180), (150, 92, 34)), rivets)
    bevel(img, rivets, 3 * k, strength=(220, 200))
    paint(img, solid(size, INK), grow(m_field, 5 * k))

    # night field with a soft aurora sweep (matches the in-game sky)
    paint(img, radial(size, (500 * k, 420 * k), 520 * k, (34, 46, 98), (7, 9, 24)), m_field)
    aur = Image.new("L", size, 0)
    ad = ImageDraw.Draw(aur)
    for i, (cy, col) in enumerate([(330, 1), (390, 1)]):
        ad.line(P(ellipse_arc(500, cy + 260, 520, 300, -8, 200, 340)), fill=110 - i * 40, width=int(70 * k))
    aur = ImageChops.multiply(aur.filter(ImageFilter.GaussianBlur(40 * k)), m_field)
    paint(img, solid(size, (70, 220, 190)), aur.point(lambda v: v * 3 // 5))
    aur2 = ImageChops.multiply(shift(aur, 30 * k, -50 * k), m_field)
    paint(img, solid(size, (150, 110, 255)), aur2.point(lambda v: v * 2 // 5))
    stars = Image.new("L", size, 0)
    sd = ImageDraw.Draw(stars)
    for _ in range(70):
        x, y = rng.uniform(120, 880), rng.uniform(110, 560)
        r = rng.choice([1.4, 1.8, 2.2, 3.2]) * k
        sd.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=rng.randint(120, 255))
    paint(img, solid(size, (230, 240, 255)), ImageChops.multiply(stars, m_field))

    # orbit (back half), drawn before the anvil
    cx, cy, rx, ry, tilt = 500, 470, 372, 104, -14
    back = stroke_mask(size, P(ellipse_arc(cx, cy, rx, ry, tilt, 180, 360)), 15 * k)
    back = ImageChops.multiply(back, m_field)
    paint(img, solid(size, (126, 204, 236)), back.point(lambda v: v * 3 // 5))

    # astral star behind the strike
    st = poly_mask(size, [P(star_points(330, 290, 140, 26))])
    glow(img, st, 40 * k, (150, 220, 255), 200)
    paint(img, vgrad(size, SILVER, 150 * k, 430 * k), st)
    small = poly_mask(size, [P(rot(star_points(330, 290, 66, 14), 330, 290, 45))])
    paint(img, solid(size, (220, 240, 255)), small.point(lambda v: v * 3 // 4))
    bevel(img, st, 5 * k)

    # hammer (handle behind head)
    hx, hy, ang = 478, 452, 36
    handle = poly_mask(size, [P(rot([(hx - 15, hy - 6), (hx + 15, hy - 6), (hx + 12, hy + 330), (hx - 12, hy + 330)], hx, hy, ang + 180))])
    shadow(img, handle, 6 * k, 10 * k, 8 * k, 140)
    paint(img, solid(size, INK), grow(handle, 5 * k))
    paint(img, vgrad(size, WOOD, 120 * k, 420 * k), handle)
    bevel(img, handle, 4 * k, strength=(120, 120))
    head_pts = rot([(hx - 92, hy - 40), (hx + 70, hy - 40), (hx + 92, hy - 22), (hx + 92, hy + 22), (hx + 70, hy + 40),
                    (hx - 92, hy + 40), (hx - 104, hy + 26), (hx - 104, hy - 26)], hx, hy, ang)
    head = poly_mask(size, [P(head_pts)])
    shadow(img, head, 6 * k, 12 * k, 10 * k, 160)
    paint(img, solid(size, INK), grow(head, 6 * k))
    paint(img, vgrad(size, STEEL, (hy - 70) * k, (hy + 70) * k), head)
    band = poly_mask(size, [P(rot([(hx - 22, hy - 41), (hx - 6, hy - 41), (hx - 6, hy + 41), (hx - 22, hy + 41)], hx, hy, ang))])
    paint(img, vgrad(size, GOLD, (hy - 50) * k, (hy + 50) * k), ImageChops.multiply(band, head))
    bevel(img, head, 6 * k, strength=(190, 150))

    # anvil
    anvil = P([(168, 560), (232, 548), (300, 542), (772, 542), (796, 556), (796, 604), (708, 616), (660, 652), (648, 700),
               (712, 732), (734, 776), (282, 776), (304, 732), (368, 700), (356, 652), (308, 616), (262, 606), (214, 590)])
    m_anvil = poly_mask(size, [anvil])
    shadow(img, m_anvil, 0, 16 * k, 14 * k, 190)
    paint(img, solid(size, INK), grow(m_anvil, 8 * k))
    paint(img, vgrad(size, STEEL, 540 * k, 780 * k), m_anvil)
    face = poly_mask(size, [P([(232, 548), (300, 542), (772, 542), (796, 556), (796, 566), (226, 566)])])
    face = ImageChops.multiply(face, m_anvil)
    paint(img, solid(size, (226, 236, 250)), face.point(lambda v: v * 2 // 3))
    hardy = poly_mask(size, [P([(676, 545), (700, 545), (700, 556), (676, 556)])])
    paint(img, solid(size, (14, 16, 26)), hardy)
    warm = Image.new("L", size, 0)
    ImageDraw.Draw(warm).ellipse(P([(330, 540), (700, 640)]), fill=255)
    warm = ImageChops.multiply(warm.filter(ImageFilter.GaussianBlur(40 * k)), m_anvil)
    paint(img, solid(size, (255, 140, 60)), warm.point(lambda v: v * 2 // 5))
    waist = poly_mask(size, [P([(356, 652), (660, 652), (648, 700), (368, 700)])])
    paint(img, solid(size, (16, 20, 34)), ImageChops.multiply(waist, m_anvil).point(lambda v: v // 3))
    bevel(img, m_anvil, 7 * k, strength=(170, 170))
    # molten strike
    hot = Image.new("L", size, 0)
    ImageDraw.Draw(hot).ellipse(P([(420, 530), (600, 560)]), fill=255)
    glow(img, hot, 30 * k, (255, 120, 30), 255)
    glow(img, hot, 10 * k, (255, 196, 90), 255)
    paint(img, solid(size, (255, 242, 210)), ImageChops.multiply(hot.filter(ImageFilter.GaussianBlur(4 * k)), m_anvil))

    # sparks thrown from the strike point
    sparks = Image.new("L", size, 0)
    sp = ImageDraw.Draw(sparks)
    for i in range(26):
        a = math.radians(rng.uniform(196, 344))
        r0, r1 = rng.uniform(20, 60), rng.uniform(90, 230)
        x0, y0 = 510 + r0 * math.cos(a), 540 + r0 * math.sin(a) * 0.8
        x1, y1 = 510 + r1 * math.cos(a), 540 + r1 * math.sin(a) * 0.8 + (r1 / 230) ** 2 * 30
        sp.line([(x0 * k, y0 * k), (x1 * k, y1 * k)], fill=rng.randint(170, 255), width=max(1, int(rng.uniform(2.2, 4.6) * k)))
    glow(img, sparks, 9 * k, (255, 140, 40), 255)
    paint(img, solid(size, (255, 232, 170)), sparks)

    # orbit (front half) with a bead planet
    front = stroke_mask(size, P(ellipse_arc(cx, cy, rx, ry, tilt, 0, 180)), 15 * k)
    front = ImageChops.multiply(front, m_field)
    paint(img, solid(size, INK), ImageChops.multiply(grow(front, 5 * k), m_field))
    paint(img, vgrad(size, SILVER, 380 * k, 600 * k), front)
    bead_a = math.radians(150)
    bx, by = rot([(cx + rx * math.cos(bead_a), cy + ry * math.sin(bead_a))], cx, cy, tilt)[0]
    bead = Image.new("L", size, 0)
    ImageDraw.Draw(bead).ellipse([(bx - 30) * k, (by - 30) * k, (bx + 30) * k, (by + 30) * k], fill=255)
    paint(img, solid(size, INK), grow(bead, 5 * k))
    paint(img, radial(size, ((bx - 10) * k, (by - 12) * k), 44 * k, (200, 246, 255), (40, 110, 170)), bead)

    if with_banner:
        ribbon = P([(96, 800), (904, 800), (870, 846), (904, 892), (96, 892), (130, 846)])
        m_rib = poly_mask(size, [ribbon])
        shadow(img, m_rib, 0, 10 * k, 10 * k, 180)
        paint(img, solid(size, INK), grow(m_rib, 7 * k))
        paint(img, vgrad(size, [(0, (150, 40, 34)), (0.5, (104, 22, 26)), (1, (60, 10, 16))], 800 * k, 892 * k), m_rib)
        bevel(img, m_rib, 5 * k, strength=(110, 140))
        tw = word_width("ASTRAL FORGE", 10)
        sc = 54 / 100 * k
        polys, holes, _ = word_polys("ASTRAL FORGE", sc, 500 * k - tw * sc / 2, 819 * k, 10)
        render_text(img, polys, holes, 54 * k, GOLD, 819 * k)

    img = grain(img, m_outer, 5, seed)
    return img.resize((px, px), Image.LANCZOS)


# ---------------------------------------------------------------- wordmark
def wordmark(width, height, pad=0.04):
    W, H = width * SS, height * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    forge_track, astral_track = 14, 44
    fw = word_width("FORGE", forge_track)
    # FORGE carries ~62% of the height, ASTRAL sits above, tracked to the same width.
    usable_h = H * (1 - pad * 2)
    f_h = usable_h * 0.58
    a_h = usable_h * 0.31
    gap = usable_h - f_h - a_h
    f_scale = f_h / 100
    if fw * f_scale > W * (1 - pad * 2):
        f_scale = W * (1 - pad * 2) / fw
        f_h = f_scale * 100
        a_h = f_h * 0.5
        gap = f_h * 0.14
    total_w = fw * f_scale
    a_scale = a_h / 100
    aw_plain = word_width("ASTRAL", 0)
    astral_track = (total_w / a_scale - aw_plain) / 5
    top = (H - (a_h + gap + f_h)) / 2
    x0 = (W - total_w) / 2

    pa, ha, _ = word_polys("ASTRAL", a_scale, x0, top, astral_track)
    render_text(img, pa, ha, a_h, SILVER, top, rim=(70, 120, 170))
    fy = top + a_h + gap
    # rule lines flanking the gap give the stacked lockup a struck-metal plate feel
    pf, hf, _ = word_polys("FORGE", f_scale, x0, fy, forge_track)
    m = render_text(img, pf, hf, f_h, GOLD, fy, rim=(120, 60, 18))
    # small four-point star sits in the A's counter-space apex as a signature detail
    a_w = GLYPHS["A"][0]
    star = poly_mask(img.size, [star_points(x0 + a_w * a_scale / 2, top + a_h * 0.03, a_h * 0.36, a_h * 0.06)])
    glow(img, star, a_h * 0.12, (160, 220, 255), 220)
    paint(img, solid(img.size, (240, 250, 255)), star)
    img = grain(img, m, 4, 3)
    return img.resize((width, height), Image.LANCZOS)


def lockup(width, height):
    """Emblem above the stacked wordmark, used on boot/shutdown screens."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    e = int(height * 0.56)
    em = emblem(e)
    img.alpha_composite(em, ((width - e) // 2, int(height * 0.02)))
    wm_h = int(height * 0.38)
    wm = wordmark(int(wm_h * 2.4), wm_h, pad=0.02)
    img.alpha_composite(wm, ((width - wm.width) // 2, e + int(height * 0.005)))
    return img


def game_icon(px):
    S = px
    bg = radial((S, S), (S * 0.5, S * 0.42), S * 0.78, (30, 40, 92), (6, 7, 18))
    arr = np.asarray(bg).astype(np.int16)
    rng = np.random.default_rng(5)
    yy, xx = np.mgrid[0:S, 0:S]
    band = np.exp(-((yy - S * 0.3 - (xx - S / 2) * 0.25) / (S * 0.12)) ** 2)
    arr[..., 1] += (band * 46).astype(np.int16)
    arr[..., 2] += (band * 40).astype(np.int16)
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    bg = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(bg)
    for _ in range(140):
        x, y, r = rng.uniform(0, S), rng.uniform(0, S), rng.choice([1, 1.5, 2, 3]) * S / 1024
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 232, 255, int(rng.uniform(90, 230))))
    e = int(S * 0.9)
    bg.alpha_composite(emblem(e, with_banner=True), ((S - e) // 2, int(S * 0.04)))
    return bg


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    emblem(1024).save(OUT / "compact-mark.png")
    wordmark(4096, 1536).save(OUT / "wordmark.png")
    lockup(4096, 2560).save(OUT / "lockup.png")
    game_icon(2048).save(OUT / "game-icon.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
