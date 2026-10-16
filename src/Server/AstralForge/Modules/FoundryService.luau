--!strict
-- Star Foundry on the server: the save shape, the one-time migration from Continuum/Reactor, every
-- player move (one FoundryAct action with an Op), passive Shards, Ignite timing and the public state.
-- The rules themselves live in FoundryMath (shared), so the client previews exactly what the server
-- will compute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FoundryMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("FoundryMath"))

local FoundryService = {}

local MAX_SHARDS = 1e15
local MAX_ACCRUE_SECONDS = 8 * 3600

local function finite(value: any, fallback: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return fallback
	end
	return n
end

-- recompute the bonuses the economy reads (stored, so production ticks never re-run the flow)
local function recompute(f)
	local flow = FoundryMath.flow({ Radius = f.Radius, Pieces = f.Pieces })
	local effects = FoundryMath.effects(flow)
	f.Effects = {
		Production = math.min(1e300, effects.Production),
		Tap = math.min(1e300, effects.Tap),
		Capacity = math.min(1e300, effects.Capacity),
		Offline = effects.Offline,
	}
	f.ShardRate = FoundryMath.shardRate(flow)
	f.Delivered = flow.Delivered
	f.Version = (tonumber(f.Version) or 0) + 1
	return flow
end

-- the save is always valid after this: bad cells, bad pieces and impossible numbers are dropped
function FoundryService.Ensure(profile, now: number?)
	local clock = now or os.time()
	local f = profile.Foundry
	if type(f) ~= "table" or f.Migrated ~= true then
		local continuum = type(profile.Continuum) == "table" and profile.Continuum or {}
		local anomaly = type(profile.Anomaly) == "table" and profile.Anomaly or {}
		local board, bench, shards = FoundryMath.migrate(finite(continuum.Rank, 0), finite(anomaly.Fragments, 0), finite(anomaly.Stabilizations, 0))
		f = {
			Migrated = true,
			Radius = board.Radius,
			Pieces = board.Pieces,
			Bench = bench,
			Shards = shards,
			Draws = 0,
			Combo = 0,
			BestCombo = 0,
			IgniteAt = clock,
			SurgeEndsAt = 0,
			LastAt = clock,
			Version = 0,
		}
		profile.Foundry = f
	end
	f.Radius = math.clamp(math.floor(finite(f.Radius, FoundryMath.MIN_RADIUS)), FoundryMath.MIN_RADIUS, FoundryMath.MAX_RADIUS)
	local clean = {}
	if type(f.Pieces) == "table" then
		for key, piece in f.Pieces do
			local q, r = nil, nil
			if type(key) == "string" then
				q, r = FoundryMath.parse(key)
			end
			if q ~= nil and r ~= nil and FoundryMath.onBoard(f.Radius, q, r) and FoundryMath.validPiece(piece) then
				clean[FoundryMath.key(q, r)] = { Kind = piece.Kind, Tier = piece.Tier, Facing = piece.Facing }
			end
		end
	end
	f.Pieces = clean
	local bench = {}
	if type(f.Bench) == "table" then
		for _, piece in f.Bench do
			if #bench < FoundryMath.BENCH_CAP and FoundryMath.validPiece(piece) then
				table.insert(bench, { Kind = piece.Kind, Tier = piece.Tier, Facing = piece.Facing })
			end
		end
	end
	f.Bench = bench
	f.Shards = math.clamp(finite(f.Shards, 0), 0, MAX_SHARDS)
	-- saves converted before the conversion was capped could start with trillions of Shards
	if f.ShardsCapped ~= true then
		f.ShardsCapped = true
		f.Shards = math.min(f.Shards, 60_000)
	end
	f.Draws = math.clamp(math.floor(finite(f.Draws, 0)), 0, 10_000)
	f.Combo = math.clamp(math.floor(finite(f.Combo, 0)), 0, 1000)
	f.BestCombo = math.clamp(math.floor(finite(f.BestCombo, 0)), 0, 1_000_000)
	f.IgniteAt = finite(f.IgniteAt, clock)
	f.SurgeEndsAt = finite(f.SurgeEndsAt, 0)
	f.LastAt = math.min(finite(f.LastAt, clock), clock)
	recompute(f)
	return f
end

-- passive Shards since the last visit (capped so a long absence is not a jackpot)
function FoundryService.Accrue(f, now: number)
	local elapsed = math.clamp(now - finite(f.LastAt, now), 0, MAX_ACCRUE_SECONDS)
	f.Shards = math.min(MAX_SHARDS, f.Shards + finite(f.ShardRate, 0) * elapsed)
	f.LastAt = now
end

-- where a piece comes from or goes to: a board cell "q,r" or a bench slot "bench:N"
local function slot(f, ref: any)
	if type(ref) ~= "string" or #ref > 16 then
		return nil
	end
	local index = string.match(ref, "^bench:(%d+)$")
	if index then
		local i = tonumber(index)
		if i and i >= 1 and i <= FoundryMath.BENCH_CAP then
			return { bench = true, index = i, piece = f.Bench[i] }
		end
		return nil
	end
	local q, r = FoundryMath.parse(ref)
	if q == nil or r == nil or not FoundryMath.onBoard(f.Radius, q, r) then
		return nil
	end
	local key = FoundryMath.key(q, r)
	return { bench = false, key = key, piece = f.Pieces[key] }
end

local function take(f, at)
	if at.bench then
		return table.remove(f.Bench, at.index)
	end
	local piece = f.Pieces[at.key]
	f.Pieces[at.key] = nil
	return piece
end

local function put(f, at, piece)
	if at.bench then
		if #f.Bench >= FoundryMath.BENCH_CAP then
			return false
		end
		table.insert(f.Bench, math.min(at.index, #f.Bench + 1), piece)
		return true
	end
	f.Pieces[at.key] = piece
	return true
end

-- One move. Returns ok, message, extra (extra.Sound names the cue the client should play).
function FoundryService.Act(profile, payload: any, random: Random, now: number)
	local f = FoundryService.Ensure(profile, now)
	FoundryService.Accrue(f, now)
	if type(payload) ~= "table" or type(payload.Op) ~= "string" then
		return false, "That foundry move is not valid."
	end
	local op = payload.Op
	if op == "place" or op == "move" or op == "fuse" or op == "store" then
		local from = slot(f, payload.From)
		local to = if op == "store" then { bench = true, index = #f.Bench + 1 } else slot(f, payload.To)
		if from == nil or to == nil or from.piece == nil then
			return false, "Pick a piece and a free cell."
		end
		if not from.bench and not to.bench and from.key == to.key then
			return false, "That piece is already there."
		end
		local moving = from.piece
		local target = if to.bench then nil else to.piece
		if target ~= nil then
			if not FoundryMath.canFuse(moving, target) then
				return false, "Only two identical pieces can fuse."
			end
			take(f, from)
			f.Pieces[to.key] = { Kind = target.Kind, Tier = target.Tier + 1, Facing = target.Facing }
			recompute(f)
			return true, `Fused into a tier {target.Tier + 1} {target.Kind}.`, { Sound = "foundryFuse", Cell = to.key }
		end
		if to.bench and #f.Bench >= FoundryMath.BENCH_CAP and not from.bench then
			return false, "The bench is full."
		end
		local piece = take(f, from)
		if not put(f, to, piece) then
			put(f, from, piece)
			return false, "The bench is full."
		end
		recompute(f)
		return true, nil, { Sound = if to.bench then "foundryPickUp" else "foundryPlace", Cell = to.key }
	elseif op == "rotate" then
		local at = slot(f, payload.At)
		if at == nil or at.bench or at.piece == nil then
			return false, "Pick a piece on the board."
		end
		local steps = if payload.Back == true then 5 else 1
		at.piece.Facing = (at.piece.Facing + steps) % 6
		recompute(f)
		return true, nil, { Sound = "foundryRotate", Cell = at.key }
	elseif op == "draw" then
		if #f.Bench >= FoundryMath.BENCH_CAP then
			return false, "Make room on the bench first."
		end
		local cost = FoundryMath.drawCost(f.Draws)
		if f.Shards < cost then
			return false, `You need {math.ceil(cost - f.Shards)} more Shards.`
		end
		f.Shards -= cost
		f.Draws += 1
		local piece = FoundryMath.draw(random:NextNumber(), random:NextNumber(), FoundryMath.bestTier({ Radius = f.Radius, Pieces = f.Pieces }, f.Bench))
		table.insert(f.Bench, piece)
		local rare = piece.Tier > 1
		return true, `New {piece.Kind}{if rare then ` (tier {piece.Tier})` else ""}.`, { Sound = if rare then "foundryDrawRare" else "foundryDraw", Piece = piece }
	elseif op == "expand" then
		local cost = FoundryMath.expandCost(f.Radius)
		if cost == nil then
			return false, "The foundry is as big as it gets."
		end
		if f.Shards < cost then
			return false, `You need {math.ceil(cost - f.Shards)} more Shards.`
		end
		f.Shards -= cost
		f.Radius += 1
		recompute(f)
		return true, `The foundry grew to {FoundryMath.cellCount(f.Radius)} cells.`, { Sound = "foundryExpand" }
	elseif op == "ignite" then
		local board = { Radius = f.Radius, Pieces = f.Pieces }
		local phase = FoundryMath.wavePhase(f.IgniteAt, now)
		local target = FoundryMath.targetPhase(board)
		if not FoundryMath.onBeat(phase, target) then
			f.Combo = 0
			return true, nil, { Sound = "foundryIgniteMiss", OnBeat = false }
		end
		f.Combo += 1
		f.BestCombo = math.max(f.BestCombo, f.Combo)
		local flow = FoundryMath.flow(board)
		local gained = FoundryMath.igniteShards(flow, f.Combo)
		f.Shards = math.min(MAX_SHARDS, f.Shards + gained)
		local surged = false
		if f.Combo % FoundryMath.IGNITE_SURGE_AT == 0 then
			f.SurgeEndsAt = now + FoundryMath.IGNITE_SURGE_SECONDS
			surged = true
		end
		return true, nil, { Sound = if surged then "foundrySurge" else "foundryIgnite", OnBeat = true, Gained = gained, Combo = f.Combo }
	end
	return false, "That foundry move is not valid."
end

-- the economy's view: production, capacity, tap multipliers and the offline bonus (Ignite surge applied)
function FoundryService.Effects(profile, now: number?): (number, number, number, number)
	local f = type(profile) == "table" and profile.Foundry or nil
	local e = type(f) == "table" and type(f.Effects) == "table" and f.Effects or nil
	if e == nil then
		return 1, 1, 1, 0
	end
	local surge = if finite(f.SurgeEndsAt, 0) > (now or os.time()) then FoundryMath.IGNITE_SURGE else 1
	local function boosted(value)
		local v = math.max(1, finite(value, 1))
		return math.min(1e300, 1 + (v - 1) * surge)
	end
	return boosted(e.Production), boosted(e.Capacity), boosted(e.Tap), math.clamp(finite(e.Offline, 0), 0, 0.45)
end

-- what the client sees
function FoundryService.State(profile, now: number)
	local f = profile.Foundry
	if type(f) ~= "table" or f.Migrated ~= true then
		return nil
	end
	local pending = math.clamp(now - finite(f.LastAt, now), 0, MAX_ACCRUE_SECONDS) * finite(f.ShardRate, 0)
	local production, capacity, tap, offline = FoundryService.Effects(profile, now)
	return {
		Radius = f.Radius,
		Pieces = f.Pieces,
		Bench = f.Bench,
		Shards = math.floor(math.min(MAX_SHARDS, f.Shards + pending)),
		ShardRate = f.ShardRate,
		DrawCost = FoundryMath.drawCost(f.Draws),
		ExpandCost = FoundryMath.expandCost(f.Radius),
		Combo = f.Combo,
		BestCombo = f.BestCombo,
		IgniteAt = f.IgniteAt,
		SurgeEndsAt = f.SurgeEndsAt,
		Effects = { Production = production, Capacity = capacity, Tap = tap, Offline = offline },
		Version = f.Version,
	}
end

return FoundryService
