--!strict
-- Purpose: Build the public, wager-free Quantum Roulette board for a player's next round.
-- Owner: Astral Forge arcade. Dependencies: none. Last-reviewed: 2026-10-07.

export type Zone = { Id: string, Start: number, Numbers: { number } }
export type Board = { Zones: { Zone }, Sink: number, Version: number, UntilShift: number, Phase: string }

local PHASES = { "Split zones", "Merged zones", "Single squares" }

local function of(gameRound: number): Board
	local safeRound = math.max(0, math.floor(gameRound))
	local version = math.floor(safeRound / 3)
	local phase = version % #PHASES
	local zones: { Zone } = {}
	local first = 1
	while first <= 36 do
		local variation = (version * 47 + first * 13 + phase * 19) % 11
		local width = if phase == 0
			then (if variation < 2 then 1 elseif variation < 5 then 3 else 2)
			elseif phase == 1 then (if variation < 3 then 2 else 6)
			else (if variation == 0 then 2 else 1)
		local numbers = {}
		for number = first, math.min(first + width - 1, 36) do
			table.insert(numbers, number)
		end
		table.insert(zones, { Id = "Q" .. tostring(first), Start = first, Numbers = numbers })
		first += #numbers
	end
	-- The sink moves only at a board shift and never hides its own location.
	local sink = (version * 17 + 11) % 37
	return {
		Zones = zones,
		Sink = sink,
		Version = version,
		UntilShift = 3 - safeRound % 3,
		Phase = PHASES[phase + 1],
	}
end

return table.freeze({ of = of })
