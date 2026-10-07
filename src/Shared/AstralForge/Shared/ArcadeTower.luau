--!strict
-- Purpose: Resolve the score-only Infinite Card Tower with recoverable column state.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/ArcadeConfig. Last-reviewed: 2026-10-07.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")

export type API = {
	begin: (round: Types.Round, request: Types.Request, stream: Types.Stream) -> (boolean, string?),
	act: (round: Types.Round, request: Types.Request) -> (boolean, string?),
}

local STREAM_SIZE = 120

local function total(cards: Types.Numbers): number
	local value, aces = 0, 0
	for _, card in cards do
		value += math.min(card, 10)
		if card == 1 then
			aces += 1
		end
	end
	if aces > 0 and value + 10 <= 21 then
		value += 10
	end
	return value
end

local function score(tower: Types.TowerState): number
	return math.clamp(tower.Hands * 140 + tower.Placed * 5, 0, Config.MaximumScore)
end

local function begin(round: Types.Round, request: Types.Request, stream: Types.Stream): (boolean, string?)
	local slots = request.Choice
	if type(slots) ~= "number" or (slots ~= 3 and slots ~= 4) then
		return false, "Choose three or four columns."
	end
	for index = 1, STREAM_SIZE do
		round.Numbers[index] = stream.integer(1, 13)
	end
	round.Tower = {
		Slots = slots,
		Columns = table.create(slots),
		CurrentCard = round.Numbers[1],
		Hands = 0,
		Placed = 0,
	}
	for index = 1, slots do
		round.Tower.Columns[index] = {}
	end
	round.Cursor = 1
	round.Draws = stream.drawCount()
	round.Label = "Place the incoming card in a column. Build 21s to grow your score."
	return true, nil
end

local function act(round: Types.Round, request: Types.Request): (boolean, string?)
	local tower = round.Tower
	if tower == nil then
		return false, "This tower round has no saved column state."
	end
	if request.Action == "Stop" then
		round.Score = score(tower)
		round.Finished = true
		round.Label = "Tower run complete"
		return true, nil
	end
	if request.Action ~= "Place" then
		return false, "Place the current card or finish the tower run."
	end
	local columnIndex = request.Choice
	if type(columnIndex) ~= "number" or columnIndex % 1 ~= 0 or columnIndex < 1 or columnIndex > tower.Slots then
		return false, "Choose one of the open columns."
	end
	local column = tower.Columns[columnIndex]
	if #column >= 5 then
		return false, "That column is full."
	end
	table.insert(column, tower.CurrentCard)
	tower.Placed += 1
	local value = total(column)
	if value > 21 or (#column >= 5 and value ~= 21) then
		round.Score = score(tower)
		round.Finished = true
		round.Label = if value > 21 then `Column {columnIndex} went over 21` else `Column {columnIndex} filled`
		return true, nil
	end
	if value == 21 then
		tower.Hands += 1
		tower.Columns[columnIndex] = {}
		round.Score = score(tower)
		round.Label = "21! Column cleared. Keep building or finish your run."
	else
		round.Score = score(tower)
		round.Label = `Column {columnIndex}: {value}. Place the next card.`
	end
	round.Cursor += 1
	local nextCard = round.Numbers[round.Cursor]
	if nextCard == nil then
		round.Finished = true
		round.Label = "Card stream complete"
		return true, nil
	end
	tower.CurrentCard = nextCard
	return true, nil
end

local api: API = { begin = begin, act = act }
return table.freeze(api)
