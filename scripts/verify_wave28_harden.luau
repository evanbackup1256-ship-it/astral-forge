--!strict
-- Wave28 offline residuals: CrewView extract from PageRouter, MainGame TopBar/MoreDock
-- softMotion gates, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local crew = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
assert(string.find(crew, "local function CrewView", 1, true), "CrewView missing")
assert(string.find(crew, "createElement(FlatList", 1, true), "Crew FlatList")
assert(string.find(crew, "FocusClaim", 1, true), "Crew FocusClaim")
assert(string.find(crew, "Name = \"CrewVisitClaim\"", 1, true), "CrewVisitClaim host")
assert(string.find(crew, "overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2", 1, true), "Crew overscan")
do
	local soft = 0
	for _ in string.gmatch(crew, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Crew softMotion density, got " .. tostring(soft))
end

local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(router, 'lazyView("CrewView", "CrewView")', 1, true), "PageRouter lazy CrewView")
assert(string.find(router, "createElement(CrewView,", 1, true), "PageRouter mounts CrewView")
assert(not string.find(router, "local function CrewRow", 1, true), "CrewRow must leave PageRouter")
assert(not string.find(router, "local function CrewView", 1, true), "inline CrewView must leave PageRouter")
assert(not string.find(router, "local FlatList = require", 1, true), "PageRouter must drop FlatList import")
assert(not string.find(router, 'GetService("Players")', 1, true), "PageRouter must drop Players import")

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChrome = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
local navChrome = fs.readFile("src/Client/AstralForge/NavChrome.luau")
assert(string.find(topBarChrome, "Canonical softMotion antilag gate — TopBar", 1, true), "TopBar softMotion gate")
assert(string.find(navChrome, "Canonical softMotion antilag gate — MoreDock", 1, true), "MoreDock softMotion gate")
do
	local shell = fs.readFile("src/Client/AstralForge/AppShellChrome.luau")
	local soft = 0
	for _ in string.gmatch(shell, "softMotion") do
		soft += 1
	end
	assert(soft >= 3, "AppShellChrome softMotion densify, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave28-offline-brief"', 1, true), "Story wave28")
assert(string.find(config, 'Id = "update-5-1-wave28-offline"', 1, true), "Mail wave28")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave28 harden residuals passed")
