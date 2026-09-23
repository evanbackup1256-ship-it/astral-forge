local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(options)
	options = options or {}

	local value = math.clamp(options.value or 0, 0, 1)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()
		local trackHeight = style.itemHeight

		return create("Frame", {
			[ref] = "frame",
			BackgroundColor3 = style.frameBgColor,
			BackgroundTransparency = style.frameBgTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, trackHeight),

			create("UICorner", {
				CornerRadius = UDim.new(0, 2),
			}),

			create("Frame", {
				[ref] = "fill",
				BackgroundColor3 = style.sliderGrabColor,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				ZIndex = 2,

				create("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),
			}),

			create("TextLabel", {
				[ref] = "label",
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 3,
			}),
		})
	end)

	local style = Style.get()
	refs.fill.Size = UDim2.new(value, 0, 1, 0)
	refs.fill.BackgroundColor3 = style.sliderGrabColor

	if options.label then
		refs.label.Text = options.label
	else
		refs.label.Text = math.floor(value * 100) .. "%"
	end
end)
