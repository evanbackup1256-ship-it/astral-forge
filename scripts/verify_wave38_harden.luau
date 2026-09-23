--!strict
-- Wave38 offline residuals: AppShellChrome extract, Crew/Missions/Milestones/
-- Leaderboards softMotion densify, playability DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local appShell = fs.readFile("src/Client/AstralForge/AppShellChrome.luau")
assert(string.find(appShell, "local function AppShell", 1, true), "AppShell missing")
assert(string.find(appShell, "local function Shell", 1, true), "Shell missing")
assert(string.find(appShell, "pausePassivePaints", 1, true), "pausePassivePaints export")
assert(string.find(appShell, "Canonical softMotion antilag gate — AppShell", 1, true), "AppShell softMotion")
do
	local soft = 0
	for _ in string.gmatch(appShell, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "AppShellChrome softMotion densify, got " .. tostring(soft))
end

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, "require(script.Parent.AppShellChrome)", 1, true), "MainGame requires AppShellChrome")
assert(string.find(main, "local Shell = _AppShellChrome.Shell", 1, true), "MainGame binds Shell")
assert(string.find(main, "local pausePassivePaints = _AppShellChrome.pausePassivePaints", 1, true), "MainGame binds pausePassivePaints")
assert(not string.find(main, "local function AppShell", 1, true), "AppShell must leave MainGame")
assert(not string.find(main, "local TUTORIAL_STEPS", 1, true), "TUTORIAL_STEPS must leave MainGame")

local crew = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
local missions = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
local milestones = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
local boards = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
assert(string.find(crew, "Canonical softMotion antilag gate — CrewView", 1, true), "Crew softMotion")
assert(string.find(missions, "Canonical softMotion antilag gate — MissionsView", 1, true), "Missions softMotion")
assert(string.find(milestones, "Canonical softMotion antilag gate — MilestonesView", 1, true), "Milestones softMotion")
assert(string.find(boards, "Canonical softMotion antilag gate — LeaderboardsView", 1, true), "Leaderboards softMotion")
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
do
	local soft = 0
	for _ in string.gmatch(boards, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Leaderboards softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/CrewView.luau"] = 12', 1, true), "Crew DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/MissionsView.luau"] = 12', 1, true), "Missions DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/MilestonesView.luau"] = 12', 1, true), "Milestones DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/LeaderboardsView.luau"] = 10', 1, true), "Leaderboards DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave38-offline-brief"', 1, true), "Story wave38")
assert(string.find(config, 'Id = "update-5-1-wave38-offline"', 1, true), "Mail wave38")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave38 harden residuals passed")
