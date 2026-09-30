--!strict
-- Wave37 offline residuals: TradeReturnPill into ShellFx, Command/Settings/Lab/
-- Continuum softMotion densify, playability DENSE floor raises, DV21 Story/Mail.

local fs = require("./_memberfs")(require("@lune/fs"))

local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#ShellFx")
assert(string.find(shell, "local function TradeReturnPill", 1, true), "TradeReturnPill missing")
assert(string.find(shell, 'Name = "TradeReturnClaim"', 1, true), "TradeReturnClaim host")
assert(string.find(shell, "GamepadNavigationService.FocusClaim", 1, true), "TradeReturn FocusClaim")
assert(string.find(shell, "Canonical softMotion antilag gate — TradeReturnPill", 1, true), "TradeReturn softMotion")
do
	local soft = 0
	for _ in string.gmatch(shell, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "ShellFx softMotion density, got " .. tostring(soft))
end

local main = fs.readFile("src/Client/AstralForge/UiCore.luau#MainGame")
local appShell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(string.find(appShell, "local TradeReturnPill = _ShellFx.TradeReturnPill", 1, true), "AppShellChrome binds TradeReturnPill")
assert(not string.find(main, "local function TradeReturnPill", 1, true), "TradeReturnPill must leave MainGame")

local command = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau#CommandView")
local settings = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau#SettingsView")
local lab = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#LabView")
local continuum = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#ContinuumView")
assert(string.find(command, "Canonical softMotion antilag gate — CommandView", 1, true), "Command softMotion")
assert(string.find(settings, "Canonical softMotion antilag gate — SettingsView", 1, true), "Settings softMotion")
assert(string.find(lab, "Canonical softMotion antilag gate — LabView", 1, true), "Lab softMotion")
assert(string.find(continuum, "Canonical softMotion antilag gate — ContinuumView", 1, true), "Continuum softMotion")
do
	local soft = 0
	for _ in string.gmatch(command, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Command softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(settings, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Settings softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(lab, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Lab softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(continuum, "softMotion") do
		soft += 1
	end
	assert(soft >= 18, "Continuum softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesStory.luau#InventoryView"] = 12', 1, true), "Inventory DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSocial.luau#GuildView"] = 12', 1, true), "Guild DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSystem.luau#AnomalyView"] = 12', 1, true), "Anomaly DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSystem.luau#CommandView"] = 12', 1, true), "Command DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSystem.luau#SettingsView"] = 12', 1, true), "Settings DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesProgress.luau#LabView"] = 12', 1, true), "Lab DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesProgress.luau#ContinuumView"] = 12', 1, true), "Continuum DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave37-offline-brief"', 1, true), "Story wave37")
assert(string.find(config, 'Id = "update-5-1-wave37-offline"', 1, true), "Mail wave37")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave37 harden residuals passed")
