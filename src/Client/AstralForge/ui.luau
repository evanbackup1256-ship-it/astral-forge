local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local _Icon = require(script.Parent.Icon)
local GAME_ICON_ASSET = _Icon.GAME_ICON_ASSET
local Icon = _Icon.Icon
local _motion = require(script.Parent.motion)
local ExitPresenceContext = _motion.ExitPresenceContext
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useExitPresence = _motion.useExitPresence
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useGlowStroke = _motion.useGlowStroke
local useMotionSettings = _motion.useMotionSettings
local useOptionalFlipperSpring = _motion.useOptionalFlipperSpring
local usePulse = _motion.usePulse
local useRotation = _motion.useRotation
local useSpring = _motion.useSpring
local useSprScale = _motion.useSprScale
local useViewport = _motion.useViewport
local compactNumber = require(script.Parent.format).compactNumber
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local Layout = _theme.Layout
local Chrome = _theme.Chrome
local darken = _theme.darken
local lighten = _theme.lighten
local contrastOn = _theme.contrastOn
local ensureContrast = _theme.ensureContrast
local chromeFor = _theme.chromeFor
local surfaceGradient = _theme.surfaceGradient
local strokeGradient = _theme.strokeGradient
local TapTarget = _theme.TapTarget
local _audio = require(script.Parent.audio)
local Audio = _audio.Audio
local buttonAudioCue = _audio.buttonAudioCue
local InteractionFeedback = require(script.Parent.interaction).InteractionFeedback
local TouchGestureService = require(script.Parent.input.TouchGestureService)
local dropdownPortal
local dropdownPortalUsers = 0
local function acquireDropdownPortal()
	if dropdownPortal == nil or dropdownPortal.Parent == nil then
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local rootScreen = playerGui:FindFirstChild("AstralForgeStudioUI")
		if rootScreen ~= nil and rootScreen:IsA("ScreenGui") then
			dropdownPortal = rootScreen
		else
			dropdownPortal = playerGui
		end
	end
	dropdownPortalUsers += 1
	return dropdownPortal
end
local function releaseDropdownPortal()
	dropdownPortalUsers = math.max(0, dropdownPortalUsers - 1)
	if dropdownPortalUsers == 0 then
		dropdownPortal = nil
	end
end
local function Stroke(_param)
	local color = _param.color
	local thickness = _param.thickness
	if thickness == nil then
		thickness = 1
	end
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local gradientColor
	if typeof(color) == "Color3" then
		gradientColor = strokeGradient(color)
	elseif type(color) == "table" and type(color.map) == "function" then
		gradientColor = color:map(function(value)
			if typeof(value) ~= "Color3" then
				return strokeGradient(Palette.lineSoft)
			end
			return strokeGradient(value)
		end)
	else
		gradientColor = strokeGradient(Palette.lineSoft)
	end
	return React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = color,
		Thickness = thickness,
		Transparency = transparency,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = gradientColor,
	}))
end
local MIN_UI_TEXT_SIZE = 10
local BUTTON_LABEL_SIZE = 15
local buttonLabelWidthCache = {}
local buttonLabelWidthCacheCount = 0
local function measureButtonLabel(label)
	local _label = label
	local cached = buttonLabelWidthCache[_label]
	if cached ~= nil then
		return cached
	end
	local width = math.ceil(TextService:GetTextSize(label, BUTTON_LABEL_SIZE, Enum.Font.BuilderSansBold, Vector2.new(2400, 48)).X) + 6
	if buttonLabelWidthCacheCount >= 256 then
		table.clear(buttonLabelWidthCache)
		buttonLabelWidthCacheCount = 0
	end
	local _label_1 = label
	buttonLabelWidthCache[_label_1] = width
	buttonLabelWidthCacheCount += 1
	return width
end
local function buttonContentWidth(label, hasIcon)
	local textW = measureButtonLabel(label)
	return if hasIcon then 10 + 22 + 8 + textW + 10 else 10 + textW + 10
end
-- Layout guard turns overflow into TextScaled. Button labels stay one line and
-- ellipsize; combining that with TextScaled makes the word shrink and clip.
local function pinButtonLabel(instance)
	if instance ~= nil then
		instance:SetAttribute("LayoutGuardIgnore", true)
	end
end
-- Soft glass-glint: narrow bright core with a long low-contrast tail. Peak stays
-- above 0.12 so idle shimmer reads as light, not a strobe.
local SHIMMER_GLINT = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.47, 0.55), NumberSequenceKeypoint.new(0.5, 0.18), NumberSequenceKeypoint.new(0.54, 0.55), NumberSequenceKeypoint.new(0.72, 0.92), NumberSequenceKeypoint.new(1, 1) })
local SHIMMER_SWEEP_SPEED = 0.72
local inputCancelListeners = {}
local inputCancelConnection
local menuCancelConnection
local function subscribeInputCancellation(listener)
	local _listener = listener
	inputCancelListeners[_listener] = true
	if inputCancelConnection == nil then
		local cancelAll = function()
			for cancel in inputCancelListeners do
				cancel()
			end
		end
		inputCancelConnection = UserInputService.WindowFocusReleased:Connect(cancelAll)
		menuCancelConnection = GuiService.MenuOpened:Connect(cancelAll)
	end
	return function()
		local _listener_1 = listener
		inputCancelListeners[_listener_1] = nil
		-- ▼ ReadonlySet.size ▼
		local _size = 0
		for _ in inputCancelListeners do
			_size += 1
		end
		-- ▲ ReadonlySet.size ▲
		if _size > 0 then
			return nil
		end
		local _result = inputCancelConnection
		if _result ~= nil then
			_result:Disconnect()
		end
		local _result_1 = menuCancelConnection
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		inputCancelConnection = nil
		menuCancelConnection = nil
	end
end
local function isValidSelectionTarget(object)
	if object == nil or not object:IsA("GuiObject") or object.Parent == nil then
		return false
	end
	if object.AbsoluteSize.X < 2 or object.AbsoluteSize.Y < 2 then
		return false
	end
	local layer = object:FindFirstAncestorWhichIsA("LayerCollector")
	if layer == nil then
		return false
	end
	local current = object
	while current ~= nil and current ~= layer do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end
		current = current.Parent
	end
	if object:IsA("GuiButton") and (not object.Selectable or not object.Active) then
		return false
	end
	return true
end
local function assignSelectedObject(object)
	if not isValidSelectionTarget(object) then
		return nil
	end
	pcall(function()
		GuiService.SelectedObject = object
	end)
end
local function lastInputIsGamepad()
	local inputType = UserInputService:GetLastInputType()
	return inputType == Enum.UserInputType.Gamepad1 or inputType == Enum.UserInputType.Gamepad2 or inputType == Enum.UserInputType.Gamepad3 or inputType == Enum.UserInputType.Gamepad4
end
local function useGamepadAutofocus(active)
	local rootRef = React.useRef()
	React.useEffect(function()
		if not active or not lastInputIsGamepad() then
			return nil
		end
		local previous = GuiService.SelectedObject
		local worker = task.delay(0.16, function()
			local root = rootRef.current
			if root == nil then
				return nil
			end
			for _, child in root:GetDescendants() do
				if child:IsA("GuiButton") and isValidSelectionTarget(child) then
					assignSelectedObject(child)
					return nil
				end
			end
		end)
		return function()
			task.cancel(worker)
			if isValidSelectionTarget(previous) then
				assignSelectedObject(previous)
			end
		end
	end, { active })
	return rootRef
end
local UiEffectsPausedContext = React.createContext(false)
local function withExitFade(localFade, presence)
	local _localFade = localFade
	local _condition = type(_localFade) == "number"
	if _condition then
		_condition = localFade == 0
	end
	if _condition then
		return presence:map(function(shown)
			return math.clamp(1 - shown, 0, 1)
		end)
	end
	local _localFade_1 = localFade
	if type(_localFade_1) == "number" then
		return presence:map(function(shown)
			return math.clamp(localFade + (1 - shown), 0, 1)
		end)
	end
	return React.joinBindings({ localFade, presence }):map(function(values)
		return math.clamp(values[1] + (1 - values[2]), 0, 1)
	end)
end
local function Text(_param)
	local value = _param.value
	local size = _param.size
	if size == nil then
		size = 16
	end
	local color = _param.color
	if color == nil then
		color = Palette.cream
	end
	local surface = _param.surface
	local weight = _param.weight
	if weight == nil then
		weight = Enum.FontWeight.Medium
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local fit = _param.fit
	if fit == nil then
		fit = false
	end
	local wrap = _param.wrap
	if wrap == nil then
		wrap = false
	end
	local minSize = _param.minSize
	local position = _param.position
	local sizeConstraint = _param.sizeConstraint
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local _binding = useMotionSettings()
	local textScale = _binding.textScale
	local boldText = _binding.boldText
	if boldText == nil then
		boldText = 0
	end
	local presence = useExitPresence()
	local faded = withExitFade(transparency, presence)
	local scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42)
	local font = if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold or boldText >= 0.5 then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	local painted = if surface ~= nil and typeof(color) == "Color3" then ensureContrast(surface, color) else color
	local constraint = false
	if fit then
		local floorSize = minSize
		if floorSize == nil then
			floorSize = math.max(MIN_UI_TEXT_SIZE, size * 0.72)
		end
		constraint = React.createElement("uitextsizeconstraint", {
			MinTextSize = math.clamp(math.floor(floorSize * textScale), MIN_UI_TEXT_SIZE, scaledSize),
			MaxTextSize = scaledSize,
		})
	end
	return React.createElement("textlabel", {
		Size = sizeConstraint or UDim2.fromScale(1, 1),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoLocalize = true,
		Text = value,
		TextColor3 = painted,
		TextSize = scaledSize,
		TextTransparency = faded,
		FontFace = Font.fromEnum(font),
		TextXAlignment = align,
		TextYAlignment = if wrap then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		TextWrapped = wrap,
		TextScaled = fit,
		LineHeight = if wrap then 1.12 else 1,
		TextTruncate = if wrap or fit then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
	}, constraint)
end
local function fontForWeight(weight)
	return if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
end
-- Real fix for the class of bug found repeatedly across pages this session: a row/card hardcodes
-- one fixed height (e.g. "150px, that fits two lines of description") that was tuned against one
-- example string and silently truncates or overlaps neighboring content the moment a longer
-- string (a longer relic name, a longer season reward line, a translated string) doesn't fit that
-- guess. This measures what a wrapped string will ACTUALLY render at, at a given width, so a
-- caller can size its row/card from the real content instead of a guess. Pass the same
-- size/weight/wrap width the real <Text> will use so the measurement matches what's on screen.
local function measureWrappedTextHeight(text, width, size, weight)
	if size == nil then
		size = 16
	end
	if weight == nil then
		weight = Enum.FontWeight.Medium
	end
	if text == "" or width <= 0 then
		return 0
	end
	local font = fontForWeight(weight)
	local bounds = TextService:GetTextSize(text, math.max(1, math.floor(size)), font, Vector2.new(math.max(1, math.floor(width)), 4000))
	return math.ceil(bounds.Y)
end
-- Drop-in for the common "label + a description that might run long" pattern: wraps, sizes itself
-- to its own real rendered content height via AutomaticSize (not a fixed sizeConstraint Y that
-- can silently be too short), and reports that real height back to the caller through
-- `onHeightChange` so a manually-height-computing row/card (VirtualGrid rows, canvas-height sums
-- -- the pattern used everywhere in this codebase) can size itself from real content instead of a
-- tuned-against-one-example constant. Width still comes from the caller (`sizeConstraint`'s X, or
-- `width`) since horizontal space is normally the fixed/known axis; only height grows.
local function AutoHeightText(_param)
	local value = _param.value
	local width = _param.width
	local size = _param.size
	if size == nil then
		size = 13
	end
	local color = _param.color
	if color == nil then
		color = Palette.creamSoft
	end
	local weight = _param.weight
	if weight == nil then
		weight = Enum.FontWeight.Medium
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local position = _param.position
	local minHeight = _param.minHeight
	if minHeight == nil then
		minHeight = 0
	end
	local maxHeight = _param.maxHeight
	local onHeightChange = _param.onHeightChange
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local _binding = useMotionSettings()
	local textScale = _binding.textScale
	local boldText = _binding.boldText
	if boldText == nil then
		boldText = 0
	end
	local scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42)
	local font = fontForWeight(if weight == Enum.FontWeight.Bold and boldText >= 0.5 then Enum.FontWeight.Bold else weight)
	local measured = math.ceil(TextService:GetTextSize(value, scaledSize, font, Vector2.new(math.max(1, math.floor(width)), 4000)).Y)
	local clamped = math.max(minHeight, if maxHeight ~= nil then math.min(maxHeight, measured) else measured)
	local lastReported = React.useRef()
	React.useEffect(function()
		if onHeightChange == nil or lastReported.current == clamped then
			return nil
		end
		lastReported.current = clamped
		onHeightChange(clamped)
	end, { clamped, onHeightChange })
	return React.createElement("textlabel", {
		Size = UDim2.new(0, width, 0, clamped),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoLocalize = true,
		Text = value,
		TextColor3 = color,
		TextSize = scaledSize,
		TextTransparency = transparency,
		FontFace = Font.fromEnum(font),
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LineHeight = 1.12,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
	})
end
local function OverlayPresence(_param)
	local amount = _param.amount
	local children = _param.children
	return React.createElement(ExitPresenceContext.Provider, {
		value = amount,
	}, children)
end
local function ShimmerText(_param)
	local value = _param.value
	local size = _param.size
	if size == nil then
		size = 22
	end
	local color = _param.color
	if color == nil then
		color = Palette.cream
	end
	local weight = _param.weight
	if weight == nil then
		weight = Enum.FontWeight.Heavy
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local fit = _param.fit
	if fit == nil then
		fit = false
	end
	local minSize = _param.minSize
	local position = _param.position
	local sizeConstraint = _param.sizeConstraint
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local enabled = _param.enabled
	if enabled == nil then
		enabled = false
	end
	local periodSeconds = _param.periodSeconds
	if periodSeconds == nil then
		periodSeconds = 3.6
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local _binding = useMotionSettings()
	local textScale = _binding.textScale
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	local want = enabled and shimmerScale > 0.02
	local speed = 1 / math.max(1.2, periodSeconds)
	local phase = useClock(want, speed, 1, true)
	local scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42)
	local font = if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	local _exp = React.createElement(Text, {
		value = value,
		size = size,
		color = color,
		weight = weight,
		align = align,
		fit = fit,
		minSize = minSize,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = zIndex,
	})
	local _condition = want
	if _condition then
		local floorSize = if minSize ~= nil then minSize else MIN_UI_TEXT_SIZE
		local minText = math.clamp(math.floor(floorSize * textScale + 0.5), MIN_UI_TEXT_SIZE, scaledSize)
		local shimmerConstraint = React.createElement("uitextsizeconstraint", {
			MinTextSize = minText,
			MaxTextSize = scaledSize,
		})
		_condition = React.createElement("textlabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoLocalize = true,
			Text = value,
			TextColor3 = Palette.white,
			TextSize = scaledSize,
			FontFace = Font.fromEnum(font),
			TextXAlignment = align,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = zIndex + 1,
		}, shimmerConstraint, React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.white),
			Transparency = SHIMMER_GLINT,
			Offset = phase:map(function(amount)
				return Vector2.new(amount * 2.2 - 1.1, 0)
			end),
			Rotation = 12,
		}))
	end
	return React.createElement("frame", {
		Size = sizeConstraint or UDim2.fromScale(1, 1),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, _exp, _condition)
end
local function SectionLabel(_param)
	local value = _param.value
	local color = _param.color
	if color == nil then
		color = Palette.muted
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local position = _param.position
	local labelColor = ensureContrast(Palette.night, color)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 22),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(22, 3),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = Chrome.accentHairline,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.7, 0.22), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement(Text, {
		value = value,
		size = 14,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(30, 0),
		sizeConstraint = UDim2.new(1, -38, 0, 22),
	}))
end
local Button
local function QuantityStepper(_param)
	local label = _param.label
	local detail = _param.detail
	local value = _param.value
	local max = _param.max
	local accent = _param.accent
	if accent == nil then
		accent = Palette.mint
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local onChange = _param.onChange
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local viewport = useViewport()
	local stacked = viewport.width < 560 or viewport.height < 420
	local step = if max >= 100000 then math.max(1, math.floor(max / 20)) elseif max >= 100 then math.max(1, math.floor(max / 10)) else 1
	local atMin = value <= 0
	local atMax = value >= max or max <= 0
	local labelColor = contrastOn(accent)
	local controlH = if stacked then TapTarget else 36
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement(Stroke, {
		color = if value > 0 then accent else Palette.lineSoft,
		thickness = 1,
		transparency = if value > 0 then 0.28 else 0.55,
	})
	local _exp_2 = React.createElement(Text, {
		value = label,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(12, 6),
		sizeConstraint = UDim2.new(1, if stacked then -16 else -220, 0, 18),
	})
	local _attributes = {}
	local _condition = detail
	if _condition == nil then
		_condition = (if max <= 0 then "None tradable" else `{compactNumber(value)} / {compactNumber(max)}`)
	end
	_attributes.value = _condition
	_attributes.size = 12
	_attributes.color = if value > 0 then accent else Palette.muted
	_attributes.weight = Enum.FontWeight.Bold
	_attributes.position = UDim2.fromOffset(12, 26)
	_attributes.sizeConstraint = UDim2.new(1, if stacked then -16 else -220, 0, 16)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stacked then 108 else 52),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, React.createElement(Text, _attributes), React.createElement("frame", {
		Size = if stacked then UDim2.new(1, -16, 0, controlH) else UDim2.fromOffset(204, controlH),
		Position = if stacked then UDim2.new(0, 8, 1, -(controlH + 8)) else UDim2.new(1, -212, 0.5, -18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "-",
		onClick = function()
			return onChange(math.max(0, value - step))
		end,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(if stacked then 0.22 else 0, if stacked then -4 else 36, 1, 0),
		disabled = atMin,
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = compactNumber(value),
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = if stacked then UDim2.new(0.22, 0, 0, 0) else UDim2.fromOffset(36, 0),
		sizeConstraint = if stacked then UDim2.new(0.28, 0, 1, 0) else UDim2.fromOffset(56, 36),
	}), React.createElement(Button, {
		text = "+",
		onClick = function()
			return onChange(math.min(max, value + step))
		end,
		color = if atMax then Palette.panelSoft else accent,
		textColor = if atMax then Palette.muted else labelColor,
		size = if stacked then UDim2.new(0.22, -4, 1, 0) else UDim2.fromOffset(36, 36),
		position = if stacked then UDim2.new(0.50, 2, 0, 0) else UDim2.fromOffset(96, 0),
		disabled = atMax,
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = "MAX",
		onClick = function()
			return onChange(max)
		end,
		color = Palette.panelRaised,
		textColor = accent,
		size = if stacked then UDim2.new(0.28, -4, 1, 0) else UDim2.fromOffset(64, 36),
		position = if stacked then UDim2.new(0.72, 2, 0, 0) else UDim2.fromOffset(136, 0),
		disabled = atMax,
		reducedMotion = reducedMotion,
	})))
end
local SCROLL_EDGE = 18
local function ScrollEdgeFade(_param)
	local color = _param.color
	if color == nil then
		color = Palette.ink
	end
	local height = _param.height
	if height == nil then
		height = SCROLL_EDGE
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 200
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = false,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.68), NumberSequenceKeypoint.new(0.55, 0.9), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.new(0, 0, 1, -height),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = false,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.9), NumberSequenceKeypoint.new(1, 0.68) }),
	})))
end
-- A ring drawn as a stroke whose transparency sweeps around it via a rotating uigradient,
-- instead of a couple of small dots orbiting a plain circle outline. `spin` should be a
-- continuous per-frame rotation binding (e.g. from useRotation) — the gradient rotation tracks
-- it exactly, so the "light" always flows smoothly around the ring regardless of speed. This
-- reads as flowing energy rather than a sparse handful of dots swinging around a ring, which is
-- what made ring-and-orbit visuals (EchoLoom, ContinuumCore) look choppy even when their
-- underlying rotation was already frame-accurate.
local function SweptRing(_param)
	local scale = _param.scale
	local color = _param.color
	local thickness = _param.thickness
	local spin = _param.spin
	local sweepWidth = _param.sweepWidth
	if sweepWidth == nil then
		sweepWidth = 0.22
	end
	local gradientRotation = spin:map(function(degrees)
		return math.floor(degrees)
	end)
	local keypoints = { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(math.max(0.001, sweepWidth * 0.5), 0.15), NumberSequenceKeypoint.new(sweepWidth, 1), NumberSequenceKeypoint.new(1, 1) }
	return React.createElement("frame", {
		Size = UDim2.fromScale(scale, scale),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = color,
		Thickness = thickness,
		Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = gradientRotation,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = color,
		Thickness = thickness + 0.5,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new(keypoints),
		Rotation = 90,
	}))))
end
local function OrbitDot(_param)
	local radiusScale = _param.radiusScale
	local angleDeg = _param.angleDeg
	local size = _param.size
	local color = _param.color
	local glow = _param.glow
	if glow == nil then
		glow = false
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 3
	end
	local rad = math.rad(angleDeg)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5 + math.cos(rad) * radiusScale, 0.5 + math.sin(rad) * radiusScale),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), glow and React.createElement("frame", {
		Size = UDim2.fromScale(2.2, 2.2),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = zIndex - 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function ScrollPads(_param)
	local edge = _param.edge
	if edge == nil then
		edge = SCROLL_EDGE
	end
	return React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, edge),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = -100000,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, edge),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 100000,
	}))
end
local function IconTile(_param)
	local kind = _param.kind
	local accent = _param.accent
	local size = _param.size
	if size == nil then
		size = 48
	end
	local radius = _param.radius
	local position = _param.position
	local anchorPoint = _param.anchorPoint
	local spin = _param.spin
	if spin == nil then
		spin = false
	end
	local hoverAmount = _param.hoverAmount
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local glow = _param.glow
	if glow == nil then
		glow = false
	end
	local filled = _param.filled
	if filled == nil then
		filled = false
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local interactionMotion = reducedMotion or effectsPaused
	local background = if filled then darken(accent, 0.22) else darken(accent, 0.42):Lerp(Palette.panelSoft, 0.28)
	local glyph = Palette.cream
	local strokeTransparency = useGlowStroke(glow and not interactionMotion, interactionMotion, 0.55, 0.2, 0.62, 2.1)
	local _condition = radius
	if _condition == nil then
		_condition = math.floor(size * 0.26)
	end
	local corner = _condition
	local inset = 2
	local inner = math.max(12, size - inset * 2)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(inner, inner),
		Position = UDim2.fromOffset(inset, inset),
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, math.max(1, corner - 1)),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(background, 0.62),
		Rotation = 90,
	}), React.createElement(Icon, {
		kind = kind,
		color = glyph,
		accent = accent,
		size = inner,
		spin = spin,
		hoverAmount = hoverAmount,
		clipSafe = true,
		reducedMotion = reducedMotion,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(inner, inner),
		Position = UDim2.fromOffset(inset, inset),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, math.max(1, corner - 1)),
	}), React.createElement(Stroke, {
		color = accent,
		thickness = 1,
		transparency = if glow then strokeTransparency elseif filled then 0.28 else 0.4,
	})))
end
local function Badge(_param)
	local value = _param.value
	local accent = _param.accent
	if accent == nil then
		accent = Palette.cyan
	end
	local filled = _param.filled
	if filled == nil then
		filled = false
	end
	local position = _param.position
	local size = _param.size
	if size == nil then
		size = UDim2.fromOffset(78, 26)
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 3
	end
	local fill = if filled then darken(accent, 0.28) else Palette.panelRaised
	local label = ensureContrast(fill, if filled then Palette.cream else lighten(accent, 0.18))
	local compressLabel = #value > 7
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = fill,
		BackgroundTransparency = if filled then 0 else 0.04,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(fill, 0.55),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}), React.createElement(Stroke, {
		color = accent,
		thickness = 1,
		transparency = if filled then 0.36 else 0.28,
	})), filled and React.createElement("frame", {
		Size = UDim2.new(0.38, 0, 0, 2),
		Position = UDim2.fromOffset(8, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement(Text, {
		value = value,
		size = 13,
		color = label,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = compressLabel,
		minSize = 12,
		position = UDim2.fromOffset(7, 0),
		sizeConstraint = UDim2.new(1, -12, 1, 0),
		zIndex = zIndex + 1,
	}))
end
local function CountBadge(_param)
	local count = _param.count
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 50
	end
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local scaleRef = useSprScale(1, effectsPaused, 0.68, 0.64, 13)
	if count <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local label = tostring(math.min(99, math.floor(count)))
	local wide = count >= 10
	local size = if compact then (if wide then 16 else 14) else (if wide then 20 else 16)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.new(1, if compact then -2 else -3, 0, if compact then 2 else 3),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, React.createElement(ScaleFromCenter, {
		scaleRef = scaleRef,
		zIndex = zIndex,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.coral,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Stroke, {
		color = Palette.cream,
		thickness = 1,
		transparency = 0.55,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 1, -1),
		Position = UDim2.fromOffset(0, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = Palette.cream,
		TextSize = MIN_UI_TEXT_SIZE,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextScaled = true,
		TextWrapped = false,
		ZIndex = zIndex + 1,
	}, React.createElement("uitextsizeconstraint", {
		MinTextSize = 8,
		MaxTextSize = MIN_UI_TEXT_SIZE,
	})))))
end
local function Panel(_param)
	local children = _param.children
	local size = _param.size
	local position = _param.position
	local accent = _param.accent
	local background = _param.background
	if background == nil then
		background = Palette.panel
	end
	local radius = _param.radius
	if radius == nil then
		radius = Layout.cardRadius
	end
	local padding = _param.padding
	if padding == nil then
		padding = 14
	elseif padding > 16 then
		-- Callers still pass 18–22 from Layout.cardPadding. Cap so cards share one inset.
		padding = 16
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local stroke = _param.stroke
	if stroke == nil then
		stroke = true
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local clips = _param.clips
	if clips == nil then
		clips = false
	end
	local reveal = _param.reveal
	local interactive = _param.interactive
	if interactive == nil then
		interactive = false
	end
	local shimmer = _param.shimmer
	if shimmer == nil then
		shimmer = false
	end
	local highlight = _param.highlight
	if highlight == nil then
		highlight = false
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local hovered, setHovered = React.useState(false)
	local hoverArmed, setHoverArmed = React.useState(false)
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local _binding = useMotionSettings()
	local panelHoverScale = _binding.panelHoverScale
	if panelHoverScale == nil then
		panelHoverScale = 1
	end
	local panelEntranceScale = _binding.panelEntranceScale
	if panelEntranceScale == nil then
		panelEntranceScale = 1
	end
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	local interactionMotion = reducedMotion or effectsPaused
	local entranceMotion = interactionMotion or panelEntranceScale <= 0.02 or reveal ~= nil
	local automaticReveal = useEntrance(entranceMotion)
	local activeReveal = reveal or automaticReveal
	React.useEffect(function()
		if hovered then
			setHoverArmed(true)
		end
	end, { hovered })
	local lift = useOptionalFlipperSpring(if interactive and hovered and not effectsPaused and panelHoverScale > 0.02 then panelHoverScale else 0, interactive and hoverArmed, interactionMotion, 480, 38)
	local accentColor = accent or Palette.lineSoft
	local highlightOn = useOptionalFlipperSpring(if highlight and not effectsPaused then 1 else 0, highlight, interactionMotion, 420, 36)
	local shimmerWanted = shimmer and interactive and shimmerScale > 0.02 and not interactionMotion
	local whiteSweep = useClock(shimmerWanted and hovered, SHIMMER_SWEEP_SPEED, 1, true)
	-- Clear hover glow on interactive cards with an accent color — separate from the subtle
	-- stroke-brighten below, gated on ambient FX the same way the shimmer sweep above is.
	local glowWanted = interactive and accent ~= nil and not interactionMotion
	local hoverGlow = useOptionalFlipperSpring(if glowWanted and hovered then 1 else 0, interactive and hoverArmed, interactionMotion, 460, 38)
	local revealFade = React.useMemo(function()
		return activeReveal:map(function(amount)
			return 1 - math.clamp(amount, 0, 1)
		end)
	end, { activeReveal })
	local strokeTransparency = React.useMemo(function()
		local live = React.joinBindings({ lift, highlightOn }):map(function(values)
			local hover = values[1]
			local lit = values[2]
			return math.clamp(Chrome.panelStrokeIdle - hover * 0.14 - lit * 0.18, Chrome.panelStrokeHover, 0.72)
		end)
		if revealFade == nil then
			return live
		end
		return React.joinBindings({ live, revealFade }):map(function(values)
			return math.clamp(values[1] + values[2], 0, 1)
		end)
	end, { highlightOn, lift, revealFade })
	local strokeColor = highlightOn:map(function(amount)
		return if amount >= 0.45 then accentColor else Palette.lineSoft
	end)
	local surfaceTransparency = if revealFade ~= nil then revealFade else 0
	local paintChrome = true
	local liftPx = lift:map(function(amount)
		return -math.round(amount)
	end)
	local revealY = activeReveal:map(function(amount)
		return math.round((1 - math.clamp(amount, 0, 1)) * 10)
	end)
	local surfaceY = React.joinBindings({ liftPx, revealY }):map(function(values)
		return values[1] + values[2]
	end)
	local hoverWashVisible = lift:map(function(amount)
		return amount > 0.04
	end)
	local hoverWashAlpha = lift:map(function(amount)
		return if amount < 0.04 then 1 else 1 - amount * 0.14
	end)
	local highlightWashVisible = highlightOn:map(function(amount)
		return amount > 0.05
	end)
	local highlightWashAlpha = highlightOn:map(function(amount)
		return if amount < 0.05 then 1 else 0.94 + (1 - amount) * 0.06
	end)
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
		Event = if interactive then {
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		} else {},
	}, paintChrome and React.createElement("frame", {
		Size = UDim2.new(1, 8, 1, -1),
		Position = surfaceY:map(function(y)
			return UDim2.new(0, -4, 0, 7 + y)
		end),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = if revealFade ~= nil then revealFade:map(function(amount)
			return math.clamp(Chrome.panelShadow + amount * (1 - Chrome.panelShadow), 0, 1)
		end) else Chrome.panelShadow,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius + 2),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = if paintChrome then surfaceY:map(function(y)
			return UDim2.new(0, 0, 0, y)
		end) else UDim2.fromScale(0, 0),
		BackgroundColor3 = background,
		BackgroundTransparency = surfaceTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(background, 0.92),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -(radius + 6), 0, 1),
		Position = UDim2.fromOffset(math.floor(radius * 0.5) + 3, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	})), stroke and React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, math.max(1, radius - 1)),
	}), React.createElement(Stroke, {
		color = strokeColor,
		thickness = 1,
		transparency = strokeTransparency,
	})), glowWanted and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Visible = hoverGlow:map(function(amount)
			return amount > 0.02
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement(Stroke, {
		color = accentColor,
		thickness = hoverGlow:map(function(amount)
			return 1 + amount * 1.8
		end),
		transparency = hoverGlow:map(function(amount)
			return 1 - amount * 0.78
		end),
	})), interactive and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = hoverWashAlpha,
		BorderSizePixel = 0,
		Visible = hoverWashVisible,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), shimmer and not interactionMotion and React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white),
		Rotation = 14,
		Transparency = SHIMMER_GLINT,
		Offset = whiteSweep:map(function(phase)
			return Vector2.new(phase * 2.25 - 1.12, 0)
		end),
	})), highlight and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = highlightWashAlpha,
		BorderSizePixel = 0,
		Visible = highlightWashVisible,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), accent ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(math.max(44, radius * 5), 2),
		Position = UDim2.fromOffset(radius + 2, 0),
		BackgroundColor3 = accent,
		BackgroundTransparency = if revealFade ~= nil then revealFade:map(function(amount)
			return math.clamp(Chrome.accentHairline + amount * (1 - Chrome.accentHairline), 0, 1)
		end) else Chrome.accentHairline,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.66, 0.18), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement("frame", {
		Size = UDim2.new(1, -padding * 2, 1, -padding * 2),
		Position = UDim2.fromOffset(padding, padding),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		ClipsDescendants = clips,
	}, children))))
end
local function Divider(_param)
	local position = _param.position
	local color = _param.color
	if color == nil then
		color = Palette.lineSoft
	end
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0.72
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = position,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0.35), NumberSequenceKeypoint.new(0.82, 0.35), NumberSequenceKeypoint.new(1, 1) }),
	}))
end
local PRIMARY_ACTION = {
	collect = true,
	buy = true,
	rebirth = true,
	claim = true,
}
local function labelMarksPrimary(text)
	if type(text) ~= "string" or text == "" then
		return false
	end
	for word in string.gmatch(string.lower(text), "%a+") do
		if PRIMARY_ACTION[word] == true then
			return true
		end
	end
	return false
end
local function pressAspect(size)
	if typeof(size) ~= "UDim2" then
		return nil, false
	end
	local xScale = size.X.Scale
	local yScale = size.Y.Scale
	local xOffset = math.abs(size.X.Offset)
	local yOffset = math.abs(size.Y.Offset)
	if xScale == 0 and yScale == 0 and xOffset > 0 and yOffset > 0 then
		return xOffset / yOffset, false
	end
	if xScale >= 0.9 and yScale < 0.5 then
		return nil, true
	end
	if xScale > 0 and yScale > 0 then
		return xScale / yScale, false
	end
	if xOffset > 0 and yOffset > 0 then
		return xOffset / yOffset, xScale >= 0.9
	end
	return nil, xScale >= 0.9
end
-- One press policy for every shared button. Icon and square controls may tilt
-- about a degree. Text, wide bars, list rows, and primary actions only scale.
local function resolvePressMotion(spec)
	if type(spec) == "string" then
		spec = {
			kind = spec,
		}
	end
	if spec == nil then
		spec = {}
	end
	local kind = spec.kind
	if kind ~= "icon" and kind ~= "text" and kind ~= "row" then
		kind = nil
	end
	local text = spec.text
	local hasLabel = type(text) == "string" and text ~= ""
	local hasIcon = spec.icon ~= nil and spec.icon ~= false and spec.icon ~= ""
	local ratio, fullRow = pressAspect(spec.size)
	local square = ratio ~= nil and ratio >= (1 / 1.35) and ratio <= 1.35
	local wide = fullRow or (ratio ~= nil and ratio > 1.35)
	if kind == nil then
		if hasLabel and labelMarksPrimary(text) then
			kind = "row"
		elseif fullRow then
			kind = "row"
		elseif hasIcon and not hasLabel and not wide then
			kind = "icon"
		elseif square and not hasLabel then
			kind = "icon"
		else
			kind = "text"
		end
	end
	local hoverGain = 0.04
	local pressDrop = 0.07
	local tilt = 0
	if kind == "icon" then
		tilt = -1
	elseif kind == "row" then
		hoverGain = 0.02
	end
	return {
		kind = kind,
		hover = hoverGain,
		press = pressDrop,
		tilt = math.clamp(tilt, -1.5, 1.5),
	}
end
local function useButtonChrome(onClick, reducedMotion, disabled, sound, allowShimmer, _idleShimmer, motionSpec)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if disabled == nil then
		disabled = false
	end
	if sound == nil then
		sound = "click"
	end
	if allowShimmer == nil then
		allowShimmer = true
	end
	if _idleShimmer == nil then
		_idleShimmer = false
	end
	local viewport = useViewport()
	local _binding = useMotionSettings()
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local softMotion = reducedMotion or effectsPaused
	local touchChrome = viewport.compact or viewport.tight
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local gamepadFocused, setGamepadFocused = React.useState(false)
	local engaged, setEngaged = React.useState(false)
	local popTrigger, setPopTrigger = React.useState(0)
	local hoveredRef = React.useRef(false)
	local activeTouch = React.useRef()
	local activeTouchEnd = React.useRef()
	local touchOrigin = React.useRef()
	local lastActivationAt = React.useRef(-math.huge)
	local pressWasTouch = React.useRef(false)
	local hoverStall = React.useRef(0)
	local active = not disabled
	-- One motor for the life of the control. resolvePressMotion picks the scale
	-- and tilt. Release springs back. softMotion does not snap it.
	local poseGoal = if disabled then 0 elseif pressed then -1 elseif hovered then 1 else 0
	local pose = useOptionalFlipperSpring(poseGoal, true, softMotion, 1180, 46)
	local hoverAmount = pose:map(function(value)
		return math.clamp(value, 0, 1)
	end)
	local pressAmount = pose:map(function(value)
		return math.clamp(-value, 0, 1)
	end)
	local offsetY = pose:map(function(value)
		if value >= 0 then
			return -value * 1.4
		end
		return -value * 1.1
	end)
	local focusRing = useOptionalFlipperSpring(if gamepadFocused and active then 1 else 0, true, softMotion, 760, 32)
	-- Impact flash is keyed off popTrigger so every successful activate gets a
	-- one-shot white wash — previously useFlash(0) never fired.
	-- Repeat activates reset this same motor. Scale and tilt stay on the pose spring.
	local impact = useFlash(popTrigger, softMotion, if touchChrome then 0.2 else 0.26)
	-- idleShimmer buttons (highlight/selected states) keep ButtonShimmer visible even when not
	-- hovered -- the sweep clock has to keep running in that case too, or it freezes mid-gradient
	-- the instant hover ends and leaves a stuck streak baked into the always-visible idle frame
	-- instead of continuing its loop or fading cleanly away.
	local shimmerWanted = allowShimmer and shimmerScale > 0.02 and active and not softMotion
	local shimmer = useClock(shimmerWanted, SHIMMER_SWEEP_SPEED, 1, true)
	local surfaceSize = pose:map(function()
		return UDim2.fromScale(1, 1)
	end)
	local pressMotion = resolvePressMotion(motionSpec)
	local hoverGain = pressMotion.hover
	local pressDrop = pressMotion.press
	local tiltDegrees = pressMotion.tilt
	local touchScale = pose:map(function(value)
		if value >= 0 then
			return 1 + math.clamp(value, 0, 1) * hoverGain
		end
		return 1 - math.clamp(-value, 0, 1) * pressDrop
	end)
	local tilt = pose:map(function(value)
		return math.clamp(value, 0, 1) * tiltDegrees
	end)
	React.useEffect(function()
		local cancel = function()
			local _result = activeTouchEnd.current
			if _result ~= nil then
				_result:Disconnect()
			end
			activeTouchEnd.current = nil
			activeTouch.current = nil
			touchOrigin.current = nil
			setPressed(false)
		end
		local unsubscribe = subscribeInputCancellation(cancel)
		return function()
			unsubscribe()
			cancel()
		end
	end, {})
	React.useEffect(function()
		if not disabled then
			return nil
		end
		local _result = activeTouchEnd.current
		if _result ~= nil then
			_result:Disconnect()
		end
		activeTouchEnd.current = nil
		activeTouch.current = nil
		touchOrigin.current = nil
		pressWasTouch.current = false
		setPressed(false)
	end, { disabled })
	local markHover = function()
		if disabled or hoveredRef.current then
			return nil
		end
		setEngaged(true)
		hoveredRef.current = true
		setHovered(true)
		local now = os.clock()
		if now - hoverStall.current < 0.1 then
			return nil
		end
		hoverStall.current = now
		Audio:play("hover")
	end
	local clearHover = function()
		hoveredRef.current = false
		setHovered(false)
		setPressed(false)
	end
	local activate = function()
		if disabled then
			return nil
		end
		local now = os.clock()
		lastActivationAt.current = now
		setEngaged(true)
		setPressed(false)
		setPopTrigger(function(current)
			return current + 1
		end)
		local pressEnergy = if touchChrome then 1.08 else 1.03
		if sound ~= false then
			Audio:play(sound, pressEnergy)
		end
		onClick()
		InteractionFeedback.tap()
	end
	local finishTouch = function(input)
		if input ~= activeTouch.current then
			return nil
		end
		local origin = touchOrigin.current
		local _result = activeTouchEnd.current
		if _result ~= nil then
			_result:Disconnect()
		end
		activeTouchEnd.current = nil
		activeTouch.current = nil
		touchOrigin.current = nil
		setPressed(false)
		local distance = if origin ~= nil then (Vector2.new(input.Position.X, input.Position.Y) - origin).Magnitude else math.huge
		if distance <= 14 and os.clock() - lastActivationAt.current > 0.12 then
			activate()
		end
	end
	local events = if active then {
		MouseEnter = function()
			return markHover()
		end,
		MouseLeave = function()
			clearHover()
		end,
		SelectionGained = function()
			setEngaged(true)
			setGamepadFocused(true)
			markHover()
		end,
		SelectionLost = function()
			clearHover()
			setGamepadFocused(false)
		end,
		InputBegan = function(button, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then
				if input.UserInputType == Enum.UserInputType.Touch and activeTouch.current ~= nil then
					return nil
				end
				pressWasTouch.current = input.UserInputType == Enum.UserInputType.Touch
				setEngaged(true)
				setPressed(true)
				if input.UserInputType == Enum.UserInputType.Touch then
					activeTouch.current = input
					touchOrigin.current = Vector2.new(input.Position.X, input.Position.Y)
					local _result = activeTouchEnd.current
					if _result ~= nil then
						_result:Disconnect()
					end
					activeTouchEnd.current = UserInputService.InputEnded:Connect(finishTouch)
				end
			end
		end,
		InputEnded = function(_button, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then
				setPressed(false)
			end
			if input.UserInputType == Enum.UserInputType.Touch then
				finishTouch(input)
			end
		end,
		Activated = function()
			if pressWasTouch.current then
				return nil
			end
			if os.clock() - lastActivationAt.current > 0.12 then
				activate()
			end
		end,
	} else {}
	return {
		active = active,
		engaged = engaged,
		hovered = hovered,
		offsetY = offsetY,
		hoverAmount = hoverAmount,
		pressAmount = pressAmount,
		impact = impact,
		shimmer = shimmer,
		focusRing = focusRing,
		surfaceSize = surfaceSize,
		touchScale = touchScale,
		tilt = tilt,
		events = events,
		assistActivate = function()
			if os.clock() - lastActivationAt.current > 0.12 then activate() end
		end,
	}
end
local function ButtonShimmer(_param)
	local hoverAmount = _param.hoverAmount
	local shimmer = _param.shimmer
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 2
	end
	local radius = _param.radius
	if radius == nil then
		radius = Layout.buttonRadius
	end
	local idle = _param.idle
	if idle == nil then
		idle = false
	end
	local _binding = useMotionSettings()
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = hoverAmount:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.38 * shimmerScale
		end),
		BorderSizePixel = 0,
		Visible = hoverAmount:map(function(amount)
			return shimmerScale > 0.02 and amount > 0.02
		end),
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white),
		Rotation = 16,
		Transparency = SHIMMER_GLINT,
		Offset = shimmer:map(function(phase)
			return Vector2.new(phase * 2.1 - 1.05, 0)
		end),
	}))
end
local nextAssistId = 0
function Button(_param)
	local text = _param.text
	local onClick = _param.onClick
	local size = _param.size
	if size == nil then
		size = UDim2.fromOffset(160, TapTarget)
	end
	local position = _param.position
	local color = _param.color
	local textColor = _param.textColor
	if color == nil then
		-- Uncolored actions were filling with cream, which reads as a white slab.
		color = Palette.panelSoft
		if textColor == nil then
			textColor = Palette.cream
		end
	end
	local icon = _param.icon
	local disabled = _param.disabled
	if disabled == nil then
		disabled = false
	end
	local loading = _param.loading
	if loading == nil then
		loading = false
	end
	local shakeToken = _param.shakeToken
	if shakeToken == nil then
		shakeToken = 0
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 5
	end
	local outline = _param.outline
	if outline == nil then
		outline = false
	end
	local highlight = _param.highlight
	if highlight == nil then
		highlight = false
	end
	local hug = _param.hug
	if hug == nil then
		hug = false
	end
	local selectable = _param.selectable
	local sound = _param.sound
	if sound == nil then
		sound = "auto"
	end
	local children = _param.children
	local resolvedSound = if sound == "auto" then buttonAudioCue(if type(text) == "string" then text else "", icon) else sound
	local effectivelyDisabled = disabled or loading
	local motion = _param.motion
	if motion == nil then
		motion = {
			text = if type(text) == "string" then text else "",
			icon = icon,
			size = size,
		}
	end
	local _binding = useButtonChrome(onClick, reducedMotion, effectivelyDisabled, resolvedSound, true, highlight, motion)
	local active = _binding.active
	local engaged = _binding.engaged
	local hovered = _binding.hovered
	local offsetY = _binding.offsetY
	local hoverAmount = _binding.hoverAmount
	local impact = _binding.impact
	local shimmer = _binding.shimmer
	local focusRing = _binding.focusRing
	local touchScale = _binding.touchScale
	local tilt = _binding.tilt
	local events = _binding.events
	local spinnerTurn = useRotation(loading, 260)
	local labelHiddenByLoading = useFlipperSpring(if loading then 1 else 0, reducedMotion, 520, 40)
	-- Error shake: bump `shakeToken` from the caller's failure handler to jitter the button
	-- horizontally and flash it red, so a rejected action reacts at the point of the tap
	-- instead of only surfacing in a toast elsewhere on screen.
	local shake = useFlash(shakeToken, reducedMotion, 0.42)
	React.useEffect(function()
		if shakeToken > 0 and not reducedMotion then
			Audio:play("noticeError")
		end
	end, { reducedMotion, shakeToken })
	local shakeOffsetX = shake:map(function(amount)
		return math.round(math.sin(amount * math.pi * 4.5) * amount * 7)
	end)
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local presence = useExitPresence()
	local arrival = useEntrance(reducedMotion or effectsPaused)
	local visualPosition = React.joinBindings({ arrival, shakeOffsetX }):map(function(values)
		return UDim2.new(0.5, math.round(values[2]), 0.5, math.round((1 - math.clamp(values[1], 0, 1)) * 8))
	end)
	local _condition = selectable
	if _condition == nil then
		_condition = not disabled
	end
	local canSelect = _condition
	-- "You should tap this" idle breathing glow for claim/collect-style highlight buttons —
	-- only while the action is actually available, gated on ambient FX like other decorative motion.
	local breatheWanted = highlight and active
	local breatheStroke = useGlowStroke(breatheWanted, reducedMotion or effectsPaused, 0.32, 0.22, 0.46, 1.15)
	local buttonRef = React.useRef()
	local assistId = React.useRef(nil)
	if assistId.current == nil then
		nextAssistId += 1
		assistId.current = "Button-" .. tostring(nextAssistId)
	end
	local assistAction = React.useRef(nil)
	assistAction.current = _binding.assistActivate
	React.useEffect(function()
		local button = buttonRef.current
		if button == nil then
			return nil
		end
		button.SelectionImageObject = nil
	end, {})
	React.useEffect(function()
		local button = buttonRef.current
		if button == nil or effectivelyDisabled then return nil end
		local id = assistId.current
		TouchGestureService.RegisterTouchTarget(id, button, function()
			local action = assistAction.current
			if action then action() end
		end, zIndex, 12)
		return function() TouchGestureService.UnregisterTouchTarget(id) end
	end, { effectivelyDisabled, zIndex })
	local baseFill = if effectivelyDisabled then Palette.panelSoft elseif outline then Palette.panel else color
	-- Affordability/cooldown gating flips `disabled` a lot; cross-fade the fill and label
	-- colors across that flip instead of snapping, so it reads as a state change rather than a glitch.
	-- Loading uses the same cross-fade so a pending request dims the button exactly like disabled does.
	local disabledAmount = useFlipperSpring(if effectivelyDisabled then 1 else 0, reducedMotion or effectsPaused, 520, 40)
	local enabledFill = hoverAmount:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		if outline then
			return Palette.panel:Lerp(Palette.panelSoft, t * 0.55)
		end
		return color:Lerp(lighten(color, 0.08), t)
	end)
	local fill = React.joinBindings({
		enabled = enabledFill,
		disabled = disabledAmount,
	}):map(function(_param_1)
		local enabled = _param_1.enabled
		local amount = _param_1.disabled
		return enabled:Lerp(Palette.panelSoft, math.clamp(amount, 0, 1))
	end)
	local preferredLabelColor = if outline then (if textColor ~= nil and textColor ~= Palette.ink then textColor elseif contrastOn(color) == Palette.ink then color else Palette.cream) else (textColor or contrastOn(baseFill))
	local enabledLabelColor = ensureContrast(baseFill, preferredLabelColor, 4.5)
	local disabledLabelColor = ensureContrast(Palette.panelSoft, Palette.muted, 3.25)
	local labelColor = disabledAmount:map(function(amount)
		return enabledLabelColor:Lerp(disabledLabelColor, math.clamp(amount, 0, 1))
	end)
	local iconOnly = text == "" and icon ~= nil
	local hasIcon = icon ~= nil
	local compactRipple = iconOnly or (size.X.Scale == 0 and size.X.Offset > 0 and size.X.Offset <= 56) or (size.Y.Scale == 0 and size.Y.Offset > 0 and size.Y.Offset <= 40)
	local surfaceFade = presence:map(function(shown)
		return math.clamp(1 - shown, 0, 1)
	end)
	local labelFade = React.joinBindings({ presence }):map(function(values)
		return math.clamp(1 - values[1], 0, 1)
	end)
	local iconAccent = React.joinBindings({
		label = labelColor,
		disabled = disabledAmount,
	}):map(function(_param_1)
		local label = _param_1.label
		local amount = _param_1.disabled
		return label:Lerp(Palette.lineSoft, math.clamp(amount, 0, 1))
	end)
	local resolvedSize = size
	if hug and size.X.Scale == 0 and type(text) == "string" and not iconOnly then
		local needed = buttonContentWidth(text, hasIcon)
		resolvedSize = UDim2.new(0, math.max(size.X.Offset, needed), size.Y.Scale, size.Y.Offset)
	end
	return React.createElement("frame", {
		Size = resolvedSize,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		ref = buttonRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = canSelect,
		SelectionOrder = zIndex,
		ZIndex = zIndex + 1,
		Event = events,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = visualPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = tilt,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uiscale", {
		Scale = touchScale,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = offsetY:map(function(amount)
			return UDim2.new(0, 0, 0, 5 - math.round(amount))
		end),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = if effectivelyDisabled then 0.84 else Chrome.buttonShadow,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = offsetY:map(function(amount)
			return UDim2.new(0, 0, 0, math.round(amount))
		end),
		BackgroundColor3 = fill,
		BackgroundTransparency = surfaceFade,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), not outline and not effectivelyDisabled and React.createElement("uigradient", {
		Color = surfaceGradient(baseFill, 0.95),
		Rotation = 90,
	}), not outline and not effectivelyDisabled and React.createElement("frame", {
		Size = UDim2.new(1, -12, 0, 1),
		Position = UDim2.fromOffset(6, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = zIndex + 2,
	}), not compactRipple and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = React.joinBindings({ hoverAmount, impact }):map(function(values)
			return math.clamp(1 - values[1] * 0.05 - values[2] * 0.06, 0.82, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex + 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	})), active and React.createElement(ButtonShimmer, {
		hoverAmount = hoverAmount,
		shimmer = shimmer,
		idle = highlight,
		zIndex = zIndex + 2,
	}), active and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = impact:map(function(amount)
			return math.clamp(1 - amount * 0.48, 0.52, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex + 4,
		Visible = impact:map(function(amount)
			return amount > 0.05
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.coral,
		BackgroundTransparency = shake:map(function(amount)
			return math.clamp(1 - amount * 0.6, 0.4, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex + 4,
		Visible = shake:map(function(amount)
			return amount > 0.02
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	})), children, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 3,
		Visible = labelHiddenByLoading:map(function(amount)
			return amount < 0.98
		end),
	}, iconOnly and icon ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zIndex + 3,
	}, React.createElement(Icon, {
		kind = icon,
		color = labelColor,
		accent = iconAccent,
		size = 24,
		spin = hovered and active,
		hoverAmount = hoverAmount,
		reducedMotion = reducedMotion,
	})), not iconOnly and hasIcon and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 3,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Icon, {
		kind = icon,
		color = labelColor,
		accent = iconAccent,
		size = 20,
		spin = hovered and active,
		hoverAmount = hoverAmount,
		reducedMotion = reducedMotion,
	})), React.createElement("textlabel", {
		ref = pinButtonLabel,
		Size = UDim2.new(1, -38, 1, 0),
		Position = UDim2.fromOffset(32, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = labelColor,
		TextTransparency = React.joinBindings({ labelFade, labelHiddenByLoading }):map(function(values)
			return math.clamp(values[1] + values[2], 0, 1)
		end),
		TextSize = BUTTON_LABEL_SIZE,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})), not iconOnly and not hasIcon and React.createElement("textlabel", {
		ref = pinButtonLabel,
		Size = UDim2.new(1, -14, 1, 0),
		Position = UDim2.fromOffset(7, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = labelColor,
		TextTransparency = React.joinBindings({ labelFade, labelHiddenByLoading }):map(function(values)
			return math.clamp(values[1] + values[2], 0, 1)
		end),
		TextSize = BUTTON_LABEL_SIZE,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = zIndex + 3,
	})), loading and React.createElement("frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = spinnerTurn,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 3,
		Visible = labelHiddenByLoading:map(function(amount)
			return amount > 0.02
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = enabledLabelColor,
		Thickness = 2.2,
		Transparency = labelHiddenByLoading:map(function(amount)
			return 1 - amount
		end),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(enabledLabelColor),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	}))), (outline or highlight) and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = offsetY:map(function(amount)
			return UDim2.new(0, 0, 0, math.round(amount))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement(Stroke, {
		color = color,
		thickness = 1,
		transparency = if outline then 0.14 elseif highlight and active then breatheStroke else 1,
	})), highlight and active and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = offsetY:map(function(amount)
			return UDim2.new(0, 0, 0, math.round(amount))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 4,
		Visible = breatheWanted,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement(Stroke, {
		color = lighten(color, 0.3),
		thickness = 2,
		transparency = breatheStroke:map(function(amount)
			return math.clamp(0.55 + amount * 0.9, 0.55, 1)
		end),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = offsetY:map(function(amount)
			return UDim2.new(0, 0, 0, math.round(amount))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 5,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement(Stroke, {
		color = Palette.cream,
		thickness = 4,
		transparency = focusRing:map(function(amount)
			return 1 - amount * 0.98
		end),
	})))))
end
local METER_EMPTY_EPS = 1e-4
local function meterFill(progress, target, complete)
	if complete == nil then
		complete = false
	end
	if complete then
		return 1
	end
	local _target = target
	local _condition = type(_target) == "number"
	if _condition then
		_condition = target == target and target > 0
	end
	local goal = if _condition then target else 1
	local _progress = progress
	local _condition_1 = type(_progress) == "number"
	if _condition_1 then
		_condition_1 = progress == progress
	end
	local current = if _condition_1 then progress else 0
	if current <= 0 then
		return 0
	end
	if current >= goal then
		return 1
	end
	return math.clamp(current / goal, 0, 1)
end
local function Meter(_param)
	local value = _param.value
	local color = _param.color
	if color == nil then
		color = Palette.cyan
	end
	local position = _param.position
	local size = _param.size
	if size == nil then
		size = UDim2.new(1, 0, 0, 8)
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local shimmer = _param.shimmer
	if shimmer == nil then
		shimmer = false
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local _binding = useMotionSettings()
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	local lowMotion = reducedMotion or effectsPaused
	local literal = if type(value) == "number" then (if value == value then math.clamp(value, 0, 1) else 0) else nil
	local empty = literal ~= nil and literal <= METER_EMPTY_EPS
	local snap = literal ~= nil and (empty or literal >= 0.999)
	local animateLiteral = literal ~= nil and not empty
	local _condition = literal
	if _condition == nil then
		_condition = 0
	end
	local eased = useOptionalFlipperSpring(_condition, animateLiteral, lowMotion, 420, 38)
	local fill = if empty then UDim2.new(0, 0, 1, 0) elseif literal ~= nil and not animateLiteral then UDim2.new(literal, 0, 1, 0) else (if literal ~= nil then eased else value):map(function(amount)
		local _amount = amount
		local _condition_1 = type(_amount) == "number"
		if _condition_1 then
			_condition_1 = amount == amount
		end
		local t = if _condition_1 then math.clamp(amount, 0, 1) else 0
		if t <= METER_EMPTY_EPS then
			return UDim2.new(0, 0, 1, 0)
		end
		return UDim2.new(t, 0, 1, 0)
	end)
	local wantShimmer = shimmer and shimmerScale > 0.02 and not empty and not lowMotion
	local shimmerBlend = useOptionalFlipperSpring(if wantShimmer then 1 else 0, true, lowMotion, 400, 34)
	local readyPulse = usePulse(wantShimmer, 2)
	local shimmerPhase = useClock(wantShimmer, 0.72, 1, true)
	local _exp = React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(48, 3),
	})
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_2 = React.createElement("frame", {
		Size = fill,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = not empty,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(color, 0.32), color),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(3, 3),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = React.joinBindings({ readyPulse, shimmerBlend }):map(function(values)
			return math.clamp(1 - values[2] * (0.2 + values[1] * 0.12), 0, 1)
		end),
		BorderSizePixel = 0,
		Visible = shimmerBlend:map(function(amount)
			return amount > 0.02
		end),
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white),
		Transparency = SHIMMER_GLINT,
		Rotation = 22,
		Offset = shimmerPhase:map(function(phase)
			return Vector2.new(phase * 2.6 - 1.3, 0)
		end),
	})))
	return React.createElement("frame", {
		Size = size,
		Position = position,
		LayoutOrder = layoutOrder,
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = Chrome.meterTrack,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2)
end
local function Slider(_param)
	local value = _param.value
	local onChange = _param.onChange
	local onCommit = _param.onCommit
	local accent = _param.accent
	if accent == nil then
		accent = Palette.cyan
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local size = _param.size
	if size == nil then
		size = UDim2.fromOffset(188, 28)
	end
	local position = _param.position
	local focused, setFocused = React.useState(false)
	local hovered, setHovered = React.useState(false)
	local dragging, setDragging = React.useState(false)
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local engaged = focused or hovered or dragging
	local engagement = useFlipperSpring(if engaged then 1 else 0, reducedMotion or effectsPaused, 460, 38)
	local amount = math.clamp(value, 0, 1)
	local thumb = useSpring(amount, reducedMotion or effectsPaused, 470, 44)
	local sliderViewport = useViewport()
	local trackInset = if (not sliderViewport.desktop and UserInputService.TouchEnabled) then 12 else 10
	local buttonRef = React.useRef()
	local activeDrag = React.useRef()
	local dragChange = React.useRef()
	local dragEnd = React.useRef()
	local dragOrigin = React.useRef()
	local touchAdjusting = React.useRef(false)
	local lastValue = React.useRef(amount)
	React.useEffect(function()
		if activeDrag.current == nil then
			lastValue.current = amount
		end
	end, { amount })
	local updateFromX = React.useCallback(function(x)
		local button = buttonRef.current
		if not button then
			return nil
		end
		local width = math.max(1, button.AbsoluteSize.X - trackInset * 2)
		local targetValue = math.clamp((x - button.AbsolutePosition.X - trackInset) / width, 0, 1)
		local snapped = math.clamp(math.round(targetValue * 20) / 20, 0, 1)
		if snapped ~= lastValue.current then
			Audio:play("sliderStep")
			InteractionFeedback.tick()
		end
		lastValue.current = snapped
		onChange(snapped)
	end, { onChange, trackInset })
	React.useEffect(function()
		local button = buttonRef.current
		if not button then
			return nil
		end
		local clearDragConnections = function()
			local _result = dragChange.current
			if _result ~= nil then
				_result:Disconnect()
			end
			local _result_1 = dragEnd.current
			if _result_1 ~= nil then
				_result_1:Disconnect()
			end
			dragChange.current = nil
			dragEnd.current = nil
		end
		local cancelDrag = function()
			setDragging(false)
			activeDrag.current = nil
			dragOrigin.current = nil
			touchAdjusting.current = false
			clearDragConnections()
		end
		local begin = button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			if activeDrag.current ~= nil then
				return nil
			end
			setDragging(true)
			activeDrag.current = input
			dragOrigin.current = Vector2.new(input.Position.X, input.Position.Y)
			touchAdjusting.current = input.UserInputType ~= Enum.UserInputType.Touch
			if input.UserInputType ~= Enum.UserInputType.Touch then
				updateFromX(input.Position.X)
			end
			clearDragConnections()
			dragChange.current = UserInputService.InputChanged:Connect(function(changedInput)
				local drag = activeDrag.current
				if drag == nil then
					return nil
				end
				if drag.UserInputType == Enum.UserInputType.Touch then
					if changedInput ~= drag then
						return nil
					end
					local origin = dragOrigin.current
					if origin == nil then
						return nil
					end
					local delta = Vector2.new(changedInput.Position.X, changedInput.Position.Y) - origin
					if not touchAdjusting.current then
						if math.abs(delta.Y) >= 8 and math.abs(delta.Y) > math.abs(delta.X) * 1.15 then
							cancelDrag()
							return nil
						end
						if math.abs(delta.X) < 8 or math.abs(delta.X) <= math.abs(delta.Y) then
							return nil
						end
						touchAdjusting.current = true
					end
					updateFromX(changedInput.Position.X)
					return nil
				end
				if drag.UserInputType == Enum.UserInputType.MouseButton1 and changedInput.UserInputType == Enum.UserInputType.MouseMovement then
					updateFromX(changedInput.Position.X)
				end
			end)
			dragEnd.current = UserInputService.InputEnded:Connect(function(endedInput)
				local drag = activeDrag.current
				if drag == nil then
					return nil
				end
				local exactTouch = drag.UserInputType == Enum.UserInputType.Touch and endedInput == drag
				local mouseRelease = drag.UserInputType == Enum.UserInputType.MouseButton1 and endedInput.UserInputType == Enum.UserInputType.MouseButton1
				if not exactTouch and not mouseRelease then
					return nil
				end
				if exactTouch and not touchAdjusting.current then
					updateFromX(endedInput.Position.X)
				end
				setDragging(false)
				activeDrag.current = nil
				dragOrigin.current = nil
				touchAdjusting.current = false
				clearDragConnections()
				local _result = onCommit
				if _result ~= nil then
					_result(lastValue.current)
				end
				Audio:play("sliderCommit")
				InteractionFeedback.tick()
			end)
		end)
		local unsubscribeCancel = subscribeInputCancellation(cancelDrag)
		return function()
			begin:Disconnect()
			unsubscribeCancel()
			cancelDrag()
		end
	end, { onCommit, updateFromX })
	local adjust = React.useCallback(function(delta)
		local adjusted = math.clamp(math.round((lastValue.current + delta) * 20) / 20, 0, 1)
		lastValue.current = adjusted
		onChange(adjusted)
		local _result = onCommit
		if _result ~= nil then
			_result(adjusted)
		end
		Audio:play("sliderStep")
		InteractionFeedback.tick()
	end, { onChange, onCommit })
	local thumbDiameter = if (not sliderViewport.desktop and UserInputService.TouchEnabled) then 20 else 18
	local thumbCenter = thumb:map(function(current)
		return UDim2.new(current, trackInset - current * trackInset * 2, 0.5, 0)
	end)
	return React.createElement("imagebutton", {
		ref = buttonRef,
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			MouseEnter = function()
				setHovered(true)
				Audio:play("hover")
			end,
			MouseLeave = function()
				return setHovered(false)
			end,
			SelectionGained = function()
				setFocused(true)
				Audio:play("hover")
			end,
			SelectionLost = function()
				return setFocused(false)
			end,
			InputBegan = function(_button, input)
				if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.Left then
					adjust(-0.05)
				elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.Right then
					adjust(0.05)
				end
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, 28),
		Position = UDim2.new(0, 2, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1.5,
		Transparency = engagement:map(function(active)
			return 1 - math.clamp(active, 0, 1) * 0.72
		end),
	})), React.createElement("frame", {
		Size = UDim2.new(1, -trackInset * 2, 0, 7),
		Position = UDim2.new(0, trackInset, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = engagement:map(function(active)
			return 0.2 - math.clamp(active, 0, 1) * 0.08
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = thumb:map(function(current)
			return UDim2.new(current, 0, 1, 0)
		end),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.28), accent),
	}))), React.createElement("frame", {
		Size = UDim2.fromOffset(30, 30),
		Position = thumbCenter,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = engagement:map(function(active)
			return 1 - math.clamp(active, 0, 1) * 0.14
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = engagement:map(function(active)
			return 1 - math.clamp(active, 0, 1) * 0.5
		end),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(thumbDiameter, thumbDiameter),
		Position = thumbCenter,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = engagement:map(function(active)
			return 1 + math.clamp(active, 0, 1) * 0.07
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, lighten(accent, 0.42)),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = engagement:map(function(active)
			return 2 + math.clamp(active, 0, 1) * 0.5
		end),
		Transparency = 0.06,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(5, 5),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))
end
local AMOUNT_OPTIONS = { 1, 5, 10, 25, 0 }
local function AmountToggle(_param)
	local value = _param.value
	local onChange = _param.onChange
	local accent = _param.accent
	if accent == nil then
		accent = Palette.cream
	end
	local position = _param.position
	local size = _param.size
	if size == nil then
		size = UDim2.fromOffset(240, TapTarget)
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local focusedIndex, setFocusedIndex = React.useState(-1)
	local hoveredIndex, setHoveredIndex = React.useState(-1)
	local activeIndex = 0
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(amount, index)
		if amount == value then
			activeIndex = index
		end
	end
	for _k, _v in AMOUNT_OPTIONS do
		_callback(_v, _k - 1, AMOUNT_OPTIONS)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local slide = useSpring(activeIndex, reducedMotion, 620, 34)
	local selectionFlash = useFlash(activeIndex + 1, reducedMotion, 0.34)
	local hoverSlide = useSpring(math.max(hoveredIndex, 0), reducedMotion, 700, 42)
	local slotScale = 1 / #AMOUNT_OPTIONS
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if focusedIndex >= 0 then accent else Palette.lineSoft,
		Thickness = if focusedIndex >= 0 then 2 else 1,
		Transparency = if focusedIndex >= 0 then 0.18 else 0.7,
	})
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(slotScale, -4, 1, -6),
		Position = hoverSlide:map(function(index)
			return UDim2.new(math.clamp(index, 0, #AMOUNT_OPTIONS - 1) * slotScale, 3, 0, 3)
		end),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Visible = hoveredIndex >= 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}))
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(slotScale, -4, 1, -6),
		Position = slide:map(function(index)
			return UDim2.new(math.clamp(index, 0, #AMOUNT_OPTIONS - 1) * slotScale, 3, 0, 3)
		end),
		BackgroundColor3 = selectionFlash:map(function(amount)
			return lighten(accent, amount * 0.18)
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.24), accent),
		Rotation = 90,
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#AMOUNT_OPTIONS)
	local _callback_1 = function(amount, index)
		return React.createElement("imagebutton", {
			key = tostring(amount),
			Size = UDim2.new(slotScale, -4, 1, 0),
			Position = UDim2.new(index * slotScale, 3, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = true,
			Selectable = true,
			ZIndex = 3,
			Event = {
				Activated = function()
					if amount ~= value then
						onChange(amount)
					end
					Audio:play("amountChange", 0.96 + index * 0.04)
					InteractionFeedback.tick()
				end,
				MouseEnter = function()
					setHoveredIndex(index)
					Audio:play("hover")
				end,
				MouseLeave = function()
					return setHoveredIndex(function(current)
						return if current == index then -1 else current
					end)
				end,
				SelectionGained = function()
					setFocusedIndex(index)
					setHoveredIndex(index)
					Audio:play("hover")
				end,
				SelectionLost = function()
					setFocusedIndex(function(current)
						return if current == index then -1 else current
					end)
					setHoveredIndex(function(current)
						return if current == index then -1 else current
					end)
				end,
			},
		}, focusedIndex == index and React.createElement("frame", {
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.fromOffset(2, 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 6),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.cream,
			Thickness = 1,
			Transparency = 0.2,
		})), React.createElement(Text, {
			value = if amount == 0 then "MAX" else `x{amount}`,
			size = 12,
			color = if value == amount then contrastOn(accent) else Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = false,
			sizeConstraint = UDim2.new(1, -2, 1, 0),
			position = UDim2.fromOffset(1, 0),
			zIndex = 4,
		}))
	end
	for _k, _v in AMOUNT_OPTIONS do
		_newValue[_k] = _callback_1(_v, _k - 1, AMOUNT_OPTIONS)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _newValue)
end
local function SegmentedTabHit(_param)
	local option = _param.option
	local selected = _param.selected
	local position = _param.position
	local size = _param.size
	local onSelect = _param.onSelect
	local accent = _param.accent
	local sound = _param.sound
	local reducedMotion = _param.reducedMotion
	local zIndex = _param.zIndex
	local chrome = useButtonChrome(function()
		if not selected then
			onSelect(option.id)
		end
	end, reducedMotion, false, sound, true, selected, {
		text = option.label,
		size = size,
	})
	local selectedInk = contrastOn(accent)
	local textColor = chrome.hoverAmount:map(function(amount)
		return if selected then selectedInk else Palette.creamSoft:Lerp(Palette.cream, math.clamp(amount, 0, 1) * 0.72)
	end)
	local hoverAlpha = chrome.hoverAmount:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.08
	end)
	return React.createElement("imagebutton", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ZIndex = zIndex,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = chrome.offsetY:map(function(y)
			return UDim2.new(0.5, 0, 0.5, math.round(y))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = hoverAlpha,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex,
	}, React.createElement("uiscale", {
		Scale = chrome.touchScale,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		idle = selected,
		zIndex = zIndex + 1,
		radius = 8,
	}), option.icon ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zIndex + 2,
	}, React.createElement(Icon, {
		kind = option.icon,
		color = textColor,
		accent = accent,
		size = 18,
		spin = chrome.hovered,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = option.label,
		size = 13,
		color = textColor,
		weight = if selected then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
		align = if option.icon ~= nil then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = false,
		position = if option.icon ~= nil then UDim2.fromOffset(38, 0) else UDim2.fromOffset(8, 0),
		sizeConstraint = UDim2.new(1, if option.icon ~= nil then -46 else -16, 1, 0),
		zIndex = zIndex + 2,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.cream,
		Thickness = 3,
		Transparency = chrome.focusRing:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.95
		end),
	})))
end
local function SegmentedTabs(_param)
	local options = _param.options
	local value = _param.value
	local onChange = _param.onChange
	local accent = _param.accent
	if accent == nil then
		accent = Palette.cyan
	end
	local sound = _param.sound
	if sound == nil then
		sound = "tabSwitch"
	end
	local columns = _param.columns
	local gap = _param.gap
	if gap == nil then
		gap = 6
	end
	local size = _param.size
	if size == nil then
		size = UDim2.new(1, 0, 0, TapTarget)
	end
	local position = _param.position
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 5
	end
	local count = math.max(1, #options)
	local _condition = columns
	if _condition == nil then
		_condition = count
	end
	local columnCount = math.max(1, math.min(_condition, count))
	local rowCount = math.max(1, math.ceil(count / columnCount))
	local activeIndex = 0
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(option, index)
		if option.id == value then
			activeIndex = index
		end
	end
	for _k, _v in options do
		_callback(_v, _k - 1, options)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local activeColumn = activeIndex % columnCount
	local activeRow = math.floor(activeIndex / columnCount)
	local columnSlide = useFlipperSpring(activeColumn, reducedMotion, 880, 34)
	local rowSlide = useFlipperSpring(activeRow, reducedMotion, 880, 34)
	local selectionFlash = useFlash(activeIndex + 1, reducedMotion, 0.22)
	local tabSweep = useClock(reducedMotion ~= true, SHIMMER_SWEEP_SPEED, 1, true)
	local _result = options[activeIndex + 1]
	if _result ~= nil then
		_result = _result.accent
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = accent
	end
	local selectedAccent = _condition_1
	local cellSize = UDim2.new(1 / columnCount, -gap * (columnCount - 1) / columnCount, 1 / rowCount, -gap * (rowCount - 1) / rowCount)
	local slotPosition = function(index)
		local column = index % columnCount
		local row = math.floor(index / columnCount)
		return UDim2.new(column / columnCount, gap * column / columnCount, row / rowCount, gap * row / rowCount)
	end
	local carrierPosition = React.joinBindings({ columnSlide, rowSlide }):map(function(values)
		return UDim2.new(math.clamp(values[1], 0, columnCount - 1) / columnCount, gap * math.clamp(values[1], 0, columnCount - 1) / columnCount, math.clamp(values[2], 0, rowCount - 1) / rowCount, gap * math.clamp(values[2], 0, rowCount - 1) / rowCount)
	end)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.62,
	})
	local _exp_3 = React.createElement("frame", {
		Size = cellSize,
		Position = carrierPosition,
		BackgroundColor3 = selectionFlash:map(function(amount)
			return lighten(selectedAccent, amount * 0.14)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(selectedAccent, 0.14), darken(selectedAccent, 0.06)),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = lighten(selectedAccent, 0.24),
		Thickness = 1,
		Transparency = 0.28,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white),
		Transparency = SHIMMER_GLINT,
		Offset = tabSweep:map(function(phase)
			return Vector2.new(phase * 2.2 - 1.1, 0)
		end),
	})), React.createElement("frame", {
		Size = UDim2.new(0.52, 0, 0, 2),
		Position = UDim2.new(0.5, 0, 1, -3),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#options)
	local _callback_1 = function(option, index)
		return React.createElement(SegmentedTabHit, {
			key = option.id,
			option = option,
			selected = option.id == value,
			position = slotPosition(index),
			size = cellSize,
			onSelect = onChange,
			accent = option.accent or accent,
			sound = sound,
			reducedMotion = reducedMotion,
			zIndex = zIndex + 2,
		})
	end
	for _k, _v in options do
		_newValue[_k] = _callback_1(_v, _k - 1, options)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, _exp_3, _newValue))
end
local function EmptyState(_param)
	local icon = _param.icon
	local title = _param.title
	local body = _param.body
	local accent = _param.accent
	if accent == nil then
		accent = Palette.steel
	end
	local size = _param.size
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local titleSize = _param.titleSize
	local bodySize = _param.bodySize
	local iconSize = _param.iconSize
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local reveal = useEntrance(reducedMotion)
	local fade = reveal:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local resolvedIcon = if iconSize ~= nil then iconSize elseif compact then 22 else 28
	local resolvedTitle = if titleSize ~= nil then titleSize elseif compact then 14 else 16
	local resolvedBody = if bodySize ~= nil then bodySize elseif compact then 12 else 13
	local resolvedSize = size or (if compact then UDim2.new(1, 0, 0, 112) else UDim2.new(1, 0, 0, 150))
	local titleH = resolvedTitle + 4
	local bodyH = math.max(resolvedBody * 2 + 6, 28)
	-- Quiet copy on the page, same voice as Divider. A second Panel here read as a card inside a card.
	return React.createElement("frame", {
		Size = resolvedSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(resolvedIcon, resolvedIcon),
		LayoutOrder = 0,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Icon, {
		kind = icon,
		color = Palette.muted,
		accent = accent,
		size = resolvedIcon,
		spin = false,
		clipSafe = true,
	})), React.createElement(Text, {
		value = title,
		size = resolvedTitle,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = false,
		transparency = fade,
		layoutOrder = 1,
		sizeConstraint = UDim2.new(1, 0, 0, titleH),
	}), React.createElement(Text, {
		value = body,
		size = resolvedBody,
		color = Palette.muted,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		fit = false,
		transparency = fade,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, bodyH),
	}))
end
local function Dropdown(_param)
	local options = _param.options
	local value = _param.value
	local onChange = _param.onChange
	local accent = _param.accent
	if accent == nil then
		accent = Palette.steel
	end
	local label = _param.label
	local position = _param.position
	local size = _param.size
	if size == nil then
		size = UDim2.fromOffset(210, 48)
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 40
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local open, setOpen = React.useState(false)
	local openUp, setOpenUp = React.useState(false)
	local hovered, setHovered = React.useState(false)
	local focused, setFocused = React.useState(false)
	local pointer, setPointer = React.useState(-1)
	local rowCap, setRowCap = React.useState(6)
	local portalBounds, setPortalBounds = React.useState({
		x = 0,
		y = 0,
		width = math.max(1, size.X.Offset),
	})
	local portalLayer = React.useState(acquireDropdownPortal)
	local touchRows = chrome.stack or (not viewport.desktop and UserInputService.TouchEnabled)
	local rowHeight = if touchRows then TapTarget else 44
	local listPad = if touchRows then 4 else 2
	local listInset = if touchRows then 6 else 4
	local optionText = if touchRows then 16 else 16
	local visibleRows = math.min(#options, rowCap)
	local listHeight = visibleRows * rowHeight + math.max(0, visibleRows - 1) * listPad + listInset * 2
	local amount = useFlipperSpring(if open then 1 else 0, reducedMotion, 760, 40)
	local triggerAmount = useFlipperSpring(if open or hovered or focused then 1 else 0, reducedMotion, 680, 40)
	local corner = 12
	local selected = options[1]
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(option)
		if option.id == value then
			selected = option
		end
	end
	for _k, _v in options do
		_callback(_v, _k - 1, options)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local buttonRef = React.useRef()
	local listRef = React.useRef()
	local overControl = React.useRef(false)
	local overList = React.useRef(false)
	React.useEffect(function()
		return function()
			return releaseDropdownPortal()
		end
	end, {})
	React.useEffect(function()
		if not open then
			return nil
		end
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				setOpen(false)
				Audio:play("close")
				return nil
			end
			-- Real keyboard nav for an open list: Up/Down (or DPad) moves the pointer, Return/A
			-- commits it. This previously only worked by hovering with a mouse or tabbing focus
			-- with a controller (SelectionGained) -- a keyboard-only player had no way to move
			-- through the list at all once it was open.
			if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.DPadUp then
				setPointer(function(current)
					return if #options == 0 then -1 else (if current <= 0 then #options - 1 else current - 1)
				end)
				Audio:play("hover")
				return nil
			end
			if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.DPadDown then
				setPointer(function(current)
					return if #options == 0 then -1 else (current + 1) % #options
				end)
				Audio:play("hover")
				return nil
			end
			if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
				local chosen = options[pointer + 1]
				if chosen == nil then
					return nil
				end
				if chosen.id ~= value then
					onChange(chosen.id)
				end
				setOpen(false)
				setPointer(-1)
				Audio:play("filterPick", 0.96 + math.min(pointer, 5) * 0.025)
				InteractionFeedback.tap()
				return nil
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			if overControl.current or overList.current then
				return nil
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local inside = function(instance)
				if not instance then
					return false
				end
				local origin = instance.AbsolutePosition
				local extent = instance.AbsoluteSize
				return point.X >= origin.X and point.X <= origin.X + extent.X and point.Y >= origin.Y and point.Y <= origin.Y + extent.Y
			end
			if inside(buttonRef.current) or inside(listRef.current) then
				return nil
			end
			setOpen(false)
		end)
		return function()
			return connection:Disconnect()
		end
	end, { open, options, pointer, value, onChange })
	local chevronRotation = amount:map(function(progress)
		return 180 * math.clamp(progress, 0, 1)
	end)
	local listSize = amount:map(function(progress)
		return UDim2.fromOffset(portalBounds.width, math.floor(listHeight * math.clamp(progress, 0, 1)))
	end)
	local listTransparency = amount:map(function(progress)
		return 1 - math.clamp(progress * 1.6, 0, 1)
	end)
	local listPosition = amount:map(function(progress)
		local offset = math.round((1 - math.clamp(progress, 0, 1)) * 5) * (if openUp then -1 else 1)
		return UDim2.fromOffset(portalBounds.x, portalBounds.y + offset)
	end)
	-- Soft accent glow ring behind the trigger, matching the web dropdown's focus box-shadow --
	-- the height-driven list reveal below already covers the web version's scaleY entrance, since
	-- Roblox has no cheap non-distorting equivalent of a CSS transform squash on real text rows.
	local glowTransparency = triggerAmount:map(function(progress)
		return 1 - math.clamp(progress, 0, 1) * 0.85
	end)
	local needsScroll = #options > visibleRows
	local canvasHeight = #options * rowHeight + math.max(0, #options - 1) * listPad
	local scrollBarThickness = amount:map(function(progress)
		return if needsScroll and progress > 0.97 then 4 else 0
	end)
	local scrollBarAlpha = amount:map(function(progress)
		return if needsScroll and progress > 0.97 then 0 else 1
	end)
	local innerH = math.max(0, listHeight - listInset * 2)
	local chooseListDirection = function()
		local button = buttonRef.current
		if button == nil then
			return nil
		end
		local clipTop = math.max(0, viewport.topInset)
		local clipBottom = viewport.height - math.max(0, viewport.bottomInset)
		local above = button.AbsolutePosition.Y - clipTop
		local below = clipBottom - (button.AbsolutePosition.Y + button.AbsoluteSize.Y)
		local available = math.max(0, math.max(above, below) - 8)
		local fittingRows = math.clamp(math.floor((available - listInset * 2 + listPad) / (rowHeight + listPad)), 1, 6)
		local nextRows = math.min(#options, fittingRows)
		local nextHeight = nextRows * rowHeight + math.max(0, nextRows - 1) * listPad + listInset * 2
		local nextOpenUp = below < nextHeight + 8 and above > below
		local screenW = math.max(viewport.screenWidth, viewport.width)
		local screenH = math.max(viewport.screenHeight, viewport.height)
		local safeLeft = math.max(10, viewport.sideInset)
		local nextWidth = math.max(1, math.min(button.AbsoluteSize.X, screenW - safeLeft * 2))
		local nextX = math.clamp(button.AbsolutePosition.X, safeLeft, math.max(safeLeft, screenW - safeLeft - nextWidth))
		local triggerGap = 6
		local desiredY = if nextOpenUp then button.AbsolutePosition.Y - triggerGap else button.AbsolutePosition.Y + button.AbsoluteSize.Y + triggerGap
		local nextY = if nextOpenUp then math.clamp(desiredY, math.max(clipTop + nextHeight, 10), math.min(clipBottom, screenH - 10)) else math.clamp(desiredY, math.max(clipTop, 10), math.max(clipTop, math.min(clipBottom, screenH - 10) - nextHeight))
		setRowCap(fittingRows)
		setOpenUp(nextOpenUp)
		setPortalBounds({
			x = nextX,
			y = nextY,
			width = nextWidth,
		})
	end
	React.useEffect(function()
		if not open or buttonRef.current == nil then
			return nil
		end
		chooseListDirection()
		local position = buttonRef.current:GetPropertyChangedSignal("AbsolutePosition"):Connect(chooseListDirection)
		local dimensions = buttonRef.current:GetPropertyChangedSignal("AbsoluteSize"):Connect(chooseListDirection)
		return function()
			position:Disconnect()
			dimensions:Disconnect()
		end
	end, { open, viewport.width, viewport.height, viewport.topInset, viewport.bottomInset, viewport.sideInset })
	local chooseOption = function(option, index)
		if option.id ~= value then
			onChange(option.id)
		end
		setOpen(false)
		setPointer(-1)
		Audio:play("filterPick", 0.96 + math.min(index, 5) * 0.025)
		InteractionFeedback.tap()
	end
	local _exp = label ~= nil and React.createElement(Text, {
		value = label,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(2, -18),
		sizeConstraint = UDim2.new(1, -4, 0, 16),
		zIndex = zIndex,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.new(1, 6, 1, 6),
		Position = UDim2.fromOffset(-3, -3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex - 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, corner + 3),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 3,
		Transparency = glowTransparency,
	}))
	local _exp_2 = React.createElement("imagebutton", {
		ref = buttonRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = triggerAmount:map(function(progress)
			return Palette.panelRaised:Lerp(Palette.panelSoft, math.clamp(progress, 0, 1) * 0.72)
		end),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ZIndex = zIndex,
		Event = {
			Activated = function()
				local willOpen = not open
				if willOpen then
					chooseListDirection()
					-- ▼ ReadonlyArray.findIndex ▼
					local _callback_1 = function(option)
						return option.id == value
					end
					local _result = -1
					for _i, _v in options do
						if _callback_1(_v, _i - 1, options) == true then
							_result = _i - 1
							break
						end
					end
					-- ▲ ReadonlyArray.findIndex ▲
					setPointer(_result)
				end
				setOpen(willOpen)
				Audio:play(if willOpen then "filterOpen" else "close")
				InteractionFeedback.tick()
			end,
			MouseEnter = function()
				setHovered(true)
				overControl.current = true
				Audio:play("hover")
			end,
			MouseLeave = function()
				setHovered(false)
				overControl.current = false
			end,
			SelectionGained = function()
				setHovered(true)
				setFocused(true)
				Audio:play("hover")
			end,
			SelectionLost = function()
				setHovered(false)
				setFocused(false)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, corner),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if focused then accent else triggerAmount:map(function(progress)
			return Palette.lineSoft:Lerp(accent, math.clamp(progress, 0, 1))
		end),
		Thickness = if focused then 2 else 1,
		Transparency = if focused then 0.08 else triggerAmount:map(function(progress)
			return 0.58 - math.clamp(progress, 0, 1) * 0.38
		end),
	}), selected ~= nil and selected.icon ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zIndex + 1,
	}, React.createElement(Icon, {
		kind = selected.icon,
		color = Palette.creamSoft,
		accent = accent,
		size = 18,
		spin = false,
	})), React.createElement(Text, {
		value = if selected ~= nil then selected.label else "",
		size = optionText,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(if selected ~= nil and selected.icon ~= nil then 36 else 14, 0),
		sizeConstraint = UDim2.new(1, if selected ~= nil and selected.icon ~= nil then -78 else -52, 1, 0),
		zIndex = zIndex + 1,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = chevronRotation,
		BackgroundTransparency = 1,
		ZIndex = zIndex + 2,
	}, React.createElement("frame", {
		Size = UDim2.new(0, 9, 0, 2),
		Position = UDim2.new(0.5, -3, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.new(0, 9, 0, 2),
		Position = UDim2.new(0.5, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -45,
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, corner),
	})
	local _exp_4 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = listTransparency:map(function(current)
			return 0.35 + current * 0.65
		end),
	})
	local _result
	if needsScroll then
		local _exp_5 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, listPad),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#options)
		local _callback_1 = function(option, index)
			local active = option.id == value
			local lit = pointer == index
			local hasIcon = option.icon ~= nil
			local showDetail = not touchRows and option.detail ~= nil
			local left = if hasIcon then 38 else 14
			local right = if option.count ~= nil then 56 elseif active then 42 else 20
			return React.createElement("imagebutton", {
				key = option.id,
				Size = UDim2.new(1, -4, 0, rowHeight),
				LayoutOrder = index,
				BackgroundColor3 = if active then accent else Palette.panelSoft,
				BackgroundTransparency = if active then 0.55 elseif lit then 0.35 else 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ZIndex = zIndex + 7,
				Active = true,
				Selectable = true,
				Event = {
					Activated = function()
						return chooseOption(option, index)
					end,
					MouseEnter = function()
						setPointer(index)
						overList.current = true
						Audio:play("hover")
					end,
					MouseLeave = function()
						return setPointer(function(current)
							return if current == index then -1 else current
						end)
					end,
					SelectionGained = function()
						setPointer(index)
						Audio:play("hover")
					end,
					SelectionLost = function()
						return setPointer(function(current)
							return if current == index then -1 else current
						end)
					end,
				},
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 7),
			}), React.createElement("frame", {
				Size = if active then UDim2.new(0, 3, 1, -8) else UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(0, 4),
				BackgroundColor3 = accent,
				BackgroundTransparency = if active then 0 else 1,
				BorderSizePixel = 0,
				Visible = active,
				ZIndex = zIndex + 8,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 2),
			})), hasIcon and React.createElement("frame", {
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.new(0, 12, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ZIndex = zIndex + 8,
			}, React.createElement(Icon, {
				kind = option.icon,
				color = if active then Palette.cream else Palette.creamSoft,
				accent = accent,
				size = 18,
				spin = lit,
			})), React.createElement(Text, {
				value = option.label,
				size = optionText,
				color = if active then Palette.cream else Palette.creamSoft,
				weight = if active then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
				fit = false,
				position = UDim2.fromOffset(left, if showDetail then 2 else 0),
				sizeConstraint = UDim2.new(1, -(left + right), if showDetail then 0 else 1, if showDetail then 21 else 0),
				zIndex = zIndex + 8,
			}), showDetail and React.createElement(Text, {
				value = option.detail,
				size = 12,
				color = Palette.muted,
				weight = Enum.FontWeight.Medium,
				fit = false,
				position = UDim2.fromOffset(left, 20),
				sizeConstraint = UDim2.new(1, -(left + right), 0, 14),
				zIndex = zIndex + 8,
			}), option.count ~= nil and React.createElement(Text, {
				value = tostring(option.count),
				size = if chrome.stack then 13 else 11,
				color = if active then accent else Palette.muted,
				weight = Enum.FontWeight.Bold,
				fit = false,
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -40, 0, 0),
				sizeConstraint = UDim2.new(0, 32, 1, 0),
				zIndex = zIndex + 8,
			}), active and option.count == nil and React.createElement("frame", {
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ZIndex = zIndex + 8,
			}, React.createElement(Icon, {
				kind = "Check",
				color = Palette.cream,
				accent = accent,
				size = 16,
				spin = false,
			})))
		end
		for _k, _v in options do
			_newValue[_k] = _callback_1(_v, _k - 1, options)
		end
		-- ▲ ReadonlyArray.map ▲
		_result = (React.createElement("scrollingframe", {
			Size = UDim2.new(1, -listInset * 2, 0, innerH),
			Position = UDim2.fromOffset(listInset, listInset),
			CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = scrollBarThickness,
			ScrollBarImageColor3 = accent,
			ScrollBarImageTransparency = scrollBarAlpha,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			ScrollingEnabled = amount:map(function(progress)
				return progress > 0.97
			end),
			ClipsDescendants = true,
			Active = true,
			Selectable = false,
			ZIndex = zIndex + 7,
		}, _exp_5, _newValue))
	else
		local _exp_5 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, listPad),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#options)
		local _callback_1 = function(option, index)
			local active = option.id == value
			local lit = pointer == index
			local hasIcon = option.icon ~= nil
			local showDetail = not touchRows and option.detail ~= nil
			local left = if hasIcon then 38 else 14
			local right = if option.count ~= nil then 56 elseif active then 42 else 20
			return React.createElement("imagebutton", {
				key = option.id,
				Size = UDim2.new(1, 0, 0, rowHeight),
				LayoutOrder = index,
				BackgroundColor3 = if active then accent else Palette.panelSoft,
				BackgroundTransparency = if active then 0.55 elseif lit then 0.35 else 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ZIndex = zIndex + 7,
				Active = true,
				Selectable = true,
				Event = {
					Activated = function()
						return chooseOption(option, index)
					end,
					MouseEnter = function()
						setPointer(index)
						overList.current = true
						Audio:play("hover")
					end,
					MouseLeave = function()
						return setPointer(function(current)
							return if current == index then -1 else current
						end)
					end,
					SelectionGained = function()
						setPointer(index)
						Audio:play("hover")
					end,
					SelectionLost = function()
						return setPointer(function(current)
							return if current == index then -1 else current
						end)
					end,
				},
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 7),
			}), React.createElement("frame", {
				Size = if active then UDim2.new(0, 3, 1, -8) else UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(0, 4),
				BackgroundColor3 = accent,
				BackgroundTransparency = if active then 0 else 1,
				BorderSizePixel = 0,
				Visible = active,
				ZIndex = zIndex + 8,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 2),
			})), hasIcon and React.createElement("frame", {
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.new(0, 12, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ZIndex = zIndex + 8,
			}, React.createElement(Icon, {
				kind = option.icon,
				color = if active then Palette.cream else Palette.creamSoft,
				accent = accent,
				size = 18,
				spin = lit,
			})), React.createElement(Text, {
				value = option.label,
				size = optionText,
				color = if active then Palette.cream else Palette.creamSoft,
				weight = if active then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
				fit = false,
				position = UDim2.fromOffset(left, if showDetail then 2 else 0),
				sizeConstraint = UDim2.new(1, -(left + right), if showDetail then 0 else 1, if showDetail then 21 else 0),
				zIndex = zIndex + 8,
			}), showDetail and React.createElement(Text, {
				value = option.detail,
				size = 12,
				color = Palette.muted,
				weight = Enum.FontWeight.Medium,
				fit = false,
				position = UDim2.fromOffset(left, 20),
				sizeConstraint = UDim2.new(1, -(left + right), 0, 14),
				zIndex = zIndex + 8,
			}), option.count ~= nil and React.createElement(Text, {
				value = tostring(option.count),
				size = if chrome.stack then 13 else 11,
				color = if active then accent else Palette.muted,
				weight = Enum.FontWeight.Bold,
				fit = false,
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -40, 0, 0),
				sizeConstraint = UDim2.new(0, 32, 1, 0),
				zIndex = zIndex + 8,
			}), active and option.count == nil and React.createElement("frame", {
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ZIndex = zIndex + 8,
			}, React.createElement(Icon, {
				kind = "Check",
				color = Palette.cream,
				accent = accent,
				size = 16,
				spin = false,
			})))
		end
		for _k, _v in options do
			_newValue[_k] = _callback_1(_v, _k - 1, options)
		end
		-- ▲ ReadonlyArray.map ▲
		_result = (React.createElement("frame", {
			Size = UDim2.new(1, -listInset * 2, 0, innerH),
			Position = UDim2.fromOffset(listInset, listInset),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = zIndex + 7,
		}, _exp_5, _newValue))
	end
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, open and ReactRoblox.createPortal(React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 5,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = zIndex + 5,
		Event = {
			Activated = function()
				setOpen(false)
				Audio:play("close")
			end,
		},
	}), React.createElement("frame", {
		ref = listRef,
		Size = listSize,
		Position = listPosition,
		AnchorPoint = if openUp then Vector2.new(0, 1) else Vector2.zero,
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = listTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex + 6,
		ClipsDescendants = true,
		Visible = amount:map(function(progress)
			return progress > 0.01
		end),
		Event = {
			MouseEnter = function()
				overList.current = true
			end,
			MouseLeave = function()
				overList.current = false
			end,
		},
	}, _exp_3, _exp_4, _result)), portalLayer))
end
local function SearchField(_param)
	local value = _param.value
	local onChange = _param.onChange
	local accent = _param.accent
	if accent == nil then
		accent = Palette.steel
	end
	local placeholder = _param.placeholder
	if placeholder == nil then
		placeholder = "Search"
	end
	local position = _param.position
	local size = _param.size
	if size == nil then
		size = UDim2.fromOffset(220, TapTarget)
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 10
	end
	local searchViewport = useViewport()
	local chrome = chromeFor(searchViewport)
	local reactModules = require(script.Parent.reactModules)
	local draft, setDraft = React.useState(value)
	local boxRef = React.useRef(nil)
	local focused, setFocused = React.useState(false)
	local clearHovered, setClearHovered = React.useState(false)
	local debouncedChange = reactModules.useDebounceCallback(function(text)
		if onChange ~= nil then
			onChange(text)
		end
	end, {
		wait = 0.08,
	})
	reactModules.useUpdateEffect(function()
		if value == "" or not focused then
			setDraft(value)
		end
	end, { value, focused })
	reactModules.useUnmountEffect(function()
		debouncedChange.flush()
	end)
	reactModules.useEventListener(UserInputService.InputBegan, function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Escape then
			return nil
		end
		local box = boxRef.current
		if box ~= nil then
			box:ReleaseFocus()
		end
	end, {
		connected = focused,
	})
	local focus = useFlipperSpring(if focused then 1 else 0, reducedMotion, 720, 40)
	local clearHover = useFlipperSpring(if clearHovered then 1 else 0, reducedMotion, 680, 42)
	-- The clear button used to mount/unmount on `value !== ""` with no transition -- a hard pop
	-- in and out, and the textbox's width snapped to match in the same frame. Both now ride one
	-- spring keyed off that same boolean, so the button scales/fades in and the textbox's width
	-- eases over to make room for it (and back) instead of jumping.
	local hasQuery = draft ~= ""
	local clearReveal = useFlipperSpring(if hasQuery then 1 else 0, reducedMotion, 760, 40, if hasQuery then 1 else 0)
	local clearSize = if chrome.stack or (not searchViewport.desktop and UserInputService.TouchEnabled) then math.max(40, math.min(TapTarget, if size.Y.Offset > 0 then size.Y.Offset else TapTarget)) else 32
	local fieldText = if chrome.stack then 16 else 16
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = focus:map(function(amount)
			return Palette.lineSoft:Lerp(accent, amount)
		end),
		Thickness = focus:map(function(amount)
			return 1 + amount
		end),
		Transparency = focus:map(function(amount)
			return 0.45 - amount * 0.35
		end),
	}), React.createElement("frame", {
		Size = focus:map(function(amount)
			return UDim2.new(0, 3, 1, -16)
		end),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = focus:map(function(amount)
			return 0.85 - amount * 0.7
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zIndex + 1,
	}, React.createElement(Icon, {
		kind = "Search",
		color = focus:map(function(amount)
			return Palette.muted:Lerp(accent, amount)
		end),
		accent = accent,
		size = 20,
		spin = false,
	})), React.createElement("textbox", {
		ref = boxRef,
		Size = clearReveal:map(function(amount)
			return UDim2.new(1, -(52 + (clearSize + 6) * math.clamp(amount, 0, 1)), 1, -8)
		end),
		Position = UDim2.fromOffset(42, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = draft,
		PlaceholderText = placeholder,
		PlaceholderColor3 = Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = fieldText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		ZIndex = zIndex + 1,
		Change = {
			Text = function(instance)
				setDraft(instance.Text)
				return debouncedChange.run(instance.Text)
			end,
		},
		Event = {
			Focused = function()
				setFocused(true)
				Audio:play("inputFocus")
				InteractionFeedback.tick()
			end,
			FocusLost = function()
				setFocused(false)
				return debouncedChange.flush()
			end,
		},
	}), React.createElement("imagebutton", {
		Size = clearReveal:map(function(amount)
			return UDim2.fromOffset(clearSize * math.clamp(amount, 0, 1), clearSize * math.clamp(amount, 0, 1))
		end),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = clearHover:map(function(amount)
			return Palette.panelRaised:Lerp(Palette.panelSoft, math.clamp(amount, 0, 1))
		end),
		BackgroundTransparency = React.joinBindings({ clearHover, clearReveal }):map(function(values)
			return (0.18 - math.clamp(values[1], 0, 1) * 0.12) + (1 - math.clamp(values[2], 0, 1))
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = hasQuery,
		Selectable = hasQuery,
		Visible = clearReveal:map(function(amount)
			return amount > 0.02
		end),
		ZIndex = zIndex + 2,
		Event = {
			Activated = function()
				debouncedChange.cancel()
				setDraft("")
				if onChange ~= nil then
					onChange("")
				end
				Audio:play("inputClear")
				InteractionFeedback.tap()
			end,
			MouseEnter = function()
				setClearHovered(true)
				Audio:play("hover")
			end,
			MouseLeave = function()
				return setClearHovered(false)
			end,
			SelectionGained = function()
				setClearHovered(true)
				Audio:play("hover")
			end,
			SelectionLost = function()
				return setClearHovered(false)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.65,
	}), React.createElement(Icon, {
		kind = "Close",
		color = Palette.creamSoft,
		accent = Palette.muted,
		size = 14,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})))
end
local function LogoLockup(_param)
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local micro = _param.micro
	if micro == nil then
		micro = false
	end
	local accent = _param.accent
	if accent == nil then
		accent = Palette.cyan
	end
	local position = _param.position
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local mark = if micro then 40 else 48
	local textX = mark + 12
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(mark, mark),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(7, 17, 28),
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1.25,
		Transparency = 0.18,
	}), React.createElement("imagelabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(7, 17, 28),
		BorderSizePixel = 0,
		Image = GAME_ICON_ASSET,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), not micro and React.createElement(Text, {
		value = "ASTRAL",
		size = if compact then 18 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(textX, 0),
		sizeConstraint = UDim2.new(1, -textX, 1, 0),
	}))
end
return {
	acquireDropdownPortal = acquireDropdownPortal,
	releaseDropdownPortal = releaseDropdownPortal,
	Stroke = Stroke,
	subscribeInputCancellation = subscribeInputCancellation,
	useGamepadAutofocus = useGamepadAutofocus,
	Text = Text,
	measureWrappedTextHeight = measureWrappedTextHeight,
	AutoHeightText = AutoHeightText,
	OverlayPresence = OverlayPresence,
	ShimmerText = ShimmerText,
	SectionLabel = SectionLabel,
	QuantityStepper = QuantityStepper,
	ScrollEdgeFade = ScrollEdgeFade,
	SweptRing = SweptRing,
	OrbitDot = OrbitDot,
	ScrollPads = ScrollPads,
	IconTile = IconTile,
	Badge = Badge,
	CountBadge = CountBadge,
	Panel = Panel,
	Divider = Divider,
	useButtonChrome = useButtonChrome,
	resolvePressMotion = resolvePressMotion,
	ButtonShimmer = ButtonShimmer,
	Button = Button,
	meterFill = meterFill,
	Meter = Meter,
	Slider = Slider,
	AmountToggle = AmountToggle,
	SegmentedTabs = SegmentedTabs,
	EmptyState = EmptyState,
	Dropdown = Dropdown,
	SearchField = SearchField,
	LogoLockup = LogoLockup,
	UiEffectsPausedContext = UiEffectsPausedContext,
	SCROLL_EDGE = SCROLL_EDGE,
}
