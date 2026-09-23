--!strict
-- Pure forge-path claim gate + XP consume. No Roblox services — ProgressionService
-- and Lune verify scripts share this so step ordering / XP math can be tested
-- without Studio. Reward application stays in ProgressionService.ApplyReward.

local ForgePathClaim = {}

export type ForgePathBag = {
	XP: number,
	ClaimedSteps: { [string]: boolean },
}

export type StepLike = {
	XPCost: number,
	Reward: any?,
}

function ForgePathClaim.Ensure(forgePath): ForgePathBag
	if type(forgePath) ~= "table" then
		return { ClaimedSteps = {}, XP = 0, XPDay = -1, XPEarnedToday = 0 } :: any
	end
	if type(forgePath.ClaimedSteps) ~= "table" then
		forgePath.ClaimedSteps = {}
	end
	forgePath.XP = math.max(0, math.floor(tonumber(forgePath.XP) or 0))
	forgePath.XPDay = math.floor(tonumber(forgePath.XPDay) or -1)
	forgePath.XPEarnedToday = math.max(0, math.floor(tonumber(forgePath.XPEarnedToday) or 0))
	return forgePath
end

-- Mutates forgePath on success (deducts XP, marks ClaimedSteps).
-- Returns ok, errOrNil, stepOrNil — step is returned so callers can ApplyReward.
function ForgePathClaim.TryClaim(forgePath, rawStep: any, steps: { StepLike }): (boolean, string?, StepLike?)
	ForgePathClaim.Ensure(forgePath)
	if type(rawStep) ~= "number" then
		return false, "Invalid forge path step.", nil
	end
	local stepIndex = math.floor(rawStep)
	local step = steps[stepIndex]
	if not step then
		return false, "That forge path step doesn't exist.", nil
	end
	local key = tostring(stepIndex)
	if forgePath.ClaimedSteps[key] then
		return false, "That step was already claimed.", nil
	end
	if stepIndex > 1 and not forgePath.ClaimedSteps[tostring(stepIndex - 1)] then
		return false, "Claim the previous step first.", nil
	end
	if forgePath.XP < step.XPCost then
		return false, "Not enough forge XP for that step.", nil
	end
	forgePath.XP -= step.XPCost
	forgePath.ClaimedSteps[key] = true
	return true, nil, step
end

return table.freeze(ForgePathClaim)
