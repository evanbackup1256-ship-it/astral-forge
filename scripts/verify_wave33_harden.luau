--!strict
-- Wave33 offline residuals: TopBarChrome extract (StatChip/PerformanceStats/
-- ActiveBoostIcon/TopbarReleaseCountdown/TopBar), TradeReturnClaim FocusClaim,
-- TopbarReleaseCountdown softMotion densify, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local chrome = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
assert(string.find(chrome, "local function TopBar", 1, true), "TopBar missing")
assert(string.find(chrome, "local function StatChip", 1, true), "StatChip missing")
assert(string.find(chrome, "local function PerformanceStats", 1, true), "PerformanceStats missing")
assert(string.find(chrome, "local function ActiveBoostIcon", 1, true), "ActiveBoostIcon missing")
assert(string.find(chrome, "local function TopbarReleaseCountdown", 1, true), "TopbarReleaseCountdown missing")
assert(string.find(chrome, "Canonical softMotion antilag gate — TopBar", 1, true), "TopBar softMotion")
assert(string.find(chrome, "Canonical softMotion antilag gate — StatChip", 1, true), "StatChip softMotion")
assert(string.find(chrome, "Canonical softMotion antilag gate — ActiveBoostIcon", 1, true), "ActiveBoostIcon softMotion")
assert(string.find(chrome, "Canonical softMotion antilag gate — TopbarReleaseCountdown", 1, true), "TopbarReleaseCountdown softMotion")
assert(string.find(chrome, "reducedMotion = softMotion", 1, true), "TopBarChrome fold softMotion")
do
	local soft = 0
	for _ in string.gmatch(chrome, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "TopBarChrome softMotion density, got " .. tostring(soft))
end

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, 'require(script.Parent.TopBarChrome)', 1, true), "MainGame requires TopBarChrome")
assert(string.find(main, "local TopBar = _TopBarChrome.TopBar", 1, true), "MainGame binds TopBar")
local nav = fs.readFile("src/Client/AstralForge/NavChrome.luau")
assert(string.find(nav, "ActiveBoostIcon = require(script.Parent.TopBarChrome).ActiveBoostIcon", 1, true), "NavChrome binds ActiveBoostIcon")
local shellFx = fs.readFile("src/Client/AstralForge/ShellFx.luau")
assert(string.find(shellFx, 'Name = "TradeReturnClaim"', 1, true), "TradeReturnClaim host")
assert(string.find(shellFx, "GamepadNavigationService.FocusClaim", 1, true), "TradeReturn FocusClaim")
assert(not string.find(main, "local function TopBar", 1, true), "TopBar must leave MainGame")
assert(not string.find(main, "local function StatChip", 1, true), "StatChip must leave MainGame")
assert(not string.find(main, "local function ActiveBoostIcon", 1, true), "ActiveBoostIcon must leave MainGame")
assert(not string.find(main, "local function TopbarReleaseCountdown", 1, true), "TopbarReleaseCountdown must leave MainGame")
do
	local hostStart = string.find(shellFx, 'Name = "TradeReturnClaim"', 1, true)
	assert(hostStart, "TradeReturnClaim missing")
	local hostSlice = string.sub(shellFx, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "TradeReturnClaim clips")
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave33-offline-brief"', 1, true), "Story wave33")
assert(string.find(config, 'Id = "update-5-1-wave33-offline"', 1, true), "Mail wave33")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave33 harden residuals passed")
