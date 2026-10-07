--!strict
-- Purpose: Keep Ascension Path schema migration and respec accounting deterministic.
-- Owner: Astral Forge progression.
-- Dependencies: none.
-- Last-reviewed: 2026-10-07.

local AscensionPathMath = {}

export type DomainPath = {
	[string]: any,
	Rank: number?,
	SkillPoints: number?,
	Nodes: { [string]: any }?,
	RespecCount: number?,
	TreeVersion: number?,
}

export type RespecConfig = {
	SchemaVersion: number,
	BaseStardust: number,
	StardustPerRank: number,
	RepeatScale: number,
	MaxStardust: number,
}

export type RespecQuote = {
	CanRespec: boolean,
	Cost: number,
	RefundPoints: number,
	OwnedNodes: number,
	RespecCount: number,
	TreeVersion: number,
	Reason: string,
}

export type RespecResult = {
	Domain: DomainPath,
	Stardust: number,
	Quote: RespecQuote,
}

local function nonNegativeInteger(value: any, ceiling: number): number
	local numberValue = tonumber(value)
	if
		numberValue == nil
		or numberValue ~= numberValue
		or numberValue == math.huge
		or numberValue == -math.huge
	then
		return 0
	end
	return math.clamp(math.floor(numberValue), 0, ceiling)
end

local function knownNodeCosts(tree: { any }): { [string]: number }
	local costs: { [string]: number } = {}
	for _, node in tree do
		if type(node) == "table" and type(node.Id) == "string" and #node.Id > 0 and #node.Id <= 64 then
			costs[node.Id] = nonNegativeInteger(node.Cost, 100_000)
		end
	end
	return costs
end

function AscensionPathMath.Migrate(domain: DomainPath?, schemaVersion: number): DomainPath
	local source: DomainPath = if type(domain) == "table" then domain else {}
	local nodes = if type(source.Nodes) == "table" then source.Nodes else {}
	local currentVersion = nonNegativeInteger(schemaVersion, 100)
	local savedVersion = if source.TreeVersion == nil
		then currentVersion
		else nonNegativeInteger(source.TreeVersion, currentVersion)
	local migrated = table.clone(source)
	migrated.Rank = nonNegativeInteger(source.Rank, 10_000_000)
	migrated.SkillPoints = nonNegativeInteger(source.SkillPoints, 10_000_000)
	migrated.Nodes = table.clone(nodes)
	migrated.RespecCount = nonNegativeInteger(source.RespecCount, 1_000_000)
	migrated.TreeVersion = math.min(currentVersion, math.max(1, savedVersion))
	return migrated
end

function AscensionPathMath.QuoteRespec(
	domain: DomainPath?,
	tree: { any },
	stardust: any,
	config: RespecConfig
): RespecQuote
	local migrated = AscensionPathMath.Migrate(domain, config.SchemaVersion)
	local costs = knownNodeCosts(tree)
	local investedPoints = 0
	local ownedNodes = 0
	for nodeId, cost in costs do
		local owned = migrated.Nodes and migrated.Nodes[nodeId]
		if owned == true or owned == 1 then
			ownedNodes += 1
			investedPoints = math.min(10_000_000, investedPoints + cost)
		end
	end

	local rank = nonNegativeInteger(migrated.Rank, 10_000_000)
	local respecCount = nonNegativeInteger(migrated.RespecCount, 1_000_000)
	local growth = tonumber(config.RepeatScale)
	if growth == nil or growth ~= growth or growth < 1 then
		growth = 1
	end
	local baseCost = math.max(0, tonumber(config.BaseStardust) or 0)
	local rankCost = rank * math.max(0, tonumber(config.StardustPerRank) or 0)
	local rawCost = (baseCost + rankCost)
		* growth ^ math.min(respecCount, 40)
	local maximum = math.max(0, tonumber(config.MaxStardust) or 0)
	local cost = math.clamp(math.floor(math.min(rawCost, maximum)), 0, 1e12)
	local wallet = tonumber(stardust)
	if wallet == nil or wallet ~= wallet or wallet == math.huge or wallet == -math.huge then
		wallet = 0
	end
	wallet = math.max(0, wallet)

	local reason = ""
	if rank < 1 then
		reason = "Expand your Domain before resetting this path."
	elseif ownedNodes == 0 then
		reason = "There are no bound branches to reset."
	elseif wallet < cost then
		reason = "You need more Stardust to reset the path."
	end

	return {
		CanRespec = reason == "",
		Cost = cost,
		RefundPoints = investedPoints,
		OwnedNodes = ownedNodes,
		RespecCount = respecCount,
		TreeVersion = migrated.TreeVersion or config.SchemaVersion,
		Reason = reason,
	}
end

function AscensionPathMath.ApplyRespec(
	domain: DomainPath?,
	tree: { any },
	stardust: any,
	config: RespecConfig
): (RespecResult?, string?)
	local quote = AscensionPathMath.QuoteRespec(domain, tree, stardust, config)
	if not quote.CanRespec then
		return nil, quote.Reason
	end

	local nextDomain = AscensionPathMath.Migrate(domain, config.SchemaVersion)
	local nextNodes = table.clone(nextDomain.Nodes or {})
	local costs = knownNodeCosts(tree)
	for nodeId in costs do
		if nextNodes[nodeId] == true or nextNodes[nodeId] == 1 then
			nextNodes[nodeId] = nil
		end
	end
	nextDomain.Nodes = nextNodes
	nextDomain.SkillPoints = math.min(10_000_000, (nextDomain.SkillPoints or 0) + quote.RefundPoints)
	nextDomain.RespecCount = math.min(1_000_000, quote.RespecCount + 1)
	nextDomain.TreeVersion = math.max(config.SchemaVersion, quote.TreeVersion)
	local wallet = math.max(0, tonumber(stardust) or 0)

	return {
		Domain = nextDomain,
		Stardust = wallet - quote.Cost,
		Quote = quote,
	}, nil
end

return table.freeze(AscensionPathMath)
