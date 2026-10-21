local DEFAULT_SHAKE_SPEED = 35
local DEFAULT_SHAKE_INTENSITY = 1

local rng = Random.new()

return {
	Init = function(char_inst, index, trove, params)
		local shake_speed = DEFAULT_SHAKE_SPEED
		local shake_intensity = DEFAULT_SHAKE_INTENSITY
		if params then
			shake_speed = tonumber(params[1]) or DEFAULT_SHAKE_SPEED
			shake_intensity = tonumber(params[2]) or DEFAULT_SHAKE_INTENSITY
		end
		
		return {
			o_pos = char_inst.Position,
			shake_timer = 0,
			shake_speed = shake_speed,
			shake_intensity = shake_intensity,
		}
	end,

	Update = function(char_inst, index, dt, trove, shake_data)
		shake_data.shake_timer += dt

		if shake_data.shake_timer < (1 / shake_data.shake_speed) then
			return
		end

		shake_data.shake_timer = 0

		local x = rng:NextInteger(-shake_data.shake_intensity, shake_data.shake_intensity)
		local y = rng:NextInteger(-shake_data.shake_intensity, shake_data.shake_intensity)
		char_inst.Position = UDim2.fromOffset(shake_data.o_pos.X.Offset + x, shake_data.o_pos.Y.Offset + y)
	end,
}
