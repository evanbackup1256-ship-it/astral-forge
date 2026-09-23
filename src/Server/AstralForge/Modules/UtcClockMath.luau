--!strict
-- Pure UTC day / midnight helpers for shop restock clocks. No Roblox services —
-- ServerServices and Lune verify scripts share this so day boundaries stay
-- testable without Studio. Pass `now` (unix seconds) for deterministic checks.

local UtcClockMath = {}

UtcClockMath.DAY_SECONDS = 86_400

function UtcClockMath.Day(now: any): number
	local seconds = tonumber(now) or 0
	return math.floor(seconds / UtcClockMath.DAY_SECONDS)
end

function UtcClockMath.NextMidnight(now: any): number
	return (UtcClockMath.Day(now) + 1) * UtcClockMath.DAY_SECONDS
end

return table.freeze(UtcClockMath)
