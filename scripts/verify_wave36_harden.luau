--!strict
-- Wave36 offline residuals: ShellFx extract (AmbientLayer/ConfettiBurst),
-- Inventory/Guild/Anomaly softMotion densify, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local shell = fs.readFile("src/Client/AstralForge/ShellFx.luau")
assert(string.find(shell, "local function AmbientLayer", 1, true), "AmbientLayer missing")
assert(string.find(shell, "local function ConfettiBurst", 1, true), "ConfettiBurst missing")
assert(string.find(shell, "local CONFETTI_PIECES", 1, true), "CONFETTI_PIECES missing")
assert(string.find(shell, "Canonical softMotion antilag gate — AmbientLayer", 1, true), "AmbientLayer softMotion")
assert(string.find(shell, "Canonical softMotion antilag gate — ConfettiBurst", 1, true), "ConfettiBurst softMotion")
do
	local soft = 0
	for _ in string.gmatch(shell, "softMotion") do
		soft += 1
	end
	assert(soft >= 6, "ShellFx softMotion density, got " .. tostring(soft))
end

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, 'require(script.Parent.ShellFx)', 1, true), "MainGame requires ShellFx")
assert(string.find(main, "local AmbientLayer = _ShellFx.AmbientLayer", 1, true), "MainGame binds AmbientLayer")
assert(not string.find(main, "local function AmbientLayer", 1, true), "AmbientLayer must leave MainGame")
assert(not string.find(main, "local function ConfettiBurst", 1, true), "ConfettiBurst must leave MainGame")
assert(not string.find(main, "local CONFETTI_PIECES", 1, true), "CONFETTI_PIECES must leave MainGame")

local inv = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local guild = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
local anomaly = fs.readFile("src/Client/AstralForge/pages/AnomalyView.luau")
assert(string.find(inv, "Canonical softMotion antilag gate — InventoryView", 1, true), "Inventory softMotion")
assert(string.find(guild, "Canonical softMotion antilag gate — GuildView", 1, true), "Guild softMotion")
assert(string.find(anomaly, "Canonical softMotion antilag gate — AnomalyView", 1, true), "Anomaly softMotion")
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
	assert(soft >= 10, "Anomaly softMotion densify, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave36-offline-brief"', 1, true), "Story wave36")
assert(string.find(config, 'Id = "update-5-1-wave36-offline"', 1, true), "Mail wave36")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave36 harden residuals passed")
