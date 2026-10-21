return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove)
		char_inst.Size += UDim2.fromOffset(5, 5)

		if char_inst:IsA("ImageLabel") then
			local h, s, v = char_inst.ImageColor3:ToHSV()
			char_inst.ImageColor3 = Color3.fromHSV(h, s, v + 0.15)
		elseif char_inst:IsA("TextLabel") then
			local h, s, v = char_inst.TextColor3:ToHSV()
			char_inst.TextColor3 = Color3.fromHSV(h, s, v + 0.15)
		end
	end,
}
