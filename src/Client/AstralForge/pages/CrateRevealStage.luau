local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local itemIconKind = require(script.Parent.Parent.Icon).itemIconKind
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local ScaleFromCenter = require(script.Parent.Parent.motion).ScaleFromCenter
local _theme = require(script.Parent.Parent.theme)
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text

local RunService = game:GetService("RunService")

-- ─── easing helpers ────────────────────────────────────────────────────────────
local function easeOutExpo(t)
	return t == 1 and 1 or 1 - math.pow(2, -10 * t)
end
local function easeOutElastic(t)
	if t == 0 or t == 1 then return t end
	return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
local function easeOutBack(t)
	local c1, c3 = 1.70158, 1.70158 + 1
	return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

-- shimmer clock shared across cards (increments each frame, wraps at 1)
local shimmerClock = React.createContext(0)

local function useShimmerClock()
	return React.useContext(shimmerClock)
end

-- ShimmerProvider: one RunService loop feeds all card shimmer animations
local function ShimmerProvider(props)
	local clock, setClock = React.useBinding(0)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			setClock((clock:getValue() + dt * 0.72) % 1)
		end)
		return function() conn:Disconnect() end
	end, {})
	return React.createElement(shimmerClock.Provider, { value = clock }, props.children)
end

-- ─── Layout resolver (unchanged logic, same API) ────────────────────────────────
local function resolveLayout(props)
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

-- ─── ForgeBackdrop ─────────────────────────────────────────────────────────────
local function ForgeBackdrop(_param)
	local props = _param.props
	local layout = _param.layout
	local contained = props.shortLandscape or layout.compactHeight or props.viewportHeight < 600
	local burstBase = if contained then 110 else 180
	local burstTravel = if contained then math.min(160, layout.reelWidth * 0.42) else 420
	local center = UDim2.new(
		layout.stagePosition.X.Scale, layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
	)

	-- rotating energy ring (spins during "spin" phase, holds at land)
	local ringRotation, setRingRotation = React.useBinding(0)
	local ringConn = React.useRef(nil)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			local speed = if props.phase == "spin" then 38 else 12
			setRingRotation((ringRotation:getValue() + dt * speed) % 360)
		end)
		ringConn.current = conn
		return function() conn:Disconnect() end
	end, { props.phase })

	local gridLines = {}
	if props.allowAmbient then
		-- horizontal grid lines
		for index = 0, 4 do
			gridLines[`h{index}`] = React.createElement("frame", {
				key = `forge-grid-h-{index}`,
				Size = UDim2.new(0.68, 0, 0, 1),
				Position = UDim2.new(0.5, 0, 0.28 + index * 0.1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.sessionAccent,
				BackgroundTransparency = 0.94,
				BorderSizePixel = 0,
			})
		end
		-- vertical grid lines
		for index = 0, 6 do
			gridLines[`v{index}`] = React.createElement("frame", {
				key = `forge-grid-v-{index}`,
				Size = UDim2.new(0, 1, 0.54, 0),
				Position = UDim2.new(0.26 + index * 0.08, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.sessionAccent,
				BackgroundTransparency = 0.96,
				BorderSizePixel = 0,
			})
		end
	end

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		Active = false,
	},
		-- top divider line
		React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0.18),
			BackgroundColor3 = Palette.line,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
		}),
		-- bottom divider line
		React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0.82),
			BackgroundColor3 = Palette.line,
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
		}),
		-- ambient grid
		props.allowAmbient and React.createElement(React.Fragment, nil, table.unpack(
			(function()
				local items = {}
				for _, v in gridLines do table.insert(items, v) end
				return items
			end)()
		)),
		-- rotating accent energy ring
		props.allowAmbient and React.createElement("frame", {
			Size = props.landFlash:map(function(f)
				local base = if contained then 72 else 130
				return UDim2.fromOffset(base + f * 60, base + f * 60)
			end),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 406,
			Rotation = ringRotation,
		}, React.createElement("uistroke", {
			Color = props.sessionAccent,
			Thickness = 1.5,
			Transparency = props.spinEnergy:map(function(e)
				return 1 - e * 0.55 * props.glowScale
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 6),
		})),
		-- burst diamond
		React.createElement("frame", {
			Size = props.landFlash:map(function(amount)
				return UDim2.fromOffset(burstBase + amount * burstTravel, burstBase + amount * burstTravel)
			end),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.sessionAccent,
			BackgroundTransparency = props.landFlash:map(function(amount)
				return 1 - amount * (if contained then 0.045 else 0.08)
			end),
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = 406,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = lighten(props.sessionAccent, 0.32),
			Thickness = 2,
			Transparency = props.landFlash:map(function(amount)
				return 1 - amount * (if contained then 0.32 else 0.46)
			end),
		})),
		-- spin speed bar
		React.createElement("frame", {
			Size = UDim2.new(if contained then 0.58 else 0.82, 0, 0, 2),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cream,
			BackgroundTransparency = props.spinEnergy:map(function(amount)
				return 1 - amount * 0.12
			end),
			BorderSizePixel = 0,
			ZIndex = 406,
		})
	)
end

-- ─── RevealHeader ──────────────────────────────────────────────────────────────
local function RevealHeader(_param)
	local props = _param.props
	local layout = _param.layout
	local status = if props.phase == "charge" then "GET READY"
		elseif props.phase == "spin" then "ROLLING"
		elseif props.phase == "land" then "YOU GOT"
		elseif props.phase == "done" or props.phase == "exit" then "READY"
		else "OPENING"

	-- animated status dot
	local dotPulse, setDotPulse = React.useBinding(0)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			setDotPulse((dotPulse:getValue() + dt * 2.8) % 1)
		end)
		return function() conn:Disconnect() end
	end, {})

	local dotColor = if props.phase == "spin" then Palette.cyan
		elseif props.phase == "land" then props.winnerAccent or Palette.mint
		elseif props.phase == "done" then Palette.mint
		else Palette.muted

	local narrowShort = props.shortLandscape and layout.headerSize.X.Offset < 260
	local simplifiedHeader = narrowShort or layout.compactHeight

	return React.createElement("frame", {
		Size = layout.headerSize,
		Position = layout.headerPosition,
		AnchorPoint = layout.headerAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 420,
	},
		-- category label
		not simplifiedHeader and React.createElement(Text, {
			value = "RELIC CRATE",
			size = 9,
			color = props.sessionAccent,
			weight = Enum.FontWeight.Heavy,
			align = if props.shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, if props.shortLandscape then -128 else 0, 0, 14),
			zIndex = 421,
		}),
		-- crate name
		React.createElement(Text, {
			value = props.crateName,
			size = if props.shortLandscape then 21 elseif props.portrait then 23 else 27,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			align = if props.shortLandscape and not simplifiedHeader then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			fit = true,
			minSize = 12,
			position = UDim2.fromOffset(0, if simplifiedHeader then 0 elseif props.shortLandscape then 15 else 16),
			sizeConstraint = UDim2.new(1, if props.shortLandscape and not simplifiedHeader then -128 else 0, 0, if props.shortLandscape then 28 else 34),
			zIndex = 421,
		}),
		-- status line with animated dot
		React.createElement("frame", {
			Size = if simplifiedHeader then UDim2.new(1, 0, 0, 15) elseif props.shortLandscape then UDim2.fromOffset(128, 36) else UDim2.new(1, 0, 0, 14),
			Position = if simplifiedHeader then UDim2.fromOffset(0, 27) elseif props.shortLandscape then UDim2.new(1, -128, 0, 6) else UDim2.fromOffset(0, 53),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 421,
		},
			-- animated dot
			React.createElement("frame", {
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.new(if props.shortLandscape and not simplifiedHeader then 0 else 0.5, -48, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = dotColor,
				BackgroundTransparency = dotPulse:map(function(t)
					return 0.1 + math.sin(t * math.pi * 2) * 0.35
				end),
				BorderSizePixel = 0,
				ZIndex = 422,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
			React.createElement(Text, {
				value = `{status}  •  {props.rollIndex + 1}/{props.rollCount}`,
				size = 9,
				color = Palette.muted,
				weight = Enum.FontWeight.Bold,
				align = if props.shortLandscape and not simplifiedHeader then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
				fit = true,
				minSize = 8,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 421,
			})
		),
		-- progress bar (non-compact, non-landscape)
		not props.shortLandscape and not layout.compactHeight and React.createElement("frame", {
			Size = UDim2.fromOffset(math.min(190, props.rollCount * 22), 4),
			Position = UDim2.new(0.5, 0, 1, -2),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Palette.line,
			BorderSizePixel = 0,
			ZIndex = 421,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
			React.createElement("frame", {
				Size = UDim2.new(math.clamp((props.rollIndex + 1) / math.max(1, props.rollCount), 0, 1), 0, 1, 0),
				BackgroundColor3 = props.sessionAccent,
				BorderSizePixel = 0,
				ZIndex = 422,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		)
	)
end

-- ─── ReelCard ──────────────────────────────────────────────────────────────────
local function ReelCard(_param)
	local card = _param.card
	local x = _param.x
	local width = _param.width
	local height = _param.height
	local emphasize = _param.emphasize
	local detailed = _param.detailed
	local fitScale = _param.fitScale
	local reducedMotion = _param.reducedMotion
	local winnerScale = _param.winnerScale
	local shimmerPhase = _param.shimmerPhase or 0  -- 0..1 offset per card

	local clock = useShimmerClock()
	local scale = if emphasize then winnerScale:map(function(amount)
		return amount * fitScale
	end) else 0.94 * fitScale
	local cardZ = if emphasize then 433 else 431

	-- shimmer strip position driven by global clock + per-card phase offset
	local shimmerX = React.joinBindings({ clock }):map(function(vals)
		local t = (vals[1] + shimmerPhase) % 1
		-- only show shimmer for a short burst window
		local sweep = if t < 0.22 then easeOutExpo(t / 0.22) else if t < 0.35 then 1 - (t - 0.22) / 0.13 else -0.15
		return UDim2.new(sweep, -28, 0, 0)
	end)

	-- winner glow halo: glowing outline ring that breathes
	local haloGlow
	if emphasize and not reducedMotion then
		haloGlow = React.createElement("frame", {
			Size = UDim2.new(1, 16, 1, 16),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = cardZ - 1,
		}, React.createElement("uistroke", {
			Color = lighten(card.accent, 0.18),
			Thickness = winnerScale:map(function(amt)
				return 1.5 + amt * 2.5
			end),
			Transparency = winnerScale:map(function(amt)
				return 1 - amt * 0.72
			end),
		}), React.createElement("uicorner", { CornerRadius = UDim.new(0, 17) }))
	end

	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(x, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = cardZ,
	},
		-- outer halo glow (winner only)
		haloGlow,
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = cardZ,
		}, React.createElement("uiscale", { Scale = scale }),
			-- drop shadow
			React.createElement("frame", {
				Size = UDim2.new(1, -8, 1, -10),
				Position = UDim2.fromOffset(4, 6),
				BackgroundColor3 = Palette.shadow or Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.36,
				BorderSizePixel = 0,
				ZIndex = cardZ,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) })),
			-- card body
			React.createElement("frame", {
				Size = UDim2.new(1, -4, 1, -4),
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				ZIndex = cardZ + 1,
				ClipsDescendants = true,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement("uistroke", {
					Color = if emphasize then lighten(card.accent, 0.3) else card.accent,
					Thickness = if emphasize then 2 else 1,
					Transparency = if emphasize then 0.04 else 0.42,
				}),
				React.createElement("uigradient", {
					Color = ColorSequence.new(lighten(Palette.panelRaised, 0.05), darken(Palette.panelRaised, 0.18)),
					Rotation = 90,
				}),
				-- rarity color cap strip
				React.createElement("frame", {
					Size = UDim2.new(1, -18, 0, 3),
					Position = UDim2.fromOffset(9, 8),
					BackgroundColor3 = card.accent,
					BackgroundTransparency = if emphasize then 0 else 0.18,
					BorderSizePixel = 0,
					ZIndex = cardZ + 2,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
				-- shimmer sweep (over card body, clipped)
				not reducedMotion and React.createElement("frame", {
					Size = UDim2.fromOffset(28, height),
					Position = shimmerX,
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Rotation = 12,
					ZIndex = cardZ + 5,
				}, React.createElement("uigradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Palette.cream),
						ColorSequenceKeypoint.new(0.5, Palette.cream),
						ColorSequenceKeypoint.new(1, Palette.cream),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.35, if emphasize then 0.38 else 0.72),
						NumberSequenceKeypoint.new(0.5, if emphasize then 0.22 else 0.58),
						NumberSequenceKeypoint.new(0.65, if emphasize then 0.38 else 0.72),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})),
				-- content
				if detailed then React.createElement(React.Fragment, nil,
					React.createElement(IconTile, {
						kind = itemIconKind(card.definitionId),
						accent = card.accent,
						size = 52,
						radius = 12,
						position = UDim2.new(0.5, 0, 0, 19),
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
						position = UDim2.new(0.5, -50, 0, 76),
						size = UDim2.fromOffset(100, 20),
						zIndex = cardZ + 4,
					}),
					React.createElement(Text, {
						value = card.name,
						size = 12,
						color = Palette.cream,
						weight = Enum.FontWeight.Heavy,
						align = Enum.TextXAlignment.Center,
						fit = true,
						minSize = 9,
						position = UDim2.fromOffset(8, 99),
						sizeConstraint = UDim2.new(1, -16, 0, 22),
						zIndex = cardZ + 4,
					})
				) else React.createElement(React.Fragment, nil,
					React.createElement("frame", {
						Size = UDim2.fromOffset(52, 52),
						Position = UDim2.new(0.5, 0, 0, 24),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = darken(card.accent, 0.6),
						BorderSizePixel = 0,
						ZIndex = cardZ + 3,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
						React.createElement("uistroke", {
							Color = card.accent,
							Thickness = 1,
							Transparency = 0.42,
						}),
						React.createElement("frame", {
							Size = UDim2.fromOffset(24, 24),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							Rotation = 45,
							BackgroundColor3 = card.accent,
							BorderSizePixel = 0,
							ZIndex = cardZ + 4,
						}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) })),
						React.createElement("frame", {
							Size = UDim2.fromOffset(8, 8),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Palette.cream,
							BorderSizePixel = 0,
							ZIndex = cardZ + 5,
						}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
					),
					React.createElement("frame", {
						Size = UDim2.new(1, -34, 0, 3),
						Position = UDim2.new(0.5, 0, 1, -24),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = card.accent,
						BackgroundTransparency = 0.32,
						BorderSizePixel = 0,
						ZIndex = cardZ + 3,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
				),
				-- winner tag badge
				card.tag ~= nil and emphasize and React.createElement(Badge, {
					value = card.tag,
					accent = if card.tag == "NEW" then Palette.mint else card.accent,
					filled = true,
					position = UDim2.new(1, -54, 0, -8),
					size = UDim2.fromOffset(48, 18),
					zIndex = cardZ + 5,
				})
			)
		)
	)
end

-- ─── ForgeReel ─────────────────────────────────────────────────────────────────
local function ForgeReel(_param)
	local props = _param.props
	local layout = _param.layout
	local landed = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	local cardFitScale = math.min(1, math.max(0.01, (layout.reelHeight - 4) / props.cardHeight))

	local pressOffset = React.joinBindings({ props.tickEnergy, props.landFlash, props.chargePulse }):map(function(values)
		return math.round(values[1] * 5 + values[2] * 12 + values[3] * 3)
	end)
	local selectorScale = React.joinBindings({ props.tickEnergy, props.landPop, props.landFlash }):map(function(values)
		return 1 + values[1] * 0.025 + values[2] * 0.035 + values[3] * 0.02
	end)
	local progressWidth = props.spinProgress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
	end)

	-- afterimage speed bars (visible when spinning fast)
	local speedBars = {}
	if props.allowAmbient then
		for index = 0, 5 do
			speedBars[index + 1] = React.createElement("frame", {
				key = `rail-speed-{index}`,
				Size = UDim2.fromOffset(52 + index * 12, 2),
				Position = UDim2.new(0.12 + index * 0.15, 0, 0.5, if index % 2 == 0 then -32 else 32),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if index % 2 == 0 then props.sessionAccent else Palette.cream,
				BackgroundTransparency = props.spinEnergy:map(function(amount)
					return 1 - amount * (0.22 + index * 0.025) * props.glowScale
				end),
				BorderSizePixel = 0,
				ZIndex = 428,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- reel cards with shimmer phase offsets
	local cardElements = {}
	for i, card in props.cards do
		local isWinner = card.winner == true
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
		-- outer shadow
		React.createElement("frame", {
			Size = UDim2.new(1, 6, 1, 8),
			Position = UDim2.fromOffset(-3, 7),
			BackgroundColor3 = Palette.shadow or Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 424,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) })),
		-- main stage frame
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ZIndex = 425,
			ClipsDescendants = false,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) }),
			React.createElement("uistroke", {
				Color = if landed then props.winnerAccent else props.sessionAccent,
				Thickness = if landed then 2 else 1.25,
				Transparency = if landed then 0.08 else 0.28,
			}),
			React.createElement("uigradient", {
				Color = ColorSequence.new(lighten(Palette.panel, 0.045), darken(Palette.panel, 0.16)),
				Rotation = 90,
			}),
			-- YOUR ROLL header strip
			React.createElement("frame", {
				Size = UDim2.new(1, -24, 0, 30),
				Position = UDim2.fromOffset(12, 8),
				BackgroundColor3 = Palette.night,
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				ZIndex = 426,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 9) }),
				React.createElement(Text, {
					value = "YOUR ROLL",
					size = 9,
					color = Palette.muted,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(10, 0),
					sizeConstraint = UDim2.new(1, -98, 1, 0),
					zIndex = 427,
				}),
				React.createElement(Text, {
					value = if props.phase == "spin" then "ROLLING" elseif landed then "LANDED" else "READY",
					size = 9,
					color = if landed then props.winnerAccent else props.sessionAccent,
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(1, -76, 0, 0),
					sizeConstraint = UDim2.fromOffset(66, 30),
					zIndex = 427,
				})
			),
			-- reel track
			React.createElement("frame", {
				Size = UDim2.fromOffset(layout.reelWidth, layout.reelHeight),
				Position = UDim2.new(0.5, 0, 1, -10),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Palette.void,
				BackgroundTransparency = 0.05,
				BorderSizePixel = 0,
				ZIndex = 427,
				ClipsDescendants = true,
				Visible = not layout.compactHeight or not landed,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement("uistroke", {
					Color = Palette.line,
					Thickness = 1,
					Transparency = 0.35,
				}),
				-- center guide line
				React.createElement("frame", {
					Size = UDim2.new(1, -16, 0, 4),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Palette.lineSoft,
					BackgroundTransparency = 0.36,
					BorderSizePixel = 0,
					ZIndex = 428,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
				-- speed afterimage bars
				table.unpack(speedBars),
				-- card strip
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
				-- left edge fade vignette
				React.createElement("frame", {
					Size = UDim2.new(0, math.min(54, layout.reelWidth * 0.16), 1, 0),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0.05,
					BorderSizePixel = 0,
					ZIndex = 438,
				}, React.createElement("uigradient", {
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
				})),
				-- right edge fade vignette
				React.createElement("frame", {
					Size = UDim2.new(0, math.min(54, layout.reelWidth * 0.16), 1, 0),
					Position = UDim2.fromScale(1, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0.05,
					BorderSizePixel = 0,
					ZIndex = 438,
				}, React.createElement("uigradient", {
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
				})),
				-- selection highlight bracket
				React.createElement("frame", {
					Size = UDim2.fromOffset(props.cardWidth + 12, props.cardHeight + 8),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
					BackgroundTransparency = if landed then 0.91 else 0.95,
					BorderSizePixel = 0,
					ZIndex = 439,
				}, React.createElement("uiscale", {
					Scale = selectorScale:map(function(amount)
						return amount * cardFitScale
					end),
				}), React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) }),
					React.createElement("uistroke", {
						Color = if landed then props.winnerAccent else props.sessionAccent,
						Thickness = if landed then 2.5 else 1.5,
						Transparency = if landed then 0.04 else 0.18,
					})
				),
				-- center tick needle
				React.createElement("frame", {
					Size = UDim2.new(0, 2, 1, -12),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Palette.cream,
					BackgroundTransparency = props.tickEnergy:map(function(amount)
						return 0.62 - amount * 0.36
					end),
					BorderSizePixel = 0,
					ZIndex = 440,
				})
			),
			-- skip caret pill
			React.createElement("frame", {
				Size = UDim2.fromOffset(68, 12),
				Position = pressOffset:map(function(value)
					return UDim2.new(0.5, 0, 0, 33 + value)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Palette.creamSoft,
				BorderSizePixel = 0,
				ZIndex = 445,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }),
				React.createElement("uigradient", {
					Color = ColorSequence.new(Palette.cream, Palette.lineSoft),
					Rotation = 90,
				}),
				React.createElement("frame", {
					Size = UDim2.fromOffset(28, 9),
					Position = UDim2.fromScale(0.5, 1),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
					BorderSizePixel = 0,
					ZIndex = 446,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) }))
			),
			-- spin progress bar
			React.createElement("frame", {
				Size = UDim2.new(1, -24, 0, 3),
				Position = UDim2.new(0.5, 0, 1, -5),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Palette.line,
				BorderSizePixel = 0,
				ZIndex = 447,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
				React.createElement("frame", {
					Size = progressWidth,
					BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
					BorderSizePixel = 0,
					ZIndex = 448,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
			)
		)
	)
end

-- ─── LandingBurst ──────────────────────────────────────────────────────────────
local function LandingBurst(_param)
	local props = _param.props
	local layout = _param.layout
	if props.phase ~= "land" then return nil end

	local count = math.clamp(math.floor(5 + props.fxBudget * 8), 5, 13)
	local center = UDim2.new(
		layout.stagePosition.X.Scale, layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
	)

	-- spark particles
	local sparks = {}
	if not props.reducedMotion and props.allowAmbient then
		for index = 0, 12 do
			if index >= count then break end
			local angle = (index / count) * math.pi * 2 - math.pi / 2
			local distance = 58 + (index % 4) * 22
			local sizeW = if index % 3 == 0 then 8 else 5
			local sizeH = if index % 2 == 0 then 3 else 5
			local travel = props.landFlash:map(function(amount)
				return 1 - amount
			end)
			sparks[index + 1] = React.createElement("frame", {
				key = `crate-spark-{index}`,
				Size = UDim2.fromOffset(sizeW, sizeH),
				Position = travel:map(function(amount)
					return UDim2.new(
						center.X.Scale, center.X.Offset + math.cos(angle) * distance * amount,
						center.Y.Scale, center.Y.Offset + math.sin(angle) * distance * amount
					)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = index * 37,
				BackgroundColor3 = if index % 3 == 0 then Palette.cream else props.winnerAccent,
				BackgroundTransparency = travel:map(function(amount)
					return math.clamp(amount * 1.2, 0, 1)
				end),
				BorderSizePixel = 0,
				ZIndex = 448,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- vertical column beams (shooting upward on land)
	local beams = {}
	if not props.reducedMotion and props.allowAmbient then
		for i = 0, 2 do
			local bx = -60 + i * 60
			beams[i + 1] = React.createElement("frame", {
				key = `land-beam-{i}`,
				Size = props.landFlash:map(function(f)
					return UDim2.fromOffset(2 + i, math.round(f * (140 + i * 40)))
				end),
				Position = UDim2.new(center.X.Scale, center.X.Offset + bx, center.Y.Scale, center.Y.Offset),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if i == 1 then Palette.cream else props.winnerAccent,
				BackgroundTransparency = props.landFlash:map(function(f)
					return 1 - f * (0.55 - i * 0.1)
				end),
				BorderSizePixel = 0,
				ZIndex = 448,
			}, React.createElement("uigradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.6, 0.3),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}), React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- shockwave ring
	local shockRing = not props.reducedMotion and React.createElement("frame", {
		Size = props.landFlash:map(function(f)
			local s = easeOutExpo(f) * 160
			return UDim2.fromOffset(s, s)
		end),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 449,
	}, React.createElement("uistroke", {
		Color = props.winnerAccent,
		Thickness = 2,
		Transparency = props.landFlash:map(function(f)
			return 0.05 + (1 - f) * 0.85
		end),
	}), React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 448,
		Active = false,
	},
		table.unpack(sparks),
		table.unpack(beams),
		shockRing,
		-- horizontal flash bar
		React.createElement("frame", {
			Size = props.landFlash:map(function(amount)
				return UDim2.fromOffset(150 + amount * 460, 3 + amount * 3)
			end),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cream,
			BackgroundTransparency = props.landFlash:map(function(amount)
				return 1 - amount * 0.82
			end),
			BorderSizePixel = 0,
			ZIndex = 448,
		}, React.createElement("uigradient", {
			Color = ColorSequence.new(props.winnerAccent, Palette.cream),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.05),
				NumberSequenceKeypoint.new(0.58, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}))
	)
end

-- ─── ResultPanel ───────────────────────────────────────────────────────────────
local function ResultPanel(_param)
	local props = _param.props
	local layout = _param.layout
	local visible = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	if not visible then return nil end

	-- animated accent underline that grows in on reveal
	local accentLineWidth, setAccentLineWidth = React.useBinding(0)
	React.useEffect(function()
		local start = os.clock()
		local dur = 0.55
		local conn = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / dur, 0, 1)
			setAccentLineWidth(easeOutBack(t))
		end)
		return function() conn:Disconnect() end
	end, { props.winnerName })

	return React.createElement("frame", {
		Size = layout.resultSize,
		Position = props.landPop:map(function(amount)
			return UDim2.new(
				layout.resultPosition.X.Scale, layout.resultPosition.X.Offset,
				layout.resultPosition.Y.Scale, layout.resultPosition.Y.Offset + math.round((1 - amount) * 18)
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
		-- rarity • roll counter
		React.createElement(Text, {
			value = `{string.upper(props.winnerRarity)}  •  ROLL {props.rollIndex + 1}/{props.rollCount}`,
			size = 9,
			color = props.winnerAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 7,
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 14),
			zIndex = 452,
		}),
		-- item name
		React.createElement(Text, {
			value = props.winnerName,
			size = if props.shortLandscape then 16 else 19,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(0, 18),
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 26),
			zIndex = 452,
		}),
		-- animated accent underline
		React.createElement("frame", {
			Size = accentLineWidth:map(function(t)
				return UDim2.new(t * (if props.shortLandscape then 0.55 else 0.42), 0, 0, 2)
			end),
			Position = UDim2.fromOffset(0, 44),
			BackgroundColor3 = props.winnerAccent,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 453,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
		-- detail text
		React.createElement(Text, {
			value = props.resultDetail,
			size = 9,
			color = Palette.creamSoft,
			fit = true,
			minSize = 7,
			wrap = true,
			position = UDim2.fromOffset(0, 47),
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, if props.shortLandscape then 32 else 24),
			zIndex = 452,
		}),
		-- result tag badge
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

-- ─── CrateRevealStage (root) ───────────────────────────────────────────────────
local function CrateRevealStage(props)
	local layout = resolveLayout(props)
	local actionHostRef = React.useRef(nil)
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
			task.cancel(selectJob)
		end
	end, { props.phase })
	local dimmer = props.visualShow:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.985
	end)
	local accentWash = props.visualShow:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.08
	end)
	local showingClaim = props.phase == "done" or props.phase == "exit"

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 400,
	},
		-- full-screen tap-to-interact backdrop
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
		-- accent gradient wash overlay
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
		-- main content (scaled from center on enter/exit)
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
			React.createElement(ForgeBackdrop, { props = props, layout = layout }),
			React.createElement(RevealHeader, { props = props, layout = layout }),
			React.createElement(ForgeReel, { props = props, layout = layout }),
			React.createElement(LandingBurst, { props = props, layout = layout }),
			React.createElement(ResultPanel, { props = props, layout = layout }),
			-- SKIP button (during spin)
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
				icon = "Chevron",
				onClick = props.onQuickLand,
				color = Palette.panelSoft,
				textColor = Palette.creamSoft,
				outline = true,
				size = UDim2.fromScale(1, 1),
				reducedMotion = props.reducedMotion,
				selectable = true,
			})),
			-- CLAIM button (after land)
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
				ZIndex = 456,
			}, React.createElement(Button, {
				text = props.claimText,
				icon = "Gift",
				onClick = props.onClaim,
				color = props.sessionAccent,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				reducedMotion = props.reducedMotion,
				highlight = true,
				selectable = true,
				disabled = props.phase == "exit",
			}))
		))
	)
end

return {
	CrateRevealStage = CrateRevealStage,
}
