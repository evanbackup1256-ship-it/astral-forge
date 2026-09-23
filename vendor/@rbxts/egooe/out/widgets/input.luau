export type InputHandle = {
	value: () -> string,
	changed: () -> boolean,
	submitted: () -> boolean,
}

--[=[
	@within EgooE
	@function input
	@tag widgets
	@param options {text: string, placeholder: string, label: string}
	@return InputHandle

	An Iris-styled text input box.

	Returns a handle with:
	- `value()` – returns the current text value.
	- `changed()` – returns `true` once when the text changed this frame.
	- `submitted()` – returns `true` once when Enter was pressed this frame.

	```lua
	local handle = input({ placeholder = "Enter your name..." })
	if handle.changed() then
		print("New value:", handle.value())
	end
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(options)
	options = options or {}

	local textValue, setTextValue = Runtime.useState(options.text or "")
	local changed, setChanged = Runtime.useState(false)
	local submitted, setSubmitted = Runtime.useState(false)
	local focused, setFocused = Runtime.useState(false)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		local frame = create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),
		})

		local labelWidth = 0
		if options.label then
			labelWidth = 80
			create("TextLabel", {
				[ref] = "label",
				Parent = frame,
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(0, labelWidth - 4, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
			})
		end

		create("Frame", {
			[ref] = "inputBg",
			Parent = frame,
			BackgroundColor3 = style.frameBgColor,
			BackgroundTransparency = style.frameBgTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -labelWidth, 1, 0),
			Position = UDim2.new(0, labelWidth, 0, 0),

			create("UICorner", {
				CornerRadius = UDim.new(0, 0),
			}),

			create("UIStroke", {
				[ref] = "inputStroke",
				Color = style.borderColor,
				Transparency = style.borderTransparency,
				Thickness = 1,
			}),

			create("TextBox", {
				[ref] = "textBox",
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				PlaceholderColor3 = style.textDisabledColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 1, 0),
				ClearTextOnFocus = false,
				TextTruncate = Enum.TextTruncate.AtEnd,

				create("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),

				Focused = function()
					setFocused(true)
				end,

				FocusLost = function(enterPressed)
					setFocused(false)
					if enterPressed then
						setSubmitted(true)
					end
				end,
			}),
		})

		-- Listen for text changes and store the connection for cleanup
		ref.textConnection = ref.textBox:GetPropertyChangedSignal("Text"):Connect(function()
			setTextValue(ref.textBox.Text)
			setChanged(true)
		end)

		return frame
	end)

	-- Clean up the text change connection when the widget is destroyed
	Runtime.useEffect(function()
		return function()
			if refs.textConnection then
				refs.textConnection:Disconnect()
				refs.textConnection = nil
			end
		end
	end)

	local style = Style.get()
	local box = refs.textBox

	-- Sync controlled text
	if options.text ~= nil and box.Text ~= options.text then
		box.Text = options.text
	end

	box.PlaceholderText = options.placeholder or ""

	-- Highlight border when focused
	if focused then
		refs.inputStroke.Color = style.sliderGrabColor
		refs.inputStroke.Transparency = 0
	else
		refs.inputStroke.Color = style.borderColor
		refs.inputStroke.Transparency = style.borderTransparency
	end

	if refs.label then
		refs.label.Text = options.label or ""
	end

	local handle = {
		value = function()
			return textValue
		end,
		changed = function()
			if changed then
				setChanged(false)
				return true
			end
			return false
		end,
		submitted = function()
			if submitted then
				setSubmitted(false)
				return true
			end
			return false
		end,
	}

	return handle
end)
