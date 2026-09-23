--!strict
-- Wave35 offline residuals: WorkspaceChrome extract (VaultPill/NextUnlockStrip/Workspace),
-- NextUnlockStrip softMotion densify, AppShell softMotion densify, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local chrome = fs.readFile("src/Client/AstralForge/WorkspaceChrome.luau")
assert(string.find(chrome, "local function Workspace", 1, true), "Workspace missing")
assert(string.find(chrome, "local function VaultPill", 1, true), "VaultPill missing")
assert(string.find(chrome, "local function NextUnlockStrip", 1, true), "NextUnlockStrip missing")
assert(string.find(chrome, 'Name = "VaultCollectClaim"', 1, true), "VaultCollectClaim host")
assert(string.find(chrome, "GamepadNavigationService.FocusClaim", 1, true), "Workspace FocusClaim")
assert(string.find(chrome, "Canonical softMotion antilag gate — Workspace", 1, true), "Workspace softMotion")
assert(string.find(chrome, "Canonical softMotion antilag gate — VaultPill", 1, true), "VaultPill softMotion")
assert(string.find(chrome, "Canonical softMotion antilag gate — NextUnlockStrip", 1, true), "NextUnlockStrip softMotion")
do
	local soft = 0
	for _ in string.gmatch(chrome, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "WorkspaceChrome softMotion density, got " .. tostring(soft))
end
do
	local hostStart = string.find(chrome, 'Name = "VaultCollectClaim"', 1, true)
	assert(hostStart, "VaultCollectClaim missing")
	local hostSlice = string.sub(chrome, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "VaultCollectClaim clips")
end

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
local appShell = fs.readFile("src/Client/AstralForge/AppShellChrome.luau")
assert(string.find(appShell, 'require(script.Parent.WorkspaceChrome)', 1, true), "AppShellChrome requires WorkspaceChrome")
assert(string.find(appShell, "local Workspace = _WorkspaceChrome.Workspace", 1, true), "AppShellChrome binds Workspace")
assert(string.find(appShell, "Canonical softMotion antilag gate — AppShell", 1, true), "AppShell softMotion")
assert(not string.find(main, "local function Workspace", 1, true), "Workspace must leave MainGame")
assert(not string.find(main, "local function VaultPill", 1, true), "VaultPill must leave MainGame")
assert(not string.find(main, "local function NextUnlockStrip", 1, true), "NextUnlockStrip must leave MainGame")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave35-offline-brief"', 1, true), "Story wave35")
assert(string.find(config, 'Id = "update-5-1-wave35-offline"', 1, true), "Mail wave35")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave35 harden residuals passed")
