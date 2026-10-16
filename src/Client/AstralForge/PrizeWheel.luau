--!nonstrict
-- The prize wheel, built from UI primitives only (frames, gradients, strokes; no image face).
-- useWheelController (PagesShop) owns the motion and the server result; this only draws it.
--
-- The face is painted once, unrotated, inside a CanvasGroup, and the CanvasGroup turns. Rotated
-- frames cannot clip, but a CanvasGroup renders its (unrotated, clipped) children to one texture
-- and then rotates that texture, so a spin costs a single Rotation write per frame.
--
-- Around it: a ring of bulbs that chase while it spins and blink in the prize colour when it
-- lands, a speed veil that smears the face at full speed, a fixed gloss, a hub that breathes
-- when a spin is ready, and a pointer that flicks off every peg.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local Art = require(script.Parent.ArtKit)("Icon")
local Geometry = require(script.Parent.WheelGeometry)
local motion = require(script.Parent.MotionKit)("motion")
local Palette = theme.Palette
local darken = theme.darken
local h = React.createElement

local BRASS = Color3.fromRGB(214, 176, 104)
local BRASS_DEEP = Color3.fromRGB(120, 92, 48)
local FACE_SCALE = 0.86
local BULBS = 24
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
		return base
	end
	-- neighbours of the same rarity still read as separate wedges
	return darken(base, if index % 2 == 0 then 0.34 else 0.5)
end

-- one half of the face at rest: stacked half-disks inside an unrotated clip (see WheelGeometry)
local function FaceHalf(props)
	local layers = {}
	for slot, layer in props.layers do
		layers["layer" .. slot] = h("frame", {
			Size = UDim2.new(2, -2, 1, 0),
			Position = if props.side == "right" then UDim2.new(-1, 2, 0, 0) else UDim2.new(),
			BackgroundColor3 = props.colors[layer.segment + 1],
			BorderSizePixel = 0,
			ZIndex = slot,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Transparency = HALF_MASK,
			Rotation = layer.angle,
		}))
	end
	return h("frame", {
		Name = if props.side == "right" then "RightHalf" else "LeftHalf",
		Size = UDim2.new(0.5, 1, 1, 0),
		Position = if props.side == "right" then UDim2.new(0.5, -1, 0, 0) else UDim2.new(),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, layers)
end

local function Bulbs(props)
	local controller = props.controller
	local clock = props.clock
	local flash = props.flash
	local bulbs = {}
	for index = 1, BULBS do
		local angle = (index - 1) / BULBS * 360
		local radians = math.rad(angle)
		bulbs["bulb" .. index] = h("frame", {
			Size = UDim2.fromScale(0.036, 0.036),
			Position = UDim2.fromScale(0.5 + math.sin(radians) * 0.465, 0.5 - math.cos(radians) * 0.465),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			ZIndex = 4,
			BackgroundColor3 = React.joinBindings({ clock, flash }):map(function(values)
				return if values[2] > 0.02 then props.winColor:Lerp(Palette.white, values[2] * 0.4) else BRASS:Lerp(Palette.white, 0.35)
			end),
			BackgroundTransparency = React.joinBindings({ clock, controller.rotation, controller.spinEnergy }):map(function(values)
				local t, rotation, energy = values[1], values[2], values[3]
				if props.landed and props.winColor ~= BRASS then
					-- landed: every other bulb blinks, swapping a few times a second
					return if (index + math.floor(t * 6)) % 2 == 0 then 0 else 0.75
				end
				if energy > 0.02 then
					-- spinning: a chase that runs with the wheel, a lit bulb every third place
					local lead = math.floor(rotation / (360 / BULBS))
					return if (index + lead) % 3 == 0 then 0 else 0.8 - energy * 0.2
				end
				-- resting: a slow wave round the rim
				return 0.35 + (math.sin(t * 2.2 - index * 0.55) + 1) * 0.28
			end),
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	return h("frame", { Name = "Bulbs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, bulbs)
end

return function(props)
	local controller = props.controller
	local rewards = props.rewards
	local count = math.max(1, #rewards)
	local size = Geometry.segmentSize(count)
	local diameter = props.diameter
	local quiet = props.reducedMotion
	local wonIndex = if type(controller.winner) == "number" then controller.winner else -1
	local winningReward = if wonIndex >= 0 and wonIndex < #rewards then rewards[wonIndex + 1] else nil
	local winColor = if winningReward and winningReward.Color then winningReward.Color else BRASS
	local landed = winningReward ~= nil and not controller.spinning
	local clock = motion.useClock(not quiet, 1, 3600, true)
	-- the landing thump: the whole wheel bumps and the bulbs flare
	local flash = motion.useFlash(controller.impactNonce or 0, quiet, 0.9)
	local ready = props.canSpin and not controller.spinning

	-- the face at rotation 0, painted once per prize set / winner
	local colors = {}
	for index, reward in rewards do
		colors[index] = wedgeColor(reward, index, wonIndex == index - 1)
	end
	local rest = Geometry.plan(count, 0)

	local marks = {}
	local divider = math.max(1, math.floor(diameter * 0.008))
	local roomy = diameter >= 240
	for index, reward in rewards do
		local won = wonIndex == index - 1
		local centre = (index - 1) * size
		local start = centre - size / 2
		marks["edge" .. index] = h("frame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = start, ZIndex = 20,
		}, h("frame", {
			Name = "Divider", Size = UDim2.new(0, divider, 0.5, 0),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Palette.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 20,
		}), h("frame", {
			Name = "Peg", Size = UDim2.fromScale(0.04, 0.04), Position = UDim2.fromScale(0.5, 0.025),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BRASS, BorderSizePixel = 0, ZIndex = 22,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = BRASS_DEEP, Thickness = 1 })))
		local iconSize = math.floor(diameter * FACE_SCALE * (if roomy then 0.1 else 0.11))
		marks["prize" .. index] = h("frame", {
			Name = "Prize" .. index, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = centre, ZIndex = 21,
		}, h("frame", {
			Name = "RewardGlyph", Size = UDim2.fromOffset(iconSize, iconSize),
			Position = UDim2.fromScale(0.5, 0.17), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 21,
		}, h(Art.Icon, {
			kind = Art.rewardIconKind(reward.Reward), color = if won then Palette.white else Palette.cream,
			size = iconSize, reducedMotion = true, clipSafe = true,
		})), h(Ui.Text, {
			value = tostring(index),
			size = math.max(11, math.floor(diameter * 0.038)),
			color = if won then Palette.white else Palette.creamSoft,
			weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center, shadow = false,
			position = UDim2.fromScale(0.42, if roomy then 0.27 else 0.29),
			sizeConstraint = UDim2.fromScale(0.16, 0.06), zIndex = 22,
		}))
	end

	return h("frame", { Name = "PrizeWheel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		h("uiscale", {
			Scale = if quiet then 1 else flash:map(function(v) return 1 + math.sin(math.clamp(v, 0, 1) * math.pi) * 0.035 end),
		}),
		-- glow behind the wheel: warm while it spins, the prize colour once it lands
		not quiet and h("frame", {
			Name = "Halo", Size = UDim2.fromScale(1.12, 1.12), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = if landed then winColor else Palette.mango,
			BorderSizePixel = 0, ZIndex = 0,
			BackgroundTransparency = React.joinBindings({ controller.spinEnergy, flash, clock }):map(function(values)
				local resting = if landed then 0.8 + math.sin(values[3] * 3) * 0.05 elseif ready then 0.88 + math.sin(values[3] * 2) * 0.04 else 0.95
				return math.clamp(resting - values[1] * 0.18 - values[2] * 0.35, 0.35, 1)
			end),
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.2),
				NumberSequenceKeypoint.new(0.65, 0.2), NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = clock:map(function(t) return t * 40 % 360 end),
		})),
		-- the rim: dark ring with a brass edge whose light slides round as the wheel turns
		h("frame", {
			Name = "Rim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.ink, BorderSizePixel = 0, ZIndex = 1,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", { Color = BRASS, Thickness = math.max(2, math.floor(diameter * 0.014)) },
				h("uigradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, BRASS_DEEP), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 232, 170)),
						ColorSequenceKeypoint.new(1, BRASS_DEEP),
					}),
					Rotation = if quiet then 45 else controller.rotation:map(function(r) return (r * 0.25 + 45) % 360 end),
				}))),
		not quiet and h(Bulbs, { controller = controller, clock = clock, flash = flash, landed = landed, winColor = winColor }),
		-- the face: painted once, turned as one texture
		h("canvasgroup", {
			Name = "Face", Size = UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 5,
			Rotation = controller.rotation,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h(FaceHalf, { side = "right", layers = rest.right, colors = colors }),
			h(FaceHalf, { side = "left", layers = rest.left, colors = colors }),
			h("frame", { Name = "Rotor", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, marks),
			h("frame", {
				-- inner bevel ring for depth
				Name = "Bevel", Size = UDim2.fromScale(0.56, 0.56), Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 23,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = Palette.ink, Thickness = 1, Transparency = 0.5 }))),
		-- at speed the wedges smear: a veil that thickens with spin energy
		not quiet and h("frame", {
			Name = "SpeedVeil", Size = UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.ink, BorderSizePixel = 0, ZIndex = 6,
			BackgroundTransparency = controller.spinEnergy:map(function(energy) return 1 - math.clamp(energy, 0, 1) * 0.45 end),
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.25, 0.85), NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.75, 0.85), NumberSequenceKeypoint.new(1, 0.2),
			}),
			Rotation = controller.rotation:map(function(r) return (r * 1.5) % 360 end),
		})),
		-- a fixed sheen across the top of the face, so it reads as glass over the wedges
		h("frame", {
			Name = "Gloss", Size = UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.white, BackgroundTransparency = 0.86,
			BorderSizePixel = 0, ZIndex = 7,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1),
			}),
		})),
		-- the hub: press to spin; breathes when a spin is ready, its ring turns against the wheel
		h("textbutton", {
			Name = "Hub", Size = UDim2.fromScale(0.24, 0.24), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.panelRaised, BorderSizePixel = 0,
			AutoButtonColor = false, Text = "", Active = ready, ZIndex = 10, Selectable = false,
			[React.Event.Activated] = function()
				if props.canSpin and not controller.spinning and controller.spin then
					controller.spin()
				end
			end,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uigradient", { Color = ColorSequence.new(Palette.panelRaised:Lerp(Palette.white, 0.08), Palette.panel), Rotation = 90 }),
			h("uistroke", { Color = BRASS, Thickness = math.max(2, math.floor(diameter * 0.012)) }),
			h("uiscale", {
				Scale = if quiet then 1 else React.joinBindings({ controller.spinEnergy, clock }):map(function(values)
					local breathe = if ready then math.sin(values[2] * 3.4) * 0.04 else 0
					return 1 - values[1] * 0.04 + breathe
				end),
			}),
			h("frame", {
				Size = UDim2.fromScale(0.78, 0.78), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1, ZIndex = 10,
				Rotation = if quiet then 0 else controller.rotation:map(function(r) return -r * 0.5 end),
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = BRASS, Thickness = 1.5, Transparency = 0.3 }, h("uigradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0),
					}),
				}))),
			h(Ui.Text, {
				value = if ready then "SPIN" else "", size = math.max(12, math.floor(diameter * 0.055)), color = BRASS,
				weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1), zIndex = 11, shadow = false,
			})),
		-- the pointer: flicks back off each peg and springs home
		h("frame", {
			Name = "Pointer", Size = UDim2.fromScale(0.09, 0.13), Position = UDim2.fromScale(0.5, -0.045),
			AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 12,
			Rotation = if quiet then 0 else controller.pointerKick:map(function(kick) return -kick * 16 end),
		}, h("frame", {
			-- a square with a diagonal hard mask, turned 45°: a downward triangle tip
			Name = "Tip", Size = UDim2.fromScale(0.72, 0.51), Position = UDim2.fromScale(0.5, 0.64),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.cream, BorderSizePixel = 0,
			Rotation = 45, ZIndex = 12,
		}, h("uiaspectratioconstraint", { AspectRatio = 1 }),
			h("uigradient", { Transparency = HALF_MASK, Rotation = 45 })),
			h("frame", {
				Name = "Cap", Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Palette.cream, BorderSizePixel = 0, ZIndex = 13,
			}, h("uiaspectratioconstraint", { AspectRatio = 1 }), h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", { Color = BRASS, Thickness = 2 }),
				h("frame", {
					Size = UDim2.fromScale(0.34, 0.34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
					BorderSizePixel = 0, ZIndex = 14,
					BackgroundColor3 = if landed then winColor else BRASS,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))))
end
