"""
fix_remaining_ts_imports.py
----------------------------
Handles the remaining TS.import patterns that were not caught by the generic
single-segment @rbxts matcher.  Patterns:

  1. TS.import(script, script, "Name")             → require(script.Name)
  2. TS.import(script, script.Parent, "sub", "Name")  → require(script.Parent.sub.Name)
  3. Multi-segment @rbxts pkg:  "pkg", "sub"       → node_modules["@rbxts"].pkg.sub
  4. @flamework imports
  5. Strip leftover bare `local TS = ...` lines if any remain
"""

import re, os

FILES_DIR = r"src\Client"

# ─── Generic multi-segment node_modules path builder ─────────────────────────
# Matches:  TS.import(script, game:GetService("ReplicatedStorage"), "rbxts_include",
#           "node_modules", "@scope", "pkg", ["sub1", ["sub2"...]])
# Stops at the closing `)` — we capture all trailing string segments.
RS_MULTI = re.compile(
    r'''TS\.import\(\s*script\s*,\s*game:GetService\(["']ReplicatedStorage["']\)\s*,\s*["']rbxts_include["']\s*,\s*["']node_modules["']\s*,\s*["'](@[^"']+)["']\s*,\s*["']([^"']+)["']\s*((?:,\s*["'][^"']+["']\s*)*)\)''',
    re.DOTALL
)

def rs_multi_replace(m):
    scope = m.group(1)    # e.g. @rbxts or @flamework
    pkg   = m.group(2)    # e.g. flipper
    rest_raw = m.group(3) # e.g. , "src"  OR  , "core", "out"
    # parse trailing segments
    segs = re.findall(r'["\']([ ^"\']+)["\']', rest_raw)
    # Build path
    if '-' in pkg:
        path = f'require(game.ReplicatedStorage.rbxts_include.node_modules["{scope}"]["{pkg}"]'
    elif scope != '@rbxts':
        path = f'require(game.ReplicatedStorage.rbxts_include.node_modules["{scope}"].{pkg}'
    else:
        path = f'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].{pkg}'
    for seg in segs:
        path += f'.{seg}'
    path += ')'
    return path

# ─── script, script, "Name"  pattern ─────────────────────────────────────────
SELF_IMPORT = re.compile(
    r'''TS\.import\(\s*script\s*,\s*script\s*,\s*["']([^"']+)["']\s*\)'''
)

# ─── script.Parent, "folder", "Name" two-segment relative ────────────────────
PARENT_MULTI = re.compile(
    r'''TS\.import\(\s*script\s*,\s*(script\.Parent(?:\.Parent)?)\s*,\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*\)'''
)

# ─── Bare TS variable left-overs ──────────────────────────────────────────────
TS_DECL = re.compile(
    r'''local TS = require\(game:GetService\(["']ReplicatedStorage["']\):WaitForChild\(["']rbxts_include["']\):WaitForChild\(["']RuntimeLib["']\)\)\r?\n'''
)

def convert(content: str) -> str:
    # 0. remove any surviving TS declaration
    content = TS_DECL.sub('', content)

    # 1. Self-import: TS.import(script, script, "X")
    content = SELF_IMPORT.sub(
        lambda m: f'require(script.{m.group(1)})',
        content
    )

    # 2. Multi-segment relative: TS.import(script, script.Parent[.Parent], "folder", "Name")
    content = PARENT_MULTI.sub(
        lambda m: f'require({m.group(1)}.{m.group(2)}.{m.group(3)})',
        content
    )

    # 3. Multi-segment node_modules (handles @flamework, @rbxts with sub-paths)
    content = RS_MULTI.sub(rs_multi_replace, content)

    return content

converted = 0
warnings  = 0

for dirpath, _dirnames, filenames in os.walk(FILES_DIR):
    for fname in filenames:
        if not fname.endswith('.luau'):
            continue
        fpath = os.path.join(dirpath, fname)
        with open(fpath, 'r', encoding='utf-8') as f:
            original = f.read()
        if 'TS.import' not in original and 'local TS = ' not in original:
            continue

        result = convert(original)

        remaining = re.findall(r'TS\.import', result)
        if remaining:
            print(f'[WARN] {fname} — {len(remaining)} TS.import call(s) remain')
            warnings += 1

        if result != original:
            with open(fpath, 'w', encoding='utf-8', newline='') as f:
                f.write(result)
            print(f'[OK]   {fname}')
            converted += 1

print(f'\nDone. Converted: {converted}  |  Warnings: {warnings}')

