--!strict
-- Wave38 offline residuals: AppShellChrome extract, Crew/Missions/Milestones/
-- Leaderboards softMotion densify, playability DENSE floor raises, DV21 Story/Mail.

local fs = require("./_memberfs")(require("@lune/fs"))

local appShell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(string.find(appShell, "local function AppShell", 1, true), "AppShell missing")
assert(string.find(appShell, "local function Shell", 1, true), "Shell missing")
assert(string.find(appShell, "pausePassivePaints", 1, true), "pausePassivePaints export")
assert(string.find(appShell, "local softMotion = ", 1, true), "AppShell softMotion")
do
	local soft = 0
	for _ in string.gmatch(appShell, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "AppShellChrome softMotion densify, got " .. tostring(soft))
end

local main = fs.readFile("src/Client/AstralForge/UiCore.luau#MainGame")
assert(string.find(main, "(\"AppShellChrome\")", 1, true), "MainGame requires AppShellChrome")
assert(string.find(main, "local Shell = _AppShellChrome.Shell", 1, true), "MainGame binds Shell")
assert(string.find(main, "local pausePassivePaints = _AppShellChrome.pausePassivePaints", 1, true), "MainGame binds pausePassivePaints")
assert(not string.find(main, "local function AppShell", 1, true), "AppShell must leave MainGame")
assert(not string.find(main, "local TUTORIAL_STEPS", 1, true), "TUTORIAL_STEPS must leave MainGame")

local crew = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau#CrewView")
local missions = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau#MissionsView")
local milestones = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau#MilestonesView")
local boards = fs.readFile("src/Client/AstralForge/RankDashboard.luau")
assert(string.find(crew, "local softMotion = ", 1, true), "Crew softMotion")
assert(string.find(missions, "local softMotion = ", 1, true), "Missions softMotion")
assert(string.find(milestones, "local softMotion = ", 1, true), "Milestones softMotion")
assert(string.find(boards, "if animate and not props.reducedMotion then", 1, true), "Ranks reduced-motion gate")
do
	local soft = 0
	for _ in string.gmatch(crew, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Crew softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(missions, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Missions softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(milestones, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "Milestones softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSocial.luau#CrewView"] = ', 1, true), "Crew DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesCore.luau#MissionsView"] = ', 1, true), "Missions DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesCore.luau#MilestonesView"] = ', 1, true), "Milestones DENSE floor")
assert(string.find(playability, "src/Client/AstralForge/RankDashboard.luau", 1, true), "Ranks actual-renderer coverage")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave38-offline-brief"', 1, true), "Story wave38")
assert(string.find(config, 'Id = "update-5-1-wave38-offline"', 1, true), "Mail wave38")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave38 harden residuals passed")
