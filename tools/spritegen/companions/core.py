"""Shared rendering for the elemental companions.

Every companion is drawn fresh per frame into a supersampled canvas in three passes:

  body   - the silhouette and its painted detail. It receives form shading, then the
           companion's own lights: diffuse spill plus a rim on the edges that face each light.
  decal  - faces and fine marks, drawn after lighting so expressions stay readable.
  fx     - small emissive pieces (embers, sparks, motes) that glow on their own.

The aura is not a separate sheet behind the character. It is the light sources a design
declares each frame: they tint and rim-light the body, and a halo bleeds off the outline.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

FRAME = 682
SS = 2
N = FRAME * SS
COUNT = 36
COLUMNS = 6
EDGE = 4096

INK = (24, 26, 40)
CREAM = (255, 246, 224)
WHITE = (255, 255, 255)

Color = tuple[int, int, int]


def mix(a: Color, b: Color, amount: float) -> Color:
    return tuple(round(a[i] * (1 - amount) + b[i] * amount) for i in range(3))  # type: ignore[return-value]


def lighten(color: Color, amount: float) -> Color:
    return mix(color, WHITE, amount)


def darken(color: Color, amount: float) -> Color:
    return mix(color, INK, amount)


def wave(t: float, cycles: int = 1, offset: float = 0.0) -> float:
    """Seamless loop helper: sin over whole cycles of the 36-frame loop."""
    return math.sin((t * cycles + offset) * math.tau)


def catmull(points: list[tuple[float, float]], closed: bool = True, steps: int = 10) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points
    pts = list(points)
    out: list[tuple[float, float]] = []
    count = len(pts)
    segments = count if closed else count - 1
    for index in range(segments):
        p0 = pts[(index - 1) % count] if closed else pts[max(index - 1, 0)]
        p1 = pts[index % count]
        p2 = pts[(index + 1) % count] if closed else pts[min(index + 1, count - 1)]
        p3 = pts[(index + 2) % count] if closed else pts[min(index + 2, count - 1)]
        for step in range(steps):
            s = step / steps
            s2, s3 = s * s, s * s * s
            out.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * s + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * s2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * s3)
                for k in range(2)
            ))  # type: ignore[arg-type]
    if not closed:
        out.append(pts[-1])
    return out


@dataclass
class Light:
    x: float
    y: float
    radius: float
    color: Color
    strength: float = 1.0
    visible: bool = False  # draw the source itself as a soft orb
    orb: float = 0.03


class Pen:
    """Drawing in unit coordinates (0..1 of the frame) on one supersampled layer."""

    def __init__(self) -> None:
        self.image = Image.new("RGBA", (N, N))
        self.draw = ImageDraw.Draw(self.image)

    @staticmethod
    def p(x: float, y: float) -> tuple[float, float]:
        return x * N, y * N

    def poly(self, points, fill: Color, alpha: int = 255) -> None:
        self.draw.polygon([self.p(x, y) for x, y in points], fill=fill + (alpha,))

    def blob(self, points, fill: Color, alpha: int = 255) -> None:
        self.poly(catmull(points), fill, alpha)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, fill: Color, rot: float = 0.0, alpha: int = 255) -> None:
        if rot == 0:
            self.draw.ellipse((*self.p(cx - rx, cy - ry), *self.p(cx + rx, cy + ry)), fill=fill + (alpha,))
            return
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        pts = []
        for k in range(64):
            a = k / 64 * math.tau
            ex, ey = math.cos(a) * rx, math.sin(a) * ry
            pts.append((cx + ex * c - ey * s, cy + ex * s + ey * c))
        self.poly(pts, fill, alpha)

    def circle(self, cx: float, cy: float, r: float, fill: Color, alpha: int = 255) -> None:
        self.ellipse(cx, cy, r, r, fill, alpha=alpha)

    def line(self, points, fill: Color, width: float, smooth: bool = False, alpha: int = 255) -> None:
        """width is in frame pixels at 682."""
        pts = catmull(points, closed=False, steps=8) if smooth and len(points) > 2 else points
        w = max(1, round(width * SS))
        self.draw.line([self.p(x, y) for x, y in pts], fill=fill + (alpha,), width=w, joint="curve")
        r = w / 2
        for x, y in (pts[0], pts[-1]):  # round caps
            px, py = self.p(x, y)
            self.draw.ellipse((px - r, py - r, px + r, py + r), fill=fill + (alpha,))

    def ring(self, cx: float, cy: float, rx: float, ry: float, fill: Color, width: float, rot: float = 0.0,
             start: float = 0.0, end: float = 360.0, alpha: int = 255) -> None:
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        pts = []
        steps = max(8, int(abs(end - start) / 4))
        for k in range(steps + 1):
            a = math.radians(start + (end - start) * k / steps)
            ex, ey = math.sin(a) * rx, -math.cos(a) * ry
            pts.append((cx + ex * c - ey * s, cy + ex * s + ey * c))
        self.line(pts, fill, width, alpha=alpha)

    def star(self, cx: float, cy: float, r: float, inner: float, points: int, fill: Color, rot: float = 0.0,
             alpha: int = 255) -> None:
        pts = []
        for k in range(points * 2):
            a = math.radians(rot) + k * math.pi / points - math.pi / 2
            rr = r if k % 2 == 0 else r * inner
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        self.poly(pts, fill, alpha)


@dataclass
class Canvas:
    name: str
    t: float
    index: int
    blink: bool
    color: Color
    glow: Color
    body: Pen = field(default_factory=Pen)
    decal: Pen = field(default_factory=Pen)
    fx: Pen = field(default_factory=Pen)
    behind: Pen = field(default_factory=Pen)  # unlit, unoutlined pieces behind the body (tails of light etc.)
    lights: list[Light] = field(default_factory=list)
    halo: float = 0.6  # strength of the outline bleed in the glow colour
    halo_color: Color | None = None
    outline: float = 13.0  # frame pixels
    shade: float = 1.0
    shade_tint: Color = (70, 64, 120)
    # a slow once-per-loop float (fraction of the frame) for designs whose own motion repeats
    # within the loop, so every frame of the 36 stays distinct
    drift: float = 0.0

    # ---- faces -------------------------------------------------------------------------------

    def eyes(self, x: float, y: float, gap: float = 0.09, size: float = 0.034, style: str = "round",
             gaze: float = 0.0, tilt: float = 0.0, color: Color = INK, shine: Color = WHITE) -> None:
        d = self.decal
        for side in (-1, 1):
            ex = x + side * gap / 2
            ey = y + side * tilt
            if self.blink and style not in {"closed", "visor"}:
                d.ring(ex, ey + size * 0.2, size, size * 0.55, color, 7, start=100, end=260)
                continue
            if style == "round":
                d.ellipse(ex, ey, size * 0.86, size, color)
                d.circle(ex - size * 0.3 + gaze * size, ey - size * 0.38, size * 0.32, shine)
                d.circle(ex + size * 0.28 + gaze * size, ey + size * 0.34, size * 0.13, shine)
            elif style == "happy":
                d.ring(ex, ey + size * 0.4, size * 0.9, size * 0.85, color, 7.5, start=-80, end=80)
            elif style == "sleepy":
                d.ring(ex, ey, size * 0.9, size * 0.5, color, 7, start=100, end=260)
            elif style == "closed":
                d.ring(ex, ey, size * 0.9, size * 0.5, color, 7, start=100, end=260)
            elif style == "fierce":
                d.ellipse(ex, ey, size * 0.8, size * 0.85, color)
                d.circle(ex - size * 0.25 + gaze * size, ey - size * 0.3, size * 0.28, shine)
                d.line([(ex - side * size * 1.1, ey - size * 1.5), (ex + side * size * 0.9, ey - size * 0.95)], color, 8)
            elif style == "glow":
                d.ellipse(ex, ey, size * 0.75, size * 0.95, shine)
            elif style == "dot":
                d.circle(ex + gaze * size, ey, size * 0.55, color)
            elif style == "visor":
                pass

    def cyclops(self, x: float, y: float, size: float = 0.06, gaze: float = 0.0, iris: Color | None = None) -> None:
        d = self.decal
        if self.blink:
            d.ring(x, y + size * 0.15, size, size * 0.55, INK, 8, start=100, end=260)
            return
        d.ellipse(x, y, size, size * 1.02, WHITE)
        d.circle(x + gaze * size * 0.4, y, size * 0.62, iris or self.color)
        d.circle(x + gaze * size * 0.4, y, size * 0.34, INK)
        d.circle(x - size * 0.22 + gaze * size * 0.4, y - size * 0.26, size * 0.17, WHITE)

    def mouth(self, x: float, y: float, style: str = "smile", size: float = 0.03, color: Color = INK) -> None:
        d = self.decal
        if style == "smile":
            d.ring(x, y - size * 0.6, size * 1.1, size, color, 6.5, start=120, end=240)
        elif style == "grin":
            d.blob([(x - size * 1.3, y - size * 0.2), (x + size * 1.3, y - size * 0.2), (x + size * 0.6, y + size),
                    (x - size * 0.6, y + size)], color)
            d.ellipse(x, y + size * 0.55, size * 0.6, size * 0.3, (232, 96, 110))
        elif style == "o":
            d.ellipse(x, y, size * 0.6, size * 0.75, color)
        elif style == "flat":
            d.line([(x - size, y), (x + size, y)], color, 6)
        elif style == "cat":
            d.ring(x - size * 0.55, y - size * 0.35, size * 0.55, size * 0.55, color, 6, start=110, end=250)
            d.ring(x + size * 0.55, y - size * 0.35, size * 0.55, size * 0.55, color, 6, start=110, end=250)
        elif style == "fang":
            d.ring(x, y - size * 0.6, size * 1.1, size, color, 6.5, start=120, end=240)
            d.poly([(x + size * 0.3, y + size * 0.2), (x + size * 0.75, y + size * 0.15), (x + size * 0.55, y + size * 0.75)], WHITE)
        elif style == "wobble":
            d.line([(x - size * 1.2, y), (x - size * 0.4, y + size * 0.35), (x + size * 0.4, y - size * 0.1),
                    (x + size * 1.2, y + size * 0.25)], color, 6, smooth=True)
        elif style == "frown":
            d.ring(x, y + size * 0.7, size * 1.0, size * 0.8, color, 6.5, start=-60, end=60)

    def cheeks(self, x: float, y: float, gap: float, color: Color = (255, 130, 150), size: float = 0.022) -> None:
        for side in (-1, 1):
            self.decal.ellipse(x + side * gap / 2, y, size * 1.3, size * 0.75, color, alpha=150)

    # ---- emissive pieces ----------------------------------------------------------------------

    def ember(self, x: float, y: float, r: float, color: Color, core: Color = WHITE) -> None:
        self.fx.circle(x, y, r, color)
        self.fx.circle(x, y, r * 0.5, core)


def _blur(mask: np.ndarray, radius: float) -> np.ndarray:
    if radius <= 0:
        return mask
    image = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), "L")
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255


def _shift(mask: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """out[y, x] = mask[y + dy, x + dx] (zero outside)."""
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(0, -dy), min(h, h - dy))
    xs = slice(max(0, -dx), min(w, w - dx))
    yd = slice(max(0, dy), min(h, h + dy))
    xd = slice(max(0, dx), min(w, w + dx))
    out[ys, xs] = mask[yd, xd]
    return out


def _screen(base: np.ndarray, add: np.ndarray) -> np.ndarray:
    return 1 - (1 - base) * (1 - np.clip(add, 0, 1))


def _img(array: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(array, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def _rgba(color: Color, alpha: np.ndarray) -> np.ndarray:
    rgb = np.broadcast_to(np.array(color, np.float32) / 255, (N, N, 3))
    return np.concatenate([rgb, np.clip(alpha, 0, 1)[..., None].astype(np.float32)], -1)


_GRID = None


def _grid() -> tuple[np.ndarray, np.ndarray]:
    global _GRID
    if _GRID is None:
        ys, xs = np.mgrid[0:N, 0:N].astype(np.float32)
        _GRID = (xs / N, ys / N)
    return _GRID


def render(canvas: Canvas) -> Image.Image:
    body = np.asarray(canvas.body.image, dtype=np.float32) / 255
    mask = body[..., 3]
    rgb = body[..., :3].copy()
    gx, gy = _grid()

    # Form shading: a soft terminator on the side away from a fixed key light (upper left).
    if canvas.shade > 0:
        d = int(0.05 * N)
        far = mask * (1 - _shift(mask, int(d * 0.6), int(d * 0.8)))
        far = _blur(far, 0.028 * N)
        far = np.clip((far - 0.18) / 0.4, 0, 1) * mask
        tint = np.array(canvas.shade_tint, dtype=np.float32) / 255
        rgb = rgb * (1 - 0.42 * canvas.shade * far[..., None]) + tint * (0.42 * canvas.shade * far[..., None]) * 0.35
        near = mask * (1 - _shift(mask, -int(d * 0.5), -int(d * 0.65)))
        near = np.clip(_blur(near, 0.02 * N) - 0.2, 0, 1) * mask
        rgb = _screen(rgb, near[..., None] * 0.22 * canvas.shade)

    # The companion's own light: spill across the body plus a rim on edges facing each source.
    glow_layers: list[Image.Image] = []
    rim_d = max(2, int(0.022 * N))
    h, w = mask.shape
    iy, ix = np.mgrid[0:h, 0:w]
    for light in canvas.lights:
        dx, dy = light.x - gx, light.y - gy
        dist = np.sqrt(dx * dx + dy * dy) + 1e-6
        falloff = np.clip(1 - dist / max(light.radius, 1e-3), 0, 1) ** 2 * light.strength
        color = np.array(light.color, dtype=np.float32) / 255
        rgb = _screen(rgb, color * (falloff * mask * 0.75)[..., None])
        sx = np.clip(ix + np.round(dx / dist * rim_d).astype(np.int32), 0, w - 1)
        sy = np.clip(iy + np.round(dy / dist * rim_d).astype(np.int32), 0, h - 1)
        rim = mask * (1 - mask[sy, sx])
        rim = _blur(rim, 0.006 * N) * mask
        wide = np.clip(1 - dist / max(light.radius * 1.7, 1e-3), 0, 1) * light.strength
        rgb = _screen(rgb, color * (rim * wide * 1.15)[..., None])
        if light.visible:
            orb = np.clip(1 - dist / max(light.orb * 3.2, 1e-3), 0, 1) ** 2.2 * min(1.0, light.strength)
            core = np.clip(1 - dist / max(light.orb, 1e-3), 0, 1)
            glow_layers.append(_img(_rgba(light.color, orb)))
            glow_layers.append(_img(_rgba(lighten(light.color, 0.7), np.clip(core * 1.6, 0, 1))))

    # Outline: a rounded dilation of the silhouette in ink.
    width = canvas.outline * SS
    grown = _blur(mask, width * 0.55)
    ink_a = np.clip((grown - 0.035) / 0.06, 0, 1)
    ink = _rgba(INK, ink_a)

    # Halo: the aura bleeding off the outline, strongest close to the body.
    halo_rgb = canvas.halo_color or canvas.glow
    halo_a = np.clip(_blur(ink_a, 0.045 * N) * 1.5, 0, 1) * canvas.halo
    halo_a = np.maximum(halo_a, np.clip(_blur(ink_a, 0.016 * N) * 1.2, 0, 1) * canvas.halo * 0.9)
    halo = _rgba(halo_rgb, halo_a * 0.85)

    fx_alpha = np.asarray(canvas.fx.image.getchannel("A"), dtype=np.float32) / 255
    fx_glow = _rgba(halo_rgb, np.clip(_blur(fx_alpha, 0.012 * N) * 1.4, 0, 1) * 0.75)

    out = Image.new("RGBA", (N, N))
    out.alpha_composite(_img(halo))
    out.alpha_composite(canvas.behind.image)
    out.alpha_composite(_img(ink))
    out.alpha_composite(_img(np.concatenate([np.clip(rgb, 0, 1), mask[..., None]], -1)))
    out.alpha_composite(canvas.decal.image)
    for layer in glow_layers:
        out.alpha_composite(layer)
    out.alpha_composite(_img(fx_glow))
    out.alpha_composite(canvas.fx.image)
    if canvas.drift:
        dy = round(math.sin(canvas.t * math.tau) * canvas.drift * N)
        dx = round(math.cos(canvas.t * math.tau) * canvas.drift * N * 0.35)
        out = out.transform(out.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BILINEAR)
    return out.resize((FRAME, FRAME), Image.LANCZOS)
