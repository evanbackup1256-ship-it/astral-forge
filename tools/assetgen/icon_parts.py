"""The pictogram library behind the composed icons.

Every generated machine and research study is a NOUN (Loom, Anvil, Lattice ...) plus a MODIFIER
(Aether, Quark, Folded ...) plus a tier, and has its own colour. An icon is built from those parts:
    plate (tinted with the thing's colour) + noun pictogram + modifier emblem + tier pips.
So every thing is unique by construction, and every icon still reads as what it is.

Each function draws into unit space (0..1, y down) on a Mask `m` (the body, cream) and a Mask `d`
(detail, drawn in a deep tone). Strokes are bold on purpose: these are drawn at 24-48 px.
"""
from __future__ import annotations

import math

# ---------------------------------------------------------------------------------- machine nouns


def loom(m, d):
    """a weaving frame: warp threads running down and the shuttle passing through them"""
    m.rect(0.15, 0.17, 0.85, 0.83, 0.05)
    m.rect(0.26, 0.28, 0.74, 0.72, 0.02, on=False)
    for x in (0.34, 0.45, 0.56, 0.67):
        m.line([(x, 0.29), (x, 0.71)], 0.05)
    # the shuttle: a boat-shaped bar with a groove, crossing the threads
    m.poly([(0.22, 0.5), (0.33, 0.4), (0.67, 0.4), (0.78, 0.5), (0.67, 0.6), (0.33, 0.6)])
    d.line([(0.34, 0.5), (0.66, 0.5)], 0.03)

def anvil(m, d):
    m.poly([(0.12, 0.30), (0.88, 0.30), (0.88, 0.42), (0.68, 0.46), (0.62, 0.58), (0.66, 0.70), (0.76, 0.70), (0.76, 0.84), (0.24, 0.84), (0.24, 0.70), (0.34, 0.70), (0.38, 0.58), (0.32, 0.46), (0.12, 0.42)])
    d.line([(0.2, 0.36), (0.8, 0.36)], 0.035)


def spindle(m, d):
    """a drop spindle: a cone of wound thread, a whorl disc, and the shaft below"""
    m.poly([(0.5, 0.08), (0.64, 0.5), (0.36, 0.5)])
    m.rect(0.18, 0.5, 0.82, 0.62, 0.06)
    m.rect(0.45, 0.62, 0.55, 0.92, 0.03)
    d.line([(0.42, 0.34), (0.58, 0.3)], 0.03)
    d.line([(0.4, 0.42), (0.6, 0.38)], 0.03)

def kiln(m, d):
    m.circle(0.5, 0.52, 0.34)
    m.rect(0.16, 0.52, 0.84, 0.86, 0.04)
    m.rect(0.62, 0.12, 0.76, 0.34, 0.02)
    d.rect(0.4, 0.58, 0.6, 0.86, 0.1)
    d.circle(0.5, 0.58, 0.1)


def array(m, d):
    for r in range(3):
        for c in range(3):
            m.rect(0.15 + c * 0.255, 0.15 + r * 0.255, 0.15 + c * 0.255 + 0.2, 0.15 + r * 0.255 + 0.2, 0.04)
    d.line([(0.15, 0.5), (0.85, 0.5)], 0.02)


def engine(m, d):
    """a turbine: five blades round a hub"""
    for i in range(5):
        a = math.radians(-90 + i * 72)
        b = math.radians(-90 + i * 72 + 52)
        m.poly([(0.5, 0.5), (0.5 + 0.38 * math.cos(a), 0.5 + 0.38 * math.sin(a)), (0.5 + 0.34 * math.cos(b), 0.5 + 0.34 * math.sin(b))])
    m.circle(0.5, 0.5, 0.12)
    d.circle(0.5, 0.5, 0.05)


def well(m, d):
    """a stone well with a little roof on two posts"""
    m.poly([(0.16, 0.3), (0.5, 0.1), (0.84, 0.3)])
    m.rect(0.24, 0.3, 0.31, 0.58, 0.01)
    m.rect(0.69, 0.3, 0.76, 0.58, 0.01)
    m.rect(0.2, 0.52, 0.8, 0.88, 0.06)
    d.rect(0.3, 0.6, 0.7, 0.68, 0.03)
    d.line([(0.5, 0.34), (0.5, 0.5)], 0.03)

def core(m, d):
    m.poly([(0.5, 0.1), (0.82, 0.38), (0.5, 0.9), (0.18, 0.38)])
    d.poly([(0.5, 0.1), (0.18, 0.38), (0.5, 0.42)])
    d.line([(0.5, 0.42), (0.5, 0.9)], 0.025)


def lattice(m, d):
    m.poly([(0.5, 0.08), (0.92, 0.5), (0.5, 0.92), (0.08, 0.5)])
    m.poly([(0.5, 0.22), (0.78, 0.5), (0.5, 0.78), (0.22, 0.5)], on=False)
    m.line([(0.5, 0.2), (0.5, 0.8)], 0.06)
    m.line([(0.2, 0.5), (0.8, 0.5)], 0.06)


def dynamo(m, d):
    m.ring(0.5, 0.5, 0.33, 0.1)
    m.poly([(0.54, 0.24), (0.38, 0.52), (0.49, 0.52), (0.44, 0.76), (0.62, 0.46), (0.51, 0.46), (0.56, 0.24)])


def press(m, d):
    m.rect(0.2, 0.12, 0.8, 0.28, 0.04)
    m.rect(0.43, 0.28, 0.57, 0.6, 0.02)
    m.rect(0.28, 0.6, 0.72, 0.72, 0.03)
    m.rect(0.14, 0.78, 0.86, 0.9, 0.03)
    d.line([(0.26, 0.2), (0.74, 0.2)], 0.025)


def sieve(m, d):
    m.circle(0.5, 0.46, 0.36)
    m.rect(0.0, 0.0, 1.0, 0.44, 0.0, on=False)
    m.rect(0.14, 0.40, 0.86, 0.50, 0.03)
    m.rect(0.45, 0.14, 0.55, 0.42, 0.03)
    for x, y in ((0.36, 0.62), (0.5, 0.66), (0.64, 0.62), (0.43, 0.76), (0.57, 0.76)):
        d.circle(x, y, 0.035)


def relay(m, d):
    m.circle(0.5, 0.5, 0.13)
    for r in (0.27, 0.4):
        m.arc(0.5, 0.5, r, -48, 48, 0.07)
        m.arc(0.5, 0.5, r, 132, 228, 0.07)


def crown(m, d):
    m.poly([(0.12, 0.76), (0.12, 0.34), (0.32, 0.52), (0.5, 0.22), (0.68, 0.52), (0.88, 0.34), (0.88, 0.76)])
    m.rect(0.12, 0.76, 0.88, 0.86, 0.02)
    d.circle(0.5, 0.62, 0.05)


def gate(m, d):
    m.rect(0.18, 0.34, 0.82, 0.88, 0.03)
    m.circle(0.5, 0.34, 0.32)
    m.rect(0.34, 0.5, 0.66, 0.88, 0.0, on=False)
    m.circle(0.5, 0.5, 0.16, on=False)
    m.line([(0.42, 0.52), (0.42, 0.86)], 0.04)
    m.line([(0.58, 0.52), (0.58, 0.86)], 0.04)


def heart(m, d):
    m.circle(0.36, 0.38, 0.2)
    m.circle(0.64, 0.38, 0.2)
    m.poly([(0.17, 0.46), (0.83, 0.46), (0.5, 0.86)])
    d.line([(0.3, 0.3), (0.36, 0.26)], 0.04)


def spire(m, d):
    m.poly([(0.5, 0.06), (0.6, 0.58), (0.4, 0.58)])
    m.poly([(0.27, 0.34), (0.34, 0.62), (0.2, 0.62)])
    m.poly([(0.73, 0.34), (0.8, 0.62), (0.66, 0.62)])
    m.rect(0.22, 0.62, 0.78, 0.88, 0.03)
    d.rect(0.44, 0.7, 0.56, 0.88, 0.02)


def forge(m, d):
    m.rect(0.16, 0.36, 0.84, 0.88, 0.05)
    m.rect(0.64, 0.12, 0.76, 0.38, 0.02)
    d.rect(0.34, 0.52, 0.66, 0.88, 0.14)
    d.poly([(0.5, 0.56), (0.58, 0.72), (0.5, 0.82), (0.42, 0.72)])


def drive(m, d):
    """two pulleys and a belt"""
    m.circle(0.28, 0.5, 0.18)
    m.circle(0.72, 0.5, 0.18)
    m.rect(0.28, 0.32, 0.72, 0.38, 0.0)
    m.rect(0.28, 0.62, 0.72, 0.68, 0.0)
    d.circle(0.28, 0.5, 0.06)
    d.circle(0.72, 0.5, 0.06)


def matrix(m, d):
    for r in range(3):
        for c in range(3):
            m.circle(0.34 + c * 0.16, 0.34 + r * 0.16, 0.065)
    m.line([(0.22, 0.18), (0.14, 0.18), (0.14, 0.82), (0.22, 0.82)], 0.05)
    m.line([(0.78, 0.18), (0.86, 0.18), (0.86, 0.82), (0.78, 0.82)], 0.05)


# ---------------------------------------------------------------------------------- study nouns


def manifold(m, d):
    m.rect(0.12, 0.5, 0.88, 0.64, 0.04)
    for x in (0.28, 0.5, 0.72):
        m.rect(x - 0.06, 0.2, x + 0.06, 0.52, 0.02)
        m.rect(x - 0.09, 0.16, x + 0.09, 0.26, 0.02)
    m.rect(0.18, 0.64, 0.3, 0.84, 0.02)
    m.rect(0.7, 0.64, 0.82, 0.84, 0.02)


def circuit(m, d):
    m.line([(0.2, 0.8), (0.2, 0.46), (0.5, 0.46), (0.5, 0.2)], 0.06)
    m.line([(0.5, 0.46), (0.8, 0.46), (0.8, 0.8)], 0.06)
    for x, y in ((0.2, 0.8), (0.5, 0.2), (0.8, 0.8)):
        m.circle(x, y, 0.09)
    d.circle(0.5, 0.46, 0.04)


def protocol(m, d):
    m.rect(0.24, 0.12, 0.76, 0.88, 0.06)
    for y in (0.3, 0.46, 0.62):
        d.line([(0.34, y), (0.66, y)], 0.045)
    d.line([(0.34, 0.76), (0.5, 0.76)], 0.045)


def doctrine(m, d):
    m.rect(0.2, 0.12, 0.8, 0.88, 0.05)
    m.rect(0.2, 0.12, 0.3, 0.88, 0.0, on=False)
    m.rect(0.2, 0.12, 0.3, 0.88, 0.02)
    d.star(0.55, 0.5, 0.17, 0.07, 5)


def axiom(m, d):
    m.poly([(0.5, 0.1), (0.9, 0.84), (0.1, 0.84)])
    m.poly([(0.5, 0.3), (0.74, 0.74), (0.26, 0.74)], on=False)
    m.circle(0.5, 0.58, 0.07)


def theorem(m, d):
    m.circle(0.5, 0.26, 0.09)
    m.circle(0.28, 0.56, 0.09)
    m.circle(0.72, 0.56, 0.09)
    m.line([(0.16, 0.82), (0.84, 0.82)], 0.07)


def pattern(m, d):
    m.rect(0.14, 0.14, 0.46, 0.46, 0.03)
    m.circle(0.7, 0.3, 0.16)
    m.circle(0.3, 0.7, 0.16)
    m.rect(0.54, 0.54, 0.86, 0.86, 0.03)


def vector(m, d):
    """a diagonal arrow: shaft and a head that points along it"""
    m.line([(0.2, 0.8), (0.58, 0.42)], 0.1)
    m.poly([(0.84, 0.16), (0.78, 0.52), (0.48, 0.22)])


def field(m, d):
    for r in (0.16, 0.3, 0.44):
        m.arc(0.5, 0.92, r, 200, 340, 0.07)
    m.circle(0.5, 0.82, 0.07)


def lens(m, d):
    m.ring(0.5, 0.5, 0.3, 0.1)
    m.circle(0.5, 0.5, 0.2)
    d.arc(0.5, 0.5, 0.2, 200, 280, 0.05)


def codec(m, d):
    m.rect(0.12, 0.2, 0.88, 0.8, 0.06)
    m.rect(0.2, 0.28, 0.8, 0.72, 0.03, on=False)
    m.line([(0.26, 0.5), (0.36, 0.5), (0.42, 0.36), (0.52, 0.64), (0.6, 0.42), (0.66, 0.5), (0.74, 0.5)], 0.045)


def harmonic(m, d):
    pts = [(0.1 + 0.8 * i / 24, 0.5 - 0.26 * math.sin(i / 24 * math.pi * 4)) for i in range(25)]
    m.line(pts, 0.09)


def ledger(m, d):
    m.rect(0.14, 0.14, 0.86, 0.86, 0.05)
    d.line([(0.5, 0.2), (0.5, 0.8)], 0.035)
    for y in (0.34, 0.5, 0.66):
        d.line([(0.22, y), (0.44, y)], 0.04)
        d.line([(0.56, y), (0.78, y)], 0.04)


def cipher(m, d):
    m.circle(0.3, 0.38, 0.2)
    m.circle(0.3, 0.38, 0.09, on=False)
    m.rect(0.44, 0.34, 0.9, 0.44, 0.03)
    m.rect(0.72, 0.44, 0.82, 0.62, 0.02)
    m.rect(0.58, 0.44, 0.66, 0.56, 0.02)


def orbit(m, d):
    m.ring(0.5, 0.5, 0.32, 0.07)
    m.circle(0.5, 0.5, 0.13)
    m.circle(0.82, 0.5, 0.075)


def thread(m, d):
    """a spool of thread: two flanges and wound thread between them"""
    m.rect(0.2, 0.16, 0.8, 0.28, 0.04)
    m.rect(0.2, 0.72, 0.8, 0.84, 0.04)
    m.rect(0.3, 0.28, 0.7, 0.72, 0.02)
    for y in (0.36, 0.46, 0.56, 0.66):
        d.line([(0.3, y + 0.04), (0.7, y - 0.04)], 0.035)

def index(m, d):
    m.rect(0.14, 0.14, 0.78, 0.86, 0.05)
    for i, y in enumerate((0.2, 0.4, 0.6)):
        m.rect(0.78, y, 0.9, y + 0.14, 0.02)
    for y in (0.34, 0.5, 0.66):
        d.line([(0.24, y), (0.66, y)], 0.04)


NOUNS = {
    "Loom": loom, "Anvil": anvil, "Spindle": spindle, "Kiln": kiln, "Array": array, "Engine": engine, "Well": well,
    "Core": core, "Lattice": lattice, "Dynamo": dynamo, "Press": press, "Sieve": sieve, "Relay": relay, "Crown": crown,
    "Gate": gate, "Heart": heart, "Spire": spire, "Forge": forge, "Drive": drive, "Matrix": matrix,
    "Manifold": manifold, "Circuit": circuit, "Protocol": protocol, "Doctrine": doctrine, "Axiom": axiom,
    "Theorem": theorem, "Pattern": pattern, "Vector": vector, "Field": field, "Lens": lens, "Codec": codec,
    "Harmonic": harmonic, "Ledger": ledger, "Cipher": cipher, "Orbit": orbit, "Thread": thread, "Index": index,
}

# ---------------------------------------------------------------------------------- modifier emblems
# drawn in the middle of the unit square, inside a radius of ~0.3, bold enough to read at 36 px


def spiral(m):
    pts = [(0.5 + (0.04 + 0.26 * t) * math.cos(t * 9), 0.5 + (0.04 + 0.26 * t) * math.sin(t * 9)) for t in [i / 40 for i in range(41)]]
    m.line(pts, 0.085)


def tri_dots(m):
    for x, y in ((0.5, 0.3), (0.34, 0.62), (0.66, 0.62)):
        m.circle(x, y, 0.11)


def helix(m):
    a = [(0.3 + 0.4 * i / 20, 0.5 + 0.2 * math.sin(i / 20 * math.pi * 2)) for i in range(21)]
    b = [(0.3 + 0.4 * i / 20, 0.5 - 0.2 * math.sin(i / 20 * math.pi * 2)) for i in range(21)]
    m.line(a, 0.08)
    m.line(b, 0.08)


def burst8(m):
    m.star(0.5, 0.5, 0.34, 0.11, 8, -90)


def plusminus(m):
    m.line([(0.3, 0.36), (0.5, 0.36)], 0.09)
    m.line([(0.4, 0.26), (0.4, 0.46)], 0.09)
    m.line([(0.52, 0.66), (0.72, 0.66)], 0.09)


def prism(m):
    m.poly([(0.5, 0.2), (0.78, 0.7), (0.22, 0.7)])
    m.poly([(0.5, 0.4), (0.62, 0.62), (0.38, 0.62)], on=False)


def void_ring(m):
    m.ring(0.5, 0.5, 0.22, 0.14)


def sun(m):
    m.circle(0.5, 0.5, 0.15)
    for i in range(8):
        a = math.radians(i * 45)
        m.line([(0.5 + 0.22 * math.cos(a), 0.5 + 0.22 * math.sin(a)), (0.5 + 0.34 * math.cos(a), 0.5 + 0.34 * math.sin(a))], 0.07)


def crescent(m):
    m.circle(0.48, 0.5, 0.3)
    m.circle(0.6, 0.44, 0.26, on=False)


def clock(m):
    m.ring(0.5, 0.5, 0.26, 0.09)
    m.line([(0.5, 0.5), (0.5, 0.32)], 0.07)
    m.line([(0.5, 0.5), (0.62, 0.56)], 0.07)


def pulse(m):
    m.line([(0.14, 0.52), (0.34, 0.52), (0.42, 0.3), (0.56, 0.72), (0.64, 0.52), (0.86, 0.52)], 0.07)


def nodes(m):
    pts = [(0.5, 0.26), (0.28, 0.68), (0.72, 0.68)]
    m.line(pts + [pts[0]], 0.05)
    for x, y in pts:
        m.circle(x, y, 0.1)


def bolt(m):
    m.poly([(0.56, 0.12), (0.3, 0.54), (0.48, 0.54), (0.42, 0.88), (0.72, 0.44), (0.52, 0.44), (0.62, 0.12)])


def halo(m):
    m.ring(0.5, 0.34, 0.2, 0.07)
    m.circle(0.5, 0.68, 0.14)


def rift(m):
    m.line([(0.62, 0.1), (0.4, 0.4), (0.6, 0.5), (0.36, 0.9)], 0.09)


def storm(m):
    m.circle(0.36, 0.46, 0.15)
    m.circle(0.56, 0.4, 0.19)
    m.circle(0.7, 0.5, 0.13)
    m.rect(0.3, 0.46, 0.76, 0.62, 0.05)
    m.poly([(0.54, 0.62), (0.44, 0.78), (0.52, 0.78), (0.46, 0.92), (0.64, 0.72), (0.56, 0.72), (0.62, 0.62)])


def flame(m):
    m.circle(0.5, 0.62, 0.22)
    m.poly([(0.5, 0.1), (0.7, 0.5), (0.3, 0.5)])


def snow(m):
    for a in (0, 60, 120):
        r = math.radians(a)
        m.line([(0.5 - 0.3 * math.cos(r), 0.5 - 0.3 * math.sin(r)), (0.5 + 0.3 * math.cos(r), 0.5 + 0.3 * math.sin(r))], 0.075)


def diamond(m):
    m.poly([(0.5, 0.14), (0.8, 0.5), (0.5, 0.86), (0.2, 0.5)])
    m.poly([(0.5, 0.3), (0.62, 0.5), (0.5, 0.7), (0.38, 0.5)], on=False)


def hexnut(m):
    m.ngon(0.5, 0.5, 0.34, 6, -90)
    m.circle(0.5, 0.5, 0.12, on=False)


def star5(m):
    m.star(0.5, 0.52, 0.36, 0.15, 5)


def myth(m):
    """a star inside a ring"""
    m.ring(0.5, 0.5, 0.34, 0.07)
    m.star(0.5, 0.52, 0.2, 0.085, 5)


def omega(m):
    m.arc(0.5, 0.46, 0.24, 140, 400, 0.09)
    m.line([(0.22, 0.78), (0.38, 0.78), (0.34, 0.66)], 0.08)
    m.line([(0.78, 0.78), (0.62, 0.78), (0.66, 0.66)], 0.08)


def sigma(m):
    m.line([(0.74, 0.22), (0.3, 0.22), (0.54, 0.5), (0.3, 0.78), (0.74, 0.78)], 0.09)


def delta(m):
    m.poly([(0.5, 0.14), (0.86, 0.8), (0.14, 0.8)])
    m.poly([(0.5, 0.38), (0.68, 0.7), (0.32, 0.7)], on=False)


def sparkle4(m):
    m.sparkle(0.5, 0.5, 0.38)


def orbit_ring(m):
    m.ring(0.5, 0.5, 0.28, 0.07)
    m.circle(0.5, 0.5, 0.1)
    m.circle(0.78, 0.5, 0.07)


def puff(m):
    m.circle(0.34, 0.58, 0.16)
    m.circle(0.52, 0.46, 0.2)
    m.circle(0.68, 0.6, 0.15)
    m.rect(0.3, 0.58, 0.74, 0.74, 0.05)


def ray(m):
    m.line([(0.18, 0.82), (0.7, 0.3)], 0.09)
    m.sparkle(0.74, 0.26, 0.18)


def gravity(m):
    m.line([(0.5, 0.14), (0.5, 0.6)], 0.09)
    m.poly([(0.3, 0.52), (0.7, 0.52), (0.5, 0.78)])
    m.line([(0.22, 0.88), (0.78, 0.88)], 0.08)


def arc_seg(m):
    m.arc(0.5, 0.64, 0.34, 200, 340, 0.1)


def rune(m):
    m.line([(0.42, 0.12), (0.42, 0.88)], 0.09)
    m.line([(0.42, 0.34), (0.74, 0.18)], 0.08)
    m.line([(0.42, 0.52), (0.74, 0.36)], 0.08)


def gem(m):
    m.ngon(0.5, 0.5, 0.34, 6, -90)
    m.line([(0.5, 0.18), (0.5, 0.5)], 0.05, on=False)
    m.line([(0.22, 0.34), (0.5, 0.5), (0.78, 0.34)], 0.05, on=False)


def plasma(m):
    m.circle(0.5, 0.5, 0.16)
    for a in range(0, 360, 90):
        r = math.radians(a + 45)
        m.circle(0.5 + 0.3 * math.cos(r), 0.5 + 0.3 * math.sin(r), 0.075)

def block(m):
    m.rect(0.2, 0.52, 0.8, 0.84, 0.04)
    m.rect(0.3, 0.2, 0.7, 0.5, 0.04)


def echo(m):
    for r in (0.12, 0.24, 0.36):
        m.arc(0.3, 0.5, r, -50, 50, 0.07)


def waves(m):
    for y in (0.34, 0.54, 0.74):
        m.line([(0.16 + 0.68 * i / 12, y + 0.06 * math.sin(i / 12 * math.pi * 3)) for i in range(13)], 0.07)


def spark(m):
    for a in range(0, 360, 45):
        r = math.radians(a)
        m.line([(0.5 + 0.1 * math.cos(r), 0.5 + 0.1 * math.sin(r)), (0.5 + 0.3 * math.cos(r), 0.5 + 0.3 * math.sin(r))], 0.07)


def hammer(m):
    m.rect(0.2, 0.2, 0.74, 0.42, 0.04)
    m.rect(0.42, 0.42, 0.54, 0.88, 0.03)


def stars3(m):
    for x, y, r in ((0.5, 0.28, 0.16), (0.3, 0.64, 0.14), (0.7, 0.64, 0.14)):
        m.star(x, y, r, r * 0.45, 5)


# study modifiers
def folded(m):
    m.poly([(0.2, 0.2), (0.62, 0.2), (0.8, 0.38), (0.8, 0.8), (0.2, 0.8)])
    m.poly([(0.62, 0.2), (0.62, 0.38), (0.8, 0.38)], on=False)


def silent(m):
    m.ring(0.5, 0.5, 0.26, 0.09)
    m.line([(0.3, 0.7), (0.7, 0.3)], 0.09)


def bound(m):
    m.ring(0.36, 0.5, 0.18, 0.08)
    m.ring(0.64, 0.5, 0.18, 0.08)


def hollow(m):
    m.rect(0.2, 0.2, 0.8, 0.8, 0.1)
    m.rect(0.3, 0.3, 0.7, 0.7, 0.05, on=False)


def rays(m):
    for i in range(6):
        a = math.radians(i * 60 - 90)
        m.line([(0.5, 0.5), (0.5 + 0.34 * math.cos(a), 0.5 + 0.34 * math.sin(a))], 0.08)
    m.circle(0.5, 0.5, 0.1)


def prime(m):
    m.poly([(0.5, 0.14), (0.78, 0.5), (0.5, 0.86), (0.22, 0.5)])


def chev_down(m):
    m.line([(0.24, 0.3), (0.5, 0.54), (0.76, 0.3)], 0.1)
    m.line([(0.24, 0.52), (0.5, 0.76), (0.76, 0.52)], 0.1)


def chev_up(m):
    m.line([(0.24, 0.7), (0.5, 0.46), (0.76, 0.7)], 0.1)
    m.line([(0.24, 0.48), (0.5, 0.24), (0.76, 0.48)], 0.1)


def nested(m):
    m.rect(0.18, 0.18, 0.82, 0.82, 0.04)
    m.rect(0.3, 0.3, 0.7, 0.7, 0.02, on=False)
    m.rect(0.4, 0.4, 0.6, 0.6, 0.02)


def outward(m):
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        m.line([(0.5 + 0.1 * dx, 0.5 + 0.1 * dy), (0.5 + 0.3 * dx, 0.5 + 0.3 * dy)], 0.08)
        m.poly([(0.5 + 0.34 * dx, 0.5 + 0.34 * dy), (0.5 + 0.34 * dx - 0.14 * dx, 0.5 + 0.34 * dy), (0.5 + 0.34 * dx, 0.5 + 0.34 * dy - 0.14 * dy)])


def check(m):
    m.line([(0.24, 0.54), (0.44, 0.74), (0.78, 0.3)], 0.11)


def leaf(m):
    m.poly([(0.2, 0.8), (0.3, 0.3), (0.7, 0.18), (0.82, 0.2), (0.78, 0.6), (0.4, 0.82)])
    m.line([(0.2, 0.8), (0.62, 0.38)], 0.04, on=False)


def blade(m):
    m.poly([(0.5, 0.08), (0.64, 0.7), (0.5, 0.9), (0.36, 0.7)])


def expand(m):
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        m.line([(0.5 + 0.34 * dx, 0.5 + 0.18 * dy), (0.5 + 0.34 * dx, 0.5 + 0.34 * dy), (0.5 + 0.18 * dx, 0.5 + 0.34 * dy)], 0.08)


def fine(m):
    for y in (0.3, 0.5, 0.7):
        m.line([(0.2, y), (0.8, y)], 0.06)


def dark(m):
    m.circle(0.5, 0.5, 0.3)


def sparkle_b(m):
    m.sparkle(0.46, 0.54, 0.3)
    m.sparkle(0.74, 0.28, 0.13)


def swift(m):
    m.line([(0.2, 0.3), (0.44, 0.5), (0.2, 0.7)], 0.1)
    m.line([(0.5, 0.3), (0.74, 0.5), (0.5, 0.7)], 0.1)


def still(m):
    m.rect(0.28, 0.24, 0.42, 0.76, 0.03)
    m.rect(0.58, 0.24, 0.72, 0.76, 0.03)


def live(m):
    m.circle(0.5, 0.5, 0.1)
    for r in (0.22, 0.34):
        m.arc(0.5, 0.5, r, -40, 40, 0.07)
        m.arc(0.5, 0.5, r, 140, 220, 0.07)


# machine modifiers in the order the generator lists them, then study modifiers
MARKS = {
    "Aether": spiral, "Quark": tri_dots, "Helix": helix, "Nova": burst8, "Ion": plusminus, "Prism": prism, "Void": void_ring,
    "Solar": sun, "Lunar": crescent, "Chrono": clock, "Pulse": pulse, "Nexus": nodes, "Flux": bolt, "Halo": halo,
    "Rift": rift, "Storm": storm, "Ember": flame, "Frost": snow, "Glass": diamond, "Iron": hexnut, "Myth": myth,
    "Omega": omega, "Sigma": sigma, "Delta": delta, "Astra": sparkle4, "Cosmo": orbit_ring, "Nebula": puff,
    "Photon": ray, "Grav": gravity, "Arc": arc_seg, "Rune": rune, "Crystal": gem, "Plasma": plasma, "Titan": block,
    "Echo": echo, "Drift": waves, "Spark": spark, "Forge": hammer, "Star": star5, "Night": stars3,
    "Folded": folded, "Silent": silent, "Bound": bound, "Hollow": hollow, "Lucent": rays, "Prime": prime,
    "Deep": chev_down, "High": chev_up, "Inner": nested, "Outer": outward, "True": check, "Wild": leaf, "Keen": blade,
    "Vast": expand, "Fine": fine, "Dark": dark, "Bright": sparkle_b, "Swift": swift, "Still": still, "Live": live,
}
