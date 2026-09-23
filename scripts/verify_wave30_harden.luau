--!strict
-- Wave30 offline residuals: WorldsView + RewardsView extracts, Worlds FocusClaim/softMotion,
-- MainGame StatChip softMotion, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local worlds = fs.readFile("src/Client/AstralForge/pages/WorldsView.luau")
assert(string.find(worlds, "local function WorldsView", 1, true), "WorldsView missing")
assert(string.find(worlds, "local function WorldRow", 1, true), "WorldRow missing")
assert(string.find(worlds, 'Name = "WorldsTravelClaim"', 1, true), "WorldsTravelClaim host")
assert(string.find(worlds, "GamepadNavigationService.FocusClaim", 1, true), "Worlds FocusClaim")
assert(
	string.find(worlds, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true),
	"Worlds softMotion canon"
)
assert(string.find(worlds, "reducedMotion = softMotion", 1, true), "Worlds fold softMotion")
do
	local soft = 0
	for _ in string.gmatch(worlds, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Worlds softMotion density, got " .. tostring(soft))
end
do
	local hostStart = string.find(worlds, 'Name = "WorldsTravelClaim"', 1, true)
	assert(hostStart, "WorldsTravelClaim missing")
	local hostSlice = string.sub(worlds, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "WorldsTravelClaim clips")
end

local rewards = fs.readFile("src/Client/AstralForge/pages/RewardsView.luau")
assert(string.find(rewards, "local function RewardsView", 1, true), "RewardsView missing")
assert(string.find(rewards, "local function RewardChargeRail", 1, true), "RewardChargeRail missing")
assert(string.find(rewards, 'Name = "RewardsDailyClaimActions"', 1, true), "RewardsDailyClaimActions")
assert(string.find(rewards, 'Name = "RewardsTimedClaimActions"', 1, true), "RewardsTimedClaimActions")
assert(string.find(rewards, "GamepadNavigationService.FocusClaim", 1, true), "Rewards FocusClaim")
assert(
	string.find(rewards, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true),
	"Rewards softMotion canon"
)

local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(router, 'lazyView("WorldsView", "WorldsView")', 1, true), "PageRouter lazy WorldsView")
assert(string.find(router, 'lazyView("RewardsView", "RewardsView")', 1, true), "PageRouter lazy RewardsView")
assert(not string.find(router, "local function WorldsView", 1, true), "inline WorldsView must leave PageRouter")
assert(not string.find(router, "local function RewardsView", 1, true), "inline RewardsView must leave PageRouter")
assert(not string.find(router, "local function WorldRow", 1, true), "WorldRow must leave PageRouter")
assert(not string.find(router, "local function RewardChargeRail", 1, true), "RewardChargeRail must leave PageRouter")
assert(not string.find(router, "GamepadNavigationService", 1, true), "PageRouter must drop GamepadNavigationService")

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, "Canonical softMotion antilag gate — StatChip", 1, true), "StatChip softMotion gate")
do
	local soft = 0
	for _ in string.gmatch(main, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "MainGame softMotion densify, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave30-offline-brief"', 1, true), "Story wave30")
assert(string.find(config, 'Id = "update-5-1-wave30-offline"', 1, true), "Mail wave30")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave30 harden residuals passed")
