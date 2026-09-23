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


-- Permanent production multiplier parts (cores ^ exp, domain rank/essence, rebirths).
-- Domain-tree / ForgePath / Insight addends are injected so Economy stays the
-- catalog owner while the arithmetic stays Lune-testable.
function EconomyEnvelopeMath.PermanentMultiplier(
	cores: any,
	coreMultiplier: any,
	coreExponent: any,
	rank: any,
	essence: any,
	essenceCap: any,
	productionPerRank: any,
	productionPerEssence: any,
	domainTreeBonus: any,
	forgePathProduction: any,
	rebirths: any,
	rebirthMultiplier: any,
	forgePathRebirth: any,
	insightLevel: any
): number
	local safeCores = math.max(0, tonumber(cores) or 0)
	local coreBonus = (tonumber(coreMultiplier) or 0) * (safeCores ^ (tonumber(coreExponent) or 0))
	local safeRank = math.max(0, tonumber(rank) or 0)
	local safeEssence = math.max(0, tonumber(essence) or 0)
	local cap = tonumber(essenceCap) or 1_000_000
	if safeEssence > cap then
		safeEssence = cap
	end
	local safeRebirths = math.max(0, tonumber(rebirths) or 0)
	local domainMultiplier = 1
		+ safeRank * (tonumber(productionPerRank) or 0)
		+ safeEssence * (tonumber(productionPerEssence) or 0)
		+ (tonumber(domainTreeBonus) or 0)
		+ (tonumber(forgePathProduction) or 0)
	local rebirthScale = (tonumber(rebirthMultiplier) or 0)
		* (1 + (tonumber(forgePathRebirth) or 0))
		* (1 + math.max(0, tonumber(insightLevel) or 0) * 0.02)
	return (1 + coreBonus + safeRebirths * rebirthScale) * domainMultiplier
end

-- Sum equipped relic effects for `effectKind`. `getDefinition(id)` resolves catalogs;
-- Machines/Research owned levels gate socket eligibility. Partial Items bags → 0.
function EconomyEnvelopeMath.ItemEffect(
	items: any,
	machines: any,
	research: any,
	effectKind: any,
	getDefinition: ((any) -> any)?,
	slotFilter: any?,
	targetFilter: any?
): number
	if type(items) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	local equipped = items.Equipped
	local inventory = items.Inventory
	if type(equipped) ~= "table" or type(inventory) ~= "table" then
		return 0
	end
	local resolve = getDefinition
	if type(resolve) ~= "function" then
		return 0
	end
	local total = 0
	for target, uid in equipped do
		local instance = inventory[uid]
		local definition = instance and resolve(instance.DefinitionId)
		local slot, targetId = string.match(tostring(target), "^(%a+):([%w_]+)$")
		local ownedLevel = if slot == "Machine" and type(machines) == "table"
			then machines[targetId]
			elseif slot == "Research" and type(research) == "table"
			then research[targetId]
			else nil
		if
			type(definition) == "table"
			and type(ownedLevel) == "number"
			and ownedLevel > 0
			and definition.EffectKind == effectKind
			and (not slotFilter or slot == slotFilter)
			and (not targetFilter or target == targetFilter)
		then
			total += EconomyEnvelopeMath.EffectAtLevel(definition, instance.Level)
		end
	end
	return total
end

return table.freeze(EconomyEnvelopeMath)
