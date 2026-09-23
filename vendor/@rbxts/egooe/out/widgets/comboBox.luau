export type ComboBoxHandle = {
	value: () -> string,
	changed: () -> boolean,
}

local UserInputService = game:GetService("UserInputService")

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local WindowConstants = require(script.Parent.windowConstants)

local ARROW = "▼"
local ITEM_HEIGHT = 22
local MAX_VISIBLE_ITEMS = 6

local function findDropdownParent(comboBtn: GuiObject?, rootGui: Instance?): Instance?
	if comboBtn then
		local ancestor = comboBtn.Parent
		while ancestor do
			if ancestor:IsA("GuiObject") and ancestor:GetAttribute(WindowConstants.WINDOW_ATTRIBUTE) then
				return ancestor
			end
			ancestor = ancestor.Parent
		end
	end

	return rootGui
end

local function toParentPosition(guiObject: GuiObject, parentInstance: Instance): Vector2
	local absolutePosition = guiObject.AbsolutePosition

	if parentInstance:IsA("GuiBase2d") then
		return absolutePosition - (parentInstance :: GuiBase2d).AbsolutePosition
	end

	return absolutePosition
end

return Runtime.widget(function(options)
	options = options or {}

	local items = options.items or {}
	local initialSelected = options.selected or (items[1] or "")

	local selectedValue, setSelectedValue = Runtime.useState(initialSelected)
	local initialIndex = nil
	for i, item in ipairs(items) do
		if item == initialSelected then
			initialIndex = i
			break
		end
	end
	local selectedIndex, setSelectedIndex = Runtime.useState(initialIndex)
	local changed, setChanged = Runtime.useState(false)
	local isOpen, setIsOpen = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)

	if options.selected and options.selected ~= selectedValue then
		for idx, item in ipairs(items) do
			if item == options.selected then
				setSelectedValue(options.selected)
				setSelectedIndex(idx)
				break
			end
		end
	end

	-- The combo button (in normal tree)
	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("TextButton", {
			[ref] = "comboBtn",
			BackgroundColor3 = style.frameBgColor,
			BackgroundTransparency = style.frameBgTransparency,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextColor3 = style.textColor,
			TextSize = style.textSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, style.itemHeight),
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

			create("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),

			create("TextLabel", {
				[ref] = "arrow",
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextColor3 = style.textColor,
				TextSize = style.textSize,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.new(0, 16, 1, 0),
				Text = ARROW,
				ZIndex = 2,
			}),

			MouseEnter = function()
				setHovered(true)
			end,

			MouseLeave = function()
				setHovered(false)
			end,

			Activated = function()
				setIsOpen(function(v)
					return not v
				end)
			end,
		})
	end)

	-- Dropdown overlay (created once, parented to root ScreenGui)
	Runtime.useEffect(function()
		local rootGui = Runtime.useRootInstance()
		if not rootGui then
			return
		end

		local style = Style.get()

		local dropdown = Instance.new("ScrollingFrame")
		dropdown.Name = "ComboDropdown"
		dropdown.BackgroundColor3 = style.popupBgColor
		dropdown.BackgroundTransparency = 0
		dropdown.BorderSizePixel = 0
		dropdown.Size = UDim2.new(0, 160, 0, 0)
		dropdown.CanvasSize = UDim2.new(0, 0, 0, 0)
		dropdown.ScrollingEnabled = true
		dropdown.ScrollBarThickness = 0
		dropdown.ScrollBarImageColor3 = style.sliderGrabColor
		dropdown.AutomaticSize = Enum.AutomaticSize.None
		dropdown.ZIndex = 250
		dropdown.Visible = false
		dropdown.Parent = rootGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = dropdown

		local stroke = Instance.new("UIStroke")
		stroke.Color = style.borderColor
		stroke.Transparency = style.borderTransparency
		stroke.Thickness = 1
		stroke.Parent = dropdown

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 0)
		list.Parent = dropdown

		refs.dropdown = dropdown

		return function()
			if dropdown and dropdown.Parent then
				dropdown:Destroy()
			end
			refs.dropdown = nil
		end
	end)

	-- Keyboard navigation when dropdown is open
	Runtime.useEffect(function()
		if not isOpen then
			refs.keyFocusIndex = nil
			return
		end

		refs.keyFocusIndex = selectedIndex

		local conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

			local current = refs.keyFocusIndex or selectedIndex or 1

			if input.KeyCode == Enum.KeyCode.Down then
				local next = math.clamp(current + 1, 1, #items)
				refs.keyFocusIndex = next
				if refs.dropdown then
					local totalH = #items * ITEM_HEIGHT
					local maxH = math.min(totalH, MAX_VISIBLE_ITEMS * ITEM_HEIGHT)
					local scrollY = math.clamp((next - 1) * ITEM_HEIGHT - math.floor(maxH / ITEM_HEIGHT / 2) * ITEM_HEIGHT, 0, totalH - maxH)
					refs.dropdown.CanvasPosition = Vector2.new(0, scrollY)
				end
			elseif input.KeyCode == Enum.KeyCode.Up then
				local prev = math.clamp(current - 1, 1, #items)
				refs.keyFocusIndex = prev
				if refs.dropdown then
					local totalH = #items * ITEM_HEIGHT
					local maxH = math.min(totalH, MAX_VISIBLE_ITEMS * ITEM_HEIGHT)
					local scrollY = math.clamp((prev - 1) * ITEM_HEIGHT - math.floor(maxH / ITEM_HEIGHT / 2) * ITEM_HEIGHT, 0, totalH - maxH)
					refs.dropdown.CanvasPosition = Vector2.new(0, scrollY)
				end
			elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				local idx = refs.keyFocusIndex
				if idx and items[idx] then
					setSelectedValue(items[idx])
					setSelectedIndex(idx)
					setChanged(true)
					setIsOpen(false)
				end
			elseif input.KeyCode == Enum.KeyCode.Escape then
				setIsOpen(false)
			end
		end)

		return function()
			conn:Disconnect()
			refs.keyFocusIndex = nil
		end
	end, isOpen)

	local rootGui = Runtime.useRootInstance()
	local style = Style.get()

	-- Update button visuals — always use internal selectedValue so it reflects clicks immediately
	refs.comboBtn.Text = " " .. selectedValue
	refs.comboBtn.TextSize = style.textSize
	refs.comboBtn.TextColor3 = style.textColor

	if isOpen then
		refs.comboBtn.BackgroundColor3 = style.frameBgHoveredColor
		refs.comboBtn.BackgroundTransparency = style.frameBgHoveredTransparency
	elseif hovered then
		refs.comboBtn.BackgroundColor3 = style.frameBgHoveredColor
		refs.comboBtn.BackgroundTransparency = style.frameBgHoveredTransparency * 1.5
	else
		refs.comboBtn.BackgroundColor3 = style.frameBgColor
		refs.comboBtn.BackgroundTransparency = style.frameBgTransparency
	end

	-- Position and populate the dropdown
	if not isOpen then
		refs.hoveredItem = nil
	end

	if refs.dropdown then
		if not isOpen and rootGui and refs.dropdown.Parent ~= rootGui then
			refs.dropdown.Parent = rootGui
		end

		refs.dropdown.Visible = isOpen

		if isOpen then
			local dropdownParent = findDropdownParent(refs.comboBtn, rootGui)
			if dropdownParent and refs.dropdown.Parent ~= dropdownParent then
				refs.dropdown.Parent = dropdownParent
			end

			-- Align dropdown below the button
			local absPos = refs.comboBtn.AbsolutePosition
			local absSize = refs.comboBtn.AbsoluteSize
			local localPos = if dropdownParent then toParentPosition(refs.comboBtn, dropdownParent) else absPos

			local totalH = #items * ITEM_HEIGHT
			local maxH = math.min(totalH, MAX_VISIBLE_ITEMS * ITEM_HEIGHT)

			refs.dropdown.Position = UDim2.new(0, localPos.X, 0, localPos.Y + absSize.Y + 2)
			refs.dropdown.Size = UDim2.new(0, absSize.X, 0, maxH)
			refs.dropdown.CanvasSize = UDim2.new(0, 0, 0, totalH)

			-- Build item buttons once (only if not already built for this set of items)
			local existingCount = 0
			for _, child in ipairs(refs.dropdown:GetChildren()) do
				if child:IsA("TextButton") then
					existingCount += 1
				end
			end
			if existingCount ~= #items then
				for _, child in ipairs(refs.dropdown:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end

				for i, item in ipairs(items) do
					local itemBtn = Instance.new("TextButton")
					itemBtn.Name = "Item_" .. tostring(i)
					itemBtn.BorderSizePixel = 0
					itemBtn.Font = Enum.Font.Code
					itemBtn.TextColor3 = style.textColor
					itemBtn.TextSize = style.textSize
					itemBtn.TextXAlignment = Enum.TextXAlignment.Left
					itemBtn.Size = UDim2.new(1, 0, 0, ITEM_HEIGHT)
					itemBtn.ZIndex = 251
					itemBtn.AutoButtonColor = false
					itemBtn.LayoutOrder = i
					itemBtn.Parent = refs.dropdown

					local itemPadding = Instance.new("UIPadding")
					itemPadding.PaddingLeft = UDim.new(0, 8)
					itemPadding.PaddingRight = UDim.new(0, 8)
					itemPadding.Parent = itemBtn

					local capturedIndex = i
					local capturedItem = item
					itemBtn.MouseEnter:Connect(function()
						refs.hoveredItem = capturedIndex
					end)
					itemBtn.MouseLeave:Connect(function()
						if refs.hoveredItem == capturedIndex then
							refs.hoveredItem = nil
						end
					end)
					itemBtn.Activated:Connect(function()
						setSelectedValue(capturedItem)
						setSelectedIndex(capturedIndex)
						setChanged(true)
						setIsOpen(false)
					end)

					itemBtn.Text = capturedItem
				end
			end

			-- Update highlight for current selection, hover, and keyboard focus each frame
			for _, child in ipairs(refs.dropdown:GetChildren()) do
				if child:IsA("TextButton") then
					local childIndex = child.LayoutOrder
					local isSelected = childIndex == selectedIndex
					local isHoveredItem = refs.hoveredItem == childIndex
					local isKeyFocused = refs.keyFocusIndex ~= nil and childIndex == refs.keyFocusIndex
					if isSelected then
						child.BackgroundColor3 = style.frameBgHoveredColor
						child.BackgroundTransparency = 0.5
					elseif isHoveredItem or isKeyFocused then
						child.BackgroundColor3 = style.frameBgHoveredColor
						child.BackgroundTransparency = 0.7
					else
						child.BackgroundColor3 = style.buttonColor
						child.BackgroundTransparency = 1
					end
				end
			end
		end
	end

	return {
		value = function()
			return selectedValue
		end,
		changed = function()
			if changed then
				setChanged(false)
				return true
			end
			return false
		end,
	}
end)
