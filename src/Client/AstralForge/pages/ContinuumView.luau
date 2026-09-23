local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local AutoGrid = require(script.Parent.Parent.scrolling).AutoGrid
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local Icon = require(script.Parent.Parent.Icon).Icon
local _motion = require(script.Parent.Parent.motion)
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useRotation = _motion.useRotation
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local Meter = _ui.Meter
local OrbitDot = _ui.OrbitDot
local Panel = _ui.Panel
local SCROLL_EDGE = _ui.SCROLL_EDGE
local Stroke = _ui.Stroke
local SweptRing = _ui.SweptRing
local Text = _ui.Text
local NEAR_COMPLETE_THRESHOLD = 0.85
local function ProgressCloseGlow(_param)
	local progress = _param.progress
	local complete = _param.complete
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local size = _param.size
	local antilag = useAntilag()
	local near = not complete and progress >= NEAR_COMPLETE_THRESHOLD and progress < 1
	local active = near and antilag.allowAmbient and antilag.tier >= 1 and not reducedMotion
	local pulse = usePulse(active, 2.4)
	if not near then
		return nil
	end
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement(Stroke, {
		color = accent,
		thickness = 1.5,
		transparency = if active then pulse:map(function(amount)
			return math.clamp(0.65 - amount * 0.45, 0.18, 0.65)
		end) else 0.5,
	}))
end
local function useReadyPop(ready, reducedMotion)
	local wasReady = React.useRef(ready)
	local trigger, setTrigger = React.useState(0)
	React.useEffect(function()
		if ready and not wasReady.current then
			setTrigger(function(current)
				return current + 1
			end)
		end
		wasReady.current = ready
	end, { ready })
	return useFlash(trigger, reducedMotion, 0.6)
end
local EMPTY_CONTINUUM = {
	Rank = 0,
	TotalFluxSpent = 0,
	TotalStardustSpent = 0,
	FluxCost = 2500000,
	StardustCost = 12,
	CanUpgrade = false,
	ProductionMultiplier = 1,
	CapacityMultiplier = 1,
	TapMultiplier = 1,
	OfflineBonus = 0,
	NextMilestone = 25,
}
local function EffectCell(_param)
	local label = _param.label
	local value = _param.value
	local accent = _param.accent
	local order = _param.order
	local reducedMotion = _param.reducedMotion
	local reveal = useStagger(order, reducedMotion, 0.035, 0.2)
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = darken(accent, 0.9),
		padding = 12,
		reveal = reveal,
		reducedMotion = reducedMotion,
	}, React.createElement(Text, {
		value = label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = value,
		size = 20,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(0, 19),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}))
end
local function ContinuumCore(_param)
	local rank = _param.rank
	local reducedMotion = _param.reducedMotion
	local size = _param.size
	local outerRotation = useRotation(not reducedMotion, 20)
	local innerRotation = useRotation(not reducedMotion, -30)
	local drift = useRotation(not reducedMotion, 7)
	local breathe = usePulse(not reducedMotion, 0.3)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = breathe:map(function(amount)
			return UDim2.fromScale(0.9 + amount * 0.03, 0.9 + amount * 0.03)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.violet,
		BackgroundTransparency = breathe:map(function(amount)
			return 0.92 - amount * 0.04
		end),
		BorderSizePixel = 0,
		ZIndex = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = drift,
		ZIndex = 1,
	}, React.createElement(SweptRing, {
		scale = 0.84,
		color = Palette.violet,
		thickness = 1.5,
		spin = outerRotation,
		sweepWidth = 0.32,
	})), React.createElement(SweptRing, {
		scale = 0.62,
		color = Palette.cyan,
		thickness = 1.5,
		spin = innerRotation,
		sweepWidth = 0.36,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(0.84, 0.84),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = outerRotation,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = -90,
		size = 8,
		color = Palette.pink,
		glow = true,
	}), React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 90,
		size = 6,
		color = Palette.cyan,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = innerRotation,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 0,
		size = 5,
		color = Palette.cyan,
	}), React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 180,
		size = 5,
		color = Palette.violet,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(Palette.violet, 0.58),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.pink, 0.1), darken(Palette.cyan, 0.38)),
		Rotation = 45,
	}), React.createElement(Icon, {
		kind = "Rebirth",
		color = Palette.cream,
		accent = Palette.cyan,
		size = math.floor(size * 0.42),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = if rank > 0 then `RANK {compactNumber(rank)}` else "UNRANKED",
		size = 9,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 1, -22),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}))
end
local function ContinuumView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local continuum = state.Continuum or EMPTY_CONTINUUM
	local heroH = if stack then 236 else 230
	local effectsH = if stack then 184 else 104
	local forgeH = if stack then 256 else 218
	local milestoneH = if stack then 156 else 132
	local contentH = heroH + effectsH + forgeH + milestoneH + 48 + scrollTail(stack, chrome.bottomSafe, 48)
	local canvasH = contentH + SCROLL_EDGE * 2
	local progress = math.clamp((continuum.Rank % 25) / 25, 0, 1)
	local milestoneComplete = continuum.Rank > 0 and continuum.Rank % 25 == 0
	local coreSize = if stack then 78 else 132
	local canFlux = gteFlux(state.Cash, continuum.FluxCost)
	local canDust = gteFlux(state.Stardust, continuum.StardustCost)
	local upgradePop = useReadyPop(continuum.CanUpgrade, reducedMotion)
	local forgeIconScale = upgradePop:map(function(amount)
		return 1 + amount * 0.18
	end)
	local milestoneMeterSize = UDim2.new(1, 0, 0, 8)
	local milestoneMeterPosition = UDim2.fromOffset(0, 56)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("scrollingframe", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, canvasH),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.violet,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, contentH),
		Position = UDim2.fromOffset(0, SCROLL_EDGE),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, heroH),
		accent = Palette.violet,
		background = darken(Palette.violet, 0.92),
		padding = if stack then 16 else 20,
		highlight = continuum.Rank > 0,
		reducedMotion = reducedMotion,
		clips = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(coreSize, coreSize),
		Position = if stack then UDim2.new(0.5, -coreSize / 2, 0, 8) else UDim2.fromOffset(4, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = forgeIconScale,
	}), React.createElement(ContinuumCore, {
		rank = continuum.Rank,
		size = coreSize,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 104) else UDim2.new(1, -(coreSize + 34), 1, -20),
		Position = if stack then UDim2.fromOffset(0, coreSize + 10) else UDim2.fromOffset(coreSize + 24, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		value = "ENDLESS PROGRESSION",
		size = 9,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = "Continuum Forge",
		size = if stack then 20 else 32,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = "Spend flux and stardust. Ranks stay through rebirths and Domain.",
		size = if stack then 11 else 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 46),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	}), React.createElement(Text, {
		value = "Doesn't stop when the worlds do.",
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(0, 84),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, effectsH),
		Position = UDim2.fromOffset(0, heroH + 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(AutoGrid, {
		columns = if stack then 2 else 4,
		cellHeight = if stack then 101 else effectsH,
		rowGap = 10,
		columnGap = 10,
	}), React.createElement(EffectCell, {
		label = "PRODUCTION",
		value = `{compactNumber(continuum.ProductionMultiplier)}×`,
		accent = Palette.cyan,
		order = 0,
		reducedMotion = reducedMotion,
	}), React.createElement(EffectCell, {
		label = "VAULT CAPACITY",
		value = `{compactNumber(continuum.CapacityMultiplier)}×`,
		accent = Palette.violet,
		order = 1,
		reducedMotion = reducedMotion,
	}), React.createElement(EffectCell, {
		label = "OVERCHARGE",
		value = `{compactNumber(continuum.TapMultiplier)}×`,
		accent = Palette.mango,
		order = 2,
		reducedMotion = reducedMotion,
	}), React.createElement(EffectCell, {
		label = "OFFLINE",
		value = `+{string.format("%.1f", continuum.OfflineBonus * 100)}%`,
		accent = Palette.mint,
		order = 3,
		reducedMotion = reducedMotion,
	})), React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, forgeH),
		position = UDim2.fromOffset(0, heroH + effectsH + 24),
		accent = if continuum.CanUpgrade then Palette.pink else Palette.violet,
		background = Palette.panelRaised,
		padding = if stack then 15 else 18,
		highlight = continuum.CanUpgrade,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(Text, {
		value = `FORGE RANK {compactNumber(continuum.Rank + 1)}`,
		size = 10,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = "Buy another rank",
		size = if stack then 20 else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 15,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 34),
	}), React.createElement(Text, {
		value = "Each rank costs more and pays more. Every 25 ranks is a permanent 1.5×.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 58),
		sizeConstraint = UDim2.new(1, if stack then 0 else -248, 0, 40),
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 62) else UDim2.fromOffset(224, 82),
		Position = if stack then UDim2.fromOffset(0, 108) else UDim2.new(1, -224, 0, 12),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if continuum.CanUpgrade then Palette.pink else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement(Text, {
		value = `{if canFlux then "READY" else "NEED"}  {compactNumber(continuum.FluxCost)} flux`,
		size = 12,
		color = if canFlux then Palette.cyan else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(12, 8),
		sizeConstraint = UDim2.new(1, -24, 0, 18),
	}), React.createElement(Text, {
		value = `{if canDust then "READY" else "NEED"}  {compactNumber(continuum.StardustCost)} stardust`,
		size = 12,
		color = if canDust then Palette.mango else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(12, 33),
		sizeConstraint = UDim2.new(1, -24, 0, 18),
	})), React.createElement(Button, {
		text = if continuum.CanUpgrade then "FORGE CONTINUUM RANK" else "GATHER RESOURCES",
		icon = "Rebirth",
		onClick = function()
			return dispatch("UpgradeContinuum")
		end,
		color = if continuum.CanUpgrade then Palette.pink else Palette.panelSoft,
		textColor = if continuum.CanUpgrade then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		disabled = not continuum.CanUpgrade,
		highlight = continuum.CanUpgrade,
	})), React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, milestoneH),
		position = UDim2.fromOffset(0, heroH + effectsH + forgeH + 36),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = if stack then 14 else 18,
		reducedMotion = reducedMotion,
	}, React.createElement(Text, {
		value = "NEXT 1.5× BOOST",
		size = 9,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = `Rank {compactNumber(continuum.NextMilestone)}  ·  permanent 1.5× production`,
		size = if stack then 16 else 19,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Meter, {
		value = progress,
		color = Palette.cyan,
		reducedMotion = reducedMotion,
		shimmer = continuum.Rank > 0,
		position = milestoneMeterPosition,
		size = milestoneMeterSize,
	}), React.createElement(ProgressCloseGlow, {
		progress = progress,
		complete = milestoneComplete,
		accent = Palette.cyan,
		reducedMotion = reducedMotion,
		position = milestoneMeterPosition,
		size = milestoneMeterSize,
	}), React.createElement(Text, {
		value = `{continuum.Rank % 25} / 25 ranks toward the next boost`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(0, 72),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), stack and React.createElement(Text, {
		value = `Lifetime invested: {compactNumber(continuum.TotalFluxSpent)} flux · {compactNumber(continuum.TotalStardustSpent)} dust`,
		size = 9,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 98),
		sizeConstraint = UDim2.new(1, 0, 0, 34),
	})))))
end
return {
	ContinuumView = ContinuumView,
}
