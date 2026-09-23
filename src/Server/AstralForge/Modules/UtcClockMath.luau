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

-- Seconds remaining until `deadline` (unix). Never negative.
function UtcClockMath.Remaining(deadline: any, now: any): number
	return math.max(0, (tonumber(deadline) or 0) - (tonumber(now) or 0))
end

-- True when the deadline has elapsed (remaining == 0).
function UtcClockMath.IsLive(deadline: any, now: any): boolean
	return UtcClockMath.Remaining(deadline, now) <= 0
end

return table.freeze(UtcClockMath)
