-- Layout-safe shimmer math. Pure functions only — no React, no GuiObjects.
-- Sweep motion belongs on UIGradient.Offset (clipped overlays), never on
-- oversized Offset-sized tip frames under AutomaticSize.

local DEFAULT_TRAVEL = 2.2
local TRAIL_LAG = 0.08
-- Trail only on high shimmer settings — dual-pass is the main hover cost.
local TRAIL_MIN_SCALE = 0.85

-- Razor specular: narrow bright core, transparent flanks.
-- Transparency 0 = opaque. Peak stays low so the glint actually reads.
local GLINT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 1),
	NumberSequenceKeypoint.new(0.46, 0.62),
	NumberSequenceKeypoint.new(0.5, 0.1),
	NumberSequenceKeypoint.new(0.54, 0.62),
	NumberSequenceKeypoint.new(0.7, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- Soft lagging wash behind the core (optional dual-pass).
local TRAIL = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.34, 1),
	NumberSequenceKeypoint.new(0.48, 0.92),
	NumberSequenceKeypoint.new(0.56, 0.72),
	NumberSequenceKeypoint.new(0.7, 0.96),
	NumberSequenceKeypoint.new(1, 1),
})

local SWEEP_SPEED = 0.62
local ROTATION = 16

local function clamp01(value)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return value
end

local function offset(phase, travel, lag)
	if travel == nil then
		travel = DEFAULT_TRAVEL
	end
	if type(travel) ~= "number" or travel ~= travel or travel <= 0 then
		travel = DEFAULT_TRAVEL
	end
	local t = phase
	if type(t) ~= "number" or t ~= t then
		t = 0
	end
	if type(lag) == "number" and lag == lag then
		t -= lag
	end
	t = t % 1
	if t < 0 then
		t += 1
	end
	return Vector2.new(t * travel - travel * 0.5, 0)
end

local function sweepSpeed(shimmerScale)
	local scale = clamp01(if type(shimmerScale) == "number" then shimmerScale else 1)
	return SWEEP_SPEED * math.clamp(0.55 + scale * 0.45, 0.55, 1)
end

-- Peak opacity of the wash layer (0..~0.5). Must stay visible on hover.
local function surfaceStrength(hoverAmount, idle, shimmerScale)
	local scale = clamp01(if type(shimmerScale) == "number" then shimmerScale else 1)
	local hoverStrength = clamp01(hoverAmount) * 0.42
	local idleStrength = if idle then 0.14 else 0
	return math.clamp(math.max(hoverStrength, idleStrength) * scale, 0, 0.5)
end

local function surfaceTransparency(hoverAmount, idle, shimmerScale)
	return 1 - surfaceStrength(hoverAmount, idle, shimmerScale)
end

local function shouldShow(hoverAmount, idle, shimmerScale)
	if clamp01(if type(shimmerScale) == "number" then shimmerScale else 1) <= 0.02 then
		return false
	end
	if idle then
		return true
	end
	return clamp01(hoverAmount) > 0.02
end

local function wantTrail(shimmerScale, trailOpt)
	if trailOpt == false then
		return false
	end
	if trailOpt == true then
		return clamp01(if type(shimmerScale) == "number" then shimmerScale else 1) > 0.02
	end
	return clamp01(if type(shimmerScale) == "number" then shimmerScale else 1) >= TRAIL_MIN_SCALE
end

return {
	GLINT = GLINT,
	TRAIL = TRAIL,
	SWEEP_SPEED = SWEEP_SPEED,
	ROTATION = ROTATION,
	DEFAULT_TRAVEL = DEFAULT_TRAVEL,
	TRAIL_LAG = TRAIL_LAG,
	TRAIL_MIN_SCALE = TRAIL_MIN_SCALE,
	offset = offset,
	sweepSpeed = sweepSpeed,
	surfaceStrength = surfaceStrength,
	surfaceTransparency = surfaceTransparency,
	shouldShow = shouldShow,
	wantTrail = wantTrail,
	clamp01 = clamp01,
}
