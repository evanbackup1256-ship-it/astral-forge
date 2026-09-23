--!strict
-- Pure overcharge tap-combo window / multiplier. No Roblox services —
-- ServerServices and Lune verify scripts share this so combo math stays
-- testable without Studio. Config knobs are injected by the caller.

local OverchargeCombo = {}

function OverchargeCombo.Window(comboWindow: number): number
	return comboWindow
end

function OverchargeCombo.Multiplier(combo: number, comboMax: number, bonusPerStack: number): number
	return 1 + math.min(comboMax, math.max(0, combo)) * bonusPerStack
end

-- Advance combo after a successful tap within the window.
function OverchargeCombo.NextCombo(previousCombo: number, comboMax: number): number
	return math.min(comboMax, math.max(0, math.floor(previousCombo)) + 1)
end

-- True when the gap since last tap exceeds the combo window (combo resets).
function OverchargeCombo.Expired(elapsed: number, comboWindow: number): boolean
	return elapsed > comboWindow
end

return table.freeze(OverchargeCombo)
