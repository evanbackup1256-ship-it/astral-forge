--!nonstrict
-- Prize wheel built entirely from UI primitives (frames, gradients, strokes); no image face.
-- useWheelController (PagesShop) owns motion and the server result; this only draws it.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local Art = require(script.Parent.ArtKit)("Icon")
local Geometry = require(script.Parent.WheelGeometry)
local Palette = theme.Palette
local darken = theme.darken
local h = React.createElement

local BRASS = Color3.fromRGB(196, 162, 98)
local FACE_SCALE = 0.92 -- wedge disk inside the rim
-- hard step: the half past the gradient midpoint is visible, so Rotation = a shows [a, a + 180)
local HALF_MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4985, 1),
	NumberSequenceKeypoint.new(0.5015, 0),
	NumberSequenceKeypoint.new(1, 0),
})

local function wedgeColor(reward, index, won)
	local base = reward.Color or Palette.violet
	if won then
		return darken(base, 0.08)
	end
	-- neighbours of the same rarity still read as separate wedges
	return darken(base, if index % 2 == 0 then 0.42 else 0.56)
end

local function halfClip(props)
	local slots = {}
	for slot = 1, props.slots do
		local function layer(rotation)
			return props.plan(rotation)[props.side][slot]
		end
		-- each clip is 1 px wider than half so the halves overlap at the centre seam;
		-- the face itself stays exactly the clip pair's full width
		slots["layer" .. slot] = h("frame", {
			Size = UDim2.new(2, -2, 1, 0),
			Position = if props.side == "right" then UDim2.new(-1, 2, 0, 0) else UDim2.new(),
			BorderSizePixel = 0,
			ZIndex = slot,
			BackgroundColor3 = props.rotation:map(function(rotation)
				local current = layer(rotation)
				return if current then props.colors[current.segment + 1] else Palette.ink
			end),
			BackgroundTransparency = props.rotation:map(function(rotation)
				return if layer(rotation) then 0 else 1
			end),
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Transparency = HALF_MASK,
			Rotation = props.rotation:map(function(rotation)
				local current = layer(rotation)
				return if current then current.angle else 0
			end),
		}))
	end
	return h("frame", {
		Name = if props.side == "right" then "RightHalf" else "LeftHalf",
		Size = UDim2.new(0.5, 1, 1, 0),
		Position = if props.side == "right" then UDim2.new(0.5, -1, 0, 0) else UDim2.new(),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, slots)
end

return function(props)
	local controller = props.controller
	local rewards = props.rewards
	local count = math.max(1, #rewards)
	local size = Geometry.segmentSize(count)
	local diameter = props.diameter
	local quiet = props.reducedMotion
	-- one plan per rotation value, shared by every layer binding in this frame
	local cache = React.useRef({ rotation = nil, plan = nil })
	local plan = React.useCallback(function(rotation)
		local memo = cache.current
		if memo.rotation ~= rotation or memo.count ~= count then
			memo.rotation, memo.count, memo.plan = rotation, count, Geometry.plan(count, rotation)
		end
		return memo.plan
	end, { count })
	local colors = {}
	for index, reward in rewards do
		colors[index] = wedgeColor(reward, index, controller.winner == index - 1)
	end
	local slots = Geometry.slotsPerHalf(count)

	local overlay = {}
	local divider = math.max(1, math.floor(diameter * 0.007))
	local roomy = diameter >= 240
	for index, reward in rewards do
		local won = controller.winner == index - 1
		local centre = (index - 1) * size
		local start = centre - size / 2
		overlay["edge" .. index] = h("frame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = start, ZIndex = 1,
		}, h("frame", {
			Name = "Divider", Size = UDim2.new(0, divider, 0.5 * FACE_SCALE, 0),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Palette.ink, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		}), h("frame", {
			Name = "Peg", Size = UDim2.fromScale(0.026, 0.026), Position = UDim2.fromScale(0.5, 0.022),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BRASS, BorderSizePixel = 0, ZIndex = 3,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))
		local iconSize = math.floor(diameter * (if roomy then 0.075 else 0.085))
		overlay["prize" .. index] = h("frame", {
			Name = "Prize" .. index, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = centre, ZIndex = 2,
		}, h("frame", {
			Name = "RewardGlyph", Size = UDim2.fromOffset(iconSize, iconSize),
			Position = UDim2.fromScale(0.5, 0.15), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
		}, h(Art.Icon, {
			kind = Art.rewardIconKind(reward.Reward), color = if won then Palette.ink else Palette.cream,
			size = iconSize, reducedMotion = true, clipSafe = true,
		})), h(Ui.Text, {
			value = tostring(index),
			size = math.max(12, math.floor(diameter * 0.042)),
			color = if won then Palette.ink else Palette.cream,
			weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center, shadow = false,
			position = UDim2.fromScale(0.42, if roomy then 0.235 else 0.255),
			sizeConstraint = UDim2.fromScale(0.16, 0.06), zIndex = 4,
		}))
	end

	local hubLabel = if controller.spinning then "" elseif props.canSpin then "SPIN" else ""
	local wonIndex = if type(controller.winner) == "number" then controller.winner else -1
	local winningReward = if wonIndex >= 0 and wonIndex < #rewards then rewards[wonIndex + 1] else nil
	local winColor = if winningReward and winningReward.Color then winningReward.Color else BRASS
	return h("frame", { Name = "PrizeWheel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		winningReward and not quiet and not controller.spinning and h("frame", {
			Name = "WinnerGlow",
			Size = UDim2.fromScale(1.045, 1.045), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", {
				Color = winColor, Thickness = math.max(2, math.floor(diameter * 0.012)),
				Transparency = 0.25,
			})),
		not quiet and h("frame", {
			Size = UDim2.fromScale(1.035, 1.035), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", {
				Color = BRASS, Thickness = 2,
				Transparency = controller.spinEnergy:map(function(energy) return 1 - energy * 0.5 end),
			})),
		h("frame", {
			Name = "Rim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.ink, BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", { Color = BRASS, Thickness = math.max(2, math.floor(diameter * 0.012)), Transparency = 0.1 })),
		h("frame", {
			Name = "Face", Size = UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2,
		}, h(halfClip, { side = "right", slots = slots, plan = plan, rotation = controller.rotation, colors = colors }),
			h(halfClip, { side = "left", slots = slots, plan = plan, rotation = controller.rotation, colors = colors }),
			-- inner bevel: one quiet ring for depth, no glow
			h("frame", {
				Name = "Bevel", Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 40,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = Palette.ink, Thickness = 1, Transparency = 0.55 }))),
		h("frame", {
			Name = "Rotor", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Rotation = controller.rotation, ZIndex = 3,
		}, overlay),
		h("textbutton", {
			Name = "Hub", Size = UDim2.fromScale(0.22, 0.22), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.panelRaised, BorderSizePixel = 0,
			AutoButtonColor = false, Text = "", Active = props.canSpin and not controller.spinning, ZIndex = 6,
			Selectable = false,
			[React.Event.Activated] = function()
				if props.canSpin and not controller.spinning and controller.spin then
					controller.spin()
				end
			end,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", { Color = BRASS, Thickness = math.max(2, math.floor(diameter * 0.01)) }),
			h("uiscale", { Scale = if quiet then 1 else controller.spinEnergy:map(function(energy) return 1 - energy * 0.03 end) }),
			h("frame", {
				Size = UDim2.fromScale(0.76, 0.76), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1, ZIndex = 6,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = BRASS, Thickness = 1, Transparency = 0.45 })),
			h(Ui.Text, {
				value = hubLabel, size = math.max(12, math.floor(diameter * 0.05)), color = BRASS,
				weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1), zIndex = 7, shadow = false,
			})),
		h("frame", {
			Name = "Pointer", Size = UDim2.fromScale(0.085, 0.12), Position = UDim2.fromScale(0.5, -0.035),
			AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 8,
			Rotation = if quiet then 0 else controller.pointerKick:map(function(kick) return -kick * 16 end),
		}, h("frame", {
			-- a square with a diagonal hard mask, turned 45°: a downward triangle tip
			Name = "Tip", Size = UDim2.fromScale(0.72, 0.51), Position = UDim2.fromScale(0.5, 0.62),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.cream, BorderSizePixel = 0,
			Rotation = 45, ZIndex = 8,
		}, h("uiaspectratioconstraint", { AspectRatio = 1 }),
			h("uigradient", { Transparency = HALF_MASK, Rotation = 45 })),
			h("frame", {
				Name = "Cap", Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Palette.cream, BorderSizePixel = 0, ZIndex = 9,
			}, h("uiaspectratioconstraint", { AspectRatio = 1 }), h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = BRASS, Thickness = 2 }),
				h("frame", {
					Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = BRASS, BorderSizePixel = 0, ZIndex = 10,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))))
end
