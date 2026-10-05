--!strict
local T = require("../src/Server/AstralForge/Modules/CasinoExpansionMath")
local Catalog = require("../src/Shared/AstralForge/Shared/CommerceCatalog")
local s = T.Ensure(nil)
assert(s.Chips == 1000 and not s.Tower.Active)
assert(T.CardTotal({ 1, 1, 9 }) == 21 and T.CardTotal({ 1, 13, 13 }) == 21)
local board = T.TableBoard()
for _, zone in board.Zones do
	local total = 0
	for number = 0, 36 do
		total += T.SettleRoulette(board, { [zone.Id] = 10 }, number)
	end
	assert(total == 360, "every standard bet returns 36/37 on average")
end
for phase = 0, 2 do
	local q = T.QuantumBoard(4, phase * 3)
	local covered = {}
	for _, zone in q.Zones do
		for _, n in zone.Numbers do
			assert(not covered[n])
			covered[n] = true
		end
	end
	for n = 0, 36 do
		assert(covered[n], "quantum covers all numbers once")
	end
	assert(T.SettleRoulette(q, { Q1 = 10, Q0 = 10 }, q.Sink) == 0, "sink never pays")
end
local q = { Zones = { { Id = "win", Numbers = { 6 }, Return = 36 } }, Sink = 3 }
assert(T.SettleRoulette(q, { win = 10 }, 6) == 720, "gravity doubles adjacent winners")
local original = s.Chips
for _, payload in
	{
		{ Game = "TableRoulette", Version = 0, Bets = { N1 = 0 } },
		{ Game = "TableRoulette", Version = 0, Bets = { N1 = 0 / 0 } },
		{ Game = "TableRoulette", Version = 0, Bets = { Fake = 10 } },
		{ Game = "TableRoulette", Version = 1, Bets = { N1 = 10 } },
		{ Game = "QuantumRoulette", Version = 0, Bets = { Q1 = 2000 } },
		{ Game = "CardTower", Action = "Start", Tier = 1, Slots = 5 },
	}
do
	local ok = T.Play(s, payload, function()
		return 0
	end)
	assert(not ok and s.Chips == original, "invalid requests cannot debit chips")
end
for i = 1, 3 do
	assert(T.Play(s, { Game = "QuantumRoulette", Version = 0, Bets = { Q1 = 10 } }, function()
		return 0.04
	end))
end
assert(s.QuantumRound == 3 and T.State(s).Quantum.Version == 1)
assert(not T.Play(s, { Game = "QuantumRoulette", Version = 0, Bets = { Q1 = 10 } }, function()
	return 0
end), "stale board rejected")
s = T.Ensure(nil)
assert(T.Play(s, { Game = "CardTower", Action = "Start", Tier = 1, Slots = 3 }, function()
	return 0
end))
local id = s.Tower.Id
assert(not T.Play(s, { Game = "CardTower", Action = "Start", Tier = 1, Slots = 3 }, function()
	return 0
end), "no double stake")
assert(not T.Play(s, { Game = "CardTower", Action = "Cashout", RoundId = id }, function()
	return 0
end), "no unearned bank")
assert(T.Play(s, { Game = "CardTower", Action = "Place", Column = 1, RoundId = id }, function()
	return 0.95
end))
assert(not T.Play(s, { Game = "CardTower", Action = "Place", Column = 1, RoundId = id }, function()
	return 0
end), "duplicate card rejected")
assert(T.Play(s, { Game = "CardTower", Action = "Place", Column = 1, RoundId = s.Tower.Id }, function()
	return 0.95
end))
assert(s.Tower.Hands == 1 and #s.Tower.Columns[1] == 0, "ace + a face clears 21")
local restored = T.Ensure(s)
assert(restored.Tower.Active and restored.Tower.Hands == 1, "tower persists")
assert(T.Play(restored, { Game = "CardTower", Action = "Cashout", RoundId = restored.Tower.Id }, function()
	return 0
end))
assert(restored.Chips == 1003 and restored.Played == 1)
local empty = T.Ensure({ Chips = 0 })
assert(T.Play(empty, { Game = "DiceTable", Action = "Refill" }, function()
	return 0
end) and empty.Chips == 1000)
local config = { DevProducts = {}, GamePasses = {} }
Catalog.Extend(config, { Products = {}, Passes = {} })
assert(#config.DevProducts == 22 and #config.GamePasses == 10)
local unique = {}
for _, item in config.DevProducts do
	assert(not unique[item.Key])
	unique[item.Key] = true
	assert(item.ProductId == 0 and item.StudioPrice > 0)
	if item.Donation then
		assert(next(item.Reward) == nil)
	else
		assert(next(item.Reward) ~= nil)
	end
end
for _, pass in config.GamePasses do
	assert(not unique[pass.Key])
	unique[pass.Key] = true
	assert(pass.ProductionBonus > 0 or pass.CapacityBonus > 0, "every pass has an applied benefit")
end
local profile = {}
local verified = { DevProducts = {}, GamePasses = {} }
Catalog.Extend(verified, require("../src/Shared/AstralForge/Shared/CommerceIds"))
local ids = {}
for _, item in verified.DevProducts do
	assert(item.ProductId > 0 and not ids[item.ProductId])
	ids[item.ProductId] = true
end
for _, item in verified.GamePasses do
	assert(item.PassId > 0 and not ids[item.PassId])
	ids[item.PassId] = true
end
assert(Catalog.RecordDonation(profile, 25).Total == 25)
assert(Catalog.RecordDonation(profile, 0 / 0).Total == 25 and profile.Donations.Count == 2)
print("[TEST] four practice tables, quantum shifts, gravity, tower replay/persistence and 32 commerce entries passed")
