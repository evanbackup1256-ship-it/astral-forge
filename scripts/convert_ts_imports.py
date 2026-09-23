"""
convert_ts_imports.py
---------------------
Strips all TS.import / local TS = require(RuntimeLib) patterns from every
.luau file under src/Client and replaces them with native Luau require() calls.
"""

import re
import os
import sys

ROOT = r"src\Client"

# ─── Replacement helpers ───────────────────────────────────────────────────────

RS_PREFIX = r"""TS\.import\(\s*script\s*,\s*game:GetService\(["']ReplicatedStorage["']\)\s*,\s*["']rbxts_include["']\s*,\s*["']node_modules["']\s*,\s*["']@rbxts["']\s*,\s*"""

SIBLING_PARENT  = r"""TS\.import\(\s*script\s*,\s*script\.Parent\s*,\s*["']([^"']+)["']\s*\)"""
SIBLING_GPARENT = r"""TS\.import\(\s*script\s*,\s*script\.Parent\.Parent\s*,\s*["']([^"']+)["']\s*\)"""
GENERIC_PKG     = RS_PREFIX + r"""["']([^"']+)["']\s*\)"""
LAYOUTUTIL_SRC  = RS_PREFIX + r"""["']layoututil["']\s*,\s*["']src["']\s*\)"""

def rs_node(pkg):
    if '-' in pkg:
        return f'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["{pkg}"])'
    return f'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].{pkg})'

SERVICES_TABLE = (
    '{ '
    'Players = game:GetService("Players"), '
    'RunService = game:GetService("RunService"), '
    'UserInputService = game:GetService("UserInputService"), '
    'GuiService = game:GetService("GuiService"), '
    'TextService = game:GetService("TextService"), '
    'TweenService = game:GetService("TweenService"), '
    'SoundService = game:GetService("SoundService"), '
    'MarketplaceService = game:GetService("MarketplaceService"), '
    'ContextActionService = game:GetService("ContextActionService"), '
    'HttpService = game:GetService("HttpService"), '
    'Workspace = game:GetService("Workspace"), '
    'ReplicatedStorage = game:GetService("ReplicatedStorage"), '
    'VirtualInputManager = game:GetService("VirtualInputManager") '
    '}'
)

def convert(content: str) -> str:
    # 1. Remove RuntimeLib TS declaration
    content = re.sub(
        r'local TS = require\(game:GetService\(["\']ReplicatedStorage["\']\):WaitForChild\(["\']rbxts_include["\']\):WaitForChild\(["\']RuntimeLib["\']\)\)\r?\n',
        '',
        content
    )

    # 2. React
    content = re.sub(
        RS_PREFIX + r'["\'](react)["\']\s*\)',
        rs_node('react'),
        content
    )

    # 3. ReactRoblox
    content = re.sub(
        RS_PREFIX + r'["\'](react-roblox)["\']\s*\)',
        rs_node('react-roblox'),
        content
    )

    # 4. @rbxts/services  →  inline services table
    content = re.sub(
        RS_PREFIX + r'["\'](services)["\']\s*\)',
        SERVICES_TABLE,
        content
    )

    # 5. layoututil/src (before generic catch-all)
    content = re.sub(
        LAYOUTUTIL_SRC,
        'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].layoututil.src)',
        content
    )

    # 6. Generic @rbxts/<pkg>
    def generic_replace(m):
        return rs_node(m.group(1))
    content = re.sub(GENERIC_PKG, generic_replace, content)

    # 7. script.Parent.Parent sibling
    content = re.sub(
        SIBLING_GPARENT,
        lambda m: f'require(script.Parent.Parent.{m.group(1)})',
        content
    )

    # 8. script.Parent sibling
    content = re.sub(
        SIBLING_PARENT,
        lambda m: f'require(script.Parent.{m.group(1)})',
        content
    )

    # A service import may be immediately indexed (for example,
    # `TS.import(..., "services").SoundService`). Replacing the import with
    # a table literal leaves invalid Luau (`{ ... }.SoundService`), so collapse
    # that specific form to a direct service lookup.
    service_access = re.compile(
        r'local\s+(\w+)\s*=\s*' + re.escape(SERVICES_TABLE) + r'\.(\w+)'
    )
    content = service_access.sub(
        lambda m: f'local {m.group(1)} = game:GetService("{m.group(2)}")',
        content
    )

    return content

# ─── Main ─────────────────────────────────────────────────────────────────────

converted = 0
warnings  = 0

for dirpath, _dirnames, filenames in os.walk(ROOT):
    for fname in filenames:
        if not fname.endswith('.luau'):
            continue
        fpath = os.path.join(dirpath, fname)
        with open(fpath, 'r', encoding='utf-8') as f:
            original = f.read()
        if 'TS.import' not in original:
            continue

        result = convert(original)

        remaining = re.findall(r'TS\.import', result)
        if remaining:
            print(f'[WARN] {fname} — {len(remaining)} TS.import call(s) remain, manual review needed')
            warnings += 1

        if result != original:
            with open(fpath, 'w', encoding='utf-8', newline='') as f:
                f.write(result)
            print(f'[OK]   {fname}')
            converted += 1

print(f'\nDone. Converted: {converted}  |  Warnings: {warnings}')
