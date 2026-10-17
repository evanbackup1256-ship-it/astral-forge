"""Cold, water and air: Ice, Blizzard, Water, Steam, Wind, Frostfire."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Ice", "Nib: an ice-cube penguin with a snow cap; it waddles foot to foot and fogs the air with a breath.")
def ice(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    step = wave(t, 2)
    sway = step * 0.012
    cube = lighten(c.color, 0.15)
    b.ellipse(0.41, 0.82 - max(0, step) * 0.02, 0.05, 0.022, (255, 170, 70))
    b.ellipse(0.59, 0.82 - max(0, -step) * 0.02, 0.05, 0.022, (255, 170, 70))
    b.blob([(0.31 + sway, 0.38), (0.5 + sway, 0.34), (0.69 + sway, 0.38), (0.71 + sway, 0.6), (0.68 + sway, 0.79),
            (0.5 + sway, 0.81), (0.32 + sway, 0.79), (0.29 + sway, 0.6)], cube)
    b.blob([(0.38 + sway, 0.52), (0.5 + sway, 0.48), (0.62 + sway, 0.52), (0.63 + sway, 0.74), (0.5 + sway, 0.78),
            (0.37 + sway, 0.74)], (242, 250, 255))
    # facets on the cube corners
    b.poly([(0.31 + sway, 0.39), (0.37 + sway, 0.37), (0.33 + sway, 0.5)], lighten(cube, 0.5))
    # snow cap
    b.blob([(0.3 + sway, 0.4), (0.38 + sway, 0.31), (0.5 + sway, 0.29), (0.63 + sway, 0.31), (0.7 + sway, 0.4),
            (0.6 + sway, 0.38), (0.5 + sway, 0.4), (0.4 + sway, 0.38)], WHITE)
    flap = wave(t, 4) * 8
    b.ellipse(0.27 + sway, 0.6, 0.03, 0.075, cube, rot=20 + flap)
    b.ellipse(0.73 + sway, 0.6, 0.03, 0.075, cube, rot=-20 - flap)
    c.eyes(0.5 + sway, 0.47, gap=0.12, size=0.028)
    c.decal.poly([(0.47 + sway, 0.525), (0.53 + sway, 0.525), (0.5 + sway, 0.56)], (255, 170, 70))
    c.cheeks(0.5 + sway, 0.53, 0.2, (150, 190, 255))
    puff = (t * 2) % 1
    if puff < 0.5:
        for k in range(3):
            r = 0.012 + puff * 0.03 + k * 0.006
            c.fx.circle(0.6 + sway + puff * 0.1 + k * 0.025, 0.55 - puff * 0.04 - k * 0.012, r, (235, 248, 255),
                        alpha=int(170 * (1 - puff * 2)))
    c.lights = [Light(0.28, 0.24, 0.55, c.glow, 0.55)]
    c.halo = 0.4
    c.shade_tint = (60, 110, 190)


@design("Blizzard", "Flurry: a shaggy little yeti puffball; snowflakes orbit it and its fur ruffles in the wind.")
def blizzard(c: Canvas) -> None:
    t = c.t
    b = c.body
    fur = lighten(c.color, 0.5)
    # fluffy outline: a ring of tufts that ruffle in a travelling wave
    tufts = []
    for k in range(18):
        a = k / 18 * math.tau
        r = 0.2 + 0.018 * wave(t, 2, k / 6)
        tufts.append((0.5 + math.cos(a) * r, 0.55 + math.sin(a) * r * 0.95))
    for x, y in tufts:
        b.circle(x, y, 0.05, fur)
    b.circle(0.5, 0.55, 0.2, fur)
    b.ellipse(0.5, 0.56, 0.12, 0.1, lighten(c.color, 0.15))  # face patch
    b.poly([(0.38, 0.38), (0.35, 0.28), (0.43, 0.36)], (230, 236, 250))
    b.poly([(0.62, 0.38), (0.65, 0.28), (0.57, 0.36)], (230, 236, 250))
    c.eyes(0.5, 0.54, gap=0.1, size=0.026)
    c.mouth(0.5, 0.6, "fang", 0.02)
    for k in range(5):
        a = t * math.tau + k / 5 * math.tau
        x, y = 0.5 + math.cos(a) * 0.32, 0.55 + math.sin(a) * 0.12
        if math.sin(a) > -0.2 or k % 2 == 0:
            c.fx.star(x, y, 0.018, 0.4, 6, WHITE, rot=t * 120 + k * 20)
    c.lights = [Light(0.5, 0.3, 0.45, c.glow, 0.5), Light(0.5 + math.cos(t * math.tau) * 0.32, 0.55, 0.2, WHITE, 0.4)]
    c.halo = 0.45
    c.shade_tint = (80, 120, 200)


@design("Water", "Ripple: a droplet axolotl; its six gill frills wave in sequence and bubbles rise past its grin.")
def water(c: Canvas) -> None:
    t = c.t
    b = c.body
    bob = wave(t, 1) * 0.012
    frill = (255, 150, 190)
    for side in (-1, 1):
        for k in range(3):
            base = (0.5 + side * 0.17, 0.44 + k * 0.06 + bob)
            angle = side * (0.9 - k * 0.35) + wave(t, 2, k * 0.2 + (0.5 if side > 0 else 0)) * 0.25
            tip = (base[0] + math.sin(angle) * 0.11 * side * side, base[1] - math.cos(angle) * 0.07)
            b.line([base, tip], frill, 11)
            b.circle(tip[0], tip[1], 0.022, lighten(frill, 0.2))
    b.blob([(0.5, 0.3 + bob), (0.62, 0.45 + bob), (0.69, 0.62 + bob), (0.62, 0.78 + bob), (0.5, 0.8 + bob),
            (0.38, 0.78 + bob), (0.31, 0.62 + bob), (0.38, 0.45 + bob)], c.color)
    b.ellipse(0.5, 0.67 + bob, 0.12, 0.09, lighten(c.color, 0.35))
    b.ellipse(0.42, 0.42 + bob, 0.025, 0.045, lighten(c.color, 0.6), rot=20)
    c.eyes(0.5, 0.57 + bob, gap=0.16, size=0.026, style="dot")
    c.mouth(0.5, 0.64 + bob, "smile", 0.045)
    c.cheeks(0.5, 0.62 + bob, 0.2, frill)
    for k in range(3):
        rise = (t + k / 3) % 1
        x = 0.7 + wave(rise, 2, k * 0.3) * 0.02
        y = 0.62 - rise * 0.38
        c.fx.ring(x, y, 0.016 + k * 0.004, 0.016 + k * 0.004, (210, 240, 255), 3.5, alpha=int(230 * (1 - rise)))
    caustic = 0.5 + wave(t, 1) * 0.12
    c.lights = [Light(caustic, 0.3, 0.38, c.glow, 0.55), Light(0.5, 0.95, 0.3, (120, 200, 255), 0.25)]
    c.halo = 0.35


@design("Steam", "Puff: a round little teapot; its lid rattles on the boil and its spout breathes curling steam.")
def steam(c: Canvas) -> None:
    t = c.t
    b = c.body
    rattle = 0.008 if (c.index % 4) < 2 else -0.004
    pot = c.color
    # handle and spout
    b.ring(0.27, 0.58, 0.065, 0.085, darken(pot, 0.15), 14, start=180, end=360)
    b.poly([(0.66, 0.62), (0.8, 0.48), (0.84, 0.5), (0.74, 0.68)], pot)
    # body and base
    b.ellipse(0.5, 0.62, 0.22, 0.18, pot)
    b.ellipse(0.5, 0.79, 0.12, 0.025, darken(pot, 0.25))
    b.ellipse(0.5, 0.67, 0.16, 0.06, lighten(pot, 0.35))
    # lid with knob
    b.ellipse(0.5, 0.45 - rattle, 0.14, 0.04, lighten(pot, 0.1))
    b.circle(0.5, 0.4 - rattle, 0.025, lighten(pot, 0.25))
    c.eyes(0.5, 0.59, gap=0.13, size=0.027, style="happy" if c.index % 12 < 3 else "round")
    c.mouth(0.5, 0.655, "smile", 0.022)
    c.cheeks(0.5, 0.635, 0.21, (255, 160, 170))
    for k in range(3):
        rise = (t * 1.0 + k / 3) % 1
        x = 0.83 + math.sin(rise * math.tau + k) * 0.03
        y = 0.45 - rise * 0.26
        r = 0.025 + rise * 0.035
        c.behind.circle(x, y, r, (245, 248, 255), alpha=int(200 * (1 - rise) ** 1.2))
    c.lights = [Light(0.84, 0.4, 0.4, c.glow, 0.45), Light(0.3, 0.3, 0.5, WHITE, 0.25)]
    c.halo = 0.3


@design("Wind", "Zephyr: a puff-cheeked gust spirit with a curl on its crown; it puffs up, then blows streaming breezes.")
def wind(c: Canvas) -> None:
    t = c.t
    b = c.body
    blow = (t * 2) % 1
    puff = max(0.0, math.sin(blow * math.pi)) if blow < 0.6 else 0.0
    bob = wave(t, 1) * 0.012
    body = lighten(c.color, 0.1)
    # a swirl tail curling off the back
    tail = []
    for k in range(16):
        s = k / 15
        a = -1.2 + s * 4.2 + wave(t, 1) * 0.3
        r = 0.09 * (1 - s * 0.6)
        tail.append((0.33 - s * 0.07 + math.cos(a) * r, 0.66 + bob + math.sin(a) * r))
    b.line(tail, body, 22, smooth=True)
    b.circle(0.5, 0.56 + bob, 0.18 + puff * 0.01, body)
    # cheeks swell before each blow
    for side in (-1, 1):
        b.circle(0.5 + side * 0.11, 0.6 + bob, 0.06 + puff * 0.03, lighten(body, 0.2))
    # crown curl
    curl = []
    for k in range(14):
        s = k / 13
        a = math.pi * 1.2 - s * math.pi * 1.6
        r = 0.065 * (1 - s * 0.55)
        curl.append((0.52 + math.cos(a) * r, 0.37 + bob + math.sin(a) * r))
    b.line(curl, body, 16, smooth=True)
    c.eyes(0.5, 0.52 + bob, gap=0.11, size=0.026, style="happy" if puff > 0.4 else "round")
    c.mouth(0.62, 0.62 + bob, "o" if blow >= 0.6 else "flat", 0.014)
    if blow >= 0.55:
        u = (blow - 0.55) / 0.45
        for k in range(3):
            y = 0.58 + bob + (k - 1) * 0.045
            x0 = 0.66 + u * 0.06
            c.fx.line([(x0, y), (x0 + 0.08, y - 0.01 + k * 0.005), (x0 + 0.16, y + 0.005)], (235, 255, 250), 5,
                      smooth=True, alpha=int(230 * (1 - u * 0.7)))
    c.lights = [Light(0.78, 0.55, 0.4, c.glow, 0.3 + (0.4 if blow >= 0.55 else 0.0)), Light(0.3, 0.3, 0.4, WHITE, 0.25)]
    c.halo = 0.35

@design("Frostfire", "Ember-Rime: a wisp split down the middle, one half crackling ice and the other flame, each flickering its own way.")
def frostfire(c: Canvas) -> None:
    t = c.t
    b = c.body
    ice, fire = (150, 220, 255), (255, 150, 70)
    sway = wave(t, 2) * 0.01
    # ice half: hard facets that shimmer
    b.poly([(0.5, 0.2 + wave(t, 3) * 0.01), (0.38, 0.34), (0.3, 0.32), (0.32, 0.48), (0.26, 0.6), (0.34, 0.76),
            (0.5, 0.8)], ice)
    b.poly([(0.5, 0.28), (0.4, 0.4), (0.42, 0.62), (0.5, 0.7)], lighten(ice, 0.45))
    # fire half: soft tongues
    b.blob([(0.5, 0.8), (0.64, 0.76), (0.72, 0.62), (0.7, 0.46), (0.76 + sway * 2, 0.3 + wave(t, 2, 0.3) * 0.03),
            (0.64, 0.4), (0.6 + sway, 0.24 + wave(t, 3, 0.1) * 0.03), (0.5, 0.36)], fire)
    b.blob([(0.5, 0.7), (0.6, 0.64), (0.62, 0.5), (0.56, 0.44), (0.5, 0.5)], (255, 220, 140))
    b.line([(0.5, 0.36), (0.5, 0.8)], (230, 230, 255), 5)
    c.eyes(0.5, 0.56, gap=0.12, size=0.028, gaze=wave(t, 1) * 0.3)
    c.mouth(0.5, 0.64, "smile", 0.022)
    c.ember(0.66 + sway, 0.2 - (t % 0.5) * 0.1, 0.008, fire)
    c.fx.star(0.33, 0.25 + wave(t, 2) * 0.01, 0.014, 0.4, 4, WHITE, rot=t * 90)
    c.lights = [Light(0.28, 0.5, 0.36, ice, 0.75 + 0.15 * wave(t, 3)), Light(0.72, 0.5, 0.36, fire, 0.75 + 0.2 * wave(t, 5))]
    c.halo = 0.45
    c.halo_color = (230, 200, 255)
