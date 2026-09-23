export type ModalHandle = {
	closed: () -> boolean,
}

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)

local DIALOG_WIDTH = 320

return Runtime.widget(function(options, fn)
	if type(options) == "string" then
		options = { title = options }
	end
	options = options or {}

	local open = options.open ~= false
	local closedSignal, setClosedSignal = Runtime.useState(false)

	-- Zero-size placeholder keeps the node alive in the EgooE tree
	local refs = Runtime.useInstance(function(ref)
		local placeholder = Instance.new("Frame")
		placeholder.Name = "ModalPlaceholder"
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.new(0, 0, 0, 0)
		ref.placeholder = placeholder
		return placeholder
	end)

	-- Build overlay + dialog once (useEffect runs sync on frame 1, no deps)
	Runtime.useEffect(function()
		local rootGui = Runtime.useRootInstance()
		if not rootGui then
			return
		end

		local style = Style.get()
		local padX = style.windowPadding.X
		local padY = style.windowPadding.Y
		local titleBarHeight = style.titleBarHeight

		local overlay = Instance.new("Frame")
		overlay.Name = "ModalOverlay"
		overlay.BackgroundColor3 = style.modalOverlayColor
		overlay.BackgroundTransparency = style.modalOverlayTransparency
		overlay.BorderSizePixel = 0
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.ZIndex = 300
		overlay.Visible = false
		overlay.Parent = rootGui

		local dialog = Instance.new("Frame")
		dialog.Name = "ModalDialog"
		dialog.BackgroundColor3 = style.windowBgColor
		dialog.BackgroundTransparency = style.windowBgTransparency
		dialog.BorderSizePixel = 0
		dialog.AnchorPoint = Vector2.new(0.5, 0.5)
		dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
		dialog.Size = UDim2.new(0, DIALOG_WIDTH, 0, 0)
		dialog.AutomaticSize = Enum.AutomaticSize.Y
		dialog.ZIndex = 301
		dialog.Parent = overlay

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 0)
		corner.Parent = dialog

		local stroke = Instance.new("UIStroke")
		stroke.Color = style.borderColor
		stroke.Transparency = style.borderTransparency
		stroke.Thickness = 1
		stroke.Parent = dialog

		local titleBar = Instance.new("Frame")
		titleBar.Name = "TitleBar"
		titleBar.BackgroundColor3 = style.titleBgActiveColor
		titleBar.BackgroundTransparency = 0
		titleBar.BorderSizePixel = 0
		titleBar.Size = UDim2.new(1, 0, 0, titleBarHeight)
		titleBar.ZIndex = 302
		titleBar.Parent = dialog

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextColor3 = style.textColor
		titleLabel.TextSize = style.textSize
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Size = UDim2.new(1, -30, 1, 0)
		titleLabel.Position = UDim2.new(0, padX, 0, 0)
		titleLabel.ZIndex = 303
		titleLabel.Text = options.title or ""
		titleLabel.Parent = titleBar

		if options.closable then
			local closeBtn = Instance.new("TextButton")
			closeBtn.Name = "CloseButton"
			closeBtn.BackgroundTransparency = 1
			closeBtn.Font = Enum.Font.GothamBold
			closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
			closeBtn.TextSize = style.textSize + 2
			closeBtn.Size = UDim2.new(0, 16, 0, 16)
			closeBtn.AnchorPoint = Vector2.new(1, 0.5)
			closeBtn.Position = UDim2.new(1, -padX, 0.5, 0)
			closeBtn.Text = "×"
			closeBtn.ZIndex = 303
			closeBtn.AutoButtonColor = false
			closeBtn.Parent = titleBar
			closeBtn.Activated:Connect(function()
				setClosedSignal(true)
			end)
		end

		local content = Instance.new("Frame")
		content.Name = "ModalContent"
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.Size = UDim2.new(1, 0, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.Position = UDim2.new(0, 0, 0, titleBarHeight)
		content.ZIndex = 302
		content.Parent = dialog

		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, style.itemSpacing.Y)
		listLayout.Parent = content

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, padX)
		padding.PaddingRight = UDim.new(0, padX)
		padding.PaddingTop = UDim.new(0, padY)
		padding.PaddingBottom = UDim.new(0, padY)
		padding.Parent = content

		refs.overlay = overlay
		refs.modalContent = content

		return function()
			if overlay and overlay.Parent then
				overlay:Destroy()
			end
			refs.overlay = nil
			refs.modalContent = nil
		end
	end)

	if refs.overlay then
		refs.overlay.Visible = open

		if open and refs.modalContent then
			Runtime.scope(function()
				Runtime.useInstance(function()
					return nil, refs.modalContent
				end)
				Runtime.scope(fn)
			end)
		end
	end

	return {
		closed = function()
			if closedSignal then
				setClosedSignal(false)
				return true
			end
			return false
		end,
	}
end)
