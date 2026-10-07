--!strict
-- Purpose: Verify the named palette against the pre-refactor source baseline and accessibility behavior.
-- Owner: Astral Forge verification. Dependencies: Lune fs/serde/luau/roblox. Last-reviewed: 2026-10-05.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
type Palette = { [string]: Color3 }
type Settings = { HighContrast: boolean, Colorblind: boolean }
type Theme = {
	Base: Palette,
	newPalette: () -> Palette,
	applyAccessibility: (Palette, Settings) -> (),
}
type ColorBaseline = { basePalette: { [string]: { number } } }

local factory: () -> Theme = luau.load(fs.readFile("src/Shared/AstralForge/Shared/ForgeTheme.luau"), {
	environment = { Color3 = roblox.Color3, table = table },
})
local theme: Theme = factory()
local baseline: ColorBaseline = serde.decode("json", fs.readFile("audit/baseline/color-inventory.json"))
local count = 0
for name, rgb in baseline.basePalette do
	count += 1
	assert(theme.Base[name] == roblox.Color3.fromRGB(rgb[1], rgb[2], rgb[3]), "palette drift: " .. name)
end
assert(count == 28)
local mutable: Palette = theme.newPalette()
mutable.cyan = roblox.Color3.fromRGB(1, 2, 3)
assert(mutable.cyan ~= theme.Base.cyan, "live accessibility palette must not mutate source colors")
local frozen = pcall(function(): ()
	theme.Base.cyan = mutable.cyan
end)
assert(not frozen, "the audited source palette must remain immutable")
theme.applyAccessibility(mutable, { Colorblind = true, HighContrast = false })
assert(mutable.cyan == theme.Base.cyan)
assert(mutable.mint == roblox.Color3.fromRGB(86, 180, 233))
assert(mutable.coral == roblox.Color3.fromRGB(230, 159, 0))
theme.applyAccessibility(mutable, { Colorblind = true, HighContrast = true })
assert(mutable.mint == roblox.Color3.fromRGB(86, 180, 233))
assert(mutable.panel == roblox.Color3.fromRGB(13, 10, 14))
theme.applyAccessibility(mutable, { Colorblind = false, HighContrast = false })
for name, color in theme.Base do
	assert(mutable[name] == color, "accessibility reset drift: " .. name)
end
print("[TEST] 28 audited palette colors, immutable baseline and accessibility composition/reset passed")
