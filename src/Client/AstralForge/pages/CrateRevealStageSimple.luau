local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _theme = require(script.Parent.Parent.theme)
local Palette = _theme.Palette
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local Text = _ui.Text

local h = React.createElement

local function ReelCard(props)
	local card = props.card
	local landedWinner = card.winner and props.landed
	local accent = card.accent or Palette.cyan
	local iconSize = math.max(18, math.round(42 * props.cardScale))
	local gemSize = math.max(9, math.round(19 * props.cardScale))
	return h("frame", {
		Size = UDim2.fromOffset(props.width, props.height),
		Position = UDim2.fromOffset(props.x, 0),
		BackgroundColor3 = if landedWinner then Palette.panelRaised else Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 433,
	},
		h("uicorner", { CornerRadius = UDim.new(0, 12) }),
		h("uistroke", {
			Color = if landedWinner then accent else Palette.line,
			Thickness = if landedWinner and not props.reducedMotion then props.winnerCardScale:map(function(value)
				return math.clamp(2 + (value - 1) * 5, 1.5, 2.5)
			end) elseif landedWinner then 2 else 1,
			Transparency = if landedWinner then 0 else 0.45,
		}),
		h("uigradient", {
			Color = ColorSequence.new(if landedWinner then Palette.panelSoft else Palette.panelRaised, Palette.panel),
			Rotation = 90,
		}),
		h("frame", {
			Size = UDim2.new(1, -20, 0, 2),
			Position = UDim2.fromOffset(10, 8),
			BackgroundColor3 = accent,
			BackgroundTransparency = if landedWinner then 0 else 0.34,
			BorderSizePixel = 0,
			ZIndex = 434,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
		h("frame", {
			Size = UDim2.fromOffset(iconSize, iconSize),
			Position = UDim2.new(0.5, 0, 0, math.round(20 * props.cardScale)),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			ZIndex = 434,
		}, h("uicorner", { CornerRadius = UDim.new(0, math.max(5, math.round(11 * props.cardScale))) }),
			h("frame", {
				Size = UDim2.fromOffset(gemSize, gemSize),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 435,
			}, h("uicorner", { CornerRadius = UDim.new(0, math.max(2, math.round(4 * props.cardScale))) }))),
		h(Text, {
			value = string.upper(card.rarity or "RELIC"),
			size = 9,
			color = accent,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(6, math.round(70 * props.cardScale)),
			sizeConstraint = UDim2.new(1, -12, 0, math.max(12, math.round(14 * props.cardScale))),
			zIndex = 435,
		}),
		h(Text, {
			value = card.name or "Relic",
			size = 12,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(6, math.round(94 * props.cardScale)),
			sizeConstraint = UDim2.new(1, -12, 0, math.max(15, math.round(28 * props.cardScale))),
			zIndex = 435,
		})
	)
end

local function CrateRevealStage(props)
	local panelRef = React.useRef(nil)
	-- README checklist: claim/skip must be D-pad/A reachable via Selection.
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local panel = panelRef.current
		if panel == nil then
			return nil
		end
		if props.phase ~= "spin" and props.phase ~= "done" then
			GamepadNavigationService.ClearSelection()
			return nil
		end
		local selectJob = task.defer(function()
			if panel.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(panel)
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { props.phase })
	local landed = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	local canClaim = props.phase == "done"
	local safeWidth = math.max(1, props.viewportWidth - (props.sideSafe or 0) * 2 - 24)
	local safeHeight = math.max(1, props.viewportHeight - (props.topInset or 0) - (props.bottomSafe or 0) - 24)
	local panelWidth = math.min(760, safeWidth)
	local panelHeight = math.min(430, safeHeight)
	local compact = panelHeight < 355
	local padding = if panelWidth < 420 then 14 else 20
	local headerHeight = if compact then 52 else 62
	local resultHeight = if compact then 62 else 76
	local actionHeight = 50
	local gap = if compact then 7 else 12
	local trackHeight = math.max(1, panelHeight - padding * 2 - headerHeight - resultHeight - actionHeight - gap * 3)
	local trackWidth = math.max(1, panelWidth - padding * 2)
	local cardScale = math.min(1, math.max(0.01, (trackHeight - 16) / props.cardHeight))
	local safeCenterY = ((props.topInset or 0) + props.viewportHeight - (props.bottomSafe or 0)) / 2
	local accent = if landed then props.winnerAccent else props.sessionAccent
	local resultTitle = if landed then props.winnerName elseif props.phase == "spin" then "Finding your relic…" else "Opening crate…"
	local resultSubtitle = if landed then props.resultDetail elseif props.phase == "spin" then "Tap to skip the roll" else "Get ready for your drop"
	local status = if props.phase == "spin" then "ROLLING" elseif landed then "RELIC FOUND" else "OPENING"
	local actionY = panelHeight - padding - actionHeight
	local resultY = actionY - gap - resultHeight
	local trackY = padding + headerHeight + gap

	local cards = {}
	for i, card in props.cards do
		cards[i] = h(ReelCard, {
			key = card.key,
			card = card,
			x = (i - 1) * props.stride * cardScale,
			width = props.cardWidth * cardScale,
			height = props.cardHeight * cardScale,
			cardScale = cardScale,
			landed = landed,
			reducedMotion = props.reducedMotion,
			winnerCardScale = props.winnerCardScale,
		})
	end

	local track = h("frame", {
		Size = UDim2.fromOffset(trackWidth, trackHeight),
		Position = UDim2.fromOffset(padding, trackY),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 430,
	},
		h("uicorner", { CornerRadius = UDim.new(0, 12) }),
		-- A quiet center lane guides the eye without covering the winning card.
		h("frame", {
			Size = UDim2.fromOffset(props.cardWidth * cardScale + 16, trackHeight),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accent,
			BackgroundTransparency = React.joinBindings({ props.spinEnergy, props.landFlash }):map(function(values)
				return if landed then math.clamp(0.95 - values[2] * 0.14, 0.78, 0.95) else 0.97 - values[1] * 0.04
			end),
			BorderSizePixel = 0,
			ZIndex = 431,
		}),
		h("frame", {
			Size = UDim2.fromOffset(#props.cards * props.stride * cardScale, props.cardHeight * cardScale),
			Position = props.reelOffset:map(function(offset)
				return UDim2.fromOffset(trackWidth / 2 - (offset + props.cardWidth / 2) * cardScale, (trackHeight - props.cardHeight * cardScale) / 2)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 432,
		}, table.unpack(cards)),
		-- Short ticks indicate the winning position without crossing the cards.
		h("frame", {
			Size = props.tickEnergy:map(function(value)
				return UDim2.fromOffset(3 + math.round(value * 2), 10 + math.round(value * 3))
			end),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 440,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
		h("frame", {
			Size = props.tickEnergy:map(function(value)
				return UDim2.fromOffset(3 + math.round(value * 2), 10 + math.round(value * 3))
			end),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 440,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
		h("frame", {
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			BackgroundColor3 = Palette.line,
			BorderSizePixel = 0,
			ZIndex = 441,
		}, h("frame", {
			Size = props.spinProgress:map(function(value)
				return UDim2.new(math.clamp(value, 0, 1), 0, 1, 0)
			end),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 442,
		}))
	)

	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 400,
	},
		h("imagebutton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.void,
			BackgroundTransparency = props.visualShow:map(function(value)
				return 1 - math.clamp(value, 0, 1) * 0.97
			end),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Selectable = false,
			Active = props.phase == "spin",
			ZIndex = 401,
			Event = { Activated = function()
				if props.phase == "spin" then props.onQuickLand() end
			end },
		}),
		h("frame", {
			ref = panelRef,
			Size = UDim2.fromOffset(panelWidth, panelHeight),
			Position = props.visualShow:map(function(value)
				return UDim2.new(0.5, 0, 0, safeCenterY + math.round((1 - value) * 16))
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			Visible = props.visualShow:map(function(value)
				return value > 0.015
			end),
			ZIndex = 410,
		},
			h("uicorner", { CornerRadius = UDim.new(0, 16) }),
			h("uiscale", { Scale = if props.reducedMotion then 1 else props.visualShow:map(function(value)
				return 0.96 + 0.04 * math.clamp(value, 0, 1)
			end) }),
			h("uistroke", {
				Color = accent,
				Thickness = 1,
				Transparency = props.landFlash:map(function(value)
					return math.clamp(0.72 - value * 0.48, 0.18, 0.72)
				end),
			}),
			h("uigradient", { Color = ColorSequence.new(Palette.panelRaised, Palette.panel), Rotation = 90 }),
			h("frame", {
				Size = UDim2.new(1, -32, 0, 3),
				Position = UDim2.fromOffset(16, 0),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 419,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
			h(Text, {
				value = props.crateName,
				size = if compact then 19 else 23,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 13,
				position = UDim2.fromOffset(padding, padding),
				sizeConstraint = UDim2.fromOffset(math.max(1, panelWidth - padding * 2 - 100), 29),
				zIndex = 420,
			}),
			h("frame", {
				Size = UDim2.fromOffset(88, 30),
				Position = UDim2.new(1, -padding - 88, 0, padding),
				BackgroundColor3 = Palette.panelSoft,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ZIndex = 420,
			}, h("uicorner", { CornerRadius = UDim.new(0, 8) }), h(Text, {
				value = `{props.rollIndex + 1} / {props.rollCount}`,
				size = 11,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 421,
			})),
			h(Text, {
				value = status,
				size = 10,
				color = accent,
				weight = Enum.FontWeight.Bold,
				position = UDim2.fromOffset(padding, padding + 30),
				sizeConstraint = UDim2.fromOffset(math.max(1, panelWidth - padding * 2), 18),
				zIndex = 420,
			}),
			track,
			h("frame", {
				Size = UDim2.fromOffset(trackWidth, resultHeight),
				Position = props.landPop:map(function(value)
					return UDim2.fromOffset(padding, resultY + (if landed then math.round((1 - value) * 8) else 0))
				end),
				BackgroundColor3 = if landed then Palette.panelSoft else Palette.panel,
				BackgroundTransparency = if landed then 0.22 else 0.48,
				BorderSizePixel = 0,
				ZIndex = 450,
			},
				h("uicorner", { CornerRadius = UDim.new(0, 10) }),
				h("frame", {
					Size = UDim2.fromOffset(3, resultHeight - 20),
					Position = UDim2.fromOffset(10, 10),
					BackgroundColor3 = accent,
					BorderSizePixel = 0,
					ZIndex = 451,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
				h(Text, {
					value = if landed then `{string.upper(props.winnerRarity)}  ·  {props.resultTag}` else status,
					size = 10,
					color = accent,
					weight = Enum.FontWeight.Bold,
					position = UDim2.fromOffset(24, if compact then 5 else 8),
					sizeConstraint = UDim2.new(1, -36, 0, 15),
					zIndex = 451,
				}),
				h(Text, {
					value = resultTitle,
					size = if compact then 17 else 20,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 11,
					position = UDim2.fromOffset(24, if compact then 19 else 24),
					sizeConstraint = UDim2.new(1, -36, 0, if compact then 22 else 26),
					zIndex = 451,
				}),
				h(Text, {
					value = resultSubtitle,
					size = 11,
					color = Palette.creamSoft,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(24, if compact then 41 else 51),
					sizeConstraint = UDim2.new(1, -36, 0, 17),
					zIndex = 451,
				})),
			h("frame", {
				Size = UDim2.fromOffset(math.min(300, trackWidth), actionHeight),
				Position = props.claimSlide:map(function(value)
					return UDim2.new(0.5, 0, 0, actionY + (if canClaim then math.round((1 - value) * 10) else 0))
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 455,
			},
				(props.phase == "spin" or canClaim) and h("frame", {
					Name = if canClaim then "CrateClaim" else "CrateSkip",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ZIndex = 456,
				}, h(Button, {
					text = if canClaim then props.claimText else "SKIP ROLL",
					onClick = if canClaim then props.onClaim else props.onQuickLand,
					color = if canClaim then props.sessionAccent else Palette.panelSoft,
					textColor = if canClaim then Palette.ink else Palette.cream,
					outline = not canClaim,
					size = UDim2.fromScale(1, 1),
					reducedMotion = props.reducedMotion,
					highlight = canClaim,
					selectable = true,
					zIndex = 456,
				})))
		)
	)
end

return { CrateRevealStage = CrateRevealStage }
