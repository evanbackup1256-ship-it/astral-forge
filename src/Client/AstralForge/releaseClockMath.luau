--!strict
-- Pure release-countdown helpers for MainGame / PageRouter topbar + Overview.
-- No Roblox services — remaining/live gates stay Lune-testable. Server time
-- injection stays with the caller (Workspace:GetServerTimeNow / os.time).

local ReleaseClockMath = {}

-- Seconds remaining until `deadline` (unix). Never negative.
function ReleaseClockMath.Remaining(deadline: any, now: any): number
	return math.max(0, (tonumber(deadline) or 0) - (tonumber(now) or 0))
end

-- True when the deadline has elapsed (remaining == 0).
function ReleaseClockMath.IsLive(deadline: any, now: any): boolean
	return ReleaseClockMath.Remaining(deadline, now) <= 0
end

return table.freeze(ReleaseClockMath)
