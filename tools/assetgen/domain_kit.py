"""Faceted gem models for the Domain lattice, exported as one binary glTF.

    python tools/assetgen/domain_kit.py            build DomainKit.glb and a preview sheet
    python tools/assetgen/domain_kit.py --upload   then upload it with Open Cloud and print the id

Every model is a named node (Domain_<Name>), so the uploaded Model holds one MeshPart per gem. The
game tints, lights and spins them at runtime, so they carry no textures. Cuts with a table (the flat
top facet) are built table-up; the client tilts them toward the camera.

    Brilliant  Emerald  Trillion  Marquise  Pear   Core   Twist   Shard
    Moon       Star     Halo      Globe     Cube   Seed   Spire
"""

from __future__ import annotations

import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

from meshes import Mesh, add, box, cross, dot, icosphere, loft, mul, norm, rot_x, rot_y, rot_z, sub, write_glb

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated", "domain")


def outline(points, y, scale=1.0, twist=0.0):
    """A 2D outline (x, z pairs) placed at height y, scaled and turned about the vertical axis."""
    c, s = math.cos(twist), math.sin(twist)
    return [((x * c - z * s) * scale, y, (x * s + z * c) * scale) for x, z in points]


def circle(sides, radius=1.0):
    return [(math.cos(math.tau * i / sides) * radius, math.sin(math.tau * i / sides) * radius) for i in range(sides)]


def cut(girdle, spec, culet=None, tip=None, cap_bottom=True):
    """Loft one outline through (y, scale, twist) rings. Turning alternate rings by half a facet is
    what breaks the bands into star and kite facets."""
    rings = [outline(girdle, y, scale, twist) for y, scale, twist in spec]
    return loft(rings, cap_bottom=cap_bottom, cap_top=tip is None, top_point=tip, bottom_point=culet)


def brilliant():
    half = math.pi / 16
    spec = [(-0.42, 0.5, half), (-0.04, 1.0, 0), (0.04, 1.0, 0), (0.26, 0.8, half), (0.4, 0.56, 0)]
    return cut(circle(16), spec, culet=(0.0, -1.0, 0.0))


def chamfered_rect(w, d, c):
    hx, hz = w / 2, d / 2
    return [(-hx + c, -hz), (hx - c, -hz), (hx, -hz + c), (hx, hz - c), (hx - c, hz), (-hx + c, hz), (-hx, hz - c), (-hx, -hz + c)]


def emerald():
    spec = [(-0.7, 0.26, 0), (-0.38, 0.63, 0), (-0.04, 1.0, 0), (0.04, 1.0, 0), (0.17, 0.87, 0), (0.29, 0.74, 0), (0.37, 0.63, 0)]
    return cut(chamfered_rect(1.6, 1.05, 0.22), spec)


def trillion_outline(bulge=0.13):
    corners = [(math.cos(math.pi / 2 + math.tau * k / 3), math.sin(math.pi / 2 + math.tau * k / 3)) for k in range(3)]
    pts = []
    for k in range(3):
        a, b = corners[k], corners[(k + 1) % 3]
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        out = math.hypot(mx, mz)
        ox, oz = mx / out, mz / out
        for t in (0, 1 / 3, 2 / 3):
            bend = bulge * math.sin(math.pi * t)
            pts.append((a[0] + (b[0] - a[0]) * t + ox * bend, a[1] + (b[1] - a[1]) * t + oz * bend))
    return pts


def trillion():
    spec = [(-0.36, 0.46, 0), (-0.04, 1.0, 0), (0.04, 1.0, 0), (0.2, 0.78, 0), (0.32, 0.56, 0)]
    return cut(trillion_outline(), spec, culet=(0.0, -0.8, 0.0))


def marquise_outline(length=1.0, width=0.5, n=8):
    pts = []
    for i in range(n + 1):
        u = -1 + 2 * i / n
        pts.append((u * length, width * (1 - u * u) ** 0.8))
    for i in range(n - 1, 0, -1):
        u = -1 + 2 * i / n
        pts.append((u * length, -width * (1 - u * u) ** 0.8))
    return pts


def marquise():
    spec = [(-0.34, 0.5, 0), (-0.04, 1.0, 0), (0.04, 1.0, 0), (0.2, 0.8, 0), (0.32, 0.58, 0)]
    return cut(marquise_outline(), spec, culet=(0.0, -0.74, 0.0))


def pear():
    """A faceted teardrop standing on its round end."""
    half = math.pi / 12
    spec = [(-0.62, 0.6, 0), (-0.3, 0.86, half), (0.05, 0.8, 0), (0.38, 0.55, half), (0.66, 0.26, 0)]
    return cut(circle(12), spec, culet=(0.0, -0.9, 0.0), tip=(0.0, 1.08, 0.0))


def core():
    """A long octagonal bipyramid whose girdle zig-zags."""
    spec = [(-0.07, 0.72, 0), (0.07, 0.72, math.pi / 8)]
    return cut(circle(8), spec, culet=(0.0, -1.1, 0.0), tip=(0.0, 1.1, 0.0))


def twist():
    """A hexagonal crystal wrung a quarter turn along its length."""
    spec = [(-0.85 + k * 0.34, 0.42, k * 0.2) for k in range(6)]
    return cut(circle(6), spec, culet=(0.0, -1.25, 0.0), tip=(0.0, 1.25, 0.0))


def spike(radius, height, lean, turn, foot=(0.0, -0.9, 0.0)):
    """A pointed hexagonal crystal grown from `foot`, leaning `lean` radians off vertical."""
    m = cut(circle(6, radius), [(0.0, 1.0, 0), (height * 0.62, 1.12, 0.12)], culet=(0.0, -radius * 1.6, 0.0), tip=(0.0, height, 0.0))
    return m.transformed(lambda p: add(rot_y(rot_z(p, lean), turn), foot))


def shard():
    """A crystal cluster: one tall spike and two partners fanning out from its foot."""
    m = spike(0.3, 2.1, 0.0, 0.0)
    m.merge(spike(0.24, 1.45, 0.55, 0.2, (-0.12, -0.8, 0.05)))
    m.merge(spike(0.21, 1.2, -0.6, -0.25, (0.12, -0.8, -0.05)))
    return m


def moon():
    """A crescent swept along an arc, a diamond section that swells in the middle."""
    m = Mesh()
    steps = 16
    radius = 0.78
    start, end = 0.62, math.tau - 0.62
    rings = []
    for i in range(1, steps):
        s = i / steps
        a = start + (end - start) * s
        d = (math.cos(a), math.sin(a), 0.0)
        swell = math.sin(math.pi * s) ** 0.75
        w, depth = 0.3 * swell, 0.2 * swell
        centre = mul(d, radius)
        rings.append([add(centre, mul(d, w)), add(centre, (0.0, 0.0, depth)), add(centre, mul(d, -w)), add(centre, (0.0, 0.0, -depth))])
    body = loft(rings, cap_bottom=False, cap_top=False)
    m.merge(body)
    for ring_points, tip_angle in ((rings[0], start), (rings[-1], end)):
        tip = (math.cos(tip_angle) * radius, math.sin(tip_angle) * radius, 0.0)
        centre = mul(tuple(sum(c) for c in zip(*ring_points)), 1 / len(ring_points))
        for k in range(4):
            a, b = ring_points[k], ring_points[(k + 1) % 4]
            # orient against a point a little behind the ring, inside the tube
            m.tri(a, b, tip, add(centre, mul(sub(centre, tip), 0.5)))
    return m.transformed(lambda p: rot_z(p, math.pi))


def star(points=5, outer=1.0, inner=0.44, depth=0.34):
    m = Mesh()
    rim = []
    for i in range(points * 2):
        a = math.pi / 2 + math.pi * i / points
        r = outer if i % 2 == 0 else inner
        rim.append((math.cos(a) * r, math.sin(a) * r, 0.0))
    for i in range(len(rim)):
        a, b = rim[i], rim[(i + 1) % len(rim)]
        m.tri(a, b, (0.0, 0.0, depth), (0.0, 0.0, 0.0))
        m.tri(a, b, (0.0, 0.0, -depth), (0.0, 0.0, 0.0))
    return m


def torus(major, minor, segments, sides, twist_sides=True):
    m = Mesh()
    rings = []
    for i in range(segments):
        a = math.tau * i / segments
        centre = (math.cos(a) * major, math.sin(a) * major, 0.0)
        offset = (math.pi / sides) * (i % 2) if twist_sides else 0.0
        pts = []
        for k in range(sides):
            b = math.tau * k / sides + offset
            radial = (math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b))
            pts.append(add(centre, mul(radial, minor)))
        rings.append((centre, pts))
    for i in range(segments):
        (c0, r0), (c1, r1) = rings[i], rings[(i + 1) % segments]
        mid = mul(add(c0, c1), 0.5)
        for k in range(sides):
            j = (k + 1) % sides
            m.quad(r0[k], r0[j], r1[j], r1[k], mid)
    return m


def halo():
    """An echo ring with a small gem caught in its centre."""
    m = torus(0.78, 0.15, 20, 6)
    m.merge(cut(circle(4, 0.3), [(-0.04, 1.0, 0), (0.04, 1.0, 0)], culet=(0.0, -0.36, 0.0), tip=(0.0, 0.36, 0.0)))
    return m


def faceted_orb(radius, seed, roughness):
    rng = random.Random(seed)
    verts, faces = icosphere(1)
    scale = [radius * (1 + rng.uniform(-roughness, roughness)) for _ in verts]
    pts = [mul(v, s) for v, s in zip(verts, scale)]
    m = Mesh()
    for a, b, c in faces:
        m.tri(pts[a], pts[b], pts[c], (0.0, 0.0, 0.0))
    return m


def globe():
    """A faceted planetoid inside a thin tilted band."""
    m = faceted_orb(0.72, 7, 0.05)
    band = torus(1.08, 0.05, 28, 4, twist_sides=False).transformed(lambda p: rot_x(p, math.pi / 2 - 0.42))
    return m.merge(band)


def cube():
    return box(1.2, 1.2, 1.2, bevel=0.2)


def seed():
    return faceted_orb(1.0, 11, 0.08)


def spire():
    """The lattice trunk: an eight-sided crystal column that tapers and twists as it climbs."""
    spec = []
    for k in range(13):
        s = k / 12
        spec.append((s * 10.0, 1.0 - 0.55 * s + 0.08 * math.sin(s * math.pi * 3), s * 1.4 + (math.pi / 8) * (k % 2)))
    return cut(circle(8, 0.6), spec, tip=(0.0, 11.0, 0.0))


MODELS = {
    "Brilliant": brilliant, "Emerald": emerald, "Trillion": trillion, "Marquise": marquise, "Pear": pear,
    "Core": core, "Twist": twist, "Shard": shard, "Moon": moon, "Star": star, "Halo": halo, "Globe": globe,
    "Cube": cube, "Seed": seed, "Spire": spire,
}
# cuts built table-up; the preview (and the game) tips these toward the viewer
TABLE_UP = {"Brilliant", "Emerald", "Trillion", "Marquise"}


def render(mesh, tilt, size=200, tint=(0.62, 0.82, 1.0)):
    """A flat-shaded painter's-algorithm preview, lit from the upper left."""
    image = Image.new("RGB", (size, size), (16, 14, 26))
    draw = ImageDraw.Draw(image)
    lo, hi = mesh.bounds()
    centre = mul(add(lo, hi), 0.5)
    extent = max(h - l for l, h in zip(lo, hi))
    light = norm((-0.5, 0.7, 0.6))
    half = norm(add(light, (0.0, 0.0, 1.0)))
    tris = []
    for a, b, c in mesh.tris:
        pts = [rot_x(rot_y(sub(p, centre), 0.45), tilt) for p in (a, b, c)]
        n = norm(cross(sub(pts[1], pts[0]), sub(pts[2], pts[0])))
        if n[2] <= 0:
            continue
        shade = 0.22 + 0.78 * max(0.0, dot(n, light))
        spec = max(0.0, dot(n, half)) ** 40
        tris.append((sum(p[2] for p in pts) / 3, pts, shade, spec))
    tris.sort(key=lambda item: item[0])
    for _, pts, shade, spec in tris:
        poly = [(size / 2 + p[0] / extent * size * 0.8, size / 2 - p[1] / extent * size * 0.8) for p in pts]
        colour = tuple(int(min(255, (base * shade + spec) * 255)) for base in tint)
        draw.polygon(poly, fill=colour)
    return image


def build():
    os.makedirs(OUT, exist_ok=True)
    named = [(f"Domain_{name}", make()) for name, make in MODELS.items()]
    sizes = write_glb(os.path.join(OUT, "DomainKit.glb"), named)
    tile = 200
    cols = 5
    rows = math.ceil(len(named) / cols)
    sheet = Image.new("RGB", (tile * cols, (tile + 18) * rows), (10, 9, 16))
    draw = ImageDraw.Draw(sheet)
    for index, (name, mesh) in enumerate(named):
        short = name.removeprefix("Domain_")
        tilt = 1.1 if short in TABLE_UP else 0.25
        x, y = (index % cols) * tile, (index // cols) * (tile + 18)
        sheet.paste(render(mesh, tilt, tile), (x, y))
        draw.text((x + 6, y + tile + 3), f"{short}  {len(mesh.tris)} tris", fill=(220, 220, 235))
    sheet.save(os.path.join(OUT, "DomainKit_preview.png"))
    with open(os.path.join(OUT, "DomainKit_sizes.json"), "w", encoding="utf-8") as handle:
        json.dump(sizes, handle, indent=2)
    total = sum(len(mesh.tris) for _, mesh in named)
    print(f"[domain] {len(named)} models, {total} triangles -> {os.path.join(OUT, 'DomainKit.glb')}")


def upload_kit():
    sys.path.insert(0, HERE)
    import upload

    key = upload.saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key yet: run  powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1")
    asset_id = upload.upload(key, "Model", os.path.join(OUT, "DomainKit.glb"), "model/gltf-binary", "Astral Forge Domain Kit", "Faceted gems and the crystal spire for the Domain lattice.")
    with open(os.path.join(OUT, "domain_kit_id.json"), "w", encoding="utf-8") as handle:
        json.dump({"Id": asset_id}, handle, indent=2)
    print(f"Uploaded Domain kit: {asset_id}  (paste it into src/Shared/AstralForge/Shared/DomainKit.luau)")


if __name__ == "__main__":
    build()
    if "--upload" in sys.argv:
        upload_kit()
