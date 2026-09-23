--[=[
	@within EgooE
	@interface ChildWindowOptions

	.title? string -- Panel title
	.height? number -- Content area height in pixels (default 200)
	.minimizable? boolean -- Show minimize button (default true)
	.scrollX? boolean -- Enable horizontal scroll (default false)
	.scrollY? boolean -- Enable vertical scroll (default true)
]=]

--[=[
	@within EgooE
	@function childWindow
	@tag widgets
	@param options string | ChildWindowOptions -- Title string or options table
	@param children () -> () -- Children

	A scrollable panel that lives inline inside a parent window. Fills the parent's
	full width, uses an explicit content height, and can be minimized to its header.
	No dragging, resizing, or closing.

	```lua
	window({ title = "My Window" }, function()
		childWindow({ title = "Section", height = 150 }, function()
			label("Scrollable content here")
		end)
	end)
	```
]=]

export type ChildWindowHandle = {
	minimized: () -> boolean,
}

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local Contexts = require(script.Parent.Parent.contexts)

local function pointInside(guiObject: GuiObject?, position: Vector3): boolean
	if guiObject == nil or not guiObject.Visible then
		return false
	end

	local absolutePosition = guiObject.AbsolutePosition
	local absoluteSize = guiObject.AbsoluteSize

	return position.X >= absolutePosition.X
		and position.X <= absolutePosition.X + absoluteSize.X
		and position.Y >= absolutePosition.Y
		and position.Y <= absolutePosition.Y + absoluteSize.Y
end

return Runtime.widget(function(options, fn)
	if type(options) == "string" then
		options = { title = options }
	end
	options = options or {}

	local minimized, setMinimized = Runtime.useState(false)

	local contentHeight = options.height or 200
	local minimizable = if options.minimizable ~= nil then options.minimizable else true

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		local titleBarHeight = style.titleBarHeight
		local padX = style.windowPadding.X
		local padY = style.windowPadding.Y

		create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, titleBarHeight + contentHeight),
			ClipsDescendants = false,

			create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			-- Header bar
			create("TextButton", {
				[ref] = "headerBar",
				BackgroundColor3 = style.titleBgActiveColor,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, titleBarHeight),
				Text = "",
				Active = true,
				AutoButtonColor = false,
				LayoutOrder = 1,

				create("UICorner", {
					CornerRadius = UDim.new(0, 0),
				}),

				create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),

				create("UIPadding", {
					PaddingLeft = UDim.new(0, padX),
					PaddingRight = UDim.new(0, 4),
				}),

				create("TextLabel", {
					[ref] = "title",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextColor3 = style.textColor,
					TextSize = style.textSize,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.new(0, 0, 1, 0),
					LayoutOrder = 1,

					create("UIFlexItem", {
						FlexMode = Enum.UIFlexMode.Fill,
					}),
				}),

				create("TextButton", {
					[ref] = "minimize",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextColor3 = Color3.fromRGB(200, 200, 200),
					TextSize = style.textSize + 2,
					Size = UDim2.new(0, 16, 0, 16),
					Text = "−",
					LayoutOrder = 2,
					Visible = false,

					MouseEnter = function()
						ref.minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
					end,

					MouseLeave = function()
						ref.minimize.TextColor3 = Color3.fromRGB(200, 200, 200)
					end,

					Activated = function()
						setMinimized(function(prev)
							return not prev
						end)
					end,
				}),

				InputEnded = function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					if not ref.minimize.Visible or pointInside(ref.minimize, input.Position) then
						return
					end

					setMinimized(function(prev)
						return not prev
					end)
				end,
			}),

			-- Scrollable content area
			create("ScrollingFrame", {
				[ref] = "container",
				BackgroundColor3 = style.windowBgColor,
				BackgroundTransparency = style.windowBgTransparency,
				BorderSizePixel = 0,
				ScrollBarThickness = style.scrollbarSize,
				ScrollBarImageColor3 = style.scrollbarGrabColor,
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				Size = UDim2.new(1, 0, 0, contentHeight),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,

				create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, style.itemSpacing.Y),
				}),

				create("UIPadding", {
					PaddingLeft = UDim.new(0, padX),
					PaddingRight = UDim.new(0, padX),
					PaddingTop = UDim.new(0, padY),
					PaddingBottom = UDim.new(0, padY),
				}),
			}),
		})

		return ref.frame, ref.container
	end)

	local style = Style.get()
	local titleBarHeight = style.titleBarHeight

	refs.title.Text = options.title or ""
	refs.minimize.Visible = minimizable

	-- Minimize collapse / restore
	if minimized then
		refs.frame.Size = UDim2.new(1, 0, 0, titleBarHeight)
		refs.container.Visible = false
	else
		refs.frame.Size = UDim2.new(1, 0, 0, titleBarHeight + contentHeight)
		refs.container.Size = UDim2.new(1, 0, 0, contentHeight)
		refs.container.Visible = true
	end

	-- Scroll axes
	local scrollX = options.scrollX or false
	local scrollY = if options.scrollY ~= nil then options.scrollY else true
	if scrollX and scrollY then
		refs.container.AutomaticCanvasSize = Enum.AutomaticSize.XY
	elseif scrollX then
		refs.container.AutomaticCanvasSize = Enum.AutomaticSize.X
	elseif scrollY then
		refs.container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	else
		refs.container.AutomaticCanvasSize = Enum.AutomaticSize.None
	end

	Runtime.provideContext(Contexts.scrollX, scrollX)

	if not minimized then
		Runtime.scope(fn)
	end

	return {
		minimized = function()
			if minimized then
				setMinimized(false)
				return true
			end
			return false
		end,
	} :: ChildWindowHandle
end)
