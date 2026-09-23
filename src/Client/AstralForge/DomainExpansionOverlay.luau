local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local AutoGrid = require(script.Parent.scrolling).AutoGrid
local useAntilag = require(script.Parent.antilag).useAntilag
local Audio = require(script.Parent.audio).Audio
local _motion = require(script.Parent.motion)
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local easeOutQuart = _motion.easeOutQuart
local CanvasEnergyField = require(script.Parent.effects).CanvasEnergyField
local bezierOrbit = require(script.Parent.motion).bezierOrbit
local InteractionFeedback = require(script.Parent.interaction).InteractionFeedback
local _motion_1 = require(script.Parent.motion)
local ScaleFromCenter = _motion_1.ScaleFromCenter
local useBoatTween = _motion_1.useBoatTween
local useExitTransition = _motion_1.useExitTransition
local useFlipperSpring = _motion_1.useFlipperSpring
local useOtterSpring = _motion_1.useOtterSpring
local useSprScale = _motion_1.useSprScale
local useViewport = _motion_1.useViewport
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.format).compactNumber
local RAYS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local CRACKS = { 0, 1, 2, 3, 4, 5, 6, 7 }
local SHARDS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local function phase(value, from, to)
	return math.clamp((value - from) / math.max(0.001, to - from), 0, 1)
end
local function pulse(value, start, peak, finish)
	if value <= peak then
		return phase(value, start, peak)
	end
	return 1 - phase(value, peak, finish)
end
local function requirementColor(ready)
	return if ready then Palette.green else Palette.coral
end
local function DomainPortal(_param)
	local time = _param.time
	local size = _param.size
	local resultMode = _param.resultMode
	local reducedMotion = _param.reducedMotion
	local rayCount = _param.rayCount
	local fade = _param.fade
	local portalSprRef = useSprScale(1, reducedMotion, 0.78, 0.66, if resultMode then 7.5 else 6.5)
	local reveal = time:map(function(value)
		return if reducedMotion then 1 else easeOutBack(phase(value, if resultMode then 0.32 else 0, if resultMode then 1.15 else 0.42))
	end)
	local impact = time:map(function(value)
		return if reducedMotion or not resultMode then 0 else pulse(value, 1.08, 1.28, 1.7)
	end)
	local spin = time:map(function(value)
		return if reducedMotion then 0 else value * (if resultMode then 34 else 12)
	end)
	local portalScale = if fade ~= nil then React.joinBindings({ reveal, impact, fade }):map(function(_param_1)
		local shown = _param_1[1]
		local hit = _param_1[2]
		local leave = _param_1[3]
		return math.max(0.02, shown * math.clamp(leave, 0, 1) * (1 + hit * 0.08))
	end) else React.joinBindings({ reveal, impact }):map(function(_param_1)
		local shown = _param_1[1]
		local hit = _param_1[2]
		return math.max(0.02, shown * (1 + hit * 0.08))
	end)
	local portalSize = portalScale:map(function(amount)
		return UDim2.fromOffset(size * amount, size * amount)
	end)
	local _exp = React.createElement(CanvasEnergyField, {
		time = time,
		enabled = not reducedMotion and rayCount >= 12,
		reducedMotion = reducedMotion,
		zIndex = 712,
	})
	-- ▼ ReadonlyArray.filter ▼
	local _newValue = {}
	local _callback = function(index)
		return index < rayCount
	end
	local _length = 0
	for _k, _v in RAYS do
		if _callback(_v, _k - 1, RAYS) == true then
			_length += 1
			_newValue[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#_newValue)
	local _callback_1 = function(index)
		local angle = index * (360 / rayCount)
		local length = size * (if index % 3 == 0 then 0.64 else 0.48)
		return React.createElement("frame", {
			key = `ray-{index}`,
			Size = UDim2.fromOffset(length, if index % 2 == 0 then 3 else 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			Rotation = spin:map(function(value)
				return value + angle
			end),
			BackgroundColor3 = if index % 2 == 0 then Palette.pink else Palette.violet,
			BackgroundTransparency = time:map(function(value)
				if reducedMotion then
					return 0.82
				end
				local energy = if resultMode then pulse(value, 0.55, 1.28, 2.4) else 0.3 + math.sin(value * 2.2 + index) * 0.08
				return math.clamp(0.94 - energy * 0.35, 0.55, 0.95)
			end),
			BorderSizePixel = 0,
			ZIndex = 711,
		}, React.createElement("uigradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Palette.white, if index % 2 == 0 then Palette.pink else Palette.violet),
		}))
	end
	for _k, _v in _newValue do
		_newValue_1[_k] = _callback_1(_v, _k - 1, _newValue)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_1 = { 0, 1, 2 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#_exp_1)
	local _callback_2 = function(ring)
		return React.createElement("frame", {
			key = `ring-{ring}`,
			Size = UDim2.new(1, -ring * size * 0.12, 1, -ring * size * 0.12),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = spin:map(function(value)
				return value * (if ring == 1 then -1.4 elseif ring == 2 then 0.72 else 1) + ring * 27
			end),
			ZIndex = 717 + ring,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Thickness = if ring == 0 then 3 else 2,
			Color = if ring == 1 then Palette.pink elseif ring == 2 then Palette.cyan else Palette.violet,
			Transparency = time:map(function(value)
				return if reducedMotion then 0.25 + ring * 0.15 else math.clamp(0.15 + ring * 0.16 + math.sin(value * 3 + ring) * 0.12, 0.04, 0.74)
			end),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.white, if ring == 1 then Palette.pink else Palette.violet),
			Rotation = ring * 120,
		}))
	end
	for _k, _v in _exp_1 do
		_newValue_2[_k] = _callback_2(_v, _k - 1, _exp_1)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_3 = {}
	local _callback_3 = function(index)
		return index < math.min(rayCount, 10)
	end
	local _length_1 = 0
	for _k, _v in RAYS do
		if _callback_3(_v, _k - 1, RAYS) == true then
			_length_1 += 1
			_newValue_3[_length_1] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_4 = table.create(#_newValue_3)
	local _callback_4 = function(index)
		return React.createElement("frame", {
			key = `mote-{index}`,
			Size = UDim2.fromOffset(if index % 3 == 0 then 6 else 4, if index % 3 == 0 then 6 else 4),
			Position = time:map(function(value)
				local orbit = bezierOrbit(value * (if resultMode then 0.2 else 0.086) * (if index % 2 == 0 then 1 else -1) + index * 0.116)
				local radius = size * (0.33 + (index % 4) * 0.045)
				return UDim2.new(0.5, orbit.X * radius, 0.5, orbit.Y * radius * 0.74)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 3 == 0 then Palette.white elseif index % 2 == 0 then Palette.cyan else Palette.pink,
			BackgroundTransparency = time:map(function(value)
				return if reducedMotion then 0.56 else 0.18 + (math.sin(value * 4 + index) * 0.5 + 0.5) * 0.56
			end),
			BorderSizePixel = 0,
			ZIndex = 723,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if index % 2 == 0 then Palette.cyan else Palette.pink,
			Thickness = 2,
			Transparency = 0.62,
		}))
	end
	for _k, _v in _newValue_3 do
		_newValue_4[_k] = _callback_4(_v, _k - 1, _newValue_3)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(0.59, 0, 0.59, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ZIndex = 721,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Thickness = 4,
		Color = Palette.pink,
		Transparency = impact:map(function(amount)
			return math.clamp(0.38 - amount * 0.35, 0.02, 0.5)
		end),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(Palette.violet, 0.78), Palette.void),
		Rotation = 90,
	}))
	local _exp_3 = React.createElement("frame", {
		Size = impact:map(function(amount)
			return UDim2.fromOffset(size * (0.12 + amount * 0.64), math.max(2, size * (0.022 - amount * 0.012)))
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = impact:map(function(amount)
			return 1 - amount * 0.96
		end),
		BorderSizePixel = 0,
		Rotation = -8,
		ZIndex = 725,
	})
	local _exp_4 = React.createElement("frame", {
		Size = impact:map(function(amount)
			return UDim2.fromOffset(math.max(2, size * (0.018 - amount * 0.008)), size * (0.12 + amount * 0.54))
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cyan,
		BackgroundTransparency = impact:map(function(amount)
			return 1 - amount * 0.85
		end),
		BorderSizePixel = 0,
		Rotation = -8,
		ZIndex = 724,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue_5 = table.create(#CRACKS)
	local _callback_5 = function(index)
		local angle = index * 45 + (index % 2) * 13
		return React.createElement("frame", {
			key = `crack-{index}`,
			Size = impact:map(function(amount)
				return UDim2.fromOffset(size * (0.05 + amount * (0.13 + (index % 3) * 0.035)), if index % 2 == 0 then 3 else 2)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			Rotation = angle,
			BackgroundColor3 = if index % 2 == 0 then Palette.white else Palette.pink,
			BackgroundTransparency = impact:map(function(amount)
				return 1 - amount * 0.88
			end),
			BorderSizePixel = 0,
			ZIndex = 726,
		})
	end
	for _k, _v in CRACKS do
		_newValue_5[_k] = _callback_5(_v, _k - 1, CRACKS)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = portalSize,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 716,
		Visible = if fade ~= nil then fade:map(function(shown)
			return shown > 0.03
		end) else true,
	}, React.createElement(ScaleFromCenter, {
		scaleRef = portalSprRef,
		zIndex = 716,
	}, _exp, _newValue_1, _newValue_2, _newValue_4, _exp_2, _exp_3, _exp_4, _newValue_5))
end
local function RewardChip(_param)
	local label = _param.label
	local value = _param.value
	local color = _param.color
	local order = _param.order
	local time = _param.time
	local reducedMotion = _param.reducedMotion
	local enter = time:map(function(amount)
		return if reducedMotion then 1 else easeOutBack(phase(amount, 2.05 + order * 0.12, 2.55 + order * 0.12))
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(154, 66),
		Position = enter:map(function(amount)
			return UDim2.new(0.5, (order - 1.5) * 164, 0.72, (1 - amount) * 34)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(color, 0.83),
		BackgroundTransparency = enter:map(function(amount)
			return 1 - amount * 0.08
		end),
		BorderSizePixel = 0,
		ZIndex = 742,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Thickness = 2,
		Color = color,
		Transparency = enter:map(function(amount)
			return 1 - amount * 0.82
		end),
	}), React.createElement(Text, {
		value = label,
		size = 9,
		color = color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(8, 8),
		sizeConstraint = UDim2.new(1, -16, 0, 14),
		transparency = enter:map(function(amount)
			return 1 - amount
		end),
	}), React.createElement(Text, {
		value = value,
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(8, 27),
		sizeConstraint = UDim2.new(1, -16, 0, 25),
		transparency = enter:map(function(amount)
			return 1 - amount
		end),
	}))
end
local function DomainExpansionOverlay(_param)
	local mode = _param.mode
	local domain = _param.domain
	local currentRebirths = _param.currentRebirths
	local currentCores = _param.currentCores
	local result = _param.result
	local busy = _param.busy
	if busy == nil then
		busy = false
	end
	local reducedMotion = _param.reducedMotion
	local onConfirm = _param.onConfirm
	local onClose = _param.onClose
	local viewport = useViewport()
	local antilag = useAntilag()
	local resultMode = mode == "result"
	local short = viewport.height < 560
	local shortLandscape = viewport.screenWidth > viewport.screenHeight and viewport.height < 440
	local compact = viewport.width < 680 and not shortLandscape
	local resultCompact = compact or shortLandscape
	local safeTop = math.max(viewport.topInset, 12)
	local safeBottom = math.max(viewport.bottomInset, 12)
	local safeHeight = math.max(240, viewport.height - safeTop - safeBottom)
	local time, setTime = React.useBinding(if reducedMotion and resultMode then 4 else 0)
	local _binding = useExitTransition(reducedMotion, 0.36)
	local leave = _binding[1]
	local leaving = _binding[2]
	local beginExit = _binding[3]
	local motionLive, setMotionLive = React.useState(false)
	local canClose, setCanClose = React.useState(not resultMode or reducedMotion)
	local start = React.useRef(os.clock())
	local leavingRef = React.useRef(leaving)
	leavingRef.current = leaving
	local portalSize = if resultMode and resultCompact then math.min(190, viewport.width * 0.46) elseif compact then math.min(230, viewport.width * 0.58) elseif short then 210 else 270
	local rayCount = if reducedMotion then 0 elseif antilag.tier <= 1 then 8 elseif antilag.tier == 2 then 12 else 18
	local boatEntrance = useBoatTween(1, if resultMode then 0.52 else 0.34, reducedMotion, easeOutCubic, 0)
	local springEntrance = useFlipperSpring(if motionLive then 1 else 0, reducedMotion, if resultMode then 520 else 660, if resultMode then 28 else 36)
	local otterEntrance = useOtterSpring(if motionLive then 1 else 0, reducedMotion, 0, if resultMode then 0.76 else 0.84, if resultMode then 3.2 else 4.2)
	React.useEffect(function()
		local token = task.defer(function()
			return setMotionLive(true)
		end)
		return function()
			return task.cancel(token)
		end
	end, {})
	React.useEffect(function()
		start.current = os.clock()
		setTime(if reducedMotion and resultMode then 4 else 0)
		if reducedMotion then
			setTime(if resultMode then 4 else 1)
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function()
			if leavingRef.current then
				return nil
			end
			setTime(os.clock() - start.current)
		end)
		return function()
			return connection:Disconnect()
		end
	end, { reducedMotion, resultMode, setTime })
	React.useEffect(function()
		setCanClose(not resultMode or reducedMotion)
	end, { reducedMotion, resultMode })
	React.useEffect(function()
		if not resultMode then
			Audio:play("domainCharge")
			return nil
		end
		if reducedMotion then
			Audio:play("domainReward")
			setCanClose(true)
			return nil
		end
		Audio:play("domainCharge")
		local crack = task.delay(0.72, function()
			return Audio:play("domainCrack")
		end)
		local impact = task.delay(1.2, function()
			Audio:play("domainImpact")
			InteractionFeedback.reward()
		end)
		local reward = task.delay(2.15, function()
			return Audio:play("domainReward")
		end)
		local ready = task.delay(2.75, function()
			return setCanClose(true)
		end)
		return function()
			task.cancel(crack)
			task.cancel(impact)
			task.cancel(reward)
			task.cancel(ready)
		end
	end, { reducedMotion, resultMode })
	local close = React.useCallback(function()
		if busy or leaving or (resultMode and not canClose) then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, busy, canClose, leaving, onClose, resultMode })
	React.useEffect(function()
		local actionName = "AstralForgeDomainClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { close })
	local timelineEnter = time:map(function(value)
		return if reducedMotion then 1 else easeOutCubic(phase(value, 0, 0.34))
	end)
	local enter = React.joinBindings({ timelineEnter, boatEntrance, springEntrance, otterEntrance, leave }):map(function(values)
		return math.clamp(math.min(values[1], values[2], values[3], values[4], values[5]), 0, 1)
	end)
	local rootTransparency = enter:map(function(inside)
		return math.clamp(1 - inside * 0.82, 0, 1)
	end)
	local impact = time:map(function(value)
		return if reducedMotion or not resultMode then 0 else pulse(value, 1.12, 1.28, 1.62)
	end)
	local titleEnter = React.joinBindings({ time, leave }):map(function(values)
		local shown = if reducedMotion then 1 else easeOutBack(phase(values[1], if resultMode then 1.22 else 0.1, if resultMode then 1.88 else 0.55))
		return shown * math.clamp(values[2], 0, 1)
	end)
	local cardEnter = React.joinBindings({ time, leave }):map(function(values)
		local shown = if reducedMotion then 1 else easeOutBack(phase(values[1], 0.04, 0.48))
		return shown * math.clamp(values[2], 0, 1)
	end)
	local cardPosition = cardEnter:map(function(amount)
		return UDim2.new(0.5, 0, 0, safeTop + safeHeight * 0.5 + (1 - amount) * 28)
	end)
	local cardScale = enter:map(function(amount)
		return 0.9 + amount * 0.1
	end)
	local _result = result
	if _result ~= nil then
		_result = _result.rank
	end
	local _condition = _result
	if _condition == nil then
		_condition = domain.Rank
	end
	local resultRank = _condition
	local contentWidth = math.min(viewport.width - math.max(24, viewport.sideInset * 2 + 20), if compact then 620 else 800)
	local cardHeight = if compact then math.min(safeHeight - 16, 580) elseif short then math.min(safeHeight - 16, 350) else math.min(safeHeight - 16, 410)
	local leftWidth = if compact then contentWidth elseif shortLandscape then math.min(280, contentWidth * 0.4) else 300
	local detailX = if compact then 18 elseif shortLandscape then leftWidth + 18 else 326
	local detailY = if compact then math.min(236, cardHeight * 0.39) else 28
	local detailWidth = if compact then contentWidth - 36 elseif shortLandscape then contentWidth - detailX - 18 else contentWidth - 350
	local detailHeight = if compact then cardHeight - detailY - 16 else cardHeight - detailY * 2
	local titleY = if shortLandscape then 14 else 20
	local titleH = if shortLandscape then 24 else 38
	local descriptionY = if shortLandscape then 40 else 62
	local descriptionH = if shortLandscape then 30 elseif compact then 54 else 48
	local requirementsY = if shortLandscape then 74 elseif compact then 122 else 116
	local requirementsH = if shortLandscape then 44 else 58
	local rewardY = if shortLandscape then 122 elseif compact then 188 else 184
	local rewardH = if shortLandscape then 18 else 30
	local actionY = if shortLandscape then 144 else detailHeight - (TapTarget + 34)
	local warningY = detailHeight - 25
	local ready = domain.CanExpand
	local rebirthReady = currentRebirths >= domain.RequiredRebirths
	local coresReady = currentCores >= domain.RequiredCores
	local padFocus = useGamepadAutofocus(true)
	local overlayHostRef = React.useRef(nil)
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current or padFocus.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			task.cancel(job)
		end
	end, { resultMode, ready })
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 700,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.fromOffset(math.max(viewport.width, viewport.height) * 1.35, math.max(viewport.width, viewport.height) * 1.35),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(Palette.violet, 0.72),
		BackgroundTransparency = time:map(function(value)
			return 0.9 - (if reducedMotion then 0.02 else math.sin(value * 1.4) * 0.025)
		end),
		BorderSizePixel = 0,
		ZIndex = 702,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.void, darken(Palette.pink, 0.62)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.52, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 28,
	}))
	local _condition_1 = resultMode
	if _condition_1 then
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(index)
			return index < (if antilag.tier <= 1 then 6 else 12)
		end
		local _length = 0
		for _k, _v in SHARDS do
			if _callback(_v, _k - 1, SHARDS) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#_newValue)
		local _callback_1 = function(index)
			local angle = index * 31 + 11
			local distance = 120 + (index % 4) * 52
			return React.createElement("frame", {
				key = `shard-{index}`,
				Size = UDim2.fromOffset(4 + index % 3, 22 + (index % 4) * 7),
				Position = time:map(function(value)
					local fly = if reducedMotion then 0.45 else easeOutQuart(phase(value, 1.18, 2.55))
					local radians = math.rad(angle)
					return UDim2.new(0.5, math.cos(radians) * distance * fly, 0.5, math.sin(radians) * distance * fly)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = time:map(function(value)
					return angle + value * (if index % 2 == 0 then 90 else -75)
				end),
				BackgroundColor3 = if index % 3 == 0 then Palette.cyan elseif index % 2 == 0 then Palette.pink else Palette.violet,
				BackgroundTransparency = React.joinBindings({ time, enter }):map(function(values)
					return math.clamp(1 - pulse(values[1], 1.16, 1.42, 3.1) * 0.9 + (1 - values[2]), 0, 1)
				end),
				BorderSizePixel = 0,
				ZIndex = 709,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}))
		end
		for _k, _v in _newValue do
			_newValue_1[_k] = _callback_1(_v, _k - 1, _newValue)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_1 = _newValue_1
	end
	local _result_1
	if resultMode then
		local _exp_2 = React.createElement(DomainPortal, {
			time = time,
			size = portalSize,
			resultMode = true,
			reducedMotion = reducedMotion,
			rayCount = rayCount,
			fade = enter,
		})
		local _exp_3 = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = impact:map(function(amount)
				return 1 - amount * 0.72
			end),
			BorderSizePixel = 0,
			Active = false,
			ZIndex = 748,
		})
		local _exp_4 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, if resultCompact then 126 else 154),
			Position = UDim2.new(0.5, 0, 0.5, if resultCompact then -42 else -54),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 750,
		}, React.createElement("textlabel", {
			Size = UDim2.new(1, -24, 0, if resultCompact then 48 else 62),
			Position = impact:map(function(amount)
				return UDim2.new(0.5, -4 - amount * 9, 0, 1)
			end),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = "DOMAIN",
			Font = Enum.Font.BuilderSansExtraBold,
			TextSize = if resultCompact then 38 else 54,
			TextColor3 = Palette.cyan,
			TextTransparency = impact:map(function(amount)
				return 1 - amount * 0.72
			end),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = false,
			ZIndex = 749,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, -24, 0, if resultCompact then 48 else 62),
			Position = impact:map(function(amount)
				return UDim2.new(0.5, 4 + amount * 9, 0, -1)
			end),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = "DOMAIN",
			Font = Enum.Font.BuilderSansExtraBold,
			TextSize = if resultCompact then 38 else 54,
			TextColor3 = Palette.pink,
			TextTransparency = impact:map(function(amount)
				return 1 - amount * 0.72
			end),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = false,
			ZIndex = 749,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, -24, 0, if resultCompact then 48 else 62),
			Position = titleEnter:map(function(amount)
				return UDim2.new(0.5, (1 - amount) * 36, 0, 0)
			end),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = "DOMAIN",
			Font = Enum.Font.BuilderSansExtraBold,
			TextSize = if resultCompact then 38 else 54,
			TextColor3 = Palette.cream,
			TextTransparency = titleEnter:map(function(amount)
				return 1 - amount
			end),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = false,
			ZIndex = 751,
		}, React.createElement("uistroke", {
			Thickness = 2,
			Color = Palette.void,
			Transparency = 0.1,
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.white, lighten(Palette.violet, 0.2)),
			Rotation = 90,
		})), React.createElement("textlabel", {
			Size = UDim2.new(1, -24, 0, if resultCompact then 48 else 62),
			Position = titleEnter:map(function(amount)
				return UDim2.new(0.5, (1 - amount) * -36, 0, if resultCompact then 42 else 54)
			end),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = "EXPANSION",
			Font = Enum.Font.BuilderSansExtraBold,
			TextSize = if resultCompact then 34 else 48,
			TextColor3 = Palette.pink,
			TextTransparency = titleEnter:map(function(amount)
				return 1 - amount
			end),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = false,
			ZIndex = 751,
		}, React.createElement("uistroke", {
			Thickness = 2,
			Color = Palette.void,
			Transparency = 0.08,
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.pink, Palette.cyan),
			Rotation = 8,
		})), React.createElement(Text, {
			value = if result ~= nil and result.nextRebirths > 0 then `DOMAIN {resultRank} COMPLETE  //  NEXT: {compactNumber(result.nextRebirths)} REBIRTHS + {compactNumber(result.nextCores)} CORES` else `DOMAIN {resultRank} COMPLETE`,
			size = 10,
			color = Palette.cyan,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 7,
			position = UDim2.fromOffset(12, if resultCompact then 90 else 116),
			sizeConstraint = UDim2.new(1, -24, 0, 18),
			transparency = titleEnter:map(function(amount)
				return 1 - amount
			end),
		}))
		local _condition_2 = not resultCompact
		if _condition_2 then
			local _attributes = {
				label = "DOMAIN ESSENCE",
			}
			local _result_2 = result
			if _result_2 ~= nil then
				_result_2 = _result_2.essence
			end
			local _condition_3 = _result_2
			if _condition_3 == nil then
				_condition_3 = 0
			end
			_attributes.value = `+{compactNumber(_condition_3)}`
			_attributes.color = Palette.pink
			_attributes.order = 0
			_attributes.time = time
			_attributes.reducedMotion = reducedMotion
			local _exp_5 = React.createElement(RewardChip, _attributes)
			local _attributes_1 = {
				label = if result ~= nil and result.overflow > 0 then "STARDUST + EXCESS" else "STARDUST",
			}
			local _result_3 = result
			if _result_3 ~= nil then
				_result_3 = _result_3.stardust
			end
			local _condition_4 = _result_3
			if _condition_4 == nil then
				_condition_4 = 0
			end
			_attributes_1.value = `+{compactNumber(_condition_4)}`
			_attributes_1.color = Palette.violet
			_attributes_1.order = 1
			_attributes_1.time = time
			_attributes_1.reducedMotion = reducedMotion
			local _exp_6 = React.createElement(RewardChip, _attributes_1)
			local _exp_7 = React.createElement(RewardChip, {
				label = "DOMAIN SURGE",
				value = "6x / 30 MIN",
				color = Palette.cyan,
				order = 2,
				time = time,
				reducedMotion = reducedMotion,
			})
			local _attributes_2 = {
				label = "FREE SPINS",
			}
			local _result_4 = result
			if _result_4 ~= nil then
				_result_4 = _result_4.freeSpins
			end
			local _condition_5 = _result_4
			if _condition_5 == nil then
				_condition_5 = 0
			end
			_attributes_2.value = `+{_condition_5}`
			_attributes_2.color = Palette.mango
			_attributes_2.order = 3
			_attributes_2.time = time
			_attributes_2.reducedMotion = reducedMotion
			_condition_2 = React.createElement(React.Fragment, nil, _exp_5, _exp_6, _exp_7, React.createElement(RewardChip, _attributes_2))
		end
		local _condition_3 = resultCompact
		if _condition_3 then
			local _exp_5 = React.createElement(AutoGrid, {
				columns = 2,
				cellHeight = if shortLandscape then 22 else 40,
				rowGap = if shortLandscape then 6 else 8,
				columnGap = 10,
			})
			local _object = {
				label = "ESSENCE",
			}
			local _left = "value"
			local _result_2 = result
			if _result_2 ~= nil then
				_result_2 = _result_2.essence
			end
			local _condition_4 = _result_2
			if _condition_4 == nil then
				_condition_4 = 0
			end
			_object[_left] = `+{compactNumber(_condition_4)}`
			_object.color = Palette.pink
			local _object_1 = {
				label = if result ~= nil and result.overflow > 0 then `DUST (+{compactNumber(result.overflow)} EXCESS)` else "STARDUST",
			}
			local _left_1 = "value"
			local _result_3 = result
			if _result_3 ~= nil then
				_result_3 = _result_3.stardust
			end
			local _condition_5 = _result_3
			if _condition_5 == nil then
				_condition_5 = 0
			end
			_object_1[_left_1] = `+{compactNumber(_condition_5)}`
			_object_1.color = Palette.violet
			local _exp_6 = {
				label = "SURGE",
				value = "6x / 30 MIN",
				color = Palette.cyan,
			}
			local _object_2 = {
				label = "SPINS",
			}
			local _left_2 = "value"
			local _result_4 = result
			if _result_4 ~= nil then
				_result_4 = _result_4.freeSpins
			end
			local _condition_6 = _result_4
			if _condition_6 == nil then
				_condition_6 = 0
			end
			_object_2[_left_2] = `+{_condition_6}`
			_object_2.color = Palette.mango
			local _exp_7 = { _object, _object_1, _exp_6, _object_2 }
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#_exp_7)
			local _callback = function(reward, index)
				return React.createElement("frame", {
					key = reward.label,
					BackgroundColor3 = darken(reward.color, 0.86),
					BackgroundTransparency = time:map(function(amount)
						return 1 - (if reducedMotion then 0.96 else phase(amount, 2.05 + index * 0.08, 2.46 + index * 0.08)) * 0.96
					end),
					BorderSizePixel = 0,
					LayoutOrder = index,
					ZIndex = 753,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 9),
				}), React.createElement("uistroke", {
					Color = reward.color,
					Thickness = 1,
					Transparency = 0.5,
				}), React.createElement(Text, {
					value = reward.label,
					size = 8,
					color = reward.color,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(8, 4),
					sizeConstraint = UDim2.new(0.48, -10, 1, -8),
					transparency = time:map(function(amount)
						return 1 - (if reducedMotion then 1 else phase(amount, 2.05 + index * 0.08, 2.46 + index * 0.08))
					end),
				}), React.createElement(Text, {
					value = reward.value,
					size = 12,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(0.48, 0, 0, 4),
					sizeConstraint = UDim2.new(0.52, -8, 1, -8),
					transparency = time:map(function(amount)
						return 1 - (if reducedMotion then 1 else phase(amount, 2.05 + index * 0.08, 2.46 + index * 0.08))
					end),
				}))
			end
			for _k, _v in _exp_7 do
				_newValue[_k] = _callback(_v, _k - 1, _exp_7)
			end
			-- ▲ ReadonlyArray.map ▲
			_condition_3 = React.createElement("frame", {
				Size = UDim2.new(1, -30, 0, if shortLandscape then 50 else 88),
				Position = UDim2.new(0.5, 0, if shortLandscape then 0.58 else 0.67, 4),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 752,
			}, _exp_5, _newValue)
		end
		_result_1 = React.createElement(React.Fragment, nil, _exp_2, _exp_3, _exp_4, _condition_2, _condition_3, React.createElement("frame", {
			Size = UDim2.fromOffset(math.min(260, viewport.width - 32), TapTarget),
			Position = UDim2.new(0.5, 0, 1, -(math.max(viewport.bottomInset, 12) + TapTarget + 14)),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 760,
		}, React.createElement(Button, {
			text = if canClose then "CONTINUE" else "HOLD ON...",
			icon = "Domain",
			onClick = close,
			color = if canClose then Palette.pink else Palette.panelSoft,
			textColor = if canClose then Palette.cream else Palette.muted,
			size = UDim2.fromScale(1, 1),
			disabled = not canClose or leaving,
			reducedMotion = reducedMotion,
			highlight = canClose,
			zIndex = 761,
		})))
	else
		_result_1 = React.createElement("frame", {
			Size = UDim2.fromOffset(contentWidth, cardHeight),
			Position = cardPosition,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 730,
			ClipsDescendants = false,
		}, React.createElement(ScaleFromCenter, {
			scale = cardScale,
			zIndex = 730,
		}, React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.night,
			BackgroundTransparency = enter:map(function(amount)
				return 1 - amount * 0.99
			end),
			BorderSizePixel = 0,
			ZIndex = 730,
			ClipsDescendants = false,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 20),
		}), React.createElement("uistroke", {
			Thickness = 2,
			Color = if ready then Palette.pink else Palette.violet,
			Transparency = 0.08,
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(darken(Palette.violet, 0.82), Palette.void),
			Rotation = 22,
		}), React.createElement("frame", {
			Size = UDim2.fromOffset(leftWidth, if compact then 196 else cardHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 732,
		}, React.createElement(DomainPortal, {
			time = time,
			size = portalSize,
			resultMode = false,
			reducedMotion = reducedMotion,
			rayCount = math.min(rayCount, 12),
			fade = enter,
		}), React.createElement(Text, {
			value = `DOMAIN {domain.Rank + 1}`,
			size = 10,
			color = Palette.pink,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, 0, 1, if compact then -24 else -42),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(detailWidth, detailHeight),
			Position = UDim2.fromOffset(detailX, detailY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 734,
		}, React.createElement(Text, {
			value = "DOMAIN EXPANSION",
			size = 10,
			color = Palette.pink,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, -36, 0, 16),
		}), React.createElement(Text, {
			value = "Spend cores. Keep the permanent stuff.",
			size = if shortLandscape then 18 elseif compact then 21 else 25,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(0, titleY),
			sizeConstraint = UDim2.new(1, -8, 0, titleH),
		}), React.createElement(Text, {
			value = "Costs rebirths and cores. This run's machines, flux, vault, and worlds reset. Research, Star Grid, relics, crew, milestones, guild, and Stardust stay.",
			size = if shortLandscape then 8 elseif compact then 11 else 10,
			color = Palette.creamSoft,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(0, descriptionY),
			sizeConstraint = UDim2.new(1, -6, 0, descriptionH),
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, requirementsH),
			Position = UDim2.fromOffset(0, requirementsY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 735,
		}, React.createElement("frame", {
			Size = UDim2.new(0.5, -5, 1, 0),
			BackgroundColor3 = darken(requirementColor(rebirthReady), 0.86),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Thickness = 1,
			Color = requirementColor(rebirthReady),
			Transparency = 0.48,
		}), React.createElement(Text, {
			value = "REBIRTHS",
			size = 8,
			color = Palette.muted,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(10, if shortLandscape then 5 else 8),
			sizeConstraint = UDim2.new(1, -20, 0, 12),
		}), React.createElement(Text, {
			value = `{compactNumber(currentRebirths)} / {compactNumber(domain.RequiredRebirths)}`,
			size = if shortLandscape then 13 else 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(10, if shortLandscape then 18 else 24),
			sizeConstraint = UDim2.new(1, -20, 0, if shortLandscape then 20 else 23),
		})), React.createElement("frame", {
			Size = UDim2.new(0.5, -5, 1, 0),
			Position = UDim2.new(0.5, 5, 0, 0),
			BackgroundColor3 = darken(requirementColor(coresReady), 0.86),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Thickness = 1,
			Color = requirementColor(coresReady),
			Transparency = 0.48,
		}), React.createElement(Text, {
			value = "ASTRAL CORES",
			size = 8,
			color = Palette.muted,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(10, if shortLandscape then 5 else 8),
			sizeConstraint = UDim2.new(1, -20, 0, 12),
		}), React.createElement(Text, {
			value = `{compactNumber(currentCores)} / {compactNumber(domain.RequiredCores)}`,
			size = if shortLandscape then 13 else 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(10, if shortLandscape then 18 else 24),
			sizeConstraint = UDim2.new(1, -20, 0, if shortLandscape then 20 else 23),
		}))), React.createElement(Text, {
			value = `REWARD  +{domain.EssenceReward} essence  /  +{compactNumber(domain.StardustReward)} stardust  /  6x surge  /  8 stored boosts`,
			size = if shortLandscape then 7 else 9,
			color = if ready then Palette.green else Palette.mango,
			weight = Enum.FontWeight.Heavy,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(0, rewardY),
			sizeConstraint = UDim2.new(1, 0, 0, rewardH),
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, TapTarget),
			Position = UDim2.fromOffset(0, actionY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 740,
		}, React.createElement(Button, {
			text = if busy then "OPENING..." elseif ready then "OPEN DOMAIN" else "NOT READY YET",
			icon = "Domain",
			onClick = function()
				local _result_2 = onConfirm
				if _result_2 ~= nil then
					_result_2 = _result_2()
				end
				return _result_2
			end,
			color = if ready then Palette.pink else Palette.panelSoft,
			textColor = if ready then Palette.cream else Palette.muted,
			size = UDim2.fromScale(1, 1),
			disabled = not ready or busy,
			reducedMotion = reducedMotion,
			highlight = ready and not busy,
			zIndex = 741,
		})), not shortLandscape and React.createElement(Text, {
			value = "You can't undo this.",
			size = 9,
			color = Palette.coral,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, warningY),
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(TapTarget, TapTarget),
			Position = UDim2.new(1, -(TapTarget + 10), 0, 10),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 750,
		}, React.createElement(Button, {
			text = "",
			icon = "Close",
			onClick = close,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = leaving,
			zIndex = 751,
		})))))
	end
	return React.createElement(OverlayPresence, {
		amount = enter,
	}, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = rootTransparency,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 700,
		ClipsDescendants = true,
		Visible = enter:map(function(amount)
			return amount > 0.02
		end),
	}, _exp, _exp_1, _condition_1, _result_1))
end
return {
	DomainExpansionOverlay = DomainExpansionOverlay,
}
