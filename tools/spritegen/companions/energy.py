"""Strange energies: Rift, Quantum, Aether, Glitch, Neon, Hologram."""

from __future__ import annotations

import math
import random

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Rift", "Peek: a zipped tear in space standing on its own; it unzips to peek out with one eye, then seals shut.")
def rift(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    opening = max(0.0, wave(t, 1, -0.25)) * 0.07
    edge = darken(c.color, 0.2)
    b.blob([(0.5, 0.18), (0.6, 0.34), (0.64, 0.56), (0.6, 0.76), (0.5, 0.84), (0.4, 0.76), (0.36, 0.56), (0.4, 0.34)], edge)
    b.blob([(0.5, 0.22), (0.5 + opening + 0.015, 0.4), (0.5 + opening + 0.02, 0.56), (0.5 + opening * 0.6 + 0.01, 0.72),
            (0.5, 0.8), (0.5 - opening * 0.6 - 0.01, 0.72), (0.5 - opening - 0.02, 0.56), (0.5 - opening - 0.015, 0.4)],
           (16, 10, 30))
    # zipper teeth along the seam
    for k in range(9):
        y = 0.28 + k * 0.06
        gap = opening * math.sin(math.pi * min(1, max(0, (y - 0.22) / 0.58)))
        side = -1 if k % 2 else 1
        b.line([(0.5 + side * (gap + 0.02), y), (0.5 + side * (gap + 0.05), y)], lighten(c.color, 0.4), 6)
    if opening > 0.025:
        c.cyclops(0.5, 0.52, min(0.045, opening * 0.75), gaze=wave(t, 2) * 0.6, iris=c.glow)
    c.decal.circle(0.5, 0.25, 0.018, lighten(c.color, 0.5))
    c.lights = [Light(0.5, 0.52, 0.3, c.glow, 0.25 + opening * 10)]
    c.halo = 0.4 + opening * 3


@design("Quantum", "Spin: a smiling nucleus with three electrons on crossed orbits, each looping at its own speed.")
def quantum(c: Canvas) -> None:
    t = c.t
    b = c.body
    orbits = [(0, 1), (60, 2), (120, 3)]
    for tilt, _ in orbits:
        c.behind.ring(0.5, 0.52, 0.3, 0.1, darken(c.glow, 0.3), 5, rot=tilt, start=-90, end=90, alpha=220)
    b.circle(0.5, 0.52, 0.13, c.color)
    for x, y in ((0.46, 0.48), (0.55, 0.5), (0.5, 0.57)):
        b.circle(x, y, 0.045, lighten(c.color, 0.2))
    c.eyes(0.5, 0.51, gap=0.09, size=0.022)
    c.mouth(0.5, 0.57, "smile", 0.016)
    lights = []
    for tilt, speed in orbits:
        c.fx.ring(0.5, 0.52, 0.3, 0.1, c.glow, 5, rot=tilt, start=90, end=270)
        a = t * math.tau * speed + tilt
        ex, ey = math.sin(a) * 0.3, -math.cos(a) * 0.1
        cr, sr = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        x, y = 0.5 + ex * cr - ey * sr, 0.52 + ex * sr + ey * cr
        (c.fx if math.cos(a) < 0 else c.behind).circle(x, y, 0.017, WHITE)
        lights.append(Light(x, y, 0.2, c.glow, 0.45))
    c.lights = lights
    c.halo = 0.45


@design("Aether", "Drifter: a dandelion-seed spirit riding the air on its silk crown; it bobs and sways like it is carried.")
def aether(c: Canvas) -> None:
    t = c.t
    b = c.body
    sway = wave(t, 1) * 0.03
    bob = wave(t, 2) * 0.015
    cx, cy = 0.5 + sway, 0.5 + bob
    # silk crown of filaments
    for k in range(11):
        a = math.radians(-75 + k * 15 + sway * 100)
        tip = (cx + math.sin(a) * 0.26, cy - 0.12 - math.cos(a) * 0.2)
        c.behind.line([(cx, cy - 0.1), tip], (250, 250, 255), 3, alpha=220)
        c.behind.circle(tip[0], tip[1], 0.012, WHITE, alpha=230)
    b.line([(cx, cy - 0.1), (cx, cy + 0.02)], darken(c.color, 0.3), 6)
    b.ellipse(cx, cy + 0.13, 0.1, 0.13, c.color)
    b.ellipse(cx - 0.03, cy + 0.08, 0.025, 0.04, lighten(c.color, 0.5), rot=20)
    c.eyes(cx, cy + 0.13, gap=0.08, size=0.022, style="happy" if c.index % 18 < 6 else "round")
    c.mouth(cx, cy + 0.19, "smile", 0.014)
    c.cheeks(cx, cy + 0.17, 0.13, (255, 190, 170))
    c.lights = [Light(cx, cy - 0.2, 0.4, c.glow, 0.6), Light(0.5, 0.9, 0.3, c.color, 0.25)]
    c.halo = 0.45


@design("Glitch", "Bit: a blocky pixel critter that stutters; every few frames it tears into offset colour channels and snaps back.")
def glitch(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    rnd = random.Random(c.index * 53 + 1)
    torn = c.index % 6 in (0, 1) or c.index in (17, 29)
    px = 0.05
    shape = ["..XX..XX..", "..XXXXXX..", ".XXXXXXXX.", ".XXXXXXXX.", ".XXXXXXXX.", "..XXXXXX..", "..X.XX.X.."]
    offsets = [(0, 0)]
    if torn:
        offsets = [(-0.018, 0), (0.018, 0.006), (0, 0)]
    tint = [(255, 70, 140), (70, 230, 255), c.color] if torn else [c.color]
    for (ox, oy), color in zip(offsets, tint):
        target = c.behind if color is not c.color else c.body
        for row, line in enumerate(shape):
            shift = (rnd.random() - 0.5) * 0.04 if torn and row in (2, 4) else 0
            for col, cell in enumerate(line):
                if cell == "X":
                    x = 0.25 + col * px + ox + shift
                    y = 0.33 + row * px + oy
                    target.poly([(x, y), (x + px, y), (x + px, y + px), (x, y + px)], color,
                                alpha=170 if target is c.behind else 255)
    eye_y = 0.33 + 2.5 * px
    if not c.blink:
        for x in (0.25 + 3 * px, 0.25 + 6 * px):
            c.decal.poly([(x, eye_y), (x + px, eye_y), (x + px, eye_y + px), (x, eye_y + px)], INK)
            c.decal.poly([(x, eye_y), (x + px * 0.4, eye_y), (x + px * 0.4, eye_y + px * 0.4), (x, eye_y + px * 0.4)], WHITE)
    else:
        for x in (0.25 + 3 * px, 0.25 + 6 * px):
            c.decal.poly([(x, eye_y + px * 0.4), (x + px, eye_y + px * 0.4), (x + px, eye_y + px * 0.65), (x, eye_y + px * 0.65)], INK)
    my = 0.33 + 4.2 * px
    c.decal.poly([(0.25 + 4 * px, my), (0.25 + 6 * px, my), (0.25 + 6 * px, my + px * 0.5), (0.25 + 4 * px, my + px * 0.5)], INK)
    c.outline = 11
    c.shade = 0.4
    c.lights = [Light(0.2, 0.3, 0.45, (255, 70, 140), 0.6 if torn else 0.25),
                Light(0.8, 0.7, 0.45, (70, 230, 255), 0.6 if torn else 0.25)]
    c.halo = 0.3 + (0.3 if torn else 0)


@design("Neon", "Buzz: a cat drawn in a single bent neon tube on a dark backing; the tube hums and stutters when it warms up.")
def neon(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    stutter = c.index in (3, 4, 22)
    on = 0.25 if stutter else 1.0
    tube = mix((60, 30, 70), c.color, on)
    b.blob([(0.27, 0.78), (0.26, 0.38), (0.5, 0.28), (0.74, 0.38), (0.73, 0.78), (0.5, 0.84)], (34, 22, 48))
    path = [(0.36, 0.72), (0.36, 0.48), (0.38, 0.36), (0.45, 0.44), (0.55, 0.44), (0.62, 0.36), (0.64, 0.48), (0.64, 0.72),
            (0.5, 0.75), (0.36, 0.72)]
    c.fx.line(path, tube, 11)
    c.fx.line(path, lighten(tube, 0.6), 4)
    second = mix((40, 60, 70), c.glow, on)
    if not c.blink:
        for x in (0.44, 0.56):
            c.fx.circle(x, 0.55, 0.018, second)
    else:
        for x in (0.44, 0.56):
            c.fx.line([(x - 0.02, 0.555), (x + 0.02, 0.555)], second, 6)
    c.fx.line([(0.47, 0.63), (0.5, 0.65), (0.53, 0.63)], second, 5)
    c.fx.line([(0.64, 0.68), (0.72, 0.62 + wave(t, 2) * 0.02)], tube, 9)
    c.lights = [Light(0.5, 0.55, 0.36, c.color, 0.85 * on), Light(0.5, 0.6, 0.25, c.glow, 0.4 * on)]
    c.halo = 0.55 * on + 0.05
    c.halo_color = c.color
    c.shade = 0.3


@design("Hologram", "Projection: a translucent wireframe sprite standing on a projector puck; scanlines climb through it.")
def hologram(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    puck = (60, 70, 96)
    b.ellipse(0.5, 0.8, 0.16, 0.04, puck)
    b.ellipse(0.5, 0.79, 0.11, 0.025, c.color)
    flicker = 0.85 if c.index % 9 == 4 else 1.0
    alpha = int(150 * flicker)
    beam = mix(c.color, WHITE, 0.3)
    c.behind.poly([(0.4, 0.78), (0.6, 0.78), (0.7, 0.3), (0.3, 0.3)], beam, alpha=40)
    figure = [(0.5, 0.26), (0.62, 0.34), (0.64, 0.5), (0.6, 0.66), (0.5, 0.72), (0.4, 0.66), (0.36, 0.5), (0.38, 0.34)]
    c.fx.blob(figure, beam, alpha=alpha)
    c.fx.line(figure + figure[:1], lighten(beam, 0.6), 4)
    for k in range(3):
        y = 0.3 + ((t + k / 3) % 1) * 0.42
        c.fx.line([(0.38, y), (0.62, y)], WHITE, 3, alpha=180)
    if not c.blink:
        for x in (0.45, 0.55):
            c.fx.circle(x, 0.46, 0.018, WHITE)
    c.fx.line([(0.47, 0.54), (0.5, 0.555), (0.53, 0.54)], WHITE, 4)
    c.lights = [Light(0.5, 0.78, 0.25, c.color, 0.8)]
    c.halo = 0.25
    c.halo_color = c.color
