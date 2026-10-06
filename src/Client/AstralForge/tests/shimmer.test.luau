local _lunit = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].lunit)
local Assert = _lunit.Assert
local ShimmerMath = require(script.Parent.Parent.MotionKit)("shimmer")

local ShimmerTests
do
	ShimmerTests = setmetatable({}, {
		__tostring = function()
			return "ShimmerTests"
		end,
	})
	ShimmerTests.__index = ShimmerTests
	function ShimmerTests.new(...)
		local self = setmetatable({}, ShimmerTests)
		return self:constructor(...) or self
	end
	function ShimmerTests:constructor()
	end

	function ShimmerTests:offsetCentersAtHalfPhase()
		local mid = ShimmerMath.offset(0.5, 2)
		Assert:equal(mid.X, 0)
		Assert:equal(mid.Y, 0)
	end

	function ShimmerTests:offsetSpansTravel()
		local start = ShimmerMath.offset(0, 2)
		local finish = ShimmerMath.offset(1, 2)
		Assert:equal(start.X, -1)
		Assert:equal(finish.X, -1)
		local almost = ShimmerMath.offset(0.999, 2)
		Assert["true"](Assert, almost.X > 0.9)
	end

	function ShimmerTests:offsetHandlesNaNAndLag()
		local nan = ShimmerMath.offset(0 / 0, 2)
		Assert:equal(nan.X, -1)
		local lagged = ShimmerMath.offset(0.5, 2, 0.25)
		Assert:equal(lagged.X, -0.5)
	end

	function ShimmerTests:surfaceStrengthRespectsIdleAndScale()
		Assert:equal(ShimmerMath.surfaceStrength(0, false, 1), 0)
		local idle = ShimmerMath.surfaceStrength(0, true, 1)
		Assert["true"](Assert, idle > 0 and idle <= 0.2)
		local hover = ShimmerMath.surfaceStrength(1, false, 1)
		Assert["true"](Assert, hover > idle and hover <= 0.5)
		local off = ShimmerMath.surfaceStrength(1, true, 0)
		Assert:equal(off, 0)
	end

	function ShimmerTests:shouldShowGatesAntilag()
		Assert["true"](Assert, ShimmerMath.shouldShow(0, true, 1) == true)
		Assert["true"](Assert, ShimmerMath.shouldShow(0, false, 1) == false)
		Assert["true"](Assert, ShimmerMath.shouldShow(1, false, 0.01) == false)
		Assert["true"](Assert, ShimmerMath.shouldShow(0.2, false, 1) == true)
	end

	function ShimmerTests:wantTrailRespectsScaleAndOptOut()
		Assert["true"](Assert, ShimmerMath.wantTrail(1, nil) == true)
		Assert["true"](Assert, ShimmerMath.wantTrail(0.2, nil) == false)
		Assert["true"](Assert, ShimmerMath.wantTrail(1, false) == false)
		Assert["true"](Assert, ShimmerMath.wantTrail(0.3, true) == true)
	end

	function ShimmerTests:sweepSpeedScalesWithSettings()
		local full = ShimmerMath.sweepSpeed(1)
		local low = ShimmerMath.sweepSpeed(0.2)
		Assert["true"](Assert, full > low)
		Assert["true"](Assert, low >= ShimmerMath.SWEEP_SPEED * 0.5)
	end
end

return ShimmerTests
