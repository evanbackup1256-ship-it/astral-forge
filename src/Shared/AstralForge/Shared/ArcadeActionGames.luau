--!strict
-- Purpose: Server-time flight runs and persistent hidden-hazard surveys; no currency is consumed or earned.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/ArcadeConfig. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")
export type API = {
	begin: (round: Types.Round, request: Types.Request, stream: Types.Stream) -> (boolean, string?),
	act: (round: Types.Round, request: Types.Request, now: number) -> (boolean, string?),
	timeout: (round: Types.Round, now: number) -> boolean,
}

local function begin(round: Types.Round, request: Types.Request, stream: Types.Stream): (boolean, string?)
	if round.Game == "Crash" then
		round.Numbers = { Config.CrashMinimum + stream.unit() * (Config.CrashMaximum - Config.CrashMinimum) }
		round.Label = "Flight in progress"
	elseif round.Game == "Mines" then
		local risk = request.Risk or 5
		if risk ~= risk or risk % 1 ~= 0 or risk < 1 or risk > 12 then
			return false, "Choose one to twelve hazards."
		end
		round.Risk = risk
		local pool: Types.Numbers = {}
		for index = 1, Config.MinesCells do
			pool[index] = index
		end
		for index = 1, risk do
			local target = stream.integer(index, #pool)
			pool[index], pool[target] = pool[target], pool[index]
			round.Numbers[index] = pool[index]
		end
		round.Label = "Choose a tile"
	else
		return false, "This is not a flight or survey round."
	end
	round.Draws = stream.drawCount()
	return true, nil
end

local function timeout(round: Types.Round, now: number): boolean
	if round.Finished then
		return false
	end
	if round.Game == "Crash" and now - round.StartedAt >= round.Numbers[1] then
		round.Finished, round.Score, round.Label = true, 0, "Engine cut out"
		return true
	elseif now >= round.ExpiresAt then
		round.Finished = true
		if round.Game == "CardTower" then
			round.Label = "Tower run expired · score saved"
		else
			round.Score, round.Label = 0, "Round expired"
		end
		return true
	end
	return false
end

local function act(round: Types.Round, request: Types.Request, now: number): (boolean, string?)
	if timeout(round, now) then
		return true, nil
	end
	if request.Action == "Stop" then
		if round.Game == "Crash" then
			round.Score = math.floor(math.max(0, now - round.StartedAt) * 100)
			round.Label = "Safe landing"
		elseif round.Game == "Mines" then
			round.Score = #round.Revealed * 25
			round.Label = "Survey complete"
		else
			return false, "This round cannot be stopped."
		end
		round.Finished = true
		return true, nil
	end
	if round.Game ~= "Mines" or request.Action ~= "Reveal" then
		return false, "Choose a tile or stop the survey."
	end
	local tile = request.Choice
	if type(tile) ~= "number" or tile ~= tile or tile % 1 ~= 0 or tile < 1 or tile > Config.MinesCells then
		return false, "Choose a valid tile."
	end
	if table.find(round.Revealed, tile) then
		return false, "That tile is already revealed."
	end
	table.insert(round.Revealed, tile)
	if table.find(round.Numbers, tile) then
		round.Finished, round.Score, round.Label = true, 0, "Hazard found"
	elseif #round.Revealed == Config.MinesCells - round.Risk then
		round.Finished, round.Score, round.Label = true, #round.Revealed * 25, "Every clear tile found"
	else
		round.Score, round.Label = #round.Revealed * 25, "Clear tile"
	end
	return true, nil
end

local api: API = { begin = begin, act = act, timeout = timeout }
return table.freeze(api)
