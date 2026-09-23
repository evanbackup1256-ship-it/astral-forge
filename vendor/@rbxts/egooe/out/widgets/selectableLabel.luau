export type SelectableLabelHandle = {
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

		return create("TextButton", {
			[ref] = "btn",
			BackgroundColor3 = style.selectableColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextColor3 = style.textColor,
			TextSize = style.textSize,
			Size = UDim2.new(0, 0, 0, style.itemHeight),
			AutomaticSize = Enum.AutomaticSize.X,
			AutoButtonColor = false,

			create("UICorner", {
				CornerRadius = UDim.new(0, 2),
			}),

			create("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
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
		})
	end)

	local style = Style.get()
	local isSelected = options.selected or false

	refs.btn.Text = text
	refs.btn.TextSize = style.textSize

	if options.disabled then
		refs.btn.BackgroundTransparency = 1
		refs.btn.TextColor3 = style.textDisabledColor
	elseif isSelected then
		refs.btn.BackgroundColor3 = style.selectableColor
		refs.btn.BackgroundTransparency = style.selectableTransparency
		refs.btn.TextColor3 = style.textColor
	elseif hovered then
		refs.btn.BackgroundColor3 = style.selectableColor
		refs.btn.BackgroundTransparency = 0.85
		refs.btn.TextColor3 = style.textColor
	else
		refs.btn.BackgroundTransparency = 1
		refs.btn.TextColor3 = style.textColor
	end

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
