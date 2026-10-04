--!strict
-- Wave36 offline residuals: ShellFx extract (AmbientLayer/ConfettiBurst),
-- Inventory/Guild/Anomaly softMotion densify, DV21 Story/Mail briefs.

local fs = require("./_memberfs")(require("@lune/fs"))

local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#ShellFx")
assert(string.find(shell, "local function AmbientLayer", 1, true), "AmbientLayer missing")
assert(string.find(shell, "local function ConfettiBurst", 1, true), "ConfettiBurst missing")
assert(string.find(shell, "local CONFETTI_PIECES", 1, true), "CONFETTI_PIECES missing")
assert(string.find(shell, "local softMotion = ", 1, true), "AmbientLayer softMotion")
assert(string.find(shell, "local softMotion = ", 1, true), "ConfettiBurst softMotion")
do
	local soft = 0
	for _ in string.gmatch(shell, "softMotion") do
		soft += 1
	end
	assert(soft >= 6, "ShellFx softMotion density, got " .. tostring(soft))
end

local main = fs.readFile("src/Client/AstralForge/UiCore.luau#MainGame")
local appShell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(string.find(appShell, '("ShellFx")', 1, true), "AppShellChrome requires ShellFx")
assert(string.find(appShell, "local AmbientLayer = _ShellFx.AmbientLayer", 1, true), "AppShellChrome binds AmbientLayer")
assert(not string.find(main, "local function AmbientLayer", 1, true), "AmbientLayer must leave MainGame")
assert(not string.find(main, "local function ConfettiBurst", 1, true), "ConfettiBurst must leave MainGame")
assert(not string.find(main, "local CONFETTI_PIECES", 1, true), "CONFETTI_PIECES must leave MainGame")

local inv = fs.readFile("src/Client/AstralForge/pages/PagesStory.luau#InventoryView")
local guild = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau#GuildView")
local anomaly = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau#AnomalyView")
assert(string.find(inv, "local softMotion = ", 1, true), "Inventory softMotion")
assert(string.find(guild, "local softMotion = ", 1, true), "Guild softMotion")
assert(string.find(anomaly, "local softMotion = ", 1, true), "Anomaly softMotion")
do
	local soft = 0
	for _ in string.gmatch(inv, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Inventory softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(guild, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Guild softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(anomaly, "softMotion") do
		soft += 1
	end
	assert(soft >= 3, "Anomaly shared motion provider, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave36-offline-brief"', 1, true), "Story wave36")
assert(string.find(config, 'Id = "update-5-1-wave36-offline"', 1, true), "Mail wave36")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave36 harden residuals passed")
