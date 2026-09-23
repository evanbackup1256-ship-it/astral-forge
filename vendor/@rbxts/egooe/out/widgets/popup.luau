local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)

local MIN_WIDTH = 120

return Runtime.widget(function(options, fn)
	options = options or {}

	local open = options.open or false

	-- Full-width zero-height placeholder — its AbsolutePosition tells us
	-- exactly where in screen space the popup should be anchored.
	local refs = Runtime.useInstance(function(ref)
		local placeholder = Instance.new("Frame")
		placeholder.Name = "PopupPlaceholder"
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.new(1, 0, 0, 0)
		ref.placeholder = placeholder
		return placeholder
	end)

	Runtime.useEffect(function()
		local rootGui = Runtime.useRootInstance()
		if not rootGui then
			return
		end

		local style = Style.get()

		local panel = Instance.new("Frame")
		panel.Name = "PopupPanel"
		panel.BackgroundColor3 = style.popupBgColor
		panel.BackgroundTransparency = 0
		panel.BorderSizePixel = 0
		panel.Size = UDim2.new(0, MIN_WIDTH, 0, 0)
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.ZIndex = 200
		panel.Visible = false
		panel.Parent = rootGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = panel

		local stroke = Instance.new("UIStroke")
		stroke.Color = style.borderColor
		stroke.Transparency = style.borderTransparency
		stroke.Thickness = 1
		stroke.Parent = panel

		local content = Instance.new("Frame")
		content.Name = "PopupContent"
		content.BackgroundTransparency = 1
		content.Size = UDim2.new(1, 0, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.ZIndex = 200
		content.Parent = panel

		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 2)
		listLayout.Parent = content

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = content

		refs.popupPanel = panel
		refs.popupContent = content

		return function()
			if panel and panel.Parent then
				panel:Destroy()
			end
			refs.popupPanel = nil
			refs.popupContent = nil
		end
	end)

	if refs.popupPanel then
		refs.popupPanel.Visible = open

		if open then
			-- Use explicit position override, or anchor below the placeholder
			if options.position then
				refs.popupPanel.Position = UDim2.new(0, options.position.X, 0, options.position.Y)
				refs.popupPanel.Size = UDim2.new(0, math.max(MIN_WIDTH, refs.placeholder.AbsoluteSize.X), 0, 0)
			else
				local abs = refs.placeholder.AbsolutePosition
				local w = math.max(MIN_WIDTH, refs.placeholder.AbsoluteSize.X)
				refs.popupPanel.Position = UDim2.new(0, abs.X, 0, abs.Y)
				refs.popupPanel.Size = UDim2.new(0, w, 0, 0)
			end

			if refs.popupContent then
				Runtime.scope(function()
					Runtime.useInstance(function()
						return nil, refs.popupContent
					end)
					Runtime.scope(fn)
				end)
			end
		end
	end
end)
