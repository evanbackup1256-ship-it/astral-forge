<#
  convert_ts_imports.ps1
  ----------------------
  Strips all TS.import / local TS = require(RuntimeLib) patterns from every
  .luau file under src\Client and replaces them with native Luau require() calls.

  Patterns handled:
    1. `local TS = require(game:GetService("ReplicatedStorage"):WaitForChild(...)` → DELETED
    2. TS.import(script, game:GetService("RS"), ..., "react")           → require node_modules path
    3. TS.import(script, game:GetService("RS"), ..., "react-roblox")
    4. TS.import(script, game:GetService("RS"), ..., "services")        → game:GetService() inline
    5. TS.import(script, game:GetService("RS"), ..., "layoututil", "src")
    6. TS.import(script, game:GetService("RS"), ..., "<pkg>")           → generic node_modules path
    7. TS.import(script, script.Parent, "name")                         → require(script.Parent.name)
    8. TS.import(script, script.Parent.Parent, "name")                  → require(script.Parent.Parent.name)
#>

$ErrorActionPreference = "Stop"
$root = "src\Client"
$files = Get-ChildItem -Path $root -Recurse -Filter "*.luau" | Where-Object {
    (Select-String -Path $_.FullName -Pattern "TS\.import" -Quiet)
}

$converted = 0
$skipped   = 0

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8

    # ── 1. Remove the RuntimeLib TS declaration line ─────────────────────────
    $content = $content -replace `
        'local TS = require\(game:GetService\("ReplicatedStorage"\):WaitForChild\("rbxts_include"\):WaitForChild\("RuntimeLib"\)\)\r?\n', `
        ''
    $content = $content -replace `
        'local TS = require\(game:GetService\(\"ReplicatedStorage\"\):WaitForChild\(\"rbxts_include\"\):WaitForChild\(\"RuntimeLib\"\)\)\r?\n', `
        ''

    # ── 2. React package ─────────────────────────────────────────────────────
    $reactPath = 'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)'
    $content = $content -replace `
        'TS\.import\(script,\s*game:GetService\(["\']ReplicatedStorage["\']\),\s*["\']rbxts_include["\'],\s*["\']node_modules["\'],\s*["\']@rbxts["\'],\s*["\']react["\']\)', `
        $reactPath

    # ── 3. ReactRoblox package ───────────────────────────────────────────────
    $reactRobloxPath = 'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])'
    $content = $content -replace `
        'TS\.import\(script,\s*game:GetService\(["\']ReplicatedStorage["\']\),\s*["\']rbxts_include["\'],\s*["\']node_modules["\'],\s*["\']@rbxts["\'],\s*["\']react-roblox["\']\)', `
        $reactRobloxPath

    # ── 4. @rbxts/services → inline game:GetService ─────────────────────────
    #    Pattern: local _services = TS.import(... "services")
    #    Then:    local Foo = _services.Foo
    #    Replace the import with a services table and keep destructuring lines.
    #    Safest: replace the TS.import call itself with an inline table of common services.
    $content = $content -replace `
        'TS\.import\(script,\s*game:GetService\(["\']ReplicatedStorage["\']\),\s*["\']rbxts_include["\'],\s*["\']node_modules["\'],\s*["\']@rbxts["\'],\s*["\']services["\']\)', `
        '{ Players = game:GetService("Players"), RunService = game:GetService("RunService"), UserInputService = game:GetService("UserInputService"), GuiService = game:GetService("GuiService"), TextService = game:GetService("TextService"), TweenService = game:GetService("TweenService"), SoundService = game:GetService("SoundService"), MarketplaceService = game:GetService("MarketplaceService"), ContextActionService = game:GetService("ContextActionService"), HttpService = game:GetService("HttpService"), Workspace = game:GetService("Workspace"), ReplicatedStorage = game:GetService("ReplicatedStorage"), VirtualInputManager = game:GetService("VirtualInputManager") }'

    # ── 5. layoututil/src ────────────────────────────────────────────────────
    $content = $content -replace `
        'TS\.import\(script,\s*game:GetService\(["\']ReplicatedStorage["\']\),\s*["\']rbxts_include["\'],\s*["\']node_modules["\'],\s*["\']@rbxts["\'],\s*["\']layoututil["\'],\s*["\']src["\']\)', `
        'require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].layoututil.src)'

    # ── 6. Generic @rbxts/<pkg> catch-all ───────────────────────────────────
    # Matches: TS.import(script, game:GetService("RS"), "rbxts_include", "node_modules", "@rbxts", "pkgname")
    $content = [regex]::Replace($content,
        'TS\.import\(script,\s*game:GetService\(["\''](ReplicatedStorage)["\']\),\s*["\''](rbxts_include)["\''],\s*["\''](node_modules)["\''],\s*["\''](@rbxts)["\''],\s*["\'']([^"\']+)["\']\)',
        { param($m)
            $pkg = $m.Groups[5].Value
            # Packages with hyphens need bracket notation
            if ($pkg -match '-') {
                return ('require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["' + $pkg + '"])')
            } else {
                return ('require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].' + $pkg + ')')
            }
        }
    )

    # ── 7. script.Parent.Parent sibling imports ──────────────────────────────
    $content = [regex]::Replace($content,
        'TS\.import\(script,\s*script\.Parent\.Parent,\s*["\'']([^"\']+)["\']\)',
        { param($m) 'require(script.Parent.Parent.' + $m.Groups[1].Value + ')' }
    )

    # ── 8. script.Parent sibling imports ────────────────────────────────────
    $content = [regex]::Replace($content,
        'TS\.import\(script,\s*script\.Parent,\s*["\'']([^"\']+)["\']\)',
        { param($m) 'require(script.Parent.' + $m.Groups[1].Value + ')' }
    )

    # A service import may be immediately indexed, which otherwise becomes
    # invalid Luau such as `{ ... }.SoundService` after the table substitution.
    $content = [regex]::Replace($content,
        '(?m)^(\s*local\s+)(\w+)\s*=\s*\{\s*Players\s*=\s*game:GetService\("Players"\).*?\}\.(\w+)\s*$',
        { param($m) $m.Groups[1].Value + $m.Groups[2].Value + ' = game:GetService("' + $m.Groups[3].Value + '")' }
    )

    # ── 9. Verify no TS.import calls remain ──────────────────────────────────
    $remaining = [regex]::Matches($content, 'TS\.import')
    if ($remaining.Count -gt 0) {
        Write-Warning "[$($file.Name)] $($remaining.Count) TS.import call(s) NOT converted — manual review needed"
        $skipped++
    }

    # ── 10. Write back ───────────────────────────────────────────────────────
    [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
    Write-Host "[OK] $($file.Name)" -ForegroundColor Green
    $converted++
}

Write-Host ""
Write-Host "Done. Converted: $converted  |  Warnings: $skipped" -ForegroundColor Cyan
