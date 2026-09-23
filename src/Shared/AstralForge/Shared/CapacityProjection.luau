--!strict
-- Pure steady-production + vault-capacity projection. No Roblox services —
-- Economy and Lune verify scripts share this so capacity/steady math can be
-- tested without Studio. Effect totals and zone/permanent multipliers are
-- injected by the caller; temporary boost/surge stay out of Steady.

local CapacityProjection = {}

export type SteadyParts = {
	EfficiencyLevel: number,
	ZoneMultiplier: number,
	PermanentMultiplier: any,
	-- Additive effect fractions (each applied as 1+x), in Economy order:
	-- Grid, Echo, Artifact, Item, Anomaly, Lab, Pass, Guild.
	Additives: { number },
	SocialMultiplier: number,
	MasteryMultiplier: number,
	-- Continuum production scale is already a multiplier (not 1+x).
	ContinuumProduction: any,
}

-- Permanent/steady multiplier only — excludes ActiveBoost and Anomaly Surge.
function CapacityProjection.SteadyMultiplier(omegaMath, parts: SteadyParts): any
	local multiplier = omegaMath.Mul(1 + parts.EfficiencyLevel * 0.15, parts.ZoneMultiplier)
	multiplier = omegaMath.Mul(multiplier, parts.PermanentMultiplier)
	for _, additive in parts.Additives do
		multiplier = omegaMath.Mul(multiplier, 1 + additive)
	end
	multiplier = omegaMath.Mul(multiplier, math.max(1, parts.SocialMultiplier))
	multiplier = omegaMath.Mul(multiplier, parts.MasteryMultiplier)
	multiplier = omegaMath.Mul(multiplier, parts.ContinuumProduction)
	return multiplier
end

function CapacityProjection.SteadyProduction(omegaMath, rawProduction: any, parts: SteadyParts): any
	return omegaMath.Mul(rawProduction, CapacityProjection.SteadyMultiplier(omegaMath, parts))
end

export type CapacitySecondsParts = {
	BaseSeconds: number,
	SecondsPerLevel: number,
	StorageLevel: number,
	-- Additive capacity fractions (1+x each), Economy order:
	-- Grid, Echo, Artifact, Item, Anomaly, Lab, Pass, Guild, ForgePath.
	Additives: { number },
	DomainRank: number,
	CapacityPerRank: number,
	BoostCapacityMultiplier: number,
	MaxSeconds: number,
	DomainTreeCapacity: number,
}

-- Vault fill-time in seconds. DomainTreeCapacity is applied AFTER the max clamp
-- (matches Economy.Capacity — do not reorder).
function CapacityProjection.Seconds(parts: CapacitySecondsParts): number
	local seconds = parts.BaseSeconds * (parts.SecondsPerLevel ^ parts.StorageLevel)
	for _, additive in parts.Additives do
		seconds *= 1 + additive
	end
	seconds *= 1 + parts.DomainRank * parts.CapacityPerRank
	seconds *= parts.BoostCapacityMultiplier
	seconds = math.clamp(seconds, 1, parts.MaxSeconds)
	seconds *= 1 + parts.DomainTreeCapacity
	return seconds
end

-- Vault size from steady output × seconds × continuum capacity scale.
function CapacityProjection.Vault(
	omegaMath,
	baseCapacity: number,
	steadyProduction: any,
	seconds: number,
	continuumCapacity: any
): any
	return omegaMath.Floor(omegaMath.Max(
		baseCapacity,
		omegaMath.Mul(omegaMath.Mul(steadyProduction, seconds), continuumCapacity)
	))
end

-- Display helper: capacity / steady → effective seconds (0 when idle).
function CapacityProjection.CapacitySeconds(omegaMath, capacity: any, steadyProduction: any, lte: (any, any) -> boolean): number
	if lte(steadyProduction, 0) then
		return 0
	end
	return omegaMath.ToNumber(omegaMath.Div(capacity, steadyProduction))
end

return table.freeze(CapacityProjection)
