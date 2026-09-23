--[=[
	@within EgooE
	@function slider
	@tag widgets
	@param options {min: number, max: number, initial: number, label: string, width: number}
	@return number -- The current slider value

	An Iris-styled horizontal slider. Returns the current value each frame.

	```lua
	local value = slider({ min = 0, max = 100, initial = 50, label = "Speed" })
	```
]=]

local UserInputService = game:GetService("UserInputService")

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local createConnect = require(script.Parent.Parent.createConnect)

return Runtime.widget(function(options)
	if type(options) == "number" then
		options = { max = options }
	end
	options = options or {}

	local min = options.min or 0
	local max = options.max or 1
	local initial = options.initial or min
	local initPercent = (initial - min) / (max - min)
	local percentageValue, setPercentageValue = Runtime.useState(initPercent)

	local refs = Runtime.useInstance(function(ref)
		local connectEvent = createConnect()
		local style = Style.get()
		local grabSize = 10
		local trackHeight = 4

		ref.connection = nil

		local function startDrag()
			if ref.connection then
				ref.connection:Disconnect()
			end
			ref.connection = connectEvent(UserInputService, "InputChanged", function(moveInput)
				if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement then
					return
				end
				local trackFrame = ref.track
				local trackWidth = trackFrame.AbsoluteSize.X
				local x = math.clamp(moveInput.Position.X - trackFrame.AbsolutePosition.X, 0, trackWidth)
				setPercentageValue(x / trackWidth)
			end)
		end

		return create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),

			-- Track background
			create("TextButton", {
				[ref] = "track",
				BackgroundColor3 = style.frameBgColor,
				BackgroundTransparency = style.frameBgTransparency,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, grabSize / 2, 0.5, 0),
				Size = UDim2.new(1, -grabSize, 0, trackHeight),

				create("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),

				-- Active fill
				create("Frame", {
					[ref] = "fill",
					BackgroundColor3 = style.sliderGrabColor,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Size = UDim2.new(0, 0, 1, 0),

					create("UICorner", {
						CornerRadius = UDim.new(0, 2),
					}),
				}),

				InputBegan = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end
					local trackFrame = ref.track
					local trackWidth = trackFrame.AbsoluteSize.X
					local x = math.clamp(input.Position.X - trackFrame.AbsolutePosition.X, 0, trackWidth)
					setPercentageValue(x / trackWidth)
					startDrag()
				end,

				InputEnded = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end
					if ref.connection then
						ref.connection:Disconnect()
						ref.connection = nil
					end
				end,
			}),

			-- Grab handle
			create("TextButton", {
				[ref] = "grab",
				BackgroundColor3 = style.sliderGrabColor,
				BorderSizePixel = 0,
				Text = "",
				Size = UDim2.new(0, grabSize, 0, grabSize),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				AutoButtonColor = false,

				create("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),

				InputBegan = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end
					startDrag()
				end,

				InputEnded = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					if ref.connection then
						ref.connection:Disconnect()
						ref.connection = nil
					end
				end,
			}),

			-- Value label overlay
			create("TextLabel", {
				[ref] = "valueLabel",
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 2,
			}),
		})
	end)

	-- Ensure the drag connection is cleaned up when this widget is destroyed
	Runtime.useEffect(function()
		return function()
			if refs.connection then
				refs.connection:Disconnect()
				refs.connection = nil
			end
		end
	end)

	-- Update visual positions using scale-based UDim (no AbsoluteSize needed)
	refs.grab.Position = UDim2.new(percentageValue, 10 * (0.5 - percentageValue), 0.5, 0)
	refs.fill.Size = UDim2.new(percentageValue, 0, 1, 0)

	local value = percentageValue * (max - min) + min
	local displayValue = math.round(value * 100) / 100

	if options.label then
		refs.valueLabel.Text = options.label .. ": " .. tostring(displayValue)
	else
		refs.valueLabel.Text = tostring(displayValue)
	end

	return value
end)
