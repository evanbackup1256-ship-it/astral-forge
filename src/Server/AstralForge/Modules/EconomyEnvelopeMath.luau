--!strict
-- Pure economy envelope helpers: bag level sums, auto-collect / offline hours /
-- offline efficiency caps, mastery + domain-tree bonuses. No Roblox services —
-- Economy and Lune verify scripts share this so RunQuick-adjacent envelopes stay
-- offline-testable. Effect totals (grid/echo/…) are injected by the caller.

local EconomyEnvelopeMath = {}

-- Sums numeric values in a bag (Machines / Research). Non-tables → 0.
function EconomyEnvelopeMath.SumNumericLevels(bag: any): number
	if type(bag) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in bag do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end

-- Soft-capped auto-collect rate. Parts are already fractional addends.
function EconomyEnvelopeMath.AutoCollectRate(
	automationLevel: number,
	grid: number,
	echo: number,
	artifact: number,
	item: number,
	anomaly: number,
	guild: number,
	forgePath: number
): number
	return math.min(
		0.8,
		math.max(0, tonumber(automationLevel) or 0) * 0.02
			+ (tonumber(grid) or 0)
			+ (tonumber(echo) or 0)
			+ (tonumber(artifact) or 0)
			+ (tonumber(item) or 0)
			+ (tonumber(anomaly) or 0)
			+ (tonumber(guild) or 0)
			+ (tonumber(forgePath) or 0)
	)
end

-- Offline hours soft-capped at `cap` (default 24).
function EconomyEnvelopeMath.OfflineHours(
	baseHours: number,
	researchOffline: number,
	artifactOffline: number,
	cap: number?
): number
	local softCap = if type(cap) == "number" then cap else 24
	return math.min(
		softCap,
		(tonumber(baseHours) or 0)
			+ math.max(0, tonumber(researchOffline) or 0) * 1.25
			+ (tonumber(artifactOffline) or 0)
	)
end

-- Offline efficiency soft-capped at 1. Continuum offline addend is already a fraction.
function EconomyEnvelopeMath.OfflineEfficiency(
	baseEfficiency: number,
	researchOffline: number,
	grid: number,
	echo: number,
	artifact: number,
	item: number,
	anomaly: number,
	guild: number,
	domainRank: number,
	offlinePerRank: number,
	continuumOffline: number,
	forgePath: number
): number
	return math.min(
		1,
		(tonumber(baseEfficiency) or 0)
			+ math.max(0, tonumber(researchOffline) or 0) * 0.06
			+ (tonumber(grid) or 0)
			+ (tonumber(echo) or 0)
			+ (tonumber(artifact) or 0)
			+ (tonumber(item) or 0)
			+ (tonumber(anomaly) or 0)
			+ (tonumber(guild) or 0)
			+ math.max(0, tonumber(domainRank) or 0) * (tonumber(offlinePerRank) or 0)
			+ (tonumber(continuumOffline) or 0)
			+ (tonumber(forgePath) or 0)
	)
end

-- Machine mastery → production multiplier. Soft-caps at +50%.
function EconomyEnvelopeMath.MasteryMultiplier(machineMastery: any): number
	if type(machineMastery) ~= "table" then
		return 1
	end
	local points = 0
	for _, value in machineMastery do
		if type(value) == "number" then
			points += value
		end
	end
	return 1 + math.min(0.5, points * 0.002)
end

-- Domain tree node bonuses for a field (Production / Capacity / …).
-- `nodes` is profile.Domain.Nodes; `tree` is GameConfig.Domain.Tree.
function EconomyEnvelopeMath.DomainTreeBonus(nodes: any, tree: any, field: string): number
	if type(nodes) ~= "table" or type(tree) ~= "table" then
		return 0
	end
	local total = 0
	for _, node in tree do
		if type(node) == "table" and nodes[node.Id] == true then
			local amount = node[field]
			if type(amount) == "number" then
				total += amount
			end
		end
	end
	return total
end

return table.freeze(EconomyEnvelopeMath)
