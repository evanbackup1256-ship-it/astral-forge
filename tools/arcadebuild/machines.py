"""Purpose: Original reel cabinet, coin-toss rig and dual-die launch chamber.
Owner: Astral Forge art. Dependencies: geometry, Blender. Last-reviewed: 2026-10-05.
"""
import math

from geometry import beam, box, cylinder, ring, sphere, text


def slots() -> None:
    box("Cabinet shell", (0, 0, 2.6), (3.6, 1.8, 4.8), "night", 0.20, metal=True)
    box("Foot pedestal", (0, 0, 0.3), (3.9, 2.2, 0.45), "graphite", 0.12, metal=True)
    box("Front bezel", (0, -0.96, 2.8), (3.28, 0.18, 2.10), "brass", 0.12, metal=True)
    box("Reel recess", (0, -1.07, 2.8), (2.95, 0.15, 1.80), "ink", 0.08)
    for index in range(3):
        x = (index - 1) * 0.95
        cylinder(f"Reel {index + 1}", (x, -0.85, 2.8), 0.63, 0.73, "cream",
                 rotation=(0, math.pi / 2, 0), group=f"Reel{index + 1}")
        for symbol in range(6):
            angle = symbol * math.tau / 6
            sphere(f"Reel {index + 1} jewel {symbol}", (x, -0.85 - math.cos(angle) * 0.65, 2.8 + math.sin(angle) * 0.65),
                   0.13, ("coral", "cyan", "mint", "violet", "mango", "pink")[symbol], group=f"Reel{index + 1}")
        ring(f"Reel {index + 1} flange", (x + 0.38, -0.85, 2.8), 0.64, 0.025, "brass", rotation=(0, math.pi / 2, 0), group=f"Reel{index + 1}")
    for x in (-1.65, 1.65):
        beam("Cabinet edge light", (x, -1.04, 0.9), (x, -1.04, 4.5), 0.035, "cyan", glow=True)
    box("Marquee", (0, -1.01, 4.44), (2.7, 0.18, 0.58), "panelRaised", 0.08)
    text("Reel Match wordmark", "REEL MATCH", (0, -1.12, 4.44), 0.30, "cream")
    beam("Payline", (-1.35, -1.16, 2.8), (1.35, -1.16, 2.8), 0.025, "mango", glow=True)
    box("Console ledge", (0, -1.14, 1.0), (3.2, 0.6, 0.27), "steel", 0.07, metal=True)
    cylinder("Spin button", (0.9, -1.18, 1.20), 0.23, 0.12, "mint")
    text("Free play plaque", "SCORE ONLY", (-0.40, -1.40, 1.08), 0.15, "ink")
    cylinder("Lever socket", (2.05, 0, 2.4), 0.23, 0.35, "brass", rotation=(0, math.pi / 2, 0))
    beam("Lever stem", (2.12, 0, 2.4), (2.12, -0.3, 3.7), 0.065, "steel", group="Lever")
    sphere("Lever handle", (2.12, -0.3, 3.7), 0.23, "coral", group="Lever")


def coin() -> None:
    cylinder("Toss pedestal", (0, 0, 0.22), 1.9, 0.42, "graphite", metal=True)
    ring("Pedestal halo", (0, 0, 0.48), 1.65, 0.04, "brass")
    for x in (-1.7, 1.7):
        beam("Launch arch upright", (x, 0.35, 0.5), (x, 0.35, 3.4), 0.10, "steel")
    beam("Launch arch crown", (-1.7, 0.35, 3.4), (1.7, 0.35, 3.4), 0.10, "brass")
    cylinder("Coin milled body", (0, -0.1, 2.0), 0.80, 0.13, "brass", rotation=(math.pi / 2, 0, 0), metal=True, group="Coin")
    ring("Coin front rim", (0, -0.18, 2.0), 0.72, 0.028, "cream", rotation=(math.pi / 2, 0, 0), group="Coin")
    for index in range(24):
        angle = math.tau * index / 24
        sphere("Coin rim tooth", (math.cos(angle) * 0.78, -0.1, 2 + math.sin(angle) * 0.78), 0.032, "brassDeep", group="Coin")
    text("Coin heads relief", "A", (0, -0.185, 2.0), 0.68, "brassDeep", group="Coin")
    text("Toss label", "COIN TOSS", (0, -1.6, 0.5), 0.26, "cream", rotation=(0, 0, 0))


def dice() -> None:
    box("Dice chamber deck", (0, 0, 0.22), (4.6, 3.4, 0.42), "graphite", 0.18, metal=True)
    box("Landing felt", (0, 0, 0.46), (4.10, 2.9, 0.04), "violet", 0.09)
    for x in (-2.25, 2.25):
        box("Side bumper", (x, 0, 0.7), (0.18, 3.4, 0.55), "steel", 0.07, metal=True)
    for y in (-1.6, 1.6):
        box("End bumper", (0, y, 0.7), (4.4, 0.18, 0.55), "brass", 0.07, metal=True)
    pips = ((-0.22, -0.22), (0.22, -0.22), (-0.22, 0.22), (0.22, 0.22), (0, 0))
    for index, x in enumerate((-0.85, 0.85)):
        box("Ivory die", (x, 0, 1.05), (0.86, 0.86, 0.86), "cream", 0.10, group=f"Die{index + 1}")
        for px, py in pips[:3 if index == 0 else 5]:
            sphere("Die top pip", (x + px, py, 1.493), 0.06, "ink", group=f"Die{index + 1}")
        for px, pz in ((-0.22, -0.22), (0.22, 0.22)):
            sphere("Die front pip", (x + px, -0.445, 1.05 + pz), 0.06, "ink", group=f"Die{index + 1}")
    text("Dice chamber label", "DICE MATCH", (0, -1.72, 0.70), 0.25, "cream")
