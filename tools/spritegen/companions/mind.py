"""Deep and uncanny: Abyss, Smoke, Necrotic, Rune, Ink."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Abyss", "Lanternjaw: a deep-sea angler whose dangling lure is the light that paints its own face.")
def abyss(c: Canvas) -> None:
    t = c.t
    b = c.body
    bob = wave(t, 1) * 0.012
    deep = darken(c.color, 0.35)
    belly = lighten(deep, 0.2)
    swish = wave(t, 2) * 0.05
    b.blob([(0.72, 0.6 + bob), (0.84, 0.5 + bob + swish), (0.86, 0.68 + bob + swish), (0.75, 0.66 + bob)], darken(deep, 0.15))
    b.blob([(0.24, 0.6 + bob), (0.3, 0.44 + bob), (0.5, 0.38 + bob), (0.68, 0.45 + bob), (0.76, 0.6 + bob),
            (0.66, 0.76 + bob), (0.46, 0.8 + bob), (0.3, 0.74 + bob)], deep)
    b.blob([(0.34, 0.68 + bob), (0.5, 0.64 + bob), (0.66, 0.68 + bob), (0.56, 0.77 + bob), (0.42, 0.77 + bob)], belly)
    b.blob([(0.5, 0.62 + bob), (0.58, 0.58 + bob + wave(t, 2, 0.3) * 0.02), (0.6, 0.66 + bob)], darken(deep, 0.25))
    lx = 0.32 + wave(t, 1, 0.2) * 0.03
    ly = 0.24 + wave(t, 2, 0.1) * 0.02 + bob
    b.line([(0.44, 0.42 + bob), (0.4, 0.3 + bob), (lx + 0.02, ly - 0.02), (lx, ly)], darken(deep, 0.2), 9, smooth=True)
    c.decal.blob([(0.3, 0.63 + bob), (0.5, 0.67 + bob), (0.64, 0.64 + bob), (0.5, 0.71 + bob)], INK)
    for k in range(5):
        x = 0.34 + k * 0.065
        y = 0.64 + bob + (0.02 if k in (1, 3) else 0.012)
        c.decal.poly([(x - 0.012, y), (x + 0.012, y), (x, y - 0.03)], WHITE)
    c.cyclops(0.56, 0.5 + bob, 0.05, gaze=-0.8 + wave(t, 1) * 0.3, iris=(110, 220, 230))
    pulse = 0.8 + 0.2 * wave(t, 2)
    c.lights = [Light(lx, ly + 0.012, 0.55, c.glow, 1.15 * pulse, visible=True, orb=0.024)]
    c.halo = 0.2
    c.shade = 1.3


@design("Smoke", "Curl: a lazy smoke-ring creature that slowly rolls over itself, trailing wisps from its rim.")
def smoke(c: Canvas) -> None:
    t = c.t
    b = c.body
    roll = t * math.tau
    grey = c.color
    for k in range(3):
        u = (t + k / 3) % 1
        c.behind.circle(0.66 + u * 0.12, 0.42 - u * 0.2, 0.03 + u * 0.04, lighten(grey, 0.3), alpha=int(150 * (1 - u)))
    b.ellipse(0.5, 0.55, 0.24, 0.17, grey)
    b.ellipse(0.5, 0.55, 0.1, 0.06, (34, 34, 46))
    for k in range(8):
        a = roll + k / 8 * math.tau
        b.circle(0.5 + math.cos(a) * 0.17, 0.55 + math.sin(a) * 0.115, 0.035, lighten(grey, 0.25 if k % 2 else 0.1))
    c.eyes(0.5, 0.43, gap=0.1, size=0.022, style="sleepy")
    c.mouth(0.5, 0.67, "o", 0.014)
    c.lights = [Light(0.3, 0.3, 0.45, c.glow, 0.35)]
    c.halo = 0.3


@design("Necrotic", "Rattle: a small skull pup with a ghost-green glow behind its eye sockets; its jaw chatters and its tail wags.")
def necrotic(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    chatter = 0.012 if c.index % 4 < 2 else 0.0
    wag = wave(t, 4) * 0.04
    bone = (236, 232, 214)
    b.line([(0.64, 0.74), (0.74, 0.66 + wag)], bone, 9)
    b.circle(0.75, 0.65 + wag, 0.018, bone)
    for x in (0.4, 0.46, 0.54, 0.6):
        b.line([(x, 0.72), (x, 0.82)], bone, 9)
    b.blob([(0.36, 0.76), (0.38, 0.66), (0.62, 0.66), (0.64, 0.76)], bone)
    b.blob([(0.34, 0.5), (0.36, 0.34), (0.5, 0.28), (0.64, 0.34), (0.66, 0.5), (0.6, 0.6), (0.4, 0.6)], bone)
    b.poly([(0.38, 0.6 + chatter), (0.62, 0.6 + chatter), (0.58, 0.67 + chatter), (0.42, 0.67 + chatter)], bone)
    for x in (0.45, 0.5, 0.55):
        c.decal.line([(x, 0.6 + chatter * 0.5), (x, 0.635 + chatter)], darken(bone, 0.5), 3)
    for side in (-1, 1):
        c.decal.ellipse(0.5 + side * 0.065, 0.45, 0.045, 0.05, (26, 30, 30))
        if not c.blink:
            c.decal.circle(0.5 + side * 0.065, 0.455, 0.018, c.glow)
    c.decal.poly([(0.49, 0.53), (0.51, 0.53), (0.5, 0.56)], (26, 30, 30))
    c.lights = [Light(0.435, 0.455, 0.12, c.glow, 0.7), Light(0.565, 0.455, 0.12, c.glow, 0.7),
                Light(0.5, 0.9, 0.35, c.color, 0.35)]
    c.halo = 0.4
    c.shade = 0.9


@design("Rune", "Menhir: a little standing stone on stubby legs; the rune carved in its face lights stroke by stroke, then fades.")
def rune(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    stone = (150, 146, 160)
    step = abs(wave(t, 2)) * 0.012
    b.ellipse(0.42, 0.82, 0.045, 0.02, darken(stone, 0.3))
    b.ellipse(0.58, 0.82, 0.045, 0.02, darken(stone, 0.3))
    b.blob([(0.36, 0.8 - step), (0.34, 0.5 - step), (0.4, 0.3 - step), (0.52, 0.24 - step), (0.62, 0.3 - step),
            (0.66, 0.52 - step), (0.64, 0.8 - step)], stone)
    b.blob([(0.4, 0.3 - step), (0.52, 0.25 - step), (0.58, 0.29 - step), (0.46, 0.34 - step)], lighten(stone, 0.3))
    for x, y in ((0.4, 0.6), (0.6, 0.42)):
        b.circle(x, y - step, 0.02, (120, 170, 100))
    strokes = [[(0.5, 0.36), (0.5, 0.56)], [(0.5, 0.4), (0.57, 0.46)], [(0.5, 0.47), (0.43, 0.53)]]
    lit = int(((t * 1.0) % 1) * 5)
    for k, stroke in enumerate(strokes):
        pts = [(x, y - step) for x, y in stroke]
        on = k < lit and lit < 5
        c.decal.line(pts, c.color if on else darken(stone, 0.35), 7)
    c.eyes(0.5, 0.64 - step, gap=0.1, size=0.02, style="dot")
    c.mouth(0.5, 0.69 - step, "smile", 0.014)
    glow = min(lit, 3) / 3 if lit < 5 else 0.0
    c.lights = [Light(0.5, 0.46 - step, 0.3, c.glow, 0.15 + glow * 0.8)]
    c.halo = 0.2 + glow * 0.4


@design("Ink", "Quill: an ink-blot octopus holding a quill in one tentacle; it scribbles in the air while its arms curl.")
def ink(c: Canvas) -> None:
    t = c.t
    b = c.body
    bob = wave(t, 1) * 0.012
    body = c.color
    for k in range(6):
        x0 = 0.36 + k * 0.056
        curl = wave(t, 2, k * 0.17) * 0.03
        b.line([(x0, 0.62 + bob), (x0 + curl, 0.72 + bob), (x0 - curl * 0.5 + (k - 2.5) * 0.015, 0.8 + bob)],
               body, 14, smooth=True)
    b.blob([(0.3, 0.56 + bob), (0.33, 0.38 + bob), (0.5, 0.3 + bob), (0.67, 0.38 + bob), (0.7, 0.56 + bob),
            (0.6, 0.66 + bob), (0.4, 0.66 + bob)], body)
    b.ellipse(0.43, 0.39 + bob, 0.04, 0.025, lighten(body, 0.4), rot=-25)
    qx, qy = 0.74 + wave(t, 3) * 0.02, 0.48 + bob + wave(t, 3, 0.25) * 0.02
    b.line([(0.66, 0.6 + bob), (qx, qy + 0.05)], body, 12, smooth=True)
    c.decal.poly([(qx - 0.01, qy + 0.06), (qx + 0.08, qy - 0.16), (qx + 0.03, qy - 0.13)], (250, 246, 236))
    c.decal.line([(qx, qy + 0.05), (qx + 0.055, qy - 0.14)], darken(body, 0.4), 3)
    c.eyes(0.5, 0.5 + bob, gap=0.12, size=0.03, gaze=0.6)
    c.mouth(0.5, 0.58 + bob, "o", 0.014)
    trail = []
    for k in range(10):
        u = k / 9
        trail.append((0.66 + u * 0.18, 0.24 + math.sin(u * 7 + t * math.tau) * 0.025))
    shown = trail[: 2 + int(((t * 2) % 1) * 8)]
    c.fx.line(shown, lighten(c.glow, 0.2), 4)
    c.lights = [Light(qx + 0.03, qy - 0.1, 0.3, c.glow, 0.55), Light(0.3, 0.3, 0.45, WHITE, 0.2)]
    c.halo = 0.3
