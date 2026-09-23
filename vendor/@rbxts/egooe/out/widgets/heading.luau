--[=[
	@within EgooE
	@function heading
	@tag widgets
	@param text string -- The heading text
	@param options {textSize: number, font: Font}

	Displays bold heading text, styled like an Iris section header.

	```lua
	heading("My Section")
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local create = require(script.Parent.Parent.create)
local Style = require(script.Parent.Parent.Style)

return Runtime.widget(function(text, options)
	options = options or {}

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("TextLabel", {
			[ref] = "heading",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextColor3 = style.textColor,
			TextSize = (style.textSize or 13) + 2,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, (style.itemHeight or 22) + 2),
		})
	end)

	local label = refs.heading
	label.Text = text
	local style = Style.get()
	label.TextSize = options.textSize or (style.textSize + 2)
	label.Font = options.font or Enum.Font.GothamBold
end)
