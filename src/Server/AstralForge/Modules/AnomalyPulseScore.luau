--!strict
-- Pure anomaly pulse-window / sweet-zone / combo scoring. No Roblox services —
-- AnomalyService and Lune verify scripts share this so timing accuracy and
-- combo multipliers can be tested without Studio. Clocks and profile mutation
-- stay with the caller; balance constants are injected (GameConfig values).

local AnomalyPulseScore = {}

-- Elapsed seconds within the current sweep (mod period). Callers that already
-- validated startedAt may use this directly; IsAccurate re-validates.
function AnomalyPulseScore.Elapsed(now: number, startedAt: number, period: number): number
	return (now - startedAt) % period
end

-- Fraction through the current window in [0, 1). Matches the client needle's
-- elapsed/period prediction (client also clamps period to >= 0.1 for display).
function AnomalyPulseScore.Fraction(now: number, startedAt: number, period: number): number
	local safePeriod = math.max(0.1, period)
	return AnomalyPulseScore.Elapsed(now, startedAt, safePeriod) / safePeriod
end

-- True when `now` lands in the trailing sweet-zone fraction of the sweep that
-- began at startedAt. Non-number / non-positive startedAt → miss (no window yet).
-- Mirrors the former AnomalyService.pulseAccuracy local exactly.
function AnomalyPulseScore.IsAccurate(
	now: number,
	startedAt: any,
	period: number,
	sweetZoneFraction: number
): boolean
	if type(startedAt) ~= "number" or startedAt <= 0 then
		return false
	end
	local elapsed = AnomalyPulseScore.Elapsed(now, startedAt, period)
	local sweetZone = period * sweetZoneFraction
	return elapsed >= period - sweetZone
end

-- Combo after one pulse. Miss resets to 0; hit increments, capped at comboMax.
function AnomalyPulseScore.NextCombo(currentCombo: number?, accurate: boolean, comboMax: number): number
	if not accurate then
		return 0
	end
	return math.min(comboMax, (currentCombo or 0) + 1)
end

function AnomalyPulseScore.NextBestCombo(bestCombo: number?, combo: number): number
	return math.max(bestCombo or 0, combo)
end

-- Multiplier from combo stacks: 1 + min(1, combo * bonusPerStack). Soft-caps
-- at 2x regardless of how high the combo climbs.
function AnomalyPulseScore.ComboBonus(combo: number, bonusPerStack: number): number
	return 1 + math.min(1, combo * bonusPerStack)
end

-- Multiplier from a sweet-zone hit: 1 + accurateBonus when accurate, else 1.
function AnomalyPulseScore.AccuracyBonus(accurate: boolean, accurateBonus: number): number
	if accurate then
		return 1 + accurateBonus
	end
	return 1
end

-- Combined score multiplier applied to pulse charge gain (combo × accuracy).
function AnomalyPulseScore.ScoreMultiplier(
	combo: number,
	accurate: boolean,
	bonusPerStack: number,
	accurateBonus: number
): number
	return AnomalyPulseScore.ComboBonus(combo, bonusPerStack)
		* AnomalyPulseScore.AccuracyBonus(accurate, accurateBonus)
end

return table.freeze(AnomalyPulseScore)
