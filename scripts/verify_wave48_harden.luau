--!strict
-- Wave48 offline residuals: Offline/ForgePathXP/SocialRewards peels,
-- Convergence/Echo/Command/Lab densify, DV21 Story/Mail.

local fs = require("./_memberfs")(require("@lune/fs"))

local offline = fs.readFile("src/Server/AstralForge/Modules/EconomyMath.luau#OfflineProjection")
assert(string.find(offline, "function OfflineProjection.PublicSnapshot", 1, true), "OfflineProjection PublicSnapshot missing")

local forgePath = fs.readFile("src/Server/AstralForge/Modules/EconomyMath.luau#ForgePathClaim")
assert(string.find(forgePath, "function ForgePathClaim.XpFromBankedAmount", 1, true), "ForgePathClaim XpFromBankedAmount missing")

local social = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau#SocialBoost")
assert(string.find(social, "function SocialBoost.CreatorRewardsPublic", 1, true), "SocialBoost CreatorRewardsPublic missing")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(services, "OfflineProjection.PublicSnapshot", 1, true), "ServerServices uses OfflineProjection.PublicSnapshot")
assert(string.find(services, "ForgePathClaim.XpFromBankedAmount", 1, true), "ServerServices uses ForgePathClaim.XpFromBankedAmount")
assert(string.find(services, "SocialBoost.CreatorRewardsPublic", 1, true), "ServerServices uses CreatorRewardsPublic")
assert(not string.find(services, "Offline = runtime and {", 1, true), "Offline IIFE bag must leave ServerServices")
assert(not string.find(services, "local xpConfig = GameConfig.Economy.ForgePathXP", 1, true), "ForgePathXP IIFE must leave ServerServices")
assert(not string.find(services, "CreatorFollowClaimed = profile.SocialRewards", 1, true), "SocialRewards inline must leave ServerServices")

local convergence = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#ConvergenceView")
local echo = fs.readFile("src/Client/AstralForge/pages/PagesStory.luau#EchoForgeView")
local command = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau#CommandView")
local lab = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#LabView")
assert(string.find(convergence, "local softMotion = ", 1, true), "ConvergenceHero softMotion")
assert(string.find(echo, "local softMotion = ", 1, true), "EchoBoard softMotion")
assert(string.find(command, "local softMotion = ", 1, true), "CommandOverview softMotion")
assert(string.find(lab, "local softMotion = ", 1, true), "LabOrders softMotion")
do
	local soft = 0
	for _ in string.gmatch(convergence, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Convergence softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(command, "softMotion") do
		soft += 1
	end
	assert(soft >= 13, "Command softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(lab, "softMotion") do
		soft += 1
	end
	assert(soft >= 15, "Lab softMotion densify, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave48-offline-brief"', 1, true), "Story wave48")
assert(string.find(config, 'Id = "update-5-1-wave48-offline"', 1, true), "Mail wave48")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local ForgePathClaim = require("../src/Server/AstralForge/Modules/EconomyMath")("ForgePathClaim")
assert(ForgePathClaim.XpFromBankedAmount(999, { LogScale = 4, Minimum = 1 }) >= 1, "xp from bank")

local OfflineProjection = require("../src/Server/AstralForge/Modules/EconomyMath")("OfflineProjection")
do
	local cold = OfflineProjection.PublicSnapshot({
		runtime = nil,
		production = 10,
		vault = 5,
		offlineHours = 8,
	})
	assert(cold.Reward == 0 and cold.CapHours == 8 and cold.Vault == 5, "offline cold")
	local hot = OfflineProjection.PublicSnapshot({
		runtime = {
			OfflineReward = 3,
			OfflineSeconds = 120,
			OfflineEfficiency = 0.5,
			OfflineCapped = true,
			OfflineAwaySeconds = 200,
			OfflineCapHours = 6,
		},
		production = 10,
		vault = 5,
		offlineHours = 8,
	})
	assert(hot.Reward == 3 and hot.Capped == true and hot.CapHours == 6, "offline hot")
end

local SocialBoost = require("../src/Server/AstralForge/Modules/ProfileMath")("SocialBoost")
do
	local bag = SocialBoost.CreatorRewardsPublic({ CreatorFollowClaimed = true }, "Mara")
	assert(bag.CreatorFollowClaimed == true and bag.CreatorName == "Mara", "creator rewards")
end

print("[INFO] [TEST] wave48 harden residuals passed")
