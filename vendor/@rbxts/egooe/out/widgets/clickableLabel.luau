export type ClickableLabelHandle = {
	clicked: () -> boolean,
}

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(text, options)
	options = options or {}

	local clicked, setClicked = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("TextButton", {
			[ref] = "btn",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextColor3 = options.color or style.buttonColor,
			TextSize = options.textSize or style.textSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, style.itemHeight),
			AutoButtonColor = false,
			RichText = true,

			MouseEnter = function()
				setHovered(true)
			end,

			MouseLeave = function()
				setHovered(false)
			end,

			Activated = function()
				setClicked(true)
			end,
		})
	end)

	local style = Style.get()
	local baseColor = options.color or style.buttonColor
	local displayText = text

	if hovered then
		refs.btn.TextColor3 = Color3.new(
			math.min(baseColor.R + 0.15, 1),
			math.min(baseColor.G + 0.15, 1),
			math.min(baseColor.B + 0.15, 1)
		)
		displayText = "<u>" .. text .. "</u>"
	else
		refs.btn.TextColor3 = baseColor
	end

	refs.btn.Text = displayText
	refs.btn.TextSize = options.textSize or style.textSize

	return {
		clicked = function()
			if clicked then
				setClicked(false)
				return true
			end
			return false
		end,
	}
end)
