--!strict
-- Wave39 offline residuals: Anomaly/Milestones/Convergence/ForgePath softMotion densify,
-- OfflineRewards/Feedback overlay softMotion gates, DENSE floor raises, DV21 Story/Mail.

local fs = require("./_memberfs")(require("@lune/fs"))

local anomaly = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau#AnomalyView")
local milestones = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau#MilestonesView")
local convergence = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#ConvergenceView")
local forgePath = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#ForgePathView")
assert(string.find(anomaly, "local softMotion = ", 1, true), "Anomaly softMotion")
assert(string.find(milestones, "local softMotion = ", 1, true), "Milestones softMotion")
assert(string.find(convergence, "local softMotion = ", 1, true), "Convergence softMotion")
assert(string.find(forgePath, "local softMotion = ", 1, true), "ForgePath softMotion")
do
	local soft = 0
	for _ in string.gmatch(anomaly, "softMotion") do
		soft += 1
	end
	assert(soft >= 3, "Anomaly shared motion provider, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(milestones, "softMotion") do
		soft += 1
	end
	assert(soft >= 13, "Milestones softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(convergence, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Convergence softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(forgePath, "softMotion") do
		soft += 1
	end
	assert(soft >= 9, "ForgePath softMotion densify, got " .. tostring(soft))
end

local offline = fs.readFile("src/Client/AstralForge/UiCore.luau#OfflineRewardsOverlay")
local feedback = fs.readFile("src/Client/AstralForge/UiCore.luau#FeedbackOverlay")
assert(string.find(offline, "local softMotion = ", 1, true), "OfflineRewards softMotion")
assert(string.find(feedback, "local softMotion = ", 1, true), "Feedback softMotion")
do
	local soft = 0
	for _ in string.gmatch(offline, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "OfflineRewards softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(feedback, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Feedback softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSystem.luau#AnomalyView"] = ', 1, true), "Anomaly DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesCore.luau#MilestonesView"] = ', 1, true), "Milestones DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesProgress.luau#ConvergenceView"] = ', 1, true), "Convergence DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesProgress.luau#ForgePathView"] = ', 1, true), "ForgePath DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave39-offline-brief"', 1, true), "Story wave39")
assert(string.find(config, 'Id = "update-5-1-wave39-offline"', 1, true), "Mail wave39")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave39 harden residuals passed")
