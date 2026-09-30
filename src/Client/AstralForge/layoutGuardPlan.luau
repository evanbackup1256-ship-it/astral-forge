--!strict
-- Scheduling and thresholds for the layout guard (layoutGuard.luau).
--
-- The guard used to wake every two seconds and repair a slice of the tree, so
-- a label that overflowed after a page opened or a phone rotated could sit
-- broken for seconds. It now works every frame on a small budget:
--
--   * fresh work first -- anything just mounted or just repaired and awaiting
--     a check -- one frame after it appears, once the engine has measured it;
--   * a continuous background sweep over everything else, so a label whose
--     text grew is caught within about a second;
--   * a burst after a resize or rotation: a large budget for a dozen frames,
--     so the whole screen settles almost at once.
--
-- Pure numbers only, so scripts/verify_layout_realtime.luau can hold it to
-- its promises under Lune.

local Plan = {}

-- Per-frame budgets (instances inspected).
Plan.FRESH_PER_FRAME = 96
Plan.SWEEP_PER_FRAME = 48
Plan.BURST_PER_FRAME = 320
-- Frames of burst after a resize or rotation.
Plan.BURST_FRAMES = 12
-- A new instance waits this many frames so its AbsoluteSize is real.
Plan.SETTLE_FRAMES = 1
-- The sweep never restarts more often than this (a restart walks the tree).
Plan.MIN_SWEEP_SECONDS = 0.75
-- More fresh work than this and the rest rides the sweep instead.
Plan.FRESH_CAP = 4000
-- A repair that doesn't stick after this many tries is abandoned.
Plan.MAX_TRIES = 3
-- A resize smaller than this (either axis) is jitter, not a new layout.
Plan.RESIZE_SLOP = 8
-- On touch screens text below this size is raised when it still fits.
Plan.TOUCH_TEXT_FLOOR = 11
-- Text this small is decorative (glyph badges, tick marks); leave it alone.
Plan.TEXT_FLOOR_MIN_SOURCE = 7

export type Budget = { fresh: number, sweep: number }

-- How much to inspect this frame.
function Plan.budget(burstFramesLeft: number, freshWaiting: number): Budget
	if burstFramesLeft > 0 then
		-- Everything gets the burst budget; fresh work goes first within it.
		local fresh = math.min(freshWaiting, Plan.BURST_PER_FRAME)
		return { fresh = fresh, sweep = Plan.BURST_PER_FRAME - fresh }
	end
	return { fresh = math.min(freshWaiting, Plan.FRESH_PER_FRAME), sweep = Plan.SWEEP_PER_FRAME }
end

-- Did the screen change enough to call for a fresh layout pass?
function Plan.resized(lastWidth: number, lastHeight: number, width: number, height: number): boolean
	if lastWidth < 0 or lastHeight < 0 then
		return true
	end
	local rotated = (lastWidth > lastHeight) ~= (width > height) and math.abs(width - height) > Plan.RESIZE_SLOP
	return rotated or math.abs(width - lastWidth) >= Plan.RESIZE_SLOP or math.abs(height - lastHeight) >= Plan.RESIZE_SLOP
end

-- The size to raise a touch-screen label to, or nil to leave it.
function Plan.textFloor(touch: boolean, textSize: number, scaled: boolean): number?
	if not touch or scaled then
		return nil
	end
	if textSize >= Plan.TOUCH_TEXT_FLOOR or textSize < Plan.TEXT_FLOOR_MIN_SOURCE then
		return nil
	end
	return Plan.TOUCH_TEXT_FLOOR
end

-- Frames for one full sweep of `count` instances at the steady budget.
function Plan.sweepFrames(count: number): number
	return math.max(1, math.ceil(math.max(0, count) / Plan.SWEEP_PER_FRAME))
end

-- Seconds before a changed label is caught, worst case, at `fps`.
function Plan.worstCatchSeconds(count: number, fps: number): number
	return math.max(Plan.MIN_SWEEP_SECONDS, Plan.sweepFrames(count) / math.max(1, fps))
end

return table.freeze(Plan)
