"""Life: Vital, Thorn, Spore, Bloom, Feather, Dream."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Vital", "Pulse: a cheerful bean with a cross-shaped badge; a heartbeat trace runs across its belly in time with its glow.")
def vital(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    beat = (t * 2) % 1
    squash = max(0.0, 1 - beat * 6) * 0.02
    b.blob([(0.34, 0.5), (0.4, 0.36), (0.5, 0.32 + squash), (0.6, 0.36), (0.66, 0.5), (0.65, 0.72), (0.5, 0.8),
            (0.35, 0.72)], c.color)
    b.ellipse(0.5, 0.66, 0.12, 0.1, lighten(c.color, 0.4))
    b.poly([(0.47, 0.38), (0.53, 0.38), (0.53, 0.41), (0.56, 0.41), (0.56, 0.45), (0.53, 0.45), (0.53, 0.48), (0.47, 0.48),
            (0.47, 0.45), (0.44, 0.45), (0.44, 0.41), (0.47, 0.41)], WHITE)
    trace = []
    head = beat
    for k in range(21):
        u = k / 20
        x = 0.4 + u * 0.2
        spike = 0.0
        if abs(u - 0.5) < 0.08:
            spike = -0.05 if u < 0.5 else 0.03
        trace.append((x, 0.66 + spike))
    visible = trace[: max(2, int(len(trace) * min(1, head * 1.5)))]
    c.decal.line(visible, darken(c.color, 0.5), 4)
    c.eyes(0.5, 0.55, gap=0.11, size=0.025)
    c.mouth(0.5, 0.6, "smile", 0.016)
    c.lights = [Light(0.5, 0.66, 0.3, c.glow, 0.4 + squash * 25)]
    c.halo = 0.3 + squash * 10


@design("Thorn", "Prickle: a round cactus hedgehog with a single red flower; its spines bristle up and smooth down as it breathes.")
def thorn(c: Canvas) -> None:
    t = c.t
    b = c.body
    bristle = 0.5 + 0.5 * wave(t, 1)
    for k in range(16):
        a = math.radians(-160 + k * 140 / 15 + 70)
        a = math.radians(200 + k * 140 / 15)
        base = (0.5 + math.cos(a) * 0.18, 0.58 + math.sin(a) * 0.17)
        length = 0.05 + bristle * 0.03
        tip = (0.5 + math.cos(a) * (0.18 + length), 0.58 + math.sin(a) * (0.17 + length))
        b.poly([(base[0] - math.sin(a) * 0.02, base[1] + math.cos(a) * 0.02), tip,
                (base[0] + math.sin(a) * 0.02, base[1] - math.cos(a) * 0.02)], darken(c.color, 0.25))
    b.blob([(0.3, 0.7), (0.32, 0.52), (0.42, 0.42), (0.58, 0.42), (0.68, 0.52), (0.7, 0.7), (0.6, 0.8), (0.4, 0.8)], c.color)
    b.ellipse(0.5, 0.67, 0.11, 0.09, (240, 214, 170))
    for side in (-1, 1):
        b.ellipse(0.5 + side * 0.12, 0.8, 0.045, 0.022, darken(c.color, 0.3))
    for k in range(5):
        a = k / 5 * math.tau + t * math.tau * 0.2
        b.ellipse(0.6 + math.cos(a) * 0.025, 0.36 + math.sin(a) * 0.025, 0.025, 0.017, c.glow, rot=math.degrees(a))
    b.circle(0.6, 0.36, 0.014, (255, 220, 120))
    c.eyes(0.5, 0.63, gap=0.1, size=0.022)
    c.decal.circle(0.5, 0.675, 0.012, INK)
    c.cheeks(0.5, 0.67, 0.17, (255, 140, 150))
    c.lights = [Light(0.6, 0.36, 0.3, c.glow, 0.6)]
    c.halo = 0.3


@design("Spore", "Puffcap: a squat mushroom with a spotted cap; it bounces on its stalk and puffs a little cloud of glowing spores.")
def spore(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    bounce = (t * 2) % 1
    squash = max(0.0, 1 - bounce * 5) * 0.03
    stalk = (244, 232, 206)
    b.blob([(0.4, 0.82), (0.41, 0.62 + squash), (0.59, 0.62 + squash), (0.6, 0.82)], stalk)
    cap_y = 0.52 + squash
    b.blob([(0.24, cap_y + 0.06), (0.3, cap_y - 0.1), (0.5, cap_y - 0.18), (0.7, cap_y - 0.1), (0.76, cap_y + 0.06),
            (0.5, cap_y + 0.1)], c.color)
    for x, y, r in ((0.4, -0.08, 0.03), (0.56, -0.12, 0.025), (0.64, -0.02, 0.02), (0.33, 0.01, 0.018)):
        b.circle(x, cap_y + y, r, lighten(c.color, 0.6))
    c.eyes(0.5, 0.7 + squash * 0.5, gap=0.08, size=0.02)
    c.mouth(0.5, 0.75 + squash * 0.5, "smile", 0.013)
    for k in range(6):
        u = (bounce + k / 6) % 1
        a = k * 1.1
        c.ember(0.5 + math.cos(a) * u * 0.25, cap_y - 0.12 - u * 0.15 + math.sin(a) * u * 0.05, 0.008 * (1 - u), c.glow)
    c.lights = [Light(0.5, cap_y - 0.22, 0.35, c.glow, 0.45 + squash * 10)]
    c.halo = 0.35


@design("Bloom", "Petal: a flower bud with a face; its petals breathe open and closed around it over the loop.")
def bloom(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    openness = 0.5 + 0.5 * wave(t, 1, -0.25)
    leaf = (110, 200, 110)
    b.line([(0.5, 0.66), (0.5, 0.84)], darken(leaf, 0.2), 9)
    b.ellipse(0.42, 0.78, 0.06, 0.025, leaf, rot=-25)
    b.ellipse(0.58, 0.8, 0.06, 0.025, leaf, rot=25)
    for k in range(6):
        a = math.radians(k * 60 + 30)
        spread = 0.07 + openness * 0.06
        b.ellipse(0.5 + math.cos(a) * spread, 0.5 + math.sin(a) * spread, 0.085, 0.055, c.color,
                  rot=math.degrees(a))
    b.circle(0.5, 0.5, 0.11, lighten(c.color, 0.45))
    c.eyes(0.5, 0.49, gap=0.08, size=0.02, style="happy" if openness > 0.85 else "round")
    c.mouth(0.5, 0.54, "smile", 0.014)
    c.cheeks(0.5, 0.525, 0.13, (255, 120, 150))
    c.lights = [Light(0.5, 0.5, 0.2 + openness * 0.15, c.glow, 0.4 + openness * 0.35)]
    c.halo = 0.3 + openness * 0.2


@design("Feather", "Plume: a round owlet made of soft layered feathers; it ruffles its wings and its ear tufts wiggle.")
def feather(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    ruffle = wave(t, 2) * 6
    plume = c.color
    b.poly([(0.38, 0.36), (0.33, 0.24 + wave(t, 2) * 0.01), (0.44, 0.33)], darken(plume, 0.2))
    b.poly([(0.62, 0.36), (0.67, 0.24 - wave(t, 2) * 0.01), (0.56, 0.33)], darken(plume, 0.2))
    b.ellipse(0.5, 0.56, 0.19, 0.24, plume)
    b.ellipse(0.31, 0.6, 0.06, 0.13, darken(plume, 0.12), rot=15 + ruffle)
    b.ellipse(0.69, 0.6, 0.06, 0.13, darken(plume, 0.12), rot=-15 - ruffle)
    for k in range(3):
        y = 0.6 + k * 0.05
        b.ring(0.5, y, 0.07 - k * 0.012, 0.03, darken(plume, 0.18), 4, start=100, end=260)
    for side in (-1, 1):
        b.circle(0.5 + side * 0.07, 0.45, 0.06, lighten(plume, 0.4))
    c.eyes(0.5, 0.45, gap=0.14, size=0.03)
    c.decal.poly([(0.48, 0.5), (0.52, 0.5), (0.5, 0.535)], (255, 180, 80))
    for side in (-1, 1):
        b.ellipse(0.5 + side * 0.06, 0.8, 0.03, 0.015, (255, 180, 80))
    c.lights = [Light(0.3, 0.3, 0.5, c.glow, 0.45)]
    c.halo = 0.3


@design("Dream", "Snooze: a cloud-wool sheep fast asleep on a pillow; its breath rises as little glowing z's.")
def dream(c: Canvas) -> None:
    t = c.t
    b = c.body
    breath = wave(t, 1) * 0.012
    wool = lighten(c.color, 0.55)
    b.ellipse(0.5, 0.78, 0.26, 0.05, (150, 140, 220))
    for x, y in ((0.36, 0.62), (0.46, 0.56), (0.58, 0.56), (0.66, 0.63), (0.5, 0.67), (0.38, 0.7), (0.62, 0.71)):
        b.circle(x, y - breath, 0.075, wool)
    b.ellipse(0.32, 0.6 - breath, 0.075, 0.065, darken(c.color, 0.2))
    b.ellipse(0.27, 0.58 - breath, 0.03, 0.018, darken(c.color, 0.3), rot=-30)
    c.decal.ring(0.31, 0.6 - breath, 0.02, 0.01, INK, 5, start=100, end=260)
    c.decal.ring(0.35, 0.6 - breath, 0.02, 0.01, INK, 5, start=100, end=260)
    for k in range(3):
        u = (t + k / 3) % 1
        size = 0.02 + u * 0.015
        x, y = 0.4 + u * 0.18, 0.46 - u * 0.24
        alpha = int(255 * (1 - u))
        c.fx.line([(x - size, y - size), (x + size, y - size), (x - size, y + size), (x + size, y + size)],
                  lighten(c.glow, 0.3), 5, alpha=alpha)
    c.lights = [Light(0.55, 0.3, 0.45, c.glow, 0.4)]
    c.halo = 0.35
