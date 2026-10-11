"""The beyond: Void, Shadow, Spirit, Arcane, Radiance, Prism, Chrono."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Void", "Hollow: a cat-shaped window onto deep space; stars drift through its body and starlight rims its edges.")
def void(c: Canvas) -> None:
    t = c.t
    b = c.body
    night = (34, 22, 62)
    tail = wave(t, 1) * 0.04
    b.line([(0.66, 0.74), (0.78, 0.7), (0.8 + tail, 0.56), (0.74 + tail, 0.5)], night, 14, smooth=True)
    b.blob([(0.32, 0.8), (0.33, 0.6), (0.4, 0.5), (0.6, 0.5), (0.67, 0.6), (0.68, 0.8)], night)
    b.circle(0.5, 0.45, 0.15, night)
    b.poly([(0.37, 0.4), (0.37, 0.24), (0.47, 0.33)], night)
    b.poly([(0.63, 0.4), (0.63, 0.24), (0.53, 0.33)], night)
    # drifting stars inside the silhouette
    for k in range(9):
        x = 0.36 + ((k * 0.137 + t * 0.12) % 1) * 0.3
        y = 0.36 + ((k * 0.311) % 1) * 0.42
        r = 0.006 + (k % 3) * 0.003
        b.circle(x, y, r, lighten(c.glow, 0.4) if k % 2 else WHITE)
    b.ellipse(0.5, 0.6, 0.06, 0.03, (90, 60, 160), alpha=160)
    c.eyes(0.5, 0.45, gap=0.11, size=0.03, style="glow", shine=lighten(c.glow, 0.3))
    c.decal.line([(0.475, 0.51), (0.5, 0.52), (0.525, 0.51)], lighten(c.glow, 0.2), 4)
    c.lights = [Light(0.5, 0.22, 0.5, c.color, 0.95), Light(0.5, 0.9, 0.35, c.glow, 0.4)]
    c.halo = 0.55
    c.shade = 0.6


@design("Shadow", "Shade: a hooded wisp with nothing inside but two eyes; its tattered hem flutters and its lantern-eyes glint.")
def shadow(c: Canvas) -> None:
    t = c.t
    b = c.body
    cloth = darken(c.color, 0.55)
    bob = wave(t, 1) * 0.015
    hem = []
    for k in range(7):
        x = 0.31 + k * 0.063
        y = 0.8 + bob + (0.04 if k % 2 == 0 else 0) + wave(t, 2, k * 0.17) * 0.02
        hem.append((x, y))
    b.blob([(0.5, 0.2 + bob), (0.62, 0.32 + bob), (0.68, 0.55 + bob), (0.7, 0.78 + bob)] + hem[::-1]
           + [(0.3, 0.78 + bob), (0.32, 0.55 + bob), (0.38, 0.32 + bob)], cloth)
    b.blob([(0.5, 0.36 + bob), (0.59, 0.43 + bob), (0.6, 0.56 + bob), (0.5, 0.62 + bob), (0.4, 0.56 + bob),
            (0.41, 0.43 + bob)], (14, 10, 26))
    glint = 1.0 if c.index % 12 < 2 else 0.0
    c.eyes(0.5, 0.49 + bob, gap=0.09, size=0.026, style="glow", shine=lighten(c.glow, 0.2 + glint * 0.6))
    c.lights = [Light(0.5, 0.5 + bob, 0.25, c.glow, 0.45 + glint * 0.4), Light(0.5, 0.95, 0.4, c.color, 0.45)]
    c.halo = 0.4
    c.shade = 0.8


@design("Spirit", "Wisp: a paper lantern on a hook with a friendly flame-spirit inside; it swings gently and the flame lights its paper.")
def spirit(c: Canvas) -> None:
    t = c.t
    b = c.body
    swing = wave(t, 1) * 0.05
    paper = mix((200, 196, 226), c.color, 0.25)  # mid-tone so the flame visibly lights it
    cx = 0.5 + swing
    b.line([(0.5, 0.15), (cx, 0.28)], darken(c.color, 0.5), 5)
    b.ring(0.5, 0.15, 0.025, 0.02, darken(c.color, 0.5), 5)
    b.poly([(cx - 0.07, 0.28), (cx + 0.07, 0.28), (cx + 0.08, 0.33), (cx - 0.08, 0.33)], darken(c.color, 0.45))
    b.ellipse(cx, 0.55, 0.17, 0.22, paper)
    for k in (-1, 0, 1):  # paper ribs
        b.ring(cx, 0.55, 0.17 * (0.35 + abs(k) * 0.5) if k else 0.01, 0.22, mix(paper, c.color, 0.35), 3,
               start=0, end=180) if k else b.line([(cx, 0.34), (cx, 0.76)], mix(paper, c.color, 0.35), 3)
    b.poly([(cx - 0.08, 0.76), (cx + 0.08, 0.76), (cx + 0.07, 0.81), (cx - 0.07, 0.81)], darken(c.color, 0.45))
    flick = wave(t, 4) * 0.01
    b.blob([(cx, 0.43 + flick), (cx + 0.07, 0.55), (cx + 0.06, 0.65), (cx, 0.68), (cx - 0.06, 0.65),
            (cx - 0.07, 0.55)], lighten(c.color, 0.35))
    c.eyes(cx, 0.58, gap=0.06, size=0.018)
    c.mouth(cx, 0.625, "smile", 0.014)
    c.lights = [Light(cx, 0.58, 0.32, c.glow, 0.9 + 0.1 * wave(t, 4))]
    c.halo = 0.5
    c.shade = 0.5


@design("Arcane", "Grimm: a floating spellbook with an eye on its cover; it flaps open to flash its pages and runes orbit its spine.")
def arcane(c: Canvas) -> None:
    t = c.t
    b = c.body
    bob = wave(t, 1) * 0.015
    open_amount = 0.5 + 0.5 * wave(t, 2)
    cover = darken(c.color, 0.5)
    pages = (250, 244, 228)
    spine = (0.5, 0.58 + bob)
    # back cover and pages, then the front cover lifting
    b.poly([(0.27, 0.46 + bob), (0.5, 0.5 + bob), (0.5, 0.76 + bob), (0.27, 0.72 + bob)], cover)
    b.poly([(0.3, 0.47 + bob), (0.5, 0.51 + bob), (0.5, 0.74 + bob), (0.3, 0.7 + bob)], pages)
    lift = open_amount * 0.12
    b.poly([(0.5, 0.5 + bob), (0.73 - lift * 0.4, 0.46 + bob - lift), (0.73 - lift * 0.4, 0.72 + bob - lift * 0.6),
            (0.5, 0.76 + bob)], c.color)
    b.poly([(0.52, 0.53 + bob), (0.7 - lift * 0.4, 0.5 + bob - lift), (0.7 - lift * 0.4, 0.69 + bob - lift * 0.6),
            (0.52, 0.73 + bob)], lighten(c.color, 0.2))
    c.cyclops(0.61 - lift * 0.2, 0.6 + bob - lift * 0.8, 0.04, gaze=wave(t, 1) * 0.5, iris=(255, 150, 240))
    for k in range(4):
        c.decal.line([(0.33, 0.53 + k * 0.045 + bob), (0.46, 0.555 + k * 0.045 + bob)], (180, 170, 200), 3)
    for k in range(3):
        a = t * math.tau + k * math.tau / 3
        x, y = 0.5 + math.cos(a) * 0.3, 0.45 + bob + math.sin(a) * 0.08
        c.fx.star(x, y, 0.016, 0.35, 4, lighten(c.glow, 0.3), rot=k * 30)
    c.lights = [Light(0.4, 0.55 + bob, 0.3, (255, 240, 200), 0.3 + open_amount * 0.5), Light(0.5, 0.3, 0.4, c.color, 0.45)]
    c.halo = 0.45


@design("Radiance", "Seraph: a serene light-orb with downy wings and a halo; its wings beat slowly and the halo turns above it.")
def radiance(c: Canvas) -> None:
    t = c.t
    b = c.body
    bob = wave(t, 1) * 0.02
    flap = wave(t, 2) * 0.05
    feather = (255, 250, 236)
    for side in (-1, 1):
        for k in range(3):
            b.ellipse(0.5 + side * (0.2 + k * 0.045), 0.52 + bob - flap * (1 - k * 0.3) + k * 0.035,
                      0.07, 0.03, feather, rot=side * (-35 + k * 22) - side * flap * 200)
    b.circle(0.5, 0.56 + bob, 0.16, c.color)
    b.circle(0.5, 0.56 + bob, 0.12, lighten(c.color, 0.45))
    c.behind.ring(0.5, 0.3 + bob, 0.11, 0.03, darken(c.glow, 0.15), 8, start=-90, end=90)
    c.fx.ring(0.5, 0.3 + bob, 0.11, 0.03, lighten(c.glow, 0.2), 8, start=90, end=270)
    a = t * math.tau
    c.ember(0.5 + math.sin(a) * 0.11, 0.3 + bob - math.cos(a) * 0.03, 0.008, WHITE)
    c.eyes(0.5, 0.55 + bob, gap=0.1, size=0.026, style="closed")
    c.mouth(0.5, 0.61 + bob, "smile", 0.02)
    c.lights = [Light(0.5, 0.3 + bob, 0.45, c.glow, 0.9), Light(0.5, 0.56 + bob, 0.25, WHITE, 0.4)]
    c.halo = 0.65


@design("Prism", "Spectra: a crisp glass prism with a face; a white beam enters one side and a moving rainbow fans out of the other.")
def prism(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    glass = mix(c.color, WHITE, 0.4)
    spectrum = [(255, 90, 110), (255, 170, 70), (255, 236, 90), (110, 230, 130), (90, 170, 255), (170, 110, 255)]
    shift = (c.index // 3) % 6
    c.behind.line([(0.08, 0.62), (0.38, 0.55)], (255, 255, 255), 6, alpha=200)
    for k in range(6):
        color = spectrum[(k + shift) % 6]
        c.behind.poly([(0.6, 0.55 + k * 0.006), (0.92, 0.48 + k * 0.05), (0.92, 0.52 + k * 0.05), (0.6, 0.56 + k * 0.006)],
                      color, alpha=210)
    b.poly([(0.5, 0.26), (0.73, 0.74), (0.27, 0.74)], glass)
    b.poly([(0.5, 0.3), (0.56, 0.42), (0.44, 0.7), (0.34, 0.7)], lighten(glass, 0.55))
    c.eyes(0.53, 0.58, gap=0.1, size=0.024)
    c.mouth(0.53, 0.645, "smile", 0.018)
    c.lights = [Light(0.74, 0.58, 0.35, spectrum[shift], 0.6), Light(0.26, 0.58, 0.3, WHITE, 0.5)]
    c.halo = 0.35


@design("Chrono", "Tock: a brass pocket-watch on two legs; its hands sweep the loop and it steps in time with the tick.")
def chrono(c: Canvas) -> None:
    t = c.t
    b = c.body
    step = 1 if (c.index // 6) % 2 == 0 else -1
    bounce = abs(wave(t, 3)) * -0.012
    brass = c.color
    face = (252, 244, 222)
    b.line([(0.43, 0.7 + bounce), (0.42 - step * 0.02, 0.83)], darken(brass, 0.35), 12)
    b.line([(0.57, 0.7 + bounce), (0.58 + step * 0.02, 0.83)], darken(brass, 0.35), 12)
    b.ellipse(0.41 - step * 0.02, 0.84, 0.035, 0.018, darken(brass, 0.4))
    b.ellipse(0.59 + step * 0.02, 0.84, 0.035, 0.018, darken(brass, 0.4))
    b.ring(0.5, 0.215 + bounce, 0.035, 0.03, darken(brass, 0.1), 9)
    b.poly([(0.47, 0.25 + bounce), (0.53, 0.25 + bounce), (0.535, 0.3 + bounce), (0.465, 0.3 + bounce)], lighten(brass, 0.1))
    b.circle(0.5, 0.52 + bounce, 0.215, brass)
    b.circle(0.5, 0.52 + bounce, 0.175, face)
    for k in range(12):
        a = k / 12 * math.tau
        r1, r2 = 0.155, (0.135 if k % 3 == 0 else 0.145)
        c.decal.line([(0.5 + math.sin(a) * r1, 0.52 + bounce - math.cos(a) * r1),
                      (0.5 + math.sin(a) * r2, 0.52 + bounce - math.cos(a) * r2)], darken(brass, 0.5), 4)
    for angle, length, width in ((t * math.tau, 0.13, 6), (t * math.tau / 12 + 2.2, 0.085, 8)):
        c.decal.line([(0.5, 0.52 + bounce), (0.5 + math.sin(angle) * length, 0.52 + bounce - math.cos(angle) * length)],
                     darken(brass, 0.55), width)
    c.decal.circle(0.5, 0.52 + bounce, 0.014, darken(brass, 0.55))
    c.eyes(0.5, 0.6 + bounce, gap=0.1, size=0.026, style="round")
    c.decal.ring(0.45, 0.6 + bounce, 0.036, 0.036, darken(brass, 0.4), 4)
    c.decal.ring(0.55, 0.6 + bounce, 0.036, 0.036, darken(brass, 0.4), 4)
    c.mouth(0.5, 0.665 + bounce, "smile", 0.02)
    tick = 1.0 if c.index % 6 == 0 else 0.75
    c.lights = [Light(0.5 + math.sin(t * math.tau) * 0.24, 0.52 - math.cos(t * math.tau) * 0.24, 0.32, c.glow, 0.7 * tick)]
    c.halo = 0.35
