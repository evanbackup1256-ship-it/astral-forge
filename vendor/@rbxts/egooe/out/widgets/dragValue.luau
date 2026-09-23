local UserInputService = game:GetService("UserInputService")

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local createConnect = require(script.Parent.Parent.createConnect)

return Runtime.widget(function(options)
	options = options or {}

	local min = options.min or 0
	local max = options.max or 100
	local step = options.step or 1
	local initial = options.initial or min
	local value, setValue = Runtime.useState(initial)
	local dragging, setDragging = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)
	local editing, setEditing = Runtime.useState(false)

	local function displayValueText(rawValue)
		if step == 0 then
			return tostring(rawValue)
		end

		return tostring(math.round(rawValue * (1 / step)) / (1 / step))
	end

	local function clampToStep(rawValue)
		local numericValue = tonumber(rawValue)
		if numericValue == nil then
			return nil
		end

		if step ~= 0 then
			numericValue = math.round(numericValue / step) * step
		end

		return math.clamp(numericValue, min, max)
	end

	local function commitEdit(ref)
		local nextValue = clampToStep(ref.textBox.Text)
		if nextValue ~= nil then
			setValue(nextValue)
		end

		setEditing(false)
	end

	local function cancelEdit(ref)
		ref.textBox.Text = ref.editStartText or ""
		setEditing(false)
	end

	local function beginEdit(ref)
		local text = displayValueText(ref.currentValue or initial)

		ref.editStartText = text
		ref.textBox.Text = text
		setEditing(true)

		ref.textBox.Visible = true
		ref.btn.Visible = false
		ref.textBox:CaptureFocus()
		ref.textBox.CursorPosition = #ref.textBox.Text + 1
	end

	local refs = Runtime.useInstance(function(ref)
		local connectEvent = createConnect()
		local style = Style.get()

		ref.connection = nil
		ref.lastX = nil
		ref.startX = nil
		ref.didDrag = false
		ref.skipCommit = false

		local frame = create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),

			create("TextButton", {
				[ref] = "btn",
				BackgroundColor3 = style.frameBgColor,
				BackgroundTransparency = style.frameBgTransparency,
				BorderSizePixel = 0,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				Size = UDim2.new(1, 0, 1, 0),
				AutoButtonColor = false,

				create("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),

				create("UIStroke", {
					[ref] = "stroke",
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

				InputBegan = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					ref.startX = input.Position.X
					ref.lastX = input.Position.X
					ref.didDrag = false

					if ref.connection then
						ref.connection:Disconnect()
					end

					ref.connection = connectEvent(UserInputService, "InputChanged", function(moveInput)
						if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement then
							return
						end

						local totalDx = moveInput.Position.X - ref.startX
						if not ref.didDrag and math.abs(totalDx) < 4 then
							return
						end

						ref.didDrag = true
						setDragging(true)

						local dx = moveInput.Position.X - ref.lastX
						ref.lastX = moveInput.Position.X

						setValue(function(current)
							local steps = math.round(dx / 4)
							local newVal = current + steps * step
							return math.clamp(newVal, min, max)
						end)
					end)
				end,

				InputEnded = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					setDragging(false)

					if ref.connection then
						ref.connection:Disconnect()
						ref.connection = nil
					end

					if not ref.didDrag then
						beginEdit(ref)
					end
				end,
			}),

			create("TextBox", {
				[ref] = "textBox",
				BackgroundColor3 = style.frameBgColor,
				BackgroundTransparency = style.frameBgTransparency,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 1, 0),
				Visible = false,

				create("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),

				create("UIStroke", {
					[ref] = "textStroke",
					Color = style.sliderGrabColor,
					Transparency = 0,
					Thickness = 1,
				}),

				create("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),

				InputBegan = function(input)
					if input.KeyCode == Enum.KeyCode.Escape then
						ref.skipCommit = true
						cancelEdit(ref)
						ref.textBox:ReleaseFocus(false)
					end
				end,

				FocusLost = function(enterPressed)
					if ref.skipCommit then
						ref.skipCommit = false
						return
					end

					if enterPressed or ref.isEditing then
						commitEdit(ref)
					end
				end,
			}),
		})

		return frame
	end)

	Runtime.useEffect(function()
		return function()
			if refs.connection then
				refs.connection:Disconnect()
				refs.connection = nil
			end
		end
	end)

	local style = Style.get()
	local currentValue = math.clamp(value, min, max)
	local displayValue = displayValueText(currentValue)
	refs.currentValue = currentValue
	refs.isEditing = editing

	if dragging then
		refs.btn.BackgroundColor3 = style.frameBgHoveredColor
		refs.btn.BackgroundTransparency = style.frameBgHoveredTransparency
	elseif hovered then
		refs.btn.BackgroundColor3 = style.frameBgHoveredColor
		refs.btn.BackgroundTransparency = style.frameBgHoveredTransparency * 1.5
	else
		refs.btn.BackgroundColor3 = style.frameBgColor
		refs.btn.BackgroundTransparency = style.frameBgTransparency
	end

	refs.textBox.BackgroundColor3 = style.frameBgColor
	refs.textBox.BackgroundTransparency = style.frameBgTransparency
	refs.textBox.TextColor3 = style.textColor
	refs.textBox.TextSize = style.textSize
	refs.textStroke.Color = style.sliderGrabColor
	refs.textStroke.Transparency = 0

	if options.label then
		refs.btn.Text = options.label .. ": " .. displayValue
	else
		refs.btn.Text = displayValue
	end

	refs.btn.Visible = not editing
	refs.textBox.Visible = editing

	return currentValue
end)
