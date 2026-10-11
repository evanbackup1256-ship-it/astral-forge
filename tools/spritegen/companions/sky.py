"""Sky and space: Cosmic, Nebula, Aurora, Lunar, Comet, Eclipse, Starlight, Celestial, Tempest."""

from __future__ import annotations

import math
import random

from .core import CREAM, INK, WHITE, Canvas, Light, darken, lighten, mix, wave
from .registry import design


@design("Cosmic", "Astro: a little blob in a space helmet whose visor holds a slowly turning galaxy; it floats and waves.")
def cosmic(c: Canvas) -> None:
    t = c.t
    b = c.body
    drift = wave(t, 1) * 0.015
    suit = (232, 234, 246)
    b.poly([(0.33, 0.56 + drift), (0.36, 0.48 + drift), (0.64, 0.48 + drift), (0.67, 0.56 + drift), (0.66, 0.74 + drift),
            (0.34, 0.74 + drift)], darken(suit, 0.15))  # backpack
    b.blob([(0.37, 0.58 + drift), (0.5, 0.54 + drift), (0.63, 0.58 + drift), (0.64, 0.78 + drift), (0.5, 0.81 + drift),
            (0.36, 0.78 + drift)], suit)
    b.ellipse(0.32, 0.64 + drift - max(0, wave(t, 2)) * 0.05, 0.035, 0.05, suit, rot=-40)
    b.ellipse(0.68, 0.68 + drift, 0.035, 0.05, suit, rot=30)
    b.circle(0.5, 0.68 + drift, 0.025, c.color)
    b.circle(0.5, 0.42 + drift, 0.17, suit)
    b.circle(0.5, 0.42 + drift, 0.135, (20, 18, 48))
    # galaxy in the visor: two arms turning a full turn per loop
    for arm in range(2):
        pts = []
        for k in range(14):
            s = k / 13
            a = t * math.tau + arm * math.pi + s * 3.2
            r = 0.012 + s * 0.1
            pts.append((0.5 + math.cos(a) * r, 0.42 + drift + math.sin(a) * r * 0.75))
        b.line(pts, mix(c.color, WHITE, 0.3), 7, smooth=True, alpha=200)
    b.circle(0.5, 0.42 + drift, 0.018, WHITE)
    c.eyes(0.5, 0.45 + drift, gap=0.09, size=0.022, style="glow", shine=WHITE)
    b.ellipse(0.43, 0.35 + drift, 0.04, 0.02, (255, 255, 255), rot=-30, alpha=170)
    c.lights = [Light(0.5, 0.42 + drift, 0.22, c.color, 0.6), Light(0.25, 0.2, 0.5, c.glow, 0.35)]
    c.halo = 0.4


@design("Nebula", "Drift: a gas-cloud jellyfish whose bell pulses as it swims; ribbon tendrils trail and ripple beneath.")
def nebula(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    pulse = wave(t, 2)
    bob = -pulse * 0.015
    for k in range(5):
        x0 = 0.38 + k * 0.06
        pts = [(x0 + wave(t, 2, s * 0.6 + k * 0.2) * 0.03 * s, 0.56 + bob + s * 0.28) for s in (0, 0.33, 0.66, 1)]
        c.behind.line(pts, mix(c.glow, c.color, k / 4), 9 - k % 2 * 3, smooth=True, alpha=230)
    w = 0.21 + pulse * 0.02
    b.blob([(0.5 - w, 0.56 + bob), (0.5 - w * 0.9, 0.42 + bob), (0.5, 0.3 + bob + pulse * 0.01), (0.5 + w * 0.9, 0.42 + bob),
            (0.5 + w, 0.56 + bob), (0.5 + w * 0.5, 0.6 + bob), (0.5, 0.57 + bob), (0.5 - w * 0.5, 0.6 + bob)], c.color)
    b.blob([(0.5 - w * 0.6, 0.5 + bob), (0.5, 0.36 + bob), (0.5 + w * 0.6, 0.5 + bob), (0.5, 0.53 + bob)], mix(c.color, c.glow, 0.45))
    for x, y in ((0.42, 0.4), (0.6, 0.44), (0.5, 0.36)):
        b.circle(x, y + bob, 0.007, WHITE)
    c.eyes(0.5, 0.47 + bob, gap=0.1, size=0.024)
    c.mouth(0.5, 0.52 + bob, "smile", 0.016)
    c.lights = [Light(0.5, 0.45 + bob, 0.3, c.glow, 0.6 + pulse * 0.2)]
    c.halo = 0.5


@design("Aurora", "Vixen: a sitting sky-fox with a long pointed muzzle and a brush tail made of three aurora bands rippling in sequence.")
def aurora(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    fur = (168, 190, 226)  # cool night-sky fur so the white muzzle and chest read
    shade = (128, 146, 190)
    bands = [(90, 240, 170), (110, 200, 255), (200, 150, 255)]
    # brush tail: wide at the base, sweeping up behind, each band rippling a beat later
    for k, color in enumerate(bands):
        pts = []
        for s in range(9):
            u = s / 8
            pts.append((0.58 + u * 0.24, 0.78 - u * 0.44 + wave(t, 2, -u + k * 0.15) * 0.03 + (k - 1) * 0.035 * (1 - u)))
        b.line(pts, color, 58 - k * 10, smooth=True)
    b.circle(0.82, 0.33 + wave(t, 2, -1) * 0.03, 0.042, WHITE)  # white tail tip
    # body sitting upright with a pale chest
    b.blob([(0.34, 0.82), (0.36, 0.62), (0.44, 0.54), (0.56, 0.54), (0.64, 0.62), (0.66, 0.82)], fur)
    b.blob([(0.44, 0.8), (0.45, 0.62), (0.5, 0.58), (0.55, 0.62), (0.56, 0.8)], WHITE)
    for x in (0.42, 0.58):
        b.ellipse(x, 0.82, 0.04, 0.02, shade)
    # tall ears with dark tips
    twitch = 0.012 if c.index % 12 == 3 else 0.0
    for side in (-1, 1):
        base_x = 0.5 + side * 0.08
        tip = (0.5 + side * 0.13, 0.17 - (twitch if side < 0 else 0))
        b.poly([(base_x - 0.05, 0.36), tip, (base_x + 0.05, 0.33)], fur)
        b.poly([(tip[0] - side * 0.012, tip[1] + 0.035), tip, (tip[0] + side * 0.02, tip[1] + 0.03)], (60, 64, 96))
        b.poly([(base_x - 0.025, 0.34), (tip[0], tip[1] + 0.06), (base_x + 0.025, 0.33)], (255, 180, 205))
    # head: wide cheek ruff narrowing to a long muzzle
    b.blob([(0.33, 0.43), (0.38, 0.33), (0.5, 0.3), (0.62, 0.33), (0.67, 0.43), (0.62, 0.48), (0.55, 0.53),
            (0.5, 0.6), (0.45, 0.53), (0.38, 0.48)], fur)
    for side in (-1, 1):  # ruff points
        b.poly([(0.5 + side * 0.15, 0.42), (0.5 + side * 0.2, 0.47), (0.5 + side * 0.12, 0.49)], fur)
    b.blob([(0.43, 0.47), (0.5, 0.45), (0.57, 0.47), (0.5, 0.575)], WHITE)
    c.decal.ellipse(0.5, 0.56, 0.018, 0.013, INK)  # nose at the muzzle tip
    if c.blink:
        c.eyes(0.5, 0.42, gap=0.12, size=0.022, style="closed")
    else:
        for side in (-1, 1):  # almond eyes
            ex = 0.5 + side * 0.06
            c.decal.ellipse(ex, 0.42, 0.024, 0.016, INK, rot=side * -18)
            c.decal.circle(ex - 0.006, 0.415, 0.006, WHITE)
    c.lights = [Light(0.78, 0.48, 0.42, bands[(c.index // 6) % 3], 0.8)]
    c.halo = 0.45
    c.halo_color = bands[(c.index // 6) % 3]

@design("Lunar", "Nod: a crescent moon in a nightcap rocking like a cradle; little stars twinkle on and off around it.")
def lunar(c: Canvas) -> None:
    t = c.t
    b = c.body
    rock = wave(t, 1) * 0.03
    moon = lighten(c.color, 0.2)
    # crescent opening to the right: outer arc round the left, inner arc back round the left
    outer = []
    inner = []
    for k in range(28):
        a = math.radians(300 - k * 240 / 27)
        outer.append((0.5 + rock + math.cos(a) * 0.22, 0.54 + math.sin(a) * 0.22))
    for k in range(28):
        a = math.radians(55 + k * 250 / 27)
        inner.append((0.6 + rock + math.cos(a) * 0.17, 0.5 + math.sin(a) * 0.17))
    b.poly(outer + inner, moon)
    # nightcap on the upper horn
    b.poly([(0.33 + rock, 0.38), (0.45 + rock, 0.32), (0.34 + rock, 0.2), (0.24 + rock, 0.18)], (100, 110, 220))
    b.circle(0.23 + rock, 0.18, 0.028, WHITE)
    b.ellipse(0.4 + rock, 0.6, 0.018, 0.012, darken(moon, 0.15))
    c.eyes(0.36 + rock, 0.52, gap=0.06, size=0.022, style="sleepy")
    c.mouth(0.37 + rock, 0.6, "smile", 0.014)
    for k, (x, y) in enumerate(((0.75, 0.3), (0.82, 0.55), (0.68, 0.76))):
        on = (c.index // 6 + k) % 3 != 0
        if on:
            c.fx.star(x, y, 0.02, 0.4, 4, WHITE, rot=k * 20)
    c.lights = [Light(0.18, 0.5, 0.5, c.glow, 0.5), Light(0.75, 0.5, 0.3, WHITE, 0.25)]
    c.halo = 0.45


@design("Comet", "Dash: a determined icy head racing forward; its tail streams back in long ribbons and sheds sparks.")
def comet(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    jit = wave(t, 4) * 0.005
    for k in range(4):
        spread = (k - 1.5) * 0.04
        pts = [(0.44, 0.58 + spread * 0.3)]
        for s in (0.3, 0.6, 1.0):
            pts.append((0.44 + s * 0.4, 0.58 - s * 0.33 + spread * (1 + s) + wave(t, 2, s + k * 0.2) * 0.012))
        c.behind.line(pts, mix(c.glow, c.color, k / 3), 22 - k * 3, smooth=True, alpha=int(230 - k * 30))
    b.circle(0.42 + jit, 0.6, 0.15, c.color)
    b.circle(0.4 + jit, 0.6, 0.11, lighten(c.color, 0.5))
    c.eyes(0.39 + jit, 0.6, gap=0.09, size=0.026, style="fierce", gaze=-0.5)
    c.mouth(0.39 + jit, 0.66, "grin", 0.018)
    for k in range(3):
        u = (t * 2 + k / 3) % 1
        c.ember(0.62 + u * 0.24, 0.5 - u * 0.2 + (k - 1) * 0.04, 0.009 * (1 - u), WHITE)
    c.lights = [Light(0.3, 0.55, 0.4, WHITE, 0.55), Light(0.6, 0.45, 0.3, c.glow, 0.5)]
    c.halo = 0.5


@design("Eclipse", "Corona: a dark moon-disc with glowing eyes; the corona's flares turn behind it and a bright bead circles its rim.")
def eclipse(c: Canvas) -> None:
    t = c.t
    b = c.body
    corona = (255, 226, 160)
    for k in range(10):
        a = math.radians(t * 36 + k * 36)
        length = 0.29 + (0.03 if k % 2 else 0.0) + wave(t, 2, k / 10) * 0.012
        c.behind.poly([(0.5 + math.sin(a - 0.12) * 0.19, 0.52 - math.cos(a - 0.12) * 0.19),
                       (0.5 + math.sin(a) * length, 0.52 - math.cos(a) * length),
                       (0.5 + math.sin(a + 0.12) * 0.19, 0.52 - math.cos(a + 0.12) * 0.19)], corona, alpha=210)
    b.circle(0.5, 0.52, 0.19, (30, 26, 44))
    b.circle(0.47, 0.49, 0.03, (44, 40, 62))
    b.circle(0.58, 0.6, 0.02, (44, 40, 62))
    c.eyes(0.5, 0.52, gap=0.1, size=0.026, style="glow", shine=corona)
    a = t * math.tau
    bead = (0.5 + math.sin(a) * 0.19, 0.52 - math.cos(a) * 0.19)
    c.lights = [Light(bead[0], bead[1], 0.3, WHITE, 1.0, visible=True, orb=0.018),
                Light(0.5, 0.52 - 0.3, 0.3, corona, 0.5), Light(0.5, 0.52 + 0.3, 0.3, corona, 0.5)]
    c.halo = 0.7
    c.halo_color = corona
    c.shade = 0.5


@design("Starlight", "Twinkle: a chubby five-point star that twirls on the spot; a twinkle hops from point to point.")
def starlight(c: Canvas) -> None:
    t = c.t
    b = c.body
    twirl = wave(t, 1) * 14
    bob = wave(t, 2) * 0.012
    b.star(0.5, 0.54 + bob, 0.27, 0.52, 5, c.color, rot=twirl)
    b.star(0.5, 0.54 + bob, 0.19, 0.55, 5, lighten(c.color, 0.35), rot=twirl)
    c.eyes(0.5, 0.53 + bob, gap=0.1, size=0.026)
    c.mouth(0.5, 0.6 + bob, "smile", 0.02)
    c.cheeks(0.5, 0.58 + bob, 0.18, (255, 150, 140))
    point = c.index // 7 % 5
    a = math.radians(twirl + point * 72) - math.pi / 2
    tip = (0.5 + math.cos(a) * 0.29, 0.54 + bob + math.sin(a) * 0.29)
    c.fx.star(tip[0], tip[1], 0.03, 0.2, 4, WHITE, rot=45 * (c.index % 7) / 7)
    c.lights = [Light(tip[0], tip[1], 0.35, WHITE, 0.6), Light(0.5, 0.54, 0.3, c.glow, 0.4)]
    c.halo = 0.5


@design("Celestial", "Astrolabe: an armillary sphere with a face at its core; its three rings turn on different axes.")
def celestial(c: Canvas) -> None:
    t = c.t
    b = c.body
    brass = (230, 196, 120)
    b.poly([(0.44, 0.78), (0.56, 0.78), (0.6, 0.84), (0.4, 0.84)], darken(brass, 0.2))
    b.line([(0.5, 0.7), (0.5, 0.78)], darken(brass, 0.2), 10)
    rings = [(0, 1, 0.0), (90, 1, 0.33), (35, 2, 0.66)]
    for tilt, speed, off in rings:
        squash = abs(math.cos((t * speed + off) * math.pi))
        c.behind.ring(0.5, 0.48, 0.24, max(0.02, 0.24 * squash), darken(brass, 0.1), 9, rot=tilt, start=-90, end=90)
    b.circle(0.5, 0.48, 0.13, c.color)
    b.circle(0.47, 0.45, 0.09, lighten(c.color, 0.25))
    c.eyes(0.5, 0.47, gap=0.09, size=0.022)
    c.mouth(0.5, 0.53, "smile", 0.016)
    for tilt, speed, off in rings:
        squash = abs(math.cos((t * speed + off) * math.pi))
        c.fx.ring(0.5, 0.48, 0.24, max(0.02, 0.24 * squash), brass, 9, rot=tilt, start=90, end=270)
    c.lights = [Light(0.5, 0.48, 0.28, c.glow, 0.55), Light(0.3, 0.25, 0.4, WHITE, 0.3)]
    c.halo = 0.4


@design("Tempest", "Grumble: a scowling thundercloud; rain streaks fall beneath it and every so often it flashes from within.")
def tempest(c: Canvas) -> None:
    t = c.t
    c.drift = 0.008
    b = c.body
    rnd = random.Random(c.index * 31 + 7)
    flash = c.index % 12 in (6, 7)
    cloud = darken(c.color, 0.25)
    shake = (rnd.random() - 0.5) * 0.01 if flash else 0.0
    for x, y, r in ((0.36, 0.5, 0.11), (0.5, 0.42, 0.14), (0.64, 0.5, 0.11), (0.5, 0.56, 0.13), (0.3, 0.58, 0.08),
                    (0.7, 0.58, 0.08)):
        b.circle(x + shake, y, r, cloud)
    b.ellipse(0.46 + shake, 0.4, 0.07, 0.04, lighten(cloud, 0.25), rot=-15)
    c.eyes(0.5 + shake, 0.53, gap=0.12, size=0.026, style="fierce")
    c.mouth(0.5 + shake, 0.6, "frown", 0.02)
    for k in range(7):
        fall = (t * 3 + k / 7) % 1
        x = 0.32 + k * 0.06
        y = 0.68 + fall * 0.16
        c.fx.line([(x, y), (x - 0.01, y + 0.03)], (170, 210, 255), 3.5, alpha=int(220 * (1 - fall)))
    if flash:
        c.fx.line([(0.55, 0.64), (0.5, 0.72), (0.56, 0.72), (0.5, 0.82)], (255, 250, 200), 7)
    c.lights = [Light(0.5, 0.5, 0.35, (230, 240, 255), 1.0 if flash else 0.2), Light(0.5, 0.25, 0.35, c.glow, 0.25)]
    c.halo = 0.25 + (0.5 if flash else 0.0)
