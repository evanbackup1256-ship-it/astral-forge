--!strict
-- Purpose: Six score-only round resolvers; there are no wallet, wager, payout or inventory mutations.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/ArcadeConfig. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")
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
