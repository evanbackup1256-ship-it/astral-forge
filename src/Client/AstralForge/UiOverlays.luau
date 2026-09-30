--!nonstrict
--[=[
	UiOverlays: merged module suite.
	Members (5): DomainExpansionOverlay, DomainSkillTree, purchaseOverlay, MobileControls, floorFx.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("UiOverlays: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("UiOverlays: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: DomainExpansionOverlay   (merged from DomainExpansionOverlay.luau, 1175 lines)
-- ======================================================================
__defs["DomainExpansionOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local AutoGrid = require(script.Parent.LayoutKit)("scrolling").AutoGrid
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local easeOutQuart = _motion.easeOutQuart
local CanvasEnergyField = require(script.Parent.UiCore)("effects").CanvasEnergyField
local bezierOrbit = require(script.Parent.MotionKit)("motion").bezierOrbit
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local _motion_1 = require(script.Parent.MotionKit)("motion")
local ScaleFromCenter = _motion_1.ScaleFromCenter
local useBoatTween = _motion_1.useBoatTween
local useExitTransition = _motion_1.useExitTransition
local useFlipperSpring = _motion_1.useFlipperSpring
local useOtterSpring = _motion_1.useOtterSpring
local useSprScale = _motion_1.useSprScale
local useViewport = _motion_1.useViewport
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — DomainExpansionOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local rayCount = _param.rayCount
	local fade = _param.fade
	local portalSprRef = useSprScale(1, reducedMotion, 0.78, 0.66, if resultMode then 7.5 else 6.5)
	local reveal = time:map(function(value)
		return easeOutBack(phase(value, if resultMode then 0.32 else 0, if resultMode then 1.15 else 0.42))
	end)
	local impact = time:map(function(value)
		return if not resultMode then 0 else pulse(value, 1.08, 1.28, 1.7)
	end)
	local spin = time:map(function(value)
		local rate = if reducedMotion then 0.55 else 1
		return value * rate * (if resultMode then 34 else 12)
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — DomainExpansionOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — DomainExpansionOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local time, setTime = React.useBinding(0)
	local _binding = useExitTransition(softMotion, 0.36)
	local leave = _binding[1]
	local leaving = _binding[2]
	local beginExit = _binding[3]
	local motionLive, setMotionLive = React.useState(false)
	local canClose, setCanClose = React.useState(not resultMode)
	local start = React.useRef(os.clock())
	local leavingRef = React.useRef(leaving)
	leavingRef.current = leaving
	local portalSize = if resultMode and resultCompact then math.min(190, viewport.width * 0.46) elseif compact then math.min(230, viewport.width * 0.58) elseif short then 210 else 270
	local rayCount = if antilag.tier <= 1 or softMotion then 8 elseif antilag.tier == 2 then 12 else 18
	local boatEntrance = useBoatTween(1, if resultMode then 0.52 else 0.34, softMotion, easeOutCubic, 0)
	local springEntrance = useFlipperSpring(if motionLive then 1 else 0, softMotion, if resultMode then 520 else 660, if resultMode then 28 else 36)
	local otterEntrance = useOtterSpring(if motionLive then 1 else 0, softMotion, 0, if resultMode then 0.76 else 0.84, if resultMode then 3.2 else 4.2)
	React.useEffect(function()
		local alive = true
		local token = task.defer(function()
			if alive then
				setMotionLive(true)
			end
		end)
		return function()
			-- A defer that already ran is a dead thread. task.cancel throws on it
			-- and would skip later effect cleanups for this overlay.
			alive = false
			pcall(task.cancel, token)
		end
	end, {})
	React.useEffect(function()
		start.current = os.clock()
		setTime(0)
		local speed = if reducedMotion then 1.8 else 1
		local connection = RunService.RenderStepped:Connect(function()
			if leavingRef.current then
				return nil
			end
			setTime((os.clock() - start.current) * speed)
		end)
		return function()
			return connection:Disconnect()
		end
	end, { reducedMotion, setTime })
	React.useEffect(function()
		if not resultMode then
			Audio:play("domainCharge")
			return nil
		end
		Audio:play("domainCharge")
		local alive = true
		local cue = if reducedMotion then 0.55 else 1
		local crack = task.delay(0.72 * cue, function()
			if alive then
				Audio:play("domainCrack")
			end
		end)
		local impact = task.delay(1.2 * cue, function()
			if not alive then
				return nil
			end
			Audio:play("domainImpact")
			if alive then
				InteractionFeedback.reward()
			end
		end)
		local reward = task.delay(2.15 * cue, function()
			if alive then
				Audio:play("domainReward")
			end
		end)
		local ready = task.delay(2.75 * cue, function()
			if alive then
				setCanClose(true)
			end
		end)
		return function()
			-- Timers that already fired are dead threads. task.cancel throws on those
			-- and would leave the later cues still scheduled after the overlay is gone.
			alive = false
			pcall(task.cancel, crack)
			pcall(task.cancel, impact)
			pcall(task.cancel, reward)
			pcall(task.cancel, ready)
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
		return easeOutCubic(phase(value, 0, 0.34))
	end)
	local enter = React.joinBindings({ timelineEnter, boatEntrance, springEntrance, otterEntrance, leave }):map(function(values)
		return math.clamp(math.min(values[1], values[2], values[3], values[4], values[5]), 0, 1)
	end)
	local rootTransparency = enter:map(function(inside)
		return math.clamp(1 - inside * 0.82, 0, 1)
	end)
	local impact = time:map(function(value)
		return if not resultMode then 0 else pulse(value, 1.12, 1.28, 1.62)
	end)
	local titleEnter = React.joinBindings({ time, leave }):map(function(values)
		local shown = easeOutBack(phase(values[1], if resultMode then 1.22 else 0.1, if resultMode then 1.88 else 0.55))
		return shown * math.clamp(values[2], 0, 1)
	end)
	local cardEnter = React.joinBindings({ time, leave }):map(function(values)
		local shown = easeOutBack(phase(values[1], 0.04, 0.48))
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
		local alive = true
		local job = task.defer(function()
			if not alive or host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
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
			reducedMotion = softMotion,
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
			_attributes.reducedMotion = softMotion
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
end

-- ======================================================================
-- Module: DomainSkillTree   (merged from DomainSkillTree.luau, 1125 lines)
-- ======================================================================
__defs["DomainSkillTree"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useButtonChrome = _ui.useButtonChrome
local NODES = { {
	id = "FluxVein",
	name = "Flux Vein",
	body = "+12% production",
	lore = "A live current under the floor.",
	cost = 2,
	requires = {},
	icon = "Flux",
	accent = Palette.cyan,
	x = 0.16,
	y = 0.2,
}, {
	id = "VaultLattice",
	name = "Vault Lattice",
	body = "+18% vault size",
	lore = "More hours banked before overflow.",
	cost = 2,
	requires = {},
	icon = "Vault",
	accent = Palette.mango,
	x = 0.39,
	y = 0.12,
}, {
	id = "EmberCore",
	name = "Ember Core",
	body = "+15% overcharge",
	lore = "Heat that answers a tap.",
	cost = 2,
	requires = {},
	icon = "Overcharge",
	accent = Palette.coral,
	x = 0.61,
	y = 0.12,
}, {
	id = "NightHarvest",
	name = "Night Harvest",
	body = "+8% offline",
	lore = "The forge works the dark shift.",
	cost = 2,
	requires = {},
	icon = "Timer",
	accent = Palette.violet,
	x = 0.84,
	y = 0.2,
}, {
	id = "StarWell",
	name = "Star Well",
	body = "+10% production",
	lore = "Draws from the first bound vein.",
	cost = 3,
	requires = { "FluxVein" },
	icon = "Forge",
	accent = Palette.cyan,
	x = 0.22,
	y = 0.46,
}, {
	id = "PrismGate",
	name = "Prism Gate",
	body = "+6% crate luck",
	lore = "Splits chance into cleaner odds.",
	cost = 3,
	requires = { "VaultLattice" },
	icon = "Crate",
	accent = Palette.pink,
	x = 0.4,
	y = 0.4,
}, {
	id = "EchoChamber",
	name = "Echo Chamber",
	body = "Echoes charge faster",
	lore = "Repeats a strike until it lands.",
	cost = 3,
	requires = { "EmberCore" },
	icon = "Wave",
	accent = Palette.mint,
	x = 0.6,
	y = 0.4,
}, {
	id = "HorizonKey",
	name = "Horizon Key",
	body = "Cheaper worlds",
	lore = "Unlocks the next gate for less.",
	cost = 3,
	requires = { "NightHarvest" },
	icon = "World",
	accent = Palette.violet,
	x = 0.78,
	y = 0.46,
}, {
	id = "RealityAnchor",
	name = "Reality Anchor",
	body = "+25% rebirth cores",
	lore = "Keeps more of what a reset forges.",
	cost = 4,
	requires = { "StarWell" },
	icon = "Core",
	accent = Palette.mango,
	x = 0.28,
	y = 0.7,
}, {
	id = "DomainPulse",
	name = "Domain Pulse",
	body = "+1 essence / expand",
	lore = "Each expansion leaves more residue.",
	cost = 4,
	requires = { "PrismGate" },
	icon = "Domain",
	accent = Palette.pink,
	x = 0.46,
	y = 0.66,
}, {
	id = "ContinuumBind",
	name = "Continuum Bind",
	body = "Cheaper continuum",
	lore = "Ranks cost less to hold.",
	cost = 4,
	requires = { "EchoChamber" },
	icon = "Rebirth",
	accent = Palette.cyan,
	x = 0.64,
	y = 0.7,
}, {
	id = "OverchargeChannel",
	name = "Overcharge Channel",
	body = "+20% crit chance",
	lore = "Two anchors share one strike.",
	cost = 5,
	requires = { "RealityAnchor", "DomainPulse" },
	icon = "Jackpot",
	accent = Palette.coral,
	x = 0.5,
	y = 0.9,
}, {
	id = "TideLock",
	name = "Tide Lock",
	body = "Cheaper world hops",
	lore = "Keeps the next gate from drifting.",
	cost = 4,
	requires = { "HorizonKey" },
	icon = "World",
	accent = Palette.violet,
	x = 0.88,
	y = 0.68,
}, {
	id = "VaultHeartNode",
	name = "Vault Heart",
	body = "+14% vault size",
	lore = "A second lock on the same bank.",
	cost = 4,
	requires = { "PrismGate" },
	icon = "Vault",
	accent = Palette.mango,
	x = 0.32,
	y = 0.58,
}, {
	id = "EmberWell",
	name = "Ember Well",
	body = "+12% overcharge",
	lore = "Stores heat between taps.",
	cost = 4,
	requires = { "EchoChamber" },
	icon = "Overcharge",
	accent = Palette.coral,
	x = 0.72,
	y = 0.58,
}, {
	id = "ApexLattice",
	name = "Apex Lattice",
	body = "+8% all production",
	lore = "The last bind that holds the rest.",
	cost = 6,
	requires = { "OverchargeChannel", "ContinuumBind" },
	icon = "Domain",
	accent = Palette.pink,
	x = 0.68,
	y = 0.92,
} }
local VEINS = { {
	from = "FluxVein",
	to = "StarWell",
}, {
	from = "StarWell",
	to = "RealityAnchor",
}, {
	from = "RealityAnchor",
	to = "OverchargeChannel",
}, {
	from = "VaultLattice",
	to = "PrismGate",
}, {
	from = "PrismGate",
	to = "DomainPulse",
}, {
	from = "PrismGate",
	to = "VaultHeartNode",
}, {
	from = "DomainPulse",
	to = "OverchargeChannel",
}, {
	from = "EmberCore",
	to = "EchoChamber",
}, {
	from = "EchoChamber",
	to = "ContinuumBind",
}, {
	from = "EchoChamber",
	to = "EmberWell",
}, {
	from = "NightHarvest",
	to = "HorizonKey",
}, {
	from = "HorizonKey",
	to = "TideLock",
}, {
	from = "OverchargeChannel",
	to = "ApexLattice",
}, {
	from = "ContinuumBind",
	to = "ApexLattice",
} }
local function nodeById(id)
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(node)
		return node.id == id
	end
	local _result
	for _i, _v in NODES do
		if _callback(_v, _i - 1, NODES) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result
	if _condition == nil then
		_condition = NODES[1]
	end
	return _condition
end
local function LatticeField(_param)
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local drift = useClock(not reducedMotion, 0.04, 1)
	local curtains = {
		{ y = 0.18, h = 0.22, color = accent, slide = 0.08 },
		{ y = 0.42, h = 0.28, color = Palette.violet, slide = -0.06 },
		{ y = 0.66, h = 0.2, color = Palette.cyan, slide = 0.05 },
	}
	local bands = table.create(#curtains)
	for index, curtain in curtains do
		bands[index] = React.createElement("frame", {
			key = `aurora-{index}`,
			Size = UDim2.fromScale(1.4, curtain.h),
			Position = drift:map(function(phase)
				local wave = math.sin(phase * math.pi * 2 + index) * curtain.slide
				return UDim2.new(-0.2 + wave, 0, curtain.y, 0)
			end),
			BackgroundColor3 = curtain.color,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, React.createElement("uigradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.15),
				NumberSequenceKeypoint.new(0.7, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 18 + index * 12,
		}))
	end
	local seeds = { 0, 1, 2, 3, 4, 5, 6, 7 }
	local motes = table.create(#seeds)
	for index, seed in seeds do
		local color = if seed % 3 == 0 then accent elseif seed % 3 == 1 then Palette.cyan else Palette.violet
		motes[index] = React.createElement("frame", {
			key = `mote-{seed}`,
			Size = UDim2.fromOffset(if seed % 2 == 0 then 5 else 3, if seed % 2 == 0 then 5 else 3),
			Position = drift:map(function(phase)
				local t = (phase + seed * 0.13) % 1
				local x = (seed * 0.11 + math.sin(t * math.pi * 2) * 0.04) % 1
				local y = (0.12 + seed * 0.09 + t * 0.22) % 1
				return UDim2.fromScale(x, y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, bands, motes)
end
local function BranchVein(_param)
	local from = _param.from
	local to = _param.to
	local live = _param.live
	local selected = _param.selected
	local reducedMotion = _param.reducedMotion
	local pulse = useClock(live and selected and not reducedMotion, 0.9, 1)
	local accent = if live then from.accent else Palette.lineSoft
	local steps = if selected then 8 elseif live then 6 else 4
	local marks = table.create(steps)
	for step = 1, steps do
		marks[step] = step / (steps + 1)
	end
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#marks)
	local _callback = function(alpha)
		return React.createElement("frame", {
			key = `seg-{alpha}`,
			Size = UDim2.fromOffset(if selected then 8 else 4, if alpha > 0.45 and alpha < 0.55 then 10 else 4),
			Position = UDim2.fromScale(from.x + (to.x - from.x) * alpha, from.y + (to.y - from.y) * alpha),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = if live then 0.18 else 0.68,
			BorderSizePixel = 0,
			ZIndex = 8,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in marks do
		_newValue[_k] = _callback(_v, _k - 1, marks)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, _newValue, live and selected and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = pulse:map(function(phase)
			return UDim2.fromScale(from.x + (to.x - from.x) * phase, from.y + (to.y - from.y) * phase)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function NodeOrnament(_param)
	local node = _param.node
	local owned = _param.owned
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local beat = usePulse((owned or ready) and not reducedMotion, if owned then 1.4 else 2.1)
	if not owned and not ready then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if owned then 9 else 7, if owned then 9 else 7),
		Position = UDim2.new(1, -4, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = node.accent,
		BackgroundTransparency = beat:map(function(amount)
			return 0.08 + (1 - amount) * 0.35
		end),
		BorderSizePixel = 0,
		ZIndex = 44,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
end
local function HexNode(_param)
	local node = _param.node
	local owned = _param.owned
	local ready = _param.ready
	local selected = _param.selected
	local bound = _param.bound
	local reducedMotion = _param.reducedMotion
	local onSelect = _param.onSelect
	local index = _param.index
	local nodeSize = _param.nodeSize
	local padX = _param.padX
	local padY = _param.padY
	local chrome = useButtonChrome(function()
		Audio:play(if owned then "tick" elseif ready then "domainCharge" else "locked")
		onSelect()
	end, reducedMotion, false, false, true)
	local reveal = useStagger(index, reducedMotion, 0.02, 0.2)
	local pulse = usePulse(ready and not owned and not reducedMotion, 1.7)
	local ownedGlow = usePulse(owned and not reducedMotion, 1.15)
	local lift = useFlipperSpring(if selected then 1 elseif ready then 0.55 elseif owned then 0.25 else 0, reducedMotion, 620, 34)
	local bindPop = useFlash(if bound then 1 else 0, reducedMotion, 0.55)
	local size = if selected then nodeSize + 8 else nodeSize
	local hitSize = math.max(size, TapTarget)
	local fill = if owned then darken(node.accent, 0.28) elseif ready then darken(node.accent, 0.62) else Palette.panel
	local x = padX + node.x * (1 - padX * 2)
	local y = padY + node.y * (1 - padY * 2)
	return React.createElement("imagebutton", {
		Size = UDim2.fromOffset(hitSize, hitSize),
		Position = React.joinBindings({ lift, bindPop }):map(function(values)
			local _exp = UDim2.fromScale(x, y)
			local _arg0 = UDim2.fromOffset(0, math.round(-values[1] * 10 - values[2] * 6))
			return _exp + _arg0
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ZIndex = 40,
		Event = chrome.events,
	}, React.createElement(ScaleFromCenter, {
		scale = React.joinBindings({ reveal, bindPop, chrome.touchScale }):map(function(values)
			return (0.62 + values[1] * 0.38) * (1 + values[2] * 0.28) * values[3]
		end),
		zIndex = 40,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 40,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if selected or owned then Palette.cream elseif ready then node.accent else Palette.lineSoft,
		Thickness = if selected then 2.4 else 1.4,
		Transparency = if owned then 0.12 elseif ready then 0.28 else 0.55,
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(fill, 0.22), darken(fill, 0.12)),
		Rotation = 90,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		live = chrome.shimmerLive,
		zIndex = 41,
		radius = math.floor(size / 2),
	}), ready and not owned and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = node.accent,
		BackgroundTransparency = pulse:map(function(amount)
			return 0.78 + (1 - amount) * 0.14
		end),
		BorderSizePixel = 0,
		ZIndex = 41,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), owned and React.createElement("frame", {
		Size = UDim2.new(0.48, 0, 0, 3),
		Position = UDim2.new(0.5, 0, 1, -5),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = node.accent,
		BackgroundTransparency = ownedGlow:map(function(amount)
			return 0.08 + (1 - amount) * 0.4
		end),
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), selected and React.createElement("frame", {
		Size = UDim2.new(0.58, 0, 0, 2),
		Position = UDim2.new(0.5, 0, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), bound and React.createElement("frame", {
		Size = bindPop:map(function(amount)
			return UDim2.fromScale(1 + amount * 1.4, 1 + amount * 1.4)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 45,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = node.accent,
		Thickness = bindPop:map(function(amount)
			return 3 - amount * 2
		end),
		Transparency = bindPop:map(function(amount)
			return 0.08 + amount * 0.9
		end),
	}))), React.createElement(NodeOrnament, {
		node = node,
		owned = owned,
		ready = ready,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(math.floor(size * 0.58), math.floor(size * 0.58)),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 43,
	}, React.createElement(Icon, {
		kind = node.icon,
		color = if owned or ready or selected then Palette.cream else Palette.muted,
		accent = node.accent,
		size = math.floor(size * 0.42),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = (selected or bound) and not reducedMotion,
		reducedMotion = reducedMotion,
	}))))
end
local function DomainSkillTree(_param)
	local domain = _param.domain
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local selectedId, setSelectedId = React.useState()
	local busy, setBusy = React.useState(false)
	local binds, setBinds = React.useState(0)
	local burstId, setBurstId = React.useState()
	local pan, setPan = React.useState({
		x = 0,
		y = 0,
	})
	local drag = React.useRef()
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion, 0.28)
	local leave = _binding[1]
	local leaving = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local flash = useFlash(binds, reducedMotion, 0.7)
	local headerIn = useStagger(1, reducedMotion, 0.04, 0.28)
	local footerIn = useStagger(2, reducedMotion, 0.05, 0.3)
	local nodeSize = if stack then (if viewport.height < 640 then 40 else 48) elseif viewport.width < 1280 then 54 else 60
	local padX = if stack then 0.08 else 0.04
	local padY = if stack then 0.08 else 0.05
	local side = chrome.sideSafe + (if stack then 10 else 0)
	local panelW = if stack then math.max(300, math.min(viewport.width - math.max(20, side * 2), math.floor(viewport.width * 0.96))) else math.min(math.max(760, math.floor(viewport.width * 0.78)), viewport.width - 48)
	local headerH = if stack then 62 else 58
	local footerH = if stack then 126 else 64
	local treeGap = 8
	local panelH = if stack then math.min(viewport.height - math.max(28, chrome.bottomSafe + viewport.topInset + 20), math.max(420, math.floor(viewport.height * 0.86))) else math.min(viewport.height - 56, math.max(560, math.floor(viewport.height * 0.8)))
	local liveFx = not reducedMotion and not leaving
	local close = function()
		if leaving then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end
	local overlayHostRef = React.useRef(nil)
	local alive = React.useRef(true)
	React.useEffect(function()
		alive.current = true
		return function()
			alive.current = false
		end
	end, {})
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
		local host = overlayHostRef.current
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
	end, {})
	local cardTravel = if stack then 22 else 18
	local cardPosition = motion:map(function(amount)
		local _exp = UDim2.fromScale(0.5, 0.5)
		local _arg0 = UDim2.fromOffset(0, math.round((1 - amount) * cardTravel))
		return _exp + _arg0
	end)
	local scrimTransparency = motion:map(function(amount)
		return 1 - amount * 0.52
	end)
	local cardScale = motion:map(function(amount)
		return 0.9 + amount * 0.1
	end)
	local nodes = domain.Nodes or {}
	local nodeOwned = function(id)
		return nodes[id] == true
	end
	local _condition = domain.SkillPoints
	if _condition == nil then
		_condition = 0
	end
	local points = _condition
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(node)
		return node.id == selectedId
	end
	local _result
	for _i, _v in NODES do
		if _callback(_v, _i - 1, NODES) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = NODES[1]
	end
	local selected = _condition_1
	local owned = selected ~= nil and nodeOwned(selected.id)
	local _condition_2 = selected ~= nil
	if _condition_2 then
		local _exp = selected.requires
		-- ▼ ReadonlyArray.every ▼
		local _result_1 = true
		local _callback_1 = function(id)
			return nodeOwned(id)
		end
		for _k, _v in _exp do
			if not _callback_1(_v, _k - 1, _exp) then
				_result_1 = false
				break
			end
		end
		-- ▲ ReadonlyArray.every ▲
		_condition_2 = _result_1
	end
	local prereqs = _condition_2
	local canBuy = selected ~= nil and not owned and prereqs and points >= selected.cost and not busy
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_1 = function(total, node)
		return total + (if nodeOwned(node.id) then 1 else 0)
	end
	for _i = 1, #NODES do
		_result_1 = _callback_1(_result_1, NODES[_i], _i - 1, NODES)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local boundCount = _result_1
	React.useEffect(function()
		Audio:play("domainCrack")
	end, {})
	React.useEffect(function()
		local moved = UserInputService.InputChanged:Connect(function(input)
			local hold = drag.current
			if hold == nil then
				return nil
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			setPan({
				x = math.clamp(hold.ox + input.Position.X - hold.x, -90, 90),
				y = math.clamp(hold.oy + input.Position.Y - hold.y, -70, 70),
			})
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				drag.current = nil
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, {})
	local unlock = function()
		if selected == nil or not canBuy then
			return nil
		end
		setBusy(true)
		Audio:play("domainImpact")
		dispatch("UnlockDomainNode", {
			Id = selected.id,
		}, function(response)
			if not alive.current then
				return nil
			end
			setBusy(false)
			if type(response) == "table" and response.ok then
				Audio:play("domainBind")
				Audio:play("domainReward")
				setBurstId(selected.id)
				setBinds(function(current)
					return current + 1
				end)
			else
				Audio:play("locked")
			end
		end)
	end
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 700,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 701,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, if stack then 16 else 18),
	}))
	local _exp_2 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, if stack then 16 else 18),
	})
	local _exp_3 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.pink,
		Thickness = 2,
		Transparency = flash:map(function(amount)
			return 0.22 - amount * 0.12
		end),
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, headerH),
		Position = headerIn:map(function(amount)
			return UDim2.fromOffset(10, 8 + math.round((1 - amount) * 10))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 720,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = darken(Palette.pink, 0.55),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.pink,
		Thickness = 1,
		Transparency = 0.2,
	}), React.createElement(Text, {
		value = `{domain.Rank}`,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	})), React.createElement(Text, {
		value = "DOMAIN LATTICE",
		size = 9,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 7,
		position = UDim2.fromOffset(50, 4),
		sizeConstraint = UDim2.new(1, if stack then -166 else -210, 0, 12),
	}), React.createElement(Text, {
		value = "Bind a branch.",
		size = if stack then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(50, 18),
		sizeConstraint = UDim2.new(1, if stack then -166 else -210, 0, 22),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 40),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = 0.35,
	}), React.createElement(Text, {
		value = `{points}`,
		size = 16,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 1),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = "POINTS",
		size = 8,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 12),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 40),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.35,
	}), React.createElement(Text, {
		value = `{boundCount}/{#NODES}`,
		size = 16,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 1),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = "BOUND",
		size = 8,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 12),
	}))))
	local _exp_5 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _attributes = {
		reducedMotion = not liveFx,
	}
	local _result_2 = selected
	if _result_2 ~= nil then
		_result_2 = _result_2.accent
	end
	local _condition_3 = _result_2
	if _condition_3 == nil then
		_condition_3 = Palette.pink
	end
	_attributes.accent = _condition_3
	local _exp_6 = React.createElement(LatticeField, _attributes)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#VEINS)
	local _callback_2 = function(vein)
		local from = nodeById(vein.from)
		local to = nodeById(vein.to)
		local live = nodeOwned(vein.from)
		local selectedVein = selectedId == vein.from or selectedId == vein.to
		local _object = table.clone(from)
		setmetatable(_object, nil)
		_object.x = padX + from.x * (1 - padX * 2)
		_object.y = padY + from.y * (1 - padY * 2)
		local fromPad = _object
		local _object_1 = table.clone(to)
		setmetatable(_object_1, nil)
		_object_1.x = padX + to.x * (1 - padX * 2)
		_object_1.y = padY + to.y * (1 - padY * 2)
		local toPad = _object_1
		return React.createElement(BranchVein, {
			key = `{vein.from}-{vein.to}`,
			from = fromPad,
			to = toPad,
			live = live and liveFx,
			selected = selectedVein,
			reducedMotion = not liveFx,
		})
	end
	for _k, _v in VEINS do
		_newValue[_k] = _callback_2(_v, _k - 1, VEINS)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#NODES)
	local _callback_3 = function(node, index)
		local isOwned = nodeOwned(node.id)
		local _condition_4 = not isOwned
		if _condition_4 then
			local _exp_7 = node.requires
			-- ▼ ReadonlyArray.every ▼
			local _result_3 = true
			local _callback_4 = function(id)
				return nodeOwned(id)
			end
			for _k, _v in _exp_7 do
				if not _callback_4(_v, _k - 1, _exp_7) then
					_result_3 = false
					break
				end
			end
			-- ▲ ReadonlyArray.every ▲
			_condition_4 = _result_3
			if _condition_4 then
				_condition_4 = points >= node.cost
			end
		end
		local ready = _condition_4
		return React.createElement(HexNode, {
			key = node.id,
			node = node,
			owned = isOwned,
			ready = ready,
			selected = selectedId == node.id,
			bound = burstId == node.id,
			reducedMotion = not liveFx,
			onSelect = function()
				return setSelectedId(node.id)
			end,
			index = index,
			nodeSize = nodeSize,
			padX = padX,
			padY = padY,
		})
	end
	for _k, _v in NODES do
		_newValue_1[_k] = _callback_3(_v, _k - 1, NODES)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.new(1, -16, 1, -(headerH + footerH + treeGap * 2 + 10)),
		Position = UDim2.fromOffset(8, headerH + treeGap + 6),
		BackgroundColor3 = darken(Palette.void, 0.04),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 710,
		Active = true,
		Event = {
			InputBegan = function(_frame, input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
					return nil
				end
				drag.current = {
					x = input.Position.X,
					y = input.Position.Y,
					ox = pan.x,
					oy = pan.y,
				}
			end,
		},
	}, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(pan.x, pan.y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _newValue, _newValue_1))
	local _exp_8 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _attributes_1 = {}
	local _result_3 = selected
	if _result_3 ~= nil then
		_result_3 = _result_3.accent
	end
	local _condition_4 = _result_3
	if _condition_4 == nil then
		_condition_4 = Palette.pink
	end
	_attributes_1.Color = _condition_4
	_attributes_1.Thickness = 1
	_attributes_1.Transparency = 0.4
	local _exp_9 = React.createElement("uistroke", _attributes_1)
	local _attributes_2 = {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(12, 10),
	}
	local _result_4 = selected
	if _result_4 ~= nil then
		_result_4 = _result_4.accent
	end
	local _condition_5 = _result_4
	if _condition_5 == nil then
		_condition_5 = Palette.pink
	end
	_attributes_2.BackgroundColor3 = _condition_5
	_attributes_2.BorderSizePixel = 0
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		ref = overlayHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 700,
		ClipsDescendants = true,
		Visible = motion:map(function(amount)
			return amount > 0.003
		end),
	}, _exp, React.createElement("frame", {
		Size = UDim2.fromOffset(panelW, panelH),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 701,
		Visible = motion:map(function(amount)
			return amount > 0.002
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 701,
	}, _exp_1, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 702,
		ClipsDescendants = true,
		Active = true,
	}, _exp_2, _exp_3, _exp_4, _exp_7, React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, footerH),
		Position = footerIn:map(function(amount)
			return UDim2.new(0, 8, 1, -(footerH + 6) + math.round((1 - amount) * 14))
		end),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 720,
	}, _exp_8, _exp_9, React.createElement("frame", _attributes_2, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = if selected ~= nil then selected.name else "Choose a branch",
		size = if stack then 14 else 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(24, 4),
		sizeConstraint = UDim2.new(1, if stack then -24 else -220, 0, 18),
	}), React.createElement(Text, {
		value = if selected ~= nil then `{selected.body}  ·  {selected.lore}` else "",
		size = if stack then 11 else 10,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(12, 24),
		sizeConstraint = UDim2.new(1, if stack then -24 else -220, 0, if stack then 32 else 14),
	}), not stack and React.createElement(Text, {
		value = if selected ~= nil then (if owned then "Already bound to this domain." elseif prereqs then `{selected.cost} points to bind` else "Open the earlier branch first.") else "",
		size = 10,
		color = if owned then Palette.mint elseif canBuy then Palette.mango else Palette.muted,
		position = UDim2.fromOffset(12, 40),
		sizeConstraint = UDim2.new(1, -220, 0, 12),
	}), React.createElement(Button, {
		text = if owned then "BOUND" elseif busy then "BINDING" else `BIND  {selected.cost}`,
		icon = "Domain",
		onClick = unlock,
		color = if canBuy then Palette.pink else Palette.panelSoft,
		textColor = if canBuy then Palette.cream else Palette.muted,
		size = if stack then UDim2.new(0.58, -8, 0, TapTarget) else UDim2.fromOffset(118, 40),
		position = if stack then UDim2.new(0, 8, 1, -(TapTarget + 8)) else UDim2.new(1, -216, 0.5, -20),
		disabled = not canBuy,
		reducedMotion = reducedMotion,
		highlight = canBuy,
	}), React.createElement(Button, {
		text = "DONE",
		icon = "Close",
		onClick = close,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = if stack then UDim2.new(0.38, -8, 0, TapTarget) else UDim2.fromOffset(86, 40),
		position = if stack then UDim2.new(0.60, 4, 1, -(TapTarget + 8)) else UDim2.new(1, -90, 0.5, -20),
		reducedMotion = reducedMotion,
	})))))))
end
return {
	DomainSkillTree = DomainSkillTree,
}
end

-- ======================================================================
-- Module: purchaseOverlay   (merged from purchaseOverlay.luau, 500 lines)
-- ======================================================================
__defs["purchaseOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useBoatTween = _motion.useBoatTween
local useClock = _motion.useClock
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local darken = _theme.darken
local Palette = _theme.Palette
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local PURCHASE_RESULT_HOLD = 2.2
local PURCHASE_RESULT_HOLD_REDUCED = 1.65
local PURCHASE_PENDING_FAILSAFE = 45
local DOT_COLORS = { Palette.mango, Palette.cyan, Palette.mint }
local function ForgeDot(_param)
	local index = _param.index
	local clock = _param.clock
	local morph = _param.morph
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — PurchaseOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local color = DOT_COLORS[index + 1]
	local x = (index - 1) * 26
	local position = React.joinBindings({ clock, morph }):map(function(values)
		local wave = if reducedMotion then 0 else math.pow((math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.5, 1.6)
		return UDim2.new(0.5, math.round(x * (1 - values[2])), 0.5, math.round(9 - wave * 18))
	end)
	local scale = React.joinBindings({ clock, morph }):map(function(values)
		local pulse = if reducedMotion then 1 else 0.82 + (math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.13
		return math.max(0.05, pulse * (1 - values[2]))
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 414,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = morph:map(function(amount)
			return math.clamp(amount * 1.2, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.white,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement("frame", {
		Size = UDim2.new(1.35, 0, 0, 3),
		Position = UDim2.new(0.5, 0, 1, 9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(color, 0.28),
		BackgroundTransparency = 0.54,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function ResultGlyph(_param)
	local phase = _param.phase
	local amount = _param.amount
	local accent = _param.accent
	local kind = if phase == "success" then "Check" else "Close"
	return React.createElement("frame", {
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement(ScaleFromCenter, {
		scale = amount:map(function(value)
			return 0.24 + value * 0.76
		end),
		zIndex = 415,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(accent, 0.78),
		BackgroundTransparency = amount:map(function(value)
			return 1 - value * 0.22
		end),
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = amount:map(function(value)
			return 1 - value * 0.92
		end),
	}), React.createElement(Icon, {
		kind = kind,
		color = Palette.cream,
		accent = accent,
		size = 54,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))))
end
local function PurchaseOverlay(_param)
	local phase = _param.phase
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — PurchaseOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local detail = _param.detail
	local onDismiss = _param.onDismiss
	local visible = phase ~= "hidden"
	local result = phase == "success" or phase == "fail"
	local show = useBoatTween(if visible then 1 else 0, if visible then 0.25 else 0.18, softMotion, easeOutCubic, 0)
	local card = useBoatTween(if visible then 1 else 0, if visible then 0.34 else 0.15, softMotion, easeOutBack, 0)
	local _binding = useExitTransition(softMotion, 0.32, phase == "hidden")
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local morph = useFlipperSpring(if result then 1 else 0, softMotion, 500, 30)
	local clock = useClock(phase == "pending" and not reducedMotion, 1.4, 1)
	local viewport = useViewport()
	local nonce, setNonce = React.useState(0)
	local dismissRef = React.useRef(onDismiss)
	local dismissStarted = React.useRef(false)
	local overlayHostRef = React.useRef(nil)
	dismissRef.current = onDismiss
	local previousPhase = React.useRef("hidden")
	React.useEffect(function()
		if phase == previousPhase.current then
			return nil
		end
		previousPhase.current = phase
		if phase == "success" then
			Audio:play("purchaseResult")
		elseif phase == "fail" then
			Audio:play("error")
		end
	end, { phase })
	React.useEffect(function()
		if result then
			setNonce(function(value)
				return value + 1
			end)
		end
	end, { phase, result })
	local flash = useFlash(nonce, reducedMotion, if phase == "fail" then 0.62 else 0.48)
	local dismiss = React.useCallback(function()
		if not result or exiting or dismissStarted.current then
			return nil
		end
		dismissStarted.current = true
		Audio:play("purchaseExit")
		beginExit(function()
			local _result = dismissRef.current
			if _result ~= nil then
				_result = _result()
			end
			return _result
		end)
	end, { beginExit, exiting, result })
	React.useEffect(function()
		if phase == "pending" or phase == "hidden" then
			dismissStarted.current = false
		end
	end, { phase })
	React.useEffect(function()
		if not result then
			return nil
		end
		local alive = true
		local worker = task.delay(if reducedMotion then PURCHASE_RESULT_HOLD_REDUCED else PURCHASE_RESULT_HOLD, function()
			if alive then
				dismiss()
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { dismiss, phase, reducedMotion, result })
	React.useEffect(function()
		if phase == "hidden" then
			GamepadNavigationService.EndOverlayFocus()
			return nil
		end
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { phase })
	React.useEffect(function()
		if not result or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current
		if host == nil then
			return nil
		end
		local alive = true
		local selectJob = task.defer(function()
			if not alive or host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			alive = false
			pcall(task.cancel, selectJob)
		end
	end, { phase, result })
	local accent = if phase == "fail" then Palette.coral elseif phase == "success" then Palette.mint else Palette.mango
	local title = if phase == "pending" then "BUYING..." elseif phase == "success" then "BOUGHT" else "COULDN'T BUY"
	local _result
	if phase == "pending" then
		_result = "Waiting on Roblox checkout"
	else
		local _result_1
		if phase == "success" then
			_result_1 = "It's in your account now"
		else
			local _condition = detail
			if _condition == nil then
				_condition = "You weren't charged"
			end
			_result_1 = _condition
		end
		_result = _result_1
	end
	local detailText = _result
	local shortLandscape = viewport.height < 430 and viewport.width > viewport.height * 1.14
	local sideSafe = math.max(viewport.sideInset, 8)
	local topSafe = math.max(viewport.topInset, 8)
	local bottomSafe = math.max(viewport.bottomInset, 8)
	local safeHeight = math.max(184, viewport.height - topSafe - bottomSafe)
	local availableWidth = math.max(280, viewport.width - (sideSafe + 12) * 2)
	local cardWidth = math.min(if shortLandscape then 540 else 430, availableWidth)
	local cardHeight = if shortLandscape then math.clamp(safeHeight - 16, 184, 218) else math.clamp(safeHeight - 20, 232, 272)
	local compactVertical = not shortLandscape and cardHeight < 260
	local presence = React.joinBindings({ show, card, exitAmount }):map(function(values)
		return math.min(values[1], values[2], values[3])
	end)
	local cardTravel = 22
	-- Center in the host. Viewport offsets push the card down-right when the
	-- host is the page, not the full screen.
	local cardPosition = presence:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.floor((1 - amount) * cardTravel))
	end)
	local cardScale = React.joinBindings({ presence, flash }):map(function(values)
		return 0.94 + math.clamp(values[1], 0, 1) * 0.06 + values[2] * 0.025
	end)
	local orbSize = if shortLandscape then math.min(106, cardHeight - 32) elseif compactVertical then 104 else 118
	local orbPosition = if shortLandscape then UDim2.fromOffset(20, math.floor(cardHeight * 0.5)) else UDim2.new(0.5, 0, 0, 24)
	local orbAnchor = if shortLandscape then Vector2.new(0, 0.5) else Vector2.new(0.5, 0)
	local copyLeft = if shortLandscape then orbSize + 42 else 18
	local copyWidth = if shortLandscape then -(copyLeft + 20) else -36
	local titleY = if shortLandscape then math.max(28, math.floor(cardHeight * 0.5) - 44) else orbSize + (if compactVertical then 32 else 40)
	local detailY = titleY + (if shortLandscape then 28 else 24)
	local railLeft = if shortLandscape then copyLeft else 26
	local railBottom = if shortLandscape then 28 elseif compactVertical then 29 else 38
	local _exp = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = presence:map(function(amount)
			return 1 - amount * 0.68
		end),
		BorderSizePixel = 0,
		ZIndex = 400,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Name = "PurchaseDismissBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Active = visible and not exiting,
		Selectable = false,
		Modal = visible,
		ZIndex = 401,
		Event = {
			Activated = function()
				if result and not exiting then
					dismiss()
				end
			end,
		},
	})
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 4),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		ZIndex = 405,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}))
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	})
	local _exp_4 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.62),
		Rotation = 90,
	})
	local _exp_5 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = presence:map(function(amount)
			return 1 - amount * 0.8
		end),
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0.56, 0, 0, 3),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 407,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_7 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_8 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.5,
	})
	local _exp_9 = { 0, 1, 2 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_9)
	local _callback = function(index)
		return React.createElement(ForgeDot, {
			key = index,
			index = index,
			clock = clock,
			morph = morph,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in _exp_9 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_9)
	end
	-- ▲ ReadonlyArray.map ▲
	local content = React.createElement(OverlayPresence, {
		amount = presence,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
		Active = presence:map(function(amount)
			return amount > 0.02 and not exiting
		end),
		Visible = presence:map(function(amount)
			return amount > 0.005
		end),
		ClipsDescendants = false,
		Event = {
			InputBegan = function(_frame, input)
				if result and not exiting and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dismiss()
				end
			end,
		},
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		ClipsDescendants = false,
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 405,
	}, _exp_2, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 406,
	}, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.fromOffset(orbSize, orbSize),
		Position = orbPosition,
		AnchorPoint = orbAnchor,
		BackgroundColor3 = darken(accent, 0.86),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 410,
	}, _exp_7, _exp_8, _newValue, phase == "success" and React.createElement(ResultGlyph, {
		phase = "success",
		amount = morph,
		accent = accent,
	}), phase == "fail" and React.createElement(ResultGlyph, {
		phase = "fail",
		amount = morph,
		accent = accent,
	})), React.createElement(Text, {
		value = title,
		size = if shortLandscape then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(copyLeft, titleY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 26),
		zIndex = 410,
	}), React.createElement(Text, {
		value = detailText,
		size = 11,
		color = Palette.creamSoft,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(copyLeft, detailY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 28),
		zIndex = 410,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -(railLeft + (if shortLandscape then 20 else 26)), 0, 3),
		Position = UDim2.new(0, railLeft, 1, -railBottom),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 409,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = if phase == "pending" then clock:map(function(time)
			return UDim2.new(0.22, 0, 1, 0)
		end) else UDim2.fromScale(1, 1),
		Position = if phase == "pending" then clock:map(function(time)
			return UDim2.new((time * 1.25) % 1, 0, 0, 0)
		end) else UDim2.fromScale(0, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, accent),
	}))), result and React.createElement("frame", {
		Name = "PurchaseContinue",
		Size = UDim2.new(1, -(copyLeft + (if shortLandscape then 20 else 26)), 0, 36),
		Position = UDim2.new(0, copyLeft, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 412,
	}, React.createElement(Button, {
		text = "CONTINUE",
		onClick = dismiss,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
		selectable = true,
		zIndex = 412,
	})))))))
	return React.createElement("frame", {
		ref = overlayHostRef,
		Name = "PurchaseOverlayHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
	}, content)
end
return {
	PurchaseOverlay = PurchaseOverlay,
	PURCHASE_RESULT_HOLD = PURCHASE_RESULT_HOLD,
	PURCHASE_RESULT_HOLD_REDUCED = PURCHASE_RESULT_HOLD_REDUCED,
	PURCHASE_PENDING_FAILSAFE = PURCHASE_PENDING_FAILSAFE,
}
end

-- ======================================================================
-- Module: MobileControls   (merged from MobileControls.luau, 1835 lines)
-- ======================================================================
__defs["MobileControls"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _motion = require(script.Parent.MotionKit)("motion")
local useExitTransition = _motion.useExitTransition
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local EDIT_BOUNDS = require(script.Parent.CoreKit)("mobileLayout").EDIT_BOUNDS
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local Text = _ui.Text
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Audio = require(script.Parent.AudioKit)("audio").Audio
local dragHandles = {}
local editMode = false
local dragId
local dragInput
local dragOffset = Vector2.zero
local dragLastCell = Vector2.zero
local dragChanged
local dragEnded
local dragFocusReleased
local dragMenuOpened
local function cancelDrag()
	dragId = nil
	dragInput = nil
end
local function clampDrag(pos, bounds)
	return Vector2.new(math.clamp(pos.X, bounds.minX, bounds.maxX), math.clamp(pos.Y, bounds.minY, bounds.maxY))
end
local function ensureDragging()
	if dragChanged ~= nil then
		return nil
	end
	dragChanged = UserInputService.InputChanged:Connect(function(input)
		if not editMode or dragId == nil or dragInput == nil then
			return nil
		end
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= dragInput then
				return nil
			end
		elseif dragInput.UserInputType == Enum.UserInputType.MouseButton1 then
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return nil
			end
		else
			return nil
		end
		local _dragId = dragId
		local handle = dragHandles[_dragId]
		if handle == nil then
			return nil
		end
		local raw = Vector2.new(input.Position.X - dragOffset.X, input.Position.Y - dragOffset.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		local cellX = math.round(raw.X / grid)
		local cellY = math.round(raw.Y / grid)
		local resolvedPosition = clampDrag(Vector2.new(cellX * grid, cellY * grid), handle.bounds)
		handle.position = resolvedPosition
		local _result = handle.onMove
		if _result ~= nil then
			_result(resolvedPosition)
		end
		-- Tick only when the snapped cell actually changes, not every frame —
		-- a per-pixel sound during drag would just be noise, but a tick each
		-- time the element locks to a new grid cell gives real tactile feedback.
		if cellX ~= dragLastCell.X or cellY ~= dragLastCell.Y then
			dragLastCell = Vector2.new(cellX, cellY)
			Audio:play("sliderStep", 1.1)
		end
	end)
	dragEnded = UserInputService.InputEnded:Connect(function(input)
		if dragInput == nil then
			return nil
		end
		local exactTouch = dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput
		local mouseRelease = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
		if exactTouch or mouseRelease then
			cancelDrag()
		end
	end)
	dragFocusReleased = UserInputService.WindowFocusReleased:Connect(cancelDrag)
	dragMenuOpened = GuiService.MenuOpened:Connect(cancelDrag)
end
local MobileDragging = {
	setEditMode = function(self, on)
		editMode = on
		if not on then
			cancelDrag()
		end
		ensureDragging()
	end,
	register = function(self, handle)
		ensureDragging()
		local _id = handle.id
		local _handle = handle
		dragHandles[_id] = _handle
		return function()
			local _id_1 = handle.id
			dragHandles[_id_1] = nil
			if dragId == handle.id then
				cancelDrag()
			end
		end
	end,
	beginDrag = function(self, id, input)
		if not editMode then
			return nil
		end
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		Audio:play("filterPick", 0.92)
		dragId = id
		dragInput = input
		dragOffset = Vector2.new(input.Position.X - handle.position.X, input.Position.Y - handle.position.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		dragLastCell = Vector2.new(math.round(handle.position.X / grid), math.round(handle.position.Y / grid))
	end,
	setPosition = function(self, id, pos)
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		handle.position = clampDrag(pos, handle.bounds)
		local _result = handle.onMove
		if _result ~= nil then
			_result(handle.position)
		end
	end,
	dispose = function(self)
		local _result = dragChanged
		if _result ~= nil then
			_result:Disconnect()
		end
		local _result_1 = dragEnded
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		local _result_2 = dragFocusReleased
		if _result_2 ~= nil then
			_result_2:Disconnect()
		end
		local _result_3 = dragMenuOpened
		if _result_3 ~= nil then
			_result_3:Disconnect()
		end
		dragChanged = nil
		dragEnded = nil
		dragFocusReleased = nil
		dragMenuOpened = nil
		table.clear(dragHandles)
		cancelDrag()
		editMode = false
	end,
}
local function slotPixels(slot, width, height)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local _exp = slot.x * width
	local _condition_2 = slot.anchorX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local _exp_1 = _exp - slotW * _condition_2
	local _exp_2 = slot.y * height
	local _condition_3 = slot.anchorY
	if _condition_3 == nil then
		_condition_3 = 0.5
	end
	return Vector2.new(_exp_1, _exp_2 - slotH * _condition_3)
end
local function slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local minX = math.max(8, sideInset + 8)
	local _exp = topInset + 8
	local _condition_2 = slot.safeTop
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local minY = math.max(48, _exp, _condition_2)
	return {
		minX = minX,
		maxX = math.max(minX, width - sideInset - slotW - 8),
		minY = minY,
		maxY = math.max(minY, height - bottomInset - slotH - 8),
	}
end
local function safeSlotPosition(slot, position, width, height, sideInset, topInset, bottomInset)
	local bounds = slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	return Vector2.new(math.clamp(position.X, bounds.minX, bounds.maxX), math.clamp(position.Y, bounds.minY, bounds.maxY))
end
local function MobileControls(_param)
	local slots = _param.slots
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local visible = _param.visible
	local onClose = _param.onClose
	local scales = _param.scales
	local opacities = _param.opacities
	local viewport = useViewport()
	local editing, setEditing = React.useState(false)
	local snap, setSnap = React.useState(true)
	local snapStep, setSnapStep = React.useState(16)
	local fine, setFine = React.useState(false)
	local showThirds, setShowThirds = React.useState(false)
	local selectedId, setSelectedId = React.useState()
	local locked, setLocked = React.useState({})
	local history, setHistory = React.useState({})
	local redo, setRedo = React.useState({})
	local positions, setPositions = React.useState({})
	local _binding = useExitTransition(reducedMotion, 0.38, visible)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local requestClose = React.useCallback(function()
		if not exiting then
			beginExit(onClose)
		end
	end, { beginExit, exiting, onClose })
	local screen = React.useState(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local rootScreen = playerGui:FindFirstChild("AstralForgeStudioUI")
		return if rootScreen ~= nil and rootScreen:IsA("ScreenGui") then rootScreen else playerGui
	end)
	local positionsRef = React.useRef(positions)
	positionsRef.current = positions
	React.useEffect(function()
		return function()
			MobileDragging:dispose()
		end
	end, {})
	React.useEffect(function()
		if not visible then
			return nil
		end
		local initialPositions = {}
		for _, slot in slots do
			initialPositions[slot.id] = safeSlotPosition(slot, slotPixels(slot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		positionsRef.current = initialPositions
		setPositions(initialPositions)
	end, { slots, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		if not visible then
			MobileDragging:setEditMode(false)
			setEditing(false)
			return nil
		end
		local cleanups = {}
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local corrected = _object
		local correctedAny = false
		for _, slot in slots do
			local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local raw = positionsRef.current[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local position = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			if position.X ~= raw.X or position.Y ~= raw.Y then
				corrected[slot.id] = position
				correctedAny = true
			end
			local _arg0 = MobileDragging:register({
				id = slot.id,
				position = position,
				bounds = bounds,
				snap = if snap then snapStep else 1,
				onMove = function(nextPosition)
					return setPositions(function(current)
						local _object_1 = table.clone(current)
						setmetatable(_object_1, nil)
						_object_1[slot.id] = nextPosition
						return _object_1
					end)
				end,
			})
			table.insert(cleanups, _arg0)
		end
		if correctedAny then
			positionsRef.current = corrected
			setPositions(corrected)
		end
		return function()
			for _, dispose in cleanups do
				dispose()
			end
		end
	end, { slots, snap, snapStep, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		MobileDragging:setEditMode(editing and visible)
		return function()
			return MobileDragging:setEditMode(false)
		end
	end, { editing, visible })
	local layoutOverlaps = function(source)
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			local pos = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			do
				local otherIndex = index + 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						otherIndex += 1
					else
						_shouldIncrement = true
					end
					if not (otherIndex < #slots) then
						break
					end
					local other = slots[otherIndex + 1]
					local otherPos = source[other.id] or slotPixels(other, viewport.width, viewport.height)
					local _condition_2 = other.width
					if _condition_2 == nil then
						_condition_2 = 112
					end
					local otherWidth = _condition_2
					local _condition_3 = other.height
					if _condition_3 == nil then
						_condition_3 = 62
					end
					local otherHeight = _condition_3
					local separated = pos.X + width + 6 <= otherPos.X or otherPos.X + otherWidth + 6 <= pos.X or pos.Y + height + 6 <= otherPos.Y or otherPos.Y + otherHeight + 6 <= pos.Y
					if not separated then
						return true
					end
				end
			end
		end
		return false
	end
	local save = function(source)
		if source == nil then
			source = positionsRef.current
		end
		if layoutOverlaps(source) then
			return false
		end
		local values = {}
		for _, slot in slots do
			local raw = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local pos = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local slotW = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local slotH = _condition_1
			local _exp = pos.X
			local _condition_2 = slot.anchorX
			if _condition_2 == nil then
				_condition_2 = 0.5
			end
			values[slot.xKey] = math.clamp((_exp + slotW * _condition_2) / viewport.width, 0, 1)
			local _exp_1 = pos.Y
			local _condition_3 = slot.anchorY
			if _condition_3 == nil then
				_condition_3 = 0.5
			end
			values[slot.yKey] = math.clamp((_exp_1 + slotH * _condition_3) / viewport.height, 0, 1)
		end
		dispatch("SetMobileLayout", {
			Values = values,
		})
		return true
	end
	local finishEditing = function()
		if not save() then
			return false
		end
		setEditing(false)
		return true
	end
	local capStack = function(source, extra)
		local _array = {}
		local _length = #_array
		table.move(source, 1, #source, _length + 1, _array)
		local nextHist = _array
		local _object = table.clone(extra)
		setmetatable(_object, nil)
		table.insert(nextHist, _object)
		if #nextHist <= 12 then
			return nextHist
		end
		local trimmed = {}
		for index = #nextHist - 12, #nextHist - 1 do
			local _arg0 = nextHist[index + 1]
			table.insert(trimmed, _arg0)
		end
		return trimmed
	end
	local applyPositions = function(nextPos)
		positionsRef.current = nextPos
		setPositions(nextPos)
		for _, slot in slots do
			local pos = nextPos[slot.id]
			if pos ~= nil then
				MobileDragging:setPosition(slot.id, pos)
			end
		end
	end
	local pushHistory = function(source)
		setHistory(function(current)
			return capStack(current, source)
		end)
		setRedo({})
	end
	local undoLayout = function()
		if #history == 0 then
			return nil
		end
		local prior = history[#history]
		if prior == nil then
			return nil
		end
		setRedo(function(current)
			return capStack(current, positionsRef.current)
		end)
		setHistory(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
		applyPositions(prior)
		Audio:play("close", 0.94)
	end
	local redoLayout = function()
		if #redo == 0 then
			return nil
		end
		local upcoming = redo[#redo]
		if upcoming == nil then
			return nil
		end
		setHistory(function(current)
			return capStack(current, positionsRef.current)
		end)
		setRedo(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
		applyPositions(upcoming)
		Audio:play("open", 1.04)
	end
	local nudgeSelected = function(dx, dy)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local step = if fine then 1 else (if snap then snapStep else 4)
		local moved = safeSlotPosition(slot, Vector2.new(current.X + dx * step, current.Y + dy * step), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = moved
		applyPositions(_object)
	end
	local alignSelected = function(mode)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local _condition_1 = slot.width
		if _condition_1 == nil then
			_condition_1 = 112
		end
		local slotW = _condition_1
		local _condition_2 = slot.height
		if _condition_2 == nil then
			_condition_2 = 62
		end
		local slotH = _condition_2
		local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local x = current.X
		local y = current.Y
		if mode == "left" then
			x = bounds.minX
		end
		if mode == "right" then
			x = bounds.maxX
		end
		if mode == "top" then
			y = bounds.minY
		end
		if mode == "bottom" then
			y = bounds.maxY
		end
		if mode == "cx" then
			x = math.floor((viewport.width - slotW) / 2)
		end
		if mode == "cy" then
			y = math.floor((viewport.height - slotH) / 2)
		end
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = safeSlotPosition(slot, Vector2.new(x, y), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		applyPositions(_object)
	end
	local unstackOverlaps = function()
		pushHistory(positionsRef.current)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local nextPos = _object
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			if locked[slot.id] == true then
				continue
			end
			local pos = nextPos[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			for otherIndex = 0, #slots - 1 do
				if otherIndex == index then
					continue
				end
				local other = slots[otherIndex + 1]
				local otherPos = nextPos[other.id] or slotPixels(other, viewport.width, viewport.height)
				local _condition_2 = other.width
				if _condition_2 == nil then
					_condition_2 = 112
				end
				local otherW = _condition_2
				local _condition_3 = other.height
				if _condition_3 == nil then
					_condition_3 = 62
				end
				local otherH = _condition_3
				local separated = pos.X + width + 8 <= otherPos.X or otherPos.X + otherW + 8 <= pos.X or pos.Y + height + 8 <= otherPos.Y or otherPos.Y + otherH + 8 <= pos.Y
				if separated then
					continue
				end
				pos = safeSlotPosition(slot, Vector2.new(pos.X, otherPos.Y + otherH + 12), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			end
			nextPos[slot.id] = pos
		end
		applyPositions(nextPos)
		save(nextPos)
	end
	local bumpSelectedSetting = function(kind, delta)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil then
			return nil
		end
		local key = if id == "quick" then (if kind == "scale" then "MobileQuickScale" else "MobileQuickOpacity") elseif id == "dock" then (if kind == "scale" then "MobileDockScale" else "MobileDockOpacity") else (if kind == "scale" then "MobileToastScale" else "MobileToastOpacity")
		local _result
		if kind == "scale" then
			local _result_1 = scales
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.5
			end
			_result = _condition_1
		else
			local _result_1 = opacities
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.85
			end
			_result = _condition_1
		end
		local current = _result
		dispatch("SetSetting", {
			Key = key,
			Value = math.clamp(current + delta, 0, 1),
		})
	end
	local resetLayout = function()
		local fresh = {}
		for _, slot in slots do
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = slot.defaultX
			_object.y = slot.defaultY
			local resetSlot = _object
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(resetSlot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		for _, slot in slots do
			MobileDragging:setPosition(slot.id, fresh[slot.id])
		end
		positionsRef.current = fresh
		setPositions(fresh)
		save(fresh)
	end
	local applyPreset = function(side)
		pushHistory(positionsRef.current)
		Audio:play("filterPick", 1.02)
		local fresh = {}
		for _, slot in slots do
			local x = slot.defaultX
			local y = slot.defaultY
			if side == "left" then
				if slot.id == "quick" then
					x = 0.28
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "right" then
				if slot.id == "quick" then
					x = 0.72
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "top" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.82
					y = 0.38
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "thumbs" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.5
					y = 0.18
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.93
				end
			elseif side == "tl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "tr" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "bl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "br" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			end
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = x
			_object.y = y
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(_object, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		applyPositions(fresh)
		save(fresh)
		if side == "left" or side == "bl" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 1,
			})
		end
		if side == "right" or side == "br" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 0,
			})
		end
	end
	local overlaps = function(slot, pos)
		local _condition = slot.width
		if _condition == nil then
			_condition = 112
		end
		local w = _condition
		local _condition_1 = slot.height
		if _condition_1 == nil then
			_condition_1 = 62
		end
		local h = _condition_1
		for _, other in slots do
			if other.id == slot.id then
				continue
			end
			local otherPos = positions[other.id] or slotPixels(other, viewport.width, viewport.height)
			local _condition_2 = other.width
			if _condition_2 == nil then
				_condition_2 = 112
			end
			local otherW = _condition_2
			local _condition_3 = other.height
			if _condition_3 == nil then
				_condition_3 = 62
			end
			local otherH = _condition_3
			local separated = pos.X + w + 6 <= otherPos.X or otherPos.X + otherW + 6 <= pos.X or pos.Y + h + 6 <= otherPos.Y or otherPos.Y + otherH + 6 <= pos.Y
			if not separated then
				return true
			end
		end
		return false
	end
	local collisionPresent = layoutOverlaps(positions)
	if not visible then
		return ReactRoblox.createPortal(React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}), screen)
	end
	local editorToolbarY = math.max(if viewport.width > viewport.height and viewport.height < 500 then 56 else 8, viewport.topInset + 8)
	local topToolbarBottom = editorToolbarY + TapTarget * 2 + 16 + 8
	local bottomBarY = math.max(topToolbarBottom, viewport.height - viewport.bottomInset - (TapTarget * 2 + 16))
	local gridMarks = if showThirds then { 1 / 3, 0.5, 2 / 3 } else { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 }
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		local _exp = entry.id
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		return _exp == _condition
	end
	local _result
	for _i, _v in slots do
		if _callback(_v, _i - 1, slots) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local selectedSlot = _result
	local selectedPos = if selectedSlot ~= nil then (positions[selectedSlot.id] or slotPixels(selectedSlot, viewport.width, viewport.height)) else nil
	local selectedLocked = selectedSlot ~= nil and locked[selectedSlot.id] == true
	local _condition = editing
	if _condition then
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(x)
			return React.createElement("frame", {
				key = `grid-x-{x}`,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.new(x, 0, 0, 0),
				BackgroundColor3 = if x == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if x == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = _newValue
	end
	local _condition_1 = editing
	if _condition_1 then
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(y)
			return React.createElement("frame", {
				key = `grid-y-{y}`,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, y, 0),
				BackgroundColor3 = if y == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if y == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_1 = _newValue
	end
	local _condition_2 = editing
	if _condition_2 then
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#slots)
		local _callback_1 = function(slot)
			local _condition_3 = slot.width
			if _condition_3 == nil then
				_condition_3 = 112
			end
			local slotW = _condition_3
			local _condition_4 = slot.height
			if _condition_4 == nil then
				_condition_4 = 62
			end
			local slotH = _condition_4
			local pos = positions[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local collision = overlaps(slot, pos)
			local isLocked = locked[slot.id] == true
			local accent = if collision then Palette.coral elseif selectedId == slot.id then Palette.mint elseif isLocked then Palette.mango else EDIT_BOUNDS
			local pctX = math.floor(((pos.X + slotW * 0.5) / viewport.width) * 100)
			local pctY = math.floor(((pos.Y + slotH * 0.5) / viewport.height) * 100)
			return React.createElement("frame", {
				key = slot.id,
				Size = UDim2.fromOffset(slotW, slotH),
				Position = UDim2.fromOffset(pos.X, pos.Y),
				BackgroundColor3 = Palette.panelRaised,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ZIndex = 502,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 14),
			}), React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = accent,
				Thickness = if collision then 3 else 2,
				Transparency = 0.08,
			}), React.createElement("frame", {
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(-7, -7),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 505,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}), React.createElement(Text, {
				value = if isLocked then "L" else "+",
				size = 14,
				color = Palette.ink,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 506,
			})), React.createElement(Text, {
				value = slot.label,
				size = 11,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(4, 8),
				sizeConstraint = UDim2.new(1, -8, 0, 18),
				zIndex = 503,
			}), React.createElement(Text, {
				value = `{pctX}%  {pctY}%`,
				size = 9,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 4, 1, -22),
				sizeConstraint = UDim2.new(1, -8, 0, 14),
				zIndex = 503,
			}), collision and React.createElement(Text, {
				value = "OVERLAP",
				size = 8,
				color = Palette.coral,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -36),
				sizeConstraint = UDim2.new(1, 0, 0, 14),
				zIndex = 506,
			}), React.createElement("imagebutton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Selectable = false,
				Active = true,
				ZIndex = 504,
				Event = {
					InputBegan = function(_button, input)
						if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
							setSelectedId(slot.id)
							if not isLocked then
								MobileDragging:beginDrag(slot.id, input)
							end
						end
					end,
				},
			}))
		end
		for _k, _v in slots do
			_newValue[_k] = _callback_1(_v, _k - 1, slots)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_2 = _newValue
	end
	local _condition_3 = editing
	if _condition_3 then
		local _exp = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 13),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.cyan,
			Thickness = 1,
			Transparency = 0.42,
		}), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if collisionPresent then "OVERLAP" else "SAVE",
			onClick = if collisionPresent then unstackOverlaps else finishEditing,
			color = if collisionPresent then Palette.coral else EDIT_BOUNDS,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.2, 1, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if snap then `SNAP {snapStep}` else "FREE",
			onClick = function()
				if not snap then
					setSnap(true)
					setSnapStep(4)
				elseif snapStep == 4 then
					setSnapStep(8)
				elseif snapStep == 8 then
					setSnapStep(16)
				elseif snapStep == 16 then
					setSnapStep(32)
				else
					setSnap(false)
					setSnapStep(8)
				end
			end,
			color = if snap then Palette.cyan else Palette.panelSoft,
			textColor = if snap then Palette.ink else Palette.creamSoft,
			outline = not snap,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.4, 2, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "UNDO",
			onClick = undoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.6, 3, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "REDO",
			onClick = redoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.8, 4, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "DONE",
			onClick = function()
				if finishEditing() then
					requestClose()
				end
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = exiting,
		})))
		local _exp_1 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY + TapTarget + 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "←",
			onClick = function()
				return nudgeSelected(-1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↑",
			onClick = function()
				return nudgeSelected(0, -1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.16, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↓",
			onClick = function()
				return nudgeSelected(0, 1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "→",
			onClick = function()
				return nudgeSelected(1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.48, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if fine then "1px" else "STEP",
			onClick = function()
				return setFine(not fine)
			end,
			color = if fine then Palette.mint else Palette.panelSoft,
			textColor = if fine then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.64, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if showThirds then "1/3" else "10%",
			onClick = function()
				return setShowThirds(not showThirds)
			end,
			color = if showThirds then Palette.cyan else Palette.panelSoft,
			textColor = if showThirds then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.82, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_2 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "L",
			onClick = function()
				return alignSelected("left")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "R",
			onClick = function()
				return alignSelected("right")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(1 / 6, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "T",
			onClick = function()
				return alignSelected("top")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(2 / 6, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "B",
			onClick = function()
				return alignSelected("bottom")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(3 / 6, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CX",
			onClick = function()
				return alignSelected("cx")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(4 / 6, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CY",
			onClick = function()
				return alignSelected("cy")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(5 / 6, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_3 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY + TapTarget + 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = if selectedLocked then "UNLOCK" else "LOCK",
			onClick = function()
				if selectedSlot == nil then
					return nil
				end
				setLocked(function(current)
					local _object = table.clone(current)
					setmetatable(_object, nil)
					_object[selectedSlot.id] = not selectedLocked
					return _object
				end)
			end,
			color = if selectedLocked then Palette.mango else Palette.panelSoft,
			textColor = if selectedLocked then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ-",
			onClick = function()
				return bumpSelectedSetting("scale", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.18, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ+",
			onClick = function()
				return bumpSelectedSetting("scale", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE-",
			onClick = function()
				return bumpSelectedSetting("opacity", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.46, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE+",
			onClick = function()
				return bumpSelectedSetting("opacity", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.62, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CLEAR",
			onClick = unstackOverlaps,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.new(0.22, -3, 1, 0),
			position = UDim2.new(0.78, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _attributes = {}
		local _result_1
		if selectedPos ~= nil then
			local _result_2 = selectedSlot
			if _result_2 ~= nil then
				_result_2 = _result_2.label
			end
			local _condition_4 = _result_2
			if _condition_4 == nil then
				_condition_4 = "HUD"
			end
			_result_1 = `{_condition_4}  ·  drag, nudge, align, size  ·  red means overlap`
		else
			_result_1 = "DRAG A BLOCK"
		end
		_attributes.value = _result_1
		_attributes.size = 10
		_attributes.color = Palette.cyan
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.align = Enum.TextXAlignment.Center
		_attributes.position = UDim2.new(0, viewport.sideInset + 12, 0, editorToolbarY + TapTarget * 2 + 16)
		_attributes.sizeConstraint = UDim2.new(1, -(viewport.sideInset * 2 + 24), 0, 18)
		_attributes.zIndex = 506
		_condition_3 = React.createElement(React.Fragment, nil, _exp, _exp_1, _exp_2, _exp_3, React.createElement(Text, _attributes))
	end
	return ReactRoblox.createPortal(React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = exit:map(function(amount)
			return 1 - amount * (if editing then 0.62 else 0.88)
		end),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 500,
		ClipsDescendants = true,
		Visible = exit:map(function(amount)
			return amount > 0.01
		end),
	}, _condition, _condition_1, _condition_2, _condition_3, not editing and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(440, viewport.width - viewport.sideInset * 2 - 24), 292),
		Position = UDim2.new(0.5, 0, 1, -(304 + viewport.bottomInset)),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 510,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement(Button, {
		text = "EDIT HUD LAYOUT",
		onClick = function()
			return setEditing(true)
		end,
		color = EDIT_BOUNDS,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "LEFT",
		onClick = function()
			return applyPreset("left")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.2, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "HOME",
		onClick = function()
			return applyPreset("default")
		end,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.4, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RIGHT",
		onClick = function()
			return applyPreset("right")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.6, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TOP",
		onClick = function()
			return applyPreset("top")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.8, 4, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "THUMB",
		onClick = function()
			return applyPreset("thumbs")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TL",
		onClick = function()
			return applyPreset("tl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.25, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TR",
		onClick = function()
			return applyPreset("tr")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.5, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BL",
		onClick = function()
			return applyPreset("bl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.75, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BR",
		onClick = function()
			return applyPreset("br")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.fromOffset(0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RESET",
		onClick = resetLayout,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.new(0.5, 4, 0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "CLOSE",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
	})), React.createElement(Text, {
		value = "Move vault, dock, and alerts. Size, fade, lock, and snap stay. Nothing is removed.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(8, 212),
		sizeConstraint = UDim2.new(1, -16, 0, 56),
	})), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	}), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	})), screen)
end
local function MobileQuickBar(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local hudX = _param.hudX
	local hudY = _param.hudY
	local hudScale = _param.hudScale
	local hudOpacity = _param.hudOpacity
	local buttonSpacing = _param.buttonSpacing
	local minTop = _param.minTop
	local reversed = _param.reversed
	if reversed == nil then
		reversed = false
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local vaultFill = if asFlux(state.Capacity) > 0 then math.clamp(asFlux(state.Vault) / asFlux(state.Capacity), 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local side = math.max(edgePad, chrome.sideSafe)
	local _condition = buttonSpacing
	if _condition == nil then
		_condition = 0.5
	end
	local gap = 4 + math.floor(math.clamp(_condition, 0, 1) * 10)
	local btnH = TapTarget
	local _condition_1 = hudScale
	if _condition_1 == nil then
		_condition_1 = 0.5
	end
	local scale = 0.72 + math.clamp(_condition_1, 0, 1) * 0.28
	local width = math.max(200, (viewport.width - side * 2) * scale)
	local _condition_2 = hudX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local x = math.clamp(_condition_2, (side + width / 2) / viewport.width, 1 - (side + width / 2) / viewport.width)
	local yFallback = 1 - (bottomOffset - height / 2) / viewport.height
	local _condition_3 = hudY
	if _condition_3 == nil then
		_condition_3 = yFallback
	end
	local y = math.clamp(_condition_3, (math.max(viewport.topInset, minTop) + height / 2 + 8) / viewport.height, 1 - (viewport.bottomInset + height / 2 + 8) / viewport.height)
	local _condition_4 = hudOpacity
	if _condition_4 == nil then
		_condition_4 = 0.85
	end
	local surfaceTransparency = math.clamp(0.48 - math.clamp(_condition_4, 0, 1) * 0.48, 0, 0.48)
	local readyPulse = usePulse(vaultReady and vaultFill > 0.8, 2.4)
	local tapReadyAt, setTapReadyAt = React.useState(0)
	local tapLeft, setTapLeft = React.useState(0)
	React.useEffect(function()
		if tapReadyAt <= 0 then
			setTapLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, tapReadyAt - os.clock())
				if not alive then
					break
				end
				setTapLeft(left)
				if not alive or left <= 0 then
					break
				end
				task.wait(0.05)
			end
		end)
		return function()
			alive = false
			-- The countdown thread has already returned once the timer hits zero.
			-- task.cancel throws on that dead thread and would skip later cleanup.
			pcall(task.cancel, worker)
		end
	end, { tapReadyAt })
	local tap = function()
		if os.clock() < tapReadyAt then
			return nil
		end
		setTapReadyAt(os.clock() + 0.45)
		setTapLeft(0.45)
		dispatch("Overcharge")
	end
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		dispatch("CollectVault")
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = surfaceTransparency,
		BorderSizePixel = 0,
		ZIndex = 61,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if vaultFill > 0.8 then Palette.green else Palette.lineSoft,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = readyPulse:map(function(amount)
			return if vaultFill > 0.8 then 0.42 - amount * 0.22 else 0.45
		end),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 3),
		Position = UDim2.fromOffset(8, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 62,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSpring:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if vaultFill > 0.92 then Palette.mango else Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, btnH),
		Position = UDim2.fromOffset(8, height - btnH - 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 63,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(0.58, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 2 else 1,
	}, React.createElement(Button, {
		text = if vaultReady then `BANK  {compactNumber(state.Vault)}` else "VAULT EMPTY",
		icon = "Flux",
		onClick = bank,
		color = if vaultReady then Palette.green else Palette.panelSoft,
		textColor = if vaultReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not vaultReady,
		highlight = vaultReady and vaultFill > 0.5,
	})), React.createElement("frame", {
		Size = UDim2.new(0.42, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 1 else 2,
	}, React.createElement(Button, {
		text = if tapLeft > 0.02 then string.format("%.1fs", tapLeft) else "TAP",
		icon = "Forge",
		onClick = tap,
		color = if tapLeft > 0.02 then Palette.panelSoft else Palette.cyan,
		textColor = if tapLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = tapLeft > 0.02,
		highlight = tapLeft <= 0.02,
	}))), chrome.landscape and React.createElement(Text, {
		value = `{compactNumber(state.Production)}/s`,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -12, 0, 6),
		sizeConstraint = UDim2.fromOffset(80, 12),
		zIndex = 64,
	})))
end
return {
	MobileControls = MobileControls,
	MobileQuickBar = MobileQuickBar,
}
end

-- ======================================================================
-- Module: floorFx   (merged from play/floorFx.luau, 493 lines)
-- ======================================================================
__defs["floorFx"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local Motion = require(script.Parent.MotionKit)("motionTokens")
local Fx = require(script.Parent.MotionKit)("vfxMath")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local Text = require(script.Parent.UiCore)("ui").Text
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
-- A strike's shock: a hot core flash, then rings that burst out fast, slow,
-- thin as they spread and fade late -- the shape of a real impact.
local SHOCK_LIFE = 0.55
local function ShockRing(_param)
	local trigger = _param.trigger
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local size = _param.size
	if size == nil then
		size = 280
	end
	local clock = useClock(trigger > 0 and not reducedMotion, 1, 1000, true)
	local rings = {}
	for ring = 0, 2 do
		local delay = ring * 0.05
		rings[ring + 1] = React.createElement("frame", {
			key = ring,
			Size = clock:map(function(seconds)
				local grow = Fx.ring(seconds - delay, SHOCK_LIFE)
				local d = 24 + grow * (size * 0.95 + ring * 26)
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 81,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then Palette.cream else lighten(color, if ring == 0 then 0.25 else 0),
			Thickness = clock:map(function(seconds)
				local _, thin = Fx.ring(seconds - delay, SHOCK_LIFE)
				return 1 + thin * (if ring == 0 then 5 else 3)
			end),
			Transparency = clock:map(function(seconds)
				local _, _, fade = Fx.ring(seconds - delay, SHOCK_LIFE)
				return 0.05 + fade * 0.95
			end),
		}))
	end
	return React.createElement("frame", {
		key = `shock-{trigger}`,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
		Active = false,
	}, React.createElement("frame", {
		-- The core flash: swells and is gone in a blink.
		Size = clock:map(function(seconds)
			local d = size * (0.16 + 0.42 * Motion.EASE.decelerate(clamp01(seconds / 0.2)))
			return UDim2.fromOffset(d, d)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = lighten(color, 0.55),
		BackgroundTransparency = clock:map(function(seconds)
			return 0.3 + 0.7 * Motion.EASE.accelerate(clamp01(seconds / 0.24))
		end),
		BorderSizePixel = 0,
		ZIndex = 82,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) }),
	})), rings)
end
local Spark
local function SparkBurst(_param)
	local sparks = _param.sparks
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(4, math.min(antilag.maxPops * 2, 28))
	local visible = sparks
	if #sparks > max then
		visible = {}
		for index = #sparks - max + 1, #sparks do
			table.insert(visible, sparks[index])
		end
	end
	local children = table.create(#visible)
	for index, spark in visible do
		children[index] = React.createElement(Spark, {
			key = spark.id,
			spark = spark,
			reducedMotion = reducedMotion,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
		Active = false,
		ClipsDescendants = false,
	}, children)
end
-- One spark off the anvil: thrown up and out, slowed by the air, pulled down
-- by gravity, white-hot at birth and cooling to its colour, stretched into a
-- streak along its path while it's fast.
local SPARK_LIFE = 0.72
local SPARK_GRAVITY = 980
local SPARK_DRAG = 2.6
function Spark(_param)
	local spark = _param.spark
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local crumb = spark.kind == "strike" or spark.kind == "perfect" or spark.kind == "bank"
	local power = if spark.kind == "perfect" then 1.35 elseif spark.kind == "bank" then 1.1 else 0.85
	local thickness = if spark.kind == "perfect" then 5 elseif crumb then 4 else 3.2
	local angle = -math.pi / 2 + (Fx.hash(spark.id, 1) - 0.5) * math.rad(150)
	local speed = (260 + Fx.hash(spark.id, 2) * 260) * power * (if reducedMotion then 0.6 else 1)
	local function velocity(seconds: number): (number, number)
		return Fx.velocity(seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG)
	end
	return React.createElement("frame", {
		Size = clock:map(function(seconds)
			local vx, vy = velocity(seconds)
			local length = thickness * 1.4 * Fx.stretch(math.sqrt(vx * vx + vy * vy))
			return UDim2.fromOffset(length, thickness)
		end),
		Position = clock:map(function(seconds)
			local dx, dy = Fx.ballistic(seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG)
			return UDim2.fromScale(spark.x, spark.y) + UDim2.fromOffset(dx, dy)
		end),
		Rotation = clock:map(function(seconds)
			local vx, vy = velocity(seconds)
			return math.deg(math.atan2(vy, vx))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = clock:map(function(seconds)
			return spark.color:Lerp(Palette.white, Fx.heat(seconds, 0.16))
		end),
		BackgroundTransparency = clock:map(function(seconds)
			return Fx.fade(seconds, SPARK_LIFE, 0.3)
		end),
		BorderSizePixel = 0,
		ZIndex = 91,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		-- Bright head, fading tail (the frame's +X points along the motion).
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }),
	}))
end
local ClickPop
local function ClickPops(_param)
	local pops = _param.pops
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(3, math.min(antilag.maxPops, 10))
	local visible = pops
	if #pops > max then
		visible = {}
		for index = #pops - max + 1, #pops do
			table.insert(visible, pops[index])
		end
	end
	local children = table.create(#visible)
	for index, pop in visible do
		children[index] = React.createElement(ClickPop, {
			key = pop.id,
			pop = pop,
			reducedMotion = reducedMotion,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 96,
		Active = false,
		ClipsDescendants = false,
	}, children)
end
-- A number stamped out of the strike: it pops past full size and settles,
-- floats up decelerating, drifts a little, and fades out as it slows. A
-- critical hit is bigger, flashes white first and lands with a small tilt.
local POP_LIFE = 0.8
function ClickPop(_param)
	local pop = _param.pop
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local size = if pop.critical then 34 else 24
	local rise = if pop.critical then 118 else 86
	local drift = (Fx.hash(pop.id, 3) - 0.5) * 36
	local tilt = if pop.critical then (Fx.hash(pop.id, 4) - 0.5) * 12 else 0
	local position = clock:map(function(seconds)
		local t = Motion.EASE.decelerate(clamp01(seconds / POP_LIFE))
		return UDim2.fromScale(pop.x, pop.y) + UDim2.fromOffset(drift * t, -t * rise)
	end)
	local scale = clock:map(function(seconds)
		if reducedMotion then
			return 1
		end
		return Fx.popScale(seconds, if pop.critical then 0.24 else 0.18, if pop.critical then 0.55 else 0.4)
	end)
	local color = if pop.critical
		then clock:map(function(seconds)
			return pop.color:Lerp(Palette.white, Fx.heat(seconds, 0.14))
		end)
		else pop.color
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if pop.critical then 168 else 128, 40),
		Position = position,
		Rotation = clock:map(function(seconds)
			return tilt * (1 - Motion.EASE.decelerate(clamp01(seconds / 0.35)))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 97,
	}, React.createElement("uiscale", {
		Scale = scale,
	}), React.createElement(Text, {
		value = pop.text,
		size = size,
		color = color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
		transparency = clock:map(function(seconds)
			return Fx.fade(seconds, POP_LIFE, 0.5)
		end),
	}))
end
local function ComboBanner(_param)
	local combo = _param.combo
	local heat = _param.heat
	local perfect = _param.perfect
	local reducedMotion = _param.reducedMotion
	local pulse = useClock(not reducedMotion and combo > 1, 1.05)
	-- Every new link in the streak kicks the banner, then it settles.
	local bump = useFlash(combo, reducedMotion, 0.3)
	local accent = if perfect then Palette.mango elseif heat > 0.82 then Palette.coral else Palette.brass
	if combo <= 1 then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(240, 52),
		Position = UDim2.fromScale(0.5, 0.145),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 70,
	}, React.createElement("uiscale", {
		Scale = React.joinBindings({ pulse, bump }):map(function(values)
			return 1 + math.sin(values[1]) * (if perfect then 0.045 else 0.022) + values[2] * 0.16
		end),
	}), React.createElement(Text, {
		value = if perfect then "CRIT" else "STREAK",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = `x{combo}`,
		size = if combo >= 10 then 30 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, 14),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}))
end
local function HeatHaze(_param)
	local heat = _param.heat
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion and heat > 0.12, 0.22)
	local strength = math.clamp(heat, 0, 1)
	if strength <= 0.02 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1.08, 0, 0.42, 0),
		Position = clock:map(function(phase)
			return UDim2.new(-0.04 + math.sin(phase) * 0.02, 0, 0.48 + math.cos(phase * 0.7) * 0.012, 0)
		end),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = 1 - 0.07 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(420, 420),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 1 - 0.05 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function FluxRiver(_param)
	local stations = _param.stations
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local clock = useClock(not reducedMotion, 0.55)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#stations)
	local _callback = function(station, index)
		return if station.live then React.createElement("frame", {
			key = `river-{index}`,
			Size = UDim2.fromOffset(3, 3),
			Position = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				local x = station.x + (0.5 - station.x) * t
				local y = station.y + (0.58 - station.y) * t - math.sin(t * math.pi) * 0.04
				return UDim2.fromScale(x, y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = station.color,
			BackgroundTransparency = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				return 0.15 + (1 - math.sin(t * math.pi)) * 0.7
			end),
			BorderSizePixel = 0,
			ZIndex = 7,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})) else nil
	end
	for _k, _v in stations do
		_newValue[_k] = _callback(_v, _k - 1, stations)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Active = false,
	}, _newValue, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromOffset(8 + math.sin(phase) * 3, 8 + math.sin(phase) * 3)
		end),
		Position = UDim2.fromScale(0.5, 0.58),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function WorldHaze(_param)
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.07)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Palette.void), ColorSequenceKeypoint.new(0.42, darken(color, 0.82)), ColorSequenceKeypoint.new(1, Palette.ink) }),
		Rotation = 118,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(720, 720),
		Position = clock:map(function(phase)
			return UDim2.new(1, 90 + math.sin(phase) * 28, 1, 50 + math.cos(phase * 0.7) * 20)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(460, 460),
		Position = UDim2.new(0, -90, 0, -70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 1, -160),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.12) }),
		Rotation = 90,
	})))
end
local function CoreAura(_param)
	local color = _param.color
	local heat = _param.heat
	local squash = _param.squash
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.16)
	local glow = math.clamp(0.16 + heat * 0.22, 0.16, 0.4)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 18,
		Active = false,
	}, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromScale(0.72 + math.sin(phase) * 0.03, 0.72 + math.sin(phase) * 0.03)
		end),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - glow,
		BorderSizePixel = 0,
		ZIndex = 18,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(lighten(color, 0.2), 0.8),
		Rotation = 90,
	})))
end
return {
	ShockRing = ShockRing,
	SparkBurst = SparkBurst,
	ClickPops = ClickPops,
	ComboBanner = ComboBanner,
	HeatHaze = HeatHaze,
	FluxRiver = FluxRiver,
	WorldHaze = WorldHaze,
	CoreAura = CoreAura,
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
