-- <shadow offset_x offset_y r g b>
-- offset_x offset_y: optional shadow offset in pixels (default 2, 2)
-- r g b: optional shadow color (default black)

local DEFAULT_OFFSET_X = 2
local DEFAULT_OFFSET_Y = 2
local DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)

return {
	Init = function(char_inst: ImageLabel | TextLabel, index, trove, params)
		local offset_x = DEFAULT_OFFSET_X
		local offset_y = DEFAULT_OFFSET_Y
		local shadow_color = DEFAULT_COLOR
		if params then
			offset_x = tonumber(params[1]) or DEFAULT_OFFSET_X
			offset_y = tonumber(params[2]) or DEFAULT_OFFSET_Y

			if params[3] and params[4] and params[5] then
				local r = tonumber(params[3]) or 0
				local g = tonumber(params[4]) or 0
				local b = tonumber(params[5]) or 0
				shadow_color = Color3.fromRGB(r, g, b)
			end
		end

		local shadow = trove:Add(char_inst:Clone())
		shadow.Name = char_inst.Name .. "_Shadow"
		shadow.Size = char_inst.Size
		shadow.ZIndex = char_inst.ZIndex - 1

		trove:Add(task.defer(function()
			shadow.Position = char_inst.Position
			shadow.Parent = char_inst.Parent
			shadow.Visible = char_inst.Visible
		end))

		if char_inst:IsA("TextLabel") then
			shadow.TextColor3 = shadow_color
			shadow.TextStrokeColor3 = shadow_color
			shadow.TextTransparency = char_inst.TextTransparency
		elseif char_inst:IsA("ImageLabel") then
			shadow.ImageColor3 = shadow_color
			shadow.ImageTransparency = char_inst.ImageTransparency
		end

		char_inst.ZIndex += 1

		-- Update() skips invisible characters entirely, so sync these reactively too
		trove:Add(char_inst:GetPropertyChangedSignal("Visible"):Connect(function()
			shadow.Visible = char_inst.Visible
		end))

		if char_inst:IsA("TextLabel") then
			trove:Add(char_inst:GetPropertyChangedSignal("TextTransparency"):Connect(function()
				shadow.TextTransparency = char_inst.TextTransparency
			end))
		elseif char_inst:IsA("ImageLabel") then
			trove:Add(char_inst:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
				shadow.ImageTransparency = char_inst.ImageTransparency
			end))
		end

		return {
			shadow = shadow,
			offset_x = offset_x,
			offset_y = offset_y,
			shadow_color = shadow_color,
		}
	end,

	Update = function(char_inst, index, dt, trove, shadow_data)
		local shadow = shadow_data.shadow
		local offset_x = shadow_data.offset_x
		local offset_y = shadow_data.offset_y
		local shadow_color = shadow_data.shadow_color

		shadow.Visible = char_inst.Visible

		if char_inst:IsA("TextLabel") then
			shadow.TextColor3 = shadow_color
			shadow.TextStrokeColor3 = shadow_color
			shadow.TextTransparency = char_inst.TextTransparency
		elseif char_inst:IsA("ImageLabel") then
			shadow.ImageColor3 = shadow_color
			shadow.ImageTransparency = char_inst.ImageTransparency
		end

		shadow.Position = char_inst.Position + UDim2.fromOffset(offset_x, offset_y)
	end,
}
