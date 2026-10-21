-- <gradientWave percent r g b flip>
-- percent: (0-1) how far up the character the gradient_color reaches, coming from
--           the bottom (default 0.5). Uses a real UIGradient locked to Rotation = 90
--           (vertical, top-to-bottom).
-- r g b: optional gradient color to blend towards (default black)
-- flip: optional, presence flips the gradient to come from the top instead of the bottom
--
-- A wave travels across the word (via each character's phase offset) and gently
-- shifts the gradient's Offset +/-15% either way, plus a small transparency pulse,
-- so it reads as a shimmer sweeping across the word. Rotation itself never changes.

local Spring = require(script.Parent.Parent.Dependencies.Spring)

local DEFAULT_PERCENT = 0.5
local DEFAULT_COLOR = Color3.new(0, 0, 0)
local GRADIENT_ROTATION = 90 -- vertical (top-to-bottom), fixed

local WAVE_AMPLITUDE = 0.15 -- max Offset shift, either way (15%)
local TRANSPARENCY_AMPLITUDE = 0.08 -- how much transparency pulses in tune with the wave
local WAVE_FREQ = 2 -- speed of the underlying sine wave
local WAVE_SPACING = 0.35 -- phase offset per character, makes the wave travel across the word
local SPRING_SPEED = 4
local SPRING_DAMPER = 0.7 -- slightly underdamped for a smooth, organic wobble instead of a rigid sine

local function build_color_sequence(base_color: Color3, gradient_color: Color3, percent: number, flip: boolean)
	if percent <= 0 then
		return ColorSequence.new(base_color)
	end

	if percent >= 1 then
		if flip then
			return ColorSequence.new(gradient_color, base_color)
		end
		return ColorSequence.new(base_color, gradient_color)
	end

	local plateau = 1 - percent
	if flip then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, gradient_color),
			ColorSequenceKeypoint.new(percent, base_color),
			ColorSequenceKeypoint.new(1, base_color),
		})
	end

	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base_color),
		ColorSequenceKeypoint.new(plateau, base_color),
		ColorSequenceKeypoint.new(1, gradient_color),
	})
end

return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		local percent = DEFAULT_PERCENT
		local gradient_color = DEFAULT_COLOR
		local flip = false

		if params then
			percent = math.clamp(tonumber(params[1]) or DEFAULT_PERCENT, 0, 1)

			if params[2] and params[3] and params[4] then
				local r = tonumber(params[2]) or 0
				local g = tonumber(params[3]) or 0
				local b = tonumber(params[4]) or 0
				gradient_color = Color3.fromRGB(r, g, b)
			end

			flip = params[5] ~= nil
		end

		local is_image = char_inst:IsA("ImageLabel")
		local base_color = is_image and char_inst.ImageColor3 or char_inst.TextColor3
		local base_transparency = is_image and char_inst.ImageTransparency or char_inst.TextTransparency

		local gradient = trove:Add(Instance.new("UIGradient"))
		gradient.Name = "GradientWaveEffect"
		gradient.Rotation = GRADIENT_ROTATION
		gradient.Color = build_color_sequence(base_color, gradient_color, percent, flip)
		gradient.Transparency = NumberSequence.new(base_transparency)
		gradient.Parent = char_inst

		local spring = Spring.new(0)
		spring.Speed = SPRING_SPEED
		spring.Damper = SPRING_DAMPER

		return {
			gradient = gradient,
			spring = spring,
		}
	end,

	Update = function(char_inst: ImageLabel | TextLabel, index, dt, trove, gradient_data)
		-- drive the spring with a sine wave so the shimmer eases around smoothly instead of ticking
		local sine = math.sin((time() * WAVE_FREQ) + (index * WAVE_SPACING))
		gradient_data.spring.Target = sine

		local wave = gradient_data.spring.Position -- smoothed, roughly -1..1

		gradient_data.gradient.Offset = Vector2.new(0, wave * WAVE_AMPLITUDE)

		-- read live; a frozen Init snapshot would desync since effect Init order isn't guaranteed
		local base_transparency = if char_inst:IsA("ImageLabel")
			then char_inst.ImageTransparency
			else char_inst.TextTransparency
		local transparency = math.clamp(base_transparency + wave * TRANSPARENCY_AMPLITUDE, 0, 1)
		gradient_data.gradient.Transparency = NumberSequence.new(transparency)
	end,
}
