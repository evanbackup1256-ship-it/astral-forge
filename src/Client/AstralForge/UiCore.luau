--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("UiCore: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("UiCore: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["ui"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local _Icon = require(script.Parent.ArtKit)("Icon")
local WORDMARK_ASSET = _Icon.WORDMARK_ASSET
local COMPACT_MARK_ASSET = _Icon.COMPACT_MARK_ASSET
local Icon = _Icon.Icon
local _motion = require(script.Parent.MotionKit)("motion")
local ExitPresenceContext = _motion.ExitPresenceContext
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useExitPresence = _motion.useExitPresence
local composePresence = _motion.composePresence
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
local MotionIntent = _motion.MotionIntent
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local _theme = require(script.Parent.CoreKit)("theme")
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
local _audio = require(script.Parent.AudioKit)("audio")
local Audio = _audio.Audio
local buttonAudioCue = _audio.buttonAudioCue
local hoverCueFor = _audio.hoverCueFor
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local TouchGestureService = require(script.Parent.CoreKit)("TouchGestureService")
local ShimmerMath = require(script.Parent.MotionKit)("shimmer")
local dropdownPortal
local dropdownPortalUsers = 0
local function acquireDropdownPortal()
	if dropdownPortal == nil or dropdownPortal.Parent == nil then
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local vrScreen = playerGui:FindFirstChild("AstralForgeVR")
		local rootScreen = if vrScreen and vrScreen.Enabled then vrScreen:FindFirstChild("Content") else playerGui:FindFirstChild("AstralForgeStudioUI")
		if rootScreen ~= nil then
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
	local gradientColor = React.useMemo(function()
		if typeof(color) == "Color3" then
			return strokeGradient(color)
		elseif type(color) == "table" and type(color.map) == "function" then
			return color:map(function(value)
				if typeof(value) ~= "Color3" then
					return strokeGradient(Palette.lineSoft)
				end
				return strokeGradient(value)
			end)
		end
		return strokeGradient(Palette.lineSoft)
	end, { color })
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
-- the readability floor every Text owns; callers asking for 8-10 px get this instead
local MIN_UI_TEXT_SIZE = 11
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
local function pinButtonLabel(instance)
	if instance ~= nil then
		instance.Name = "ButtonLabel"
	end
end
local function pinLayoutGuardIgnore(instance)
	if instance ~= nil then
		instance:SetAttribute("LayoutGuardIgnore", true)
	end
end
local SHIMMER_GLINT = ShimmerMath.GLINT
local SHIMMER_TRAIL = ShimmerMath.TRAIL
local SHIMMER_SWEEP_SPEED = ShimmerMath.SWEEP_SPEED
local shimmerOffset = ShimmerMath.offset
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
		local _size = 0
		for _ in inputCancelListeners do
			_size += 1
		end
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
local fontFaceCache = {}
local function fontFaceFor(font)
	local face = fontFaceCache[font]
	if face == nil then
		face = Font.fromEnum(font)
		fontFaceCache[font] = face
	end
	return face
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
	local faded = React.useMemo(function()
		return withExitFade(transparency, presence)
	end, { transparency, presence })
	local scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42)
	local font = if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold or boldText >= 0.5 then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	local painted = if surface ~= nil and typeof(color) == "Color3" then ensureContrast(surface, color) else color
	local constraint = false
	if fit then
		local floorSize = minSize
		if floorSize == nil then
			floorSize = math.max(12, size * 0.85)
		end
		constraint = React.createElement("uitextsizeconstraint", {
			MinTextSize = math.clamp(math.floor(floorSize * textScale), math.min(12, scaledSize), scaledSize),
			MaxTextSize = scaledSize,
		})
	end
	local face = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoLocalize = true,
		Text = value,
		TextColor3 = painted,
		TextSize = scaledSize,
		TextTransparency = faded,
		FontFace = fontFaceFor(font),
		TextXAlignment = align,
		TextYAlignment = if wrap then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		TextWrapped = wrap,
		TextScaled = fit,
		LineHeight = if wrap then 1.12 else 1,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = zIndex + 1,
	}
	local shadow = table.clone(face)
	shadow.Name = "TextShadow"
	shadow.Position = UDim2.fromOffset(0, 1)
	shadow.TextColor3 = Palette.void
	shadow.TextTransparency = faded:map(function(v) return 0.78 + v * 0.22 end)
	shadow.ZIndex = zIndex
	shadow.ref = function(label)
		if label then label:SetAttribute("LayoutGuardIgnore", true) end
	end
	return React.createElement("frame", {
		Size = sizeConstraint or UDim2.fromScale(1, 1),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
	}, _param.shadow ~= false and React.createElement("textlabel", shadow, constraint), React.createElement("textlabel", face, constraint))
end
local function useGuiSize(ref, useParent)
	local size, setSize = React.useBinding(Vector2.zero)
	React.useEffect(function()
		local node = ref.current
		local host = if node ~= nil and useParent then node.Parent else node
		if host == nil or not host:IsA("GuiObject") then
			return nil
		end
		local function update()
			setSize(host.AbsoluteSize)
		end
		update()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			connection:Disconnect()
		end
	end, { ref, useParent })
	return size
end
local function pixelPosition(size, xScale, xPixels, yScale, yPixels)
	-- UDim offsets are integers; scale coordinates retain fractional pixel travel.
	if size.X <= 0 or size.Y <= 0 then
		return UDim2.new(xScale, xPixels, yScale, yPixels)
	end
	return UDim2.fromScale(xScale + xPixels / size.X, yScale + yPixels / size.Y)
end
local function fontForWeight(weight)
	return if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
end
local WRAPPED_LINE_HEIGHT = 1.12
local function measureWrappedTextHeight(text, width, size, weight)
	if size == nil then
		size = 16
	end
	if weight == nil then
		weight = Enum.FontWeight.Medium
	end
	if type(text) ~= "string" or text == "" or type(width) ~= "number" or width <= 0 then
		return 0
	end
	local font = fontForWeight(weight)
	local bounds = TextService:GetTextSize(text, math.max(1, math.floor(size)), font, Vector2.new(math.max(1, math.floor(width)), 4000))
	return math.ceil(bounds.Y * WRAPPED_LINE_HEIGHT)
end
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
	local safeValue = if type(value) == "string" then value else ""
	local safeWidth = if type(width) == "number" and width == width then width else 0
	local measured = if safeValue == "" then 0 else math.ceil(TextService:GetTextSize(safeValue, scaledSize, font, Vector2.new(math.max(1, math.floor(safeWidth)), 4000)).Y * WRAPPED_LINE_HEIGHT)
	local clamped = math.max(minHeight, if maxHeight ~= nil then math.min(maxHeight, measured) else measured)
	local lastReported = React.useRef()
	local lastReportedTo = React.useRef()
	React.useEffect(function()
		if onHeightChange == nil then
			return nil
		end
		if lastReported.current == clamped and lastReportedTo.current == onHeightChange then
			return nil
		end
		lastReported.current = clamped
		lastReportedTo.current = onHeightChange
		onHeightChange(clamped)
	end, { clamped, onHeightChange })
	return React.createElement("textlabel", {
		Size = UDim2.new(0, safeWidth, 0, clamped),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoLocalize = true,
		Text = safeValue,
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
	local want = enabled and not reducedMotion and not effectsPaused and shimmerScale > 0.02
	local speed = (1 / math.max(1.2, periodSeconds)) * math.clamp(0.45 + shimmerScale * 0.55, 0.45, 1)
	local phase = useClock(want, speed, 1, false)
	local scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42)
	local font = if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	local glintColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, color:Lerp(Palette.white, 0.7)),
		ColorSequenceKeypoint.new(1, color),
	})
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
			Active = false,
			Selectable = false,
			AutoLocalize = true,
			Text = value,
			TextColor3 = Palette.cream,
			TextTransparency = math.clamp(1 - shimmerScale * 0.55, 0.35, 0.82),
			TextSize = scaledSize,
			FontFace = Font.fromEnum(font),
			TextXAlignment = align,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = zIndex + 1,
		}, shimmerConstraint, React.createElement("uigradient", {
			Color = glintColor,
			Transparency = SHIMMER_GLINT,
			Offset = phase:map(function(amount)
				return shimmerOffset(amount, 2.05)
			end),
			Rotation = ShimmerMath.ROTATION,
		}))
	end
	return React.createElement("frame", {
		Size = sizeConstraint or UDim2.fromScale(1, 1),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		ClipsDescendants = true,
		AutomaticSize = Enum.AutomaticSize.None,
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
	max = if type(max) == "number" and max == max then math.max(0, max) else 0
	value = if type(value) == "number" and value == value then math.clamp(value, 0, max) else 0
	local viewport = useViewport()
	local narrow, setNarrow = React.useState(false)
	local stacked = viewport.width < 560 or viewport.height < 420 or narrow
	local step = if max >= 100000 then math.max(1, math.floor(max / 20)) elseif max >= 100 then math.max(1, math.floor(max / 10)) else 1
	local atMin = value <= 0
	local atMax = value >= max or max <= 0
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
		fit = true,
		minSize = 11,
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
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		Change = {
			AbsoluteSize = function(instance)
				if instance.AbsoluteSize.X > 0 then
					setNarrow(instance.AbsoluteSize.X < 360)
				end
			end,
		},
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
		color = accent,
		textColor = accent,
		outline = true,
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
		outline = true,
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
local function SweptRing(_param)
	local scale = _param.scale
	local color = _param.color
	local thickness = _param.thickness
	local spin = _param.spin
	local sweepWidth = _param.sweepWidth
	if sweepWidth == nil then
		sweepWidth = 0.22
	end
	sweepWidth = math.clamp(sweepWidth, 0.02, 0.9)
	local gradientRotation = spin:map(function(degrees)
		return degrees
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
	if accent == nil then
		accent = Palette.cyan
	end
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
	if type(value) ~= "string" then
		value = if value == nil then "" else tostring(value)
	end
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
	local whole = if type(count) == "number" and count == count then math.floor(count) else 0
	if whole <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local label = if whole > 99 then "99+" else tostring(whole)
	local wide = whole >= 10
	local size = if compact then (if wide then 16 else 14) else (if wide then 20 else 16)
	if whole > 99 then
		size += 4
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = _param.position or UDim2.new(1, if compact then -2 else -3, 0, if compact then 2 else 3),
		AnchorPoint = _param.anchorPoint or Vector2.new(1, 0),
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
	local panelRef = React.useRef(nil)
	local panelSize = useGuiSize(panelRef)
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
	local automaticReveal = useFlipperSpring(1, entranceMotion, 620, 48, if reveal ~= nil or effectsPaused or panelEntranceScale <= 0.02 then 1 else 0)
	local activeReveal = reveal or automaticReveal
	local parentPresence = useExitPresence()
	local contentPresence = React.useMemo(function()
		return composePresence(parentPresence, activeReveal)
	end, { parentPresence, activeReveal })
	React.useEffect(function()
		if hovered then
			setHoverArmed(true)
		end
	end, { hovered })
	local lift = useOptionalFlipperSpring(if interactive and hovered and not effectsPaused and panelHoverScale > 0.02 then panelHoverScale else 0, interactive and hoverArmed, interactionMotion, 480, 38)
	local accentColor = accent or Palette.lineSoft
	local highlightOn = useOptionalFlipperSpring(if highlight and not effectsPaused then 1 else 0, highlight, interactionMotion, 420, 36)
	local shimmerWanted = shimmer and interactive and shimmerScale > 0.02 and not effectsPaused
	local whiteSweep = useClock(shimmerWanted and hovered, SHIMMER_SWEEP_SPEED, 1, false)
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
	local surfaceTransparency = if revealFade ~= nil then revealFade else 0
	local paintChrome = true
	local derived = React.useMemo(function()
		local liftPx = lift:map(function(amount)
			return -amount
		end)
		local revealY = activeReveal:map(function(amount)
			return (1 - math.clamp(amount, 0, 1)) * 10
		end)
		local surfaceY = React.joinBindings({ liftPx, revealY }):map(function(values)
			return values[1] + values[2]
		end)
		return {
			strokeColor = highlightOn:map(function(amount)
				return if amount >= 0.45 then accentColor else Palette.lineSoft
			end),
			shadowPosition = React.joinBindings({ surfaceY, panelSize }):map(function(values)
				return pixelPosition(values[2], 0, -4, 0, 7 + values[1])
			end),
			surfacePosition = React.joinBindings({ surfaceY, panelSize }):map(function(values)
				return pixelPosition(values[2], 0, 0, 0, values[1])
			end),
			shadowTransparency = if revealFade ~= nil then revealFade:map(function(amount)
				return math.clamp(Chrome.panelShadow + amount * (1 - Chrome.panelShadow), 0, 1)
			end) else Chrome.panelShadow,
			hairlineTransparency = if revealFade ~= nil then revealFade:map(function(amount)
				return math.clamp(Chrome.accentHairline + amount * (1 - Chrome.accentHairline), 0, 1)
			end) else Chrome.accentHairline,
			hoverWashVisible = lift:map(function(amount)
				return amount > 0.04
			end),
			hoverWashAlpha = lift:map(function(amount)
				return if amount < 0.04 then 1 else 1 - amount * 0.14
			end),
			highlightWashVisible = highlightOn:map(function(amount)
				return amount > 0.05
			end),
			highlightWashAlpha = highlightOn:map(function(amount)
				return if amount < 0.05 then 1 else 0.94 + (1 - amount) * 0.06
			end),
			glowVisible = hoverGlow:map(function(amount)
				return amount > 0.02
			end),
			glowThickness = hoverGlow:map(function(amount)
				return 1 + amount * 1.8
			end),
			glowTransparency = hoverGlow:map(function(amount)
				return 1 - amount * 0.78
			end),
		}
	end, { lift, highlightOn, activeReveal, revealFade, accentColor, hoverGlow, panelSize })
	local strokeColor = derived.strokeColor
	local hoverWashVisible = derived.hoverWashVisible
	local hoverWashAlpha = derived.hoverWashAlpha
	local highlightWashVisible = derived.highlightWashVisible
	local highlightWashAlpha = derived.highlightWashAlpha
	return React.createElement("frame", {
		ref = panelRef,
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
		Position = derived.shadowPosition,
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = derived.shadowTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius + 2),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = if paintChrome then derived.surfacePosition else UDim2.fromScale(0, 0),
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
		Visible = derived.glowVisible,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement(Stroke, {
		color = accentColor,
		thickness = derived.glowThickness,
		transparency = derived.glowTransparency,
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
		Color = ColorSequence.new(Palette.cream),
		Rotation = ShimmerMath.ROTATION,
		Transparency = SHIMMER_GLINT,
		Offset = whiteSweep:map(function(phase)
			return shimmerOffset(phase, 2.25)
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
		BackgroundTransparency = derived.hairlineTransparency,
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
	}, React.createElement(ExitPresenceContext.Provider, {
		value = contentPresence,
	}, children)))))
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
	if kind ~= nil and spec.pressStiffness ~= nil then
		return spec
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
	-- semantic role from the label: destructive actions stay calm, confirm/claim actions feel springier
	local role = spec.role
	if role == nil and hasLabel then
		role = MotionIntent.classify(text)
	end
	local pressStiffness, pressDamping, hoverStiffness, hoverDamping = 1500, 52, 900, 44
	if role == "dangerButton" then
		hoverGain *= 0.5
		pressDrop = 0.05
		tilt = 0
		pressStiffness, pressDamping, hoverStiffness, hoverDamping = 1700, 60, 980, 52
	elseif role == "primaryButton" or role == "reward" or role == "reveal" or role == "ceremony" then
		hoverGain += 0.01
		pressDrop = 0.08
		pressStiffness, pressDamping, hoverStiffness, hoverDamping = 1400, 46, 820, 38
	end
	return {
		kind = kind,
		role = role,
		hover = hoverGain,
		press = pressDrop,
		tilt = math.clamp(tilt, -1.5, 1.5),
		pressStiffness = pressStiffness,
		pressDamping = pressDamping,
		hoverStiffness = hoverStiffness,
		hoverDamping = hoverDamping,
	}
end
local function useButtonChrome(onClick, reducedMotion, disabled, sound, allowShimmer, idleShimmer, motionSpec)
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
	if idleShimmer == nil then
		idleShimmer = false
	end
	local viewport = useViewport()
	local _binding = useMotionSettings()
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local softMotion = reducedMotion or effectsPaused
	local springSoft = effectsPaused
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
	local onClickRef = React.useRef(onClick)
	onClickRef.current = onClick
	local soundRef = React.useRef(sound)
	soundRef.current = sound
	local activeTouchMove = React.useRef()
	local active = not disabled
	local poseGoal = if disabled then 0 elseif pressed then -1 elseif hovered then 1 else 0
	local pressMotion = resolvePressMotion(motionSpec)
	local pose = useOptionalFlipperSpring(poseGoal, true, springSoft, if pressed then pressMotion.pressStiffness else pressMotion.hoverStiffness, if pressed then pressMotion.pressDamping else pressMotion.hoverDamping)
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
	local focusRing = useOptionalFlipperSpring(if gamepadFocused and active then 1 else 0, true, springSoft, 760, 32)
	local impact = useFlash(popTrigger, softMotion, if touchChrome then 0.2 else 0.26)
	local shimmerWanted = allowShimmer and shimmerScale > 0.02 and active and not effectsPaused and (idleShimmer or hovered or gamepadFocused)
	local shimmer = useClock(shimmerWanted, ShimmerMath.sweepSpeed(shimmerScale), 1, false)
	local shimmerLinger, setShimmerLinger = React.useState(false)
	local wasShimmering = React.useRef(false)
	React.useEffect(function()
		if shimmerWanted then
			wasShimmering.current = true
			setShimmerLinger(true)
			return nil
		end
		if not wasShimmering.current then
			return nil
		end
		wasShimmering.current = false
		local job = task.delay(0.35, function()
			setShimmerLinger(false)
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { shimmerWanted })
	local surfaceSize = pose:map(function()
		return UDim2.fromScale(1, 1)
	end)
	local hoverGain = pressMotion.hover
	local pressDrop = pressMotion.press
	local tiltDegrees = pressMotion.tilt
	local touchScale = React.joinBindings({ pose, impact }):map(function(values)
		local value = values[1]
		local kick = math.clamp(values[2], 0, 1) * 0.035
		if value >= 0 then
			return 1 + math.clamp(value, 0, 1) * hoverGain + kick
		end
		return 1 - math.clamp(-value, 0, 1) * pressDrop + kick
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
			local moved = activeTouchMove.current
			if moved ~= nil then
				moved:Disconnect()
			end
			activeTouchMove.current = nil
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
		local moved = activeTouchMove.current
		if moved ~= nil then
			moved:Disconnect()
		end
		activeTouchMove.current = nil
		activeTouch.current = nil
		touchOrigin.current = nil
		pressWasTouch.current = false
		setPressed(false)
		hoveredRef.current = false
		setHovered(false)
		setGamepadFocused(false)
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
		if sound ~= false and not pressWasTouch.current then
			Audio:play(hoverCueFor(sound))
		end
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
		local currentSound = soundRef.current
		if currentSound ~= false then
			Audio:play(currentSound, pressEnergy)
		end
		onClickRef.current()
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
		local moved = activeTouchMove.current
		if moved ~= nil then
			moved:Disconnect()
		end
		activeTouchMove.current = nil
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
					local previousMove = activeTouchMove.current
					if previousMove ~= nil then
						previousMove:Disconnect()
					end
					activeTouchMove.current = UserInputService.InputChanged:Connect(function(changed)
						if changed ~= activeTouch.current then
							return nil
						end
						local origin = touchOrigin.current
						if origin == nil then
							return nil
						end
						if (Vector2.new(changed.Position.X, changed.Position.Y) - origin).Magnitude > 14 then
							setPressed(false)
							local moveConnection = activeTouchMove.current
							activeTouchMove.current = nil
							if moveConnection ~= nil then
								moveConnection:Disconnect()
							end
						end
					end)
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
		shimmerLive = shimmerWanted or shimmerLinger,
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
local SHIMMER_SPECULAR_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Palette.cream),
	ColorSequenceKeypoint.new(0.42, Palette.cream:Lerp(Palette.white, 0.6)),
	ColorSequenceKeypoint.new(0.5, Palette.white),
	ColorSequenceKeypoint.new(0.58, Palette.cream:Lerp(Palette.white, 0.6)),
	ColorSequenceKeypoint.new(1, Palette.cream),
})
local SHIMMER_TRAIL_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Palette.cream),
	ColorSequenceKeypoint.new(0.5, Palette.cream:Lerp(Palette.cyan, 0.1)),
	ColorSequenceKeypoint.new(1, Palette.cream),
})
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
	local live = _param.live
	if live == nil then
		live = true
	end
	local trail = _param.trail
	if trail == nil then
		trail = idle == true
	end
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local _binding = useMotionSettings()
	local shimmerScale = _binding.shimmerScale
	if shimmerScale == nil then
		shimmerScale = 1
	end
	if not live or effectsPaused or shimmerScale <= 0.02 then
		return nil
	end
	local useTrail = ShimmerMath.wantTrail(shimmerScale, trail)
	local specularColor = SHIMMER_SPECULAR_COLOR
	local trailColor = SHIMMER_TRAIL_COLOR
	local strength = hoverAmount:map(function(amount)
		return ShimmerMath.surfaceStrength(amount, idle, shimmerScale)
	end)
	local visible = hoverAmount:map(function(amount)
		return ShimmerMath.shouldShow(amount, idle, shimmerScale)
	end)
	local corner = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})
	local core = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = strength:map(function(s)
			return 1 - s
		end),
		BorderSizePixel = 0,
		Active = false,
		Selectable = false,
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 2,
	}, corner, React.createElement("uigradient", {
		Color = specularColor,
		Rotation = ShimmerMath.ROTATION,
		Transparency = SHIMMER_GLINT,
		Offset = shimmer:map(function(phase)
			return shimmerOffset(phase, ShimmerMath.DEFAULT_TRAVEL, 0)
		end),
	}))
	local trailPass = useTrail and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = strength:map(function(s)
			return 1 - s * 0.38
		end),
		BorderSizePixel = 0,
		Active = false,
		Selectable = false,
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = trailColor,
		Rotation = ShimmerMath.ROTATION,
		Transparency = SHIMMER_TRAIL,
		Offset = shimmer:map(function(phase)
			return shimmerOffset(phase, ShimmerMath.DEFAULT_TRAVEL, ShimmerMath.TRAIL_LAG)
		end),
	}))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		AutomaticSize = Enum.AutomaticSize.None,
		Active = false,
		Selectable = false,
		Visible = visible,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), trailPass, core)
end
local function fadedBy(base, fade)
	if type(base) == "number" then
		return fade:map(function(amount)
			return base + (1 - base) * amount
		end)
	end
	return React.joinBindings({ base, fade }):map(function(values)
		return values[1] + (1 - values[1]) * values[2]
	end)
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
	local hovered = _binding.hovered
	local offsetY = _binding.offsetY
	local hoverAmount = _binding.hoverAmount
	local impact = _binding.impact
	local shimmer = _binding.shimmer
	local shimmerLive = _binding.shimmerLive
	local focusRing = _binding.focusRing
	local touchScale = _binding.touchScale
	local tilt = _binding.tilt
	local events = _binding.events
	local spinnerTurn = useRotation(loading, 260)
	local labelHiddenByLoading = useFlipperSpring(if loading then 1 else 0, reducedMotion, 520, 40)
	local shake = useFlash(shakeToken, reducedMotion, 0.42)
	local lastShakeToken = React.useRef(shakeToken)
	React.useEffect(function()
		if shakeToken ~= lastShakeToken.current then
			lastShakeToken.current = shakeToken
			if shakeToken > 0 and not reducedMotion then
				Audio:play("noticeError")
			end
		end
	end, { reducedMotion, shakeToken })
	local shakeOffsetX = shake:map(function(amount)
		return math.sin(amount * math.pi * 4.5) * amount * 7
	end)
	local effectsPaused = React.useContext(UiEffectsPausedContext)
	local presence = useExitPresence()
	local arrival = useEntrance(reducedMotion or effectsPaused)
	local _condition = selectable
	if _condition == nil then
		_condition = not disabled
	end
	local canSelect = _condition
	local breatheWanted = highlight and active
	local breatheStroke = useGlowStroke(breatheWanted, reducedMotion or effectsPaused, 0.32, 0.22, 0.46, 1.15)
	local buttonRef = React.useRef()
	local hostSize = useGuiSize(buttonRef)
	local visualPosition = React.joinBindings({ arrival, shakeOffsetX, hostSize }):map(function(values)
		return pixelPosition(values[3], 0.5, values[2], 0.5, (1 - math.clamp(values[1], 0, 1)) * 8)
	end)
	local surfacePosition = React.joinBindings({ offsetY, hostSize }):map(function(values)
		return pixelPosition(values[2], 0, 0, 0, values[1])
	end)
	local shadowPosition = React.joinBindings({ offsetY, hostSize }):map(function(values)
		return pixelPosition(values[2], 0, 0, 0, 5 - values[1])
	end)
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
	local surfaceFade = React.useMemo(function()
		return presence:map(function(shown)
			return math.clamp(1 - shown, 0, 1)
		end)
	end, { presence })
	local labelFade = surfaceFade
	local shadowTransparency = React.useMemo(function()
		return fadedBy(if effectivelyDisabled then 0.84 else Chrome.buttonShadow, surfaceFade)
	end, { surfaceFade, effectivelyDisabled })
	local outlineTransparency = React.useMemo(function()
		return fadedBy(if outline then 0.14 elseif highlight and active then breatheStroke else 1, surfaceFade)
	end, { surfaceFade, outline, highlight, active, breatheStroke })
	local breatheRingTransparency = React.useMemo(function()
		return fadedBy(breatheStroke:map(function(amount)
			return math.clamp(0.55 + amount * 0.9, 0.55, 1)
		end), surfaceFade)
	end, { surfaceFade, breatheStroke })
	local focusRingTransparency = React.useMemo(function()
		return fadedBy(focusRing:map(function(amount)
			return 1 - amount * 0.98
		end), surfaceFade)
	end, { surfaceFade, focusRing })
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
		Position = shadowPosition,
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = shadowTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = surfacePosition,
		BackgroundColor3 = fill,
		BackgroundTransparency = surfaceFade,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}),
	not outline and not effectivelyDisabled and React.createElement("uigradient", {
		Color = surfaceGradient(baseFill, 0.95),
		Rotation = 90,
	}), not outline and not effectivelyDisabled and React.createElement("frame", {
		Size = UDim2.new(1, -12, 0, 1),
		Position = UDim2.fromOffset(6, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex + 2,
	}), not compactRipple and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = React.joinBindings({ hoverAmount, impact }):map(function(values)
			return math.clamp(1 - values[1] * 0.05 - values[2] * 0.06, 0.82, 1)
		end),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex + 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	})), active and React.createElement(ButtonShimmer, {
		hoverAmount = hoverAmount,
		shimmer = shimmer,
		live = shimmerLive,
		idle = highlight,
		zIndex = zIndex + 2,
		radius = Layout.buttonRadius,
	}), active and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = impact:map(function(amount)
			return math.clamp(1 - amount * 0.48, 0.52, 1)
		end),
		BorderSizePixel = 0,
		Active = false,
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
		Active = false,
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
		Active = false,
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
		ZIndex = zIndex + 3,
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
		TextWrapped = true,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = zIndex + 3,
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
		TextWrapped = true,
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
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(enabledLabelColor),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	})))), (outline or highlight) and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = surfacePosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex + 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement(Stroke, {
		color = color,
		thickness = 1,
		transparency = outlineTransparency,
	})), highlight and active and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = surfacePosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex + 4,
		Visible = breatheWanted,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement(Stroke, {
		color = lighten(color, 0.3),
		thickness = 2,
		transparency = breatheRingTransparency,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = surfacePosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex + 5,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement(Stroke, {
		color = Palette.cream,
		thickness = 4,
		transparency = focusRingTransparency,
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
	if value == nil then
		value = 0
	end
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
	local lead = useOptionalFlipperSpring(_condition, animateLiteral, lowMotion, 1500, 52)
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
	local wantShimmer = shimmer and shimmerScale > 0.02 and not empty and not effectsPaused
	local shimmerBlend = useOptionalFlipperSpring(if wantShimmer then 1 else 0, true, lowMotion, 400, 34)
	local readyPulse = usePulse(wantShimmer, 2)
	local shimmerPhase = useClock(wantShimmer, ShimmerMath.sweepSpeed(shimmerScale), 1, false)
	local _exp = React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(48, 3),
	})
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local rushing = if animateLiteral then React.joinBindings({ lead, eased }):map(function(values)
		return math.clamp(math.abs(values[1] - values[2]) * 6, 0, 1)
	end) else nil
	local _exp_lead = animateLiteral and React.createElement("frame", {
		Size = lead:map(function(amount)
			return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
		end),
		BackgroundColor3 = lighten(color, 0.45),
		BackgroundTransparency = rushing:map(function(amount)
			return 1 - amount * 0.55
		end),
		BorderSizePixel = 0,
		Visible = not empty,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	local _exp_2 = React.createElement("frame", {
		Size = fill,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = not empty,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(color, 0.32), color),
	}), React.createElement("frame", {
		Size = if rushing ~= nil then rushing:map(function(amount)
			local d = 3 + amount * 5
			return UDim2.fromOffset(d, d)
		end) else UDim2.fromOffset(3, 3),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = if rushing ~= nil then rushing:map(function(amount)
			return 0.22 - amount * 0.2
		end) else 0.22,
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
		Color = ColorSequence.new(Palette.cream),
		Transparency = SHIMMER_GLINT,
		Rotation = 22,
		Offset = shimmerPhase:map(function(phase)
			return shimmerOffset(phase, 2.6)
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
	}, _exp, _exp_1, _exp_lead, _exp_2)
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
	local amount = if type(value) == "number" and value == value then math.clamp(value, 0, 1) else 0
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
	local dragStartValue = React.useRef(amount)
	local onChangeRef = React.useRef(onChange)
	onChangeRef.current = onChange
	local onCommitRef = React.useRef(onCommit)
	onCommitRef.current = onCommit
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
		if snapped == lastValue.current then
			return nil
		end
		Audio:play("sliderStep")
		InteractionFeedback.tick()
		lastValue.current = snapped
		local change = onChangeRef.current
		if change ~= nil then
			change(snapped)
		end
	end, { trackInset })
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
			if activeDrag.current ~= nil and lastValue.current ~= dragStartValue.current then
				local commit = onCommitRef.current
				dragStartValue.current = lastValue.current
				if commit ~= nil then
					commit(lastValue.current)
				end
			end
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
			dragStartValue.current = lastValue.current
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
				dragStartValue.current = lastValue.current
				local _result = onCommitRef.current
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
	end, { updateFromX })
	local adjust = React.useCallback(function(delta)
		local adjusted = math.clamp(math.round((lastValue.current + delta) * 20) / 20, 0, 1)
		if adjusted == lastValue.current then
			return nil
		end
		lastValue.current = adjusted
		local change = onChangeRef.current
		if change ~= nil then
			change(adjusted)
		end
		local _result = onCommitRef.current
		if _result ~= nil then
			_result(adjusted)
		end
		Audio:play("sliderStep")
		InteractionFeedback.tick()
	end, {})
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
	local matched = false
	local _callback = function(amount, index)
		if amount == value then
			activeIndex = index
			matched = true
		end
	end
	for _k, _v in AMOUNT_OPTIONS do
		_callback(_v, _k - 1, AMOUNT_OPTIONS)
	end
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
		Visible = matched,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.24), accent),
		Rotation = 90,
	}))
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
	return React.createElement("frame", {
		Name = "AmountToggleTarget",
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
		ref = pinLayoutGuardIgnore,
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
		live = chrome.shimmerLive,
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
	local matched = false
	local _callback = function(option, index)
		if option.id == value then
			activeIndex = index
			matched = true
		end
	end
	for _k, _v in options do
		_callback(_v, _k - 1, options)
	end
	local activeColumn = activeIndex % columnCount
	local activeRow = math.floor(activeIndex / columnCount)
	local columnSlide = useFlipperSpring(activeColumn, reducedMotion, 1100, 48)
	local columnTrail = useFlipperSpring(activeColumn, reducedMotion, 480, 46)
	local rowSlide = useFlipperSpring(activeRow, reducedMotion, 880, 34)
	local selectionFlash = useFlash(activeIndex + 1, reducedMotion, 0.22)
	local tabsEffectsPaused = React.useContext(UiEffectsPausedContext)
	local tabSweep = useClock(reducedMotion ~= true and not tabsEffectsPaused, SHIMMER_SWEEP_SPEED, 1, false)
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
	local carrierSpan = React.joinBindings({ columnSlide, columnTrail, rowSlide })
	local carrierPosition = carrierSpan:map(function(values)
		local column = math.clamp(math.min(values[1], values[2]), 0, columnCount - 1)
		return UDim2.new(column / columnCount, gap * column / columnCount, math.clamp(values[3], 0, rowCount - 1) / rowCount, gap * math.clamp(values[3], 0, rowCount - 1) / rowCount)
	end)
	local carrierSize = carrierSpan:map(function(values)
		local stretch = math.clamp(math.abs(values[1] - values[2]), 0, columnCount - 1)
		return cellSize + UDim2.new(stretch / columnCount, gap * stretch / columnCount, 0, 0)
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
		Size = carrierSize,
		Position = carrierPosition,
		BackgroundColor3 = selectionFlash:map(function(amount)
			return lighten(selectedAccent, amount * 0.14)
		end),
		BorderSizePixel = 0,
		Visible = matched,
		ZIndex = zIndex + 1,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(selectedAccent, 0.14), darken(selectedAccent, 0.06)),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = lighten(selectedAccent, 0.24),
		Thickness = 1,
		Transparency = 0.28,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 2,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.cream),
		Rotation = ShimmerMath.ROTATION,
		Transparency = SHIMMER_GLINT,
		Offset = tabSweep:map(function(phase)
			return shimmerOffset(phase, 2.2)
		end),
	})), React.createElement("frame", {
		Size = UDim2.new(0.52, 0, 0, 2),
		Position = UDim2.new(0.5, 0, 1, -3),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
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
	local _callback = function(option)
		if option.id == value then
			selected = option
		end
	end
	for _k, _v in options do
		_callback(_v, _k - 1, options)
	end
	local buttonRef = React.useRef()
	local listRef = React.useRef()
	local scrollRef = React.useRef()
	local overControl = React.useRef(false)
	local overList = React.useRef(false)
	local shown, setShown = React.useState(open)
	if open and not shown then
		setShown(true)
	end
	React.useEffect(function()
		if open then
			return nil
		end
		overList.current = false
		overControl.current = false
		local job = task.delay(if reducedMotion then 0 else 0.32, function()
			setShown(false)
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { open, reducedMotion })
	local latest = React.useRef({ options = options, pointer = pointer, value = value, onChange = onChange })
	latest.current = { options = options, pointer = pointer, value = value, onChange = onChange }
	local lastPickAt = React.useRef(-math.huge)
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
			local live = latest.current
			if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.DPadUp then
				setPointer(function(current)
					local count = #live.options
					return if count == 0 then -1 else (if current <= 0 then count - 1 else current - 1)
				end)
				return nil
			end
			if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.DPadDown then
				setPointer(function(current)
					local count = #live.options
					return if count == 0 then -1 else (current + 1) % count
				end)
				return nil
			end
			if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
				local chosen = live.options[live.pointer + 1]
				if chosen == nil then
					return nil
				end
				local now = os.clock()
				if now - lastPickAt.current < 0.2 then
					return nil
				end
				lastPickAt.current = now
				if chosen.id ~= live.value then
					live.onChange(chosen.id)
				end
				setOpen(false)
				setPointer(-1)
				Audio:play("filterPick", 0.96 + math.min(live.pointer, 5) * 0.025)
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
	end, { open })
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
	local glowTransparency = triggerAmount:map(function(progress)
		return 1 - math.clamp(progress, 0, 1) * 0.85
	end)
	local needsScroll = #options > visibleRows
	local canvasHeight = #options * rowHeight + math.max(0, #options - 1) * listPad
	React.useEffect(function()
		if not open or not needsScroll or pointer < 0 then
			return nil
		end
		local scroller = scrollRef.current
		if scroller == nil then
			return nil
		end
		local rowTop = pointer * (rowHeight + listPad)
		local rowBottom = rowTop + rowHeight
		local viewHeight = scroller.AbsoluteWindowSize.Y
		local top = scroller.CanvasPosition.Y
		if rowTop < top then
			scroller.CanvasPosition = Vector2.new(0, rowTop)
		elseif viewHeight > 0 and rowBottom > top + viewHeight then
			scroller.CanvasPosition = Vector2.new(0, rowBottom - viewHeight)
		end
	end, { pointer, open, needsScroll })
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
		local nextY = if nextOpenUp then math.clamp(desiredY, math.max(clipTop + nextHeight, 10), math.max(math.max(clipTop + nextHeight, 10), math.min(clipBottom, screenH - 10))) else math.clamp(desiredY, math.max(clipTop, 10), math.max(clipTop, math.min(clipBottom, screenH - 10) - nextHeight))
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
		lastPickAt.current = os.clock()
		overList.current = false
		overControl.current = false
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
		_result = (React.createElement("scrollingframe", {
			ref = scrollRef,
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
	}, _exp, _exp_1, _exp_2, (open or shown) and ReactRoblox.createPortal(React.createElement("frame", {
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
		Active = open,
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
	local reactModules = require(script.Parent.ReactHosts)("reactModules")
	local draft, setDraft = React.useState(value)
	local lastEmitted = React.useRef(value)
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
			lastEmitted.current = value
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
			return UDim2.new(0, 3, 1, -math.round(16 + (1 - math.clamp(amount, 0, 1)) * 12))
		end),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = focus:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.85
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
				local text = instance.Text
				setDraft(text)
				if text == lastEmitted.current then
					return nil
				end
				lastEmitted.current = text
				return debouncedChange.run(text)
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
				lastEmitted.current = ""
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
	local micro = _param.micro == true
	local mark = if micro then 40 else 48
	local textX = mark + 10
	return React.createElement("frame", {
		Name = "AstralForgeBrand",
		Size = UDim2.fromScale(1, 1),
		Position = _param.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(mark, mark),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagelabel", {
		Name = "ForgeMonogram",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = COMPACT_MARK_ASSET,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	})), not micro and React.createElement("imagelabel", {
		Name = "ForgeWordmark",
		Image = WORDMARK_ASSET,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, textX, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -textX, 0, 44),
		ZIndex = 2,
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
	shimmerOffset = shimmerOffset,
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
	useGuiSize = useGuiSize,
	pixelPosition = pixelPosition,
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
end

__defs["MainGame"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local WorkspaceService = game:GetService("Workspace")
local _interaction = require(script.Parent.CoreKit)("interaction")
local setHapticIntensity = _interaction.setHapticIntensity
local usesDesktopStructure = _interaction.usesDesktopStructure
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _effects = __load("effects")
local POP_SECONDS = _effects.POP_SECONDS
local AutoScale = require(script.Parent.MotionKit)("autoScale").AutoScale
local _antilag = require(script.Parent.MotionKit)("antilag")
local AntilagProvider = _antilag.AntilagProvider
local _motion = require(script.Parent.MotionKit)("motion")
local MotionSettingsContext = _motion.MotionSettingsContext
local ToastRail = __load("notifications").ToastRail
local _ui = __load("ui")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local applyAccessibilityTheme = _theme.applyAccessibilityTheme
local _format = require(script.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local _AdminPrankOverlay = __load("AdminPrankOverlay")
local AdminPrankOverlay = _AdminPrankOverlay.AdminPrankOverlay
local HudPrankStage = _AdminPrankOverlay.HudPrankStage
local ActionCopy = require(script.Parent.CoreKit)("actionCopy")
local NoticeMath = require(script.Parent.CoreKit)("noticeMath")
local SnapshotEnvelopeMath = require(script.Parent.CoreKit)("snapshotEnvelopeMath")
local _appNav = require(script.Parent.CoreKit)("appNav")
local AppHelpers = _appNav.AppHelpers
local NetworkPolicy = require(script.Parent.CoreKit)("networkPolicy")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local _session = require(script.Parent.CoreKit)("session")
local GRANT_ACTIONS = _session.GRANT_ACTIONS
local adopt = _session.adopt
local attachGrantFields = _session.attachGrantFields
local isAuthed = _session.isAuthed
local whenAuthed = _session.whenAuthed
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Boot = require(script.Parent.BootKit)("BootScreen")
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local _scrolling = require(script.Parent.LayoutKit)("scrolling")
local setScrollMomentum = _scrolling.setScrollMomentum
local setScrollSpeed = _scrolling.setScrollSpeed
local _clientStore = require(script.Parent.CoreKit)("clientStore")
local ClientActions = _clientStore.ClientActions
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local preloadMountedGame = require(script.Parent.ClientRuntime)("assetPreloader").preloadMountedGame
local warmClientModules = require(script.Parent.ClientRuntime)("assetPreloader").warmClientModules
local useClientIntegrityProbe = require(script.Parent.ClientRuntime)("clientIntegrity").useClientIntegrityProbe
local friendlyPlayerMessage = ActionCopy.friendlyPlayerMessage
local failureTitle = ActionCopy.failureTitle
local failureBody = ActionCopy.failureBody
local friendlyActionResponse = ActionCopy.friendlyActionResponse
local _AppShellChrome = __load("AppShellChrome")
local Shell = _AppShellChrome.Shell
local pausePassivePaints = _AppShellChrome.pausePassivePaints
local EMPTY_NOTICES = table.freeze({})
local NOOP = function() end
local function MainGame(_param)
	local remotes = _param.remotes
	local config = _param.config
	local bootStartedAt = _param.bootStartedAt
	local externalBoot = _param.externalBoot
	if externalBoot == nil then
		externalBoot = false
	end
	local externalAntilag = _param.externalAntilag
	if externalAntilag == nil then
		externalAntilag = false
	end
	local destroyFontSamples = function()
		return nil
	end
	local onBootStatus = _param.onBootStatus
	local domainUi = _param.domainUi
	local appAlive = React.useRef(true)
	local requestWorkers = React.useRef({})
	local requestTimeouts = React.useRef({})
	local deferredJobs = React.useRef({})
	React.useEffect(function()
		appAlive.current = true
		return function()
			appAlive.current = false
			for worker in requestWorkers.current do
				pcall(function()
					return task.cancel(worker)
				end)
			end
			for timeout in requestTimeouts.current do
				pcall(function()
					return task.cancel(timeout)
				end)
			end
			for job in deferredJobs.current do
				pcall(function()
					return task.cancel(job)
				end)
			end
			table.clear(requestWorkers.current)
			table.clear(requestTimeouts.current)
			table.clear(deferredJobs.current)
		end
	end, {})
	local state = useClientSelector(function(client)
		return client.session
	end)
	local visit = useClientSelector(function(client)
		return client.visit
	end)
	local _exp = function()
		local _result = state
		if _result ~= nil then
			_result = _result.Settings.HighContrast
		end
		local _condition = _result
		if _condition == nil then
			_condition = 0
		end
		local _exp_1 = _condition >= 0.5
		local _result_1 = state
		if _result_1 ~= nil then
			_result_1 = _result_1.Settings.ColorblindMode
		end
		local _condition_1 = _result_1
		if _condition_1 == nil then
			_condition_1 = 0
		end
		applyAccessibilityTheme(_exp_1, _condition_1 >= 0.5)
	end
	local _result = state
	if _result ~= nil then
		_result = _result.Settings.ColorblindMode
	end
	local _result_1 = state
	if _result_1 ~= nil then
		_result_1 = _result_1.Settings.HighContrast
	end
	React.useEffect(_exp, { _result, _result_1 })
	local dispatchStore = useClientDispatch()
	local setVisit = React.useCallback(function(visitNext)
		return dispatchStore(ClientActions.setVisit(visitNext))
	end, { dispatchStore })
	local notices, setNotices = React.useState({})
	local hoveredNotices = React.useRef({})
	local noticeTimers = React.useRef({})
	local noticesLive = React.useRef({})
	noticesLive.current = notices
	local setNoticeHovered = React.useCallback(function(id, hovered)
		if hovered then
			local _current = hoveredNotices.current
			local _id = id
			_current[_id] = true
		else
			local _current = hoveredNotices.current
			local _id = id
			_current[_id] = nil
		end
	end, {})
	local toastsSuppressed, setToastsSuppressed = React.useState(false)
	local purchasePresentationActive = React.useRef(false)
	local setPurchasePresentationActive = React.useCallback(function(active)
		purchasePresentationActive.current = active
	end, {})
	local confettiNonce, setConfettiNonce = React.useState(0)
	local celebrationSeed = React.useRef(math.random(1, 100000))
	local bootVisible, setBootVisible = React.useState(not externalBoot)
	local shellMounted, setShellMounted = React.useState(not externalBoot)
	local shellMountedRef = React.useRef(shellMounted)
	shellMountedRef.current = shellMounted
	local bootMarks, setBootMarks = React.useState({
		bridge = true,
		remotes = remotes.Request ~= nil and remotes.State ~= nil and remotes.Toast ~= nil and remotes.Effect ~= nil,
		state = false,
		audio = false,
		assets = false,
		fonts = false,
		modules = false,
		shell = false,
		mail = false,
		research = false,
		forge = false,
		trade = false,
		boosts = false,
		settings = false,
		mobile = false,
	})
	local assetProgress, setAssetProgress = React.useState({
		loaded = 0,
		total = 0,
	})
	local moduleProgress, setModuleProgress = React.useState({
		loaded = 0,
		total = 0,
	})
	local onBootExitDone = React.useCallback(function()
		return setBootVisible(false)
	end, {})
	local markBoot = React.useCallback(function(key)
		setBootMarks(function(current)
			local _result_2
			if current[key] then
				_result_2 = current
			else
				local _object = table.clone(current)
				setmetatable(_object, nil)
				_object[key] = true
				_result_2 = _object
			end
			return _result_2
		end)
	end, {})
	local bootReady = Boot.bootChecklistReady(bootMarks)
	local bootFill = Boot.bootProgress(bootMarks)
	local bootReducedMotion = false
	React.useEffect(function()
		local assetShare = if assetProgress.total > 0 then math.clamp(assetProgress.loaded / assetProgress.total, 0, 1) elseif bootMarks.assets then 1 else 0
		local moduleShare = if moduleProgress.total > 0 then math.clamp(moduleProgress.loaded / moduleProgress.total, 0, 1) elseif bootMarks.modules then 1 else 0
		local _result_3 = onBootStatus
		if _result_3 ~= nil then
			_result_3({
				marks = bootMarks,
				ready = bootReady,
				progress = bootFill * 0.4 + assetShare * 0.3 + moduleShare * 0.3,
				reducedMotion = bootReducedMotion,
				assetsLoaded = assetProgress.loaded,
				assetsTotal = assetProgress.total,
				modulesLoaded = moduleProgress.loaded,
				modulesTotal = moduleProgress.total,
			})
		end
	end, { assetProgress.loaded, assetProgress.total, bootFill, bootMarks, bootReady, bootReducedMotion, moduleProgress.loaded, moduleProgress.total, onBootStatus })
	local adminPrank, setAdminPrank = React.useState()
	local pops, setPops = React.useState({})
	local popId = React.useRef(0)
	local comboReadout, setComboReadout = React.useState()
	local lastComboTier = React.useRef(0)
	local noticeId = React.useRef(0)
	local lastNotice = React.useRef({
		signature = "",
		at = 0,
	})
	local busy = React.useRef({})
	local inFlight = React.useRef({})
	local inFlightTotal = React.useRef(0)
	local requestSequence = React.useRef(0)
	local sentAt = React.useRef({})
	local sentAtCount = React.useRef(0)
	local latestSnapshot = React.useRef(-1)
	local latestRevision = React.useRef(-1)
	local lastTradeEpoch = React.useRef(-1)
	local lastSnapshotPaintAt = React.useRef(-math.huge)
	local loggedFirstSnapshot = React.useRef(false)
	local streakToastSent = React.useRef(false)
	local lastAcceptedSnapshot = React.useRef(nil)
	local pendingPassive = React.useRef(nil)
	local passiveFlushJob = React.useRef(nil)
	local acceptStateRef = React.useRef(nil)
	local acceptState = React.useCallback(function(rawSnapshot)
		local _rawSnapshot = rawSnapshot
		if not (type(_rawSnapshot) == "table") then
			ClientLog:warnEvery("state-envelope", 10, "UI", "ignored a bad state packet")
			return false
		end
		local candidate = rawSnapshot
		if not SnapshotEnvelopeMath.IsValidEnvelope(candidate) then
			ClientLog:warnEvery("state-envelope", 10, "UI", "ignored an incomplete snapshot")
			return false
		end
		local snapshot = rawSnapshot
		if snapshot.Revision < latestRevision.current then
			return true
		end
		if snapshot.Revision == latestRevision.current and snapshot.SnapshotId < latestSnapshot.current then
			return true
		end
		if snapshot.Revision > latestRevision.current then
			latestSnapshot.current = snapshot.SnapshotId
		else
			latestSnapshot.current = math.max(latestSnapshot.current, snapshot.SnapshotId)
		end
		local now = os.clock()
		local revisionChanged = snapshot.Revision > latestRevision.current
		local _result_6 = snapshot.Trade
		if _result_6 ~= nil then
			_result_6 = _result_6.Epoch
		end
		local _condition = _result_6
		if _condition == nil then
			_condition = -1
		end
		local tradeEpoch = _condition
		local tradeHot = tradeEpoch ~= lastTradeEpoch.current
		if tradeHot then
			lastTradeEpoch.current = tradeEpoch
		end
		local passivePaintInterval = if UserInputService.TouchEnabled then 0.7 else 0.45
		if pausePassivePaints.current and not revisionChanged and not tradeHot then
			return true
		end
		if latestRevision.current >= 0 and not revisionChanged and not tradeHot and now - lastSnapshotPaintAt.current < passivePaintInterval then
			pendingPassive.current = snapshot
			if passiveFlushJob.current == nil and appAlive.current then
				local job
				job = task.delay(math.max(0.02, passivePaintInterval - (now - lastSnapshotPaintAt.current)), function()
					passiveFlushJob.current = nil
					deferredJobs.current[job] = nil
					local pending = pendingPassive.current
					pendingPassive.current = nil
					local accept = acceptStateRef.current
					if pending ~= nil and accept ~= nil and appAlive.current then
						accept(pending)
					end
				end)
				passiveFlushJob.current = job
				deferredJobs.current[job] = true
			end
			return true
		end
		pendingPassive.current = nil
		latestRevision.current = math.max(latestRevision.current, snapshot.Revision)
		lastSnapshotPaintAt.current = now
		lastAcceptedSnapshot.current = snapshot
		dispatchStore(ClientActions.setSnapshot(snapshot))
		if not loggedFirstSnapshot.current then
			loggedFirstSnapshot.current = true
			ClientLog:once("profile-ready", "profile", `loaded world {snapshot.CurrentZone}`)
		end
		return true
	end, { dispatchStore })
	acceptStateRef.current = acceptState
	local dismissNotice = React.useCallback(function(id)
		setNotices(function(current)
			local _newValue = {}
			local _callback = function(notice)
				return notice.id ~= id
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			return _newValue
		end)
	end, {})
	local _result_3 = state
	if _result_3 ~= nil then
		_result_3 = _result_3.Settings.ToastDensity
	end
	local _condition = _result_3
	if _condition == nil then
		_condition = 0.55
	end
	local toastDensityRef = React.useRef(_condition)
	local _result_4 = state
	if _result_4 ~= nil then
		_result_4 = _result_4.Settings.ToastDensity
	end
	local _condition_1 = _result_4
	if _condition_1 == nil then
		_condition_1 = 0.55
	end
	toastDensityRef.current = _condition_1
	local _result_5 = state
	if _result_5 ~= nil then
		_result_5 = _result_5.Settings.NotificationDuration
	end
	local _condition_2 = _result_5
	if _condition_2 == nil then
		_condition_2 = 0.55
	end
	local notificationDurationRef = React.useRef(_condition_2)
	local _result_6 = state
	if _result_6 ~= nil then
		_result_6 = _result_6.Settings.NotificationDuration
	end
	local _condition_3 = _result_6
	if _condition_3 == nil then
		_condition_3 = 0.55
	end
	notificationDurationRef.current = _condition_3
	local addNotice = React.useCallback(function(title, body, tone, playSound)
		if tone == nil then
			tone = "Info"
		end
		if playSound == nil then
			playSound = true
		end
		local _condition_4 = friendlyPlayerMessage(body)
		if _condition_4 == nil then
			_condition_4 = body
		end
		body = _condition_4
		local normalizedTitle = NoticeMath.NormalizeTitle(title)
		local signature = NoticeMath.Signature(normalizedTitle, body, tone)
		local now = os.clock()
		if NoticeMath.ShouldDedupe(lastNotice.current.signature, lastNotice.current.at, signature, now) then
			return nil
		end
		lastNotice.current = {
			signature = signature,
			at = now,
		}
		NoticeMath.Record(normalizedTitle, body, tone)
		local lifetime = NoticeMath.Lifetime(notificationDurationRef.current)
		local maxNotices = NoticeMath.MaxNotices(toastDensityRef.current)
		local _exp_1 = noticesLive.current
		local _callback = function(notice)
			return notice.leaving ~= true and notice.title == normalizedTitle and notice.body == body
		end
		local _result_7
		for _i, _v in _exp_1 do
			if _callback(_v, _i - 1, _exp_1) == true then
				_result_7 = _v
				break
			end
		end
		local matching = _result_7
		local dismissId = if matching ~= nil then matching.id else noticeId.current + 1
		if matching == nil then
			noticeId.current = dismissId
		end
		local priorTimer = noticeTimers.current[dismissId]
		if priorTimer ~= nil then
			pcall(function()
				return task.cancel(priorTimer)
			end)
			deferredJobs.current[priorTimer] = nil
			noticeTimers.current[dismissId] = nil
		end
		setNotices(function(current)
			local _array = {}
			local _length = #_array
			table.move(current, 1, #current, _length + 1, _array)
			local updated = _array
			local _callback_1 = function(notice)
				return notice.id == dismissId and notice.leaving ~= true
			end
			local _result_8 = -1
			for _i, _v in updated do
				if _callback_1(_v, _i - 1, updated) == true then
					_result_8 = _i - 1
					break
				end
			end
			local index = _result_8
			if index >= 0 then
				local existing = updated[index + 1]
				local _object = table.clone(existing)
				setmetatable(_object, nil)
				_object.body = body
				_object.tone = tone
				_object.lifetime = lifetime
				_object.sound = false
				local _left = "count"
				local _condition_5 = existing.count
				if _condition_5 == nil then
					_condition_5 = 1
				end
				_object[_left] = _condition_5 + 1
				updated[index + 1] = _object
			else
				local _arg0 = {
					id = dismissId,
					title = normalizedTitle,
					body = body,
					tone = tone,
					lifetime = lifetime,
					sound = playSound,
					count = 1,
				}
				table.insert(updated, _arg0)
			end
			while #updated > maxNotices do
				local _callback_2 = function(notice)
					return notice.leaving ~= true and notice.id ~= dismissId
				end
				local _result_9
				for _i, _v in updated do
					if _callback_2(_v, _i - 1, updated) == true then
						_result_9 = _v
						break
					end
				end
				local _condition_5 = _result_9
				if _condition_5 == nil then
					_condition_5 = updated[1]
				end
				local oldest = _condition_5
				if oldest == nil then
					break
				end
				local _current = noticeTimers.current
				local _id = oldest.id
				local oldTimer = _current[_id]
				if oldTimer ~= nil then
					pcall(function()
						return task.cancel(oldTimer)
					end)
					deferredJobs.current[oldTimer] = nil
					local _current_1 = noticeTimers.current
					local _id_1 = oldest.id
					_current_1[_id_1] = nil
				end
				local _arg0 = (table.find(updated, oldest) or 0) - 1
				table.remove(updated, _arg0 + 1)
			end
			return updated
		end)
		local tryDismiss
		tryDismiss = function()
			local job = noticeTimers.current[dismissId]
			if job ~= nil then
				deferredJobs.current[job] = nil
			end
			noticeTimers.current[dismissId] = nil
			if not appAlive.current then
				return nil
			end
			if hoveredNotices.current[dismissId] ~= nil then
				local wait = task.delay(0.45, tryDismiss)
				noticeTimers.current[dismissId] = wait
				deferredJobs.current[wait] = true
				return nil
			end
			dismissNotice(dismissId)
		end
		local job = task.delay(lifetime, tryDismiss)
		noticeTimers.current[dismissId] = job
		deferredJobs.current[job] = true
	end, { dismissNotice })
	local celebrate = React.useCallback(function()
		celebrationSeed.current += math.random(1, 3)
		setConfettiNonce(celebrationSeed.current)
	end, {})
	local clearConfetti = React.useCallback(function(expectedSeed)
		setConfettiNonce(function(current)
			return if expectedSeed == nil or current == expectedSeed then 0 else current
		end)
	end, {})
	local addPop = React.useCallback(function(text, color, critical)
		local id = popId.current + 1
		popId.current = id
		setPops(function(current)
			local updated = table.clone(current)
			updated[#updated + 1] = {
				id = id,
				text = text,
				color = color,
				critical = critical,
				offset = math.random(-90, 90),
			}
			local excess = #updated - 12
			if excess > 0 then
				table.move(updated, excess + 1, #updated, 1)
				for index = #updated, #updated - excess + 1, -1 do
					updated[index] = nil
				end
			end
			return updated
		end)
		local job
		job = task.delay(POP_SECONDS, function()
			local _current = deferredJobs.current
			local _job = job
			_current[_job] = nil
			if appAlive.current then
				setPops(function(current)
					local kept = table.create(#current)
					local removed = false
					for _, pop in current do
						if pop.id == id then
							removed = true
						else
							kept[#kept + 1] = pop
						end
					end
					return if removed then kept else current
				end)
			end
		end)
		local _current = deferredJobs.current
		local _job = job
		_current[_job] = true
	end, {})
	local applyComboReadout = React.useCallback(function(combo, comboMultiplier, comboMax, comboWindow)
		if combo <= 0 then
			return nil
		end
		setComboReadout({
			combo = combo,
			comboMultiplier = comboMultiplier,
			comboMax = comboMax,
			comboWindow = comboWindow,
			updatedAt = os.clock(),
		})
	end, {})
	local _exp_1 = function(response, action, callback)
		local _action = action
		if GRANT_ACTIONS[_action] ~= nil then
			adopt(response)
		end
		local rawError = response.error
		response = friendlyActionResponse(response)
		if response.State then
			acceptState(response.State)
		end
		if action == "LeaveGuild" and response.ok then
			dispatchStore(ClientActions.patchSession({
				Guild = nil,
				GuildBonuses = {
					Production = 0,
					Capacity = 0,
					Offline = 0,
					Automation = 0,
					Tap = 0,
				},
			}))
		elseif response.Guild ~= nil then
			local guild = response.Guild
			dispatchStore(ClientActions.patchSession({
				Guild = if guild.Id == "" then nil else guild,
			}))
		end
		local _result_7 = callback
		if _result_7 ~= nil then
			_result_7(response)
		end
		if not response.ok then
			local _condition_4 = response.error
			if _condition_4 == nil then
				_condition_4 = "Try again in a moment."
			end
			local detail = _condition_4
			local _condition_5 = rawError
			if _condition_5 == nil then
				_condition_5 = detail
			end
			local lowered = string.lower(_condition_5)
			local expectedBusy = (action == "Overcharge" and (string.find(lowered, "cooling", 1, true)) ~= nil) or (string.find(lowered, "still working", 1, true)) ~= nil or (string.find(lowered, "slow down", 1, true)) ~= nil
			if not expectedBusy and response.State == nil and NetworkPolicy.IsOptimistic(action) then
				local accepted = lastAcceptedSnapshot.current
				if accepted ~= nil and appAlive.current then
					dispatchStore(ClientActions.setSnapshot(accepted))
				end
			end
			if expectedBusy then
				return nil
			end
			local _exp_2 = action
			local _condition_6 = rawError
			if _condition_6 == nil then
				_condition_6 = detail
			end
			ClientLog:warn("action", `{_exp_2} failed — {_condition_6}`)
			if AppHelpers:isPassiveRequest(action) then
				return nil
			end
			local gated = (string.find(string.lower(detail), "unlock", 1, true)) ~= nil
			local _exp_3 = failureTitle(action, gated)
			local _exp_4 = action
			local _condition_7 = rawError
			if _condition_7 == nil then
				_condition_7 = detail
			end
			addNotice(_exp_3, failureBody(_exp_4, _condition_7), "Info", false)
			return nil
		end
		local machinePurchase = action == "BuyMachine"
		local progressionPurchase = action == "BuyResearch" or action == "BuyGridUpgrade" or action == "BuyAnomalyProtocol" or action == "UpgradeContinuum" or action == "UpgradeArtifact" or action == "BuyArtifact" or action == "UpgradeCrew" or action == "BuyGuildUpgrade" or action == "UpgradeItem"
		local purchase = machinePurchase or progressionPurchase or action == "BuySignalOffer" or action == "BuyItemOffer"
		local reward = action == "ClaimDaily" or action == "ClaimTimedReward" or action == "ClaimQuest" or action == "ClaimAchievement" or action == "ClaimLabOrder" or action == "ClaimCommanderReward" or action == "ClaimWeeklyDirective" or action == "ClaimSeasonTier" or action == "ClaimExpedition" or action == "ClaimConvergenceReward" or action == "ClaimAnomalyDirective" or action == "ClaimAnomalyMilestone" or action == "ClaimForgePathStep"
		if purchase then
			Audio:play(if machinePurchase then "machineInstall" elseif action == "UpgradeArtifact" or action == "BuyArtifact" then "artifactUpgrade" elseif progressionPurchase then "researchUnlock" else "purchase")
			if action == "BuySignalOffer" or action == "BuyItemOffer" then
				local _condition_4 = response.message
				if _condition_4 == nil then
					_condition_4 = "Purchase complete."
				end
				addNotice("Bought", _condition_4, "Success")
			elseif machinePurchase then
				local _condition_4 = response.message
				if _condition_4 == nil then
					_condition_4 = "Station tuned."
				end
				addNotice("Upgraded", _condition_4, "Success", false)
			elseif progressionPurchase then
				local _condition_4 = response.message
				if _condition_4 == nil then
					_condition_4 = "Level increased."
				end
				addNotice("Upgraded", _condition_4, "Success", false)
			end
		elseif reward then
			local _condition_4 = action == "ClaimForgePathStep"
			if _condition_4 then
				local _result_8 = response.State
				if _result_8 ~= nil then
					_result_8 = _result_8.ForgePath
				end
				_condition_4 = _result_8 ~= nil
				if _condition_4 then
					local _exp_2 = response.State.ForgePath.ClaimedSteps
					local _result_9 = 0
					local _callback = function(max, step)
						return math.max(max, step)
					end
					for _i = 1, #_exp_2 do
						_result_9 = _callback(_result_9, _exp_2[_i], _i - 1, _exp_2)
					end
					_condition_4 = _result_9 % 5 == 0
				end
			end
			local forgePathMajorStep = _condition_4
			if forgePathMajorStep then
				Audio:playCelebration({ "researchUnlock", "discovery", "reward" }, 0.08)
			else
				Audio:play(if action == "ClaimDaily" then "dailyClaim" elseif action == "ClaimTimedReward" then "timedClaim" elseif action == "ClaimAchievement" then "achievementClaim" elseif action == "ClaimSeasonTier" or action == "ClaimConvergenceReward" then "seasonClaim" elseif action == "ClaimExpedition" then "expeditionReturn" elseif action == "ClaimForgePathStep" then "researchUnlock" else "missionClaim")
			end
			InteractionFeedback.reward()
			celebrate()
		elseif action == "ContributeGuild" then
			Audio:play("guildDeposit")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Contribution deposited."
			end
			addNotice("Guild bank", _condition_4, "Success")
		elseif action == "CreateGuild" then
			Audio:play("guildCreate")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Your hall is open."
			end
			addNotice("Guild chartered", _condition_4, "Special")
		elseif action == "JoinGuild" then
			Audio:play("guildJoin")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "You're in."
			end
			addNotice("Guild", _condition_4, "Success")
		elseif action == "LeaveGuild" then
			Audio:play("guildLeave")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Left the guild."
			end
			addNotice("Guild", _condition_4, "Info")
		elseif action == "DisbandGuild" then
			Audio:play("guildLeave")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "The guild is gone."
			end
			addNotice("Guild disbanded", _condition_4, "Info")
		elseif action == "KickGuildMember" then
			Audio:play("memberRemove")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "They're out of the guild."
			end
			addNotice("Crew removed", _condition_4, "Info")
		elseif action == "SetGuildRole" then
			Audio:play("roleChange")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Role changed."
			end
			addNotice("Role updated", _condition_4, "Success")
		elseif action == "SalvageItem" then
			Audio:play("salvage")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Dust recovered."
			end
			addNotice("Salvaged", _condition_4, "Success")
		elseif action == "CaptureEcho" then
			Audio:play("echoCapture")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Got three echoes."
			end
			addNotice("Pattern captured", _condition_4, "Special")
		elseif action == "ClaimEcho" then
			Audio:play("echoClaim")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "EquipEcho" then
			Audio:play("echoEquip")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Loadout updated."
			end
			addNotice("Echo linked", _condition_4, "Info")
		elseif action == "UpgradeEcho" then
			Audio:play("echoTune")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "It's stronger now."
			end
			addNotice("Echo tuned", _condition_4, "Success")
		elseif action == "DismantleEcho" then
			Audio:play("echoDismantle")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Resonance recovered."
			end
			addNotice("Memory released", _condition_4, "Info")
		elseif action == "LaunchExpedition" then
			Audio:play("expeditionLaunch")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "They're out."
			end
			addNotice("Expedition", _condition_4, "Success")
		elseif action == "EquipArtifact" then
			Audio:play("artifactEquip")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Loadout updated."
			end
			addNotice("Equipped", _condition_4, "Info")
		elseif action == "EquipTitle" then
			Audio:play("badgeEarn")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Title updated."
			end
			addNotice("Title equipped", _condition_4, "Success", false)
		elseif action == "ClaimStoryChapter" then
			Audio:play("unlock")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "ClaimMail" or action == "ClaimAllMail" then
			Audio:play("mailClaim")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "RedeemCode" then
			Audio:play("codeReward")
			InteractionFeedback.reward()
			celebrate()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Reward claimed."
			end
			addNotice("Code claimed", _condition_4, "Special")
		elseif action == "VerifyCreatorFollow" then
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = ""
			end
			local already = (string.find(string.lower(_condition_4), "already", 1, true)) ~= nil
			if not already then
				Audio:play("codeReward")
				InteractionFeedback.reward()
				celebrate()
			end
			local _condition_5 = response.message
			if _condition_5 == nil then
				_condition_5 = "Thanks for following."
			end
			addNotice("Follow reward", _condition_5, if already then "Info" else "Special")
		elseif action == "StudioGrantProduct" then
			Audio:play("purchase")
		elseif action == "AdminExecute" then
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Done."
			end
			if response.DryRun == true then
				addNotice("Preview ready", _condition_4, "Info")
			else
				Audio:play("confirm")
				addNotice("Change applied", _condition_4, "Success")
			end
		elseif action == "InviteTrade" then
			Audio:play("invite")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Invite sent."
			end
			addNotice("Trade invite", _condition_4, "Info")
		elseif action == "RespondTrade" then
			Audio:play("confirm")
		elseif action == "ConfirmTrade" then
			Audio:play("purchase")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Trade finished."
			end
			addNotice("Trade", _condition_4, "Success")
		elseif action == "CancelTrade" then
			Audio:play("close")
		elseif action == "SpinWheel" then
		elseif action == "OpenItemCrate" then
			local _result_8 = response.Rolls
			if _result_8 ~= nil then
				_result_8 = #_result_8
			end
			local _condition_4 = _result_8
			if _condition_4 == nil then
				_condition_4 = 0
			end
			if _condition_4 == 0 then
				celebrate()
			end
		elseif action == "RouteLabPower" then
			Audio:play("labRoute")
		elseif action == "SetAutoForge" then
			Audio:play("autoForge")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Auto-forge set."
			end
			addNotice("Auto-Forge", _condition_4, "Info")
		elseif action == "SetAnomalyChannel" then
			Audio:play("toggleOn")
		elseif action == "ActivateAnomalySurge" then
			Audio:play("reactorSurge")
		elseif action == "DeleteMail" then
			Audio:play("close")
		elseif action == "DomainExpansion" then
			Audio:play("domainImpact")
			local rewardJob
			rewardJob = task.delay(0.2, function()
				deferredJobs.current[rewardJob] = nil
				if appAlive.current then
					Audio:playCelebration({ "domainReward", "discovery" }, 0.1)
				end
			end)
			deferredJobs.current[rewardJob] = true
			InteractionFeedback.reward()
			celebrate()
		elseif action == "Rebirth" then
			-- the ceremony owns the rebirth cues and timing; the notice still lands for the log
			__load("RebirthCeremony").play({
				rebirths = response.Rebirths,
				before = response.MultiplierBefore,
				after = response.MultiplierAfter,
				reward = response.Reward,
				stardust = response.StardustReward,
			})
			celebrate()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "The forge starts over, stronger."
			end
			addNotice("Rebirth done", _condition_4, "Special")
		elseif action == "SetSetting" then
			if response.message ~= nil and response.message ~= "Setting updated." then
				addNotice("Preset on", response.message, "Success")
			end
		elseif action == "SetMobileLayout" then
		elseif action == "ActivateBoost" then
			Audio:play("boostActivate")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Timer started."
			end
			addNotice("Boost on", _condition_4, "Success")
		elseif action == "UnlockZone" then
			Audio:play("zoneUnlock")
			InteractionFeedback.reward()
			celebrate()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "A new world is open."
			end
			addNotice("World unlocked", _condition_4, "Special", false)
		elseif action == "NudgeCrew" then
			Audio:play("crewNudge")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "They’ll see it."
			end
			addNotice("Waved", _condition_4, "Info")
		elseif action == "VisitPlot" then
			Audio:play("travel")
			if response.Visit then
				setVisit(response.Visit)
			end
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "You're in their shop."
			end
			addNotice("Visiting", _condition_4, "Info")
		elseif action == "LeavePlot" then
			Audio:play("close")
			setVisit(nil)
		elseif action == "SelectZone" then
			Audio:play("zoneSelect")
		elseif action == "EquipItem" then
			Audio:play("itemLink")
		elseif action == "UnequipItem" then
			Audio:play("itemUnlink")
		elseif action == "EquipBestItems" then
			Audio:play("itemLink")
			InteractionFeedback.tap()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Best relics equipped."
			end
			addNotice("Loadout optimized", _condition_4, "Success", false)
		elseif action == "BulkSalvageItems" then
			Audio:play("salvage")
			InteractionFeedback.tap()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Relics broken down."
			end
			addNotice("Salvaged", _condition_4, "Success", false)
		elseif action == "ToggleItemLock" then
			Audio:play("toggleOn")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Lock updated."
			end
			addNotice("Relic", _condition_4, "Info", false)
		elseif action == "StabilizeAnomaly" then
			Audio:play("reactorStabilize")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "CompleteTutorial" then
			InteractionFeedback.reward()
			celebrate()
		elseif action == "CollectVault" then
			Audio:play("vaultDeposit")
			InteractionFeedback.reward()
			InteractionFeedback.confirm()
			celebrate()
		elseif action == "Overcharge" then
			if response.Combo ~= nil and response.ComboMultiplier ~= nil then
				local _exp_2 = response.Combo
				local _exp_3 = response.ComboMultiplier
				local _condition_4 = response.ComboMax
				if _condition_4 == nil then
					_condition_4 = 12
				end
				local _condition_5 = response.ComboWindow
				if _condition_5 == nil then
					_condition_5 = 1.8
				end
				applyComboReadout(_exp_2, _exp_3, _condition_4, _condition_5)
			end
		elseif action == "PulseAnomaly" then
			Audio:play("reactorPulse")
		elseif action == "ClaimAnomalyDirective" or action == "ClaimAnomalyMilestone" then
			Audio:play("collect")
			InteractionFeedback.reward()
		elseif response.message ~= nil and action ~= "Overcharge" and action ~= "ActivateBoost" and action ~= "RouteLabPower" and action ~= "SetTutorialStep" and action ~= "ReplayTutorial" and action ~= "DismissRelease" and action ~= "OpenRelease" and action ~= "ReadStoryChapter" and action ~= "ReadMail" and action ~= "SetSetting" and action ~= "SetMobileLayout" and action ~= "ChatOpenWhisper" and action ~= "ChatGlobal" and action ~= "VisitPlot" and action ~= "LeavePlot" and action ~= "SyncShop" and action ~= "GetPlayers" and action ~= "GetLeaderboard" and action ~= "GetGuildLeaderboard" and action ~= "GetGuild" and action ~= "GetGuildChatHistory" and action ~= "GetGuildAnnouncements" and action ~= "GetGuildSettings" and action ~= "GetGuildLogoReview" and action ~= "SendGuildChat" and action ~= "CreateGuildAnnouncement" and action ~= "EditGuildAnnouncement" and action ~= "PinGuildAnnouncement" and action ~= "ArchiveGuildAnnouncement" and action ~= "SetGuildAnnouncementExpiry" and action ~= "SetGuildSettings" and action ~= "MuteGuildMember" and action ~= "UnmuteGuildMember" and action ~= "BanGuildMember" and action ~= "UnbanGuildMember" and action ~= "UploadGuildLogo" and action ~= "ModerateGuildLogo" and action ~= "GetTrade" and action ~= "UpdateTradeOffer" and action ~= "SetTradeReady" and action ~= "VerifyCreatorFollow" and action ~= "RedeemCode" then
			addNotice("Done", response.message, "Info")
		end
	end
	local applyResponse = React.useCallback(_exp_1, { acceptState, addNotice, applyComboReadout, celebrate, dispatchStore, setVisit })
	local dispatch
	dispatch = React.useCallback(function(action, payload, callback)
		if payload == nil then
			payload = {}
		end
		local _payload = payload
		local value = if type(_payload) == "table" then payload else {}
		local signature = AppHelpers:actionSignature(action, value)
		local pipelined = NetworkPolicy.IsPipelined(action)
		local reject = function(message, uncertain)
			local _result_8 = callback
			if _result_8 ~= nil then
				_result_8({
					ok = false,
					error = message,
					Uncertain = uncertain == true,
				})
			end
		end
		if not appAlive.current then
			return nil
		end
		local _action_1 = action
		if GRANT_ACTIONS[_action_1] ~= nil then
			if not isAuthed() then
				local settled = false
				whenAuthed(function()
					if settled or not appAlive.current then
						return nil
					end
					settled = true
					return dispatch(action, payload, callback)
				end)
				local authJob
				authJob = task.delay(4, function()
					deferredJobs.current[authJob] = nil
					if settled or not appAlive.current then
						return nil
					end
					settled = true
					if isAuthed() then
						dispatch(action, payload, callback)
						return nil
					end
					reject("Your session is still connecting. Try again in a moment.")
				end)
				return nil
			end
			value = table.clone(value)
			attachGrantFields(value)
		end
		if not pipelined and busy.current[signature] ~= nil then
			reject("Already working on that.")
			return nil
		end
		local _condition_4 = inFlight.current[signature]
		if _condition_4 == nil then
			_condition_4 = 0
		end
		local activeRequests = _condition_4
		local requestLimit = NetworkPolicy.RequestLimit(pipelined)
		if activeRequests >= requestLimit then
			reject("Still working on your last tap.")
			return nil
		end
		if inFlightTotal.current >= NetworkPolicy.MAX_PHYSICAL_REQUESTS then
			reject("The connection is busy. Try again in a moment.")
			return nil
		end
		local now = os.clock()
		local cooldown = NetworkPolicy.Cooldown(action)
		local previous = sentAt.current[signature]
		if previous ~= nil and NetworkPolicy.IsCoolingDown(now, previous, cooldown) then
			reject("Slow down a sec.")
			return nil
		end
			if previous == nil then
				sentAtCount.current += 1
			end
			sentAt.current[signature] = now
			if sentAtCount.current > 256 then
				local remaining = 0
				for key, timestamp in sentAt.current do
					if now - timestamp > 60 then
						sentAt.current[key] = nil
					else
						remaining += 1
					end
				end
				if remaining > 384 then
					-- Evict oldest timestamps first so unrelated action signatures do not
					-- lose their cooldowns arbitrarily.
					local entries = {}
					for key, timestamp in sentAt.current do
						table.insert(entries, { key = key, timestamp = timestamp })
					end
					table.sort(entries, function(a, b)
						return a.timestamp < b.timestamp
					end)
					local target = remaining - 256
					for i = 1, target do
						sentAt.current[entries[i].key] = nil
					end
					remaining -= target
				end
				sentAtCount.current = remaining
			end
		if NetworkPolicy.IsOptimistic(action) then
			dispatchStore(ClientActions.applyOptimistic(action, value, config.Game.Version))
		end
		if action == "Overcharge" or action == "PulseAnomaly" then
			Audio:play("reactorPulse")
		elseif action == "CollectVault" then
			Audio:play("vaultBank")
		end
		local requestToken = requestSequence.current + 1
		requestSequence.current = requestToken
		local _current = inFlight.current
		local _arg1 = activeRequests + 1
		_current[signature] = _arg1
		inFlightTotal.current += 1
		if not pipelined then
			busy.current[signature] = requestToken
		end
		local requestTimedOut = false
		local requestReleased = false
		local releaseRequest = function()
			if requestReleased then
				return nil
			end
			requestReleased = true
			local _condition_6 = inFlight.current[signature]
			if _condition_6 == nil then
				_condition_6 = 1
			end
			local remaining = _condition_6 - 1
			if remaining > 0 then
				inFlight.current[signature] = remaining
			else
				inFlight.current[signature] = nil
			end
			inFlightTotal.current = math.max(0, inFlightTotal.current - 1)
		end
		local requestTimeout
		local requestWorker
		local timeoutSeconds = NetworkPolicy.Timeout(action)
		requestTimeout = task.delay(timeoutSeconds, function()
			if requestTimeout ~= nil then
				local _current_1 = requestTimeouts.current
				local _requestTimeout = requestTimeout
				_current_1[_requestTimeout] = nil
			end
			requestTimeout = nil
			local ownsControl = pipelined or busy.current[signature] == requestToken
			if not pipelined and ownsControl then
				busy.current[signature] = nil
			end
			requestTimedOut = true
			releaseRequest()
			if not appAlive.current or not ownsControl then
				return nil
			end
			if NetworkPolicy.IsOptimistic(action) then
				local accepted = lastAcceptedSnapshot.current
				if accepted ~= nil then
					dispatchStore(ClientActions.setSnapshot(accepted))
				end
			end
			ClientLog:warnEvery(`timeout:{action}`, 8, "UI", `{action} timed out after {timeoutSeconds}s`)
			addNotice("Connection hiccup", "That action timed out. You can try it again now.", "Info", false)
			reject("That took too long. Try again.", true)
		end)
		local _current_1 = requestTimeouts.current
		local _requestTimeout = requestTimeout
		_current_1[_requestTimeout] = true
		requestWorker = task.defer(function()
			local ok, raw = pcall(function()
				return remotes.Request:InvokeServer(action, value)
			end)
			if requestWorker ~= nil then
				local _current_2 = requestWorkers.current
				local _requestWorker = requestWorker
				_current_2[_requestWorker] = nil
			end
			requestWorker = nil
			if requestTimeout ~= nil then
				task.cancel(requestTimeout)
				local _current_2 = requestTimeouts.current
				local _requestTimeout_1 = requestTimeout
				_current_2[_requestTimeout_1] = nil
				requestTimeout = nil
			end
			if not pipelined and busy.current[signature] == requestToken then
				busy.current[signature] = nil
			end
			releaseRequest()
			if not appAlive.current then
				return nil
			end
			if requestTimedOut then
				if ok and type(raw) == "table" then
					if GRANT_ACTIONS[action] ~= nil then
						adopt(raw)
					end
					if raw.State then
						acceptState(raw.State)
					end
				end
				return nil
			end
			local _condition_7 = not ok or not (type(raw) == "table")
			if not _condition_7 then
				local _ok = raw.ok
				_condition_7 = not (type(_ok) == "boolean")
			end
			if _condition_7 then
				ClientLog:warnEvery(`request:{action}`, 5, "UI", `{action} got no answer`)
				addNotice("Connection hiccup", "That tap didn't go through. Try again.", "Info", false)
				reject("That tap didn't go through. Try again.", true)
				return nil
			end
			applyResponse(raw, action, callback)
		end)
		local _current_2 = requestWorkers.current
		local _requestWorker = requestWorker
		_current_2[_requestWorker] = true
	end, { acceptState, addNotice, applyResponse, config.Game.Version, dispatchStore, remotes })
	useClientIntegrityProbe(dispatch)
	local _exp_2 = function()
		if state == nil then
			return nil
		end
		if state.Daily.CanClaim ~= true then
			streakToastSent.current = false
			return nil
		end
		if streakToastSent.current then
			return nil
		end
		if state.Daily.CanClaim == true and state.Daily.Streak >= 1 then
			streakToastSent.current = true
			local day = state.Daily.Streak
			addNotice("Daily streak", if day > 1 then `Day {day} is ready to claim in Rewards.` else "Today’s daily is ready in Rewards.", "Special")
		end
	end
	local _result_8 = state
	if _result_8 ~= nil then
		_result_8 = _result_8.Daily.CanClaim
	end
	local _result_9 = state
	if _result_9 ~= nil then
		_result_9 = _result_9.Daily.Streak
	end
	React.useEffect(_exp_2, { addNotice, _result_8, _result_9 })
	local _exp_3 = function()
		local _snapshotCombo = state
		if _snapshotCombo ~= nil then
			_snapshotCombo = _snapshotCombo.Overcharge
		end
		local snapshotCombo = _snapshotCombo
		if snapshotCombo == nil or snapshotCombo.Combo <= 0 or comboReadout ~= nil then
			return nil
		end
		setComboReadout({
			combo = snapshotCombo.Combo,
			comboMultiplier = snapshotCombo.ComboMultiplier,
			comboMax = snapshotCombo.ComboMax,
			comboWindow = snapshotCombo.ComboWindow,
			updatedAt = os.clock(),
		})
	end
	local _result_10 = state
	if _result_10 ~= nil then
		_result_10 = _result_10.Overcharge
	end
	React.useEffect(_exp_3, { comboReadout, _result_10 })
	React.useEffect(function()
		local alive = true
		local fontWorker
		local fontTimeout
		local moduleWorker
		local stateWorker
		local cancelWorker = function(worker)
			if worker ~= nil then
				pcall(function()
					return task.cancel(worker)
				end)
			end
		end
		local stateConnection = remotes.State.OnClientEvent:Connect(function(snapshot)
			local _condition_4 = not alive
			if not _condition_4 then
				local _snapshot = snapshot
				_condition_4 = not (type(_snapshot) == "table")
			end
			if _condition_4 then
				return nil
			end
			if not acceptState(snapshot) then
				return nil
			end
			markBoot("bridge")
			markBoot("state")
		end)
		local toastConnection = remotes.Toast.OnClientEvent:Connect(function(payload)
			local _condition_4 = not alive
			if not _condition_4 then
				local _payload = payload
				_condition_4 = not (type(_payload) == "table")
			end
			if _condition_4 then
				return nil
			end
			local value = payload
			local tone = (value.Tone) or "Info"
			local _condition_5 = value.Title
			if _condition_5 == nil then
				_condition_5 = "Update"
			end
			local _exp_4 = tostring(_condition_5)
			local _condition_6 = value.Body
			if _condition_6 == nil then
				_condition_6 = "Something changed."
			end
			addNotice(_exp_4, tostring(_condition_6), tone)
		end)
		local effectConnection = remotes.Effect.OnClientEvent:Connect(function(payload)
			local _condition_4 = not alive
			if not _condition_4 then
				local _payload = payload
				_condition_4 = not (type(_payload) == "table")
			end
			if _condition_4 then
				return nil
			end
			local value = payload
			local _condition_5 = value.Type
			if _condition_5 == nil then
				_condition_5 = ""
			end
			local kind = tostring(_condition_5)
			local _amount = value.Amount
			local amount = if type(_amount) == "number" then value.Amount else 0
			if kind == "Collect" and amount > 0 then
				addPop(`+{compactNumber(amount)}`, Palette.green, false)
			elseif kind == "Overcharge" and amount > 0 then
				addPop(`+{compactNumber(amount)}`, if value.Critical == true then Palette.mango else Palette.cyan, value.Critical == true)
				local _combo = value.Combo
				local combo = if type(_combo) == "number" then value.Combo else nil
				local _comboMultiplier = value.ComboMultiplier
				local comboMultiplier = if type(_comboMultiplier) == "number" then value.ComboMultiplier else nil
				if combo ~= nil and comboMultiplier ~= nil then
					local _comboMax = value.ComboMax
					local comboMax = if type(_comboMax) == "number" then value.ComboMax else 12
					local _comboWindow = value.ComboWindow
					applyComboReadout(combo, comboMultiplier, comboMax, if type(_comboWindow) == "number" then value.ComboWindow else 1.8)
					if combo <= 1 then
						lastComboTier.current = 0
					end
					local tier = math.floor((combo / math.max(1, comboMax)) * 4)
					if tier > lastComboTier.current and combo < comboMax then
						Audio:play("tick")
					elseif combo >= comboMax and lastComboTier.current < 4 then
						Audio:play("unlock")
					end
					lastComboTier.current = if combo >= comboMax then 4 else tier
				end
			elseif kind == "FeatureUnlocked" and not purchasePresentationActive.current then
				Audio:play("unlock")
				InteractionFeedback.reward()
				celebrate()
			elseif kind == "LevelUp" and not purchasePresentationActive.current then
				__load("levelMoments").pushLevelMoment(value)
				InteractionFeedback.reward()
				celebrate()
			elseif kind == "ServerEvent" then
				__load("serverEventsUi").pushServerEvent(value)
			elseif kind == "LevelReward" then
				__load("levelMoments").pushLevelMoment(value)
			elseif kind == "AnomalyPulse" then
				Audio:play("reactor")
			elseif kind == "AnomalyReady" then
				Audio:play("reactorReady")
			elseif kind == "AnomalyStabilized" then
				Audio:play("discovery")
			elseif kind == "ItemLinked" then
				Audio:play("equip")
			elseif kind == "GuildChat" or kind == "GuildAnnouncement" or kind == "GuildSettings" or kind == "GuildLogo" or kind == "GuildModeration" then
				if kind == "GuildAnnouncement" then Audio:play("guildAnnounce") elseif kind ~= "GuildChat" then Audio:play("collect") end
			elseif kind == "GuildBanned" then
				addNotice("Guild ban", "You have been removed from this guild.", "Warning")
			else
				local _condition_6 = kind == "VisitUpdate"
				if _condition_6 then
					local _visit = value.Visit
					_condition_6 = type(_visit) == "table"
				end
				if _condition_6 then
					setVisit(value.Visit)
				elseif kind == "VisitEnded" then
					setVisit(nil)
				elseif kind == "CrewState" then
					local CrewStore = require(script.Parent.CrewStore)
					local wasInCrew = CrewStore.get().crew ~= nil
					CrewStore.set({ crew = if type(value.Crew) == "table" then value.Crew else CrewStore.NONE })
					if value.Crew == nil and wasInCrew and type(value.Reason) == "string" then
						addNotice("Crew", value.Reason, "Info")
					end
				elseif kind == "CrewInvite" then
					local CrewStore = require(script.Parent.CrewStore)
					CrewStore.set({ invite = { FromUserId = value.FromUserId, FromName = value.FromName, CrewName = value.CrewName, ExpiresAt = value.ExpiresAt } })
					Audio:play("invite")
					addNotice("Crew invite", `{tostring(value.FromName or "Someone")} invited you to {tostring(value.CrewName or "a crew")}. Open Crew to answer.`, "Special")
				elseif kind == "CrewNotice" then
					addNotice("Crew", tostring(value.Text or ""), "Info")
				elseif kind == "CrewNudge" then
					Audio:play("crewNudge")
					InteractionFeedback.tap()
					local _condition_7 = value.FromName
					if _condition_7 == nil then
						_condition_7 = "Someone"
					end
					local from = tostring(_condition_7)
					addNotice("Crew nudge", `{from} waved at you.`, "Special")
				elseif kind == "DomainExpansion" and tonumber(value.UserId) ~= Players.LocalPlayer.UserId then
					Audio:play("domainImpact")
					local _condition_7 = tonumber(value.Rank)
					if _condition_7 == nil then
						_condition_7 = 1
					end
					addNotice("Domain nearby", `Someone opened Domain {math.floor(_condition_7)}.`, "Special")
				elseif kind == "AdminPrank" then
					local _condition_7 = value.Kind
					if _condition_7 == nil then
						_condition_7 = "Jumpscare"
					end
					local prankKind = tostring(_condition_7)
					local _condition_8 = tonumber(value.Duration)
					if _condition_8 == nil then
						_condition_8 = 6
					end
					local duration = math.clamp(_condition_8, 2, 20)
					local _condition_9 = value.Caption
					if _condition_9 == nil then
						_condition_9 = ""
					end
					local caption = tostring(_condition_9)
					setAdminPrank({
						kind = prankKind,
						endsAt = os.clock() + duration,
						caption = caption,
					})
					Audio:play("adminExecute")
				end
			end
		end)
		markBoot("remotes")
		Audio:start()
		Audio:whenWarm(function()
			if alive then
				markBoot("audio")
			end
		end)
		local fontFaces = { Font.fromEnum(Enum.Font.BuilderSans), Font.fromEnum(Enum.Font.BuilderSansMedium), Font.fromEnum(Enum.Font.BuilderSansBold), Font.fromEnum(Enum.Font.BuilderSansExtraBold), Font.fromEnum(Enum.Font.RobotoMono), Font.fromEnum(Enum.Font.Code), Font.new("rbxasset://fonts/families/GothamSSm.json") }
		local fontFinished = false
		fontWorker = task.spawn(function()
			pcall(function()
				return ContentProvider:PreloadAsync(fontFaces)
			end)
			if fontFinished then
				return nil
			end
			fontFinished = true
			if alive then
				markBoot("fonts")
			end
		end)
		fontTimeout = task.delay(6, function()
			if fontFinished then
				return nil
			end
			fontFinished = true
			cancelWorker(fontWorker)
			fontWorker = nil
			destroyFontSamples()
			if alive then
				markBoot("fonts")
			end
		end)
		moduleWorker = task.spawn(function()
			local deadline = os.clock() + Boot.BOOT_MODULE_TIMEOUT
			local waitChild = function(parent, name, budget)
				local left = math.max(0.05, deadline - os.clock())
				return parent:WaitForChild(name, math.min(budget, left))
			end
			pcall(function()
				local astral = waitChild(ReplicatedStorage, "AstralForge", 4)
				if astral ~= nil then
					waitChild(astral, "Shared", 3)
					local shared = astral:FindFirstChild("Shared")
					if shared ~= nil then
						local spinner = waitChild(shared, "NumberSpinner", 3)
						if spinner ~= nil and spinner:IsA("ModuleScript") then
							pcall(function()
								return require(spinner)
							end)
						end
					end
					local vendor = astral:FindFirstChild("Vendor") or waitChild(astral, "Vendor", 2)
					if vendor ~= nil then
						local vendorSpinner = vendor:FindFirstChild("NumberSpinner")
						if vendorSpinner ~= nil and vendorSpinner:IsA("ModuleScript") then
							pcall(function()
								return require(vendorSpinner)
							end)
						end
					end
				end
				local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts") or Players.LocalPlayer:WaitForChild("PlayerScripts", math.max(0.1, deadline - os.clock()))
				if playerScripts ~= nil then
					waitChild(playerScripts, "AstralForge", 3)
				end
				pcall(function()
					local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
					if starterScripts ~= nil then
						starterScripts:FindFirstChild("AstralForge")
					end
				end)
				warmClientModules(function(loaded, total)
					if alive then
						setModuleProgress({
							loaded = loaded,
							total = total,
						})
					end
				end)
			end)
			if alive then
				markBoot("modules")
			end
		end)
		stateWorker = task.spawn(function()
			local attempt = 0
			local lastConnectNotice = 0
			while alive and latestSnapshot.current < 0 do
				local bridgeReady = remotes.Bridge ~= nil and remotes.Bridge:GetAttribute("Ready") == true
				if bridgeReady then
					markBoot("bridge")
				end
				if bridgeReady then
					local ok, raw = pcall(function()
						return remotes.Request:InvokeServer("GetState", {})
					end)
					if alive and ok and type(raw) == "table" then
						local response = raw
						if response.State and acceptState(response.State) then
							markBoot("state")
							break
						end
					end
				end
				attempt += 1
				if alive and attempt >= 20 and os.clock() - lastConnectNotice > 30 then
					lastConnectNotice = os.clock()
					addNotice("Still connecting", "Your save is taking longer than usual to load. If Astral Forge is open on another device, close it there.", "Info", false)
				end
				task.wait(math.min(0.2 + attempt * 0.08, 1.5))
			end
			if alive and remotes.Bridge ~= nil and remotes.Bridge:GetAttribute("Ready") == true then
				markBoot("bridge")
			end
		end)
		return function()
			alive = false
			fontFinished = true
			cancelWorker(fontWorker)
			cancelWorker(fontTimeout)
			cancelWorker(moduleWorker)
			cancelWorker(stateWorker)
			destroyFontSamples()
			stateConnection:Disconnect()
			toastConnection:Disconnect()
			effectConnection:Disconnect()
		end
	end, { acceptState, addNotice, addPop, applyComboReadout, celebrate, markBoot, remotes })
	local stateLoaded = state ~= nil
	React.useEffect(function()
		if not stateLoaded then
			return nil
		end
		local connection
		local token = task.defer(function()
			setShellMounted(true)
			local frames = 0
			connection = RunService.Heartbeat:Connect(function()
				frames += 1
				if frames < 2 then
					return nil
				end
				local _result_11 = connection
				if _result_11 ~= nil then
					_result_11:Disconnect()
				end
				connection = nil
				markBoot("shell")
				markBoot("mail")
				markBoot("research")
				markBoot("forge")
				markBoot("trade")
				markBoot("boosts")
				markBoot("settings")
				markBoot("mobile")
			end)
		end)
		return function()
			task.cancel(token)
			local _result_11 = connection
			if _result_11 ~= nil then
				_result_11:Disconnect()
			end
		end
	end, { markBoot, stateLoaded })
	React.useEffect(function()
		return preloadMountedGame(function()
			return markBoot("assets")
		end, function(loaded, total)
			return setAssetProgress({
				loaded = loaded,
				total = total,
			})
		end, function()
			return shellMountedRef.current
		end)
	end, { markBoot })
	local _exp_4 = function()
		Audio:start()
		local _object = {}
		local _left = "UiVolume"
		local _result_11 = state
		if _result_11 ~= nil then
			_result_11 = _result_11.Settings.UiVolume
		end
		_object[_left] = _result_11
		local _left_1 = "GameplayVolume"
		local _result_12 = state
		if _result_12 ~= nil then
			_result_12 = _result_12.Settings.GameplayVolume
		end
		_object[_left_1] = _result_12
		local _left_2 = "RewardVolume"
		local _result_13 = state
		if _result_13 ~= nil then
			_result_13 = _result_13.Settings.RewardVolume
		end
		_object[_left_2] = _result_13
		local _left_3 = "AmbientVolume"
		local _result_14 = state
		if _result_14 ~= nil then
			_result_14 = _result_14.Settings.AmbientVolume
		end
		_object[_left_3] = _result_14
		local _left_4 = "HoverSounds"
		local _result_15 = state
		if _result_15 ~= nil then
			_result_15 = _result_15.Settings.HoverSounds
		end
		_object[_left_4] = _result_15
		local _left_5 = "NotificationSounds"
		local _result_16 = state
		if _result_16 ~= nil then
			_result_16 = _result_16.Settings.NotificationSounds
		end
		_object[_left_5] = _result_16
		local _left_6 = "PageMusic"
		local _result_17 = state
		if _result_17 ~= nil then
			_result_17 = _result_17.Settings.PageMusic
		end
		_object[_left_6] = _result_17
		local _left_8 = "SoundVariation"
		local _result_19 = state
		if _result_19 ~= nil then
			_result_19 = _result_19.Settings.SoundVariation
		end
		_object[_left_8] = _result_19
		Audio:configurePreferences(_object)
		local _result_21 = state
		if _result_21 ~= nil then
			_result_21 = _result_21.Settings.SoundVolume
		end
		local _condition_4 = _result_21
		if _condition_4 == nil then
			_condition_4 = 0.75
		end
		Audio:setVolume(_condition_4)
		local _result_22 = state
		if _result_22 ~= nil then
			_result_22 = _result_22.Settings.MusicVolume
		end
		local _condition_5 = _result_22
		if _condition_5 == nil then
			_condition_5 = 1
		end
		Audio:setMusicVolume(_condition_5)
		local _result_23 = state
		if _result_23 ~= nil then
			_result_23 = _result_23.Settings.SfxVolume
		end
		local _condition_6 = _result_23
		if _condition_6 == nil then
			_condition_6 = 1
		end
		Audio:setSfxVolume(_condition_6)
	end
	local _result_11 = state
	if _result_11 ~= nil then
		_result_11 = _result_11.Settings.AmbientVolume
	end
	local _result_12 = state
	if _result_12 ~= nil then
		_result_12 = _result_12.Settings.GameplayVolume
	end
	local _result_13 = state
	if _result_13 ~= nil then
		_result_13 = _result_13.Settings.HoverSounds
	end
	local _result_15 = state
	if _result_15 ~= nil then
		_result_15 = _result_15.Settings.SoundVariation
	end
	local _result_17 = state
	if _result_17 ~= nil then
		_result_17 = _result_17.Settings.MusicVolume
	end
	local _result_18 = state
	if _result_18 ~= nil then
		_result_18 = _result_18.Settings.NotificationSounds
	end
	local _result_19 = state
	if _result_19 ~= nil then
		_result_19 = _result_19.Settings.PageMusic
	end
	local _result_20 = state
	if _result_20 ~= nil then
		_result_20 = _result_20.Settings.RewardVolume
	end
	local _result_21 = state
	if _result_21 ~= nil then
		_result_21 = _result_21.Settings.SfxVolume
	end
	local _result_22 = state
	if _result_22 ~= nil then
		_result_22 = _result_22.Settings.SoundVolume
	end
	local _result_23 = state
	if _result_23 ~= nil then
		_result_23 = _result_23.Settings.UiVolume
	end
	React.useEffect(_exp_4, { _result_11, _result_12, _result_13, _result_15, _result_17, _result_18, _result_19, _result_20, _result_21, _result_22, _result_23 })
	local _exp_5 = function()
		local _result_24 = state
		if _result_24 ~= nil then
			_result_24 = _result_24.Settings.ScrollSpeed
		end
		local _condition_4 = _result_24
		if _condition_4 == nil then
			_condition_4 = 0.65
		end
		setScrollSpeed(_condition_4)
		local _result_25 = state
		if _result_25 ~= nil then
			_result_25 = _result_25.Settings.ScrollMomentum
		end
		local _condition_5 = _result_25
		if _condition_5 == nil then
			_condition_5 = 0.75
		end
		setScrollMomentum(_condition_5)
		local _result_26 = state
		if _result_26 ~= nil then
			_result_26 = _result_26.Settings.HapticIntensity
		end
		local _condition_6 = _result_26
		if _condition_6 == nil then
			_condition_6 = 0.65
		end
		setHapticIntensity(_condition_6)
	end
	local _result_24 = state
	if _result_24 ~= nil then
		_result_24 = _result_24.Settings.HapticIntensity
	end
	local _result_25 = state
	if _result_25 ~= nil then
		_result_25 = _result_25.Settings.ScrollMomentum
	end
	local _result_26 = state
	if _result_26 ~= nil then
		_result_26 = _result_26.Settings.ScrollSpeed
	end
	React.useEffect(_exp_5, { _result_24, _result_25, _result_26 })
	local _result_27 = state
	if _result_27 ~= nil then
		_result_27 = _result_27.Settings.MotionIntensity
	end
	local _condition_4 = _result_27
	if _condition_4 == nil then
		_condition_4 = 1
	end
	local motionIntensity = _condition_4
	local softFeel = game:GetService("GuiService").ReducedMotionEnabled == true or motionIntensity < 0.3
	local _result_28 = state
	if _result_28 ~= nil then
		_result_28 = _result_28.Settings.ViewportSpeed
	end
	local _condition_5 = _result_28
	if _condition_5 == nil then
		_condition_5 = 1
	end
	local viewportSpeed = _condition_5
	local viewportTick, setViewportTick = React.useState(0)
	React.useEffect(function()
		local sizeConnection
		local function attach()
			if sizeConnection ~= nil then
				sizeConnection:Disconnect()
				sizeConnection = nil
			end
			local camera = WorkspaceService.CurrentCamera
			if camera ~= nil then
				sizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					setViewportTick(function(current)
						return current + 1
					end)
				end)
			end
		end
		attach()
		local cameraConnection = WorkspaceService:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			attach()
			setViewportTick(function(current)
				return current + 1
			end)
		end)
		return function()
			cameraConnection:Disconnect()
			if sizeConnection ~= nil then
				sizeConnection:Disconnect()
			end
		end
	end, {})
	local _result_29 = WorkspaceService.CurrentCamera
	if _result_29 ~= nil then
		_result_29 = _result_29.ViewportSize
	end
	local _condition_6 = _result_29
	if _condition_6 == nil then
		_condition_6 = Vector2.new(1280, 720)
	end
	local rawViewportSize = _condition_6
	local isTouchUiHere = not usesDesktopStructure(rawViewportSize.X, rawViewportSize.Y) and UserInputService.TouchEnabled
	local _result_30
	if isTouchUiHere then
		local _result_31 = state
		if _result_31 ~= nil then
			_result_31 = _result_31.Settings.MobileTextScale
		end
		local _condition_7 = _result_31
		if _condition_7 == nil then
			_condition_7 = 0.5
		end
		_result_30 = 0.92 + _condition_7 * 0.34
	else
		local _result_31 = state
		if _result_31 ~= nil then
			_result_31 = _result_31.Settings.DesktopTextScale
		end
		local _condition_7 = _result_31
		if _condition_7 == nil then
			_condition_7 = 0.5
		end
		_result_30 = 0.96 + _condition_7 * 0.2
	end
	local textScale = _result_30
	local _exp_6 = function()
		local _object = {
			motionScale = motionIntensity,
			viewportScale = viewportSpeed,
			textScale = textScale,
			soft = softFeel,
		}
		local _left = "shimmerScale"
		local _result_31 = state
		if _result_31 ~= nil then
			_result_31 = _result_31.Settings.ButtonShimmers
		end
		local _condition_7 = _result_31
		if _condition_7 == nil then
			_condition_7 = 1
		end
		local _result_32
		if _condition_7 >= 0.5 then
			local _result_33 = state
			if _result_33 ~= nil then
				_result_33 = _result_33.Settings.ShimmerIntensity
			end
			local _condition_8 = _result_33
			if _condition_8 == nil then
				_condition_8 = 0.8
			end
			_result_32 = _condition_8
		else
			_result_32 = 0
		end
		_object[_left] = _result_32
		local _left_1 = "panelHoverScale"
		local _result_33 = state
		if _result_33 ~= nil then
			_result_33 = _result_33.Settings.PanelHover
		end
		local _condition_8 = _result_33
		if _condition_8 == nil then
			_condition_8 = 1
		end
		_object[_left_1] = if _condition_8 >= 0.5 then 1 else 0
		local _left_2 = "panelEntranceScale"
		local _result_34 = state
		if _result_34 ~= nil then
			_result_34 = _result_34.Settings.PanelEntrances
		end
		local _condition_9 = _result_34
		if _condition_9 == nil then
			_condition_9 = 1
		end
		_object[_left_2] = if _condition_9 >= 0.5 then 1 else 0
		local _left_3 = "titleScale"
		local _result_35 = state
		if _result_35 ~= nil then
			_result_35 = _result_35.Settings.AnimatedTitles
		end
		local _condition_10 = _result_35
		if _condition_10 == nil then
			_condition_10 = 1
		end
		_object[_left_3] = if _condition_10 >= 0.5 then 1 else 0
		local _left_4 = "iconScale"
		local _result_36 = state
		if _result_36 ~= nil then
			_result_36 = _result_36.Settings.IconAnimations
		end
		local _condition_11 = _result_36
		if _condition_11 == nil then
			_condition_11 = 1
		end
		_object[_left_4] = if _condition_11 >= 0.5 then 1 else 0
		local _left_5 = "numberScale"
		local _result_37 = state
		if _result_37 ~= nil then
			_result_37 = _result_37.Settings.NumberAnimations
		end
		local _condition_12 = _result_37
		if _condition_12 == nil then
			_condition_12 = 1
		end
		_object[_left_5] = if _condition_12 >= 0.5 then 1 else 0
		local _left_6 = "boldText"
		local _result_38 = state
		if _result_38 ~= nil then
			_result_38 = _result_38.Settings.BoldText
		end
		local _condition_13 = _result_38
		if _condition_13 == nil then
			_condition_13 = 0
		end
		_object[_left_6] = _condition_13
		return _object
	end
	local _result_31 = state
	if _result_31 ~= nil then
		_result_31 = _result_31.Settings.AnimatedTitles
	end
	local _result_32 = state
	if _result_32 ~= nil then
		_result_32 = _result_32.Settings.BoldText
	end
	local _result_33 = state
	if _result_33 ~= nil then
		_result_33 = _result_33.Settings.ButtonShimmers
	end
	local _result_34 = state
	if _result_34 ~= nil then
		_result_34 = _result_34.Settings.IconAnimations
	end
	local _result_35 = state
	if _result_35 ~= nil then
		_result_35 = _result_35.Settings.NumberAnimations
	end
	local _result_36 = state
	if _result_36 ~= nil then
		_result_36 = _result_36.Settings.PanelEntrances
	end
	local _result_37 = state
	if _result_37 ~= nil then
		_result_37 = _result_37.Settings.PanelHover
	end
	local _result_38 = state
	if _result_38 ~= nil then
		_result_38 = _result_38.Settings.ShimmerIntensity
	end
	local motionSettings = React.useMemo(_exp_6, { motionIntensity, softFeel, _result_31, _result_32, _result_33, _result_34, _result_35, _result_36, _result_37, _result_38, textScale, viewportSpeed })
	local touchUi = isTouchUiHere
	local _condition_7 = not touchUi
	if not _condition_7 then
		local _result_39 = state
		if _result_39 ~= nil then
			_result_39 = _result_39.Settings.MobileToastVisible
		end
		local _condition_8 = _result_39
		if _condition_8 == nil then
			_condition_8 = 1
		end
		_condition_7 = _condition_8 >= 0.5
	end
	local mobileToastsVisible = _condition_7
	local mobileLayoutCache = React.useRef(nil)
	local clearAdminPrank = React.useCallback(function()
		setAdminPrank(nil)
	end, {})
	local _condition_8 = state ~= nil and shellMounted
	if _condition_8 then
		local _attributes = {
			state = state,
			config = config,
			dispatch = dispatch,
			addNotice = addNotice,
			celebrate = celebrate,
			confettiNonce = confettiNonce,
			clearConfetti = clearConfetti,
			pops = pops,
			comboReadout = comboReadout,
			visit = visit,
			setVisit = setVisit,
		}
		local _result_39 = domainUi
		if _result_39 ~= nil then
			_result_39 = _result_39.open
		end
		local _condition_9 = _result_39
		if _condition_9 == nil then
			_condition_9 = NOOP
		end
		_attributes.openDomain = _condition_9
		local _result_40 = domainUi
		if _result_40 ~= nil then
			_result_40 = _result_40.active
		end
		_attributes.domainOverlayActive = _result_40 == true
		_attributes.setToastsSuppressed = setToastsSuppressed
		_attributes.setPurchasePresentationActive = setPurchasePresentationActive
		local _exp_7 = React.createElement(Shell, _attributes)
		local _attributes_1 = {
			notices = if mobileToastsVisible and not toastsSuppressed then notices else EMPTY_NOTICES,
			remove = dismissNotice,
			setHovered = setNoticeHovered,
			reducedMotion = false,
			density = toastDensityRef.current,
		}
		local _result_41
		if touchUi then
			local _object = {}
			local _left = "x"
			local _condition_10 = state.Settings.MobileToastX
			if _condition_10 == nil then
				_condition_10 = 0.84
			end
			_object[_left] = _condition_10
			local _left_1 = "y"
			local _condition_11 = state.Settings.MobileToastY
			if _condition_11 == nil then
				_condition_11 = 0.27
			end
			_object[_left_1] = _condition_11
			local _left_2 = "scale"
			local _condition_12 = state.Settings.MobileToastScale
			if _condition_12 == nil then
				_condition_12 = state.Settings.MobileHudScale
				if _condition_12 == nil then
					_condition_12 = 0.5
				end
			end
			_object[_left_2] = _condition_12
			local _left_3 = "opacity"
			local _condition_13 = state.Settings.ReducedTransparency
			if _condition_13 == nil then
				_condition_13 = 0
			end
			local _result_42
			if _condition_13 >= 0.5 then
				_result_42 = 1
			else
				local _condition_14 = state.Settings.MobileToastOpacity
				if _condition_14 == nil then
					_condition_14 = state.Settings.MobileHudOpacity
					if _condition_14 == nil then
						_condition_14 = 0.85
					end
				end
				_result_42 = _condition_14
			end
			_object[_left_3] = _result_42
			local cachedLayout = mobileLayoutCache.current
			if cachedLayout ~= nil and cachedLayout.x == _object.x and cachedLayout.y == _object.y and cachedLayout.scale == _object.scale and cachedLayout.opacity == _object.opacity then
				_result_41 = cachedLayout
			else
				mobileLayoutCache.current = _object
				_result_41 = _object
			end
		else
			_result_41 = nil
		end
		_attributes_1.mobileLayout = _result_41
		_condition_8 = React.createElement(React.Fragment, nil, _exp_7, React.createElement(ToastRail, _attributes_1))
	end
	local shellContent = _condition_8
	local domainContent = if state ~= nil and shellMounted then React.createElement(AutoScale, nil, if domainUi ~= nil then domainUi.render(state, dispatch, shellContent) else shellContent) else shellContent
	local _attributes = {
		prank = adminPrank,
	}
	_attributes.reducedMotion = false
	local _exp_7 = React.createElement(HudPrankStage, _attributes, domainContent)
	local _condition_9 = adminPrank ~= nil
	if _condition_9 then
		local _attributes_1 = {
			prank = adminPrank,
		}
		_attributes_1.reducedMotion = false
		_attributes_1.onClose = clearAdminPrank
		_condition_9 = React.createElement(AdminPrankOverlay, _attributes_1)
	end
	local _condition_10 = not externalBoot and bootVisible
	if _condition_10 then
		local _attributes_1 = {
			marks = bootMarks,
			ready = bootReady,
			progress = bootFill,
			version = config.Game.Version,
		}
		_attributes_1.reducedMotion = false
		_attributes_1.startedAt = bootStartedAt
		_attributes_1.assetsLoaded = assetProgress.loaded
		_attributes_1.assetsTotal = assetProgress.total
		_attributes_1.modulesLoaded = moduleProgress.loaded
		_attributes_1.modulesTotal = moduleProgress.total
		_attributes_1.onExitDone = onBootExitDone
		_condition_10 = React.createElement(MotionSettingsContext.Provider, {
			value = Boot.BOOT_MOTION,
		}, React.createElement(Boot.BootScreen, _attributes_1))
	end
	local content = React.createElement(MotionSettingsContext.Provider, {
		value = motionSettings,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_7, _condition_9, _condition_10))
	return if externalAntilag then content else React.createElement(AntilagProvider, nil, content)
end
return {
	MainGame = MainGame,
}
end

__defs["AppShellChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local reactModules = require(script.Parent.ReactHosts)("reactModules")
local useLatestCallback = reactModules.useLatestCallback
local notePage = require(script.Parent.ReactHosts)("vendorHost").notePage
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _MobileShell = __load("MobileShell")
local MobileHeader = _MobileShell.MobileHeader
local MobileQuickActions = _MobileShell.MobileQuickActions
local MobileTabBar = _MobileShell.MobileTabBar
local _flexbox = require(script.Parent.MotionKit)("flexbox")
local Flex = _flexbox.Flex
local FlexItem = _flexbox.FlexItem
local _effects = __load("effects")
local EffectLayer = _effects.EffectLayer
local StarField = _effects.StarField
local CelebrationBurst = __load("CelebrationBurst").CelebrationBurst
local ComboBadge = __load("ComboBadge").ComboBadge
local _antilag = require(script.Parent.MotionKit)("antilag")
local AntilagContext = _antilag.AntilagContext
local clampAntilagTier = _antilag.clampAntilagTier
local setAntilagPreference = _antilag.setAntilagPreference
local setAntilagScene = _antilag.setAntilagScene
local useAntilag = _antilag.useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local beginUiTransition = _motion.beginUiTransition
local setClockBudget = _motion.setClockBudget
local useFlipperSpring = _motion.useFlipperSpring
local useDynamicLayoutNumber = require(script.Parent.MotionKit)("dynamicLayout").useDynamicLayoutNumber
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _ui = __load("ui")
local Button = _ui.Button
local Text = _ui.Text
local _theme = require(script.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local CreditsOverlay = __load("CreditsView").CreditsOverlay
local CrateRevealOverlay = __load("CrateRevealOverlay").CrateRevealOverlay
local RebirthCeremonyHost = __load("RebirthCeremony").RebirthCeremonyHost
local PageContent = require(script.Parent.pages.PageRouter).PageContent
local PageFrame = require(script.Parent.ReactHosts)("reactHost").PageFrame
local useGameChat = require(script.Parent.ClientRuntime)("chat").useGameChat
local _appNav = require(script.Parent.CoreKit)("appNav")
local AppHelpers = _appNav.AppHelpers
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _TopBarChrome = __load("TopBarChrome")
local TopBar = _TopBarChrome.TopBar
local _ShellFx = __load("ShellFx")
local TradeReturnPill = _ShellFx.TradeReturnPill
local AmbientLayer = _ShellFx.AmbientLayer
local _NavChrome = __load("NavChrome")
local Navigation = _NavChrome.Navigation
local _WorkspaceChrome = __load("WorkspaceChrome")
local Workspace = _WorkspaceChrome.Workspace
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local _session = require(script.Parent.CoreKit)("session")
local setPresencePage = _session.setPresencePage
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _onboarding = __load("onboarding")
local ReleaseNotesModal = _onboarding.ReleaseNotesModal
local TutorialOverlay = _onboarding.TutorialOverlay
local LevelMomentHost = __load("levelMoments").LevelMomentHost
local ServerEventHost = __load("serverEventsUi").ServerEventHost
local _clientStore = require(script.Parent.CoreKit)("clientStore")
local ClientActions = _clientStore.ClientActions
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local PlayerlistOverlay = __load("PlayerlistOverlay").PlayerlistOverlay
local OfflineRewardsOverlay = __load("OfflineRewardsOverlay").OfflineRewardsOverlay
local FeedbackOverlay = __load("FeedbackOverlay").FeedbackOverlay
local LevelRoadmapHost = __load("levelRoadmap").LevelRoadmapHost
local readLevelState = __load("levelRoadmap").readLevelState

local pausePassivePaints = {
	current = false,
}
local TUTORIAL_STEPS = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("TutorialScript").STEPS
local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}
local function offlineRewardsProps(state, reducedMotion, dispatch, dismiss)
	local offline = if type(state.Offline) == "table" then state.Offline else {}
	local effects = state.Settings.OfflineRewardEffects
	if effects == nil then
		effects = 1
	end
	return {
		reward = if offline.Reward ~= nil then offline.Reward else 0,
		seconds = if offline.Seconds ~= nil then offline.Seconds else 0,
		efficiency = if offline.Efficiency ~= nil then offline.Efficiency else state.OfflineEfficiency,
		capped = offline.Capped == true,
		production = if offline.Production ~= nil then offline.Production else state.Production,
		awaySeconds = offline.AwaySeconds,
		capHours = if offline.CapHours ~= nil then offline.CapHours else state.OfflineHours,
		vault = if offline.Vault ~= nil then offline.Vault else state.Vault,
		reducedMotion = reducedMotion,
		effectsEnabled = effects >= 0.5,
		onCollect = function()
			return dispatch("CollectVault")
		end,
		onClose = dismiss,
	}
end
local function AppShell(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local addNotice = _param.addNotice
	local celebrate = _param.celebrate
	local confettiNonce = _param.confettiNonce
	local clearConfetti = _param.clearConfetti
	local pops = _param.pops
	local comboReadout = _param.comboReadout
	local visit = _param.visit
	local setVisit = _param.setVisit
	local openDomain = _param.openDomain
	local domainOverlayActive = _param.domainOverlayActive
	local setToastsSuppressed = _param.setToastsSuppressed
	local setPurchasePresentationActive = _param.setPurchasePresentationActive
	local crateReveal, setCrateReveal = React.useState()
	local pageHostRef = React.useRef(nil)
	local cinematicOpen = crateReveal ~= nil or domainOverlayActive
	React.useEffect(function()
		pausePassivePaints.current = cinematicOpen
		return function()
			pausePassivePaints.current = false
		end
	end, { cinematicOpen })
	React.useEffect(function()
		local _condition = state.Settings.PerformanceBias
		if _condition == nil then
			_condition = 0.5
		end
		setAntilagPreference(_condition)
	end, { state.Settings.PerformanceBias })
	local playerlistOpen, setPlayerlistOpen = React.useState(false)
	local feedbackOpen, setFeedbackOpen = React.useState(false)
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local drawerNav = chrome.stack or (not viewport.desktop and UserInputService.TouchEnabled and viewport.compact)
	local page = useClientSelector(function(client)
		return client.navigation.page
	end)
	local bootChromeVisible = useClientSelector(function(client)
		return client.boot.visible
	end)
	local dispatchStore = useClientDispatch()
	local setPage = React.useCallback(function(pageNext)
		return dispatchStore(ClientActions.navigate(pageNext))
	end, { dispatchStore })
	React.useEffect(function()
		setPresencePage(page)
	end, { page })
	local railOpen, setRailOpen = React.useState(not drawerNav)
	local previousDrawerNav = React.useRef(drawerNav)
	React.useEffect(function()
		if previousDrawerNav.current == drawerNav then
			return nil
		end
		previousDrawerNav.current = drawerNav
		setRailOpen(not drawerNav)
	end, { drawerNav })
	local arcadeBusy, setArcadeBusy = React.useState(false)
	local hidden, setHidden = React.useState(false)
	local buyAmount, setBuyAmount = React.useState(1)
	local chat = useGameChat(page == "Chat", true, dispatch, state.Settings)
	local offlineReceiptKey = if state.Offline ~= nil and state.Offline.Seconds >= 30 then `{math.floor(state.Offline.Seconds)}:{compactNumber(state.Offline.Reward)}` else ""
	local dismissedOfflineKey, setDismissedOfflineKey = React.useState("")
	local offlineDismissed = offlineReceiptKey ~= "" and dismissedOfflineKey == offlineReceiptKey
	local _binding = (function()
		local _condition = state.Settings.UiDensity
		if _condition == nil then
			_condition = 0.55
		end
		local uiDensity = _condition
		local densityScale = 0.82 + uiDensity * 0.36
		local edgePad = math.max(8, chrome.sideSafe, math.floor(chrome.pagePadding * densityScale))
		local topPad = if chrome.stack then 6 else Layout.topbarClearance
		local _condition_1 = viewport.keyboardOpen and chrome.mobile
		if _condition_1 then
			local _condition_2 = state.Settings.MobileKeyboardCompact
			if _condition_2 == nil then
				_condition_2 = 1
			end
			_condition_1 = _condition_2 >= 0.5
		end
		local keyboardShellCompact = _condition_1
		local _result
		if keyboardShellCompact then
			_result = 0
		else
			local _result_1
			if chrome.stack then
				_result_1 = chrome.topbarRows
			else
				local _condition_2 = state.Settings.CompactTopBar
				if _condition_2 == nil then
					_condition_2 = 0
				end
				_result_1 = if _condition_2 >= 0.5 then math.max(52, chrome.topbarRows - 8) else chrome.topbarRows
			end
			_result = _result_1
		end
		local topbarHeight = _result
		local moreAtBottom = chrome.stack
		local tabBarH = if keyboardShellCompact then 0 else chrome.tabBarH
		local shellTop = topPad + topbarHeight + chrome.panelGap
		local desktopDockTop = shellTop
		local desktopDockHeight = 0
		local _condition_2 = state.Settings.MobileQuickVisible
		if _condition_2 == nil then
			_condition_2 = 1
		end
		local mobileQuickEnabled = _condition_2 >= 0.5
		local quickActionsVisible = mobileQuickEnabled and moreAtBottom and page == "Workshop" and not viewport.keyboardOpen and not arcadeBusy and crateReveal == nil and not railOpen
		local quickBottomOffset = tabBarH + 12
		local bottomPad = if keyboardShellCompact then 4 elseif moreAtBottom then (if quickActionsVisible then tabBarH + 76 + chrome.panelGap else tabBarH + chrome.panelGap) else math.max(8, math.floor(edgePad * 0.6))
		return {
			edgePad = edgePad,
			topPad = topPad,
			keyboardShellCompact = keyboardShellCompact,
			topbarHeight = topbarHeight,
			moreAtBottom = moreAtBottom,
			shellTop = shellTop,
			desktopDockTop = desktopDockTop,
			desktopDockHeight = desktopDockHeight,
			tabBarH = tabBarH,
			quickActionsVisible = quickActionsVisible,
			quickBottomOffset = quickBottomOffset,
			bottomPad = bottomPad,
		}
	end)()
	local edgePad = _binding.edgePad
	local topPad = _binding.topPad
	local keyboardShellCompact = _binding.keyboardShellCompact
	local topbarHeight = _binding.topbarHeight
	local shellTop = _binding.shellTop
	local tabBarH = _binding.tabBarH
	local quickActionsVisible = _binding.quickActionsVisible
	local quickBottomOffset = _binding.quickBottomOffset
	local bottomPad = _binding.bottomPad
	local reducedMotion = false
	local softMotion = false
	local shellTopLive = useDynamicLayoutNumber(shellTop, softMotion)
	local topbarLive = useDynamicLayoutNumber(topbarHeight, softMotion)
	React.useEffect(function()
		Audio:setView(page, false)
	end, { page })
	local _condition = state.Settings.EffectsIntensity
	if _condition == nil then
		_condition = 1
	end
	local effectsScale = _condition
	local accent = AppHelpers:pageAccent(page)
	local _result = state.ActiveBoost
	if _result ~= nil then
		_result = _result.Id
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = ""
	end
	local activeBoostId = _condition_1
	local _result_1 = state.ActiveBoost
	if _result_1 ~= nil then
		_result_1 = _result_1.EndsAt
	end
	local _condition_2 = _result_1
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local activeBoostEndsAt = _condition_2
	local activeBoostExpired, setActiveBoostExpired = React.useState(activeBoostEndsAt <= workspace:GetServerTimeNow())
	React.useEffect(function()
		local remaining = activeBoostEndsAt - workspace:GetServerTimeNow()
		setActiveBoostExpired(remaining <= 0)
		if activeBoostId == "" or remaining <= 0 then
			return nil
		end
		local expiry = task.delay(remaining + 0.05, function()
			return setActiveBoostExpired(true)
		end)
		return function()
			return task.cancel(expiry)
		end
	end, { activeBoostEndsAt, activeBoostId })
	local _result_2
	if not activeBoostExpired and activeBoostId ~= "" then
		local _result_3 = config.Boosts
		if _result_3 ~= nil then
			_result_3 = _result_3[activeBoostId]
		end
		_result_2 = _result_3
	else
		_result_2 = nil
	end
	local activeBoost = _result_2
	local wallClock = useWallClock(activeBoost ~= nil)
	local hideAmount = useFlipperSpring(if hidden then 1 else 0, softMotion, 620, 42)
	local mobileShell = chrome.stack
	local drawerWidth = math.min(Layout.sidebarWidth, math.max(248, viewport.width - edgePad * 2 - 36))
	local railTarget = if railOpen then (if drawerNav then drawerWidth else (if viewport.compact then Layout.sidebarCollapsedWidth else Layout.sidebarWidth)) else 0
	local railWidth = useFlipperSpring(if mobileShell then 0 else railTarget, softMotion, 900, 46)
	local drawerProgress = railWidth:map(function(width)
		return if drawerNav then math.clamp(width / math.max(drawerWidth, 1), 0, 1) else 0
	end)
	local drawerScrimTransparency = drawerProgress:map(function(amount)
		return 1 - amount * 0.58
	end)
	local drawerScrimVisible = drawerProgress:map(function(amount)
		return amount > 0.01
	end)
	local drawerPanelVisible = railWidth:map(function(width)
		return not drawerNav or width > 36
	end)
	local dockVisible = railWidth:map(function(width)
		return not drawerNav or width <= 4
	end)
	local workspaceOffset = railWidth:map(function(width)
		if drawerNav then
			return UDim2.fromOffset(0, 0)
		end
		return UDim2.new(0, if width > 1 then width + Layout.panelGap else 0, 0, 0)
	end)
	local workspaceSize = railWidth:map(function(width)
		if drawerNav then
			return UDim2.fromScale(1, 1)
		end
		return UDim2.new(1, -(if width > 1 then width + Layout.panelGap else 0), 1, 0)
	end)
	local _condition_3 = state.Flags.TutorialStep
	if _condition_3 == nil then
		_condition_3 = 1
	end
	local serverTutorialStep = math.clamp(math.floor(_condition_3), 1, #TUTORIAL_STEPS)
	local tutorialStep, setTutorialStep = React.useState(serverTutorialStep)
	local tutorialHold = React.useRef(0)
	React.useEffect(function()
		if tutorialHold.current > 0 and serverTutorialStep < tutorialHold.current and not state.Flags.TutorialDone then
			return nil
		end
		tutorialHold.current = 0
		setTutorialStep(serverTutorialStep)
	end, { serverTutorialStep, state.Flags.TutorialDone })
	local tutorial = TUTORIAL_STEPS[tutorialStep]
	local tutorialOpen = not state.Flags.TutorialDone and tutorial ~= nil
	local releaseClosedLocally, setReleaseClosedLocally = React.useState(false)
	React.useEffect(function()
		if state.Flags.LastSeenVersion == "" then
			setReleaseClosedLocally(false)
		end
	end, { state.Flags.LastSeenVersion })
	local showRelease = state.Flags.TutorialDone and state.Flags.LastSeenVersion ~= config.Game.Version and not releaseClosedLocally
	local _condition_4 = offlineReceiptKey ~= "" and not offlineDismissed and state.Flags.TutorialDone
	if _condition_4 then
		local _result_3 = state.Offline
		if _result_3 ~= nil then
			_result_3 = _result_3.Reward
		end
		local _condition_5 = _result_3
		if _condition_5 == nil then
			_condition_5 = 0
		end
		_condition_4 = gteFlux(_condition_5, 0.01)
		if _condition_4 then
			_condition_4 = not showRelease and page ~= "Credits" and crateReveal == nil and not playerlistOpen and not feedbackOpen and not domainOverlayActive
		end
	end
	local offlineRewardsOpen = _condition_4
	local modalOwnsScreen = tutorialOpen or showRelease or page == "Credits" or crateReveal ~= nil or domainOverlayActive
	React.useEffect(function()
		setToastsSuppressed(modalOwnsScreen)
		return function()
			return setToastsSuppressed(false)
		end
	end, { modalOwnsScreen, setToastsSuppressed })
	reactModules.useEventListener(UserInputService.InputBegan, function(input, processed)
		if UserInputService:GetFocusedTextBox() ~= nil then
			return nil
		end
		if processed then
			return nil
		end
		if input.KeyCode == Enum.KeyCode.Backquote then
			setHidden(function(current)
				return not current
			end)
		end
	end, {
		connected = not domainOverlayActive and not showRelease and not tutorialOpen,
	})
	local navigate = function(pageId)
		local entry = AppHelpers:pageEntry(pageId)
		if entry.disabled == true then
			Audio:play("locked")
			local _exp = `{entry.label} is closed`
			local _condition_5 = entry.disabledReason
			if _condition_5 == nil then
				_condition_5 = "Closed for now."
			end
			addNotice(_exp, _condition_5, "Info")
			return nil
		end
		local _exp = pageId
		local _result_3 = tutorial
		if _result_3 ~= nil then
			_result_3 = _result_3.page
		end
		if not AppHelpers:navUnlocked(state, _exp, _result_3) then
			local _lock = state.FeatureUnlocks
			if _lock ~= nil then
				_lock = _lock[pageId]
			end
			local lock = _lock
			Audio:play("locked")
			local _result_4 = lock
			if _result_4 ~= nil then
				_result_4 = _result_4.Name
			end
			local _condition_5 = _result_4
			if _condition_5 == nil then
				_condition_5 = pageId
			end
			local _exp_1 = `{_condition_5} is locked`
			local _result_5 = lock
			if _result_5 ~= nil then
				_result_5 = _result_5.Requirement
			end
			local _condition_6 = _result_5
			if _condition_6 == nil then
				_condition_6 = "Not unlocked yet."
			end
			local levelNeeded = if lock ~= nil and type(lock.Level) == "number" then lock.Level else nil
			if levelNeeded ~= nil then
				local currentLevel, _tier, nextStep = readLevelState(state)
				_exp_1 = `{_condition_5} opens at Level {levelNeeded}`
				_condition_6 = if nextStep ~= nil
					then `You're Level {currentLevel}. Next goal: {nextStep.Text} ({compactNumber(nextStep.Progress)}/{compactNumber(nextStep.Target)}). Tap the level bar to see every level.`
					else `You're Level {currentLevel}.`
			end
			if pageId == "Research" then
				_condition_6 ..= " Research bonuses stay after rebirth."
			end
			addNotice(_exp_1, _condition_6, "Info")
			return nil
		end
		Audio:setView(pageId)
		ClientLog:debug("nav", pageId)
		beginUiTransition(0.1)
		setPage(pageId)
		if drawerNav then
			setRailOpen(false)
		end
	end
	local navigationStateRef = React.useRef(state)
	navigationStateRef.current = state
	local _result_3 = tutorial
	if _result_3 ~= nil then
		_result_3 = _result_3.page
	end
	local tutorialPageRef = React.useRef(_result_3)
	local _result_4 = tutorial
	if _result_4 ~= nil then
		_result_4 = _result_4.page
	end
	tutorialPageRef.current = _result_4
	local navigateRef = React.useRef(navigate)
	navigateRef.current = navigate
	local navigateStable = useLatestCallback(function(pageId)
		notePage(pageId)
		return navigateRef.current(pageId)
	end)
	local openWorkshop = React.useCallback(function()
		return navigateRef.current("Workshop")
	end, {})
	local onWheelLand = React.useCallback(function()
		return celebrate()
	end, { celebrate })
	React.useEffect(function()
		if state.Flags.TutorialDone or tutorial == nil or tutorial.startPage == nil then
			return nil
		end
		setHidden(false)
		setPage(if AppHelpers:navUnlocked(state, tutorial.startPage, tutorial.page) then tutorial.startPage else "Overview")
	end, { state.Flags.TutorialDone, tutorial })
	React.useEffect(function()
		local _condition_5 = page ~= "Trade"
		if _condition_5 then
			local _result_5 = tutorial
			if _result_5 ~= nil then
				_result_5 = _result_5.page
			end
			_condition_5 = not AppHelpers:navUnlocked(state, page, _result_5)
		end
		if _condition_5 then
			setPage("Overview")
		end
	end, { page, state.FeatureUnlocks, tutorial })
	local tradeFocusKey = React.useRef("")
	local _exp = function()
		local _sessionId = state.Trade
		if _sessionId ~= nil then
			_sessionId = _sessionId.Session
			if _sessionId ~= nil then
				_sessionId = _sessionId.Id
			end
		end
		local sessionId = _sessionId
		local _invite = state.Trade
		if _invite ~= nil then
			_invite = _invite.Invite
		end
		local invite = _invite
		local key = if sessionId ~= nil then `session:{sessionId}` elseif invite ~= nil then `invite:{invite.FromUserId}:{invite.ExpiresAt}` else ""
		if key == "" then
			tradeFocusKey.current = ""
			return nil
		end
		local fresh = key ~= tradeFocusKey.current
		if fresh then
			tradeFocusKey.current = key
			Audio:play(if sessionId ~= nil then "confirm" else "invite")
			if sessionId ~= nil then
				setHidden(false)
				setPlayerlistOpen(false)
				setFeedbackOpen(false)
				if drawerNav then
					setRailOpen(false)
				end
				setPage("Trade")
			end
		end
	end
	local _result_5 = state.Trade
	if _result_5 ~= nil then
		_result_5 = _result_5.Invite
		if _result_5 ~= nil then
			_result_5 = _result_5.ExpiresAt
		end
	end
	local _result_6 = state.Trade
	if _result_6 ~= nil then
		_result_6 = _result_6.Invite
		if _result_6 ~= nil then
			_result_6 = _result_6.FromUserId
		end
	end
	local _result_7 = state.Trade
	if _result_7 ~= nil then
		_result_7 = _result_7.Session
		if _result_7 ~= nil then
			_result_7 = _result_7.Id
		end
	end
	React.useEffect(_exp, { drawerNav, _result_5, _result_6, _result_7 })
	local tradeAwaySent = React.useRef(false)
	local _exp_1 = function()
		local _result_8 = state.Trade
		if _result_8 ~= nil then
			_result_8 = _result_8.Session
		end
		local live = _result_8 ~= nil
		if not live then
			tradeAwaySent.current = false
			return nil
		end
		local away = page ~= "Trade"
		if away == tradeAwaySent.current then
			return nil
		end
		tradeAwaySent.current = away
		dispatch("TradeViewAway", {
			Away = away,
		})
	end
	local _result_8 = state.Trade
	if _result_8 ~= nil then
		_result_8 = _result_8.Session
		if _result_8 ~= nil then
			_result_8 = _result_8.Id
		end
	end
	React.useEffect(_exp_1, { dispatch, page, _result_8 })
	React.useEffect(function()
		local player = Players.LocalPlayer
		local unfocusedAt = -math.huge
		local focused = true
		local mark = function(away)
			player:SetAttribute("AF_Away", away)
			player:SetAttribute("AF_AwayAt", if away then os.clock() else 0)
		end
		mark(false)
		local lost = UserInputService.WindowFocusReleased:Connect(function()
			focused = false
			unfocusedAt = os.clock()
		end)
		local gained = UserInputService.WindowFocused:Connect(function()
			focused = true
			mark(false)
		end)
		local menuOpen = GuiService.MenuOpened:Connect(function()
			focused = false
			unfocusedAt = os.clock()
		end)
		local menuClose = GuiService.MenuClosed:Connect(function()
			focused = true
			mark(false)
		end)
		local pulse = task.spawn(function()
			while true do
				task.wait(1)
				if not focused and os.clock() - unfocusedAt >= 20 then
					mark(true)
				end
			end
		end)
		return function()
			lost:Disconnect()
			gained:Disconnect()
			menuOpen:Disconnect()
			menuClose:Disconnect()
			task.cancel(pulse)
			mark(false)
		end
	end, {})
	React.useEffect(function()
		GuiService.AutoSelectGuiEnabled = true
		GuiService.GuiNavigationEnabled = true
		local BUY_STEPS = { 1, 5, 10, 25, 0 }
		local cycleBuy = function(dir)
			local index = (table.find(BUY_STEPS, buyAmount) or 0) - 1
			local at = if index >= 0 then index else 0
			local stepped = BUY_STEPS[(at + dir + #BUY_STEPS) % #BUY_STEPS + 1]
			setBuyAmount(stepped)
			Audio:play("tick")
		end
		local actionName = "AstralForgeNavigation"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState, input)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if UserInputService:GetFocusedTextBox() ~= nil then
				return Enum.ContextActionResult.Pass
			end
			if arcadeBusy then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and page == "Credits" then
				navigateRef.current("Overview")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and playerlistOpen then
				setPlayerlistOpen(false)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and feedbackOpen then
				setFeedbackOpen(false)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and showRelease then
				dispatch("DismissRelease")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and tutorialOpen then
				if tutorialStep > 1 then
					dispatch("SetTutorialStep", {
						Step = tutorialStep - 1,
					})
				end
				return Enum.ContextActionResult.Sink
			end
			if crateReveal ~= nil or playerlistOpen or feedbackOpen or page == "Credits" or domainOverlayActive or showRelease or tutorialOpen then
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB then
				if hidden then
					setHidden(false)
				elseif railOpen then
					setRailOpen(false)
				else
					setRailOpen(true)
				end
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonY then
				Audio:play("vaultBank")
				dispatch("CollectVault")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonX then
				Audio:play("reactorPulse")
				dispatch("Overcharge")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonSelect then
				setHidden(function(current)
					return not current
				end)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonL2 then
				cycleBuy(-1)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				cycleBuy(1)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonStart then
				navigateRef.current("Settings")
				return Enum.ContextActionResult.Sink
			end
			local rail = AppHelpers:visibleNav(navigationStateRef.current, tutorialPageRef.current)
			if #rail == 0 then
				return Enum.ContextActionResult.Pass
			end
			local _callback = function(entry)
				return entry.id == page
			end
			local _result_9 = -1
			for _i, _v in rail do
				if _callback(_v, _i - 1, rail) == true then
					_result_9 = _i - 1
					break
				end
			end
			local index = math.max(0, _result_9)
			if input.KeyCode == Enum.KeyCode.ButtonL1 then
				navigateRef.current(rail[(index - 1 + #rail) % #rail + 1].id)
			elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
				navigateRef.current(rail[(index + 1) % #rail + 1].id)
			else
				return Enum.ContextActionResult.Pass
			end
			return Enum.ContextActionResult.Sink
		end, false, 2200, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonSelect, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonStart)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { arcadeBusy, buyAmount, crateReveal, dispatch, domainOverlayActive, feedbackOpen, hidden, page, playerlistOpen, railOpen, showRelease, tutorialOpen, tutorialStep })
	-- Keyboard: "/" opens chat ready to type, Tab shows or hides the player list. Roblox's own chat
	-- bar and player list are turned off, so both keys are free.
	local requestChatFocus = chat.requestFocus
	React.useEffect(function()
		local actionName = "AstralForgeKeyboard"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState, input)
			if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() ~= nil then
				return Enum.ContextActionResult.Pass
			end
			if crateReveal ~= nil or tutorialOpen or showRelease or domainOverlayActive then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.Slash then
				setPlayerlistOpen(false)
				navigateRef.current("Chat")
				if requestChatFocus ~= nil then
					requestChatFocus()
				end
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.Tab then
				setPlayerlistOpen(function(current)
					return not current
				end)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, 2100, Enum.KeyCode.Slash, Enum.KeyCode.Tab)
		return function()
			ContextActionService:UnbindAction(actionName)
		end
	end, { crateReveal, domainOverlayActive, requestChatFocus, showRelease, tutorialOpen })
	local gamepadActive, setGamepadActive = React.useState(false)
	React.useEffect(function()
		local isPad = function(inputType)
			return inputType == Enum.UserInputType.Gamepad1 or inputType == Enum.UserInputType.Gamepad2 or inputType == Enum.UserInputType.Gamepad3 or inputType == Enum.UserInputType.Gamepad4
		end
		local sync = function(inputType)
			return setGamepadActive(isPad(inputType))
		end
		sync(UserInputService:GetLastInputType())
		local connection = UserInputService.LastInputTypeChanged:Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	local sampledAntilag = useAntilag()
	local _condition_5 = state.Settings.PerformanceBias
	if _condition_5 == nil then
		_condition_5 = 0.5
	end
	local performanceBias = _condition_5
	local performanceTierCap = if performanceBias >= 0.88 then 1 elseif performanceBias >= 0.68 then 2 else 3
	local rootAntilag = React.useMemo(function()
		return clampAntilagTier(sampledAntilag, performanceTierCap)
	end, { performanceTierCap, sampledAntilag })
	local _condition_6 = state.Settings.BackgroundDetail
	if _condition_6 == nil then
		_condition_6 = 0.8
	end
	local backgroundDetail = _condition_6
	local _condition_7 = state.Settings.GlowIntensity
	if _condition_7 == nil then
		_condition_7 = 0.75
	end
	local glowIntensity = _condition_7
	local suppressBackground = backgroundDetail < 0.34 or not rootAntilag.allowAmbient
	local _condition_8 = state.Settings.ParticleDensity
	if _condition_8 == nil then
		_condition_8 = 0.75
	end
	local renderEffectsScale = effectsScale * _condition_8 * rootAntilag.fxBudget
	local _result_9
	if #pops > rootAntilag.maxPops then
		local _newValue = {}
		local _callback = function(_, index)
			return index >= #pops - rootAntilag.maxPops
		end
		local _length = 0
		for _k, _v in pops do
			if _callback(_v, _k - 1, pops) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		_result_9 = _newValue
	else
		_result_9 = pops
	end
	local visiblePops = _result_9
	local heavyPage = page == "Worlds" or page == "Anomaly" or page == "StarGrid"
	local quietPage = page == "Story" or page == "Chat" or page == "Mail" or page == "Credits" or page == "Leaderboards" or page == "Admin"
	local pageAntilag = React.useMemo(function()
		local _result_10
		if arcadeBusy then
			local _object = table.clone(rootAntilag)
			setmetatable(_object, nil)
			_object.allowConfetti = false
			_object.maxStars = 0
			_object.maxClocks = math.min(rootAntilag.maxClocks, 4)
			_result_10 = _object
		else
			local _result_11
			if heavyPage then
				local _object = table.clone(rootAntilag)
				setmetatable(_object, nil)
				_object.maxStars = 0
				_object.maxClocks = math.min(rootAntilag.maxClocks, if page == "Anomaly" then 8 else 4)
				_result_11 = _object
			else
				local _result_12
				if quietPage then
					local _object = table.clone(rootAntilag)
					setmetatable(_object, nil)
					_object.maxStars = math.min(rootAntilag.maxStars, 4)
					_result_12 = _object
				else
					_result_12 = rootAntilag
				end
				_result_11 = _result_12
			end
			_result_10 = _result_11
		end
		return _result_10
	end, { arcadeBusy, heavyPage, page, quietPage, rootAntilag })
	React.useEffect(function()
		local scene = if cinematicOpen then "cinematic" elseif arcadeBusy then "arcade" elseif heavyPage then "heavy" else "normal"
		setAntilagScene(scene)
		return function()
			return setAntilagScene("normal")
		end
	end, { arcadeBusy, cinematicOpen, heavyPage })
	React.useEffect(function()
		setClockBudget(pageAntilag.maxClocks)
	end, { pageAntilag.maxClocks })
	local _exp_2 = React.createElement("uigradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Palette.void), ColorSequenceKeypoint.new(0.5, Palette.graphite), ColorSequenceKeypoint.new(1, Palette.void) }),
		Rotation = 112,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = hideAmount:map(function(amount)
			return math.clamp(0.8 + amount, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	local _condition_9 = state.Settings.BackgroundStars
	if _condition_9 == nil then
		_condition_9 = 1
	end
	local _condition_10 = _condition_9 >= 0.5
	if _condition_10 then
		_condition_10 = backgroundDetail >= 0.2 and React.createElement(StarField, {
			accent = accent,
			reducedMotion = softMotion or heavyPage or quietPage or arcadeBusy or backgroundDetail < 0.58,
		})
	end
	local _condition_11 = state.Settings.AmbientGlow
	if _condition_11 == nil then
		_condition_11 = 1
	end
	local _condition_12 = _condition_11 >= 0.5
	if _condition_12 then
		_condition_12 = not suppressBackground and React.createElement(AmbientLayer, {
			accent = accent,
			reducedMotion = softMotion or heavyPage or quietPage or arcadeBusy,
			intensity = glowIntensity,
		})
	end
	local _condition_13 = state.Settings.AmbientGlow
	if _condition_13 == nil then
		_condition_13 = 1
	end
	local _condition_14 = _condition_13 >= 0.5
	if _condition_14 then
		_condition_14 = glowIntensity > 0.02 and backgroundDetail >= 0.45 and React.createElement("frame", {
			Size = UDim2.fromOffset(620, 620),
			Position = UDim2.new(1, 170, 1, 90),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = 1 - 0.035 * math.clamp(glowIntensity, 0, 1),
			BorderSizePixel = 0,
			Rotation = -12,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	local _condition_15 = state.Settings.AmbientGlow
	if _condition_15 == nil then
		_condition_15 = 1
	end
	local _condition_16 = _condition_15 >= 0.5
	if _condition_16 then
		_condition_16 = glowIntensity > 0.02 and backgroundDetail >= 0.7 and React.createElement("frame", {
			Size = UDim2.fromOffset(420, 420),
			Position = UDim2.new(0, -170, 0, -130),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cyan,
			BackgroundTransparency = 1 - 0.025 * math.clamp(glowIntensity, 0, 1),
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	local _exp_4 = not keyboardShellCompact and mobileShell and React.createElement(MobileHeader, {
		state = state,
		page = page,
		accent = accent,
		width = viewport.width,
		topPad = topPad,
		barHeight = topbarHeight,
		edgePad = edgePad,
		reducedMotion = softMotion,
		openPlayerlist = function()
			setFeedbackOpen(false)
			setPlayerlistOpen(true)
		end,
	})
	local _condition_17 = not keyboardShellCompact and not mobileShell
	if _condition_17 then
		local _attributes = {
			state = state,
			page = page,
			railOpen = railOpen,
			toggleRail = function()
				setRailOpen(not railOpen)
			end,
			hideUI = function()
				return setHidden(true)
			end,
			tight = viewport.tight,
			width = viewport.width,
			topPad = topPad,
			barHeight = topbarHeight,
			barHeightMotion = topbarLive,
			edgePad = edgePad,
			reducedMotion = softMotion,
		}
		local _condition_18 = config.Release.CountdownAt
		if _condition_18 == nil then
			_condition_18 = 1789272000
		end
		_attributes.releaseAt = _condition_18
		_attributes.visit = visit
		_attributes.openPlayerlist = function()
			setFeedbackOpen(false)
			setPlayerlistOpen(true)
		end
		_attributes.openFeedback = function()
			setPlayerlistOpen(false)
			setFeedbackOpen(true)
		end
		_condition_17 = React.createElement(TopBar, _attributes)
	end
	local _condition_18 = false
	local _exp_5 = React.createElement(React.Fragment, nil, _condition_10, _condition_12, _condition_14, _condition_16, _exp_4, _condition_17, _condition_18)
	local _exp_6 = React.createElement("frame", {
		Size = workspaceSize,
		Position = workspaceOffset,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement(AntilagContext.Provider, {
		value = pageAntilag,
	}, React.createElement(Workspace, {
		page = page,
		state = state,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
	}, React.createElement(PageFrame, {
		page = page,
		ref = pageHostRef,
	}, React.createElement(PageContent, {
		key = page,
		page = page,
		state = state,
		config = config,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		domainOverlayActive = domainOverlayActive,
		openWorkshop = openWorkshop,
		openDomain = openDomain,
		buyAmount = buyAmount,
		setBuyAmount = setBuyAmount,
		onWheelLand = onWheelLand,
		wallClock = wallClock,
		activeBoostExpired = activeBoostExpired,
		clearConfetti = clearConfetti,
		chat = chat,
		visit = visit,
		setVisit = setVisit,
		addNotice = addNotice,
		crateRevealActive = crateReveal ~= nil,
		setCrateReveal = setCrateReveal,
		navigate = navigateStable,
		setArcadeBusy = setArcadeBusy,
		setPurchasePresentationActive = setPurchasePresentationActive,
	})))))
	local _exp_7 = not mobileShell and drawerNav and React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = drawerScrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Active = drawerScrimVisible,
		Visible = drawerScrimVisible,
		ZIndex = 28,
		Event = {
			Activated = function()
				setRailOpen(false)
				Audio:play("close")
			end,
		},
	})
	local _condition_19 = not mobileShell
	if _condition_19 then
		local _attributes = {
			page = page,
			setPage = navigate,
			collapsed = not drawerNav and viewport.compact,
			width = railWidth,
			fixedWidth = if drawerNav then drawerWidth else nil,
			reducedMotion = softMotion,
			state = state,
			chatUnread = chat.unread,
		}
		local _result_10 = tutorial
		if _result_10 ~= nil then
			_result_10 = _result_10.page
		end
		_attributes.tutorialPage = _result_10
		_attributes.includeSecondary = true
		_attributes.fromMore = false
		_attributes.activeBoost = activeBoost
		_attributes.activeBoostEndsAt = activeBoostEndsAt
		_attributes.wallClock = wallClock
		_attributes.openBoosts = function()
			return navigate("Rewards")
		end
		_condition_19 = React.createElement("frame", {
			Size = if drawerNav then UDim2.new(0, drawerWidth, 1, 0) else railWidth:map(function(width)
				return UDim2.new(0, math.max(0, width), 1, 0)
			end),
			Position = if drawerNav then drawerProgress:map(function(amount)
				return UDim2.new(0, -drawerWidth * (1 - amount), 0, 0)
			end) else nil,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = if drawerNav then 30 else 10,
			ClipsDescendants = true,
			Visible = if drawerNav then drawerScrimVisible else drawerPanelVisible,
		}, React.createElement(Navigation, _attributes))
	end
	local gamepadReserve = if gamepadActive then 44 else 0
	local _exp_8 = React.createElement("frame", {
		Size = shellTopLive:map(function(top)
			return UDim2.new(1, -edgePad * 2, 1, -(top + bottomPad + gamepadReserve))
		end),
		Position = shellTopLive:map(function(top)
			return UDim2.fromOffset(edgePad, top)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_6, _exp_7, _condition_19)
	local _result_10 = state.Trade
	if _result_10 ~= nil then
		_result_10 = _result_10.Session
	end
	local _condition_20 = _result_10 ~= nil
	if _condition_20 then
		_condition_20 = page ~= "Trade" and React.createElement(TradeReturnPill, {
			stack = chrome.stack,
			bottomPad = bottomPad,
			reducedMotion = softMotion,
			onReturn = function()
				setHidden(false)
				setRailOpen(false)
				navigate("Trade")
			end,
		})
	end
	local _condition_21 = mobileShell
	if _condition_21 then
		local _attributes = {
			page = page,
			setPage = navigate,
			state = state,
			chatUnread = chat.unread,
		}
		local _result_11 = tutorial
		if _result_11 ~= nil then
			_result_11 = _result_11.page
		end
		_attributes.tutorialPage = _result_11
		_attributes.reducedMotion = reducedMotion
		_attributes.height = tabBarH
		_attributes.bottomSafe = chrome.bottomSafe
		_attributes.visible = not keyboardShellCompact
		_attributes.viewportHeight = viewport.height
		_attributes.moreCols = chrome.moreCols
		_attributes.moreCellH = chrome.moreCellH
		_condition_21 = React.createElement(MobileTabBar, _attributes)
	end
	local _exp_9 = mobileShell and quickActionsVisible and React.createElement(MobileQuickActions, {
		state = state,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		bottomOffset = quickBottomOffset,
		edgePad = edgePad,
	})
	local _exp_10 = not hidden and React.createElement(ComboBadge, {
		readout = comboReadout,
		reducedMotion = reducedMotion,
		position = UDim2.new(1, -18, 0, topPad + topbarHeight + 8),
		anchorPoint = Vector2.new(1, 0),
		zIndex = 65,
	})
	local _exp_11 = renderEffectsScale > 0.05 and React.createElement(EffectLayer, {
		pops = visiblePops,
	})
	local _condition_22 = confettiNonce > 0
	if _condition_22 then
		local _attributes = {
			key = confettiNonce,
			seed = confettiNonce,
			intensity = math.max(0.08, renderEffectsScale),
			reducedMotion = softMotion,
		}
		local _condition_23 = state.Settings.ConfettiEnabled
		if _condition_23 == nil then
			_condition_23 = 1
		end
		_attributes.particlesEnabled = _condition_23 >= 0.5
		_attributes.onDone = clearConfetti
		_condition_22 = React.createElement(CelebrationBurst, _attributes)
	end
	local _exp_12 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = hideAmount:map(function(amount)
			local base = UDim2.new(0, 0, amount * 1.05, 0)
			return base
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_5, _exp_8, React.createElement(React.Fragment, nil, _condition_20, _condition_21, _exp_9, _exp_10, _exp_11, _condition_22), React.createElement(require(script.Parent.QuickFind).QuickFind, {
		state = state,
		dispatch = dispatch,
		navigate = navigateStable,
		chatUnread = chat.unread,
		reducedMotion = reducedMotion,
		enabled = not hidden and not tutorialOpen and not domainOverlayActive and not showRelease,
	}))
	local _exp_13 = React.createElement("frame", {
		Size = UDim2.fromOffset(186, 44),
		Position = hideAmount:map(function(amount)
			return UDim2.new(0, edgePad, 0, -64 + math.floor(amount * (topPad + 64)))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 200,
	}, React.createElement(Button, {
		text = "SHOW UI  ( ` )",
		icon = "Hide",
		onClick = function()
			return setHidden(false)
		end,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))
	local ownedMachines = 0
	local machineTable = state.Machines
	if type(machineTable) == "table" then
		for _, level in machineTable do
			local amount = level
			if type(amount) == "table" then
				amount = amount.Level or amount.level or 0
			end
			if type(amount) == "number" and amount > 0 then
				ownedMachines += 1
			end
		end
	end
	local _exp_14 = not state.Flags.TutorialDone and tutorial ~= nil and React.createElement(TutorialOverlay, {
		copy = tutorial,
		step = tutorialStep,
		count = #TUTORIAL_STEPS,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		reducedMotion = reducedMotion,
		live = {
			page = page,
			vault = compactNumber(state.Vault),
			vaultFlux = asFlux(state.Vault),
			production = compactNumber(state.Production),
			ownedMachines = ownedMachines,
			buyAmount = buyAmount,
		},
		ctaLabel = tutorial.ctaLabel,
		onCta = if tutorial.cta == "collect" then function()
			return dispatch("CollectVault")
		end elseif tutorial.cta == "workshop" then function()
			return navigate("Workshop")
		end elseif tutorial.cta == "research" then function()
			return navigate("Research")
		end else nil,
		onJump = function(n)
			local targetStep = math.clamp(math.floor(n), 1, #TUTORIAL_STEPS)
			tutorialHold.current = targetStep
			setTutorialStep(targetStep)
			dispatch("SetTutorialStep", {
				Step = targetStep,
			})
		end,
		onBack = function()
			local targetStep = math.max(1, tutorialStep - 1)
			Audio:play("stepBack")
			tutorialHold.current = targetStep
			setTutorialStep(targetStep)
			dispatch("SetTutorialStep", {
				Step = targetStep,
			})
		end,
		onNext = function()
			if tutorialStep >= #TUTORIAL_STEPS then
				dispatch("CompleteTutorial")
			else
				local targetStep = tutorialStep + 1
				Audio:play("stepNext")
				tutorialHold.current = targetStep
				setTutorialStep(targetStep)
				dispatch("SetTutorialStep", {
					Step = targetStep,
				})
			end
		end,
		onSkip = function()
			return dispatch("CompleteTutorial")
		end,
	})
	local _condition_23 = gamepadActive and not hidden and not tutorialOpen
	if _condition_23 then
		local _exp_15 = require(script.Parent.CoreKit)("GamepadNavigationService").GetHintLabels()
		local _newValue = table.create(#_exp_15)
		local _callback = function(hint, index)
			return React.createElement(FlexItem, {
				key = hint,
				mode = "grow",
				minWidth = 88,
				minHeight = 22,
				layoutOrder = index,
			}, React.createElement(Text, {
				value = hint,
				size = 11,
				color = Palette.creamSoft,
				align = Enum.TextXAlignment.Center,
				fit = true,
				minSize = 9,
				sizeConstraint = UDim2.fromScale(1, 1),
			}))
		end
		for _k, _v in _exp_15 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_15)
		end
		_condition_23 = React.createElement("frame", {
			Size = UDim2.new(1, -edgePad * 2, 0, 36),
			Position = UDim2.new(0, edgePad, 1, -(bottomPad + 36)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 180,
		}, React.createElement(Flex, {
			direction = "row",
			wrap = true,
			justify = "space-evenly",
			align = "center",
			gap = 10,
			size = UDim2.fromScale(1, 1),
			exact = true,
		}, _newValue))
	end
	local _exp_15 = showRelease and React.createElement(ReleaseNotesModal, {
		version = config.Game.Version,
		season = config.Release.Season,
		announcement = config.Release.Announcement,
		notes = config.Release.Notes,
		history = config.Release.History,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		reducedMotion = reducedMotion,
		onClose = function()
			setReleaseClosedLocally(true)
			dispatch("DismissRelease")
		end,
		onOpenMail = function()
			Audio:play("mail")
			setReleaseClosedLocally(true)
			dispatch("DismissRelease")
			setPage("Mail")
		end,
	})
	local _exp_16 = page == "Credits" and React.createElement(CreditsOverlay, {
		version = state.Game.Version,
		reducedMotion = reducedMotion,
		onClose = function()
			return navigate("Overview")
		end,
	})
	local _exp_17 = playerlistOpen and React.createElement(PlayerlistOverlay, {
		state = state,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		onClose = function()
			return setPlayerlistOpen(false)
		end,
		-- MESSAGE on a player card lands in Chat on a private thread with them
		onMessage = function(userId)
			setPlayerlistOpen(false)
			navigate("Chat")
			chat.openWhisper(userId)
		end,
		notify = function(title, body)
			return addNotice(title, body, "Info")
		end,
	})
	local _exp_18 = feedbackOpen and React.createElement(FeedbackOverlay, {
		dispatch = dispatch,
		page = if type(page) == "string" then page else nil,
		reducedMotion = reducedMotion,
		onClose = function()
			return setFeedbackOpen(false)
		end,
		notify = function(title, body)
			return addNotice(title, body, "Info")
		end,
	})
	local _condition_24 = offlineRewardsOpen and React.createElement(
		OfflineRewardsOverlay,
		offlineRewardsProps(state, reducedMotion, dispatch, function()
			return setDismissedOfflineKey(offlineReceiptKey)
		end)
	)
	return React.createElement(AntilagContext.Provider, {
		value = rootAntilag,
	}, React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = hideAmount,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = crateReveal == nil,
	}, _exp_2, _exp_3, _exp_12, _exp_13, _exp_14, _condition_23, _exp_15, _exp_16, _exp_17, _exp_18, React.createElement(LevelRoadmapHost, {
		state = state,
		config = config,
		reducedMotion = reducedMotion,
	}), React.createElement(LevelMomentHost, {
		state = state,
	}), React.createElement(ServerEventHost, {
		state = state,
		inTopBar = not keyboardShellCompact and not mobileShell,
	}), _condition_24), crateReveal ~= nil and React.createElement(CrateRevealOverlay, {
		session = crateReveal,
		config = config,
		skin = if state ~= nil and state.Cosmetics ~= nil then state.Cosmetics.CrateSkin else nil,
		reducedMotion = reducedMotion,
		onClose = function()
			return setCrateReveal(nil)
		end,
	}), React.createElement(RebirthCeremonyHost, {
		reducedMotion = reducedMotion,
	})))
end
local function Shell(props)
	local _attributes = table.clone(props)
	setmetatable(_attributes, nil)
	return React.createElement(AppShell, _attributes)
end

return {
	AppShell = AppShell,
	Shell = Shell,
	pausePassivePaints = pausePassivePaints,
}
end

__defs["TopBarChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _antilag = require(script.Parent.MotionKit)("antilag")
local usePerformanceTelemetry = _antilag.usePerformanceTelemetry
local _motion = require(script.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local useGlowStroke = _motion.useGlowStroke
local usePulse = _motion.usePulse
local _ui = __load("ui")
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local IconTile = _ui.IconTile
local LogoLockup = _ui.LogoLockup
local Text = _ui.Text
local resolvePressMotion = _ui.resolvePressMotion
local useButtonChrome = _ui.useButtonChrome
local NumberSpinnerHost = require(script.Parent.ReactHosts)("NumberSpinnerHost").NumberSpinnerHost
local _theme = require(script.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local surfaceGradient = _theme.surfaceGradient
local strokeGradient = _theme.strokeGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local AppHelpers = require(script.Parent.CoreKit)("appNav").AppHelpers
local BoostIconKind = require(script.Parent.CoreKit)("boostIconKind")
local ReleaseClockMath = require(script.Parent.CoreKit)("releaseClockMath")
local Audio = require(script.Parent.AudioKit)("audio").Audio

local CHIP_TIPS = {
	FLUX = {
		title = "Flux",
		body = "Spendable cash from your vault. Bank production, then buy machines and research.",
	},
	DUST = {
		title = "Stardust",
		body = "Earn Stardust from rebirths and rewards. Spend it on artifacts and supplies in the Shop.",
	},
	CORES = {
		title = "Astral cores",
		body = "Permanent rebirth currency. Multiplies future runs and unlocks prestige tech.",
	},
}

local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}

local function StatChip(_param)
	local label = _param.label
	local value = _param.value
	local icon = _param.icon
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local velocity = _param.velocity
	if velocity == nil then
		velocity = 0
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local tall = _param.tall
	if tall == nil then
		tall = false
	end
	local reactiveFlash = _param.reactiveFlash
	if reactiveFlash == nil then
		reactiveFlash = true
	end
	local placeholder = _param.placeholder
	local showLabel = _param.showLabel
	if showLabel == nil then
		showLabel = true
	end
	local animateValue = _param.animateValue
	if animateValue == nil then
		animateValue = true
	end
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local gains, setGains = React.useState(0)
	local previous = React.useRef(value)
	React.useEffect(function()
		local nextFlux = asFlux(value)
		local prevFlux = asFlux(previous.current)
		if nextFlux == prevFlux then
			return nil
		end
		if reactiveFlash and nextFlux > prevFlux then
			setGains(function(current)
				return current + 1
			end)
		end
		previous.current = value
	end, { value, reactiveFlash })
	local flash = useFlash(gains, reducedMotion)
	local chipH = if tall then TapTarget else 44
	local iconSize = if tall then 28 else 24
	local valueSize = if tall then 15 else 14
	local _ = CHIP_TIPS[label]
	-- room for long scale names ("37.3 Googolchime"); FPS/ping only ever show a few digits
	local valueMaxW = if _param.narrow then 40 elseif tall then 108 else 116
	local chipInnerW = iconSize + 6 + valueMaxW + (if tall then 20 else 18)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = flash:map(function(amount)
			return Palette.lineSoft:Lerp(accent, amount)
		end),
		Thickness = 1,
		Transparency = flash:map(function(amount)
			return 0.56 - amount * 0.5
		end),
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = flash:map(function(amount)
			return strokeGradient(Palette.lineSoft:Lerp(accent, amount))
		end),
	}))
	local _exp_3 = React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, if tall then 10 else 9),
		PaddingRight = UDim.new(0, if tall then 12 else 11),
		PaddingTop = UDim.new(0, if tall then 6 else 8),
		PaddingBottom = UDim.new(0, if tall then 6 else 8),
	})
	local _exp_4 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = true,
	}, React.createElement(IconTile, {
		kind = icon,
		accent = accent,
		size = iconSize,
		radius = 99,
	}))
	local _exp_6 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 0),
	})
	local _exp_7 = showLabel and React.createElement("textlabel", {
		Size = UDim2.fromOffset(valueMaxW, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = ensureContrast(Palette.panel, accent),
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
	})
	local _result
	if placeholder ~= nil or not animateValue or type(value) == "string" then
		local _attributes = {
			Size = UDim2.fromOffset(valueMaxW, 20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextScaled = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}
		local _condition = placeholder
		if _condition == nil then
			_condition = compactNumber(value)
		end
		_attributes.Text = _condition
		_attributes.TextColor3 = ensureContrast(Palette.panel, Palette.cream)
		_attributes.TextSize = valueSize
		_attributes.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		_attributes.TextXAlignment = Enum.TextXAlignment.Left
		_attributes.TextYAlignment = Enum.TextYAlignment.Center
		_attributes.LayoutOrder = 2
		_result = React.createElement("textlabel", _attributes, React.createElement("uitextsizeconstraint", {
			MinTextSize = 10,
			MaxTextSize = valueSize,
		}))
	else
		_result = React.createElement(NumberSpinnerHost, {
			value = value,
			velocity = asFlux(velocity),
			reducedMotion = reducedMotion,
			duration = 0.32,
			size = valueSize,
			color = ensureContrast(Palette.panel, Palette.cream),
			autoWidth = false,
			spacedSuffix = true,
			sizeConstraint = UDim2.fromOffset(valueMaxW, 20),
			layoutOrder = 2,
			zIndex = 3,
		})
	end
	local chip = React.createElement("frame", {
		Size = UDim2.fromOffset(chipInnerW, chipH),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, React.createElement("frame", {
		Size = UDim2.fromOffset(valueMaxW, 34),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = true,
	}, _exp_6, _exp_7, _result))
	return React.createElement("frame", {
		Size = UDim2.fromOffset(chipInnerW + 4, chipH + 2),
		AutomaticSize = Enum.AutomaticSize.None,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
		ClipsDescendants = false,
		Name = label,
	}, React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
	}), chip)
end
local function ServerEventChip(_param)
	local events = __load("serverEventsUi")
	local event = events.useServerEvent(_param.state.ServerEvent)
	local now, setNow = React.useState(function()
		return workspace:GetServerTimeNow()
	end)
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				local t = workspace:GetServerTimeNow()
				task.wait(1 - (t % 1) + 0.02)
				if alive then
					setNow(workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})
	if event == nil then
		return nil
	end
	local def = events.EVENTS[event.Id or ""]
	local active = def ~= nil and event.Phase ~= "Rest"
	local left = events.clockText((event.PhaseEndsAt or now) - now)
	local value = if not active then left
		elseif event.Phase == "Warning" then `in {left}`
		elseif event.Phase == "Live" then `{left} left`
		elseif event.Completed then "Goal!"
		else "Done"
	return React.createElement("textbutton", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = _param.layoutOrder,
		ZIndex = 22,
		Event = {
			Activated = events.openServerEventPanel,
		},
	}, React.createElement(StatChip, {
		label = if active then string.upper(def.Name) else "NEXT EVENT",
		value = 0,
		placeholder = value,
		icon = if active then def.Icon else "Calendar",
		accent = if active then events.accentOf(def) else Palette.blue,
		reducedMotion = _param.reducedMotion,
		reactiveFlash = false,
		animateValue = false,
		tall = _param.tall,
		showLabel = true,
	}))
end
local function PerformanceStats(_param)
	local tall = _param.tall
	if tall == nil then
		tall = false
	end
	local reducedMotion = _param.reducedMotion
	local showFps = _param.showFps
	if showFps == nil then
		showFps = true
	end
	local showPing = _param.showPing
	if showPing == nil then
		showPing = true
	end
	local telemetry = usePerformanceTelemetry()
	local fps = math.max(0, math.floor(telemetry.fps + 0.5))
	local ping = if telemetry.pingMs ~= nil then math.max(0, math.floor(telemetry.pingMs + 0.5)) else nil
	local fpsAccent = if fps >= 54 then Palette.mint elseif fps >= 38 then Palette.mango else Palette.coral
	local pingAccent = if ping == nil then Palette.muted elseif ping <= 85 then Palette.mint elseif ping <= 165 then Palette.mango else Palette.coral
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	})
	local _exp_1 = showFps and React.createElement(StatChip, {
		label = "FPS",
		value = fps,
		icon = "Timer",
		accent = fpsAccent,
		reducedMotion = reducedMotion,
		reactiveFlash = false,
		animateValue = false,
		placeholder = `{fps}`,
		tall = tall,
		narrow = true,
		layoutOrder = 1,
	})
	local _condition = showPing
	if _condition then
		local _attributes = {
			label = "PING",
		}
		local _condition_1 = ping
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_attributes.value = _condition_1
		_attributes.icon = "Wave"
		_attributes.accent = pingAccent
		_attributes.reducedMotion = reducedMotion
		_attributes.reactiveFlash = false
		_attributes.animateValue = false
		_attributes.placeholder = if ping == nil then "—" else `{ping}`
		_attributes.tall = tall
		_attributes.narrow = true
		_attributes.layoutOrder = 2
		_condition = React.createElement(StatChip, _attributes)
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(0, if tall then TapTarget else 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _condition)
end
local boostIconKind = BoostIconKind.of
local function ActiveBoostIcon(_param)
	local boost = _param.boost
	local endsAt = _param.endsAt
	local now = _param.now
	local open = _param.open
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local remaining = now:map(function(timestamp)
		return clockText(math.max(0, endsAt - timestamp))
	end)
	local fraction = now:map(function(timestamp)
		return math.clamp((endsAt - timestamp) / math.max(1, boost.Duration), 0, 1)
	end)
	local chrome = useButtonChrome(open, reducedMotion, false, "boostOpen", true, false, resolvePressMotion(if compact then {
		icon = boost.Id,
		size = UDim2.fromOffset(62, 62),
	} else {
		text = boost.Name,
		size = UDim2.fromOffset(220, 56),
	}))
	local reveal = useEntrance(reducedMotion)
	local radius = if compact then 11 else 12
	local visualScale = React.joinBindings({
		press = chrome.touchScale,
		reveal = reveal,
	}):map(function(_param_1)
		local press = _param_1.press
		local amount = _param_1.reveal
		return press * (0.94 + math.clamp(amount, 0, 1) * 0.06)
	end)
	local visualPosition = React.joinBindings({
		offset = chrome.offsetY,
		reveal = reveal,
	}):map(function(_param_1)
		local offset = _param_1.offset
		local amount = _param_1.reveal
		return UDim2.new(0.5, 0, 0.5, math.round(offset + (1 - math.clamp(amount, 0, 1)) * 6))
	end)
	local hoverFill = chrome.hoverAmount:map(function(amount)
		return Palette.panelRaised:Lerp(darken(boost.Color, 0.72), math.clamp(amount, 0, 1) * 0.24)
	end)
	local runningLow, setRunningLow = React.useState(function()
		return endsAt - workspace:GetServerTimeNow() <= boost.Duration * 0.15
	end)
	React.useEffect(function()
		local threshold = boost.Duration * 0.15
		local remainingSeconds = endsAt - workspace:GetServerTimeNow()
		local shouldRunLow = remainingSeconds <= threshold
		setRunningLow(shouldRunLow)
		if shouldRunLow then
			return nil
		end
		local timer = task.delay(math.max(0, remainingSeconds - threshold), function()
			return setRunningLow(true)
		end)
		return function()
			return task.cancel(timer)
		end
	end, { boost.Duration, endsAt })
	local urgentStroke = useGlowStroke(runningLow, reducedMotion, 0.5, 0.15, 0.65, 2.4)
	local strokeTransparency = React.joinBindings({
		hover = chrome.hoverAmount,
		glow = urgentStroke,
	}):map(function(_param_1)
		local hover = _param_1.hover
		local glow = _param_1.glow
		return math.min(0.5 - hover * 0.22, glow)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = visualPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = chrome.tilt,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = visualScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundColor3 = hoverFill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.5),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 3 else 4, if compact then 34 else 38),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = boost.Color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = chrome.hoverAmount:map(function(amount)
			return 1 - amount * 0.1
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		live = chrome.shimmerLive,
		idle = true,
		zIndex = 2,
		radius = radius,
	}), React.createElement(IconTile, {
		kind = boostIconKind(boost.Id),
		accent = boost.Color,
		size = if compact then 34 else 40,
		radius = if compact then 9 else 10,
		position = if compact then UDim2.new(0.5, -17, 0, 4) else UDim2.fromOffset(9, 8),
		spin = chrome.hovered,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
		zIndex = 3,
	}), if compact then React.createElement(Text, {
		value = remaining,
		size = 10,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 5, 1, -19),
		sizeConstraint = UDim2.new(1, -10, 0, 13),
		zIndex = 4,
	}) else React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "ACTIVE BOOST",
		size = 9,
		color = boost.Color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, -128, 0, 13),
		zIndex = 4,
	}), React.createElement(Text, {
		value = boost.Name,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(60, 20),
		sizeConstraint = UDim2.new(1, -128, 0, 18),
		zIndex = 4,
	}), React.createElement(Text, {
		value = remaining,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 10,
		position = UDim2.new(1, -64, 0, 18),
		sizeConstraint = UDim2.fromOffset(54, 18),
		zIndex = 4,
	}), React.createElement(Text, {
		value = AppHelpers:boostEffectText(boost),
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(60, 38),
		sizeConstraint = UDim2.new(1, -72, 0, 13),
		zIndex = 4,
	})), React.createElement("frame", {
		Size = if compact then UDim2.new(1, -12, 0, 3) else UDim2.new(1, -69, 0, 3),
		Position = if compact then UDim2.new(0, 6, 1, -6) else UDim2.new(0, 60, 1, -7),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fraction:map(function(amount)
			return UDim2.new(amount, 0, 1, 0)
		end),
		BackgroundColor3 = boost.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = boost.Color,
		Thickness = 1,
		Transparency = strokeTransparency,
	})))))
end
local function TopbarReleaseCountdown(_param)
	local releaseAt = _param.releaseAt
	local width = _param.width
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local Workspace = game:GetService("Workspace")
	local function syncedNow()
		local ok, value = pcall(function()
			return Workspace:GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return math.floor(value)
		end
		return os.time()
	end
	local now, setNow = React.useState(syncedNow())
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.5)
				if alive then
					setNow(syncedNow())
				end
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, {})
	local remaining = ReleaseClockMath.Remaining(releaseAt, now)
	local live = ReleaseClockMath.IsLive(releaseAt, now)
	local slam, setSlam = React.useState(0)
	local wasLive = React.useRef(live)
	React.useEffect(function()
		if live and not wasLive.current then
			wasLive.current = true
			setSlam(function(n)
				return n + 1
			end)
			if not reducedMotion then
				Audio:play("prestige")
				Audio:play("bootFinaleBang")
			end
		end
		if not live then
			wasLive.current = false
		end
	end, { live, reducedMotion })
	local pulse = usePulse(live, 2.4)
	local flash = useFlash(slam, reducedMotion, 1.05)
	local days = math.floor(remaining / 86400)
	local hours = math.floor(remaining / 3600) % 24
	local minutes = math.floor(remaining / 60) % 60
	local seconds = remaining % 60
	local pair = function(value)
		return if value < 10 then `0{value}` else tostring(value)
	end
	local values = if live then { {
		value = "LIVE",
		unit = "NOW",
		color = Palette.mint,
	} } else { {
		value = tostring(days),
		unit = "DAYS",
		color = Palette.cyan,
	}, {
		value = pair(hours),
		unit = "HRS",
		color = Palette.violet,
	}, {
		value = pair(minutes),
		unit = "MIN",
		color = Palette.pink,
	}, {
		value = pair(seconds),
		unit = "SEC",
		color = Palette.mango,
	} }
	local labelW = if live then (if width >= 360 then 96 else 82) elseif width >= 360 then 104 else 88
	local strokeColor = if live then Palette.mint else Palette.cyan
	local strokeTransparency = if live then pulse:map(function(amount)
		return 0.08 + (1 - amount) * 0.38
	end) else 0.5
	local fillWash = if live then pulse:map(function(amount)
		return 0.82 - amount * 0.28
	end) else 1
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = strokeColor,
		Thickness = if live then 1.6 else 1,
		Transparency = strokeTransparency,
	})
	local _exp_2 = live and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mint,
		BackgroundTransparency = fillWash,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}))
	local _condition = nil
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(9, 11),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Icon, {
		kind = "Calendar",
		color = Palette.cream,
		accent = if live then Palette.mint else Palette.cyan,
		size = 26,
		spin = live,
	}))
	local _exp_4 = React.createElement(Text, {
		value = if live then "LAUNCH" else "NEXT",
		size = 10,
		color = if live then Palette.mint else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(40, 7),
		sizeConstraint = UDim2.fromOffset(labelW - 42, 14),
		zIndex = 3,
	})
	local _exp_5 = React.createElement(Text, {
		value = if live then "LIVE" else "UPDATE",
		size = 10,
		minSize = 8,
		color = if live then Palette.cream else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(40, 23),
		sizeConstraint = UDim2.fromOffset(labelW - 42, 15),
		zIndex = 3,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0, 1, 1, -16),
		Position = UDim2.fromOffset(labelW, 8),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.36,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	local _exp_7 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local _newValue = table.create(#values)
	local _callback = function(entry, index)
		return React.createElement("frame", {
			key = entry.unit,
			Size = UDim2.new(1 / #values, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, index > 0 and React.createElement("frame", {
			Size = UDim2.fromOffset(1, 22),
			Position = UDim2.new(0, 0, 0.5, -11),
			BackgroundColor3 = Palette.lineSoft,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, -4, 0, 21),
			Position = UDim2.fromOffset(2, 3),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = entry.value,
			TextColor3 = entry.color,
			TextSize = if live then 15 else 14,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 4,
		}), React.createElement(Text, {
			value = entry.unit,
			size = 10,
			minSize = 9,
			color = if live then Palette.mint else Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(2, 25),
			sizeConstraint = UDim2.new(1, -4, 0, 11),
			zIndex = 3,
		}))
	end
	for _k, _v in values do
		_newValue[_k] = _callback(_v, _k - 1, values)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _condition, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.new(1, -(labelW + 7), 1, -6),
		Position = UDim2.fromOffset(labelW + 5, 3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _exp_7, _newValue))
end
local function TopBar(_param)
	local state = _param.state
	local page = _param.page
	local railOpen = _param.railOpen
	local toggleRail = _param.toggleRail
	local hideUI = _param.hideUI
	local tight = _param.tight
	local width = _param.width
	local topPad = _param.topPad
	local barHeight = _param.barHeight
	local barHeightMotion = _param.barHeightMotion
	local edgePad = _param.edgePad
	local reducedMotion = _param.reducedMotion
	local releaseAt = _param.releaseAt
	local visit = _param.visit
	local openPlayerlist = _param.openPlayerlist
	local openFeedback = _param.openFeedback
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local accent = AppHelpers:pageAccent(page)
	local shortRow = barHeight <= 54 and width < 980
	local micro = barHeight <= 54 and width < 620
	local stacked = barHeight > Layout.topbarHeight
	local chipWidthEstimate = if stacked then 172 elseif micro then 172 else 170
	local logoCompact = tight or stacked or barHeight <= Layout.topbarHeight
	local logoWidth = if micro then 48 elseif stacked then 156 elseif shortRow then 156 elseif logoCompact then 168 else 176
	local pageTitleW = 0
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	local visitPill = if not stacked and visit ~= nil then {
		label = `AT {string.upper(visit.DisplayName)}`,
		accent = Palette.blue,
	} elseif not stacked and visitorsHere > 0 then {
		label = if visitorsHere == 1 then "1 VISITOR" else `{visitorsHere} VISITORS`,
		accent = Palette.mango,
	} else nil
	local allChips = {}
	if state.ServerEvent ~= nil then
		table.insert(allChips, { label = "EVENT", event = true })
	end
	if AppHelpers:featureUnlocked(state, "Rebirth") then
		local _arg0 = {
			label = "CORES",
			value = state.Cores,
			icon = "Core",
			accent = Palette.violet,
		}
		table.insert(allChips, _arg0)
	end
	if AppHelpers:featureUnlocked(state, "StarGrid") then
		local _arg0 = {
			label = "DUST",
			value = state.Stardust,
			icon = "Dust",
			accent = Palette.mango,
		}
		table.insert(allChips, _arg0)
	end
	local _arg0 = {
		label = "FLUX",
		value = state.Cash,
		icon = "Flux",
		accent = Palette.cyan,
	}
	table.insert(allChips, _arg0)
	local visitPillWidth = if visitPill ~= nil then (if tight then 124 else 156) else 0
	local countdownW = 0
	local _condition_1 = state.Settings.ShowFps
	if _condition_1 == nil then
		_condition_1 = 1
	end
	local _exp = (if _condition_1 >= 0.5 then 1 else 0)
	local _condition_2 = state.Settings.ShowPing
	if _condition_2 == nil then
		_condition_2 = 1
	end
	local performanceCount = _exp + (if _condition_2 >= 0.5 then 1 else 0)
	local fullPerformanceW = if micro or performanceCount == 0 then 0 elseif performanceCount == 1 then (if stacked then 96 else 90) elseif stacked then 200 else 188
	local performanceGap = 10
	local playerControlGap = if shortRow then 6 else 8
	local playerControlW = if micro or stacked or width < 980 then SHELL_CHROME.topbarControl else 110
	local feedbackControlGap = if shortRow then 6 else 8
	local showFeedbackControl = not (stacked and width < 360)
	local feedbackControlW = if not showFeedbackControl then 0 elseif micro or stacked or width < 1480 then SHELL_CHROME.topbarControl else 116
	local searchControlW = if width < 340 then 0 elseif micro or stacked or width < 1280 then SHELL_CHROME.topbarControl else 112
	local controlsBeforeSearch = SHELL_CHROME.topbarControl + playerControlGap + playerControlW + (if showFeedbackControl then feedbackControlGap + feedbackControlW else 0)
	local controlsW = controlsBeforeSearch + (if searchControlW > 0 then feedbackControlGap + searchControlW else 0)
	local fixedSingleRow = edgePad * 2 + (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) + controlsW + 12 + (if visitPillWidth > 0 then visitPillWidth + 6 else 0) + (if countdownW > 0 then countdownW + 10 else 0)
	-- currencies matter more than FPS/ping: the performance readout only stays when at least two
	-- resource chips (or all of them, if fewer) still fit beside it
	local minimumResourceRoom = math.min(#allChips, 2) * (chipWidthEstimate + 8)
	local performanceW = if not stacked and fullPerformanceW > 0 and width - fixedSingleRow - fullPerformanceW - performanceGap < minimumResourceRoom then 0 else fullPerformanceW
	local chips = allChips
	local controlsRight = edgePad + 4
	-- Show only the chips that fit whole, most important first (flux, cores, dust, then the event),
	-- instead of a scroller whose last chip is sliced by the edge and whose flux chip falls off it.
	if not stacked then
		local railRoom = math.max(48, width - edgePad * 2 - (controlsW + controlsRight + 12) - (12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14))
		local room = railRoom - (if performanceW > 0 then performanceW + 8 else 0) - (if visitPillWidth > 0 then visitPillWidth + 8 else 0)
		local chipFitW = if micro then 172 else 170 -- a rendered desktop chip is ~166px with the wider value box
		local fits = math.max(0, math.floor((room + 8) / (chipFitW + 8)))
		if fits < #allChips then
			local rank = { FLUX = 1, CORES = 2, DUST = 3, EVENT = 4 }
			local ranked = table.clone(allChips)
			table.sort(ranked, function(a, b) return (rank[a.label] or 9) < (rank[b.label] or 9) end)
			local keep = {}
			for index = 1, fits do keep[ranked[index]] = true end
			chips = {}
			for _, chip in allChips do
				if keep[chip] then table.insert(chips, chip) end
			end
		end
	end
	local hasRightCluster = not stacked and (#chips > 0 or visitPill ~= nil or performanceW > 0)
	local row1H = if stacked then 62 else barHeight
	local logoMark = if micro then 40 else SHELL_CHROME.topbarControl
	local logoH = logoMark
	local controlY = math.floor((row1H - SHELL_CHROME.topbarControl) / 2)
	local logoY = controlY + math.floor((SHELL_CHROME.topbarControl - logoMark) / 2)
	local chipRowH = if stacked then 44 elseif shortRow then math.max(28, barHeight - 4) else 44
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_2 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	})
	local _exp_3 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.52,
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromOffset(72, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.new(1, -36, 0, 1),
		Position = UDim2.fromOffset(18, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		Position = UDim2.fromOffset(12, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = if railOpen then "Close" else "Menu",
		onClick = toggleRail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = "",
			icon = if railOpen then "Close" else "Menu",
			size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		}),
	}))
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.fromOffset(logoWidth, logoH),
		Position = UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap, logoY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(LogoLockup, {
		compact = logoCompact,
		micro = micro,
		accent = accent,
		reducedMotion = reducedMotion,
	}))
	local _exp_8 = countdownW > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(countdownW, 48),
		Position = UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14, math.floor((row1H - 48) / 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 22,
	}, React.createElement(TopbarReleaseCountdown, {
		releaseAt = releaseAt,
		width = countdownW,
		reducedMotion = reducedMotion,
	}))
	local _condition_3 = hasRightCluster
	if _condition_3 then
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		})
		local _condition_4 = performanceW > 0
		if _condition_4 then
			local _attributes = {
				tall = false,
				reducedMotion = reducedMotion,
			}
			local _condition_5 = state.Settings.ShowFps
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showFps = _condition_5 >= 0.5
			local _condition_6 = state.Settings.ShowPing
			if _condition_6 == nil then
				_condition_6 = 1
			end
			_attributes.showPing = _condition_6 >= 0.5
			_condition_4 = React.createElement(PerformanceStats, _attributes)
		end
		local _exp_10 = visitPill ~= nil and React.createElement("frame", {
			Size = UDim2.fromOffset(visitPillWidth, TapTarget),
			LayoutOrder = 10,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, {
			text = visitPill.label,
			icon = "Crew",
			onClick = openPlayerlist,
			color = Palette.panelSoft,
			textColor = visitPill.accent,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		}))
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
			if chip.event then
				return React.createElement(ServerEventChip, {
					key = chip.label,
					layoutOrder = 20 + index,
					state = state,
					reducedMotion = reducedMotion,
				})
			end
			local _attributes = {
				key = chip.label,
				layoutOrder = 20 + index,
				label = chip.label,
				value = chip.value,
				icon = chip.icon,
				accent = chip.accent,
				reducedMotion = reducedMotion,
				velocity = if chip.label == "FLUX" then state.Production else 0,
			}
			local _condition_5 = state.Settings.ShowResourceLabels
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showLabel = _condition_5 >= 0.5
			return React.createElement(StatChip, _attributes)
		end
		for _k, _v in chips do
			_newValue[_k] = _callback_1(_v, _k - 1, chips)
		end
		_condition_3 = React.createElement("scrollingframe", {
			Name = "TopbarResourceRail",
			Size = UDim2.fromOffset(math.max(48, width - edgePad * 2 - (controlsW + controlsRight + 12) - (12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14)), chipRowH + 4),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = accent,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(controlsW + controlsRight + 12), 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = true,
		}, _exp_9, _condition_4, _exp_10, _newValue)
	end
	local _condition_4 = stacked
	if _condition_4 then
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
		})
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
			if chip.event then
				return React.createElement(ServerEventChip, {
					key = chip.label,
					layoutOrder = index + 1,
					state = state,
					reducedMotion = reducedMotion,
					tall = true,
				})
			end
			local _attributes = {
				key = chip.label,
				layoutOrder = index + 1,
				label = chip.label,
				value = chip.value,
				icon = chip.icon,
				accent = chip.accent,
				reducedMotion = reducedMotion,
				velocity = if chip.label == "FLUX" then state.Production else 0,
				tall = true,
			}
			local _condition_5 = state.Settings.ShowResourceLabels
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showLabel = _condition_5 >= 0.5
			return React.createElement(StatChip, _attributes)
		end
		for _k, _v in chips do
			_newValue[_k] = _callback_1(_v, _k - 1, chips)
		end
		_condition_4 = React.createElement("scrollingframe", {
			Name = "TopbarResourceRail",
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = accent,
			Size = UDim2.new(1, -(24 + (if performanceW > 0 then performanceW + performanceGap else 0)), 0, TapTarget + 6),
			Position = UDim2.fromOffset(12, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = true,
		}, _exp_9, _newValue)
	end
	local _condition_5 = stacked and performanceW > 0
	if _condition_5 then
		local _attributes = {
			tall = true,
			reducedMotion = reducedMotion,
		}
		local _condition_6 = state.Settings.ShowFps
		if _condition_6 == nil then
			_condition_6 = 1
		end
		_attributes.showFps = _condition_6 >= 0.5
		local _condition_7 = state.Settings.ShowPing
		if _condition_7 == nil then
			_condition_7 = 1
		end
		_attributes.showPing = _condition_7 >= 0.5
		_condition_5 = React.createElement("frame", {
			Size = UDim2.fromOffset(performanceW, TapTarget),
			Position = UDim2.new(1, -(performanceW + 12), 0, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 23,
			ClipsDescendants = true,
		}, React.createElement(PerformanceStats, _attributes))
	end
	return React.createElement("frame", {
		Size = if barHeightMotion ~= nil then barHeightMotion:map(function(height)
			return UDim2.new(1, -edgePad * 2, 0, height)
		end) else UDim2.new(1, -edgePad * 2, 0, barHeight),
		Position = UDim2.fromOffset(edgePad, topPad),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = false,
	}, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _exp_8, _condition_3, _condition_4, _condition_5, React.createElement("frame", {
		Size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = "Hide",
		onClick = hideUI,
		color = Palette.panelSoft,
		textColor = accent,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = "",
			icon = "Hide",
			size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		}),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(playerControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if playerControlW > SHELL_CHROME.topbarControl then "PLAYERS" else "",
		icon = "Pilot",
		onClick = openPlayerlist,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = if playerControlW > SHELL_CHROME.topbarControl then "PLAYERS" else "",
			icon = "Pilot",
			size = UDim2.fromOffset(playerControlW, SHELL_CHROME.topbarControl),
		}),
	})), showFeedbackControl and React.createElement("frame", {
		Size = UDim2.fromOffset(feedbackControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW + feedbackControlGap + feedbackControlW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if feedbackControlW > SHELL_CHROME.topbarControl then "FEEDBACK" else "",
		icon = "Chat",
		onClick = openFeedback,
		color = Palette.panelSoft,
		textColor = Palette.mint,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = if feedbackControlW > SHELL_CHROME.topbarControl then "FEEDBACK" else "",
			icon = "Chat",
			size = UDim2.fromOffset(feedbackControlW, SHELL_CHROME.topbarControl),
		}),
	})), searchControlW > 0 and React.createElement("frame", {
		Name = "QuickFindButton",
		Size = UDim2.fromOffset(searchControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(controlsRight + controlsW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if searchControlW > SHELL_CHROME.topbarControl then "FIND" else "",
		icon = "Search",
		onClick = function()
			require(script.Parent.QuickFind).open()
		end,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = if searchControlW > SHELL_CHROME.topbarControl then "FIND" else "",
			icon = "Search",
			size = UDim2.fromOffset(searchControlW, SHELL_CHROME.topbarControl),
		}),
	})))
end

return {
	TopBar = TopBar,
	ActiveBoostIcon = ActiveBoostIcon,
	StatChip = StatChip,
	PerformanceStats = PerformanceStats,
	TopbarReleaseCountdown = TopbarReleaseCountdown,
}
end

__defs["NavChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _ui = __load("ui")
local ButtonShimmer = _ui.ButtonShimmer
local CountBadge = _ui.CountBadge
local Text = _ui.Text
local acquireDropdownPortal = _ui.acquireDropdownPortal
local releaseDropdownPortal = _ui.releaseDropdownPortal
local subscribeInputCancellation = _ui.subscribeInputCancellation
local resolvePressMotion = _ui.resolvePressMotion
local useButtonChrome = _ui.useButtonChrome
local _theme = require(script.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local moreDockHeight = _theme.moreDockHeight
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local strokeGradient = _theme.strokeGradient
local TapTarget = _theme.TapTarget
local _appNav = require(script.Parent.CoreKit)("appNav")
local AppHelpers = _appNav.AppHelpers
local MORE_NAV = _appNav.MORE_NAV
local PRIMARY_NAV = _appNav.PRIMARY_NAV
local NAV_GROUPS = _appNav.NAV_GROUPS
local navGroupOf = _appNav.navGroupOf
local Audio = require(script.Parent.AudioKit)("audio").Audio
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local ActiveBoostIcon = __load("TopBarChrome").ActiveBoostIcon

local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}

local MORE_BTN_W = 172

local function RailButton(_param)
	local entry = _param.entry
	local active = _param.active
	local collapsed = _param.collapsed
	local onClick = _param.onClick
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local rowHeight = _param.rowHeight
	local bodySize = _param.bodySize
	local viewport = useViewport()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local touchChrome = viewport.compact or viewport.tight
	local disabled = entry.disabled == true
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local hoveredRef = React.useRef(false)
	local emphasis = useFlipperSpring(if not disabled and active then 1 elseif not disabled and hovered then 0.4 else 0, reducedMotion, 300, 36)
	local pose = useFlipperSpring(if disabled then 0 elseif pressed then -1 elseif hovered then 1 else 0, reducedMotion, 1180, 46)
	local iconHover = pose:map(function(value)
		return math.clamp(value, 0, 1)
	end)
	local press = pose:map(function(value)
		return math.clamp(-value, 0, 1)
	end)
	local fill = emphasis:map(function(raw)
		return if disabled then Palette.panelRaised else Palette.panel:Lerp(Palette.panelSoft, math.clamp(raw, 0, 1))
	end)
	local fillTransparency = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return 0.34 - amount * 0.34
	end)
	local strokeTransparency = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return math.clamp(0.82 - amount * 0.62, 0.18, 0.85)
	end)
	local markerSize = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return UDim2.new(0, 3, 1, -18 - math.round((1 - amount) * 16))
	end)
	local tileFill = emphasis:map(function(raw)
		return if disabled then Palette.panelSoft else Palette.panelRaised:Lerp(darken(entry.accent, 0.52), math.clamp(raw, 0, 1))
	end)
	local ringTransparency = emphasis:map(function(raw)
		return math.clamp(0.78 - math.clamp(raw, 0, 1) * 0.7, 0.05, 0.82)
	end)
	local labelColor = emphasis:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local eyebrowColor = emphasis:map(function(raw)
		return if disabled then Palette.muted else Palette.muted:Lerp(entry.accent, math.clamp(raw, 0, 1))
	end)
	local pressWash = press:map(function(amount)
		return if touchChrome then math.clamp(1 - amount * 0.22, 0.78, 1) else 1
	end)
	local pressMotion = resolvePressMotion("row")
	local rowHover = pressMotion.hover
	local rowPress = pressMotion.press
	local rowTilt = pressMotion.tilt
	local pressScale = pose:map(function(value)
		if value >= 0 then
			return 1 + math.clamp(value, 0, 1) * rowHover
		end
		return 1 - math.clamp(-value, 0, 1) * rowPress
	end)
	local tilt = pose:map(function(value)
		return math.clamp(value, 0, 1) * rowTilt
	end)
	local iconSize = if collapsed then 34 else 30
	local iconX = if collapsed then math.floor((Layout.sidebarCollapsedWidth - SHELL_CHROME.railGutter * 2 - iconSize) / 2) else 12
	local markHover = function()
		if disabled then
			return nil
		end
		if hoveredRef.current then
			return nil
		end
		hoveredRef.current = true
		setHovered(true)
		Audio:play("navHover" .. entry.id)
	end
	local clearHover = function()
		hoveredRef.current = false
		setHovered(false)
		setPressed(false)
	end
	React.useEffect(function()
		return subscribeInputCancellation(function()
			hoveredRef.current = false
			setHovered(false)
			setPressed(false)
		end)
	end, {})
	return React.createElement("frame", {
		Name = "Nav_" .. entry.id,
		Size = UDim2.new(1, 0, 0, rowHeight),
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		Event = {
			Activated = function()
				local audioMarker = Audio:captureIntent()
				onClick()
				if not disabled then
					Audio:playIfUnclaimed(audioMarker, "navOpen" .. entry.id)
				end
				InteractionFeedback.tap()
			end,
			MouseEnter = function()
				return markHover()
			end,
			MouseLeave = function()
				return clearHover()
			end,
			SelectionGained = function()
				return markHover()
			end,
			SelectionLost = function()
				return clearHover()
			end,
			InputBegan = function(_b, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setPressed(true)
				end
			end,
			InputEnded = function()
				return setPressed(false)
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = tilt,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = pressScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -4, 1, -2),
		Position = press:map(function(amount)
			return UDim2.new(0, 2, 0, 1 + math.round(amount * (if touchChrome then 2 else 1)))
		end),
		BackgroundColor3 = fill,
		BackgroundTransparency = fillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.7),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = entry.accent,
		Thickness = 1,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), touchChrome and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = lighten(entry.accent, 0.35),
		BackgroundTransparency = pressWash,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})), React.createElement("frame", {
		Size = markerSize,
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = entry.accent,
		BackgroundTransparency = emphasis:map(function(amount)
			return if amount < 0.08 then 1 else 0.75 - amount * 0.75
		end),
		BorderSizePixel = 0,
		Visible = emphasis:map(function(amount)
			return amount >= 0.08
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = UDim2.new(0, iconX, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = tileFill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = entry.accent,
		Thickness = 1,
		Transparency = ringTransparency,
	}), React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft elseif active then lighten(entry.accent, 0.42) else Palette.muted,
		size = iconSize,
		spin = not disabled and hovered,
		hoverAmount = iconHover,
		reducedMotion = reducedMotion,
	})), not collapsed and React.createElement(Text, {
		value = entry.label,
		size = bodySize,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, if rowHeight <= 54 then 2 else 8),
		sizeConstraint = UDim2.new(1, -66, 0, if rowHeight <= 54 then 22 else 26),
	}), not collapsed and React.createElement(Text, {
		value = entry.eyebrow,
		size = 12,
		color = eyebrowColor,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(56, if rowHeight <= 54 then 26 else 38),
		sizeConstraint = UDim2.new(1, -66, 0, if rowHeight <= 54 then 16 else 20),
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 12,
	})))))
end
local function MoreDockButton(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local fill = _param.fill
	local disabled = entry.disabled == true
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true, false, resolvePressMotion(if fill then "row" else {
		text = entry.label,
		icon = entry.icon,
		size = UDim2.fromOffset(MORE_BTN_W, TapTarget),
	}))
	local selection = useFlipperSpring(if active and not disabled then 1 else 0, reducedMotion, 420, 32)
	local radius = 12
	local iconSize = if fill then 22 else 28
	local iconX = if fill then 7 else 9
	local textX = if fill then 38 else 49
	local fillColor = chrome.hoverAmount:map(function(amount)
		return if disabled then Palette.panelRaised else Palette.panel:Lerp(Palette.panelSoft, math.clamp(amount, 0, 1) * 0.6)
	end)
	local cardTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		if fill then
			return 0
		end
		local selected = math.clamp(raw, 0, 1)
		local hoverAmount = math.clamp(hovered, 0, 1)
		return math.clamp(1 - selected * 0.94 - hoverAmount * 0.55, 0.06, 1)
	end)
	local activeFillTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1) * 0.78
	end)
	local strokeTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		local selected = math.clamp(raw, 0, 1)
		if fill then
			return math.clamp(0.72 - math.clamp(hovered, 0, 1) * 0.32 - selected * 0.48, 0.18, 0.76)
		end
		return math.clamp(1 - math.clamp(hovered, 0, 1) * 0.55 - selected * 0.82, 0.18, 1)
	end)
	local iconPosition = selection:map(function(raw)
		local selected = math.clamp(raw, 0, 1)
		return if fill then UDim2.new(0.5, 0, 0, 3 - math.round(selected * 2)) else UDim2.new(0, iconX, 0.5, -math.round(selected))
	end)
	local iconFill = selection:map(function(raw)
		return if disabled then Palette.panelSoft else Palette.panelRaised:Lerp(darken(entry.accent, 0.64), math.clamp(raw, 0, 1))
	end)
	local iconFillTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		if disabled then
			return 0.35
		end
		if fill then
			return 0
		end
		local selected = math.clamp(raw, 0, 1)
		local hoverAmount = math.clamp(hovered, 0, 1)
		return math.clamp(0.62 - hoverAmount * 0.5 - selected * 0.62, 0, 0.62)
	end)
	local labelColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local underlineSize = selection:map(function(raw)
		return UDim2.new(0.46 * math.clamp(raw, 0, 1), 0, 0, 2)
	end)
	local underlineTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1)
	end)
	return React.createElement("frame", {
		Size = if fill then UDim2.fromScale(1, 1) else UDim2.fromOffset(MORE_BTN_W, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		ZIndex = 56,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 57,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = chrome.tilt,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = chrome.touchScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundColor3 = fillColor,
		BackgroundTransparency = cardTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 57,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.55),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = entry.accent,
		Thickness = 1,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(entry.accent, 0.68),
		BackgroundTransparency = activeFillTransparency,
		BorderSizePixel = 0,
		ZIndex = 57,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 58,
	}, React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		live = chrome.shimmerLive,
		zIndex = 58,
		radius = radius,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = iconPosition,
		AnchorPoint = if fill then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
		BackgroundColor3 = iconFill,
		BackgroundTransparency = iconFillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 59,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = iconSize,
		spin = not disabled and chrome.hovered,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = entry.label,
		size = if fill then 11 else 12,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		align = if fill then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		fit = true,
		minSize = if fill then 9 else 10,
		position = if fill then UDim2.fromOffset(2, if fill then 26 else 4) else UDim2.fromOffset(textX, 12),
		sizeConstraint = if fill then UDim2.new(1, -4, 0, 16) else UDim2.new(1, -(textX + 6), 0, 22),
		zIndex = 59,
	}), React.createElement("frame", {
		Size = underlineSize,
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = lighten(entry.accent, 0.48),
		BackgroundTransparency = underlineTransparency,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 58,
		compact = true,
	}), not fill and React.createElement("frame", {
		Size = UDim2.new(0, 1, 1, -18),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 56,
	}))
end
local MoreCell
local function MoreDockPopover(_param)
	local entries = _param.entries
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local anchor = _param.anchor
	local onClose = _param.onClose
	local viewport = useViewport()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local portalLayer = React.useState(acquireDropdownPortal)
	React.useEffect(function()
		return function()
			return releaseDropdownPortal()
		end
	end, {})
	local panelRef = React.useRef()
	local onCloseRef = React.useRef(onClose)
	onCloseRef.current = onClose
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				onCloseRef.current()
				return nil
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			local panel = panelRef.current
			if panel == nil then
				return nil
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local origin = panel.AbsolutePosition
			local extent = panel.AbsoluteSize
			local inside = point.X >= origin.X and point.X <= origin.X + extent.X and point.Y >= origin.Y and point.Y <= origin.Y + extent.Y
			if not inside then
				onCloseRef.current()
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, {})
	local visible = AppHelpers:filterNav(entries, state, tutorialPage)
	local cols = math.min(5, math.max(3, math.ceil(math.sqrt(#visible))))
	local cellW = 132
	local cellH = 68
	local gap = 8
	local rows = math.max(1, math.ceil(#visible / cols))
	local panelW = cols * cellW + (cols - 1) * gap + 20
	local panelH = rows * cellH + (rows - 1) * gap + 56
	local clampedX = math.clamp(anchor.right - panelW, 10, math.max(10, viewport.width - panelW - 10))
	local clampedY = math.min(anchor.top, math.max(10, viewport.height - panelH - 10))
	local reveal = useFlipperSpring(1, reducedMotion, 780, 44)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = reveal:map(function(amount)
			return math.clamp(1 - amount * 0.38, 0.4, 1)
		end),
	})
	local _exp_2 = React.createElement(Text, {
		value = "MORE",
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 8),
		sizeConstraint = UDim2.new(1, -20, 0, 14),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
	})
	local _exp_3 = React.createElement("uigridlayout", {
		CellSize = UDim2.fromOffset(cellW, cellH),
		CellPadding = UDim2.new(0, gap, 0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	local _newValue = table.create(#visible)
	local _callback = function(entry, index)
		return React.createElement(MoreCell, {
			key = entry.id,
			entry = entry,
			active = page == entry.id,
			onClick = function()
				setPage(entry.id)
				onClose()
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		})
	end
	for _k, _v in visible do
		_newValue[_k] = _callback(_v, _k - 1, visible)
	end
	return React.createElement(React.Fragment, nil, ReactRoblox.createPortal(React.createElement("frame", {
		ref = panelRef,
		Size = UDim2.fromOffset(panelW, panelH),
		Position = reveal:map(function(amount)
			return UDim2.fromOffset(clampedX, clampedY + math.round((1 - math.clamp(amount, 0, 1)) * 10))
		end),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - math.clamp(amount, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 220,
		ClipsDescendants = true,
		Visible = reveal:map(function(amount)
			return amount > 0.01
		end),
	}, _exp, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, -20, 1, -34),
		Position = UDim2.fromOffset(10, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 221,
	}, _exp_3, _newValue)), portalLayer))
end
function MoreCell(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local disabled = entry.disabled == true
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true, false, resolvePressMotion({
		text = entry.label,
		icon = entry.icon,
		size = UDim2.fromScale(1, 1),
	}))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 93,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 94,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = chrome.tilt,
		BackgroundColor3 = if active then darken(entry.accent, 0.7) else Palette.panelRaised,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ZIndex = 95,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = chrome.touchScale,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if active then entry.accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.35 else 0.7,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		live = chrome.shimmerLive,
		zIndex = 95,
		radius = 12,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 96,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = 22,
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = if disabled then Palette.muted else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(2, 36),
		sizeConstraint = UDim2.new(1, -4, 0, 26),
		zIndex = 96,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 97,
		compact = true,
	}))))
end
local function MoreDock(_param)
	local softMotion = _param.reducedMotion == true
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local stack = _param.stack
	local cols = _param.cols
	local cellH = _param.cellH
	local opacity = _param.opacity
	if opacity == nil then
		opacity = 1
	end
	local spacing = _param.spacing
	if spacing == nil then
		spacing = 0.5
	end
	local entries = _param.entries
	local viewport = useViewport()
	local more = AppHelpers:filterNav(entries, state, tutorialPage)
	local gridGap = 3 + math.floor(math.clamp(spacing, 0, 1) * 5)
	local height = moreDockHeight(stack, #more, cols, cellH, gridGap)
	local moreMenuOpen, setMoreMenuOpen = React.useState(false)
	local moreTriggerRef = React.useRef()
	local popoverAnchor, setPopoverAnchor = React.useState()
	if stack then
		local _exp = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 14),
		})
		local _exp_1 = React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.65,
		})
		local _exp_2 = React.createElement("uigridlayout", {
			CellSize = UDim2.new(1 / cols, -gridGap, 0, cellH),
			CellPadding = UDim2.new(0, gridGap, 0, gridGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = cols,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		})
		local _newValue = table.create(#more)
		local _callback = function(entry, index)
			return React.createElement(MoreDockButton, {
				key = entry.id,
				entry = entry,
				active = page == entry.id,
				onClick = function()
					return setPage(entry.id)
				end,
				reducedMotion = reducedMotion,
				badge = AppHelpers:navBadge(entry, state, chatUnread),
				layoutOrder = index,
				fill = true,
			})
		end
		for _k, _v in more do
			_newValue[_k] = _callback(_v, _k - 1, more)
		end
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundColor3 = Palette.night,
			BackgroundTransparency = math.clamp(1 - opacity, 0, 0.48),
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Active = false,
			ZIndex = 55,
		}, _exp, _exp_1, React.createElement("frame", {
			Size = UDim2.new(1, -10, 1, -12),
			Position = UDim2.fromOffset(5, 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 56,
		}, _exp_2, _newValue))
	end
	local visibleCount = math.clamp(math.floor((viewport.width - 32) / (MORE_BTN_W + 4)), 1, 7)
	local needsMore = #more > visibleCount
	local primaryCount = if needsMore then math.max(1, visibleCount - 1) else visibleCount
	local primary = {}
	local overflow = {}
	local _callback = function(entry, index)
		if index < primaryCount then
			local _entry = entry
			table.insert(primary, _entry)
		else
			local _overflow = overflow
			local _entry = entry
			table.insert(_overflow, _entry)
		end
	end
	for _k, _v in more do
		_callback(_v, _k - 1, more)
	end
	local _callback_1 = function(entry)
		return entry.id == page
	end
	local _result
	for _i, _v in overflow do
		if _callback_1(_v, _i - 1, overflow) == true then
			_result = _v
			break
		end
	end
	local activeInOverflow = _result
	if activeInOverflow ~= nil and #primary > 0 then
		local displaced = primary[#primary]
		primary[#primary] = activeInOverflow
		local _newValue = {}
		local _callback_2 = function(entry)
			return entry.id ~= activeInOverflow.id
		end
		local _length = 0
		for _k, _v in overflow do
			if _callback_2(_v, _k - 1, overflow) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		overflow = _newValue
		if displaced ~= nil then
			table.insert(overflow, 1, displaced)
		end
	end
	local _result_1 = 0
	local _callback_2 = function(sum, entry)
		return sum + AppHelpers:navBadge(entry, state, chatUnread)
	end
	for _i = 1, #overflow do
		_result_1 = _callback_2(_result_1, overflow[_i], _i - 1, overflow)
	end
	local overflowBadgeTotal = _result_1
	local moreTriggerActive = moreMenuOpen or activeInOverflow ~= nil
	local toggleMoreMenu = function()
		if not moreMenuOpen then
			local trigger = moreTriggerRef.current
			if trigger ~= nil then
				local origin = trigger.AbsolutePosition
				local extent = trigger.AbsoluteSize
				setPopoverAnchor({
					right = origin.X + extent.X,
					top = origin.Y + extent.Y + 6,
				})
			end
		end
		setMoreMenuOpen(function(current)
			return not current
		end)
	end
	local canvasW = math.max(#primary * (MORE_BTN_W + 4) - 4, 1)
	local dockW = math.min(viewport.width - 16, #primary * (MORE_BTN_W + 4) - 4)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	local _exp_2 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
	})
	local _newValue = table.create(#primary)
	local _callback_3 = function(entry, index)
		return React.createElement(MoreDockButton, {
			key = entry.id,
			entry = entry,
			active = page == entry.id,
			onClick = function()
				return setPage(entry.id)
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		})
	end
	for _k, _v in primary do
		_newValue[_k] = _callback_3(_v, _k - 1, primary)
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = false,
		ZIndex = 55,
	}, _exp, _exp_1, React.createElement("scrollingframe", {
		Size = UDim2.new(0, dockW, 1, -8),
		Position = UDim2.new(0.5, -math.floor(dockW / 2) - (if needsMore then (MORE_BTN_W + 4) / 2 else 0), 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, canvasW, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		ScrollingEnabled = true,
		Active = true,
		Selectable = false,
		ClipsDescendants = true,
		ZIndex = 56,
	}, _exp_2, _newValue), needsMore and React.createElement("frame", {
		ref = moreTriggerRef,
		Size = UDim2.fromOffset(MORE_BTN_W, TapTarget),
		Position = UDim2.new(1, -(MORE_BTN_W + 6), 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 57,
	}, React.createElement(MoreDockButton, {
		entry = {
			id = "Overview",
			label = "MORE",
			eyebrow = "",
			icon = "Menu",
			accent = Palette.muted,
		},
		active = moreTriggerActive,
		onClick = toggleMoreMenu,
		reducedMotion = reducedMotion,
		badge = overflowBadgeTotal,
		layoutOrder = #primary,
	})), moreMenuOpen and popoverAnchor ~= nil and React.createElement(MoreDockPopover, {
		entries = overflow,
		page = page,
		setPage = function(chosen)
			setPage(chosen)
			setMoreMenuOpen(false)
		end,
		reducedMotion = reducedMotion,
		state = state,
		chatUnread = chatUnread,
		tutorialPage = tutorialPage,
		anchor = popoverAnchor,
		onClose = function()
			return setMoreMenuOpen(false)
		end,
	}))
end
local railGroupMemory = {}
local NAV_BODY_PAD = 3
local function NavChevron(_param)
	local openAmount = _param.openAmount
	local color = _param.color
	local bar = function(offset, rotation)
		return React.createElement("frame", {
			Size = UDim2.fromOffset(7, 2),
			Position = UDim2.new(0.5, offset, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = _param.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = openAmount:map(function(amount)
			return -90 + math.clamp(amount, 0, 1) * 90
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, bar(-2, 45), bar(2, -45))
end
local function NavGroup(_param)
	local entries = _param.entries
	local headerless = _param.headerless == true
	local open = headerless or _param.open == true
	local collapsed = _param.collapsed
	local rowHeight = _param.rowHeight
	local gap = _param.gap
	local headerHeight = if headerless then 0 else _param.headerHeight
	local page = _param.page
	local setPage = _param.setPage
	local state = _param.state
	local chatUnread = _param.chatUnread
	local reducedMotion = _param.reducedMotion
	local stride = rowHeight + gap
	local bodyH = math.max(0, #entries * stride - gap) + NAV_BODY_PAD * 2
	local openAmount = useFlipperSpring(if open then 1 else 0, reducedMotion, 560, 46)
	local hovered, setHovered = React.useState(false)
	local hover = useFlipperSpring(if hovered then 1 else 0, reducedMotion, 900, 44)
	local activeIndex = nil
	local badgeTotal = 0
	for index, entry in entries do
		if entry.id == page then
			activeIndex = index
		end
		badgeTotal += AppHelpers:navBadge(entry, state, chatUnread)
	end
	local heldSelection = React.useRef(0)
	if activeIndex ~= nil then
		heldSelection.current = (activeIndex - 1) * stride
	end
	local selectionLead = useFlipperSpring(heldSelection.current, reducedMotion, 720, 48)
	local selectionTrail = useFlipperSpring(heldSelection.current, reducedMotion, 300, 46)
	local selectionSpan = React.joinBindings({ selectionLead, selectionTrail })
	local hasActive = activeIndex ~= nil
	local selectionAccent = if hasActive then AppHelpers:pageAccent(page) else Palette.muted
	local labelColor = hover:map(function(amount)
		local base = if hasActive then lighten(selectionAccent, 0.2) else Palette.muted
		return base:Lerp(Palette.cream, math.clamp(amount, 0, 1) * 0.7)
	end)
	local rows = {}
	rows.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	rows.pad = React.createElement("uipadding", {
		PaddingTop = UDim.new(0, NAV_BODY_PAD),
		PaddingBottom = UDim.new(0, NAV_BODY_PAD),
	})
	for index, entry in entries do
		rows[entry.id] = React.createElement(RailButton, {
			entry = entry,
			active = page == entry.id,
			collapsed = collapsed,
			onClick = function()
				return setPage(entry.id)
			end,
			layoutOrder = index,
			reducedMotion = reducedMotion,
			rowHeight = rowHeight,
			bodySize = _param.bodySize,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
		})
	end
	local header = nil
	if not headerless then
		local toggle = function()
			_param.onToggle()
			Audio:play(if open then "close" else "open")
			InteractionFeedback.tap()
		end
		local headerChildren = {}
		local showBadge = not open and badgeTotal > 0
		local badgeW = if badgeTotal > 99 then 20 elseif badgeTotal >= 10 then 16 else 14
		local countShift = if showBadge and not collapsed then badgeW + 6 else 0
		if collapsed then
			headerChildren.rule = React.createElement("frame", {
				Size = UDim2.new(0.5, 0, 0, 2),
				Position = UDim2.new(0.5, 0, 0, 4),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = selectionAccent,
				BackgroundTransparency = if hasActive then 0.2 else 0.55,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}))
			headerChildren.chevron = React.createElement(NavChevron, {
				openAmount = openAmount,
				color = Palette.muted,
				position = UDim2.new(0.5, 0, 1, -5),
			})
		else
			headerChildren.label = React.createElement(Text, {
				value = string.upper(_param.label),
				size = 11,
				color = labelColor,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(26, 0),
				sizeConstraint = UDim2.new(1, -70, 1, 0),
			})
			headerChildren.chevron = React.createElement(NavChevron, {
				openAmount = openAmount,
				color = if hasActive then selectionAccent else Palette.muted,
				position = UDim2.new(0, 12, 0.5, 0),
			})
			headerChildren.count = React.createElement(Text, {
				value = tostring(#entries),
				size = 10,
				color = Palette.muted,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Right,
				fit = false,
				position = UDim2.new(1, -40 - countShift, 0, 0),
				sizeConstraint = UDim2.new(0, 32, 1, 0),
			})
			headerChildren.rule = React.createElement("frame", {
				Size = UDim2.new(1, -16, 0, 1),
				Position = UDim2.new(0, 8, 1, -1),
				BackgroundColor3 = Palette.lineSoft,
				BackgroundTransparency = hover:map(function(amount)
					return 0.72 - math.clamp(amount, 0, 1) * 0.3
				end),
				BorderSizePixel = 0,
			})
		end
		if showBadge then
			headerChildren.badge = React.createElement(CountBadge, {
				count = badgeTotal,
				zIndex = 12,
				compact = true,
				position = if collapsed then nil else UDim2.new(1, -8, 0.5, 0),
				anchorPoint = if collapsed then nil else Vector2.new(1, 0.5),
			})
		end
		header = React.createElement("textbutton", {
			Size = UDim2.new(1, 0, 0, headerHeight),
			BackgroundColor3 = Palette.panelSoft,
			BackgroundTransparency = hover:map(function(amount)
				return 1 - math.clamp(amount, 0, 1) * 0.55
			end),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			ZIndex = 3,
			Event = {
				Activated = toggle,
				MouseEnter = function()
					setHovered(true)
				end,
				MouseLeave = function()
					setHovered(false)
				end,
				SelectionGained = function()
					setHovered(true)
				end,
				SelectionLost = function()
					setHovered(false)
				end,
			},
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 8),
		}), headerChildren)
	end
	local pill = hasActive and React.createElement("frame", {
		Size = selectionSpan:map(function(values)
			local stretch = math.abs(values[1] - values[2])
			return UDim2.new(1, -4, 0, math.max(8, rowHeight - 4) + math.round(stretch))
		end),
		Position = selectionSpan:map(function(values)
			return UDim2.fromOffset(2, NAV_BODY_PAD + math.round(math.min(values[1], values[2])) + 2)
		end),
		BackgroundColor3 = Palette.panelSoft,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelSoft, 0.9),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = selectionAccent,
		Thickness = 1,
		Transparency = 0.38,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = strokeGradient(selectionAccent),
	})), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -14),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = selectionAccent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})))
	return React.createElement("frame", {
		Size = openAmount:map(function(amount)
			return UDim2.new(1, 0, 0, headerHeight + math.round(bodyH * math.clamp(amount, 0, 1)))
		end),
		LayoutOrder = _param.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, header, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, bodyH),
		Position = openAmount:map(function(amount)
			return UDim2.fromOffset(0, headerHeight - math.round((1 - math.clamp(amount, 0, 1)) * 8))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = openAmount:map(function(amount)
			return amount > 0.01
		end),
	}, pill, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, rows)))
end
local function Navigation(_param)
	local page = _param.page
	local setPage = _param.setPage
	local collapsed = _param.collapsed
	local width = _param.width
	local fixedWidth = _param.fixedWidth
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local includeSecondary = _param.includeSecondary
	if includeSecondary == nil then
		includeSecondary = false
	end
	local fromMore = _param.fromMore
	if fromMore == nil then
		fromMore = false
	end
	local activeBoost = _param.activeBoost
	local activeBoostEndsAt = _param.activeBoostEndsAt
	if activeBoostEndsAt == nil then
		activeBoostEndsAt = 0
	end
	local wallClock = _param.wallClock
	local openBoosts = _param.openBoosts
	local viewport = useViewport()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local railNavHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = railNavHostRef.current
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
	end, { page, collapsed })
	local chrome = chromeFor(viewport)
	local rowHeight = if collapsed then chrome.railCollapsedRow else chrome.railRow
	local primaryEntries = if fromMore then {} else AppHelpers:filterNav(PRIMARY_NAV, state, tutorialPage)
	local secondaryEntries = if fromMore then AppHelpers:filterNav(MORE_NAV, state, tutorialPage) elseif includeSecondary then AppHelpers:filterNav(MORE_NAV, state, tutorialPage) else {}
	local headerHeight = 12
	local showBoost = activeBoost ~= nil and not chrome.mobile and page ~= "Rewards" and wallClock ~= nil and openBoosts ~= nil
	local boostHeight = if showBoost then (if collapsed then 62 else 64) else 0
	local boostReserve = if showBoost then boostHeight + SHELL_CHROME.railGutter * 2 else 0
	local railScrollRef = React.useRef(nil)
	local grouped = includeSecondary and not fromMore
	local groupHeaderH = if collapsed then 18 else 30
	local activeGroup = navGroupOf(page)
	local groupOpen, setGroupOpen = React.useState(function()
		return table.clone(railGroupMemory)
	end)
	local function isGroupOpen(id)
		local remembered = groupOpen[id]
		if remembered ~= nil then
			return remembered
		end
		return id == "Home" or id == activeGroup
	end
	React.useEffect(function()
		if activeGroup == nil or groupOpen[activeGroup] == true then
			return nil
		end
		railGroupMemory[activeGroup] = true
		setGroupOpen(table.clone(railGroupMemory))
	end, { activeGroup })
	local toggleGroup = function(id)
		railGroupMemory[id] = not isGroupOpen(id)
		setGroupOpen(table.clone(railGroupMemory))
	end
	local railChildren = {}
	local groupOrder = 0
	local function addGroup(id, label, entries, headerless)
		if #entries == 0 then
			return nil
		end
		groupOrder += 1
		railChildren[id] = React.createElement(NavGroup, {
			label = label,
			entries = entries,
			headerless = headerless,
			open = isGroupOpen(id),
			onToggle = function()
				toggleGroup(id)
			end,
			page = page,
			setPage = setPage,
			collapsed = collapsed,
			rowHeight = rowHeight,
			gap = chrome.railGap,
			headerHeight = groupHeaderH,
			bodySize = chrome.bodyText,
			state = state,
			chatUnread = chatUnread,
			reducedMotion = reducedMotion,
			layoutOrder = groupOrder,
		})
	end
	if grouped then
		local byId = {}
		for _, list in { primaryEntries, secondaryEntries } do
			for _, entry in list do
				byId[entry.id] = entry
			end
		end
		local placed = {}
		for _, group in NAV_GROUPS do
			local entries = {}
			for _, id in group.routes do
				local entry = byId[id]
				if entry ~= nil and not placed[id] then
					placed[id] = true
					table.insert(entries, entry)
				end
			end
			addGroup(group.key, group.label, entries, false)
		end
		local loose = {}
		for _, list in { primaryEntries, secondaryEntries } do
			for _, entry in list do
				if not placed[entry.id] then
					placed[entry.id] = true
					table.insert(loose, entry)
				end
			end
		end
		addGroup("More", "More", loose, false)
	else
		local flat = table.clone(primaryEntries)
		for _, entry in secondaryEntries do
			table.insert(flat, entry)
		end
		addGroup("All", "", flat, true)
	end
	return React.createElement("frame", {
		Name = "RailNavClaim",
		ref = railNavHostRef,
		Size = if fixedWidth ~= nil then UDim2.fromScale(1, 1) else width:map(function(value)
			return UDim2.new(0, math.max(0, value), 1, 0)
		end),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 10,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.5),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = strokeGradient(Palette.lineSoft),
	})), React.createElement("scrollingframe", {
		ref = railScrollRef,
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2 + 4), 1, -(headerHeight + SHELL_CHROME.railGutter + boostReserve)),
		Position = UDim2.fromOffset(SHELL_CHROME.railGutter, headerHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, if collapsed then 4 else 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("uipadding", {
		PaddingBottom = UDim.new(0, Layout.stackGap),
	}), railChildren), showBoost and React.createElement("frame", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2), 0, boostHeight),
		Position = UDim2.new(0, SHELL_CHROME.railGutter, 1, -(boostHeight + SHELL_CHROME.railGutter)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, React.createElement(ActiveBoostIcon, {
		boost = activeBoost,
		endsAt = activeBoostEndsAt,
		now = wallClock,
		open = openBoosts,
		reducedMotion = reducedMotion,
		compact = collapsed,
	})))
end

return {
	Navigation = Navigation,
	MoreDock = MoreDock,
	RailButton = RailButton,
	MoreDockButton = MoreDockButton,
	MoreDockPopover = MoreDockPopover,
}
end

__defs["WorkspaceChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.MotionKit)("motion")
local EntranceMotionSuppressedContext = _motion.EntranceMotionSuppressedContext
local useFlash = _motion.useFlash
local useTokenEntrance = _motion.useTokenEntrance
local PageTransition = require(script.Parent.MotionKit)("pageTransition")
local NavRouteTable = require(script.Parent.CoreKit)("navRouteTable")
local PAGE_ORDER = {}
local function pageOrderFor(phone)
	local key = if phone then "phone" else "rail"
	local cached = PAGE_ORDER[key]
	if cached ~= nil then
		return cached
	end
	local order, seen = {}, {}
	local function add(id)
		if not seen[id] then
			seen[id] = true
			table.insert(order, id)
		end
	end
	if phone then
		for _, id in NavRouteTable.MOBILE_TAB_PRIORITY do
			add(id)
		end
	end
	for _, group in NavRouteTable.NAV_GROUPS do
		for _, id in group.routes do
			add(id)
		end
	end
	for _, id in NavRouteTable.allNavIds() do
		add(id)
	end
	PAGE_ORDER[key] = order
	return order
end
local useViewport = _motion.useViewport
local ExitPresenceContext = _motion.ExitPresenceContext
local useExitPresence = _motion.useExitPresence
local composePresence = _motion.composePresence
local _ui = __load("ui")
local Button = _ui.Button
local resolvePressMotion = _ui.resolvePressMotion
local IconTile = _ui.IconTile
local meterFill = _ui.meterFill
local ScrollEdgeFade = _ui.ScrollEdgeFade
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local _theme = require(script.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local surfaceGradient = _theme.surfaceGradient
local strokeGradient = _theme.strokeGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local AppHelpers = require(script.Parent.CoreKit)("appNav").AppHelpers
local LayoutSectionPlan = require(script.Parent.LayoutKit)("layoutSectionPlan")
local VaultCollectEligibility = require(script.Parent.CoreKit)("vaultCollectEligibility")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _levelRoadmap = __load("levelRoadmap")
local tierAccent = _levelRoadmap.tierAccent
local featureNames = _levelRoadmap.featureNames
local readLevelState = _levelRoadmap.readLevelState
local openRoadmap = _levelRoadmap.openRoadmap
local progressFraction = _levelRoadmap.progressFraction

local function VaultPill(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local top = _param.top
	if top == nil then
		top = 8
	end
	local fill = meterFill(asFlux(state.Vault), asFlux(state.Capacity))
	local ready = VaultCollectEligibility.isEligible(asFlux(state.Vault))
	local full = VaultCollectEligibility.isFull(fill)
	local bar = if full then Palette.mango else accent
	local gains, setGains = React.useState(0)
	local previousVault = React.useRef(state.Vault)
	local softMotion = reducedMotion
	React.useEffect(function()
		if asFlux(state.Vault) > asFlux(previousVault.current) then
			setGains(function(current)
				return current + 1
			end)
		end
		previousVault.current = state.Vault
	end, { state.Vault })
	local vaultFlash = useFlash(gains, softMotion, 0.5)
	local vaultTextColor = vaultFlash:map(function(amount)
		return ensureContrast(Palette.panelRaised, if ready then Palette.cream else Palette.muted):Lerp(bar, amount * 0.7)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(248, 52),
		Position = UDim2.new(1, -316, 0, top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 13),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if full then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = if full then 0.35 else 0.72,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = darken(bar, 0.62),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Icon, {
		kind = "Vault",
		color = Palette.cream,
		accent = bar,
		size = 18,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), React.createElement(Text, {
		value = compactNumber(state.Vault),
		size = 15,
		color = vaultTextColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(50, 7),
		sizeConstraint = UDim2.new(1, -62, 0, 20),
	}), React.createElement(Text, {
		value = `of {compactNumber(state.Capacity)}`,
		size = 11,
		color = ensureContrast(Palette.panelRaised, Palette.muted),
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(50, 26),
		sizeConstraint = UDim2.new(1, -62, 0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, 4),
		Position = UDim2.new(0, 10, 1, -8),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(math.clamp(fill, 0.02, 1), 0, 1, 0),
		BackgroundColor3 = bar,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function NextUnlockStrip(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local onOpen = _param.onOpen
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local viewport = useViewport()
	local narrow = chromeFor(viewport).stack or viewport.width < 720
	local level, tier, nextStep = readLevelState(state)
	local accent = tierAccent(tier)
	local fill = if nextStep ~= nil then progressFraction(nextStep) else 1
	local hovered, setHovered = React.useState(false)
	local levelW = if narrow then 58 else 64
	local tierW = if narrow then 0 else 92
	local goalLeft = 14 + levelW + (if narrow then 8 else tierW + 14)
	local progressW = if narrow then 72 else 88
	local nextNames = if nextStep ~= nil then featureNames(state, nextStep.Unlocks) else {}
	local nextText = if nextStep == nil then ""
		elseif #nextNames == 0 then `Next: Level {nextStep.Level}`
		elseif #nextNames == 1 then `Opens {nextNames[1]}`
		else `Opens {nextNames[1]} +{#nextNames - 1}`
	local nextW = if narrow or nextText == "" then 0 else 150
	local LevelRewards = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("LevelRewards")
	local rate = tonumber(state.Production) or 0
	local eta = if nextStep ~= nil then LevelRewards.eta(nextStep.Kind, nextStep.Target - nextStep.Progress, rate) else nil
	local etaText = LevelRewards.etaText(eta)
	if etaText ~= "" then
		progressW += 44
	end
	return React.createElement("imagebutton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = onOpen ~= nil,
		Selectable = onOpen ~= nil,
		ClipsDescendants = true,
		Event = {
			Activated = function()
				if onOpen ~= nil then
					Audio:play("open")
					onOpen()
				end
			end,
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = if hovered then 0.96 else 1,
		BorderSizePixel = 0,
	}), React.createElement(Text, {
		value = `Level {level}`,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(14, 0),
		sizeConstraint = UDim2.new(0, levelW, 1, -3),
	}), not narrow and React.createElement(Text, {
		value = tier,
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(14 + levelW + 4, 0),
		sizeConstraint = UDim2.new(0, tierW, 1, -3),
	}), not narrow and React.createElement("frame", {
		Size = UDim2.fromOffset(1, 12),
		Position = UDim2.new(0, goalLeft - 8, 0.5, -7),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
	}), React.createElement(Text, {
		value = if nextStep ~= nil then nextStep.Text else "Every level reached",
		size = 12,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(goalLeft, 0),
		sizeConstraint = UDim2.new(1, -(goalLeft + progressW + nextW + 38), 1, -3),
	}), nextStep ~= nil and React.createElement(Text, {
		value = `{compactNumber(nextStep.Progress)} / {compactNumber(nextStep.Target)}` .. (if etaText ~= "" then `  ·  ~{etaText}` else ""),
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -(progressW + nextW + 30), 0, 0),
		sizeConstraint = UDim2.new(0, progressW, 1, -3),
	}), nextW > 0 and React.createElement(Text, {
		value = nextText,
		size = 11,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -(nextW + 26), 0, 0),
		sizeConstraint = UDim2.new(0, nextW, 1, -3),
	}), onOpen ~= nil and React.createElement(Text, {
		value = "›",
		size = 16,
		color = if hovered then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.new(1, -22, 0, -1),
		sizeConstraint = UDim2.fromOffset(14, 30),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}), nextStep ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(2, 6),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = if fill >= 0.5 then accent else Palette.lineSoft,
		BorderSizePixel = 0,
	})))
end

local function Workspace(_param)
	local page = _param.page
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local keyboardCompact = viewport.keyboardOpen
	local _condition = chrome.stack
	if _condition then
		local _condition_1 = state.Settings.MobileCompactHeaders
		if _condition_1 == nil then
			_condition_1 = 1
		end
		_condition = _condition_1 >= 0.5
	end
	local mobileHeaderCompact = _condition
	local accent = AppHelpers:pageAccent(page)
	local entry = AppHelpers:pageEntry(page)
	local enter = useTokenEntrance(page, reducedMotion, 0.2)
	local pageTrack = React.useRef(nil)
	if pageTrack.current == nil then
		pageTrack.current = { page = page, direction = 1 }
	elseif pageTrack.current.page ~= page then
		pageTrack.current = { page = page, direction = PageTransition.direction(pageTrack.current.page, page, pageOrderFor(chrome.stack)) }
	end
	local pageDirection = pageTrack.current.direction
	local shellPresence = useExitPresence()
	local pagePresence = React.useMemo(function()
		return composePresence(shellPresence, enter)
	end, { shellPresence, enter })
	local entranceLock, setEntranceLock = React.useState({
		page = page,
		suppress = false,
	})
	local suppressEntrance = entranceLock.page == page and entranceLock.suppress
	React.useEffect(function()
		local alive = true
		setEntranceLock({
			page = page,
			suppress = false,
		})
		local job = task.delay(0.34, function()
			if not alive then
				return nil
			end
			setEntranceLock({
				page = page,
				suppress = true,
			})
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { page })
	local inset = if keyboardCompact then 6 elseif chrome.stack then chrome.contentInset else Layout.contentInset
	local showNextGoal = true
	do
		local setting = state.Settings.ShowNextGoal
		if setting == nil then
			setting = 1
		end
		showNextGoal = setting >= 0.5
	end
	local workspacePlan = LayoutSectionPlan.planWorkspace({
		keyboardCompact = keyboardCompact,
		stack = chrome.stack,
		landscape = chrome.landscape,
		workspaceHeaderH = chrome.workspaceHeaderH,
		layoutWorkspaceHeaderHeight = Layout.workspaceHeaderHeight,
		tapTarget = TapTarget,
		showNextGoal = showNextGoal,
	})
	local headerHeight = workspacePlan.headerHeight
	local unlockH = workspacePlan.unlockH
	local vaultBtn = if chrome.stack then TapTarget else 44
	local ready = VaultCollectEligibility.isEligible(asFlux(state.Vault))
	local vaultCollectHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = vaultCollectHostRef.current
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
	end, { ready, page })
	local slideAxis = if chrome.stack then "x" else "y"
	local slideDistance = PageTransition.distance(chrome.stack, softMotion)
	local contentPosition = enter:map(function(amount)
		local dx, dy = PageTransition.offset(amount, pageDirection, slideAxis, slideDistance)
		return UDim2.new(0, inset + dx, 0, headerHeight + unlockH + inset + dy)
	end)
	local veilTransparency = enter:map(PageTransition.veilTransparency)
	local veilVisible = enter:map(function(amount)
		return PageTransition.veilTransparency(amount) < 0.995
	end)
	local revealFade = enter:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local contentFade = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		return (1 - t) * 0.4
	end)
	local titleLeft = if keyboardCompact then 54 elseif chrome.stack then 66 else 84
	local titleReserve = if keyboardCompact then -(titleLeft + vaultBtn + 18) else (if chrome.stack then -(vaultBtn + 18) elseif chrome.tight then -(vaultBtn + 28) else -344) - (titleLeft - (if chrome.stack then 14 else 22))
	local denseHeader = not keyboardCompact and not chrome.landscape and not chrome.stack and headerHeight < 74
	local titleBlockH = if keyboardCompact then 32 elseif chrome.landscape then 28 elseif chrome.stack then 36 elseif denseHeader then 44 else 72
	local headerIconSize = if keyboardCompact then 28 elseif chrome.landscape then 28 elseif chrome.stack then 32 elseif denseHeader then 36 else 48
	local headerTitleY = if keyboardCompact then 6 elseif chrome.landscape then 10 elseif chrome.stack then 12 else math.max(10, math.floor((headerHeight - titleBlockH) / 2))
	local vaultPillY = math.max(8, math.floor((headerHeight - 52) / 2))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 5,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.48,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = strokeGradient(Palette.lineSoft),
	})), headerHeight > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = darken(Palette.panel, 0.24),
		BorderSizePixel = 0,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.68, 0.18), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(headerIconSize, headerIconSize),
		Position = enter:map(function(amount)
			return UDim2.fromOffset((if keyboardCompact then 8 elseif chrome.stack then 14 else 20) - math.round((1 - math.clamp(amount, 0, 1)) * 10), math.floor((headerHeight - headerIconSize) / 2))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = headerIconSize,
		radius = 12,
		spin = false,
		reducedMotion = reducedMotion,
		zIndex = 4,
	})), React.createElement("frame", {
		Size = UDim2.new(1, titleReserve, 0, titleBlockH),
		Position = UDim2.fromOffset(titleLeft, headerTitleY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, React.createElement(ShimmerText, {
		value = if entry.label == "Ranks" then "Leaderboards" else entry.label,
		size = if chrome.stack then chrome.titleText elseif denseHeader then 20 else 24,
		color = ensureContrast(Palette.panel, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = false,
		minSize = 14,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 6), 0, if chrome.landscape then 4 else 2)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.landscape then 26 elseif chrome.stack then 24 elseif denseHeader then 24 else 28),
		reducedMotion = reducedMotion,
		enabled = true,
		periodSeconds = 4.2,
	}), not keyboardCompact and not mobileHeaderCompact and not chrome.landscape and React.createElement(Text, {
		value = if page == "Overview" then `World {state.CurrentZone}  /  {compactNumber(state.Production)}/s` else entry.eyebrow,
		size = if chrome.stack then chrome.labelText else 14,
		color = ensureContrast(Palette.panel, accent),
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 10), 0, if chrome.stack then 28 elseif denseHeader then 28 else 32)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.stack then 32 elseif denseHeader then 16 else 28),
		transparency = revealFade,
	})), not chrome.stack and React.createElement(VaultPill, {
		state = state,
		reducedMotion = reducedMotion,
		accent = accent,
		top = vaultPillY,
	}), React.createElement("frame", {
		Name = "VaultCollectClaim",
		ref = vaultCollectHostRef,
		Size = UDim2.fromOffset(vaultBtn, vaultBtn),
		Position = UDim2.new(1, -(vaultBtn + 14), 0, math.floor((headerHeight - vaultBtn) / 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = "",
		icon = "Collect",
		onClick = function()
			return dispatch("CollectVault")
		end,
		color = if ready then accent else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		disabled = not ready,
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = "",
			icon = "Collect",
			size = UDim2.fromOffset(vaultBtn, vaultBtn),
		}),
		highlight = asFlux(state.Vault) >= asFlux(state.Capacity) * VaultCollectEligibility.NEAR_FULL,
		zIndex = 22,
	}))), unlockH > 0 and React.createElement("frame", {
		Name = "LevelBarTarget",
		Size = UDim2.new(1, 0, 0, unlockH),
		Position = UDim2.fromOffset(0, headerHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement(NextUnlockStrip, {
		state = state,
		reducedMotion = reducedMotion,
		onOpen = openRoadmap,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -inset * 2, 1, -(headerHeight + unlockH + inset * 2)),
		Position = contentPosition,
		BackgroundTransparency = contentFade,
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, React.createElement(EntranceMotionSuppressedContext.Provider, {
		value = suppressEntrance,
	}, React.createElement(ExitPresenceContext.Provider, {
		value = pagePresence,
	}, children)), React.createElement("frame", {
		Name = "PageVeil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = veilTransparency,
		BorderSizePixel = 0,
		Active = false,
		Selectable = false,
		Visible = veilVisible,
		ZIndex = 190,
	}), React.createElement(ScrollEdgeFade, {
		color = Palette.ink,
		height = if chrome.stack then 18 else 16,
		zIndex = 200,
	})))
end

return {
	Workspace = Workspace,
	VaultPill = VaultPill,
	NextUnlockStrip = NextUnlockStrip,
}
end

__defs["ShellFx"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local usePulse = _motion.usePulse
local Button = __load("ui").Button
local Palette = require(script.Parent.CoreKit)("theme").Palette
local darken = require(script.Parent.CoreKit)("theme").darken
local lighten = require(script.Parent.CoreKit)("theme").lighten
local Fx = require(script.Parent.MotionKit)("vfxMath")

local CONFETTI_COLORS = { Palette.green, Palette.cyan, Palette.mango, Palette.pink, Palette.violet, Palette.cream }
local CONFETTI_COUNT = 44
local CONFETTI_PIECES = {}
for index = 1, CONFETTI_COUNT do
	local side = if index % 2 == 0 then -1 else 1
	CONFETTI_PIECES[index] = {
		side = side,
		angle = -math.pi / 2 - side * math.rad(8 + Fx.hash(index, 1) * 34),
		speed = 640 + Fx.hash(index, 2) * 560,
		size = 5 + math.floor(Fx.hash(index, 3) * 4),
		spin = 5 + Fx.hash(index, 4) * 9,
		sway = 12 + Fx.hash(index, 5) * 24,
		phase = Fx.hash(index, 6) * math.pi * 2,
		ribbon = index % 3 == 0,
		delay = (index % 6) * 0.018,
		color = CONFETTI_COLORS[(index - 1) % #CONFETTI_COLORS + 1],
	}
end
local CONFETTI_GRAVITY = 760
local CONFETTI_DRAG = 3.2
local CONFETTI_LIFE = 1.95

local function TradeReturnPill(_param)
	local stack = _param.stack
	local bottomPad = _param.bottomPad
	local reducedMotion = _param.reducedMotion
	local onReturn = _param.onReturn
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local pulse = usePulse(true, 1.35)
	local width = if stack then 176 else 198
	local height = if stack then 48 else 46
	local tradeReturnHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = tradeReturnHostRef.current
		if host == nil then
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
	end, { onReturn })
	return React.createElement("frame", {
		Name = "TradeReturnClaim",
		ref = tradeReturnHostRef,
		Size = UDim2.fromOffset(width, height),
		ClipsDescendants = false,
		Position = enter:map(function(amount)
			return UDim2.new(0.5, 0, 1, -(bottomPad + (if stack then 10 else 16) - math.round((1 - amount) * 22)))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(amount)
			return 1 + amount * 0.03
		end),
	}), React.createElement(Button, {
		text = "BACK TO TRADE",
		icon = "Visit",
		onClick = onReturn,
		sound = "open",
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = true,
	}))
end
local function AmbientLayer(_param)
	local reducedMotion = _param.reducedMotion
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	local strength = math.clamp(intensity, 0, 1)
	local enabled = not reducedMotion and antilag.allowAmbient and strength > 0.02
	local slow = useClock(enabled, 0.08)
	if strength <= 0.02 or not antilag.allowAmbient then
		return React.createElement("frame", {
			Name = "AuroraBorealis",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end
	local curtains = {}
	local count = if antilag.constrained then 8 else 14
	for index = 1, count do
		local offset = index / count
		curtains[index] = React.createElement("frame", {
			Name = "AuroraCurtain" .. index,
			Size = slow:map(function(t)
				return UDim2.fromScale(2.4 / count, 0.48 + math.sin(offset * 5 + t * 2) * 0.09)
			end),
			Position = slow:map(function(t)
				return UDim2.fromScale(offset - 0.12 + math.sin(t + offset * 4) * 0.025, 0.24 + math.sin(offset * 6 + t * 2) * 0.09)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = slow:map(function(t) return -18 + math.sin(t + offset * 3) * 8 end),
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = 1 - 0.2 * strength * antilag.glowScale,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), React.createElement("uigradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Palette.mint),
				ColorSequenceKeypoint.new(0.4, Palette.cyan),
				ColorSequenceKeypoint.new(1, Palette.violet),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.25),
				NumberSequenceKeypoint.new(0.55, 0.08),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
		}))
	end
	return React.createElement("frame", {
		Name = "AuroraBorealis",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, curtains)
end
local function ConfettiBurst(_param)
	local onDone = _param.onDone
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	local softMotion = false
	local confettiLive = antilag.allowConfetti == true
	local clock = useClock(confettiLive, if softMotion then 1.4 else 1, 1000, true)
	local confettiSpan = if softMotion then 1.35 else 2.15
	local onDoneRef = React.useRef(onDone)
	onDoneRef.current = onDone
	local spanRef = React.useRef(confettiSpan)
	spanRef.current = confettiSpan
	React.useEffect(function()
		if not confettiLive then
			local finish = onDoneRef.current
			if finish ~= nil then
				finish()
			end
			return nil
		end
		local alive = true
		local completion = task.delay(spanRef.current, function()
			if alive then
				local finish = onDoneRef.current
				if finish ~= nil then
					finish()
				end
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, completion)
		end
	end, { confettiLive })
	if not confettiLive then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local activeCount = math.clamp(math.floor(#CONFETTI_PIECES * math.clamp(intensity, 0, 1.5) * math.max(0.34, antilag.fxBudget)), 0, #CONFETTI_PIECES)
	if activeCount <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local pieces = {}
	local _callback = function(piece, index)
		if index < activeCount then
			local _piece = piece
			table.insert(pieces, _piece)
		end
	end
	for _k, _v in CONFETTI_PIECES do
		_callback(_v, _k - 1, CONFETTI_PIECES)
	end
	local _exp = { 0, 1 }
	local _newValue = table.create(#_exp)
	local _callback_1 = function(ring)
		return React.createElement("frame", {
			key = `confetti-ring-{ring}`,
			Size = clock:map(function(seconds)
				local grow = Fx.ring(seconds - ring * 0.08, 0.6)
				local d = 24 + grow * (190 + ring * 52)
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromScale(0.5, 0.56),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 141,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 0 then Palette.mango else Palette.cyan,
			Thickness = clock:map(function(seconds)
				local _, thin = Fx.ring(seconds - ring * 0.08, 0.6)
				return 1 + thin * (if ring == 0 then 3.5 else 2.5)
			end),
			Transparency = clock:map(function(seconds)
				local _, _, fade = Fx.ring(seconds - ring * 0.08, 0.6)
				return 0.1 + fade * 0.9
			end),
		}))
	end
	for _k, _v in _exp do
		_newValue[_k] = _callback_1(_v, _k - 1, _exp)
	end
	local _newValue_1 = table.create(#pieces)
	local _callback_2 = function(piece, index)
		local origin = UDim2.fromScale(0.5 + piece.side * 0.12, 0.66)
		local function age(seconds: number): number
			return math.max(0, seconds - piece.delay)
		end
		local function flip(t: number): number
			return math.abs(math.cos(t * piece.spin + piece.phase))
		end
		return React.createElement("frame", {
			key = index,
			Size = clock:map(function(seconds)
				local long = piece.size * (if piece.ribbon then 3 else 1.6)
				return UDim2.fromOffset(math.max(1.5, piece.size * (0.18 + 0.82 * flip(age(seconds)))), long)
			end),
			Position = clock:map(function(seconds)
				local t = age(seconds)
				local dx, dy = Fx.ballistic(t, piece.angle, piece.speed, CONFETTI_GRAVITY, CONFETTI_DRAG)
				local flutter = math.sin(t * 2.6 + piece.phase) * piece.sway * math.clamp(t / 0.6, 0, 1)
				return origin + UDim2.fromOffset(dx + flutter, dy)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = clock:map(function(seconds)
				local t = age(seconds)
				return math.deg(piece.phase) + t * (if index % 2 == 0 then 210 else -190) + math.sin(t * 3 + piece.phase) * 18
			end),
			BackgroundColor3 = clock:map(function(seconds)
				return piece.color:Lerp(lighten(piece.color, 0.4), flip(age(seconds)))
			end),
			BackgroundTransparency = clock:map(function(seconds)
				if seconds < piece.delay then
					return 1
				end
				return Fx.fade(age(seconds), CONFETTI_LIFE, 0.7)
			end),
			BorderSizePixel = 0,
			ZIndex = 142 + index % 3,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, if piece.ribbon then 1 else 2),
		}))
	end
	for _k, _v in pieces do
		_newValue_1[_k] = _callback_2(_v, _k - 1, pieces)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 140,
		Active = false,
	}, _newValue, _newValue_1)
end
return {
	TradeReturnPill = TradeReturnPill,
	AmbientLayer = AmbientLayer,
	ConfettiBurst = ConfettiBurst,
}
end

__defs["effects"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local loadCanvasDraw = _motion.loadCanvasDraw
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local Text = __load("ui").Text
local POP_SECONDS = 1.15
local function Pop(_param)
	local pop = _param.pop
	local clock = useClock(true, 1, 1000, true)
	local size = if pop.critical then 30 else 22
	local travel = if pop.critical then 190 else 140
	local rise = clock:map(function(seconds)
		local progress = easeOutCubic(math.clamp(seconds / POP_SECONDS, 0, 1))
		return UDim2.new(0.5, pop.offset, 1, -70 - math.floor(progress * travel))
	end)
	local fade = clock:map(function(seconds)
		return math.clamp((seconds - 0.5) / 0.6, 0, 1)
	end)
	local scale = clock:map(function(seconds)
		return 0.72 + easeOutBack(math.clamp(seconds / 0.2, 0, 1)) * 0.28
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(240, 40),
		Position = rise,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 150,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 150,
	}, React.createElement(Text, {
		value = pop.text,
		size = size,
		color = pop.color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		transparency = fade,
		zIndex = 151,
	}), pop.critical and React.createElement(Text, {
		value = "CRITICAL",
		size = 11,
		color = lighten(pop.color, 0.4),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		transparency = fade,
		zIndex = 151,
	})))
end
local function EffectLayer(_param)
	local pops = _param.pops
	local antilag = useAntilag()
	local max = math.max(1, math.min(antilag.maxPops, math.floor(12 * antilag.fxBudget)))
	local _result
	if #pops > max then
		local _newValue = {}
		local _callback = function(_, index)
			return index >= #pops - max
		end
		local _length = 0
		for _k, _v in pops do
			if _callback(_v, _k - 1, pops) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		_result = _newValue
	else
		_result = pops
	end
	local visible = _result
	local _newValue = table.create(#visible)
	local _callback = function(pop)
		return React.createElement(Pop, {
			key = pop.id,
			pop = pop,
		})
	end
	for _k, _v in visible do
		_newValue[_k] = _callback(_v, _k - 1, visible)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 150,
		Active = false,
		ClipsDescendants = true,
	}, _newValue)
end
local STARS = { {
	x = 0.08,
	y = 0.18,
	size = 2,
	phase = 0.4,
}, {
	x = 0.17,
	y = 0.72,
	size = 3,
	phase = 2.1,
}, {
	x = 0.31,
	y = 0.34,
	size = 2,
	phase = 4.0,
}, {
	x = 0.44,
	y = 0.86,
	size = 2,
	phase = 1.3,
}, {
	x = 0.58,
	y = 0.22,
	size = 3,
	phase = 5.2,
}, {
	x = 0.69,
	y = 0.62,
	size = 2,
	phase = 3.1,
}, {
	x = 0.79,
	y = 0.14,
	size = 2,
	phase = 0.9,
}, {
	x = 0.88,
	y = 0.78,
	size = 3,
	phase = 2.7,
}, {
	x = 0.94,
	y = 0.42,
	size = 2,
	phase = 4.6,
}, {
	x = 0.24,
	y = 0.52,
	size = 2,
	phase = 5.8,
}, {
	x = 0.52,
	y = 0.48,
	size = 2,
	phase = 1.7,
}, {
	x = 0.12,
	y = 0.9,
	size = 2,
	phase = 3.4,
} }
local function StarField(_param)
	local accent = _param.accent
	local antilag = useAntilag()
	local enabled = antilag.tier > 0 and antilag.maxStars > 0 and antilag.allowAmbient
	local clock = useClock(enabled, if antilag.constrained then 0.7 else 1.1)
	local starCap = antilag.maxStars
	local budgeted = math.clamp(math.floor(#STARS * antilag.fxBudget), 0, #STARS)
	local count = if enabled then math.clamp(math.min(budgeted, starCap), 0, #STARS) else 0
	if count <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			ClipsDescendants = true,
		})
	end
	local glow = antilag.glowScale
	local children = table.create(count)
	for index = 0, count - 1 do
		local star = STARS[index + 1]
		children[index + 1] = React.createElement("frame", {
			key = index,
			Size = UDim2.fromOffset(star.size, star.size),
			Position = UDim2.fromScale(star.x, star.y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 3 == 0 then accent else Palette.creamSoft,
			BackgroundTransparency = clock:map(function(phase)
				return 0.62 + math.sin(phase + star.phase) * 0.3 * glow
			end),
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, children)
end
local ENERGY_FIELD_RESOLUTION = Vector2.new(48, 28)
local function CanvasEnergyField(_param)
	local time = _param.time
	local enabled = _param.enabled
	local reducedMotion = _param.reducedMotion
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 712
	end
	local host = React.useRef()
	local renderCanvas = React.useRef(enabled and not reducedMotion).current
	React.useEffect(function()
		if not renderCanvas or host.current == nil then
			return nil
		end
		local module = loadCanvasDraw()
		if module == nil then
			return nil
		end
		local canvas = module.new(host.current, ENERGY_FIELD_RESOLUTION, Palette.void, false)
		canvas.AutoUpdate = false
		canvas.OutputWarnings = false
		local center = Vector2.new((ENERGY_FIELD_RESOLUTION.X + 1) * 0.5, (ENERGY_FIELD_RESOLUTION.Y + 1) * 0.5)
		do
			local y = 1
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					y += 1
				else
					_shouldIncrement = true
				end
				if not (y <= ENERGY_FIELD_RESOLUTION.Y) then
					break
				end
				do
					local x = 1
					local _shouldIncrement_1 = false
					while true do
						if _shouldIncrement_1 then
							x += 1
						else
							_shouldIncrement_1 = true
						end
						if not (x <= ENERGY_FIELD_RESOLUTION.X) then
							break
						end
						local dx = (x - center.X) / ENERGY_FIELD_RESOLUTION.X
						local dy = (y - center.Y) / ENERGY_FIELD_RESOLUTION.Y
						local distance = math.sqrt(dx * dx + dy * dy)
						local ribbon = math.max(0, 1 - math.abs(distance - 0.23) * 13)
						local cross = math.max(0, 1 - math.abs(dx * 0.65 + dy) * 18) * math.max(0, 1 - distance * 2.2)
						local energy = math.clamp(ribbon * 0.42 + cross * 0.28, 0, 1)
						canvas:SetPixel(x, y, darken(Palette.violet:Lerp(Palette.cyan, math.clamp(x / ENERGY_FIELD_RESOLUTION.X, 0, 1)), 0.86 - energy * 0.28))
					end
				end
			end
		end
		canvas:DrawCircle(center, 7, darken(Palette.pink, 0.36), false)
		canvas:DrawCircle(center, 11, darken(Palette.cyan, 0.54), false)
		canvas:DrawLine(Vector2.new(7, 22), Vector2.new(41, 6), darken(Palette.violet, 0.42), 1)
		canvas:Update()
		return function()
			return canvas:DestroyCanvas()
		end
	end, { renderCanvas })
	return React.createElement("frame", {
		ref = host,
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = time:map(function(value)
			return if reducedMotion then 0 else value * -3.4
		end),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
end
return {
	EffectLayer = EffectLayer,
	StarField = StarField,
	CanvasEnergyField = CanvasEnergyField,
	POP_SECONDS = POP_SECONDS,
}
end

__defs["levelRoadmap"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber

local UNIT = 4
local ROW_H = 54
local TIER_H = 44
local RAIL_X = 14
local TEXT_X = 40

local TIER_ACCENT_KEYS = {
	Beginner = "mint",
	Apprentice = "cyan",
	Journeyman = "blue",
	Expert = "violet",
	Master = "mango",
	Legend = "pink",
}

local function tierAccent(tier)
	local key = if type(tier) == "string" then TIER_ACCENT_KEYS[tier] else nil
	return if key ~= nil then Palette[key] else Palette.cyan
end

local function featureNames(state, ids)
	local names = {}
	if type(ids) ~= "table" then
		return names
	end
	local unlocks = if state ~= nil then state.FeatureUnlocks else nil
	for _, id in ids do
		local row = if type(unlocks) == "table" then unlocks[id] else nil
		table.insert(names, if type(row) == "table" and type(row.Name) == "string" then row.Name else tostring(id))
	end
	return names
end

local function joinNames(names)
	local count = #names
	if count == 0 then
		return ""
	elseif count == 1 then
		return names[1]
	end
	return table.concat(names, ", ", 1, count - 1) .. " and " .. names[count]
end

local function readLevelState(state)
	local levelState = if state ~= nil then state.Level else nil
	if type(levelState) ~= "table" then
		return 1, "Beginner", nil
	end
	local level = if type(levelState.Level) == "number" then math.max(1, math.floor(levelState.Level)) else 1
	local tier = if type(levelState.Tier) == "string" then levelState.Tier else "Beginner"
	local nextStep = if type(levelState.Next) == "table" then levelState.Next else nil
	return level, tier, nextStep
end

local function progressText(nextStep)
	return `{compactNumber(nextStep.Progress)} / {compactNumber(nextStep.Target)}`
end

local function progressFraction(nextStep)
	if nextStep == nil then
		return 1
	end
	return math.clamp((tonumber(nextStep.Progress) or 0) / math.max(1, tonumber(nextStep.Target) or 1), 0, 1)
end

local function Track(props)
	return React.createElement("frame", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromScale(math.clamp(props.value, 0, 1), 1),
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end

local function TierHeading(_param)
	return React.createElement("frame", {
		Size = UDim2.new(1, -UNIT * 2, 0, TIER_H),
		Position = UDim2.fromOffset(0, _param.y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 476,
	}, React.createElement(Text, {
		value = string.upper(_param.tier),
		size = 11,
		color = tierAccent(_param.tier),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(TEXT_X, 12),
		sizeConstraint = UDim2.new(1, -TEXT_X, 0, 14),
		zIndex = 477,
	}), _param.blurb ~= "" and React.createElement(Text, {
		value = _param.blurb,
		size = 11,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(TEXT_X, 27),
		sizeConstraint = UDim2.new(1, -TEXT_X, 0, 14),
		zIndex = 477,
	}))
end

local function RailNode(_param)
	local status = _param.status
	local accent = _param.accent
	local here = status == "here"
	local reached = status == "done" or here
	local size = if here then 12 else 8
	return React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(RAIL_X, _param.centerY),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = if here then accent elseif reached then Palette.creamSoft else Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 478,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), not reached and React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if status == "next" then Palette.creamSoft else Palette.lineSoft,
		Thickness = 1.5,
	}))
end

local function LevelRow(_param)
	local def = _param.def
	local status = _param.status
	local nextStep = _param.nextStep
	local y = _param.y
	local accent = _param.accent
	local here = status == "here"
	local isNext = status == "next"
	local ahead = status == "ahead"
	local rightW = _param.rightW
	local goalText = if def.Goal ~= nil and type(def.Goal.Text) == "string" then def.Goal.Text else "Where every forge starts"
	local detail = if _param.opens ~= "" then `Level {def.Level} · Opens {_param.opens}` else `Level {def.Level}`
	if def.Level > 1 and status ~= "done" and not here then
		local LevelRewards = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("LevelRewards")
		local reward = LevelRewards.forLevel(def.Level, def.Tier)
		detail ..= string.format(" · +%d stardust, Surge ×%.2f", reward.Stardust, reward.SurgeMultiplier)
	end
	local rightText = if here then "Current" elseif isNext and nextStep ~= nil then progressText(nextStep) else ""
	return React.createElement("frame", {
		Size = UDim2.new(1, -UNIT * 2, 0, ROW_H),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 476,
	}, React.createElement(RailNode, {
		status = status,
		accent = accent,
		centerY = 17,
	}), React.createElement(Text, {
		value = goalText,
		size = 14,
		color = if ahead then Palette.creamSoft else Palette.cream,
		weight = if here or isNext then Enum.FontWeight.Bold else Enum.FontWeight.Medium,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(TEXT_X, 8),
		sizeConstraint = UDim2.new(1, -(TEXT_X + rightW + UNIT * 3), 0, 18),
		zIndex = 477,
	}), React.createElement(Text, {
		value = detail,
		size = 11,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(TEXT_X, 28),
		sizeConstraint = UDim2.new(1, -(TEXT_X + rightW + UNIT * 3), 0, 14),
		zIndex = 477,
	}), rightText ~= "" and React.createElement(Text, {
		value = rightText,
		size = 11,
		color = if here then accent else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -rightW, 0, 9),
		sizeConstraint = UDim2.fromOffset(rightW, 14),
		zIndex = 477,
	}), isNext and nextStep ~= nil and React.createElement(Track, {
		value = progressFraction(nextStep),
		color = accent,
		size = UDim2.fromOffset(rightW, 3),
		position = UDim2.new(1, -rightW, 0, 30),
		zIndex = 477,
	}))
end

local function LevelRoadmap(_param)
	local cardRef = React.useRef(nil)
	local parentSize = useGuiSize(cardRef, true)
	local state = _param.state
	local config = _param.config
	local onClose = _param.onClose
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local compact = chrome.stack or viewport.width < 620 or viewport.height < 560

	local level, tier, nextStep = readLevelState(state)
	local ladder = if config ~= nil and type(config.Levels) == "table" then config.Levels else {}
	local blurbs = if config ~= nil and type(config.LevelTierBlurbs) == "table" then config.LevelTierBlurbs else {}
	local maxLevel = #ladder
	local accent = tierAccent(tier)

	React.useEffect(function()
		Audio:play("modalOpen")
	end, {})
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local close = React.useCallback(function()
		if closing then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
		return nil
	end, { beginExit, closing, onClose })
	React.useEffect(function()
		local actionName = "AstralForgeLevelRoadmapClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2400, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { close })
	local padFocus = useGamepadAutofocus(true)
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
		local host = padFocus.current
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

	local side = chrome.sideSafe + UNIT * 4
	local width = math.min(viewport.width - side * 2, 600)
	local safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - UNIT * 4)
	local height = math.min(if compact then 580 else 640, safeHeight)
	local pad = if compact then UNIT * 4 else UNIT * 6
	local headerH = if nextStep ~= nil then 132 else 104
	local listTop = headerH + UNIT * 3
	local listH = math.max(60, height - pad * 2 - listTop)
	local rightW = if compact then 64 else 88

	local rows = {}
	local y = 0
	local focusY = 0
	local firstNodeY: number? = nil
	local lastNodeY = 0
	local reachedNodeY = 0
	local lastTier = nil
	for _, def in ladder do
		if def.Tier ~= lastTier then
			lastTier = def.Tier
			rows[`Tier_{def.Tier}`] = React.createElement(TierHeading, {
				tier = def.Tier,
				blurb = blurbs[def.Tier] or "",
				y = y,
			})
			y += TIER_H
		end
		local nodeY = y + 17
		if firstNodeY == nil then
			firstNodeY = nodeY
		end
		lastNodeY = nodeY
		if def.Level <= level then
			reachedNodeY = nodeY
		end
		if def.Level == level then
			focusY = y
		end
		local status = if def.Level < level then "done" elseif def.Level == level then "here" elseif def.Level == level + 1 then "next" else "ahead"
		rows[`Level_{def.Level}`] = React.createElement(LevelRow, {
			def = def,
			status = status,
			opens = joinNames(featureNames(state, def.Unlocks)),
			nextStep = if status == "next" then nextStep else nil,
			accent = accent,
			rightW = rightW,
			y = y,
		})
		y += ROW_H
	end
	local canvasH = y + UNIT * 2
	local railTop = firstNodeY or 0
	rows.Rail = React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(RAIL_X, railTop),
		Size = UDim2.fromOffset(2, math.max(0, lastNodeY - railTop)),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 476,
	})
	rows.RailFill = React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(RAIL_X, railTop),
		Size = UDim2.fromOffset(2, math.max(0, reachedNodeY - railTop)),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 477,
	})

	local listRef = React.useRef(nil)
	React.useEffect(function()
		local list = listRef.current
		if list == nil then
			return nil
		end
		list.CanvasPosition = Vector2.new(0, math.max(0, math.min(focusY - TIER_H, canvasH - listH)))
		return nil
	end, {})

	local cardPosition = React.joinBindings({ motion, parentSize }):map(function(values)
		return pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 12)
	end)
	local cardScale = motion:map(function(amount)
		return 0.96 + amount * 0.04
	end)
	local fade = motion:map(function(amount)
		return 1 - amount
	end)
	local opensNext = if nextStep ~= nil then joinNames(featureNames(state, nextStep.Unlocks)) else ""

	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 470,
		Visible = motion:map(function(amount)
			return amount > 0.003
		end),
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = motion:map(function(amount)
			return 1 - amount * 0.6
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 470,
		Event = {
			Activated = function()
				close()
			end,
		},
	}), React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			cardRef.current = node
		end,
		Size = UDim2.fromOffset(width, height),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 471,
		Visible = motion:map(function(amount)
			return amount > 0.002
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 471,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 472,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.35,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		Position = UDim2.fromOffset(pad, pad),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 473,
	}, React.createElement(Text, {
		value = "Forge Level",
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, -(TapTarget + UNIT * 3), 0, 16),
		zIndex = 474,
	}), React.createElement(Text, {
		value = `Level {level}`,
		size = if compact then 24 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 18,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.fromOffset(if compact then 112 else 128, 34),
		zIndex = 474,
	}), React.createElement(Text, {
		value = `{tier}  ·  {level} of {maxLevel}`,
		size = 13,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(if compact then 116 else 134, 28),
		sizeConstraint = UDim2.new(1, -((if compact then 116 else 134) + TapTarget + UNIT * 3), 0, 18),
		zIndex = 474,
	}), React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.panel,
		textColor = Palette.creamSoft,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		position = UDim2.new(1, -TapTarget, 0, 0),
		reducedMotion = softMotion,
		disabled = closing,
	}), nextStep ~= nil and React.createElement(Text, {
		value = nextStep.Text,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(0, 66),
		sizeConstraint = UDim2.new(1, -96, 0, 18),
		zIndex = 474,
	}), nextStep ~= nil and React.createElement(Text, {
		value = progressText(nextStep),
		size = 12,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -92, 0, 67),
		sizeConstraint = UDim2.fromOffset(92, 16),
		zIndex = 474,
	}), React.createElement(Track, {
		value = progressFraction(nextStep),
		color = accent,
		size = UDim2.new(1, 0, 0, 4),
		position = UDim2.fromOffset(0, if nextStep ~= nil then 92 else 66),
		zIndex = 474,
	}), nextStep ~= nil and React.createElement(Text, {
		value = if opensNext ~= "" then `Level {nextStep.Level} opens {opensNext}` else `Next: Level {nextStep.Level}`,
		size = 12,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 104),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 474,
	}), nextStep == nil and React.createElement(Text, {
		value = "Every level reached. This is the top of the forge.",
		size = 12,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 76),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 474,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, headerH),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 474,
	}), React.createElement("scrollingframe", {
		ref = listRef,
		Size = UDim2.new(1, 0, 0, listH),
		Position = UDim2.fromOffset(0, listTop),
		CanvasSize = UDim2.fromOffset(0, canvasH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 475,
	}, rows))))))
end

local openListeners: { [(boolean) -> ()]: boolean } = {}
local roadmapOpen = false

local function setRoadmapOpen(value: boolean)
	if roadmapOpen == value then
		return
	end
	roadmapOpen = value
	for listener in openListeners do
		listener(value)
	end
end

local function openRoadmap()
	setRoadmapOpen(true)
end

local function LevelRoadmapHost(_param)
	local open, setOpen = React.useState(roadmapOpen)
	React.useEffect(function()
		local listener = function(value: boolean)
			setOpen(value)
		end
		openListeners[listener] = true
		setOpen(roadmapOpen)
		return function()
			openListeners[listener] = nil
		end
	end, {})
	if not open then
		return nil
	end
	return React.createElement(LevelRoadmap, {
		state = _param.state,
		config = _param.config,
		reducedMotion = _param.reducedMotion,
		onClose = function()
			setRoadmapOpen(false)
		end,
	})
end

return {
	LevelRoadmap = LevelRoadmap,
	LevelRoadmapHost = LevelRoadmapHost,
	openRoadmap = openRoadmap,
	tierAccent = tierAccent,
	featureNames = featureNames,
	readLevelState = readLevelState,
	joinNames = joinNames,
	progressFraction = progressFraction,
}
end

__defs["CelebrationBurst"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local VectorIconFace = require(script.Parent.ArtKit)("Icon").VectorIconFace
local _motion = require(script.Parent.MotionKit)("motion")
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local MotionTokens = require(script.Parent.MotionKit)("motionTokens")
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local STYLES = { {
	pattern = "AnvilStrike",
	accent = Palette.mango,
	secondary = Palette.cream,
	colors = { Palette.cream, Palette.mango, Palette.coral, Palette.cyan },
	duration = 1.95,
}, {
	pattern = "SparkCrown",
	accent = Palette.coral,
	secondary = Palette.mango,
	colors = { Palette.mango, Palette.coral, Palette.cream, Palette.mint },
	duration = 2.1,
}, {
	pattern = "AstralTemper",
	accent = Palette.violet,
	secondary = Palette.cyan,
	colors = { Palette.cream, Palette.violet, Palette.cyan, Palette.pink },
	duration = 2.2,
}, {
	pattern = "Starfall",
	accent = Palette.cyan,
	secondary = Palette.mint,
	colors = { Palette.white, Palette.cyan, Palette.mint, Palette.violet },
	duration = 2.15,
}, {
	pattern = "ShockRing",
	accent = Palette.mint,
	secondary = Palette.cyan,
	colors = { Palette.mint, Palette.cyan, Palette.cream, Palette.white },
	duration = 1.85,
}, {
	pattern = "HelixLift",
	accent = Palette.violet,
	secondary = Palette.pink,
	colors = { Palette.violet, Palette.pink, Palette.cyan, Palette.cream },
	duration = 2.25,
}, {
	pattern = "EmberWell",
	accent = Palette.coral,
	secondary = Palette.mango,
	colors = { Palette.coral, Palette.mango, Palette.cream, Palette.pink },
	duration = 2.05,
}, {
	pattern = "CoinBurst",
	accent = Palette.mango,
	secondary = Palette.cream,
	colors = { Palette.mango, Palette.cream, Palette.white, Palette.cyan },
	duration = 1.9,
}, {
	pattern = "LatticeCrack",
	accent = Palette.cyan,
	secondary = Palette.violet,
	colors = { Palette.cyan, Palette.violet, Palette.mint, Palette.cream },
	duration = 2.0,
}, {
	pattern = "NovaPulse",
	accent = Palette.white,
	secondary = Palette.cyan,
	colors = { Palette.white, Palette.cyan, Palette.mint, Palette.violet },
	duration = 1.8,
}, {
	pattern = "DriftMotes",
	accent = Palette.mint,
	secondary = Palette.cream,
	colors = { Palette.mint, Palette.cream, Palette.cyan, Palette.violet },
	duration = 2.3,
}, {
	pattern = "HammerArc",
	accent = Palette.mango,
	secondary = Palette.coral,
	colors = { Palette.mango, Palette.coral, Palette.cream, Palette.violet },
	duration = 1.88,
}, {
	pattern = "PrismSplit",
	accent = Palette.pink,
	secondary = Palette.cyan,
	colors = { Palette.pink, Palette.cyan, Palette.mango, Palette.mint },
	duration = 2.12,
}, {
	pattern = "VortexPull",
	accent = Palette.violet,
	secondary = Palette.mint,
	colors = { Palette.violet, Palette.mint, Palette.cyan, Palette.cream },
	duration = 2.08,
}, {
	pattern = "RibbonLash",
	accent = Palette.coral,
	secondary = Palette.pink,
	colors = { Palette.coral, Palette.pink, Palette.mango, Palette.cream },
	duration = 1.92,
}, {
	pattern = "OrbitBeads",
	accent = Palette.cyan,
	secondary = Palette.mango,
	colors = { Palette.cyan, Palette.mango, Palette.white, Palette.violet },
	duration = 2.18,
}, {
	pattern = "TideWash",
	accent = Palette.mint,
	secondary = Palette.blue,
	colors = { Palette.mint, Palette.cyan, Palette.blue, Palette.cream },
	duration = 2.05,
}, {
	pattern = "FlintSpray",
	accent = Palette.mango,
	secondary = Palette.white,
	colors = { Palette.mango, Palette.white, Palette.coral, Palette.cyan },
	duration = 1.78,
}, {
	pattern = "CrownFlare",
	accent = Palette.cream,
	secondary = Palette.mango,
	colors = { Palette.cream, Palette.mango, Palette.pink, Palette.violet },
	duration = 2.0,
}, {
	pattern = "PulseGrid",
	accent = Palette.cyan,
	secondary = Palette.mint,
	colors = { Palette.cyan, Palette.mint, Palette.white, Palette.violet },
	duration = 1.94,
} }
local MAX_PARTICLES = 18
local MINIMAL_DURATION = 1.05
local function noise(seed, index, salt)
	local raw = math.sin(seed * 0.019 + (index + 1) * 12.9898 + salt * 78.233) * 43758.5453
	return raw - math.floor(raw)
end
local function easeOutCubic(value)
	return MotionTokens.EASE.decelerate(math.clamp(value, 0, 1))
end
local function easeOutBack(value)
	local overshoot = 1.55
	local shifted = math.clamp(value, 0, 1) - 1
	return 1 + (overshoot + 1) * shifted * shifted * shifted + overshoot * shifted * shifted
end
local function styleForSeed(seed)
	return STYLES[math.abs(math.floor(seed)) % #STYLES + 1]
end
local function shapeForRoll(roll)
	if roll < 0.28 then
		return "Spark"
	end
	if roll < 0.46 then
		return "Star"
	end
	if roll < 0.62 then
		return "Shard"
	end
	if roll < 0.76 then
		return "Ember"
	end
	if roll < 0.88 then
		return "Coin"
	end
	return "Needle"
end
local function makeParticles(seed, style)
	local particles = {}
	for index = 0, MAX_PARTICLES - 1 do
		local _arg0 = {
			shape = shapeForRoll(noise(seed, index, 1)),
			lane = noise(seed, index, 2) * 2 - 1,
			phase = noise(seed, index, 3) * math.pi * 2,
			energy = noise(seed, index, 4),
			delay = noise(seed, index, 5) * 0.1 + (index % 4) * 0.018,
			size = 5 + math.floor(noise(seed, index, 6) * 6),
			spin = (noise(seed, index, 7) * 2 - 1) * (280 + noise(seed, index, 8) * 520),
			color = style.colors[index % #style.colors + 1],
		}
		table.insert(particles, _arg0)
	end
	return particles
end
local function positionFor(pattern, particle, progress, index)
	local travel = easeOutCubic(progress)
	if pattern == "SparkCrown" then
		local spread = particle.lane * (0.12 + travel * (0.35 + particle.energy * 0.16))
		local lift = progress * (0.72 + particle.energy * 0.34)
		local gravity = progress * progress * (0.42 + particle.energy * 0.24)
		return UDim2.fromScale(0.5 + spread + math.sin(progress * 8 + particle.phase) * 0.012, 0.58 - lift + gravity)
	end
	if pattern == "AstralTemper" or pattern == "OrbitBeads" or pattern == "VortexPull" then
		local direction = if index % 2 == 0 then 1 else -1
		local spin = if pattern == "VortexPull" then -1.8 else 1.1
		local angle = particle.phase + progress * direction * (spin + particle.energy * 0.9)
		local radius = if pattern == "VortexPull" then 0.32 - travel * (0.22 + particle.energy * 0.1) else 0.035 + travel * (0.28 + particle.energy * 0.2)
		return UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.54 + math.sin(angle) * radius * 0.72 - progress * 0.05)
	end
	if pattern == "Starfall" or pattern == "DriftMotes" or pattern == "TideWash" then
		local drift = if pattern == "TideWash" then math.sin(progress * 3 + particle.phase) * 0.08 else 0
		local x = 0.5 + particle.lane * 0.5 + math.sin(progress * 7 + particle.phase) * (0.01 + particle.energy * 0.018) + drift
		local y = -0.06 - particle.energy * 0.12 + progress * (0.82 + particle.energy * 0.28)
		return UDim2.fromScale(x, y)
	end
	if pattern == "HelixLift" or pattern == "CrownFlare" then
		local angle = particle.phase + progress * 4.2
		local radius = 0.04 + (1 - progress) * (0.22 + particle.energy * 0.12)
		return UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.62 - travel * (0.42 + particle.energy * 0.18))
	end
	if pattern == "EmberWell" or pattern == "FlintSpray" then
		local spread = particle.lane * (0.08 + travel * 0.4)
		return UDim2.fromScale(0.5 + spread, 0.62 - travel * 0.18 + progress * progress * 0.38)
	end
	if pattern == "CoinBurst" or pattern == "NovaPulse" or pattern == "ShockRing" or pattern == "PulseGrid" then
		local angle = particle.phase + (if pattern == "PulseGrid" then math.floor(index / 4) * 0.4 else 0)
		local distance = travel * (0.18 + particle.energy * 0.28)
		return UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.5 + math.sin(angle) * distance * 0.7)
	end
	if pattern == "HammerArc" or pattern == "RibbonLash" then
		local arc = -0.9 + travel * 1.8
		return UDim2.fromScale(0.5 + particle.lane * 0.28 + math.cos(arc) * 0.16, 0.48 + math.sin(arc) * 0.22 + progress * 0.12)
	end
	if pattern == "PrismSplit" or pattern == "LatticeCrack" then
		local col = (index % 5) - 2
		local row = math.floor(index / 5) - 1
		return UDim2.fromScale(0.5 + col * 0.07 * travel, 0.48 + row * 0.08 * travel + progress * 0.06)
	end
	local angle = -math.pi + (particle.phase / (math.pi * 2)) * math.pi
	local distance = travel * (0.26 + particle.energy * 0.32)
	local x = 0.5 + math.cos(angle) * distance
	local y = 0.55 + math.sin(angle) * distance * 0.82 + progress * progress * (0.12 + particle.energy * 0.08)
	return UDim2.fromScale(x, y)
end
local function sizeFor(shape, base, progress)
	local arrival = math.clamp(progress / 0.08, 0, 1)
	local pulse = 0.9 + math.sin(progress * math.pi * 5) * 0.1
	if shape == "Spark" then
		return UDim2.fromOffset(math.max(1, base * (3.3 - progress * 1.5) * arrival), math.max(2, base * 0.3 * arrival))
	end
	if shape == "Star" then
		return UDim2.fromOffset(math.max(1, base * 1.25 * pulse * arrival), math.max(1, base * 1.25 * pulse * arrival))
	end
	if shape == "Shard" then
		return UDim2.fromOffset(math.max(1, base * 0.72 * arrival), math.max(1, base * 1.45 * arrival))
	end
	return UDim2.fromOffset(math.max(1, base * 0.72 * pulse * arrival), math.max(1, base * 0.72 * pulse * arrival))
end
local function ForgeParticle(_param)
	local style = _param.style
	local particle = _param.particle
	local index = _param.index
	local time = _param.time
	local duration = _param.duration
	local detailed = _param.detailed
	local motion = time:map(function(seconds)
		local progress = math.clamp((seconds - particle.delay) / math.max(0.2, duration - 0.2 - particle.delay), 0, 1)
		local arrival = MotionTokens.EASE.decelerate(math.clamp(progress / 0.07, 0, 1))
		local departure = MotionTokens.EASE.accelerate(math.clamp((progress - 0.68) / 0.32, 0, 1))
		local visibility = arrival * (1 - departure)
		local rotation = if style.pattern == "Starfall" then 24 + particle.lane * 20 + progress * particle.spin * 0.18 else particle.phase * 57.2958 + progress * particle.spin
		return {
			position = positionFor(style.pattern, particle, progress, index),
			rotation = rotation,
			size = sizeFor(particle.shape, particle.size, progress),
			transparency = 1 - visibility,
			glowTransparency = math.clamp(1 - visibility * 0.18, 0.78, 1),
		}
	end)
	local position = motion:map(function(value)
		return value.position
	end)
	local rotation = motion:map(function(value)
		return value.rotation
	end)
	local size = motion:map(function(value)
		return value.size
	end)
	local transparency = motion:map(function(value)
		return value.transparency
	end)
	local glowTransparency = motion:map(function(value)
		return value.glowTransparency
	end)
	local zIndex = 146 + index % 3
	if particle.shape == "Star" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, detailed and React.createElement("frame", {
			Size = UDim2.fromScale(2.2, 2.2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = particle.color,
			BackgroundTransparency = glowTransparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 3),
		})), React.createElement("frame", {
			Size = UDim2.new(0, 2, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(3, 3),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}))
	end
	if particle.shape == "Coin" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = Palette.cream,
			Thickness = 1,
			Transparency = glowTransparency,
		}), React.createElement("frame", {
			Size = UDim2.fromScale(0.42, 0.42),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cream,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})))
	end
	if particle.shape == "Needle" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.white, particle.color),
			Rotation = 90,
		}))
	end
	if particle.shape == "Ember" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, detailed and React.createElement("frame", {
			Size = UDim2.fromScale(2.8, 2.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = glowTransparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})), React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.cream, particle.color),
			Rotation = 90,
		})))
	end
	return React.createElement("frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		BackgroundColor3 = particle.color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = if particle.shape == "Spark" then UDim.new(1, 0) else UDim.new(0, 2),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(particle.color, 0.42), darken(particle.color, 0.25)),
		Rotation = if particle.shape == "Spark" then 0 else 90,
	}), detailed and React.createElement("frame", {
		Size = if particle.shape == "Spark" then UDim2.new(0, 3, 2.4, 0) else UDim2.fromScale(2.1, 2.1),
		Position = if particle.shape == "Spark" then UDim2.fromScale(0.08, 0.5) else UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = particle.color,
		BackgroundTransparency = glowTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex - 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = if particle.shape == "Spark" then UDim2.new(0, 3, 1, 0) else UDim2.new(1, -2, 0, 2),
		Position = if particle.shape == "Spark" then UDim2.fromScale(0.08, 0.5) else UDim2.fromScale(0.5, 0.24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function RewardReceipt(_param)
	local style = _param.style
	local time = _param.time
	local duration = _param.duration
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	local motion = time:map(function(seconds)
		local arrival = math.clamp(seconds / 0.18, 0, 1)
		local departure = math.clamp((seconds - duration * 0.72) / math.max(0.18, duration * 0.25), 0, 1)
		local settle = if reducedMotion then arrival else easeOutBack(arrival)
		return {
			scale = if reducedMotion then 1 else 0.72 + settle * 0.32 - departure * 0.1,
			transparency = math.clamp(1 - arrival + departure, 0, 1),
			rotation = if reducedMotion then 0 else (1 - settle) * -7 + math.sin(arrival * math.pi) * 2,
			y = math.round((1 - settle) * 36 - departure * 40),
		}
	end)
	local receiptW = if compact then 236 else 306
	local receiptH = if compact then 70 else 84
	local transparency = motion:map(function(value)
		return value.transparency
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(receiptW, receiptH),
		Position = motion:map(function(value)
			return UDim2.new(0.5, 0, if compact then 0.16 else 0.2, value.y)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = motion:map(function(value)
			return value.rotation
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 151,
	}, React.createElement(ScaleFromCenter, {
		scale = motion:map(function(value)
			return value.scale
		end),
		zIndex = 151,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 151,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 13),
	}), React.createElement("uistroke", {
		Color = style.accent,
		Thickness = 2,
		Transparency = motion:map(function(value)
			return math.clamp(value.transparency + 0.1, 0, 1)
		end),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(style.accent, 0.74), Palette.panelRaised),
		Rotation = 18,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 48 else 58, if compact then 48 else 58),
		Position = UDim2.fromOffset(if compact then 11 else 13, if compact then 11 else 13),
		BackgroundColor3 = darken(style.accent, 0.5),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 153,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uistroke", {
		Color = style.accent,
		Thickness = 1.5,
		Transparency = motion:map(function(value)
			return math.clamp(value.transparency + 0.16, 0, 1)
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 24 else 30, if compact then 24 else 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 154,
		Visible = motion:map(function(value)
			return value.transparency < 0.98
		end),
	}, React.createElement(VectorIconFace, {
		kind = "Check",
		color = Palette.cream,
		transparency = transparency,
	}))), React.createElement("textlabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "REWARD CLAIMED",
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		TextSize = if compact then 15 else 19,
		TextColor3 = Palette.cream,
		TextTransparency = transparency,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(if compact then 70 else 84, if compact then 10 else 14),
		Size = UDim2.new(1, if compact then -78 else -94, 0, if compact then 22 else 26),
		ZIndex = 154,
	}), React.createElement("textlabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "DELIVERED TO YOUR FORGE",
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		TextSize = 12,
		TextColor3 = style.accent,
		TextTransparency = transparency,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(if compact then 70 else 84, if compact then 34 else 43),
		Size = UDim2.new(1, if compact then -78 else -94, 0, 18),
		ZIndex = 154,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -24, 0, 3),
		Position = UDim2.new(0.5, 0, 1, -7),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 154,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = time:map(function(seconds)
			return UDim2.new(math.clamp(seconds / math.max(0.1, duration), 0, 1), 0, 1, 0)
		end),
		BackgroundColor3 = style.accent,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 155,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))))
end
local function CelebrationBurst(_param)
	local seed = _param.seed
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local particlesEnabled = _param.particlesEnabled
	if particlesEnabled == nil then
		particlesEnabled = true
	end
	local onDone = _param.onDone
	local antilag = useAntilag()
	local viewport = useViewport()
	local style = React.useMemo(function()
		return styleForSeed(seed)
	end, { seed })
	local specs = React.useMemo(function()
		return makeParticles(seed, style)
	end, { seed, style })
	local visible = intensity > 0.02
	local minimal = reducedMotion or not particlesEnabled
	local duration = if minimal then MINIMAL_DURATION else style.duration
	local time = useClock(visible, 1, 1000, true)
	local onDoneRef = React.useRef(onDone)
	onDoneRef.current = onDone
	React.useEffect(function()
		if not visible then
			local completion = task.defer(function()
				return onDoneRef.current(seed)
			end)
			return function()
				pcall(task.cancel, completion)
			end
		end
		local completion = task.delay(duration + 0.06, function()
			return onDoneRef.current(seed)
		end)
		return function()
			pcall(task.cancel, completion)
		end
	end, { duration, seed, visible })
	if not visible then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
		})
	end
	local constrained = antilag.constrained == true or viewport.compact or viewport.tight
	local mobileCap = if constrained then (if antilag.tier <= 1 then 5 else 7) else 12
	local desired = math.floor(MAX_PARTICLES * math.clamp(intensity, 0.12, 1) * math.max(0.4, antilag.fxBudget))
	local budgetCap = if minimal then 0 else math.max(if constrained then 2 else 4, antilag.particleBudget)
	local activeCount = math.clamp(math.min(desired, budgetCap, mobileCap), 0, MAX_PARTICLES)
	local _newValue = {}
	local _callback = function(_, index)
		return index < activeCount
	end
	local _length = 0
	for _k, _v in specs do
		if _callback(_v, _k - 1, specs) == true then
			_length += 1
			_newValue[_length] = _v
		end
	end
	local particles = _newValue
	local detailed = not minimal and not constrained and antilag.quality >= 0.72 and antilag.glowScale >= 0.45 and activeCount <= 10
	local impact = time:map(function(seconds)
		return easeOutBack(math.clamp(seconds / 0.28, 0, 1))
	end)
	local rayCount = if minimal then 0 elseif constrained then (if antilag.quality >= 0.55 then 2 else 0) elseif antilag.quality >= 0.62 then 4 elseif antilag.quality >= 0.28 then 2 else 0
	local rays = if rayCount == 4 then { 0, 90, 180, 270 } elseif rayCount == 2 then { 0, 180 } else {}
	local _newValue_1 = table.create(#rays)
	local _callback_1 = function(angle, index)
		return React.createElement("frame", {
			key = `forge-ray-{angle}`,
			Size = impact:map(function(value)
				return UDim2.fromOffset(value * (if viewport.compact then 72 else 120 + index % 2 * 24), 2)
			end),
			Position = UDim2.fromScale(0.5, if viewport.compact or viewport.tight then 0.16 else 0.2),
			AnchorPoint = Vector2.new(0, 0.5),
			Rotation = angle,
			BackgroundColor3 = if index % 3 == 0 then Palette.cream elseif index % 2 == 0 then style.accent else style.secondary,
			BackgroundTransparency = time:map(function(seconds)
				return math.clamp(0.72 + seconds * 1.8, 0.72, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 142,
		}, React.createElement("uigradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(1, 1) }),
		}))
	end
	for _k, _v in rays do
		_newValue_1[_k] = _callback_1(_v, _k - 1, rays)
	end
	local _exp = { 0, 1 }
	local _newValue_2 = {}
	local _callback_2 = function(ring)
		return not minimal or ring == 0
	end
	local _length_1 = 0
	for _k, _v in _exp do
		if _callback_2(_v, _k - 1, _exp) == true then
			_length_1 += 1
			_newValue_2[_length_1] = _v
		end
	end
	local _newValue_3 = table.create(#_newValue_2)
	local _callback_3 = function(ring)
		return React.createElement("frame", {
			key = `forge-ring-{ring}`,
			Size = impact:map(function(value)
				local delayed = math.clamp((value - ring * 0.14) / math.max(0.01, 1 - ring * 0.14), 0, 1)
				local diameter = (if viewport.compact then 18 else 24) + delayed * ((if viewport.compact then 104 else 152) + ring * (if viewport.compact then 44 else 68))
				return UDim2.fromOffset(diameter, diameter)
			end),
			Position = UDim2.fromScale(0.5, if viewport.compact or viewport.tight then 0.16 else 0.2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 141,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then style.secondary else style.accent,
			Thickness = if minimal then 1 else 1.8 - ring * 0.3,
			Transparency = impact:map(function(value)
				return math.clamp(0.58 + value * 0.42 + ring * 0.06, 0, 1)
			end),
		}))
	end
	for _k, _v in _newValue_2 do
		_newValue_3[_k] = _callback_3(_v, _k - 1, _newValue_2)
	end
	local _exp_1 = React.createElement(RewardReceipt, {
		style = style,
		time = time,
		duration = duration,
		reducedMotion = reducedMotion,
		compact = viewport.compact or viewport.tight,
	})
	local _newValue_4 = table.create(#particles)
	local _callback_4 = function(particle, index)
		return React.createElement(ForgeParticle, {
			key = `{style.pattern}-{index}`,
			style = style,
			particle = particle,
			index = index,
			time = time,
			duration = duration,
			detailed = detailed,
		})
	end
	for _k, _v in particles do
		_newValue_4[_k] = _callback_4(_v, _k - 1, particles)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 140,
		Active = false,
	}, _newValue_1, _newValue_3, _exp_1, _newValue_4)
end
return {
	CelebrationBurst = CelebrationBurst,
}
end

__defs["ComboBadge"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local useGlowStroke = _motion.useGlowStroke
local useOptionalFlipperSpring = _motion.useOptionalFlipperSpring
local usePulse = _motion.usePulse
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local lighten = _theme.lighten
local _ui = __load("ui")
local Stroke = _ui.Stroke
local Text = _ui.Text

local HEAT_STOPS = { Palette.cyan, Palette.pink, Palette.coral, Palette.mango }
local function heatColor(ratio)
	local t = math.clamp(ratio, 0, 1) * (#HEAT_STOPS - 1)
	local index = math.min(#HEAT_STOPS - 2, math.floor(t))
	return HEAT_STOPS[index + 1]:Lerp(HEAT_STOPS[index + 2], t - index)
end
local function DecayRing(_param)
	local accent = _param.accent
	local updatedAt = _param.updatedAt
	local windowSeconds = _param.windowSeconds
	local animate = _param.animate
	local anchorOffset = os.clock() - updatedAt
	local sweep = useClock(animate, 1 / math.max(0.1, windowSeconds), 1, true)
	local remaining = sweep:map(function(raw)
		return math.clamp(1 - ((raw + anchorOffset / windowSeconds) % 1), 0, 1)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = -90,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Transparency = remaining:map(function(fraction)
			local edge = math.clamp(fraction, 0.001, 0.998)
			return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(edge, 0.05), NumberSequenceKeypoint.new(edge + 0.001, 1), NumberSequenceKeypoint.new(1, 1) })
		end),
	})))
end
local function ComboBadge(_param)
	local readout = _param.readout
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local anchorPoint = _param.anchorPoint
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 65
	end
	local antilag = useAntilag()
	local visible, setVisible = React.useState(false)
	React.useEffect(function()
		if readout == nil or readout.combo <= 0 then
			setVisible(false)
			return nil
		end
		setVisible(true)
		local expiresIn = math.max(0.05, readout.comboWindow - (os.clock() - readout.updatedAt)) + readout.comboWindow * 0.35
		local timer = task.delay(expiresIn, function()
			return setVisible(false)
		end)
		return function()
			return task.cancel(timer)
		end
	end, { readout })
	local _result = readout
	if _result ~= nil then
		_result = _result.combo
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local combo = _condition
	local _result_1 = readout
	if _result_1 ~= nil then
		_result_1 = _result_1.comboMax
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 12
	end
	local comboMax = math.max(1, _condition_1)
	local _result_2 = readout
	if _result_2 ~= nil then
		_result_2 = _result_2.comboMultiplier
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 1
	end
	local multiplier = _condition_2
	local ratio = math.clamp(combo / comboMax, 0, 1)
	local maxed = combo >= comboMax
	local accent = heatColor(ratio)
	local everVisible, setEverVisible = React.useState(false)
	React.useEffect(function()
		if visible then
			setEverVisible(true)
		end
	end, { visible })
	local tapPunch, setTapPunch = React.useState(0)
	local lastCombo = React.useRef(0)
	React.useEffect(function()
		if combo > lastCombo.current then
			setTapPunch(function(current)
				return current + 1
			end)
		end
		lastCombo.current = combo
	end, { combo })
	local punch = useFlash(tapPunch, reducedMotion, 0.28)
	local presence = useOptionalFlipperSpring(if visible then 1 else 0, everVisible, reducedMotion, 580, 32)
	local intensitySpring = useOptionalFlipperSpring(ratio, visible, reducedMotion, 380, 28)
	local glow = useGlowStroke(maxed and visible and antilag.allowAmbient, reducedMotion, 0.42, 0.22, 0.5, if maxed then 1.6 else 1.2)
	local maxPulse = usePulse(maxed and visible and not reducedMotion, 1.7)
	local scale = React.useMemo(function()
		return React.joinBindings({ presence, intensitySpring, punch }):map(function(values)
			return 0.72 + values[1] * 0.28 + values[2] * 0.05 + values[3] * 0.14
		end)
	end, { presence, intensitySpring, punch })
	local iconScale = React.useMemo(function()
		return punch:map(function(amount)
			return 1 + amount * 0.28
		end)
	end, { punch })
	local rise = React.useMemo(function()
		return presence:map(function(amount)
			return math.round((1 - amount) * 18)
		end)
	end, { presence })
	local fade = React.useMemo(function()
		return presence:map(function(amount)
			return 1 - amount
		end)
	end, { presence })
	if not everVisible then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(96, 40),
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = presence:map(function(amount)
			return amount > 0.01
		end),
		Visible = presence:map(function(amount)
			return amount > 0.01
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = zIndex,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = rise:map(function(offset)
			return UDim2.fromOffset(0, offset)
		end),
		BackgroundColor3 = darken(accent, 0.58),
		BackgroundTransparency = fade:map(function(amount)
			return math.clamp(0.12 + amount * 0.88, 0, 1)
		end),
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement(Stroke, {
		color = if maxed then Palette.mango else accent,
		thickness = if maxed then 2 else 1.4,
		transparency = if maxed then glow else fade:map(function(amount)
			return math.clamp(0.28 + amount * 0.72, 0, 1)
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = darken(accent, 0.3),
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), not maxed and readout ~= nil and visible and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(-2, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uisizeconstraint", {
		MaxSize = Vector2.new(32, 32),
	}), React.createElement(DecayRing, {
		accent = accent,
		updatedAt = readout.updatedAt,
		windowSeconds = readout.comboWindow,
		animate = not reducedMotion and antilag.allowAmbient,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(ScaleFromCenter, {
		scale = iconScale,
		zIndex = zIndex + 1,
	}, React.createElement(Icon, {
		kind = "Overcharge",
		color = Palette.cream,
		accent = accent,
		size = 17,
		spin = false,
		reducedMotion = reducedMotion,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})))), React.createElement(Text, {
		value = `×{math.floor(combo)}`,
		size = if maxed then 19 else 16,
		color = ensureContrast(darken(accent, 0.58), if maxed then lighten(Palette.mango, 0.3) else Palette.cream),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Left,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(40, 4),
		sizeConstraint = UDim2.new(1, -46, 0, 20),
		transparency = fade,
		zIndex = zIndex + 1,
	}), React.createElement(Text, {
		value = if maxed then "MAXED" else `{string.format("%.2f", multiplier)}x`,
		size = 10,
		color = ensureContrast(darken(accent, 0.58), if maxed then Palette.mango else accent),
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Left,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(40, 22),
		sizeConstraint = UDim2.new(1, -46, 0, 14),
		transparency = fade,
		zIndex = zIndex + 1,
	}), maxed and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = maxPulse:map(function(amount)
			return 0.9 - amount * 0.06
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex - 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})))))
end
return {
	ComboBadge = ComboBadge,
}
end

__defs["FeedbackOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local IconTile = _ui.IconTile
local OverlayPresence = _ui.OverlayPresence
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local CATEGORIES = { "Bug", "Suggestion", "Balance", "Performance", "Interface", "Other" }
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition
local CATEGORY_LABELS = { Suggestion = "IDEA", Performance = "LAG", Interface = "UI" }
local CATEGORY_HINTS = {
	Bug = "What did you do, what did you expect, and what happened instead?",
	Suggestion = "What should we add or change, and why would it be fun?",
	Balance = "What feels too strong, too weak, too slow or too fast?",
	Performance = "Where does it lag or stutter? What were you doing at the time?",
	Interface = "Which screen or button is confusing, clipped or hard to reach?",
	Other = "Anything else on your mind. (8+ characters)",
}
local IMPACT_LABELS = { "Minor", "Noticeable", "Annoying", "Major", "Blocking" }
local function deviceTag()
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Desktop"
end
local function FeedbackOverlay(_param)
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local onClose = _param.onClose
	local notify = _param.notify
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local narrow = viewport.width < 620
	local compact = chrome.stack or narrow or viewport.height < 560
	local keyboardCompact = viewport.keyboardOpen or viewport.height < 240
	local wideShort = not narrow and viewport.height < 560
	local category, setCategory = React.useState("Bug")
	local impact, setImpact = React.useState(0)
	local attachDevice, setAttachDevice = React.useState(true)
	local message, setMessage = React.useState("")
	local sending, setSending = React.useState(false)
	local sent, setSent = React.useState(false)
	local mountedRef = React.useRef(true)
	React.useEffect(function()
		Audio:play("modalOpen")
		return function()
			mountedRef.current = false
		end
	end, {})
	local enter = useEntrance(softMotion)
	local headerReveal = useStagger(0, softMotion)
	local footerReveal = useStagger(1, softMotion)
	local _binding = useExitTransition(softMotion)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local side = chrome.sideSafe + 16
	local width = math.min(if compact then viewport.width - side * 2 else 620, 620)
	local safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - 16)
	local height = math.min(if keyboardCompact then 210 elseif wideShort then 300 elseif compact then 456 else 486, safeHeight)
	local contentHeight = math.max(1, height - 28)
	local headerH = if keyboardCompact then 46 elseif compact then 64 else 72
	local categoryTop = headerH + (if keyboardCompact then 0 else 8)
	local categoryColumns = if narrow then 3 else 6
	local categoryH = if keyboardCompact then 0 elseif categoryColumns == 3 then 96 else 44
	local impactTop = categoryTop + categoryH + 8
	local impactH = if keyboardCompact or sent then 0 elseif narrow then 30 + TapTarget + 4 else 30
	local editorTop = if keyboardCompact then categoryTop + 6 else impactTop + impactH + (if impactH > 0 then 8 else 2)
	local footerH = TapTarget + (if keyboardCompact then 4 else 14)
	local editorH = math.max(44, contentHeight - editorTop - footerH - 8)
	local trimmed = (string.gsub((string.gsub(message, "^%s+", "")), "%s+$", ""))
	local canSend = not sending and not sent and #trimmed >= 8
	local close = React.useCallback(function()
		if closing or sending then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, closing, onClose, sending })
	React.useEffect(function()
		local actionName = "AstralForgeFeedbackClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2400, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { close })
	React.useEffect(function()
		if not sent then
			return nil
		end
		local token = task.delay(2.4, function()
			if mountedRef.current and not closing then
				beginExit(onClose)
			end
		end)
		return function()
			return task.cancel(token)
		end
	end, { beginExit, closing, onClose, sent })
	local submit = React.useCallback(function()
		if not canSend then
			return nil
		end
		setSending(true)
		Audio:play("chatSend")
		local camera = workspace.CurrentCamera
		local viewSize = camera and camera.ViewportSize or Vector2.zero
		dispatch("SubmitFeedback", {
			Category = category,
			Message = trimmed,
			Impact = if impact >= 1 then impact else nil,
			Device = if attachDevice then deviceTag() else nil,
			Screen = if attachDevice then `{math.floor(viewSize.X)}x{math.floor(viewSize.Y)}` else nil,
			Page = if attachDevice and type(_param.page) == "string" then string.sub(_param.page, 1, 32) else nil,
		}, function(response)
			if not mountedRef.current then
				return nil
			end
			setSending(false)
			if not response.ok then
				local _condition = response.error
				if _condition == nil then
					_condition = response.message
					if _condition == nil then
						_condition = "Please try again in a moment."
					end
				end
				notify("Couldn't send feedback", _condition)
				Audio:play("noticeError")
				return nil
			end
			setSent(true)
			Audio:play("feedbackSubmit")
			notify("Feedback sent", "Thanks for helping make the game better.")
		end)
	end, { canSend, category, dispatch, notify, trimmed, impact, attachDevice })
	local padFocus = useGamepadAutofocus(true)
	local overlayHostRef = React.useRef(nil)
	local parentSize = useGuiSize(overlayHostRef, true)
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
	end, { sent })
	local cardTravel = 16
	local cardPosition = React.joinBindings({ motion, parentSize }):map(function(values)
		return pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * cardTravel)
	end)
	local scrimTransparency = motion:map(function(amount)
		return 1 - amount * 0.72
	end)
	local fade = motion:map(function(amount)
		return 1 - amount
	end)
	local cardScale = motion:map(function(amount)
		return 0.92 + amount * 0.08
	end)
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 470,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 471,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	}))
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 472,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if sent then Palette.mint else Palette.cyan,
		Thickness = 2,
		Transparency = motion:map(function(amount)
			return 0.55 - amount * 0.4
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(64, 2),
		Position = UDim2.fromOffset(20, 0),
		BackgroundColor3 = if sent then Palette.mint else Palette.cyan,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
	local _exp_3 = not keyboardCompact and React.createElement(IconTile, {
		kind = if sent then "Check" else "Chat",
		accent = if sent then Palette.mint else Palette.cyan,
		size = if compact then 44 else 50,
		radius = 14,
		filled = sent,
		reveal = headerReveal,
		reducedMotion = softMotion,
		glow = sent and not softMotion,
	})
	local _exp_4 = not keyboardCompact and React.createElement(Text, {
		value = if sent then "THANK YOU" else "FEEDBACK",
		size = 11,
		color = if sent then Palette.mint else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if compact then 56 else 62, 0),
		sizeConstraint = UDim2.new(1, -116, 0, 16),
		zIndex = 474,
		transparency = headerReveal:map(function(amount)
			return 1 - amount
		end),
	})
	local _exp_5 = React.createElement(Text, {
		value = if sent then "Got it. Thanks." elseif keyboardCompact then "Send feedback" else "What's bugging you?",
		size = if keyboardCompact then 18 elseif compact then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 15,
		position = UDim2.fromOffset(if keyboardCompact then 0 elseif compact then 56 else 62, if keyboardCompact then 3 else 18),
		sizeConstraint = UDim2.new(1, if keyboardCompact then -(TapTarget + 10) else -116, 0, 28),
		zIndex = 474,
	})
	local _exp_6 = React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.ink,
		textColor = Palette.coral,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		position = UDim2.new(1, -TapTarget, 0, 0),
		reducedMotion = softMotion,
		disabled = sending or closing,
	})
	local _condition = not sent and not keyboardCompact
	if _condition then
		local _attributes = {}
		local _newValue = table.create(#CATEGORIES)
		local _callback = function(choice)
			return {
				id = choice,
				label = CATEGORY_LABELS[choice] or string.upper(choice),
				accent = Palette.cyan,
			}
		end
		for _k, _v in CATEGORIES do
			_newValue[_k] = _callback(_v, _k - 1, CATEGORIES)
		end
		_attributes.options = _newValue
		_attributes.value = category
		_attributes.onChange = function(id)
			return setCategory(id)
		end
		_attributes.accent = Palette.cyan
		_attributes.sound = "tabSwitch"
		_attributes.columns = categoryColumns
		_attributes.gap = 6
		_attributes.size = UDim2.fromScale(1, 1)
		_attributes.reducedMotion = softMotion
		_attributes.zIndex = 475
		_condition = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, categoryH),
			Position = UDim2.fromOffset(0, categoryTop),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 474,
		}, React.createElement(SegmentedTabs, _attributes))
	end
	local impactRow = nil
	if impactH > 0 then
		local impactAccent = if impact >= 4 then Palette.coral elseif impact >= 2 then Palette.mango else Palette.cyan
		local pips = {
			layout = React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for level = 1, 5 do
			local lit = impact >= level
			pips["pip" .. level] = React.createElement("textbutton", {
				Name = "Impact" .. level,
				LayoutOrder = level,
				Size = UDim2.fromOffset(if narrow then math.min(TapTarget, (width - 28 - 16) / 5) else 28, if narrow then TapTarget else 30),
				BackgroundColor3 = if lit then impactAccent else Palette.ink,
				BackgroundTransparency = if lit then 0.05 else 0.2,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 476,
				Event = {
					Activated = function()
						setImpact(if impact == level then 0 else level)
						Audio:play(if impact == level then "favoriteOff" else "ratingStar")
					end,
				},
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 5),
			}), React.createElement("uistroke", {
				Color = if lit then impactAccent else Palette.lineSoft,
				Transparency = if lit then 0.2 else 0.55,
			}), React.createElement(Text, {
				value = tostring(level),
				size = 13,
				color = if lit then Palette.ink else Palette.creamSoft,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 477,
			}))
		end
		impactRow = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, impactH),
			Position = UDim2.fromOffset(0, impactTop),
			BackgroundTransparency = 1,
			ZIndex = 474,
		}, React.createElement(Text, {
			value = if impact >= 1 then `IMPACT · {string.upper(IMPACT_LABELS[impact])}` else "IMPACT · OPTIONAL",
			size = 11,
			color = if impact >= 1 then impactAccent else Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(0, 7),
			sizeConstraint = UDim2.new(0, if narrow then 120 else 170, 0, 16),
			zIndex = 475,
		}), React.createElement("frame", {
			Size = if narrow then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 160, 1, 0),
			Position = if narrow then UDim2.fromOffset(0, 30 + 4) else UDim2.fromOffset(170, 0),
			BackgroundTransparency = 1,
			ZIndex = 475,
		}, pips), React.createElement("textbutton", {
			Size = UDim2.fromOffset(if narrow then 92 else 150, 30),
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 475,
			Event = {
				Activated = function()
					setAttachDevice(not attachDevice)
					Audio:play(if attachDevice then "toggleOff" else "toggleOn")
				end,
			},
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = if attachDevice then Palette.cyan else Palette.ink,
			BorderSizePixel = 0,
			ZIndex = 476,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 5),
		}), React.createElement("uistroke", {
			Color = Palette.cyan,
			Transparency = 0.35,
		})), React.createElement(Text, {
			value = if narrow then "Device info" else "Attach device info",
			size = 11,
			color = if attachDevice then Palette.creamSoft else Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(22, 7),
			sizeConstraint = UDim2.new(1, -22, 0, 16),
			zIndex = 476,
		})))
	end
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 470,
		Visible = motion:map(function(amount)
			return amount > 0.003
		end),
	}, _exp, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromOffset(width, height),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 471,
		Visible = motion:map(function(amount)
			return amount > 0.002
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 471,
	}, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, -32, 1, -28),
		Position = UDim2.fromOffset(16, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 473,
	}, _exp_3, _exp_4, _exp_5, _exp_6, _condition, impactRow, not sent and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, editorH),
		Position = UDim2.fromOffset(0, editorTop),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 474,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.45,
	}), React.createElement("textbox", {
		Size = UDim2.new(1, -24, 1, -38),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = message,
		PlaceholderText = CATEGORY_HINTS[category] or "What happened, or what should we add? (8+ characters)",
		PlaceholderColor3 = Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 15,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MultiLine = true,
		ClearTextOnFocus = false,
		TextEditable = not sending,
		MaxVisibleGraphemes = 600,
		ZIndex = 475,
		Change = {
			Text = function(box)
				local message = string.sub(box.Text, 1, 600)
				local _, brokenAt = utf8.len(message)
				return setMessage(if brokenAt then string.sub(message, 1, brokenAt - 1) else message)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}), React.createElement(Text, {
		value = if #trimmed < 8 then `{math.max(0, 8 - #trimmed)} more to send  ·  {#message} / 600` else `{#message} / 600`,
		size = 11,
		color = if #trimmed < 8 then Palette.mango elseif #message >= 580 then Palette.mango else Palette.muted,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(0, 12, 1, -26),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
		zIndex = 475,
	})), if sent then React.createElement(Button, {
		text = "DONE",
		icon = "Check",
		onClick = close,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = footerReveal:map(function(amount)
			return UDim2.new(0, 0, 1, -TapTarget + math.round((1 - amount) * 10))
		end),
		reducedMotion = softMotion,
		highlight = true,
	}) else React.createElement(Button, {
		text = if sending then "SENDING..." elseif #trimmed < 8 then "WRITE A LITTLE MORE" else "SEND FEEDBACK",
		icon = "Send",
		onClick = submit,
		color = if canSend then Palette.cyan else Palette.panelSoft,
		textColor = if canSend then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = footerReveal:map(function(amount)
			return UDim2.new(0, 0, 1, -TapTarget + math.round((1 - amount) * 10))
		end),
		disabled = not canSend,
		reducedMotion = softMotion,
		highlight = canSend and not softMotion,
	}))))))
end
return {
	FeedbackOverlay = FeedbackOverlay,
}
end

__defs["MobileShell"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _motion = require(script.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _appNav = require(script.Parent.CoreKit)("appNav")
local AppHelpers = _appNav.AppHelpers
local MORE_NAV = _appNav.MORE_NAV
local PRIMARY_NAV = _appNav.PRIMARY_NAV
local NAV_GROUPS = _appNav.NAV_GROUPS
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local CountBadge = _ui.CountBadge
local IconTile = _ui.IconTile
local SearchField = _ui.SearchField
local Text = _ui.Text
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local Audio = require(script.Parent.AudioKit)("audio").Audio
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber

local SHEET_SWIPE_CLOSE = 90
local OVERCHARGE_REPEAT = 0.11

local function allNav(state, tutorialPage)
	local list = {}
	for _, entry in PRIMARY_NAV do
		table.insert(list, entry)
	end
	for _, entry in MORE_NAV do
		table.insert(list, entry)
	end
	return AppHelpers:filterNav(list, state, tutorialPage)
end

local function TabButton(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local badge = _param.badge or 0
	local reducedMotion = _param.reducedMotion
	local accent = entry.accent or Palette.cyan
	local pressed, setPressed = React.useState(false)
	local selection = useFlipperSpring(if active then 1 else 0, reducedMotion, 620, 38)
	local press = useFlipperSpring(if pressed then 1 else 0, reducedMotion, 1100, 44)
	local compactLabel = _param.compact == true
	return React.createElement("imagebutton", {
		Name = "Nav_" .. entry.id,
		Size = _param.size,
		LayoutOrder = _param.order,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = true,
		ZIndex = 41,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				InteractionFeedback.tap()
				onClick()
			end,
			InputBegan = function(_, input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					setPressed(true)
				end
			end,
			InputEnded = function()
				setPressed(false)
			end,
			MouseLeave = function()
				setPressed(false)
			end,
		},
	}, React.createElement("uiscale", {
		Scale = press:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.06
		end),
	}), React.createElement("frame", {
		Size = selection:map(function(amount)
			local t = math.clamp(amount, 0, 1)
			return UDim2.fromOffset(math.round(28 + 22 * t), 28)
		end),
		Position = UDim2.new(0.5, 0, 0, if compactLabel then 3 else 5),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = darken(accent, 0.5),
		BackgroundTransparency = selection:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.85
		end),
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0.5, 0, 0, if compactLabel then 5 else 7),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 43,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = if active then Palette.cream else Palette.creamSoft,
		accent = if active then accent else Palette.muted,
		size = 24,
		spin = false,
		reducedMotion = reducedMotion,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 46,
		compact = true,
	})), React.createElement("textlabel", {
		Size = UDim2.new(1, -4, 0, 14),
		Position = UDim2.new(0.5, 0, 0, if compactLabel then 32 else 36),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = entry.label,
		TextColor3 = if active then Palette.cream else Palette.muted,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", if active then Enum.FontWeight.Heavy else Enum.FontWeight.Bold),
		ZIndex = 43,
	}))
end

local function MenuCell(_param)
	local entry = _param.entry
	local active = _param.active
	local badge = _param.badge or 0
	local accent = entry.accent or Palette.cyan
	return React.createElement("textbutton", {
		Name = "Menu_" .. entry.id,
		LayoutOrder = _param.order,
		BackgroundColor3 = if active then darken(accent, 0.6) else Palette.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 512,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				InteractionFeedback.tap()
				_param.onPick(entry.id)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = if active then accent else Palette.line,
		Thickness = if active then 1.5 else 1,
		Transparency = if active then 0.15 else 0.55,
	}), React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = 34,
		radius = 10,
		position = UDim2.new(0.5, -17, 0, 10),
		spin = false,
		zIndex = 513,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -8, 0, 16),
		Position = UDim2.new(0.5, 0, 0, 48),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = entry.label,
		TextColor3 = Palette.cream,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		ZIndex = 513,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -8, 0, 12),
		Position = UDim2.new(0.5, 0, 0, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = entry.eyebrow or "",
		TextColor3 = Palette.muted,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
		ZIndex = 513,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 515,
	}))
end

local function MenuSheet(_param)
	local open = _param.open
	local page = _param.page
	local state = _param.state
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local reducedMotion = _param.reducedMotion
	local query, setQuery = React.useState("")
	local amount = useFlipperSpring(if open then 1 else 0, reducedMotion, 620, 42)
	local drag, setDrag = React.useBinding(0)
	local dragState = React.useRef({ active = false, startY = 0, value = 0 })
	React.useEffect(function()
		if not open then
			setQuery("")
		end
		dragState.current.value = 0
		setDrag(0)
	end, { open })
	React.useEffect(function()
		if not open then
			return nil
		end
		local moved = UserInputService.InputChanged:Connect(function(input)
			local current = dragState.current
			if not current.active then
				return
			end
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
				current.value = math.max(0, input.Position.Y - current.startY)
				setDrag(current.value)
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			local current = dragState.current
			if not current.active then
				return
			end
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				current.active = false
				if current.value > SHEET_SWIPE_CLOSE then
					_param.onClose()
				else
					current.value = 0
					setDrag(0)
				end
			end
		end)
		local back = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed) then
				_param.onClose()
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
			back:Disconnect()
		end
	end, { open })

	local visible = allNav(state, _param.tutorialPage)
	local byId = {}
	for _, entry in visible do
		byId[entry.id] = entry
	end
	local needle = string.lower((string.gsub(query, "^%s*(.-)%s*$", "%1")))
	local cols = if chrome.landscape then 6 elseif viewport.width >= 560 then 5 else 4
	local sideGap = math.max(chrome.sideSafe, 12)
	local sheetW = viewport.width - sideGap * 2
	local cellGap = 8
	local cellW = math.floor((sheetW - 24 - cellGap * (cols - 1)) / cols)
	local cellH = 82
	local sections = {}
	sections.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	sections.pad = React.createElement("uipadding", {
		PaddingBottom = UDim.new(0, 12),
	})
	local placed = {}
	local function addSection(key, label, ids, order)
		local entries = {}
		for _, id in ids do
			local entry = byId[id]
			if entry ~= nil and not placed[id] then
				local matches = needle == "" or string.find(string.lower(entry.label), needle, 1, true) ~= nil or string.find(string.lower(entry.eyebrow or ""), needle, 1, true) ~= nil
				if matches then
					placed[id] = true
					table.insert(entries, entry)
				end
			end
		end
		if #entries == 0 then
			return
		end
		local rows = math.ceil(#entries / cols)
		local cells = {}
		cells.grid = React.createElement("uigridlayout", {
			CellSize = UDim2.fromOffset(cellW, cellH),
			CellPadding = UDim2.fromOffset(cellGap, cellGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		for index, entry in entries do
			cells[entry.id] = React.createElement(MenuCell, {
				entry = entry,
				order = index,
				active = entry.id == page,
				badge = AppHelpers:navBadge(entry, state, _param.chatUnread),
				onPick = function(id)
					_param.setPage(id)
					_param.onClose()
				end,
			})
		end
		sections[key] = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 22 + rows * (cellH + cellGap) - cellGap),
			LayoutOrder = order,
			BackgroundTransparency = 1,
			ZIndex = 511,
		}, React.createElement(Text, {
			value = string.upper(label),
			size = 11,
			color = Palette.muted,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 16),
			zIndex = 512,
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 1, -22),
			Position = UDim2.fromOffset(0, 22),
			BackgroundTransparency = 1,
			ZIndex = 511,
		}, cells))
	end
	for order, group in NAV_GROUPS do
		addSection(group.key, group.label, group.routes, order)
	end
	local loose = {}
	for _, entry in visible do
		if not placed[entry.id] then
			table.insert(loose, entry.id)
		end
	end
	addSection("More", "More", loose, #NAV_GROUPS + 1)

	local topGap = math.max(viewport.topInset + 24, 40)
	local sheetH = viewport.height - topGap
	local searchH = if chrome.landscape then 0 else 40
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = amount:map(function(value)
			return value > 0.01
		end),
		ZIndex = 505,
	}, React.createElement("textbutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = amount:map(function(value)
			return 1 - math.clamp(value, 0, 1) * 0.55
		end),
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		ZIndex = 506,
		Event = {
			Activated = _param.onClose,
		},
	}), React.createElement("frame", {
		Size = UDim2.new(1, -sideGap * 2, 0, sheetH),
		Position = React.joinBindings({ amount, drag }):map(function(values)
			local hidden = (1 - math.clamp(values[1], 0, 1)) * (sheetH + 20)
			return UDim2.new(0.5, 0, 1, math.round(hidden + values[2]))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 508,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Transparency = 0.3,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 509,
		Event = {
			InputBegan = function(_, input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragState.current.active = true
					dragState.current.startY = input.Position.Y
				end
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(44, 5),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 510,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement(Text, {
		value = "All pages",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(16, 28),
		sizeConstraint = UDim2.new(1, -80, 0, 24),
		zIndex = 510,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -(TapTarget + 8), 0, 18),
		BackgroundTransparency = 1,
		ZIndex = 510,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = _param.onClose,
		color = Palette.panel,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 511,
	})), searchH > 0 and React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = Palette.cyan,
		placeholder = "Find a page",
		position = UDim2.fromOffset(12, 68),
		size = UDim2.new(1, -24, 0, searchH),
		reducedMotion = reducedMotion,
		zIndex = 511,
	}), React.createElement("scrollingframe", {
		Size = UDim2.new(1, -24, 1, -(76 + searchH + _param.bottomSafe)),
		Position = UDim2.fromOffset(12, 72 + searchH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ZIndex = 510,
	}, sections)))
end

local function MobileTabBar(_param)
	local page = _param.page
	local setPage = _param.setPage
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomSafe = _param.bottomSafe
	local visible = if _param.visible == nil then true else _param.visible
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local enter = useEntrance(reducedMotion)
	local menuOpen, setMenuOpen = React.useState(false)
	local available = allNav(state, tutorialPage)
	local byId = {}
	for _, entry in available do
		byId[entry.id] = entry
	end
	local slots = math.clamp(chrome.tabBarSlots, 4, 6)
	local availableIds = {}
	for id in byId do
		availableIds[id] = true
	end
	local tabIds = require(script.Parent.CoreKit)("navRouteTable").mobileTabs(availableIds, slots, page)
	local tabs = {}
	for _, id in tabIds do
		table.insert(tabs, byId[id])
	end
	local onBar = {}
	for _, entry in tabs do
		onBar[entry.id] = true
	end
	local menuBadge = 0
	for _, entry in available do
		if not onBar[entry.id] then
			menuBadge += AppHelpers:navBadge(entry, state, chatUnread)
		end
	end
	local current = byId[page]
	local menuShowsPage = current ~= nil and not onBar[page]
	local menuEntry = if menuShowsPage
		then { id = "Menu", label = current.label, icon = current.icon, accent = current.accent }
		else { id = "Menu", label = "Menu", icon = "Menu", accent = Palette.cyan }
	local compact = chrome.landscape
	local items = {}
	items.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local tabSize = UDim2.new(1 / (#tabs + 1), 0, 1, 0)
	for index, entry in tabs do
		items[entry.id] = React.createElement(TabButton, {
			entry = entry,
			order = index,
			size = tabSize,
			active = page == entry.id,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			compact = compact,
			reducedMotion = reducedMotion,
			onClick = function()
				setMenuOpen(false)
				setPage(entry.id)
			end,
		})
	end
	items.menu = React.createElement(TabButton, {
		entry = menuEntry,
		order = #tabs + 1,
		size = tabSize,
		active = menuShowsPage or menuOpen,
		badge = menuBadge,
		compact = compact,
		reducedMotion = reducedMotion,
		onClick = function()
			Audio:play(if menuOpen then "dropdownClose" else "dropdownOpen")
			setMenuOpen(not menuOpen)
		end,
	})
	return React.createElement(React.Fragment, nil, React.createElement("frame", {
		Name = "MobileTabBar",
		Size = UDim2.new(1, 0, 0, height),
		Position = enter:map(function(value)
			return UDim2.new(0, 0, 1, math.round((1 - math.clamp(value, 0, 1)) * height))
		end),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		Active = true,
		Visible = visible,
		ZIndex = 40,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 41,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -(chrome.sideSafe * 2), 0, height - bottomSafe),
		Position = UDim2.fromOffset(chrome.sideSafe, 0),
		BackgroundTransparency = 1,
		ZIndex = 41,
	}, items)), React.createElement(MenuSheet, {
		open = menuOpen,
		page = page,
		setPage = setPage,
		state = state,
		chatUnread = chatUnread,
		tutorialPage = tutorialPage,
		bottomSafe = bottomSafe,
		reducedMotion = reducedMotion,
		onClose = function()
			setMenuOpen(false)
		end,
	}))
end

local function Chip(_param)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(_param.width, _param.height),
		LayoutOrder = _param.order,
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 7, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = _param.accent,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("textlabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = compactNumber(_param.value),
		TextColor3 = Palette.cream,
		TextScaled = true,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		ZIndex = 23,
	}, React.createElement("uitextsizeconstraint", {
		MaxTextSize = 13,
		MinTextSize = 9,
	})))
end

local function MobileHeader(_param)
	local state = _param.state
	local page = _param.page
	local accent = _param.accent
	local topPad = _param.topPad
	local barHeight = _param.barHeight
	local edgePad = _param.edgePad
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local entry = AppHelpers:pageEntry(page)
	local short = barHeight <= 40
	local width = viewport.width - edgePad * 2
	local chipH = if short then 24 else 30
	local chipW = if short then 84 else 96
	local playersW = barHeight - 8
	local iconSize = if short then 24 else 30
	local wanted = { { key = "flux", value = state.Cash, accent = Palette.cyan } }
	if AppHelpers:featureUnlocked(state, "StarGrid") then
		table.insert(wanted, { key = "dust", value = state.Stardust, accent = Palette.mango })
	end
	if AppHelpers:featureUnlocked(state, "Rebirth") then
		table.insert(wanted, { key = "cores", value = state.Cores, accent = Palette.violet })
	end
	local titleMin = 110
	local room = width - (8 + iconSize + 8 + titleMin + playersW + 22)
	local chips = {}
	chips.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for index, item in wanted do
		chips[item.key] = React.createElement(Chip, {
			order = index,
			value = item.value,
			accent = item.accent,
			width = chipW,
			height = chipH,
		})
	end
	local contentW = #wanted * chipW + math.max(0, #wanted - 1) * 6
	local chipsW = math.min(contentW, math.max(48, room))
	local visitors = if type(state.Visitors) == "table" then #state.Visitors else 0
	local roadmap = __load("levelRoadmap")
	local level, _tier, nextStep = roadmap.readLevelState(state)
	local fill = if nextStep ~= nil then roadmap.progressFraction(nextStep) else 1
	return React.createElement("frame", {
		Name = "MobileHeader",
		Size = UDim2.new(1, -edgePad * 2, 0, barHeight),
		Position = UDim2.fromOffset(edgePad, topPad),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Transparency = 0.4,
	}), React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = iconSize,
		radius = 9,
		position = UDim2.fromOffset(8, math.floor((barHeight - iconSize) / 2)),
		spin = false,
		reducedMotion = reducedMotion,
		zIndex = 21,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -(8 + iconSize + 8 + chipsW + playersW + 22), 0, if short then barHeight else 20),
		Position = UDim2.fromOffset(8 + iconSize + 8, if short then 0 else 2),
		BackgroundTransparency = 1,
		Text = entry.label,
		TextColor3 = Palette.cream,
		TextSize = if short then 14 else 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		ZIndex = 21,
	}), not short and React.createElement("imagebutton", {
		Name = "MobileRoadmapButton",
		Size = UDim2.new(1, -(chipsW + playersW + 22), 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 22,
		Event = {
			Activated = function()
				Audio:play("open")
				roadmap.openRoadmap()
			end,
		},
	}), not short and React.createElement("textlabel", {
		Name = "MobileLevelLabel",
		Size = UDim2.fromOffset(64, 16),
		Position = UDim2.fromOffset(8 + iconSize + 8, 24),
		BackgroundColor3 = darken(accent, 0.55),
		BorderSizePixel = 0,
		Text = `LV {level}`,
		TextColor3 = Palette.cream,
		TextSize = 10,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		ZIndex = 22,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("scrollingframe", {
		Name = "MobileResourceRail",
		Size = UDim2.fromOffset(chipsW, chipH + 4),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = accent,
		Active = true,
		Position = UDim2.new(1, -(playersW + 12), 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, chips), React.createElement("imagebutton", {
		Name = "MobilePlayersButton",
		Size = UDim2.fromOffset(playersW, playersW),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 22,
		Event = {
			Activated = function()
				Audio:play("playerlistOpen")
				_param.openPlayerlist()
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement(Icon, {
		kind = "Crew",
		color = Palette.cream,
		accent = Palette.cyan,
		size = math.floor(playersW * 0.62),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}), visitors > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(1, -3, 0, 3),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, -24, 0, 2),
		Position = UDim2.new(0, 12, 1, -2),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 22,
	})))
end

local function MobileQuickActions(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local viewport = useViewport()
	local capacity = asFlux(state.Capacity)
	local vaultFill = if capacity > 0 then math.clamp(asFlux(state.Vault) / capacity, 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local enter = useEntrance(reducedMotion)
	local holding, setHolding = React.useState(false)
	local holdPulse = useFlipperSpring(if holding then 1 else 0, reducedMotion, 900, 40)
	React.useEffect(function()
		if not holding then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				dispatch("Overcharge")
				InteractionFeedback.tap()
				task.wait(OVERCHARGE_REPEAT)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { holding })
	React.useEffect(function()
		if not holding then
			return nil
		end
		local released = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				setHolding(false)
			end
		end)
		return function()
			released:Disconnect()
		end
	end, { holding })
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		InteractionFeedback.reward()
		dispatch("CollectVault")
	end
	local width = math.min(220, math.floor(viewport.width * 0.6))
	local height = TapTarget + 14
	return React.createElement("frame", {
		Name = "MobileQuickActions",
		Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(1, 1),
		Position = enter:map(function(value)
			return UDim2.new(1, -edgePad, 1, -bottomOffset + math.round((1 - value) * 14))
		end),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 38,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		Color = if vaultFill > 0.8 then Palette.green else Palette.line,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = 0.35,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, 3),
		Position = UDim2.fromOffset(10, 3),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 39,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSpring:map(function(value)
			return UDim2.new(math.clamp(value, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if vaultFill > 0.92 then Palette.mango else Palette.green,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, -12, 0, TapTarget),
		Position = UDim2.fromOffset(6, 9),
		BackgroundTransparency = 1,
		ZIndex = 40,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Name = "OverviewVaultClaimActions",
		Size = UDim2.new(0.58, -3, 1, 0),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = if vaultReady then `BANK {compactNumber(state.Vault)}` else "EMPTY",
		icon = "Flux",
		onClick = bank,
		color = if vaultReady then Palette.green else Palette.panelSoft,
		textColor = if vaultReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not vaultReady,
		highlight = vaultReady and vaultFill > 0.5,
	})), React.createElement("imagebutton", {
		Name = "MobileOvercharge",
		Size = UDim2.new(0.42, -3, 1, 0),
		LayoutOrder = 2,
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 41,
		Event = {
			InputBegan = function(_, input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					setHolding(true)
				end
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uiscale", {
		Scale = holdPulse:map(function(value)
			return 1 - math.clamp(value, 0, 1) * 0.06
		end),
	}), React.createElement(Icon, {
		kind = "Forge",
		color = Palette.ink,
		accent = Palette.ink,
		size = 20,
		position = UDim2.new(0, 8, 0.5, -10),
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(30, 0),
		BackgroundTransparency = 1,
		Text = if holding then "HOLD" else "TAP",
		TextColor3 = Palette.ink,
		TextSize = 14,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		ZIndex = 42,
	}))))
end

return {
	MobileTabBar = MobileTabBar,
	MobileHeader = MobileHeader,
	MobileQuickActions = MobileQuickActions,
}
end

__defs["OfflineRewardsOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useGlowStroke = _motion.useGlowStroke
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local NumberSpinnerHost = require(script.Parent.ReactHosts)("NumberSpinnerHost").NumberSpinnerHost
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local IconTile = _ui.IconTile
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition
local function StatTile(_param)
	local label = _param.label
	local value = _param.value
	local color = _param.color
	local index = _param.index
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local reveal = useStagger(index, reducedMotion, 0.07, 0.22)
	return React.createElement("frame", {
		Size = UDim2.new(0.25, -6, 1, 0),
		Position = UDim2.new(index * 0.25, if index == 0 then 0 else 6, 0, 0),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Text, {
		value = label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(2, 8),
		sizeConstraint = UDim2.new(1, -4, 0, 14),
	}), React.createElement(Text, {
		value = value,
		size = if #value > 6 then 11 else 12,
		color = color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(2, 28),
		sizeConstraint = UDim2.new(1, -4, 0, 28),
	}))
end
local function OfflineRewardsOverlay(_param)
	local reward = _param.reward
	local seconds = _param.seconds
	local efficiency = _param.efficiency
	local capped = _param.capped
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local effectsEnabled = _param.effectsEnabled
	local production = _param.production
	local awaySeconds = _param.awaySeconds
	local capHours = _param.capHours
	local vault = _param.vault
	local onCollect = _param.onCollect
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.stack or viewport.width < 720
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion, 0.32)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local padFocus = useGamepadAutofocus(true)
	local overlayHostRef = React.useRef(nil)
	local parentSize = useGuiSize(overlayHostRef, true)
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
	end, {})
	local bankedSeconds = math.max(0, seconds)
	local _condition = awaySeconds
	if _condition == nil then
		_condition = bankedSeconds
	end
	local actualAway = math.max(bankedSeconds, _condition)
	local _condition_1 = capHours
	if _condition_1 == nil then
		_condition_1 = math.floor(bankedSeconds / 3600 + 0.49)
	end
	local hoursCap = math.max(1, _condition_1)
	local efficiencyPct = math.floor(math.clamp(efficiency, 0, 1) * 100 + 0.5)
	local rate = if production ~= nil then asFlux(production) else 0
	local missedSeconds = math.max(0, actualAway - bankedSeconds)
	local missed = if capped and rate > 0 then rate * efficiency * missedSeconds else 0
	local _condition_2 = vault
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local vaultAmount = asFlux(_condition_2)
	local canBankVault = vaultAmount >= 0.01
	local rewardAmount = asFlux(reward)
	local bigHaul = rate > 0 and rewardAmount >= rate * 3600
	local rewardGlow = useGlowStroke(bigHaul, softMotion, 0.35, 0.15, 0.62, 1.6)
	local cardWidth = math.min(if stack then math.max(280, viewport.width - chrome.sideSafe * 2 - 20) else 560, 560)
	-- The card is as tall as the layout it can show: stats, the explanation and stacked buttons
	-- when there is room, otherwise stats and side-by-side buttons with nothing left empty.
	local statsBottom = if stack then 240 else 242
	local roomH = math.max(240, viewport.height - viewport.topInset - chrome.bottomSafe - 24)
	local fullInner = statsBottom + 48 + TapTarget * 2 + 8
	local shortInner = statsBottom + 14 + TapTarget
	local cardHeight = if roomH >= fullInner + 28 then math.min(if stack then 468 else 420, roomH) else math.min(shortInner + 28, roomH)
	local innerHeight = cardHeight - 28
	local shortCard = innerHeight < fullInner
	local tinyCard = shortCard and innerHeight < statsBottom + 10 + TapTarget
	local finish = React.useCallback(function(bankVault)
		if closing then
			return nil
		end
		Audio:play(if bankVault then "offlineCollect" else "close")
		if bankVault then
			onCollect()
		end
		beginExit(onClose)
	end, { beginExit, closing, onClose, onCollect })
	React.useEffect(function()
		if bigHaul then
			Audio:playCelebration({ "offlineOpen", "discovery" }, 0.12)
		else
			Audio:play("offlineOpen")
		end
	end, {})
	local cardPosition = React.joinBindings({ motion, parentSize }):map(function(values)
		return pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 18)
	end)
	local cardScale = motion:map(function(amount)
		return 0.94 + amount * 0.06
	end)
	local scrim = motion:map(function(amount)
		return math.clamp(1 - amount * 0.78, 0.2, 1)
	end)
	local fade = motion:map(function(amount)
		return 1 - amount
	end)
	local _exp = {
		label = "AWAY",
		value = clockText(actualAway),
		color = Palette.cyan,
	}
	local _exp_1 = {
		label = "BANKED",
		value = clockText(bankedSeconds),
		color = Palette.mint,
	}
	local _exp_2 = {
		label = "EFFICIENCY",
		value = `{efficiencyPct}%`,
		color = Palette.violet,
	}
	local _object = {
		label = "RATE",
	}
	local _left = "value"
	local _result
	if rate > 0 then
		local _condition_3 = production
		if _condition_3 == nil then
			_condition_3 = 0
		end
		_result = `{compactNumber(_condition_3)}/s`
	else
		_result = "—"
	end
	_object[_left] = _result
	_object.color = Palette.mango
	local rows = { _exp, _exp_1, _exp_2, _object }
	local copy = if capped then `Offline earnings cap out at {hoursCap}h. {if missed > 0 then `About {compactNumber(missed)} flux was earned outside that window and missed.` else "Everything inside the window is already in your cash."}` else `Earned at {efficiencyPct}% efficiency for {clockText(bankedSeconds)}. That flux is already in your cash.`
	local _exp_3 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrim,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 460,
	})
	local _exp_4 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	})
	local _exp_5 = React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 2,
		Transparency = motion:map(function(amount)
			return 0.45 - amount * 0.28
		end),
	})
	local _exp_6 = React.createElement(IconTile, {
		kind = "Gift",
		accent = Palette.mint,
		size = if stack then 40 else 48,
		radius = 14,
		position = UDim2.fromOffset(0, 0),
		glow = effectsEnabled or bigHaul,
		spin = false,
		reducedMotion = softMotion,
	})
	local _exp_7 = React.createElement(Text, {
		value = "WELCOME BACK",
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, 2),
		sizeConstraint = UDim2.new(1, -70, 0, 16),
	})
	local _exp_8 = React.createElement(Text, {
		value = "The forge kept running.",
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(56, 20),
		sizeConstraint = UDim2.new(1, -70, 0, 28),
	})
	local _exp_9 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 86 else 96),
		Position = UDim2.fromOffset(0, 64),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 465,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 1.5,
		Transparency = rewardGlow,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), React.createElement(Text, {
		value = "ALREADY IN YOUR CASH",
		size = 10,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(14, 10),
		sizeConstraint = UDim2.new(1, -28, 0, 14),
	}), React.createElement(NumberSpinnerHost, {
		value = rewardAmount,
		reducedMotion = softMotion,
		duration = 0.85,
		prefix = "+",
		extraSuffix = " FLUX",
		spacedSuffix = true,
		size = if stack then 24 else 30,
		color = Palette.mint,
		position = UDim2.fromOffset(14, 28),
		sizeConstraint = UDim2.fromOffset(0, 40),
		autoWidth = true,
		zIndex = 466,
	}))
	local _newValue = table.create(#rows)
	local _callback = function(row, index)
		return React.createElement(StatTile, {
			key = row.label,
			label = row.label,
			value = row.value,
			color = row.color,
			index = index,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in rows do
		_newValue[_k] = _callback(_v, _k - 1, rows)
	end
	local _exp_10 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 78 else 70),
		Position = UDim2.fromOffset(0, if stack then 162 else 172),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = not tinyCard,
	}, _newValue)
	local _exp_11 = if shortCard then nil else React.createElement(Text, {
		value = copy,
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 40)),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	})
	local _result_1
	if canBankVault then
		local _attributes = {}
		local _condition_3 = vault
		if _condition_3 == nil then
			_condition_3 = 0
		end
		_attributes.text = `BANK VAULT  {compactNumber(_condition_3)}`
		_attributes.icon = "Collect"
		_attributes.onClick = function()
			return finish(true)
		end
		_attributes.color = Palette.mint
		_attributes.textColor = Palette.ink
		_attributes.size = if shortCard then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.new(1, 0, 0, TapTarget)
		_attributes.position = if shortCard then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(0, 0, 1, -(TapTarget * 2 + 8))
		_attributes.reducedMotion = reducedMotion
		_attributes.disabled = closing
		_attributes.highlight = true
		_result_1 = React.createElement(Button, _attributes)
	else
		_result_1 = React.createElement(Button, {
			text = "CONTINUE",
			icon = "Collect",
			onClick = function()
				return finish(false)
			end,
			color = Palette.mint,
			textColor = Palette.ink,
			size = if shortCard then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.new(1, 0, 0, TapTarget),
			position = if shortCard then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(0, 0, 1, -(TapTarget * 2 + 8)),
			reducedMotion = reducedMotion,
			disabled = closing,
			highlight = true,
		})
	end
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 460,
		Visible = motion:map(function(amount)
			return amount > 0.004
		end),
	}, _exp_3, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 461,
		Visible = motion:map(function(amount)
			return amount > 0.004
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 461,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 462,
		ClipsDescendants = true,
	}, _exp_4, _exp_5, React.createElement("frame", {
		Size = UDim2.new(1, -28, 1, -28),
		Position = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 464,
	}, _exp_6, _exp_7, _exp_8, _exp_9, _exp_10, _exp_11, _result_1, React.createElement(Button, {
		text = if canBankVault then "KEEP VAULT" else "CLOSE",
		icon = "Close",
		onClick = function()
			return finish(false)
		end,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = if shortCard then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.new(1, 0, 0, TapTarget),
		position = if shortCard then UDim2.new(0.5, 5, 1, -TapTarget) else UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		disabled = closing,
	})))))))
end
return {
	OfflineRewardsOverlay = OfflineRewardsOverlay,
}
end

__defs["PlayerlistOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local _ui = __load("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local SearchField = _ui.SearchField
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition

local SharedData = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
local Model = SharedData("PlayerlistModel")
local _elementFx = require(script.Parent.ElementFx)
local ElementFx = _elementFx.ElementFx
local elementSheet = _elementFx.sheet

local TEST_BOT_USER_ID = 771133001
local ROW_H = 60
local ROW_GAP = 6
local FRIEND_TTL = 120
local REPORT_COOLDOWN = 600

local friendCache = {}
local reportedAt = {}

local function StatCell(_param)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = _param.order,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 625,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = _param.label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(8, 4),
		sizeConstraint = UDim2.new(1, -12, 0, 13),
		zIndex = 626,
	}), React.createElement(Text, {
		value = _param.value,
		size = 13,
		color = _param.color or Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(8, 17),
		sizeConstraint = UDim2.new(1, -12, 0, 18),
		zIndex = 626,
	}))
end

local function Avatar(_param)
	local size = _param.size
	local accent = _param.accent
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = _param.position,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = darken(accent, 0.64),
		BorderSizePixel = 0,
		ZIndex = 624,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.25,
	}), React.createElement("imagelabel", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={_param.userId}&w=150&h=150`,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 625,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(11, 11),
		Position = UDim2.new(1, -1, 1, -1),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = if _param.away then Palette.mango else Palette.mint,
		BorderSizePixel = 0,
		ZIndex = 627,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.ink,
		Thickness = 2,
	})))
end

local function ActionButton(_param)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = _param.order,
		BackgroundTransparency = 1,
		ZIndex = 626,
	}, React.createElement(Button, {
		text = _param.text,
		icon = _param.icon,
		onClick = _param.onClick,
		color = _param.color,
		textColor = _param.textColor or Palette.ink,
		outline = _param.outline,
		size = UDim2.fromScale(1, 1),
		reducedMotion = _param.reducedMotion,
		disabled = _param.disabled,
		zIndex = 626,
	}))
end

-- Two groups of four: the things people do with each other (message, trade, visit, crew) as full
-- buttons, then quieter, shorter buttons for wave, friend, block and report, with room between.
local function playerActionLayout(width)
	local PLAYER_ACTION_GAP, PLAYER_GROUP_GAP, PLAYER_SECONDARY_H = 10, 14, 40
	local columns = if width < 440 then 2 else 4
	local groupRows = math.ceil(4 / columns)
	local primaryHeight = groupRows * TapTarget + (groupRows - 1) * PLAYER_ACTION_GAP
	local secondaryHeight = groupRows * PLAYER_SECONDARY_H + (groupRows - 1) * PLAYER_ACTION_GAP
	return {
		columns = columns,
		rows = groupRows * 2,
		gap = PLAYER_ACTION_GAP,
		cellWidth = math.floor((math.max(0, width - 16) - (columns - 1) * PLAYER_ACTION_GAP) / columns),
		primaryHeight = primaryHeight,
		secondaryHeight = secondaryHeight,
		secondaryCellHeight = PLAYER_SECONDARY_H,
		groupGap = PLAYER_GROUP_GAP,
		height = primaryHeight + PLAYER_GROUP_GAP + secondaryHeight,
	}
end

local function detailsHeight(row, width)
	if row.IsLocal then
		return 8 + 2 * 40 + 6 + 22 + 8
	end
	return 8 + 2 * 40 + 6 + 22 + playerActionLayout(width).height + 10
end

local function PlayerRow(_param)
	local row = _param.row
	local expanded = _param.expanded
	local rowRef = React.useRef(nil)
	local width, setWidth = React.useState(_param.width)
	React.useEffect(function()
		local host = rowRef.current
		if host == nil then return end
		local function resize()
			if host.AbsoluteSize.X > 0 then setWidth(math.floor(host.AbsoluteSize.X)) end
		end
		resize()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		return function() connection:Disconnect() end
	end, {})
	local reducedMotion = _param.reducedMotion
	local friend = _param.friend
	local blocked = _param.blocked
	local away = _param.away
	local reported = _param.reported
	local accent = if row.IsLocal then Palette.mint elseif friend then Palette.mango else Palette.cyan
	local openAmount = useFlipperSpring(if expanded then 1 else 0, reducedMotion, 560, 44)
	local hovered, setHovered = React.useState(false)
	local hover = useFlipperSpring(if hovered or expanded then 1 else 0, reducedMotion, 900, 44)
	local detailsH = detailsHeight(row, width)
	local tags = {}
	if row.IsLocal then
		table.insert(tags, "YOU")
	end
	if _param.crewmate then
		table.insert(tags, "CREW")
	end
	if friend then
		table.insert(tags, "FRIEND")
	end
	if away then
		table.insert(tags, "AFK")
	end
	if blocked then
		table.insert(tags, "BLOCKED")
	end
	local subtitle = `WORLD {compactNumber(row.CurrentZone)}  ·  {compactNumber(row.Rebirths)} REBIRTHS`
	local artifact = _param.artifact
	local artifactColor = if artifact ~= nil then (artifact.Color or (elementSheet(artifact.Element) or { Color = Palette.violet }).Color) else nil
	if artifact ~= nil then
		subtitle = `{string.upper(artifact.Name)} LV{artifact.Level}  ·  {subtitle}`
	end
	local actions = nil
	if not row.IsLocal then
		local actionLayout = playerActionLayout(width)
		local function actionGroup(name, top, height, cellHeight, children)
			return React.createElement("frame", {
				Name = name,
				Size = UDim2.new(1, 0, 0, height),
				Position = UDim2.fromOffset(0, top),
				BackgroundTransparency = 1,
				ZIndex = 625,
			}, React.createElement("uigridlayout", {
				CellSize = UDim2.fromOffset(actionLayout.cellWidth, cellHeight),
				FillDirectionMaxCells = actionLayout.columns,
				CellPadding = UDim2.fromOffset(actionLayout.gap, actionLayout.gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}), children)
		end
		actions = React.createElement("frame", {
			Name = "PlayerActions",
			Size = UDim2.new(1, -16, 0, actionLayout.height),
			Position = UDim2.fromOffset(8, 8 + 2 * 40 + 6 + 22),
			BackgroundTransparency = 1,
			ZIndex = 625,
		}, actionGroup("Primary", 0, actionLayout.primaryHeight, TapTarget, {
			Message = React.createElement(ActionButton, {
				order = 1,
				text = "MESSAGE",
				icon = "Chat",
				color = Palette.cyan,
				disabled = blocked,
				onClick = _param.onMessage,
				reducedMotion = reducedMotion,
			}),
			Trade = React.createElement(ActionButton, {
				order = 2,
				text = "TRADE",
				icon = "Send",
				color = Palette.mint,
				onClick = _param.onTrade,
				reducedMotion = reducedMotion,
			}),
			Visit = React.createElement(ActionButton, {
				order = 3,
				text = "VISIT",
				icon = "Visit",
				color = Palette.violet,
				onClick = _param.onVisit,
				reducedMotion = reducedMotion,
			}),
			Crew = React.createElement(ActionButton, {
				order = 4,
				text = if _param.crewmate then "IN CREW" else "CREW",
				icon = "Crew",
				color = Palette.green,
				disabled = _param.crewmate or blocked,
				onClick = _param.onCrew,
				reducedMotion = reducedMotion,
			}),
		}), actionGroup("Secondary", actionLayout.primaryHeight + actionLayout.groupGap, actionLayout.secondaryHeight, actionLayout.secondaryCellHeight, {
			Wave = React.createElement(ActionButton, {
				order = 1,
				text = "WAVE",
				icon = "Wave",
				color = Palette.panelSoft,
				textColor = Palette.cream,
				outline = true,
				onClick = _param.onWave,
				reducedMotion = reducedMotion,
			}),
			Friend = React.createElement(ActionButton, {
				order = 2,
				text = if friend then "UNFRIEND" else "ADD FRIEND",
				icon = "Crew",
				color = Palette.panelSoft,
				textColor = Palette.cream,
				outline = true,
				onClick = _param.onFriend,
				reducedMotion = reducedMotion,
			}),
			Block = React.createElement(ActionButton, {
				order = 3,
				text = if blocked then "UNBLOCK" else "BLOCK",
				icon = "Close",
				color = Palette.panelSoft,
				textColor = Palette.creamSoft,
				outline = true,
				onClick = _param.onBlock,
				reducedMotion = reducedMotion,
			}),
			Report = React.createElement(ActionButton, {
				order = 4,
				text = if reported then "REPORTED" else "REPORT",
				icon = "Admin",
				color = Palette.panelSoft,
				textColor = Palette.coral,
				outline = true,
				disabled = reported,
				onClick = _param.onReport,
				reducedMotion = reducedMotion,
			}),
		}))
	end
	local relics = if #row.EquippedItems > 0 then table.concat(row.EquippedItems, " · ") else "No relics equipped"
	return React.createElement("frame", {
		Name = "PlayerCard",
		ref = rowRef,
		Size = openAmount:map(function(amount)
			return UDim2.new(1, 0, 0, ROW_H + math.round(detailsH * math.clamp(amount, 0, 1)))
		end),
		LayoutOrder = _param.order,
		BackgroundColor3 = hover:map(function(amount)
			return Palette.panel:Lerp(darken(accent, 0.7), math.clamp(amount, 0, 1) * 0.8)
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 620,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = hover:map(function(amount)
			return 0.8 - math.clamp(amount, 0, 1) * 0.45
		end),
	}), React.createElement("textbutton", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 621,
		Event = {
			Activated = _param.onToggle,
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
			SelectionGained = function()
				setHovered(true)
			end,
			SelectionLost = function()
				setHovered(false)
			end,
		},
	}, artifact ~= nil and React.createElement(ElementFx, {
		element = artifact.Element,
		size = UDim2.fromOffset(66, 66),
		position = UDim2.new(0, 30, 0.5, -3),
		transparency = 0.2,
		reducedMotion = reducedMotion,
		zIndex = 622,
		-- a newly equipped or upgraded artifact pops on the player card
		reaction = "equip",
		reactionKey = `{artifact.Name}:{artifact.Level}`,
	}), React.createElement(Avatar, {
		userId = row.UserId,
		accent = artifactColor or accent,
		size = 40,
		away = away,
		position = UDim2.new(0, 10, 0.5, 0),
	}), React.createElement(Text, {
		value = row.DisplayName,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(60, 9),
		sizeConstraint = UDim2.new(1, -150, 0, 20),
		zIndex = 623,
	}), React.createElement(Text, {
		value = if #tags > 0 then table.concat(tags, " · ") .. "  ·  " .. subtitle else subtitle,
		size = 10,
		color = if away then Palette.mango elseif artifactColor ~= nil then lighten(artifactColor, 0.18) else accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(60, 32),
		sizeConstraint = UDim2.new(1, -150, 0, 16),
		zIndex = 623,
	}), React.createElement(Text, {
		value = `{compactNumber(row.Production)}/s`,
		size = 13,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -110, 0, 12),
		sizeConstraint = UDim2.fromOffset(78, 18),
		zIndex = 623,
	}), React.createElement(Text, {
		value = "OUTPUT",
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -110, 0, 31),
		sizeConstraint = UDim2.fromOffset(78, 14),
		zIndex = 623,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(1, -18, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = openAmount:map(function(amount)
			return math.clamp(amount, 0, 1) * 180
		end),
		BackgroundTransparency = 1,
		ZIndex = 623,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(7, 2),
		Position = UDim2.new(0.5, -2, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = Palette.muted,
		BorderSizePixel = 0,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(7, 2),
		Position = UDim2.new(0.5, 2, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -45,
		BackgroundColor3 = Palette.muted,
		BorderSizePixel = 0,
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, detailsH),
		Position = UDim2.fromOffset(0, ROW_H),
		BackgroundTransparency = 1,
		Visible = openAmount:map(function(amount)
			return amount > 0.01
		end),
		ZIndex = 624,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 2 * 40 + 6),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		ZIndex = 624,
	}, React.createElement("uigridlayout", {
		CellSize = UDim2.fromOffset(math.floor((math.max(0, width - 16) - 12) / 3), 40),
		FillDirectionMaxCells = 3,
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(StatCell, {
		order = 1,
		label = "WORLD",
		value = `{compactNumber(row.CurrentZone)} / {compactNumber(row.Zone)}`,
	}), React.createElement(StatCell, {
		order = 2,
		label = "REBIRTHS",
		value = compactNumber(row.Rebirths),
	}), React.createElement(StatCell, {
		order = 3,
		label = "OUTPUT",
		value = `{compactNumber(row.Production)}/s`,
		color = Palette.mint,
	}), React.createElement(StatCell, {
		order = 4,
		label = "LIFETIME",
		value = compactNumber(row.LifetimeCash),
	}), React.createElement(StatCell, {
		order = 5,
		label = "RELICS",
		value = compactNumber(row.ItemCount),
		color = Palette.violet,
	}), React.createElement(StatCell, {
		order = 6,
		label = "PLAYED",
		value = Model.playTime(row.PlayTime),
	})), row.IsLocal and React.createElement(Text, {
		value = if artifact ~= nil
			then `ARTIFACT  {artifact.Name} · {artifact.Rarity} · LV {artifact.Level}{if artifact.Effect ~= nil then "  ·  " .. artifact.Effect else ""}`
			else "ARTIFACT  none equipped",
		size = 10,
		color = artifactColor or Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(10, 8 + 2 * 40 + 8),
		sizeConstraint = UDim2.new(1, -20, 0, 16),
		zIndex = 625,
	}), not row.IsLocal and React.createElement(Text, {
		value = `{if artifact ~= nil then string.upper(artifact.Name) .. (if artifact.Effect ~= nil then " " .. artifact.Effect else "") else relics}  ·  ACCOUNT {Model.accountAge(row.AccountAge)}{if row.Premium then "  ·  PREMIUM" else ""}`,
		size = 10,
		color = artifactColor or Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(10, 8 + 2 * 40 + 8),
		sizeConstraint = UDim2.new(1, -20, 0, 16),
		zIndex = 625,
	}), actions))
end

local function ReportSheet(_param)
	local hostRef = React.useRef(nil)
	local hostSize = useGuiSize(hostRef)
	local target = _param.target
	local reducedMotion = _param.reducedMotion
	local reason, setReason = React.useState(nil)
	local severity, setSeverity = React.useState("Minor")
	local when, setWhen = React.useState("Now")
	local where, setWhere = React.useState("World")
	local details, setDetails = React.useState("")
	local alsoBlock, setAlsoBlock = React.useState(false)
	local phase, setPhase = React.useState("form")
	local errorText, setErrorText = React.useState(nil)
	local enter = useFlipperSpring(1, reducedMotion, 620, 42, 0)
	local alive = React.useRef(true)
	React.useEffect(function()
		return function()
			alive.current = false
		end
	end, {})
	local send = function()
		if reason == nil or phase ~= "form" then
			return nil
		end
		setPhase("sending")
		setErrorText(nil)
		Audio:play("dangerPress")
		_param.dispatch("ReportPlayer", {
			UserId = target.UserId,
			userId = target.UserId,
			Reason = reason,
			Details = Model.details(details),
			Severity = severity,
			When = when,
			Where = where,
		}, function(response)
			if not alive.current then
				return nil
			end
			if not response.ok then
				setPhase("form")
				setErrorText(response.error or "Couldn't send the report. Try again in a moment.")
				return nil
			end
			reportedAt[target.UserId] = os.clock()
			setPhase("sent")
			Audio:play("reportSubmit")
			if alsoBlock then
				_param.onBlock()
			end
		end)
	end
	local reasonCells = {}
	reasonCells.layout = React.createElement("uigridlayout", {
		CellSize = UDim2.new(0.5, -4, 0, 64),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for order, entry in Model.REASONS do
		local picked = reason == entry.id
		reasonCells[entry.id] = React.createElement("frame", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 704,
		}, React.createElement(Button, {
			text = "", size = UDim2.fromScale(1, 1),
			color = if picked then darken(Palette.coral, 0.45) else Palette.panelSoft,
			reducedMotion = reducedMotion, highlight = picked, sound = "tabSwitch",
			disabled = phase ~= "form", zIndex = 704,
			onClick = function() setReason(entry.id) end,
			children = React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = string.upper(entry.label),
			size = 11,
			color = if picked then Palette.cream else Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(10, 10),
			sizeConstraint = UDim2.new(1, -16, 0, 16),
			zIndex = 710,
		}), React.createElement(Text, {
			value = entry.detail,
			size = 10,
			color = Palette.muted,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(10, 29),
			sizeConstraint = UDim2.new(1, -16, 0, 28),
			zIndex = 710,
		})),
		}))
	end
	local width = _param.width
	local reasonRows = math.ceil(#Model.REASONS / 2)
	local CHIP_ROW = 52
	local contextH = CHIP_ROW * 3 + 4
	local function chipRow(label, options, value, onPick, accent, order)
		local cells = {
			layout = React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, option in options do
			local picked = value == option.id
			cells[option.id] = React.createElement("frame", {
				LayoutOrder = index,
				Size = UDim2.new(1 / #options, -math.ceil(6 * (#options - 1) / #options), 0, 48),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 705,
			}, React.createElement(Button, {
				text = "", size = UDim2.fromScale(1, 1),
				color = if picked then darken(accent, 0.5) else Palette.panelSoft,
				textColor = Palette.creamSoft, highlight = picked,
				onClick = function() onPick(option.id) end, sound = "tabSwitch",
				reducedMotion = reducedMotion, disabled = phase ~= "form", zIndex = 705,
				children = React.createElement(Text, {
					value = string.upper(option.label), size = 11, fit = true, minSize = 9, wrap = true,
					align = Enum.TextXAlignment.Center, weight = Enum.FontWeight.Bold,
					position = UDim2.fromOffset(4, 4), sizeConstraint = UDim2.new(1, -8, 1, -8), zIndex = 711,
				}),
			}))
		end
		return React.createElement("frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, CHIP_ROW),
			BackgroundTransparency = 1,
			ZIndex = 704,
		}, React.createElement(Text, {
			value = label,
			size = 10,
			color = Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 8,
			position = UDim2.fromOffset(0, 18),
			sizeConstraint = UDim2.new(0, 58, 0, 14),
			zIndex = 705,
		}), React.createElement("frame", {
			Size = UDim2.new(1, -62, 1, 0),
			Position = UDim2.fromOffset(62, 0),
			BackgroundTransparency = 1,
			ZIndex = 704,
		}, cells))
	end
	local severityAccent = if severity == "Urgent" then Palette.coral elseif severity == "Serious" then Palette.mango else Palette.cyan
	local contextBlock = React.createElement("frame", {
		Size = UDim2.new(1, -28, 0, contextH),
		Position = UDim2.fromOffset(14, 48 + reasonRows * 72),
		BackgroundTransparency = 1,
		ZIndex = 703,
	}, React.createElement("uilistlayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), chipRow("HOW BAD", Model.SEVERITIES, severity, setSeverity, severityAccent, 1), chipRow("WHEN", Model.WHENS, when, setWhen, Palette.cyan, 2), chipRow("WHERE", Model.WHERES, where, setWhere, Palette.cyan, 3))
	local formH = 48 + reasonRows * 72 + contextH + 8 + 70 + 54 + 64 + (if errorText then 18 else 0)
	local body
	if phase == "sent" then
		body = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 703,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.new(0.5, 0, 0, 30),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = darken(Palette.mint, 0.5),
			BorderSizePixel = 0,
			ZIndex = 704,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement(Icon, {
			kind = "Check",
			color = Palette.cream,
			accent = Palette.mint,
			size = 56,
		})), React.createElement(Text, {
			value = "REPORT SENT",
			size = 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 98),
			sizeConstraint = UDim2.new(1, 0, 0, 22),
			zIndex = 704,
		}), React.createElement(Text, {
			value = if alsoBlock then `Thanks. You also blocked {target.DisplayName}.` else "Thanks for helping keep the server friendly.",
			size = 12,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			wrap = true,
			position = UDim2.fromOffset(10, 124),
			sizeConstraint = UDim2.new(1, -20, 0, 34),
			zIndex = 704,
		}), React.createElement("frame", {
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.new(0, 10, 1, -50),
			BackgroundTransparency = 1,
			ZIndex = 704,
		}, React.createElement(Button, {
			text = "DONE",
			icon = "Check",
			onClick = _param.onClose,
			color = Palette.mint,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			zIndex = 705,
		})))
	else
		body = React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = `REPORT {string.upper(target.DisplayName)}`,
			size = 15,
			color = Palette.coral,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 11,
			position = UDim2.fromOffset(14, 10),
			sizeConstraint = UDim2.new(1, -28, 0, 20),
			zIndex = 704,
		}), React.createElement(Text, {
			value = "What happened?",
			size = 11,
			color = Palette.muted,
			position = UDim2.fromOffset(14, 28),
			sizeConstraint = UDim2.new(1, -28, 0, 14),
			zIndex = 704,
		}), React.createElement("frame", {
			Size = UDim2.new(1, -28, 0, reasonRows * 72),
			Position = UDim2.fromOffset(14, 48),
			BackgroundTransparency = 1,
			ZIndex = 703,
		}, reasonCells), contextBlock, React.createElement("frame", {
			Size = UDim2.new(1, -28, 0, 62),
			Position = UDim2.fromOffset(14, 48 + reasonRows * 72 + contextH + 4),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ZIndex = 704,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Color = Palette.lineSoft,
			Transparency = 0.5,
		}), React.createElement("textbox", {
			Size = UDim2.new(1, -16, 1, -18),
			Position = UDim2.fromOffset(8, 4),
			BackgroundTransparency = 1,
			Text = details,
			PlaceholderText = "Details (optional): what did they do, and when?",
			PlaceholderColor3 = Palette.muted,
			TextColor3 = Palette.cream,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ClearTextOnFocus = false,
			MultiLine = true,
			ZIndex = 705,
			Change = {
				Text = function(box)
					local value = box.Text
					if #value > Model.DETAILS_MAX then
						value = string.sub(value, 1, Model.DETAILS_MAX)
						local _, brokenAt = utf8.len(value)
						if brokenAt then
							value = string.sub(value, 1, brokenAt - 1)
						end
						box.Text = value
					end
					setDetails(value)
				end,
			},
		}), React.createElement(Text, {
			value = `{#details} / {Model.DETAILS_MAX}`,
			size = 9,
			color = Palette.muted,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(0, 8, 1, -14),
			sizeConstraint = UDim2.new(1, -16, 0, 12),
			zIndex = 705,
		})), React.createElement("frame", {
			Size = UDim2.new(1, -28, 0, 48),
			Position = UDim2.fromOffset(14, 48 + reasonRows * 72 + contextH + 78),
			BackgroundTransparency = 1,
			ZIndex = 704,
		}, React.createElement(Button, {
			text = `Also block {target.DisplayName}: {if alsoBlock then "ON" else "OFF"}`,
			icon = if alsoBlock then "Check" else "Lock",
			size = UDim2.fromScale(1, 1),
			color = if alsoBlock then darken(Palette.coral, 0.45) else Palette.panelSoft,
			textColor = Palette.creamSoft, highlight = alsoBlock, reducedMotion = reducedMotion,
			disabled = phase ~= "form", sound = if alsoBlock then "toggleOff" else "toggleOn",
			onClick = function() setAlsoBlock(not alsoBlock) end,
			zIndex = 705,
		})), errorText ~= nil and React.createElement(Text, {
			value = errorText,
			size = 11,
			color = Palette.coral,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.new(0, 14, 1, -70),
			sizeConstraint = UDim2.new(1, -28, 0, 16),
			zIndex = 704,
		}), React.createElement("frame", {
			Size = UDim2.new(1, -28, 0, 48),
			Position = UDim2.new(0, 14, 1, -58),
			BackgroundTransparency = 1,
			ZIndex = 704,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement("frame", {
			Size = UDim2.new(0.4, -4, 1, 0),
			LayoutOrder = 1,
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "CANCEL",
			onClick = _param.onClose,
			color = Palette.panelSoft,
			textColor = Palette.creamSoft,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = phase == "sending",
			zIndex = 705,
		})), React.createElement("frame", {
			Size = UDim2.new(0.6, -4, 1, 0),
			LayoutOrder = 2,
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if phase == "sending" then "SENDING..." elseif reason == nil then "PICK A REASON" else "SEND REPORT",
			icon = "Admin",
			onClick = send,
			color = Palette.coral,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = reason == nil or phase == "sending",
			highlight = reason ~= nil,
			zIndex = 705,
		}))))
	end
	local sheetH = if phase == "sent" then 230 else formH
	return React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = enter:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.5
		end),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 700,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(width, math.min(sheetH, _param.maxHeight)),
		Position = React.joinBindings({ enter, hostSize }):map(function(values)
			return pixelPosition(values[2], 0.5, 0, 0.5, (1 - math.clamp(values[1], 0, 1)) * 24)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 702,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = Palette.coral,
		Thickness = 1.25,
		Transparency = 0.35,
	}), React.createElement("scrollingframe", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, sheetH),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = if sheetH > _param.maxHeight then 3 else 0,
		ScrollBarImageColor3 = Palette.coral,
		ScrollingEnabled = sheetH > _param.maxHeight,
		ZIndex = 702,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, sheetH),
		BackgroundTransparency = 1,
		ZIndex = 702,
	}, body))))
end

local function PlayerlistOverlay(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local onMessage = _param.onMessage
	local notify = _param.notify
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local localPlayer = Players.LocalPlayer
	local localRow = React.useMemo(function()
		return Model.clean({ {
			UserId = localPlayer.UserId,
			Name = localPlayer.Name,
			DisplayName = localPlayer.DisplayName,
			CurrentZone = state.CurrentZone,
			Zone = state.Zone,
			Rebirths = state.Rebirths,
			IsLocal = true,
		} })[1]
	end, { state.CurrentZone, state.Zone, state.Rebirths })
	local rows, setRows = React.useState(function()
		return { localRow }
	end)
	local expandedId, setExpandedId = React.useState(nil)
	local sortId, setSortId = React.useState("Production")
	local query, setQuery = React.useState("")
	local friendsOnly, setFriendsOnly = React.useState(false)
	local friends, setFriends = React.useState({})
	local blocked, setBlocked = React.useState({})
	local reportTarget, setReportTarget = React.useState(nil)
	local inviteBusy, setInviteBusy = React.useState(false)
	local awayTick, setAwayTick = React.useState(0)
	local alive = React.useRef(true)
	local _binding = useExitTransition(reducedMotion)
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local enter = useEntrance(reducedMotion)
	React.useEffect(function()
		alive.current = true
		Audio:play("playerlistOpen")
		local ticker = task.spawn(function()
			while true do
				task.wait(2)
				setAwayTick(function(current)
					return current + 1
				end)
			end
		end)
		return function()
			alive.current = false
			task.cancel(ticker)
		end
	end, {})

	local refresh = React.useCallback(function()
		dispatch("GetPlayers", {}, function(response)
			if not alive.current or not response.ok then
				return nil
			end
			local cleaned = Model.clean(response.Players or {}, TEST_BOT_USER_ID)
			setRows(if #cleaned > 0 then cleaned else { localRow })
		end)
	end, { dispatch, localRow })
	local applyRoster = React.useCallback(function()
		setRows(function(current)
			local known = {}
			for _, row in current do
				known[row.UserId] = row
			end
			local nextRows = { localRow }
			for _, player in Players:GetPlayers() do
				if player.UserId ~= localRow.UserId and player.UserId ~= TEST_BOT_USER_ID then
					table.insert(nextRows, known[player.UserId] or Model.clean({ {
						UserId = player.UserId,
						Name = player.Name,
						DisplayName = player.DisplayName,
					} })[1])
				end
			end
			return nextRows
		end)
	end, { localRow })
	React.useEffect(function()
		refresh()
		applyRoster()
		local debounce
		local onRoster = function()
			applyRoster()
			if debounce ~= nil then
				task.cancel(debounce)
			end
			debounce = task.delay(0.35, function()
				debounce = nil
				if alive.current then
					refresh()
				end
			end)
		end
		local joined = Players.PlayerAdded:Connect(onRoster)
		local left = Players.PlayerRemoving:Connect(onRoster)
		local pulse = task.spawn(function()
			while alive.current do
				task.wait(10)
				if alive.current then
					refresh()
				end
			end
		end)
		return function()
			joined:Disconnect()
			left:Disconnect()
			if debounce ~= nil then
				task.cancel(debounce)
			end
			task.cancel(pulse)
		end
	end, { applyRoster, refresh })

	local syncSocial = React.useCallback(function()
		task.spawn(function()
			local now = os.clock()
			local nextFriends = {}
			for _, player in Players:GetPlayers() do
				local userId = player.UserId
				if userId == localPlayer.UserId then
					continue
				end
				local cached = friendCache[userId]
				if cached == nil or now - cached.at > FRIEND_TTL then
					local ok, isFriend = pcall(function()
						return localPlayer:IsFriendsWithAsync(userId)
					end)
					cached = { at = now, value = ok and isFriend == true }
					friendCache[userId] = cached
				end
				if cached.value then
					nextFriends[userId] = true
				end
			end
			local nextBlocked = {}
			local ok, raw = pcall(function()
				return StarterGui:GetCore("GetBlockedUserIds")
			end)
			if ok and type(raw) == "table" then
				for _, value in raw do
					if type(value) == "number" then
						nextBlocked[math.floor(value)] = true
					end
				end
			end
			if alive.current then
				setFriends(nextFriends)
				setBlocked(nextBlocked)
			end
		end)
	end, {})
	React.useEffect(function()
		syncSocial()
		local friendship
		pcall(function()
			friendship = localPlayer.FriendStatusChanged:Connect(function(other)
				friendCache[other.UserId] = nil
				syncSocial()
			end)
		end)
		return function()
			if friendship ~= nil then
				friendship:Disconnect()
			end
		end
	end, { #rows, syncSocial })

	local close = React.useCallback(function()
		if exiting then
			return nil
		end
		Audio:play("playerlistClose")
		beginExit(onClose)
	end, { beginExit, exiting, onClose })
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed) then
				if reportTarget ~= nil then
					setReportTarget(nil)
				else
					close()
				end
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { close, reportTarget })

	local function peerOf(row)
		local player = Players:GetPlayerByUserId(row.UserId)
		if player == nil then
			notify("Player left", "That player is no longer in this server.")
		end
		return player
	end
	local function promptCore(key, row)
		local player = peerOf(row)
		if player == nil then
			return nil
		end
		local ok = pcall(function()
			StarterGui:SetCore(key, player)
		end)
		if not ok then
			notify("Roblox menu unavailable", "Wait a moment, then try again.")
			return nil
		end
		Audio:play("playerlistAction")
		task.delay(2, function()
			friendCache[row.UserId] = nil
			if alive.current then
				syncSocial()
			end
		end)
	end
	local invite = function()
		if inviteBusy then
			return nil
		end
		setInviteBusy(true)
		Audio:play("invite")
		task.spawn(function()
			local canCheck, canInvite = pcall(function()
				return SocialService:CanSendGameInviteAsync(localPlayer)
			end)
			local opened = canCheck and canInvite == true and pcall(function()
				SocialService:PromptGameInvite(localPlayer)
			end)
			if not alive.current then
				return
			end
			setInviteBusy(false)
			if not opened then
				notify("Invites unavailable", "Roblox could not open the invite panel on this device.")
			end
		end)
	end

	local padFocus = useGamepadAutofocus(true)
	local social = state.SocialBoost or { FriendCount = 0, FriendLimit = 5, FriendBonus = 0, Premium = false, PremiumBonus = 0 }
	local listParentSize = useGuiSize(padFocus, true)
	local side = math.max(chrome.sideSafe, viewport.sideInset, 8) + 6
	local top = math.max(viewport.topInset, 36) + 8
	local bottom = math.max(chrome.bottomSafe, viewport.bottomInset, 8) + 8
	local width = math.max(286, math.min(460, viewport.width - side * 2))
	local height = math.max(260, math.min(680, viewport.height - top - bottom))
	local innerW = width - 20
	local showSearch = #rows >= Model.SEARCH_MIN_ROWS
	local headerH = 58
	local boostH = 52
	local controlsTop = headerH + boostH + 14
	local controlsH = 30 + (if showSearch then 30 + 8 else 0)
	local listTop = controlsTop + controlsH + 8
	local listH = math.max(80, height - listTop - 10)

	local visible = Model.view(rows, sortId, query, friendsOnly, friends)
	local crewState = require(script.Parent.CrewStore).useCrew()
	local crewmates = {}
	if crewState.crew then
		for _, member in crewState.crew.Members do
			crewmates[member.UserId] = true
		end
	end
	local listChildren = {}
	listChildren.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ROW_GAP),
	})
	listChildren.pad = React.createElement("uipadding", {
		PaddingRight = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	})
	local _ = awayTick
	for order, row in visible do
		local peer = if row.IsLocal then nil else Players:GetPlayerByUserId(row.UserId)
		local cooledAt = reportedAt[row.UserId]
		listChildren[tostring(row.UserId)] = React.createElement(PlayerRow, {
			row = row,
			artifact = Model.artifactOf(if row.IsLocal then localPlayer else peer, row.Artifact),
			order = order,
			width = innerW - 9,
			expanded = expandedId == row.UserId,
			friend = friends[row.UserId] == true,
			blocked = blocked[row.UserId] == true,
			away = peer ~= nil and peer:GetAttribute("AF_Away") == true,
			reported = cooledAt ~= nil and os.clock() - cooledAt < REPORT_COOLDOWN,
			reducedMotion = reducedMotion,
			onToggle = function()
				Audio:play("playerlistSelect")
				setExpandedId(if expandedId == row.UserId then nil else row.UserId)
			end,
			onFriend = function()
				promptCore(if friends[row.UserId] then "PromptUnfriend" else "PromptSendFriendRequest", row)
			end,
			onBlock = function()
				promptCore(if blocked[row.UserId] then "PromptUnblockPlayer" else "PromptBlockPlayer", row)
			end,
			onMessage = function()
				if peerOf(row) == nil or onMessage == nil then
					return nil
				end
				Audio:play("playerlistAction")
				onMessage(row.UserId)
			end,
			onVisit = function()
				if peerOf(row) == nil then
					return nil
				end
				Audio:play("playerlistAction")
				dispatch("VisitPlot", { UserId = row.UserId })
				onClose()
			end,
			crewmate = crewmates[row.UserId] == true,
			onCrew = function()
				if peerOf(row) == nil then
					return nil
				end
				Audio:play("playerlistAction")
				dispatch("CrewInvite", { UserId = row.UserId }, function(response)
					if type(response) == "table" and notify then
						notify("Crew", if response.ok then (response.message or "Invite sent.") else (response.error or "Couldn't send that invite."))
					end
				end)
			end,
			onWave = function()
				if peerOf(row) == nil then
					return nil
				end
				Audio:play("playerlistAction")
				dispatch("NudgeCrew", { UserId = row.UserId })
			end,
			onTrade = function()
				if peerOf(row) == nil then
					return nil
				end
				Audio:play("playerlistAction")
				dispatch("InviteTrade", { UserId = row.UserId })
			end,
			onReport = function()
				Audio:play("dangerPress")
				setReportTarget(row)
			end,
		})
	end
	if #visible <= 1 and (query ~= "" or friendsOnly) then
		listChildren.empty = React.createElement(Text, {
			value = if friendsOnly then "No friends in this server right now." else `Nobody matches "{query}".`,
			size = 12,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, 0, 0, 36),
			zIndex = 620,
		})
	end

	local chips = {}
	chips.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local function chip(key, order, label, active, accent, onClick)
		chips[key] = React.createElement("textbutton", {
			Size = UDim2.fromOffset(math.max(56, #label * 7 + 22), 28),
			LayoutOrder = order,
			BackgroundColor3 = if active then darken(accent, 0.5) else Palette.panel,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 616,
			Event = {
				Activated = function()
					Audio:play("tabSwitch")
					onClick()
				end,
			},
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = accent,
			Transparency = if active then 0.15 else 0.7,
		}), React.createElement(Text, {
			value = string.upper(label),
			size = 10,
			color = if active then Palette.cream else Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 8,
			position = UDim2.fromOffset(6, 0),
			sizeConstraint = UDim2.new(1, -12, 1, 0),
			zIndex = 617,
		}))
	end
	for order, sort in Model.SORTS do
		chip("sort" .. sort.id, order, sort.label, sortId == sort.id, Palette.cyan, function()
			setSortId(sort.id)
		end)
	end
	chip("friends", #Model.SORTS + 1, "Friends", friendsOnly, Palette.mango, function()
		setFriendsOnly(not friendsOnly)
	end)

	local showAmount = composePresence(enter, exitAmount)
	local friendProgress = math.clamp(social.FriendCount / math.max(1, social.FriendLimit), 0, 1)
	return React.createElement(OverlayPresence, {
		amount = showAmount,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 600,
		Visible = showAmount:map(function(amount)
			return amount > 0.003
		end),
	}, React.createElement("textbutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = showAmount:map(function(amount)
			return 1 - amount * 0.44
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		ZIndex = 600,
		Event = {
			Activated = close,
		},
	}), React.createElement("frame", {
		ref = padFocus,
		Size = UDim2.fromOffset(width, height),
		Position = React.joinBindings({ showAmount, listParentSize }):map(function(values)
			return pixelPosition(values[2], 1, -side + (1 - values[1]) * 24, 0, top)
		end),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 610,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1.25,
		Transparency = 0.55,
	}), React.createElement(Icon, {
		kind = "Crew",
		color = Palette.cream,
		accent = Palette.cyan,
		size = 30,
		position = UDim2.fromOffset(14, 14),
	}), React.createElement(Text, {
		value = "PLAYERS",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(54, 9),
		sizeConstraint = UDim2.new(1, -112, 0, 24),
		zIndex = 613,
	}), React.createElement(Text, {
		value = `{#rows} IN THIS SERVER`,
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(54, 33),
		sizeConstraint = UDim2.new(1, -112, 0, 16),
		zIndex = 613,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -(TapTarget + 8), 0, 7),
		BackgroundTransparency = 1,
		ZIndex = 614,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.panel,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 614,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, boostH),
		Position = UDim2.fromOffset(10, headerH + 6),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 612,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.mint,
		Transparency = 0.55,
	}), React.createElement(Text, {
		value = `FRIEND BOOST  {social.FriendCount}/{social.FriendLimit}  ·  +{math.floor(social.FriendBonus * 100 + 0.5)}%`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(10, 8),
		sizeConstraint = UDim2.new(0.6, -14, 0, 16),
		zIndex = 613,
	}), React.createElement(Text, {
		value = if social.Premium then `PREMIUM +{math.floor(social.PremiumBonus * 100 + 0.5)}%` else "Play with friends for more output",
		size = 10,
		color = if social.Premium then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(10, 25),
		sizeConstraint = UDim2.new(0.6, -14, 0, 14),
		zIndex = 613,
	}), React.createElement("frame", {
		Size = UDim2.new(0.6, -20, 0, 3),
		Position = UDim2.fromOffset(10, 43),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 613,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(friendProgress, 0, 1, 0),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(0.4, -8, 0, 36),
		Position = UDim2.new(0.6, 0, 0.5, -18),
		BackgroundTransparency = 1,
		ZIndex = 614,
	}, React.createElement(Button, {
		text = if inviteBusy then "OPENING" else "INVITE",
		icon = "Crew",
		onClick = invite,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = inviteBusy,
		highlight = true,
		zIndex = 614,
	}))), showSearch and React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = Palette.cyan,
		placeholder = "Find a player",
		position = UDim2.fromOffset(10, controlsTop),
		size = UDim2.fromOffset(innerW, 30),
		reducedMotion = reducedMotion,
		zIndex = 616,
	}), React.createElement("scrollingframe", {
		Size = UDim2.fromOffset(innerW, 30),
		Position = UDim2.fromOffset(10, controlsTop + (if showSearch then 38 else 0)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ZIndex = 615,
	}, chips), React.createElement("scrollingframe", {
		Size = UDim2.fromOffset(innerW, listH),
		Position = UDim2.fromOffset(10, listTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.cyan,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		ZIndex = 619,
	}, listChildren), reportTarget ~= nil and React.createElement(ReportSheet, {
		target = reportTarget,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		width = math.min(innerW, 420),
		maxHeight = height - 20,
		onBlock = function()
			promptCore("PromptBlockPlayer", reportTarget)
		end,
		onClose = function()
			setReportTarget(nil)
		end,
	}))))
end
return {
	PlayerlistOverlay = PlayerlistOverlay,
}
end

__defs["onboarding"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local lighten = _theme.lighten
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local AutoHeightText = _ui.AutoHeightText
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local OverlayPresence = _ui.OverlayPresence
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local SharedDataSuite = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
local TutorialScript = SharedDataSuite("TutorialScript")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PET_SIZE = 56
local TYPE_RATE = 46
local AUTO_ADVANCE_SECONDS = 1.1
local SPARKS = 12
local HEARTS = 5
local TRAIL = 9
local ZZZ = 3
local SLEEP_AFTER = 14
local pixelPosition = _ui.pixelPosition
local useGuiSize = _ui.useGuiSize
local function approach(current, goal, rate, dt)
	return current + (goal - current) * (1 - math.exp(-rate * dt))
end
local function blankFrame(width, height)
	return {
		spot = { x = 0, y = 0, w = 0, h = 0, a = 0 },
		pet = {
			x = width * 0.5, y = height * 0.6, tilt = 0, sx = 1, sy = 1, lookX = 0, lookY = 0, pupil = 7, blink = 0,
			point = 90, reach = 0, poke = 0, wingA = 0, wingL = 0.7, mouth = 3, mouthW = 11, happy = 0, glow = 0,
			tipX = 0, tipY = 0, shadow = 1, sleep = 0,
		},
		chars = 0,
		sparks = {},
		hearts = {},
		trail = {},
		zzz = 0,
		dockY = height - 260,
		dockTop = false,
		bubbleX = 8,
		bubbleY = 0,
		bubbleAbove = true,
		bubbleScale = 1,
		t = 0,
	}
end

local function shown(instance)
	if instance == nil or instance.Parent == nil or not instance:IsA("GuiObject") then
		return false
	end
	if instance.AbsoluteSize.X < 4 or instance.AbsoluteSize.Y < 4 then
		return false
	end
	local node = instance
	while node ~= nil do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end
local function findTarget(name)
	if type(name) == "table" then
		for _, candidate in name do
			local found = findTarget(candidate)
			if found ~= nil then
				return found
			end
		end
		return nil
	end
	if name == nil then
		return nil
	end
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local quick = playerGui:FindFirstChild(name, true)
	if shown(quick) then
		return quick
	end
	for _, candidate in playerGui:GetDescendants() do
		if candidate.Name == name and shown(candidate) then
			return candidate
		end
	end
	return nil
end

local function TutorialOverlay(_param)
	local copy = _param.copy
	local step = _param.step
	local count = _param.count
	local reducedMotion = _param.reducedMotion
	local ctaLabel = _param.ctaLabel
	local onCta = _param.onCta
	local onNext = _param.onNext
	local onBack = _param.onBack
	local onSkip = _param.onSkip
	local onJump = _param.onJump
	local viewport = useViewport()
	local soft = React.useContext(_motion.MotionSettingsContext).soft == true
	local live = if type(_param.live) == "table" then _param.live else {}

	local vaultNow = if type(live.vaultFlux) == "number" then live.vaultFlux else 0
	local collected, setCollected = React.useState(false)
	local vaultMark = React.useRef(vaultNow)
	React.useEffect(function()
		setCollected(false)
		vaultMark.current = vaultNow
	end, { step })
	React.useEffect(function()
		if copy.watch == "collect" and vaultNow < vaultMark.current - 0.5 then
			setCollected(true)
		end
	end, { step, vaultNow })
	local met = TutorialScript.goalMet(copy, live, collected)
	local needsAction = TutorialScript.needsAction(copy)

	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local requestNext = React.useCallback(function()
		if exiting then
			return nil
		end
		if step >= count then
			beginExit(onNext)
		else
			onNext()
		end
	end, { beginExit, count, exiting, onNext, step })
	local requestSkip = React.useCallback(function()
		if not exiting then
			beginExit(onSkip)
		end
	end, { beginExit, exiting, onSkip })

	React.useEffect(function()
		Audio:play(if step == 1 then "modalOpen" else "tutorialStep")
	end, { step })
	React.useEffect(function()
		if met and needsAction then
			Audio:play("successChime")
		end
	end, { met, needsAction, step })
	React.useEffect(function()
		if not (met and needsAction and copy.auto) then
			return nil
		end
		local job = task.delay(AUTO_ADVANCE_SECONDS, function()
			requestNext()
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { met, needsAction, step, requestNext })

	local stateRef = React.useRef({})
	stateRef.current = { step = step, exiting = exiting, met = met, needsAction = needsAction, onBack = onBack, onCta = onCta, requestNext = requestNext }
	React.useEffect(function()
		ContextActionService:BindActionAtPriority("AstralForgeTutorialBack", function(_name, inputState)
			local current = stateRef.current
			if inputState == Enum.UserInputState.Begin and current.step > 1 and not current.exiting then
				current.onBack()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		ContextActionService:BindActionAtPriority("AstralForgeTutorialConfirm", function(_name, inputState)
			local current = stateRef.current
			if not current.exiting and current.needsAction and not current.met and current.onCta == nil then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin and not current.exiting then
				if current.needsAction and not current.met and current.onCta ~= nil then
					current.onCta()
				elseif current.met then
					current.requestNext()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonA)
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			ContextActionService:UnbindAction("AstralForgeTutorialBack")
			ContextActionService:UnbindAction("AstralForgeTutorialConfirm")
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})

	local sideInset = math.max(10, viewport.sideInset)
	local phone = viewport.width < 720 or viewport.height < 560
	local dockW = math.min(if phone then viewport.width - sideInset * 2 else 520, viewport.width - sideInset * 2)
	local innerW = dockW - 28
	local hasCta = ctaLabel ~= nil and onCta ~= nil and needsAction and not met
	local layoutRef = React.useRef({})
	layoutRef.current = { dockW = dockW, top = viewport.topInset, bottom = viewport.bottomInset }

	local rootRef = React.useRef(nil)
	local rootSize = useGuiSize(rootRef, false)
	local probeRef = React.useRef(nil)
	local dockRef = React.useRef(nil)
	local frame, setFrame = React.useBinding(blankFrame(viewport.width, viewport.height))
	local sizedFrame = React.joinBindings({ frame, rootSize })
	local petState = React.useRef(nil)
	if petState.current == nil then
		local sparks, hearts, trail = {}, {}, {}
		for i = 1, SPARKS do
			sparks[i] = { x = 0, y = 0, vx = 0, vy = 0, age = 1, life = 1 }
		end
		for i = 1, HEARTS do
			hearts[i] = { x = 0, y = 0, vx = 0, vy = 0, age = 1, life = 1 }
		end
		for i = 1, TRAIL do
			trail[i] = { x = -100, y = -100, age = 1, life = 1 }
		end
		petState.current = {
			x = viewport.width * 0.5, y = viewport.height * 0.6, vx = 0, vy = 0,
			spot = { x = 0, y = 0, w = 0, h = 0, a = 0 },
			target = nil, targetName = nil, lastSearch = 0,
			nextBlink = 1.5, blinkAt = -10, doubleBlink = false,
			chars = 0, lastTick = 0,
			mouse = Vector2.new(-1000, -1000), mouseMovedAt = 0, nearPet = false,
			spinAt = -10, celebrateAt = -10, hopAt = -10, clickTimes = {}, dizzyUntil = -10,
			rub = 0, lastHeart = -10, lastPetQuip = -10, sleeping = false,
			tipX = 0, tipY = 0, tipVX = 0, tipVY = 0,
			wingPhase = 0, flapRate = 10, mouthH = 3, mouthW = 11, happy = 0, glow = 0, pupil = 7,
			lookX = 0, lookY = 0, reach = 0, sleep = 0, tilt = 0, squash = 0, squashV = 0,
			sparks = sparks, sparkNext = 1, hearts = hearts, heartNext = 1, trail = trail, trailNext = 1, trailAt = 0,
			dockY = nil, bubblePopAt = 0,
			t = 0,
		}
	end
	React.useEffect(function()
		local redirecting = false
		local function constrainSelection()
			if redirecting or not UserInputService.GamepadEnabled then return end
			local selected = GuiService.SelectedObject
			local root, target = rootRef.current, petState.current.target
			if selected == nil or (root and selected:IsDescendantOf(root)) or (target and (selected == target or selected:IsDescendantOf(target))) then return end
			redirecting = true
			local assigned = target and GamepadNavigationService.AssignSelection(target)
			for _, scope in { target, dockRef.current } do
				if scope and not assigned then
					for _, candidate in scope:GetDescendants() do
						if candidate:IsA("GuiButton") and GamepadNavigationService.AssignSelection(candidate) then assigned = true; break end
					end
				end
			end
			if not assigned then GamepadNavigationService.ClearSelection() end
			redirecting = false
		end
		local connection = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(constrainSelection)
		constrainSelection()
		return function() connection:Disconnect() end
	end, {})
	local quip, setQuip = React.useState(nil)
	local quipToken = React.useRef(0)
	local sayQuip = React.useCallback(function(pool)
		if type(pool) ~= "table" or #pool == 0 then
			return
		end
		quipToken.current += 1
		local token = quipToken.current
		setQuip(pool[math.random(1, #pool)])
		task.delay(2.8, function()
			if quipToken.current == token then
				setQuip(nil)
			end
		end)
	end, {})
	local say = quip or copy.say or copy.body
	React.useEffect(function()
		local st = petState.current
		st.chars = 0
		st.bubblePopAt = st.t
	end, { say })
	local burst = React.useCallback(function(amount, speedMin, speedMax)
		local st = petState.current
		for _ = 1, amount do
			local spark = st.sparks[st.sparkNext]
			st.sparkNext = st.sparkNext % SPARKS + 1
			local angle = math.random() * math.pi * 2
			local speed = speedMin + math.random() * (speedMax - speedMin)
			spark.x, spark.y = 0, 0
			spark.vx, spark.vy = math.cos(angle) * speed, math.sin(angle) * speed - 40
			spark.age, spark.life = 0, 0.6 + math.random() * 0.35
		end
	end, {})
	React.useEffect(function()
		if met and needsAction then
			local st = petState.current
			st.celebrateAt = st.t
			st.squashV += 5
			burst(SPARKS, 90, 170)
		end
	end, { met, needsAction, step })

	React.useEffect(function()
		-- reused every frame so the pet loop does not allocate
		local rectBuf = { x = 0, y = 0, w = 0, h = 0 }
		local dockRect = { x = 0, y = 0, w = 0, h = 0 }
		local connection = RunService.RenderStepped:Connect(function(rawDt)
			local dt = math.min(rawDt, 1 / 20)
			local st = petState.current
			local root = rootRef.current
			local probe = probeRef.current
			if root == nil or probe == nil then
				return
			end
			st.t += dt
			local t = st.t
			local k = math.max(0.01, probe.AbsoluteSize.X / 100)
			local origin = root.AbsolutePosition
			local screenW = root.AbsoluteSize.X / k
			local screenH = root.AbsoluteSize.Y / k
			local amp = if soft then 0.65 else 1
			local layout = layoutRef.current

			if st.targetName ~= copy.target then
				st.targetName = copy.target
				st.target = nil
				st.lastSearch = 0
			end
			if (st.target == nil or not shown(st.target)) and t - st.lastSearch > 0.25 then
				st.lastSearch = t
				st.target = findTarget(copy.target)
			end
			local rect = nil
			if st.target ~= nil and shown(st.target) then
				local pad = 6
				local p = (st.target.AbsolutePosition - origin) / k
				local s = st.target.AbsoluteSize / k
				rectBuf.x, rectBuf.y, rectBuf.w, rectBuf.h = p.X - pad, p.Y - pad, s.X + pad * 2, s.Y + pad * 2
				rect = rectBuf
			end
			local spot = st.spot
			local ease = 1 - math.exp(-dt * 11)
			if rect ~= nil then
				if spot.a < 0.02 then
					spot.x, spot.y, spot.w, spot.h = rect.x - 30, rect.y - 30, rect.w + 60, rect.h + 60
				end
				spot.x += (rect.x - spot.x) * ease
				spot.y += (rect.y - spot.y) * ease
				spot.w += (rect.w - spot.w) * ease
				spot.h += (rect.h - spot.h) * ease
				spot.a += (1 - spot.a) * ease
			else
				spot.a += (0 - spot.a) * ease
			end
			local lit = if spot.a > 0.3 then rect else nil

			local dock = dockRef.current
			local cardH = if dock ~= nil and dock.AbsoluteSize.Y > 1 then dock.AbsoluteSize.Y / k else 220
			local goalDockY, dockSide = TutorialScript.dockPlacement(lit, screenH, cardH, layout.top / k, layout.bottom / k)
			st.dockY = if st.dockY == nil then goalDockY else approach(st.dockY, goalDockY, 10, dt)
			dockRect.x, dockRect.y, dockRect.w, dockRect.h = (screenW - layout.dockW) / 2, st.dockY, layout.dockW, cardH

			local mouseScreen = UserInputService:GetMouseLocation()
			if st.screenGui == nil then
				st.screenGui = root:FindFirstAncestorOfClass("ScreenGui")
			end
			local screenGui = st.screenGui
			local inset = if screenGui ~= nil and screenGui.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
			local mouse = (mouseScreen - inset - origin) / k
			local moved = (mouse - st.mouse).Magnitude
			local mouseDistance = (Vector2.new(st.x, st.y) - mouse).Magnitude
			local hovering = mouseDistance < PET_SIZE * 0.6
			if moved > 2 then
				local speed = moved / math.max(dt, 1e-3)
				st.mouse = mouse
				if st.sleeping then
					st.sleeping = false
					st.vy -= 200
					st.squashV -= 5
					Audio:play("modalPop")
					sayQuip(TutorialScript.QUIPS.wake)
				end
				st.mouseMovedAt = t
				if speed > 2400 and mouseDistance < 90 and t - st.hopAt > 0.8 then
					st.hopAt = t
					st.vy -= 260
					st.squashV -= 4
					Audio:play("hoverTick")
				end
				if hovering then
					st.rub += moved
				end
			end
			st.rub *= math.exp(-dt * 1.4)
			if st.rub > 240 and t - st.lastHeart > 0.32 then
				st.lastHeart = t
				st.rub = 110
				local heart = st.hearts[st.heartNext]
				st.heartNext = st.heartNext % HEARTS + 1
				heart.x, heart.y = (math.random() - 0.5) * 24, -PET_SIZE * 0.35
				heart.vx, heart.vy = (math.random() - 0.5) * 30, -70 - math.random() * 30
				heart.age, heart.life = 0, 1.1
				st.happy = 1
				Audio:play("hoverTick")
				if t - st.lastPetQuip > 5 then
					st.lastPetQuip = t
					sayQuip(TutorialScript.QUIPS.pet)
				end
			end
			if hovering and not st.nearPet then
				Audio:play("hoverTick")
				st.squashV += 2.5
			end
			st.nearPet = hovering

			local total = utf8.len(say) or #say
			if st.chars < total then
				local before = math.floor(st.chars)
				st.chars = math.min(total, st.chars + dt * TYPE_RATE)
				if math.floor(st.chars) // 5 > before // 5 and t - st.lastTick > 0.07 then
					st.lastTick = t
					Audio:play("tick")
				end
			end
			local talking = st.chars < total
			if not talking and not st.sleeping and t - st.mouseMovedAt > SLEEP_AFTER and t - st.celebrateAt > 3 then
				st.sleeping = true
			end
			st.sleep = approach(st.sleep, if st.sleeping then 1 else 0, if st.sleeping then 1.6 else 9, dt)
			local dizzy = t < st.dizzyUntil

			local goalX, goalY, pointAngle = TutorialScript.petPose(lit, screenW, screenH, PET_SIZE, dockRect)
			if mouseDistance < 140 and mouseDistance > 1 and not st.sleeping then
				local away = (Vector2.new(st.x, st.y) - mouse).Unit
				local push = (1 - mouseDistance / 140) * 22 * amp
				goalX += away.X * push
				goalY += away.Y * push
			end
			goalY += st.sleep * 10
			local steps = math.max(1, math.ceil(dt / (1 / 120)))
			local h = dt / steps
			for _ = 1, steps do
				st.vx += ((goalX - st.x) * 55 - st.vx * 11.5) * h
				st.vy += ((goalY - st.y) * 55 - st.vy * 11.5) * h
				st.x += st.vx * h
				st.y += st.vy * h
				st.squashV += (-st.squash * 380 - st.squashV * 13) * h
				st.squash += st.squashV * h
				st.tipVX += ((-st.vx * 0.02 - st.tipX) * 120 - st.tipVX * 10) * h
				st.tipVY += ((-st.vy * 0.02 - st.tipY) * 120 - st.tipVY * 10) * h
				st.tipX += st.tipVX * h
				st.tipY += st.tipVY * h
			end
			local speed = math.sqrt(st.vx * st.vx + st.vy * st.vy)
			local breathe = 1 - st.sleep * 0.6
			local bob = (math.sin(t * 2.3) * 5 + math.sin(t * 3.7) * 1.5) * amp * breathe

			local flapGoal = (9 + math.clamp(speed / 110, 0, 9) + (if t - st.celebrateAt < 1.2 then 6 else 0)) * (1 - st.sleep * 0.7)
			st.flapRate = approach(st.flapRate, flapGoal, 4, dt)
			st.wingPhase += dt * st.flapRate
			local wingA = math.sin(st.wingPhase) * 30 * amp
			local wingL = 0.7 + math.sin(st.wingPhase + 0.9) * 0.12

			if t >= st.nextBlink then
				st.blinkAt = t
				st.doubleBlink = math.random() < 0.22
				st.nextBlink = t + 2 + math.random() * 3
			end
			local since = t - st.blinkAt
			local blink = 0
			if since < 0.16 then
				blink = math.sin(since / 0.16 * math.pi)
			elseif st.doubleBlink and since > 0.22 and since < 0.38 then
				blink = math.sin((since - 0.22) / 0.16 * math.pi)
			end
			blink = math.max(blink, st.sleep * 0.88)

			local lookAt = if t - st.mouseMovedAt < 1.6 then mouse elseif rect ~= nil then Vector2.new(rect.x + rect.w / 2, rect.y + rect.h / 2) else Vector2.new(st.x, st.y + 40)
			local look = lookAt - Vector2.new(st.x, st.y + bob)
			local lookUnit = if look.Magnitude > 1 then look.Unit * math.min(1, look.Magnitude / 60) else Vector2.zero
			local lookGoalX = if dizzy then math.cos(t * 9) * 3 else lookUnit.X * 3.2
			local lookGoalY = if dizzy then math.sin(t * 9) * 3 else lookUnit.Y * 3.2
			st.lookX = approach(st.lookX, lookGoalX, if dizzy then 40 else 16, dt)
			st.lookY = approach(st.lookY, lookGoalY, if dizzy then 40 else 16, dt)
			st.pupil = approach(st.pupil, if hovering then 8.5 elseif dizzy then 5.5 else 7, 12, dt)

			local celebrate = t - st.celebrateAt
			local happyGoal = if hovering or celebrate < 1.6 or met or st.rub > 60 then 1 else 0
			st.happy = approach(st.happy, happyGoal, 6, dt)
			st.glow = approach(st.glow, if hovering then 1 else 0, 10, dt)
			local mouthGoal = if talking then 3.5 + 3.2 * (0.5 + 0.5 * math.sin(t * 17)) * (0.6 + 0.4 * math.sin(t * 5.3))
				elseif st.sleeping then 3
				elseif dizzy then 4
				elseif st.happy > 0.5 then 6
				else 3
			st.mouthH = approach(st.mouthH, mouthGoal, 22, dt)
			st.mouthW = approach(st.mouthW, if st.happy > 0.5 and not talking then 16 elseif st.sleeping then 6 else 11, 14, dt)

			-- audit-ignore: per-frame (setFrame needs fresh tables each frame or React skips the render)
			local sparkOut = {}
			for i, spark in st.sparks do
				if spark.age < spark.life then
					spark.age += dt
					spark.vy += 260 * dt
					spark.vx *= math.exp(-dt * 1.2)
					spark.x += spark.vx * dt
					spark.y += spark.vy * dt
					sparkOut[i] = { x = spark.x, y = spark.y, a = spark.age / spark.life }
				end
			end
			local heartOut = {}
			for i, heart in st.hearts do
				if heart.age < heart.life then
					heart.age += dt
					heart.x += (heart.vx + math.sin(heart.age * 9 + i) * 24) * dt
					heart.y += heart.vy * dt
					heartOut[i] = { x = heart.x, y = heart.y, a = heart.age / heart.life }
				end
			end
			if speed > 240 and t - st.trailAt > 0.035 then
				st.trailAt = t
				local mote = st.trail[st.trailNext]
				st.trailNext = st.trailNext % TRAIL + 1
				mote.x, mote.y, mote.age, mote.life = st.x, st.y + bob, 0, 0.42
			end
			local trailOut = {}
			for i, mote in st.trail do
				if mote.age < mote.life then
					mote.age += dt
					trailOut[i] = { x = mote.x, y = mote.y, a = mote.age / mote.life }
				end
			end

			local spinAge = t - st.spinAt
			local spin = 0
			if spinAge < 0.6 then
				local s = spinAge / 0.6
				spin = 360 * (1 + 2.2 * (s - 1) ^ 3 + 1.2 * (s - 1) ^ 2)
			end
			local tiltGoal = math.clamp(st.vx * 0.05, -18, 18) * amp + (if dizzy then math.sin(t * 7) * 14 * amp else 0) + st.sleep * 12
			st.tilt = approach(st.tilt, tiltGoal, 12, dt)
			local hop = if celebrate < 0.5 then math.sin(celebrate / 0.5 * math.pi) * 18 * amp else 0
			local stretch = math.clamp(math.abs(st.vy) / 900, 0, 0.1) * amp
			local squash = st.squash * amp
			local breath = math.sin(t * 2.1) * 0.02 * breathe

			st.reach = approach(st.reach, if lit ~= nil and not st.sleeping then 1 else 0, 9, dt)

			local bubbleW = math.min(250, screenW - 16)
			local bubbleH = 64
			local petY = st.y + bob - hop
			local aboveY = petY - PET_SIZE / 2 - 12 - bubbleH
			local belowY = petY + PET_SIZE / 2 + 12
			local function hitsCard(y)
				return y < dockRect.y + dockRect.h and y + bubbleH > dockRect.y
			end
			local above = aboveY > 8 and not hitsCard(aboveY)
			if not above and (belowY + bubbleH > screenH - 8 or hitsCard(belowY)) and aboveY > 8 then
				above = true
			end
			local popAge = t - st.bubblePopAt
			local bubbleScale = if popAge < 0.35 then 1 + 2.4 * ((popAge / 0.35) - 1) ^ 3 + 1.4 * ((popAge / 0.35) - 1) ^ 2 else 1

			setFrame({
				spot = { x = spot.x, y = spot.y, w = spot.w, h = spot.h, a = spot.a },
				pet = {
					x = st.x,
					y = petY,
					tilt = st.tilt + spin,
					sx = 1 + squash - stretch * 0.5 - breath * 0.5,
					sy = 1 - squash + stretch + breath,
					lookX = st.lookX,
					lookY = st.lookY,
					pupil = st.pupil,
					blink = blink,
					point = pointAngle,
					reach = st.reach,
					poke = (math.sin(t * 6) + 1) * 0.5,
					wingA = wingA,
					wingL = wingL,
					mouth = st.mouthH,
					mouthW = st.mouthW,
					happy = st.happy,
					glow = st.glow,
					tipX = st.tipX,
					tipY = st.tipY,
					shadow = 1 - (bob + hop) * 0.012,
					sleep = st.sleep,
				},
				chars = math.floor(st.chars),
				sparks = sparkOut,
				hearts = heartOut,
				trail = trailOut,
				zzz = st.sleep,
				dockY = st.dockY,
				dockTop = dockSide == "top",
				bubbleX = math.clamp(st.x - bubbleW / 2, 8, math.max(8, screenW - bubbleW - 8)),
				bubbleY = if above then petY - PET_SIZE / 2 - 12 else belowY,
				bubbleAbove = above,
				bubbleScale = math.max(0.01, bubbleScale),
				t = t,
			})
		end)
		return function()
			connection:Disconnect()
		end
	end, { copy, say, met, soft, sayQuip })

	local onPetClick = function()
		local st = petState.current
		local now = st.t
		table.insert(st.clickTimes, now)
		while #st.clickTimes > 0 and now - st.clickTimes[1] > 1.2 do
			table.remove(st.clickTimes, 1)
		end
		st.squashV += 6
		st.sleeping = false
		st.mouseMovedAt = now
		burst(5, 60, 110)
		if #st.clickTimes >= 3 then
			st.clickTimes = {}
			st.dizzyUntil = now + 1.8
			st.spinAt = now
			Audio:play("locked")
			sayQuip(TutorialScript.QUIPS.dizzy)
			return
		end
		st.spinAt = now
		Audio:play("modalPop")
		sayQuip(if met then TutorialScript.QUIPS.done else TutorialScript.QUIPS.idle)
	end

	local dimColor = Palette.void
	local dimAlpha = 1
	local function dim(key, sizeFn, posFn)
		return React.createElement("textbutton", {
			key = key,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Size = frame:map(sizeFn),
			Position = frame:map(posFn),
			BackgroundColor3 = dimColor,
			BackgroundTransparency = React.joinBindings({ frame, reveal }):map(function(values)
				return 1 - math.clamp(values[2], 0, 1) * dimAlpha
			end),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 380,
		})
	end
	local spotlight = React.createElement(React.Fragment, nil, dim("top", function(f)
		return UDim2.new(1, 0, 0, math.max(0, f.spot.y))
	end, function()
		return UDim2.fromScale(0, 0)
	end), dim("bottom", function(f)
		return UDim2.new(1, 0, 1, -math.max(0, f.spot.y + f.spot.h))
	end, function(f)
		return UDim2.fromOffset(0, f.spot.y + f.spot.h)
	end), dim("left", function(f)
		return UDim2.fromOffset(math.max(0, f.spot.x), math.max(0, f.spot.h))
	end, function(f)
		return UDim2.fromOffset(0, f.spot.y)
	end), dim("right", function(f)
		return UDim2.new(1, -math.max(0, f.spot.x + f.spot.w), 0, math.max(0, f.spot.h))
	end, function(f)
		return UDim2.fromOffset(f.spot.x + f.spot.w, f.spot.y)
	end), React.createElement("frame", {
		key = "ring",
		Size = frame:map(function(f)
			local grow = 3 + math.sin(f.t * 3.2) * 3
			return UDim2.fromOffset(f.spot.w + grow * 2, f.spot.h + grow * 2)
		end),
		Position = frame:map(function(f)
			local grow = 3 + math.sin(f.t * 3.2) * 3
			return UDim2.fromOffset(f.spot.x - grow, f.spot.y - grow)
		end),
		BackgroundTransparency = 1,
		Active = false,
		Visible = frame:map(function(f)
			return f.spot.a > 0.05
		end),
		ZIndex = 381,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 2.5,
		Transparency = frame:map(function(f)
			return 1 - math.clamp(f.spot.a, 0, 1) * (0.55 + 0.45 * (math.sin(f.t * 3.2) + 1) * 0.5)
		end),
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.mango, Palette.cream),
		Rotation = frame:map(function(f)
			return (f.t * 90) % 360
		end),
	}))))

	local petColor = Palette.mango
	local petShade = Palette.ember
	local petLine = Color3.fromRGB(74, 36, 18)
	local function outline(thickness)
		return React.createElement("uistroke", {
			Color = petLine,
			Thickness = thickness or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end
	local function poolLabels(prefix, n, getList, build)
		local out = {}
		for i = 1, n do
			out[prefix .. i] = build(i, function(f)
				return getList(f)[i]
			end)
		end
		return out
	end
	local sparkEls = poolLabels("s", SPARKS, function(f)
		return f.sparks
	end, function(i, get)
		return React.createElement("frame", {
			Size = frame:map(function(f)
				local spark = get(f)
				local size = if spark == nil then 0 else 7 * (1 - spark.a * 0.6)
				return UDim2.fromScale(size / PET_SIZE, size / PET_SIZE)
			end),
			Position = frame:map(function(f)
				local spark = get(f)
				return if spark == nil then UDim2.fromOffset(-50, -50) else UDim2.fromScale(0.5 + spark.x / PET_SIZE, 0.5 + spark.y / PET_SIZE)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = if i % 3 == 0 then Palette.mango elseif i % 3 == 1 then Palette.cream else Palette.ember,
			BackgroundTransparency = frame:map(function(f)
				local spark = get(f)
				return if spark == nil then 1 else spark.a ^ 1.6
			end),
			BorderSizePixel = 0,
			ZIndex = 418,
		})
	end)
	local heartEls = poolLabels("h", HEARTS, function(f)
		return f.hearts
	end, function(_i, get)
		return React.createElement("textlabel", {
			Size = UDim2.fromOffset(18, 18),
			Position = frame:map(function(f)
				local heart = get(f)
				return if heart == nil then UDim2.fromOffset(-50, -50) else UDim2.fromScale(0.5 + heart.x / PET_SIZE, 0.5 + heart.y / PET_SIZE)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "♥",
			TextColor3 = Palette.pink,
			TextSize = frame:map(function(f)
				local heart = get(f)
				return if heart == nil then 1 else 12 + 8 * math.min(1, heart.a * 4)
			end),
			TextTransparency = frame:map(function(f)
				local heart = get(f)
				return if heart == nil then 1 else heart.a ^ 2
			end),
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			ZIndex = 418,
		})
	end)
	local zzzEls = {}
	for i = 1, ZZZ do
		zzzEls["z" .. i] = React.createElement("textlabel", {
			Size = UDim2.fromOffset(16, 16),
			Position = frame:map(function(f)
				local phase = (f.t * 0.45 + i / ZZZ) % 1
				return UDim2.fromScale(0.82 + (phase * 18 + math.sin(phase * 6 + i) * 4) / PET_SIZE, 0.08 - phase * 34 / PET_SIZE)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "z",
			TextColor3 = Palette.creamSoft,
			TextSize = frame:map(function(f)
				local phase = (f.t * 0.45 + i / ZZZ) % 1
				return 10 + phase * 8
			end),
			TextTransparency = frame:map(function(f)
				local phase = (f.t * 0.45 + i / ZZZ) % 1
				return 1 - f.zzz * math.sin(phase * math.pi)
			end),
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			ZIndex = 418,
		})
	end
	local effectEls = {}
	for _, pool in { sparkEls, heartEls, zzzEls } do
		for key, element in pool do
			effectEls[key] = element
		end
	end
	local trailEls = {}
	for i = 1, TRAIL do
		trailEls["t" .. i] = React.createElement("frame", {
			Size = sizedFrame:map(function(values)
				local mote = values[1].trail[i]
				local size = if mote == nil then 0 else 7 * (1 - mote.a)
				return pixelPosition(values[2], 0, size, 0, size)
			end),
			Position = sizedFrame:map(function(values)
				local mote = values[1].trail[i]
				return if mote == nil then UDim2.fromOffset(-100, -100) else pixelPosition(values[2], 0, mote.x, 0, mote.y + PET_SIZE * 0.2)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if i % 2 == 0 then petColor else petShade,
			BackgroundTransparency = frame:map(function(f)
				local mote = f.trail[i]
				return if mote == nil then 1 else 0.15 + mote.a * 0.85
			end),
			BorderSizePixel = 0,
			ZIndex = 403,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	local pet = React.createElement("frame", {
		Name = "Bolt",
		Size = UDim2.fromOffset(PET_SIZE, PET_SIZE),
		Position = sizedFrame:map(function(values)
			return pixelPosition(values[2], 0, values[1].pet.x, 0, values[1].pet.y)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 405,
	}, React.createElement("frame", {
		Size = frame:map(function(f) return UDim2.fromScale(0.7 * f.pet.shadow, 0.12 * f.pet.shadow) end),
		Position = UDim2.new(0.5, 0, 0.5, PET_SIZE * 0.7), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.void, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 406,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
	React.createElement("frame", {
		Name = "BoltPointer",
		Size = frame:map(function(f) return UDim2.fromScale((PET_SIZE * 0.5 + 16 + f.pet.poke * 8) * f.pet.reach / PET_SIZE, 5 / PET_SIZE) end),
		Position = frame:map(function(f)
			local length = (PET_SIZE * 0.5 + 16 + f.pet.poke * 8) * f.pet.reach
			local angle = math.rad(f.pet.point)
			return UDim2.fromScale(0.5 + math.cos(angle) * length / (2 * PET_SIZE), 0.5 + math.sin(angle) * length / (2 * PET_SIZE))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = frame:map(function(f) return f.pet.point end),
		BackgroundColor3 = petColor, BorderSizePixel = 0, ZIndex = 410,
		Visible = frame:map(function(f) return f.pet.reach > 0.03 end),
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), outline(1.5)),
	React.createElement("textbutton", {
		Name = "BoltTouchTarget", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, BorderSizePixel = 0,
		Size = frame:map(function(f) return UDim2.fromScale(f.pet.sx, f.pet.sy) end),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = frame:map(function(f) return f.pet.tilt end), ZIndex = 412,
		Event = { Activated = onPetClick },
	}, React.createElement("imagelabel", {
		Name = "BoltSprite", Image = "rbxassetid://70681368255210", ImageRectSize = Vector2.new(128, 128),
		ImageRectOffset = frame:map(function(f)
			local phase = if reducedMotion or soft then 0 else math.floor(f.t * 8) % 4
			local index = if f.pet.sleep > 0.5 then 6 + phase % 2 elseif f.pet.blink > 0.5 then 4 + phase % 2 elseif f.pet.happy > 0.4 then 8 + phase else phase
			return Vector2.new((index % 4) * 128, math.floor(index / 4) * 128)
		end),
		Size = UDim2.fromScale(2, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.625),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 413,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 417,
	}, effectEls))

	local bubbleW = math.min(250, viewport.width - 24)
	local bubble = React.createElement("frame", {
		Size = UDim2.fromOffset(bubbleW, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = sizedFrame:map(function(values)
			return pixelPosition(values[2], 0, values[1].bubbleX, 0, values[1].bubbleY)
		end),
		AnchorPoint = frame:map(function(f)
			return Vector2.new(0, if f.bubbleAbove then 1 else 0)
		end),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		ZIndex = 420,
	}, React.createElement("uiscale", {
		Scale = frame:map(function(f)
			return f.bubbleScale
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1.5,
		Transparency = 0.45,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = say,
		MaxVisibleGraphemes = frame:map(function(f)
			return f.chars
		end),
		TextColor3 = Palette.ink,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 421,
	}))

	local dots = {}
	dots.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	for n = 1, count do
		dots["d" .. n] = React.createElement("textbutton", {
			Size = UDim2.new(1 / count, -4, 0, if n == step then 8 else 5),
			LayoutOrder = n,
			BackgroundColor3 = if n < step or (n == step and met and needsAction) then Palette.mint elseif n == step then Palette.mango else Palette.lineSoft,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 403,
			Event = {
				Activated = function()
					if n ~= step and not exiting then
						onJump(n)
					end
				end,
			},
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	local primary
	if met or not needsAction then
		primary = {
			text = if step >= count then "FINISH" elseif met and needsAction then "NICE! CONTINUE" else "CONTINUE",
			icon = if step >= count then "Check" else nil,
			color = Palette.mint,
			textColor = Palette.ink,
			highlight = true,
			onClick = requestNext,
		}
	elseif hasCta then
		primary = {
			text = string.upper(ctaLabel),
			icon = "Play",
			color = Palette.mango,
			textColor = Palette.ink,
			highlight = true,
			onClick = onCta,
		}
	else
		primary = {
			text = "DO IT TO CONTINUE",
			icon = nil,
			color = Palette.panelSoft,
			textColor = Palette.muted,
			highlight = false,
			onClick = function()
				local st = petState.current
				st.spinAt = st.t
				st.squashV += 5
				st.chars = 0
				Audio:play("locked")
			end,
		}
	end
	local goalDone = met and needsAction
	local dock = React.createElement("frame", {
		ref = dockRef,
		Size = UDim2.fromOffset(dockW, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = React.joinBindings({ frame, reveal }):map(function(values)
			local f = values[1]
			local slide = (1 - math.clamp(values[2], 0, 1)) * 24
			return UDim2.new(0.5, 0, 0, f.dockY + (if f.dockTop then -slide else slide))
		end),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 400,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1.5,
		Transparency = 0.35,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		ZIndex = 402,
	}, React.createElement(Text, {
		value = `STEP {step} OF {count}  ·  {string.upper(TutorialScript.PET_NAME)}'S TOUR`,
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		sizeConstraint = UDim2.new(1, -96, 1, 0),
		zIndex = 402,
	}), React.createElement("textbutton", {
		Size = UDim2.new(0, 90, 1, 0),
		Position = UDim2.new(1, -90, 0, 0),
		BackgroundTransparency = 1,
		Text = "SKIP GUIDE",
		TextColor3 = Palette.muted,
		TextSize = 10,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 403,
		Event = {
			Activated = requestSkip,
		},
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		ZIndex = 402,
	}, dots), React.createElement(Text, {
		value = copy.title,
		size = if phone then 16 else 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		sizeConstraint = UDim2.new(1, 0, 0, 24),
		layoutOrder = 3,
		zIndex = 402,
	}), React.createElement(AutoHeightText, {
		value = copy.body,
		width = innerW,
		size = 12,
		color = Palette.creamSoft,
		layoutOrder = 4,
		zIndex = 402,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 5,
		BackgroundTransparency = 1,
		ZIndex = 402,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = if goalDone then Palette.mint else Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 403,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}), React.createElement("uistroke", {
		Color = if goalDone then Palette.mint else Palette.lineSoft,
		Transparency = 0.2,
	}), goalDone and React.createElement(Icon, {
		kind = "Check",
		color = Palette.ink,
		accent = Palette.ink,
		size = 18,
	})), React.createElement(Text, {
		value = string.upper(copy.goal or ""),
		size = 11,
		color = if goalDone then Palette.mint else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(28, 0),
		sizeConstraint = UDim2.new(1, -28, 1, 0),
		zIndex = 403,
	})), copy.controls ~= nil and React.createElement(Text, {
		value = copy.controls,
		size = 10,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		layoutOrder = 6,
		zIndex = 402,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 7,
		BackgroundTransparency = 1,
		ZIndex = 402,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), step > 1 and React.createElement("frame", {
		Size = UDim2.new(0.28, -4, 1, 0),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BACK",
		icon = "Back",
		onClick = onBack,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 403,
	})), React.createElement("frame", {
		Size = UDim2.new(if step > 1 then 0.72 else 1, if step > 1 then -4 else 0, 1, 0),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = primary.text,
		icon = primary.icon,
		onClick = primary.onClick,
		color = primary.color,
		textColor = primary.textColor,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		highlight = primary.highlight,
		zIndex = 403,
	}))))

	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		Name = "TutorialClaimActions",
		ref = rootRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 379,
	}, React.createElement("frame", {
		ref = probeRef,
		Size = UDim2.fromOffset(100, 100),
		BackgroundTransparency = 1,
		Visible = true,
		Active = false,
	}), spotlight, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 403,
	}, trailEls), dock, pet, bubble))
end
local VERSION_ROW_H = 48
local HIGHLIGHT_ROW_H = 46
local VERSION_RIGHT_COLUMN_W = 72
local function versionCardHeight(entry, expanded)
	if not expanded then
		return VERSION_ROW_H
	end
	return VERSION_ROW_H + #entry.Highlights * HIGHLIGHT_ROW_H + 18
end
local function VersionCard(_param)
	local entry = _param.entry
	local index = _param.index
	local current = _param.current
	local expanded = _param.expanded
	local onToggle = _param.onToggle
	local reducedMotion = _param.reducedMotion
	local reveal = useStagger(index, reducedMotion, 0.03, 0.26)
	local accent = if current then Palette.mint else Palette.violet
	local height = versionCardHeight(entry, expanded)
	local _exp = React.createElement("textbutton", {
		Size = UDim2.new(1, 0, 0, VERSION_ROW_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 328,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				onToggle()
			end,
		},
	})
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = accent,
		Thickness = if current then 1.5 else 1,
		Transparency = if current then 0.32 else 0.68,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(3, 22),
		Position = UDim2.fromOffset(10, 13),
		BackgroundColor3 = accent,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ZIndex = 326,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, -(VERSION_RIGHT_COLUMN_W + 28), 0, VERSION_ROW_H),
		Position = UDim2.fromOffset(20, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 326,
	}, React.createElement(Text, {
		value = entry.Version,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, 8),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 326,
	}), React.createElement(Text, {
		value = entry.Title,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 326,
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromOffset(VERSION_RIGHT_COLUMN_W, VERSION_ROW_H),
		Position = UDim2.new(1, -(VERSION_RIGHT_COLUMN_W + 10), 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 327,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Text, {
		value = entry.Date,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 7,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 12),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 327,
	}), current and React.createElement("frame", {
		Size = UDim2.fromOffset(VERSION_RIGHT_COLUMN_W, 17),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 328,
	}, React.createElement(Badge, {
		value = "LATEST",
		accent = Palette.mint,
		filled = true,
		size = UDim2.fromScale(1, 1),
		zIndex = 328,
	})), React.createElement(Text, {
		value = if expanded then "HIDE" else "VIEW",
		size = 9,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, 13),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 327,
	}))
	local _condition = expanded
	if _condition then
		local _exp_6 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local _exp_7 = entry.Highlights
		local _newValue = table.create(#_exp_7)
		local _callback = function(line, lineIndex)
			return React.createElement(Text, {
				key = lineIndex,
				value = `•  {line}`,
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				fit = false,
				layoutOrder = lineIndex,
				sizeConstraint = UDim2.new(1, 0, 0, HIGHLIGHT_ROW_H - 6),
				zIndex = 327,
			})
		end
		for _k, _v in _exp_7 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_7)
		end
		_condition = React.createElement("frame", {
			Size = UDim2.new(1, -30, 0, #entry.Highlights * HIGHLIGHT_ROW_H),
			Position = UDim2.fromOffset(20, VERSION_ROW_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 326,
		}, _exp_6, _newValue)
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ClipsDescendants = false,
	}, _exp, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 325,
	}, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _condition))
end
local function ReleaseNotesModal(_param)
	local version = _param.version
	local season = _param.season
	local announcement = _param.announcement
	local notes = _param.notes
	local history = _param.history
	if history == nil then
		history = {}
	end
	local viewportWidth = _param.viewportWidth
	local viewportHeight = _param.viewportHeight
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local onOpenMail = _param.onOpenMail
	local viewport = useViewport()
	React.useEffect(function()
		Audio:play("modalOpen")
	end, {})
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local closeGuard = React.useRef(false)
	local closeOnce = React.useCallback(function()
		if closeGuard.current then
			return nil
		end
		closeGuard.current = true
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, onClose })
	local closeOnceRef = React.useRef(closeOnce)
	closeOnceRef.current = closeOnce
	React.useEffect(function()
		local actionName = "AstralForgeReleaseClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				closeOnceRef.current()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, {})
	local openMail = React.useCallback(function()
		if closeGuard.current or onOpenMail == nil then
			return nil
		end
		closeGuard.current = true
		beginExit(onOpenMail)
	end, { beginExit, onOpenMail })
	local safeTop = math.max(8, viewport.topInset)
	local safeBottom = math.max(8, viewport.bottomInset)
	local safeSide = math.max(8, viewport.sideInset)
	local width = math.max(240, math.min(650, viewportWidth - safeSide * 2 - 16))
	local availableHeight = math.max(160, viewportHeight - safeTop - safeBottom - 16)
	local height = math.min(530, availableHeight)
	local veryShort = height < 280
	local condensed = height < 420
	local padding = if condensed then 12 else 22
	local contentHeight = math.max(1, height - padding * 2)
	local stackActions = onOpenMail ~= nil and (viewport.compact or width < 430) and height >= 320
	local actionHeight = if stackActions then TapTarget * 2 + 8 else TapTarget
	local headerHeight = if veryShort then 68 elseif condensed then 112 else 148
	local scrollHeight = math.max(1, contentHeight - headerHeight - actionHeight - 10)
	local centerY = safeTop + math.max(0, (viewportHeight - safeTop - safeBottom) / 2)
	local effectiveHistory = if #history > 0 then history else { {
		Version = version,
		Title = season,
		Date = "",
		Highlights = notes,
	} }
	local expandedVersions, setExpandedVersions = React.useState(function()
		return if #effectiveHistory > 0 then { effectiveHistory[1].Version } else {}
	end)
	local toggleVersion = React.useCallback(function(entryVersion)
		setExpandedVersions(function(current)
			local _current = current
			local _entryVersion = entryVersion
			local _result
			if (table.find(_current, _entryVersion) or 0) - 1 >= 0 then
				local _newValue = {}
				local _callback = function(id)
					return id ~= entryVersion
				end
				local _length = 0
				for _k, _v in current do
					if _callback(_v, _k - 1, current) == true then
						_length += 1
						_newValue[_length] = _v
					end
				end
				_result = _newValue
			else
				local _array = {}
				local _length = #_array
				local _currentLength = #current
				table.move(current, 1, _currentLength, _length + 1, _array)
				_length += _currentLength
				_array[_length + 1] = entryVersion
				_result = _array
			end
			return _result
		end)
	end, {})
	local _result = 0
	local _callback = function(total, entry)
		local _exp = total
		local _exp_1 = entry
		local _version = entry.Version
		return _exp + versionCardHeight(_exp_1, (table.find(expandedVersions, _version) or 0) - 1 >= 0)
	end
	for _i = 1, #effectiveHistory do
		_result = _callback(_result, effectiveHistory[_i], _i - 1, effectiveHistory)
	end
	local canvasH = _result + math.max(0, #effectiveHistory - 1) * 8
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
	end, {})
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount * 0.84
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 321,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 322,
	})
	local _exp_2 = React.createElement(Text, {
		value = "WHAT'S NEW",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, -60, 0, 16),
		zIndex = 325,
	})
	local _exp_3 = React.createElement(Text, {
		value = season,
		size = if veryShort then 18 else 25,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, if veryShort then 16 else 20),
		sizeConstraint = UDim2.new(1, -60, 0, if veryShort then 26 else 34),
		zIndex = 325,
	})
	local _exp_4 = React.createElement(Text, {
		value = `VERSION {version}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, if veryShort then 43 else 56),
		sizeConstraint = UDim2.new(1, -60, 0, 15),
		zIndex = 325,
	})
	local _exp_5 = not veryShort and React.createElement(Text, {
		value = announcement,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 78),
		sizeConstraint = UDim2.new(1, -4, 0, if condensed then 26 else 42),
		zIndex = 325,
	})
	local _exp_6 = React.createElement(Meter, {
		value = 1,
		color = Palette.violet,
		position = UDim2.fromOffset(0, if veryShort then 64 elseif condensed then 104 else 130),
		size = UDim2.new(1, 0, 0, 3),
		reducedMotion = reducedMotion,
		shimmer = true,
	})
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -TapTarget, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 328,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = closeOnce,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 328,
	}))
	local _exp_8 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local _newValue = table.create(#effectiveHistory)
	local _callback_1 = function(entry, index)
		local _attributes = {
			key = entry.Version,
			entry = entry,
			index = index,
			current = entry.Version == version,
		}
		local _version = entry.Version
		_attributes.expanded = (table.find(expandedVersions, _version) or 0) - 1 >= 0
		_attributes.onToggle = function()
			return toggleVersion(entry.Version)
		end
		_attributes.reducedMotion = reducedMotion
		return React.createElement(VersionCard, _attributes)
	end
	for _k, _v in effectiveHistory do
		_newValue[_k] = _callback_1(_v, _k - 1, effectiveHistory)
	end
	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 320,
		Visible = reveal:map(function(amount)
			return amount > 0.01
		end),
	}, _exp, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromOffset(width, height),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 0, centerY + math.floor((1 - amount) * 18))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 322,
		Visible = reveal:map(function(amount)
			return amount > 0.015
		end),
	}, _exp_1, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = padding,
		zIndex = 323,
		reveal = reveal,
	}, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, React.createElement("scrollingframe", {
		Size = UDim2.new(1, 0, 0, scrollHeight),
		Position = UDim2.fromOffset(0, headerHeight),
		CanvasSize = UDim2.new(0, 0, 0, canvasH),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.violet,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 324,
	}, _exp_8, _newValue), if stackActions then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, actionHeight),
		Position = UDim2.fromOffset(0, contentHeight - actionHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 327,
	}, React.createElement(Button, {
		text = "GOT IT",
		icon = "Close",
		onClick = closeOnce,
		color = Palette.violet,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	}), onOpenMail ~= nil and React.createElement(Button, {
		text = "OPEN MAIL",
		icon = "Mail",
		onClick = openMail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.fromOffset(0, TapTarget + 8),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	})) else React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.fromOffset(0, contentHeight - TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 327,
	}, onOpenMail ~= nil and React.createElement(Button, {
		text = "OPEN MAIL",
		icon = "Mail",
		onClick = openMail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(0.5, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	}), React.createElement(Button, {
		text = "GOT IT",
		icon = "Close",
		onClick = closeOnce,
		color = Palette.violet,
		textColor = Palette.ink,
		size = if onOpenMail ~= nil then UDim2.new(0.5, -4, 1, 0) else UDim2.fromScale(1, 1),
		position = if onOpenMail ~= nil then UDim2.new(0.5, 4, 0, 0) else nil,
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	}))))))
end
return {
	TutorialOverlay = TutorialOverlay,
	ReleaseNotesModal = ReleaseNotesModal,
}
end

__defs["AdminPrankOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useRotation = _motion.useRotation
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local Panel = _ui.Panel
local Text = _ui.Text
local HUD_STAGE_KINDS = {
	["InvertHud"] = true,
	["SpinHud"] = true,
	["TinyHud"] = true,
	["GiantHud"] = true,
	["ShakeHud"] = true,
}
local function PrankCard(_param)
	local title = _param.title
	local body = _param.body
	local action = _param.action
	local accent = _param.accent
	local height = _param.height
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local width = if chrome.stack then UDim2.new(1, -math.max(24, chrome.sideSafe * 2 + 16), 0, height) else UDim2.new(0, 420, 0, height)
	return React.createElement("frame", {
		Size = width,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 422,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 18,
		zIndex = 422,
		clips = false,
	}, React.createElement(Text, {
		value = "ASTRAL FORGE",
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = title,
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 48),
		position = UDim2.fromOffset(0, 22),
	}), React.createElement(Text, {
		value = body,
		size = 13,
		color = Palette.creamSoft,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 72),
		position = UDim2.fromOffset(0, 74),
	}), React.createElement(Button, {
		text = action,
		onClick = onClose,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		highlight = true,
	})))
end
local function ConfettiBits()
	local bits = {}
	for index = 0, 27 do
		local accent = if index % 4 == 0 then Palette.mango elseif index % 4 == 1 then Palette.cyan elseif index % 4 == 2 then Palette.pink else Palette.violet
		local _arg0 = React.createElement("frame", {
			key = `bit-{index}`,
			Size = UDim2.fromOffset(9 + (index % 3) * 3, 16 + (index % 2) * 6),
			Position = UDim2.new(((index * 37) % 100) / 100, 0, ((index * 53) % 100) / 100, 0),
			Rotation = (index * 27) % 360,
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 421,
		})
		table.insert(bits, _arg0)
	end
	return React.createElement(React.Fragment, nil, bits)
end
local function HudPrankStage(_param)
	local prank = _param.prank
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local _result = prank
	if _result ~= nil then
		_result = _result.kind
	end
	local _condition = _result
	if _condition == nil then
		_condition = ""
	end
	local kind = if workspace:GetAttribute("AstralForgeVRCanvasWidth") then "" else _condition
	local spinning = kind == "SpinHud"
	local shaking = kind == "ShakeHud"
	local invert = kind == "InvertHud"
	local tiny = kind == "TinyHud"
	local giant = kind == "GiantHud"
	local rotation = useRotation(spinning and not reducedMotion, 80)
	local shake = useClock(shaking and not reducedMotion, 16, math.pi * 2, true)
	local frameRotation = if spinning then (if reducedMotion then 24 else rotation) elseif invert then 180 else 0
	local size = if tiny then UDim2.fromScale(0.4, 0.4) elseif giant then UDim2.fromScale(1.82, 1.82) else UDim2.fromScale(1, 1)
	local restPosition = if tiny or giant then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0, 0)
	local position = if shaking and not reducedMotion then shake:map(function(phase)
		return UDim2.new(0, math.sin(phase * 3.2) * 16, 0, math.cos(phase * 2.5) * 12)
	end) else restPosition
	local anchor = if tiny or giant then Vector2.new(0.5, 0.5) else Vector2.new(0, 0)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = tiny or giant or shaking,
	}, React.createElement("frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		Rotation = frameRotation,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children))
end
local function AdminPrankOverlay(_param)
	local prank = _param.prank
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local onClose = _param.onClose
	local kind = prank.kind
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local overlayHostRef = React.useRef(nil)
	local _exp = chrome.bottomSafe
	local _condition = viewport.bottomInset
	if _condition == nil then
		_condition = 0
	end
	local toastInset = math.max(_exp, _condition, 8)
	local now, setNow = React.useState(os.clock())
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
	end, { prank.kind })
	React.useEffect(function()
		local worker = task.spawn(function()
			while os.clock() < prank.endsAt do
				task.wait(0.2)
				setNow(os.clock())
			end
			onClose()
		end)
		return function()
			return task.cancel(worker)
		end
	end, { onClose, prank.endsAt, prank.kind })
	local left = math.max(0, prank.endsAt - now)
	local washOn = kind == "DiscoHud" or kind == "RainbowHud"
	local wash = useClock(washOn and not softMotion, 0.42, 1, true)
	local washColor = wash:map(function(alpha)
		return Color3.fromHSV(alpha, if kind == "RainbowHud" then 0.55 else 0.88, 1)
	end)
	local loadSpin = useRotation(kind == "LoadingForever" and not softMotion, 240)
	local caption = if prank.caption ~= nil and prank.caption ~= "" then prank.caption else "CLOWN"
	local stageOnly = HUD_STAGE_KINDS[kind] ~= nil
	local blind = kind == "Blind"
	local fakeBan = kind == "FakeBan"
	local fakeCrash = kind == "FakeCrash"
	local jump = kind == "Jumpscare"
	local confetti = kind == "ConfettiStorm"
	local disco = kind == "DiscoHud"
	local rainbow = kind == "RainbowHud"
	local fakeRebirth = kind == "FakeRebirth"
	local fakeTrade = kind == "FakeTrade"
	local fakeRob = kind == "FakeRob"
	local loading = kind == "LoadingForever"
	local blue = kind == "BlueScreen"
	local battery = kind == "LowBattery"
	local update = kind == "UpdateForced"
	local clown = kind == "ClownTitle"
	local muteToasts = kind == "MuteToasts"
	local emptyBag = kind == "EmptyBagScare"
	local fill = if blind then Palette.void elseif fakeBan or fakeCrash then Palette.ink elseif jump then Palette.coral elseif blue then Color3.fromRGB(0, 94, 184) elseif battery then Palette.void elseif loading then Palette.void elseif confetti then Palette.void elseif clown then Palette.ink else Palette.void
	local fillAlpha = if blind then 0.04 elseif fakeBan or fakeCrash or fakeRebirth or fakeTrade or fakeRob or update or jump then 0.14 elseif blue then 0 elseif battery then 0.28 elseif loading then 0.18 elseif confetti then 0.78 elseif disco or rainbow then 0.48 elseif clown then 0.22 elseif muteToasts then 1 elseif emptyBag then 0.22 elseif stageOnly then 0.86 else 0.7
	local banner = if stageOnly then (if kind == "InvertHud" then "HUD INVERTED" elseif kind == "SpinHud" then "HUD SPINNING" elseif kind == "TinyHud" then "TINY HUD" elseif kind == "GiantHud" then "GIANT HUD" else "HUD SHAKING") else nil
	return React.createElement("frame", {
		ref = overlayHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if washOn then washColor else fill,
		BackgroundTransparency = fillAlpha,
		BorderSizePixel = 0,
		ZIndex = 420,
	}, banner ~= nil and React.createElement(Text, {
		value = `{banner}  {string.format("%.1f", left)}s`,
		size = 16,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 24),
		position = UDim2.new(0, 12, 0.06, 0),
	}), fakeBan and React.createElement(PrankCard, {
		title = "You were removed",
		body = "This session was closed by an administrator. You can rejoin from the experience page.",
		action = "OK",
		accent = Palette.coral,
		height = 248,
		reducedMotion = softMotion,
		onClose = onClose,
	}), fakeCrash and React.createElement(PrankCard, {
		title = "Couldn't reach the forge",
		body = "The server stopped answering. Check your connection, then try again.",
		action = "RETRY",
		accent = Palette.mango,
		height = 248,
		reducedMotion = softMotion,
		onClose = onClose,
	}), jump and React.createElement(PrankCard, {
		title = "BEHIND YOU",
		body = "Got you. Admin's bored.",
		action = "OK FINE",
		accent = Palette.coral,
		height = 240,
		reducedMotion = softMotion,
		onClose = onClose,
	}), fakeRebirth and React.createElement(PrankCard, {
		title = "REBIRTH NOW?",
		body = "Fake prompt. You keep everything.",
		action = "NOT TODAY",
		accent = Palette.violet,
		height = 268,
		reducedMotion = softMotion,
		onClose = onClose,
	}), fakeTrade and React.createElement(PrankCard, {
		title = "INCOMING TRADE",
		body = "xXVoidLordXx wants your whole bag for 3 flux. This trade isn't real.",
		action = "DECLINE JOKE",
		accent = Palette.cyan,
		height = 268,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}), fakeRob and React.createElement(PrankCard, {
		title = "WALLET COMPROMISED",
		body = "Flux 0, vault 0, cores 0. Fake card. Your wallet is fine.",
		action = "RECOVER",
		accent = Palette.coral,
		height = 268,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}), update and React.createElement(PrankCard, {
		title = "UPDATE REQUIRED",
		body = "There is no 9.9.9. This screen goes away on its own.",
		action = "REMIND ME NEVER",
		accent = Palette.mango,
		height = 268,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}), confetti and React.createElement(React.Fragment, nil, React.createElement(ConfettiBits), React.createElement(Text, {
		value = "CONFETTI TAX",
		size = 32,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 40),
		position = UDim2.new(0, 12, 0.42, 0),
	})), (disco or rainbow) and React.createElement(Text, {
		value = if disco then "DISCO FORGE" else "RAINBOW WASH",
		size = 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 36),
		position = UDim2.new(0, 12, 0.44, 0),
	}), blind and React.createElement(Text, {
		value = `LIGHTS OUT  {string.format("%.1f", left)}s`,
		size = 16,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 24),
		position = UDim2.new(0, 12, 0.9, 0),
	}), loading and React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0.5, 0, 0.38, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = loadSpin,
		ZIndex = 422,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 4,
	})), React.createElement(Text, {
		value = "SYNCING PROFILE",
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 30),
		position = UDim2.new(0, 12, 0.5, 0),
	}), React.createElement(Text, {
		value = `Fake load. {string.format("%.1f", left)}s left.`,
		size = 13,
		color = Palette.muted,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 20),
		position = UDim2.new(0, 12, 0.56, 0),
	}), React.createElement(Button, {
		text = "SKIP JOKE",
		onClick = onClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(0.42, 0, 0, 44),
		position = UDim2.new(0.29, 0, 0.66, 0),
		reducedMotion = softMotion,
	})), blue and React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = ":(",
		size = 72,
		color = Palette.white,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Left,
		sizeConstraint = UDim2.new(1, -64, 0, 80),
		position = UDim2.fromOffset(40, 70),
	}), React.createElement(Text, {
		value = "Your forge ran into a problem and needs to restart.",
		size = 18,
		color = Palette.white,
		wrap = true,
		align = Enum.TextXAlignment.Left,
		sizeConstraint = UDim2.new(1, -80, 0, 56),
		position = UDim2.fromOffset(40, 170),
	}), React.createElement(Text, {
		value = `Stop code: ADMIN_PRANK_{string.format("%.0f", left)}`,
		size = 14,
		color = Color3.fromRGB(190, 220, 255),
		align = Enum.TextXAlignment.Left,
		sizeConstraint = UDim2.new(1, -80, 0, 22),
		position = UDim2.fromOffset(40, 240),
	}), React.createElement(Button, {
		text = "THIS IS FAKE",
		onClick = onClose,
		color = Palette.white,
		textColor = Color3.fromRGB(0, 94, 184),
		size = UDim2.new(0.36, 0, 0, 44),
		position = UDim2.new(0, 40, 0, 290),
		reducedMotion = reducedMotion,
		highlight = true,
	})), battery and React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.new(0.72, 0, 0, 18),
		Position = UDim2.new(0.14, 0, 0.08, 0),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 422,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement("frame", {
		Size = UDim2.new(0.08, 0, 1, 0),
		BackgroundColor3 = Palette.coral,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}))), React.createElement(Text, {
		value = "LOW BATTERY",
		size = 28,
		color = Palette.coral,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 36),
		position = UDim2.new(0, 12, 0.42, 0),
	}), React.createElement(Text, {
		value = "Your battery is fine. This bar is fake.",
		size = 14,
		color = Palette.creamSoft,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -40, 0, 40),
		position = UDim2.new(0, 20, 0.5, 0),
	})), clown and React.createElement(Text, {
		value = string.upper(caption),
		size = 36,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -32, 0, 120),
		position = UDim2.new(0, 16, 0.38, 0),
	}), muteToasts and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(280, viewport.width - chrome.sideSafe * 2 - 24), 72),
		Position = UDim2.new(1, -math.max(16, chrome.sideSafe), 1, -math.max(16, toastInset)),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 430,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.coral,
		background = Palette.panel,
		padding = 12,
		zIndex = 430,
		clips = false,
	}, React.createElement(Text, {
		value = "Could not save",
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Text, {
		value = "The vault is fine. This toast is a joke.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
		position = UDim2.fromOffset(0, 22),
	}))), emptyBag and React.createElement(PrankCard, {
		title = "Inventory",
		body = "0 / 100 bag. No relics. This empty bag is a prank. Your relics are safe.",
		action = "CLOSE",
		accent = Palette.violet,
		height = 248,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}))
end
return {
	HudPrankStage = HudPrankStage,
	AdminPrankOverlay = AdminPrankOverlay,
}
end

__defs["notifications"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local _react_lifetime_component = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-lifetime-component"].out)
local LifetimeComponentImpl = _react_lifetime_component.LifetimeComponent
local useComponentIsActive = _react_lifetime_component.useComponentIsActive
local useComponentLifetime = _react_lifetime_component.useComponentLifetime
local LifetimeHost = LifetimeComponentImpl
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local usesDesktopStructure = require(script.Parent.CoreKit)("interaction").usesDesktopStructure
local planMobileLayout = require(script.Parent.CoreKit)("mobileLayout").planMobileLayout
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlipperSpring = _motion.useFlipperSpring
local useIntent = _motion.useIntent
local useIntentSpring = _motion.useIntentSpring
local MotionTokens = require(script.Parent.MotionKit)("motionTokens")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local ensureContrast = _theme.ensureContrast
local Breakpoints = _theme.Breakpoints
local Layout = _theme.Layout
local _ui = __load("ui")
local Stroke = _ui.Stroke
local Text = _ui.Text
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition
local NOTICE_LIFETIME = 4.2
local NOTICE_EXIT_SECONDS = 0.24
local SWIPE_DISMISS_PX = 56
local SWIPE_RETURN_FEEL = { frequency = 3.3, dampingRatio = 0.86 }
local function toneColor(tone)
	if tone == "Success" then
		return Palette.mint
	end
	if tone == "Warning" then
		return Palette.mango
	end
	if tone == "Error" then
		return Palette.coral
	end
	if tone == "Special" then
		return Palette.violet
	end
	return Palette.cyan
end
local function toneCue(tone)
	if tone == "Success" then
		return "noticeSuccess"
	end
	if tone == "Warning" then
		return "noticeWarning"
	end
	if tone == "Error" then
		return "noticeError"
	end
	if tone == "Special" then
		return "noticeSpecial"
	end
	return "noticeInfo"
end
local function toneIcon(tone)
	if tone == "Success" then
		return "Check"
	end
	if tone == "Warning" then
		return "Timer"
	end
	if tone == "Error" then
		return "Close"
	end
	if tone == "Special" then
		return "Gift"
	end
	return "Wave"
end
local CARD_HEIGHT = 74
local CARD_HEIGHT_MOBILE = 68
local CARD_GAP = 8
local CARD_GAP_MOBILE = 8
local RAIL_WIDTH = 360
local RAIL_WIDTH_MOBILE = 340
local MAX_VISIBLE = 3
local MAX_VISIBLE_MOBILE = 2
local function densityVisibleCap(density, stack)
	local clamped = math.clamp(if type(density) == "number" then density else 0.55, 0, 1)
	if stack then
		return math.clamp(math.floor(1 + clamped * 2 + 0.35), 1, 3)
	end
	return math.clamp(math.floor(2 + clamped * 3 + 0.5), 2, 5)
end
local function NoticeCard(props)
	local slotRef = React.useRef(nil)
	local slotSizePixels = useGuiSize(slotRef)
	local isActive = useComponentIsActive(props)
	useComponentLifetime(props, NOTICE_EXIT_SECONDS)
	local notice = props.notice
	local hovered, setHovered = React.useState(false)
	local entered, setEntered = React.useState(false)
	local leaving = not isActive or notice.leaving == true
	local leavingRef = React.useRef(leaving)
	leavingRef.current = leaving
	local visible = not leaving and entered
	local color = toneColor(notice.tone)
	local cardH = if props.compact then CARD_HEIGHT_MOBILE else CARD_HEIGHT
	local cardGap = if props.compact then CARD_GAP_MOBILE else CARD_GAP
	local titleSize = if props.compact then 14 else 15
	local bodySize = if props.compact then 12 else 13
	local dismiss = if props.touch then 34 else 28
	local iconSize = if props.compact then 34 else 38
	local hasBody = #notice.body > 0 and notice.body ~= notice.title
	local swipeX, setSwipeX = React.useBinding(0)
	local drag = React.useRef({
		active = false,
		start = 0,
		x = 0,
		v = 0,
		mode = "idle",
	})
	local dragConn = React.useRef()
	local dragEndConn = React.useRef()
	React.useEffect(function()
		local alive = true
		local job = task.defer(function()
			if alive then
				setEntered(true)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, {})
	React.useEffect(function()
		return function()
			local _result = dragConn.current
			if _result ~= nil then
				_result:Disconnect()
			end
			local _result_1 = dragEndConn.current
			if _result_1 ~= nil then
				_result_1:Disconnect()
			end
		end
	end, {})
	React.useEffect(function()
		if leaving then
			setHovered(false)
			drag.current.active = false
			drag.current.mode = "idle"
			local _result = dragConn.current
			if _result ~= nil then
				_result:Disconnect()
			end
			local _result_1 = dragEndConn.current
			if _result_1 ~= nil then
				_result_1:Disconnect()
			end
		end
	end, { leaving })
	React.useEffect(function()
		local _result = props.setHovered
		if _result ~= nil then
			_result(notice.id, hovered)
		end
		return function()
			local _result_1 = props.setHovered
			if _result_1 ~= nil then
				_result_1 = _result_1(notice.id, false)
			end
			return _result_1
		end
	end, { hovered, notice.id, props.setHovered })
	local plan = useIntent({ role = "toast", tone = notice.tone, emphasis = if notice.tone == "Special" then 0.5 else 0, reduced = props.reducedMotion })
	React.useEffect(function()
		if not visible or notice.sound == false then
			return nil
		end
		Audio:play(plan.cue or toneCue(notice.tone))
	end, { notice.sound, notice.tone, visible })
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			local state = drag.current
			if state.mode ~= "return" or leavingRef.current then
				return nil
			end
			state.x, state.v = MotionTokens.step(state.x, state.v, 0, SWIPE_RETURN_FEEL, dt)
			if math.abs(state.x) < 0.4 and math.abs(state.v) < 6 then
				state.x = 0
				state.v = 0
				state.mode = "idle"
			end
			setSwipeX(state.x)
		end)
		return function()
			return connection:Disconnect()
		end
	end, { setSwipeX })
	local progress = useIntentSpring(if visible then 1 else 0, plan)
	local hover = useFlipperSpring(if hovered and visible then 1 else 0, props.reducedMotion, plan.hover.stiffness, plan.hover.damping)
	local life = useClock(visible, 1, 1000, true)
	local surface = Palette.panelRaised
	local titleColor = ensureContrast(surface, Palette.cream)
	local bodyColor = ensureContrast(surface, Palette.creamSoft)
	local mutedX = ensureContrast(surface, Palette.muted)
	local slotSize = progress:map(function(shown)
		local t = math.clamp(shown, 0, 1)
		local squish = t * t
		return UDim2.new(1, 0, 0, math.max(0, math.round(squish * cardH + (if t > 0.06 then cardGap else 0))))
	end)
	local cardSize = progress:map(function(shown)
		local t = math.clamp(shown, 0, 1)
		local squish = t * t
		local widen = math.round((1 - t) * 16)
		return UDim2.new(1, widen, 0, math.max(0, math.round(cardH * squish)))
	end)
	local enterX = progress:map(function(shown)
		return if leavingRef.current then 0 else (1 - math.clamp(shown, 0, 1)) * 22
	end)
	local swipeFade = swipeX:map(function(amount)
		return math.clamp(math.abs(amount) / SWIPE_DISMISS_PX, 0, 1) * 0.7
	end)
	local motionFade = progress:map(function(shown)
		return 1 - math.clamp(shown, 0, 1)
	end)
	local backgroundTransparency = React.joinBindings({ motionFade, swipeFade }):map(function(values)
		return math.clamp(1 - props.surfaceOpacity + values[1] * props.surfaceOpacity + values[2], 0, 1)
	end)
	local drain = life:map(function(seconds)
		local _exp = seconds
		local _condition = notice.lifetime
		if _condition == nil then
			_condition = NOTICE_LIFETIME
		end
		return math.clamp(1 - _exp / _condition, 0, 1)
	end)
	local fade = motionFade
	local shownEnough = progress:map(function(shown)
		return shown > 0.05
	end)
	local _condition = notice.count
	if _condition == nil then
		_condition = 1
	end
	local count = _condition
	local lift = hover:map(function(amount)
		return -amount
	end)
	local cardPosition = React.joinBindings({ enterX, swipeX, lift, slotSizePixels }):map(function(values)
		return pixelPosition(values[4], 0.5, values[1] + values[2], 0.5, values[3])
	end)
	local beginDrag = function(frame, input)
		if leavingRef.current then
			return nil
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return nil
		end
		local abs = frame.AbsolutePosition
		local size = frame.AbsoluteSize
		if input.Position.X >= abs.X + size.X - dismiss - 6 then
			return nil
		end
		local state = drag.current
		state.active = true
		state.mode = "drag"
		state.start = input.Position.X - state.x
		state.v = 0
		local _result = dragConn.current
		if _result ~= nil then
			_result:Disconnect()
		end
		dragConn.current = UserInputService.InputChanged:Connect(function(moved)
			if not state.active then
				return nil
			end
			if moved.UserInputType ~= Enum.UserInputType.MouseMovement and moved.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			state.x = moved.Position.X - state.start
			setSwipeX(state.x)
		end)
		local _result_1 = dragEndConn.current
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		dragEndConn.current = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType ~= Enum.UserInputType.MouseButton1 and ended.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			local _result_2 = dragConn.current
			if _result_2 ~= nil then
				_result_2:Disconnect()
			end
			local _result_3 = dragEndConn.current
			if _result_3 ~= nil then
				_result_3:Disconnect()
			end
			state.active = false
			if leavingRef.current then
				return nil
			end
			if math.abs(state.x) >= SWIPE_DISMISS_PX then
				Audio:play("noticeClose")
				state.mode = "idle"
				props.remove(notice.id)
			else
				state.mode = "return"
			end
		end)
	end
	return React.createElement("frame", {
		ref = slotRef,
		Size = slotSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = notice.id,
		ClipsDescendants = true,
		Visible = shownEnough,
	}, React.createElement("frame", {
		Size = cardSize,
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = surface,
		BackgroundTransparency = backgroundTransparency,
		BorderSizePixel = 0,
		Active = not leaving,
		ClipsDescendants = true,
		ZIndex = 101,
		Event = {
			InputBegan = function(frame, input)
				return beginDrag(frame, input)
			end,
			MouseEnter = function()
				if not leaving then
					setHovered(true)
					Audio:play("hover")
				end
			end,
			MouseLeave = function()
				return setHovered(false)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(surface:Lerp(color, 0.1), surface),
		Rotation = 0,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = color,
		Thickness = 1,
		Transparency = React.joinBindings({ fade, hover }):map(function(values)
			return 0.7 - values[2] * 0.3 + values[1] * 0.3
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = UDim2.new(0, 14, 0.5, -1),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = fade:map(function(amount)
			return 0.8 + amount * 0.2
		end),
		BorderSizePixel = 0,
		ZIndex = 103,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uistroke", {
		Color = color,
		Thickness = 1,
		Transparency = fade:map(function(amount)
			return 0.55 + amount * 0.45
		end),
	}), React.createElement(Icon, {
		kind = toneIcon(notice.tone),
		color = color,
		accent = color,
		size = math.floor(iconSize * 0.62),
		spin = false,
		reducedMotion = props.reducedMotion,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), React.createElement(Text, {
		value = notice.title,
		size = titleSize,
		color = titleColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(iconSize + 26, if hasBody then 11 else 0),
		sizeConstraint = UDim2.new(1, -(iconSize + 26 + dismiss + 14 + (if count > 1 then 34 else 0)), 0, if hasBody then 20 else cardH - 4),
		zIndex = 105,
	}), hasBody and React.createElement("textlabel", {
		Size = UDim2.new(1, -(iconSize + 26 + dismiss + 14), 0, cardH - 40),
		Position = UDim2.fromOffset(iconSize + 26, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Text = notice.body,
		TextColor3 = bodyColor,
		TextTransparency = fade:map(function(amount)
			return 0.1 + amount
		end),
		TextSize = bodySize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 105,
	}), count > 1 and React.createElement("frame", {
		Size = UDim2.fromOffset(30, 20),
		Position = UDim2.new(1, -(dismiss + 40), 0, 11),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 106,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Text, {
		value = `×{count}`,
		size = 11,
		color = Palette.ink,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 107,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -28, 0, 3),
		Position = UDim2.new(0, 14, 1, -6),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = fade:map(function(amount)
			return 0.6 + amount * 0.4
		end),
		BorderSizePixel = 0,
		ZIndex = 103,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = drain:map(function(amount)
			return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
		end),
		BackgroundColor3 = color,
		BackgroundTransparency = fade:map(function(amount)
			return 0.15 + amount
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("imagebutton", {
		Size = UDim2.fromOffset(dismiss, dismiss),
		Position = UDim2.new(1, -10, 0.5, -1),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = hover:map(function(amount)
			return 1 - amount * 0.6
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not leaving,
		Selectable = false,
		ZIndex = 109,
		Event = {
			Activated = function()
				props.remove(notice.id)
				Audio:play("noticeClose")
			end,
			MouseEnter = function()
				if not leaving then
					setHovered(true)
				end
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "×",
		TextColor3 = if hovered then color else mutedX,
		TextTransparency = fade,
		TextSize = if props.touch then 22 else 20,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 110,
	}))))
end
local function ToastRail(_param)
	local notices = _param.notices
	local remove = _param.remove
	local setHovered = _param.setHovered
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local mobileLayout = _param.mobileLayout
	local density = _param.density
	if density == nil then
		density = 0.55
	end
	local screen, setScreen = React.useState(function()
		local _result = Workspace.CurrentCamera
		if _result ~= nil then
			_result = _result.ViewportSize
		end
		local _condition = _result
		if _condition == nil then
			_condition = Vector2.new(1280, 720)
		end
		return _condition
	end)
	local topbarInset, setTopbarInset = React.useState(function()
		return GuiService.TopbarInset.Height
	end)
	React.useEffect(function()
		local viewportConnection
		local bindCamera = function()
			local _result = viewportConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			viewportConnection = nil
			local camera = Workspace.CurrentCamera
			if camera == nil then
				return nil
			end
			local sync = function()
				return setScreen(camera.ViewportSize)
			end
			sync()
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(sync)
		end
		bindCamera()
		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
		return function()
			cameraConnection:Disconnect()
			local _result = viewportConnection
			if _result ~= nil then
				_result:Disconnect()
			end
		end
	end, {})
	React.useEffect(function()
		local sync = function()
			return setTopbarInset(GuiService.TopbarInset.Height)
		end
		sync()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	local noticesRef = React.useRef(notices)
	noticesRef.current = notices
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or input.KeyCode ~= Enum.KeyCode.Escape then
				return nil
			end
			local live = noticesRef.current
			local newest = live[#live]
			if newest ~= nil then
				remove(newest.id)
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { remove })
	local width = math.floor(screen.X)
	local height = math.floor(screen.Y)
	local plan = planMobileLayout({
		width = width,
		height = height,
		compact = width < Breakpoints.compact,
		tight = width < Breakpoints.tight,
		short = height < Breakpoints.short,
		desktop = usesDesktopStructure(width, height),
	})
	local stack = plan.stack
	local layoutScale = if mobileLayout ~= nil then 0.88 + math.clamp(mobileLayout.scale, 0, 1) * 0.12 else 1
	local railW = (if stack then math.min(RAIL_WIDTH_MOBILE, math.max(200, width - plan.sideSafe * 2 - 20)) else RAIL_WIDTH) * layoutScale
	local cardH = if stack then CARD_HEIGHT_MOBILE else CARD_HEIGHT
	local cardGap = if stack then math.max(4, CARD_GAP_MOBILE - math.floor(density * 2)) else CARD_GAP
	local topInset = math.max(topbarInset, Layout.minTopInset) + (if stack then plan.topbarRows + 10 else Layout.topbarClearance + 12)
	local keyboardOpen = UserInputService.TouchEnabled and UserInputService.OnScreenKeyboardVisible
	local densityCap = densityVisibleCap(density, stack)
	local requestedVisible = if keyboardOpen then 1 else densityCap
	local bottomReserve = plan.bottomSafe + plan.tabBarH + (if stack then 18 else 12)
	local fittingVisible = math.max(1, math.floor((height - topInset - bottomReserve - 8) / math.max(1, cardH + cardGap)))
	local maxVisible = math.max(1, math.min(requestedVisible, fittingVisible, if stack then MAX_VISIBLE_MOBILE + 1 else 2))
	local railHeight = maxVisible * (cardH + cardGap)
	local minX = (plan.sideSafe + 8 + railW / 2) / width
	local maxX = math.max(minX, 1 - minX)
	local minY = topInset / height
	local maxY = math.max(minY, (height - bottomReserve - railHeight - 8) / height)
	local customX = if mobileLayout ~= nil then math.clamp(mobileLayout.x, minX, maxX) else 0.5
	local customY = if mobileLayout ~= nil then math.clamp(mobileLayout.y, minY, maxY) else minY
	local _newValue = {}
	local _callback = function(notice)
		return notice.leaving ~= true
	end
	local _length = 0
	for _k, _v in notices do
		if _callback(_v, _k - 1, notices) == true then
			_length += 1
			_newValue[_length] = _v
		end
	end
	local live = _newValue
	local _result
	if #live > maxVisible then
		local _newValue_1 = {}
		local _callback_1 = function(_, i)
			return i >= #live - maxVisible
		end
		local _length_1 = 0
		for _k, _v in live do
			if _callback_1(_v, _k - 1, live) == true then
				_length_1 += 1
				_newValue_1[_length_1] = _v
			end
		end
		_result = _newValue_1
	else
		_result = live
	end
	local visible = _result
	local _exp = function()
		local entries = {}
		local _callback_1 = function(notice)
			local _exp_1 = tostring(notice.id)
			local _attributes = {
				notice = notice,
				remove = remove,
				setHovered = setHovered,
				reducedMotion = reducedMotion,
				compact = stack,
				touch = plan.mobile,
			}
			local _result_1 = mobileLayout
			if _result_1 ~= nil then
				_result_1 = _result_1.opacity
			end
			local _condition = _result_1
			if _condition == nil then
				_condition = 1
			end
			_attributes.surfaceOpacity = _condition
			local _arg1 = React.createElement(NoticeCard, _attributes)
			entries[_exp_1] = _arg1
		end
		for _k, _v in visible do
			_callback_1(_v, _k - 1, visible)
		end
		return entries
	end
	local _result_1 = mobileLayout
	if _result_1 ~= nil then
		_result_1 = _result_1.opacity
	end
	local rendered = React.useMemo(_exp, { _result_1, plan.mobile, reducedMotion, remove, setHovered, stack, visible })
	local hiddenCount = math.max(0, #live - maxVisible)
	local useCustom = mobileLayout ~= nil
	-- Desktop toasts sit at the top of the content area, centred in the page header's empty middle
	-- (between the page title and the vault card), and stack downward. The old bottom-left spot
	-- sat on top of whatever the page showed there.
	local desktopTop = math.max(topbarInset, Layout.minTopInset) + Layout.topbarHeight + 12
	local defaultPosition = if stack
		then UDim2.new(0.5, 0, 0, topInset)
		else UDim2.new(0.5, math.floor(Layout.sidebarWidth / 2), 0, desktopTop)
	local defaultAnchor = Vector2.new(0.5, 0)
	return React.createElement("frame", {
		Size = UDim2.new(0, railW, 0, railHeight),
		Position = if useCustom then UDim2.fromScale(customX, customY) else defaultPosition,
		AnchorPoint = if useCustom then Vector2.new(0.5, 0) else defaultAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 250,
		ClipsDescendants = false,
	}, hiddenCount > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(160, railW), if stack then 22 else 24),
		Position = UDim2.new(0.5, 0, 0, -(if stack then 28 else 30)),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 249,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Stroke, {
		color = Palette.lineSoft,
		thickness = 1,
		transparency = 0.62,
	}), React.createElement(Text, {
		value = `+{hiddenCount} more`,
		size = 11,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
	})), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = if stack or mobileLayout == nil then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(LifetimeHost, {
		CanRecover = true,
	}, rendered))
end
return {
	ToastRail = ToastRail,
	NOTICE_LIFETIME = NOTICE_LIFETIME,
	NOTICE_EXIT_SECONDS = NOTICE_EXIT_SECONDS,
}
end

__defs["levelMoments"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local Text = __load("ui").Text

local CARD_SECONDS = 6.5

local listeners = {}
local pendingNames = {}
local function pushLevelMoment(effect)
	if type(effect) ~= "table" then
		return
	end
	if effect.Type == "LevelUp" then
		pendingNames = if type(effect.Names) == "table" then effect.Names else {}
		return
	end
	if effect.Type ~= "LevelReward" then
		return
	end
	local moment = table.clone(effect)
	moment.Names = pendingNames
	moment.At = os.clock()
	pendingNames = {}
	for listener in listeners do
		listener(moment)
	end
end

local function clockText(seconds)
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

local function RewardRow(_param)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = _param.order,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 452,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = darken(_param.color, 0.55),
		BorderSizePixel = 0,
		ZIndex = 453,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement(Icon, {
		kind = _param.icon,
		color = Palette.cream,
		accent = _param.color,
		size = 26,
	})), React.createElement(Text, {
		value = _param.text,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(40, 0),
		sizeConstraint = UDim2.new(1, -48, 1, 0),
		zIndex = 453,
	}))
end

local function LevelCard(_param)
	local moment = _param.moment
	local onClose = _param.onClose
	local viewport = useViewport()
	local show = useFlipperSpring(if _param.leaving then 0 else 1, false, 520, 30, 0)
	local spin = useClock(true, 0.35, math.pi * 2)
	local rows = {}
	rows.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local count = 0
	local function add(key, icon, color, text)
		count += 1
		rows[key] = React.createElement(RewardRow, { order = count, icon = icon, color = color, text = text })
	end
	if (moment.Flux or 0) > 0 then
		add("flux", "Flux", Palette.mango, `+{compactNumber(moment.Flux)} flux`)
	end
	if (moment.Stardust or 0) > 0 then
		add("dust", "Dust", Palette.cyan, `+{compactNumber(moment.Stardust)} stardust`)
	end
	if (moment.SurgeMultiplier or 1) > 1 then
		local seconds = math.max(0, (moment.SurgeEndsAt or 0) - Workspace:GetServerTimeNow())
		add("surge", "Boost", Palette.pink, string.format("Forge Surge ×%.2f for %s", moment.SurgeMultiplier, clockText(seconds)))
	end
	add("mastery", "Forge", Palette.mint, string.format("+%d%% production, for good", math.floor(((moment.Level or 1) - 1) * 2 + 0.5)))
	if type(moment.Names) == "table" and #moment.Names > 0 then
		add("opens", "Lock", Palette.violet, "Opened: " .. table.concat(moment.Names, ", "))
	end
	local width = math.min(380, viewport.width - 28)
	local height = 128 + count * 40
	local levels = moment.Levels or {}
	local title = if #levels > 1 then `Levels {levels[1]}–{levels[#levels]}` else `Level {moment.Level}`
	return React.createElement("textbutton", {
		Size = UDim2.fromOffset(width, height),
		Position = show:map(function(amount)
			return UDim2.new(0.5, 0, 0.42, math.round((1 - amount) * 30))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = show:map(function(amount)
			return 1 - math.clamp(amount, 0, 1)
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 450,
		Event = {
			Activated = onClose,
		},
	}, React.createElement("uiscale", {
		Scale = show:map(function(amount)
			return 0.85 + amount * 0.15
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	}), React.createElement("uistroke", {
		Color = Palette.brass,
		Thickness = 2,
		Transparency = show:map(function(amount)
			return 1 - amount * 0.8
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(220, 220),
		Position = UDim2.new(0.5, 0, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = spin:map(function(angle)
			return math.deg(angle)
		end),
		BackgroundTransparency = 1,
		ZIndex = 450,
	}, (function()
		local rays = {}
		for index = 1, 8 do
			rays["ray" .. index] = React.createElement("frame", {
				Size = UDim2.fromOffset(10, 110),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 1),
				Rotation = index * 45,
				BackgroundColor3 = Palette.mango,
				BackgroundTransparency = show:map(function(amount)
					return 1 - amount * 0.12
				end),
				BorderSizePixel = 0,
				ZIndex = 450,
			}, React.createElement("uigradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(1, 0.4),
			}))
		end
		return React.createElement(React.Fragment, nil, rays)
	end)()), React.createElement(Text, {
		value = "LEVEL UP",
		size = 12,
		color = Palette.brass,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 452,
	}), React.createElement(Text, {
		value = title,
		size = 30,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 18,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
		zIndex = 452,
	}), React.createElement(Text, {
		value = string.upper(moment.Tier or ""),
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 72),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 452,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -28, 0, count * 40),
		Position = UDim2.fromOffset(14, 98),
		BackgroundTransparency = 1,
		ZIndex = 451,
	}, rows), React.createElement(Text, {
		value = "Tap to continue",
		size = 11,
		color = Palette.muted,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 1, -24),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		zIndex = 452,
	}))
end

local function SurgeChip(_param)
	local surge = _param.surge
	local now = useWallClock(true)
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local top = viewport.topInset + 64
	local pulse = useClock(true, 2.4, math.pi * 2)
	local stack = chrome.stack
	local edge = math.max(chrome.sideSafe, 10)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if stack then math.max(120, viewport.width - math.min(220, math.floor(viewport.width * 0.6)) - edge * 3) else 168, 30),
		Position = if stack then UDim2.new(0, edge, 1, -(chrome.tabBarH + 8 + 54)) else UDim2.new(1, -14, 0, top),
		AnchorPoint = if stack then Vector2.new(0, 1) else Vector2.new(1, 0),
		BackgroundColor3 = darken(Palette.pink, 0.62),
		BorderSizePixel = 0,
		Visible = now:map(function(value)
			return surge.EndsAt > value
		end),
		ZIndex = 240,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.pink,
		Thickness = 1.5,
		Transparency = pulse:map(function(angle)
			return 0.25 + (math.sin(angle) + 1) * 0.2
		end),
	}), React.createElement(Icon, {
		kind = "Boost",
		color = Palette.cream,
		accent = Palette.pink,
		size = 20,
		position = UDim2.new(0, 8, 0.5, -10),
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -38, 1, 0),
		Position = UDim2.fromOffset(32, 0),
		BackgroundTransparency = 1,
		Text = now:map(function(value)
			return string.format("SURGE ×%.2f  %s", surge.Multiplier, clockText(surge.EndsAt - value))
		end),
		TextColor3 = Palette.cream,
		TextSize = 13,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 241,
	}))
end

local function LevelMomentHost(_param)
	local state = _param.state
	local queue, setQueue = React.useState({})
	local leaving, setLeaving = React.useState(false)
	React.useEffect(function()
		local listener = function(moment)
			Audio:play("achievementClaim")
			setQueue(function(current)
				local nextQueue = table.clone(current)
				table.insert(nextQueue, moment)
				return nextQueue
			end)
		end
		listeners[listener] = true
		return function()
			listeners[listener] = nil
		end
	end, {})
	local current = queue[1]
	local close = React.useCallback(function()
		setLeaving(true)
		task.delay(0.25, function()
			setLeaving(false)
			setQueue(function(list)
				local nextQueue = table.clone(list)
				table.remove(nextQueue, 1)
				return nextQueue
			end)
		end)
	end, {})
	React.useEffect(function()
		if current == nil then
			return nil
		end
		local job = task.delay(CARD_SECONDS, close)
		return function()
			pcall(task.cancel, job)
		end
	end, { current })
	local level = state and state.Level
	local progression = level and level.Progression
	local surge = progression and progression.Surge
	return React.createElement(React.Fragment, nil, surge ~= nil and (surge.EndsAt or 0) > 0 and React.createElement(SurgeChip, {
		surge = surge,
	}), current ~= nil and React.createElement(LevelCard, {
		key = tostring(current.At),
		moment = current,
		leaving = leaving,
		onClose = close,
	}))
end

return {
	pushLevelMoment = pushLevelMoment,
	LevelMomentHost = LevelMomentHost,
}
end

__defs["serverEventsUi"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local h = React.createElement
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local _ui = __load("ui")
local Button = _ui.Button
local Text = _ui.Text
local ServerEvents = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("ServerEvents")

local latest = nil
local listeners = {}
local function pushServerEvent(effect)
	if type(effect) ~= "table" or type(effect.Event) ~= "table" then
		return
	end
	latest = effect.Event
	for listener in listeners do
		listener(latest)
	end
end
local function useServerEvent(fromSnapshot)
	local live, setLive = React.useState(latest)
	React.useEffect(function()
		local listener = function(event)
			setLive(event)
		end
		listeners[listener] = true
		return function()
			listeners[listener] = nil
		end
	end, {})
	if live ~= nil and (fromSnapshot == nil or (live.PhaseEndsAt or 0) >= (fromSnapshot.PhaseEndsAt or 0)) then
		return live
	end
	return fromSnapshot
end

local panelOpeners = {}
local function openServerEventPanel()
	for opener in panelOpeners do
		opener()
	end
end

local function clockText(seconds)
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end
local function accentOf(def)
	return Palette[def and def.Accent or "cyan"] or Palette.cyan
end
local function phaseLine(event, now)
	local left = (event.PhaseEndsAt or now) - now
	if event.Phase == "Warning" then
		return `Starts in {clockText(left)}`
	elseif event.Phase == "Live" then
		return `{clockText(left)} left`
	elseif event.Phase == "Results" then
		return if event.Completed then "Goal reached!" elseif event.Goal ~= nil then "Time's up" else "Finished"
	end
	return `Next event in {clockText(left)}`
end

local function ProgressBar(_param)
	local fill = math.clamp(_param.value, 0, 1)
	return React.createElement("frame", {
		Size = _param.size,
		Position = _param.position,
		BackgroundColor3 = Palette.graphite,
		BorderSizePixel = 0,
		ZIndex = _param.zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromScale(math.max(fill, 0.02), 1),
		BackgroundColor3 = _param.color,
		BorderSizePixel = 0,
		ZIndex = _param.zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end

local function EventPanel(_param)
	local event = _param.event
	local def = ServerEvents.EVENTS[event.Id or ""]
	local now = useWallClock(true)
	local viewport = useViewport()
	local show = useFlipperSpring(1, false, 560, 34, 0)
	local accent = accentOf(def)
	local width = math.min(440, viewport.width - 24)
	local rows = {}
	rows.layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local order = 0
	local function line(key, text, color, size, height)
		order += 1
		rows[key] = React.createElement(Text, {
			value = text,
			size = size or 13,
			color = color or Palette.creamSoft,
			wrap = true,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, height or 34),
			layoutOrder = order,
			zIndex = 562,
		})
	end
	local height = 150
	if def == nil then
		line("rest", "No event right now. Events run every few minutes: when one is coming, a banner appears at the top of the screen.", Palette.creamSoft, 13, 52)
		height += 60
	else
		line("how", def.How, Palette.creamSoft, 13, 40)
		height += 48
		if def.Id == "MeteorShower" then
			line("effect", string.format("Effect: everyone's output ×%.1f while it lasts.", def.Multiplier), Palette.mango, 13, 20)
			height += 28
		elseif def.Id == "StardustRain" then
			line("effect", string.format("Effect: every vault collect drops up to %d stardust.", def.MaxDustPerCollect), Palette.violet, 13, 20)
			height += 28
		elseif def.Id == "CommunityForge" then
			line("reward", string.format("Reward for everyone who helps: %d seconds of your output in flux and %d stardust. Top 3 get +%d / +%d / +%d stardust.", def.RewardFluxSeconds, def.RewardStardust, def.TopBonusStardust[1], def.TopBonusStardust[2], def.TopBonusStardust[3]), Palette.cyan, 12, 34)
			height += 42
			if event.Goal ~= nil then
				order += 1
				rows.goal = React.createElement("frame", {
					Size = UDim2.new(1, 0, 0, 36),
					LayoutOrder = order,
					BackgroundTransparency = 1,
					ZIndex = 562,
				}, React.createElement(Text, {
					value = `{compactNumber(event.Progress or 0)} / {compactNumber(event.Goal)} points  ·  yours {compactNumber(event.Yours or 0)}`,
					size = 12,
					color = Palette.cream,
					weight = Enum.FontWeight.Bold,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
					zIndex = 563,
				}), React.createElement(ProgressBar, {
					value = (event.Progress or 0) / math.max(1, event.Goal),
					color = accent,
					size = UDim2.new(1, 0, 0, 10),
					position = UDim2.fromOffset(0, 22),
					zIndex = 563,
				}))
				height += 44
				for index, entry in event.Top or {} do
					line("top" .. index, `#{index}  {entry.Name}  ·  {compactNumber(entry.Points)} pts`, if index <= 3 then Palette.mango else Palette.muted, 12, 16)
					height += 24
				end
			end
		end
	end
	return React.createElement("textbutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = show:map(function(amount)
			return 1 - amount * 0.5
		end),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 558,
		Event = {
			Activated = _param.onClose,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(width, math.min(height, viewport.height - 40)),
		Position = show:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * 24))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 560,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.3,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = darken(accent, 0.55),
		BorderSizePixel = 0,
		ZIndex = 561,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement(Icon, {
		kind = def and def.Icon or "Calendar",
		color = Palette.cream,
		accent = accent,
		size = 52,
	})), React.createElement(Text, {
		value = if def then def.Name else "Server events",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(80, 18),
		sizeConstraint = UDim2.new(1, -140, 0, 26),
		zIndex = 561,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -140, 0, 18),
		Position = UDim2.fromOffset(80, 46),
		BackgroundTransparency = 1,
		Text = now:map(function(value)
			return phaseLine(event, value)
		end),
		TextColor3 = accent,
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 561,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -52, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 562,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = _param.onClose,
		color = Palette.panel,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		zIndex = 563,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -32, 1, -96),
		Position = UDim2.fromOffset(16, 84),
		BackgroundTransparency = 1,
		ZIndex = 561,
	}, rows)))
end

local function LiveSplash(_param)
	local def = _param.def
	local show = useFlipperSpring(if _param.leaving then 0 else 1, false, 420, 26, 0)
	local accent = accentOf(def)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(accent, 0.7),
		BackgroundTransparency = show:map(function(amount)
			return 1 - amount * 0.25
		end),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 540,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}), React.createElement("uiscale", {
		Scale = show:map(function(amount)
			return 0.8 + amount * 0.2
		end),
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1,
		Text = "SERVER EVENT",
		TextColor3 = accent,
		TextTransparency = show:map(function(amount)
			return 1 - amount
		end),
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 541,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 38),
		BackgroundTransparency = 1,
		Text = string.upper(def.Name),
		TextColor3 = Palette.cream,
		TextTransparency = show:map(function(amount)
			return 1 - amount
		end),
		TextSize = 42,
		TextScaled = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 541,
	}, React.createElement("uitextsizeconstraint", {
		MaxTextSize = 42,
	})), React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 90),
		BackgroundTransparency = 1,
		Text = def.Blurb,
		TextColor3 = Palette.creamSoft,
		TextTransparency = show:map(function(amount)
			return 1 - amount
		end),
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		ZIndex = 541,
	}))
end

-- Screen-space weather for live events. Every particle is a pure function of one time
-- binding (no per-particle state), seeded so the pattern is stable between renders.
local SKY_STYLE = {
	MeteorShower = { kind = "streak", burst = 16, ambient = 4, angle = 34 },
	StardustRain = { kind = "dust", burst = 34, ambient = 12 },
	-- embers stay few after the opening burst so they never crowd the pages
	CommunityForge = { kind = "ember", burst = 22, ambient = 4 },
}
local SKY_BURST_SECONDS = 6

local function hash01(i, salt)
	local x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function SkyParticle(p)
	local i, style, clock = p.index, p.style, p.clock
	local w, hgt = p.width, p.height
	local period = if style.kind == "streak" then 1.6 + hash01(i, 1) * 1.8 elseif style.kind == "dust" then 5 + hash01(i, 1) * 4 else 4 + hash01(i, 1) * 3
	local phase0 = hash01(i, 2) * period
	local function progress(t)
		return ((t + phase0) % period) / period
	end
	local function alive(t)
		local active = if t - p.since < SKY_BURST_SECONDS then style.burst else style.ambient
		return i <= active
	end
	if style.kind == "streak" then
		local a = math.rad(style.angle)
		local dx, dy = -math.cos(a), math.sin(a)
		local len = 70 + hash01(i, 3) * 110
		local thick = if hash01(i, 4) > 0.75 then 3 else 2
		local sx = w * (0.25 + hash01(i, 5) * 1.05)
		local travel = (hgt + 160) / dy
		-- a meteor flies for the first 55% of its period, then rests off-screen
		local function head(t)
			local q = progress(t) / 0.55
			return sx + dx * travel * q, -80 + dy * travel * q, q
		end
		return h("frame", {
			Size = UDim2.fromOffset(len, thick),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 180 - style.angle,
			Position = clock:map(function(t)
				local x, y = head(t)
				return UDim2.fromOffset(x - dx * len / 2, y - dy * len / 2)
			end),
			Visible = clock:map(function(t)
				local _, _, q = head(t)
				return alive(t) and q <= 1
			end),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 120,
		},
			h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uigradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, p.accent),
					ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 236, 200)),
					ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.7, 0.45),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
			h("frame", {
				Size = UDim2.fromOffset(thick * 3, thick * 3),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 244, 220),
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				ZIndex = 121,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
		)
	end
	local size = if style.kind == "dust" then 2 + math.round(hash01(i, 3) * 3) else 3 + math.round(hash01(i, 3) * 3)
	local baseX = w * hash01(i, 5)
	local sway = 10 + hash01(i, 6) * 26
	local rising = style.kind == "ember"
	return h("frame", {
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = clock:map(function(t)
			local q = progress(t)
			local y = if rising then hgt + 20 - q * (hgt * 0.7) else -20 + q * (hgt + 40)
			return UDim2.fromOffset(baseX + math.sin(t * 0.9 + i) * sway, y)
		end),
		BackgroundTransparency = clock:map(function(t)
			local q = progress(t)
			local fade = if rising then q else math.max(0, (q - 0.8) / 0.2)
			local twinkle = if rising then 0 else (math.sin(t * 6 + i * 1.7) + 1) * 0.18
			return math.clamp((if rising then 0.35 else 0.1) + fade * 0.65 + twinkle, 0, 1)
		end),
		Visible = clock:map(alive),
		BackgroundColor3 = if rising then Color3.fromRGB(255, 168, 92) else p.accent,
		BorderSizePixel = 0,
		ZIndex = 120,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) })) -- soft round embers, never diamonds
end

local function EventSkyFx(_param)
	local style = SKY_STYLE[_param.eventId]
	local viewport = useViewport()
	local antilag = useAntilag()
	local clock, setClock = React.useBinding(os.clock())
	local since = React.useMemo(os.clock, { _param.eventId })
	React.useEffect(function()
		local conn = RunService.Heartbeat:Connect(function()
			setClock(os.clock())
		end)
		return function()
			conn:Disconnect()
		end
	end, {})
	if style == nil then
		return nil
	end
	local budget = if antilag.tier <= 1 then 0.45 elseif antilag.allowAmbient == false then 0.7 else 1
	local tuned = {
		kind = style.kind,
		angle = style.angle,
		burst = math.max(1, math.floor(style.burst * budget)),
		ambient = math.max(1, math.floor(style.ambient * budget)),
	}
	local particles = {}
	for i = 1, tuned.burst do
		particles[i] = h(SkyParticle, {
			key = i,
			index = i,
			style = tuned,
			clock = clock,
			since = since,
			width = viewport.width,
			height = viewport.height,
			accent = _param.accent,
		})
	end
	return h("frame", {
		Name = "EventSkyFx",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 120,
	}, table.unpack(particles))
end

local function ServerEventHost(_param)
	local state = _param.state
	local event = useServerEvent(state and state.ServerEvent)
	local now = useWallClock(true)
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local pulse = useClock(true, 3, math.pi * 2)
	local panelOpen, setPanelOpen = React.useState(false)
	local splash, setSplash = React.useState(nil)
	local splashLeaving, setSplashLeaving = React.useState(false)
	local lastPhase = React.useRef(nil)
	React.useEffect(function()
		local opener = function()
			Audio:play("open")
			setPanelOpen(true)
		end
		panelOpeners[opener] = true
		return function()
			panelOpeners[opener] = nil
		end
	end, {})
	React.useEffect(function()
		if event == nil then
			return nil
		end
		local key = tostring(event.Phase) .. ":" .. tostring(event.Id)
		if lastPhase.current ~= nil and lastPhase.current ~= key and event.Phase == "Live" then
			local def = ServerEvents.EVENTS[event.Id or ""]
			if def ~= nil then
				Audio:play("noticeSpecial")
				setSplashLeaving(false)
				setSplash(def)
				local leave = task.delay(2.4, function()
					setSplashLeaving(true)
				end)
				local gone = task.delay(2.8, function()
					setSplash(nil)
				end)
				lastPhase.current = key
				return function()
					pcall(task.cancel, leave)
					pcall(task.cancel, gone)
				end
			end
		end
		lastPhase.current = key
		return nil
	end, { event and event.Phase, event and event.Id })
	if event == nil then
		return nil
	end
	local def = ServerEvents.EVENTS[event.Id or ""]
	local active = def ~= nil and event.Phase ~= "Rest"
	local accent = accentOf(def)
	local stack = chrome.stack
	local edge = math.max(chrome.sideSafe, 10)
	local width = if stack then math.min(320, viewport.width - edge * 2)
		elseif active then math.min(320, viewport.width - 120)
		else 170
	local height = if active then (if event.Goal ~= nil then 58 else 50) else 28
	local top = viewport.topInset + 62
	local skyFx = def ~= nil and event.Phase == "Live" and React.createElement(EventSkyFx, {
		key = tostring(event.Id),
		eventId = event.Id,
		accent = accent,
	})
	if (stack and not active) or _param.inTopBar == true then
		return React.createElement(React.Fragment, nil, skyFx, splash ~= nil and React.createElement(LiveSplash, {
			def = splash,
			leaving = splashLeaving,
		}), panelOpen and React.createElement(EventPanel, {
			event = event,
			onClose = function()
				setPanelOpen(false)
			end,
		}))
	end
	local banner = React.createElement("textbutton", {
		Name = "ServerEventBanner",
		Size = UDim2.fromOffset(width, height),
		Position = if stack then UDim2.new(0, edge, 1, -(chrome.tabBarH + 8)) else UDim2.new(0.5, 0, 0, top),
		AnchorPoint = if stack then Vector2.new(0, 1) else Vector2.new(0.5, 0),
		BackgroundColor3 = if active then darken(accent, 0.62) else Palette.night,
		BackgroundTransparency = if active then 0.04 else 0.25,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 238,
		Event = {
			Activated = function()
				Audio:play("open")
				setPanelOpen(true)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, if active then 12 else 14),
	}), React.createElement("uistroke", {
		Color = if active then accent else Palette.line,
		Thickness = if active then 1.5 else 1,
		Transparency = if active and event.Phase == "Live" then pulse:map(function(angle)
			return 0.15 + (math.sin(angle) + 1) * 0.2
		end) else 0.4,
	}), active and React.createElement(Icon, {
		kind = def.Icon,
		color = Palette.cream,
		accent = accent,
		size = 24,
		position = UDim2.fromOffset(10, 8),
	}), React.createElement("textlabel", {
		Name = "ServerEventName",
		Size = UDim2.new(1, if active then -44 else -16, 0, if active then 22 else height),
		Position = UDim2.fromOffset(if active then 40 else 8, if active then 4 else 0),
		BackgroundTransparency = 1,
		Text = if active then def.Name else "",
		TextColor3 = Palette.cream,
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		Visible = active,
		ZIndex = 239,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, if active then -44 else -16, 0, if active then 16 else height),
		Position = UDim2.fromOffset(if active then 40 else 8, if active then 27 else 0),
		BackgroundTransparency = 1,
		Text = now:map(function(value)
			return phaseLine(event, value)
		end),
		TextColor3 = if active then accent else Palette.muted,
		TextSize = if active then 12 else 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = if active then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		ZIndex = 239,
	}), active and event.Goal ~= nil and React.createElement(ProgressBar, {
		value = (event.Progress or 0) / math.max(1, event.Goal),
		color = accent,
		size = UDim2.new(1, -52, 0, 5),
		position = UDim2.fromOffset(40, 46),
		zIndex = 239,
	}))
	return React.createElement(React.Fragment, nil, skyFx, banner, splash ~= nil and React.createElement(LiveSplash, {
		def = splash,
		leaving = splashLeaving,
	}), panelOpen and React.createElement(EventPanel, {
		event = event,
		onClose = function()
			Audio:play("close")
			setPanelOpen(false)
		end,
	}))
end

return {
	pushServerEvent = pushServerEvent,
	ServerEventHost = ServerEventHost,
	useServerEvent = useServerEvent,
	openServerEventPanel = openServerEventPanel,
	accentOf = accentOf,
	clockText = clockText,
	EVENTS = ServerEvents.EVENTS,
}
end

__defs["CreditsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local _ui = __load("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Panel = _ui.Panel
local SearchField = _ui.SearchField
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus

local SharedData = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
local CreditsModel = SharedData("CreditsModel")
local MODEL = CreditsModel.normalize(SharedData("CreditsConfig"))

local GRID_GAP = 10
local SECTION_GAP = 18
local SECTION_HEADER_H = 46
local EMPTY_ROW_H = 40
local TAB_H = 34
local MAX_STAGGER_INDEX = 14

local function tone(key, fallback)
	local color = Palette[key]
	if typeof(color) == "Color3" then
		return color
	end
	return fallback
end

local liveNames = {}
local liveNamesRequested = false
local function useLiveNames()
	local version, setVersion = React.useState(0)
	React.useEffect(function()
		if not MODEL.FetchNames or liveNamesRequested then
			return nil
		end
		liveNamesRequested = true
		local ids, seen = {}, {}
		for _, category in MODEL.Categories do
			for _, member in category.Members do
				if member.UserId ~= nil and not seen[member.UserId] then
					seen[member.UserId] = true
					table.insert(ids, member.UserId)
				end
			end
		end
		if #ids == 0 then
			return nil
		end
		local alive = true
		task.spawn(function()
			local ok, infos = pcall(function()
				return game:GetService("UserService"):GetUserInfosByUserIdsAsync(ids)
			end)
			if not ok or type(infos) ~= "table" then
				return
			end
			for _, info in infos do
				if type(info) == "table" and info.Id ~= nil then
					liveNames[info.Id] = { display = info.DisplayName, username = info.Username }
				end
			end
			if alive then
				setVersion(function(current)
					return current + 1
				end)
			end
		end)
		return function()
			alive = false
		end
	end, {})
	return version
end

local function Avatar(_param)
	local member = _param.member
	local size = _param.size
	local accent = _param.accent
	local radius = if MODEL.AvatarShape == "Circle" then UDim.new(1, 0) else UDim.new(0, math.floor(size * 0.22))
	if member.UserId ~= nil then
		return React.createElement("imagelabel", {
			Size = UDim2.fromOffset(size, size),
			Position = _param.position,
			AnchorPoint = _param.anchor,
			BackgroundColor3 = darken(accent, 0.6),
			BorderSizePixel = 0,
			Image = `rbxthumb://type=AvatarHeadShot&id={member.UserId}&w=150&h=150`,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 325,
		}, React.createElement("uicorner", {
			CornerRadius = radius,
		}), React.createElement("uistroke", {
			Color = accent,
			Thickness = 1.5,
			Transparency = 0.35,
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = _param.position,
		AnchorPoint = _param.anchor,
		BackgroundColor3 = darken(accent, 0.45),
		BorderSizePixel = 0,
		ZIndex = 325,
	}, React.createElement("uicorner", {
		CornerRadius = radius,
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.35,
	}), React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = string.upper(string.match(member.DisplayName, utf8.charpattern) or "?"),
		TextColor3 = Palette.cream,
		TextSize = math.floor(size * 0.46),
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 326,
	}))
end

local function MemberCard(_param)
	local member = _param.member
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local live = if member.UserId ~= nil then liveNames[member.UserId] else nil
	local displayName = if live ~= nil and type(live.display) == "string" and live.display ~= "" then live.display else member.DisplayName
	local username = if live ~= nil and type(live.username) == "string" then live.username else member.Name
	local hovered, setHovered = React.useState(false)
	local lift = useFlipperSpring(if hovered and MODEL.CardHoverLift then 1 else 0, reducedMotion, 620, 40)
	local arrive = useStagger(math.min(_param.index, MAX_STAGGER_INDEX), reducedMotion or not MODEL.EntranceStagger, MODEL.StaggerStep)
	local compact = MODEL.CardStyle == "Compact"
	local avatarSize = if compact then math.min(MODEL.AvatarSize, 48) else MODEL.AvatarSize
	local textX = if MODEL.ShowAvatars then avatarSize + 24 else 14
	local lines = {}
	local y = if compact then 0 else 12
	local function line(key, value, size, color, weight, height, wrap)
		lines[key] = React.createElement(Text, {
			value = value,
			size = size,
			color = color,
			weight = weight,
			wrap = wrap,
			fit = not wrap,
			minSize = if wrap then nil else math.max(9, size - 3),
			position = UDim2.fromOffset(textX, y),
			sizeConstraint = UDim2.new(1, -(textX + 12), 0, height),
			zIndex = 326,
		})
		y += height
	end
	if compact then
		lines.name = React.createElement(Text, {
			value = displayName,
			size = 14,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 10,
			position = UDim2.new(0, textX, 0.5, -9),
			sizeConstraint = UDim2.new(0.55, -textX, 0, 18),
			zIndex = 326,
		})
		if MODEL.ShowRoles and member.Role ~= "" then
			lines.role = React.createElement(Text, {
				value = string.upper(member.Role),
				size = 11,
				color = accent,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Right,
				fit = true,
				minSize = 9,
				position = UDim2.new(0.55, 0, 0.5, -8),
				sizeConstraint = UDim2.new(0.45, -12, 0, 16),
				zIndex = 326,
			})
		end
	else
		line("name", displayName, 15, Palette.cream, Enum.FontWeight.Heavy, 22, false)
		if MODEL.ShowUsernames and member.UserId ~= nil and username ~= displayName then
			line("username", "@" .. username, 11, Palette.muted, Enum.FontWeight.Bold, 16, false)
		end
		if MODEL.ShowRoles and member.Role ~= "" then
			line("role", string.upper(member.Role), 11, accent, Enum.FontWeight.Heavy, 18, false)
		end
		if MODEL.ShowNotes and member.Note ~= "" then
			line("note", member.Note, 12, Palette.creamSoft, Enum.FontWeight.Medium, 34, true)
		end
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = _param.index,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 323,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = React.joinBindings({ lift, arrive }):map(function(values)
			return UDim2.fromOffset(0, math.round(-values[1] * 3 + (1 - math.clamp(values[2], 0, 1)) * 12))
		end),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 324,
		Active = true,
		Event = {
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		},
	}, React.createElement("uiscale", {
		Scale = arrive:map(function(amount)
			return 0.94 + math.clamp(amount, 0, 1) * 0.06
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.panelRaised, Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = lift:map(function(amount)
			return 0.78 - math.clamp(amount, 0, 1) * 0.45
		end),
	}), MODEL.ShowAvatars and React.createElement(Avatar, {
		member = member,
		size = avatarSize,
		accent = accent,
		position = if compact then UDim2.new(0, 10, 0.5, 0) else UDim2.fromOffset(12, 12),
		anchor = if compact then Vector2.new(0, 0.5) else Vector2.zero,
	}), lines))
end

local function CategorySection(_param)
	local entry = _param.entry
	local category = entry.category
	local members = entry.members
	local accent = tone(category.Accent, Palette.violet)
	local columns = _param.columns
	local cardH = _param.cardH
	local width = _param.width
	local cellW = math.floor((width - GRID_GAP * (columns - 1)) / columns)
	local rows = math.ceil(#members / columns)
	local cards = {}
	cards.layout = React.createElement("uigridlayout", {
		CellSize = UDim2.fromOffset(cellW, cardH),
		CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = columns,
	})
	for index, member in members do
		cards[category.Id .. ":" .. member.Name .. ":" .. index] = React.createElement(MemberCard, {
			member = member,
			accent = accent,
			index = _param.firstIndex + index - 1,
			reducedMotion = _param.reducedMotion,
		})
	end
	local count = if MODEL.ShowCategoryCounts and #members > 0 then ` · {#members}` else ""
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, _param.height),
		LayoutOrder = _param.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 322,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, SECTION_HEADER_H - 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 323,
	}, React.createElement("frame", {
		Size = UDim2.new(0, 4, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 323,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = darken(accent, 0.62),
		BorderSizePixel = 0,
		ZIndex = 323,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Icon, {
		kind = category.Icon,
		color = Palette.cream,
		accent = lighten(accent, 0.2),
		size = 30,
	})), React.createElement(Text, {
		value = string.upper(category.Label) .. count,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(52, if category.Description ~= "" then 1 else 9),
		sizeConstraint = UDim2.new(1, -60, 0, 20),
		zIndex = 323,
	}), category.Description ~= "" and React.createElement(Text, {
		value = category.Description,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Medium,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(52, 21),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
		zIndex = 323,
	})), if #members == 0
		then React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, EMPTY_ROW_H),
			Position = UDim2.fromOffset(0, SECTION_HEADER_H),
			BackgroundColor3 = Palette.panel,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 323,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.6,
		}), React.createElement(Text, {
			value = category.EmptyText,
			size = 12,
			color = Palette.muted,
			weight = Enum.FontWeight.Medium,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(10, 0),
			sizeConstraint = UDim2.new(1, -20, 1, 0),
			zIndex = 324,
		}))
		else React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, rows * (cardH + GRID_GAP) - GRID_GAP),
			Position = UDim2.fromOffset(0, SECTION_HEADER_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 323,
		}, cards))
end

local function TabChip(_param)
	local tab = _param.tab
	local active = _param.active
	local accent = tone(tab.accent, tone(MODEL.Accent, Palette.violet))
	local hovered, setHovered = React.useState(false)
	local selected = useFlipperSpring(if active then 1 elseif hovered then 0.35 else 0, _param.reducedMotion, 700, 42)
	local label = if MODEL.ShowCategoryCounts then `{tab.label}  {tab.count}` else tab.label
	local width = math.max(64, #label * 8 + 28)
	return React.createElement("textbutton", {
		Size = UDim2.fromOffset(width, TAB_H),
		LayoutOrder = _param.order,
		BackgroundColor3 = selected:map(function(amount)
			return Palette.panel:Lerp(darken(accent, 0.5), math.clamp(amount, 0, 1))
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 324,
		Event = {
			Activated = function()
				_param.onPick(tab.id)
			end,
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = selected:map(function(amount)
			return 0.7 - math.clamp(amount, 0, 1) * 0.5
		end),
	}), React.createElement(Text, {
		value = string.upper(label),
		size = 11,
		color = if active then Palette.cream else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(8, 0),
		sizeConstraint = UDim2.new(1, -16, 1, 0),
		zIndex = 325,
	}))
end

local function CreditsOverlay(_param)
	local version = _param.version
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local softMotion = reducedMotion
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local tab, setTab = React.useState(MODEL.DefaultCategory)
	local query, setQuery = React.useState("")
	useLiveNames()
	local requestClose = React.useCallback(function()
		if exiting then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, exiting, onClose })
	local pickTab = function(id)
		if id == tab then
			return nil
		end
		Audio:play("tabSwitch")
		setTab(id)
	end

	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local pad = if stack then 14 else 22
	local safeSide = math.max(8, viewport.sideInset, chrome.sideSafe)
	local safeTop = math.max(8, viewport.topInset)
	local safeBottom = math.max(8, viewport.bottomInset, chrome.bottomSafe)
	local width = math.min(940, math.max(260, viewport.width - safeSide * 2 - 12))
	local height = math.min(680, math.max(260, viewport.height - safeTop - safeBottom - 12))
	local centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2)
	local closeSize = math.max(TapTarget - 4, 44)
	local innerW = width - pad * 2

	local tabs = CreditsModel.tabs(MODEL)
	local showTabs = MODEL.CategoryTabs and #tabs > 2
	local showSearch = CreditsModel.showSearch(MODEL)
	local searchBeside = showSearch and showTabs and innerW >= 620
	local headerH = if MODEL.Tagline ~= "" then 72 else 58
	local controlsH = (if showTabs or showSearch then TAB_H + 12 else 0) + (if showSearch and showTabs and not searchBeside then TAB_H + 8 else 0)
	local bodyTop = headerH + controlsH
	local bodyH = math.max(80, height - pad * 2 - bodyTop)

	local scrollBar = 4
	local contentW = innerW - scrollBar - 8
	local columns = CreditsModel.columns(MODEL, contentW, GRID_GAP)
	local cardH = CreditsModel.cardHeight(MODEL)
	local visible = CreditsModel.visible(MODEL, tab, query)

	React.useEffect(function()
		ClientLog:debug("nav", "credits opened")
		return function()
			return ClientLog:debug("nav", "credits closed")
		end
	end, {})
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed) then
				requestClose()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { requestClose })
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
			pcall(task.cancel, job)
		end
	end, {})

	local sections = {}
	local cursor = 0
	local cardIndex = 1
	for order, entry in visible do
		local rows = math.ceil(#entry.members / columns)
		local sectionH = SECTION_HEADER_H + (if #entry.members == 0 then EMPTY_ROW_H else rows * (cardH + GRID_GAP) - GRID_GAP)
		sections[entry.category.Id] = React.createElement(CategorySection, {
			entry = entry,
			columns = columns,
			cardH = cardH,
			width = contentW,
			height = sectionH,
			firstIndex = cardIndex,
			layoutOrder = order,
			reducedMotion = softMotion,
		})
		cardIndex += #entry.members
		cursor += sectionH + SECTION_GAP
	end
	if #visible == 0 then
		sections.none = React.createElement(Text, {
			value = if query ~= "" then `Nobody matches "{query}".` else MODEL.DefaultEmptyText,
			size = 13,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 40),
			zIndex = 323,
		})
		cursor += 40 + SECTION_GAP
	end
	local smallPrint = table.clone(MODEL.Acknowledgements)
	if MODEL.Footer ~= "" then
		table.insert(smallPrint, MODEL.Footer)
	end
	local footerH = #smallPrint * 16 + 8 + closeSize
	sections.footer = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, footerH),
		LayoutOrder = #visible + 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 322,
	}, React.createElement(Text, {
		value = table.concat(smallPrint, "\n"),
		size = 10,
		color = Palette.muted,
		wrap = true,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, #smallPrint * 16),
		zIndex = 323,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(0, closeSize),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 323,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "CLOSE",
		icon = "Close",
		onClick = requestClose,
		color = tone(MODEL.Accent, Palette.violet),
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, closeSize),
		hug = true,
		reducedMotion = softMotion,
		disabled = exiting,
		zIndex = 324,
	})))
	cursor += footerH

	local tabChips = {}
	if showTabs then
		tabChips.layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		for order, entry in tabs do
			tabChips[entry.id] = React.createElement(TabChip, {
				tab = entry,
				active = entry.id == tab,
				order = order,
				onPick = pickTab,
				reducedMotion = softMotion,
			})
		end
	end
	local searchW = if searchBeside then 220 else innerW
	local tabsW = if searchBeside then innerW - searchW - 10 else innerW
	local accent = tone(MODEL.Accent, Palette.violet)

	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		Name = "CreditsClaimActions",
		ref = overlayHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount * 0.82
		end),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = true,
		ZIndex = 318,
		Visible = reveal:map(function(amount)
			return amount > 0.003
		end),
	}, React.createElement("textbutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 319,
		Event = {
			Activated = requestClose,
		},
	}), React.createElement("frame", {
		ref = padFocus,
		Size = UDim2.fromOffset(width, height),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 0, centerY + math.floor((1 - amount) * 18))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 320,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = pad,
		zIndex = 321,
		clips = false,
		reveal = reveal,
		reducedMotion = softMotion,
		highlight = true,
	}, React.createElement(Text, {
		value = MODEL.Eyebrow,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 16),
		zIndex = 322,
	}), React.createElement(Text, {
		value = MODEL.Title,
		size = if stack then 22 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 32),
		zIndex = 322,
	}), React.createElement(Text, {
		value = table.concat({
			if MODEL.ShowVersion and version ~= nil then `VERSION {version}` else "",
			MODEL.Tagline,
		}, if MODEL.ShowVersion and version ~= nil and MODEL.Tagline ~= "" then "  ·  " else ""),
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 50),
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 16),
		zIndex = 322,
	}), React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromOffset(closeSize, closeSize),
		position = UDim2.new(1, -closeSize, 0, 0),
		reducedMotion = softMotion,
		disabled = exiting,
		zIndex = 323,
	}), showTabs and React.createElement("scrollingframe", {
		Size = UDim2.fromOffset(tabsW, TAB_H + 4),
		Position = UDim2.fromOffset(0, headerH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ZIndex = 323,
	}, tabChips), showSearch and React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = accent,
		placeholder = "Search names or roles",
		position = UDim2.fromOffset(if searchBeside then innerW - searchW else 0, headerH + (if showTabs and not searchBeside then TAB_H + 8 else 0)),
		size = UDim2.fromOffset(searchW, TAB_H),
		reducedMotion = softMotion,
		zIndex = 324,
	}), React.createElement("scrollingframe", {
		Size = UDim2.fromOffset(innerW, bodyH),
		Position = UDim2.fromOffset(0, bodyTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, cursor + 6),
		ScrollBarThickness = scrollBar,
		ScrollBarImageColor3 = accent,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		ZIndex = 322,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, SECTION_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 8),
	}), React.createElement(React.Fragment, {
		key = tab,
	}, sections))))))
end

return {
	CreditsOverlay = CreditsOverlay,
}
end

__defs["crateModel"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local subscribeContinuous = require(script.Parent.MotionKit)("motion").subscribeContinuous
local ShopCatalog = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("ShopCatalog")

local OPEN_ANGLE = 1.95
local kitListeners = {}
local kitWatch = nil

local function rgb(value, fallback)
	if type(value) ~= "table" then
		return fallback
	end
	return Color3.fromRGB(value[1] or 255, value[2] or 255, value[3] or 255)
end

local function skinOf(id)
	return ShopCatalog.skin(id) or ShopCatalog.skin(ShopCatalog.DEFAULT_SKIN)
end

local function kitFolder()
	local folder = ReplicatedStorage:FindFirstChild("CrateKit") or ReplicatedStorage:FindFirstChild("PropKit")
	return if folder ~= nil and folder:IsA("Folder") then folder else nil
end

local function useKitReady()
	local ready, setReady = React.useState(if kitFolder() ~= nil then 1 else 0)
	React.useEffect(function()
				local listener = function()
			setReady(function(revision)
					return revision + 1
				end)
		end
		kitListeners[listener] = true
		if kitWatch == nil then
			kitWatch = ReplicatedStorage.ChildAdded:Connect(function(child)
				if child.Name == "PropKit" or child.Name == "CrateKit" then
					for each in kitListeners do
						task.defer(each)
					end
				end
			end)
		end
		return function()
			kitListeners[listener] = nil
		end
	end, { ready })
	return ready
end

local function inert(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function buildCrate(model, skinId)
	local skin = skinOf(skinId)
	local folder = kitFolder()
	local bodySource = folder and folder:FindFirstChild(`Crate_{skin.Id}_Body`)
	local lidSource = folder and folder:FindFirstChild(`Crate_{skin.Id}_Lid`)
	local body, lid
	if bodySource ~= nil and lidSource ~= nil and bodySource:IsA("MeshPart") and lidSource:IsA("MeshPart") then
		body = bodySource:Clone()
		lid = lidSource:Clone()
	else
		local accent = rgb(skin.Accent, Color3.fromRGB(255, 184, 52))
		local material = require(script.Parent.CrateDetails).bodyMaterial(require(script.Parent.CrateDetails).family(skin.Id, skin.Family))
		body = Instance.new("Part")
		body.Size = Vector3.new(1.72, 1.04, 1.22)
		body.Color = accent:Lerp(Color3.new(0, 0, 0), 0.55)
		body.Material = material
		lid = Instance.new("Part")
		lid.Size = Vector3.new(1.8, 0.4, 1.3)
		lid.Color = accent:Lerp(Color3.new(0, 0, 0), 0.3)
		lid.Material = material
	end
	inert(body)
	inert(lid)
	local bodyH = body.Size.Y
	body.CFrame = CFrame.new(0, bodyH / 2, 0)
	body.Parent = model
		if bodySource == nil or lidSource == nil then
			require(script.Parent.CrateDetails).build(model, body, rgb(skin.Accent, body.Color), skin.Id, skin.Family)
		end
	local lidRest = CFrame.new(0, bodyH + lid.Size.Y / 2 - 0.01, 0)
	lid.CFrame = lidRest
	lid.Parent = model
	local lidPieces = {}
	if bodySource == nil or lidSource == nil then
		lidPieces = require(script.Parent.CrateDetails).buildLid(model, lid, rgb(skin.Accent, lid.Color), skin.Id, skin.Family)
	end
	local glow = inert(Instance.new("Part"))
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.one * 0.7
	glow.Material = Enum.Material.Neon
	glow.Color = rgb(skin.Glow, Color3.fromRGB(255, 220, 160))
	glow.Transparency = 1
	glow.CFrame = CFrame.new(0, bodyH - 0.2, 0)
	glow.Parent = model
	return {
		lid = lid,
		lidPieces = lidPieces,
		lidRest = lidRest,
		hinge = CFrame.new(0, bodyH, lid.Size.Z / 2),
		glow = glow,
		center = Vector3.new(0, (bodyH + lid.Size.Y) * 0.46, 0),
	}
end

local function pose(scene, camera, state, props)
	local zoom = props.zoom or 1
	local distance = 4.6 * zoom
	local yaw = state.yaw
	local lift = state.open
	local angle = lift * OPEN_ANGLE
	local shake = state.shake
	local rattle = if shake > 0 then math.sin(state.t * 46) * 0.05 * shake else 0
	scene.lid.CFrame = scene.hinge * CFrame.Angles(angle + math.abs(rattle) * 0.6, 0, 0) * scene.hinge:Inverse() * scene.lidRest
	local lidFrame = scene.lid.CFrame
	for _, piece in scene.lidPieces do
		piece.part.CFrame = lidFrame * piece.offset
	end
	scene.glow.Transparency = 1 - math.clamp(lift, 0, 1) * 0.55
	scene.glow.Size = Vector3.one * (0.5 + lift * 0.5)
	local focus = scene.center + Vector3.new(0, lift * 0.25, 0)
	local eye = focus + Vector3.new(math.sin(yaw) * distance, distance * 0.42, -math.cos(yaw) * distance)
	camera.CFrame = CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, rattle)
end

local function CrateModel(props)
	local host = React.useRef(nil)
	local propsRef = React.useRef(props)
	propsRef.current = props
	local kitReady = useKitReady()
	local skinId = skinOf(props.skin).Id
	local live = props.live ~= false
	React.useEffect(function()
		local viewport = host.current
		if viewport == nil then
			return nil
		end
		viewport:ClearAllChildren()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local model = Instance.new("Model")
		model.Parent = viewport
		local scene = buildCrate(model, skinId)
		local first = propsRef.current
		local state = {
			t = 0,
			yaw = first.yaw or -0.5,
			open = tonumber(first.open) or 0,
			shake = 0,
		}
		pose(scene, camera, state, first)
		if not live then
			return function()
				viewport:ClearAllChildren()
			end
		end
		local release = subscribeContinuous(function(dt)
			local now = propsRef.current
			state.t += dt
			local base = now.yaw or -0.5
			state.yaw = if now.spin then base + state.t * 0.55 else base + math.sin(state.t * 0.7) * 0.22
			local target = math.clamp(tonumber(now.open) or 0, 0, 1)
			local rate = if target > state.open then 9 else 4
			state.open += (target - state.open) * (1 - math.exp(-dt * rate))
			state.shake = math.clamp(tonumber(now.shake) or 0, 0, 1)
			pose(scene, camera, state, now)
		end)
		return function()
			release()
			viewport:ClearAllChildren()
		end
	end, { skinId, kitReady, live })
	return React.createElement("viewportframe", {
		ref = host,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = props.ambient or (if kitReady > 0 then Color3.fromRGB(200, 194, 208) else Color3.fromRGB(150, 140, 165)),
		LightColor = if kitReady > 0 then Color3.fromRGB(200, 192, 180) else Color3.fromRGB(255, 244, 224),
		LightDirection = Vector3.new(-0.5, -0.8, 1),
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder or 0,
	})
end

local function kitPiece(name, fit)
	local folder = ReplicatedStorage:FindFirstChild("PropKit")
	local source = folder and folder:FindFirstChild(name)
	if source == nil or not source:IsA("MeshPart") then
		return nil, 1
	end
	local part = inert(source:Clone())
	local size = part.Size
	local largest = math.max(size.X, size.Y, size.Z)
	if fit ~= nil and largest > 1e-3 then
		part.Size = size * (fit / largest)
		return part, fit / largest
	end
	return part, 1
end

return {
	CrateModel = CrateModel,
	kitFolder = kitFolder,
	kitPiece = kitPiece,
	useKitReady = useKitReady,
	skinOf = skinOf,
	skinAccent = function(id)
		return rgb(skinOf(id).Accent, Color3.fromRGB(255, 184, 52))
	end,
	skinGlow = function(id)
		return rgb(skinOf(id).Glow, Color3.fromRGB(255, 220, 160))
	end,
}
end

__defs["prismFx"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useClock = require(script.Parent.MotionKit)("motion").useClock

local PERIOD = 40
local TAU = math.pi * 2
local SEQUENCES = {
	Celestial = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 240, 255)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 226, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 240, 255)),
	}),
	Astral = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 200)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(170, 120, 255)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(100, 220, 255)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 255, 190)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 220, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 200)),
	}),
}
local CORE = {
	Celestial = Color3.fromRGB(190, 248, 255),
	Astral = Color3.fromRGB(255, 200, 240),
}
local SPARKS = {
	{ 0.08, 0.18, 7 }, { 0.92, 0.12, 9 }, { 0.2, 0.86, 8 }, { 0.82, 0.8, 11 }, { 0.5, 0.06, 10 },
	{ 0.04, 0.55, 12 }, { 0.96, 0.5, 13 }, { 0.36, 0.94, 9 }, { 0.66, 0.92, 7 }, { 0.62, 0.1, 14 },
}

local function isAscended(rarity)
	return rarity == "Celestial" or rarity == "Astral"
end

local function PrismAura(props)
	local rarity = if props.rarity == "Astral" then "Astral" else "Celestial"
	local clock = useClock(true, 1, PERIOD, false)
	local zIndex = props.zIndex or 1
	local intensity = props.intensity
	if intensity == nil then
		intensity = 1
	end
	local function scaled(map)
		if type(intensity) == "number" then
			return clock:map(function(t)
				return map(t, intensity)
			end)
		end
		return React.joinBindings({ clock, intensity }):map(function(values)
			return map(values[1], math.clamp(values[2], 0, 1))
		end)
	end
	local children = {
		Rim = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = zIndex + 2,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, props.corner or 12),
		}), React.createElement("uistroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = props.thickness or 2.5,
			Transparency = scaled(function(t, k)
				return 1 - k * (0.82 + 0.18 * math.sin(t * TAU / PERIOD * 8))
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, React.createElement("uigradient", {
			Color = SEQUENCES[rarity],
			Rotation = clock:map(function(t)
				return (t * 90) % 360
			end),
		}))),
	}
	if props.rays ~= false then
		local rays = {}
		for index = 1, 6 do
			rays[`Ray{index}`] = React.createElement("frame", {
				Size = UDim2.new(0, 10, 1.6, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = clock:map(function(t)
					return (index - 1) * 30 + (t * 9) % 360
				end),
				BackgroundColor3 = CORE[rarity],
				BackgroundTransparency = scaled(function(t, k)
					return 1 - k * (0.16 + 0.1 * math.sin(t * TAU / PERIOD * (3 + index)))
				end),
				BorderSizePixel = 0,
				ZIndex = zIndex,
			}, React.createElement("uigradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}))
		end
		children.Rays = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = props.clipRays ~= false,
			ZIndex = zIndex,
		}, rays)
	end
	if props.sparks ~= false then
		for index, spot in SPARKS do
			children[`Spark{index}`] = React.createElement("frame", {
				Size = scaled(function(t, k)
					local wave = math.max(0, math.sin(t * TAU / PERIOD * spot[3] + index))
					local px = math.round((3 + wave * 6) * k)
					return UDim2.fromOffset(px, px)
				end),
				Position = UDim2.fromScale(spot[1], spot[2]),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = if index % 2 == 0 then Color3.new(1, 1, 1) else CORE[rarity],
				BackgroundTransparency = scaled(function(t, k)
					local wave = math.max(0, math.sin(t * TAU / PERIOD * spot[3] + index))
					return 1 - k * wave
				end),
				BorderSizePixel = 0,
				ZIndex = zIndex + 3,
			})
		end
	end
	return React.createElement("frame", {
		Name = "PrismAura",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, children)
end

return {
	PrismAura = PrismAura,
	isAscended = isAscended,
	SEQUENCES = SEQUENCES,
	CORE = CORE,
}
end

__defs["RebirthCeremony"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber

local GOLDEN = math.pi * (3 - math.sqrt(5))
local HEAVY = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
local BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FULL = { shock = 0.55, count0 = 0.85, count1 = 1.75, ascend = 1.95, fade = 2.8, finish = 3.4 }
local CALM = { shock = 0, count0 = 0.12, count1 = 0.6, ascend = 0.7, fade = 1.35, finish = 1.7 }

local listeners = {}
local function subscribe(listener)
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end
-- payload: { rebirths, before, after, reward, stardust }
local function play(payload)
	for _, listener in table.clone(listeners) do
		task.spawn(listener, payload)
	end
end

local function ramp(t, a, b)
	if b <= a then
		return if t >= b then 1 else 0
	end
	return math.clamp((t - a) / (b - a), 0, 1)
end
local function outCubic(x)
	local y = 1 - x
	return 1 - y * y * y
end
local function outBack(x)
	local c = 1.55
	local y = x - 1
	return 1 + (c + 1) * y * y * y + c * y * y
end
-- multipliers may be persisted big-number strings; blend in log space so the count never lurches
local function blendMultiplier(before, after, k)
	if k >= 1 then
		return after
	end
	local a, b = asFlux(before), asFlux(after)
	if type(a) ~= "number" or type(b) ~= "number" or a ~= a or b ~= b or a <= 0 or b <= 0 or a == math.huge or b == math.huge then
		return before
	end
	return math.exp(math.log(a) + (math.log(b) - math.log(a)) * k)
end
local function multiplierText(value)
	local n = asFlux(value)
	if type(n) == "number" and n < 1000 then
		return string.format("×%.2f", n)
	end
	return "×" .. compactNumber(value)
end

local function corner(radius)
	return React.createElement("uicorner", { CornerRadius = radius or UDim.new(1, 0) })
end

local function Motes(props)
	local clock, tl, count = props.clock, props.tl, props.count
	local children = {}
	for i = 1, count do
		local angle = i * GOLDEN
		local radius = 230 + (i % 5) * 34
		local lead = (i / count) * 0.2
		local tint = if i % 3 == 0 then Palette.mint elseif i % 3 == 1 then Palette.violet else Palette.pink
		children["m" .. i] = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 4 == 0 then 8 else 5, if i % 4 == 0 then 8 else 5),
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			Position = clock:map(function(t)
				local pull = outCubic(ramp(t, lead, tl.shock))
				local swirl = angle + pull * 1.1
				local r = radius * (1 - pull)
				return UDim2.new(0.5, math.cos(swirl) * r, 0.5, math.sin(swirl) * r * 0.82)
			end),
			BackgroundTransparency = clock:map(function(t)
				if t >= tl.shock then
					return 1
				end
				return 1 - 0.9 * ramp(t, lead, lead + 0.14)
			end),
		}, corner())
	end
	return React.createElement(React.Fragment, nil, children)
end

local function Rings(props)
	local clock, tl = props.clock, props.tl
	local children = {}
	for k = 0, 2 do
		local start = tl.shock + k * 0.09
		children["r" .. k] = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = clock:map(function(t)
				local p = outCubic(ramp(t, start, start + 0.7))
				return UDim2.fromScale(0.04 + p * (1.25 - k * 0.22), 0.04 + p * (1.25 - k * 0.22))
			end),
			Visible = clock:map(function(t)
				return t >= start and t < start + 0.7
			end),
		}, corner(), React.createElement("uiaspectratioconstraint", { AspectRatio = 1 }), React.createElement("uistroke", {
			Color = if k == 1 then Palette.mint else Palette.violet,
			Thickness = clock:map(function(t)
				return 6 - 4 * ramp(t, start, start + 0.7)
			end),
			Transparency = clock:map(function(t)
				return 0.15 + 0.85 * ramp(t, start, start + 0.7)
			end),
		}))
	end
	return React.createElement(React.Fragment, nil, children)
end

local function Streaks(props)
	local clock, tl, count = props.clock, props.tl, props.count
	local children = {}
	for i = 1, count do
		local x = (i * 0.618034) % 1
		local start = tl.ascend + (i % 4) * 0.05
		local length = 0.55 + (i % 3) * 0.14
		local tall = 70 + (i * 37) % 90
		children["s" .. i] = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(if i % 5 == 0 then 3 else 2, tall),
			BackgroundColor3 = if i % 2 == 0 then Palette.violet else Palette.cream,
			BorderSizePixel = 0,
			Position = clock:map(function(t)
				local p = ramp(t, start, start + length)
				return UDim2.new(0.06 + x * 0.88, 0, 1.08 - p * 1.35, 0)
			end),
			BackgroundTransparency = clock:map(function(t)
				if t < start then
					return 1
				end
				return 0.2 + 0.8 * ramp(t, start + length * 0.5, start + length)
			end),
		}, React.createElement("uigradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}))
	end
	return React.createElement(React.Fragment, nil, children)
end

local function RebirthCeremonyHost(props)
	local antilag = useAntilag() or {}
	local session, setSession = React.useState(nil)
	local clock, setClock = React.useBinding(0)
	local jobsRef = React.useRef({})
	local skipRef = React.useRef(0)
	local function cancelJobs()
		for _, job in jobsRef.current do
			pcall(task.cancel, job)
		end
		jobsRef.current = {}
	end
	React.useEffect(function()
		local unsubscribe = subscribe(function(payload)
			setSession({
				id = os.clock(),
				payload = if type(payload) == "table" then payload else {},
			})
		end)
		return function()
			unsubscribe()
			cancelJobs()
		end
	end, {})
	local reduced = props.reducedMotion == true
	local plan = _motion.resolveIntent({
		role = "ceremony",
		emphasis = 1,
		reduced = reduced,
		tier = antilag.tier,
		particleBudget = antilag.particleBudget,
		glowScale = antilag.glowScale,
		allowConfetti = antilag.allowConfetti,
	})
	local calm = plan.reduced
	local tl = if calm then CALM else FULL
	React.useEffect(function()
		if session == nil then
			return nil
		end
		cancelJobs()
		skipRef.current = 0
		setClock(0)
		local function at(seconds, fn)
			table.insert(jobsRef.current, task.delay(seconds, fn))
		end
		if calm then
			Audio:play("rebirthTierUp")
		else
			Audio:play("rebirthIgnite")
			at(tl.shock, function()
				Audio:play("rebirthShockwave")
				InteractionFeedback.reward()
			end)
			at(tl.count0 + 0.04, function()
				Audio:play("rebirthTierUp")
			end)
			local ticks = 7
			for i = 1, ticks do
				at(tl.count0 + (tl.count1 - tl.count0) * i / (ticks + 1), function()
					Audio:play("countTick", 0.92 + i * 0.05)
				end)
			end
			at(tl.ascend, function()
				Audio:play("rebirthAscend")
			end)
		end
		local started = os.clock()
		local done = false
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if done then
				return
			end
			local t = os.clock() - started + skipRef.current
			setClock(t)
			if t >= tl.finish then
				done = true
				connection:Disconnect()
				setSession(nil)
			end
		end)
		return function()
			done = true
			connection:Disconnect()
			cancelJobs()
		end
	end, { session })
	if session == nil then
		return nil
	end
	local payload = session.payload
	local newCount = math.max(1, math.floor(tonumber(payload.rebirths) or 1))
	local oldCount = newCount - 1
	local before = if payload.before ~= nil then payload.before else 1
	local after = if payload.after ~= nil then payload.after else before
	local moteCount = if calm then 0 else math.clamp(plan.particles * 2, 8, 26)
	local streakCount = if calm then 0 else math.clamp(plan.particles, 5, 16)
	local shakeAmp = if calm then 0 else math.clamp(plan.shake * 2, 3, 12)
	local function fadeOut(t)
		return ramp(t, tl.fade, tl.finish)
	end
	local function contentIn(t)
		return outCubic(ramp(t, tl.count0 - 0.18, tl.count0 + 0.16))
	end
	local skip = function()
		local t = clock:getValue()
		if t < tl.fade then
			skipRef.current += tl.fade - t
			cancelJobs()
		end
	end
	local rewardLine = {}
	if payload.reward ~= nil then
		table.insert(rewardLine, "+" .. compactNumber(payload.reward) .. " cores")
	end
	if payload.stardust ~= nil then
		table.insert(rewardLine, "+" .. compactNumber(payload.stardust) .. " stardust")
	end
	return React.createElement("frame", {
		Name = "RebirthCeremony",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 500,
	}, React.createElement("frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		BackgroundTransparency = clock:map(function(t)
			return 1 - 0.62 * ramp(t, 0, 0.3) * (1 - fadeOut(t))
		end),
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Rotation = 90,
	})), React.createElement("frame", {
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = clock:map(function(t)
			if shakeAmp <= 0 or t < tl.shock then
				return UDim2.new()
			end
			local decay = 1 - ramp(t, tl.shock, tl.shock + 0.42)
			return UDim2.fromOffset(math.sin(t * 83) * shakeAmp * decay, math.cos(t * 67) * shakeAmp * 0.7 * decay)
		end),
	}, moteCount > 0 and React.createElement(Motes, { clock = clock, tl = tl, count = moteCount }), not calm and React.createElement("frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		Size = clock:map(function(t)
			local grow = outCubic(ramp(t, 0.05, tl.shock)) * 30
			local pop = math.sin(math.pi * ramp(t, tl.shock, tl.shock + 0.3)) * 46
			local gone = 1 - ramp(t, tl.shock + 0.15, tl.shock + 0.4)
			local s = (grow + pop) * gone
			return UDim2.fromOffset(s, s)
		end),
	}, corner(), React.createElement("uistroke", {
		Color = Palette.violet,
		Thickness = 3,
		Transparency = 0.25,
	})), not calm and React.createElement(Rings, { clock = clock, tl = tl }), streakCount > 0 and React.createElement(Streaks, { clock = clock, tl = tl, count = streakCount }), React.createElement("frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(420, 250),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = clock:map(function(t)
			local rise = outCubic(ramp(t, tl.ascend, tl.fade)) * 22 + fadeOut(t) * 18
			return UDim2.new(0.5, 0, 0.5, (1 - contentIn(t)) * 18 - rise)
		end),
	}, React.createElement("uiscale", {
		Scale = clock:map(function(t)
			return 0.92 + 0.08 * outBack(ramp(t, tl.count0 - 0.18, tl.count0 + 0.3))
		end),
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		FontFace = BOLD,
		Text = "REBIRTH",
		TextSize = 14,
		TextColor3 = Palette.violet,
		TextTransparency = clock:map(function(t)
			return 1 - contentIn(t) * (1 - fadeOut(t))
		end),
	}), React.createElement("frame", {
		Name = "Count",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		Text = tostring(oldCount),
		TextSize = 96,
		TextColor3 = Palette.muted,
		Position = clock:map(function(t)
			return UDim2.fromScale(0, -outCubic(ramp(t, tl.count0, tl.count0 + 0.3)))
		end),
		TextTransparency = clock:map(function(t)
			return 1 - contentIn(t) * (1 - ramp(t, tl.count0, tl.count0 + 0.24))
		end),
	}), React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		Text = tostring(newCount),
		TextSize = 96,
		TextColor3 = Palette.cream,
		Position = clock:map(function(t)
			return UDim2.fromScale(0, 1 - outBack(ramp(t, tl.count0 + 0.06, tl.count0 + 0.42)))
		end),
		TextTransparency = clock:map(function(t)
			return fadeOut(t)
		end),
	}, React.createElement("uistroke", {
		Color = Palette.violet,
		Thickness = 2,
		Transparency = clock:map(function(t)
			return 0.35 + 0.65 * fadeOut(t)
		end),
	}))), React.createElement("textlabel", {
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		TextSize = 30,
		TextColor3 = Palette.mint,
		Text = clock:map(function(t)
			local k = outCubic(ramp(t, tl.count0, tl.count1))
			return `{multiplierText(before)}  →  {multiplierText(blendMultiplier(before, after, k))}`
		end),
		TextTransparency = clock:map(function(t)
			return 1 - contentIn(t) * (1 - fadeOut(t))
		end),
	}), React.createElement("textlabel", {
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextSize = 17,
		TextColor3 = Palette.creamSoft,
		Text = if #rewardLine > 0 then table.concat(rewardLine, "    ") else "Permanent production raised",
		TextTransparency = clock:map(function(t)
			return 1 - ramp(t, tl.count1 - 0.2, tl.count1 + 0.1) * (1 - fadeOut(t))
		end),
	}))), React.createElement("frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BorderSizePixel = 0,
		BackgroundTransparency = clock:map(function(t)
			if calm or t < tl.shock then
				return 1
			end
			return 0.5 + 0.5 * outCubic(ramp(t, tl.shock, tl.shock + 0.3))
		end),
	}), React.createElement("textlabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(240, 18),
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextSize = 13,
		TextColor3 = Palette.muted,
		Text = "tap to skip",
		TextTransparency = clock:map(function(t)
			return 1 - 0.75 * ramp(t, 0.6, 1) * (1 - ramp(t, tl.fade - 0.2, tl.fade))
		end),
	}), React.createElement("textbutton", {
		Name = "Skip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		[React.Event.Activated] = skip,
	}))
end

return {
	play = play,
	RebirthCeremonyHost = RebirthCeremonyHost,
}
end

__defs["CrateRevealOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutCubic = _motion.easeOutCubic
local useBoatTween = _motion.useBoatTween
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local CrateRevealStage = require(script.Parent.pages.PagesShop)("CrateRevealStage").CrateRevealStage
local CARD_W = 156
local CARD_H = 132
local CARD_GAP = 12
local STRIDE = CARD_W + CARD_GAP
local START_SLOT = 2
local WIN_SLOT = 15
local FILLER_COUNT = 19
local START_OFFSET = START_SLOT * STRIDE
local TARGET_OFFSET = WIN_SLOT * STRIDE
local SPIN_SECONDS = 3.8
local BATCH_SPIN_SECONDS = 1.42
local EXIT_SETTLE = 0.42
-- the resonance climb walks this ladder one rung at a time before an Epic-or-better drop lands
local RARITY_LADDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral" }
local CLIMB_FROM_RANK = 4
local function rarityRank(rarity)
	for index, name in RARITY_LADDER do
		if name == rarity then
			return index
		end
	end
	return 1
end
local function playRevealCues(roll)
	if roll == nil then
		Audio:play("crateLand")
		return
	end
	local plan = _motion.resolveIntent({ role = "reveal", rarity = roll.Rarity })
	local special = roll.New == true or roll.Pity == true
	if plan.celebrate then
		Audio:playCelebration({ plan.cue or "crateRevealMythic", "discovery", "prestige", "reward" }, 0.12)
		InteractionFeedback.reward()
	elseif plan.weight >= 0.75 then
		Audio:playCelebration({ plan.cue or "crateRevealMythic", "discovery", "reward" }, 0.08)
	elseif plan.weight >= 0.4 then
		Audio:playCelebration({ plan.cue or "crateRevealEpic", if special then "crateRare" else "crateLand" }, 0.06)
	else
		Audio:play(if special then "crateRare" else "crateLand")
	end
end
local function rarityColor(config, rarity)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Rarities[rarity]
		if _result ~= nil then
			_result = _result.Color
		end
	end
	local _condition = _result
	if _condition == nil then
		_condition = Palette.mango
	end
	return _condition
end
local function definitionName(config, definitionId)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Definitions
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	for _, definition in _condition do
		if definition.Id == definitionId then
			return definition.Name
		end
	end
	return definitionId
end
local function buildStrip(config, session, roll, rollIndex)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Crates
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	local _callback = function(entry)
		return entry.Id == session.crateId
	end
	local _result_1
	for _i, _v in _condition do
		if _callback(_v, _i - 1, _condition) == true then
			_result_1 = _v
			break
		end
	end
	local crate = _result_1
	local _result_2 = crate
	if _result_2 ~= nil then
		_result_2 = _result_2.Weights
	end
	local _condition_1 = _result_2
	if _condition_1 == nil then
		_condition_1 = {
			Common = 1,
		}
	end
	local weights = _condition_1
	local _result_3 = config.Items
	if _result_3 ~= nil then
		_result_3 = _result_3.Definitions
	end
	local _condition_2 = _result_3
	if _condition_2 == nil then
		_condition_2 = {}
	end
	local definitions = _condition_2
	local pools = {}
	for _, definition in definitions do
		local _rarity = definition.Rarity
		local pool = pools[_rarity]
		if pool == nil then
			pool = {}
			local _rarity_1 = definition.Rarity
			local _pool = pool
			pools[_rarity_1] = _pool
		end
		table.insert(pool, definition)
	end
	local weighted = {}
	local totalWeight = 0
	for rarity, rawWeight in pairs(weights) do
		local weight = math.max(0, rawWeight)
		if weight <= 0 then
			continue
		end
		local _arg0 = {
			rarity = rarity,
			weight = weight,
		}
		table.insert(weighted, _arg0)
		totalWeight += weight
	end
	table.sort(weighted, function(a, b)
		return a.rarity < b.rarity
	end)
	local fillerAt = function(seed)
		if #definitions == 0 then
			return nil
		end
		if totalWeight <= 0 then
			return definitions[seed % #definitions + 1]
		end
		local sample = ((math.abs(math.sin(seed * 12.9898)) * 43758.5453) % 1) * totalWeight
		local selected
		for _, entry in weighted do
			sample -= entry.weight
			if sample <= 0 then
				selected = entry.rarity
				break
			end
		end
		local _result_4
		if selected ~= nil then
			local _selected = selected
			_result_4 = pools[_selected]
		else
			_result_4 = nil
		end
		local pool = _result_4
		if pool == nil or #pool == 0 then
			return definitions[seed % #definitions + 1]
		end
		return pool[seed % #pool + 1]
	end
	local cards = {}
	for index = 0, FILLER_COUNT - 1 do
		if index == WIN_SLOT then
			local _arg0 = {
				key = `winner-{roll.Uid}-{rollIndex}`,
				definitionId = roll.DefinitionId,
				name = definitionName(config, roll.DefinitionId),
				rarity = roll.Rarity,
				accent = rarityColor(config, roll.Rarity),
				winner = true,
				tag = if roll.New == true then "NEW" elseif roll.Pity == true then "PITY" else "WIN",
			}
			table.insert(cards, _arg0)
			continue
		end
		local filler = fillerAt(rollIndex * 97 + index * 13 + 11)
		local _object = {
			key = if filler ~= nil then `filler-{rollIndex}-{index}-{filler.Id}` else `fallback-{rollIndex}-{index}`,
		}
		local _left = "definitionId"
		local _result_4 = filler
		if _result_4 ~= nil then
			_result_4 = _result_4.Id
		end
		local _condition_3 = _result_4
		if _condition_3 == nil then
			_condition_3 = roll.DefinitionId
		end
		_object[_left] = _condition_3
		local _left_1 = "name"
		local _result_5 = filler
		if _result_5 ~= nil then
			_result_5 = _result_5.Name
		end
		local _condition_4 = _result_5
		if _condition_4 == nil then
			_condition_4 = definitionName(config, roll.DefinitionId)
		end
		_object[_left_1] = _condition_4
		local _left_2 = "rarity"
		local _result_6 = filler
		if _result_6 ~= nil then
			_result_6 = _result_6.Rarity
		end
		local _condition_5 = _result_6
		if _condition_5 == nil then
			_condition_5 = roll.Rarity
		end
		_object[_left_2] = _condition_5
		local _left_3 = "accent"
		local _exp = config
		local _result_7 = filler
		if _result_7 ~= nil then
			_result_7 = _result_7.Rarity
		end
		local _condition_6 = _result_7
		if _condition_6 == nil then
			_condition_6 = roll.Rarity
		end
		_object[_left_3] = rarityColor(_exp, _condition_6)
		_object.winner = false
		table.insert(cards, _object)
	end
	return cards
end
local function reelProgress(t, travel)
	local x = math.clamp(t, 0, 1)
	if x <= 0.13 then
		local u = x / 0.13
		return 0.055 * u * u * u
	end
	if x <= 0.67 then
		local u = (x - 0.13) / 0.54
		return 0.055 + 0.735 * (u + math.sin(u * math.pi) * 0.035)
	end
	if x <= 0.92 then
		local u = (x - 0.67) / 0.25
		return 0.79 + 0.21 * (1 - math.pow(1 - u, 3.7))
	end
	local u = (x - 0.92) / 0.08
	local overshoot = math.min(0.018, STRIDE * 0.34 / math.max(STRIDE, travel))
	return 1 + math.sin(u * math.pi * 2) * math.exp(-3.6 * u) * overshoot
end
local function CrateRevealExperience(_param)
	local session = _param.session
	local config = _param.config
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local reelFrameRate = 240
	local rollIndex, setRollIndex = React.useState(0)
	local phase, setPhase = React.useState("enter")
	local offset, setOffset = React.useBinding(START_OFFSET)
	local spinEnergy, setSpinEnergy = React.useBinding(0)
	local spinProgress, setSpinProgress = React.useBinding(0)
	local tickEnergy, setTickEnergy = React.useBinding(0)
	local closedRef = React.useRef(false)
	local spinSettledRef = React.useRef(false)
	local quickLandAtRef = React.useRef(-1)
	local quickLandOffsetRef = React.useRef(START_OFFSET)
	local brakeSoundedRef = React.useRef(false)
	local live, setLive = React.useState(false)
	local climbStep, setClimbStep = React.useState(0)
	local climbSkipRef = React.useRef(false)
	local _binding = useExitTransition(reducedMotion, EXIT_SETTLE)
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	React.useEffect(function()
		local alive = true
		local job = task.defer(function()
			if alive then
				setLive(true)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, {})
	local present = live
	local motionScale = if reducedMotion then 0.55 else 1
	local boatShow = useBoatTween(if present then 1 else 0, (if present then 0.3 else EXIT_SETTLE) * motionScale, false, easeOutCubic, 0)
	local showSpring = useFlipperSpring(if present then 1 else 0, false, 720, 36)
	local show = showSpring
	local landHold = phase == "land" or phase == "done" or phase == "exit"
	local claimHold = phase == "done" or phase == "exit"
	local landPopSpring = useFlipperSpring(if landHold then 1 else 0, false, 640, 14)
	local landPop = landPopSpring
	local claimSlideSpring = useFlipperSpring(if claimHold then 1 else 0, false, 520, 24)
	local claimSlide = claimSlideSpring
	local landFlash = useFlash(if phase == "land" then rollIndex + 1 else 0, false, 0.62 * motionScale)
	local claimFlash = useFlash(if phase == "done" then rollIndex + 11 else 0, false, 0.48 * motionScale)
	local sealFlash = useFlash(if phase == "seal" then rollIndex + 21 else 0, false, 0.55 * motionScale)
	local climbFlash = useFlash(if phase == "climb" then climbStep + 31 else 0, false, 0.22)
	local chargePulseSpring = useFlipperSpring(if phase == "charge" or phase == "seal" then 1 else 0, false, 360, 19)
	local chargePulse = chargePulseSpring
	local rolls = session.rolls
	if type(rolls) ~= "table" then
		rolls = {}
	end
	local currentRoll = rolls[math.clamp(rollIndex, 0, math.max(0, #rolls - 1)) + 1]
	local strip = React.useMemo(function()
		return buildStrip(config, session, currentRoll, rollIndex)
	end, { config, currentRoll, rollIndex, session })
	local travelDistance = TARGET_OFFSET - START_OFFSET
	React.useEffect(function()
		local previousTouch = GuiService.TouchControlsEnabled
		GamepadNavigationService.BeginOverlayFocus()
		GuiService.TouchControlsEnabled = false
		return function()
			GamepadNavigationService.EndOverlayFocus()
			GuiService.TouchControlsEnabled = previousTouch
		end
	end, {})
	React.useEffect(function()
		if phase ~= "enter" then
			return nil
		end
		local alive = true
		local job = task.delay(if reducedMotion then 0.12 else 0.2, function()
			if alive then
				setPhase("charge")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, reducedMotion })
	React.useEffect(function()
		if phase ~= "charge" then
			return nil
		end
		Audio:play("crateCharge")
		local alive = true
		local job = task.delay(if reducedMotion then 0.32 else 0.62, function()
			if alive then
				setPhase("seal")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, reducedMotion })
	React.useEffect(function()
		if phase ~= "seal" then
			return nil
		end
		Audio:play("crateSeal")
		InteractionFeedback.confirm()
		local alive = true
		local job = task.delay(if reducedMotion then 0.16 else 0.44, function()
			if alive then
				setPhase("spin")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, reducedMotion })
	local landCurrent = React.useCallback(function()
		if spinSettledRef.current then
			return nil
		end
		spinSettledRef.current = true
		setOffset(TARGET_OFFSET)
		setSpinEnergy(0)
		setSpinProgress(1)
		setTickEnergy(1)
		local rank = if currentRoll ~= nil then rarityRank(currentRoll.Rarity) else 1
		if rank >= CLIMB_FROM_RANK and not reducedMotion then
			climbSkipRef.current = false
			setClimbStep(0)
			setPhase("climb")
			return
		end
		setPhase("land")
		playRevealCues(currentRoll)
		InteractionFeedback.reward()
	end, { currentRoll, reducedMotion, setOffset, setSpinEnergy, setSpinProgress, setTickEnergy })
	React.useEffect(function()
		if phase ~= "climb" then
			return nil
		end
		local alive = true
		local target = if currentRoll ~= nil then rarityRank(currentRoll.Rarity) else 1
		local job = task.spawn(function()
			-- each rung arrives a little faster than the last, so the climb accelerates into the reveal
			for step = 1, target do
				if not alive or climbSkipRef.current then
					break
				end
				setClimbStep(step)
				Audio:play("crateRarityStep", 0.88 + step * 0.07)
				if step >= CLIMB_FROM_RANK then
					InteractionFeedback.tick()
				end
				task.wait(math.max(0.07, 0.17 - step * 0.012))
			end
			if not alive then
				return
			end
			setClimbStep(target)
			task.wait(0.08)
			if not alive then
				return
			end
			setPhase("land")
			playRevealCues(currentRoll)
			InteractionFeedback.reward()
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, currentRoll })
	local skipSpin = React.useCallback(function()
		if phase == "climb" then
			climbSkipRef.current = true
			return nil
		end
		if phase ~= "spin" then
			return nil
		end
		Audio:play("crateNear")
		if quickLandAtRef.current < 0 then
			quickLandAtRef.current = os.clock()
			quickLandOffsetRef.current = START_OFFSET
		end
	end, { phase })
	React.useEffect(function()
		if phase ~= "spin" then
			return nil
		end
		spinSettledRef.current = false
		setOffset(START_OFFSET)
		setSpinEnergy(0)
		setSpinProgress(0)
		setTickEnergy(0)
		quickLandAtRef.current = -1
		quickLandOffsetRef.current = START_OFFSET
		brakeSoundedRef.current = false
		Audio:play("crateOpen")
		if rollIndex == 0 and not reducedMotion then
			Audio:play("crateOrbit")
		end
		local startedAt = os.clock()
		local lastVisualAt = startedAt - 1 / reelFrameRate
		local duration = (if rollIndex == 0 then SPIN_SECONDS else BATCH_SPIN_SECONDS) * (if reducedMotion then 0.55 else 1)
		local lastTickSlot = -1
		local lastTickAt = -math.huge
		local previousValue = START_OFFSET
		local tick = 0
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if spinSettledRef.current then
				connection:Disconnect()
				return nil
			end
			local now = os.clock()
			local elapsed = now - startedAt
			local raw = math.clamp(elapsed / duration, 0, 1)
			if raw < 1 and now - lastVisualAt < 1 / reelFrameRate then
				return nil
			end
			local visualDelta = math.max(1 / 240, now - lastVisualAt)
			lastVisualAt = now
			local value
			if quickLandAtRef.current >= 0 then
				if quickLandOffsetRef.current == START_OFFSET then
					quickLandOffsetRef.current = previousValue
				end
				local quick = math.clamp((now - quickLandAtRef.current) / 0.34, 0, 1)
				value = quickLandOffsetRef.current + (TARGET_OFFSET - quickLandOffsetRef.current) * (1 - math.pow(1 - quick, 4))
				raw = 0.94 + quick * 0.06
			else
				value = START_OFFSET + travelDistance * reelProgress(raw, travelDistance)
			end
			setOffset(value)
			setSpinProgress(raw)
			local cardsPerSecond = math.abs(value - previousValue) / visualDelta / STRIDE
			previousValue = value
			local authoredEnergy = if raw < 0.1 then raw / 0.1 elseif raw < 0.7 then 1 else math.clamp((0.97 - raw) / 0.27, 0, 1)
			setSpinEnergy(math.clamp(cardsPerSecond / 18, 0, 1) * authoredEnergy)
			if raw >= 0.69 and not brakeSoundedRef.current then
				brakeSoundedRef.current = true
				Audio:play("crateBrake")
			end
			tick *= math.exp(-visualDelta * 18)
			local slot = math.floor(value / STRIDE + 0.5)
			local tickGap = if rollIndex == 0 then 0.045 else 0.065
			if slot ~= lastTickSlot and raw < 0.97 and elapsed - lastTickAt >= tickGap then
				lastTickSlot = slot
				lastTickAt = elapsed
				tick = if raw > 0.72 then 1 else 0.58
				Audio:play("crateTick", 0.94 + raw * 0.18)
				if raw > 0.72 then
					InteractionFeedback.tick()
				end
			end
			setTickEnergy(tick)
			if raw >= 1 then
				connection:Disconnect()
				landCurrent()
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { landCurrent, phase, reducedMotion, reelFrameRate, rollIndex, setOffset, setSpinEnergy, setSpinProgress, setTickEnergy, travelDistance })
	React.useEffect(function()
		if phase ~= "land" then
			return nil
		end
		local alive = true
		local landed = rolls[rollIndex + 1]
		local ascended = landed ~= nil and (landed.Rarity == "Celestial" or landed.Rarity == "Astral")
		local hold = if ascended then 1.6 elseif rollIndex >= #rolls - 1 then 0.72 else 0.62
		local job = task.delay(hold, function()
			if not alive then
				return nil
			end
			if rollIndex >= #rolls - 1 then
				setPhase("done")
			else
				setRollIndex(function(value)
					return value + 1
				end)
				setPhase("spin")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, rollIndex, rolls })
	local finish = React.useCallback(function()
		if closedRef.current or phase == "exit" or exiting then
			return nil
		end
		GamepadNavigationService.ClearSelection()
		Audio:play("crateClaim")
		InteractionFeedback.confirm()
		setPhase("exit")
		beginExit(function()
			if not closedRef.current then
				closedRef.current = true
				onClose()
			end
		end)
	end, { beginExit, exiting, onClose, phase })
	React.useEffect(function()
		local actionName = "AstralForgeCrateClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				if phase == "spin" or phase == "climb" then
					skipSpin()
				elseif phase == "done" then
					finish()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		local input = UserInputService.InputBegan:Connect(function(event, processed)
			if processed then
				return nil
			end
			local activate = event.KeyCode == Enum.KeyCode.ButtonA or event.KeyCode == Enum.KeyCode.Return or event.KeyCode == Enum.KeyCode.Space
			if not activate then
				return nil
			end
			if phase == "spin" or phase == "climb" then
				skipSpin()
			elseif phase == "done" then
				finish()
			end
		end)
		return function()
			input:Disconnect()
			ContextActionService:UnbindAction(actionName)
		end
	end, { finish, phase, skipSpin })
	local count = #rolls
	local safeRoll = currentRoll or {
		Rarity = "Common",
		DefinitionId = "Unknown",
		New = false,
		Pity = false,
		AutoSalvaged = false,
		Essence = 0,
	}
	local winnerAccent = rarityColor(config, safeRoll.Rarity)
	local _result
	if safeRoll.AutoSalvaged == true then
		local _condition = safeRoll.Essence
		if _condition == nil then
			_condition = 0
		end
		_result = `+{_condition} ESSENCE`
	else
		_result = if safeRoll.New == true then "NEW FIND" elseif safeRoll.Pity == true then "PITY DROP" else "OWNED"
	end
	local resultTag = _result
	local resultDetail = if safeRoll.AutoSalvaged == true then "Relic Recycler converted this drop into essence." elseif safeRoll.Pity == true then "Pity protection delivered this rarity." elseif safeRoll.New == true then "Added to your relic inventory." else "Added to your inventory."
	local _exp = rolls
	local _result_1 = true
	local _callback = function(roll)
		return roll.AutoSalvaged == true
	end
	for _k, _v in _exp do
		if not _callback(_v, _k - 1, _exp) then
			_result_1 = false
			break
		end
	end
	local claimText = if _result_1 then "BANK ESSENCE" elseif count == 1 then "CLAIM RELIC" else `CLAIM {count} DROPS`
	local visualShow = React.joinBindings({ show, boatShow, exitAmount }):map(function(values)
		return math.clamp(math.min(values[1], values[2], values[3]), 0, 1)
	end)
	local winnerCardScale = React.joinBindings({ landPop, landFlash, claimFlash }):map(function(values)
		return 0.94 + values[1] * 0.075 + values[2] * 0.025 + values[3] * 0.02
	end)
	return React.createElement(CrateRevealStage, {
		crateName = session.crateName,
		skin = require(game.ReplicatedStorage.AstralForge.Shared.CrateAppearance).resolve(_param.skin, session.crateId, config.Items.Crates),
		sessionAccent = session.accent,
		cards = strip,
		cardWidth = CARD_W,
		cardHeight = CARD_H,
		stride = STRIDE,
		reelOffset = offset,
		phase = phase,
		rollIndex = rollIndex,
		rollCount = count,
		winnerName = definitionName(config, safeRoll.DefinitionId),
		winnerRarity = safeRoll.Rarity,
		winnerAccent = winnerAccent,
		resultTag = resultTag,
		resultDetail = resultDetail,
		claimText = claimText,
		reducedMotion = reducedMotion,
		shortLandscape = chrome.landscape and viewport.height < 400,
		portrait = chrome.portrait,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		topInset = viewport.topInset,
		bottomSafe = math.max(chrome.bottomSafe, 8),
		sideSafe = math.max(chrome.sideSafe, viewport.sideInset),
		fxBudget = antilag.fxBudget,
		glowScale = antilag.glowScale,
		allowAmbient = antilag.allowAmbient,
		economyMode = chrome.mobile or antilag.tier <= 1,
		visualShow = visualShow,
		spinEnergy = spinEnergy,
		spinProgress = spinProgress,
		tickEnergy = tickEnergy,
		landFlash = landFlash,
		landPop = landPop,
		claimSlide = claimSlide,
		chargePulse = chargePulse,
		sealFlash = sealFlash,
		climbFlash = climbFlash,
		climbStep = climbStep,
		climbColor = rarityColor(config, RARITY_LADDER[math.clamp(climbStep, 1, #RARITY_LADDER)]),
		winnerRank = rarityRank(safeRoll.Rarity),
		ladderColors = (function()
			local colors = {}
			for index, name in RARITY_LADDER do
				colors[index] = rarityColor(config, name)
			end
			return colors
		end)(),
		winnerCardScale = winnerCardScale,
		onQuickLand = skipSpin,
		onClaim = finish,
	})
end
local function EmptyCrateReveal(_param)
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local safeGutter = viewport.sideInset + 10
	local width = math.max(1, math.min(360, viewport.width - safeGutter * 2))
	local focusRef = useGamepadAutofocus(true)
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		local host = focusRef.current
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
			pcall(task.cancel, job)
		end
	end, {})
	return React.createElement("frame", {
		ref = focusRef,
		Name = "CrateClaim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = true,
		ZIndex = 400,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(width, 164),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 410,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.coral,
		background = Palette.panelRaised,
		padding = 16,
		clips = false,
		zIndex = 411,
	}, React.createElement(Text, {
		value = "Crate didn't open",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 14,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
		zIndex = 412,
	}), React.createElement(Text, {
		value = "Nothing was taken. Try opening it again.",
		size = 12,
		color = Palette.creamSoft,
		align = Enum.TextXAlignment.Center,
		wrap = true,
		position = UDim2.fromOffset(0, 36),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
		zIndex = 412,
	}), React.createElement(Button, {
		text = "BACK TO INVENTORY",
		icon = "Close",
		onClick = onClose,
		color = Palette.coral,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		selectable = true,
		highlight = true,
		zIndex = 413,
	}))))
end
local function CrateRevealOverlay(props)
	local session = props.session
	local rolls = if session ~= nil then session.rolls else nil
	local hasRolls = type(rolls) == "table" and #rolls > 0
	local _result
	if hasRolls then
		local _attributes = table.clone(props)
		setmetatable(_attributes, nil)
		_result = React.createElement(CrateRevealExperience, _attributes)
	else
		_result = React.createElement(EmptyCrateReveal, {
			reducedMotion = props.reducedMotion,
			onClose = props.onClose,
		})
	end
	return _result
end
return {
	CrateRevealOverlay = CrateRevealOverlay,
}
end

__defs["CrateRevealStageSimple"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local _ui = __load("ui")
local Button = _ui.Button
local Text = _ui.Text
local CrateModel = __load("crateModel").CrateModel
local _prism = __load("prismFx")
local PrismAura = _prism.PrismAura
local isAscended = _prism.isAscended

local h = React.createElement

local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- One relic sigil riding the astrolabe ring. Angle comes from the shared reel offset so
-- skip / land / batch logic in the overlay stays untouched; depth fakes perspective.
local function OrbitNode(props)
	local card = props.card
	local accent = card.accent or Palette.cyan
	local landedWinner = card.winner and props.landed
	local geometry = props.reelOffset:map(function(offset)
		local theta = ((props.index - 1) - offset / props.stride) * props.step
		local depth = (math.cos(theta) + 1) / 2
		return { theta = theta, depth = depth }
	end)
	local base = props.nodeSize
	return h("frame", {
		Size = geometry:map(function(g)
			local s = math.round(base * (0.42 + 0.58 * g.depth) * (if landedWinner then 1.1 else 1))
			return UDim2.fromOffset(s, s)
		end),
		Position = geometry:map(function(g)
			return UDim2.fromOffset(props.cx + props.rx * math.sin(g.theta), props.cy + props.ry * math.cos(g.theta))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = geometry:map(function(g)
			return 433 + math.round(g.depth * 6)
		end),
	},
		h("frame", {
			Size = UDim2.fromScale(0.66, 0.66),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = geometry:map(function(g)
				return 0.15 + (1 - g.depth) * 0.6
			end),
			BorderSizePixel = 0,
			ZIndex = geometry:map(function(g)
				return 433 + math.round(g.depth * 6)
			end),
		},
			h("uicorner", { CornerRadius = UDim.new(0.18, 0) }),
			h("uistroke", {
				Color = accent,
				Thickness = if landedWinner then 2 else 1,
				Transparency = geometry:map(function(g)
					return if landedWinner then 0 else 0.2 + (1 - g.depth) * 0.65
				end),
			}),
			h("frame", {
				Size = UDim2.fromScale(0.42, 0.42),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = accent,
				BackgroundTransparency = geometry:map(function(g)
					return (1 - g.depth) * 0.7
				end),
				BorderSizePixel = 0,
				ZIndex = geometry:map(function(g)
					return 434 + math.round(g.depth * 6)
				end),
			}, h("uicorner", { CornerRadius = UDim.new(0.2, 0) }))
		),
		isAscended(card.rarity) and landedWinner and h(PrismAura, {
			rarity = card.rarity,
			intensity = 1,
			rays = false,
			sparks = not props.reducedMotion,
			corner = 999,
			zIndex = 440,
		}),
		h("textlabel", {
			Size = UDim2.new(2.4, 0, 0, 12),
			Position = UDim2.new(0.5, 0, 1, 2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = string.upper(card.rarity or "RELIC"),
			TextColor3 = accent,
			TextSize = 9,
			FontFace = FONT_BOLD,
			TextTransparency = geometry:map(function(g)
				return 1 - smooth((g.depth - 0.78) / 0.2)
			end),
			ZIndex = 441,
		})
	)
end

local function CrateRevealStage(props)
	local panelRef = React.useRef(nil)
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
	local climbing = props.phase == "climb"
	local ladderTarget = props.winnerRank or 1
	local showLadder = (climbing or landed) and ladderTarget >= 4
	local accent = if landed then props.winnerAccent elseif climbing then props.climbColor or props.sessionAccent else props.sessionAccent
	local resultTitle = if landed then props.winnerName elseif climbing then "Resonance rising" elseif props.phase == "spin" then "Attuning the astrolabe" elseif props.phase == "seal" then "Seal breaking" else "Unsealing crate"
	local resultSubtitle = if landed then props.resultDetail elseif climbing then "Something rare is answering. Tap to skip." elseif props.phase == "spin" then "Tap anywhere to lock the ring" else "The forge is waking up"
	local status = if props.phase == "spin" then "ATTUNING" elseif climbing then "RESONATING" elseif landed then "RELIC BOUND" else "UNSEALING"
	local actionY = panelHeight - padding - actionHeight
	local resultY = actionY - gap - resultHeight
	local trackY = padding + headerHeight + gap
	local ascended = landed and isAscended(props.winnerRarity)
	if ascended then
		status = if props.winnerRarity == "Astral" then "ASTRAL RELIC" else "CELESTIAL RELIC"
	end
	local crateSize = headerHeight - 4
	local nameX = padding + crateSize + 10
	local introOpen = props.phase == "spin" or landed
	local intro = props.rollIndex == 0 and (props.phase == "enter" or props.phase == "charge" or props.phase == "seal" or props.phase == "spin")
	local introFade = props.spinProgress:map(function(value)
		return if props.phase == "spin" then math.clamp((value - 0.05) / 0.09, 0, 1) else 0
	end)

	local nodeSize = math.clamp(math.round(math.min(trackHeight * 0.3, trackWidth * 0.11)), 26, 62)
	local ringCx = trackWidth / 2
	local ringCy = trackHeight / 2 - nodeSize * 0.12
	local ringRx = math.max(nodeSize, trackWidth / 2 - nodeSize * 0.75)
	local ringRy = math.max(8, trackHeight / 2 - nodeSize * 0.62)
	local step = (2 * math.pi) / math.max(1, #props.cards)
	local nodes = {}
	for i, card in props.cards do
		nodes[i] = h(OrbitNode, {
			key = card.key,
			card = card,
			index = i,
			step = step,
			stride = props.stride,
			reelOffset = props.reelOffset,
			nodeSize = nodeSize,
			cx = ringCx,
			cy = ringCy,
			rx = ringRx,
			ry = ringRy,
			landed = landed,
			reducedMotion = props.reducedMotion,
		})
	end
	local coreSize = math.round(math.min(ringRy * 1.5, ringRx * 0.62, trackHeight * 0.62))
	local spinAngle = if props.reducedMotion then nil else props.spinProgress:map(function(value)
		return value * 540
	end)

	local function orbitLine(scale, transparency, zIndex)
		return h("frame", {
			Size = UDim2.fromOffset(ringRx * 2 * scale, ringRy * 2 * scale),
			Position = UDim2.fromOffset(ringCx, ringCy),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = accent,
			Thickness = 1,
			Transparency = transparency,
		}))
	end

	local track = h("frame", {
		Name = "Astrolabe",
		Size = UDim2.fromOffset(trackWidth, trackHeight),
		Position = UDim2.fromOffset(padding, trackY),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 430,
	},
		h("uicorner", { CornerRadius = UDim.new(0, 12) }),
		h("uigradient", {
			Color = ColorSequence.new(Palette.panel, Palette.void),
			Transparency = NumberSequence.new(0.2, 0),
			Rotation = 90,
		}),
		orbitLine(1, 0.55, 431),
		orbitLine(0.72, 0.82, 431),
		orbitLine(1.18, 0.9, 431),
		-- front marker: the sigil that settles under it is the drop
		h("frame", {
			Size = props.tickEnergy:map(function(value)
				return UDim2.fromOffset(9 + math.round(value * 3), 9 + math.round(value * 3))
			end),
			Position = UDim2.fromOffset(ringCx, math.min(trackHeight - 8, ringCy + ringRy + nodeSize * 0.62)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 442,
		}),
		h("frame", {
			Name = "Core",
			Size = UDim2.fromOffset(coreSize, coreSize),
			Position = UDim2.fromOffset(ringCx, ringCy),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.void,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = 436,
		},
			h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", {
				Color = accent,
				Thickness = 2,
				Transparency = 0.1,
			}, h("uigradient", {
				Rotation = spinAngle or 0,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.35, 0.85),
					NumberSequenceKeypoint.new(0.65, 1),
					NumberSequenceKeypoint.new(1, 0.2),
				}),
			})),
			h("frame", {
				Size = UDim2.fromScale(0.74, 0.74),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Rotation = if spinAngle then props.spinProgress:map(function(value)
					return -value * 300
				end) else 0,
				ZIndex = 437,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
				Color = accent,
				Thickness = 1,
				Transparency = 0.45,
			}, h("uigradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}))),
			-- crystallised drop
			h("frame", {
				Size = props.landPop:map(function(value)
					local s = if landed then math.round(coreSize * 0.42 * math.clamp(value, 0, 1.15)) else 0
					return UDim2.fromOffset(s, s)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = props.winnerAccent,
				BorderSizePixel = 0,
				Visible = landed,
				ZIndex = 438,
			},
				h("uicorner", { CornerRadius = UDim.new(0.18, 0) }),
				h("uigradient", {
					Color = ColorSequence.new(Color3.new(1, 1, 1), props.winnerAccent),
					Transparency = NumberSequence.new(0.15, 0),
					Rotation = -45,
				})
			),
			-- shockwave when the drop locks in
			landed and h("frame", {
				Size = props.landFlash:map(function(value)
					local s = math.round(coreSize * (1 + (1 - math.clamp(value, 0, 1)) * 1.6))
					return UDim2.fromOffset(s, s)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 438,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
				Color = props.winnerAccent,
				Thickness = 2,
				Transparency = props.landFlash:map(function(value)
					return 1 - math.clamp(value, 0, 1) * 0.85
				end),
			}))
		),
		climbing and h("frame", {
			Name = "Resonance",
			Size = props.climbFlash:map(function(value)
				local reach = math.clamp((props.climbStep or 0) / math.max(1, ladderTarget), 0, 1)
				local s = math.round(coreSize * (0.5 + reach * 0.5 + math.clamp(value, 0, 1) * 0.16))
				return UDim2.fromOffset(s, s)
			end),
			Position = UDim2.fromOffset(ringCx, ringCy),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = props.climbFlash:map(function(value)
				return 0.55 - math.clamp(value, 0, 1) * 0.3
			end),
			BorderSizePixel = 0,
			ZIndex = 437,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.7, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})),
		showLadder and h("frame", {
			Name = "RarityLadder",
			Size = UDim2.fromOffset(ladderTarget * 16, 12),
			Position = UDim2.new(0.5, 0, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ZIndex = 445,
		}, (function()
			local pips = {
				layout = h("uilistlayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			local litTo = if landed then ladderTarget else props.climbStep or 0
			for index = 1, ladderTarget do
				local lit = index <= litTo
				local head = index == litTo
				pips[`pip{index}`] = h("frame", {
					LayoutOrder = index,
					Size = UDim2.fromOffset(if head then 10 else 8, if head then 10 else 8),
					Rotation = 45,
					BackgroundColor3 = if lit then props.ladderColors[index] else Palette.line,
					BackgroundTransparency = if lit then 0 else 0.4,
					BorderSizePixel = 0,
					ZIndex = 446,
				}, h("uicorner", { CornerRadius = UDim.new(0.2, 0) }))
			end
			return pips
		end)()),
		h("frame", {
			Size = UDim2.fromOffset(trackWidth, trackHeight),
			BackgroundTransparency = 1,
			ZIndex = 432,
		}, table.unpack(nodes)),
		h("frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 1, -2),
			BackgroundColor3 = Palette.line,
			BorderSizePixel = 0,
			ZIndex = 443,
		}, h("frame", {
			Size = props.spinProgress:map(function(value)
				return UDim2.new(math.clamp(value, 0, 1), 0, 1, 0)
			end),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 444,
		})),
		intro and h("frame", {
			Name = "CrateIntro",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.void,
			BackgroundTransparency = introFade,
			BorderSizePixel = 0,
			ZIndex = 444,
		},
			h("frame", {
				Size = UDim2.fromOffset(trackHeight * 0.9, trackHeight * 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.sessionAccent,
				BackgroundTransparency = React.joinBindings({ introFade, props.chargePulse }):map(function(values)
					return 1 - (1 - values[1]) * (0.1 + values[2] * 0.12)
				end),
				BorderSizePixel = 0,
				ZIndex = 445,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) })),
			h("canvasgroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = introFade,
				ZIndex = 446,
			}, h(CrateModel, {
				skin = props.skin,
				size = UDim2.fromOffset(trackHeight * 1.15, trackHeight * 1.15),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				open = if introOpen then 1 elseif props.phase == "seal" then 0.55 else 0,
				shake = if props.phase == "charge" then 1 elseif props.phase == "seal" then 0.5 elseif props.phase == "enter" then 0.3 else 0,
				yaw = -0.35,
				zoom = 0.92,
				zIndex = 447,
			})),
			not props.reducedMotion and (function()
				-- the seal fractures outward: uneven shards on a golden-angle spread so no two runs read as a clean starburst
				local shards = {}
				local reach = trackHeight * 0.95
				for index = 1, 11 do
					local angle = (index * 137.5 + 9) % 360
					local length = reach * (0.55 + ((index * 0.618) % 1) * 0.45)
					shards[`shard{index}`] = h("frame", {
						Size = props.sealFlash:map(function(value)
							local t = 1 - math.clamp(value, 0, 1)
							return UDim2.fromOffset(math.round(length * (0.15 + 0.85 * smooth(t))), if index % 3 == 0 then 3 else 2)
						end),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Rotation = angle,
						BackgroundColor3 = if index % 4 == 0 then Color3.new(1, 1, 1) else props.sessionAccent,
						BackgroundTransparency = props.sealFlash:map(function(value)
							return 1 - math.clamp(value, 0, 1) * 0.95
						end),
						BorderSizePixel = 0,
						ZIndex = 448,
					}, h("uigradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.15, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}))
				end
				shards.ring = h("frame", {
					Size = props.sealFlash:map(function(value)
						local s = math.round(trackHeight * (0.4 + (1 - math.clamp(value, 0, 1)) * 1.2))
						return UDim2.fromOffset(s, s)
					end),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ZIndex = 448,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
					Color = Color3.new(1, 1, 1),
					Thickness = 2,
					Transparency = props.sealFlash:map(function(value)
						return 1 - math.clamp(value, 0, 1) * 0.8
					end),
				}))
				return h("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 448,
				}, shards)
			end)() or nil
		)
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
			Active = props.phase == "spin" or props.phase == "climb",
			ZIndex = 401,
			Event = { Activated = function()
				if props.phase == "spin" or props.phase == "climb" then props.onQuickLand() end
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
			ascended and h(PrismAura, {
				rarity = props.winnerRarity,
				intensity = props.landPop:map(function(value)
					return math.clamp(value, 0, 1)
				end),
				corner = 16,
				thickness = 3,
				clipRays = false,
				zIndex = 411,
			}),
			h(CrateModel, {
				skin = props.skin,
				size = UDim2.fromOffset(crateSize, crateSize),
				position = UDim2.fromOffset(padding - 4, padding - 6),
				open = if landed then 1 elseif props.phase == "spin" then 0.4 else 0,
				shake = if props.phase == "charge" then 0.6 else 0,
				zoom = 0.85,
				live = not props.reducedMotion,
				zIndex = 420,
			}),
			h(Text, {
				value = props.crateName,
				size = if compact then 19 else 23,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 13,
				position = UDim2.fromOffset(nameX, padding),
				sizeConstraint = UDim2.fromOffset(math.max(1, panelWidth - nameX - padding - 100), 29),
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
				position = UDim2.fromOffset(nameX, padding + 30),
				sizeConstraint = UDim2.fromOffset(math.max(1, panelWidth - nameX - padding), 18),
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
					text = if canClaim then props.claimText else "LOCK RING",
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
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
