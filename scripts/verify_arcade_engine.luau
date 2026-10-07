--!strict
-- Purpose: Exercise all score-only arcade kernels, action/replay fences, recovery and secret projections.
-- Owner: Astral Forge verification. Dependencies: ArcadeEngine/types/cards/registry, Lune serde. Last-reviewed: 2026-10-05.
local Types = require("../src/Shared/AstralForge/Shared/ArcadeTypes")
local Engine = require("../src/Shared/AstralForge/Shared/ArcadeEngine")
local Cards = require("../src/Shared/AstralForge/Shared/ArcadeCards")
local Registry = require("../src/Shared/AstralForge/Shared/RemoteRegistry")
local Hash = require("../src/Shared/AstralForge/Shared/ProofHash")
local Fair = require("../src/Shared/AstralForge/Shared/FairRandom")(Hash)
local Config = require("../src/Shared/AstralForge/Shared/ArcadeConfig")
local Tower = require("../src/Shared/AstralForge/Shared/ArcadeTower")
local serde = require("@lune/serde")
type Fixture = { Dependencies: Types.Dependencies, Time: number, Id: number, Seed: number }

local function fixture(): Fixture
	local value: Fixture = {
		Dependencies = {
			now = function(): number
				return 0
			end,
			newSeed = function(): string
				return ""
			end,
			newId = function(): string
				return ""
			end,
		},
		Time = 100,
		Id = 0,
		Seed = 0,
	}
	value.Dependencies = {
		now = function(): number
			return value.Time
		end,
		newId = function(): string
			value.Id += 1
			return "round-" .. tostring(value.Id)
		end,
		newSeed = function(): string
			value.Seed += 1
			return string.rep("test-secret-", 4) .. tostring(value.Seed)
		end,
	}
	return value
end

local function start(
	state: Types.State,
	f: Fixture,
	game: Types.GameId,
	choice: Types.Selection?,
	picks: Types.Numbers?,
	risk: number?
): (Types.Reply, Types.Request)
	f.Time += 1
	local request: Types.Request = {
		RequestId = "request-start-" .. tostring(f.Id + 1),
		Game = game,
		Action = "Start",
		Commitment = state.Commitment,
		ClientSeed = "player-seed",
		Nonce = state.Nonce,
		Choice = choice,
		Picks = picks,
		Risk = risk,
	}
	return Engine.apply(state, request, f.Dependencies), request
end

local function finishAction(
	state: Types.State,
	f: Fixture,
	action: string,
	choice: Types.Selection?,
	picks: Types.Numbers?
): (Types.Reply, Types.Request)
	local active = assert(state.Active)
	f.Time += 0.1
	local request: Types.Request = {
		RequestId = "request-action-" .. tostring(f.Id) .. "-" .. tostring(active.Version),
		Game = active.Game,
		Action = action,
		RoundId = active.Id,
		Version = active.Version,
		Choice = choice,
		Picks = picks,
	}
	return Engine.apply(state, request, f.Dependencies), request
end

local stream = Fair.create(string.rep("seed", 10), "test", 0, "Arcade.Deck")
local deck = Cards.deck(stream)
local seen: { [number]: boolean } = {}
for _, card in deck do
	assert(not seen[card])
	seen[card] = true
end
assert(#deck == 52 and stream.drawCount() >= 51)
assert(Cards.total({ 1, 13 }).Natural)
assert(Cards.total({ 1, 14, 9 }).Total == 21)
assert(Cards.total({ 1, 14, 27, 40, 10 }).Total == 14)
for _, sample in
	{
		{ Cards = { 1, 10, 11, 12, 13 }, Category = "RoyalFlush" },
		{ Cards = { 1, 2, 3, 4, 5 }, Category = "StraightFlush" },
		{ Cards = { 1, 14, 27, 40, 2 }, Category = "FourKind" },
		{ Cards = { 1, 14, 27, 2, 15 }, Category = "FullHouse" },
		{ Cards = { 1, 3, 6, 9, 12 }, Category = "Flush" },
		{ Cards = { 1, 15, 29, 43, 5 }, Category = "Straight" },
		{ Cards = { 1, 14, 27, 2, 16 }, Category = "ThreeKind" },
		{ Cards = { 1, 14, 2, 15, 3 }, Category = "TwoPair" },
		{ Cards = { 11, 24, 1, 2, 3 }, Category = "HighPair" },
	}
do
	assert(Cards.poker(sample.Cards).Category == sample.Category, sample.Category)
end
assert(not pcall(function(): ()
	Cards.poker({ 1, 1, 2, 3, 4 })
end))

local f = fixture()
local state = Engine.new(f.Dependencies)
for _, entry in Config.Games do
	local result, request = start(
		state,
		f,
		entry.Id,
		if entry.Id == "Roulette" or entry.Id == "TableRoulette"
			then 12
			elseif entry.Id == "QuantumRoulette" then 1
			elseif entry.Id == "Dice" or entry.Id == "DiceTable" then 7
			elseif entry.Id == "CardTower" then 3
			elseif entry.Id == "CoinFlip" then "Heads"
			else nil,
		if entry.Id == "Keno" then { 1, 2, 3, 4, 5 } else nil,
		if entry.Id == "Mines" then 3 else nil
	)
	assert(result.ok, result.error)
	local count = state.Stats.Played
	local duplicate = Engine.apply(state, request, f.Dependencies)
	assert(
		duplicate.ok and duplicate.Replayed and state.Stats.Played == count,
		"duplicate starts cannot add another result"
	)
	if state.Active then
		local public = Engine.snapshot(state)
		assert(
			not serde.encode("json", public):find(state.ServerSeed, 1, true),
			"the live seed must not appear in public state"
		)
		if entry.Id == "Blackjack" then
			assert(public.Active and #public.Active.DealerCards == 1)
		end
		local persisted: Types.State = serde.decode("json", serde.encode("json", state))
		state = persisted
		local action = if entry.Id == "Poker" then "Draw" elseif entry.Id == "Blackjack" then "Stand" else "Stop"
		local response, move = finishAction(state, f, action, nil, if entry.Id == "Poker" then { 1, 2 } else nil)
		assert(response.ok and response.Result, response.error)
		count = state.Stats.Played
		duplicate = Engine.apply(state, move, f.Dependencies)
		assert(duplicate.ok and duplicate.Replayed and state.Stats.Played == count)
	end
	local finished = state.History[1]
	assert(
		finished.Game == entry.Id
			and finished.Finished
			and finished.Score >= 0
			and finished.Score <= Config.MaximumScore
	)
	assert(Fair.verifyCommitment(finished.Reveal))
	assert(state.Commitment ~= finished.Proof.Commitment, "finished rounds rotate the seed before another round")
end
assert(state.Stats.Played == 14)

local towerFixture = fixture()
local towerState = Engine.new(towerFixture.Dependencies)
local towerStarted, towerRequest = start(towerState, towerFixture, "CardTower", 3, nil, nil)
assert(towerStarted.ok and towerStarted.Round and towerStarted.Round.Tower)
assert(towerStarted.Round.Tower.Slots == 3 and towerStarted.Round.Tower.CurrentCard >= 1)
local towerPublic = Engine.snapshot(towerState)
assert(towerPublic.Active and towerPublic.Active.Tower)
assert(not serde.encode("json", towerPublic.Active):find("Numbers", 1, true), "active card stream stays private")
assert(not serde.encode("json", towerPublic.Active):find(towerState.ServerSeed, 1, true))
towerPublic.Active.Tower.Columns[1][1] = -1
assert(towerState.Active and towerState.Active.Tower and towerState.Active.Tower.Columns[1][1] ~= -1, "public tower columns cannot alias saved state")
local badColumn, badColumnRequest = finishAction(towerState, towerFixture, "Place", 4, nil)
assert(not badColumn.ok and towerState.Active and towerState.Active.Version == 1)
local nextCard, placeRequest = finishAction(towerState, towerFixture, "Place", 1, nil)
assert(nextCard.ok and (nextCard.Round or nextCard.Result))
local towerPlayed = towerState.Stats.Played
local placeReplay = Engine.apply(towerState, placeRequest, towerFixture.Dependencies)
assert(placeReplay.ok and placeReplay.Replayed and towerState.Stats.Played == towerPlayed)
local restoredTower: Types.State = serde.decode("json", serde.encode("json", towerState))
assert(restoredTower.Active and restoredTower.Active.Tower)
assert(restoredTower.Active.Tower.CurrentCard == towerState.Active.Tower.CurrentCard)
assert(restoredTower.Active.Tower.Columns[1][1] == towerState.Active.Tower.Columns[1][1])
local expiredTower: Types.State = serde.decode("json", serde.encode("json", towerState))
local expiryFixture = fixture()
expiryFixture.Time = towerFixture.Time + Config.RoundLifetime + 1
local expiredResult = Engine.tick(expiredTower, expiryFixture.Dependencies)
assert(expiredResult and expiredResult.Score == 5 and expiredResult.Label:find("score saved", 1, true))
if restoredTower.Active then
	local stopped, stopRequest = finishAction(restoredTower, towerFixture, "Stop", nil, nil)
	assert(stopped.ok and stopped.Result and stopped.Result.Score <= Config.MaximumScore)
	local duplicateStop = Engine.apply(restoredTower, stopRequest, towerFixture.Dependencies)
	assert(duplicateStop.ok and duplicateStop.Replayed)
end
assert(not Tower.begin(assert(towerState.Active), { Choice = 5 } :: Types.Request, Fair.create(string.rep("tower-seed-", 4), "tower-test", 0, "Arcade.CardTower")))

local quantumFixture = fixture()
local quantumState = Engine.new(quantumFixture.Dependencies)
for roundIndex = 0, 5 do
	local quantumResult = start(quantumState, quantumFixture, "QuantumRoulette", 1, nil, nil)
	assert(quantumResult.ok and quantumResult.Result)
	assert(quantumResult.Result.Numbers[3] == math.floor(roundIndex / 3), "quantum layout shifts after every three completed games")
end

local activeFixture = fixture()
local activeState = Engine.new(activeFixture.Dependencies)
local opened = start(activeState, activeFixture, "Mines", nil, nil, 4)
assert(opened.ok and activeState.Active)
local active = assert(activeState.Active)
local originalVersion = active.Version
local invalid: Types.Request = {
	RequestId = "request-invalid-1",
	Game = "Mines",
	Action = "Reveal",
	RoundId = active.Id,
	Version = originalVersion - 1,
	Choice = 1,
}
assert(
	not Engine.apply(activeState, invalid, activeFixture.Dependencies).ok
		and activeState.Active
		and activeState.Active.Version == originalVersion
)
local secondStart = start(activeState, activeFixture, "Slots", nil, nil, nil)
assert(not secondStart.ok and activeState.Stats.Played == 0, "overlapping rounds must be rejected")
local safe = 1
while table.find(active.Numbers, safe) do
	safe += 1
end
local revealed, move = finishAction(activeState, activeFixture, "Reveal", safe, nil)
assert(revealed.ok and activeState.Active and #activeState.Active.Revealed == 1)
local conflict: Types.Request = table.clone(move)
conflict.Choice = safe + 1
assert(not Engine.apply(activeState, conflict, activeFixture.Dependencies).ok)
local old = table.clone(move)
old.RequestId = "request-evicted-1"
assert(
	not Engine.apply(activeState, old, activeFixture.Dependencies).ok,
	"version fence protects replay even without its old receipt"
)
local public = Engine.snapshot(activeState)
assert(public.Active and #public.Active.Revealed == 1)
public.Active.Revealed[1] = 999
assert(
	activeState.Active and activeState.Active.Revealed[1] == safe,
	"public state must not alias authoritative arrays"
)
activeFixture.Time += Config.RoundLifetime
assert(Engine.tick(activeState, activeFixture.Dependencies))
assert(activeState.Active == nil and activeState.History[1].Label == "Round expired")

local breaks = fixture()
local breakState = Engine.new(breaks.Dependencies)
for _ = 1, Config.SessionRounds do
	assert(start(breakState, breaks, "Slots", nil, nil, nil).ok)
end
assert(not start(breakState, breaks, "Slots", nil, nil, nil).ok and breakState.BreakUntil > breaks.Time)
breaks.Time = breakState.BreakUntil + 1
assert(start(breakState, breaks, "Slots", nil, nil, nil).ok)
for _ = 1, Config.ReceiptLimit + 5 do
	breaks.Time += Config.BreakSeconds
	assert(start(breakState, breaks, "Dice", 7, nil, nil).ok)
end
assert(#breakState.Receipts == Config.ReceiptLimit and #breakState.History == Config.HistoryLimit)

local wire: Registry.WireValue = {
	RequestId = "valid-request-01",
	Game = "Dice",
	Action = "Start",
	Choice = 7,
	Commitment = state.Commitment,
	Nonce = state.Nonce,
	ClientSeed = "seed",
}
assert(Registry.arcade(wire))
assert(Registry.arcade({
	RequestId = "valid-tower-start-01",
	Game = "CardTower",
	Action = "Start",
	Choice = 4,
	Commitment = state.Commitment,
	Nonce = state.Nonce,
	ClientSeed = "seed",
}))
assert(Registry.arcade({ RequestId = "valid-tower-place-01", Game = "CardTower", Action = "Place", Choice = 3, RoundId = "round", Version = 1 }))
assert(not Registry.arcade({ RequestId = "valid-cashout-01", Game = "CardTower", Action = "Cashout", RoundId = "round", Version = 1 }))
assert(Registry.readOnly({ Gen = 1, N = "session-nonce", TxnId = "transaction-id-01" }))
assert(not Registry.readOnly({ Gen = 1, N = "session-nonce", TxnId = "transaction-id-01", Stake = 1 }))
assert(not Registry.readOnly({ Gen = 0 / 0, N = "session-nonce", TxnId = "transaction-id-01" }))
local authenticated: Registry.TableValue = {
	RequestId = "valid-request-01",
	Game = "Dice",
	Action = "Start",
	Choice = 7,
	Commitment = state.Commitment,
	Nonce = state.Nonce,
	ClientSeed = "seed",
	Gen = 1,
	N = "session-nonce",
	TxnId = "transaction-id-01",
}
assert(
	Registry.arcade(authenticated),
	"sealed game payloads must coexist with the separately validated session envelope"
)
for _, key in { "Stake", "Amount", "Payout", "ServerSeed", "UserId", "StartedAt" } do
	local payload: Registry.TableValue = {
		RequestId = "valid-request-01",
		Game = "Dice",
		Action = "Start",
		Choice = 7,
		Commitment = state.Commitment,
		Nonce = state.Nonce,
		ClientSeed = "seed",
		[key] = 10,
	}
	assert(Registry.arcade(payload) == nil, "extra monetary/authority fields must be rejected")
end
assert(Registry.arcade({
	RequestId = "valid-request-01",
	Game = "Keno",
	Action = "Start",
	Commitment = state.Commitment,
	Nonce = state.Nonce,
	ClientSeed = "seed",
	Picks = { [1] = 2, [9] = 3 },
}) == nil)
assert(Registry.arcade({
	RequestId = "valid-request-01",
	Game = "Dice",
	Action = "Start",
	Commitment = state.Commitment,
	Nonce = 0 / 0,
	ClientSeed = "seed",
}) == nil)
assert(Registry.arcade({
	RequestId = "valid-request-01",
	Game = "CoinFlip",
	Action = "Start",
	Commitment = state.Commitment,
	Nonce = state.Nonce,
	ClientSeed = "seed",
	Choice = "<b>Heads</b>",
}) == nil)
print(
	"[TEST] fourteen score-only games, tower state/replay/persistence, decks/hand categories, action fences, private projections and break limits passed"
)
