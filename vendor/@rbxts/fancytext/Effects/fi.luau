-- <fi seconds>
-- seconds: optional delay before the character fades in and falls into place (default 0)

local TweenService = game:GetService("TweenService")

local DEFAULT_DELAY = 0 -- Delay before fading/falling starts (seconds)
local DEFAULT_DURATION = 0.5 -- How long the fade+fall takes (seconds)
local DEFAULT_DISTANCE = 20 -- How far above the final position characters start

return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		local delay = DEFAULT_DELAY
		if params and params[1] then
			delay = tonumber(params[1]) or DEFAULT_DELAY
		end

		if char_inst:IsA("TextLabel") then
			char_inst.TextTransparency = 1
		elseif char_inst:IsA("ImageLabel") then
			char_inst.ImageTransparency = 1
		end

		trove:Add(task.delay(delay, function()
			-- Read OrigPos here, after vertical alignment has been applied
			local target_pos = char_inst:GetAttribute("OrigPos") or char_inst.Position
			local start_pos = target_pos - UDim2.fromOffset(0, DEFAULT_DISTANCE)

			char_inst.Position = start_pos

			if char_inst:IsA("TextLabel") then
				TweenService:Create(
					char_inst,
					TweenInfo.new(DEFAULT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = target_pos, TextTransparency = 0 }
				):Play()
			elseif char_inst:IsA("ImageLabel") then
				TweenService:Create(
					char_inst,
					TweenInfo.new(DEFAULT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = target_pos, ImageTransparency = 0 }
				):Play()
			end
		end))
	end,
}
