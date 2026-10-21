local TweenService = game:GetService("TweenService")

local DEFAULT_DELAY = 2 -- Delay before fading starts (seconds)
local DEFAULT_DURATION = 1 -- How long the fade takes (seconds)

return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		local delay = DEFAULT_DELAY
		local duration = DEFAULT_DURATION
		if params then
			delay = tonumber(params[1]) or DEFAULT_DELAY
			duration = tonumber(params[2]) or DEFAULT_DURATION
		end

		return {
			delay = delay,
			duration = duration,
			elapsed = 0,
			started = false,
		}
	end,

	Update = function(char_inst: ImageLabel | TextLabel, index, dt, trove, fade_data)
		fade_data.elapsed += dt

		if not fade_data.started and fade_data.elapsed >= fade_data.delay then
			fade_data.started = true

			if char_inst:IsA("TextLabel") then
				TweenService:Create(char_inst, TweenInfo.new(fade_data.duration, Enum.EasingStyle.Linear), {
					TextTransparency = 1,
				}):Play()
			elseif char_inst:IsA("ImageLabel") then
				TweenService:Create(char_inst, TweenInfo.new(fade_data.duration, Enum.EasingStyle.Linear), {
					ImageTransparency = 1,
				}):Play()
			end
		end
	end,
}
