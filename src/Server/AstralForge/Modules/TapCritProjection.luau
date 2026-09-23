--!strict
-- Pure tap power + critical chance/multiplier projection. No Roblox services —
-- Economy and Lune verify scripts share this so tap/crit math can be tested
-- without Studio. Effect totals (grid/echo/artifact/…) are injected by the caller.

local TapCritProjection = {}

export type TapBonuses = {
	Grid: number,
	Echo: number,
	Artifact: number,
	Item: number,
	Anomaly: number,
	Lab: number,
	Guild: number,
	-- Continuum tap scale is already a multiplier (not 1+x).
	Continuum: any,
	ForgePath: number,
}

-- Mirrors Economy.TapPower composition: max(1, production*0.15) then
-- Overcharge / effect / continuum / forge-path multipliers. Balance constants
-- (0.15 base share, 0.35 per Overcharge level) stay here intentionally.
function TapCritProjection.TapPower(omegaMath, production: any, overchargeLevel: number, bonuses: TapBonuses): any
	local tap = omegaMath.Max(1, omegaMath.Mul(production, 0.15))
	tap = omegaMath.Mul(tap, 1 + overchargeLevel * 0.35)
	tap = omegaMath.Mul(tap, 1 + bonuses.Grid)
	tap = omegaMath.Mul(tap, 1 + bonuses.Echo)
	tap = omegaMath.Mul(tap, 1 + bonuses.Artifact)
	tap = omegaMath.Mul(tap, 1 + bonuses.Item)
	tap = omegaMath.Mul(tap, 1 + bonuses.Anomaly)
	tap = omegaMath.Mul(tap, 1 + bonuses.Lab)
	tap = omegaMath.Mul(tap, 1 + bonuses.Guild)
	tap = omegaMath.Mul(tap, bonuses.Continuum)
	tap = omegaMath.Mul(tap, 1 + bonuses.ForgePath)
	return tap
end

-- Soft-capped critical chance. researchCritical is Research.Critical level.
function TapCritProjection.CriticalChance(
	researchCritical: number,
	grid: number,
	echo: number,
	artifact: number,
	item: number,
	anomaly: number,
	forgePath: number
): number
	return math.min(
		0.75,
		0.05
			+ researchCritical * 0.012
			+ grid
			+ echo
			+ artifact
			+ item
			+ anomaly
			+ forgePath
	)
end

-- Critical payout multiplier. Impact research + forge-path CriticalMultiplier.
function TapCritProjection.CriticalMultiplier(
	researchCritical: number,
	researchImpact: number,
	forgePath: number
): number
	return 2
		+ math.floor(researchCritical / 5) * 0.5
		+ researchImpact * 0.1
		+ forgePath
end

return table.freeze(TapCritProjection)
