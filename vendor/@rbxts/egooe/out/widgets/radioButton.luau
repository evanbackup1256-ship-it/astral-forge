export type RadioButtonHandle = {
	selected: () -> boolean,
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
		local circleSize = style.itemHeight - 6

		return create("Frame", {
			[ref] = "row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),

			create("TextButton", {
				[ref] = "circle",
				BackgroundColor3 = style.frameBgColor,
				BackgroundTransparency = style.frameBgTransparency,
				BorderSizePixel = 0,
				Size = UDim2.new(0, circleSize, 0, circleSize),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Text = "",
				AutoButtonColor = false,

				create("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),

				create("UIStroke", {
					[ref] = "stroke",
					Color = style.borderColor,
					Transparency = style.borderTransparency,
					Thickness = 1,
				}),

				-- Inner dot (selected indicator)
				create("Frame", {
					[ref] = "dot",
					BackgroundColor3 = style.checkMarkColor,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, 0),

					create("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				}),

				MouseEnter = function()
					setHovered(true)
				end,

				MouseLeave = function()
					setHovered(false)
				end,

				Activated = function()
					if not options.disabled then
						setClicked(true)
					end
				end,
			}),

			create("TextLabel", {
				[ref] = "label",
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, -(style.itemHeight - 6 + 6), 1, 0),
				Position = UDim2.new(0, style.itemHeight - 6 + 6, 0, 0),
			}),
		})
	end)

	local style = Style.get()
	local isSelected = options.selected or false

	refs.dot.BackgroundTransparency = isSelected and 0 or 1
	refs.dot.BackgroundColor3 = style.checkMarkColor

	if options.disabled then
		refs.circle.BackgroundTransparency = 0.7
		refs.label.TextColor3 = style.textDisabledColor
	elseif hovered then
		refs.circle.BackgroundColor3 = style.frameBgHoveredColor
		refs.circle.BackgroundTransparency = style.frameBgHoveredTransparency
		refs.label.TextColor3 = style.textColor
	else
		refs.circle.BackgroundColor3 = style.frameBgColor
		refs.circle.BackgroundTransparency = style.frameBgTransparency
		refs.label.TextColor3 = style.textColor
	end

	refs.label.Text = text

	return {
		selected = function()
			return isSelected
		end,
		clicked = function()
			if clicked then
				setClicked(false)
				return true
			end
			return false
		end,
	}
end)
