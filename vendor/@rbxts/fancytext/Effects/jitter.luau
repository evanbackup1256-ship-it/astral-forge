local SHAKE_INTENSITY = 1

return {
	Init = function(char_inst: TextLabel, index, trove)
		char_inst:SetAttribute("OrigPos", char_inst.Position)
	end,

	Update = function(char_inst: TextLabel, index, dt)
		local orig_pos = char_inst:GetAttribute("OrigPos")

		local x_offset = (math.random() * 2 - 1) * SHAKE_INTENSITY
		local y_offset = (math.random() * 2 - 1) * SHAKE_INTENSITY

		char_inst.Position = UDim2.fromOffset(orig_pos.X.Offset + x_offset, orig_pos.Y.Offset + y_offset)
	end,
}
