--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.UiCore)("ui")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local Art = require(script.Parent.ArtKit)("Icon")
local h = React.createElement
local FACE = "rbxassetid://74107873507267"

return function(props)
	local controller, count = props.controller, math.max(1, #props.rewards)
	local details = {}
	local brass = Color3.fromRGB(191, 158, 94)
	for index, reward in props.rewards do
		local angle = (index - 1) * 360 / count
		local won = controller.winner == index - 1
		details["prize-" .. reward.Id] = h("frame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = angle, ZIndex = 3,
		}, h("frame", {
			Size = UDim2.fromScale(0.073, 0.088), Position = UDim2.fromScale(0.5, 0.168),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 3,
			Rotation = controller.rotation:map(function(rotation) return -rotation - angle end),
		}, h("uicorner", { CornerRadius = UDim.new(0.25, 0) }),
			h("uistroke", { Color = if won then Palette.cream else brass, Thickness = if won then 2 else 1, Transparency = 0.2 }),
			h(Ui.Text, {
				value = tostring(index), color = if won then Palette.cream else Palette.creamSoft,
				size = math.max(10, math.floor(props.diameter * 0.041)), weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center, sizeConstraint = UDim2.fromScale(1, 1), shadow = false, zIndex = 4,
			})),
			h("frame", {
				Size = UDim2.fromScale(0.016, 0.016), Position = UDim2.fromScale(0.5, 0.036),
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = brass, BorderSizePixel = 0, ZIndex = 4,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = Palette.ink, Thickness = 1, Transparency = 0.2 })),
			if props.diameter >= 220 then h("frame", {
				Name = "RewardGlyph", Size = UDim2.fromScale(0.065, 0.065),
				Position = UDim2.fromScale(0.5, 0.285), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1, ZIndex = 4,
				Rotation = controller.rotation:map(function(rotation) return -rotation - angle end),
			}, h(Art.Icon, {
				kind = Art.rewardIconKind(reward.Reward), color = Palette.creamSoft,
				size = math.floor(props.diameter * 0.065), reducedMotion = true, clipSafe = true,
			})) else nil)
	end
	local quiet = props.reducedMotion
	return h("frame", { Name = "EnamelPrizeWheel2D", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		h("frame", {
			Name = "MountShadow", Size = UDim2.fromScale(0.95, 0.95),
			Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.void, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
		h("frame", {
			Name = "Rotor", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Rotation = controller.rotation, ZIndex = 2,
		}, h("imagelabel", {
			Name = "EnamelFace", Image = FACE, Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
		}), h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, details)),
		h("frame", {
			Name = "Glass", Size = UDim2.fromScale(0.905, 0.905),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uigradient", {
				Rotation = if quiet then 30 else controller.spinEnergy:map(function(energy) return 30 + energy * 18 end),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.28, 0.99),
					NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(0.46, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			})),
		h("frame", {
			Name = "Hub", Size = UDim2.fromScale(0.225, 0.225),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.panelRaised, BorderSizePixel = 0, ZIndex = 6,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", { Color = brass, Thickness = 2 }),
			h("uigradient", { Color = ColorSequence.new(Palette.panelRaised, Palette.ink), Rotation = 90 }),
			h("uiscale", { Scale = if quiet then 1 else controller.spinEnergy:map(function(energy) return 1 + energy * 0.025 end) }),
			h(Ui.Text, {
				value = "AF", size = math.max(14, math.floor(props.diameter * 0.075)),
				color = brass, weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1), zIndex = 7, shadow = false,
			})),
		h("frame", {
			Name = "Clicker", Size = UDim2.fromScale(0.045, 0.095),
			Position = UDim2.fromScale(0.5, 0.024), AnchorPoint = Vector2.new(0.5, 0.15),
			BackgroundColor3 = Palette.cream, BorderSizePixel = 0, ZIndex = 8,
			Rotation = if quiet then 0 else controller.pointerKick:map(function(kick) return -kick * 18 end),
		}, h("uicorner", { CornerRadius = UDim.new(0.4, 0) }),
			h("uistroke", { Color = brass, Thickness = 1 }),
			h("frame", {
				Size = UDim2.fromScale(0.25, 0.13), Position = UDim2.fromScale(0.5, 0.15),
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.ink, BorderSizePixel = 0, ZIndex = 9,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))))
end
