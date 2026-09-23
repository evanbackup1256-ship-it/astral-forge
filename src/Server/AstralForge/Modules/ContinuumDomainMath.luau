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

return table.freeze(ContinuumDomainMath)
