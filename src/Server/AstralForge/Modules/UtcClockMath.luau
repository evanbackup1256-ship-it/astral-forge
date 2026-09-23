--!strict
-- Pure UTC day / week / midnight helpers for shop restock clocks and
-- Progression daily/weekly rolls. No Roblox services — ServerServices /
-- ProgressionService and Lune verify scripts share this so day boundaries stay
-- testable without Studio. Pass `now` (unix seconds) for deterministic checks.

local UtcClockMath = {}

UtcClockMath.DAY_SECONDS = 86_400
UtcClockMath.WEEK_SECONDS = UtcClockMath.DAY_SECONDS * 7

function UtcClockMath.Day(now: any): number
	local seconds = tonumber(now) or 0
	return math.floor(seconds / UtcClockMath.DAY_SECONDS)
end

function UtcClockMath.Week(now: any): number
	local seconds = tonumber(now) or 0
	return math.floor(seconds / UtcClockMath.WEEK_SECONDS)
end

function UtcClockMath.NextMidnight(now: any): number
	return (UtcClockMath.Day(now) + 1) * UtcClockMath.DAY_SECONDS
end

return table.freeze(UtcClockMath)
