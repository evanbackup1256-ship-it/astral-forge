--!nonstrict

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.CoreKit)("theme").Palette

local function Placeholder(props)
	return React.createElement("Frame", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
	})
end

return function()
	local children = {
		Status = React.createElement("TextLabel", {
			Size = UDim2.new(1, -32, 0, 28),
			Position = UDim2.fromOffset(16, 12),
			BackgroundTransparency = 1,
			Text = "Opening page…",
			TextColor3 = Palette.creamSoft,
			TextSize = 16,
			Font = Enum.Font.BuilderSansMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Summary = React.createElement(Placeholder, {
			size = UDim2.new(1, -32, 0, 104),
			position = UDim2.fromOffset(16, 52),
		}),
	}

	for index = 1, 3 do
		children["Row" .. index] = React.createElement(Placeholder, {
			size = UDim2.new(1, -32, 0, 60),
			position = UDim2.fromOffset(16, 168 + (index - 1) * 72),
		})
	end

	return React.createElement("Frame", {
		Name = "PageLoading",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, children)
end
