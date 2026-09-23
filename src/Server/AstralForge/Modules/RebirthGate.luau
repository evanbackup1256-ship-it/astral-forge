--!strict
-- Pure rebirth eligibility / requirement / prestige-reward math. No Roblox
-- services — Economy, ServerServices, and Lune verify scripts share this so
-- rebirth gates can be tested without Studio. Profile mutation stays with callers.

local RebirthGate = {}

-- True when the player has enough rebirths for a gate (upgrade / zone / domain).
function RebirthGate.MeetsRequired(rebirths: number, required: number?): boolean
	local have = math.max(0, math.floor(tonumber(rebirths) or 0))
	local need = math.max(0, math.floor(tonumber(required) or 0))
	return have >= need
end

function RebirthGate.RequirementMessage(required: number): string
	local need = math.max(0, math.floor(tonumber(required) or 0))
	return string.format("Requires %d rebirths.", need)
end

-- Prestige core reward from run flux. Mirrors Economy.PrestigeReward exactly:
-- below requirement → 0; otherwise max(1, floor((run/req)^exponent)).
function RebirthGate.PrestigeReward(
	omegaMath,
	runCash: any,
	requirement: number,
	exponent: number,
	lt: (any, any) -> boolean
): any
	if lt(runCash, requirement) then
		return 0
	end
	local ratio = omegaMath.Div(runCash, requirement)
	return omegaMath.Max(1, omegaMath.Floor(omegaMath.Pow(ratio, exponent)))
end

-- Rebirth action is allowed when prestige reward is at least 1 core.
function RebirthGate.CanRebirth(prestigeReward: any, gte: (any, any) -> boolean): boolean
	return gte(prestigeReward, 1)
end

-- Stardust granted on a successful rebirth (sqrt of cores * scale, floored).
function RebirthGate.StardustReward(coreReward: number, scale: number, minimum: number): number
	local reward = math.max(0, tonumber(coreReward) or 0)
	local stardustScale = tonumber(scale) or 5
	local stardustMinimum = tonumber(minimum) or 4
	return math.max(stardustMinimum, math.floor(math.sqrt(reward) * stardustScale))
end

-- Run-cash target for the next prestige core after currentReward.
-- Mirrors Economy.NextPrestigeTarget: floor(req * (max(1, reward+1))^(1/exp)).
function RebirthGate.NextPrestigeTarget(
	omegaMath: any,
	currentReward: any,
	requirement: number,
	exponent: number
): any
	local desired = omegaMath.Max(1, omegaMath.Add(currentReward, 1))
	return omegaMath.Floor(omegaMath.Mul(requirement, omegaMath.Pow(desired, 1 / exponent)))
end

return table.freeze(RebirthGate)
