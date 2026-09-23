--!strict
-- Wave32 offline residuals: MainGame VaultCollectClaim FocusClaim + chrome softMotion densify
-- (TradeReturnPill / ActiveBoostIcon / ConfettiBurst / Workspace), DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChrome = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
local workspaceChrome = fs.readFile("src/Client/AstralForge/WorkspaceChrome.luau")
assert(string.find(workspaceChrome, 'Name = "VaultCollectClaim"', 1, true), "VaultCollectClaim host")
assert(string.find(workspaceChrome, "GamepadNavigationService.FocusClaim", 1, true), "Workspace FocusClaim")
assert(string.find(main, "Canonical softMotion antilag gate — TradeReturnPill", 1, true), "TradeReturnPill softMotion")
assert(string.find(topBarChrome, "Canonical softMotion antilag gate — ActiveBoostIcon", 1, true), "ActiveBoostIcon softMotion")
assert(string.find(main, "Canonical softMotion antilag gate — ConfettiBurst", 1, true), "ConfettiBurst softMotion")
assert(string.find(workspaceChrome, "Canonical softMotion antilag gate — Workspace", 1, true), "Workspace softMotion")
do
	local hostStart = string.find(workspaceChrome, 'Name = "VaultCollectClaim"', 1, true)
	assert(hostStart, "VaultCollectClaim missing")
	local hostSlice = string.sub(workspaceChrome, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "VaultCollectClaim clips")
end
do
	local soft = 0
	for _ in string.gmatch(main, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "MainGame softMotion densify, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave32-offline-brief"', 1, true), "Story wave32")
assert(string.find(config, 'Id = "update-5-1-wave32-offline"', 1, true), "Mail wave32")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave32 harden residuals passed")
