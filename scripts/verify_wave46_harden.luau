--!strict
-- Wave46 offline residuals: Domain/Continuum SnapshotPublic peels,
-- Credits/Worlds/Rewards/Workshop densify, DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local continuum = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
assert(string.find(continuum, "function ContinuumDomainMath.SnapshotDomainPublic", 1, true), "SnapshotDomainPublic missing")
assert(string.find(continuum, "function ContinuumDomainMath.SnapshotContinuumPublic", 1, true), "SnapshotContinuumPublic missing")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(services, "ContinuumDomainMath.SnapshotDomainPublic", 1, true), "ServerServices uses SnapshotDomainPublic")
assert(string.find(services, "ContinuumDomainMath.SnapshotContinuumPublic", 1, true), "ServerServices uses SnapshotContinuumPublic")
assert(not string.find(services, "Domain = (function()", 1, true), "Domain IIFE must leave ServerServices")
assert(not string.find(services, "NextMilestone = (math.floor(continuumRank", 1, true), "Continuum NextMilestone must leave ServerServices")

local credits = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
local worlds = fs.readFile("src/Client/AstralForge/pages/WorldsView.luau")
local rewards = fs.readFile("src/Client/AstralForge/pages/RewardsView.luau")
local workshop = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
assert(string.find(credits, "Canonical softMotion antilag gate — CreditsRoles", 1, true), "CreditsRoles softMotion")
assert(string.find(worlds, "Canonical softMotion antilag gate — WorldsBoard", 1, true), "WorldsBoard softMotion")
assert(string.find(rewards, "Canonical softMotion antilag gate — RewardsTimed", 1, true), "RewardsTimed softMotion")
assert(string.find(workshop, "Canonical softMotion antilag gate — WorkshopBoard", 1, true), "WorkshopBoard softMotion")
do
	local soft = 0
	for _ in string.gmatch(credits, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Credits softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(worlds, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Worlds softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(rewards, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Rewards softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(workshop, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Workshop softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/CreditsView.luau"] = 12', 1, true), "Credits DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/WorldsView.luau"] = 12', 1, true), "Worlds DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/RewardsView.luau"] = 12', 1, true), "Rewards DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/WorkshopView.luau"] = 12', 1, true), "Workshop DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave46-offline-brief"', 1, true), "Story wave46")
assert(string.find(config, 'Id = "update-5-1-wave46-offline"', 1, true), "Mail wave46")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local ContinuumDomainMath = require("../src/Server/AstralForge/Modules/ContinuumDomainMath")
do
	local domain = ContinuumDomainMath.SnapshotDomainPublic({
		domain = { Essence = 2, Nodes = { A = 1 }, SkillPoints = 3 },
		rank = 1,
		requiredRebirths = 5,
		requiredCores = 10,
		essenceReward = 4,
		stardustReward = 6,
		rebirths = 5,
		cores = 10,
		domainConfig = {
			ProductionPerRank = 0.1,
			ProductionPerEssence = 0.01,
			CapacityPerRank = 0.05,
			OfflineEfficiencyPerRank = 0.02,
		},
		MeetsRequired = function(have, need)
			return have >= need
		end,
		Gte = function(a, b)
			return (tonumber(a) or 0) >= (tonumber(b) or 0)
		end,
		DomainTreeBonus = function(_kind)
			return 0
		end,
	})
	assert(domain.CanExpand == true and domain.Rank == 1 and domain.Nodes.A == 1, "domain public")
end
do
	local continuumBag = ContinuumDomainMath.SnapshotContinuumPublic({
		rank = 10,
		totalFluxSpent = 1,
		totalStardustSpent = "2",
		fluxCost = 5,
		stardustCost = 5,
		cash = 10,
		stardust = 10,
		production = 1.2,
		capacity = 1.1,
		tap = 1.05,
		offline = 0.1,
		milestoneEvery = 5,
		Gte = function(a, b)
			return (tonumber(a) or 0) >= (tonumber(b) or 0)
		end,
	})
	assert(continuumBag.CanUpgrade == true and continuumBag.NextMilestone == 15, "continuum public")
end

print("[INFO] [TEST] wave46 harden residuals passed")
