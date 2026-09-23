--!strict
-- Wave39 offline residuals: Anomaly/Milestones/Convergence/ForgePath softMotion densify,
-- OfflineRewards/Feedback overlay softMotion gates, DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local anomaly = fs.readFile("src/Client/AstralForge/pages/AnomalyView.luau")
local milestones = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
local convergence = fs.readFile("src/Client/AstralForge/pages/ConvergenceView.luau")
local forgePath = fs.readFile("src/Client/AstralForge/pages/ForgePathView.luau")
assert(string.find(anomaly, "Canonical softMotion antilag gate — AnomalyView", 1, true), "Anomaly softMotion")
assert(string.find(milestones, "Canonical softMotion antilag gate — MilestonesView", 1, true), "Milestones softMotion")
assert(string.find(convergence, "Canonical softMotion antilag gate — ConvergenceView", 1, true), "Convergence softMotion")
assert(string.find(forgePath, "Canonical softMotion antilag gate — ForgePathView", 1, true), "ForgePath softMotion")
do
	local soft = 0
	for _ in string.gmatch(anomaly, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Anomaly softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(milestones, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Milestones softMotion densify, got " .. tostring(soft))
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
	assert(soft >= 12, "ForgePath softMotion densify, got " .. tostring(soft))
end

local offline = fs.readFile("src/Client/AstralForge/OfflineRewardsOverlay.luau")
local feedback = fs.readFile("src/Client/AstralForge/FeedbackOverlay.luau")
assert(string.find(offline, "Canonical softMotion antilag gate — OfflineRewardsOverlay", 1, true), "OfflineRewards softMotion")
assert(string.find(feedback, "Canonical softMotion antilag gate — FeedbackOverlay", 1, true), "Feedback softMotion")
do
	local soft = 0
	for _ in string.gmatch(offline, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "OfflineRewards softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(feedback, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Feedback softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/AnomalyView.luau"] = 12', 1, true), "Anomaly DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/MilestonesView.luau"] = 12', 1, true), "Milestones DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/ConvergenceView.luau"] = 12', 1, true), "Convergence DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/ForgePathView.luau"] = 10', 1, true), "ForgePath DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave39-offline-brief"', 1, true), "Story wave39")
assert(string.find(config, 'Id = "update-5-1-wave39-offline"', 1, true), "Mail wave39")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave39 harden residuals passed")
