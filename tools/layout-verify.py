#!/usr/bin/env python3
"""Mirror of planComposition (src/Client/AstralForge/UiCore/layoutEngine.ts) for off-engine checks.
Usage: python3 tools/layout-verify.py  -> prints the zone table for each page spec at
1920x1080, 1366x768 and 844x390 and fails on overlap, overflow, ragged edges or uneven gutters."""
import math, sys

# content width = screen - nav rail - 2*pagePadding (CoreKit/mobileLayout.ts, CoreKit/theme.ts)
# minus SCAFFOLD_RESERVE (3px scrollbar + 8px gutter, pages/layoutRise.tsx): composeSection plans at that width
R = 11
VIEWPORTS = {"1920x1080": dict(w=1920 - 268 - 40 - R, stack=False, landscape=False, gap=18),
             "1366x768": dict(w=1366 - 268 - 40 - R, stack=False, landscape=False, gap=18),
             "844x390": dict(w=844 - 2 * 47 - 2 * 10 - R, stack=True, landscape=True, gap=10, fold=219)}
# 844x390: side inset 47 (notch) and the core-safe height (390 - 44 Roblox top bar) leave a ~219px
# content budget below the app top bar and above the tab bar (forge-ui-2 pass 2, P2.4)

def fit_columns(width, count, min_cell, max_cols=6, gap=10):
    usable = max(0, math.floor(width)); items = max(1, count); cap = max(1, min(max_cols, items))
    cols = min(max(math.floor((usable + gap) / (min_cell + gap)), 1), cap)
    rows = math.ceil(items / cols); ev = math.ceil(items / rows)
    if ev < cols and (usable - gap * (ev - 1)) / ev >= min_cell: cols = ev
    return cols

def stack(role, hs, x, y, w, gap, out):
    c = y
    for i, h in enumerate(hs):
        out.append(dict(role=role, i=i, x=x, y=c, w=w, h=max(0, h))); c += h + (gap if i < len(hs) - 1 else 0)
    return c

def tiles(hs, x, y, w, gap, s, out):
    n = len(hs)
    if not n: return y, 0
    cols = fit_columns(w, n, s.get("tileMin", 260), s.get("tileColumns", 4), gap); rows = math.ceil(n / cols); c = y
    for r in range(rows):
        inrow = min(cols, n - r * cols); rh = max(hs[r * cols:r * cols + inrow]); cw = (w - gap * (inrow - 1)) / inrow
        for k in range(inrow):
            left = math.floor(x + k * (cw + gap)); right = x + w if k == inrow - 1 else math.floor(x + (k + 1) * (cw + gap)) - gap
            out.append(dict(role="tiles", i=r * cols + k, x=left, y=c, w=right - left, h=rh))
        c += rh + (gap if r < rows - 1 else 0)
    return c, cols

def plan(width, gap, s):
    w = math.floor(width); R = []; hero = s.get("hero", []); sec = s.get("secondary", []); ti = s.get("tiles", []); foot = s.get("footer", [])
    split = bool(sec) and bool(s["primary"]) and w >= s.get("splitMin", 980); y = 0
    band = lambda b: b + gap if b > 0 else 0
    if hero: y = band(stack("hero", hero, 0, 0, w, gap, R))
    if split:
        sw = math.floor(min(max(w * s.get("secondaryRatio", 0.32), s.get("secondaryMin", 300)), min(s.get("secondaryMax", 520), w * 0.5)))
        mw = w - sw - gap; right = s.get("secondaryOnRight", True); mx = 0 if right else sw + gap; sx = mw + gap if right else 0
        mp, tp, sp = [], [], []
        me = stack("primary", s["primary"], mx, y, mw, gap, mp)
        if s.get("tilesInPrimary") and ti: me, _ = tiles(ti, mx, me + gap, mw, gap, s, tp)
        se = stack("secondary", sec, sx, y, sw, gap, sp); end = max(me, se)
        if se < end: sp[-1]["h"] += end - se
        elif me < end:
            last = tp or mp; ly = last[-1]["y"]
            for r in last:
                if r["y"] == ly: r["h"] += end - me
        R += mp + tp + sp; y = end + gap
    else:
        if s["primary"]: y = band(stack("primary", s["primary"], 0, y, w, gap, R))
        if sec: y = band(stack("secondary", sec, 0, y, w, gap, R))
    if ti and not (split and s.get("tilesInPrimary")):
        e, _ = tiles(ti, 0, y, w, gap, s, R); y = e + gap
    if foot: y = band(stack("footer", foot, 0, y, w, gap, R))
    return dict(w=w, h=max(0, y - gap), split=split, rects=R)

def check(name, vp, p, gap, min_h=40):
    errs = []; R = p["rects"]
    for a in R:
        if a["x"] < 0 or a["x"] + a["w"] > p["w"]: errs.append(f"overflow {a}")
        if a["h"] < min_h: errs.append(f"cramped {a['role']}{a['i']} h={a['h']}")
    for i, a in enumerate(R):
        for b in R[i + 1:]:
            if a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]:
                errs.append(f"overlap {a['role']}{a['i']} / {b['role']}{b['i']}")
            # horizontal neighbours on the same band must sit exactly one gutter apart
            if a["y"] == b["y"] and a["x"] != b["x"]:
                l, r = (a, b) if a["x"] < b["x"] else (b, a)
                if r["x"] - (l["x"] + l["w"]) != gap: errs.append(f"gutter {r['x'] - (l['x'] + l['w'])} != {gap} {l['role']}/{r['role']}")
    # outer edges: every band's right-most rect ends flush with the content width
    for y in {a["y"] for a in R}:
        row = [a for a in R if a["y"] == y]
        if max(a["x"] + a["w"] for a in row) != p["w"] and not any(a["role"] in ("primary", "secondary") for a in row):
            errs.append(f"ragged right edge at y={y}")
    return errs

def run(pages):
    bad = 0
    for name, fn in pages.items():
        print(f"\n## {name}")
        for vp, v in VIEWPORTS.items():
            s = fn(v); p = plan(v["w"], v["gap"], s); errs = check(name, vp, p, v["gap"])
            print(f"  {vp:9} width {p['w']:4}  split={str(p['split']):5} height {p['h']}" + (f"  fold {v['fold']}" if v.get('fold') else ""))
            for r in p["rects"]: print(f"    {r['role']:9}{r['i']:<2} x={r['x']:<5} y={r['y']:<5} w={r['w']:<5} h={r['h']}")
            for e in errs: print("    !!", e); bad += 1
    print("\nFAIL" if bad else "\nOK: no overlap, overflow, ragged edge or uneven gutter")
    return bad

if __name__ == "__main__":
    sys.path.insert(0, __file__.rsplit("/", 1)[0])
    from layout_pages import PAGES
    sys.exit(1 if run(PAGES) else 0)
