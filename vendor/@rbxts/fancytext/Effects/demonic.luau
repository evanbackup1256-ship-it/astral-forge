local DEFAULT_SPEED = 2 -- How fast it pulses between colors
local DEFAULT_MIN_VALUE = 0.1 -- Darkest point (almost black)
local DEFAULT_MAX_VALUE = 0.8 -- Brightest point (visible red)

return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		local speed = DEFAULT_SPEED
		local min_value = DEFAULT_MIN_VALUE
		local max_value = DEFAULT_MAX_VALUE

		if params then
			speed = tonumber(params[1]) or DEFAULT_SPEED
			min_value = tonumber(params[2]) or DEFAULT_MIN_VALUE
			max_value = tonumber(params[3]) or DEFAULT_MAX_VALUE
		end

		return {
			speed = speed,
			min_value = min_value,
			max_value = max_value,
			time_offset = index * 0.1,
		}
	end,

	Update = function(char_inst: ImageLabel | TextLabel, index, dt, trove, demonic_data)
		local t = time() * demonic_data.speed + demonic_data.time_offset
		local pulse = math.sin(t) * 0.5 + 0.5 -- Normalize to 0-1
		local value = demonic_data.min_value + (pulse * (demonic_data.max_value - demonic_data.min_value))

		local color = Color3.fromHSV(0, 1, value)

		if char_inst:IsA("TextLabel") then
			char_inst.TextColor3 = color
		elseif char_inst:IsA("ImageLabel") then
			char_inst.ImageColor3 = color
		end
	end,
}
