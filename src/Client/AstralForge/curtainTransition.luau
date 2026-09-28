--!strict
-- Motion curves for the sanctuary rift curtain.
--
-- Opening the rift splits the shell down the middle and slides the two halves
-- off opposite edges, revealing the sanctuary. Both halves read one `travel`
-- value (0 shut .. 1 open), so they always move as an exact mirror pair.
--
-- Travel is a time-based tween driven on RenderStepped, not a spring, so there
-- is no overshoot and no settle wobble. Opening uses a quartic ease-out -- it
-- moves on the very first frame (no perceptible delay) at a speed the eye can
-- follow, then glides into place; closing uses a cubic ease-in-out so the
-- halves gather speed and meet softly instead of slamming. A reversal
-- mid-motion starts from wherever the halves are, and a partial run takes
-- proportionally less time.
--
-- Time advances by the frame's delta, capped at MAX_FRAME_STEP. Opening the
-- rift does one-off work (the right half's snapshot, the sanctuary's lighting,
-- streaming); a long frame from that used to leap the halves most of the way
-- across in one step. Now a slow frame just slows the curtain for a moment.
--
-- A dark veil sits behind the halves and hides the world until the sanctuary
-- is ready, so the camera move into the rift is never seen.
--
-- Pure: no Roblox instances, so the curves are unit tested under Lune
-- (scripts/verify_sanctuary_curtain.luau). sanctuaryChrome.luau draws them.

local Curtain = {}

Curtain.OPEN_SECONDS = 0.62
Curtain.CLOSE_SECONDS = 0.5
-- The most time one rendered frame may advance the curtain (seconds).
Curtain.MAX_FRAME_STEP = 1 / 40
-- How long the rift's loading (camera, lighting, streaming) waits after the
-- press, so it starts once the halves are mostly apart instead of competing
-- with their first frames.
Curtain.LOAD_HEAD_START = 0.36
-- Reduced motion keeps the same path and runs it in about half the time.
Curtain.REDUCED_SCALE = 0.55
-- A partial run (reversing mid-motion) never takes less than this share of a
-- full one, so a quick flick still reads as motion rather than a snap.
Curtain.MIN_RUN_SHARE = 0.35

-- How far each half travels, in screen widths. A half is 0.5 wide, so 0.5
-- clears the screen; the small extra carries the rim and shading out too.
Curtain.TRAVEL = 0.53

-- Veil fade once the sanctuary is ready (flipper motor stiffness/damping).
Curtain.VEIL_STIFFNESS = 220
Curtain.VEIL_DAMPING = 50

local function unit(t: number): number
	if t ~= t then
		return 0
	end
	return math.clamp(t, 0, 1)
end

-- Quartic ease-out: moving from the first frame, a long soft landing.
function Curtain.easeOpen(t: number): number
	local inv = 1 - unit(t)
	return 1 - inv * inv * inv * inv
end

-- Advance a run's clock by one rendered frame.
function Curtain.advance(elapsed: number, dt: number): number
	return elapsed + math.clamp(dt, 0, Curtain.MAX_FRAME_STEP)
end

-- Cubic ease-in-out: the halves gather speed and meet gently.
function Curtain.easeClose(t: number): number
	local x = unit(t)
	if x < 0.5 then
		return 4 * x * x * x
	end
	local k = -2 * x + 2
	return 1 - (k * k * k) / 2
end

-- Seconds for a run covering `distance` of travel (0..1).
function Curtain.duration(opening: boolean, distance: number, reduced: boolean): number
	local full = if opening then Curtain.OPEN_SECONDS else Curtain.CLOSE_SECONDS
	local seconds = full * math.clamp(distance, Curtain.MIN_RUN_SHARE, 1)
	return if reduced then seconds * Curtain.REDUCED_SCALE else seconds
end

-- Travel at `elapsed` seconds into a run from `from` to `to`.
function Curtain.sample(from: number, to: number, elapsed: number, seconds: number): number
	local t = if seconds <= 0 then 1 else elapsed / seconds
	local eased = if to > from then Curtain.easeOpen(t) else Curtain.easeClose(t)
	return from + (to - from) * eased
end

-- Offset of each half from its closed position, in screen widths.
function Curtain.shift(travel: number): number
	return unit(travel) * Curtain.TRAVEL
end

-- A half dims a little as it swings away, which gives the pair depth.
function Curtain.shadeTransparency(travel: number): number
	return 1 - unit(travel) * 0.4
end

-- The hairline rim along each parting edge: brightest as the seam opens,
-- gone by the time the halves are off screen.
function Curtain.rimTransparency(travel: number): number
	return 0.3 + unit(travel) * 0.7
end

-- The veil is 1 while it covers the world and 0 once the sanctuary shows.
function Curtain.veilTransparency(veil: number): number
	return 1 - unit(veil)
end

return Curtain
