-- <smash speed rise>
-- Typewriter that hammers: characters appear one by one, each one slams down
-- from high above at 1.7x size, hits with a hard squash + random tilt, then
-- straightens out. Only the glyphs animate; the container never moves.
-- speed: per-character delay in seconds (default 0.06)
-- rise: how many pixels above its final position each character starts (default 90)

local TweenService = game:GetService("TweenService")

local DEFAULT_SPEED = 0.06
local DEFAULT_RISE = 90

local SLAM_TIME = 0.06 -- very fast accelerating drop
local SETTLE_TIME = 0.18 -- squash/tilt recovery
local AIRBORNE_SCALE = 1.7 -- TextSize multiplier while falling (stamp feel)
local SQUASH_SCALE = 0.65 -- how far under final size it crushes on impact
local TILT_MAX = 16 -- max degrees of random tilt on impact

local rng = Random.new()

return {
	Init = function(char_inst, index, trove, params)
		local speed = DEFAULT_SPEED
		local rise = DEFAULT_RISE
		if params then
			speed = tonumber(params[1]) or DEFAULT_SPEED
			rise = tonumber(params[2]) or DEFAULT_RISE
		end

		local is_text = char_inst:IsA("TextLabel")
		local o_size = is_text and char_inst.TextSize or nil

		char_inst.Visible = false

		trove:Add(task.delay(index * speed, function()
			-- Read OrigPos here, after vertical alignment has been applied
			local o_pos = char_inst:GetAttribute("OrigPos") or char_inst.Position

			char_inst.Position = o_pos - UDim2.fromOffset(0, rise)
			if is_text then
				char_inst.TextSize = o_size * AIRBORNE_SCALE
			end
			char_inst.Visible = true

			-- slam down, accelerating hard into the impact
			local slam = TweenService:Create(
				char_inst,
				TweenInfo.new(SLAM_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
				is_text and { Position = o_pos, TextSize = math.max(1, o_size * SQUASH_SCALE) }
					or { Position = o_pos }
			)

			slam.Completed:Once(function()
				-- impact: random tilt on the glyph
				char_inst.Rotation = rng:NextNumber(-TILT_MAX, TILT_MAX)

				-- squash/tilt recovery: overshoot back up to the real size, straighten out
				TweenService:Create(
					char_inst,
					TweenInfo.new(SETTLE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					is_text and { TextSize = o_size, Rotation = 0 } or { Rotation = 0 }
				):Play()
			end)

			slam:Play()
		end))
	end,
}
