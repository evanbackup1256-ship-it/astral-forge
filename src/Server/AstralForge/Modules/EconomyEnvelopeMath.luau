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

-- Lab power channel bonus: routing cells × EffectPerCell. Missing channel → 0.
function EconomyEnvelopeMath.LabPowerEffect(routing: any, channelId: any, channel: any): number
	if type(routing) ~= "table" or type(channel) ~= "table" or type(channelId) ~= "string" then
		return 0
	end
	local perCell = tonumber(channel.EffectPerCell) or 0
	local cells = tonumber(routing[channelId]) or 0
	return math.max(0, cells) * perCell
end

-- Relic / item effect at level: BaseEffect * (1 + LevelGrowth * max(0, level-1)).
-- Matches InventoryMath.EffectAtLevel — keep formulas in lockstep via verify.
function EconomyEnvelopeMath.EffectAtLevel(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = if type(level) == "number" then level else 1
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

-- Artifact effect: EffectPerLevel * owned.Level when kinds match.
function EconomyEnvelopeMath.ArtifactLevelEffect(artifact: any, owned: any, effectKind: any): number
	if type(artifact) ~= "table" or type(owned) ~= "table" then
		return 0
	end
	if artifact.EffectKind ~= effectKind then
		return 0
	end
	local perLevel = tonumber(artifact.EffectPerLevel) or 0
	local level = tonumber(owned.Level) or 0
	return perLevel * math.max(0, level)
end

-- Grid upgrade bag → effect total for `effectKind`. `gridById` maps id → upgrade.
function EconomyEnvelopeMath.GridEffect(levels: any, gridById: any, effectKind: any): number
	if type(levels) ~= "table" or type(gridById) ~= "table" then
		return 0
	end
	local total = 0
	for id, level in levels do
		if type(level) == "number" and level > 0 then
			local upgrade = gridById[id]
			if type(upgrade) == "table" and upgrade.EffectKind == effectKind then
				local per = tonumber(upgrade.EffectPerLevel) or 0
				total += level * per
			end
		end
	end
	return total
end

return table.freeze(EconomyEnvelopeMath)
