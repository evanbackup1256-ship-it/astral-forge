--!strict
-- Astral Forge v2: Cinematic Crate Reveal Stage
-- AAA tactile physics, physical collectible card presentation,
-- center-lock reticle framing, holographic prismatic foil shaders,
-- and omni-platform gamepad/touch certification.
-- 100% Declarative React 17 (@rbxts/react). Zero imperative UI widgets.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local itemIconKind = require(script.Parent.Parent.ArtKit)("Icon").itemIconKind
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local ScaleFromCenter = require(script.Parent.Parent.MotionKit)("motion").ScaleFromCenter
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text

local function easeOutExpo(t: number): number
	return if t == 1 then 1 else 1 - math.pow(2, -10 * t)
end

local function easeOutBack(t: number): number
	local c1, c3 = 1.70158, 1.70158 + 1
	return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

local function easeOutCubic(t: number): number
	return 1 - math.pow(1 - t, 3)
end

-- holographic foil: the full wheel at even brightness, so it reads as foil catching light rather
-- than five pastel stripes
local HOLO_GRADIENT = require(script.Parent.Parent.Rainbow).loop("soft")

local shimmerClock = React.createContext(0)

local function useShimmerClock(): any
	return React.useContext(shimmerClock)
end

local function ShimmerProvider(props: { children: any })
	local clock, setClock = React.useBinding(0)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			setClock((clock:getValue() + dt * 0.72) % 1)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})
	return React.createElement(shimmerClock.Provider, { value = clock }, props.children)
end

local function resolveLayout(props: any)
	local edge = if props.portrait then 10 else 18
	local leftEdge = edge + props.sideSafe
	local rightEdge = edge + props.sideSafe
	local usableWidth = math.max(1, props.viewportWidth - leftEdge - rightEdge)
	if props.shortLandscape then
		local columnGap = 12
		local availableRight = math.max(1, usableWidth - columnGap - 1)
		local rightWidth = math.min(availableRight, math.min(218, math.max(132, math.floor(usableWidth * 0.36))))
		local leftWidth = math.max(1, usableWidth - columnGap - rightWidth)
		local headerTop = props.topInset + 5
		local headerHeight = 52
		local stageTop = headerTop + headerHeight + 8
		local stageBottom = props.viewportHeight - props.bottomSafe - 8
		local stageHeight = math.max(1, math.min(202, stageBottom - stageTop))
		return {
			compactHeight = false,
			headerSize = UDim2.fromOffset(leftWidth, headerHeight),
			headerPosition = UDim2.fromOffset(leftEdge, headerTop),
			headerAnchor = Vector2.zero,
			stageSize = UDim2.fromOffset(leftWidth, stageHeight),
			stagePosition = UDim2.fromOffset(leftEdge, stageTop),
			stageAnchor = Vector2.zero,
			reelWidth = math.max(1, leftWidth - 24),
			reelHeight = math.max(1, stageHeight - 58),
			resultSize = UDim2.fromOffset(rightWidth, 126),
			resultPosition = UDim2.new(1, -rightEdge, 0, props.topInset + 12),
			resultAnchor = Vector2.new(1, 0),
			actionSize = UDim2.fromOffset(rightWidth, TapTarget),
			actionPosition = UDim2.new(1, -rightEdge, 1, -(props.bottomSafe + 8)),
			actionAnchor = Vector2.new(1, 1),
		}
	end
	if props.viewportHeight < 540 then
		local stageWidth = math.min(usableWidth, 390)
		local headerTop = props.topInset + 4
		local headerHeight = 44
		local actionBottom = props.bottomSafe + 8
		local actionTop = props.viewportHeight - actionBottom - TapTarget
		local stageTop = headerTop + headerHeight + 6
		local stageBottom = math.max(stageTop + 1, actionTop - 8)
		local stageHeight = stageBottom - stageTop
		local resultHeight = math.max(1, math.min(100, stageHeight - 12))
		return {
			compactHeight = true,
			headerSize = UDim2.fromOffset(stageWidth, headerHeight),
			headerPosition = UDim2.new(0.5, 0, 0, headerTop),
			headerAnchor = Vector2.new(0.5, 0),
			stageSize = UDim2.fromOffset(stageWidth, stageHeight),
			stagePosition = UDim2.new(0.5, 0, 0, stageTop),
			stageAnchor = Vector2.new(0.5, 0),
			reelWidth = math.max(1, stageWidth - 24),
			reelHeight = math.max(1, stageHeight - 58),
			resultSize = UDim2.fromOffset(math.max(1, stageWidth - 24), resultHeight),
			resultPosition = UDim2.fromOffset(math.floor(props.viewportWidth / 2), math.floor(stageTop + stageHeight / 2)),
			resultAnchor = Vector2.new(0.5, 0.5),
			actionSize = UDim2.fromOffset(stageWidth, TapTarget),
			actionPosition = UDim2.new(0.5, 0, 1, -actionBottom),
			actionAnchor = Vector2.new(0.5, 1),
		}
	end
	local stageWidth = math.min(usableWidth, if props.portrait then 390 else 850)
	local stageHeight = if props.portrait then math.clamp(math.floor(props.viewportHeight * 0.37), 204, 232) else math.clamp(math.floor(props.viewportHeight * 0.38), 232, 286)
	local headerHeight = if props.portrait then 74 else 82
	local resultHeight = if props.portrait then 88 else 94
	local resultWidth = math.min(if props.portrait then stageWidth else 470, usableWidth)
	local actionWidth = math.min(if props.portrait then stageWidth else 260, usableWidth)
	local actionBottom = props.bottomSafe + 10
	local resultBottom = actionBottom + TapTarget + 10
	local freeTop = props.topInset + headerHeight + 16
	local freeBottom = props.viewportHeight - resultBottom - resultHeight - 10
	local stageCenter = math.floor((freeTop + freeBottom) * 0.5)
	return {
		compactHeight = false,
		headerSize = UDim2.fromOffset(math.min(stageWidth, 620), headerHeight),
		headerPosition = UDim2.new(0.5, 0, 0, props.topInset + 8),
		headerAnchor = Vector2.new(0.5, 0),
		stageSize = UDim2.fromOffset(stageWidth, stageHeight),
		stagePosition = UDim2.fromOffset(math.floor(props.viewportWidth / 2), stageCenter),
		stageAnchor = Vector2.new(0.5, 0.5),
		reelWidth = math.max(1, stageWidth - 24),
		reelHeight = stageHeight - 58,
		resultSize = UDim2.fromOffset(resultWidth, resultHeight),
		resultPosition = UDim2.new(0.5, 0, 1, -resultBottom),
		resultAnchor = Vector2.new(0.5, 1),
		actionSize = UDim2.fromOffset(actionWidth, TapTarget),
		actionPosition = UDim2.new(0.5, 0, 1, -actionBottom),
		actionAnchor = Vector2.new(0.5, 1),
	}
end

-- Cinematic atmospheric stage lighting (replaces cluttered grid lines)
local function CinematicBackdrop(props: any)
	local layout = props.layout
	local p = props.props
	local landed = p.phase == "land" or p.phase == "done" or p.phase == "exit"
	local center = UDim2.new(
		layout.stagePosition.X.Scale, layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
	)

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		Active = false,
	},
		-- Soft central ambient spotlight
		React.createElement("frame", {
			Size = UDim2.fromOffset(layout.stageSize.X.Offset + 120, layout.stageSize.Y.Offset + 100),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if landed then p.winnerAccent else p.sessionAccent,
			BackgroundTransparency = p.spinEnergy:map(function(e)
				local base = if landed then 0.88 else 0.94
				return math.clamp(base - e * 0.08, 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 405,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 32) }),
			React.createElement("uigradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.65, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
			})
		),
		-- Stage horizontal grounding aura
		React.createElement("frame", {
			Size = UDim2.new(0.85, 0, 0, 1),
			Position = UDim2.new(0.5, 0, layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + layout.stageSize.Y.Offset / 2 + 18),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if landed then p.winnerAccent else p.sessionAccent,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			ZIndex = 406,
		}, React.createElement("uigradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}))
	)
end

-- Clean, human-designed cinematic header (no buzzword salad)
local function CinematicHeader(props: any)
	local layout = props.layout
	local p = props.props
	local landed = p.phase == "land" or p.phase == "done" or p.phase == "exit"
	local narrowShort = p.shortLandscape and layout.headerSize.X.Offset < 260
	local simplifiedHeader = narrowShort or layout.compactHeight

	local statusText = if p.phase == "charge" or p.phase == "seal" then "SEAL UNLOCKED"
		elseif p.phase == "spin" then "SELECTING RELIC..."
		elseif p.phase == "climb" then "RESONANCE SURGE"
		elseif landed then `{string.upper(p.winnerRarity)} RELIC`
		else "RELIC VAULT"

	local statusColor = if landed then p.winnerAccent
		elseif p.phase == "climb" then (p.climbColor or Palette.violet)
		elseif p.phase == "spin" then Palette.cyan
		else Palette.muted

	return React.createElement("frame", {
		Size = layout.headerSize,
		Position = layout.headerPosition,
		AnchorPoint = layout.headerAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 420,
	},
		not simplifiedHeader and React.createElement(Text, {
			value = "RELIC FORGE",
			size = 10,
			color = p.sessionAccent,
			weight = Enum.FontWeight.Heavy,
			align = if p.shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, if p.shortLandscape then -128 else 0, 0, 14),
			zIndex = 421,
		}),
		React.createElement(Text, {
			value = p.crateName,
			size = if p.shortLandscape then 20 elseif p.portrait then 22 else 26,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			align = if p.shortLandscape and not simplifiedHeader then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			fit = true,
			minSize = 12,
			position = UDim2.fromOffset(0, if simplifiedHeader then 0 elseif p.shortLandscape then 14 else 15),
			sizeConstraint = UDim2.new(1, if p.shortLandscape and not simplifiedHeader then -128 else 0, 0, if p.shortLandscape then 26 else 32),
			zIndex = 421,
		}),
		-- Clean status pill & drop count
		React.createElement("frame", {
			Size = if simplifiedHeader then UDim2.new(1, 0, 0, 16) elseif p.shortLandscape then UDim2.fromOffset(136, 32) else UDim2.new(1, 0, 0, 16),
			Position = if simplifiedHeader then UDim2.fromOffset(0, 26) elseif p.shortLandscape then UDim2.new(1, -136, 0, 6) else UDim2.fromOffset(0, 50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 421,
		},
			React.createElement(Text, {
				value = if p.rollCount > 1 then `{statusText}  •  DROP {p.rollIndex + 1}/{p.rollCount}` else statusText,
				size = 10,
				color = statusColor,
				weight = Enum.FontWeight.Bold,
				align = if p.shortLandscape and not simplifiedHeader then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
				fit = true,
				minSize = 8,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 421,
			})
		),
		-- Batch progress bar if multiple rolls
		p.rollCount > 1 and not p.shortLandscape and not layout.compactHeight and React.createElement("frame", {
			Size = UDim2.fromOffset(math.min(180, p.rollCount * 28), 3),
			Position = UDim2.new(0.5, 0, 1, -1),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Palette.line,
			BorderSizePixel = 0,
			ZIndex = 421,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
			React.createElement("frame", {
				Size = UDim2.new(math.clamp((p.rollIndex + 1) / math.max(1, p.rollCount), 0, 1), 0, 1, 0),
				BackgroundColor3 = if landed then p.winnerAccent else p.sessionAccent,
				BorderSizePixel = 0,
				ZIndex = 422,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		)
	)
end

-- Physical collectible holographic card
local function ReelCard(_param: any)
	local card = _param.card
	local x = _param.x
	local width = _param.width
	local height = _param.height
	local emphasize = _param.emphasize
	local detailed = _param.detailed
	local fitScale = _param.fitScale
	local reducedMotion = _param.reducedMotion
	local winnerScale = _param.winnerScale
	local shimmerPhase = _param.shimmerPhase

	local clock = useShimmerClock()
	local scale = if emphasize then winnerScale:map(function(amount)
		return amount * fitScale
	end) else 0.94 * fitScale
	local cardZ = if emphasize then 438 else 431

	local shimmerX = React.joinBindings({ clock }):map(function(vals)
		local t = (vals[1] + shimmerPhase) % 1
		local sweep = if t < 0.22 then easeOutExpo(t / 0.22) else if t < 0.35 then 1 - (t - 0.22) / 0.13 else -0.15
		return UDim2.new(sweep, -28, 0, 0)
	end)

	local isHolo = card.rarity == "Mythic" or card.rarity == "Celestial" or card.rarity == "Astral" or (emphasize and card.rarity == "Legendary")

	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(x, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = cardZ,
	},
		-- Radiant outer aura for landed winning card
		emphasize and not reducedMotion and React.createElement("frame", {
			Size = UDim2.new(1, 24, 1, 24),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = cardZ - 1,
		}, React.createElement("uistroke", {
			Color = lighten(card.accent, 0.28),
			Thickness = 3,
			Transparency = winnerScale:map(function(amt)
				return math.clamp(1 - amt * 0.75, 0.05, 1)
			end),
		}), React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) })),

		-- Scaled Card Body
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = cardZ,
		}, React.createElement("uiscale", { Scale = scale }),
			-- Card drop shadow
			React.createElement("frame", {
				Size = UDim2.new(1, -6, 1, -8),
				Position = UDim2.fromOffset(3, 5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.42,
				BorderSizePixel = 0,
				ZIndex = cardZ,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) })),

			-- Card Face Chassis
			React.createElement("frame", {
				Size = UDim2.new(1, -4, 1, -4),
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				ZIndex = cardZ + 1,
				ClipsDescendants = true,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) }),
				-- Sleek metallic stroke colored by rarity
				React.createElement("uistroke", {
					Color = if emphasize then lighten(card.accent, 0.3) else card.accent,
					Thickness = if emphasize then 2.2 else 1,
					Transparency = if emphasize then 0.04 else 0.42,
				}),
				React.createElement("uigradient", {
					Color = ColorSequence.new(lighten(Palette.panelRaised, 0.06), darken(Palette.panelRaised, 0.16)),
					Rotation = 90,
				}),
				-- Top rarity gem pip socket
				React.createElement("frame", {
					Size = UDim2.fromOffset(8, 8),
					Position = UDim2.new(0.5, 0, 0, 8),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = card.accent,
					BorderSizePixel = 0,
					ZIndex = cardZ + 3,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),

				-- Prismatic Holographic Foil Overlay (Mythic / Celestial / Astral)
				isHolo and not reducedMotion and React.createElement("frame", {
					Size = UDim2.new(1.8, 0, 1.8, 0),
					Position = React.joinBindings({ clock }):map(function(vals)
						local t = (vals[1] * 0.72 + shimmerPhase) % 1
						local offset = -0.4 + t * 1.4
						return UDim2.new(offset, 0, offset * 0.45, 0)
					end),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Rotation = 32,
					ZIndex = cardZ + 4,
				}, React.createElement("uigradient", {
					Color = HOLO_GRADIENT,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.35, if emphasize then 0.62 else 0.82),
						NumberSequenceKeypoint.new(0.5, if emphasize then 0.38 else 0.72),
						NumberSequenceKeypoint.new(0.65, if emphasize then 0.62 else 0.82),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})),

				-- Specular light sweep across card
				not reducedMotion and React.createElement("frame", {
					Size = UDim2.fromOffset(32, height),
					Position = shimmerX,
					AnchorPoint = Vector2.new(0, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Rotation = 14,
					ZIndex = cardZ + 5,
				}, React.createElement("uigradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Palette.cream),
						ColorSequenceKeypoint.new(0.5, Palette.cream),
						ColorSequenceKeypoint.new(1, Palette.cream),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.35, if emphasize then 0.34 else 0.7),
						NumberSequenceKeypoint.new(0.5, if emphasize then 0.18 else 0.54),
						NumberSequenceKeypoint.new(0.65, if emphasize then 0.34 else 0.7),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})),

				-- Card Glyph & Typography
				if detailed then React.createElement(React.Fragment, nil,
					React.createElement(IconTile, {
						kind = itemIconKind(card.definitionId),
						accent = card.accent,
						size = 50,
						radius = 12,
						position = UDim2.new(0.5, 0, 0, 22),
						anchorPoint = Vector2.new(0.5, 0),
						reducedMotion = reducedMotion,
						glow = emphasize,
						filled = true,
						zIndex = cardZ + 3,
					}),
					React.createElement(Badge, {
						value = string.upper(card.rarity),
						accent = card.accent,
						filled = true,
						position = UDim2.new(0.5, -46, 0, 78),
						size = UDim2.fromOffset(92, 18),
						zIndex = cardZ + 4,
					}),
					React.createElement(Text, {
						value = card.name,
						size = 11,
						color = Palette.cream,
						weight = Enum.FontWeight.Heavy,
						align = Enum.TextXAlignment.Center,
						fit = true,
						minSize = 9,
						position = UDim2.fromOffset(6, 100),
						sizeConstraint = UDim2.new(1, -12, 0, 22),
						zIndex = cardZ + 3,
					})
				) else nil
			)
		)
	)
end

-- Horizontal Reel Showcase Window with Center Lock Reticle
local function ForgeReel(_param: any)
	local props = _param.props
	local layout = _param.layout
	local landed = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	local cardFitScale = math.clamp(layout.reelHeight / 148, 0.75, 1)

	local selectorScale = props.tickEnergy:map(function(amount)
		return 1 + amount * 0.035
	end)

	local progressWidth = props.spinProgress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
	end)

	local reticleAccent = if landed then props.winnerAccent else props.sessionAccent

	local cardElements = {}
	for i, card in props.cards do
		local besideWinner = (props.cards[i] and props.cards[i].winner == true) or (props.cards[i + 2] and props.cards[i + 2].winner == true)
		local detailed = not props.economyMode or i <= 4 or card.winner or besideWinner
		cardElements[i] = React.createElement(ReelCard, {
			key = card.key,
			card = card,
			x = i * props.stride,
			width = props.cardWidth,
			height = props.cardHeight,
			emphasize = card.winner and landed,
			detailed = detailed,
			fitScale = cardFitScale,
			reducedMotion = props.reducedMotion,
			winnerScale = props.winnerCardScale,
			shimmerPhase = (i * 0.13) % 1,
		})
	end

	return React.createElement("frame", {
		Size = layout.stageSize,
		Position = layout.stagePosition,
		AnchorPoint = layout.stageAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 425,
		ClipsDescendants = false,
	},
		-- Showcase chassis shadow
		React.createElement("frame", {
			Size = UDim2.new(1, 4, 1, 6),
			Position = UDim2.fromOffset(-2, 5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 424,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 16) })),

		-- Showcase chassis body
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ZIndex = 425,
			ClipsDescendants = false,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 16) }),
			React.createElement("uistroke", {
				Color = if landed then props.winnerAccent else props.sessionAccent,
				Thickness = if landed then 2 else 1.25,
				Transparency = if landed then 0.08 else 0.35,
			}),
			React.createElement("uigradient", {
				Color = ColorSequence.new(lighten(Palette.panel, 0.035), darken(Palette.panel, 0.14)),
				Rotation = 90,
			}),

			-- Reel viewing aperture (clips cards horizontally)
			React.createElement("frame", {
				Size = UDim2.fromOffset(layout.reelWidth, layout.reelHeight),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.void,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ZIndex = 427,
				ClipsDescendants = true,
				Visible = not layout.compactHeight or not landed,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement("uistroke", {
					Color = Palette.line,
					Thickness = 1,
					Transparency = 0.45,
				}),

				-- Moving cards track
				React.createElement(ShimmerProvider, {},
					React.createElement("frame", {
						Size = UDim2.fromOffset(#props.cards * props.stride, props.cardHeight),
						Position = props.reelOffset:map(function(offset)
							return UDim2.fromOffset(layout.reelWidth / 2 - props.cardWidth / 2 - offset, math.floor((layout.reelHeight - props.cardHeight) / 2))
						end),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = 429,
					}, table.unpack(cardElements))
				),

				-- Left edge depth vignette
				React.createElement("frame", {
					Size = UDim2.new(0, math.min(64, layout.reelWidth * 0.18), 1, 0),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ZIndex = 438,
				}, React.createElement("uigradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})),

				-- Right edge depth vignette
				React.createElement("frame", {
					Size = UDim2.new(0, math.min(64, layout.reelWidth * 0.18), 1, 0),
					Position = UDim2.fromScale(1, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ZIndex = 438,
				}, React.createElement("uigradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0),
					}),
				})),

				-- Center target reticle bracket
				React.createElement("frame", {
					Size = UDim2.fromOffset(props.cardWidth + 10, props.cardHeight + 6),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = reticleAccent,
					BackgroundTransparency = if landed then 0.92 else 0.96,
					BorderSizePixel = 0,
					ZIndex = 439,
				}, React.createElement("uiscale", {
					Scale = selectorScale:map(function(amount)
						return amount * cardFitScale
					end),
				}), React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) }),
					React.createElement("uistroke", {
						Color = reticleAccent,
						Thickness = if landed then 2.5 else 1.5,
						Transparency = if landed then 0.05 else 0.22,
					})
				),

				-- Center hairline alignment guide
				React.createElement("frame", {
					Size = UDim2.new(0, 1, 1, -8),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Palette.cream,
					BackgroundTransparency = props.tickEnergy:map(function(amount)
						return math.clamp(0.68 - amount * 0.42, 0.1, 1)
					end),
					BorderSizePixel = 0,
					ZIndex = 440,
				})
			),

			-- Top center reticle arrow notch
			React.createElement("frame", {
				Size = UDim2.fromOffset(18, 9),
				Position = UDim2.new(0.5, 0, 0, 6),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = reticleAccent,
				BorderSizePixel = 0,
				ZIndex = 446,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) })),

			-- Bottom center reticle arrow notch
			React.createElement("frame", {
				Size = UDim2.fromOffset(18, 9),
				Position = UDim2.new(0.5, 0, 1, -6),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = reticleAccent,
				BorderSizePixel = 0,
				ZIndex = 446,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) })),

			-- Bottom subtle spin progress line
			React.createElement("frame", {
				Size = UDim2.new(1, -24, 0, 2),
				Position = UDim2.new(0.5, 0, 1, -2),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Palette.line,
				BorderSizePixel = 0,
				ZIndex = 447,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
				React.createElement("frame", {
					Size = progressWidth,
					BackgroundColor3 = reticleAccent,
					BorderSizePixel = 0,
					ZIndex = 448,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
			)
		)
	)
end

-- Cinematic Landing Impact Visuals (lens flare, shockwave ring, radiant embers)
local function LandingBurst(_param: any)
	local props = _param.props
	local layout = _param.layout
	if props.phase ~= "land" and props.phase ~= "climb" then return nil end

	local count = math.clamp(math.floor(6 + props.fxBudget * 8), 6, 14)
	local center = UDim2.new(
		layout.stagePosition.X.Scale, layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
	)

	local sparks = {}
	if not props.reducedMotion and props.allowAmbient then
		for index = 0, count - 1 do
			local angle = (index / count) * math.pi * 2 - math.pi / 2
			local distance = 72 + (index % 4) * 26
			local travel = props.landFlash:map(function(amount)
				return 1 - amount
			end)
			sparks[index + 1] = React.createElement("frame", {
				key = `crate-ember-{index}`,
				Size = UDim2.fromOffset(if index % 2 == 0 then 6 else 4, if index % 2 == 0 then 6 else 4),
				Position = travel:map(function(amount)
					return UDim2.new(
						center.X.Scale, center.X.Offset + math.cos(angle) * distance * amount,
						center.Y.Scale, center.Y.Offset + math.sin(angle) * distance * amount
					)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = index * 45,
				BackgroundColor3 = if index % 3 == 0 then Palette.cream else props.winnerAccent,
				BackgroundTransparency = travel:map(function(amount)
					return math.clamp(amount * 1.3, 0, 1)
				end),
				BorderSizePixel = 0,
				ZIndex = 448,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- Expanding circular shockwave ring
	local shockRing = not props.reducedMotion and React.createElement("frame", {
		Size = props.landFlash:map(function(f)
			local s = easeOutExpo(f) * 180
			return UDim2.fromOffset(s, s)
		end),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 449,
	}, React.createElement("uistroke", {
		Color = props.winnerAccent,
		Thickness = 2.4,
		Transparency = props.landFlash:map(function(f)
			return math.clamp(0.05 + (1 - f) * 0.9, 0, 1)
		end),
	}), React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))

	-- Central optical flare bloom
	local opticalFlare = React.createElement("frame", {
		Size = props.landFlash:map(function(amount)
			return UDim2.fromOffset(160 + amount * 440, 3 + amount * 3)
		end),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = props.landFlash:map(function(amount)
			return math.clamp(1 - amount * 0.85, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 448,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(props.winnerAccent, Palette.cream),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.44, 0.05),
			NumberSequenceKeypoint.new(0.56, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}))

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 448,
		Active = false,
	},
		table.unpack(sparks),
		shockRing,
		opticalFlare
	)
end

-- Clean Result Display Card (bold presentation, clear discovery badges)
local function ResultPanel(_param: any)
	local props = _param.props
	local layout = _param.layout
	local visible = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	local accentLineWidth, setAccentLineWidth = React.useBinding(0)

	React.useEffect(function()
		if not visible then
			return nil
		end
		local start = os.clock()
		local dur = 0.52
		local conn = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / dur, 0, 1)
			setAccentLineWidth(easeOutBack(t))
		end)
		return function()
			conn:Disconnect()
		end
	end, { props.winnerName, visible })

	if not visible then return nil end

	local isHolo = props.winnerRarity == "Mythic" or props.winnerRarity == "Celestial" or props.winnerRarity == "Astral"

	return React.createElement("frame", {
		Size = layout.resultSize,
		Position = props.landPop:map(function(amount)
			return UDim2.new(
				layout.resultPosition.X.Scale, layout.resultPosition.X.Offset,
				layout.resultPosition.Y.Scale, layout.resultPosition.Y.Offset + math.round((1 - amount) * 16)
			)
		end),
		AnchorPoint = layout.resultAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 450,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = props.winnerAccent,
		background = Palette.panelRaised,
		padding = if props.shortLandscape then 10 else 12,
		highlight = true,
		reducedMotion = props.reducedMotion,
		clips = false,
		zIndex = 450,
	},
		-- Prismatic top edge bar for Mythic/Celestial/Astral
		isHolo and not props.reducedMotion and React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 455,
		}, React.createElement("uigradient", {
			Color = HOLO_GRADIENT,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.5, 0.05),
				NumberSequenceKeypoint.new(1, 0.7),
			}),
		}), React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),

		-- Rarity header
		React.createElement(Text, {
			value = `{string.upper(props.winnerRarity)}  •  ROLL {props.rollIndex + 1}/{props.rollCount}`,
			size = 10,
			color = props.winnerAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 7,
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 14),
			zIndex = 452,
		}),
		-- Relic title
		React.createElement(Text, {
			value = props.winnerName,
			size = if props.shortLandscape then 17 else 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 10,
			position = UDim2.fromOffset(0, 18),
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 26),
			zIndex = 452,
		}),
		-- Accent separator bar
		React.createElement("frame", {
			Size = accentLineWidth:map(function(t)
				return UDim2.new(t * (if props.shortLandscape then 0.55 else 0.45), 0, 0, 2)
			end),
			Position = UDim2.fromOffset(0, 44),
			BackgroundColor3 = props.winnerAccent,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 453,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
		-- Relic detail / description
		React.createElement(Text, {
			value = props.resultDetail,
			size = 10,
			color = Palette.creamSoft,
			fit = true,
			minSize = 8,
			wrap = true,
			position = UDim2.fromOffset(0, 48),
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, if props.shortLandscape then 32 else 24),
			zIndex = 452,
		}),
		-- Discovery badge (NEW FIND / ESSENCE / OWNED)
		React.createElement(Badge, {
			value = props.resultTag,
			accent = if props.resultTag == "NEW FIND" then Palette.mint else props.winnerAccent,
			filled = true,
			position = if props.shortLandscape then UDim2.new(0, 0, 1, -27) else UDim2.new(1, -106, 0.5, -14),
			size = if props.shortLandscape then UDim2.new(1, 0, 0, 22) else UDim2.fromOffset(106, 28),
			zIndex = 453,
		})
	))
end

-- Root CrateRevealStage orchestrator
local function CrateRevealStage(props: any)
	local layout = resolveLayout(props)
	local antilag = useAntilag()
	local softMotion = props.reducedMotion == true
	local reducedMotion = softMotion
	local allowAmbient = not reducedMotion and props.allowAmbient ~= false and antilag.allowAmbient
	local actionHostRef = React.useRef(nil)

	-- Omni-Platform Gamepad Overlay Focus Stack
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})

	-- Gamepad focus selection when actionable
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = actionHostRef.current
		if host == nil then
			return nil
		end
		if props.phase ~= "spin" and props.phase ~= "done" then
			GamepadNavigationService.ClearSelection()
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { props.phase })

	local dimmer = props.visualShow:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.985
	end)
	local accentWash = props.visualShow:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.08
	end)
	local showingClaim = props.phase == "done" or props.phase == "exit"

	local stageProps = table.clone(props)
	stageProps.reducedMotion = reducedMotion
	stageProps.allowAmbient = allowAmbient

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 400,
	},
		-- Full-screen click-to-skip or click-to-claim backdrop
		React.createElement("imagebutton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.void,
			BackgroundTransparency = dimmer,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Selectable = false,
			Active = props.phase == "spin" or props.phase == "done",
			ZIndex = 401,
			Event = {
				Activated = function()
					if props.phase == "spin" then
						Audio:play("crateBrake")
						props.onQuickLand()
					elseif props.phase == "done" then
						Audio:play("crateClaim")
						props.onClaim()
					end
				end,
			},
		}),
		-- Atmospheric ambient stage wash
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = darken(props.sessionAccent, 0.6),
			BackgroundTransparency = accentWash,
			BorderSizePixel = 0,
			ZIndex = 402,
		}, React.createElement("uigradient", {
			Color = ColorSequence.new(darken(props.sessionAccent, 0.78), Palette.void),
			Rotation = 90,
		})),
		-- Scaled Stage Content
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 404,
			ClipsDescendants = true,
			Visible = props.visualShow:map(function(amount)
				return amount > 0.015
			end),
		}, React.createElement(ScaleFromCenter, {
			scale = props.shellScale,
			zIndex = 404,
		},
			React.createElement(CinematicBackdrop, { props = stageProps, layout = layout }),
			React.createElement(CinematicHeader, { props = stageProps, layout = layout }),
			React.createElement(ForgeReel, { props = stageProps, layout = layout }),
			React.createElement(LandingBurst, { props = stageProps, layout = layout }),
			React.createElement(ResultPanel, { props = stageProps, layout = layout }),

			-- Skip / Fast-Forward Button during spin
			props.phase == "spin" and React.createElement("frame", {
				ref = actionHostRef,
				Name = "CrateSkip",
				Size = layout.actionSize,
				Position = layout.actionPosition,
				AnchorPoint = layout.actionAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 455,
			}, React.createElement(Button, {
				text = "SKIP TO RESULT",
				icon = "Chevron.1",
				onClick = props.onQuickLand,
				color = Palette.panelSoft,
				textColor = Palette.creamSoft,
				outline = true,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				selectable = true,
			})),

			-- Claim Drop Button when finished
			showingClaim and React.createElement("frame", {
				ref = actionHostRef,
				Name = "CrateClaim",
				Size = layout.actionSize,
				Position = props.claimSlide:map(function(amount)
					return UDim2.new(
						layout.actionPosition.X.Scale, layout.actionPosition.X.Offset,
						layout.actionPosition.Y.Scale, layout.actionPosition.Y.Offset + math.round((1 - amount) * 24)
					)
				end),
				AnchorPoint = layout.actionAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ZIndex = 456,
			}, React.createElement(Button, {
				text = props.claimText,
				icon = "Gift.1",
				onClick = props.onClaim,
				color = props.sessionAccent,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				highlight = true,
				selectable = true,
				disabled = props.phase == "exit",
			}))
		))
	)
end

return {
	CrateRevealStage = CrateRevealStage,
	resolveLayout = resolveLayout,
	ShimmerProvider = ShimmerProvider,
}
