return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		if not params or #params < 3 then
			warn("[FancyText/col]: col effect requires 3 parameters (R G B)")
			return
		end

		local r = tonumber(params[1]) or 255
		local g = tonumber(params[2]) or 255
		local b = tonumber(params[3]) or 255
		local color = Color3.fromRGB(r, g, b)

		if char_inst:IsA("ImageLabel") then
			char_inst.ImageColor3 = color
		else
			char_inst.TextColor3 = color
		end
	end,
}
