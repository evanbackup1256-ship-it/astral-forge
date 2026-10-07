--!strict
-- Purpose: Explicit public round projections; active decks, hazards and server seeds never leave the server.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/FairRandom/ProofHash. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Hash = require("./ProofHash")
local Fair = require("./FairRandom")(Hash)
export type API = {
	round: (round: Types.Round) -> Types.PublicRound,
	finished: (round: Types.Round) -> Types.FinishedRound,
	state: (state: Types.State) -> Types.PublicState,
	cloneReply: (reply: Types.Reply) -> Types.Reply,
}

local function moves(source: { Types.Move }): { Types.Move }
	local result: { Types.Move } = {}
	for index, move in source do
		result[index] = { Action = move.Action, Choice = move.Choice, Picks = table.clone(move.Picks), At = move.At }
	end
	return result
end

local function round(source: Types.Round): Types.PublicRound
	local dealer = if source.Game == "Blackjack" and not source.Finished
		then { source.DealerCards[1] }
		else table.clone(source.DealerCards)
	return {
		Id = source.Id,
		Game = source.Game,
		Version = source.Version,
		StartedAt = source.StartedAt,
		ExpiresAt = source.ExpiresAt,
		PlayerCards = table.clone(source.PlayerCards),
		DealerCards = dealer,
		Revealed = table.clone(source.Revealed),
		Risk = source.Risk,
		Score = source.Score,
		Finished = source.Finished,
		Label = source.Label,
		Choice = source.Choice,
		Proof = Fair.proof(source.ServerSeed, source.ClientSeed, source.Nonce, "Arcade." .. source.Game),
	}
end

local function finished(source: Types.Round): Types.FinishedRound
	assert(source.Finished, "unfinished rounds cannot reveal their server seed")
	local public = round(source)
	local result: Types.FinishedRound = {
		Id = public.Id,
		Game = public.Game,
		Version = public.Version,
		StartedAt = public.StartedAt,
		ExpiresAt = public.ExpiresAt,
		PlayerCards = public.PlayerCards,
		DealerCards = public.DealerCards,
		Revealed = public.Revealed,
		Risk = public.Risk,
		Score = public.Score,
		Finished = true,
		Label = public.Label,
		Choice = public.Choice,
		Proof = public.Proof,
		Reveal = {
			Algorithm = public.Proof.Algorithm,
			Commitment = public.Proof.Commitment,
			ClientSeed = source.ClientSeed,
			Nonce = source.Nonce,
			Domain = public.Proof.Domain,
			ServerSeed = source.ServerSeed,
		},
		Numbers = table.clone(source.Numbers),
		Moves = moves(source.Moves),
		Draws = source.Draws,
	}
	return result
end

local function cloneRound(source: Types.PublicRound): Types.PublicRound
	local result: Types.PublicRound = table.clone(source)
	result.PlayerCards = table.clone(source.PlayerCards)
	result.DealerCards = table.clone(source.DealerCards)
	result.Revealed = table.clone(source.Revealed)
	result.Proof = table.clone(source.Proof)
	return result
end

local function cloneFinished(source: Types.FinishedRound): Types.FinishedRound
	local result: Types.FinishedRound = table.clone(source)
	result.PlayerCards = table.clone(source.PlayerCards)
	result.DealerCards = table.clone(source.DealerCards)
	result.Revealed = table.clone(source.Revealed)
	result.Proof = table.clone(source.Proof)
	result.Reveal = table.clone(source.Reveal)
	result.Numbers = table.clone(source.Numbers)
	result.Moves = moves(source.Moves)
	return result
end

local function state(source: Types.State): Types.PublicState
	local history: { Types.FinishedRound } = {}
	for index, entry in source.History do
		history[index] = cloneFinished(entry)
	end
	local stats: Types.Statistics = { Played = source.Stats.Played, TotalScore = source.Stats.TotalScore, ByGame = {} }
	for key, value in source.Stats.ByGame do
		stats.ByGame[key] = table.clone(value)
	end
	return {
		Schema = source.Schema,
		Nonce = source.Nonce,
		Commitment = source.Commitment,
		Active = if source.Active then round(source.Active) else nil,
		History = history,
		Stats = stats,
		BreakUntil = source.BreakUntil,
	}
end

local function cloneReply(source: Types.Reply): Types.Reply
	return {
		ok = source.ok,
		message = source.message,
		error = source.error,
		Round = if source.Round then cloneRound(source.Round) else nil,
		Result = if source.Result then cloneFinished(source.Result) else nil,
		Replayed = source.Replayed,
	}
end

local api: API = { round = round, finished = finished, state = state, cloneReply = cloneReply }
return table.freeze(api)
