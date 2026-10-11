"""Ground and blood: Sand, Earth, Nature, Poison, Blood, Amber."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Sand", "Dune: a lounging sphinx-cat in a striped headdress; its tail flicks and sand trickles through its paws.")
def sand(c: Canvas) -> None:
    t = c.t
    b = c.body
    stripe = (90, 120, 200)
    # tail flicking behind
    flick = wave(t, 2) * 0.05
    b.line([(0.7, 0.74), (0.8, 0.7), (0.84, 0.6 + flick), (0.8, 0.54 + flick)], darken(c.color, 0.1), 12, smooth=True)
    # lying body and forepaws
    b.blob([(0.26, 0.78), (0.3, 0.64), (0.5, 0.6), (0.72, 0.64), (0.78, 0.76), (0.6, 0.8), (0.4, 0.8)], c.color)
    b.ellipse(0.33, 0.79, 0.075, 0.03, lighten(c.color, 0.2))
    b.ellipse(0.5, 0.8, 0.075, 0.03, lighten(c.color, 0.2))
    # headdress
    b.blob([(0.3, 0.62), (0.32, 0.38), (0.5, 0.3), (0.68, 0.38), (0.7, 0.62), (0.6, 0.56), (0.4, 0.56)], c.color)
    for k in range(4):
        y = 0.4 + k * 0.05
        b.line([(0.33, y + 0.02), (0.37, y)], stripe, 7)
        b.line([(0.67, y + 0.02), (0.63, y)], stripe, 7)
    # face and ears
    b.poly([(0.36, 0.38), (0.34, 0.24), (0.45, 0.33)], c.color)
    b.poly([(0.64, 0.38), (0.66, 0.24), (0.55, 0.33)], c.color)
    b.ellipse(0.5, 0.45, 0.12, 0.11, lighten(c.color, 0.25))
    c.eyes(0.5, 0.44, gap=0.1, size=0.026, style="round", gaze=wave(t, 1) * 0.3)
    for side in (-1, 1):  # kohl wings
        c.decal.line([(0.5 + side * 0.075, 0.445), (0.5 + side * 0.105, 0.43)], INK, 5)
    c.mouth(0.5, 0.505, "cat", 0.016)
    for k in range(4):
        fall = (t * 2 + k / 4) % 1
        c.fx.circle(0.27 - k * 0.006, 0.8 + fall * 0.07, 0.006, lighten(c.color, 0.3), alpha=int(255 * (1 - fall)))
    c.lights = [Light(0.78, 0.22, 0.6, (255, 226, 150), 0.6)]
    c.halo = 0.3


@design("Earth", "Pebble: a mossy stone tortoise with a sprout on its shell; its head peeks out, looks around and tucks back in.")
def earth(c: Canvas) -> None:
    t = c.t
    b = c.body
    peek = 0.5 + 0.5 * wave(t, 1, -0.25)
    head_x = 0.27 - peek * 0.06
    stone = c.color
    moss = (110, 170, 80)
    for x in (0.36, 0.64):
        b.ellipse(x, 0.79, 0.055, 0.035, darken(stone, 0.25))
    b.circle(head_x, 0.66, 0.075, lighten(stone, 0.15))
    b.blob([(0.26, 0.74), (0.3, 0.56), (0.42, 0.45), (0.58, 0.44), (0.72, 0.52), (0.78, 0.7), (0.7, 0.78),
            (0.34, 0.78)], stone)
    # shell plates
    for x, y, r in ((0.5, 0.58, 0.06), (0.38, 0.65, 0.05), (0.63, 0.64, 0.05)):
        b.ellipse(x, y, r, r * 0.8, lighten(stone, 0.2))
    b.blob([(0.42, 0.47), (0.52, 0.43), (0.62, 0.46), (0.56, 0.5), (0.47, 0.5)], moss)
    sway = wave(t, 2) * 0.02
    b.line([(0.53, 0.45), (0.54 + sway, 0.34)], darken(moss, 0.3), 7)
    b.ellipse(0.5 + sway, 0.33, 0.04, 0.02, moss, rot=-25)
    b.ellipse(0.58 + sway, 0.32, 0.04, 0.02, lighten(moss, 0.2), rot=25)
    c.eyes(head_x - 0.01, 0.65, gap=0.06, size=0.018, gaze=-0.5 + peek)
    c.mouth(head_x - 0.01, 0.69, "smile", 0.015)
    c.lights = [Light(0.55, 0.3, 0.35, (220, 255, 160), 0.45)]
    c.halo = 0.25
    c.shade = 1.1


@design("Nature", "Sprig: a round seed spirit with two broad leaf arms and a branching twig crown; it waves, and a leaf drifts down.")
def nature(c: Canvas) -> None:
    t = c.t
    b = c.body
    leaf = lighten(c.color, 0.1)
    bark = (130, 90, 60)
    wavearm = wave(t, 2) * 14
    # twig crown
    b.line([(0.5, 0.4), (0.5, 0.26), (0.43, 0.19)], bark, 9)
    b.line([(0.5, 0.3), (0.58, 0.21)], bark, 8)
    for x, y, rot in ((0.42, 0.18, -30), (0.59, 0.2, 30), (0.51, 0.24, 0)):
        b.ellipse(x, y, 0.035, 0.018, lighten(leaf, 0.2), rot=rot + wave(t, 2) * 10)
    # leaf arms
    b.ellipse(0.27, 0.56, 0.1, 0.045, leaf, rot=-35 - wavearm)
    b.ellipse(0.73, 0.56, 0.1, 0.045, leaf, rot=35 + wavearm * 0.5)
    b.line([(0.33, 0.58), (0.2, 0.52)], darken(leaf, 0.2), 3)
    b.circle(0.5, 0.6, 0.18, (196, 150, 96))
    b.ellipse(0.5, 0.64, 0.13, 0.12, (226, 190, 130))
    c.eyes(0.5, 0.58, gap=0.11, size=0.027)
    c.mouth(0.5, 0.645, "smile", 0.022)
    c.cheeks(0.5, 0.625, 0.19, (240, 140, 120))
    fall = t
    c.fx.ellipse(0.72 + math.sin(fall * math.tau) * 0.05, 0.22 + fall * 0.55, 0.022, 0.011, lighten(leaf, 0.3),
                 rot=fall * 360)
    c.lights = [Light(0.5, 0.18, 0.45, c.glow, 0.5)]
    c.halo = 0.3


@design("Poison", "Toxi: a squat tree-frog with violet spots; its throat sac swells and glows, then it lets a drip fall.")
def poison(c: Canvas) -> None:
    t = c.t
    b = c.body
    sac = 0.5 + 0.5 * wave(t, 1, -0.25)
    spots = (150, 80, 200)
    for side in (-1, 1):
        b.ellipse(0.5 + side * 0.22, 0.8, 0.07, 0.03, darken(c.color, 0.15))
    b.blob([(0.24, 0.72), (0.28, 0.52), (0.4, 0.44), (0.6, 0.44), (0.72, 0.52), (0.76, 0.72), (0.62, 0.8),
            (0.38, 0.8)], c.color)
    for side in (-1, 1):  # eye domes on top
        b.circle(0.5 + side * 0.11, 0.42, 0.075, c.color)
    for x, y, r in ((0.32, 0.6, 0.025), (0.68, 0.62, 0.03), (0.6, 0.72, 0.02), (0.37, 0.73, 0.018)):
        b.circle(x, y, r, spots)
    b.ellipse(0.5, 0.68 + sac * 0.01, 0.07 + sac * 0.05, 0.04 + sac * 0.04, lighten(c.color, 0.5))
    c.eyes(0.5, 0.41, gap=0.22, size=0.04)
    c.mouth(0.5, 0.58, "smile", 0.06)
    drip = (t * 1 + 0.5) % 1
    if drip > 0.55:
        fall = (drip - 0.55) / 0.45
        c.fx.ellipse(0.62, 0.76 + fall * 0.1, 0.01, 0.015, lighten(c.color, 0.3), alpha=int(255 * (1 - fall * 0.6)))
    c.lights = [Light(0.5, 0.7, 0.2 + sac * 0.12, c.glow, 0.4 + sac * 0.6)]
    c.halo = 0.25 + sac * 0.2


@design("Blood", "Ruby: a stout heart with stubby limbs; it beats lub-dub twice each loop and its light throbs with it.")
def blood(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    beat = (t * 2) % 1
    pulse = max(0.0, 1 - beat * 8) + 0.6 * max(0.0, 1 - abs(beat - 0.2) * 9)
    s = 1 + pulse * 0.05
    cx, cy = 0.5, 0.56

    def p(x: float, y: float) -> tuple[float, float]:
        return cx + (x - cx) * s, cy + (y - cy) * s

    for side in (-1, 1):
        b.line([(0.5 + side * 0.1, 0.72), (0.5 + side * 0.11, 0.83)], darken(c.color, 0.3), 12)
        b.line([(0.5 + side * 0.2, 0.56), (0.5 + side * 0.27, 0.62 - pulse * 0.03)], darken(c.color, 0.2), 11)
    b.blob([p(0.5, 0.4), p(0.6, 0.31), p(0.72, 0.36), p(0.73, 0.5), p(0.62, 0.66), p(0.5, 0.77), p(0.38, 0.66),
            p(0.27, 0.5), p(0.28, 0.36), p(0.4, 0.31)], c.color)
    b.ellipse(*p(0.38, 0.41), 0.04 * s, 0.025 * s, lighten(c.color, 0.5), rot=-30)
    c.eyes(0.5, 0.52, gap=0.12, size=0.028 * s, style="happy" if pulse > 0.5 else "round")
    c.mouth(0.5, 0.6, "smile", 0.022)
    c.lights = [Light(0.5, 0.55, 0.28 + pulse * 0.1, (255, 120, 120), 0.4 + pulse * 0.6)]
    c.halo = 0.3 + pulse * 0.35


@design("Amber", "Honey: a sleepy amber drop with a fossil leaf caught inside; light pools in its core and a drip stretches beneath.")
def amber(c: Canvas) -> None:
    t = c.t
    b = c.body
    sway = wave(t, 1) * 0.012
    stretch = 0.5 + 0.5 * wave(t, 1)
    b.blob([(0.5 + sway, 0.27), (0.63, 0.44), (0.7, 0.6), (0.63, 0.76), (0.5, 0.8), (0.37, 0.76), (0.3, 0.6),
            (0.37, 0.44)], c.color)
    b.ellipse(0.5, 0.64, 0.13, 0.11, lighten(c.color, 0.3))
    # the fossil leaf inside, seen through the resin
    b.ellipse(0.56, 0.49, 0.05, 0.025, darken(c.color, 0.35), rot=40)
    b.line([(0.52, 0.53), (0.6, 0.45)], darken(c.color, 0.5), 3)
    b.ellipse(0.41, 0.43, 0.02, 0.04, lighten(c.color, 0.7), rot=25)
    b.blob([(0.47, 0.79), (0.53, 0.79), (0.52, 0.81 + stretch * 0.05), (0.5, 0.83 + stretch * 0.05),
            (0.48, 0.81 + stretch * 0.05)], c.color)
    c.eyes(0.5, 0.62, gap=0.11, size=0.026, style="sleepy")
    c.mouth(0.5, 0.68, "smile", 0.02)
    c.cheeks(0.5, 0.66, 0.19, (255, 120, 80))
    c.lights = [Light(0.5, 0.6, 0.3, c.glow, 0.6 + 0.2 * wave(t, 1, 0.3))]
    c.halo = 0.35
