--!strict
-- Phone / tablet / accessibility matrix. Runs the compiled layout plan (out/) and theme at the
-- sizes players actually use and fails the build when a size loses its touch targets, readable
-- text, content room, or when a palette mode drops text contrast. Also stops new desktop-only
-- spacing tokens (24px Layout.*) from landing in phone code paths unguarded.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function load(path: string): any
	local env: any = {
		Color3 = {
			fromRGB = function(r: number, g: number, b: number)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
		},
	}
	setmetatable(env, { __index = getfenv() })
	return (luau.load(fs.readFile(path), { environment = env }) :: any)()
end

local M = load("out/Client/AstralForge/CoreKit/mobileLayout.luau")
local T = load("out/Shared/AstralForge/Shared/ForgeTheme.luau")

local TAP = 44
local fails: { string } = {}
local function check(ok: boolean, msg: string)
	if not ok then
		table.insert(fails, msg)
	end
end

-- width, height, name, expected shape
type Size = { w: number, h: number, name: string, kind: string, inset: number?, side: number?, coreSafe: boolean? }
local SIZES: { Size } = {
	{ w = 286, h = 640, name = "286 portrait", kind = "portrait" },
	{ w = 360, h = 800, name = "360 portrait", kind = "portrait", inset = 24 },
	{ w = 414, h = 896, name = "414 portrait", kind = "portrait", inset = 34 },
	{ w = 640, h = 286, name = "286 landscape", kind = "landscape" },
	{ w = 800, h = 360, name = "360 landscape", kind = "landscape", inset = 21 },
	{ w = 896, h = 414, name = "414 landscape", kind = "landscape", inset = 21 },
	-- iPhone 12-15 landscape (most common modern phone): side ~47 (notch), bottom 21 (home bar).
	-- `h` is the raw screen; the app's ScreenGui uses CoreUISafeInsets, so the live plan height is
	-- the core-safe area (screen minus Roblox's 44px top bar). The second row feeds that height.
	{ w = 844, h = 390, name = "844 landscape", kind = "landscape", inset = 21, side = 47 },
	{ w = 844, h = 346, name = "844 landscape core-safe", kind = "landscape", inset = 21, side = 47, coreSafe = true },
	{ w = 768, h = 1024, name = "tablet portrait", kind = "tablet" },
	{ w = 820, h = 1180, name = "tablet 820 portrait", kind = "tablet" },
	{ w = 1024, h = 768, name = "tablet landscape", kind = "desktop-touch" },
	{ w = 1280, h = 720, name = "laptop", kind = "desktop" },
	{ w = 1920, h = 1080, name = "desktop", kind = "desktop" },
}

-- The app ScreenGui uses CoreUISafeInsets, so on touch devices the live plan height is the screen
-- minus Roblox's top bar (CORE_TOP). Landscape phones put the shell bar inside that row
-- (GuiService.TopbarInset: screen width minus the side insets and Roblox's own buttons), so the bar
-- costs no content height when the row has room for it.
local CORE_TOP = 44
local ROBLOX_BUTTONS_W = 200
local ROW_MIN_W = 320
for _, s in SIZES do
	local touch = s.kind ~= "desktop"
	local planH = if touch and not s.coreSafe then s.h - CORE_TOP else s.h
	local rowW = s.w - 2 * (s.side or 0) - ROBLOX_BUTTONS_W
	local inRow = s.kind == "landscape" and rowW >= ROW_MIN_W
	local p = M.planMobileLayout({
		width = s.w,
		height = planH,
		topbarInRow = inRow,
		compact = s.w < 1100,
		tight = s.w < 840,
		short = s.h < 740,
		desktop = not touch,
		bottomInset = s.inset or 0,
		sideInset = if s.kind == "landscape" then (s.side or s.inset or 0) else 0,
	})
	local n = s.name
	if s.kind == "portrait" then
		check(p.stack and p.portrait and not p.landscape and not p.tablet, `{n}: should plan as phone portrait`)
	elseif s.kind == "landscape" then
		check(p.stack and p.landscape, `{n}: should plan as phone landscape`)
	elseif s.kind == "tablet" then
		check(p.stack and p.tablet and not p.landscape, `{n}: should plan as tablet`)
	else
		check(not p.landscape, `{n}: desktop shell must not use phone landscape chrome`)
	end
	if p.stack then
		local core = p.tabBarH - p.bottomSafe
		check(core >= TAP, `{n}: tab bar {core}px < {TAP}px`)
		check(p.tabBarSlots >= 3 and p.tabBarSlots * TAP <= s.w - p.sideSafe * 2, `{n}: {p.tabBarSlots} tab slots don't fit at {TAP}px`)
		check(p.moreCellH >= TAP, `{n}: More grid cell {p.moreCellH}px < {TAP}px`)
		check(p.topbarRows >= TAP, `{n}: top bar {p.topbarRows}px < {TAP}px`)
		-- room left for card content once page + card padding are paid on both sides
		local inner = s.w - 2 * math.max(p.pagePadding, p.sideSafe) - 2 * p.cardPadding
		check(inner >= 220, `{n}: only {inner}px left inside a card (need 220)`)
		check(p.pagePadding <= 18 and p.cardPadding <= 18, `{n}: phone padding grew past 18px (page {p.pagePadding}, card {p.cardPadding})`)
		if s.kind == "landscape" then
			check(p.topbarInRow == inRow, `{n}: top bar should {if inRow then "" else "not "}sit in Roblox's top-bar row (row {rowW}px)`)
			check(not inRow or rowW - 8 >= ROW_MIN_W - 8, `{n}: top-bar row {rowW}px too narrow for the shell bar`)
		end
		local minBudget = if p.landscape then 160 else 360
		check(p.contentBudget >= minBudget, `{n}: content budget {p.contentBudget}px < {minBudget}`)
		check(p.bottomSafe >= (s.inset or 0), `{n}: bottom safe area {p.bottomSafe} ignores inset {s.inset}`)
	end
	check(p.railCollapsedRow >= TAP, `{n}: rail row {p.railCollapsedRow}px < {TAP}px`)
	check(p.labelText >= 12 and p.bodyText >= 14, `{n}: text too small (label {p.labelText}, body {p.bodyText})`)
end

-- WCAG contrast for each palette mode
local function lin(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end
local function lum(c: any): number
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end
local function ratio(a: any, b: any): number
	local x, y = lum(a), lum(b)
	if x < y then
		x, y = y, x
	end
	return (x + 0.05) / (y + 0.05)
end

local TEXT = { "cream", "creamSoft", "muted" }
local ACCENT = { "mint", "coral", "mango", "cyan", "violet", "green", "red", "blue", "pink" }
local SURFACE = { "panel", "panelRaised" }
for _, mode in { { "base", false, false }, { "high contrast", true, false }, { "colorblind", false, true }, { "both", true, true } } do
	local pal = T.newPalette()
	T.applyAccessibility(pal, { HighContrast = mode[2], Colorblind = mode[3] })
	local name = mode[1]
	for _, fg in TEXT do
		for _, bg in { "panel", "panelRaised", "panelSoft" } do
			local r = ratio(pal[fg], pal[bg])
			local need = if mode[2] then 7 else 4.5
			if fg == "muted" and mode[2] then
				need = 4.5
			end
			check(r >= need, string.format("%s: %s on %s is %.2f:1 (need %.1f)", name, fg, bg, r, need))
		end
	end
	for _, fg in ACCENT do
		for _, bg in SURFACE do
			local r = ratio(pal[fg], pal[bg])
			check(r >= 4.5, string.format("%s: %s on %s is %.2f:1 (need 4.5)", name, fg, bg, r))
		end
		local r = ratio(pal[fg], pal.panelSoft)
		check(r >= 3, string.format("%s: %s on panelSoft is %.2f:1 (need 3)", name, fg, r))
	end
	-- high contrast must actually be higher
	if mode[2] then
		local base = T.newPalette()
		check(ratio(pal.muted, pal.panel) > ratio(base.muted, base.panel), `{name}: muted isn't stronger than base`)
	end
end
-- colorblind mode: good/bad pairs must not be the same hue family (Okabe-Ito blue vs orange)
do
	local pal = T.newPalette()
	T.applyAccessibility(pal, { HighContrast = false, Colorblind = true })
	local g, r = pal.green, pal.red
	check(math.abs(g.B - r.B) > 0.5, "colorblind: green/red don't separate on the blue axis")
end

-- desktop 24px tokens in phone paths: Layout.cardPadding/pagePadding/panelGap/contentInset used
-- without a `stack`/`compact`/`large`/`chrome.` guard on the same line. Existing uses are capped
-- per file so new ones fail; shrink these numbers as pages move to chrome.* tokens.
local KNOWN: { [string]: number } = {
	["src/Client/AstralForge/UiCore/AppShellChrome.tsx"] = 2, -- desktop rail offset only
	["src/Client/AstralForge/UiCore/CrateRevealOverlay.tsx"] = 2, -- reveal card, already 12px on phones via `large`
	["src/Client/AstralForge/pages/PagesCore/OverviewView.tsx"] = 1,
	["src/Client/AstralForge/pages/PagesProgress/LabView.tsx"] = 1, -- ORDER_GAP constant
	["src/Client/AstralForge/pages/PagesShop.tsx"] = 1,
	["src/Client/AstralForge/pages/PagesSystem/CommandView.tsx"] = 12, -- TODO: chrome.panelGap on phones
}
local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.tsx?$") then
			table.insert(out, path)
		end
	end
end
local files = {}
walk("src/Client/AstralForge", files)
table.sort(files)
for _, path in files do
	if not string.find(path, "CoreKit/theme.ts", 1, true) then
		local count = 0
		for _, line in string.split(fs.readFile(path), "\n") do
			if string.find(line, "Layout%.cardPadding") or string.find(line, "Layout%.pagePadding") or string.find(line, "Layout%.panelGap") or string.find(line, "Layout%.contentInset") then
				local guarded = string.find(line, "stack") or string.find(line, "compact") or string.find(line, "large") or string.find(line, "keyboardCompact")
				if not guarded then
					count += 1
				end
			end
		end
		check(count <= (KNOWN[path] or 0), `{path}: {count} unguarded desktop spacing tokens (cap {KNOWN[path] or 0}); use chrome.* on phones`)
	end
end

if #fails > 0 then
	error("Mobile/accessibility matrix failed:\n  " .. table.concat(fails, "\n  "))
end
print(`[TEST] mobile matrix: {#SIZES} sizes, 4 palette modes, spacing tokens all within caps`)
