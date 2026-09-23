--!strict
-- Pure convergence event-profile / phase / multiplier helpers. No Roblox
-- services — ConvergenceService and Lune verify scripts share this so partial
-- LiveOps fixtures (EventId-matched bags missing Contribution/Claimed) rebuild
-- before Flush/Claim index nested fields. Reward cash mutation stays with the
-- caller (OmegaMath + profile bags).

local ConvergenceOpsMath = {}

export type EventProfile = {
	EventId: string,
	Contribution: number,
	Claimed: { [string]: any },
}

export type GlobalPhase = {
	Target: number,
	Name: string,
	ProductionMultiplier: number,
}

-- Mutating ensure for Flush/Claim paths. Mid-cycle bags that already share
-- EventId but omit Contribution (nil) used to throw on `Contribution += amount`.
function ConvergenceOpsMath.EnsureEventProfile(profile: any, eventId: string): EventProfile
	if type(profile.LiveOps) ~= "table" then
		profile.LiveOps = {}
	end
	local current = profile.LiveOps.Convergence
	if type(current) ~= "table" or current.EventId ~= eventId then
		current = { EventId = eventId, Contribution = 0, Claimed = {} }
		profile.LiveOps.Convergence = current
	end
	current.Claimed = type(current.Claimed) == "table" and current.Claimed or {}
	current.Contribution = math.max(0, tonumber(current.Contribution) or 0)
	if type(current.EventId) ~= "string" then
		current.EventId = eventId
	end
	return current :: EventProfile
end

-- Read-only snapshot for State() — never mutates profile.LiveOps.
function ConvergenceOpsMath.ReadEventProfile(profile: any, eventId: string): EventProfile
	local liveOps = type(profile) == "table" and type(profile.LiveOps) == "table" and profile.LiveOps or nil
	local current = liveOps and liveOps.Convergence or nil
	if type(current) ~= "table" or current.EventId ~= eventId then
		return { EventId = eventId, Contribution = 0, Claimed = {} }
	end
	return {
		EventId = eventId,
		Contribution = math.max(0, tonumber(current.Contribution) or 0),
		Claimed = type(current.Claimed) == "table" and current.Claimed or {},
	}
end

-- Rebuild Stats / Command / BoostInventory nests before Claim applies a tier
-- reward — same class of partial-fixture footgun as Anomaly/Echo Ensures.
function ConvergenceOpsMath.EnsureRewardBags(profile: any)
	if type(profile.Stats) ~= "table" then
		profile.Stats = {}
	end
	if type(profile.Command) ~= "table" then
		profile.Command = { Signals = 0 }
	end
	if type(profile.BoostInventory) ~= "table" then
		profile.BoostInventory = {}
	end
end

-- Highest unlocked global phase multiplier (1 when below first target).
function ConvergenceOpsMath.ProductionMultiplier(total: number, phases: { GlobalPhase }): number
	local multiplier = 1
	local safeTotal = math.max(0, tonumber(total) or 0)
	if type(phases) ~= "table" then
		return multiplier
	end
	for _, phase in phases do
		local target = tonumber(phase.Target) or 0
		local mult = tonumber(phase.ProductionMultiplier) or 1
		if safeTotal >= target then
			multiplier = mult
		else
			break
		end
	end
	return multiplier
end

-- Phase index/name + next Target for the progress rail.
function ConvergenceOpsMath.PhaseState(
	total: number,
	phases: { GlobalPhase }
): (number, string, number)
	local safeTotal = math.max(0, tonumber(total) or 0)
	local phaseIndex, phaseName = 0, "HEATING"
	local nextTarget = 0
	if type(phases) == "table" and phases[1] then
		nextTarget = tonumber(phases[1].Target) or 0
	end
	if type(phases) ~= "table" then
		return phaseIndex, phaseName, nextTarget
	end
	for index, phase in phases do
		local target = tonumber(phase.Target) or 0
		if safeTotal >= target then
			phaseIndex = index
			phaseName = if type(phase.Name) == "string" then phase.Name else phaseName
			local following = phases[index + 1]
			nextTarget = if following then (tonumber(following.Target) or target) else target
		else
			nextTarget = target
			break
		end
	end
	return phaseIndex, phaseName, nextTarget
end

-- Personal tier claim readiness (Contribution vs Required + Claimed flag).
function ConvergenceOpsMath.CanClaimTier(
	contribution: number,
	required: number,
	claimed: { [string]: any }?,
	tierIndex: number
): boolean
	local key = tostring(tierIndex)
	local already = type(claimed) == "table" and claimed[key] == true
	return not already and math.max(0, tonumber(contribution) or 0) >= math.max(0, tonumber(required) or 0)
end

return table.freeze(ConvergenceOpsMath)
