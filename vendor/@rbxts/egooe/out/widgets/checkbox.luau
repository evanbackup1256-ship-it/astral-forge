export type CheckboxHandle = {
	checked: () -> boolean,
	clicked: () -> boolean,
}

--[=[
	@within EgooE
	@function checkbox
	@tag widgets
	@param text string -- Label displayed next to the checkbox
	@param options {checked: boolean, disabled: boolean}
	@return CheckboxHandle

	An Iris-styled checkbox. May be controlled (pass `checked`) or uncontrolled.

	Returns a handle with:
	- `checked()` – returns whether the checkbox is currently checked.
	- `clicked()` – returns `true` once when the checkbox was toggled this frame.

	```lua
	if checkbox("Enable feature", { checked = enabled }).clicked() then
		enabled = not enabled
	end
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local Contexts = require(script.Parent.Parent.contexts)
local TextService = game:GetService("TextService")

return Runtime.widget(function(text, options)
	options = options or {}

	local checked, setChecked = Runtime.useState(false)
	local clicked, setClicked = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()
		local boxSize = style.itemHeight - 4

		return create("Frame", {
			[ref] = "row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),

			create("TextButton", {
				[ref] = "box",
				BackgroundColor3 = style.frameBgColor,
				BackgroundTransparency = style.frameBgTransparency,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				TextColor3 = style.checkMarkColor,
				TextSize = style.textSize + 2,
				Size = UDim2.new(0, boxSize, 0, boxSize),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Text = "",
				AutoButtonColor = false,

				create("UICorner", {
					CornerRadius = UDim.new(0, 0),
				}),

				create("UIStroke", {
					[ref] = "boxStroke",
					Color = style.borderColor,
					Transparency = style.borderTransparency,
					Thickness = 1,
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
						setChecked(function(c)
							return not c
						end)
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
				Size = UDim2.new(1, -(boxSize + 6), 1, 0),
				Position = UDim2.new(0, boxSize + 6, 0, 0),
			}),
		})
	end)

	local style = Style.get()
	local isChecked = if options.checked ~= nil then options.checked else checked
	local tableCellState = Runtime.useContext(Contexts.tableCellState)

	local box = refs.box
	box.Text = isChecked and "✓" or ""

	if options.disabled then
		box.BackgroundColor3 = style.frameBgColor
		box.BackgroundTransparency = 0.7
		box.TextColor3 = style.textDisabledColor
	elseif hovered then
		box.BackgroundColor3 = style.frameBgHoveredColor
		box.BackgroundTransparency = style.frameBgHoveredTransparency
	else
		box.BackgroundColor3 = style.frameBgColor
		box.BackgroundTransparency = style.frameBgTransparency
		box.TextColor3 = style.checkMarkColor
	end

	refs.label.Text = text
	refs.label.TextColor3 = if options.disabled then style.textDisabledColor else style.textColor

	local boxSize = style.itemHeight - 4
	if tableCellState and tableCellState.centered then
		local measured = TextService:GetTextSize(text, style.textSize, Enum.Font.Code, Vector2.new(1000, style.itemHeight))
		local rowWidth = boxSize + 6 + measured.X
		refs.row.Size = UDim2.new(0, rowWidth, 0, style.itemHeight)
		refs.label.Size = UDim2.new(0, measured.X, 1, 0)
	else
		refs.row.Size = UDim2.new(1, 0, 0, style.itemHeight)
		refs.label.Size = UDim2.new(1, -(boxSize + 6), 1, 0)
	end

	local handle = {
		checked = function()
			return if options.checked ~= nil then options.checked else checked
		end,
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
