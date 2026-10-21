-- flicker colors like a broken light
return {
	Init = function(char_inst: TextLabel, index, trove)
		char_inst:SetAttribute("OrigPos", char_inst.Position)
		char_inst:SetAttribute("BaseBrightness", 0.6 + math.random() * 0.2)
		char_inst:SetAttribute("FlickerSeed", math.random() * 1000)
	end,

	Update = function(char_inst: TextLabel, index, dt)
		local orig_pos = char_inst:GetAttribute("OrigPos")
		local base_brightness = char_inst:GetAttribute("BaseBrightness")
		local flicker_seed = char_inst:GetAttribute("FlickerSeed")
		local t = time()

		local flicker = math.noise(flicker_seed, t * 2) * 0.4
		local brightness = math.clamp(base_brightness + flicker, 0, 1)

		if math.random() < 0.015 then
			brightness = brightness + 0.5
		end

		local hue = 0.12 + math.noise(flicker_seed, t * 0.3) * 0.02 -- around orange/yellow
		local sat = 0.8 + math.noise(flicker_seed, t * 0.2) * 0.2

		local color = Color3.fromHSV(math.clamp(hue, 0, 1), math.clamp(sat, 0, 1), math.clamp(brightness, 0, 1))

		if char_inst:IsA("ImageLabel") then
			char_inst.ImageColor3 = color
		else
			char_inst.TextColor3 = color
		end
	end,
}
