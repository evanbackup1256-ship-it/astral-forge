export type ButtonHandle = {
	clicked: () -> boolean,
}

--[=[
	@within EgooE
	@function button
	@tag widgets
	@param text string -- The label on the button
	@param options {width: UDim | number, disabled: boolean}
	@return ButtonHandle

	An Iris-styled button. Returns a handle with:
	- `clicked()` – returns `true` once when the button was clicked this frame.

	```lua
	if button("Click me").clicked() then
		print("Clicked!")
	end
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(text, options)
	options = options or {}

	local clicked, setClicked = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)
	local pressing, setPressing = Runtime.useState(false)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("TextButton", {
			[ref] = "button",
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextColor3 = style.textColor,
			TextSize = style.textSize,
			Size = UDim2.new(1, 0, 0, style.itemHeight),
			BackgroundColor3 = style.buttonColor,
			BackgroundTransparency = style.buttonTransparency,
			AutoButtonColor = false,

			create("UICorner", {
				CornerRadius = UDim.new(0, 0),
			}),

			create("UIStroke", {
				Color = style.borderColor,
				Transparency = style.borderTransparency,
				Thickness = 1,
			}),

			MouseEnter = function()
				setHovered(true)
			end,

			MouseLeave = function()
				setHovered(false)
				setPressing(false)
			end,

			MouseButton1Down = function()
				print("[Button] MouseButton1Down:", text)
				setPressing(true)
			end,

			MouseButton1Up = function()
				setPressing(false)
			end,

			Activated = function()
				print("[Button] Activated:", text)
				if not options.disabled then
					setClicked(true)
				end
			end,
		})
	end)

	local btn = refs.button
	btn.Text = text
	btn.AutoButtonColor = false

	local style = Style.get()
	if options.disabled then
		btn.BackgroundColor3 = style.buttonColor
		btn.BackgroundTransparency = 0.8
		btn.TextColor3 = style.textDisabledColor
	elseif pressing then
		btn.BackgroundColor3 = style.buttonActiveColor
		btn.BackgroundTransparency = style.buttonActiveTransparency
		btn.TextColor3 = style.textColor
	elseif hovered then
		btn.BackgroundColor3 = style.buttonHoveredColor
		btn.BackgroundTransparency = style.buttonHoveredTransparency
		btn.TextColor3 = style.textColor
	else
		btn.BackgroundColor3 = style.buttonColor
		btn.BackgroundTransparency = style.buttonTransparency
		btn.TextColor3 = style.textColor
	end

	if options.width then
		local w = options.width
		if type(w) == "number" then
			btn.Size = UDim2.new(0, w, 0, style.itemHeight)
		else
			btn.Size = UDim2.new(w.Scale, w.Offset, 0, style.itemHeight)
		end
	end

	local handle = {
		clicked = function()
			if clicked then
				setClicked(false)
				return true
			end
			return false
		end,
	}

	return handle
end)
