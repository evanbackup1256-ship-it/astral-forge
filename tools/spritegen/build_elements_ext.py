"""The second wave of elemental spritesheets (33 more), same format as build_elements.py:
6 x 6 frames of 170 px, straight-alpha RGBA, every time-varying term periodic over the 36 frames.

    python tools/spritegen/build_elements_ext.py              # all of this wave
    python tools/spritegen/build_elements_ext.py crystal rift # some
"""

from __future__ import annotations

import math
import sys

import numpy as np

import build_elements as base
from build_elements import (
    FRAMES,
    TAU,
    Canvas,
    PeriodicNoise,
    blend,
    edge,
    gear,
    glow,
    over,
    polar,
    ramp,
    sparkle,
    stack,
    to_image,
    vignette,
)


def lit(field, stops):
    return to_image(ramp(field, stops))


def ring(r, radius, width):
    return np.exp(-((r - radius) ** 2) / width)


def hue_rgb(h):
    """Vectorised hue -> rgb (full saturation)."""
    h = np.mod(h, 1.0)
    r = np.clip(np.abs(h * 6 - 3) - 1, 0, 1)
    g = np.clip(2 - np.abs(h * 6 - 2), 0, 1)
    b = np.clip(2 - np.abs(h * 6 - 4), 0, 1)
    return np.stack([r, g, b], axis=-1)


def stars(seed, count, x, y, t, color=(1.0, 1.0, 1.0), rate=1):
    """A twinkling star field (float RGBA), twinkle periodic over the loop."""
    rng = np.random.default_rng(seed)
    light = np.zeros_like(x)
    for _ in range(count):
        sx, sy = rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9)
        phase, size = rng.random(), rng.uniform(0.00004, 0.00016)
        tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(TAU * (t * rate + phase)))
        light = np.maximum(light, np.exp(-((x - sx) ** 2 + (y - sy) ** 2) / size) * tw)
    out = np.zeros(x.shape + (4,), np.float32)
    out[..., :3] = color
    out[..., 3] = light
    return out


def rot(px, py, a):
    c, s = math.cos(a), math.sin(a)
    return px * c - py * s, px * s + py * c


# ------------------------------------------------------------------------------------------------
# minerals and metals
# ------------------------------------------------------------------------------------------------

def crystal():
    """A geode cluster: faceted amethyst shards fanning from a glowing heart, a glint sweeping across."""
    x, y, r, _ = polar()
    rng = np.random.default_rng(301)
    shards = sorted(
        [(rng.uniform(-1.05, 1.05), rng.uniform(0.36, 0.72), rng.uniform(0.06, 0.11)) for _ in range(9)],
        key=lambda s: -s[1],
    )
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        pulse = 0.5 + 0.5 * math.sin(TAU * t)
        heart = lit(np.exp(-(x ** 2 + (y + 0.32) ** 2) / (0.05 + 0.025 * pulse)), [(0, (0.55, 0.3, 1, 0)), (1, (0.95, 0.82, 1, 0.9))])
        c = Canvas()
        sweep = -1.5 + 3.0 * t
        for a, length, w in shards:
            bx, by = math.sin(a) * 0.08, -0.4
            dx, dy = math.sin(a), math.cos(a)
            px, py = -dy, dx
            tipx, tipy = bx + dx * length, by + dy * length
            sx, sy = bx + dx * length * 0.76, by + dy * length * 0.76
            g = math.exp(-(((bx + tipx) / 2 - sweep) / 0.2) ** 2)
            light = tuple(int(c0 + (255 - c0) * g) for c0 in (186, 136, 255))
            dark = tuple(int(c0 + (225 - c0) * g * 0.7) for c0 in (92, 54, 168))
            c.polygon([(bx + px * w * 0.7, by + py * w * 0.7), (sx + px * w, sy + py * w), (tipx, tipy), (sx, sy), (bx, by)], light + (245,))
            c.polygon([(bx - px * w * 0.7, by - py * w * 0.7), (sx - px * w, sy - py * w), (tipx, tipy), (sx, sy), (bx, by)], dark + (245,))
            c.line([(bx, by), (sx, sy), (tipx, tipy)], fill=(244, 226, 255, int(110 + 140 * g)), width=1.0)
            twinkle = 0.5 + 0.5 * math.sin(TAU * (t * 2 + a))
            if twinkle > 0.72:
                sparkle(c, tipx, tipy, 0.03 + 0.18 * (twinkle - 0.72), (255, 246, 255, 235))
        c.ellipse(0, -0.48, 0.56, 0.14, fill=(40, 28, 58, 255))
        c.ellipse(0, -0.44, 0.44, 0.08, fill=(126, 78, 196, int(170 + 60 * pulse)))
        frames.append(glow(over(heart, c.done()), 3, 0.55))
    return frames


def steel():
    """A spinning steel sawblade with brushed highlights, throwing a fan of orange grinder sparks."""
    x, y, r, theta = polar()
    rng = np.random.default_rng(311)
    sparks = [(rng.random(), rng.uniform(-0.35, 0.35), rng.uniform(0.9, 1.5)) for _ in range(28)]
    R, teeth = 0.42, 18
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        spin = TAU * t * 2 / teeth
        brushed = 0.45 + 0.35 * np.cos(2 * (theta - math.pi * t)) + 0.12 * np.cos(6 * (theta + math.pi * t / 3))
        disk = ramp(brushed, [(0, (0.24, 0.28, 0.35, 1)), (0.6, (0.62, 0.68, 0.76, 1)), (1, (0.96, 0.98, 1, 1))])
        disk[..., 3] = edge(r - R) * (1 - edge(r - 0.06))
        blend(disk, (0.14, 0.16, 0.21), ring(r, 0.25, 0.0003) * 0.85)
        blend(disk, (0.85, 0.9, 1.0), ring(r, 0.4, 0.00015) * 0.6)
        c = Canvas()
        for i in range(teeth):
            a = spin + TAU * i / teeth
            b = a + TAU / teeth
            tip = a + 0.24
            pts = [(math.cos(a) * R * 0.97, math.sin(a) * R * 0.97), (math.cos(tip) * R * 1.24, math.sin(tip) * R * 1.24), (math.cos(b) * R * 0.97, math.sin(b) * R * 0.97)]
            c.polygon(pts, (176, 186, 202, 255))
            c.line(pts[:2], fill=(250, 252, 255, 255), width=1.0)
        for i in range(9):
            a = spin + TAU * i / 9
            c.circle(math.cos(a) * 0.17, math.sin(a) * 0.17, 0.022, fill=(60, 66, 80, 255), outline=(210, 216, 228, 255), width=1.0)
        c.circle(0, 0, 0.09, fill=(66, 74, 88, 255), outline=(222, 228, 238, 255), width=1.6)
        sp = Canvas()
        ex, ey = math.cos(-0.55) * R * 1.2, math.sin(-0.55) * R * 1.2
        for phase, spread, speed in sparks:
            p = (t * 2 + phase) % 1.0
            dx, dy = rot(0.52, 0.85, spread)
            px = ex + dx * speed * p * 0.75
            py = ey + dy * speed * p * 0.75 - 1.5 * p * p
            vx, vy = dx * speed, dy * speed - 3.0 * p
            fade = (1 - p) ** 1.4
            sp.line([(px, py), (px - vx * 0.05, py - vy * 0.05)], fill=(255, int(220 - 110 * p), int(120 - 90 * p), int(255 * fade)), width=1.6)
        frames.append(stack(to_image(disk), c.done(), glow(sp.done(), 2.5, 0.9)))
    return frames


def gold():
    """A fountain of spinning gold coins arcing up and raining onto a glinting hoard."""
    rng = np.random.default_rng(321)
    coins = [(rng.random(), rng.uniform(-0.55, 0.55), rng.uniform(1.6, 2.0), int(rng.integers(1, 4))) for _ in range(12)]
    pile = [(rng.uniform(-0.5, 0.5), rng.uniform(-0.62, -0.46)) for _ in range(26)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        c = Canvas()
        c.ellipse(0, -0.6, 0.62, 0.16, fill=(120, 74, 18, 255))
        for k, (px, py) in enumerate(sorted(pile, key=lambda q: -q[1])):
            c.ellipse(px, py, 0.08, 0.035, fill=(214, 160, 46, 255), outline=(255, 222, 120, 255), width=1.0)
            if 0.5 + 0.5 * math.sin(TAU * (t * 2 + k * 0.37)) > 0.93:
                sparkle(c, px + 0.02, py + 0.02, 0.05, (255, 252, 220, 255))
        for phase, vx, vy, spins in coins:
            p = (t + phase) % 1.0
            cx = vx * p * 0.7
            cy = -0.5 + vy * p - 2.0 * p * p
            if cy < -0.62:
                continue
            face = math.cos(TAU * (t * spins + phase))
            width = 0.075 * max(abs(face), 0.12)
            fade = int(255 * min(1.0, (1 - p) * 4, p * 8))
            rim = (190, 128, 28, fade)
            body = (255, 206, 70, fade) if face > 0 else (232, 172, 52, fade)
            c.ellipse(cx, cy, width, 0.075, fill=body, outline=rim, width=1.2)
            if abs(face) > 0.4:
                c.ellipse(cx, cy, width * 0.55, 0.042, outline=(255, 236, 150, fade), width=1.0)
        frames.append(glow(c.done(), 3, 0.55))
    return frames


def amber():
    """A drop of glowing amber, wobbling, with shafts of honey light and tiny bubbles caught inside."""
    x, y, r, theta = polar()
    rng = np.random.default_rng(331)
    bubbles = [(rng.uniform(-0.25, 0.25), rng.uniform(-0.3, 0.2), rng.uniform(0.012, 0.03), rng.random()) for _ in range(9)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        wob = 0.03 * np.sin(3 * theta + TAU * t) + 0.02 * np.sin(2 * theta - TAU * 2 * t)
        # a teardrop: rounder below, pinched to a point above
        shape = np.hypot(x * (1 + 0.55 * np.clip(y, 0, 1)), (y + 0.08) * 0.92) - (0.46 + wob)
        inside = edge(shape)
        depth = np.clip(-shape / 0.46, 0, 1)
        body = ramp(depth, [(0, (0.7, 0.32, 0.02, 1)), (0.4, (0.94, 0.56, 0.08, 1)), (1, (1.0, 0.86, 0.38, 1))])
        shafts = np.clip(np.cos(5 * (theta + math.pi * 0.4 * t)), 0, 1) ** 8 * depth * 0.6
        body[..., :3] = np.clip(body[..., :3] + shafts[..., None] * np.array([0.3, 0.25, 0.1]), 0, 1)
        body[..., 3] = inside * 0.95
        blend(body, (1, 0.94, 0.7), np.exp(-((shape + 0.012) ** 2) / 0.00018) * 0.9)
        c = Canvas()
        for bx, by, size, phase in bubbles:
            dy = 0.03 * math.sin(TAU * (t + phase))
            c.circle(bx, by + dy, size, outline=(255, 240, 190, 200), width=1.0)
            c.circle(bx - size * 0.35, by + dy + size * 0.35, size * 0.3, fill=(255, 252, 230, 220))
        c.arc(-0.06, 0.02, 0.32, 200, 250, (255, 252, 230, 210), 2.4)
        halo = lit(ring(r, 0.5, 0.01) * 0.45, [(0, (1, 0.7, 0.2, 0)), (1, (1, 0.75, 0.3, 0.6))])
        frames.append(glow(stack(halo, to_image(body), c.done()), 3, 0.5))
    return frames


def magnet():
    """A horseshoe magnet with field lines arcing pole to pole and iron filings streaming along them."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        field, filings, body = Canvas(), Canvas(), Canvas()
        surge = 0.5 + 0.5 * math.sin(TAU * t)
        for j in range(5):
            pts = []
            for i in range(41):
                s = math.pi * i / 40
                pts.append((math.cos(s) * (0.25 + 0.16 * j * math.sin(s)), 0.04 + math.sin(s) * (0.14 + 0.15 * j)))
            field.line(pts, fill=(120, 190, 255, int(70 + 50 * surge - j * 8)), width=1.0)
            for k in range(10):
                s = math.pi * ((k / 10 + t * (1 if j % 2 == 0 else 2)) % 1.0)
                px, py = math.cos(s) * (0.25 + 0.16 * j * math.sin(s)), 0.04 + math.sin(s) * (0.14 + 0.15 * j)
                tx, ty = -math.sin(s) * (0.25 + 0.16 * j), math.cos(s) * (0.14 + 0.15 * j)
                n = math.hypot(tx, ty) or 1
                filings.line([(px - tx / n * 0.02, py - ty / n * 0.02), (px + tx / n * 0.02, py + ty / n * 0.02)], fill=(210, 236, 255, 235), width=1.6)
        body.arc(0, -0.26, 0.25, 0, 180, (204, 40, 52, 255), 16)
        body.polygon([(-0.32, -0.26), (-0.18, -0.26), (-0.18, -0.06), (-0.32, -0.06)], (204, 40, 52, 255))
        body.polygon([(0.18, -0.26), (0.32, -0.26), (0.32, -0.06), (0.18, -0.06)], (204, 40, 52, 255))
        body.polygon([(-0.32, -0.06), (-0.18, -0.06), (-0.18, 0.05), (-0.32, 0.05)], (214, 222, 234, 255))
        body.polygon([(0.18, -0.06), (0.32, -0.06), (0.32, 0.05), (0.18, 0.05)], (214, 222, 234, 255))
        body.arc(0, -0.26, 0.29, 20, 80, (255, 140, 140, 200), 2.0)
        for sx in (-0.25, 0.25):
            sparkle(body, sx, 0.06, 0.04 + 0.05 * surge, (200, 236, 255, 230))
        frames.append(stack(glow(field.done(), 2, 0.6), glow(filings.done(), 1.5, 0.5), body.done()))
    return frames


# ------------------------------------------------------------------------------------------------
# sky and space
# ------------------------------------------------------------------------------------------------

def gravity():
    """Levitating stones orbiting a lensing well, distortion ripples sliding inward."""
    x, y, r, theta = polar()
    rng = np.random.default_rng(341)
    rocks = []
    for k in range(7):
        verts = [rng.uniform(0.7, 1.0) for _ in range(7)]
        rocks.append((k / 7, rng.uniform(0.04, 0.075), verts, int(rng.integers(1, 3)), rng.uniform(0.45, 0.72)))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        ripples = np.zeros_like(r)
        for k in range(4):
            p = (t + k / 4) % 1.0
            ripples = np.maximum(ripples, ring(r, 0.85 * (1 - p) ** 1.3 + 0.2, 0.0012) * math.sin(math.pi * p))
        lens = ring(r, 0.2, 0.0009) + 0.5 * ring(r, 0.24, 0.004)
        well = lit(np.clip(ripples * 0.6 + lens, 0, 1), [(0, (0.5, 0.3, 1, 0)), (0.5, (0.62, 0.45, 1, 0.6)), (1, (0.95, 0.9, 1, 1))])
        core = np.zeros(r.shape + (4,), np.float32)
        core[..., 3] = edge(r - 0.18) * 0.96
        back, front = Canvas(), Canvas()
        for phase, size, verts, rate, radius in rocks:
            a = TAU * (t * rate + phase)
            cx, cy = math.cos(a) * radius, math.sin(a) * radius * 0.32 + 0.04 * math.sin(TAU * (t + phase))
            canvas = back if math.sin(a) > 0 else front
            shade = 0.65 if math.sin(a) > 0 else 1.0
            spin = TAU * t * rate
            pts = [(cx + math.cos(spin + TAU * i / 7) * size * v, cy + math.sin(spin + TAU * i / 7) * size * v) for i, v in enumerate(verts)]
            canvas.polygon(pts, (int(104 * shade), int(92 * shade), int(128 * shade), 255))
            canvas.line(pts[:4], fill=(int(200 * shade), int(180 * shade), 255, 255), width=1.0)
        frames.append(glow(stack(back.done(), well, to_image(core), front.done()), 3, 0.5))
    return frames


def nebula():
    """A swirling nebula of rose and teal gas, a young star breathing at its heart."""
    x, y, r, theta = polar()
    gas = PeriodicNoise(351, (8, 8, 8))
    dust = PeriodicNoise(352, (8, 8, 8))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        swirl = theta / TAU * 8 + r * 5
        a = gas.fbm(swirl, r * 4, t * 8, octaves=4)
        b = dust.fbm(swirl + 3, r * 4 + 2, t * 8 + 4, octaves=4)
        falloff = np.clip(1 - r / 0.92, 0, 1) ** 0.8
        image = np.zeros(r.shape + (4,), np.float32)
        blend(image, (0.95, 0.38, 0.7), np.clip((a - 0.42) * 3.2, 0, 1) * falloff)
        blend(image, (0.25, 0.85, 0.92), np.clip((b - 0.48) * 3.0, 0, 1) * falloff * 0.85)
        blend(image, (0.08, 0.04, 0.16), np.clip((0.4 - b) * 4, 0, 1) * falloff * 0.5)
        pulse = 0.5 + 0.5 * math.sin(TAU * t)
        blend(image, (1, 0.96, 0.9), np.exp(-(r ** 2) / (0.006 + 0.004 * pulse)))
        blend(image, (1, 0.8, 0.95), np.exp(-(r ** 2) / 0.04) * 0.35)
        sky = stars(353, 22, x, y, t, rate=2)
        frames.append(vignette(glow(over(to_image(sky), to_image(image)), 3, 0.4), 0.7, 0.96))
    return frames


def aurora():
    """Curtains of aurora rippling over a dark ridge, rays shimmering green into violet."""
    x, y, r, _ = polar()
    rays = PeriodicNoise(361, (16, 8, 8))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        image = stars(362, 18, x, y, t)
        for layer, (amp, shift, tint) in enumerate(((0.16, 0.0, 1.0), (0.1, 0.37, 0.7))):
            curve = -0.05 + layer * 0.18 + amp * np.sin(TAU * (x * 0.7 + t + shift)) + 0.05 * np.sin(TAU * (x * 1.9 - 2 * t + shift))
            above = y - curve
            streak = 0.55 + 0.45 * rays.sample(x * 8 + layer * 4, layer * 2.0, t * 8)
            intensity = np.where(above > 0, np.exp(-above * 3.2), np.exp(-((above / 0.02) ** 2))) * streak * tint
            color = ramp(np.clip(above * 1.6, 0, 1), [(0, (0.4, 1.0, 0.6, 1)), (0.5, (0.3, 0.9, 0.8, 1)), (1, (0.75, 0.4, 1.0, 1))])
            blend(image, color[..., :3], np.clip(intensity, 0, 1) * 0.9)
        ridge = -0.5 + 0.08 * np.sin(x * 5.3) + 0.05 * np.sin(x * 11 + 1)
        blend(image, (0.04, 0.05, 0.1), edge(y - ridge, 0.02))
        frames.append(vignette(glow(to_image(image), 2.5, 0.45), 0.72, 0.96))
    return frames


def lunar():
    """A cratered moon running through its phases, earthshine on the dark limb, a pale halo."""
    x, y, r, _ = polar()
    craters = PeriodicNoise(371, (16, 16, 4))
    R = 0.5
    inside = r < R
    z = np.sqrt(np.clip(R * R - x * x - y * y, 0, None)) / R
    nx, ny = x / R, y / R
    surface = craters.fbm(x * 3 + 8, y * 3 + 8, 0, octaves=4)
    maria = np.clip((surface - 0.5) * 4, 0, 1)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        phase = TAU * t
        lx, lz = math.sin(phase), -math.cos(phase)
        light = np.clip(nx * lx + z * lz, 0, 1)
        lightish = np.clip(light * 4, 0, 1)
        tone = 0.78 - maria * 0.28 + (surface - 0.5) * 0.3
        moon = np.zeros(r.shape + (4,), np.float32)
        lit_rgb = np.stack([tone * 1.0, tone * 0.98, tone * 0.92], axis=-1)
        shine = np.stack([tone * 0.16, tone * 0.2, tone * 0.32], axis=-1)
        moon[..., :3] = lit_rgb * lightish[..., None] + shine * (1 - lightish[..., None])
        moon[..., 3] = edge(r - R)
        halo = lit(ring(r, R + 0.06, 0.006) * (0.4 + 0.4 * lightish.max()), [(0, (0.7, 0.8, 1, 0)), (1, (0.8, 0.88, 1, 0.55))])
        sky = stars(372, 14, x, y, t)
        sky[..., 3] *= ~inside
        frames.append(glow(stack(to_image(sky), halo, to_image(moon)), 3, 0.4))
    return frames


def comet():
    """A comet swinging round a small star, its blue ion tail streaming straight away, dust tail curling."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        star, tail, head = Canvas(), Canvas(), Canvas()
        star.circle(0, 0, 0.08, fill=(255, 220, 140, 255))
        star.circle(0, 0, 0.14, fill=(255, 200, 110, 70))

        def at(a):
            return math.cos(a) * 0.62, math.sin(a) * 0.36 - 0.05

        a = TAU * t
        hx, hy = at(a)
        dist = math.hypot(hx, hy) or 1
        ax, ay = hx / dist, hy / dist
        length = 0.55 + 0.25 * (0.62 - dist)
        for k in range(16):
            s = k / 16
            tail.circle(hx + ax * length * s, hy + ay * length * s, 0.05 * (1 - s) + 0.01, fill=(120, 200, 255, int(160 * (1 - s) ** 1.5)))
        for k in range(1, 20):
            px, py = at(a - k * 0.06)
            tail.circle(px + ax * k * 0.008, py + ay * k * 0.008, 0.035 * (1 - k / 20) + 0.006, fill=(255, 230, 190, int(150 * (1 - k / 20))))
        head.circle(hx, hy, 0.04, fill=(255, 255, 255, 255))
        head.circle(hx, hy, 0.075, fill=(200, 236, 255, 110))
        frames.append(glow(stack(glow(star.done(), 4, 0.8), glow(tail.done(), 3, 0.7), head.done()), 2, 0.5))
    return frames


def eclipse():
    """Totality: a black disk ringed by a streaming white corona, pink prominences and a diamond ring."""
    x, y, r, theta = polar()
    streams = PeriodicNoise(381, (8, 4, 8))
    R = 0.34
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        n = streams.fbm(theta / TAU * 8, 0, t * 8, octaves=3)
        reach = 0.05 + 0.22 * n ** 2
        corona = np.where(r > R, np.exp(-(r - R) / reach), 0)
        image = ramp(np.clip(corona, 0, 1), [(0, (0.8, 0.85, 1, 0)), (0.4, (0.9, 0.92, 1, 0.55)), (1, (1, 1, 1, 1))])
        prom = np.clip(np.cos(3 * theta + 1.1) * 0.5 + 0.5, 0, 1) ** 12 * ring(r, R + 0.02, 0.0004 + 0.0006 * n)
        blend(image, (1, 0.35, 0.55), prom)
        blend(image, (0.02, 0.02, 0.04), edge(r - R))
        c = Canvas()
        glint = 0.5 + 0.5 * math.sin(TAU * t)
        gx, gy = math.cos(2.3) * R, math.sin(2.3) * R
        sparkle(c, gx, gy, 0.1 + 0.12 * glint, (255, 255, 255, 255))
        c.circle(gx, gy, 0.035 + 0.015 * glint, fill=(255, 255, 255, 255))
        frames.append(glow(over(to_image(image), c.done()), 3, 0.5))
    return frames


def starlight():
    """A constellation drawing itself star by star, then breathing out and starting over."""
    x, y, r, _ = polar()
    points = [(-0.58, -0.28), (-0.32, -0.02), (-0.08, 0.06), (0.16, 0.36), (0.46, 0.44), (0.12, -0.18), (0.4, -0.42), (0.6, -0.12)]
    path = [0, 1, 2, 3, 4, 3, 2, 5, 6, 7]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        progress = min(1.0, t / 0.7) * (len(path) - 1)
        fade = 1.0 if t < 0.82 else max(0.0, 1 - (t - 0.82) / 0.18)
        sky = stars(391, 26, x, y, t, color=(0.8, 0.88, 1.0), rate=2)
        dust = lit(np.exp(-((x * 0.8 + y * 0.6) ** 2) / 0.05) * 0.4, [(0, (0.3, 0.4, 1, 0)), (1, (0.45, 0.55, 1, 0.5))])
        lines, nodes = Canvas(), Canvas()
        for i in range(len(path) - 1):
            seg = progress - i
            if seg <= 0:
                break
            a, b = points[path[i]], points[path[i + 1]]
            s = min(1.0, seg)
            lines.line([a, (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s)], fill=(170, 210, 255, int(220 * fade)), width=1.4)
        for k, (px, py) in enumerate(points):
            reached = k in path[: int(progress) + 1]
            tw = 0.5 + 0.5 * math.sin(TAU * (t * 2 + k * 0.3))
            size = (0.05 + 0.03 * tw) if reached else 0.025
            alpha = int((255 if reached else 120) * (fade if reached else 1))
            sparkle(nodes, px, py, size, (235, 244, 255, alpha))
        frames.append(glow(stack(to_image(sky), dust, glow(lines.done(), 2, 0.7), nodes.done()), 2, 0.5))
    return frames


def celestial():
    """An armillary sphere: three gilded rings at fixed tilts, planets riding them round a small sun."""
    rings_def = [(0.15, 0.0, 1, 0.6), (1.05, 0.5, 2, 0.52), (-0.95, 1.2, 1, 0.44)]
    frames = []

    def project(px, py, pz, tilt, yaw):
        y1, z1 = py * math.cos(tilt) - pz * math.sin(tilt), py * math.sin(tilt) + pz * math.cos(tilt)
        x2, z2 = px * math.cos(yaw) + z1 * math.sin(yaw), -px * math.sin(yaw) + z1 * math.cos(yaw)
        return x2, y1, z2

    for f in range(FRAMES):
        t = f / FRAMES
        back, front, sun = Canvas(), Canvas(), Canvas()
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 2)
        sun.circle(0, 0, 0.09 + 0.01 * pulse, fill=(255, 220, 130, 255))
        sun.circle(0, 0, 0.16, fill=(255, 200, 100, 60))
        for idx, (tilt, yaw, rate, R) in enumerate(rings_def):
            pts = []
            for i in range(73):
                s = TAU * i / 72
                pts.append(project(math.cos(s) * R, math.sin(s) * R, 0, tilt, yaw))
            for i in range(72):
                (ax, ay, az), (bx, by, bz) = pts[i], pts[i + 1]
                canvas = front if az + bz < 0 else back
                alpha = 245 if az + bz < 0 else 120
                canvas.line([(ax, ay), (bx, by)], fill=(232, 192, 110, alpha), width=2.0)
            for k in range(12):
                s = TAU * (k / 12 + t / 12)
                px, py, pz = project(math.cos(s) * R, math.sin(s) * R, 0, tilt, yaw)
                qx, qy, _ = project(math.cos(s) * R * 1.07, math.sin(s) * R * 1.07, 0, tilt, yaw)
                canvas = front if pz < 0 else back
                canvas.line([(px, py), (qx, qy)], fill=(255, 226, 150, 220 if pz < 0 else 100), width=1.0)
            s = TAU * (t * rate + idx / 3)
            px, py, pz = project(math.cos(s) * R, math.sin(s) * R, 0, tilt, yaw)
            canvas = front if pz < 0 else back
            color = [(140, 210, 255), (255, 140, 120), (180, 255, 200)][idx]
            canvas.circle(px, py, 0.04 if pz < 0 else 0.03, fill=color + (255,))
        frames.append(glow(stack(back.done(), glow(sun.done(), 4, 0.8), front.done()), 2, 0.45))
    return frames


def tempest():
    """A thunderhead churning, slanting rain beneath, lightning lighting it from inside twice a loop."""
    x, y, r, _ = polar()
    cloud = PeriodicNoise(401, (8, 8, 8))
    rng = np.random.default_rng(402)
    drops = [(rng.uniform(-0.6, 0.7), rng.random(), rng.uniform(0.9, 1.3)) for _ in range(34)]
    bolt = [(0.05, 0.05)]
    for _ in range(6):
        bolt.append((bolt[-1][0] + rng.uniform(-0.09, 0.09), bolt[-1][1] - 0.11))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        flash = max(math.exp(-((t - 0.3) / 0.025) ** 2), 0.7 * math.exp(-((t - 0.72) / 0.02) ** 2))
        n = cloud.fbm(x * 2.5, y * 2.5, t * 8, octaves=4)
        mask = np.clip(1 - np.hypot(x / 0.78, (y - 0.25) / 0.34), 0, 1)
        density = np.clip((n * 0.6 + mask * 0.9 - 0.45) * 3, 0, 1)
        shade = 0.25 + 0.35 * np.clip(y - 0.05, 0, 0.5) * 2
        rgb = np.stack([shade * 0.75, shade * 0.82, shade * 1.0], axis=-1) + flash * 0.65 * mask[..., None]
        image = np.zeros(r.shape + (4,), np.float32)
        blend(image, np.clip(rgb, 0, 1), density)
        rain = Canvas()
        for dx, phase, speed in drops:
            p = (t * 2 + phase) % 1.0
            py = 0.0 - p * 0.95 * speed
            px = dx - p * 0.25
            if py < -0.9:
                continue
            rain.line([(px, py), (px + 0.03, py + 0.09)], fill=(150, 190, 255, int(200 * (1 - p * 0.6))), width=1.0)
        strike = Canvas()
        if flash > 0.2:
            strike.line(bolt, fill=(230, 240, 255, int(255 * flash)), width=2.4)
        frames.append(vignette(stack(rain.done(), to_image(image), glow(strike.done(), 3, 1.0)), 0.75, 0.97))
    return frames


def rift():
    """A tear in space: a jagged magenta-white slit breathing open, pulling streaks of light into it."""
    x, y, r, _ = polar()
    energy = PeriodicNoise(411, (8, 8, 8))
    rng = np.random.default_rng(412)
    jag = rng.uniform(-1, 1, 24)
    streaks = [(rng.uniform(0, TAU), rng.random(), rng.uniform(0.5, 0.9)) for _ in range(22)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        breathe = 0.5 + 0.5 * math.sin(TAU * t)
        idx = np.clip(((y + 0.75) / 1.5 * 23).astype(int), 0, 23)
        width = (0.04 + 0.07 * breathe) * np.clip(1 - np.abs(y / 0.75) ** 2, 0, 1) + 0.01 * jag[idx]
        slit = np.abs(x - 0.03 * np.sin(y * 7)) - np.maximum(width, 0)
        n = energy.fbm(x * 6, y * 3, t * 8, octaves=3)
        inner = edge(slit, 0.012)
        image = ramp(np.clip(1 - slit / 0.25, 0, 1) ** 3 * (0.6 + 0.4 * n), [(0, (0.6, 0.1, 0.9, 0)), (0.5, (0.95, 0.3, 0.9, 0.7)), (1, (1, 0.85, 1, 1))])
        blend(image, (1, 1, 1), inner * (0.7 + 0.3 * n))
        c = Canvas()
        for a, phase, start in streaks:
            p = (t * 2 + phase) % 1.0
            rr = start * (1 - p) + 0.02
            px, py = math.cos(a) * rr * 0.6, math.sin(a) * rr
            qx, qy = math.cos(a) * (rr + 0.08) * 0.6, math.sin(a) * (rr + 0.08)
            c.line([(px, py), (qx, qy)], fill=(255, 170, 250, int(230 * math.sin(math.pi * p))), width=1.2)
        frames.append(glow(over(to_image(image), c.done()), 3, 0.6))
    return frames


# ------------------------------------------------------------------------------------------------
# energy and signal
# ------------------------------------------------------------------------------------------------

def quantum():
    """An atom in superposition: three tilted orbitals, electrons smeared into flickering ghosts."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        orbits, electrons, core = Canvas(), Canvas(), Canvas()
        flick = np.random.default_rng(420 + f)
        for idx in range(3):
            tilt = idx * math.pi / 3
            pts = []
            for i in range(65):
                s = TAU * i / 64
                pts.append(rot(math.cos(s) * 0.66, math.sin(s) * 0.2, tilt))
            orbits.line(pts, fill=(110, 200, 255, 150), width=1.2)
            s = TAU * (t * (idx + 1) + idx / 3)
            ex, ey = rot(math.cos(s) * 0.66, math.sin(s) * 0.2, tilt)
            for k in range(1, 7):
                gx, gy = rot(math.cos(s - k * 0.12) * 0.66, math.sin(s - k * 0.12) * 0.2, tilt)
                electrons.circle(gx, gy, 0.03 * (1 - k / 8), fill=(140, 230, 255, int(150 * (1 - k / 7))))
            electrons.circle(ex, ey, 0.04, fill=(225, 250, 255, 255))
            if flick.random() > 0.55:
                gx, gy = rot(math.cos(s + math.pi) * 0.66, math.sin(s + math.pi) * 0.2, tilt)
                electrons.circle(gx, gy, 0.035, fill=(200, 160, 255, int(flick.uniform(60, 160))))
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 3)
        for k, (dx, dy) in enumerate([(0, 0), (0.05, 0.03), (-0.04, 0.04), (0.02, -0.05), (-0.05, -0.02)]):
            color = (255, 140, 120, 255) if k % 2 == 0 else (130, 180, 255, 255)
            core.circle(dx * (1 + 0.15 * pulse), dy * (1 + 0.15 * pulse), 0.045, fill=color)
        frames.append(glow(stack(glow(orbits.done(), 2, 0.5), glow(core.done(), 3, 0.7), glow(electrons.done(), 2.5, 0.9)), 2, 0.4))
    return frames


def aether():
    """An hourglass of light: eight strands twisting through a waist, motes riding them upward."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        back, front = Canvas(), Canvas()
        for k in range(8):
            prev = None
            for i in range(41):
                hgt = -0.72 + 1.44 * i / 40
                radius = 0.06 + 0.5 * abs(hgt) ** 1.1
                a = TAU * k / 8 + hgt * 3.2 + TAU * t / 8
                px, py = math.cos(a) * radius, hgt + math.sin(a) * radius * 0.16
                depth = math.sin(a)
                if prev is not None:
                    canvas = front if depth < 0 else back
                    canvas.line([prev, (px, py)], fill=(255, 236, 190, 230 if depth < 0 else 90), width=1.4)
                prev = (px, py)
            for m in range(2):
                p = (t + m / 2 + k / 16) % 1.0
                hgt = -0.72 + 1.44 * p
                radius = 0.06 + 0.5 * abs(hgt) ** 1.1
                a = TAU * k / 8 + hgt * 3.2 + TAU * t / 8
                depth = math.sin(a)
                canvas = front if depth < 0 else back
                canvas.circle(math.cos(a) * radius, hgt + math.sin(a) * radius * 0.16, 0.022, fill=(255, 252, 230, int(255 * math.sin(math.pi * p))))
        waist = Canvas()
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 2)
        waist.circle(0, 0, 0.07 + 0.02 * pulse, fill=(255, 248, 215, 255))
        frames.append(glow(stack(glow(back.done(), 2, 0.5), glow(waist.done(), 5, 0.9), glow(front.done(), 2, 0.6)), 2, 0.4))
    return frames


def glitch():
    """Corrupted data: an RGB-split wireframe cube tearing into displaced scanline slices, code raining."""
    rng = np.random.default_rng(431)
    columns = [(rng.uniform(-0.8, 0.8), rng.random(), int(rng.integers(1, 3))) for _ in range(14)]
    cube = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8) if sum(1 for i in range(3) if cube[a][i] != cube[b][i]) == 1]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        yaw = math.pi / 2 * t
        pitch = 0.5

        def proj(v, dx=0.0):
            x0, y0, z0 = v
            x1, z1 = x0 * math.cos(yaw) + z0 * math.sin(yaw), -x0 * math.sin(yaw) + z0 * math.cos(yaw)
            y2 = y0 * math.cos(pitch) - z1 * math.sin(pitch)
            return x1 * 0.3 + dx, y2 * 0.3 + 0.02

        layers = []
        for dx, color in ((-0.018, (255, 60, 140, 220)), (0.018, (60, 230, 255, 220)), (0, (230, 255, 240, 255))):
            c = Canvas()
            for a, b in edges:
                c.line([proj(cube[a], dx), proj(cube[b], dx)], fill=color, width=1.6)
            layers.append(c.done())
        rain = Canvas()
        for cx, phase, rate in columns:
            p = (t * rate + phase) % 1.0
            head = 0.9 - p * 1.8
            for k in range(6):
                rain.polygon([(cx - 0.012, head + k * 0.05), (cx + 0.012, head + k * 0.05), (cx + 0.012, head + k * 0.05 + 0.03), (cx - 0.012, head + k * 0.05 + 0.03)], (90, 255, 160, int(200 * (1 - k / 6))))
        image = stack(rain.done(), *layers)
        arr = np.asarray(image).copy()
        chaos = np.random.default_rng(440 + f)
        if chaos.random() > 0.35:
            for _ in range(int(chaos.integers(2, 5))):
                top = int(chaos.integers(10, 150))
                height = int(chaos.integers(3, 12))
                arr[top: top + height] = np.roll(arr[top: top + height], int(chaos.integers(-14, 14)), axis=1)
        scan = (np.arange(arr.shape[0]) % 3 == 0)[:, None]
        arr[..., 3] = (arr[..., 3] * np.where(scan, 0.7, 1.0)).astype(np.uint8)
        frames.append(vignette(glow(to_image(arr.astype(np.float32) / 255), 2, 0.5), 0.78, 0.98))
    return frames


def vital():
    """A life monitor: an ECG trace sweeping across, beating twice a loop, the ring flaring on each beat."""
    x, y, r, _ = polar()
    frames = []

    def beat_shape(s):
        # P, QRS spike and T wave over one beat (s in [0, 1))
        return 0.05 * math.exp(-((s - 0.18) / 0.04) ** 2) - 0.08 * math.exp(-((s - 0.38) / 0.012) ** 2) + 0.42 * math.exp(-((s - 0.42) / 0.014) ** 2) - 0.14 * math.exp(-((s - 0.46) / 0.014) ** 2) + 0.1 * math.exp(-((s - 0.66) / 0.05) ** 2)

    for f in range(FRAMES):
        t = f / FRAMES
        beat = max(math.exp(-(((t * 2) % 1.0 - 0.42) / 0.06) ** 2), 0)
        frame = lit(ring(r, 0.66, 0.0006) * (0.6 + 0.4 * beat) + ring(r, 0.66 + 0.1 * beat, 0.003) * beat * 0.6, [(0, (0.3, 1, 0.6, 0)), (1, (0.6, 1, 0.8, 1))])
        c = Canvas()
        head = -0.6 + 1.2 * t
        pts = []
        for i in range(121):
            px = -0.6 + 1.2 * i / 120
            behind = (head - px) % 1.2
            if behind > 0.9:
                continue
            pts.append((px, beat_shape(((px + 0.6) / 0.6) % 1.0) - 0.02, behind))
        for i in range(len(pts) - 1):
            ax, ay, ab = pts[i]
            bx, by, _ = pts[i + 1]
            if abs(bx - ax) > 0.05:
                continue
            c.line([(ax, ay), (bx, by)], fill=(110, 255, 160, int(255 * (1 - ab / 0.9) ** 1.3)), width=2.0)
        c.circle(head, beat_shape(((head + 0.6) / 0.6) % 1.0) - 0.02, 0.03, fill=(230, 255, 240, 255))
        frames.append(glow(over(frame, c.done()), 3, 0.7))
    return frames


def neon():
    """A neon sign: a triangle, a ring and a zig-zag in pink and cyan tube light, one stuttering on."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        stutter = 1.0 if not (0.4 < t < 0.52) else (0.25 if f % 2 else 0.9)
        c1, c2, c3 = Canvas(), Canvas(), Canvas()
        tri = [(math.cos(a) * 0.5, math.sin(a) * 0.5 - 0.04) for a in (math.pi / 2, math.pi / 2 + TAU / 3, math.pi / 2 + 2 * TAU / 3)]
        c1.line(tri + [tri[0]], fill=(255, 80, 200, 255), width=4.0)
        c2.circle(0, -0.04, 0.2, outline=(80, 240, 255, int(255 * stutter)), width=4.0)
        zig = [(-0.62 + 0.124 * i, -0.62 + (0.06 if i % 2 else -0.06)) for i in range(11)]
        c3.line(zig, fill=(255, 220, 90, 255), width=3.0)
        hum = 0.92 + 0.08 * math.sin(TAU * t * 6)
        layers = [glow(glow(layer.done(), 5, 0.9 * hum), 2, 0.8) for layer in (c1, c2, c3)]
        frames.append(stack(*layers))
    return frames


def hologram():
    """A cyan hologram of an icosahedron over its emitter, a scan band rolling up through it."""
    phi = (1 + 5 ** 0.5) / 2
    verts = []
    for a, b in ((1, phi), (-1, phi), (1, -phi), (-1, -phi)):
        verts += [(0, a, b), (a, b, 0), (b, 0, a)]
    norm = math.sqrt(1 + phi * phi)
    verts = [(vx / norm, vy / norm, vz / norm) for vx, vy, vz in verts]
    edges = [(i, j) for i in range(12) for j in range(i + 1, 12) if abs(math.dist(verts[i], verts[j]) - 2 / norm) < 1e-3]
    # put a vertex on the vertical axis so a fifth of a turn is a symmetry
    axis = verts[1]
    ay, az = axis[1], axis[2]
    tilt = math.atan2(az, ay)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        yaw = TAU / 5 * t
        c, beam = Canvas(), Canvas()
        scan = -0.5 + ((t * 2) % 1.0) * 1.1

        def proj(v):
            x0, y0, z0 = v
            y1, z1 = y0 * math.cos(tilt) + z0 * math.sin(tilt), -y0 * math.sin(tilt) + z0 * math.cos(tilt)
            x2, z2 = x0 * math.cos(yaw) + z1 * math.sin(yaw), -x0 * math.sin(yaw) + z1 * math.cos(yaw)
            y3 = y1 * math.cos(0.35) - z2 * math.sin(0.35)
            z3 = y1 * math.sin(0.35) + z2 * math.cos(0.35)
            return x2 * 0.42, y3 * 0.42 + 0.12, z3

        pts = [proj(v) for v in verts]
        for i, j in edges:
            ax, ay2, az2 = pts[i]
            bx, by, bz = pts[j]
            near = math.exp(-(((ay2 + by) / 2 - scan) / 0.06) ** 2)
            alpha = int((200 if az2 + bz < 0 else 90) + 55 * near)
            c.line([(ax, ay2), (bx, by)], fill=(int(120 + 120 * near), 240, 255, min(255, alpha)), width=1.5)
        for px, py, pz in pts:
            c.circle(px, py, 0.018, fill=(220, 255, 255, 240 if pz < 0 else 120))
        beam.polygon([(-0.08, -0.62), (0.08, -0.62), (0.46, 0.12), (-0.46, 0.12)], (80, 220, 255, 26))
        beam.ellipse(0, -0.64, 0.2, 0.05, fill=(90, 230, 255, 200))
        beam.polygon([(-0.5, scan - 0.01), (0.5, scan - 0.01), (0.5, scan + 0.01), (-0.5, scan + 0.01)], (180, 255, 255, 90))
        image = stack(glow(beam.done(), 3, 0.6), glow(c.done(), 2.5, 0.8))
        arr = np.asarray(image).astype(np.float32) / 255
        arr[::2, :, 3] *= 0.78
        frames.append(to_image(arr))
    return frames


# ------------------------------------------------------------------------------------------------
# life, growth and dream
# ------------------------------------------------------------------------------------------------

def thorn():
    """Three thorned briars spiralling round a crimson rose that slowly turns."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        vines, rose = Canvas(), Canvas()
        spin = TAU * t / 3
        for k in range(3):
            pts = []
            for i in range(60):
                s = i / 59
                a = spin + TAU * k / 3 + s * 4.2
                rr = 0.16 + s * 0.6
                pts.append((math.cos(a) * rr, math.sin(a) * rr))
            vines.line(pts, fill=(48, 110, 52, 255), width=3.4 - 0)
            vines.line(pts, fill=(96, 170, 84, 160), width=1.0)
            for i in range(6, 60, 7):
                px, py = pts[i]
                qx, qy = pts[i - 1]
                dx, dy = px - qx, py - qy
                n = math.hypot(dx, dy) or 1
                nx, ny = -dy / n, dx / n
                side = 1 if i % 2 else -1
                vines.polygon([(px - dx * 0.8, py - dy * 0.8), (px + dx * 0.8, py + dy * 0.8), (px + nx * 0.06 * side + dx, py + ny * 0.06 * side + dy)], (150, 196, 120, 255))
        for layer, (count, radius, color) in enumerate([(5, 0.2, (150, 16, 40)), (5, 0.14, (196, 28, 58)), (4, 0.085, (232, 60, 84))]):
            for i in range(count):
                a = -spin * (1 + layer * 0.5) * (5 / count) + TAU * i / count + layer * 0.6
                px, py = math.cos(a) * radius * 0.55, math.sin(a) * radius * 0.55
                rose.ellipse(px, py, radius * 0.62, radius * 0.62, fill=color + (255,))
                rose.arc(px, py, radius * 0.6, 200, 300, (255, 140, 160, 160), 1.0)
        rose.circle(0, 0, 0.035, fill=(110, 8, 26, 255))
        frames.append(glow(over(vines.done(), rose.done()), 2, 0.4))
    return frames


def spore():
    """A bioluminescent mushroom pulsing teal, puffing glowing spores that sway as they rise."""
    rng = np.random.default_rng(451)
    motes = [(rng.uniform(-0.3, 0.3), rng.random(), rng.uniform(0.012, 0.025), rng.uniform(0.6, 1.2)) for _ in range(20)]
    spots = [(rng.uniform(-0.3, 0.3), rng.uniform(0.0, 0.18), rng.uniform(0.02, 0.04)) for _ in range(8)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        pulse = 0.5 + 0.5 * math.sin(TAU * t)
        c, glowc, air = Canvas(), Canvas(), Canvas()
        c.polygon([(-0.07, -0.62), (0.07, -0.62), (0.05, -0.08), (-0.05, -0.08)], (220, 232, 236, 255))
        c.ellipse(0, -0.62, 0.18, 0.04, fill=(40, 70, 80, 255))
        cap = [(math.cos(a) * 0.46, -0.06 + math.sin(a) * 0.3) for a in np.linspace(0, math.pi, 30)]
        c.polygon(cap + [(-0.46, -0.06), (0.46, -0.06)], (34, 96, 120, 255))
        for i in range(13):
            gx = -0.4 + 0.8 * i / 12
            c.line([(gx * 0.3, -0.12), (gx, -0.06)], fill=(120, 230, 230, int(120 + 100 * pulse)), width=1.0)
        for sx, sy, size in spots:
            glowc.circle(sx, -0.02 + sy, size, fill=(120, 255, 230, int(150 + 100 * pulse)))
        for mx, phase, size, rate in motes:
            p = (t + phase) % 1.0
            px = mx * (1 + p) + 0.06 * math.sin(TAU * (p * 2 + phase))
            py = 0.1 + p * 0.85
            air.circle(px, py, size, fill=(160, 255, 220, int(230 * math.sin(math.pi * p))))
        frames.append(glow(stack(c.done(), glow(glowc.done(), 3, 0.9), glow(air.done(), 2, 0.8)), 2, 0.4))
    return frames


def bloom():
    """A five-petal blossom turning, petals peeling off to tumble outward on a spiral breeze."""
    rng = np.random.default_rng(461)
    drift = [(rng.uniform(0, TAU), rng.random(), int(rng.integers(1, 3))) for _ in range(14)]
    frames = []

    def petal(c, cx, cy, angle, length, width, color):
        pts = []
        for i in range(17):
            s = i / 16
            w = math.sin(math.pi * s) * width * (1 - 0.3 * s)
            pts.append((s * length, w))
        for i in range(16, -1, -1):
            s = i / 16
            w = math.sin(math.pi * s) * width * (1 - 0.3 * s)
            pts.append((s * length, -w))
        notch = (length * 0.92, 0)
        pts.insert(17, notch)
        c.polygon([(cx + px * math.cos(angle) - py * math.sin(angle), cy + px * math.sin(angle) + py * math.cos(angle)) for px, py in pts], color)

    for f in range(FRAMES):
        t = f / FRAMES
        c, air = Canvas(), Canvas()
        spin = TAU * t / 5
        for i in range(5):
            a = spin + TAU * i / 5
            petal(c, 0, 0, a, 0.4, 0.17, (255, 176, 206, 255))
            petal(c, 0, 0, a, 0.3, 0.1, (255, 214, 230, 200))
        c.circle(0, 0, 0.07, fill=(255, 226, 120, 255))
        for i in range(10):
            a = TAU * i / 10 + spin
            c.circle(math.cos(a) * 0.09, math.sin(a) * 0.09, 0.012, fill=(255, 240, 170, 255))
        for a0, phase, tumble in drift:
            p = (t + phase) % 1.0
            a = a0 + p * 2.4
            rr = 0.3 + p * 0.55
            size = 0.06 * abs(math.cos(TAU * (t * tumble + phase))) + 0.015
            air.ellipse(math.cos(a) * rr, math.sin(a) * rr, size, 0.035, fill=(255, 190, 215, int(230 * math.sin(math.pi * p))))
        frames.append(glow(over(c.done(), air.done()), 2, 0.4))
    return frames


def dream():
    """Pastel soap bubbles with shifting thin-film colours drifting up through soft cloud."""
    x, y, r, theta = polar()
    haze = PeriodicNoise(471, (8, 8, 8))
    rng = np.random.default_rng(472)
    bubbles = [(rng.uniform(-0.5, 0.5), rng.random(), rng.uniform(0.08, 0.17)) for _ in range(7)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        n = haze.fbm(x * 2, y * 2 - t * 8, t * 8, octaves=3)
        image = np.zeros(r.shape + (4,), np.float32)
        blend(image, (0.85, 0.75, 1.0), np.clip((n - 0.45) * 2.4, 0, 1) * 0.45)
        for bx, phase, size in bubbles:
            p = (t + phase) % 1.0
            cx = bx + 0.05 * math.sin(TAU * (p + phase))
            cy = -0.8 + p * 1.6
            d = np.hypot(x - cx, y - cy)
            film = hue_rgb(np.arctan2(y - cy, x - cx) / TAU + t + phase) * 0.5 + 0.5
            fade = math.sin(math.pi * p)
            blend(image, film, ring(d, size, 0.00025 * size * 10) * 0.9 * fade)
            blend(image, (1, 1, 1), np.exp(-((x - cx + size * 0.4) ** 2 + (y - cy - size * 0.4) ** 2) / (size * size * 0.02)) * fade)
            blend(image, film, edge(d - size) * 0.08 * fade)
        frames.append(vignette(glow(to_image(image), 2, 0.4), 0.72, 0.96))
    return frames


def feather():
    """A phoenix quill rocking on a warm updraft, its vanes catching a travelling sheen, sparks shed."""
    rng = np.random.default_rng(481)
    sparks = [(rng.uniform(-0.2, 0.2), rng.random(), rng.uniform(0.01, 0.022)) for _ in range(16)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        sway = 0.22 * math.sin(TAU * t)
        lift = 0.04 * math.sin(TAU * t * 2)
        c, air = Canvas(), Canvas()
        base_a = math.pi / 2 + 0.5 + sway

        def at(s, off):
            bend = 0.12 * s * s
            px, py = s * 1.1 - 0.55, bend + off
            q = rot(px, py, base_a - math.pi / 2)
            return q[0], q[1] + lift

        sheen = (t * 1.6) % 1.6 - 0.3
        for i in range(30):
            s = i / 29
            width = 0.17 * math.sin(math.pi * min(1, s * 1.1)) * (1 - 0.2 * s)
            near = math.exp(-((s - sheen) / 0.1) ** 2)
            for side in (-1, 1):
                a0 = at(s, 0)
                a1 = at(min(1, s + 0.12), side * width)
                hue = (255, int(120 + 100 * s + 35 * near), int(40 + 60 * near))
                c.line([a0, a1], fill=hue + (230,), width=2.2)
        c.line([at(s / 20, 0) for s in range(21)], fill=(255, 240, 200, 255), width=1.6)
        for sx, phase, size in sparks:
            p = (t + phase) % 1.0
            px, py = at(0.15 + 0.7 * phase, 0)
            air.circle(px + sx * p, py - p * 0.4, size, fill=(255, 190, 90, int(230 * (1 - p))))
        frames.append(glow(over(c.done(), glow(air.done(), 2, 0.8)), 3, 0.55))
    return frames


def abyss():
    """A deep-sea jellyfish pulsing its bell, glowing tentacles trailing, marine snow drifting down."""
    rng = np.random.default_rng(491)
    snow = [(rng.uniform(-0.85, 0.85), rng.random(), rng.uniform(0.006, 0.014)) for _ in range(26)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        squeeze = 0.5 + 0.5 * math.sin(TAU * t)
        rise = 0.05 * math.sin(TAU * t - 1.0)
        bell, tent, sea = Canvas(), Canvas(), Canvas()
        for sx, phase, size in snow:
            p = (t + phase) % 1.0
            sea.circle(sx, 0.85 - p * 1.7, size, fill=(170, 210, 255, 120))
        w = 0.36 - 0.07 * squeeze
        hgt = 0.26 + 0.06 * squeeze
        top = 0.2 + rise
        dome = [(math.cos(a) * w, top + math.sin(a) * hgt) for a in np.linspace(0, math.pi, 32)]
        skirt = [(-w + 2 * w * i / 12, top - 0.03 * (1 + (i % 2))) for i in range(13)]
        bell.polygon(dome + skirt, (210, 120, 255, 150))
        bell.polygon([(math.cos(a) * w * 0.6, top + 0.02 + math.sin(a) * hgt * 0.62) for a in np.linspace(0, math.pi, 24)], (255, 200, 255, 120))
        for i in range(4):
            a = TAU * i / 4 + 0.4
            bell.circle(math.cos(a) * w * 0.3, top + 0.08 + math.sin(a) * 0.03, 0.03, fill=(255, 170, 230, 230))
        for k in range(7):
            x0 = -w * 0.8 + 1.6 * w * k / 6
            pts = []
            for i in range(25):
                s = i / 24
                pts.append((x0 + 0.06 * math.sin(TAU * (t - s * 0.8) + k), top - 0.05 - s * (0.55 + 0.05 * (k % 3))))
            tent.line(pts, fill=(120, 230, 255, 200), width=1.4)
        frames.append(stack(sea.done(), glow(tent.done(), 2.5, 0.8), glow(bell.done(), 3, 0.7)))
    return frames


# ------------------------------------------------------------------------------------------------
# dark arts and mixtures
# ------------------------------------------------------------------------------------------------

def smoke():
    """A smouldering coal sending up curling ribbons of smoke that unravel as they rise."""
    x, y, r, _ = polar()
    curl = PeriodicNoise(501, (8, 8, 8))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        n = curl.fbm(x * 2.2 + 0.4 * np.sin(y * 3 + TAU * t), y * 2.2 - t * 8, t * 8, octaves=4)
        width = 0.12 + 0.34 * np.clip((y + 0.6) / 1.4, 0, 1)
        column = np.exp(-((x - 0.12 * np.sin(y * 2.5 - TAU * t)) / width) ** 2)
        rise = np.clip((y + 0.62) / 0.1, 0, 1) * np.clip((0.9 - y) / 0.5, 0, 1)
        density = np.clip((n - 0.38) * 2.6, 0, 1) * column * rise
        image = ramp(np.clip((y + 0.6) / 1.4, 0, 1), [(0, (0.55, 0.45, 0.42, 1)), (1, (0.42, 0.4, 0.5, 1))])
        image[..., 3] = density * 0.85
        ember = np.exp(-(x ** 2 / 0.02 + (y + 0.64) ** 2 / 0.004)) * (0.75 + 0.25 * math.sin(TAU * t * 3))
        blend(image, (1, 0.5, 0.15), ember)
        blend(image, (0.12, 0.08, 0.08), edge(np.hypot(x / 0.2, (y + 0.7) / 0.06) - 1, 0.04) * 0.9)
        frames.append(glow(to_image(image), 2, 0.35))
    return frames


def necrotic():
    """A ring of sickly green ghost-fire licking outward around a void, bone shards orbiting inside."""
    x, y, r, theta = polar()
    flame = PeriodicNoise(511, (8, 8, 8))
    shards = [(TAU * k / 6, 0.21 + 0.03 * (k % 2)) for k in range(6)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        n = flame.fbm(theta / TAU * 8, r * 4 - t * 8, t * 8, octaves=4)
        heat = np.clip(1 - (r - 0.36) / (0.08 + 0.32 * n), 0, 1) * edge(0.33 - r, 0.04)
        image = ramp(heat ** 1.4, [(0, (0.1, 0.4, 0.1, 0)), (0.35, (0.25, 0.75, 0.2, 0.7)), (0.75, (0.6, 1.0, 0.4, 0.95)), (1, (0.9, 1.0, 0.8, 1))])
        blend(image, (0.02, 0.05, 0.03), edge(r - 0.33) * 0.95)
        c = Canvas()
        spin = TAU * t / 6
        for a0, radius in shards:
            a = a0 + spin
            cx, cy = math.cos(a) * radius, math.sin(a) * radius
            q = [rot(px, py, a + 1.2) for px, py in ((-0.04, -0.012), (0.04, -0.008), (0.05, 0.0), (0.04, 0.012), (-0.04, 0.01))]
            c.polygon([(cx + px, cy + py) for px, py in q], (226, 232, 210, 255))
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 2)
        c.circle(0, 0, 0.05 + 0.01 * pulse, fill=(150, 255, 120, 230))
        frames.append(glow(over(to_image(image), c.done()), 3, 0.55))
    return frames


def rune():
    """A stone tablet with a carved glyph whose groove fills with light, stroke by stroke."""
    x, y, r, _ = polar()
    grain = PeriodicNoise(521, (16, 16, 4))
    strokes = [
        [(0.0, 0.42), (0.0, -0.42)],
        [(-0.24, 0.24), (0.0, 0.06), (0.24, 0.24)],
        [(-0.24, -0.16), (0.0, -0.3), (0.24, -0.16)],
        [(-0.14, 0.42), (0.14, 0.42)],
    ]
    segs = []
    for stroke in strokes:
        for a, b in zip(stroke, stroke[1:]):
            for i in range(12):
                s0, s1 = i / 12, (i + 1) / 12
                segs.append(((a[0] + (b[0] - a[0]) * s0, a[1] + (b[1] - a[1]) * s0), (a[0] + (b[0] - a[0]) * s1, a[1] + (b[1] - a[1]) * s1)))
    lengths = [math.dist(a, b) for a, b in segs]
    total = sum(lengths)
    slab = np.maximum(np.abs(x) - 0.42, np.abs(y) - 0.6)
    stone = ramp(grain.fbm(x * 4 + 8, y * 4 + 8, 0, octaves=4), [(0, (0.22, 0.22, 0.27, 1)), (1, (0.45, 0.45, 0.52, 1))])
    stone[..., 3] = edge(slab - 0.0, 0.02)
    blend(stone, (0.62, 0.62, 0.7), np.exp(-((slab + 0.01) ** 2) / 0.00015) * 0.7)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        head = t * total * 1.3
        groove, light = Canvas(), Canvas()
        run = 0.0
        for (a, b), length in zip(segs, lengths):
            groove.line([a, b], fill=(20, 18, 26, 255), width=5.0)
            mid = run + length / 2
            filled = 1.0 if mid < head else 0.0
            front = math.exp(-((mid - head) / 0.06) ** 2)
            glowing = max(filled * (0.75 if t < 0.85 else (1 - (t - 0.85) / 0.15) * 0.75), front)
            if glowing > 0.02:
                light.line([a, b], fill=(255, int(170 + 70 * front), int(80 + 150 * front), int(255 * glowing)), width=3.0)
            run += length
        frames.append(stack(to_image(stone), groove.done(), glow(light.done(), 3, 0.9)))
    return frames


def mirror():
    """A ring of mirror shards each flipping on its own axis, flashing white as it faces you."""
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        back, front, core = Canvas(), Canvas(), Canvas()
        spin = TAU * t / 8
        core.circle(0, 0, 0.08, fill=(240, 246, 255, 255))
        for k in range(8):
            a = spin + TAU * k / 8
            cx, cy = math.cos(a) * 0.52, math.sin(a) * 0.52 * 0.45
            face = math.cos(TAU * (t * 2 + k / 8))
            w = 0.1 * max(abs(face), 0.1)
            flash = max(0.0, face) ** 12
            tone = int(130 + 125 * flash)
            pts = [(cx - w, cy - 0.12), (cx + w, cy - 0.06), (cx + w * 0.6, cy + 0.14), (cx - w * 0.8, cy + 0.08)]
            canvas = back if math.sin(a) > 0 else front
            canvas.polygon(pts, (tone, min(255, tone + 10), 255, 230))
            canvas.line(pts + [pts[0]], fill=(255, 200, 255, 180), width=1.0)
            if flash > 0.3:
                sparkle(canvas, cx, cy + 0.02, 0.08 * flash, (255, 255, 255, 255))
        frames.append(glow(stack(back.done(), glow(core.done(), 5, 0.9), front.done()), 2.5, 0.5))
    return frames


def ink():
    """A drop of luminous ink hitting still water and blooming into indigo tendrils that dissolve."""
    x, y, r, theta = polar()
    curl = PeriodicNoise(531, (8, 8, 8))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        image = np.zeros(r.shape + (4,), np.float32)
        c = Canvas()
        if t < 0.15:
            p = t / 0.15
            c.ellipse(0, 0.8 - p * 0.8, 0.035, 0.05, fill=(160, 120, 255, 255))
        else:
            p = (t - 0.15) / 0.85
            spread = 0.08 + 0.62 * (1 - (1 - p) ** 2.2)
            n = curl.fbm(theta / TAU * 8, r * 3, t * 8, octaves=4)
            reach = spread * (0.6 + 0.7 * n)
            body = np.clip(1 - r / np.maximum(reach, 1e-3), 0, 1)
            rim = np.exp(-((r - reach * 0.85) ** 2) / 0.003) * body.clip(0.05, 1)
            fade = (1 - p) ** 0.8
            blend(image, (0.16, 0.08, 0.38), body ** 0.6 * 0.85 * fade)
            blend(image, (0.55, 0.45, 1.0), np.clip(rim * 1.5, 0, 1) * fade)
            ripple = ring(r, 0.1 + p * 0.8, 0.002) * (1 - p)
            blend(image, (0.7, 0.8, 1.0), ripple * 0.6)
        frames.append(glow(over(to_image(image), c.done()), 2.5, 0.5))
    return frames


def frostfire():
    """Two flames of fire and two of frost spiralling together into a single violet core."""
    x, y, r, theta = polar()
    flicker = PeriodicNoise(541, (8, 8, 8))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        phase = theta - 3.2 * r - math.pi * t
        n = flicker.fbm(theta / TAU * 8, r * 4, t * 8, octaves=3)
        shape = np.clip(1 - r / 0.82, 0, 1) * (0.7 + 0.6 * n)
        fire = np.clip(np.cos(2 * phase), 0, 1) ** 4 * shape
        frost = np.clip(-np.cos(2 * phase), 0, 1) ** 4 * shape
        image = np.zeros(r.shape + (4,), np.float32)
        blend(image, (1.0, 0.5, 0.15), np.clip(fire * 1.6, 0, 1))
        blend(image, (1.0, 0.85, 0.5), np.clip(fire * 2.5 - 1, 0, 1))
        blend(image, (0.3, 0.75, 1.0), np.clip(frost * 1.6, 0, 1))
        blend(image, (0.85, 0.97, 1.0), np.clip(frost * 2.5 - 1, 0, 1))
        blend(image, (0.85, 0.7, 1.0), np.exp(-(r ** 2) / 0.008))
        frames.append(glow(to_image(image), 3, 0.5))
    return frames


WAVE = {
    "crystal": crystal, "steel": steel, "gold": gold, "amber": amber, "magnet": magnet,
    "gravity": gravity, "nebula": nebula, "aurora": aurora, "lunar": lunar, "comet": comet,
    "eclipse": eclipse, "starlight": starlight, "celestial": celestial, "tempest": tempest, "rift": rift,
    "quantum": quantum, "aether": aether, "glitch": glitch, "vital": vital, "neon": neon,
    "hologram": hologram, "thorn": thorn, "spore": spore, "bloom": bloom, "dream": dream,
    "feather": feather, "abyss": abyss, "smoke": smoke, "necrotic": necrotic, "rune": rune,
    "mirror": mirror, "ink": ink, "frostfire": frostfire,
}

base.ELEMENTS.update(WAVE)

if __name__ == "__main__":
    wanted = sys.argv[1:] or list(WAVE)
    for element in wanted:
        base.build(element)
