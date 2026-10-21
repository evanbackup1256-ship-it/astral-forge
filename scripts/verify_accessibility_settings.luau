--!strict
-- Text size and gamepad wiring. Runs the compiled text-scale resolver and checks the shell keeps
-- its gamepad selection regions and the kit focus ring.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local fails: { string } = {}
local function check(ok: boolean, msg: string)
	if not ok then
		table.insert(fails, msg)
	end
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local env: any = setmetatable({}, { __index = getfenv() })
local S = (luau.load(fs.readFile("out/Client/AstralForge/CoreKit/textScale.luau"), { environment = env }) :: any)()

-- limits the text-fit / tap / copy-fit checks were measured against
check(S.TEXT_SCALE_BANDS.touch.max <= 1.26 and S.TEXT_SCALE_BANDS.desktop.max <= 1.16, "text scale bands grew past the tested limits")
check(S.TEXT_SCALE_BANDS.touch.min >= 0.92 and S.TEXT_SCALE_BANDS.desktop.min >= 0.96, "text scale bands shrink text below the tested floor")
-- the player's choice maps exactly like before (existing saves look the same)
for _, c in { 0.25, 0.5, 0.75, 1 } do
	check(near(S.resolveTextScale(true, c, false, "Medium"), 0.92 + c * 0.34), `touch choice {c} moved`)
	check(near(S.resolveTextScale(false, c, false, "Medium"), 0.96 + c * 0.2), `desktop choice {c} moved`)
	check(near(S.resolveTextScale(true, c, true, "Medium"), 0.92 + c * 0.34), `Medium Roblox size changed choice {c}`)
end
check(near(S.resolveTextScale(true, nil, true, nil), 0.92 + 0.5 * 0.34), "missing setting isn't M")
check(near(S.resolveTextScale(true, 0 / 0, true, nil), 0.92 + 0.5 * 0.34), "NaN setting isn't M")
-- Roblox size lifts small choices, never past the band, never shrinks a big choice
check(near(S.resolveTextScale(true, 0.25, true, "Larger"), 1.18), "Larger doesn't lift touch text to 1.18")
check(near(S.resolveTextScale(true, 0.25, true, "Largest"), 1.26), "Largest isn't capped at touch max")
check(near(S.resolveTextScale(false, 0.25, true, "Largest"), 1.16), "Largest isn't capped at desktop max")
check(near(S.resolveTextScale(true, 1, true, "Large"), 1.26), "Large shrank an XL choice")
check(near(S.resolveTextScale(true, 0.25, false, "Largest"), 0.92 + 0.25 * 0.34), "follow off still uses Roblox size")

-- setting is in the schema (so the server accepts and saves it) and in the template
local schema = fs.readFile("src/Shared/AstralForge/Shared/SharedData/SettingsSchema.ts")
check(string.find(schema, 'toggle("FollowRobloxTextSize", "accessibility"', 1, true) ~= nil, "FollowRobloxTextSize missing from SettingsSchema")
check(string.find(schema, '"DesktopTextScale", "FollowRobloxTextSize"', 1, true) ~= nil, "FollowRobloxTextSize not in the Reading group")
check(string.find(fs.readFile("src/Server/AstralForge/DataTemplate.ts"), "FollowRobloxTextSize: 1", 1, true) ~= nil, "FollowRobloxTextSize missing from DataTemplate")
local main = fs.readFile("src/Client/AstralForge/UiCore/MainGame.tsx")
check(string.find(main, "resolveTextScale(", 1, true) ~= nil and string.find(main, 'GetPropertyChangedSignal("PreferredTextSize")', 1, true) ~= nil, "MainGame doesn't resolve text scale from Roblox PreferredTextSize")

-- gamepad: shell regions and kit focus ring
local shell = fs.readFile("src/Client/AstralForge/UiCore/AppShellChrome.tsx")
check(string.find(shell, 'registerRegion("page"', 1, true) ~= nil, "shell lost the page selection region")
check(string.find(shell, 'registerRegion("nav"', 1, true) ~= nil, "shell lost the nav selection region")
check(string.find(shell, "ref={pageRegionRef}", 1, true) ~= nil and string.find(shell, "ref={navRegionRef}", 1, true) ~= nil, "region refs not attached")
check(string.find(shell, "enterPage()", 1, true) ~= nil, "page changes don't move gamepad focus")
local regionsSrc = fs.readFile("src/Client/AstralForge/CoreKit/selectionRegions.ts")
check(string.find(regionsSrc, "SelectionGroup = true", 1, true) ~= nil and string.find(regionsSrc, "NextSelectionRight", 1, true) ~= nil, "selection regions lost SelectionGroup/NextSelection wiring")
local ui = fs.readFile("src/Client/AstralForge/UiCore/ui.tsx")
check(string.find(ui, "button.SelectionImageObject = hiddenSelectionImage()", 1, true) ~= nil, "kit Button shows the default Roblox selection box again")
check(string.find(ui, "transparency={focusRingTransparency}", 1, true) ~= nil, "kit Button lost its focus ring")

if #fails > 0 then
	error("Accessibility settings failed:\n  " .. table.concat(fails, "\n  "))
end
print("[TEST] accessibility settings: text scale bands, Roblox text size, gamepad regions and focus ring")
