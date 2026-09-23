-- Internal error display widget
local Runtime = require(script.Parent.Parent.Runtime)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(errorText)
	local refs = Runtime.useInstance(function(ref)
		return create("TextLabel", {
			[ref] = "label",
			Visible = true,
			BackgroundColor3 = Color3.fromRGB(80, 20, 20),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextColor3 = Color3.fromRGB(255, 100, 100),
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 40),

			create("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		})
	end)

	refs.label.Visible = true
	refs.label.Text = errorText
end)
