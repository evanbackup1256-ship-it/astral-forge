--!strict
-- Pure Continuum cost + Domain requirement/reward envelopes. No Roblox
-- services — Economy and Lune verify_runquick_pure share this so endless
-- economy soak subsets can run offline. Profile mutation stays with callers;
-- omegaMath + config knobs are injected.

local ContinuumDomainMath = {}

local MAX_VALUE = 1e308

export type ContinuumConfig = {
	BaseFluxCost: number,
	FluxCostScale: number,
	BaseStardustCost: number,
	StardustCostScale: number,
}

export type ContinuumEffectsConfig = {
	ProductionScale: number,
	MilestoneEvery: number,
	MilestoneScale: number,
	CapacityScale: number,
	TapScale: number,
	OfflineCap: number,
	OfflinePerRank: number,
}

export type DomainConfig = {
	BaseRequiredRebirths: number,
	RebirthsPerRank: number,
	BaseRequiredCores: number,
	CoreRequirementScale: number,
	BaseEssenceReward: number,
	EssencePerRank: number,
	BaseStardustReward: number,
	StardustPerRank: number,
}

function ContinuumDomainMath.ContinuumCosts(omegaMath: any, config: ContinuumConfig, rank: number): (any, any)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local flux = omegaMath.Floor(omegaMath.Mul(config.BaseFluxCost, omegaMath.BoundedPower(config.FluxCostScale, safeRank)))
	local stardust = omegaMath.Floor(omegaMath.Mul(config.BaseStardustCost, omegaMath.BoundedPower(config.StardustCostScale, safeRank)))
	return flux, stardust
end

function ContinuumDomainMath.DomainRequirements(omegaMath: any, config: DomainConfig, rank: number): (number, number)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local rebirths = math.floor(math.min(
		MAX_VALUE,
		config.BaseRequiredRebirths + safeRank * config.RebirthsPerRank
	))
	local cores = omegaMath.ScaledCost(config.BaseRequiredCores, config.CoreRequirementScale, safeRank)
	return rebirths, omegaMath.ToNumber(cores)
end

function ContinuumDomainMath.DomainRewards(config: DomainConfig, rank: number): (number, number)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local essence = math.floor(math.min(
		MAX_VALUE,
		config.BaseEssenceReward + safeRank * config.EssencePerRank
	))
	local stardust = math.floor(math.min(
		MAX_VALUE,
		config.BaseStardustReward + safeRank * config.StardustPerRank
	))
	return essence, stardust
end

-- Rank → production/capacity/tap multipliers + offline efficiency addend.
-- Mirrors Economy.ContinuumEffects; milestones multiply production only.
function ContinuumDomainMath.ContinuumEffects(
	omegaMath: any,
	config: ContinuumEffectsConfig,
	rank: number
): (any, any, any, number)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local every = math.max(1, math.floor(tonumber(config.MilestoneEvery) or 1))
	local milestones = math.floor(safeRank / every)
	local milestoneMultiplier = omegaMath.BoundedPower(config.MilestoneScale, milestones)
	local production = omegaMath.Mul(omegaMath.BoundedPower(config.ProductionScale, safeRank), milestoneMultiplier)
	local capacity = omegaMath.BoundedPower(config.CapacityScale, safeRank)
	local tap = omegaMath.BoundedPower(config.TapScale, safeRank)
	local offline = math.min(config.OfflineCap, safeRank * config.OfflinePerRank)
	return production, capacity, tap, offline
end


function ContinuumDomainMath.DomainProductionMultiplier(rank: any, essence: any, productionPerRank: any, productionPerEssence: any, essenceCap: any, domainTreeBonus: any): number
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local safeEssence = math.max(0, tonumber(essence) or 0)
	local cap = tonumber(essenceCap) or 1_000_000
	if safeEssence > cap then
		safeEssence = cap
	end
	return 1 + safeRank * (tonumber(productionPerRank) or 0) + safeEssence * (tonumber(productionPerEssence) or 0) + (tonumber(domainTreeBonus) or 0)
end

function ContinuumDomainMath.DomainRankBonus(rank: any, perRank: any, domainTreeBonus: any): number
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	return safeRank * (tonumber(perRank) or 0) + (tonumber(domainTreeBonus) or 0)
end

-- Non-negative integer coerce for Domain/Continuum snapshot bags (string fixtures).
function ContinuumDomainMath.NonNegativeInt(value: any): number
	return math.max(0, math.floor(tonumber(value) or 0))
end

-- Snapshot Domain bag fields that must stay numeric for client UI rails.
function ContinuumDomainMath.SnapshotDomainInts(domain: any): {
	Essence: number,
	LastExpandedAt: number,
	TotalRebirthsSpent: number,
	TotalCoresSpent: number,
	SkillPoints: number,
}
	local bag = if type(domain) == "table" then domain else {}
	return {
		Essence = ContinuumDomainMath.NonNegativeInt(bag.Essence),
		LastExpandedAt = ContinuumDomainMath.NonNegativeInt(bag.LastExpandedAt),
		TotalRebirthsSpent = ContinuumDomainMath.NonNegativeInt(bag.TotalRebirthsSpent),
		TotalCoresSpent = ContinuumDomainMath.NonNegativeInt(bag.TotalCoresSpent),
		SkillPoints = ContinuumDomainMath.NonNegativeInt(bag.SkillPoints),
	}
end

-- Full Domain snapshot bag for client rails (wave46). Injects gate/economy helpers.
function ContinuumDomainMath.SnapshotDomainPublic(args: {
	domain: any,
	rank: number,
	requiredRebirths: number,
	requiredCores: number,
	essenceReward: number,
	stardustReward: number,
	rebirths: number,
	cores: any,
	domainConfig: any,
	MeetsRequired: (number, number) -> boolean,
	Gte: (any, any) -> boolean,
	DomainTreeBonus: (string) -> number,
}): any
	local ints = ContinuumDomainMath.SnapshotDomainInts(args.domain)
	local bag = if type(args.domain) == "table" then args.domain else {}
	local config = args.domainConfig or {}
	return {
		Rank = args.rank,
		Essence = ints.Essence,
		LastExpandedAt = ints.LastExpandedAt,
		TotalRebirthsSpent = ints.TotalRebirthsSpent,
		TotalCoresSpent = ints.TotalCoresSpent,
		RequiredRebirths = args.requiredRebirths,
		RequiredCores = args.requiredCores,
		CanExpand = args.MeetsRequired(args.rebirths, args.requiredRebirths) and args.Gte(args.cores, args.requiredCores),
		EssenceReward = args.essenceReward,
		StardustReward = args.stardustReward,
		ProductionMultiplier = ContinuumDomainMath.DomainProductionMultiplier(
			args.rank,
			bag.Essence,
			config.ProductionPerRank,
			config.ProductionPerEssence,
			1_000_000,
			args.DomainTreeBonus("Production")
		),
		CapacityMultiplier = 1 + ContinuumDomainMath.DomainRankBonus(
			args.rank,
			config.CapacityPerRank,
			args.DomainTreeBonus("Capacity")
		),
		OfflineBonus = ContinuumDomainMath.DomainRankBonus(
			args.rank,
			config.OfflineEfficiencyPerRank,
			args.DomainTreeBonus("Offline")
		),
		SkillPoints = ints.SkillPoints,
		Nodes = type(bag.Nodes) == "table" and bag.Nodes or {},
	}
end

-- Full Continuum snapshot bag for client rails (wave46).
function ContinuumDomainMath.SnapshotContinuumPublic(args: {
	rank: number,
	totalFluxSpent: any,
	totalStardustSpent: any,
	fluxCost: any,
	stardustCost: any,
	cash: any,
	stardust: any,
	production: any,
	capacity: any,
	tap: any,
	offline: any,
	milestoneEvery: number,
	Gte: (any, any) -> boolean,
}): any
	local every = math.max(1, math.floor(tonumber(args.milestoneEvery) or 1))
	local safeRank = math.max(0, math.floor(tonumber(args.rank) or 0))
	return {
		Rank = args.rank,
		TotalFluxSpent = args.totalFluxSpent,
		TotalStardustSpent = math.max(0, tonumber(args.totalStardustSpent) or 0),
		FluxCost = args.fluxCost,
		StardustCost = args.stardustCost,
		CanUpgrade = args.Gte(args.cash, args.fluxCost) and args.Gte(args.stardust, args.stardustCost),
		ProductionMultiplier = args.production,
		CapacityMultiplier = args.capacity,
		TapMultiplier = args.tap,
		OfflineBonus = args.offline,
		NextMilestone = (math.floor(safeRank / every) + 1) * every,
	}
end

return table.freeze(ContinuumDomainMath)
