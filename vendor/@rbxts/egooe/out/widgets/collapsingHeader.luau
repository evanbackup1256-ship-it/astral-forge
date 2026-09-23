export type CollapsingHeaderHandle = {
	open: () -> boolean,
}

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(text, fn)
	local isOpen, setIsOpen = Runtime.useState(false)
	local hovered, setHovered = Runtime.useState(false)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		local outerFrame = create("Frame", {
			[ref] = "outer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, style.itemHeight),
			AutomaticSize = Enum.AutomaticSize.Y,

			create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			-- Header button
			create("TextButton", {
				[ref] = "header",
				BackgroundColor3 = style.headerColor,
				BackgroundTransparency = style.headerTransparency,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Text = "",
				Size = UDim2.new(1, 0, 0, style.itemHeight),
				LayoutOrder = 1,
				AutoButtonColor = false,

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
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(0, 14, 1, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Text = "▶",
				}),

				create("TextLabel", {
					[ref] = "title",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextColor3 = style.textColor,
					TextSize = style.textSize,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Size = UDim2.new(1, -20, 1, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 18, 0.5, 0),
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
			}),

			-- Children container (hidden when closed)
			create("Frame", {
				[ref] = "content",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,

				create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),

				create("UIPadding", {
					PaddingLeft = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				}),
			}),
		})

		return outerFrame, ref.content
	end)

	local style = Style.get()

	refs.title.Text = text
	refs.arrow.Text = isOpen and "▼" or "▶"
	refs.content.Visible = isOpen

	if hovered then
		refs.header.BackgroundTransparency = style.headerTransparency * 0.5
	else
		refs.header.BackgroundTransparency = style.headerTransparency
	end

	if isOpen and fn then
		Runtime.scope(fn)
	end

	return {
		open = function()
			return isOpen
		end,
	}
end)
