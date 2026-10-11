"""Matter: Crystal, Steel, Gold, Magnet, Gravity, Mirror."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Crystal", "Geode: a hermit crab carrying a crystal cluster for a shell; it snips its claws and the cluster catches its light.")
def crystal(c: Canvas) -> None:
    t = c.t
    b = c.body
    shell = (236, 150, 120)
    snip = 0.5 + 0.5 * wave(t, 3)
    for side in (-1, 1):
        for k in range(3):
            b.line([(0.5 + side * 0.08, 0.72), (0.5 + side * (0.16 + k * 0.04), 0.8 + (k % 2) * 0.01)], darken(shell, 0.2), 7)
    # cluster of crystals as the shell
    for x, top, w, shade in ((0.44, 0.22, 0.06, 0.3), (0.56, 0.28, 0.07, 0.0), (0.66, 0.38, 0.05, 0.2), (0.36, 0.36, 0.05, 0.1)):
        color = lighten(c.color, shade)
        b.poly([(x - w, 0.6), (x - w * 0.8, top + 0.06), (x, top), (x + w * 0.8, top + 0.06), (x + w, 0.6)], color)
        b.poly([(x - w * 0.2, 0.58), (x - w * 0.3, top + 0.08), (x, top + 0.02), (x + w * 0.1, 0.58)], lighten(color, 0.5))
    b.blob([(0.3, 0.7), (0.34, 0.58), (0.5, 0.55), (0.66, 0.58), (0.7, 0.7), (0.5, 0.76)], shell)
    for side in (-1, 1):
        cx, cy = 0.5 + side * 0.24, 0.62
        b.circle(cx, cy, 0.05, lighten(shell, 0.1))
        gap = 0.03 * snip
        b.poly([(cx + side * 0.02, cy - 0.01), (cx + side * 0.09, cy - 0.04 - gap), (cx + side * 0.07, cy - 0.005)],
               lighten(shell, 0.1))
        b.line([(0.5 + side * 0.04, 0.58), (0.5 + side * 0.06, 0.5)], shell, 6)
        b.circle(0.5 + side * 0.06, 0.49, 0.025, WHITE)
    c.decal.circle(0.44 + wave(t, 1) * 0.005, 0.49, 0.013, INK) if not c.blink else None
    c.decal.circle(0.56 + wave(t, 1) * 0.005, 0.49, 0.013, INK) if not c.blink else None
    c.mouth(0.5, 0.66, "smile", 0.02)
    sweep = 0.3 + (t % 1) * 0.4
    c.lights = [Light(sweep, 0.3, 0.25, c.glow, 0.7), Light(0.5, 0.42, 0.3, c.color, 0.35)]
    c.halo = 0.35


@design("Steel", "Rivet: a riveted boxy robot with a visor face; its antenna bulb blinks and its head tilts to listen.")
def steel(c: Canvas) -> None:
    t = c.t
    b = c.body
    tilt = wave(t, 1) * 0.015
    metal = c.color
    bulb_on = (c.index // 4) % 3 == 0
    b.ellipse(0.42, 0.82, 0.05, 0.02, darken(metal, 0.4))
    b.ellipse(0.58, 0.82, 0.05, 0.02, darken(metal, 0.4))
    b.poly([(0.36, 0.62), (0.64, 0.62), (0.62, 0.8), (0.38, 0.8)], darken(metal, 0.15))
    b.circle(0.5, 0.71, 0.03, (255, 180, 80))
    for side in (-1, 1):
        b.line([(0.5 + side * 0.15, 0.66), (0.5 + side * 0.22, 0.74 + wave(t, 2) * side * 0.02)], darken(metal, 0.3), 9)
    # head
    hx = 0.5 + tilt
    b.poly([(hx - 0.17, 0.33), (hx + 0.17, 0.33 + tilt), (hx + 0.17, 0.6 + tilt), (hx - 0.17, 0.6)], metal)
    b.poly([(hx - 0.13, 0.4), (hx + 0.13, 0.4 + tilt), (hx + 0.13, 0.52 + tilt), (hx - 0.13, 0.52)], (30, 40, 60))
    for x, y in ((hx - 0.15, 0.35), (hx + 0.15, 0.35 + tilt), (hx - 0.15, 0.58), (hx + 0.15, 0.58 + tilt)):
        b.circle(x, y, 0.01, lighten(metal, 0.5))
    b.line([(hx, 0.33 + tilt / 2), (hx + 0.01, 0.23)], darken(metal, 0.3), 5)
    b.circle(hx + 0.01, 0.22, 0.022, (255, 90, 90) if bulb_on else (120, 60, 70))
    if not c.blink:
        for side in (-1, 1):
            c.decal.ellipse(hx + side * 0.06, 0.46 + tilt * side * -0.5, 0.03, 0.022, (120, 230, 255))
    else:
        for side in (-1, 1):
            c.decal.line([(hx + side * 0.06 - 0.03, 0.46), (hx + side * 0.06 + 0.03, 0.46)], (120, 230, 255), 5)
    c.decal.line([(hx - 0.04, 0.565), (hx + 0.04, 0.565 + tilt)], darken(metal, 0.5), 4)
    c.lights = [Light(hx + 0.01, 0.22, 0.3, (255, 110, 110), 0.8 if bulb_on else 0.1, visible=bulb_on, orb=0.016),
                Light(hx, 0.46, 0.16, (120, 230, 255), 0.4)]
    c.halo = 0.25
    c.shade = 1.2


@design("Gold", "Doubloon: a cheeky coin with a face on one side and a star stamped on the other; it flips end over end.")
def gold(c: Canvas) -> None:
    t = c.t
    b = c.body
    angle = t * math.tau
    width = abs(math.cos(angle))
    front = math.cos(angle) >= 0
    hop = abs(math.sin(angle)) * 0.04
    cy = 0.5 - hop
    rim = darken(c.color, 0.2)
    b.ellipse(0.5, cy, max(0.025, 0.2 * width), 0.2, rim)
    if width > 0.2:
        b.ellipse(0.5, cy, 0.165 * width, 0.165, c.color)
        b.ellipse(0.5 - 0.06 * width, cy - 0.07, 0.04 * width, 0.03, lighten(c.color, 0.6), rot=-30)
        if front:
            if width > 0.55:
                c.eyes(0.5, cy - 0.01, gap=0.1 * width, size=0.026)
                c.mouth(0.5, cy + 0.06, "grin", 0.025 * width)
        else:
            b.star(0.5, cy, 0.09, 0.45, 5, darken(c.color, 0.25))
            b.poly([(0.5 - 0.09 * width, cy), (0.5 + 0.09 * width, cy)], c.color)
    for side in (-1, 1):
        b.line([(0.5 + side * 0.04, cy + 0.19), (0.5 + side * 0.06, 0.8)], rim, 9)
    glint = (t * 2) % 1
    if glint < 0.25:
        c.fx.star(0.5 + 0.12 * width, cy - 0.12, 0.022, 0.25, 4, WHITE)
    c.lights = [Light(0.3 + glint * 0.4, cy - 0.15, 0.25, WHITE, 0.6), Light(0.5, cy, 0.3, c.glow, 0.3)]
    c.halo = 0.4


@design("Magnet", "Polly: a horseshoe magnet with a red and a blue pole for feet; it hops, and field lines pulse between its poles.")
def magnet(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    hop = abs(wave(t, 2)) * 0.035
    red, blue = (232, 72, 90), (90, 140, 255)
    cy = 0.46 - hop
    b.ring(0.5, cy, 0.15, 0.15, red, 52, start=-90, end=0)
    b.ring(0.5, cy, 0.15, 0.15, blue, 52, start=0, end=90)
    b.poly([(0.315, cy), (0.39, cy), (0.39, cy + 0.26), (0.315, cy + 0.26)], red)
    b.poly([(0.61, cy), (0.685, cy), (0.685, cy + 0.26), (0.61, cy + 0.26)], blue)
    b.poly([(0.315, cy + 0.2), (0.39, cy + 0.2), (0.39, cy + 0.26), (0.315, cy + 0.26)], (225, 228, 238))
    b.poly([(0.61, cy + 0.2), (0.685, cy + 0.2), (0.685, cy + 0.26), (0.61, cy + 0.26)], (225, 228, 238))
    c.eyes(0.5, cy - 0.15, gap=0.1, size=0.024)
    c.mouth(0.5, cy - 0.1, "smile", 0.016)
    pulse = (t * 2) % 1
    for k in range(2):
        r = 0.05 + ((pulse + k * 0.5) % 1) * 0.1
        c.fx.ring(0.5, cy + 0.26, r, r * 0.7, (200, 220, 255), 4, start=90 + 10, end=270 - 10,
                  alpha=int(220 * (1 - (pulse + k * 0.5) % 1)))
    c.lights = [Light(0.35, cy + 0.26, 0.25, red, 0.5), Light(0.65, cy + 0.26, 0.25, blue, 0.5)]
    c.halo = 0.3
    c.halo_color = (200, 190, 255)


@design("Gravity", "Orbit: a tiny ringed planet with a sleepy face; two moons circle it, passing behind and in front.")
def gravity(c: Canvas) -> None:
    t = c.t
    b = c.body
    c.behind.ring(0.5, 0.54, 0.3, 0.07, darken(c.glow, 0.2), 9, rot=-15, start=-90, end=90)
    b.circle(0.5, 0.54, 0.17, c.color)
    b.ellipse(0.46, 0.5, 0.12, 0.05, lighten(c.color, 0.2), rot=-15)
    b.ellipse(0.55, 0.62, 0.1, 0.03, darken(c.color, 0.15), rot=-15)
    c.eyes(0.5, 0.53, gap=0.1, size=0.026, style="sleepy")
    c.mouth(0.5, 0.6, "o", 0.016)
    c.fx.ring(0.5, 0.54, 0.3, 0.07, c.glow, 9, rot=-15, start=90, end=270)
    for k, (speed, size, color) in enumerate(((1, 0.03, (230, 220, 255)), (2, 0.02, (255, 210, 160)))):
        a = t * math.tau * speed + k * math.pi
        x, y = 0.5 + math.cos(a) * 0.36, 0.54 + math.sin(a) * 0.11
        target = c.fx if math.sin(a) > 0 else c.behind
        target.circle(x, y, size, color)
        target.circle(x - size * 0.3, y - size * 0.3, size * 0.35, WHITE)
    moon = (0.5 + math.cos(t * math.tau) * 0.36, 0.54 + math.sin(t * math.tau) * 0.11)
    c.lights = [Light(moon[0], moon[1], 0.3, (230, 220, 255), 0.55), Light(0.5, 0.3, 0.4, c.glow, 0.3)]
    c.halo = 0.4


@design("Mirror", "Glint: a hand mirror with a polite face in the glass; a bright reflection sweeps across it and it winks.")
def mirror(c: Canvas) -> None:
    t = c.t
    b = c.body
    frame = (196, 160, 230)
    sway = wave(t, 1) * 0.01
    b.poly([(0.47 + sway, 0.66), (0.53 + sway, 0.66), (0.54 + sway, 0.84), (0.46 + sway, 0.84)], darken(frame, 0.2))
    b.ellipse(0.5 + sway, 0.46, 0.18, 0.22, frame)
    b.ellipse(0.5 + sway, 0.46, 0.14, 0.18, mix(c.color, (150, 175, 210), 0.5))
    sweep = (t * 1.0) % 1
    x = 0.34 + sweep * 0.32
    # a vertical band bounded by the glass oval, so the reflection never leaves the mirror
    gx, gy, rx, ry = 0.5 + sway, 0.46, 0.13, 0.17
    left, right = max(gx - rx + 0.005, x - 0.035), min(gx + rx - 0.005, x + 0.02)
    if right - left > 0.008:
        top, bottom = [], []
        for k in range(7):
            px = left + (right - left) * k / 6
            half = ry * math.sqrt(max(0.0, 1 - ((px - gx) / rx) ** 2))
            top.append((px, gy - half))
            bottom.append((px, gy + half))
        b.poly(top + bottom[::-1], (245, 250, 255), alpha=190)
    wink = c.index % 18 in (11, 12)
    if wink and not c.blink:
        c.decal.circle(0.45 + sway, 0.46, 0.016, INK)
        c.decal.line([(0.53 + sway, 0.465), (0.57 + sway, 0.465)], INK, 6)
    else:
        c.eyes(0.5 + sway, 0.46, gap=0.09, size=0.022, style="dot")
    c.mouth(0.5 + sway, 0.52, "smile", 0.018)
    c.lights = [Light(x, 0.4, 0.25, WHITE, 0.7), Light(0.5, 0.2, 0.4, c.glow, 0.3)]
    c.halo = 0.35
