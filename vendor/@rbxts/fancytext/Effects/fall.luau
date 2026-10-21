local TweenService = game:GetService("TweenService")

local DEFAULT_DELAY = 0 -- Delay before falling starts (seconds)
local DEFAULT_DURATION = 1 -- How long the fall takes (seconds)
local DEFAULT_DISTANCE = 200 -- How far characters fall off screen

return {
	Init = function(char_inst, index, trove, params)
		local delay = DEFAULT_DELAY
		local duration = DEFAULT_DURATION
		local distance = DEFAULT_DISTANCE

		if params then
			delay = tonumber(params[1]) or DEFAULT_DELAY
			duration = tonumber(params[2]) or DEFAULT_DURATION
			distance = tonumber(params[3]) or DEFAULT_DISTANCE
		end

		local is_odd = index % 2 == 1
		local fall_direction = is_odd and 1 or -1 -- Odd goes down (1), even goes up (-1)

		return {
			delay = delay,
			duration = duration,
			distance = distance,
			elapsed = 0,
			started = false,
			fall_direction = fall_direction,
		}
	end,

	Update = function(char_inst, index, dt, trove, fall_data)
		fall_data.elapsed += dt

		if not fall_data.started and fall_data.elapsed >= fall_data.delay then
			fall_data.started = true

			local o_pos = char_inst:GetAttribute("OrigPos") or char_inst.Position
			local target_pos = o_pos + UDim2.fromOffset(0, fall_data.distance * fall_data.fall_direction)

			if char_inst:IsA("TextLabel") then
				TweenService:Create(
					char_inst,
					TweenInfo.new(fall_data.duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
					{
						Position = target_pos,
						TextTransparency = 1,
					}
				):Play()
			elseif char_inst:IsA("ImageLabel") then
				TweenService:Create(
					char_inst,
					TweenInfo.new(fall_data.duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
					{
						Position = target_pos,
						ImageTransparency = 1,
					}
				):Play()
			end
		end
	end,
}
