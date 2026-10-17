--!strict
-- The Domain Lattice: a fixed figure of thirteen anchors (the Hearth at the centre, an inner ring
-- of six, an outer ring of six) and the thirty links between them. Domain points etch links. An
-- anchor's bonus fills with the links that touch it; every closed triangle (a facet) adds
-- production on top. Links have to grow out of the Hearth, and the whole lattice can be cleared
-- for a full refund once per domain rank. Pure: the server rules and the client both use it.

local DomainLattice = {}

export type Anchor = {
	index: number,
	name: string,
	kind: string,
	ring: number,
	angle: number,
	full: number,
}

local INNER = { "Capacity", "Tap", "RebirthYield", "Critical", "EchoCharge", "ContinuumDiscount" }
local OUTER = { "Offline", "Luck", "WorldDiscount", "EssenceGain", "ForgePathXP", "CommandXP" }
local NAMES = {
	Production = "Hearth",
	Capacity = "Cistern",
	Tap = "Anvil",
	RebirthYield = "Kiln",
	Critical = "Flint",
	EchoCharge = "Bellows",
	ContinuumDiscount = "Crucible",
	Offline = "Ember Bed",
	Luck = "Lodestone",
	WorldDiscount = "Waystone",
	EssenceGain = "Wellspring",
	ForgePathXP = "Ledger",
	CommandXP = "Banner",
}
-- the bonus an anchor gives with every one of its links etched
local FULL = {
	Production = 0.3,
	Capacity = 0.36,
	Tap = 0.27,
	RebirthYield = 0.25,
	Critical = 0.2,
	EchoCharge = 0.2,
	ContinuumDiscount = 0.15,
	Offline = 0.12,
	Luck = 0.08,
	WorldDiscount = 0.2,
	EssenceGain = 2,
	ForgePathXP = 0.12,
	CommandXP = 0.15,
}
DomainLattice.FACET_PRODUCTION = 0.015
DomainLattice.HEARTH = 1

local anchors: { Anchor } = {}
table.insert(anchors, { index = 1, name = NAMES.Production, kind = "Production", ring = 0, angle = 0, full = FULL.Production })
for i, kind in INNER do
	table.insert(anchors, { index = 1 + i, name = NAMES[kind], kind = kind, ring = 1, angle = (i - 1) * 60 - 90, full = FULL[kind] })
end
for i, kind in OUTER do
	table.insert(anchors, { index = 7 + i, name = NAMES[kind], kind = kind, ring = 2, angle = (i - 1) * 60 - 60, full = FULL[kind] })
end
DomainLattice.ANCHORS = anchors

local function inner(i: number): number
	return 1 + ((i - 1) % 6) + 1
end
local function outer(i: number): number
	return 7 + ((i - 1) % 6) + 1
end

function DomainLattice.key(a: number, b: number): string
	if a > b then
		a, b = b, a
	end
	return `{a}-{b}`
end

-- every link the figure has, and every triangle three of them close
local edges = {}
local edgeSet = {}
local function edge(a: number, b: number)
	local k = DomainLattice.key(a, b)
	if not edgeSet[k] then
		edgeSet[k] = true
		table.insert(edges, { a = math.min(a, b), b = math.max(a, b), key = k })
	end
end
for i = 1, 6 do
	edge(1, inner(i))
	edge(inner(i), inner(i + 1))
	edge(outer(i), inner(i))
	edge(outer(i), inner(i + 1))
	edge(outer(i), outer(i + 1))
end
DomainLattice.EDGES = edges
local triangles = {}
for i = 1, 6 do
	table.insert(triangles, { 1, inner(i), inner(i + 1) })
	table.insert(triangles, { inner(i), inner(i + 1), outer(i) })
	table.insert(triangles, { outer(i), outer(i + 1), inner(i + 1) })
end
DomainLattice.TRIANGLES = triangles

function DomainLattice.isEdge(a: number, b: number): boolean
	return edgeSet[DomainLattice.key(a, b)] == true
end

-- where an anchor sits, in units of the inner ring's radius
function DomainLattice.position(index: number): (number, number)
	local anchor = anchors[index]
	if anchor == nil or anchor.ring == 0 then
		return 0, 0
	end
	local radius = if anchor.ring == 1 then 1 else 1.92
	local r = math.rad(anchor.angle)
	return math.cos(r) * radius, math.sin(r) * radius
end

local maxDegree = {}
for _, e in edges do
	maxDegree[e.a] = (maxDegree[e.a] or 0) + 1
	maxDegree[e.b] = (maxDegree[e.b] or 0) + 1
end
function DomainLattice.maxDegree(index: number): number
	return maxDegree[index] or 0
end

-- links come as a set { ["a-b"] = true }; anything that isn't a real edge is ignored
function DomainLattice.count(links: any): number
	local n = 0
	if type(links) == "table" then
		for k, v in links do
			if v == true and edgeSet[k] then
				n += 1
			end
		end
	end
	return n
end
function DomainLattice.degrees(links: any): { [number]: number }
	local degree = {}
	if type(links) == "table" then
		for _, e in edges do
			if links[e.key] == true then
				degree[e.a] = (degree[e.a] or 0) + 1
				degree[e.b] = (degree[e.b] or 0) + 1
			end
		end
	end
	return degree
end

-- the next link costs more every six links
function DomainLattice.linkCost(etched: number): number
	return 1 + math.floor(math.max(0, etched) / 6)
end
-- points spent on the first n links
function DomainLattice.spent(n: number): number
	local total = 0
	for i = 0, n - 1 do
		total += DomainLattice.linkCost(i)
	end
	return total
end

function DomainLattice.canEtch(links: any, a: any, b: any, points: number): (boolean, string?)
	if type(a) ~= "number" or type(b) ~= "number" or a ~= a or b ~= b then
		return false, "Pick two anchors."
	end
	a, b = math.floor(a), math.floor(b)
	if not DomainLattice.isEdge(a, b) then
		return false, "Those anchors aren't joined."
	end
	local set = if type(links) == "table" then links else {}
	if set[DomainLattice.key(a, b)] == true then
		return false, "Already etched."
	end
	local degree = DomainLattice.degrees(set)
	local touches = a == DomainLattice.HEARTH or b == DomainLattice.HEARTH or (degree[a] or 0) > 0 or (degree[b] or 0) > 0
	if not touches then
		return false, "Links grow out from the Hearth."
	end
	local cost = DomainLattice.linkCost(DomainLattice.count(set))
	if points < cost then
		return false, if cost == 1 then "Need 1 domain point." else `Need {cost} domain points.`
	end
	return true, nil
end

-- the triangles whose three links are all etched
function DomainLattice.facets(links: any): { number }
	local closed = {}
	if type(links) ~= "table" then
		return closed
	end
	for index, t in triangles do
		if links[DomainLattice.key(t[1], t[2])] == true and links[DomainLattice.key(t[2], t[3])] == true and links[DomainLattice.key(t[1], t[3])] == true then
			table.insert(closed, index)
		end
	end
	return closed
end

-- what an anchor gives right now
function DomainLattice.anchorBonus(index: number, degree: number?): number
	local anchor = anchors[index]
	if anchor == nil then
		return 0
	end
	local d = math.clamp(degree or 0, 0, maxDegree[index] or 1)
	return anchor.full * d / math.max(1, maxDegree[index] or 1)
end

-- the total bonus of one kind ("Production", "Capacity", ...) from a set of links
function DomainLattice.bonus(links: any, kind: string): number
	if type(links) ~= "table" then
		return 0
	end
	local degree = DomainLattice.degrees(links)
	local total = 0
	for _, anchor in anchors do
		if anchor.kind == kind then
			total += DomainLattice.anchorBonus(anchor.index, degree[anchor.index])
		end
	end
	if kind == "Production" then
		total += #DomainLattice.facets(links) * DomainLattice.FACET_PRODUCTION
	end
	return total
end

-- how a kind reads on screen ("+12% vault capacity")
local TEXT = {
	Production = "%s production",
	Capacity = "%s vault capacity",
	Tap = "%s overcharge power",
	RebirthYield = "%s cores from rebirths",
	Critical = "%s critical strike chance",
	EchoCharge = "%s faster Forge Echoes",
	ContinuumDiscount = "%s Star Foundry resonance",
	Offline = "%s offline yield",
	Luck = "%s crate and market luck",
	WorldDiscount = "%s off world unlocks",
	EssenceGain = "%s essence per expansion",
	ForgePathXP = "%s forge path XP",
	CommandXP = "%s command XP",
}
function DomainLattice.describe(kind: string, amount: number): string
	local value
	if kind == "EssenceGain" then
		value = string.format("+%.1f", amount):gsub("%.0$", "")
	else
		local pct = amount * 100
		value = if pct >= 10 or pct == math.floor(pct) then string.format("+%d%%", math.floor(pct + 0.5)) else string.format("+%.1f%%", pct)
	end
	return string.format(TEXT[kind] or "%s", value)
end

-- Keep only real links that still connect back to the Hearth. Returns the clean set and how many
-- points the dropped ones are worth.
function DomainLattice.sanitize(links: any): ({ [string]: boolean }, number)
	local before = DomainLattice.count(links)
	local clean = {}
	if type(links) == "table" then
		local reached = { [DomainLattice.HEARTH] = true }
		local grew = true
		while grew do
			grew = false
			for _, e in edges do
				if links[e.key] == true and clean[e.key] == nil and (reached[e.a] or reached[e.b]) then
					clean[e.key] = true
					reached[e.a] = true
					reached[e.b] = true
					grew = true
				end
			end
		end
	end
	local after = DomainLattice.count(clean)
	return clean, DomainLattice.spent(before) - DomainLattice.spent(after)
end

-- the old twenty-node tree, refunded in full when a save first meets the lattice
local OLD_NODE_COST = {
	FluxVein = 2, VaultLattice = 2, EmberCore = 2, NightHarvest = 2, StarWell = 3, PrismGate = 3, EchoChamber = 3,
	HorizonKey = 3, RealityAnchor = 4, DomainPulse = 4, ContinuumBind = 4, OverchargeChannel = 5, TideLock = 4,
	VaultHeartNode = 4, EmberWell = 4, ApexLattice = 6, ForgeMnemonic = 3, SignalCrown = 4, VaultSpire = 5, AstralCrown = 7,
}
function DomainLattice.oldTreeRefund(nodes: any): number
	local total = 0
	if type(nodes) == "table" then
		for id, owned in nodes do
			if owned == true or owned == 1 then
				total += OLD_NODE_COST[id] or 0
			end
		end
	end
	return total
end

return table.freeze(DomainLattice)
