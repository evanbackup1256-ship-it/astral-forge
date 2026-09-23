local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.theme).Palette
local DOTS = { 0, 1, 2, 3 }
local CYCLE = 0.86
local COUNT = 4
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function pulse(elapsed, index)
	local travel = ((elapsed / CYCLE) % 1) * COUNT
	local delta = math.abs(travel - index)
	local wrap = math.min(delta, COUNT - delta)
	local falloff = clamp01(1 - wrap)
	return falloff * falloff * (3 - 2 * falloff)
end
local function LoadingDots(_param)
	local clock = _param.clock
	local leaving = _param.leaving
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	local width = if compact then 92 else 112
	local height = if compact then 22 else 26
	local gap = if compact then 18 else 22
	local size = if compact then 7 else 8
	local lift = if compact then 5 else 6
	local center = width / 2
	local restY = height * 0.55
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#DOTS)
	local _callback = function(index)
		local x = center + (index - 1.5) * gap
		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(_param_1)
			local elapsed = _param_1.clock
			local exit = _param_1.leaving
			local fade = clamp01(exit)
			if reducedMotion or ready then
				return {
					y = restY,
					scale = 0.72,
					alpha = 0.45,
					mix = 0,
					fade = fade,
				}
			end
			local amount = pulse(elapsed, index)
			return {
				y = restY - amount * lift,
				scale = 0.62 + amount * 0.38,
				alpha = 0.28 + amount * 0.72,
				mix = amount,
				fade = fade,
			}
		end)
		return React.createElement("frame", {
			key = `load-dot-{index}`,
			Size = motion:map(function(value)
				return UDim2.fromOffset(size * value.scale, size * value.scale)
			end),
			Position = motion:map(function(value)
				return UDim2.fromOffset(x, value.y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = motion:map(function(value)
				return Palette.cream:Lerp(Palette.cyan, value.mix)
			end),
			BackgroundTransparency = motion:map(function(value)
				return clamp01(1 - value.alpha + value.fade)
			end),
			BorderSizePixel = 0,
			ZIndex = 527,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in DOTS do
		_newValue[_k] = _callback(_v, _k - 1, DOTS)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 525,
	}, _newValue)
end
return {
	LoadingDots = LoadingDots,
}
