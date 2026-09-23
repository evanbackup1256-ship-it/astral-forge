--!strict
-- Wave34 offline residuals: NavChrome extract (RailButton/MoreDock*/Navigation),
-- RailNavClaim FocusClaim, MoreDock densify, AmbientLayer/VaultPill softMotion, DV21 briefs.

local fs = require("@lune/fs")

local nav = fs.readFile("src/Client/AstralForge/NavChrome.luau")
assert(string.find(nav, "local function Navigation", 1, true), "Navigation missing")
assert(string.find(nav, "local function RailButton", 1, true), "RailButton missing")
assert(string.find(nav, "local function MoreDock", 1, true), "MoreDock missing")
assert(string.find(nav, "local function MoreDockButton", 1, true), "MoreDockButton missing")
assert(string.find(nav, 'Name = "RailNavClaim"', 1, true), "RailNavClaim host")
assert(string.find(nav, "GamepadNavigationService.FocusClaim", 1, true), "RailNav FocusClaim")
assert(string.find(nav, "Canonical softMotion antilag gate — RailButton", 1, true), "RailButton softMotion")
assert(string.find(nav, "Canonical softMotion antilag gate — Navigation", 1, true), "Navigation softMotion")
assert(string.find(nav, "Canonical softMotion antilag gate — MoreDock", 1, true), "MoreDock softMotion")
assert(string.find(nav, "Canonical softMotion antilag gate — MoreDockButton", 1, true), "MoreDockButton softMotion")
assert(string.find(nav, "Canonical softMotion antilag gate — MoreDockPopover", 1, true), "MoreDockPopover softMotion")
assert(string.find(nav, "Canonical softMotion antilag gate — MoreCell", 1, true), "MoreCell softMotion")
do
	local soft = 0
	for _ in string.gmatch(nav, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "NavChrome softMotion density, got " .. tostring(soft))
end
do
	local hostStart = string.find(nav, 'Name = "RailNavClaim"', 1, true)
	assert(hostStart, "RailNavClaim missing")
	local hostSlice = string.sub(nav, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "RailNavClaim clips")
end

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, 'require(script.Parent.NavChrome)', 1, true), "MainGame requires NavChrome")
assert(string.find(main, "local Navigation = _NavChrome.Navigation", 1, true), "MainGame binds Navigation")
assert(string.find(main, "Canonical softMotion antilag gate — AmbientLayer", 1, true), "AmbientLayer softMotion")
assert(string.find(main, "Canonical softMotion antilag gate — VaultPill", 1, true), "VaultPill softMotion")
assert(not string.find(main, "local function Navigation", 1, true), "Navigation must leave MainGame")
assert(not string.find(main, "local function RailButton", 1, true), "RailButton must leave MainGame")
assert(not string.find(main, "local function MoreDock", 1, true), "MoreDock must leave MainGame")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave34-offline-brief"', 1, true), "Story wave34")
assert(string.find(config, 'Id = "update-5-1-wave34-offline"', 1, true), "Mail wave34")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave34 harden residuals passed")
