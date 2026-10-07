--!strict
-- Purpose: Guard the public arcade against legacy wager routes and verify shifting score-only quantum layouts.
local fs = require("@lune/fs")
local Config = require("../src/Shared/AstralForge/Shared/ArcadeConfig")
local Board = require("../src/Shared/AstralForge/Shared/ArcadeQuantumBoard")

local expected = { TableRoulette = true, QuantumRoulette = true, CardTower = true, DiceTable = true }
local found = {}
for _, game in Config.Games do
	if expected[game.Id] then
		found[game.Id] = true
	end
end
for game in expected do
	assert(found[game], `missing score-only arcade game: {game}`)
end

local previousSignature = nil
for roundNumber = 0, 8 do
	local board = Board.of(roundNumber)
	assert(board.UntilShift == 3 - roundNumber % 3)
	assert(board.Sink >= 0 and board.Sink <= 36)
	local seen = { [0] = true }
	for _, zone in board.Zones do
		assert(#zone.Numbers > 0 and zone.Start == zone.Numbers[1])
		for _, number in zone.Numbers do
			assert(number >= 1 and number <= 36 and not seen[number], "zones must be disjoint table pockets")
			seen[number] = true
		end
	end
	for number = 0, 36 do
		assert(seen[number], `quantum layout does not cover pocket {number}`)
	end
	local signatureParts = { tostring(board.Sink) }
	for _, zone in board.Zones do
		table.insert(signatureParts, table.concat(zone.Numbers, ","))
	end
	local signature = table.concat(signatureParts, "|")
	if roundNumber % 3 == 0 then
		previousSignature = signature
	else
		assert(signature == previousSignature, "layout must remain stable for each three-round cycle")
	end
end
assert(Board.of(0).Phase == "Split zones")
assert(Board.of(3).Phase == "Merged zones")
assert(Board.of(6).Phase == "Single squares")

local service = fs.readFile("src/Server/AstralForge/Services/CasinoService.luau")
assert(service:find("Arcade games do not use currency wagers", 1, true), "legacy wager route must stay disabled")
assert(not service:find("PracticeTables", 1, true), "public casino state must not expose practice-chip tables")
assert(not service:find("casino.Arcade", 1, true), "legacy chip saves stay out of the public state")
local page = fs.readFile("src/Client/AstralForge/pages/PagesCasino.luau")
assert(not page:find("CasinoTables", 1, true), "retired wager UI must not be routable")
assert(page:find("ArcadePage).ArcadePage", 1, true), "the active casino view must use the score-only arcade")
local arcadePage = fs.readFile("src/Client/AstralForge/ArcadePage.luau")
for game in expected do
	assert(arcadePage:find(game, 1, true), `missing active UI route for {game}`)
end
assert(not pcall(fs.readFile, "src/Client/AstralForge/CasinoTables.luau"))
assert(not pcall(fs.readFile, "src/Server/AstralForge/Modules/CasinoExpansionMath.luau"))

print("[TEST] public casino uses the free arcade, legacy wager UI is removed, and quantum layouts shift every three rounds")
