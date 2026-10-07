--!strict
-- Purpose: Score-only round resolvers; there are no wallet, wager, payout or inventory mutations.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/ArcadeConfig. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")
local QuantumBoard = require("./ArcadeQuantumBoard")
export type API = { resolve: (round: Types.Round, request: Types.Request, stream: Types.Stream) -> (boolean, string?) }

local function integer(value: Types.Selection?, minimum: number, maximum: number): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < minimum or value > maximum then
		return nil
	end
	return value
end

local function resolve(round: Types.Round, request: Types.Request, stream: Types.Stream): (boolean, string?)
	if round.Game == "Slots" then
		for index = 1, 3 do
			round.Numbers[index] = stream.integer(1, Config.SlotSymbols)
		end
		local a, b, c = round.Numbers[1], round.Numbers[2], round.Numbers[3]
		round.Score = if a == b and b == c then 100 + a * 25 elseif a == b or a == c or b == c then 25 else 0
		round.Label = if a == b and b == c
			then "Three matching reels"
			elseif round.Score > 0 then "Two matching reels"
			else "No match"
	elseif round.Game == "Roulette" then
		local choice = integer(request.Choice, 0, Config.RoulettePockets - 1)
		if choice == nil then
			return false, "Choose a number from 0 to 36."
		end
		local landing = stream.integer(0, Config.RoulettePockets - 1)
		round.Choice = choice
		round.Numbers = { landing }
		round.Score = if choice == landing then 100 else 0
		round.Label = "Landed on " .. tostring(landing)
	elseif round.Game == "TableRoulette" then
		local choice = integer(request.Choice, 0, Config.RoulettePockets - 1)
		if choice == nil then
			return false, "Choose a table pocket from 0 to 36."
		end
		local landing = stream.integer(0, Config.RoulettePockets - 1)
		local wheel = { 0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26 }
		local wheelIndex: { [number]: number } = {}
		for index, pocket in wheel do
			wheelIndex[pocket] = index
		end
		local directDistance = math.abs(wheelIndex[choice] - wheelIndex[landing])
		local distance = math.min(directDistance, #wheel - directDistance)
		round.Choice = choice
		round.Numbers = { landing }
		round.Score = if distance == 0 then 300 elseif distance == 1 then 40 else 0
		round.Label = if distance == 0
			then `Exact pocket: {landing}`
			elseif distance == 1 then `One pocket away: {landing}`
			else `Ball landed on {landing}`
	elseif round.Game == "QuantumRoulette" then
		local zoneStart = integer(request.Choice, 1, 36)
		local board = QuantumBoard.of(round.GameRound or 0)
		local selectedZone
		for _, zone in board.Zones do
			if zone.Start == zoneStart then
				selectedZone = zone
				break
			end
		end
		if selectedZone == nil and zoneStart == 0 then
			selectedZone = { Id = "Q0", Start = 0, Numbers = { 0 } }
		end
		if selectedZone == nil then
			return false, "Choose a zone from the current quantum layout."
		end
		local landing = stream.integer(0, Config.RoulettePockets - 1)
		local hitsSink = landing == board.Sink
		local hitsZone = table.find(selectedZone.Numbers, landing) ~= nil
		local adjacentToSink = if landing == 0
			then board.Sink >= 1 and board.Sink <= 3
			elseif board.Sink == 0 then landing <= 3
			else math.abs(landing - board.Sink) == 3
				or (math.floor((landing - 1) / 3) == math.floor((board.Sink - 1) / 3)
					and math.abs(landing - board.Sink) == 1)
		local baseScore = math.floor(900 / #selectedZone.Numbers)
		round.Choice = zoneStart
		round.Numbers = { landing, board.Sink, board.Version }
		round.Score = if hitsZone and not hitsSink
			then math.min(Config.MaximumScore, baseScore * (if adjacentToSink then 2 else 1))
			else 0
		round.Label = if hitsSink
			then `Gravity Sink swallowed pocket {landing}`
			elseif hitsZone and adjacentToSink then `Pocket {landing} hit beside the Sink · score doubled`
			elseif hitsZone then `Pocket {landing} matched your zone`
			else `Pocket {landing} missed your zone`
	elseif round.Game == "Dice" then
		local choice = integer(request.Choice, 2, 12)
		if choice == nil then
			return false, "Choose a total from 2 to 12."
		end
		round.Numbers = { stream.integer(1, 6), stream.integer(1, 6) }
		local sum = round.Numbers[1] + round.Numbers[2]
		round.Choice = choice
		round.Score = if sum == choice then 100 elseif math.abs(sum - choice) == 1 then 10 else 0
		round.Label = "Rolled " .. tostring(sum)
	elseif round.Game == "DiceTable" then
		local choice = integer(request.Choice, 2, 12)
		if choice == nil then
			return false, "Choose a total from 2 to 12."
		end
		round.Numbers = { stream.integer(1, 6), stream.integer(1, 6) }
		local sum = round.Numbers[1] + round.Numbers[2]
		round.Choice = choice
		round.Score = if sum == choice then 120 elseif math.abs(sum - choice) == 1 then 15 else 0
		round.Label = `Dice: {round.Numbers[1]} + {round.Numbers[2]} = {sum}`
	elseif round.Game == "CoinFlip" then
		if request.Choice ~= "Heads" and request.Choice ~= "Tails" and request.Choice ~= "Edge" then
			return false, "Choose heads, tails or edge."
		end
		local outcome = stream.integer(1, Config.CoinOutcomes)
		local face = if outcome == Config.CoinOutcomes then "Edge" elseif outcome <= 99 then "Heads" else "Tails"
		round.Numbers = { outcome }
		round.Choice = request.Choice
		round.Score = if request.Choice == face then (if face == "Edge" then 1000 else 50) else 0
		round.Label = face
	elseif round.Game == "Keno" then
		local picks = request.Picks or {}
		if #picks < 1 or #picks > Config.KenoDraws then
			return false, "Choose one to ten distinct numbers."
		end
		local selected: { [number]: boolean } = {}
		for _, pick in picks do
			if not integer(pick, 1, Config.KenoNumbers) or selected[pick] then
				return false, "Numbers must be distinct and between 1 and 40."
			end
			selected[pick] = true
		end
		local pool: Types.Numbers = {}
		for value = 1, Config.KenoNumbers do
			pool[value] = value
		end
		local matches = 0
		for index = 1, Config.KenoDraws do
			local target = stream.integer(index, #pool)
			pool[index], pool[target] = pool[target], pool[index]
			round.Numbers[index] = pool[index]
			if selected[pool[index]] then
				matches += 1
			end
		end
		round.Revealed = table.clone(picks)
		round.Score = matches * matches * 10
		round.Label = tostring(matches) .. " matching numbers"
	elseif round.Game == "Plinko" then
		local rights = 0
		for row = 1, Config.PlinkoRows do
			local direction = stream.integer(0, 1)
			round.Numbers[row] = direction
			rights += direction
		end
		round.Choice = rights
		round.Score = Config.PlinkoScores[rights + 1]
		round.Label = "Bin " .. tostring(rights + 1)
	else
		return false, "This game requires interactive round controls."
	end
	round.Draws = stream.drawCount()
	round.Finished = true
	return true, nil
end

local api: API = { resolve = resolve }
return table.freeze(api)
