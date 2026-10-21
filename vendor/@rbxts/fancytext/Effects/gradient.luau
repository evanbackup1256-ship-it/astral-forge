-- <gradient percent r g b flip accent_r accent_g accent_b>
-- percent: (0-1) how far up the character the gradient_color reaches, coming from
--           the bottom (default 0.5). Uses a real UIGradient with Rotation = 90
--           (vertical, top-to-bottom) as its base.
-- r g b: optional gradient color to blend towards (default black)
-- flip: optional, must be "flip"/"true"/"1" to enable (unlike before, presence alone
--       isn't enough) - this keeps its position fixed so accent_r/g/b can follow it.
--       Pass "0" or "false" here as a placeholder if you want the accent color but
--       not flip.
-- accent_r accent_g accent_b: optional 2nd color. If given, adds a thin accent seam
--       right at the boundary between the anchor and the rest - e.g. mostly blue
--       (anchor) -> thin white seam -> real letter color (fills the remaining tip).
--
-- The gradient stays fully opaque end to end (no fade to invisible, so it never
-- reveals whatever's behind it). A single wave travels across the word: each
-- character's phase is driven by its actual horizontal position (not its character
-- index), so neighboring letters line up into one continuous wave shape instead of
-- ticking independently, tilting Rotation +/-15 degrees around its 90 degree base,
-- plus a small overall transparency pulse in tune with the same wave.

local Spring = require(script.Parent.Parent.Dependencies.Spring)

local DEFAULT_PERCENT = 0.5
local DEFAULT_COLOR = Color3.new(1, 1, 1)
local GRADIENT_ROTATION_BASE = 90 -- vertical (top-to-bottom)
local ROTATION_AMPLITUDE = 15 -- max tilt, either way, from the 90 degree base

local TRANSPARENCY_PULSE = 0.08 -- how much the opaque point pulses in tune with the wave
local WAVE_FREQ = 2 -- speed of the underlying sine wave
local WAVE_LENGTH = 70 -- pixels per full wave cycle; phase is driven by X position, not char index
local SPRING_SPEED = 4
local SPRING_DAMPER = 0.7 -- slightly underdamped for a smooth, organic wobble instead of a rigid sine
local EDGE_SHARPNESS = 0.05 -- width (0-1) of the transition band; keep this small for a crisp line
local ACCENT_WIDTH = 0.12 -- width (0-1) of the optional accent seam at the boundary; kept thin on purpose

-- Appends a keypoint, skipping it if its time doesn't strictly increase (keeps
-- sequences valid when the sharp edge collides with 0/1 at extreme percent values).
local function add_keypoint(keypoints, ctor, t: number, value)
	t = math.clamp(t, 0, 1)
	if #keypoints == 0 or t > keypoints[#keypoints].Time then
		table.insert(keypoints, ctor(t, value))
	end
end

-- Solid gradient_color anchor, then either:
--  - no accent_color: a crisp line straight into solid base_color (the letter's real
--    color) the rest of the way, or
--  - accent_color given: a thin accent seam right at the boundary, then base_color
--    fills the remaining majority - e.g. mostly blue -> thin white seam -> real
--    letter color.
local function build_color_sequence(
	base_color: Color3,
	gradient_color: Color3,
	percent: number,
	flip: boolean,
	accent_color: Color3?
)
	percent = math.clamp(percent, 0, 1)

	if percent >= 1 and not accent_color then
		return ColorSequence.new(gradient_color)
	end

	if percent <= 0 and not accent_color then
		return ColorSequence.new(base_color)
	end

	local boundary = flip and percent or (1 - percent)
	local keypoints = {}

	if not accent_color then
		local edge_start = boundary - EDGE_SHARPNESS / 2
		local edge_end = boundary + EDGE_SHARPNESS / 2

		if flip then
			-- anchor (gradient_color) is the top (0), tip (base_color) is the bottom (1)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, 0, gradient_color)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, edge_start, gradient_color)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, edge_end, base_color)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, 1, base_color)
		else
			-- tip (base_color) is the top (0), anchor (gradient_color) is the bottom (1)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, 0, base_color)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, edge_start, base_color)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, edge_end, gradient_color)
			add_keypoint(keypoints, ColorSequenceKeypoint.new, 1, gradient_color)
		end

		return ColorSequence.new(keypoints)
	end

	-- thin accent seam centered on the boundary, base_color fills the rest of the tip side
	local accent_half = ACCENT_WIDTH / 2
	local seam_start = boundary - accent_half
	local seam_end = boundary + accent_half

	if flip then
		-- anchor (gradient_color) is the top (0), tip (base_color) is the bottom (1)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, 0, gradient_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_start - EDGE_SHARPNESS / 2, gradient_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_start + EDGE_SHARPNESS / 2, accent_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_end - EDGE_SHARPNESS / 2, accent_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_end + EDGE_SHARPNESS / 2, base_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, 1, base_color)
	else
		-- tip (base_color) is the top (0), anchor (gradient_color) is the bottom (1)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, 0, base_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_start - EDGE_SHARPNESS / 2, base_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_start + EDGE_SHARPNESS / 2, accent_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_end - EDGE_SHARPNESS / 2, accent_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, seam_end + EDGE_SHARPNESS / 2, gradient_color)
		add_keypoint(keypoints, ColorSequenceKeypoint.new, 1, gradient_color)
	end

	return ColorSequence.new(keypoints)
end

return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		local percent = DEFAULT_PERCENT
		local gradient_color = DEFAULT_COLOR
		local flip = false
		local accent_color = nil

		if params then
			percent = math.clamp(tonumber(params[1]) or DEFAULT_PERCENT, 0, 1)

			if params[2] and params[3] and params[4] then
				local r = tonumber(params[2]) or 0
				local g = tonumber(params[3]) or 0
				local b = tonumber(params[4]) or 0
				gradient_color = Color3.fromRGB(r, g, b)
			end

			if params[5] and params[6] and params[7] then
				local r = tonumber(params[5]) or 0
				local g = tonumber(params[6]) or 0
				local b = tonumber(params[7]) or 0
				accent_color = Color3.fromRGB(r, g, b)
			end
			
			flip = params[8] == "flip" or params[8] == "true" or params[8] == "1"
		end

		local is_image = char_inst:IsA("ImageLabel")
		local base_color = is_image and char_inst.ImageColor3 or char_inst.TextColor3

		-- UIGradient's Color sequence is multiplied against the object's own color
		-- property, not used as an absolute replacement. Reset to white so it acts as
		-- the multiplicative identity and our ColorSequence renders its true colors.
		if is_image then
			char_inst.ImageColor3 = Color3.new(1, 1, 1)
		else
			char_inst.TextColor3 = Color3.new(1, 1, 1)
		end

		local gradient = trove:Add(Instance.new("UIGradient"))
		gradient.Name = "GradientEffect"
		gradient.Rotation = GRADIENT_ROTATION_BASE
		gradient.Color = build_color_sequence(base_color, gradient_color, percent, flip, accent_color)
		gradient.Transparency = NumberSequence.new(0)
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
		-- phase comes from the character's actual horizontal position, not its index,
		-- so characters line up spatially into one wave shape regardless of glyph width
		local phase = (char_inst.Position.X.Offset / WAVE_LENGTH) * (2 * math.pi)

		-- drive the spring with a sine wave so the tilt eases around smoothly instead of ticking
		local sine = math.sin((time() * WAVE_FREQ) + phase)
		gradient_data.spring.Target = sine

		local wave: number = gradient_data.spring.Position -- smoothed, roughly -1..1

		-- skip the write when the spring hasn't meaningfully moved (most frames, once settled)
		local last_wave = gradient_data.last_wave
		if last_wave and math.abs(wave - last_wave) < 1e-3 then
			return
		end
		gradient_data.last_wave = wave

		gradient_data.gradient.Rotation = GRADIENT_ROTATION_BASE + math.clamp(wave, -1, 1) * ROTATION_AMPLITUDE

		local transparency = math.clamp(wave * TRANSPARENCY_PULSE, 0, 1)
		gradient_data.gradient.Transparency = NumberSequence.new(transparency)
	end,
}
