--!strict
-- Star Foundry: the rules, as pure functions (no Roblox services), shared by server, client and tests.
--
-- A hex board (axial coordinates q, r). Pieces sit on cells and face one of six sides:
--   Ember    a source: emits energy out of its facing side
--   Conduit  carries what it receives out of its facing side (a little loss, less at higher tiers)
--   Lens     focuses everything it receives out of its facing side, stronger
--   Prism    splits what it receives three ways (facing, facing+2, facing+4)
--   Anvils   sinks that turn the energy reaching them into a bonus:
--            ForgeAnvil -> production, StrikeAnvil -> tap, VaultAnvil -> capacity, EchoAnvil -> offline
-- Two identical pieces (kind and tier) fuse into one of the next tier.
--
-- Flow is computed, not simulated: every Ember sends its energy along the board, a piece is
-- crossed at most once per path (so loops cannot amplify forever), paths stop after MAX_HOPS,
-- trickles below MIN_FLOW are dropped and the whole walk has a hard STEP_BUDGET. Traversal order
-- is fixed (cells sorted, faces in order), so server and client always get the same answer.

local FoundryMath = {}

export type Piece = { Kind: string, Tier: number, Facing: number }
export type Board = { Radius: number, Pieces: { [string]: Piece } }
export type Flow = {
	Production: number, Tap: number, Capacity: number, Offline: number,
	Delivered: number, Wasted: number, Links: { { from: string, to: string, amount: number } },
	Lit: { [string]: number },
}

FoundryMath.MIN_RADIUS = 2
FoundryMath.MAX_RADIUS = 5
FoundryMath.MAX_HOPS = 24
FoundryMath.MIN_FLOW = 0.01
FoundryMath.STEP_BUDGET = 6000
FoundryMath.MAX_TIER = 40
FoundryMath.BENCH_CAP = 12
FoundryMath.EMBER_BASE = 10
FoundryMath.TIER_GROWTH = 2.2

FoundryMath.KINDS = table.freeze({
	Ember = { role = "source" },
	Conduit = { role = "relay" },
	Lens = { role = "relay" },
	Prism = { role = "split" },
	ForgeAnvil = { role = "sink", stat = "Production" },
	StrikeAnvil = { role = "sink", stat = "Tap" },
	VaultAnvil = { role = "sink", stat = "Capacity" },
	EchoAnvil = { role = "sink", stat = "Offline" },
})
-- what a draw from the shop can give, by weight
FoundryMath.DRAW_WEIGHTS = table.freeze({
	{ "Ember", 22 }, { "Conduit", 26 }, { "Lens", 12 }, { "Prism", 10 },
	{ "ForgeAnvil", 12 }, { "StrikeAnvil", 7 }, { "VaultAnvil", 7 }, { "EchoAnvil", 4 },
})

-- axial neighbours, clockwise from east
FoundryMath.DIRECTIONS = table.freeze({
	{ 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 },
})

function FoundryMath.key(q: number, r: number): string
	return `{q},{r}`
end

function FoundryMath.parse(key: string): (number?, number?)
	local q, r = string.match(key, "^(%-?%d+),(%-?%d+)$")
	return tonumber(q), tonumber(r)
end

function FoundryMath.onBoard(radius: number, q: number, r: number): boolean
	local s = -q - r
	return math.max(math.abs(q), math.abs(r), math.abs(s)) <= radius
end

function FoundryMath.cellCount(radius: number): number
	return 3 * radius * (radius + 1) + 1
end

function FoundryMath.cells(radius: number): { string }
	local list = {}
	for q = -radius, radius do
		for r = -radius, radius do
			if FoundryMath.onBoard(radius, q, r) then
				table.insert(list, FoundryMath.key(q, r))
			end
		end
	end
	table.sort(list)
	return list
end

function FoundryMath.validPiece(piece: any): boolean
	return type(piece) == "table"
		and type(piece.Kind) == "string" and FoundryMath.KINDS[piece.Kind] ~= nil
		and type(piece.Tier) == "number" and piece.Tier == math.floor(piece.Tier) and piece.Tier >= 1 and piece.Tier <= FoundryMath.MAX_TIER
		and type(piece.Facing) == "number" and piece.Facing == math.floor(piece.Facing) and piece.Facing >= 0 and piece.Facing <= 5
end

-- how strong a piece is at a tier
function FoundryMath.tierScale(tier: number): number
	return FoundryMath.TIER_GROWTH ^ (math.clamp(tier, 1, FoundryMath.MAX_TIER) - 1)
end
function FoundryMath.emberOutput(tier: number): number
	return FoundryMath.EMBER_BASE * FoundryMath.tierScale(tier)
end
local function relayGain(piece: Piece): number
	local t = math.clamp(piece.Tier, 1, FoundryMath.MAX_TIER) - 1
	if piece.Kind == "Conduit" then
		return math.min(1.25, 0.92 + 0.04 * t)
	elseif piece.Kind == "Lens" then
		return 1.8 * 1.12 ^ t
	elseif piece.Kind == "Prism" then
		return 0.6 * 1.12 ^ t
	end
	return 0
end
local function sinkGain(piece: Piece): number
	return 1.1 ^ (math.clamp(piece.Tier, 1, FoundryMath.MAX_TIER) - 1)
end

local function outputs(piece: Piece): { number }
	if piece.Kind == "Prism" then
		return { piece.Facing, (piece.Facing + 2) % 6, (piece.Facing + 4) % 6 }
	end
	return { piece.Facing }
end

function FoundryMath.flow(board: Board): Flow
	local radius = math.clamp(math.floor(tonumber(board.Radius) or FoundryMath.MIN_RADIUS), FoundryMath.MIN_RADIUS, FoundryMath.MAX_RADIUS)
	local pieces = board.Pieces or {}
	local result: Flow = { Production = 0, Tap = 0, Capacity = 0, Offline = 0, Delivered = 0, Wasted = 0, Links = {}, Lit = {} }
	local linkIndex: { [string]: number } = {}
	local steps = 0
	local function addLink(from: string, to: string, amount: number)
		local id = from .. ">" .. to
		local at = linkIndex[id]
		if at == nil then
			table.insert(result.Links, { from = from, to = to, amount = amount })
			linkIndex[id] = #result.Links
		else
			result.Links[at].amount += amount
		end
		result.Lit[to] = (result.Lit[to] or 0) + amount
	end
	local visiting: { [string]: boolean } = {}
	local function send(fromKey: string, q: number, r: number, direction: number, amount: number, hops: number)
		steps += 1
		if steps > FoundryMath.STEP_BUDGET or amount < FoundryMath.MIN_FLOW then
			result.Wasted += math.max(0, amount)
			return
		end
		local d = FoundryMath.DIRECTIONS[direction + 1]
		local nq, nr = q + d[1], r + d[2]
		local key = FoundryMath.key(nq, nr)
		local target = pieces[key]
		if not FoundryMath.onBoard(radius, nq, nr) or target == nil or not FoundryMath.validPiece(target) or visiting[key] or hops >= FoundryMath.MAX_HOPS then
			result.Wasted += amount
			return
		end
		addLink(fromKey, key, amount)
		local role = FoundryMath.KINDS[target.Kind].role
		if role == "sink" then
			local stat = FoundryMath.KINDS[target.Kind].stat
			local gained = amount * sinkGain(target)
			result[stat] += gained
			result.Delivered += gained
			return
		end
		if role == "source" then
			-- an ember is not a relay: what reaches it is lost
			result.Wasted += amount
			return
		end
		visiting[key] = true
		local gain = relayGain(target)
		for _, side in outputs(target) do
			send(key, nq, nr, side, amount * gain, hops + 1)
		end
		visiting[key] = nil
	end
	local keys = {}
	for key in pieces do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local piece = pieces[key]
		local q, r = FoundryMath.parse(key)
		if q ~= nil and r ~= nil and FoundryMath.onBoard(radius, q, r) and FoundryMath.validPiece(piece) and piece.Kind == "Ember" then
			visiting[key] = true
			send(key, q, r, piece.Facing, FoundryMath.emberOutput(piece.Tier), 0)
			visiting[key] = nil
		end
	end
	return result
end

-- what the energy is worth to the economy
function FoundryMath.effects(flow: Flow, surge: number?): { Production: number, Tap: number, Capacity: number, Offline: number }
	local boost = math.max(1, surge or 1)
	return {
		Production = 1 + flow.Production * boost / 10,
		Tap = 1 + flow.Tap * boost / 10,
		Capacity = 1 + flow.Capacity * boost / 12,
		Offline = math.min(0.45, flow.Offline * boost / 400),
	}
end

-- shards earned per second from everything the board delivers
function FoundryMath.shardRate(flow: Flow): number
	return math.sqrt(math.max(0, flow.Delivered)) * 0.02
end

function FoundryMath.drawCost(draws: number): number
	return math.floor(25 * 1.32 ^ math.max(0, draws))
end

function FoundryMath.expandCost(radius: number): number?
	if radius >= FoundryMath.MAX_RADIUS then
		return nil
	end
	return math.floor(400 * 6 ^ (radius - FoundryMath.MIN_RADIUS))
end

-- a draw: weighted kind; tier 1 most of the time, with a small chance of a better piece
function FoundryMath.draw(roll: number, tierRoll: number, bestTier: number): Piece
	local total = 0
	for _, entry in FoundryMath.DRAW_WEIGHTS do
		total += entry[2]
	end
	local pick = roll * total
	local kind = FoundryMath.DRAW_WEIGHTS[1][1]
	for _, entry in FoundryMath.DRAW_WEIGHTS do
		pick -= entry[2]
		if pick <= 0 then
			kind = entry[1]
			break
		end
	end
	local tier = 1
	if tierRoll > 0.97 then
		tier = math.max(1, math.floor(bestTier * 0.6))
	elseif tierRoll > 0.85 then
		tier = 2
	end
	return { Kind = kind, Tier = math.clamp(tier, 1, FoundryMath.MAX_TIER), Facing = 0 }
end

function FoundryMath.canFuse(a: Piece?, b: Piece?): boolean
	return a ~= nil and b ~= nil and a.Kind == b.Kind and a.Tier == b.Tier and a.Tier < FoundryMath.MAX_TIER
end

function FoundryMath.bestTier(board: Board, bench: { Piece }?): number
	local best = 1
	for _, piece in board.Pieces or {} do
		best = math.max(best, piece.Tier)
	end
	for _, piece in bench or {} do
		best = math.max(best, piece.Tier)
	end
	return best
end

-- Ignite: a wave sweeps round the board every PERIOD seconds; tapping while it crosses the target
-- angle (within WINDOW of a turn) is on beat.
FoundryMath.IGNITE_PERIOD = 2.4
FoundryMath.IGNITE_WINDOW = 0.07
FoundryMath.IGNITE_SURGE_AT = 10
FoundryMath.IGNITE_SURGE_SECONDS = 60
FoundryMath.IGNITE_SURGE = 1.5

function FoundryMath.wavePhase(startedAt: number, now: number): number
	return ((now - startedAt) / FoundryMath.IGNITE_PERIOD) % 1
end

function FoundryMath.targetPhase(board: Board): number
	-- the angle of the brightest anvil (or 0 with none), as a fraction of a turn
	local flow = FoundryMath.flow(board)
	local best, bestKey = -1, nil
	for key, amount in flow.Lit do
		local piece = (board.Pieces or {})[key]
		if piece and FoundryMath.KINDS[piece.Kind].role == "sink" and amount > best then
			best, bestKey = amount, key
		end
	end
	if bestKey == nil then
		return 0
	end
	local q, r = FoundryMath.parse(bestKey)
	local x = 1.5 * (q :: number)
	local y = math.sqrt(3) * ((r :: number) + (q :: number) / 2)
	return ((math.atan2(y, x) / (2 * math.pi)) % 1)
end

function FoundryMath.onBeat(phase: number, target: number): boolean
	local delta = math.abs(phase - target)
	return math.min(delta, 1 - delta) <= FoundryMath.IGNITE_WINDOW
end

function FoundryMath.igniteShards(flow: Flow, combo: number): number
	return math.max(1, math.floor((5 + FoundryMath.shardRate(flow) * 6) * (1 + 0.1 * math.min(combo, 20))))
end

-- Old saves: a Continuum rank and Reactor progress become a starter board worth about as much,
-- plus Shards. Returns the board, bench and shards to grant.
function FoundryMath.migrate(continuumRank: number, anomalyFragments: number, stabilizations: number): (Board, { Piece }, number)
	local rank = math.max(0, math.floor(continuumRank or 0))
	-- the old production multiplier was 1.16^rank (x1.5 every 25 ranks)
	local oldProduction = 1.16 ^ rank * 1.5 ^ math.floor(rank / 25)
	local needed = math.max(0, (oldProduction - 1) * 10)
	-- ember -> conduit -> forge anvil delivers emberOutput * 0.92
	local tier = 1
	while tier < FoundryMath.MAX_TIER and FoundryMath.emberOutput(tier) * 0.92 < needed do
		tier += 1
	end
	local pieces: { [string]: Piece } = {
		["-1,0"] = { Kind = "Ember", Tier = tier, Facing = 0 },
		["0,0"] = { Kind = "Conduit", Tier = 1, Facing = 0 },
		["1,0"] = { Kind = "ForgeAnvil", Tier = 1, Facing = 0 },
	}
	local bench: { Piece } = {
		{ Kind = "Ember", Tier = 1, Facing = 0 },
		{ Kind = "StrikeAnvil", Tier = 1, Facing = 0 },
	}
	local shards = math.floor(math.max(0, anomalyFragments or 0) * 4 + math.max(0, stabilizations or 0) * 25 + rank * 30)
	return { Radius = FoundryMath.MIN_RADIUS + (if rank >= 40 then 1 else 0), Pieces = pieces }, bench, shards
end

return table.freeze(FoundryMath)
