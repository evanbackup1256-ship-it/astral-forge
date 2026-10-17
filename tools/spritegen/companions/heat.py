"""Heat and charge: Fire, Magma, Solar, Lightning, Plasma, Sonic."""

from __future__ import annotations

import math

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Fire", "Kindle: a teardrop flame imp whose three crown tongues flicker out of step; it sways and sheds embers.")
def fire(c: Canvas) -> None:
    t = c.t
    b = c.body
    sway = wave(t, 2) * 0.012
    squash = 1 + wave(t, 2, 0.25) * 0.025
    hot = lighten(c.color, 0.35)
    core = (255, 236, 150)
    # crown tongues, each on its own rhythm
    tongues = [(-0.11, 0.30, 1, 0.0), (0.0, 0.18, 3, 0.3), (0.12, 0.27, 2, 0.6)]
    for dx, tip, cycles, off in tongues:
        tipx = 0.5 + dx + sway * 2 + wave(t, cycles, off) * 0.025
        tipy = tip + wave(t, cycles, off + 0.25) * 0.03
        b.blob([(0.5 + dx - 0.08, 0.5), (tipx - 0.02, (tipy + 0.5) / 2), (tipx, tipy),
                (tipx + 0.03, (tipy + 0.5) / 2), (0.5 + dx + 0.08, 0.5)], c.color)
    # teardrop body
    b.blob([(0.5 + sway, 0.33), (0.66, 0.5), (0.69 * squash - 0.17 * (squash - 1), 0.66), (0.6, 0.79),
            (0.5, 0.815), (0.4, 0.79), (0.31, 0.66), (0.34, 0.5)], c.color)
    b.blob([(0.5 + sway, 0.46), (0.61, 0.6), (0.58, 0.74), (0.5, 0.77), (0.42, 0.74), (0.39, 0.6)], hot)
    b.blob([(0.5 + sway * 0.5, 0.58), (0.56, 0.67), (0.54, 0.75), (0.46, 0.75), (0.44, 0.67)], core)
    # stubby arms
    b.ellipse(0.29, 0.62 + wave(t, 2) * 0.01, 0.045, 0.035, c.color, rot=-30)
    b.ellipse(0.71, 0.63 - wave(t, 2) * 0.01, 0.045, 0.035, c.color, rot=30)
    c.eyes(0.5 + sway, 0.585, gap=0.1, size=0.032, gaze=wave(t, 1) * 0.3)
    c.mouth(0.5 + sway, 0.665, "smile", 0.026)
    c.cheeks(0.5 + sway, 0.645, 0.17, (255, 120, 60))
    # embers rise and fade over the loop
    for k in range(3):
        phase = (t + k / 3) % 1
        x = 0.5 + (k - 1) * 0.12 + wave(phase, 1, k * 0.3) * 0.02
        y = 0.3 - phase * 0.16
        r = 0.011 * (1 - phase)
        if r > 0.003:
            c.ember(x, y, r, c.glow, (255, 250, 220))
    flicker = 0.85 + 0.15 * wave(t, 3) * wave(t, 5, 0.2)
    c.lights = [Light(0.5, 0.66, 0.42, (255, 200, 90), 0.9 * flicker)]
    c.halo = 0.55 + 0.12 * flicker


@design("Magma", "Slag: a squat boulder-toad with a cooled crust; molten cracks pulse with its breathing and lava drips off its chin.")
def magma(c: Canvas) -> None:
    t = c.t
    b = c.body
    breathe = wave(t, 1) * 0.012
    crust = darken(c.color, 0.62)
    lava = (255, 170, 60)
    # feet
    b.ellipse(0.32, 0.8, 0.07, 0.035, darken(crust, 0.1))
    b.ellipse(0.68, 0.8, 0.07, 0.035, darken(crust, 0.1))
    # heavy rounded body, wider than tall
    b.blob([(0.22, 0.66), (0.26, 0.5 - breathe), (0.4, 0.42 - breathe), (0.6, 0.42 - breathe), (0.74, 0.5 - breathe),
            (0.79, 0.66), (0.68, 0.79), (0.32, 0.79)], crust)
    # brow ridge
    b.blob([(0.3, 0.52 - breathe), (0.5, 0.47 - breathe), (0.7, 0.52 - breathe), (0.5, 0.5 - breathe)], darken(crust, 0.2))
    heat = 0.6 + 0.4 * (0.5 + 0.5 * wave(t, 1, 0.1))
    glow = mix(c.color, lava, heat)
    cracks = [[(0.27, 0.6), (0.33, 0.64), (0.3, 0.71), (0.36, 0.75)],
              [(0.72, 0.58), (0.67, 0.64), (0.71, 0.7)],
              [(0.45, 0.45 - breathe), (0.48, 0.42 - breathe), (0.55, 0.44 - breathe)],
              [(0.4, 0.775), (0.47, 0.75), (0.52, 0.78)]]
    for crack in cracks:
        b.line(crack, glow, 7)
    c.eyes(0.5, 0.57, gap=0.15, size=0.03, style="round", gaze=wave(t, 1) * 0.2)
    for side in (-1, 1):  # heavy lids
        c.decal.line([(0.5 + side * 0.04, 0.545), (0.5 + side * 0.115, 0.55)], crust, 11)
    c.mouth(0.5, 0.665, "wobble", 0.04)
    # a drip forms under the chin and falls once per loop
    drop = (t * 1.0) % 1
    if drop < 0.6:
        c.fx.ellipse(0.53, 0.71 + drop * 0.02, 0.01 + drop * 0.008, 0.012 + drop * 0.01, lava)
    else:
        fall = (drop - 0.6) / 0.4
        c.ember(0.53, 0.73 + fall * 0.11, 0.012 * (1 - fall * 0.5), lava, (255, 240, 180))
    c.lights = [Light(0.3, 0.66, 0.24, lava, 0.8 * heat), Light(0.7, 0.64, 0.22, lava, 0.7 * heat),
                Light(0.5, 0.74, 0.2, lava, 0.6 * heat)]
    c.halo = 0.35 + 0.15 * heat
    c.shade = 1.2


@design("Solar", "Sunny: a beaming sun-disc whose twelve rays turn a full step each loop while its warmth pulses outward.")
def solar(c: Canvas) -> None:
    t = c.t
    b = c.body
    spin = t * 30
    ray = lighten(c.color, 0.15)
    for k in range(12):
        a = math.radians(spin + k * 30)
        length = 0.3 if k % 2 == 0 else 0.255
        width = 0.055 if k % 2 == 0 else 0.04
        tip = (0.5 + math.sin(a) * length, 0.52 - math.cos(a) * length)
        left = (0.5 + math.sin(a - width * 4) * 0.17, 0.52 - math.cos(a - width * 4) * 0.17)
        right = (0.5 + math.sin(a + width * 4) * 0.17, 0.52 - math.cos(a + width * 4) * 0.17)
        b.poly([left, tip, right], ray)
    b.circle(0.5, 0.52, 0.19, c.color)
    b.circle(0.5, 0.52, 0.145, lighten(c.color, 0.35))
    c.eyes(0.5, 0.5, gap=0.11, size=0.03, style="happy" if c.index % 18 < 9 else "round")
    c.mouth(0.5, 0.58, "grin", 0.03)
    c.cheeks(0.5, 0.56, 0.19, (255, 120, 80))
    pulse = 0.75 + 0.25 * (0.5 + 0.5 * wave(t, 2))
    c.lights = [Light(0.5, 0.52, 0.36, (255, 236, 160), 0.6 * pulse), Light(0.36, 0.36, 0.3, WHITE, 0.25)]
    c.halo = 0.55 + 0.25 * pulse


@design("Lightning", "Volt: a zig-zag imp with one wide eye; a live arc snaps between its horn tips and it twitches when it fires.")
def lightning(c: Canvas) -> None:
    import random

    t = c.t
    rnd = random.Random(c.index * 97 + 13)
    firing = c.index % 9 in (0, 1, 5)
    jx = (rnd.random() - 0.5) * (0.018 if firing else 0.006)
    jy = (rnd.random() - 0.5) * (0.012 if firing else 0.004)
    b = c.body
    hi = lighten(c.color, 0.45)
    # horns
    b.poly([(0.36 + jx, 0.4 + jy), (0.3 + jx, 0.2 + jy), (0.42 + jx, 0.36 + jy)], hi)
    b.poly([(0.64 + jx, 0.4 + jy), (0.7 + jx, 0.2 + jy), (0.58 + jx, 0.36 + jy)], hi)
    # bolt body: two offset wedges
    b.poly([(0.33 + jx, 0.36 + jy), (0.68 + jx, 0.36 + jy), (0.6 + jx, 0.55 + jy), (0.7 + jx, 0.55 + jy),
            (0.45 + jx, 0.86 + jy), (0.5 + jx, 0.63 + jy), (0.36 + jx, 0.63 + jy)], c.color)
    b.poly([(0.38 + jx, 0.39 + jy), (0.62 + jx, 0.39 + jy), (0.56 + jx, 0.5 + jy), (0.42 + jx, 0.5 + jy)], hi)
    c.cyclops(0.5 + jx, 0.46 + jy, 0.055, gaze=(rnd.random() - 0.5) if firing else wave(t, 1) * 0.5,
              iris=(255, 230, 90))
    c.mouth(0.52 + jx, 0.585 + jy, "fang" if firing else "flat", 0.022)
    if firing:
        points = [(0.3 + jx, 0.2 + jy)]
        for k in range(1, 6):
            points.append((0.3 + k * 0.08 + jx, 0.2 + jy + (rnd.random() - 0.5) * 0.06))
        points.append((0.7 + jx, 0.2 + jy))
        c.fx.line(points, (230, 240, 255), 6)
        c.fx.line(points, WHITE, 2.5)
    strength = 1.0 if firing else 0.35
    c.lights = [Light(0.5 + jx, 0.2 + jy, 0.45, (200, 220, 255), strength, visible=firing, orb=0.02)]
    c.halo = 0.3 + (0.45 if firing else 0.0)


@design("Plasma", "Orbi: a wobbling jelly orb with a churning core; two charged rings orbit it on crossed tilts.")
def plasma(c: Canvas) -> None:
    t = c.t
    b = c.body
    wob = wave(t, 2) * 0.012
    ring = lighten(c.color, 0.5)
    # back halves of the rings sit behind the orb
    for tilt, phase in ((-24, 0.0), (28, 0.5)):
        c.behind.ring(0.5, 0.53, 0.3, 0.075, darken(ring, 0.25), 6, rot=tilt, start=-90, end=90, alpha=220)
    b.ellipse(0.5, 0.53, 0.2 + wob, 0.2 - wob, c.color)
    b.ellipse(0.5, 0.53, 0.15 + wob, 0.15 - wob, lighten(c.color, 0.25))
    # churning core: three arms turning a third per loop
    for k in range(3):
        a = t * math.tau / 3 + k * math.tau / 3
        b.line([(0.5, 0.53), (0.5 + math.cos(a) * 0.05, 0.53 + math.sin(a) * 0.05),
                (0.5 + math.cos(a + 0.9) * 0.09, 0.53 + math.sin(a + 0.9) * 0.09)], lighten(c.color, 0.6), 7, smooth=True)
    c.eyes(0.5, 0.49, gap=0.12, size=0.03, gaze=wave(t, 1) * 0.4)
    c.mouth(0.5, 0.575, "o", 0.02)
    for tilt, phase in ((-24, 0.0), (28, 0.5)):
        c.fx.ring(0.5, 0.53, 0.3, 0.075, ring, 6, rot=tilt, start=90, end=270)
        a = math.tau * (t + phase)
        ex, ey = math.sin(a) * 0.3, -math.cos(a) * 0.075
        cr, sr = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        if math.cos(a) < 0:  # spark rides the front arc
            c.ember(0.5 + ex * cr - ey * sr, 0.53 + ex * sr + ey * cr, 0.013, ring)
    c.lights = [Light(0.5, 0.53, 0.3, c.glow, 0.85 + 0.15 * wave(t, 3))]
    c.halo = 0.6


@design("Sonic", "Echo: a round pup with speaker-cone ears; every beat its ears thump and a ring of sound rolls off its call.")
def sonic(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    beat = (t * 4) % 1
    thump = max(0.0, 1 - beat * 4) * 0.025
    inner = lighten(c.color, 0.4)
    for side in (-1, 1):
        ex = 0.5 + side * 0.2
        b.ellipse(ex, 0.34, 0.12 + thump, 0.13 + thump, c.color, rot=side * 18)
        b.ellipse(ex, 0.34, 0.085 + thump, 0.095 + thump, darken(c.color, 0.35), rot=side * 18)
        b.ellipse(ex, 0.34, 0.04 + thump * 0.6, 0.045 + thump * 0.6, inner, rot=side * 18)
    b.blob([(0.32, 0.56), (0.38, 0.42), (0.5, 0.39), (0.62, 0.42), (0.68, 0.56), (0.63, 0.74), (0.5, 0.79),
            (0.37, 0.74)], c.color)
    b.ellipse(0.5, 0.66, 0.11, 0.08, inner)
    c.eyes(0.5, 0.54, gap=0.12, size=0.03, style="happy" if beat < 0.25 else "round")
    c.mouth(0.5, 0.635, "o" if beat < 0.3 else "smile", 0.022)
    # two rings in flight at a time, fading as they widen
    for k in range(2):
        r = ((t * 2 + k * 0.5) % 1)
        alpha = int(230 * (1 - r))
        if alpha > 20:
            for side in (-1, 1):
                c.fx.ring(0.5 + side * 0.2, 0.62, 0.05 + r * 0.12, 0.05 + r * 0.12, lighten(c.glow, 0.2), 5,
                          start=90 - side * 50 - 40 if side > 0 else -90 - 40, end=90 + 40 if side > 0 else -90 + 40,
                          alpha=alpha)
    c.lights = [Light(0.3, 0.34, 0.2, c.glow, 0.5 + thump * 12), Light(0.7, 0.34, 0.2, c.glow, 0.5 + thump * 12)]
    c.halo = 0.4
