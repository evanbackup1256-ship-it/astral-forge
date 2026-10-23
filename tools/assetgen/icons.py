"""Astral Forge icons: every icon in the game is its own, rendered here.

Each icon id ("Forge.12", "Machine.OriginPress", ...) names a concept (the part before the dot)
and a use. The concept picks the glyph, drawn below as shapes; the id seeds everything else:
badge shape, material, ornaments, the glyph's pose and accent colour, so no two ids render the
same (a signature check enforces it). Small interface controls (close, back, chevron ...) are
drawn without a badge so they stay readable at 20 px.

Every icon is two layers: the body, and a light layer (rim light, glints, sparkles, glow) that the
game animates (spin, pulse, glint sweep, twinkle, bob, beat) so icons feel alive.

    python tools/assetgen/icons.py --preview          # contact sheet of every concept + variants
    python tools/assetgen/icons.py                    # draw the ids not on a sheet yet into the next free cells
    python tools/assetgen/icons.py --full             # render every id into fresh atlas sheets + manifest
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "generated" / "icons"
CELL = 96          # final cell size in the atlas
SS = 4             # supersampling
S = CELL * SS      # working canvas
SHEET = 1024
PER_ROW = SHEET // CELL  # 10 cells a row

INK = (14, 10, 20)

# ------------------------------------------------------------------ materials
# each material: badge gradient (top -> bottom), rim, glyph metal, glow accent
MATERIALS = {
    "ember":    dict(badge=[(84, 30, 18), (40, 12, 10)],  rim=(255, 150, 70),  glyph=[(255, 248, 226), (255, 196, 98), (214, 120, 44)], accent=(255, 140, 60)),
    "gold":     dict(badge=[(96, 66, 20), (44, 28, 10)],  rim=(255, 210, 110), glyph=[(255, 250, 220), (250, 204, 104), (176, 112, 34)], accent=(255, 200, 90)),
    "steel":    dict(badge=[(52, 62, 84), (22, 26, 40)],  rim=(176, 204, 236), glyph=[(250, 252, 255), (190, 210, 232), (110, 128, 160)], accent=(150, 200, 255)),
    "azure":    dict(badge=[(20, 66, 104), (10, 28, 52)], rim=(110, 214, 250), glyph=[(236, 252, 255), (140, 224, 252), (40, 140, 200)], accent=(80, 210, 250)),
    "violet":   dict(badge=[(66, 34, 110), (26, 14, 52)], rim=(196, 150, 255), glyph=[(248, 240, 255), (204, 170, 255), (126, 84, 214)], accent=(180, 130, 255)),
    "jade":     dict(badge=[(18, 84, 62), (8, 36, 30)],   rim=(110, 240, 184), glyph=[(236, 255, 246), (140, 240, 196), (40, 160, 118)], accent=(90, 236, 178)),
    "rose":     dict(badge=[(104, 30, 64), (44, 12, 30)], rim=(255, 140, 190), glyph=[(255, 240, 248), (255, 168, 206), (200, 70, 130)], accent=(255, 120, 180)),
    "obsidian": dict(badge=[(40, 34, 48), (12, 10, 16)],  rim=(232, 220, 236), glyph=[(255, 252, 246), (236, 226, 214), (150, 136, 140)], accent=(240, 230, 255)),
    "coral":    dict(badge=[(110, 42, 30), (48, 16, 14)], rim=(255, 140, 110), glyph=[(255, 244, 236), (255, 170, 140), (210, 84, 60)], accent=(255, 120, 96)),
    "sun":      dict(badge=[(110, 84, 14), (52, 34, 6)],  rim=(255, 236, 120), glyph=[(255, 254, 236), (255, 230, 120), (210, 150, 30)], accent=(255, 226, 100)),
}
FRAMES = ["circle", "hex", "shield", "rounded", "diamond", "octagon", "gear", "burst", "pentagon"]
PATTERNS = ["none", "stripes", "dots", "rays", "rings", "hatch"]
ORNAMENTS = ["rivets", "notches", "inner_ring", "corner_gems", "rays", "dots_ring", "none", "double_rim"]


# ------------------------------------------------------------------ geometry helpers
def P(x, y):
    """unit coords (0..1, y down) to canvas pixels"""
    return (x * S, y * S)


def polygon_pts(cx, cy, r, n, rot=-90):
    return [P(cx + r * math.cos(math.radians(rot + i * 360 / n)), cy + r * math.sin(math.radians(rot + i * 360 / n))) for i in range(n)]


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append(P(cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


class Mask:
    """a glyph drawn as filled shapes and strokes into one 8-bit mask"""

    def __init__(self):
        self.img = Image.new("L", (S, S), 0)
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, on=True):
        self.d.polygon([p if isinstance(p[0], float) and p[0] > 1.5 else P(*p) for p in pts], fill=255 if on else 0)
        return self

    def circle(self, cx, cy, r, on=True):
        self.d.ellipse([*P(cx - r, cy - r), *P(cx + r, cy + r)], fill=255 if on else 0)
        return self

    def ring(self, cx, cy, r, w, on=True):
        self.circle(cx, cy, r + w / 2, on)
        self.circle(cx, cy, r - w / 2, not on)
        return self

    def rect(self, x0, y0, x1, y1, radius=0.0, on=True):
        self.d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=radius * S, fill=255 if on else 0)
        return self

    def line(self, pts, w, on=True):
        px = [P(*p) for p in pts]
        self.d.line(px, fill=255 if on else 0, width=max(1, int(w * S)), joint="curve")
        for p in px:
            r = w * S / 2
            self.d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255 if on else 0)
        return self

    def arc(self, cx, cy, r, a0, a1, w, on=True, steps=48):
        pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]
        return self.line(pts, w, on)

    def star(self, cx, cy, r1, r2, n=5, rot=-90, on=True):
        self.d.polygon(star_pts(cx, cy, r1, r2, n, rot), fill=255 if on else 0)
        return self

    def ngon(self, cx, cy, r, n, rot=-90, on=True):
        self.d.polygon(polygon_pts(cx, cy, r, n, rot), fill=255 if on else 0)
        return self

    def sparkle(self, cx, cy, r, on=True):
        return self.star(cx, cy, r, r * 0.22, 4, -90, on)


# ------------------------------------------------------------------ glyphs (unit square, centred ~0.5)
# each returns (body Mask, detail Mask or None). Detail is drawn in the darker metal tone.
def g_flux(m, d):
    m.poly([(0.56, 0.12), (0.30, 0.55), (0.48, 0.55), (0.40, 0.88), (0.72, 0.42), (0.53, 0.42), (0.62, 0.12)])


def g_core(m, d):
    m.poly([(0.5, 0.12), (0.80, 0.42), (0.5, 0.88), (0.20, 0.42)])
    d.poly([(0.5, 0.12), (0.62, 0.42), (0.5, 0.88), (0.38, 0.42)])
    d.line([(0.20, 0.42), (0.80, 0.42)], 0.025)


def g_dust(m, d):
    m.sparkle(0.42, 0.44, 0.26)
    m.sparkle(0.72, 0.30, 0.12)
    m.sparkle(0.70, 0.70, 0.15)
    m.circle(0.26, 0.76, 0.04)


def g_forge(m, d):
    # anvil with a hammer raised over it
    m.poly([(0.16, 0.56), (0.80, 0.56), (0.72, 0.66), (0.60, 0.68), (0.62, 0.80), (0.70, 0.86), (0.30, 0.86), (0.38, 0.80), (0.40, 0.68), (0.24, 0.64)])
    m.rect(0.30, 0.14, 0.64, 0.30, 0.03)
    m.line([(0.47, 0.30), (0.47, 0.50)], 0.07)
    d.line([(0.30, 0.62), (0.70, 0.62)], 0.02)


def g_research(m, d):
    m.circle(0.5, 0.5, 0.08)
    for a in (0, 60, 120):
        pts = []
        for i in range(61):
            t = math.radians(i * 6)
            x, y = 0.34 * math.cos(t), 0.13 * math.sin(t)
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            pts.append((0.5 + x * ca - y * sa, 0.5 + x * sa + y * ca))
        m.line(pts, 0.035)
    d.circle(0.5, 0.5, 0.035)


def g_grid(m, d):
    for i in range(3):
        for j in range(3):
            x0, y0 = 0.17 + i * 0.23, 0.17 + j * 0.23
            m.rect(x0, y0, x0 + 0.19, y0 + 0.19, 0.03)
    d.rect(0.40 + 0.03, 0.40 + 0.03, 0.59 - 0.03, 0.59 - 0.03, 0.02)


def g_world(m, d):
    m.circle(0.5, 0.5, 0.25)
    pts = []
    for i in range(73):
        t = math.radians(i * 5)
        x, y = 0.40 * math.cos(t), 0.11 * math.sin(t)
        c, s = math.cos(math.radians(-18)), math.sin(math.radians(-18))
        pts.append((0.5 + x * c - y * s, 0.5 + x * s + y * c))
    m.line(pts, 0.04)
    d.arc(0.5, 0.5, 0.17, 200, 280, 0.035)


def g_mission(m, d):
    m.rect(0.24, 0.16, 0.76, 0.88, 0.05)
    d.rect(0.38, 0.11, 0.62, 0.21, 0.03)
    d.line([(0.34, 0.52), (0.46, 0.64), (0.68, 0.38)], 0.06)


def g_milestone(m, d):
    m.star(0.5, 0.53, 0.38, 0.16, 5)
    d.star(0.5, 0.53, 0.16, 0.07, 5)


def g_leaderboard(m, d):
    m.rect(0.38, 0.30, 0.62, 0.84, 0.02)
    m.rect(0.14, 0.48, 0.36, 0.84, 0.02)
    m.rect(0.64, 0.58, 0.86, 0.84, 0.02)
    d.star(0.5, 0.18, 0.09, 0.04, 5)


def g_crew(m, d):
    m.circle(0.36, 0.36, 0.11)
    m.poly([(0.16, 0.80), (0.20, 0.58), (0.36, 0.50), (0.52, 0.58), (0.56, 0.80)])
    m.circle(0.66, 0.40, 0.10)
    m.poly([(0.50, 0.82), (0.52, 0.62), (0.66, 0.54), (0.80, 0.62), (0.84, 0.82)])


def g_guild(m, d):
    m.line([(0.30, 0.12), (0.30, 0.90)], 0.05)
    m.poly([(0.30, 0.16), (0.82, 0.16), (0.70, 0.34), (0.82, 0.52), (0.30, 0.52)])
    d.star(0.54, 0.34, 0.09, 0.04, 5)


def g_wheel(m, d):
    m.ring(0.5, 0.5, 0.30, 0.08)
    for i in range(8):
        a = math.radians(i * 45)
        m.line([(0.5, 0.5), (0.5 + 0.30 * math.cos(a), 0.5 + 0.30 * math.sin(a))], 0.03)
    m.circle(0.5, 0.5, 0.07)
    d.poly([(0.44, 0.08), (0.56, 0.08), (0.5, 0.20)])


def g_games(m, d):
    m.rect(0.14, 0.34, 0.86, 0.70, 0.17)
    d.line([(0.30, 0.52), (0.42, 0.52)], 0.04)
    d.line([(0.36, 0.46), (0.36, 0.58)], 0.04)
    d.circle(0.64, 0.48, 0.035)
    d.circle(0.72, 0.56, 0.035)


def g_credits(m, d):
    m.rect(0.16, 0.38, 0.84, 0.84, 0.04)
    m.poly([(0.16, 0.34), (0.80, 0.16), (0.84, 0.30), (0.20, 0.48)])
    for i in range(3):
        d.poly([(0.30 + i * 0.18, 0.30 - i * 0.05), (0.40 + i * 0.18, 0.27 - i * 0.05), (0.36 + i * 0.18, 0.41 - i * 0.05), (0.26 + i * 0.18, 0.44 - i * 0.05)])


def g_gift(m, d):
    m.rect(0.18, 0.42, 0.82, 0.86, 0.03)
    m.rect(0.14, 0.32, 0.86, 0.44, 0.03)
    d.rect(0.45, 0.32, 0.55, 0.86)
    m.poly([(0.5, 0.32), (0.30, 0.14), (0.24, 0.26)])
    m.poly([(0.5, 0.32), (0.70, 0.14), (0.76, 0.26)])


def g_guide(m, d):
    m.ring(0.5, 0.5, 0.32, 0.06)
    m.poly([(0.5, 0.20), (0.58, 0.5), (0.5, 0.80), (0.42, 0.5)])
    d.poly([(0.5, 0.50), (0.58, 0.5), (0.5, 0.80), (0.42, 0.5)])


def g_settings(m, d):
    m.ngon(0.5, 0.5, 0.30, 16)
    for i in range(8):
        a = math.radians(i * 45)
        m.circle(0.5 + 0.32 * math.cos(a), 0.5 + 0.32 * math.sin(a), 0.07)
    m.circle(0.5, 0.5, 0.11, False)


def g_close(m, d):
    m.line([(0.26, 0.26), (0.74, 0.74)], 0.12)
    m.line([(0.74, 0.26), (0.26, 0.74)], 0.12)


def g_menu(m, d):
    for y in (0.30, 0.5, 0.70):
        m.line([(0.22, y), (0.78, y)], 0.10)


def g_chevron(m, d):
    m.line([(0.38, 0.22), (0.66, 0.5), (0.38, 0.78)], 0.12)


def g_back(m, d):
    m.line([(0.78, 0.5), (0.26, 0.5)], 0.11)
    m.line([(0.46, 0.28), (0.24, 0.5), (0.46, 0.72)], 0.11)


def g_minus(m, d):
    m.line([(0.24, 0.5), (0.76, 0.5)], 0.13)


def g_plus(m, d):
    m.line([(0.24, 0.5), (0.76, 0.5)], 0.13)
    m.line([(0.5, 0.24), (0.5, 0.76)], 0.13)


def g_check(m, d):
    m.line([(0.20, 0.52), (0.42, 0.74), (0.80, 0.28)], 0.13)


def g_stargrid(m, d):
    pts = [(0.22, 0.30), (0.46, 0.20), (0.72, 0.34), (0.60, 0.62), (0.34, 0.74), (0.80, 0.80)]
    m.line(pts[:5] + [pts[0]], 0.025)
    m.line([pts[3], pts[5]], 0.025)
    for x, y in pts:
        m.sparkle(x, y, 0.08)


def g_command(m, d):
    for i in range(3):
        y = 0.24 + i * 0.20
        m.poly([(0.16, y + 0.14), (0.5, y - 0.02), (0.84, y + 0.14), (0.84, y + 0.24), (0.5, y + 0.08), (0.16, y + 0.24)])


def g_anomaly(m, d):
    pts = []
    for i in range(140):
        t = i / 139
        a = t * math.pi * 4.2
        r = 0.04 + t * 0.32
        pts.append((0.5 + r * math.cos(a), 0.5 + r * math.sin(a)))
    m.line(pts, 0.05)
    d.circle(0.5, 0.5, 0.05)


def g_reactor(m, d):
    m.circle(0.5, 0.5, 0.10)
    for i in range(3):
        a0 = -90 + i * 120 - 30
        pts = [(0.5, 0.5)] + [(0.5 + 0.36 * math.cos(math.radians(a0 + k * 3)), 0.5 + 0.36 * math.sin(math.radians(a0 + k * 3))) for k in range(21)]
        m.poly(pts)
    m.circle(0.5, 0.5, 0.14, False)
    m.circle(0.5, 0.5, 0.08)


def g_lab(m, d):
    m.poly([(0.42, 0.14), (0.58, 0.14), (0.58, 0.40), (0.80, 0.84), (0.20, 0.84), (0.42, 0.40)])
    d.poly([(0.30, 0.66), (0.70, 0.66), (0.78, 0.82), (0.22, 0.82)])
    m.rect(0.36, 0.10, 0.64, 0.16, 0.02)


def g_loadout(m, d):
    m.line([(0.20, 0.80), (0.76, 0.24)], 0.08)
    m.rect(0.62, 0.12, 0.88, 0.30, 0.03)
    m.line([(0.24, 0.24), (0.78, 0.78)], 0.06)
    m.ring(0.22, 0.22, 0.08, 0.05)


def g_artifact(m, d):
    m.arc(0.5, 0.18, 0.18, 200, 340, 0.03)
    m.ngon(0.5, 0.56, 0.28, 6, -90)
    d.ngon(0.5, 0.56, 0.15, 6, -90)


def g_vault(m, d):
    m.rect(0.16, 0.16, 0.84, 0.84, 0.08)
    d.ring(0.5, 0.5, 0.19, 0.05)
    for i in range(6):
        a = math.radians(i * 60)
        d.line([(0.5, 0.5), (0.5 + 0.16 * math.cos(a), 0.5 + 0.16 * math.sin(a))], 0.03)


def g_rebirth(m, d):
    m.arc(0.5, 0.5, 0.29, -60, 160, 0.08)
    m.poly([(0.20, 0.78), (0.10, 0.56), (0.32, 0.60)])
    m.arc(0.5, 0.5, 0.29, 120, 340, 0.08)
    m.poly([(0.80, 0.22), (0.90, 0.44), (0.68, 0.40)])
    d.poly([(0.5, 0.36), (0.58, 0.52), (0.5, 0.64), (0.42, 0.52)])


def g_hide(m, d):
    m.poly([(0.12, 0.5), (0.30, 0.32), (0.5, 0.26), (0.70, 0.32), (0.88, 0.5), (0.70, 0.68), (0.5, 0.74), (0.30, 0.68)])
    m.circle(0.5, 0.5, 0.13, False)
    m.circle(0.5, 0.5, 0.07)
    m.line([(0.20, 0.82), (0.80, 0.18)], 0.07)


def g_lock(m, d):
    m.rect(0.22, 0.44, 0.78, 0.86, 0.06)
    m.arc(0.5, 0.42, 0.18, 180, 360, 0.08)
    m.line([(0.32, 0.42), (0.32, 0.46)], 0.08)
    m.line([(0.68, 0.42), (0.68, 0.46)], 0.08)
    d.circle(0.5, 0.60, 0.05)
    d.rect(0.48, 0.60, 0.52, 0.74)


def g_story(m, d):
    m.poly([(0.10, 0.24), (0.46, 0.30), (0.50, 0.82), (0.12, 0.74)])
    m.poly([(0.90, 0.24), (0.54, 0.30), (0.50, 0.82), (0.88, 0.74)])
    for i in range(3):
        d.line([(0.18, 0.40 + i * 0.10), (0.40, 0.44 + i * 0.10)], 0.02)
        d.line([(0.82, 0.40 + i * 0.10), (0.60, 0.44 + i * 0.10)], 0.02)


def g_mail(m, d):
    m.rect(0.14, 0.26, 0.86, 0.76, 0.04)
    d.line([(0.18, 0.30), (0.5, 0.56), (0.82, 0.30)], 0.045)


def g_chat(m, d):
    m.rect(0.14, 0.18, 0.86, 0.66, 0.12)
    m.poly([(0.28, 0.60), (0.24, 0.86), (0.48, 0.64)])
    for x in (0.34, 0.5, 0.66):
        d.circle(x, 0.42, 0.045)


def g_shop(m, d):
    m.poly([(0.18, 0.36), (0.82, 0.36), (0.76, 0.86), (0.24, 0.86)])
    m.arc(0.5, 0.36, 0.16, 180, 360, 0.05)
    d.circle(0.38, 0.48, 0.03)
    d.circle(0.62, 0.48, 0.03)


def g_boost(m, d):
    m.poly([(0.5, 0.10), (0.84, 0.44), (0.64, 0.44), (0.64, 0.56), (0.36, 0.56), (0.36, 0.44), (0.16, 0.44)])
    m.poly([(0.5, 0.52), (0.80, 0.80), (0.62, 0.80), (0.5, 0.68), (0.38, 0.80), (0.20, 0.80)])


def g_jackpot(m, d):
    for i, (x, y) in enumerate([(0.36, 0.70), (0.64, 0.70), (0.5, 0.52)]):
        m.circle(x, y, 0.17)
        d.ring(x, y, 0.11, 0.025)
    m.sparkle(0.78, 0.28, 0.12)


def g_admin(m, d):
    m.poly([(0.14, 0.76), (0.14, 0.30), (0.32, 0.50), (0.5, 0.20), (0.68, 0.50), (0.86, 0.30), (0.86, 0.76)])
    m.rect(0.14, 0.78, 0.86, 0.86, 0.02)
    d.circle(0.5, 0.58, 0.06)


def g_pilot(m, d):
    m.poly([(0.20, 0.62), (0.22, 0.38), (0.36, 0.20), (0.64, 0.20), (0.78, 0.38), (0.80, 0.62), (0.70, 0.84), (0.30, 0.84)])
    d.rect(0.28, 0.40, 0.72, 0.60, 0.08)


def g_overview(m, d):
    m.arc(0.5, 0.62, 0.32, 180, 360, 0.08)
    for i in range(5):
        a = math.radians(180 + i * 45)
        m.line([(0.5 + 0.22 * math.cos(a), 0.62 + 0.22 * math.sin(a)), (0.5 + 0.26 * math.cos(a), 0.62 + 0.26 * math.sin(a))], 0.03)
    m.line([(0.5, 0.62), (0.70, 0.40)], 0.05)
    m.circle(0.5, 0.62, 0.06)


def g_inventory(m, d):
    m.rect(0.20, 0.30, 0.80, 0.86, 0.10)
    m.arc(0.5, 0.30, 0.13, 180, 360, 0.05)
    d.rect(0.32, 0.52, 0.68, 0.70, 0.04)


def g_continuum(m, d):
    pts = []
    for i in range(121):
        t = math.radians(i * 3)
        x = 0.34 * math.sin(t)
        y = 0.17 * math.sin(t) * math.cos(t) * 2
        pts.append((0.5 + x, 0.5 + y))
    m.line(pts, 0.07)


def g_rewards(m, d):
    m.poly([(0.24, 0.14), (0.76, 0.14), (0.72, 0.42), (0.5, 0.58), (0.28, 0.42)])
    m.arc(0.24, 0.28, 0.10, 90, 270, 0.035)
    m.arc(0.76, 0.28, 0.10, -90, 90, 0.035)
    m.rect(0.44, 0.56, 0.56, 0.72)
    m.rect(0.30, 0.72, 0.70, 0.84, 0.02)
    d.star(0.5, 0.32, 0.08, 0.035, 5)


def g_collect(m, d):
    m.line([(0.5, 0.14), (0.5, 0.52)], 0.09)
    m.poly([(0.30, 0.42), (0.70, 0.42), (0.5, 0.64)])
    m.poly([(0.14, 0.62), (0.26, 0.62), (0.32, 0.74), (0.68, 0.74), (0.74, 0.62), (0.86, 0.62), (0.80, 0.88), (0.20, 0.88)])


def g_overcharge(m, d):
    m.rect(0.18, 0.28, 0.78, 0.76, 0.06)
    m.rect(0.78, 0.42, 0.86, 0.62, 0.02)
    d.poly([(0.52, 0.32), (0.36, 0.54), (0.48, 0.54), (0.42, 0.72), (0.60, 0.48), (0.48, 0.48), (0.54, 0.32)])


def g_domain(m, d):
    m.ngon(0.5, 0.5, 0.36, 6, -90)
    m.ngon(0.5, 0.5, 0.26, 6, -90, False)
    for i in range(6):
        a = math.radians(-90 + i * 60)
        m.line([(0.5, 0.5), (0.5 + 0.26 * math.cos(a), 0.5 + 0.26 * math.sin(a))], 0.035)
    m.circle(0.5, 0.5, 0.07)


def g_search(m, d):
    m.ring(0.42, 0.42, 0.20, 0.08)
    m.line([(0.57, 0.57), (0.80, 0.80)], 0.10)


def g_pause(m, d):
    m.rect(0.26, 0.20, 0.42, 0.80, 0.03)
    m.rect(0.58, 0.20, 0.74, 0.80, 0.03)


def g_play(m, d):
    m.poly([(0.30, 0.18), (0.80, 0.5), (0.30, 0.82)])


def g_refresh(m, d):
    m.arc(0.5, 0.5, 0.28, -30, 250, 0.09)
    m.poly([(0.74, 0.12), (0.84, 0.40), (0.58, 0.34)])


def g_send(m, d):
    m.poly([(0.12, 0.46), (0.88, 0.16), (0.62, 0.88), (0.48, 0.58)])
    d.line([(0.48, 0.58), (0.88, 0.16)], 0.03)


def g_code(m, d):
    m.line([(0.32, 0.26), (0.14, 0.5), (0.32, 0.74)], 0.08)
    m.line([(0.68, 0.26), (0.86, 0.5), (0.68, 0.74)], 0.08)
    m.line([(0.58, 0.18), (0.42, 0.82)], 0.07)


def g_crate(m, d):
    m.rect(0.14, 0.24, 0.86, 0.86, 0.03)
    d.rect(0.14, 0.24, 0.86, 0.34)
    d.line([(0.20, 0.80), (0.80, 0.40)], 0.05)
    d.line([(0.14, 0.60), (0.86, 0.60)], 0.03)


def g_calendar(m, d):
    m.rect(0.16, 0.22, 0.84, 0.86, 0.06)
    d.rect(0.16, 0.22, 0.84, 0.38, 0.06)
    m.line([(0.32, 0.14), (0.32, 0.28)], 0.06)
    m.line([(0.68, 0.14), (0.68, 0.28)], 0.06)
    for i in range(3):
        for j in range(2):
            d.rect(0.26 + i * 0.18, 0.48 + j * 0.16, 0.36 + i * 0.18, 0.58 + j * 0.16, 0.01)


def g_timer(m, d):
    m.ring(0.5, 0.56, 0.28, 0.07)
    m.rect(0.42, 0.12, 0.58, 0.20, 0.02)
    m.line([(0.5, 0.56), (0.5, 0.38)], 0.05)
    m.line([(0.5, 0.56), (0.64, 0.64)], 0.05)


def g_wave(m, d):
    for k, y in enumerate((0.32, 0.5, 0.68)):
        pts = [(0.12 + i * 0.019, y + 0.08 * math.sin(i * 0.33 + k)) for i in range(41)]
        m.line(pts, 0.05)


def g_visit(m, d):
    m.rect(0.26, 0.14, 0.74, 0.88, 0.04)
    d.rect(0.34, 0.24, 0.66, 0.82, 0.03)
    m.circle(0.60, 0.54, 0.035)


def g_ember(m, d):
    m.poly([(0.5, 0.10), (0.66, 0.36), (0.74, 0.30), (0.80, 0.56), (0.70, 0.80), (0.5, 0.90), (0.30, 0.80), (0.20, 0.56), (0.32, 0.42), (0.40, 0.48)])
    d.poly([(0.5, 0.46), (0.60, 0.62), (0.58, 0.80), (0.42, 0.80), (0.40, 0.62)])


def g_production(m, d):
    m.poly([(0.12, 0.86), (0.12, 0.44), (0.32, 0.56), (0.32, 0.44), (0.52, 0.56), (0.52, 0.30), (0.62, 0.30), (0.62, 0.16), (0.74, 0.16), (0.74, 0.30), (0.88, 0.30), (0.88, 0.86)])
    for x in (0.24, 0.44, 0.66):
        d.rect(x, 0.66, x + 0.10, 0.76, 0.01)


def g_travel(m, d):
    m.poly([(0.5, 0.08), (0.64, 0.30), (0.64, 0.66), (0.36, 0.66), (0.36, 0.30)])
    m.poly([(0.36, 0.48), (0.20, 0.70), (0.36, 0.66)])
    m.poly([(0.64, 0.48), (0.80, 0.70), (0.64, 0.66)])
    d.circle(0.5, 0.36, 0.06)
    m.poly([(0.42, 0.68), (0.58, 0.68), (0.5, 0.90)])






def g_brand(m, d):
    m.ngon(0.5, 0.5, 0.36, 6, -90)
    d.line([(0.34, 0.70), (0.5, 0.28), (0.66, 0.70)], 0.06)
    d.line([(0.40, 0.56), (0.60, 0.56)], 0.05)


GLYPHS = {
    "Flux": g_flux, "Core": g_core, "Dust": g_dust, "Forge": g_forge, "Research": g_research, "Grid": g_grid,
    "World": g_world, "Mission": g_mission, "Milestone": g_milestone, "Leaderboard": g_leaderboard, "Crew": g_crew,
    "Guild": g_guild, "Wheel": g_wheel, "Games": g_games, "Credits": g_credits, "Gift": g_gift, "Guide": g_guide,
    "Settings": g_settings, "Close": g_close, "Menu": g_menu, "Chevron": g_chevron, "Back": g_back, "Check": g_check, "Minus": g_minus, "Plus": g_plus,
    "StarGrid": g_stargrid, "Command": g_command, "Anomaly": g_anomaly, "Reactor": g_reactor, "Lab": g_lab,
    "Loadout": g_loadout, "Artifact": g_artifact, "Vault": g_vault, "Rebirth": g_rebirth, "Hide": g_hide, "Lock": g_lock,
    "Story": g_story, "Mail": g_mail, "Chat": g_chat, "Shop": g_shop, "Boost": g_boost, "Jackpot": g_jackpot,
    "Admin": g_admin, "Pilot": g_pilot, "Overview": g_overview, "Inventory": g_inventory, "Continuum": g_continuum,
    "Rewards": g_rewards, "Collect": g_collect, "Overcharge": g_overcharge, "Domain": g_domain, "Search": g_search,
    "Pause": g_pause, "Play": g_play, "Refresh": g_refresh, "Send": g_send, "Code": g_code, "Crate": g_crate,
    "Calendar": g_calendar, "Timer": g_timer, "Wave": g_wave, "Visit": g_visit, "Ember": g_ember,
    "Production": g_production, "Travel": g_travel, "Brand": g_brand,
}
# drawn without a badge: small controls that must read at a glance
CHROME = {"Minus", "Plus", "Close", "Menu", "Chevron", "Back", "Check", "Search", "Hide", "Lock", "Pause", "Play", "Refresh", "Send", "Code", "Settings"}
# glyphs whose direction carries meaning: never mirrored, barely turned
DIRECTIONAL = {"Back", "Chevron", "Play", "Send", "Collect", "Boost", "Travel", "Refresh", "Rebirth", "Code", "Check", "Leaderboard", "Story", "Overview", "Timer"}
ANIM = {
    "spin": {"Wheel", "Settings", "Refresh", "Reactor", "Rebirth", "World", "Research", "Domain", "Guide", "Anomaly"},
    "pulse": {"Core", "Flux", "Boost", "Ember", "Overcharge", "Production", "Brand"},
    "twinkle": {"Dust", "StarGrid", "Milestone", "Jackpot", "Artifact"},
    "bob": {"Travel", "Mail", "Send", "Chat", "Crew", "Pilot", "Visit", "Wave"},
    "beat": {"Rewards", "Credits", "Gift", "Guild", "Admin", "Leaderboard"},
}


def anim_of(concept):
    for name, members in ANIM.items():
        if concept in members:
            return name
    return "shine"


# ------------------------------------------------------------------ compositing
def gradient_fill(stops, mask, angle=90):
    """fill a mask with a gradient across it (stops top->bottom by default)"""
    n = len(stops)
    yy = np.linspace(0, 1, S)[:, None]
    xx = np.linspace(0, 1, S)[None, :]
    a = math.radians(angle)
    t = np.clip((xx - 0.5) * math.cos(a) + (yy - 0.5) * math.sin(a) + 0.5, 0, 1)
    xs = np.linspace(0, 1, n)
    rgb = np.zeros((S, S, 3))
    for c in range(3):
        rgb[..., c] = np.interp(t, xs, [s[c] for s in stops])
    img = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(mask)
    return img


def solid(rgb, mask, alpha=255):
    img = Image.new("RGBA", (S, S), (*rgb, 0))
    a = np.array(mask, dtype=np.float32) * (alpha / 255)
    img.putalpha(Image.fromarray(a.astype(np.uint8)))
    return img


def grow(mask, r):
    return mask.filter(ImageFilter.MaxFilter(r * 2 + 1)) if r > 0 else mask


def blur(mask, r):
    return mask.filter(ImageFilter.GaussianBlur(r))


def sub(a, b):
    return ImageChops.subtract(a, b)


def mul(a, f):
    return Image.fromarray((np.array(a, dtype=np.float32) * f).clip(0, 255).astype(np.uint8))


def frame_mask(kind, r=0.44):
    m = Mask()
    c = 0.5
    if kind == "circle":
        m.circle(c, c, r)
    elif kind == "hex":
        m.ngon(c, c, r * 1.04, 6, -90)
    elif kind == "shield":
        m.poly([(0.10, 0.10), (0.90, 0.10), (0.90, 0.48), (0.5, 0.94), (0.10, 0.48)])
    elif kind == "rounded":
        m.rect(0.08, 0.08, 0.92, 0.92, 0.2)
    elif kind == "diamond":
        m.ngon(c, c, r * 1.12, 4, -90)
    elif kind == "octagon":
        m.ngon(c, c, r * 1.02, 8, -67.5)
    elif kind == "gear":
        m.circle(c, c, r * 0.9)
        for i in range(10):
            a = math.radians(i * 36)
            m.circle(c + r * 0.92 * math.cos(a), c + r * 0.92 * math.sin(a), 0.06)
    elif kind == "burst":
        m.star(c, c, r * 1.05, r * 0.86, 12, -90)
    elif kind == "pentagon":
        m.ngon(c, c + 0.02, r * 1.06, 5, -90)
    elif kind == "tri":
        m.poly([(0.5, 0.06), (0.95, 0.86), (0.05, 0.86)])
    return m.img


def ornament(kind, rng, frame):
    """small decorations on the badge, drawn into the rim tone"""
    m = Mask()
    if kind == "rivets":
        n = rng.choice([4, 5, 6, 8])
        for i in range(n):
            a = math.radians(-90 + i * 360 / n + 180 / n)
            m.circle(0.5 + 0.37 * math.cos(a), 0.5 + 0.37 * math.sin(a), 0.022)
    elif kind == "notches":
        for i in range(4):
            a = math.radians(i * 90 - 45)
            m.line([(0.5 + 0.33 * math.cos(a), 0.5 + 0.33 * math.sin(a)), (0.5 + 0.40 * math.cos(a), 0.5 + 0.40 * math.sin(a))], 0.03)
    elif kind == "inner_ring":
        m.ring(0.5, 0.5, 0.34, 0.012)
    elif kind == "corner_gems":
        for a in (45, 135, 225, 315):
            r = math.radians(a)
            m.ngon(0.5 + 0.36 * math.cos(r), 0.5 + 0.36 * math.sin(r), 0.03, 4, 0)
    elif kind == "rays":
        for i in range(16):
            a = math.radians(i * 22.5)
            m.line([(0.5 + 0.30 * math.cos(a), 0.5 + 0.30 * math.sin(a)), (0.5 + 0.38 * math.cos(a), 0.5 + 0.38 * math.sin(a))], 0.008)
    elif kind == "dots_ring":
        for i in range(24):
            a = math.radians(i * 15)
            m.circle(0.5 + 0.37 * math.cos(a), 0.5 + 0.37 * math.sin(a), 0.008)
    elif kind == "double_rim":
        m.ring(0.5, 0.5, 0.40, 0.01)
    return m.img


def pattern(kind):
    """a faint texture inside the badge"""
    m = Mask()
    if kind == "stripes":
        for i in range(-10, 11):
            x = 0.5 + i * 0.07
            m.line([(x - 0.5, 1.0), (x + 0.5, 0.0)], 0.012)
    elif kind == "dots":
        for i in range(12):
            for j in range(12):
                m.circle(0.06 + i * 0.08, 0.06 + j * 0.08, 0.008)
    elif kind == "rays":
        for i in range(24):
            a = math.radians(i * 15)
            m.line([(0.5, 0.5), (0.5 + 0.6 * math.cos(a), 0.5 + 0.6 * math.sin(a))], 0.01)
    elif kind == "rings":
        for r in (0.12, 0.2, 0.28, 0.36):
            m.ring(0.5, 0.5, r, 0.008)
    elif kind == "hatch":
        for i in range(-10, 11):
            x = 0.5 + i * 0.08
            m.line([(x - 0.5, 0.0), (x + 0.5, 1.0)], 0.008)
            m.line([(x - 0.5, 1.0), (x + 0.5, 0.0)], 0.008)
    return m.img


def gem_row(n):
    """small cut gems along the bottom of the badge"""
    m = Mask()
    for i in range(n):
        x = 0.5 + (i - (n - 1) / 2) * 0.09
        m.ngon(x, 0.83, 0.032, 4, 0)
    return m.img


def transform(mask, scale, rot, mirror, dx, dy):
    img = mask
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if scale != 1 or rot != 0 or dx or dy:
        img = img.rotate(rot, resample=Image.BICUBIC, center=(S / 2, S / 2), translate=(dx * S, dy * S))
        if scale != 1:
            w = int(S * scale)
            scaled = img.resize((w, w), Image.LANCZOS)
            canvas = Image.new("L", (S, S), 0)
            off = (S - w) // 2
            if off >= 0:
                canvas.paste(scaled, (off, off))
            else:
                canvas = scaled.crop((-off, -off, -off + S, -off + S))
            img = canvas
    return img


# ------------------------------------------------------------------ one icon
def spec_for(icon_id):
    concept = icon_id.split(".", 1)[0]
    seed = int(hashlib.sha1(icon_id.encode()).hexdigest()[:12], 16)
    rng = random.Random(seed)
    chrome = concept in CHROME
    directional = concept in DIRECTIONAL
    spec = {
        "id": icon_id,
        "concept": concept,
        "chrome": chrome,
        "material": rng.choice(list(MATERIALS)),
        "frame": None if chrome else rng.choice(FRAMES),
        "ornament": None if chrome else rng.choice(ORNAMENTS),
        "scale": rng.choice([0.86, 0.9, 0.94, 0.98]) if chrome else rng.choice([0.58, 0.62, 0.66]),
        "rot": 0 if directional else rng.choice([-10, -6, 0, 0, 6, 10]),
        "mirror": False if directional else rng.random() < 0.4,
        "sparkles": rng.randint(1, 3),
        "pattern": None if chrome else rng.choice(PATTERNS),
        "gems": 0 if chrome else rng.randint(0, 3),
        "glint": rng.choice([-40, -25, 25, 40]),
        "anim": anim_of(concept),
        "phase": round(rng.random(), 3),
        "speed": round(0.8 + rng.random() * 0.5, 3),
        "seed": seed,
    }
    return spec


def signature(spec):
    return (spec["concept"], spec["material"], spec["frame"], spec["ornament"], spec["pattern"], spec["gems"], spec["scale"], spec["rot"], spec["mirror"])


def render(spec):
    rng = random.Random(spec["seed"])
    mat = MATERIALS[spec["material"]]
    glyph_fn = GLYPHS.get(spec["concept"], g_brand)
    body_m, detail_m = Mask(), Mask()
    glyph_fn(body_m, detail_m)
    g = transform(body_m.img, spec["scale"], spec["rot"], spec["mirror"], 0, 0)
    gd = transform(detail_m.img, spec["scale"], spec["rot"], spec["mirror"], 0, 0)
    gd = ImageChops.multiply(gd, g) if spec["concept"] not in ("Gift",) else gd
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    light = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    if not spec["chrome"]:
        fm = frame_mask(spec["frame"])
        # badge: shadow, rim, inner body with a gradient and a soft inner shade
        body.alpha_composite(solid((0, 0, 0), blur(grow(fm, 6), 10), 140))
        body.alpha_composite(solid(mat["rim"], fm))
        inner = grow(fm, 0).filter(ImageFilter.MinFilter(int(0.035 * S) * 2 + 1))
        body.alpha_composite(gradient_fill(mat["badge"], inner, 90))
        shade = sub(inner, ImageChops.offset(inner, 0, int(0.05 * S)))
        body.alpha_composite(solid((0, 0, 0), blur(shade, 8), 90))
        if spec["pattern"] and spec["pattern"] != "none":
            pm = ImageChops.multiply(pattern(spec["pattern"]), inner)
            body.alpha_composite(solid(mat["rim"], pm, 46))
        if spec["gems"]:
            gm = ImageChops.multiply(gem_row(spec["gems"]), inner)
            body.alpha_composite(solid(INK, grow(gm, 3)))
            body.alpha_composite(solid(mat["accent"], gm))
            light.alpha_composite(solid((255, 255, 255), sub(gm, ImageChops.offset(gm, 3, 4)), 200))
        om = ImageChops.multiply(ornament(spec["ornament"], rng, spec["frame"]), inner)
        body.alpha_composite(solid(mat["rim"], om, 210))
        # light layer: a rim highlight on the upper-left edge and a soft glow in the middle
        rim_only = sub(fm, inner)
        hi = Mask()
        hi.circle(0.30, 0.22, 0.42)
        light.alpha_composite(solid((255, 255, 255), ImageChops.multiply(rim_only, blur(hi.img, 30)), 200))
        glow = Mask().circle(0.5, 0.5, 0.30).img
        light.alpha_composite(solid(mat["accent"], ImageChops.multiply(blur(glow, 40), inner), 90))

    # glyph: dark outline, drop shadow, metal body, darker detail, bevel light
    outline = grow(g, int(0.022 * S))
    body.alpha_composite(solid((0, 0, 0), blur(ImageChops.offset(outline, int(0.01 * S), int(0.03 * S)), 6), 150))
    body.alpha_composite(solid(INK, outline))
    body.alpha_composite(gradient_fill(mat["glyph"], g, 90))
    if gd.getbbox():
        deep = tuple(int(c * 0.55 + i * 0.45) for c, i in zip(mat["glyph"][2], INK))
        body.alpha_composite(solid(deep, gd, 245))
    bevel_dark = sub(g, ImageChops.offset(g, -int(0.012 * S), -int(0.016 * S)))
    body.alpha_composite(solid((0, 0, 0), blur(bevel_dark, 3), 110))
    bevel_light = sub(g, ImageChops.offset(g, int(0.012 * S), int(0.016 * S)))
    light.alpha_composite(solid((255, 255, 255), blur(bevel_light, 2), 230))
    # glint streak across the glyph and a glow halo of the accent
    streak = Mask()
    a = math.radians(spec["glint"])
    w = 0.09
    cx, cy = 0.5, 0.5
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    streak.poly([(cx - dx + nx * w, cy - dy + ny * w), (cx + dx + nx * w, cy + dy + ny * w), (cx + dx - nx * w, cy + dy - ny * w), (cx - dx - nx * w, cy - dy - ny * w)])
    light.alpha_composite(solid((255, 255, 255), ImageChops.multiply(blur(streak.img, 6), g), 120))
    light.alpha_composite(solid(mat["accent"], sub(blur(grow(g, 10), 18), outline), 140))
    # sparkles
    for _ in range(spec["sparkles"]):
        sp = Mask()
        ang = rng.random() * math.tau
        rr = rng.uniform(0.30, 0.40)
        sp.sparkle(0.5 + rr * math.cos(ang), 0.5 + rr * math.sin(ang), rng.uniform(0.04, 0.07))
        light.alpha_composite(solid((255, 255, 255), sp.img, 240))
    return body.resize((CELL, CELL), Image.LANCZOS), light.resize((CELL, CELL), Image.LANCZOS)


# ------------------------------------------------------------------ sheets
def stable_order(ids, out_dir):
    """cells never move: icons already on a sheet keep their place, new ones go on the end"""
    old = []
    path = out_dir / "manifest.json"
    if path.exists():
        previous = json.loads(path.read_text(encoding="utf-8"))
        old = previous.get("order") or sorted(previous["icons"], key=lambda i: (previous["icons"][i]["body"][0], previous["icons"][i]["body"][2], previous["icons"][i]["body"][1]))
    known = set(old)
    return old + sorted(i for i in ids if i not in known)


def unique_specs(ids):
    """one spec per id, in order; a clash with an earlier icon re-rolls until it is unlike every other"""
    seen = {}
    specs = []
    for icon_id in ids:
        spec = spec_for(icon_id)
        tries = 0
        while signature(spec) in seen and tries < 400:
            tries += 1
            spec = spec_for(f"{icon_id}~{tries}")
            spec["id"] = icon_id
        if signature(spec) in seen:
            raise SystemExit(f"could not make {icon_id} unique (clashes with {seen[signature(spec)]})")
        seen[signature(spec)] = icon_id
        specs.append(spec)
    return specs


def place(manifest, spec, k):
    """cell k (body and light are two cells) -> [sheet, x, y]"""
    per_sheet = PER_ROW * PER_ROW
    n, c = divmod(k, per_sheet)
    return [n, (c % PER_ROW) * CELL, (c // PER_ROW) * CELL]


def build_incremental(ids, out_dir):
    """render only the icons not on a sheet yet and paste them into the next free cells; every other
    cell stays exactly as it was uploaded, so only the sheets that gained icons need uploading again"""
    previous = json.loads((out_dir / "manifest.json").read_text(encoding="utf-8"))
    manifest = {k: dict(v) for k, v in previous["icons"].items()}
    sheets = list(previous["sheets"])
    specs = unique_specs(ids)
    fresh = [spec for spec in specs if spec["id"] not in manifest]
    cell = 2 * (len(ids) - len(fresh))
    touched = {}
    for spec in fresh:
        body, light = render(spec)
        for layer, img in (("body", body), ("light", light)):
            at = place(manifest, spec, cell)
            cell += 1
            while at[0] >= len(sheets):
                sheets.append(f"icons_{len(sheets):03d}.png")
            if at[0] not in touched:
                path = out_dir / sheets[at[0]]
                touched[at[0]] = Image.open(path).convert("RGBA") if path.exists() else Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
            touched[at[0]].paste(img, (at[1], at[2]))
            manifest.setdefault(spec["id"], {})[layer] = at
        manifest[spec["id"]].update(anim=spec["anim"], phase=spec["phase"], speed=spec["speed"], accent=list(MATERIALS[spec["material"]]["accent"]))
        print("drew", spec["id"], flush=True)
    for n, img in touched.items():
        img.save(out_dir / sheets[n], optimize=True)
    return sheets, manifest


def build(ids, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    specs = unique_specs(ids)
    per_sheet = PER_ROW * PER_ROW
    sheets = []
    manifest = {}
    from multiprocessing import Pool
    with Pool() as pool:
        rendered = pool.map(render, specs, chunksize=16)
    cells = [(spec, body, light) for spec, (body, light) in zip(specs, rendered)]
    flat = []
    for spec, body, light in cells:
        flat.append((spec["id"], "body", body))
        flat.append((spec["id"], "light", light))
    for index in range(0, len(flat), per_sheet):
        sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
        n = len(sheets)
        for k, (icon_id, layer, img) in enumerate(flat[index:index + per_sheet]):
            x, y = (k % PER_ROW) * CELL, (k // PER_ROW) * CELL
            sheet.paste(img, (x, y))
            manifest.setdefault(icon_id, {})[layer] = [n, x, y]
        path = out_dir / f"icons_{n:03d}.png"
        sheet.save(path, optimize=True)
        sheets.append(path.name)
    for spec in specs:
        entry = manifest[spec["id"]]
        entry.update(anim=spec["anim"], phase=spec["phase"], speed=spec["speed"], accent=list(MATERIALS[spec["material"]]["accent"]))
    return sheets, manifest


def sheet_hash(path):
    """what a sheet looks like, so only sheets that changed are uploaded again"""
    with Image.open(path) as img:
        return hashlib.sha1(img.convert("RGBA").tobytes()).hexdigest()


def preview(path):
    concepts = list(GLYPHS)
    cols = 12
    rows_n = math.ceil(len(concepts) / cols)
    tile = CELL + 8
    img = Image.new("RGBA", (cols * tile, rows_n * tile * 3), (18, 14, 24, 255))
    for i, concept in enumerate(concepts):
        for v in range(3):
            body, light = render(spec_for(f"{concept}.{v + 1}"))
            x, y = (i % cols) * tile + 4, ((i // cols) * 3 + v) * tile + 4
            img.alpha_composite(body, (x, y))
            img.alpha_composite(light, (x, y))
    img.save(path)
    print("preview", path, img.size)


def write_luau(sheets, manifest):
    """the game's icon table: sheet images (empty until uploaded) and where each icon sits"""
    asset_ids = {}
    ids_path = ROOT / "assets" / "asset_ids.json"
    if ids_path.exists():
        asset_ids = json.loads(ids_path.read_text(encoding="utf-8"))
    lines = [
        "--!nocheck",
        "-- Generated by tools/assetgen/icons.py. Do not edit by hand.",
        "-- Every icon in the game: b = body cell, l = light cell ({sheet, x, y}), a = animation, p = phase, s = speed.",
        "return {",
        f"\tCell = {CELL},",
        "\tSheets = {",
    ]
    for index, name in enumerate(sheets):
        # the image behind each uploaded decal (resolve_icon_images.py fills these in)
        asset = asset_ids.get(f"IconImage{index:03d}", 0)
        lines.append(f'\t\t"{"rbxassetid://" + str(asset) if asset else ""}", -- {name}')
    lines.append("\t},")
    lines.append("\tIcons = {")
    for icon_id in sorted(manifest):
        e = manifest[icon_id]
        b, l = e["body"], e["light"]
        lines.append(f'\t\t["{icon_id}"] = {{ b = {{ {b[0]}, {b[1]}, {b[2]} }}, l = {{ {l[0]}, {l[1]}, {l[2]} }}, a = "{e["anim"]}", p = {e["phase"]}, s = {e["speed"]} }},')
    lines.append("\t},")
    lines.append("}")
    out = ROOT / "src" / "Client" / "AstralForge" / "IconManifest.luau"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(OUT / "preview.png")
    else:
        ids_path = OUT / "ids.json"
        ids = stable_order(json.loads(ids_path.read_text(encoding="utf-8")), OUT)
        if (OUT / "manifest.json").exists() and "--full" not in sys.argv:
            sheets, manifest = build_incremental(ids, OUT)
        else:
            sheets, manifest = build(ids, OUT)
        hashes = [sheet_hash(OUT / name) for name in sheets]
        (OUT / "manifest.json").write_text(json.dumps({"sheets": sheets, "order": ids, "hashes": hashes, "icons": manifest}), encoding="utf-8")
        write_luau(sheets, manifest)
        print(f"{len(ids)} icons on {len(sheets)} sheets")
