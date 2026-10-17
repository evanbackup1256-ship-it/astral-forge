"""Generate the elemental spritesheets used by the artifact UI (Sprite library, Vendor/Sprite).

    python tools/spritegen/build_elements.py            # all six
    python tools/spritegen/build_elements.py fire void  # some

Each legacy sheet is 6 x 6 frames of 170 px, RGBA with
straight alpha, and loops seamlessly: every time-varying term is periodic over the 36 frames.
Output: assets/generated/sprites/<element>.png and previews/<element>_preview.png (over a dark panel).
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "sprites")
PREVIEWS = os.path.join(OUT, "previews")
os.makedirs(PREVIEWS, exist_ok=True)

FRAME = int(os.environ.get("AF_ELEMENT_FRAME", "170"))
if FRAME not in (170, 682):
    raise ValueError("AF_ELEMENT_FRAME must be 170 (legacy) or 682 (4K atlas)")
PIXEL_SCALE = FRAME / 170
COLUMNS = 6
FRAMES = 36
TAU = math.tau


# ------------------------------------------------------------------------------------------------
# periodic value noise: lattice wraps on every axis, so scrolling by a full period or running time
# through a full period lands exactly where it started
# ------------------------------------------------------------------------------------------------

class PeriodicNoise:
    def __init__(self, seed: int, size=(8, 8, 8)):
        rng = np.random.default_rng(seed)
        self.grid = rng.random(size).astype(np.float32)
        self.size = size

    def sample(self, x, y, z):
        nx, ny, nz = self.size
        x = np.asarray(x, dtype=np.float32)
        y = np.asarray(y, dtype=np.float32)
        z = np.asarray(z, dtype=np.float32) + np.zeros_like(x)
        xi = np.floor(x).astype(int)
        yi = np.floor(y).astype(int)
        zi = np.floor(z).astype(int)
        xf, yf, zf = x - xi, y - yi, z - zi
        sx = xf * xf * (3 - 2 * xf)
        sy = yf * yf * (3 - 2 * yf)
        sz = zf * zf * (3 - 2 * zf)
        g = self.grid

        def at(dx, dy, dz):
            return g[(xi + dx) % nx, (yi + dy) % ny, (zi + dz) % nz]

        c00 = at(0, 0, 0) * (1 - sx) + at(1, 0, 0) * sx
        c10 = at(0, 1, 0) * (1 - sx) + at(1, 1, 0) * sx
        c01 = at(0, 0, 1) * (1 - sx) + at(1, 0, 1) * sx
        c11 = at(0, 1, 1) * (1 - sx) + at(1, 1, 1) * sx
        c0 = c00 * (1 - sy) + c10 * sy
        c1 = c01 * (1 - sy) + c11 * sy
        return c0 * (1 - sz) + c1 * sz

    def fbm(self, x, y, z, octaves=4):
        total = 0.0
        amp = 0.5
        norm = 0.0
        freq = 1
        for _ in range(octaves):
            total = total + self.sample(x * freq, y * freq, z * freq) * amp
            norm += amp
            amp *= 0.5
            freq *= 2
        return total / norm


def grid():
    """Pixel coordinates: u in [-1, 1] left to right, v in [0, 1] bottom to top."""
    ys, xs = np.mgrid[0:FRAME, 0:FRAME].astype(np.float32)
    u = (xs + 0.5) / FRAME * 2 - 1
    v = 1 - (ys + 0.5) / FRAME
    return u, v


def ramp(value, stops):
    """Map value in [0, 1] through [(pos, (r, g, b, a)), ...] color stops."""
    value = np.clip(value, 0, 1)
    out = np.zeros(value.shape + (4,), dtype=np.float32)
    positions = [p for p, _ in stops]
    colors = np.array([c for _, c in stops], dtype=np.float32)
    for channel in range(4):
        out[..., channel] = np.interp(value, positions, colors[:, channel])
    return out


def to_image(rgba):
    rgba = np.clip(rgba, 0, 1)
    return Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")


def over(base: Image.Image, top: Image.Image) -> Image.Image:
    return Image.alpha_composite(base, top)


def blank():
    return Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))


def particles():
    """A separate layer: ImageDraw replaces pixels instead of blending, so particles never draw
    straight onto a soft layer (that punches dark holes); they go here and get composited."""
    layer = blank()
    return layer, ImageDraw.Draw(layer)


def glow(image: Image.Image, radius: float, strength: float) -> Image.Image:
    """Additive-looking bloom: blur the layer and lay it under itself."""
    # High-resolution sheets retain the emissive halo without burying the sharp core.
    hq = FRAME > 170
    layer = image.convert("RGBa") if hq else image
    blurred = layer.filter(ImageFilter.GaussianBlur(radius * PIXEL_SCALE * (0.65 if hq else 1)))
    if hq:
        blurred = blurred.convert("RGBA")
    arr = np.asarray(blurred).astype(np.float32) / 255
    arr[..., 3] = np.clip(arr[..., 3] * strength * (0.7 if hq else 1), 0, 1)
    return over(to_image(arr), image)


# ------------------------------------------------------------------------------------------------
# the elements: each returns a list of FRAMES RGBA images
# ------------------------------------------------------------------------------------------------

def fire():
    noise = PeriodicNoise(11, (8, 8, 8))
    detail = PeriodicNoise(12, (16, 16, 8))
    u, v = grid()
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        # rising: scroll the noise up by exactly one vertical period per loop
        n = noise.fbm(u * 2.0 + 8, v * 1.8 - t * 8, t * 8, octaves=4)
        d = detail.fbm(u * 4 + 3, v * 4 - t * 16, t * 8, octaves=3)
        width = 0.86 * np.power(np.clip(1.08 - v, 0, 1), 0.7)
        sway = 0.1 * np.sin(TAU * (t + v * 0.7)) * v
        # three tongues: a tall centre and two shorter flanks, fused at the base
        centre = np.clip(1 - np.abs(u - sway) / np.maximum(width * 0.7, 1e-3), 0, 1)
        flanks = np.clip(1 - np.abs(np.abs(u - sway * 0.5) - 0.32) / np.maximum(width * 0.45, 1e-3), 0, 1) * np.clip(1.25 - v * 1.6, 0, 1)
        shape = np.maximum(centre, flanks * 0.9)
        heat = shape * 1.35 - (1 - n) * 0.9 - v * 0.45 + (d - 0.5) * 0.4
        heat = np.clip(heat * 1.55, 0, 1)
        rgba = ramp(heat, [
            (0.0, (0.55, 0.05, 0.0, 0.0)),
            (0.1, (0.7, 0.08, 0.02, 0.45)),
            (0.3, (0.97, 0.3, 0.04, 0.88)),
            (0.55, (1.0, 0.6, 0.1, 1.0)),
            (0.8, (1.0, 0.88, 0.45, 1.0)),
            (1.0, (1.0, 0.99, 0.9, 1.0)),
        ])
        image = glow(to_image(rgba), 7, 0.6)
        # embers drifting up, each on its own periodic track
        layer, draw = particles()
        rng = np.random.default_rng(13)
        for k in range(18):
            phase = rng.random()
            x0 = rng.uniform(-0.5, 0.5)
            p = (t + phase) % 1.0
            x = FRAME * (0.5 + 0.5 * (x0 + 0.07 * math.sin(TAU * (p * 2 + phase))))
            y = FRAME * (1 - (0.2 + p * 0.8))
            size = 1.0 + 1.6 * (1 - p)
            alpha = int(255 * math.sin(math.pi * p) ** 1.2)
            draw.ellipse([x - size, y - size, x + size, y + size], fill=(255, 205, 110, alpha))
        frames.append(over(image, glow(layer, 2.5, 1.2)))
    return frames


def bolt_points(rng, start, end, roughness, depth):
    points = [start, end]
    for _ in range(depth):
        refined = [points[0]]
        for a, b in zip(points, points[1:]):
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            length = math.hypot(b[0] - a[0], b[1] - a[1])
            nx, ny = -(b[1] - a[1]) / max(length, 1e-6), (b[0] - a[0]) / max(length, 1e-6)
            offset = rng.normal(0, roughness * length)
            refined += [(mx + nx * offset, my + ny * offset), b]
        points = refined
    return points


def lightning():
    u, v = grid()
    frames = []
    # four strikes per loop; each one cracks in, re-flickers once, then decays to a crackling orb
    beats = 4
    per = FRAMES // beats
    for f in range(FRAMES):
        beat = f // per
        k = f % per
        rng = np.random.default_rng(100 + beat * 7 + (1 if k in (2, 3) else 0))
        intensity = [1.0, 0.85, 0.4, 0.95, 0.7, 0.45, 0.28, 0.18, 0.12][k] if k < 9 else 0.1
        # the charged orb the bolts leap from, always present so no frame is empty
        orb = np.exp(-(u ** 2 + ((v - 0.78) * 1.2) ** 2) / 0.02) * (0.65 + 0.35 * intensity)
        base = to_image(ramp(orb, [(0, (0.3, 0.5, 1.0, 0.0)), (0.5, (0.55, 0.75, 1.0, 0.75)), (1, (0.95, 0.98, 1.0, 1.0))]))
        flash = np.exp(-(u ** 2 + (v - 0.5) ** 2) / 0.22) * intensity * 0.3
        image = over(to_image(ramp(flash, [(0, (0.4, 0.55, 1.0, 0.0)), (1, (0.55, 0.7, 1.0, 1.0))])), glow(base, 6, 1.0))
        halo, hdraw = particles()
        core, cdraw = particles()
        start = (FRAME * 0.5, FRAME * 0.22)
        for bolt in range(2):
            end = (FRAME * rng.uniform(0.15, 0.85), FRAME + 6)
            main = bolt_points(rng, start, end, 0.2, 6)
            paths = [(main, 3)]
            for _ in range(3):
                i = int(rng.integers(len(main) // 4, len(main) * 3 // 4))
                a = main[i]
                angle = math.pi / 2 + rng.uniform(-1.0, 1.0)
                reach = FRAME * rng.uniform(0.15, 0.32)
                b = (a[0] + math.cos(angle) * reach * rng.choice([-1, 1]), a[1] + math.sin(angle) * reach)
                paths.append((bolt_points(rng, a, b, 0.24, 4), 2))
            weight = intensity * (1.0 if bolt == 0 else 0.7)
            for path, width in paths:
                hdraw.line(path, fill=(110, 160, 255, int(255 * weight)), width=width * 4, joint="curve")
                cdraw.line(path, fill=(245, 250, 255, int(255 * min(1.0, weight * 1.3))), width=max(1, width), joint="curve")
        # crackle around the orb
        rng2 = np.random.default_rng(900 + f)
        for _ in range(6):
            angle = rng2.uniform(0, TAU)
            a = (FRAME * 0.5 + math.cos(angle) * 10, FRAME * 0.22 + math.sin(angle) * 10)
            b = (a[0] + math.cos(angle) * rng2.uniform(10, 22), a[1] + math.sin(angle) * rng2.uniform(10, 22))
            cdraw.line(bolt_points(rng2, a, b, 0.3, 3), fill=(200, 225, 255, 200), width=1)
        image = over(image, glow(halo, 9, 1.4))
        frames.append(over(image, glow(core, 2, 1.0)))
    return frames


def ice():
    u, v = grid()
    mist = PeriodicNoise(31, (8, 8, 8))
    rng = np.random.default_rng(32)
    shards = []
    for _ in range(9):
        cx = rng.uniform(-0.55, 0.55)
        base = rng.uniform(0.0, 0.25)
        height = rng.uniform(0.35, 0.85) * (1 - abs(cx) * 0.6)
        width = rng.uniform(0.07, 0.13)
        lean = rng.uniform(-0.25, 0.25)
        shards.append((cx, base, height, width, lean))
    shards.sort(key=lambda s: -s[2])
    sparkles = [(rng.uniform(-0.8, 0.8), rng.uniform(0.1, 0.95), rng.random()) for _ in range(16)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        image = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        # frost mist hugging the ground
        m = mist.fbm(u * 2 + t * 8, v * 2, t * 8, octaves=3)
        fog = np.clip((m - 0.35) * 2.2, 0, 1) * np.clip(1 - v * 2.4, 0, 1) * np.clip((1 - np.abs(u)) * 3, 0, 1) * np.clip(v * 8, 0, 1)
        image = over(image, to_image(ramp(fog, [(0, (0.7, 0.9, 1.0, 0.0)), (1, (0.82, 0.95, 1.0, 0.55))])))
        layer = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        sweep = (t * 1.6) % 1.6 - 0.3  # specular band crossing the cluster once per loop
        for cx, base, height, width, lean in shards:
            px = lambda x, y: (FRAME * (0.5 + 0.5 * x), FRAME * (1 - y))
            tip = px(cx + lean * height, base + height)
            left = px(cx - width, base)
            right = px(cx + width, base)
            mid_l = px(cx - width * 0.7 + lean * height * 0.6, base + height * 0.62)
            mid_r = px(cx + width * 0.7 + lean * height * 0.6, base + height * 0.62)
            body = [left, mid_l, tip, mid_r, right]
            spine = (FRAME * (0.5 + 0.5 * cx), FRAME * (1 - base))
            # shadowed right facet, lit left facet, bright spine: reads as a faceted crystal
            draw.polygon([spine, tip, mid_r, right], fill=(70, 150, 225, 225))
            draw.polygon([left, mid_l, tip, spine], fill=(185, 232, 255, 235))
            draw.line([spine, tip], fill=(250, 254, 255, 255), width=1)
            draw.line(body + [left], fill=(225, 245, 255, 255), width=1)
            # glint where the sweep band passes this shard
            shard_x = 0.5 + 0.5 * cx
            closeness = max(0.0, 1 - abs(shard_x - sweep) * 6)
            if closeness > 0:
                draw.line([mid_l, tip], fill=(255, 255, 255, int(255 * closeness)), width=2)
        image = over(image, glow(layer, 4, 0.7))
        stars, draw = particles()
        for sx, sy, phase in sparkles:
            twinkle = max(0.0, math.sin(TAU * (t * 2 + phase))) ** 3
            if twinkle < 0.05:
                continue
            x, y = FRAME * (0.5 + 0.5 * sx), FRAME * (1 - sy)
            r = 2 + 5 * twinkle
            a = int(255 * twinkle)
            # a four-point star: two thin diamonds
            draw.polygon([(x - r, y), (x, y - r * 0.18), (x + r, y), (x, y + r * 0.18)], fill=(235, 250, 255, a))
            draw.polygon([(x, y - r), (x - r * 0.18, y), (x, y + r), (x + r * 0.18, y)], fill=(235, 250, 255, a))
        frames.append(over(image, glow(stars, 2.5, 1.3)))
    return frames


def earth():
    dust = PeriodicNoise(41, (8, 8, 8))
    u, v = grid()
    rng = np.random.default_rng(42)
    rocks = []
    for k in range(7):
        radius = rng.uniform(0.32, 0.62)
        size = rng.uniform(0.07, 0.15)
        phase = k / 7 + rng.uniform(-0.04, 0.04)
        tilt = rng.uniform(0.35, 0.55)
        sides = int(rng.integers(5, 8))
        jag = rng.uniform(0.7, 1.0, sides)
        rocks.append((radius, size, phase, tilt, sides, jag))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        image = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        # a churning dust ring
        d = dust.fbm(u * 2.5 + 3, v * 2.5, t * 8, octaves=4)
        ring = np.exp(-((np.hypot(u, (v - 0.45) * 2.2) - 0.45) ** 2) / 0.02)
        haze = np.clip((d - 0.3) * 1.8, 0, 1) * ring
        image = over(image, to_image(ramp(haze, [(0, (0.55, 0.42, 0.28, 0.0)), (1, (0.72, 0.58, 0.38, 0.6))])))
        # a glowing core, like heated ore
        core = np.exp(-(u ** 2 + ((v - 0.45) * 1.0) ** 2) / 0.035) * (0.85 + 0.15 * math.sin(TAU * t))
        image = over(image, to_image(ramp(core, [(0, (0.9, 0.55, 0.2, 0.0)), (0.6, (1.0, 0.7, 0.3, 0.6)), (1, (1.0, 0.9, 0.6, 0.95))])))
        layer = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        ordered = sorted(rocks, key=lambda r: math.sin(TAU * (t + r[2])))  # back to front
        for radius, size, phase, tilt, sides, jag in ordered:
            a = TAU * (t + phase)
            depth = math.sin(a)
            x = 0.5 + 0.5 * radius * math.cos(a)
            y = 0.55 - 0.5 * radius * depth * tilt + 0.03 * math.sin(TAU * (t * 2 + phase))
            scale = size * (0.85 + 0.25 * (depth + 1) / 2)
            spin = TAU * (t + phase) * (1 if sides % 2 else -1)
            pts = []
            for i in range(sides):
                ang = spin + TAU * i / sides
                pts.append((FRAME * (x + 0.5 * scale * jag[i] * math.cos(ang)), FRAME * (y + 0.5 * scale * jag[i] * math.sin(ang))))
            shade = 0.55 + 0.45 * (depth + 1) / 2
            base = (int(120 * shade), int(88 * shade), int(58 * shade), 255)
            draw.polygon(pts, fill=base)
            lit = [pts[0], pts[1], (FRAME * x, FRAME * y)]
            draw.polygon(lit, fill=(int(176 * shade), int(140 * shade), int(96 * shade), 255))
            draw.line(pts + [pts[0]], fill=(int(70 * shade), int(50 * shade), int(32 * shade), 255), width=1)
            # a moss or ore fleck
            draw.ellipse([FRAME * x - 1.5, FRAME * y - 1.5, FRAME * x + 1.5, FRAME * y + 1.5], fill=(150, 200, 90, int(200 * shade)))
        frames.append(over(image, glow(layer, 2, 0.5)))
    return frames


def void():
    u, v = grid()
    noise = PeriodicNoise(51, (8, 8, 8))
    y = v - 0.5
    r = np.hypot(u, y * 2)
    theta = np.arctan2(y * 2, u)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        arms = 3
        # spiral arms rotate one arm spacing per loop (seamless with 3-fold symmetry)
        swirl = np.sin(arms * (theta + TAU * t / arms) + np.log(r + 0.05) * 5.5)
        n = noise.fbm(np.cos(theta) * 2 + 4, np.sin(theta) * 2 + 4, t * 8 + r * 3, octaves=3)
        body = np.clip(1 - r / 0.95, 0, 1)
        arm = np.clip((swirl * 0.5 + 0.5) * 1.3 - 0.35 + (n - 0.5) * 0.6, 0, 1) * body
        rim = np.exp(-((r - 0.33 - 0.03 * math.sin(TAU * t)) ** 2) / 0.003)
        hole = np.clip(1 - r / 0.22, 0, 1) ** 0.6
        light = np.clip(arm * 0.85 + rim * 0.9, 0, 1)
        rgba = ramp(light, [
            (0.0, (0.15, 0.0, 0.25, 0.0)),
            (0.25, (0.32, 0.06, 0.55, 0.65)),
            (0.6, (0.62, 0.22, 0.95, 0.9)),
            (0.85, (0.95, 0.5, 1.0, 1.0)),
            (1.0, (1.0, 0.85, 1.0, 1.0)),
        ])
        # the event horizon: a black core that eats the light
        dark = ramp(hole, [(0, (0, 0, 0, 0)), (0.4, (0.02, 0.0, 0.05, 0.9)), (1, (0.0, 0.0, 0.0, 1.0))])
        image = over(to_image(rgba), to_image(dark))
        frames.append(glow(image, 5, 0.6))
    return frames


def poison():
    u, v = grid()
    gas = PeriodicNoise(61, (8, 8, 8))
    rng = np.random.default_rng(62)
    bubbles = [(rng.uniform(-0.6, 0.6), rng.random(), rng.uniform(0.035, 0.085), rng.uniform(0.5, 1.0)) for _ in range(13)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        g = gas.fbm(u * 2 + 2, v * 2 - t * 8, t * 8, octaves=4)
        cloud = np.clip((g - 0.38) * 2.4, 0, 1) * np.clip(1.15 - v * 1.1, 0, 1) * np.clip(1 - np.abs(u) * 0.9, 0, 1)
        cloud = np.clip(cloud * 1.35, 0, 1) * np.clip(v * 6, 0, 1) * np.clip(1 - v * 0.15, 0, 1)
        rgba = ramp(cloud, [
            (0.0, (0.15, 0.45, 0.05, 0.0)),
            (0.3, (0.3, 0.75, 0.1, 0.6)),
            (0.65, (0.55, 0.95, 0.2, 0.88)),
            (1.0, (0.85, 1.0, 0.55, 0.95)),
        ])
        image = glow(to_image(rgba), 5, 0.5)
        # a purple underglow in the thickest gas
        under = np.clip((g - 0.62) * 3, 0, 1) * np.clip(1 - v * 1.6, 0, 1)
        image = over(image, to_image(ramp(under, [(0, (0.4, 0.1, 0.5, 0.0)), (1, (0.6, 0.25, 0.8, 0.6))])))
        layer, draw = particles()
        for bx, phase, size, speed in bubbles:
            p = (t * (2 if speed > 0.75 else 1) + phase) % 1.0
            x = FRAME * (0.5 + 0.5 * (bx + 0.05 * math.sin(TAU * (p * 2 + phase))))
            y = FRAME * (1 - (0.05 + p * 0.85))
            r = FRAME * size * (0.6 + 0.4 * p)
            if p > 0.9:
                # pop: a thin ring that widens and fades
                q = (p - 0.9) / 0.1
                rr = r * (1 + q * 0.8)
                draw.ellipse([x - rr, y - rr, x + rr, y + rr], outline=(200, 255, 140, int(220 * (1 - q))), width=1)
                continue
            draw.ellipse([x - r, y - r, x + r, y + r], fill=(130, 235, 80, 150), outline=(200, 255, 130, 240), width=1)
            draw.ellipse([x - r * 0.45, y - r * 0.6, x - r * 0.05, y - r * 0.2], fill=(240, 255, 215, 220))
        frames.append(over(image, glow(layer, 2, 0.8)))
    return frames


# ------------------------------------------------------------------------------------------------
# the second wave: eighteen more elements, each built on its own visual idea. These work in
# isotropic centred units (x right, y up, both -1..1 across the frame, so 1 unit = 85px) and draw
# shapes on a supersampled canvas, so edges come out anti-aliased and translucent shapes blend.
# ------------------------------------------------------------------------------------------------

PIX = 2 / FRAME
BOX = getattr(Image, "Resampling", Image).BOX


def polar():
    u, v = grid()
    y = (v - 0.5) * 2
    return u, y, np.hypot(u, y), np.arctan2(y, u)


def edge(distance, width=PIX):
    """Anti-aliased coverage of a signed distance (negative is inside)."""
    return np.clip(0.5 - distance / width, 0, 1)


def blend(dst, rgb, alpha):
    """Composite a colour (a tuple or an HxWx3 field) over a float RGBA array, in place."""
    alpha = np.clip(alpha, 0, 1)
    keep = dst[..., 3] * (1 - alpha)
    out = alpha + keep
    safe = np.maximum(out, 1e-6)[..., None]
    dst[..., :3] = (np.asarray(rgb, np.float32) * alpha[..., None] + dst[..., :3] * keep[..., None]) / safe
    dst[..., 3] = out
    return dst


def segment_distance(x, y, a, b):
    ax, ay = a
    dx, dy = b[0] - ax, b[1] - ay
    s = np.clip(((x - ax) * dx + (y - ay) * dy) / max(dx * dx + dy * dy, 1e-9), 0, 1)
    return np.hypot(x - (ax + s * dx), y - (ay + s * dy)), s


def vignette(image, inner=0.74, outer=0.97):
    """Fade a frame-filling effect towards a circle so it never shows the square edge."""
    _, _, r, _ = polar()
    arr = np.asarray(image).astype(np.float32) / 255
    arr[..., 3] *= np.clip((outer - r) / (outer - inner), 0, 1)
    return to_image(arr)


def hsv(h, s, v):
    i = int(h * 6) % 6
    fr = h * 6 - int(h * 6)
    p, q, w = v * (1 - s), v * (1 - fr * s), v * (1 - (1 - fr) * s)
    return [(v, w, p), (q, v, p), (p, v, w), (p, q, v), (w, p, v), (v, p, q)][i]


class Canvas:
    """A 3x supersampled drawing layer in centred units. PIL replaces pixels when it draws on RGBA,
    so colour (premultiplied over black) and coverage live on two RGB images drawn in blend mode,
    which composites every translucent shape properly; done() box-filters both back down."""

    S = 3

    def __init__(self):
        size = (FRAME * self.S, FRAME * self.S)
        self.color = Image.new("RGB", size, (0, 0, 0))
        self.cover = Image.new("RGB", size, (0, 0, 0))
        self.draws = (ImageDraw.Draw(self.color, "RGBA"), ImageDraw.Draw(self.cover, "RGBA"))
        self.half = FRAME * self.S * 0.5

    def p(self, x, y):
        return float(self.half * (1 + x)), float(self.half * (1 - y))

    def w(self, pixels):
        return max(1, round(pixels * self.S * PIXEL_SCALE))

    def _pairs(self, fill, outline=None):
        def mask(c):
            return None if c is None else (255, 255, 255, c[3] if len(c) > 3 else 255)

        return ((self.draws[0], fill, outline), (self.draws[1], mask(fill), mask(outline)))

    def ellipse(self, x, y, rx, ry, fill=None, outline=None, width=1.0):
        cx, cy = self.p(x, y)
        box = [cx - rx * self.half, cy - ry * self.half, cx + rx * self.half, cy + ry * self.half]
        for draw, f, o in self._pairs(fill, outline):
            draw.ellipse(box, fill=f, outline=o, width=self.w(width))

    def circle(self, x, y, radius, fill=None, outline=None, width=1.0):
        self.ellipse(x, y, radius, radius, fill, outline, width)

    def arc(self, x, y, radius, start, end, fill, width=1.0):
        cx, cy = self.p(x, y)
        rr = radius * self.half
        for draw, f, _ in self._pairs(fill):
            draw.arc([cx - rr, cy - rr, cx + rr, cy + rr], start, end, fill=f, width=self.w(width))

    def line(self, points, fill, width=1.0):
        pts = [self.p(*q) for q in points]
        for draw, f, _ in self._pairs(fill):
            draw.line(pts, fill=f, width=self.w(width), joint="curve")

    def polygon(self, points, fill):
        pts = [self.p(*q) for q in points]
        for draw, f, _ in self._pairs(fill):
            draw.polygon(pts, fill=f)

    def done(self):
        color = np.asarray(self.color.resize((FRAME, FRAME), BOX)).astype(np.float32) / 255
        cover = np.asarray(self.cover.resize((FRAME, FRAME), BOX)).astype(np.float32)[..., 0] / 255
        rgba = np.zeros((FRAME, FRAME, 4), np.float32)
        rgba[..., :3] = color / np.maximum(cover, 1e-4)[..., None]
        rgba[..., 3] = cover
        return to_image(rgba)


def sparkle(canvas, x, y, size, fill):
    k = size * 0.18
    canvas.polygon([(x - size, y), (x - k, y + k), (x, y + size), (x + k, y + k), (x + size, y), (x + k, y - k), (x, y - size), (x - k, y - k)], fill)


def stack(*layers):
    image = layers[0]
    for layer in layers[1:]:
        image = over(image, layer)
    return image


def water():
    """A glass globe of sloshing water with caustics and rising bubbles, ringed by orbiting spray."""
    x, y, r, _ = polar()
    noise = PeriodicNoise(71, (8, 8, 8))
    rng = np.random.default_rng(72)
    bubbles = [(rng.uniform(-0.36, 0.36), rng.random(), rng.uniform(0.016, 0.032)) for _ in range(8)]
    R = 0.6

    def level(at, t):
        return 0.08 + 0.09 * np.sin(TAU * (at * 0.6 + t)) + 0.035 * np.sin(TAU * (at * 1.4 - 2 * t))

    tint = to_image(ramp(np.clip((r - R * 0.72) / (R * 0.28), 0, 1) ** 2 * edge(r - R), [(0, (0.6, 0.85, 1.0, 0.0)), (1, (0.66, 0.88, 1.0, 0.3))]))
    shell = to_image(ramp(np.exp(-((r - R) ** 2) / 0.0007), [(0, (0.7, 0.9, 1.0, 0.0)), (1, (0.88, 0.97, 1.0, 0.92))]))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        below = level(x, t) - y
        depth = np.clip(below / (R + 0.12), 0, 1)
        body = ramp(depth, [(0, (0.72, 0.95, 1.0, 0.96)), (0.06, (0.3, 0.76, 0.98, 0.94)), (0.45, (0.08, 0.42, 0.86, 0.94)), (1, (0.03, 0.15, 0.46, 0.97))])
        n = noise.fbm(x * 2.4 + t * 8, y * 2.4, t * 8, octaves=3)
        caustic = np.clip(1 - np.abs(n - 0.5) * 12, 0, 1) ** 2 * (1 - depth) ** 1.5
        body[..., :3] = np.clip(body[..., :3] + caustic[..., None] * 0.5, 0, 1)
        body[..., 3] *= edge(-below) * edge(r - R)
        blend(body, (0.92, 0.99, 1.0), np.exp(-(below ** 2) / 0.0005) * edge(r - R + 0.015) * 0.9)
        back, front, inner, shine = Canvas(), Canvas(), Canvas(), Canvas()
        for k in range(10):
            a = TAU * (t / 5 + k / 10)
            behind = math.sin(a) > 0
            canvas = back if behind else front
            alpha = 150 if behind else 245
            for lag, shrink in ((0.0, 1.0), (0.09, 0.62), (0.18, 0.38)):
                b = a - lag
                canvas.circle(math.cos(b) * 0.82, -0.06 + math.sin(b) * 0.2, (0.034 - 0.01 * math.sin(b)) * shrink, fill=(120, 205, 255, int(alpha * (0.45 + 0.55 * shrink))))
            canvas.circle(math.cos(a) * 0.82 - 0.01, -0.06 + math.sin(a) * 0.2 + 0.012, 0.009, fill=(245, 253, 255, alpha))
        for bx, phase, size in bubbles:
            p = (t + phase) % 1.0
            cx = bx + 0.025 * math.sin(TAU * (p * 2 + phase))
            cy = -R * 0.85 + p * (R * 0.85 + 0.12)
            if cy > float(level(cx, t)) - size or math.hypot(cx, cy) > R - size - 0.02:
                continue
            fade = min(1.0, p / 0.15)
            inner.circle(cx, cy, size, outline=(215, 245, 255, int(210 * fade)), width=1.0)
            inner.circle(cx - size * 0.35, cy + size * 0.35, size * 0.3, fill=(240, 252, 255, int(220 * fade)))
        shine.arc(0, 0, R * 0.84, 200, 245, (255, 255, 255, 190), 2.6)
        shine.circle(-0.33, 0.36, 0.028, fill=(255, 255, 255, 210))
        image = stack(glow(back.done(), 2, 0.6), tint, to_image(body), inner.done(), shell, shine.done(), glow(front.done(), 2, 0.6))
        frames.append(glow(image, 3, 0.4))
    return frames


def wind():
    """A whirlwind: tapered air ribbons wrapping a faint spinning funnel, with tumbling leaves."""
    x, y, r, _ = polar()
    air = PeriodicNoise(82, (8, 8, 8))
    rng = np.random.default_rng(81)
    ribbons = [(-0.66 + k * 0.165 + rng.uniform(-0.025, 0.025), rng.random(), int(rng.integers(1, 3)), rng.uniform(1.6, 2.6)) for k in range(9)]
    leaves = [(rng.random(), rng.uniform(-0.5, 0.45), int(rng.integers(1, 3)), rng.uniform(0, TAU)) for _ in range(5)]
    specks = [(rng.random(), rng.uniform(-0.7, 0.65), int(rng.integers(1, 4))) for _ in range(18)]

    def spot(a, h, shrink=1.0):
        radius = (0.2 + 0.44 * (h + 0.8) / 1.6) * shrink
        return math.cos(a) * radius, h + math.sin(a) * radius * 0.24, math.sin(a)

    s = x / (0.2 + 0.44 * np.clip((y + 0.8) / 1.6, 0, 1))
    shell = edge(np.abs(s) - 1, 0.3) * np.clip((y + 0.9) / 0.25, 0, 1) * np.clip((0.82 - y) / 0.2, 0, 1)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        n = air.fbm(s * 1.2 + t * 8, y * 2.0, t * 8, octaves=3)
        haze = shell * (0.35 + 0.65 * np.clip(np.abs(s), 0, 1) ** 2) * np.clip(0.4 + (n - 0.5) * 1.6, 0, 1)
        far, near = np.zeros_like(x), np.zeros_like(x)
        # ribbons are coverage fields (max over segments), so the taper never beads at the joints
        for h, phase, turns, sweep in ribbons:
            head = TAU * (t * turns + phase)
            steps = 20
            pts, widths, alphas, depths = [], [], [], []
            for i in range(steps + 1):
                fade = 1 - i / steps
                px_, py_, depth = spot(head - sweep * i / steps, h, 1 - 0.16 * i / steps)
                pts.append((px_, py_))
                widths.append(0.004 + 0.024 * fade)
                alphas.append(fade ** 0.8)
                depths.append(depth)
            for i in range(steps):
                d, sg = segment_distance(x, y, pts[i], pts[i + 1])
                cover = edge(d - (widths[i] + (widths[i + 1] - widths[i]) * sg)) * (alphas[i] + (alphas[i + 1] - alphas[i]) * sg)
                if depths[i] + depths[i + 1] > 0:
                    far = np.maximum(far, cover * 0.45)
                else:
                    near = np.maximum(near, cover)
        back_air = blend(blend(np.zeros((FRAME, FRAME, 4), np.float32), (0.85, 0.97, 0.94), haze * 0.35), (0.8, 0.95, 0.9), far)
        front_air = blend(np.zeros((FRAME, FRAME, 4), np.float32), (0.89, 0.98, 0.96), near)
        back, front = Canvas(), Canvas()
        for phase, h, turns, spin in leaves:
            a = TAU * (t * turns + phase)
            x_, y_, depth = spot(a, h, 1.08)
            y_ += 0.05 * math.sin(TAU * (t + phase))
            ang = spin + TAU * t * 2
            flip = 0.2 + 0.8 * abs(math.cos(TAU * (t * 2 + phase)))
            size = 0.075 * (0.9 - 0.18 * depth)
            ca, sa = math.cos(ang), math.sin(ang)
            tip, tail = (x_ + ca * size, y_ + sa * size), (x_ - ca * size * 0.9, y_ - sa * size * 0.9)
            side1 = (x_ - sa * size * 0.42 * flip, y_ + ca * size * 0.42 * flip)
            side2 = (x_ + sa * size * 0.42 * flip, y_ - ca * size * 0.42 * flip)
            shade = 0.7 + 0.3 * (1 - depth) / 2
            canvas = back if depth > 0 else front
            canvas.polygon([tip, side1, tail, side2], (int(110 * shade), int(215 * shade), int(105 * shade), 240))
            canvas.line([tip, tail], fill=(int(70 * shade), int(150 * shade), int(70 * shade), 255), width=0.8)
        for phase, h, turns in specks:
            x_, y_, depth = spot(TAU * (t * turns + phase), h, 0.9)
            (back if depth > 0 else front).circle(x_, y_, 0.008, fill=(235, 255, 248, 150 if depth > 0 else 230))
        frames.append(stack(glow(to_image(back_air), 2, 0.5), back.done(), glow(to_image(front_air), 2.5, 0.7), glow(front.done(), 2, 0.5)))
    return frames


def radiance():
    """Holy light: counter-rotating god rays from a blazing core, a halo ring and rising motes."""
    x, y, r, theta = polar()
    rng = np.random.default_rng(91)
    motes = [(rng.uniform(-0.6, 0.6), rng.random(), rng.uniform(0.03, 0.055)) for _ in range(14)]
    fall = np.clip(1 - r / 0.92, 0, 1)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        rays = (0.5 + 0.5 * np.cos(12 * theta - TAU * t)) ** 28 * fall ** 1.3
        rays2 = (0.5 + 0.5 * np.cos(8 * theta + TAU * t)) ** 40 * np.clip(1 - r / 0.68, 0, 1) ** 1.2 * 0.8
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 2)
        core = np.exp(-(r ** 2) / (0.018 + 0.008 * pulse))
        halo = np.exp(-((r - 0.36 - 0.015 * pulse) ** 2) / 0.0006) * (0.7 + 0.3 * pulse)
        light = np.clip(np.maximum(rays, rays2) + core + halo, 0, 1)
        image = to_image(ramp(light, [(0, (1.0, 0.78, 0.3, 0.0)), (0.25, (1.0, 0.84, 0.42, 0.55)), (0.6, (1.0, 0.93, 0.66, 0.92)), (1, (1.0, 1.0, 0.94, 1.0))]))
        sparks = Canvas()
        for mx, phase, size in motes:
            p = (t + phase) % 1.0
            a = math.sin(math.pi * p)
            sparkle(sparks, mx + 0.03 * math.sin(TAU * (p + phase)), -0.72 + p * 1.44, size * (0.4 + 0.6 * a), (255, 246, 205, int(255 * a)))
        frames.append(glow(over(image, sparks.done()), 6, 0.55))
    return frames


def shadow():
    """A hooded wraith of churning smoke with a violet rim light and burning eyes."""
    x, y, r, _ = polar()
    noise = PeriodicNoise(101, (8, 8, 8))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        sway = 0.04 * math.sin(TAU * t)
        sx = x - sway * np.clip((0.3 - y) / 1.1, 0, 1)
        n = noise.fbm(sx * 1.8, y * 1.8 - t * 8, t * 8, octaves=4)
        head = np.hypot(sx, (y - 0.24) * 0.95) - 0.3
        width = 0.3 + np.clip(0.24 - y, 0, None) * 0.34
        body = np.maximum(np.maximum(np.abs(sx) - width, -0.95 - y), y - 0.24)
        mass = np.maximum(np.clip(0.5 - head / 0.14, 0, 1), np.clip(0.5 - body / 0.18, 0, 1))
        # a tattered hem: the robe frays into tendrils along a moving ragged line
        hemline = -0.6 + (noise.fbm(sx * 2.6 + 11, 5.0, t * 8, octaves=3) - 0.5) * 0.7
        hem = np.clip((y - hemline) / 0.3 + 0.5, 0, 1)
        density = np.clip(mass * (0.75 + (n - 0.5) * 1.6) * hem * 1.25, 0, 1)
        rim = np.clip(1 - np.abs(density - 0.28) * 5, 0, 1) * (density < 0.55)
        image = to_image(ramp(density, [(0, (0.06, 0.0, 0.12, 0.0)), (0.35, (0.08, 0.02, 0.15, 0.7)), (1, (0.015, 0.0, 0.03, 0.97))]))
        image = over(image, to_image(ramp(rim, [(0, (0.55, 0.22, 0.95, 0.0)), (1, (0.72, 0.4, 1.0, 0.8))])))
        hood = np.exp(-(x ** 2 + (y - 0.2) ** 2) / 0.02) * (0.4 + 0.15 * math.sin(TAU * t * 2))
        image = over(image, to_image(ramp(hood, [(0, (0.5, 0.15, 0.85, 0.0)), (1, (0.65, 0.25, 1.0, 0.6))])))
        eyes = Canvas()
        drift = sway * 0.09
        for side in (-1, 1):
            ex, ey = side * 0.105 + drift, 0.2
            eyes.polygon([(ex - side * 0.06, ey), (ex + side * 0.055, ey + 0.03), (ex + side * 0.04, ey - 0.012), (ex - side * 0.05, ey - 0.018)], (235, 150, 255, 255))
        frames.append(over(image, glow(glow(eyes.done(), 3, 1.6), 1, 0.8)))
    return frames


def arcane():
    """A spinning magic circle: rune band lit by a chasing glow, an octagram and a pulsing core."""
    x, y, r, _ = polar()
    rng = np.random.default_rng(111)
    lattice = [(-1, -1.4), (0, -1.4), (1, -1.4), (-1, 0), (0, 0), (1, 0), (-1, 1.4), (0, 1.4), (1, 1.4)]
    glyphs = [[lattice[i] for i in rng.choice(9, int(rng.integers(3, 5)), replace=False)] for _ in range(12)]
    motes = [(rng.random(), rng.uniform(0.3, 0.82), int(rng.choice([-2, -1, 1, 2]))) for _ in range(10)]
    disc = to_image(ramp(edge(r - 0.86) * (0.55 + 0.45 * np.clip(r / 0.86, 0, 1)), [(0, (0.1, 0.08, 0.35, 0.0)), (1, (0.16, 0.1, 0.45, 0.42))]))
    cyan, pink = (110, 225, 255), (255, 125, 235)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        c = Canvas()
        c.circle(0, 0, 0.86, outline=cyan + (235,), width=1.8)
        c.circle(0, 0, 0.74, outline=cyan + (200,), width=1.0)
        c.circle(0, 0, 0.58, outline=cyan + (220,), width=1.4)
        for k in range(32):  # a dotted ring creeping one dot per loop
            a = TAU * (k + t) / 32
            c.circle(math.cos(a) * 0.8, math.sin(a) * 0.8, 0.012, fill=(190, 240, 255, 220))
        for k, glyph in enumerate(glyphs):
            a = TAU * k / 12 + TAU / 24
            lit = 0.4 + 0.6 * max(0.0, math.cos(TAU * t - a)) ** 6
            ca, sa = math.cos(a), math.sin(a)
            cx, cy = ca * 0.66, sa * 0.66
            # gx runs along the ring, gy points outward
            pts = [(cx + (-sa * gx + ca * gy) * 0.03, cy + (ca * gx + sa * gy) * 0.03) for gx, gy in glyph]
            c.line(pts, fill=(int(170 + 85 * lit), int(225 + 30 * lit), 255, int(255 * lit)), width=1.4)
        spin = TAU * t / 8
        verts = [(math.cos(spin + TAU * i / 8) * 0.56, math.sin(spin + TAU * i / 8) * 0.56) for i in range(8)]
        c.line([verts[(i * 3) % 8] for i in range(9)], fill=pink + (235,), width=1.6)
        for off in (0, TAU / 8):
            c.line([(math.cos(off - spin + TAU * i / 4) * 0.28, math.sin(off - spin + TAU * i / 4) * 0.28) for i in range(5)], fill=cyan + (220,), width=1.2)
        c.circle(0, 0, 0.2, outline=pink + (200,), width=1.0)
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 2)
        c.circle(0, 0, 0.07 + 0.02 * pulse, fill=(255, 225, 250, 240))
        for phase, radius, turns in motes:
            a = TAU * (t * turns + phase)
            c.circle(math.cos(a) * radius, math.sin(a) * radius, 0.014, fill=(255, 200, 250, 220))
        frames.append(over(disc, glow(glow(c.done(), 5, 1.0), 1.5, 0.5)))
    return frames


def nature():
    """A breathing rosette of veined leaves around a glowing bud, shedding spores."""
    x, y, r, _ = polar()
    rng = np.random.default_rng(121)
    spores = [(rng.uniform(-0.55, 0.55), rng.random(), rng.uniform(0.012, 0.022)) for _ in range(14)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        rgba = np.zeros((FRAME, FRAME, 4), np.float32)
        for ring, (count, length, width, offset, dark) in enumerate(((8, 0.8, 0.19, 0.0, 0.72), (8, 0.56, 0.15, TAU / 16, 1.0))):
            for k in range(count):
                a = offset + TAU * k / count + 0.05 * math.sin(TAU * t + k * 0.8 + ring)
                reach = length * (1 + 0.04 * math.sin(TAU * t + ring * 1.7 + k * 0.4))
                ca, sa = math.cos(a), math.sin(a)
                along = x * ca + y * sa
                across = -x * sa + y * ca
                s = np.clip(along / reach, 0, 1)
                half = width * np.clip(np.sin(np.pi * s), 0, 1) ** 0.7
                cover = edge(np.abs(across) - half) * (along > 0) * (along < reach)
                side = np.clip(across / np.maximum(half, 1e-3), -1, 1)
                tone = (0.62 + 0.22 * side + 0.25 * s) * dark
                color = np.stack([0.2 * tone, 0.64 * tone, 0.24 * tone], -1)
                rib = np.exp(-(across ** 2) / 0.00009) * (s < 0.9)
                veins = (0.5 + 0.5 * np.cos((along - np.abs(across) * 1.4) * 55)) ** 8 * np.clip(np.abs(side), 0.2, 1)
                color += rib[..., None] * np.array([0.42, 0.38, 0.22]) + veins[..., None] * np.array([0.1, 0.16, 0.06]) * dark
                margin = edge(np.abs(np.abs(across) - half) - 0.007) * cover
                color = color * (1 - margin[..., None] * 0.6) + np.array([0.55, 0.92, 0.45]) * margin[..., None] * 0.6
                blend(rgba, np.clip(color, 0, 1), cover)
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 2)
        blend(rgba, (0.92, 1.0, 0.6), np.clip(np.exp(-(r ** 2) / (0.02 + 0.008 * pulse)) * 1.3, 0, 1))
        image = glow(to_image(rgba), 3, 0.35)
        motes = Canvas()
        for sx, phase, size in spores:
            p = (t + phase) % 1.0
            motes.circle(sx + 0.04 * math.sin(TAU * (p * 2 + phase)), -0.55 + p * 1.3, size, fill=(225, 255, 150, int(230 * math.sin(math.pi * p))))
        frames.append(over(image, glow(motes.done(), 2.5, 1.0)))
    return frames


def blood():
    """A crimson heart-orb beating lub-dub twice a loop, veins flaring, drops swelling and falling."""
    x, y, r, _ = polar()
    vein_n = PeriodicNoise(131, (8, 8, 8))
    rng = np.random.default_rng(132)
    drips = [(rng.uniform(-0.24, 0.24), rng.random(), int(rng.integers(1, 3))) for _ in range(5)]
    v = vein_n.fbm(x * 2.6 + 2, y * 2.6 + 2, 0.0, octaves=4)
    vein = np.clip(1 - np.abs(v - 0.5) * 16, 0, 1)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        q = (t * 2) % 1.0
        beat = math.exp(-((q / 0.07) ** 2)) + math.exp(-(((q - 1) / 0.07) ** 2)) + 0.65 * math.exp(-(((q - 0.17) / 0.06) ** 2))
        R = 0.5 + 0.045 * beat
        nz = np.sqrt(np.clip(1 - (r / R) ** 2, 0, 1))
        lit = np.clip(((-x * 0.5 + y * 0.6) / R) * 0.55 + nz * 0.6, 0, 1)
        body = ramp(lit, [(0, (0.28, 0.0, 0.03, 1.0)), (0.5, (0.6, 0.03, 0.07, 1.0)), (0.85, (0.85, 0.1, 0.12, 1.0)), (1, (1.0, 0.4, 0.38, 1.0))])
        inside = edge(r - R)
        body[..., 3] *= inside
        blend(body, (1.0, 0.22 + 0.2 * min(beat, 1.0), 0.2), vein * inside * (0.25 + 0.55 * min(beat, 1.0)) * nz)
        aura = np.exp(-((r - R) ** 2) / 0.006) * (0.3 + 0.7 * min(beat, 1.0))
        image = over(to_image(ramp(aura, [(0, (0.9, 0.05, 0.1, 0.0)), (1, (1.0, 0.2, 0.25, 0.75))])), to_image(body))
        c = Canvas()
        c.ellipse(-0.17, 0.2, 0.09, 0.055, fill=(255, 210, 210, 110))
        for dx, phase, speed in drips:
            p = (t * speed + phase) % 1.0
            top = -math.sqrt(max(R * R - dx * dx, 0.0))
            if p < 0.35:  # the drop swells on the underside
                g = p / 0.35
                c.circle(dx, top - 0.02 * g, 0.012 + 0.022 * g, fill=(150, 6, 18, 255))
            else:  # then lets go, stretches and fades
                g = (p - 0.35) / 0.65
                cy = top - 0.04 - g * g * 0.45
                c.circle(dx, cy, 0.03 * (1 - 0.3 * g), fill=(150, 6, 18, int(255 * (1 - g) ** 0.5)))
                c.line([(dx, cy + 0.02), (dx, cy + 0.02 + 0.08 * g)], fill=(130, 4, 16, int(200 * (1 - g))), width=2.2)
        frames.append(glow(over(image, c.done()), 4, 0.5))
    return frames


def plasma():
    """A plasma globe: wandering filaments from a hot electrode to the glass, crackling as they go."""
    x, y, r, _ = polar()
    wander = PeriodicNoise(141, (8, 8, 8))
    rng = np.random.default_rng(142)
    roots = [(TAU * k / 7 + rng.uniform(-0.25, 0.25), rng.random(), rng.uniform(0.25, 0.5)) for k in range(7)]
    R = 0.74
    tint = to_image(ramp(edge(r - R) * 0.6, [(0, (0.4, 0.1, 0.5, 0.0)), (1, (0.5, 0.15, 0.6, 0.45))]))
    glass = np.exp(-((r - R) ** 2) / 0.0006) + np.clip((r - R * 0.8) / (R * 0.2), 0, 1) ** 3 * edge(r - R) * 0.3
    shell = to_image(ramp(np.clip(glass, 0, 1), [(0, (0.9, 0.6, 1.0, 0.0)), (1, (1.0, 0.86, 1.0, 0.85))]))
    steps = np.linspace(0, 1, 25)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        jitter = np.random.default_rng(1400 + f)
        c = Canvas()
        for k, (base, phase, reach) in enumerate(roots):
            a = base + reach * math.sin(TAU * (t + phase))
            ex, ey = math.cos(a) * R * 0.97, math.sin(a) * R * 0.97
            nx, ny = -math.sin(a), math.cos(a)
            off = (wander.fbm(steps * 3.0, np.full_like(steps, k * 1.37), t * 8, octaves=3) - 0.5) * 0.34 * np.sin(np.pi * steps)
            off = off + jitter.normal(0, 0.006, steps.shape) * np.sin(np.pi * steps)
            pts = [(ex * s + nx * o, ey * s + ny * o) for s, o in zip(steps, off)]
            c.line(pts, fill=(255, 120, 230, 200), width=3.0)
            c.line(pts, fill=(255, 235, 255, 255), width=1.0)
            c.circle(ex, ey, 0.04, fill=(255, 190, 250, 210))
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 3)
        c.circle(0, 0, 0.11 + 0.015 * pulse, fill=(255, 225, 255, 255))
        frames.append(stack(tint, glow(glow(c.done(), 4, 1.2), 1.5, 0.8), shell))
    return frames


def prism():
    """A turning cut gem catching a white beam and fanning it out into a rainbow."""
    x, y, r, _ = polar()
    rng = np.random.default_rng(151)
    glints = [(rng.uniform(-0.75, 0.75), rng.uniform(-0.65, 0.65), rng.random()) for _ in range(7)]
    spectrum = [(1.0, 0.3, 0.32), (1.0, 0.62, 0.2), (1.0, 0.95, 0.35), (0.4, 1.0, 0.5), (0.35, 0.68, 1.0), (0.68, 0.45, 1.0)]
    ct, st = math.cos(0.38), math.sin(0.38)
    light = np.array([-0.45, 0.65, 0.62])
    light /= np.linalg.norm(light)

    def view(p):
        return np.array([p[0], p[1] * ct - p[2] * st, p[1] * st + p[2] * ct])

    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        beams = np.zeros((FRAME, FRAME, 4), np.float32)
        d, _ = segment_distance(x, y, (-1.05, 0.22), (-0.2, 0.05))
        blend(beams, (1.0, 1.0, 1.0), np.exp(-(d ** 2) / 0.0005) * 0.8)
        sway = 0.035 * math.sin(TAU * t)
        for i, col in enumerate(spectrum):
            ang = 0.12 - i * 0.1 + sway
            d, s = segment_distance(x, y, (0.15, -0.02), (0.15 + math.cos(ang) * 0.95, -0.02 + math.sin(ang) * 0.95))
            blend(beams, col, np.exp(-(d ** 2) / (0.0005 + 0.0028 * s)) * (0.9 - 0.45 * s))
        blend(beams, (0.85, 0.95, 1.0), np.exp(-(x ** 2 + (y - 0.02) ** 2) / 0.08) * (0.4 + 0.1 * math.sin(TAU * t * 2)))
        image = vignette(glow(to_image(beams), 3, 0.6), 0.7, 0.98)
        # a hexagonal bipyramid turning one face per loop; facet colour follows the facet's
        # direction, not its identity, so the loop is seamless
        spin = TAU * t / 6
        ring = [(0.47 * math.cos(spin + TAU * i / 6), 0.0, 0.47 * math.sin(spin + TAU * i / 6)) for i in range(6)]
        faces = []
        for i in range(6):
            a, b = ring[i], ring[(i + 1) % 6]
            for tip, crown in (((0.0, 0.34, 0.0), True), ((0.0, -0.58, 0.0), False)):
                v = [view(q) for q in (tip, a, b)]
                normal = np.cross(v[1] - v[0], v[2] - v[0])
                centre = (v[0] + v[1] + v[2]) / 3
                if normal @ centre < 0:
                    normal = -normal
                normal /= np.linalg.norm(normal)
                if normal[2] > 0:
                    faces.append((centre[2], v, normal, crown))
        faces.sort(key=lambda item: item[0])
        gem = Canvas()
        for _, v, normal, crown in faces:
            lam = max(0.0, float(normal @ light))
            hue = (math.atan2(normal[0], normal[2]) / TAU + (0.1 if crown else 0.55)) % 1.0
            spec = lam ** 10
            rgb = [ch + (1 - ch) * spec for ch in hsv(hue, 0.62, 0.48 + 0.52 * lam)]
            pts = [(q[0], q[1] + 0.04) for q in v]
            gem.polygon(pts, (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255), 230))
            gem.line(pts + [pts[0]], fill=(255, 255, 255, 170), width=0.9)
        sparks = Canvas()
        for gx, gy, phase in glints:
            a = max(0.0, math.sin(TAU * (t + phase))) ** 6
            if a > 0.02:
                sparkle(sparks, gx, gy, 0.02 + 0.05 * a, (255, 255, 255, int(255 * a)))
        frames.append(stack(image, glow(gem.done(), 3, 0.5), glow(sparks.done(), 2, 0.8)))
    return frames


def magma():
    """A cracked basalt ball bleeding lava through its seams, spitting molten blobs and embers."""
    x, y, r, _ = polar()
    rock_n = PeriodicNoise(151, (8, 8, 8))
    crack_n = PeriodicNoise(152, (8, 8, 8))
    flow_n = PeriodicNoise(153, (8, 8, 8))
    rng = np.random.default_rng(154)
    blobs = [(rng.uniform(-0.3, 0.3), rng.random(), rng.uniform(-0.3, 0.3), rng.uniform(0.028, 0.045)) for _ in range(6)]
    embers = [(rng.uniform(-0.6, 0.6), rng.random(), int(rng.integers(1, 3))) for _ in range(16)]
    R = 0.55
    inside = edge(r - R)
    nz = np.sqrt(np.clip(1 - (r / R) ** 2, 0, 1))
    lit = np.clip(((-x * 0.5 + y * 0.6) / R) * 0.5 + nz * 0.6, 0.12, 1)
    bumps = rock_n.fbm(x * 4 + 1, y * 4 + 1, 0.0, octaves=4)
    seams = crack_n.fbm(x * 2.2 + 3, y * 2.2 + 3, 0.0, octaves=3)
    crack = np.clip(1 - np.abs(seams - 0.5) * 20, 0, 1) * edge(r - R + 0.015)
    rock = ramp(np.clip(bumps * lit * 1.3, 0, 1), [(0, (0.05, 0.035, 0.03, 1)), (0.45, (0.15, 0.09, 0.07, 1)), (1, (0.36, 0.24, 0.17, 1))])
    rock[..., 3] *= inside
    rock_image = to_image(rock)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        flow = flow_n.fbm(x * 3 + t * 8, y * 3 - t * 8, t * 8, octaves=2)
        heat = np.clip(crack * (0.45 + 0.75 * flow) * (0.85 + 0.15 * math.sin(TAU * t * 2)), 0, 1)
        lava = to_image(ramp(heat, [(0, (1.0, 0.25, 0.0, 0.0)), (0.3, (1.0, 0.32, 0.02, 0.85)), (0.65, (1.0, 0.6, 0.1, 1.0)), (1, (1.0, 0.93, 0.6, 1.0))]))
        aura = np.exp(-((r - R) ** 2) / 0.009) * (0.55 + 0.12 * math.sin(TAU * t * 2))
        image = stack(to_image(ramp(aura, [(0, (1.0, 0.3, 0.0, 0.0)), (1, (1.0, 0.45, 0.08, 0.7))])), rock_image, glow(lava, 3, 1.1))
        c = Canvas()
        for bx, phase, vx, size in blobs:
            p = (t + phase) % 1.0
            px_, py_ = bx + vx * p, math.sqrt(max(R * R - bx * bx, 0.0)) + 1.15 * p - 1.5 * p * p
            fade = min(1.0, p / 0.06) * (1 - p) ** 0.4
            s = size * (1 - 0.4 * p)
            c.circle(px_, py_, s * 1.5, fill=(255, 90, 10, int(120 * fade)))
            c.circle(px_, py_, s, fill=(255, 160, 40, int(255 * fade)))
            c.circle(px_, py_, s * 0.5, fill=(255, 235, 150, int(255 * fade)))
        for ex, phase, speed in embers:
            p = (t * speed + phase) % 1.0
            c.circle(ex + 0.05 * math.sin(TAU * (p * 2 + phase)), -0.2 + p, 0.009, fill=(255, 190, 90, int(240 * math.sin(math.pi * p))))
        frames.append(over(image, glow(c.done(), 2.5, 1.0)))
    return frames


def blizzard():
    """Driving snow in three depth layers across a slowly turning frost emblem."""
    x, y, r, _ = polar()
    fog_n = PeriodicNoise(161, (8, 8, 8))
    rng = np.random.default_rng(162)
    flakes = []
    for depth, (count, size, speed, alpha) in enumerate(((24, 0.014, 1, 150), (14, 0.026, 2, 210), (6, 0.045, 3, 250))):
        for _ in range(count):
            flakes.append((rng.random(), rng.random(), size * rng.uniform(0.8, 1.25), speed, rng.uniform(0, TAU), alpha, depth))
    streaks = [(rng.random(), rng.random()) for _ in range(9)]
    cold = to_image(ramp(np.exp(-(r ** 2) / 0.14), [(0, (0.55, 0.78, 1.0, 0.0)), (1, (0.66, 0.86, 1.0, 0.5))]))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        fog = fog_n.fbm(x * 1.4 - t * 8, y * 1.4 + t * 8, t * 8, octaves=3)
        image = over(cold, to_image(ramp(np.clip((fog - 0.42) * 1.6, 0, 1), [(0, (0.86, 0.94, 1.0, 0.0)), (1, (0.93, 0.97, 1.0, 0.26))])))
        emblem = Canvas()
        spin = TAU * t / 6
        for k in range(6):
            a = spin + TAU * k / 6
            ca, sa = math.cos(a), math.sin(a)
            emblem.line([(0, 0), (ca * 0.5, sa * 0.5)], fill=(200, 235, 255, 200), width=3.0)
            for along, reach in ((0.22, 0.13), (0.36, 0.1)):
                for turn in (0.75, -0.75):
                    emblem.line([(ca * along, sa * along), (ca * along + math.cos(a + turn) * reach, sa * along + math.sin(a + turn) * reach)], fill=(200, 235, 255, 190), width=2.0)
        emblem.circle(0, 0, 0.07, outline=(220, 245, 255, 220), width=2.0)
        c = Canvas()
        for sx, sy in streaks:
            px_, py_ = -1.1 + 2.2 * ((sx + t * 3) % 1.0), 1.1 - 2.2 * ((sy + t * 3) % 1.0)
            c.line([(px_ - 0.16, py_ + 0.16), (px_, py_)], fill=(215, 235, 255, 110), width=1.0)
        for sx, sy, size, speed, spin0, alpha, depth in flakes:
            px_ = -1.1 + 2.2 * ((sx + t * speed) % 1.0) + 0.03 * math.sin(TAU * t * 2 + spin0)
            py_ = 1.1 - 2.2 * ((sy + t * speed) % 1.0)
            ang = spin0 + TAU * t * (1 if depth % 2 else -1)
            for k in range(3):
                a = ang + k * math.pi / 3
                dx, dy = math.cos(a) * size, math.sin(a) * size
                c.line([(px_ - dx, py_ - dy), (px_ + dx, py_ + dy)], fill=(240, 250, 255, alpha), width=0.6 + 0.5 * depth)
                if depth == 2:  # the near flakes get little branches
                    for sign in (-1, 1):
                        bx, by = px_ + dx * 0.55 * sign, py_ + dy * 0.55 * sign
                        out = a if sign > 0 else a + math.pi
                        for turn in (0.6, -0.6):
                            c.line([(bx, by), (bx + math.cos(out + turn) * size * 0.35, by + math.sin(out + turn) * size * 0.35)], fill=(240, 250, 255, alpha), width=0.8)
            c.circle(px_, py_, size * 0.2, fill=(255, 255, 255, alpha))
        image = over(image, glow(emblem.done(), 4, 0.9))
        frames.append(vignette(over(image, glow(c.done(), 1.5, 0.6)), 0.6, 0.95))
    return frames


def solar():
    """A sun: granulated disk with limb darkening, a ragged streaming corona and looping prominences."""
    x, y, r, theta = polar()
    corona_n = PeriodicNoise(171, (8, 8, 8))
    gran_n = PeriodicNoise(172, (16, 16, 8))
    R = 0.44
    disk = edge(r - R)
    limb = 0.45 + 0.55 * np.sqrt(np.clip(1 - (r / R) ** 2, 0, 1)) ** 0.6
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        cn = corona_n.fbm(np.cos(theta) * 1.6 + 4, np.sin(theta) * 1.6 + 4, t * 8 + r * 1.5, octaves=4)
        reach = 0.06 + 0.17 * cn ** 1.5
        corona = np.exp(-np.maximum(r - R, 0) / reach) * (0.7 + 0.3 * (0.5 + 0.5 * np.cos(10 * theta + (cn - 0.5) * 6)) ** 3)
        g = gran_n.fbm(x * 9, y * 9, t * 8, octaves=2)
        sun = ramp(np.clip(limb * (0.82 + 0.3 * (g - 0.5)), 0, 1), [(0, (0.85, 0.25, 0.0, 1.0)), (0.45, (0.95, 0.42, 0.04, 1.0)), (0.75, (1.0, 0.7, 0.18, 1.0)), (1, (1.0, 0.96, 0.7, 1.0))])
        sun[..., 3] *= disk
        crown = ramp(np.clip(corona, 0, 1), [(0, (1.0, 0.45, 0.05, 0.0)), (0.35, (1.0, 0.55, 0.1, 0.55)), (1, (1.0, 0.82, 0.35, 0.95))])
        arcs = Canvas()
        for base, span, phase in ((0.65, 0.55, 0.0), (3.7, 0.45, 0.5)):
            lift = 0.1 + 0.06 * math.sin(TAU * (t + phase))
            pts = []
            for i in range(25):
                s = i / 24
                a = base + span * (s - 0.5)
                rr = R + lift * math.sin(math.pi * s)
                pts.append((math.cos(a) * rr, math.sin(a) * rr))
            arcs.line(pts, fill=(255, 120, 40, 230), width=3.2)
            arcs.line(pts, fill=(255, 210, 120, 255), width=1.2)
        image = stack(to_image(crown), to_image(sun), glow(arcs.done(), 2, 0.8))
        frames.append(vignette(glow(image, 6, 0.55), 0.74, 0.97))
    return frames


def cosmic():
    """A banded gas giant with a tilted ring and an orbiting moon against twinkling stars."""
    x, y, r, _ = polar()
    band_n = PeriodicNoise(181, (8, 8, 8))
    rng = np.random.default_rng(182)
    stars = [(rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.random(), rng.uniform(0.006, 0.014)) for _ in range(44)]
    stars = [s for s in stars if math.hypot(s[0], s[1]) < 0.9]
    R = 0.34
    tilt = -0.3
    xr = x * math.cos(tilt) + y * math.sin(tilt)
    yr = -x * math.sin(tilt) + y * math.cos(tilt)
    rho = np.hypot(xr, yr / 0.3)
    texture = 0.62 + 0.38 * np.sin(rho * 95) * np.sin(rho * 31 + 1)
    gap = 1 - np.exp(-((rho - 0.66) ** 2) / 0.0002) * 0.9
    ring_a = edge(0.5 - rho, 0.012) * edge(rho - 0.82, 0.012) * texture * gap * 0.85
    ring_rgb = ramp(np.clip((rho - 0.5) / 0.32, 0, 1), [(0, (1.0, 0.8, 0.55, 1)), (1, (0.92, 0.88, 0.75, 1))])[..., :3]
    far = to_image(blend(np.zeros((FRAME, FRAME, 4), np.float32), ring_rgb, ring_a * (yr > 0)))
    near = to_image(blend(np.zeros((FRAME, FRAME, 4), np.float32), ring_rgb, ring_a * (yr <= 0)))
    inside = edge(r - R)
    nz = np.sqrt(np.clip(1 - (r / R) ** 2, 0, 1))
    L = np.array([-0.55, 0.45, 0.7])
    L /= np.linalg.norm(L)
    lam = np.clip((x / R) * L[0] + (y / R) * L[1] + nz * L[2], 0, 1)
    lat = np.clip(yr / R, -1, 1)
    lon = np.arcsin(np.clip(xr / np.sqrt(np.clip(R * R - yr * yr, 1e-6, None)), -1, 1))
    atmo = to_image(ramp(np.exp(-((r - R) ** 2) / 0.0012), [(0, (0.5, 0.8, 1.0, 0.0)), (1, (0.65, 0.88, 1.0, 0.75))]))
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        sky = Canvas()
        for sx, sy, phase, size in stars:
            tw = 0.35 + 0.65 * max(0.0, math.sin(TAU * (t * 2 + phase))) ** 2
            sky.circle(sx, sy, size, fill=(225, 232, 255, int(255 * tw)))
        n = band_n.fbm(lon * 1.2 + t * 8, lat * 3, 0.0, octaves=3)
        planet = ramp(0.5 + 0.5 * np.sin(lat * 8 + (n - 0.5) * 3), [(0, (0.24, 0.18, 0.55, 1)), (0.5, (0.5, 0.42, 0.88, 1)), (1, (0.9, 0.82, 0.98, 1))])
        planet[..., :3] *= (0.16 + 0.84 * lam)[..., None]
        planet[..., 3] *= inside
        phi = TAU * t
        ox, oy = math.cos(phi) * 0.66, math.sin(phi) * 0.66 * 0.45
        mx, my = ox * math.cos(0.42) - oy * math.sin(0.42), ox * math.sin(0.42) + oy * math.cos(0.42)
        md = np.hypot(x - mx, y - my)
        mlam = np.clip(((x - mx) / 0.065) * L[0] + ((y - my) / 0.065) * L[1] + np.sqrt(np.clip(1 - (md / 0.065) ** 2, 0, 1)) * L[2], 0, 1)
        shade = 0.2 + 0.8 * mlam
        moon = to_image(blend(np.zeros((FRAME, FRAME, 4), np.float32), np.stack([0.85 * shade, 0.86 * shade, 0.92 * shade], -1), edge(md - 0.065)))
        if math.sin(phi) > 0:  # behind the planet
            image = stack(sky.done(), far, moon, atmo, to_image(planet), near)
        else:
            image = stack(sky.done(), far, atmo, to_image(planet), near, moon)
        frames.append(glow(image, 3, 0.35))
    return frames


def sand():
    """A sand devil: a spinning funnel of dust over a churning skirt, grains and pebbles in orbit."""
    x, y, r, _ = polar()
    noise = PeriodicNoise(191, (8, 8, 8))
    rng = np.random.default_rng(192)
    grains = [(rng.random(), rng.uniform(-0.8, 0.78), int(rng.integers(1, 3))) for _ in range(36)]
    pebbles = [(rng.random(), rng.uniform(-0.45, 0.55), rng.uniform(0.018, 0.03), int(rng.integers(1, 3))) for _ in range(5)]

    def width_at(h):
        return 0.1 + 0.52 * min(max((h + 0.86) / 1.72, 0.0), 1.0) ** 1.3

    w = 0.1 + 0.52 * np.clip((y + 0.86) / 1.72, 0, 1) ** 1.3
    s = x / w
    funnel = edge(np.abs(s) - 1, 0.35) * np.clip((0.9 - y) / 0.3, 0, 1) * edge(-0.86 - y, 0.12)
    wall = 0.7 + 0.3 * np.clip(np.abs(s), 0, 1) ** 2
    tone = np.clip(0.8 - 0.22 * s, 0.4, 1.05)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        n = noise.fbm(s * 1.3 + t * 8, y * 2.4 - t * 8, t * 8, octaves=4)
        dust = np.clip(funnel * wall * (0.5 + (n - 0.5) * 1.9), 0, 1)
        rgba = ramp(dust, [(0, (0.7, 0.55, 0.32, 0.0)), (0.35, (0.78, 0.62, 0.38, 0.6)), (1, (0.93, 0.8, 0.55, 0.95))])
        rgba[..., :3] = np.clip(rgba[..., :3] * tone[..., None], 0, 1)
        skirt_n = noise.fbm(x * 2 + t * 8, y * 2, t * 8 + 3, octaves=3)
        skirt = np.exp(-((x / 0.6) ** 2 + ((y + 0.8) / 0.16) ** 2)) * np.clip(0.6 + (skirt_n - 0.5) * 1.6, 0, 1)
        blend(rgba, (0.8, 0.66, 0.42), skirt * 0.8)
        back, front = Canvas(), Canvas()
        for phase, h, turns in grains:
            a = TAU * (t * turns + phase)
            depth = math.sin(a)
            shade = 0.6 + 0.4 * (1 - depth) / 2
            (back if depth > 0 else front).circle(math.cos(a) * width_at(h) * 1.08, h + depth * 0.045, 0.011, fill=(int(225 * shade), int(185 * shade), int(115 * shade), 255))
        for phase, h, size, turns in pebbles:
            a = TAU * (t * turns + phase)
            depth = math.sin(a)
            px_, py_ = math.cos(a) * width_at(h) * 1.3, h + depth * 0.06
            pts = [(px_ + math.cos(a * 2 + TAU * i / 5) * size * (1 if i % 2 else 0.75), py_ + math.sin(a * 2 + TAU * i / 5) * size * (1 if i % 2 else 0.75)) for i in range(5)]
            (back if depth > 0 else front).polygon(pts, (140, 105, 70, 255))
        frames.append(vignette(stack(back.done(), to_image(rgba), front.done()), 0.72, 0.97))
    return frames


def steam():
    """Steam: a glowing vent in dark rock jetting puffs that billow, swell and thin out."""
    x, y, r, _ = polar()
    noise = PeriodicNoise(201, (8, 8, 8))
    rng = np.random.default_rng(202)
    puffs = [(k / 6 + rng.uniform(-0.03, 0.03), rng.uniform(-0.14, 0.14)) for k in range(6)]
    vent = np.exp(-((x / 0.24) ** 2 + ((y + 0.76) / 0.05) ** 2))
    rock = edge(np.hypot(x / 0.4, (y + 0.8) / 0.12) - 1, 0.04)
    warm = np.clip(1 - (y + 0.75) / 0.6, 0, 1)
    jet = np.exp(-(x ** 2) / (0.006 + 0.04 * np.clip(y + 0.72, 0, 1))) * np.clip((y + 0.74) / 0.06, 0, 1) * np.clip(1 - (y + 0.72) / 0.4, 0, 1) * 0.55
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        dens = np.zeros_like(x)
        for phase, drift in puffs:
            p = (t + phase) % 1.0
            cx = drift * p + 0.05 * math.sin(TAU * (p + phase))
            cy = -0.66 + p * 1.36
            rad = 0.11 + 0.3 * p
            dens += np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (rad * rad)) * min(1.0, p / 0.3) * (1 - p) ** 1.1 * 0.85
        n = noise.fbm(x * 2.2 + 1, y * 2.2 - t * 8, t * 8, octaves=4)
        density = np.clip((dens * 1.25 + jet * 0.9) * (0.72 + (n - 0.5) * 1.1), 0, 1)
        # light from above: a pixel denser than the one a few rows over it is a lit top edge
        lift = np.clip((density - np.roll(density, 5, axis=0)) * 1.4, -0.22, 0.2)
        rgba = ramp(density, [(0, (0.86, 0.9, 0.95, 0.0)), (0.3, (0.88, 0.92, 0.97, 0.6)), (1, (1.0, 1.0, 1.0, 0.96))])
        rgba[..., :3] = np.clip(rgba[..., :3] * (0.9 + lift)[..., None], 0, 1)
        rgba[..., 0] = np.clip(rgba[..., 0] + warm * 0.08, 0, 1)
        rgba[..., 2] = np.clip(rgba[..., 2] - warm * 0.12, 0, 1)
        base = np.zeros((FRAME, FRAME, 4), np.float32)
        blend(base, (0.16, 0.12, 0.12), rock)
        blend(base, (1.0, 0.55, 0.15), np.clip(vent * (0.8 + 0.2 * math.sin(TAU * t * 3)) * 1.3, 0, 1))
        frames.append(over(glow(to_image(base), 3, 0.8), glow(to_image(rgba), 3, 0.35)))
    return frames


def spirit():
    """Three soul flames circling a faint core, trailing motes; blue-white and flickering upward."""
    x, y, r, _ = polar()
    noise = PeriodicNoise(211, (8, 8, 8))

    def where(turn):
        a = TAU * turn
        return math.cos(a) * 0.52, -0.04 + math.sin(a) * 0.17 + 0.05 * math.sin(2 * a), math.sin(a)

    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        field = np.zeros_like(x)
        trails = Canvas()
        for k in range(3):
            # the three wisps advance one third of a turn per loop, so every value below depends
            # on the wisp's position, never on its index
            turn = (t + k) / 3
            cx, cy, depth = where(turn)
            size = 0.2 * (0.92 - 0.14 * depth)
            dx, dy = (x - cx) / size, (y - cy) / size
            n = noise.fbm(dx * 0.9 + 8 * turn, dy * 0.9 - t * 8, t * 8, octaves=3)
            up = np.clip(dy, 0, None)
            # a teardrop that narrows upward, its tip licking side to side
            wx = dx + (n - 0.5) * 0.9 * up
            q = np.hypot(wx * (1 + 0.45 * up), np.where(dy > 0, dy * 0.42, dy))
            flame = np.clip((1 - q) * 1.8 + (n - 0.5) * 0.8 - 0.1, 0, 1) * (0.72 + 0.28 * (1 - depth) / 2)
            field = np.maximum(field, flame)
            for j in range(1, 9):
                tx, ty, _ = where(turn - j * 0.012)
                trails.circle(tx, ty - 0.05, 0.03 * (1 - j / 10), fill=(170, 220, 255, int(200 * (1 - j / 9))))
        pulse = 0.5 + 0.5 * math.sin(TAU * t * 3)
        core = np.exp(-(x ** 2 + (y + 0.04) ** 2) / (0.006 + 0.004 * pulse)) * 0.8
        light = np.clip(np.maximum(field, core), 0, 1)
        image = to_image(ramp(light, [(0, (0.35, 0.6, 1.0, 0.0)), (0.3, (0.45, 0.72, 1.0, 0.65)), (0.7, (0.7, 0.88, 1.0, 0.92)), (1, (0.96, 0.99, 1.0, 1.0))]))
        frames.append(glow(over(glow(trails.done(), 2, 0.8), image), 5, 0.75))
    return frames


def sonic():
    """A sound burst: a thumping speaker core, shockwave rings and a bouncing radial equaliser."""
    x, y, r, _ = polar()
    rng = np.random.default_rng(221)
    bars = [(rng.random(), int(rng.integers(1, 4))) for _ in range(20)]
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        rings = np.zeros_like(r)
        for k in range(3):
            p = (t + k / 3) % 1.0
            rings = np.maximum(rings, np.exp(-((r - 0.12 - p * 0.78) ** 2) / (0.0004 + p * 0.0035)) * (1 - p) ** 1.3)
        beat = (t * 3) % 1.0
        thump = math.exp(-((beat / 0.08) ** 2)) + math.exp(-(((beat - 1) / 0.08) ** 2))
        core = np.exp(-(r ** 2) / (0.012 + 0.01 * thump))
        cone = (np.exp(-((r - 0.2) ** 2) / 0.0003) + np.exp(-((r - 0.28 - 0.01 * thump) ** 2) / 0.0004)) * 0.8
        light = np.clip(rings + core + cone, 0, 1)
        image = to_image(ramp(light, [(0, (0.3, 1.0, 0.8, 0.0)), (0.35, (0.4, 1.0, 0.85, 0.7)), (1, (0.9, 1.0, 0.98, 1.0))]))
        c = Canvas()
        for k, (phase, rate) in enumerate(bars):
            a = TAU * k / len(bars)
            amp = 0.5 + 0.5 * math.sin(TAU * (t * rate + phase))
            outer = 0.46 + amp * 0.2 + 0.08 * thump
            c.line([(math.cos(a) * 0.4, math.sin(a) * 0.4), (math.cos(a) * outer, math.sin(a) * outer)], fill=(150, 255, 225, 230), width=3.2)
        frames.append(glow(over(image, c.done()), 4, 0.7))
    return frames


def gear(canvas, cx, cy, radius, teeth, angle, fill, outline):
    """A toothed wheel with a rim and hub only, so it is symmetric under a one-tooth turn."""
    pts = []
    for i in range(teeth * 4):
        a = angle + TAU * i / (teeth * 4)
        rr = radius * (1.16 if (i % 4) in (1, 2) else 1.0)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    canvas.polygon(pts, fill)
    canvas.line(pts + [pts[0]], fill=outline, width=1.0)
    canvas.circle(cx, cy, radius * 0.62, outline=outline, width=1.0)
    canvas.circle(cx, cy, radius * 0.2, fill=outline)


def chrono():
    """A clock of turning gears whose minute hand races round, trailing afterimages and lighting beads."""
    frames = []
    bronze, trim = (150, 106, 48, 255), (232, 190, 104, 255)
    R = 0.56
    for f in range(FRAMES):
        t = f / FRAMES
        c = Canvas()
        gear(c, -0.5, 0.44, 0.27, 10, TAU * t / 10, bronze, trim)
        gear(c, 0.54, -0.42, 0.22, 8, -TAU * t / 8, bronze, trim)
        gear(c, 0.52, 0.5, 0.13, 6, TAU * t / 6, bronze, trim)
        c.circle(0, 0, R, fill=(26, 22, 38, 240))
        c.circle(0, 0, R, outline=(240, 200, 110, 255), width=3.0)
        c.circle(0, 0, R * 0.9, outline=(240, 200, 110, 140), width=1.0)
        for k in range(12):
            a = TAU * k / 12
            inner = R * (0.72 if k % 3 == 0 else 0.8)
            c.line([(math.cos(a) * inner, math.sin(a) * inner), (math.cos(a) * R * 0.88, math.sin(a) * R * 0.88)], fill=(240, 205, 120, 255), width=2.2 if k % 3 == 0 else 1.2)
        minute = math.pi / 2 - TAU * t
        for j in range(10, 0, -1):  # afterimages trail behind the hand as it sweeps clockwise
            a = minute + j * 0.07
            c.line([(0, 0), (math.cos(a) * R * 0.8, math.sin(a) * R * 0.8)], fill=(120, 230, 255, int(90 * (1 - j / 11))), width=2.2)
        hour = math.radians(150)
        c.line([(0, 0), (math.cos(hour) * R * 0.5, math.sin(hour) * R * 0.5)], fill=(255, 215, 130, 255), width=4.2)
        c.line([(0, 0), (math.cos(minute) * R * 0.8, math.sin(minute) * R * 0.8)], fill=(170, 240, 255, 255), width=2.4)
        c.circle(0, 0, 0.045, fill=(255, 225, 150, 255))
        for k in range(12):
            a = TAU * k / 12
            lit = max(0.0, math.cos(a - minute)) ** 16
            c.circle(math.cos(a) * 0.68, math.sin(a) * 0.68, 0.022 + 0.012 * lit, fill=(int(120 + 135 * lit), int(200 + 55 * lit), 255, int(120 + 135 * lit)))
        frames.append(glow(c.done(), 3, 0.6))
    return frames


ELEMENTS = {
    "fire": fire, "lightning": lightning, "ice": ice, "earth": earth, "void": void, "poison": poison,
    "water": water, "wind": wind, "radiance": radiance, "shadow": shadow, "arcane": arcane, "nature": nature,
    "blood": blood, "plasma": plasma, "prism": prism, "magma": magma, "blizzard": blizzard, "solar": solar,
    "cosmic": cosmic, "sand": sand, "steam": steam, "spirit": spirit, "sonic": sonic, "chrono": chrono,
}


def build(name):
    frames = ELEMENTS[name]()
    assert len(frames) == FRAMES
    rows = math.ceil(FRAMES / COLUMNS)
    sheet = Image.new("RGBA", (FRAME * COLUMNS, FRAME * rows), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % COLUMNS) * FRAME, (i // COLUMNS) * FRAME))
    path = os.path.join(OUT, f"{name}.png")
    sheet.save(path, optimize=True)
    backdrop = Image.new("RGBA", sheet.size, (16, 14, 26, 255))
    over(backdrop, sheet).convert("RGB").resize((510, 510)).save(os.path.join(PREVIEWS, f"{name}_preview.png"))
    print(f"[sprites] {name}: {sheet.size[0]}x{sheet.size[1]}, {FRAMES} frames -> {path}", flush=True)


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(ELEMENTS)
    for element in wanted:
        build(element)
