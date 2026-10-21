local WAVE_AMP = 2
local WAVE_FREQ = 5
local WAVE_SPACING = 0.5

return {
	Init = function(char_inst: TextLabel, index, trove)
		char_inst:SetAttribute("OrigPos", char_inst.Position)
		char_inst:SetAttribute("CharIndex", index)
	end,

	Update = function(char_inst: TextLabel, index, dt)
		local orig_pos = char_inst:GetAttribute("OrigPos")
		local char_index = char_inst:GetAttribute("CharIndex")

		local sine_value = math.sin((time() * WAVE_FREQ) + (char_index * WAVE_SPACING))
		local y_offset = sine_value * WAVE_AMP

		char_inst.Position = UDim2.fromOffset(orig_pos.X.Offset, orig_pos.Y.Offset + y_offset)
	end,
}
