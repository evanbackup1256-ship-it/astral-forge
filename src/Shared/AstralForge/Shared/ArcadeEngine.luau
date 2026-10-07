--!strict
-- Purpose: Version-fenced, replay-safe score-only arcade rounds that survive profile save/load.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/config/game kernels/views/FairRandom/ProofHash. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")
local Hash = require("./ProofHash")
local Fair = require("./FairRandom")(Hash)
local Instant = require("./ArcadeInstantGames")
local Cards = require("./ArcadeCardGames")
local Action = require("./ArcadeActionGames")
local Tower = require("./ArcadeTower")
local Views = require("./ArcadeViews")
export type API = {
	new: (dependencies: Types.Dependencies) -> Types.State,
	apply: (state: Types.State, request: Types.Request, dependencies: Types.Dependencies) -> Types.Reply,
	tick: (state: Types.State, dependencies: Types.Dependencies) -> Types.FinishedRound?,
	snapshot: (state: Types.State) -> Types.PublicState,
}

local function new(dependencies: Types.Dependencies): Types.State
	local seed = dependencies.newSeed()
	return {
		Schema = Config.Schema,
		Nonce = 0,
		ServerSeed = seed,
		Commitment = Fair.commitment(seed),
		Active = nil,
		History = {},
		Receipts = {},
		Stats = { Played = 0, TotalScore = 0, ByGame = {} },
		SessionRounds = 0,
		BreakUntil = 0,
		LastStartAt = -Config.StartCooldown,
	}
end

local function fail(message: string): Types.Reply
	return { ok = false, error = message }
end

local function fingerprint(request: Types.Request): string
	local fields: { string } = {}
	for _, value in
		{
			request.Game,
			request.Action,
			request.Commitment or "",
			request.ClientSeed or "",
			tostring(request.Nonce),
			request.RoundId or "",
			tostring(request.Version),
			type(request.Choice) .. ":" .. tostring(request.Choice),
			tostring(request.Risk),
		}
	do
		table.insert(fields, tostring(#value) .. ":" .. value)
	end
	for _, pick in request.Picks or {} do
		table.insert(fields, "pick:" .. tostring(pick))
	end
	return Hash.hex(table.concat(fields, "|"))
end

local function cloneRound(round: Types.Round): Types.Round
	local result: Types.Round = table.clone(round)
	result.Numbers = table.clone(round.Numbers)
	result.PlayerCards = table.clone(round.PlayerCards)
	result.DealerCards = table.clone(round.DealerCards)
	result.Revealed = table.clone(round.Revealed)
	result.Moves = table.clone(round.Moves)
	if round.Tower then
		result.Tower = { Slots = round.Tower.Slots, Columns = {}, CurrentCard = round.Tower.CurrentCard, Hands = round.Tower.Hands, Placed = round.Tower.Placed }
		for index, column in round.Tower.Columns do
			result.Tower.Columns[index] = table.clone(column)
		end
	end
	return result
end

local function complete(state: Types.State, round: Types.Round, nextSeed: string): Types.FinishedRound
	round.Score = math.clamp(math.floor(round.Score), 0, Config.MaximumScore)
	local result = Views.finished(round)
	state.Stats.Played = math.min(Config.ScoreTotalLimit, state.Stats.Played + 1)
	state.Stats.TotalScore = math.min(Config.ScoreTotalLimit, state.Stats.TotalScore + round.Score)
	local stats: Types.GameStats = state.Stats.ByGame[round.Game] or { Played = 0, BestScore = 0, TotalScore = 0 }
	stats.Played = math.min(Config.ScoreTotalLimit, stats.Played + 1)
	stats.BestScore = math.max(stats.BestScore, round.Score)
	stats.TotalScore = math.min(Config.ScoreTotalLimit, stats.TotalScore + round.Score)
	state.Stats.ByGame[round.Game] = stats
	table.insert(state.History, 1, result)
	if #state.History > Config.HistoryLimit then
		table.remove(state.History)
	end
	state.Active = nil
	state.Nonce += 1
	state.ServerSeed, state.Commitment = nextSeed, Fair.commitment(nextSeed)
	return result
end

local function tick(state: Types.State, dependencies: Types.Dependencies): Types.FinishedRound?
	local active = state.Active
	if not active then
		return nil
	end
	local candidate = cloneRound(active)
	if Action.timeout(candidate, dependencies.now()) then
		local seed = dependencies.newSeed()
		Fair.commitment(seed)
		local result = complete(state, candidate, seed)
		return Views.cloneReply({ ok = true, Result = result }).Result
	end
	return nil
end

local function apply(state: Types.State, request: Types.Request, dependencies: Types.Dependencies): Types.Reply
	local signature = fingerprint(request)
	for _, receipt in state.Receipts do
		if receipt.Id == request.RequestId then
			if receipt.Fingerprint ~= signature then
				return fail("That request ID belongs to another action.")
			end
			local replay = Views.cloneReply(receipt.Reply)
			replay.Replayed = true
			return replay
		end
	end
	local now = dependencies.now()
	assert(now == now and now >= 0 and now < math.huge, "invalid server time")
	local round: Types.Round
	if request.Action == "Start" then
		if state.Active then
			return fail("Finish your current round first.")
		end
		if now < state.BreakUntil then
			return fail("A short play break is active. Come back in a moment.")
		end
		if now - state.LastStartAt < Config.StartCooldown then
			return fail("Give the previous round a moment to finish.")
		end
		if request.Commitment ~= state.Commitment or request.Nonce ~= state.Nonce then
			return fail("The round commitment changed. Refresh before starting.")
		end
		if not request.ClientSeed then
			return fail("Choose a client seed before starting.")
		end
		local stream = Fair.create(state.ServerSeed, request.ClientSeed, state.Nonce, "Arcade." .. request.Game)
		round = {
			Id = dependencies.newId(),
			Game = request.Game,
			GameRound = (state.Stats.ByGame[request.Game] or { Played = 0, BestScore = 0, TotalScore = 0 }).Played,
			Version = 1,
			StartedAt = now,
			ExpiresAt = now + Config.RoundLifetime,
			ServerSeed = state.ServerSeed,
			ClientSeed = request.ClientSeed,
			Nonce = state.Nonce,
			Commitment = state.Commitment,
			Numbers = {},
			PlayerCards = {},
			DealerCards = {},
			Revealed = {},
			Cursor = 1,
			Risk = 0,
			Choice = request.Choice,
			Score = 0,
			Finished = false,
			Label = "Round started",
			Moves = {},
			Draws = 0,
		}
		local ok: boolean = true
		local problem: string? = nil
		if request.Game == "CardTower" then
			ok, problem = Tower.begin(round, request, stream)
		elseif request.Game == "Blackjack" or request.Game == "Poker" then
			Cards.begin(round, stream)
		elseif request.Game == "Crash" or request.Game == "Mines" then
			ok, problem = Action.begin(round, request, stream)
		else
			ok, problem = Instant.resolve(round, request, stream)
		end
		if not ok then
			return fail(problem or "The round could not start.")
		end
	else
		local active = state.Active
		if not active or active.Id ~= request.RoundId or active.Game ~= request.Game then
			return fail("That round is no longer active.")
		end
		if request.Version ~= active.Version then
			return fail("That action is out of date. Refresh the round.")
		end
		round = cloneRound(active)
		local ok: boolean = true
		local problem: string? = nil
		if request.Game == "CardTower" then
			if not Action.timeout(round, now) then
				ok, problem = Tower.act(round, request)
			end
		elseif request.Game == "Blackjack" or request.Game == "Poker" then
			if not Action.timeout(round, now) then
				ok, problem = Cards.act(round, request)
			end
		else
			ok, problem = Action.act(round, request, now)
		end
		if not ok then
			return fail(problem or "That action is unavailable.")
		end
		round.Version += 1
	end
	table.insert(
		round.Moves,
		{
			Action = request.Action,
			Choice = request.Choice,
			Picks = table.clone(request.Picks or {}),
			At = now - round.StartedAt,
		}
	)
	-- Prepare the next seed before mutating state, so a failed dependency cannot leave a partial transition.
	local nextSeed = if round.Finished then dependencies.newSeed() else ""
	if round.Finished then
		Fair.commitment(nextSeed)
	end
	if request.Action == "Start" then
		state.SessionRounds += 1
		state.LastStartAt = now
		if state.SessionRounds >= Config.SessionRounds then
			state.SessionRounds = 0
			state.BreakUntil = now + Config.BreakSeconds
		end
	end
	local reply: Types.Reply
	if round.Finished then
		reply = { ok = true, message = round.Label, Result = complete(state, round, nextSeed) }
	else
		state.Active = round
		reply = { ok = true, message = round.Label, Round = Views.round(round) }
	end
	table.insert(state.Receipts, { Id = request.RequestId, Fingerprint = signature, Reply = Views.cloneReply(reply) })
	if #state.Receipts > Config.ReceiptLimit then
		table.remove(state.Receipts, 1)
	end
	return Views.cloneReply(reply)
end

local api: API = { new = new, apply = apply, tick = tick, snapshot = Views.state }
return table.freeze(api)
