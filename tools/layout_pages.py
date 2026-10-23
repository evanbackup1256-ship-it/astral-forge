"""Per-page composition inputs for layout-verify.py; heights are the TSX constants for each
viewport (see docs/layout-specs/<page>.md). Browse bar height is the Browse kit's value
(~96 wide / ~136 stacked, estimated)."""
import math

def boosts(v):
    stack = v["stack"] and not v["landscape"]; w = v["w"]
    cols = 1 if stack else 4 if w >= 1500 else 3 if w >= 1000 else 2
    rows = math.ceil(12 / cols)
    return dict(hero=[260 if stack else 182, 128 if stack else 60],
                primary=[136 if v["stack"] else 96, rows * (196 + 10)])

def research(v):
    hero_stack = v["stack"] and not v["landscape"]; row_stack = v["stack"] and not v["landscape"]
    stride = (190 if row_stack else 116) + 22
    return dict(hero=[208 if hero_stack else 128, 164 if hero_stack else 96], primary=[24 * stride])

PAGES = {"Boosts": boosts, "Research": research}
