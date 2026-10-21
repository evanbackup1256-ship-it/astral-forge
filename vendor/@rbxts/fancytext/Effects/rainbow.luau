return {
	Update = function(char_inst, index, dt, trove)
		local hue = ((time() * 0.3) + index * 0.05) % 1

		if char_inst:IsA("ImageLabel") then
			char_inst.ImageColor3 = Color3.fromHSV(hue, 1, 1)
		else
			char_inst.TextColor3 = Color3.fromHSV(hue, 1, 1)
		end
	end,
}
