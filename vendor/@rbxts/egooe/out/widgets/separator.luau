--[=[
	@within EgooE
	@function separator
	@tag widgets

	Draws a horizontal separator line, styled like an Iris separator.

	```lua
	heading("Section A")
	separator()
	label("First item")
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local create = require(script.Parent.Parent.create)
local Style = require(script.Parent.Parent.Style)

return Runtime.widget(function()
	Runtime.useInstance(function()
		local style = Style.get()

		return create("Frame", {
			BackgroundColor3 = style.separatorColor,
			BackgroundTransparency = style.separatorTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
		})
	end)
end)
