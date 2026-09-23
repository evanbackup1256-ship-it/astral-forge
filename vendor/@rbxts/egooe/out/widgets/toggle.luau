export type ToggleHandle = {
	on: () -> boolean,
	clicked: () -> boolean,
}

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)

local TRACK_WIDTH = 36
local TRACK_HEIGHT = 18
local HANDLE_SIZE = 14

return Runtime.widget(function(text, options)
	options = options or {}

	local isOn, setIsOn = Runtime.useState(false)
	local clicked, setClicked = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("Frame", {
			[ref] = "row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),

			-- Track background
			create("TextButton", {
				[ref] = "track",
				BackgroundColor3 = style.toggleOffColor,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Text = "",
				Size = UDim2.new(0, TRACK_WIDTH, 0, TRACK_HEIGHT),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				AutoButtonColor = false,

				create("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),

				-- Handle circle
				create("Frame", {
					[ref] = "handle",
					BackgroundColor3 = style.toggleHandleColor,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Size = UDim2.new(0, HANDLE_SIZE, 0, HANDLE_SIZE),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, HANDLE_SIZE / 2 + 2, 0.5, 0),

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
						setIsOn(function(v)
							return not v
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
				Size = UDim2.new(1, -(TRACK_WIDTH + 8), 1, 0),
				Position = UDim2.new(0, TRACK_WIDTH + 8, 0, 0),
			}),
		})
	end)

	local style = Style.get()
	local currentOn = if options.on ~= nil then options.on else isOn

	-- Slide handle position
	local handleX = currentOn and (TRACK_WIDTH - HANDLE_SIZE / 2 - 2) or (HANDLE_SIZE / 2 + 2)
	refs.handle.Position = UDim2.new(0, handleX, 0.5, 0)

	-- Track color
	if options.disabled then
		refs.track.BackgroundColor3 = style.toggleOffColor
		refs.track.BackgroundTransparency = 0.5
		refs.label.TextColor3 = style.textDisabledColor
	elseif currentOn then
		refs.track.BackgroundColor3 = style.toggleOnColor
		refs.track.BackgroundTransparency = hovered and 0.2 or 0
		refs.label.TextColor3 = style.textColor
	else
		refs.track.BackgroundColor3 = style.toggleOffColor
		refs.track.BackgroundTransparency = hovered and 0.2 or 0
		refs.label.TextColor3 = style.textColor
	end

	refs.handle.BackgroundColor3 = style.toggleHandleColor
	refs.label.Text = text

	return {
		on = function()
			return currentOn
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
