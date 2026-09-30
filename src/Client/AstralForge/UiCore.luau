--!nonstrict
--[=[
	UiCore: merged module suite.
	Members (23): ui, MainGame, AppShellChrome, TopBarChrome, NavChrome, WorkspaceChrome, ShellFx, effects, levelRoadmap, sanctuaryChrome, CelebrationBurst, ComboBadge, FeedbackOverlay, MobilePreviewGate, MobileShell, OfflineRewardsOverlay, PlayerlistOverlay, onboarding, AdminPrankOverlay, notifications, CreditsView, CrateRevealOverlay, CrateRevealStageSimple.

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
	if def == nil then error("UiCore: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("UiCore: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: ui   (merged from ui.luau, 4301 lines)
-- ======================================================================
__defs["ui"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local _Icon = require(script.Parent.ArtKit)("Icon")
local GAME_ICON_ASSET = _Icon.GAME_ICON_ASSET
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
-- LayoutGuardIgnore is an attribute, not a property: passing it as a React prop
-- makes the renderer try to assign a real member and throw. Deliberately stacked
-- elements (a segmented control's overlapping hit targets) opt out through this
-- ref so the guard's overlap pass leaves them alone.
local function pinLayoutGuardIgnore(instance)
	if instance ~= nil then
		instance:SetAttribute("LayoutGuardIgnore", true)
	end
end
-- Soft specular glint + sweep speed live in shimmer.luau (pure helpers).
-- Never animate oversized tip frames under AutomaticSize — Offset only.
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
	local want = enabled and not reducedMotion and not effectsPaused and shimmerScale > 0.02
	local speed = (1 / math.max(1.2, periodSeconds)) * math.clamp(0.45 + shimmerScale * 0.55, 0.45, 1)
	local phase = useClock(want, speed, 1, false)
	local scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42)
	local font = if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	local glintColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, color:Lerp(Palette.cyan, 0.22)),
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
		-- Overlay matches host via Scale inside a clipped shell; motion is
		-- UIGradient.Offset only — never an oversized tip child.
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
			Rotation = 14,
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
	-- The card's content materializes with the card: every Text and Button
	-- inside reads this presence, so labels fade in with the surface instead of
	-- popping in fully opaque over a still-fading background. Nested panels and
	-- overlays compose (the least-present one wins).
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
		Color = ColorSequence.new(Palette.cream),
		Rotation = 14,
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
	-- Interactive chrome must stay springy under antilag softMotion. Pages fold
	-- allowAmbient into reducedMotion, which was snapping every hover/press and
	-- reading as lag. motionScale already slows springs; only effectsPaused snaps.
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
	local active = not disabled
	-- One motor for the life of the control. resolvePressMotion picks the scale
	-- and tilt. Release springs back. softMotion does not snap it.
	local poseGoal = if disabled then 0 elseif pressed then -1 elseif hovered then 1 else 0
	-- Asymmetric: the press goes in almost at once (a finger expects that),
	-- and the release eases back out, so a click reads as struck, not toggled.
	local pose = useOptionalFlipperSpring(poseGoal, true, springSoft, if pressed then 1500 else 900, if pressed then 52 else 44)
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
	-- Impact flash is keyed off popTrigger so every successful activate gets a
	-- one-shot white wash — previously useFlash(0) never fired.
	-- Repeat activates reset this same motor. Scale and tilt stay on the pose spring.
	local impact = useFlash(popTrigger, softMotion, if touchChrome then 0.2 else 0.26)
	-- Phase-locked hover+idle: one DECORATIVE clock (not realtime — realtime
	-- budget is for spinners/needles; putting shimmers there starved UI and
	-- made motion feel laggy). Do NOT gate on softMotion/antilag reducedMotion:
	-- pages fold antilag into reducedMotion and that was killing every shimmer.
	-- Settings already zero shimmerScale when ButtonShimmers is off.
	local shimmerWanted = allowShimmer and shimmerScale > 0.02 and active and not effectsPaused and (idleShimmer or hovered or gamepadFocused)
	local shimmer = useClock(shimmerWanted, ShimmerMath.sweepSpeed(shimmerScale), 1, false)
	local surfaceSize = pose:map(function()
		return UDim2.fromScale(1, 1)
	end)
	local pressMotion = resolvePressMotion(motionSpec)
	local hoverGain = pressMotion.hover
	local pressDrop = pressMotion.press
	local tiltDegrees = pressMotion.tilt
	-- Pose sets the resting scale; each activation adds a small outward kick
	-- that rides the impact flash and settles with it.
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
		Audio:play(hoverCueFor(sound))
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
		shimmerLive = shimmerWanted,
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
	-- Optional; defaults true so existing call sites stay valid. useButtonChrome
	-- passes shimmerLive so softMotion/antilag unmounts instead of freezing a streak.
	local live = _param.live
	if live == nil then
		live = true
	end
	local trail = _param.trail
	-- Default trail off — dual-pass is costly when many buttons hover at once.
	-- Highlight/selected call sites can pass trail = true.
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
	-- Soft cream→cyan specular. Masked shell fills its host without layout
	-- participation (Active=false, AutomaticSize=None, ClipsDescendants).
	-- Sweep is UIGradient.Offset only — no tip frames that inflate AutomaticSize.
	local specularColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Palette.cream),
		ColorSequenceKeypoint.new(0.5, Palette.cream:Lerp(Palette.cyan, 0.28)),
		ColorSequenceKeypoint.new(1, Palette.cream),
	})
	local trailColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Palette.cream),
		ColorSequenceKeypoint.new(0.5, Palette.cream:Lerp(Palette.cyan, 0.14)),
		ColorSequenceKeypoint.new(1, Palette.cream),
	})
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
	}), -- Sheen gradient lives only on the fill shell. UIStroke always mounts on
	-- separate transparent siblings below so a leftover paint gradient can never
	-- recolor the outline / focus ring.
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
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(enabledLabelColor),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	})))), (outline or highlight) and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = offsetY:map(function(amount)
			return UDim2.new(0, 0, 0, math.round(amount))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
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
		Active = false,
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
		Active = false,
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
	-- The lead races to a new value; the fill eases after it. On a gain the
	-- bright lead segment shows energy flowing in; on a loss it reads as the
	-- chip that trails away.
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
	-- How far the lead is ahead of the fill (0 at rest): lights the head.
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
		-- The head: a point of light at the fill's edge that flares while filling.
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
	-- A liquid carrier: the leading edge reaches the new tab first and the
	-- trailing edge follows, so the pill stretches across and gathers in.
	local columnSlide = useFlipperSpring(activeColumn, reducedMotion, 1100, 48)
	local columnTrail = useFlipperSpring(activeColumn, reducedMotion, 480, 46)
	local rowSlide = useFlipperSpring(activeRow, reducedMotion, 880, 34)
	local selectionFlash = useFlash(activeIndex + 1, reducedMotion, 0.22)
	local tabSweep = useClock(reducedMotion ~= true, SHIMMER_SWEEP_SPEED, 1, false)
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
	local reactModules = require(script.Parent.ReactHosts)("reactModules")
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

-- ======================================================================
-- Module: MainGame   (merged from MainGame.luau, 2209 lines)
-- ======================================================================
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
-- Action toast copy (friendlyPlayerMessage / failureTitle / failureBody /
-- friendlyActionResponse) lives in actionCopy — Lune-tested, behavior unchanged.
local friendlyPlayerMessage = ActionCopy.friendlyPlayerMessage
local failureTitle = ActionCopy.failureTitle
local failureBody = ActionCopy.failureBody
local friendlyActionResponse = ActionCopy.friendlyActionResponse
local _AppShellChrome = __load("AppShellChrome")
local Shell = _AppShellChrome.Shell
local pausePassivePaints = _AppShellChrome.pausePassivePaints
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
	-- Dead cleanup hook from an earlier font-preloading implementation. No-op until the
	-- surrounding boot effect is rewritten, so React unmount doesn't call nil.
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
	-- Radix's toast pattern pauses auto-dismiss while the pointer is over a toast — the
	-- dismiss timer below is scheduled once per notice, so this tracks which ones are
	-- currently hovered and the timer re-checks it instead of dismissing outright.
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
	local _result_2 = state
	if _result_2 ~= nil then
		_result_2 = _result_2.Settings.ReducedMotion
	end
	local bootReducedMotion = _result_2 == true
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
	local latestSnapshot = React.useRef(-1)
	local latestRevision = React.useRef(-1)
	local lastTradeEpoch = React.useRef(-1)
	local lastSnapshotPaintAt = React.useRef(-math.huge)
	local loggedFirstSnapshot = React.useRef(false)
	local streakToastSent = React.useRef(false)
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
			return true
		end
		latestRevision.current = math.max(latestRevision.current, snapshot.Revision)
		lastSnapshotPaintAt.current = now
		dispatchStore(ClientActions.setSnapshot(snapshot))
		if not loggedFirstSnapshot.current then
			loggedFirstSnapshot.current = true
			ClientLog:once("profile-ready", "profile", `loaded world {snapshot.CurrentZone}`)
		end
		return true
	end, { dispatchStore })
	local dismissNotice = React.useCallback(function(id)
		setNotices(function(current)
			-- ▼ ReadonlyArray.filter ▼
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
			-- ▲ ReadonlyArray.filter ▲
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
		local lifetime = NoticeMath.Lifetime(notificationDurationRef.current)
		local maxNotices = NoticeMath.MaxNotices(toastDensityRef.current)
		local _exp_1 = noticesLive.current
		-- ▼ ReadonlyArray.find ▼
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
		-- ▲ ReadonlyArray.find ▲
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
			-- ▼ ReadonlyArray.findIndex ▼
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
			-- ▲ ReadonlyArray.findIndex ▲
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
				-- ▼ ReadonlyArray.find ▼
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
				-- ▲ ReadonlyArray.find ▲
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
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			_array[_length + 1] = {
				id = id,
				text = text,
				color = color,
				critical = critical,
				offset = math.random(-90, 90),
			}
			local updated = _array
			while #updated > 12 do
				table.remove(updated, 1)
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
					local found = false
					for _, pop in current do
						if pop.id == id then
							found = true
							break
						end
					end
					if not found then
						return current
					end
					local _newValue = {}
					for _, pop in current do
						if pop.id ~= id then
							table.insert(_newValue, pop)
						end
					end
					return _newValue
				end)
			end
		end)
		local _current = deferredJobs.current
		local _job = job
		_current[_job] = true
	end, {})
	-- Cosmetic-only combo mirror: `combo`/`comboMultiplier` here are never computed
	-- client-side, only copied from whichever server payload just arrived (per-tap
	-- effect/RemoteFunction data, or the decay-aware snapshot as a resync fallback).
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
			if expectedBusy then
				return nil
			end
			-- Log the server's raw error, not the player-friendly rewrite -- friendlyActionResponse
			-- already overwrote response.error above, so logging that instead of rawError meant
			-- the dev console showed the SAME friendly copy the player saw in the toast, with no
			-- way to tell what the server actually rejected without cross-referencing server logs.
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
		local progressionPurchase = action == "BuyResearch" or action == "BuyGridUpgrade" or action == "BuyAnomalyProtocol" or action == "UpgradeContinuum" or action == "UpgradeArtifact" or action == "UpgradeCrew" or action == "BuyGuildUpgrade" or action == "UpgradeItem" or action == "BuyOreUpgrade"
		local purchase = machinePurchase or progressionPurchase or action == "BuySignalOffer" or action == "BuyItemOffer"
		local reward = action == "ClaimDaily" or action == "ClaimTimedReward" or action == "ClaimQuest" or action == "ClaimAchievement" or action == "ClaimLabOrder" or action == "ClaimCommanderReward" or action == "ClaimWeeklyDirective" or action == "ClaimSeasonTier" or action == "ClaimExpedition" or action == "ClaimConvergenceReward" or action == "ClaimAnomalyDirective" or action == "ClaimAnomalyMilestone" or action == "ClaimForgePathStep"
		if purchase then
			Audio:play(if machinePurchase then "machineInstall" elseif progressionPurchase then "researchUnlock" else "purchase")
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
					-- ▼ ReadonlyArray.reduce ▼
					local _result_9 = 0
					local _callback = function(max, step)
						return math.max(max, step)
					end
					for _i = 1, #_exp_2 do
						_result_9 = _callback(_result_9, _exp_2[_i], _i - 1, _exp_2)
					end
					-- ▲ ReadonlyArray.reduce ▲
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
			Audio:play("itemLink")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Loadout updated."
			end
			addNotice("Equipped", _condition_4, "Info")
		elseif action == "EquipTitle" then
			Audio:play("itemLink")
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
			Audio:play("confirm")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Done."
			end
			addNotice("Change applied", _condition_4, "Success")
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
			Audio:play("rebirthCharge")
			local bloomJob
			bloomJob = task.delay(0.18, function()
				deferredJobs.current[bloomJob] = nil
				if appAlive.current then
					Audio:playCelebration({ "prestige", "rebirthBloom", "discovery" }, 0.09)
				end
			end)
			deferredJobs.current[bloomJob] = true
			InteractionFeedback.reward()
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
		elseif response.message ~= nil and action ~= "Overcharge" and action ~= "ActivateBoost" and action ~= "RouteLabPower" and action ~= "SetTutorialStep" and action ~= "ReplayTutorial" and action ~= "DismissRelease" and action ~= "OpenRelease" and action ~= "ReadStoryChapter" and action ~= "ReadMail" and action ~= "SetSetting" and action ~= "SetMobileLayout" and action ~= "VisitPlot" and action ~= "LeavePlot" and action ~= "SyncShop" and action ~= "GetPlayers" and action ~= "GetLeaderboard" and action ~= "GetGuildLeaderboard" and action ~= "GetTrade" and action ~= "UpdateTradeOffer" and action ~= "SetTradeReady" and action ~= "VerifyCreatorFollow" and action ~= "RedeemCode" then
			addNotice("Done", response.message, "Info")
		end
	end
	local _result_7 = state
	if _result_7 ~= nil then
		_result_7 = _result_7.Settings.ReducedMotion
	end
	local applyResponse = React.useCallback(_exp_1, { acceptState, addNotice, applyComboReadout, celebrate, dispatchStore, setVisit, _result_7 })
	local dispatch
	dispatch = React.useCallback(function(action, payload, callback)
		if payload == nil then
			payload = {}
		end
		local _payload = payload
		local value = if type(_payload) == "table" then payload else {}
		local signature = AppHelpers:actionSignature(action, value)
		local pipelined = NetworkPolicy.IsPipelined(action)
		local reject = function(message)
			local _result_8 = callback
			if _result_8 ~= nil then
				_result_8({
					ok = false,
					error = message,
				})
			end
		end
		local _action_1 = action
		if GRANT_ACTIONS[_action_1] ~= nil then
			if not isAuthed() then
				local settled = false
				whenAuthed(function()
					if settled then
						return nil
					end
					settled = true
					return dispatch(action, payload, callback)
				end)
				task.delay(4, function()
					if settled then
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
		sentAt.current[signature] = now
		-- ▼ ReadonlyMap.size ▼
		local _size = 0
		for _ in sentAt.current do
			_size += 1
		end
		-- ▲ ReadonlyMap.size ▲
		if _size > 256 then
			for key, timestamp in sentAt.current do
				if now - timestamp > 60 then
					sentAt.current[key] = nil
				end
			end
		end
		-- ▼ ReadonlyMap.size ▼
		local _size_1 = 0
		for _ in sentAt.current do
			_size_1 += 1
		end
		-- ▲ ReadonlyMap.size ▲
		if _size_1 > 384 then
			for key in sentAt.current do
				sentAt.current[key] = nil
				-- ▼ ReadonlyMap.size ▼
				local _size_2 = 0
				for _ in sentAt.current do
					_size_2 += 1
				end
				-- ▲ ReadonlyMap.size ▲
				if _size_2 <= 256 then
					break
				end
			end
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
			if requestWorker ~= nil then
				local _current_1 = requestWorkers.current
				local _requestWorker = requestWorker
				_current_1[_requestWorker] = nil
				pcall(function()
					return task.cancel(requestWorker)
				end)
				requestWorker = nil
			end
			releaseRequest()
			if not appAlive.current or not ownsControl then
				return nil
			end
			ClientLog:warnEvery(`timeout:{action}`, 8, "UI", `{action} timed out after {timeoutSeconds}s`)
			addNotice("Connection hiccup", "That action timed out. You can try it again now.", "Info", false)
			reject("That took too long. Try again.")
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
				reject("That tap didn't go through. Try again.")
				return nil
			end
			applyResponse(raw, action, callback)
		end)
		local _current_2 = requestWorkers.current
		local _requestWorker = requestWorker
		_current_2[_requestWorker] = true
	end, { addNotice, applyResponse, config.Game.Version, dispatchStore, remotes })
	useClientIntegrityProbe(dispatch)
	local _exp_2 = function()
		if state == nil or streakToastSent.current then
			return nil
		end
		if state.Daily.CanClaim == true and state.Daily.Streak >= 1 then
			streakToastSent.current = true
			local day = state.Daily.Streak
			addNotice("Daily streak", if day > 1 then `Day {day} is ready — claim it in Rewards.` else "Today’s daily is ready in Rewards.", "Special")
		end
		-- `state` is recreated on every tick (production, cash, etc.); keying off it
		-- here would re-run this effect continuously for no benefit since the actual
		-- trigger is the daily-streak flag, which changes far less often.
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
	-- Resync-only fallback: the state snapshot's `Overcharge` block already has the
	-- server's window-decay applied at read time, so on first sight of a live combo
	-- (e.g. right after a reconnect, before any fresh per-tap data has arrived) it's
	-- safe to adopt directly. Per-tap effect/RemoteFunction data always wins once it
	-- starts arriving, since it is strictly fresher than a coalesced snapshot.
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
			-- Sanctuary effects (ore, the Rift Warden, waystones) go to the bus the
			-- world controller and the sanctuary HUD listen on.
			local sanctuarySignals = require(script.Parent.SanctuaryKit)("sanctuarySignals")
			if sanctuarySignals.handles(kind) then
				sanctuarySignals.fire(kind, value)
				return nil
			end
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
				-- A new Forge Level: the server toast names the level and what it
				-- opened; this is the felt part of the moment.
				Audio:play("achievementClaim")
				InteractionFeedback.reward()
				celebrate()
			elseif kind == "AnomalyPulse" then
				Audio:play("reactor")
			elseif kind == "AnomalyReady" then
				Audio:play("reactorReady")
			elseif kind == "AnomalyStabilized" then
				Audio:play("discovery")
			elseif kind == "ItemLinked" then
				Audio:play("equip")
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
				local bridgeReady = remotes.Bridge:GetAttribute("Ready") == true
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
				-- The boot screen force-exits at 20s in production even without state, so a
				-- save that is still loading (session lock, datastore retry) renders as a
				-- dead UI unless we say something. Surface it once, then keep polling.
				if alive and attempt >= 20 and os.clock() - lastConnectNotice > 30 then
					lastConnectNotice = os.clock()
					addNotice("Still connecting", "Your save is taking longer than usual to load — if Astral Forge is open on another device or Studio session, close it.", "Info", false)
				end
				task.wait(math.min(0.2 + attempt * 0.08, 1.5))
			end
			if alive and remotes.Bridge:GetAttribute("Ready") == true then
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
				-- Every page reads directly off the single state/config payload that
				-- gated stateLoaded above — there's no separate per-page async fetch,
				-- so once the shell itself is up, every page's data is already there.
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
	local _result_28 = state
	if _result_28 ~= nil then
		_result_28 = _result_28.Settings.ViewportSpeed
	end
	local _condition_5 = _result_28
	if _condition_5 == nil then
		_condition_5 = 1
	end
	local viewportSpeed = _condition_5
	-- This runs above <AutoScale> (it builds the shellContent AutoScale then wraps), so there is
	-- no scaled ViewportScaleContext available yet here — useViewport() at this exact point would
	-- only ever hit its own raw-camera fallback (desktop: KeyboardEnabled || MouseEnabled, with no
	-- touch or screen-size check at all, always true in Roblox Studio's device emulator). Calling
	-- usesDesktopStructure() directly with the real camera size at least matches the same
	-- touch-aware logic AutoScale itself uses internally, instead of two different guesses
	-- disagreeing about the same device.
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
	local motionSettings = React.useMemo(_exp_6, { motionIntensity, _result_31, _result_32, _result_33, _result_34, _result_35, _result_36, _result_37, _result_38, textScale, viewportSpeed })
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
			_condition_9 = (function()
				return nil
			end)
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
			notices = if mobileToastsVisible and not toastsSuppressed then notices else {},
			remove = dismissNotice,
			setHovered = setNoticeHovered,
			reducedMotion = state.Settings.ReducedMotion == true,
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
			_result_41 = _object
		else
			_result_41 = nil
		end
		_attributes_1.mobileLayout = _result_41
		_condition_8 = React.createElement(React.Fragment, nil, _exp_7, React.createElement(ToastRail, _attributes_1))
	end
	local shellContent = _condition_8
	-- The domain overlays must render inside the same AutoScale layout frame as the shell.
	-- AutoScale is what publishes ViewportScaleContext, and it insets/centres its child frame
	-- (maxShellWidth clamp + safe-area insets). Rendering the overlays as siblings *outside* it
	-- left them parented to the raw full-screen frame while useViewport() fell back to raw camera
	-- pixels — so every centre-relative offset they computed was measured against a different
	-- coordinate space than the one they were actually laid out in.
	local domainContent = if state ~= nil and shellMounted then React.createElement(AutoScale, nil, if domainUi ~= nil then domainUi.render(state, dispatch, shellContent) else shellContent) else shellContent
	local _attributes = {
		prank = adminPrank,
	}
	local _result_39 = state
	if _result_39 ~= nil then
		_result_39 = _result_39.Settings.ReducedMotion
	end
	_attributes.reducedMotion = _result_39 == true
	local _exp_7 = React.createElement(HudPrankStage, _attributes, domainContent)
	local _condition_9 = adminPrank ~= nil
	if _condition_9 then
		local _attributes_1 = {
			prank = adminPrank,
		}
		local _result_40 = state
		if _result_40 ~= nil then
			_result_40 = _result_40.Settings.ReducedMotion
		end
		_attributes_1.reducedMotion = _result_40 == true
		_attributes_1.onClose = function()
			return setAdminPrank(nil)
		end
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
		local _result_40 = state
		if _result_40 ~= nil then
			_result_40 = _result_40.Settings.ReducedMotion
		end
		_attributes_1.reducedMotion = _result_40 == true
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

-- ======================================================================
-- Module: AppShellChrome   (merged from AppShellChrome.luau, 1553 lines)
-- ======================================================================
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
local setDecorativeMotionFrozen = _motion.setDecorativeMotionFrozen
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
local SplitCurtain = __load("sanctuaryChrome").SplitCurtain
local SanctuaryPresence = require(script.Parent.SanctuaryKit)("sanctuaryPresence")
local _onboarding = __load("onboarding")
local ReleaseNotesModal = _onboarding.ReleaseNotesModal
local TutorialOverlay = _onboarding.TutorialOverlay
local _clientStore = require(script.Parent.CoreKit)("clientStore")
local ClientActions = _clientStore.ClientActions
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local PlayerlistOverlay = __load("PlayerlistOverlay").PlayerlistOverlay
local MobilePreviewGate = __load("MobilePreviewGate").MobilePreviewGate
local OfflineRewardsOverlay = __load("OfflineRewardsOverlay").OfflineRewardsOverlay
local FeedbackOverlay = __load("FeedbackOverlay").FeedbackOverlay
local LevelRoadmapHost = __load("levelRoadmap").LevelRoadmapHost
local readLevelState = __load("levelRoadmap").readLevelState

local pausePassivePaints = {
	current = false,
}
local TUTORIAL_STEPS = { {
	title = "Machines earn while you play",
	goal = "See your vault",
	body = "Machines pour Flux into the vault. Collect it to get cash you can spend.",
	hint = "The big number is Flux stored right now.",
	controls = "Tap Continue  ·  Xbox: A",
	page = "Overview",
	watch = "vault",
}, {
	title = "Collect turns Flux into cash",
	goal = "Collect the vault",
	body = "Collect now. A full vault stops earning, so empty it often.",
	hint = "Tap Collect stored Flux on this page.",
	controls = "Keyboard: E   ·   Xbox: Y",
	page = "Overview",
	cta = "collect",
	ctaLabel = "Collect stored Flux",
	watch = "collect",
}, {
	title = "Buy a machine to earn more",
	goal = "Buy Stellar Core",
	body = "Buy Stellar Core in Workshop. Each level adds Flux per second.",
	hint = "If the button is grey, collect the vault first.",
	controls = "Xbox: A opens Workshop",
	page = "Workshop",
	cta = "workshop",
	ctaLabel = "Open Workshop",
	watch = "buy",
}, {
	title = "Buy several levels at once",
	goal = "Try x5 or Max",
	body = "x1 buys one level. x5 buys five. Max buys what you can afford.",
	hint = "Stay on x1 until the prices make sense.",
	controls = "Xbox: LT / RT changes the buy amount",
	page = "Workshop",
	watch = "amount",
}, {
	title = "Research stays after rebirth",
	goal = "Open Research",
	body = "Buy the lit bonuses in order. They stay when you rebirth.",
	hint = "Research opens at Level 2. The level bar at the top of the page shows your next goal.",
	controls = "Xbox: A opens Research",
	page = "Research",
	cta = "research",
	ctaLabel = "Open Research",
	watch = "research",
}, {
	title = "Rebirth trades machines for Cores",
	goal = "Read the rebirth panel",
	body = "Rebirth resets machines and pays Cores. Research stays. The next run is stronger.",
	hint = "Overview shows the Core payout before you confirm.",
	controls = "Tap Continue when you've read the panel",
	page = "Overview",
	watch = "rebirth",
}, {
	title = "Come back and collect",
	goal = "Finish the guide",
	body = "Collect, buy machines, research, rebirth. Each level you reach opens more of the forge.",
	hint = "Tap the level bar to see every level. Finishing pays a small Flux bonus; replay from Settings, then Guide.",
	controls = "Tap Finish  ·  Xbox: A",
	page = "Overview",
	watch = "finish",
} }
local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}
-- Props for the offline-earnings overlay. Built out here rather than inline:
-- AppShell sits near Luau's 200-local limit, and Studio compiles at O0 when
-- the debugger is on, where each of these temporaries would count against it.
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
		setDecorativeMotionFrozen(cinematicOpen)
		return function()
			pausePassivePaints.current = false
			setDecorativeMotionFrozen(false)
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
	local sanctuaryOpen, setSanctuaryOpen = React.useState(false)
	local riftOpen, setRiftOpen = React.useState(false)
	local sanctuaryOpenRef = React.useRef(false)
	sanctuaryOpenRef.current = sanctuaryOpen
	local blockSanctuaryRef = React.useRef(false)
	local dispatchRef = React.useRef(dispatch)
	dispatchRef.current = dispatch
	React.useEffect(function()
		if not sanctuaryOpen then
			return nil
		end
		local call = function(action, payload, callback)
			return dispatchRef.current(action, payload, callback)
		end
		local token = SanctuaryPresence.enterSoon(call, function()
			setRiftOpen(false)
			setSanctuaryOpen(false)
		end, function()
			setRiftOpen(false)
			setSanctuaryOpen(false)
		end, function()
			setRiftOpen(true)
		end)
		return function()
			setRiftOpen(false)
			SanctuaryPresence.leaveSoon(call, token)
		end
	end, { sanctuaryOpen })
	local buyAmount, setBuyAmount = React.useState(1)
	local chat = useGameChat(page == "Chat", true)
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
		-- The ScreenGui itself is CoreUISafeInsets; do not reserve the device/topbar
		-- cutout a second time inside the shell.
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
		-- Desktop secondary destinations live in the sidebar (includeSecondary). The old
		-- horizontal MoreDock row above the workspace was wasted chrome on PC/ultrawide.
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
		-- Overview already exposes Collect/Overcharge in its hero; keep the floating cluster
		-- on Workshop only so it does not cover Overview first-screen CTAs.
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
	local reducedMotion = state.Settings.ReducedMotion == true
	local antilagShell = useAntilag()
	-- Canonical softMotion antilag gate — AppShell chrome springs drop on soft tiers.
	local softMotion = reducedMotion or antilagShell.tier <= 1 or not antilagShell.allowAmbient
	reducedMotion = softMotion
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
	local activeBoostExpired, setActiveBoostExpired = React.useState(activeBoostEndsAt <= os.time())
	React.useEffect(function()
		local remaining = activeBoostEndsAt - os.time()
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
	-- The v2 mobile shell (chrome.stack) never uses the drawer/rail system at all — it has its
	-- own fixed bottom tab bar (MobileTabBar) instead. The drawer/rail below only still applies
	-- to the non-stack "touch + compact" case (e.g. a touch tablet in a window too wide to
	-- count as `stack`), which keeps its own slide-out drawer.
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
	blockSanctuaryRef.current = tutorialOpen or showRelease or crateReveal ~= nil or domainOverlayActive
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
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			setHidden(false)
			setSanctuaryOpen(function(current)
				if current then
					return false
				end
				if blockSanctuaryRef.current then
					return false
				end
				return true
			end)
			return nil
		end
		if processed or sanctuaryOpenRef.current then
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
			-- Every feature opens at a Forge Level: say which one, and the single
			-- goal that gets the player closer.
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
		local _condition_5 = state.Flags.TutorialDone
		if not _condition_5 then
			local _result_5 = tutorial
			if _result_5 ~= nil then
				_result_5 = _result_5.page
			end
			_condition_5 = _result_5 == nil
		end
		if _condition_5 then
			return nil
		end
		setHidden(false)
		setPage(if AppHelpers:navUnlocked(state, tutorial.page, tutorial.page) then tutorial.page else "Overview")
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
			-- ▼ ReadonlyArray.findIndex ▼
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
			-- ▲ ReadonlyArray.findIndex ▲
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
		-- ▼ ReadonlyArray.filter ▼
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
		-- ▲ ReadonlyArray.filter ▲
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
		setDecorativeMotionFrozen(pageAntilag.tier <= 0 or pageAntilag.hitchScore >= 0.2 or pageAntilag.quality < 0.14)
	end, { pageAntilag.hitchScore, pageAntilag.maxClocks, pageAntilag.quality, pageAntilag.tier })
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
		openSanctuary = function()
			if blockSanctuaryRef.current then
				return nil
			end
			setHidden(false)
			setSanctuaryOpen(true)
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
		_attributes.openSanctuary = function()
			if blockSanctuaryRef.current then
				return nil
			end
			setHidden(false)
			setSanctuaryOpen(true)
		end
		_condition_17 = React.createElement(TopBar, _attributes)
	end
	-- Desktop MoreDock removed: secondary nav is in the sidebar via includeSecondary.
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
	}, _exp_5, _exp_8, React.createElement(React.Fragment, nil, _condition_20, _condition_21, _exp_9, _exp_10, _exp_11, _condition_22))
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
		-- ▼ ReadonlyArray.map ▼
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
		-- ▲ ReadonlyArray.map ▲
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
		notify = function(title, body)
			return addNotice(title, body, "Info")
		end,
	})
	local _exp_18 = feedbackOpen and React.createElement(FeedbackOverlay, {
		dispatch = dispatch,
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
	}, React.createElement(React.Fragment, nil, React.createElement(SplitCurtain, {
		-- The curtain answers the press itself; `ready` (the character standing in
		-- the sanctuary) only lifts the veil behind it, so opening never waits on
		-- the server round-trip or streaming.
		open = sanctuaryOpen,
		ready = riftOpen,
		reducedMotion = reducedMotion,
		-- For the sanctuary HUD (ore chips, strikes, waystone travel).
		ore = state.Ore,
		dispatch = dispatch,
		onNavigate = function(pageId)
			setSanctuaryOpen(false)
			navigateStable(pageId)
		end,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = hideAmount,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = not arcadeBusy and crateReveal == nil,
	}, _exp_2, _exp_3, _exp_12, _exp_13, _exp_14, _condition_23, _exp_15, _exp_16, _exp_17, _exp_18, React.createElement(LevelRoadmapHost, {
		state = state,
		config = config,
		reducedMotion = reducedMotion,
	}), _condition_24, not bootChromeVisible and React.createElement(MobilePreviewGate, {
		ack = state.Settings.MobilePreviewAck,
		reducedMotion = reducedMotion,
		dispatch = dispatch,
	}))), crateReveal ~= nil and React.createElement(CrateRevealOverlay, {
		session = crateReveal,
		config = config,
		reducedMotion = reducedMotion,
		onClose = function()
			return setCrateReveal(nil)
		end,
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

-- ======================================================================
-- Module: TopBarChrome   (merged from TopBarChrome.luau, 1209 lines)
-- ======================================================================
__defs["TopBarChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _antilag = require(script.Parent.MotionKit)("antilag")
local useAntilag = _antilag.useAntilag
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
		body = "Premium dust from rebirths and rewards. Spend it on Star Grid routes.",
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — StatChip flash/springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local chipH = if tall then TapTarget else 54
	local iconSize = if tall then 32 else 28
	local valueSize = if tall then 16 else 16
	-- CHIP_TIPS kept for hover copy elsewhere; never parent tip UI under an
	-- AutomaticSize chip — Scale-width hairlines + tip AABB blew chips to ~1.3k px
	-- and shoved CORES/DUST/FPS off the left of the topbar.
	local _ = CHIP_TIPS[label]
	local valueMaxW = if tall then 84 else 96
	local chipInnerW = iconSize + 6 + valueMaxW + (if tall then 22 else 20)
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
		_attributes.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ActiveBoostIcon springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
		return endsAt - os.time() <= boost.Duration * 0.15
	end)
	React.useEffect(function()
		local threshold = boost.Duration * 0.15
		local remainingSeconds = endsAt - os.time()
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TopbarReleaseCountdown pulses drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
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
	local openSanctuary = _param.openSanctuary
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TopBar chips/pills drop springs on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local accent = AppHelpers:pageAccent(page)
	local shortRow = barHeight <= 54 and width < 980
	local micro = barHeight <= 54 and width < 620
	local stacked = barHeight > Layout.topbarHeight
	local chipWidthEstimate = if stacked then 148 elseif micro then 150 else 164
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
	-- Launch countdown is not shown on desktop or mobile. Width stays 0 so the chip
	-- is not mounted and the bar does not reserve a gap for it.
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
	local fullPerformanceW = if micro or performanceCount == 0 then 0 elseif performanceCount == 1 then (if stacked then 100 else 90) elseif stacked then 192 else 172
	local performanceGap = 10
	local playerControlGap = if shortRow then 6 else 8
	local playerControlW = if micro or stacked or width < 980 then SHELL_CHROME.topbarControl else 110
	local feedbackControlGap = if shortRow then 6 else 8
	local showFeedbackControl = not (stacked and width < 360)
	local feedbackControlW = if not showFeedbackControl then 0 elseif micro or stacked or width < 1480 then SHELL_CHROME.topbarControl else 116
	local sanctuaryGap = if openSanctuary ~= nil then (if shortRow then 6 else 8) else 0
	local sanctuaryW = if openSanctuary ~= nil then SHELL_CHROME.topbarControl else 0
	local controlsW = sanctuaryW + sanctuaryGap + SHELL_CHROME.topbarControl + playerControlGap + playerControlW + (if showFeedbackControl then feedbackControlGap + feedbackControlW else 0)
	local fixedSingleRow = edgePad * 2 + (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) + controlsW + 12 + (if visitPillWidth > 0 then visitPillWidth + 6 else 0) + (if countdownW > 0 then countdownW + 10 else 0)
	local minimumResourceRoom = if #allChips > 0 then chipWidthEstimate + 6 else 0
	local performanceW = if not stacked and fullPerformanceW > 0 and width - fixedSingleRow - fullPerformanceW - performanceGap < minimumResourceRoom then 0 else fullPerformanceW
	local spare = if stacked then width - edgePad * 2 - 24 - performanceW - performanceGap else width - edgePad * 2 - (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) - (if pageTitleW > 0 then pageTitleW + 10 else 0) - controlsW - 12 - (if visitPillWidth > 0 then visitPillWidth + 6 else 0) - performanceW - performanceGap - (if countdownW > 0 then countdownW + 10 else 0)
	local fitCount = if stacked then math.clamp(math.floor((spare + 6) / (chipWidthEstimate + 6)), 1, math.min(2, #allChips)) else math.clamp(math.floor((spare + 6) / (chipWidthEstimate + 6)), 0, #allChips)
	local chips = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(chip, index)
		if index >= #allChips - fitCount then
			local _chip = chip
			table.insert(chips, _chip)
		end
	end
	for _k, _v in allChips do
		_callback(_v, _k - 1, allChips)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local controlsRight = edgePad + 4
	local hasRightCluster = not stacked and (#chips > 0 or visitPill ~= nil or performanceW > 0)
	local row1H = if stacked then 62 else barHeight
	local logoMark = if micro then 40 else SHELL_CHROME.topbarControl
	local logoH = logoMark
	local controlY = math.floor((row1H - SHELL_CHROME.topbarControl) / 2)
	local logoY = controlY + math.floor((SHELL_CHROME.topbarControl - logoMark) / 2)
	local chipRowH = if stacked then TapTarget else 50
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
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
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
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
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
		-- ▲ ReadonlyArray.map ▲
		_condition_3 = React.createElement("frame", {
			Size = UDim2.fromOffset(0, chipRowH + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(controlsW + controlsRight + 12), 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = false,
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
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
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
		-- ▲ ReadonlyArray.map ▲
		_condition_4 = React.createElement("frame", {
			Size = UDim2.new(1, -(24 + (if performanceW > 0 then performanceW + performanceGap else 0)), 0, TapTarget + 6),
			Position = UDim2.fromOffset(12, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = false,
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
	})), openSanctuary ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(sanctuaryW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW + (if showFeedbackControl then feedbackControlGap + feedbackControlW else 0) + sanctuaryGap + sanctuaryW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = "Forge",
		onClick = openSanctuary,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		motion = resolvePressMotion({
			text = "",
			icon = "Forge",
			size = UDim2.fromOffset(sanctuaryW, SHELL_CHROME.topbarControl),
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

-- ======================================================================
-- Module: NavChrome   (merged from NavChrome.luau, 1321 lines)
-- ======================================================================
__defs["NavChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — RailButton springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
		position = UDim2.fromOffset(56, if rowHeight <= 54 then 4 else 10),
		sizeConstraint = UDim2.new(1, -66, 0, if rowHeight <= 54 then 18 else 22),
	}), not collapsed and React.createElement(Text, {
		value = entry.eyebrow,
		size = 12,
		color = eyebrowColor,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(56, if rowHeight <= 54 then 22 else 34),
		sizeConstraint = UDim2.new(1, -66, 0, if rowHeight <= 54 then 14 else 18),
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreDockButton springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- On the desktop row, idle buttons carry no card surface at all -- with 20+ of these in one
	-- strip, giving every one its own border/fill turned the dock into a wall of identical boxes.
	-- Only the active page or whatever the pointer is currently over gets a card; everything else
	-- sits flat on the dock's own background, so the row reads as one toolbar with a highlight
	-- instead of a row of tiles. The mobile "More" sheet (fill=true) is a small deliberate grid,
	-- not a crowded strip, so it keeps a visible card on every cell -- that's what makes each
	-- touch target legible there.
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
	-- Idle rows on the desktop strip keep a mostly-transparent icon tile so 20+ buttons in one row
	-- don't read as a wall of solid squares; hovering or being the active page fills the tile back
	-- in, which is what actually needs to draw the eye. The mobile grid keeps its icon tile solid.
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
-- Desktop equivalent of the mobile MoreSheet: a small grid popover anchored below the dock,
-- opened from a "MORE" trigger instead of always occupying screen width. Rendered through the
-- shared dropdown portal (a top-level ScreenGui) rather than nested under the dock's own frame,
-- since the dock's ancestor shell clips descendants to its own small strip -- anything drawn
-- inside that tree past the dock's bounds would be invisible. Closes on picking a page, Escape,
-- or clicking anywhere outside the panel.
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreDockPopover motion drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreCell springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreDock motion drops on soft tiers.
	local softMotion = (_param.reducedMotion or false) or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- These hooks back the desktop-only MORE popover, but must still run unconditionally on
	-- every render (including the mobile `stack` branch below) -- React requires the same
	-- hooks in the same order on every call, regardless of which branch's JSX gets returned.
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
		-- ▼ ReadonlyArray.map ▼
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
		-- ▲ ReadonlyArray.map ▲
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
	-- Only as many entries as comfortably fit get a permanent slot on the bar; the rest live
	-- behind a "MORE" trigger opened on demand (MoreDockPopover), same idea as the mobile tab
	-- bar's overflow sheet. One slot is reserved for the trigger whenever there's overflow.
	local visibleCount = math.clamp(math.floor((viewport.width - 32) / (MORE_BTN_W + 4)), 1, 7)
	local needsMore = #more > visibleCount
	local primaryCount = if needsMore then math.max(1, visibleCount - 1) else visibleCount
	local primary = {}
	local overflow = {}
	-- ▼ ReadonlyArray.forEach ▼
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
	-- ▲ ReadonlyArray.forEach ▲
	-- Keep the active page visible on the bar even if it would otherwise land in overflow --
	-- swap it in for the last primary slot (and move the displaced entry into overflow) so the
	-- current page is never hidden behind the MORE trigger.
	-- ▼ ReadonlyArray.find ▼
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
	-- ▲ ReadonlyArray.find ▲
	local activeInOverflow = _result
	if activeInOverflow ~= nil and #primary > 0 then
		local displaced = primary[#primary]
		primary[#primary] = activeInOverflow
		-- ▼ ReadonlyArray.filter ▼
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
		-- ▲ ReadonlyArray.filter ▲
		overflow = _newValue
		if displaced ~= nil then
			table.insert(overflow, 1, displaced)
		end
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_2 = function(sum, entry)
		return sum + AppHelpers:navBadge(entry, state, chatUnread)
	end
	for _i = 1, #overflow do
		_result_1 = _callback_2(_result_1, overflow[_i], _i - 1, overflow)
	end
	-- ▲ ReadonlyArray.reduce ▲
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
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — Navigation rail motion drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local railNavHostRef = React.useRef(nil)
	-- Gamepad: park Selection on sidebar rail (FocusClaim prefers Claim-named hosts).
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
	local showSecondarySection = includeSecondary and not fromMore and #secondaryEntries > 0 and not collapsed
	local sectionH = if showSecondarySection then 22 else 0
	local railCount = if fromMore then #secondaryEntries else (#primaryEntries + #secondaryEntries)
	local canvasHeight = math.max(1, railCount) * (rowHeight + chrome.railGap) - chrome.railGap + Layout.stackGap * 2 + sectionH
	local headerHeight = 12
	local showBoost = activeBoost ~= nil and not chrome.mobile and page ~= "Rewards" and wallClock ~= nil and openBoosts ~= nil
	local boostHeight = if showBoost then (if collapsed then 62 else 64) else 0
	local boostReserve = if showBoost then boostHeight + SHELL_CHROME.railGutter * 2 else 0
	local railScrollRef = React.useRef(nil)
	local railCropRef = React.useRef(0)
	local railCrop, setRailCrop = React.useState(0)
	local primaryCount = #primaryEntries
	local railChromeTop = headerHeight + SHELL_CHROME.railGutter + boostReserve
	React.useEffect(function()
		local scroll = railScrollRef.current
		if scroll == nil then
			return nil
		end
		local host = scroll.Parent
		if host == nil or not host:IsA("GuiObject") then
			return nil
		end
		local function fit()
			if collapsed or not showSecondarySection then
				if railCropRef.current ~= 0 then
					railCropRef.current = 0
					setRailCrop(0)
				end
				return nil
			end
			local stride = rowHeight + chrome.railGap
			local secondaryTop = primaryCount * stride + sectionH + chrome.railGap
			-- Measure the rail, not the scroller. Cropping the scroller used to
			-- change its AbsoluteSize and schedule another crop.
			local windowH = host.AbsoluteSize.Y - railChromeTop
			local sliver = windowH - secondaryTop
			local next = if sliver > 2 and sliver < rowHeight - 2 then math.floor(sliver) else 0
			if next ~= railCropRef.current then
				railCropRef.current = next
				setRailCrop(next)
			end
		end
		fit()
		local conn = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		return function()
			conn:Disconnect()
		end
	end, { chrome.railGap, collapsed, primaryCount, railChromeTop, rowHeight, sectionH, showSecondarySection })
	local stride = rowHeight + chrome.railGap
	local selectionTop = 0
	local selectionVisible = false
	local function locateSelection(entries, top)
		local y = top
		for _, entry in entries do
			if page == entry.id then
				selectionTop = y
				selectionVisible = true
			end
			y += stride
		end
		return y
	end
	local scanY = 0
	if fromMore then
		locateSelection(secondaryEntries, 0)
	else
		scanY = locateSelection(primaryEntries, 0)
		if showSecondarySection then
			scanY += sectionH + chrome.railGap
		end
		if includeSecondary then
			locateSelection(secondaryEntries, scanY)
		end
	end
	local heldSelection = React.useRef(0)
	if selectionVisible then
		heldSelection.current = selectionTop
	end
	-- A liquid pill: its leading edge chases the new row on a fast spring while
	-- the trailing edge follows on a slower one, so it stretches toward where
	-- you clicked and gathers itself as it lands.
	local selectionLead = useFlipperSpring(heldSelection.current, reducedMotion, 720, 48)
	local selectionTrail = useFlipperSpring(heldSelection.current, reducedMotion, 300, 46)
	local selectionSpan = React.joinBindings({ selectionLead, selectionTrail })
	local selectionAccent = AppHelpers:pageAccent(page)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.5),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = strokeGradient(Palette.lineSoft),
	}))
	local _exp_3 = nil
	local _exp_4 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, chrome.railGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local railChildren = {}
	local appendRail = function(entries, orderBase)
		local _callback = function(entry, index)
			table.insert(railChildren, React.createElement(RailButton, {
				key = entry.id,
				entry = entry,
				active = page == entry.id,
				collapsed = collapsed,
				onClick = function()
					return setPage(entry.id)
				end,
				layoutOrder = orderBase + index,
				reducedMotion = reducedMotion,
				rowHeight = rowHeight,
				bodySize = chrome.bodyText,
				badge = AppHelpers:navBadge(entry, state, chatUnread),
			}))
		end
		for _k, _v in entries do
			_callback(_v, _k - 1, entries)
		end
		return orderBase + #entries
	end
	local layoutCursor = 0
	if fromMore then
		appendRail(secondaryEntries, 0)
	else
		layoutCursor = appendRail(primaryEntries, 0)
		if showSecondarySection then
			table.insert(railChildren, React.createElement("frame", {
				key = "nav-more-section",
				Size = UDim2.new(1, 0, 0, sectionH),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = layoutCursor,
			}, React.createElement(Text, {
				value = "MORE",
				size = 9,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(8, 4),
				sizeConstraint = UDim2.new(1, -12, 1, -4),
			})))
			layoutCursor += 1
		end
		if includeSecondary then
			appendRail(secondaryEntries, layoutCursor)
		end
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
		-- FocusClaim rail nav must not clip CTA overshoot.
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("scrollingframe", {
		ref = railScrollRef,
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2 + 4), 1, -(headerHeight + SHELL_CHROME.railGutter + boostReserve + railCrop)),
		Position = UDim2.fromOffset(SHELL_CHROME.railGutter, headerHeight),
		CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
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
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, canvasHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, selectionVisible and React.createElement("frame", {
		Size = selectionSpan:map(function(values)
			local stretch = math.abs(values[1] - values[2])
			return UDim2.new(1, -4, 0, math.max(8, rowHeight - 4) + math.round(stretch))
		end),
		Position = selectionSpan:map(function(values)
			return UDim2.fromOffset(2, math.round(math.min(values[1], values[2])) + 2)
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
	}))), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, _exp_4, railChildren))), showBoost and React.createElement("frame", {
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

-- ======================================================================
-- Module: WorkspaceChrome   (merged from WorkspaceChrome.luau, 565 lines)
-- ======================================================================
__defs["WorkspaceChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.MotionKit)("motion")
local EntranceMotionSuppressedContext = _motion.EntranceMotionSuppressedContext
local useFlash = _motion.useFlash
local useTokenEntrance = _motion.useTokenEntrance
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
	-- This number updates on every production tick for the whole session, so it can't afford a
	-- continuously-running tween -- instead, a brief flash on genuine gains via useFlash (a
	-- short spring that settles and goes idle) gives it a felt reaction without any per-tick
	-- motor cost between updates.
	local gains, setGains = React.useState(0)
	local previousVault = React.useRef(state.Vault)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — VaultPill flash drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
-- The level bar: the player's Forge Level, the one goal that levels them up,
-- and what that level opens -- one calm line under every page title. Type
-- carries the hierarchy (level and goal in cream, the rest muted); the tier
-- colour only fills the progress hairline along the bottom. Tapping anywhere
-- on it opens the full level roadmap.
local function NextUnlockStrip(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local onOpen = _param.onOpen
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — NextUnlockStrip motion drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
		-- A barely-there lift on hover says "this opens something".
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
		-- Hairline between who you are and what's next.
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
		value = `{compactNumber(nextStep.Progress)} / {compactNumber(nextStep.Target)}`,
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
		-- Progress to the next level: a hairline across the whole bar.
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1),
		BackgroundColor3 = accent,
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — Workspace entrance drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- The whole page arrives as one piece: its text and buttons follow the
	-- page's entrance (cards inside layer their own on top).
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
	-- Gamepad: park Selection on Workspace COLLECT (FocusClaim prefers Claim-named hosts).
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
	local contentPosition = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		local lift = math.round((1 - t) * 12)
		return UDim2.new(0, inset, 0, headerHeight + unlockH + inset + lift)
	end)
	local revealFade = enter:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local contentFade = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		return (1 - t) * 0.4
	end)
	local titleLeft = if keyboardCompact then 54 elseif chrome.stack then 66 else 84
	-- Desktop reserves room for the right-side VaultPill (248px wide, anchored at -316): the
	-- title block must stop before it. -392 used to run 8px into the pill; -344 keeps a 6px
	-- clearance on every desktop width.
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
		value = if entry.label == "Games" then "Mini Games" elseif entry.label == "Ranks" then "Leaderboards" else entry.label,
		size = if chrome.stack then chrome.titleText elseif denseHeader then 20 else 24,
		color = ensureContrast(Palette.panel, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = false,
		minSize = 14,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 6), 0, if chrome.landscape then 4 else 2)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.landscape then 22 elseif chrome.stack then 24 elseif denseHeader then 22 else 28),
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
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 10), 0, if chrome.stack then 28 elseif denseHeader then 26 else 32)
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
		-- FocusClaim COLLECT must not clip CTA overshoot.
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
	}, children)), React.createElement(ScrollEdgeFade, {
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

-- ======================================================================
-- Module: ShellFx   (merged from ShellFx.luau, 311 lines)
-- ======================================================================
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

-- Confetti: paper pieces, generated once. Each is thrown from one of two
-- cannons under the reward, slowed hard by the air, and left to flutter down.
local CONFETTI_COLORS = { Palette.green, Palette.cyan, Palette.mango, Palette.pink, Palette.violet, Palette.cream }
local CONFETTI_COUNT = 44
local CONFETTI_PIECES = {}
for index = 1, CONFETTI_COUNT do
	local side = if index % 2 == 0 then -1 else 1
	CONFETTI_PIECES[index] = {
		side = side,
		-- Up and a little inward from each cannon.
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TradeReturnPill springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local pulse = usePulse(true, 1.35)
	local width = if stack then 176 else 198
	local height = if stack then 48 else 46
	local tradeReturnHostRef = React.useRef(nil)
	-- Gamepad: park Selection on BACK TO TRADE (FocusClaim prefers Claim-named hosts).
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
		-- FocusClaim BACK TO TRADE must not clip CTA overshoot.
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
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AmbientLayer clocks drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local strength = math.clamp(intensity, 0, 1)
	local enabled = not reducedMotion and antilag.allowAmbient and strength > 0.02
	local slow = useClock(enabled, 0.17)
	local breath = useClock(enabled, 0.09)
	local orbA = slow:map(function(phase)
		return UDim2.new(0, 130 + math.sin(phase) * 30, 0, 108 + math.cos(phase) * 20)
	end)
	local orbScale = breath:map(function(phase)
		return 1 + math.sin(phase) * 0.12 * antilag.glowScale * strength
	end)
	if not enabled then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(240, 240),
		Position = orbA,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1 - 0.03 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = orbScale,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function ConfettiBurst(_param)
	local onDone = _param.onDone
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ConfettiBurst skips particle clocks on soft tiers.
	local softMotion = antilag.tier <= 1 or not antilag.allowAmbient
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
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(piece, index)
		if index < activeCount then
			local _piece = piece
			table.insert(pieces, _piece)
		end
	end
	for _k, _v in CONFETTI_PIECES do
		_callback(_v, _k - 1, CONFETTI_PIECES)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local _exp = { 0, 1 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp)
	local _callback_1 = function(ring)
		return React.createElement("frame", {
			key = `confetti-ring-{ring}`,
			Size = clock:map(function(seconds)
				-- Bursts out fast and slows, like the forge's shock rings.
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
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#pieces)
	local _callback_2 = function(piece, index)
		local origin = UDim2.fromScale(0.5 + piece.side * 0.12, 0.66)
		local function age(seconds: number): number
			return math.max(0, seconds - piece.delay)
		end
		-- How face-on the paper is as it tumbles (0 = edge-on, 1 = flat).
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
				-- Flutter grows as the paper slows and starts to fall.
				local flutter = math.sin(t * 2.6 + piece.phase) * piece.sway * math.clamp(t / 0.6, 0, 1)
				return origin + UDim2.fromOffset(dx + flutter, dy)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = clock:map(function(seconds)
				local t = age(seconds)
				return math.deg(piece.phase) + t * (if index % 2 == 0 then 210 else -190) + math.sin(t * 3 + piece.phase) * 18
			end),
			-- Paper catches the light when it turns face-on.
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
	-- ▲ ReadonlyArray.map ▲
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

-- ======================================================================
-- Module: effects   (merged from effects.luau, 299 lines)
-- ======================================================================
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
		-- ▼ ReadonlyArray.filter ▼
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
		-- ▲ ReadonlyArray.filter ▲
		_result = _newValue
	else
		_result = pops
	end
	local visible = _result
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
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
	-- Only iterate the live prefix — building #STARS nil slots every render was
	-- free work on every antilag context push.
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

-- ======================================================================
-- Module: levelRoadmap   (merged from levelRoadmap.luau, 643 lines)
-- ======================================================================
__defs["levelRoadmap"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
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
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber

-- The Forge Level roadmap: the whole progression ladder on one screen, laid
-- out as a timeline. A rail runs down the left edge and fills up to the
-- player's level; each level is one quiet row -- its goal, and what it opens.
--
-- Visual rules (kept deliberately plain):
--   * Type does the work: goal text is the primary line, everything else is
--     secondary and muted. No pills, badges, icons, glows or outlines.
--   * The tier colour appears in exactly three places: the tier name, the
--     player's own node on the rail, and progress fills.
--   * One spacing unit (4px) and one left edge for all text.
--
-- The ladder comes from ForgeLevels (shared, via config.Levels); the player's
-- level and next-goal progress come from the server snapshot (state.Level).

local UNIT = 4
local ROW_H = 54
local TIER_H = 44
local RAIL_X = 14
local TEXT_X = 40

-- The ladder warms as it climbs.
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

-- Display names for feature ids, from the live unlock states.
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

-- "Missions, Leaderboards and Guild".
local function joinNames(names)
	local count = #names
	if count == 0 then
		return ""
	elseif count == 1 then
		return names[1]
	end
	return table.concat(names, ", ", 1, count - 1) .. " and " .. names[count]
end

-- The player's level state, tolerant of a snapshot from before levels existed.
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

-- A thin progress track: a hairline of the line colour with the filled part in
-- the tier colour. Used in the header and on the next level's row.
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

-- The node where a row meets the rail.
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
	local state = _param.state
	local config = _param.config
	local onClose = _param.onClose
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — LevelRoadmap.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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

	-- Lay the ladder out top to bottom, a heading at the start of each tier.
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
	-- The rail: the whole ladder in the line colour, filled to the player's node.
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

	-- Open scrolled to the player's own level, with a little of what's behind.
	local listRef = React.useRef(nil)
	React.useEffect(function()
		local list = listRef.current
		if list == nil then
			return nil
		end
		list.CanvasPosition = Vector2.new(0, math.max(0, math.min(focusY - TIER_H, canvasH - listH)))
		return nil
	end, {})

	local cardPosition = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * 12))
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
		-- Scrim: tapping outside the card closes the roadmap.
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
		-- Hairline between the header and the ladder.
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

-- Open state lives here rather than in the app shell. The shell's main
-- component sits near Luau's 200-local limit (Studio compiles at O0 when the
-- debugger is on, where every local counts), and the level bar that opens the
-- roadmap lives deep inside the workspace. A tiny store both sides can reach
-- keeps the shell at zero new locals and avoids threading a prop through.
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

-- Mounted once by the app shell; renders the roadmap while it is open.
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

-- ======================================================================
-- Module: sanctuaryChrome   (merged from sanctuaryChrome.luau, 659 lines)
-- ======================================================================
__defs["sanctuaryChrome"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local createFlipperMotor = require(script.Parent.MotionKit)("motion").createFlipperMotor
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local useClientSelector = require(script.Parent.CoreKit)("clientStore").useClientSelector
local Text = __load("ui").Text
local Palette = require(script.Parent.CoreKit)("theme").Palette
local surfaceGradient = require(script.Parent.CoreKit)("theme").surfaceGradient
local Curtain = require(script.Parent.SanctuaryKit)("curtainTransition")
local HudPlan = require(script.Parent.SanctuaryKit)("sanctuaryHudPlan")
local SanctuaryHud = require(script.Parent.SanctuaryKit)("sanctuaryHud").SanctuaryHud

-- The parting edge of each half: a hairline rim and a soft inward shadow.
local RIM_WIDTH = 2
local EDGE_SHADOW_WIDTH = 36

local LEFT_DOCK = {
	{ key = "Overview", pageId = "Overview", label = "Overview", icon = "Overview" },
	{ key = "Workshop", pageId = "Workshop", label = "Workshop", icon = "Forge" },
	{ key = "StarGrid", pageId = "StarGrid", label = "Star Grid", icon = "StarGrid" },
	{ key = "Continuum", pageId = "Continuum", label = "Next Rank", icon = "Continuum" },
	{ key = "Missions", pageId = "Missions", label = "Missions", icon = "Mission" },
	{ key = "Foundry", pageId = "Foundry", label = "Foundry", icon = "Artifact" },
}

local RIGHT_DOCK = {
	{ key = "Shop", pageId = "Shop", label = "Shop", icon = "Shop" },
	{ key = "Rewards", pageId = "Rewards", label = "Rewards", icon = "Crate" },
	{ key = "Boosts", pageId = "Boosts", label = "Boosts", icon = "Boost" },
	{ key = "Guild", pageId = "Guild", label = "Guild", icon = "Crew" },
	{ key = "Leaderboards", pageId = "Leaderboards", label = "Ranks", icon = "Leaderboard" },
	{ key = "Settings", pageId = "Settings", label = "Settings", icon = "Settings" },
}

-- Every destination, for the menu sheet that replaces the docks on small and
-- touch screens.
local ALL_DOCK = table.clone(LEFT_DOCK)
for _, entry in RIGHT_DOCK do
	table.insert(ALL_DOCK, entry)
end

local function muteClone(root)
	pcall(function()
		root.Interactable = false
	end)
	if root:IsA("GuiObject") then
		root.Active = false
	end
	if root:IsA("GuiButton") then
		root.Selectable = false
		root.AutoButtonColor = false
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.Active = false
			pcall(function()
				descendant.Interactable = false
			end)
		end
		if descendant:IsA("GuiButton") then
			descendant.Selectable = false
			descendant.AutoButtonColor = false
		end
	end
end

-- Square icon tiles lean a little. A two-word or long caption fills the tile, so it only scales.
local function dockTiltDegrees(label, side)
	local textLabel = string.find(label, " ", 1, true) ~= nil or #label >= 8
	if textLabel then
		return 0
	end
	local span = math.clamp(1 - (#label - 4) * 0.18, 0.4, 1)
	local sign = if side == "left" then -1 else 1
	return sign * span
end

local function settingsReduced(state)
	local settings = state.Settings
	return settings ~= nil and settings.ReducedMotion == true
end

-- One motor for the life of the component. Nothing retargets it except a new goal.
local function useHeldSpring(initial, stiffness, damping)
	local binding, setBinding = React.useBinding(initial)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local motor = React.useRef(nil)
	if motor.current == nil then
		motor.current = createFlipperMotor(initial, stiffness, damping)
	end
	React.useEffect(function()
		local active = motor.current
		if active == nil then
			return nil
		end
		local disconnect = active:onChange(function(value)
			setBindingRef.current(value)
		end)
		return function()
			disconnect()
			active:destroy()
			if motor.current == active then
				motor.current = nil
			end
		end
	end, {})
	return binding, motor
end

local function DockButton(props)
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local hoveredRef = React.useRef(false)
	local strictReduced = useClientSelector(settingsReduced)
	local strictReducedRef = React.useRef(strictReduced)
	strictReducedRef.current = strictReduced
	local scaleGoal = if pressed then 0.93 elseif hovered then 1.04 else 1
	local tiltGoal = if hovered and not pressed then dockTiltDegrees(props.entry.label, props.side) else 0
	local scaleSpring, scaleMotor = useHeldSpring(1, 720, 42)
	local tilt, tiltMotor = useHeldSpring(0, 640, 40)
	local reveal, revealMotor = useHeldSpring(0, 920, 44)
	React.useEffect(function()
		local active = scaleMotor.current
		if active ~= nil then
			active:setGoal(scaleGoal)
		end
	end, { scaleGoal })
	React.useEffect(function()
		local active = tiltMotor.current
		if active ~= nil then
			active:setGoal(tiltGoal)
		end
	end, { tiltGoal })
	React.useEffect(function()
		local active = revealMotor.current
		if active == nil then
			return nil
		end
		local step = if strictReducedRef.current then 0.012 else 0.025
		local delay = math.min(math.max(props.index, 0), 8) * step
		task.delay(delay, function()
			if active:alive() then
				active:setGoal(1)
			end
		end)
		return nil
	end, {})
	local position = reveal:map(function(amount)
		local shift = (1 - math.clamp(amount, 0, 1)) * (props.button + 22)
		local x = if props.side == "left" then -shift else shift
		return UDim2.new(0.5, x, 0.5, 0)
	end)
	local size = React.joinBindings({
		scale = scaleSpring,
		reveal = reveal,
	}):map(function(values)
		local shown = 0.92 + 0.08 * math.clamp(values.reveal, 0, 1)
		local scale = values.scale * shown
		return UDim2.fromScale(scale, scale)
	end)
	local markHover = function()
		if hoveredRef.current then
			return nil
		end
		hoveredRef.current = true
		setHovered(true)
		Audio:play("sanctuaryHover")
	end
	local clearHover = function()
		hoveredRef.current = false
		setHovered(false)
		setPressed(false)
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(props.button, props.button),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.index,
		ClipsDescendants = false,
		ZIndex = 8,
	}, React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Rotation = tilt,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.16,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		ZIndex = 8,
		Event = {
			Activated = function()
				Audio:play("sanctuaryClick")
				props.onNavigate(props.entry.pageId)
			end,
			MouseEnter = function()
				markHover()
			end,
			MouseLeave = function()
				clearHover()
			end,
			SelectionGained = function()
				markHover()
			end,
			SelectionLost = function()
				clearHover()
			end,
			InputBegan = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setPressed(true)
				end
			end,
			InputEnded = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setPressed(false)
				end
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.ink, 0.85),
		Rotation = 95,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.white,
		Thickness = 1.25,
		Transparency = 0.08,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.cyan),
			ColorSequenceKeypoint.new(1, Palette.mint),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.55, 0.32),
			NumberSequenceKeypoint.new(1, 0.62),
		}),
	})), React.createElement("frame", {
		Size = UDim2.new(1, -10, 0, 1),
		Position = UDim2.fromOffset(5, 1),
		BackgroundColor3 = Palette.cyan,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 2,
	}), React.createElement(Icon, {
		kind = props.entry.icon,
		size = math.clamp(props.button - 30, 16, 26),
		color = Palette.cream,
		spin = false,
		position = UDim2.new(0.5, 0, 0, 6),
		anchorPoint = Vector2.new(0.5, 0),
	}), React.createElement(Text, {
		value = props.entry.label,
		size = 11,
		minSize = 8,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = true,
		position = UDim2.new(0, 4, 1, -16),
		sizeConstraint = UDim2.new(1, -8, 0, 14),
		zIndex = 3,
	}))))
end

-- One dock column, placed by the HUD plan (sanctuaryHudPlan) so it never
-- meets the Warden bar, the ore chips or the strike button.
local function DockColumn(props)
	local rect = props.rect
	local buttons = {
		Layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, props.gap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}
	for index, entry in props.entries do
		buttons[entry.key] = React.createElement(DockButton, {
			key = entry.key,
			entry = entry,
			button = props.button,
			index = index - 1,
			side = props.side,
			onNavigate = props.onNavigate,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(rect.w, rect.h),
		Position = UDim2.fromOffset(rect.x, rect.y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ClipsDescendants = false,
		ZIndex = 40,
	}, buttons)
end

-- The parting edge of one half: a hairline of light on the edge itself and a
-- soft shadow falling inward, so each half reads as a panel with thickness
-- rather than a flat cut. `side` is the side of the half the edge sits on.
local function PartingEdge(props)
	local onRight = props.side == "right"
	local anchor = Vector2.new(if onRight then 1 else 0, 0)
	local position = UDim2.fromScale(if onRight then 1 else 0, 0)
	return React.createElement(React.Fragment, nil, React.createElement("frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.new(0, EDGE_SHADOW_WIDTH, 1, 0),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 6,
	}, React.createElement("uigradient", {
		-- Darkest at the edge, gone a few dozen pixels in.
		Rotation = if onRight then 0 else 180,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})), React.createElement("frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.new(0, RIM_WIDTH, 1, 0),
		BackgroundColor3 = Palette.creamSoft,
		BackgroundTransparency = props.rimTransparency,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 7,
	}, React.createElement("uigradient", {
		-- The rim fades out toward the top and bottom instead of ending hard.
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0.2),
			NumberSequenceKeypoint.new(0.82, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})))
end

-- Dims a half as it swings away.
local function HalfShade(props)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = props.transparency,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 5,
	})
end

-- The dark behind the curtain. It hides the world while the sanctuary loads,
-- so the server round-trip and the camera move into the rift are never seen,
-- then fades once the sanctuary is ready. Deliberately plain: no text, no
-- decoration, nothing that could read as something left behind.
local function RiftVeil(props)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = props.veil:map(Curtain.veilTransparency),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.void),
			ColorSequenceKeypoint.new(0.5, Palette.night),
			ColorSequenceKeypoint.new(1, Palette.void),
		}),
	}))
end

-- Drives the curtain's travel toward `open` on RenderStepped. The clock starts
-- on the first frame after the change is committed, so any one-off work in
-- that commit (the right-half snapshot) delays the start by a frame instead of
-- showing up as a jump. A change of direction mid-run starts from wherever the
-- halves are.
local function useCurtainTravel(open: boolean, reduced: boolean, onSettled: (number) -> ())
	local travel, setTravel = React.useBinding(0)
	local current = React.useRef(0)
	local settledRef = React.useRef(onSettled)
	settledRef.current = onSettled
	React.useLayoutEffect(function()
		local target = if open then 1 else 0
		local from = current.current
		local distance = math.abs(target - from)
		if distance < 1e-4 then
			current.current = target
			setTravel(target)
			settledRef.current(target)
			return nil
		end
		local seconds = Curtain.duration(open, distance, reduced)
		-- The run's own clock: starts on the first frame after the commit and
		-- advances by each frame's (capped) delta, so a slow frame never leaps.
		local elapsed: number? = nil
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(dt: number)
			elapsed = if elapsed == nil then 0 else Curtain.advance(elapsed :: number, dt)
			local value = Curtain.sample(from, target, elapsed :: number, seconds)
			current.current = value
			setTravel(value)
			if (elapsed :: number) >= seconds then
				if connection ~= nil then
					connection:Disconnect()
					connection = nil
				end
				current.current = target
				setTravel(target)
				settledRef.current(target)
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
		end
	end, { open })
	return travel, current
end

-- The rift opens like a stage curtain: the shell splits down the middle and
-- the two halves slide off opposite edges, revealing the sanctuary. The
-- halves move on the frame after the rift is requested -- nothing waits on
-- the server. The veil behind them covers the world until the sanctuary is
-- ready (`ready`), then fades. Closing brings the halves back together.
local function SplitCurtain(props)
	local open = props.open == true
	local ready = props.ready == true
	local strictReduced = useClientSelector(settingsReduced)
	local viewport = useViewport()
	-- True only while the curtain is shut and settled. `split` is derived here,
	-- so the halves exist on the very frame `open` turns true.
	local closedAtRest, setClosedAtRest = React.useState(not open)
	local split = open or not closedAtRest
	local travel = useCurtainTravel(open, strictReduced == true, function(target)
		if target <= 0 then
			setClosedAtRest(true)
		end
	end)
	local veil, setVeil = React.useBinding(1)
	local veilMotor = React.useRef(nil)
	local wasOpen = React.useRef(open)
	local paneRef = React.useRef(nil)
	local rightClipRef = React.useRef(nil)
	if veilMotor.current == nil then
		veilMotor.current = createFlipperMotor(1, Curtain.VEIL_STIFFNESS, Curtain.VEIL_DAMPING)
	end

	-- Subscribe once. Cleanup runs on unmount, not when the curtain retargets.
	React.useLayoutEffect(function()
		local motor = veilMotor.current
		if motor == nil then
			return nil
		end
		local disconnect = motor:onChange(setVeil)
		return function()
			disconnect()
			motor:destroy()
			if veilMotor.current == motor then
				veilMotor.current = nil
			end
		end
	end, {})

	React.useLayoutEffect(function()
		if open then
			setClosedAtRest(false)
		else
			-- The shell camera and lighting are restored the moment the rift
			-- closes, so cover the world at once; the halves close over the veil.
			local motor = veilMotor.current
			if motor ~= nil then
				motor:setPosition(1)
			end
		end
		if open ~= wasOpen.current then
			wasOpen.current = open
			Audio:play(if open then "curtainOpen" else "curtainClose")
		end
		return nil
	end, { open })

	-- Lift the veil once the sanctuary is standing behind the halves.
	React.useLayoutEffect(function()
		local motor = veilMotor.current
		if motor == nil or not open then
			return nil
		end
		motor:setGoal(if ready then 0 else 1)
		return nil
	end, { open, ready })

	-- A GUI renders in one place only, so the right half shows a muted snapshot
	-- of the shell. It is re-taken when the rift closes, so the halves always
	-- meet on the shell as it is now (numbers that ticked while away, or a page
	-- the player jumped to from the dock), never on a stale picture.
	React.useLayoutEffect(function()
		if not split then
			return nil
		end
		local pane = paneRef.current
		local slot = rightClipRef.current
		if pane == nil or slot == nil then
			return nil
		end
		local copy = pane:Clone()
		copy.Name = "SanctuaryRightMute"
		copy.Size = UDim2.fromScale(2, 1)
		copy.Position = UDim2.fromScale(-1, 0)
		copy.AnchorPoint = Vector2.new(0, 0)
		copy.ZIndex = 1
		muteClone(copy)
		copy.Parent = slot
		return function()
			pcall(function()
				copy:Destroy()
			end)
		end
	end, { split, open })

	-- While the dark veil fully covers the screen (opening before the sanctuary
	-- is ready, and all through a close), nothing 3D can be seen, so the 3D
	-- scene isn't drawn: the curtain gets the whole frame and glides. It comes
	-- back the moment the veil starts to lift, and always when the curtain goes.
	local coverWorld = split and not (open and ready)
	React.useLayoutEffect(function()
		pcall(function()
			RunService:Set3dRenderingEnabled(not coverWorld)
		end)
		return nil
	end, { coverWorld })
	React.useEffect(function()
		return function()
			pcall(function()
				RunService:Set3dRenderingEnabled(true)
			end)
		end
	end, {})

	-- The shell takes no input while it is split; the docks drive navigation.
	React.useLayoutEffect(function()
		local pane = paneRef.current
		if pane == nil then
			return nil
		end
		pcall(function()
			pane.Interactable = not split
		end)
		return nil
	end, { split })

	-- One plan places the docks, the HUD and the touch controls, recomputed on
	-- every viewport change (rotation, resize, keyboard, safe-area change).
	local plan = HudPlan.compute({
		width = viewport.width,
		height = viewport.height,
		touch = UserInputService.TouchEnabled,
		dockEntries = #LEFT_DOCK,
	})
	local showDocks = open and plan.dockMode == "columns"
	local leftPosition = travel:map(function(value)
		return UDim2.fromScale(-Curtain.shift(value), 0)
	end)
	local rightPosition = travel:map(function(value)
		return UDim2.fromScale(0.5 + Curtain.shift(value), 0)
	end)
	local rimTransparency = travel:map(Curtain.rimTransparency)
	local shadeTransparency = travel:map(Curtain.shadeTransparency)

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = false,
	}, split and React.createElement(RiftVeil, {
		veil = veil,
	}), React.createElement("frame", {
		-- Left half: the live shell, clipped to the left half while split. Its
		-- inner pane doubles in width so the UI keeps its full-screen layout.
		Size = if split then UDim2.fromScale(0.5, 1) else UDim2.fromScale(1, 1),
		Position = if split then leftPosition else UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = split,
		Active = not split,
		ZIndex = 2,
	}, React.createElement("frame", {
		ref = paneRef,
		Size = if split then UDim2.fromScale(2, 1) else UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = not split,
	}, props.children), split and React.createElement(HalfShade, {
		transparency = shadeTransparency,
	}), split and React.createElement(PartingEdge, {
		side = "right",
		rimTransparency = rimTransparency,
	})), split and React.createElement("frame", {
		-- Right half: holds the muted snapshot (see the clone effect above).
		ref = rightClipRef,
		Size = UDim2.fromScale(0.5, 1),
		Position = rightPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = false,
		ZIndex = 2,
	}, React.createElement(HalfShade, {
		transparency = shadeTransparency,
	}), React.createElement(PartingEdge, {
		side = "left",
		rimTransparency = rimTransparency,
	})), showDocks and React.createElement(DockColumn, {
		entries = LEFT_DOCK,
		side = "left",
		rect = plan.dockLeft,
		gap = plan.dockGap,
		button = plan.dockButton,
		onNavigate = props.onNavigate,
	}), showDocks and React.createElement(DockColumn, {
		entries = RIGHT_DOCK,
		side = "right",
		rect = plan.dockRight,
		gap = plan.dockGap,
		button = plan.dockButton,
		onNavigate = props.onNavigate,
	}), open and ready and React.createElement(SanctuaryHud, {
		plan = plan,
		ore = props.ore,
		dispatch = props.dispatch,
		entries = ALL_DOCK,
		reducedMotion = strictReduced == true or props.reducedMotion == true,
		onNavigate = props.onNavigate,
	}))
end

return {
	SplitCurtain = SplitCurtain,
}
end

-- ======================================================================
-- Module: CelebrationBurst   (merged from CelebrationBurst.luau, 767 lines)
-- ======================================================================
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
-- Bursts use the shared decelerate curve: a sharp launch that settles long,
-- the same arrival the rest of the interface uses.
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
		-- Arrive decelerating, leave accelerating (never a linear fade).
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
	-- ▼ ReadonlyArray.filter ▼
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
	-- ▲ ReadonlyArray.filter ▲
	local particles = _newValue
	-- Skip per-particle glow frames on constrained/low quality — each glow is an
	-- extra GuiObject + transparency binding for every spark.
	local detailed = not minimal and not constrained and antilag.quality >= 0.72 and antilag.glowScale >= 0.45 and activeCount <= 10
	local impact = time:map(function(seconds)
		return easeOutBack(math.clamp(seconds / 0.28, 0, 1))
	end)
	local rayCount = if minimal then 0 elseif constrained then (if antilag.quality >= 0.55 then 2 else 0) elseif antilag.quality >= 0.62 then 4 elseif antilag.quality >= 0.28 then 2 else 0
	local rays = if rayCount == 4 then { 0, 90, 180, 270 } elseif rayCount == 2 then { 0, 180 } else {}
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
	local _exp = { 0, 1 }
	-- ▼ ReadonlyArray.filter ▼
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
	-- ▲ ReadonlyArray.filter ▲
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
	local _exp_1 = React.createElement(RewardReceipt, {
		style = style,
		time = time,
		duration = duration,
		reducedMotion = reducedMotion,
		compact = viewport.compact or viewport.tight,
	})
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
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

-- ======================================================================
-- Module: ComboBadge   (merged from ComboBadge.luau, 296 lines)
-- ======================================================================
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
--[[
	*
	 * Cosmetic-only combo readout for the Overcharge tap loop. The server is the sole
	 * authority on `Combo` / `ComboMultiplier` — this component only ever mirrors values
	 * it is handed (per-tap effect/RemoteFunction data, or the decay-aware state snapshot
	 * as a resync fallback) and layers a client-side countdown purely to decide when to
	 * fade the badge out if the player stops tapping before the next server update arrives.
	 
]]
-- Continuous cyan -> pink -> coral -> mango ramp instead of comboAccent's old hard steps, so the
-- badge's color visibly eases as the streak climbs instead of jumping between four fixed colors.
local HEAT_STOPS = { Palette.cyan, Palette.pink, Palette.coral, Palette.mango }
local function heatColor(ratio)
	local t = math.clamp(ratio, 0, 1) * (#HEAT_STOPS - 1)
	local index = math.min(#HEAT_STOPS - 2, math.floor(t))
	return HEAT_STOPS[index + 1]:Lerp(HEAT_STOPS[index + 2], t - index)
end
-- Thin decay-countdown ring around the icon: a real read of how long the streak has left before
-- it expires, not just decoration. Reuses the same startedAt-anchored useClock sweep technique as
-- the reactor's PulseWindowNeedle (motion.ts's useClock always loops, so a "one countdown, not a
-- repeating sweep" ring is built by driving Visible off the remaining-time fraction directly).
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
			-- NumberSequence throws if keypoints aren't strictly increasing in time. Clamping
			-- each bound independently (the original approach) let the second keypoint land
			-- past the third once `fraction` got close enough to 1 -- clamp them jointly
			-- instead so the ordering holds for every possible fraction, including 0 and 1.
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
	-- Punches the icon and stat text on every combo increment (not just on show/hide), so each
	-- successful tap reads as a distinct beat instead of the badge only ever animating in once
	-- and then sitting static while the number underneath silently climbs.
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
	-- Maxed glow breathes slowly; punch carries the beat hierarchy.
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

-- ======================================================================
-- Module: FeedbackOverlay   (merged from FeedbackOverlay.luau, 417 lines)
-- ======================================================================
__defs["FeedbackOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
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
local CATEGORIES = { "Bug", "Suggestion", "Balance", "Other" }
local function FeedbackOverlay(_param)
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — FeedbackOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local height = math.min(if keyboardCompact then 210 elseif wideShort then 286 elseif compact then 420 else 448, safeHeight)
	local contentHeight = math.max(1, height - 28)
	local headerH = if keyboardCompact then 46 elseif compact then 64 else 72
	local categoryTop = headerH + (if keyboardCompact then 0 else 8)
	local categoryColumns = if narrow then 2 else 4
	local categoryH = if keyboardCompact then 0 elseif categoryColumns == 2 then 96 else 44
	local editorTop = categoryTop + categoryH + (if keyboardCompact then 6 else 10)
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
		dispatch("SubmitFeedback", {
			Category = category,
			Message = trimmed,
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
			Audio:play("reward")
			notify("Feedback sent", "Thanks for helping make the game better.")
		end)
	end, { canSend, category, dispatch, notify, trimmed })
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
	end, { sent })
	local cardTravel = 16
	local cardPosition = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * cardTravel))
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
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#CATEGORIES)
		local _callback = function(choice)
			return {
				id = choice,
				label = string.upper(choice),
				accent = Palette.cyan,
			}
		end
		for _k, _v in CATEGORIES do
			_newValue[_k] = _callback(_v, _k - 1, CATEGORIES)
		end
		-- ▲ ReadonlyArray.map ▲
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
	}, _exp_3, _exp_4, _exp_5, _exp_6, _condition, not sent and React.createElement("frame", {
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
		PlaceholderText = "What happened, or what should we add? (8+ characters)",
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
				return setMessage(string.sub(box.Text, 1, 600))
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

-- ======================================================================
-- Module: MobilePreviewGate   (merged from MobilePreviewGate.luau, 237 lines)
-- ======================================================================
__defs["MobilePreviewGate"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local MOBILE_PREVIEW_ACK = 1
local DISCLAIMER = "Phone and tablet are still a preview. Some pages overlap, clip, or miss buttons — especially in short landscape.\n\nThis is not the finished mobile game. Trade, inventory, shop, and the top bar can still crash into each other. Some taps are too small. The keyboard and home bar are best-effort. Mid-range Androids may hitch on crates and celebrations.\n\nBugs are expected. Your save is still on the server. Hit Feedback if something blocks you. Desktop is the supported way to play."
local function MobilePreviewGate(_param)
	local ack = _param.ack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local touchDevice = not viewport.desktop and UserInputService.TouchEnabled
	local checked, setChecked = React.useState(false)
	local dismissed, setDismissed = React.useState(false)
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local short = viewport.height < 500
	local side = math.max(16, chrome.sideSafe + 12)
	local top = math.max(18, viewport.topInset + 12)
	local bottom = math.max(18, chrome.bottomSafe + 12)
	local boxWidth = math.min(viewport.width - side * 2, 720)
	local boxHeight = math.min(viewport.height - top - bottom, if short then viewport.height - top - bottom else 620)
	local fade = motion:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local scrim = motion:map(function(amount)
		return math.clamp(1 - amount * 0.94, 0.06, 1)
	end)
	local lift = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - math.clamp(amount, 0, 1)) * 18))
	end)
	local close = function()
		if not checked or closing then
			return nil
		end
		Audio:play("confirm")
		dispatch("SetSetting", {
			Key = "MobilePreviewAck",
			Value = MOBILE_PREVIEW_ACK,
		})
		beginExit(function()
			return setDismissed(true)
		end)
	end
	local _condition = not touchDevice or dismissed
	if not _condition then
		local _condition_1 = ack
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_condition = _condition_1 >= MOBILE_PREVIEW_ACK
	end
	if _condition then
		return React.createElement(React.Fragment)
	end
	local toggle = function()
		Audio:play("tick")
		setChecked(function(current)
			return not current
		end)
	end
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrim,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 900,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(boxWidth, boxHeight),
		Position = lift,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 901,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.mango,
		Thickness = 2,
		Transparency = 0.18,
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.night, Palette.ink),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(92, 3),
		Position = UDim2.fromOffset(22, 0),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 902,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = "MOBILE PREVIEW",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(22, 16),
		sizeConstraint = UDim2.new(1, -44, 0, 16),
		transparency = fade,
		zIndex = 902,
	}), React.createElement(Text, {
		value = "Mobile is in development",
		size = if short then 22 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		position = UDim2.fromOffset(22, 36),
		sizeConstraint = UDim2.new(1, -44, 0, if short then 36 else 40),
		transparency = fade,
		zIndex = 902,
	}), React.createElement(Text, {
		value = "Expect bugs. This is not the finished phone game.",
		size = 14,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(22, if short then 74 else 82),
		sizeConstraint = UDim2.new(1, -44, 0, 36),
		transparency = fade,
		zIndex = 902,
	}), React.createElement("scrollingframe", {
		Size = UDim2.new(1, -44, 1, if short then -196 else -214),
		Position = UDim2.fromOffset(22, if short then 114 else 126),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Palette.mango,
		ScrollBarImageTransparency = 0.28,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 902,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}), React.createElement(Text, {
		value = DISCLAIMER,
		size = 13,
		color = Palette.creamSoft,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 420),
		zIndex = 903,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -44, 0, TapTarget),
		Position = UDim2.new(0, 22, 1, -(TapTarget * 2 + 20)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 902,
	}, React.createElement(Button, {
		text = "",
		onClick = toggle,
		color = if checked then darken(Palette.mango, 0.55) else Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 903,
		outline = not checked,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(12, 13),
		BackgroundColor3 = if checked then Palette.mango else Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 904,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if checked then Palette.mango else Palette.lineSoft,
		Thickness = 1,
	}), checked and React.createElement(Text, {
		value = "✓",
		size = 16,
		color = Palette.ink,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 905,
	})), React.createElement(Text, {
		value = "I understand mobile is unfinished and I may hit bugs.",
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(44, 4),
		sizeConstraint = UDim2.new(1, -56, 1, -8),
		zIndex = 904,
	}))), React.createElement(Button, {
		text = "CONTINUE",
		onClick = close,
		color = if checked then Palette.mango else Palette.panelSoft,
		textColor = if checked then Palette.ink else Palette.muted,
		size = UDim2.new(1, -44, 0, TapTarget),
		position = UDim2.new(0, 22, 1, -(TapTarget + 12)),
		disabled = not checked or closing,
		reducedMotion = reducedMotion,
		highlight = checked,
		zIndex = 903,
	}))))
end
return {
	MobilePreviewGate = MobilePreviewGate,
	MOBILE_PREVIEW_ACK = MOBILE_PREVIEW_ACK,
}
end

-- ======================================================================
-- Module: MobileShell   (merged from MobileShell.luau, 908 lines)
-- ======================================================================
__defs["MobileShell"] = function()
-- Mobile shell (v2) — a ground-up rewrite of the touch/narrow-viewport navigation chrome.
--
-- The previous mobile pattern reused the desktop rail as a slide-out drawer, sharing one
-- animated spring (`railWidth`) between "desktop sidebar collapse" (a real width change) and
-- "mobile drawer open/close" (should have been a slide). Any interruption mid-animation left
-- the drawer visibly stuck at a partial size — a bug that survived three separate fix attempts
-- aimed at the symptom instead of the shape of the problem.
--
-- This shell removes the shared-animation hazard entirely by using a different navigation
-- pattern for touch/narrow viewports: a fixed-height bottom tab bar. Nothing about a tab bar's
-- container ever needs to resize or reposition — it is exactly Layout.tabBarH tall, anchored to
-- the bottom safe area, for the lifetime of the mobile session. Only icon/label emphasis
-- animates (a purely decorative tween on already-mounted, already-correctly-sized elements),
-- so there is no failure mode where the bar itself can render at a wrong size.
--
-- Overflow destinations (anything past the tab bar's `tabBarSlots`) live in a "More" sheet: a
-- bottom sheet that slides up from off-screen and is fully hidden (Visible=false) when closed,
-- so it never occupies layout space it could get stuck holding onto.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _motion = require(script.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _appNav = require(script.Parent.CoreKit)("appNav")
local AppHelpers = _appNav.AppHelpers
local MORE_NAV = _appNav.MORE_NAV
local PRIMARY_NAV = _appNav.PRIMARY_NAV
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local CountBadge = _ui.CountBadge
local IconTile = _ui.IconTile
local Text = _ui.Text
local useButtonChrome = _ui.useButtonChrome
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local Audio = require(script.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local function TabButton(_param)
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
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	local selection = useFlipperSpring(if active and not disabled then 1 else 0, reducedMotion, 520, 34)
	local iconSize = 22
	local iconColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(entry.accent, math.clamp(raw, 0, 1))
	end)
	local labelColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.muted:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local liftY = selection:map(function(raw)
		return -math.round(math.clamp(raw, 0, 1) * 2)
	end)
	local indicatorSize = selection:map(function(raw)
		return UDim2.fromOffset(20 * math.clamp(raw, 0, 1), 2)
	end)
	local indicatorTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1) * 0.72
	end)
	-- Packed to fit a TAP_TARGET (48px) tab core: icon + label must clear inside the bar
	-- before bottomSafe, especially on landscape phones.
	local iconTop = 3
	local labelTop = 26
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		ZIndex = 40,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 41,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = chrome.touchScale,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = liftY:map(function(lift)
			return UDim2.new(0.5, 0, 0, iconTop + lift)
		end),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = iconColor,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = iconSize,
		spin = false,
		reducedMotion = reducedMotion,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 44,
		compact = true,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 0, 0, labelTop),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		zIndex = 42,
	}), React.createElement("frame", {
		Size = indicatorSize,
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = entry.accent,
		BackgroundTransparency = indicatorTransparency,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local MoreCell
local function MoreSheet(_param)
	local open = _param.open
	local entries = _param.entries
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local bottomSafe = _param.bottomSafe
	local onClose = _param.onClose
	local viewportHeight = _param.viewportHeight
	local visible = AppHelpers:filterNav(entries, state, tutorialPage)
	local cols = math.max(1, math.min(_param.moreCols or 4, #visible))
	local cellH = _param.moreCellH or 72
	local rows = math.max(1, math.ceil(#visible / cols))
	local rawSheetH = rows * (cellH + 8) + bottomSafe + 64
	local maxSheetH = if viewportHeight and viewportHeight > 0 then math.floor(viewportHeight * 0.8) else rawSheetH
	local sheetH = math.min(rawSheetH, maxSheetH)
	local gridH = math.min(rows * (cellH + 8), maxSheetH - bottomSafe - 64)
	local needsScroll = rawSheetH > maxSheetH
	local reveal = useFlipperSpring(if open then 1 else 0, reducedMotion, 780, 44)
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.6
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Active = true,
		ZIndex = 200,
		Event = {
			Activated = function()
				Audio:play("close")
				onClose()
			end,
		},
	})
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	})
	local _exp_2 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.76,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(36, 3),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 202,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	local _exp_4 = React.createElement(Text, {
		value = "MORE",
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 202,
	})
	local _exp_5 = React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / cols, -8, 0, cellH),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 200,
		Visible = open,
	}, _exp, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, sheetH),
		AnchorPoint = Vector2.new(0, 1),
		Position = reveal:map(function(amount)
			return UDim2.new(0, 0, 1, math.round((1 - math.clamp(amount, 0, 1)) * sheetH))
		end),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 201,
		ClipsDescendants = true,
	}, _exp_1, _exp_2, _exp_3, _exp_4, React.createElement(if needsScroll then "scrollingframe" else "frame", (function()
		local props = {
			Size = UDim2.new(1, -16, 0, math.max(1, gridH)),
			Position = UDim2.fromOffset(8, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 202,
		}
		if needsScroll then
			props.ScrollBarThickness = 6
			props.ScrollingEnabled = true
			props.CanvasSize = UDim2.new(0, 0, 0, rows * (cellH + 8))
			props.AutomaticCanvasSize = Enum.AutomaticSize.Y
		end
		return props
	end)(), _exp_5, _newValue)))
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
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 203,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 204,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if active then darken(entry.accent, 0.74) else Palette.panelRaised,
		BackgroundTransparency = if active then 0.02 else 0.12,
		BorderSizePixel = 0,
		ZIndex = 205,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if active then entry.accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.48 else 0.8,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		live = chrome.shimmerLive,
		zIndex = 205,
		radius = 14,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 206,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = 24,
		spin = false,
		reducedMotion = reducedMotion,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 207,
		compact = true,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = if disabled then Palette.muted else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 2, 1, -18),
		sizeConstraint = UDim2.new(1, -4, 0, 16),
		zIndex = 206,
	}))))
end
-- The fixed-height bottom tab bar. Size is a pure function of the viewport (via
-- chrome.tabBarH / chrome.tabBarSlots computed in mobileLayout.ts) — it is set once per
-- viewport change and never animates, so there is no "stuck mid-resize" failure mode.
local function MobileTabBar(_param)
	local page = _param.page
	local setPage = _param.setPage
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomSafe = _param.bottomSafe
	local visible = _param.visible
	if visible == nil then
		visible = true
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local enter = useEntrance(reducedMotion)
	local moreOpen, setMoreOpen = React.useState(false)
	local _array = {}
	local _length = #_array
	local _pRIMARY_NAVLength = #PRIMARY_NAV
	table.move(PRIMARY_NAV, 1, _pRIMARY_NAVLength, _length + 1, _array)
	_length += _pRIMARY_NAVLength
	table.move(MORE_NAV, 1, #MORE_NAV, _length + 1, _array)
	local allVisible = AppHelpers:filterNav(_array, state, tutorialPage)
	local slots = math.max(3, chrome.tabBarSlots)
	-- Reserve one slot for "More" whenever there's overflow; otherwise every visible entry
	-- fits directly on the bar.
	local needsMore = #allVisible > slots
	local primaryCount = if needsMore then slots - 1 else slots
	local primary = {}
	local overflow = {}
	-- ▼ ReadonlyArray.forEach ▼
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
	for _k, _v in allVisible do
		_callback(_v, _k - 1, allVisible)
	end
	-- ▲ ReadonlyArray.forEach ▲
	-- If the current page is buried in overflow, still show it in the bar in place of the
	-- last primary slot so the active tab is never invisible to the player. The swap has to
	-- move the displaced primary entry into the More sheet AND take the active entry out of
	-- it — leaving the active entry in `overflow` rendered it twice (tab bar + More sheet,
	-- duplicate React keys) while the displaced entry vanished from the sheet entirely.
	-- ▼ ReadonlyArray.find ▼
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
	-- ▲ ReadonlyArray.find ▲
	local activeInOverflow = _result
	if activeInOverflow ~= nil and #primary > 0 then
		local displaced = primary[#primary]
		primary[#primary] = activeInOverflow
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback_2 = function(entry)
			return entry.id ~= activeInOverflow.id
		end
		local _length_1 = 0
		for _k, _v in overflow do
			if _callback_2(_v, _k - 1, overflow) == true then
				_length_1 += 1
				_newValue[_length_1] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		overflow = _newValue
		if displaced ~= nil then
			table.insert(overflow, 1, displaced)
		end
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_2 = function(sum, entry)
		return sum + AppHelpers:navBadge(entry, state, chatUnread)
	end
	for _i = 1, #overflow do
		_result_1 = _callback_2(_result_1, overflow[_i], _i - 1, overflow)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local overflowBadgeTotal = _result_1
	local moreActive = activeInOverflow ~= nil or moreOpen
	local _exp = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.36),
		Rotation = 90,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 41,
	})
	local _exp_2 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#primary)
	local _callback_3 = function(entry, index)
		return React.createElement("frame", {
			key = entry.id,
			Size = UDim2.new(1 / slots, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, React.createElement(TabButton, {
			entry = entry,
			active = page == entry.id,
			onClick = function()
				return setPage(entry.id)
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		}))
	end
	for _k, _v in primary do
		_newValue[_k] = _callback_3(_v, _k - 1, primary)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = enter:map(function(amount)
			return UDim2.new(0, 0, 1, math.round((1 - math.clamp(amount, 0, 1)) * (height * 0.6)))
		end),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 40,
		ClipsDescendants = false,
		Visible = visible,
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.new(1, -8, 0, height - bottomSafe),
		Position = UDim2.fromOffset(4, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 41,
	}, _exp_2, _newValue, needsMore and React.createElement("frame", {
		key = "more",
		Size = UDim2.new(1 / slots, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = primaryCount,
	}, React.createElement(TabButton, {
		entry = {
			id = "Overview",
			label = "More",
			eyebrow = "",
			icon = "Menu",
			accent = Palette.muted,
		},
		active = moreActive,
		onClick = function()
			return setMoreOpen(true)
		end,
		reducedMotion = reducedMotion,
		badge = overflowBadgeTotal,
		layoutOrder = primaryCount,
	})))), React.createElement(MoreSheet, {
		open = moreOpen,
		entries = overflow,
		page = page,
		setPage = setPage,
		reducedMotion = reducedMotion,
		state = state,
		chatUnread = chatUnread,
		tutorialPage = tutorialPage,
		bottomSafe = bottomSafe,
		onClose = function()
			return setMoreOpen(false)
		end,
		viewportHeight = _param.viewportHeight,
		moreCols = _param.moreCols,
		moreCellH = _param.moreCellH,
	}))
end
-- Compact mobile header: logo mark, resource chips, and a vault-collect button. Replaces the
-- old TopBar's mobile branch — same information, laid out for a fixed-height single row
-- instead of the old desktop bar's row-stacking logic.
local MiniChip
local function MobileHeader(_param)
	local state = _param.state
	local page = _param.page
	local accent = _param.accent
	local topPad = _param.topPad
	local barHeight = _param.barHeight
	local edgePad = _param.edgePad
	local reducedMotion = _param.reducedMotion
	local openPlayerlist = _param.openPlayerlist
	local openSanctuary = _param.openSanctuary
	local entry = AppHelpers:pageEntry(page)
	local vaultReady = asFlux(state.Vault) >= 0.01
	local showDust = AppHelpers:featureUnlocked(state, "StarGrid")
	local showCores = AppHelpers:featureUnlocked(state, "Rebirth")
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	-- Reserve the right side purely for however wide the chip cluster actually needs (not a
	-- guessed percentage), and let the player-list button fill whatever's left. Guessed
	-- percentages on both sides is exactly what let them overlap in the middle on narrow
	-- phones once real (long) numbers pushed the chip row wider than assumed.
	local chipCount = (if showCores then 1 else 0) + (if showDust then 1 else 0) + 1
	local chipW = if barHeight <= 40 then 56 else 64
	local sanctuarySlot = if openSanctuary ~= nil then 36 else 0
	local chipReserve = chipCount * chipW + (chipCount - 1) * 6 + 12 + sanctuarySlot
	local titleSize = if barHeight <= 40 then 13 else 15
	local iconSize = if barHeight <= 40 then 26 else 30
	return React.createElement("frame", {
		Size = UDim2.new(1, -edgePad * 2, 0, barHeight),
		Position = UDim2.fromOffset(edgePad, topPad),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.4),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.72,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(40, 1),
		Position = UDim2.fromOffset(14, 0),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("imagebutton", {
		Size = UDim2.new(1, -chipReserve, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 4,
		Event = {
			Activated = function()
				Audio:play("playerlistOpen")
				openPlayerlist()
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = iconSize,
		radius = 10,
		position = UDim2.fromOffset(10, math.floor((barHeight - iconSize) / 2)),
		spin = false,
		reducedMotion = reducedMotion,
		zIndex = 4,
	}), React.createElement(Text, {
		value = entry.label,
		size = titleSize,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(10 + iconSize + 8, math.floor(barHeight / 2) - 10),
		sizeConstraint = UDim2.new(1, -(10 + iconSize + 16), 0, 20),
		zIndex = 4,
	}), visitorsHere > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(10 + iconSize - 2, math.floor((barHeight - iconSize) / 2) - 2),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.fromOffset(0, math.min(TapTarget - 10, barHeight - 8)),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}), openSanctuary ~= nil and React.createElement("imagebutton", {
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Palette.panelSoft,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = 0,
		ZIndex = 5,
		Event = {
			Activated = function()
				Audio:play("click")
				openSanctuary()
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Icon, {
		kind = "Forge",
		size = 18,
		color = Palette.cyan,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), showCores and React.createElement(MiniChip, {
		label = "CORES",
		value = state.Cores,
		accent = Palette.violet,
		layoutOrder = 1,
		width = chipW,
	}), showDust and React.createElement(MiniChip, {
		label = "DUST",
		value = state.Stardust,
		accent = Palette.mango,
		layoutOrder = 2,
		width = chipW,
	}), React.createElement(MiniChip, {
		label = "FLUX",
		value = state.Cash,
		accent = if vaultReady then Palette.cyan else Palette.muted,
		layoutOrder = 3,
		width = chipW,
	})))
end
function MiniChip(_param)
	local value = _param.value
	local accent = _param.accent
	local layoutOrder = _param.layoutOrder
	local width = _param.width
	if width == nil then
		width = 64
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, 30),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}), React.createElement(Text, {
		value = `{compactNumber(value)}`,
		size = 12,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(0, 0, 1, 0),
		zIndex = 2,
	}))
end
-- Floating vault/overcharge quick-action cluster anchored above the tab bar. Fixed position
-- (bottom-right, above the bar) — no drag/reposition in v2, since the tab bar already claims
-- the thumb-reachable bottom strip and a second freely-floating control invites exactly the
-- kind of overlap bugs the old floating quick bar produced.
local function MobileQuickActions(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local vaultFill = if asFlux(state.Capacity) > 0 then math.clamp(asFlux(state.Vault) / asFlux(state.Capacity), 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local enter = useEntrance(reducedMotion)
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
				setTapLeft(left)
				if left <= 0 then
					break
				end
				task.wait(0.05)
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { tapReadyAt })
	local tap = function()
		if os.clock() < tapReadyAt then
			return nil
		end
		setTapReadyAt(os.clock() + 0.06)
		setTapLeft(0.06)
		dispatch("Overcharge")
	end
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		dispatch("CollectVault")
	end
	local width = 190
	local height = 56
	-- AnchorPoint (1, 1): Position's Y is measured to this frame's OWN bottom edge, so
	-- `bottomOffset` (the tab bar's total height + a gap) places the cluster's bottom edge
	-- exactly that far above the screen bottom — i.e. directly above the tab bar, never
	-- overlapping it. Without an explicit anchor this defaults to the top-left corner, which
	-- silently made the same offset math place the cluster's TOP that far up and let its
	-- bottom (anchor + height) sink down past the tab bar's own top edge.
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(1, 1),
		Position = enter:map(function(amount)
			return UDim2.new(1, -edgePad, 1, -bottomOffset + math.round((1 - amount) * 14))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 38,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 39,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if vaultFill > 0.8 then Palette.green else Palette.lineSoft,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = 0.45,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -14, 0, 3),
		Position = UDim2.fromOffset(7, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 40,
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
		Size = UDim2.new(1, -14, 0, TapTarget),
		Position = UDim2.fromOffset(7, height - TapTarget - 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 41,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(0.58, -3, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
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
	})), React.createElement("frame", {
		Size = UDim2.new(0.42, -3, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
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
	})))))
end
return {
	MobileTabBar = MobileTabBar,
	MobileHeader = MobileHeader,
	MobileQuickActions = MobileQuickActions,
}
end

-- ======================================================================
-- Module: OfflineRewardsOverlay   (merged from OfflineRewardsOverlay.luau, 420 lines)
-- ======================================================================
__defs["OfflineRewardsOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
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
local function StatTile(_param)
	local label = _param.label
	local value = _param.value
	local color = _param.color
	local index = _param.index
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — OfflineRewardsOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — OfflineRewardsOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- A haul big enough to matter (roughly an hour or more at the player's own rate) gets a
	-- stronger glow around the reward panel -- coming back to a small trickle and a huge bank
	-- both said "ALREADY IN YOUR CASH" identically before, with nothing to make a genuinely big
	-- welcome-back moment read as more exciting than a routine five-minute check-in.
	local rewardAmount = asFlux(reward)
	local bigHaul = rate > 0 and rewardAmount >= rate * 3600
	local rewardGlow = useGlowStroke(bigHaul, softMotion, 0.35, 0.15, 0.62, 1.6)
	local cardWidth = math.min(if stack then math.max(280, viewport.width - chrome.sideSafe * 2 - 20) else 560, 560)
	local cardHeight = math.min(if stack then 468 else 420, math.max(300, viewport.height - viewport.topInset - chrome.bottomSafe - 24))
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
	local cardPosition = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * 18))
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
		size = if stack then 24 else 30,
		color = Palette.mint,
		position = UDim2.fromOffset(14, 28),
		sizeConstraint = UDim2.fromOffset(0, 40),
		autoWidth = true,
		zIndex = 466,
	}))
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
	local _exp_10 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 78 else 70),
		Position = UDim2.fromOffset(0, if stack then 162 else 172),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue)
	local _exp_11 = React.createElement(Text, {
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
		_attributes.size = UDim2.new(1, 0, 0, TapTarget)
		_attributes.position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 8))
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
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 8)),
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
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		disabled = closing,
	})))))))
end
return {
	OfflineRewardsOverlay = OfflineRewardsOverlay,
}
end

-- ======================================================================
-- Module: PlayerlistOverlay   (merged from PlayerlistOverlay.luau, 1059 lines)
-- ======================================================================
__defs["PlayerlistOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local _ui = __load("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local Core = StarterGui
local TEST_BOT_USER_ID = 771133001
local REPORT_REASONS = { "Exploiting", "Harassment", "Trolling", "Spam", "Inappropriate", "Other" }
local function sanitizeRows(raw)
	local rows = {}
	for _, entry in raw do
		local _userId = entry.UserId
		local userId = if type(_userId) == "number" then math.floor(entry.UserId) else tonumber(tostring(entry.UserId))
		if userId == nil or userId == 0 or userId ~= userId then
			continue
		end
		if userId == TEST_BOT_USER_ID then
			continue
		end
		local _object = table.clone(entry)
		setmetatable(_object, nil)
		_object.UserId = userId
		table.insert(rows, _object)
	end
	return rows
end
local function AvatarThumbnail(_param)
	local userId = _param.userId
	local accent = _param.accent
	local size = _param.size
	local position = _param.position
	local zIndex = _param.zIndex
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundColor3 = darken(accent, 0.64),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.2,
	}), React.createElement("imagelabel", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={math.floor(userId)}&w=150&h=150`,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function PlayerRow(_param)
	local player = _param.player
	local selected = _param.selected
	local onSelect = _param.onSelect
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local awayStamp = _param.awayStamp
	local accent = if player.IsLocal then Palette.mint else Palette.cyan
	local peer = Players:GetPlayerByUserId(player.UserId)
	local _result
	if player.IsLocal or awayStamp < 0 then
		_result = false
	else
		local _result_1 = peer
		if _result_1 ~= nil then
			_result_1 = _result_1:GetAttribute("AF_Away")
		end
		_result = _result_1 == true
	end
	local away = _result
	local subtitle = if player.IsLocal then "YOUR PROFILE" elseif away then "AFK" else `WORLD {compactNumber(player.CurrentZone)}  •  {compactNumber(player.Rebirths)} REBIRTHS`
	return React.createElement("frame", {
		Size = UDim2.new(1, -2, 0, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 620,
	}, React.createElement(Button, {
		text = "",
		onClick = onSelect,
		color = if selected then darken(accent, 0.64) else Palette.panel,
		textColor = Palette.cream,
		outline = not selected,
		highlight = selected,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 620,
	}, React.createElement(AvatarThumbnail, {
		userId = player.UserId,
		accent = accent,
		size = 38,
		position = UDim2.fromOffset(10, 10),
		zIndex = 623,
	}), React.createElement(Text, {
		value = if away then `{player.DisplayName}  ·  AFK` else player.DisplayName,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(58, 7),
		sizeConstraint = UDim2.new(1, -118, 0, 21),
		zIndex = 623,
	}), React.createElement(Text, {
		value = subtitle,
		size = 10,
		color = if away then Palette.mango else accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(58, 31),
		sizeConstraint = UDim2.new(1, -118, 0, 17),
		zIndex = 623,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -22, 0.5, -4),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
		ZIndex = 624,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.white,
		Thickness = 1,
		Transparency = 0.58,
	}))))
end
local function PlayerlistOverlay(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local notify = _param.notify
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local localSummary = React.useMemo(function()
		return {
			UserId = Players.LocalPlayer.UserId,
			Name = Players.LocalPlayer.Name,
			DisplayName = Players.LocalPlayer.DisplayName,
			CurrentZone = state.CurrentZone,
			Rebirths = state.Rebirths,
			Production = 0,
			LifetimeCash = 0,
			IsLocal = true,
		}
	end, { state.CurrentZone, state.Rebirths })
	local localSummaryRef = React.useRef(localSummary)
	localSummaryRef.current = localSummary
	local rows, setRows = React.useState(function()
		return { localSummary }
	end)
	local selectedId, setSelectedId = React.useState(Players.LocalPlayer.UserId)
	local friends, setFriends = React.useState({})
	local blocked, setBlocked = React.useState({})
	local inventoryOpen, setInventoryOpen = React.useState(false)
	local reportOpen, setReportOpen = React.useState(false)
	local reportReason, setReportReason = React.useState("Exploiting")
	local reportBusy, setReportBusy = React.useState(false)
	local inviteBusy, setInviteBusy = React.useState(false)
	local alive = React.useRef(true)
	local _binding = useExitTransition(reducedMotion)
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local enter = useEntrance(reducedMotion)
	local awayTick, setAwayTick = React.useState(0)
	React.useEffect(function()
		local pulse = task.spawn(function()
			while true do
				task.wait(1)
				setAwayTick(function(current)
					return current + 1
				end)
			end
		end)
		return function()
			return task.cancel(pulse)
		end
	end, {})
	React.useEffect(function()
		Audio:play("playerlistOpen")
	end, {})
	React.useEffect(function()
		alive.current = true
		return function()
			alive.current = false
		end
	end, {})
	local refresh = React.useCallback(function()
		return dispatch("GetPlayers", {}, function(response)
			if not alive.current or not response.ok then
				return nil
			end
			local cleaned = sanitizeRows(response.Players or {})
			local nextRows = if #cleaned > 0 then cleaned else { localSummaryRef.current }
			setRows(nextRows)
			setSelectedId(function(current)
				-- ▼ ReadonlyArray.some ▼
				local _result = false
				local _callback = function(row)
					return row.UserId == current
				end
				for _k, _v in nextRows do
					if _callback(_v, _k - 1, nextRows) then
						_result = true
						break
					end
				end
				-- ▲ ReadonlyArray.some ▲
				return if _result then current else nextRows[1].UserId
			end)
		end)
	end, { dispatch })
	local applyLocalRoster = React.useCallback(function()
		local selfRow = localSummaryRef.current
		local nextRows = {}
		table.insert(nextRows, selfRow)
		for _, player in Players:GetPlayers() do
			if player.UserId == selfRow.UserId then
				continue
			end
			local _arg0 = {
				UserId = player.UserId,
				Name = player.Name,
				DisplayName = player.DisplayName,
				CurrentZone = 1,
				Rebirths = 0,
				Production = 0,
				IsLocal = false,
			}
			table.insert(nextRows, _arg0)
		end
		setRows(function(current)
			local byId = {}
			for _, row in current do
				local _userId = row.UserId
				byId[_userId] = row
			end
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#nextRows)
			local _callback = function(row)
				local _userId = row.UserId
				local known = byId[_userId]
				local _result
				if known ~= nil and not row.IsLocal then
					local _object = table.clone(known)
					setmetatable(_object, nil)
					_object.Name = row.Name
					_object.DisplayName = row.DisplayName
					_result = _object
				else
					_result = row
				end
				return _result
			end
			for _k, _v in nextRows do
				_newValue[_k] = _callback(_v, _k - 1, nextRows)
			end
			-- ▲ ReadonlyArray.map ▲
			return _newValue
		end)
		setSelectedId(function(current)
			-- ▼ ReadonlyArray.some ▼
			local _result = false
			local _callback = function(row)
				return row.UserId == current
			end
			for _k, _v in nextRows do
				if _callback(_v, _k - 1, nextRows) then
					_result = true
					break
				end
			end
			-- ▲ ReadonlyArray.some ▲
			return if _result then current else nextRows[1].UserId
		end)
	end, {})
	React.useEffect(function()
		refresh()
		applyLocalRoster()
		local debounce
		local requestRefresh = function()
			applyLocalRoster()
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
		local joined = Players.PlayerAdded:Connect(requestRefresh)
		local left = Players.PlayerRemoving:Connect(requestRefresh)
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
	end, { applyLocalRoster, refresh })
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(row)
		return row.UserId == selectedId
	end
	local _result
	for _i, _v in rows do
		if _callback(_v, _i - 1, rows) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result
	if _condition == nil then
		_condition = rows[1]
	end
	local selected = _condition
	local _exp = function()
		local _result_1 = selected
		if _result_1 ~= nil then
			_result_1 = _result_1.IsLocal
		end
		if _result_1 then
			setInventoryOpen(false)
		end
	end
	local _result_1 = selected
	if _result_1 ~= nil then
		_result_1 = _result_1.IsLocal
	end
	React.useEffect(_exp, { _result_1 })
	local syncSocial = React.useCallback(function(userId)
		if userId == nil or userId == Players.LocalPlayer.UserId then
			return nil
		end
		local job = task.spawn(function()
			local nextFriends = {}
			local friendOk, isFriend = pcall(function()
				return (Players.LocalPlayer):IsFriendsWithAsync(userId)
			end)
			if friendOk and isFriend == true then
				local _userId = userId
				nextFriends[_userId] = true
			end
			local nextBlocked = {}
			local blockOk, raw = pcall(function()
				return Core:GetCore("GetBlockedUserIds")
			end)
			if blockOk and type(raw) == "table" then
				for _, value in raw do
					if type(value) == "number" then
						local _arg0 = math.floor(value)
						nextBlocked[_arg0] = true
					end
				end
			end
			if not alive.current then
				return nil
			end
			setFriends(nextFriends)
			setBlocked(nextBlocked)
		end)
		return function()
			return task.cancel(job)
		end
	end, {})
	local _exp_1 = function()
		if selected == nil or selected.IsLocal then
			return nil
		end
		local cancel = syncSocial(selected.UserId)
		local function replaceSocial()
			if cancel ~= nil then
				pcall(cancel)
			end
			cancel = syncSocial(selected.UserId)
		end
		local pulse = task.spawn(function()
			while alive.current do
				task.wait(4)
				if not alive.current then
					break
				end
				replaceSocial()
			end
		end)
		local friendship
		pcall(function()
			local localPlayer = Players.LocalPlayer
			friendship = localPlayer.FriendStatusChanged:Connect(function()
				if alive.current then
					replaceSocial()
				end
			end)
		end)
		return function()
			if cancel ~= nil then
				pcall(cancel)
			end
			pcall(task.cancel, pulse)
			local _result_3 = friendship
			if _result_3 ~= nil then
				_result_3:Disconnect()
			end
		end
	end
	local _result_2 = selected
	if _result_2 ~= nil then
		_result_2 = _result_2.IsLocal
	end
	local _result_3 = selected
	if _result_3 ~= nil then
		_result_3 = _result_3.UserId
	end
	React.useEffect(_exp_1, { _result_2, _result_3, syncSocial })
	local close = React.useCallback(function()
		if exiting then
			return nil
		end
		Audio:play("playerlistClose")
		beginExit(onClose)
	end, { beginExit, exiting, onClose })
	local prompt = function(kind)
		if selected == nil or selected.IsLocal then
			return nil
		end
		local player = Players:GetPlayerByUserId(selected.UserId)
		if player == nil then
			notify("Player left", "That player is no longer in this server.")
			return nil
		end
		local _result_4
		if kind == "friend" then
			local _userId = selected.UserId
			_result_4 = (if friends[_userId] ~= nil then "PromptUnfriend" else "PromptSendFriendRequest")
		else
			local _userId = selected.UserId
			_result_4 = (if blocked[_userId] ~= nil then "PromptUnblockPlayer" else "PromptBlockPlayer")
		end
		local key = _result_4
		local ok = pcall(function()
			return Core:SetCore(key, player)
		end)
		if not ok then
			notify("Roblox menu unavailable", "Wait a moment, then try again.")
		else
			Audio:play("playerlistAction")
		end
	end
	local submitReport = function()
		if selected == nil or selected.IsLocal or reportBusy then
			return nil
		end
		setReportBusy(true)
		Audio:play("dangerPress")
		dispatch("ReportPlayer", {
			UserId = selected.UserId,
			userId = selected.UserId,
			Reason = reportReason,
		}, function(response)
			if not alive.current then
				return nil
			end
			setReportBusy(false)
			if not response.ok then
				local _condition_1 = response.error
				if _condition_1 == nil then
					_condition_1 = "Please try again in a moment."
				end
				notify("Couldn't send report", _condition_1)
				return nil
			end
			setReportOpen(false)
			notify("Report sent", "Thanks for helping keep the server clean.")
		end)
	end
	local invite = function()
		if inviteBusy then
			return nil
		end
		setInviteBusy(true)
		Audio:play("invite")
		local checkDone = false
		local worker
		worker = task.defer(function()
			local canCheck, canInvite = pcall(function()
				return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
			end)
			checkDone = true
			if not alive.current then
				return nil
			end
			local opened = false
			if canCheck and canInvite == true then
				opened = pcall(function()
					return SocialService:PromptGameInvite(Players.LocalPlayer)
				end)
			end
			if not alive.current then
				return nil
			end
			setInviteBusy(false)
			if not opened then
				notify("Invites unavailable", "Roblox could not open the invite panel on this device.")
			end
		end)
		task.delay(8, function()
			if checkDone or not alive.current then
				return nil
			end
			pcall(task.cancel, worker)
			setInviteBusy(false)
			notify("Invites unavailable", "Roblox could not open the invite panel on this device.")
		end)
	end
	local padFocus = useGamepadAutofocus(true)
	local social = state.SocialBoost or {
		FriendCount = 0,
		FriendLimit = 5,
		FriendBonus = 0,
		Premium = false,
		PremiumBonus = 0,
		Multiplier = 1,
	}
	local side = math.max(chrome.sideSafe, viewport.sideInset, 8) + 6
	local top = math.max(viewport.topInset, 36) + 8
	local bottom = math.max(chrome.bottomSafe, viewport.bottomInset, 8) + 8
	local availableHeight = math.max(210, viewport.height - top - bottom)
	local compactWidth = viewport.width < 620
	local shortSurface = availableHeight < 380
	local width = math.max(286, math.min(if compactWidth then viewport.width - side * 2 else 440, viewport.width - side * 2))
	local headerH = 64
	local boostH = if shortSurface then 54 else 68
	local actionH = if selected ~= nil and not selected.IsLocal then (if reportOpen then (if shortSurface then 168 else 188) elseif inventoryOpen then (if shortSurface then 100 else 126) else 62) else 0
	local desiredListH = math.clamp(#rows * 64, 62, if shortSurface then 144 else 316)
	local desiredHeight = headerH + boostH + desiredListH + actionH + 30
	local height = math.min(availableHeight, desiredHeight)
	local listTop = headerH + boostH + 16
	local listH = math.max(54, height - listTop - actionH - 12)
	-- On a short surface the action panel (report form / inventory) cannot share the column
	-- with the player list — the old math parked it at `height - actionH - 8`, which landed it
	-- ON TOP of the list and the friend-boost strip, and its passive background let taps fall
	-- straight through to hidden rows underneath. When it genuinely doesn't fit below the list,
	-- take over the panel body instead and hide the list until the player backs out.
	local actionCovered = shortSurface and actionH > 0 and listTop + listH + 8 + actionH > height + 1
	local actionTop = if actionCovered then headerH + 8 else height - actionH - 8
	local showAmount = composePresence(enter, exitAmount)
	local panelPosition = showAmount:map(function(amount)
		return UDim2.new(1, -(side - math.round((1 - amount) * 18)), 0, top)
	end)
	local friendProgress = math.clamp(social.FriendCount / math.max(1, social.FriendLimit), 0, 1)
	local _exp_2 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = showAmount:map(function(amount)
			return 1 - amount * 0.44
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 600,
	})
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_4 = React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1.25,
		Transparency = showAmount:map(function(amount)
			return 1 - amount * 0.76
		end),
	})
	local _exp_5 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 610,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, headerH),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 611,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(4, 30),
		Position = UDim2.fromOffset(0, 17),
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
		ZIndex = 612,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Icon, {
		kind = "Pilot",
		color = Palette.cream,
		accent = Palette.cyan,
		size = 30,
		spin = false,
		position = UDim2.fromOffset(14, 17),
	}), React.createElement(Text, {
		value = "PLAYERLIST",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(54, 8),
		sizeConstraint = UDim2.new(1, -112, 0, 24),
		zIndex = 613,
	}), React.createElement(Text, {
		value = `{#rows} ONLINE  •  PLAY TOGETHER FOR A PRODUCTION BOOST`,
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(54, 34),
		sizeConstraint = UDim2.new(1, -112, 0, 17),
		zIndex = 613,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -(TapTarget + 7), 0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 614,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.ink,
		textColor = Palette.coral,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 614,
	})))
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, boostH),
		Position = UDim2.fromOffset(10, headerH + 8),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 612,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 1,
		Transparency = 0.5,
	}), React.createElement(Text, {
		value = `FRIEND BOOST  {social.FriendCount}/{social.FriendLimit}  •  +{math.floor(social.FriendBonus * 100 + 0.5)}%`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, if shortSurface then 5 else 8),
		sizeConstraint = UDim2.new(0.58, -14, 0, 18),
		zIndex = 613,
	}), not shortSurface and React.createElement(Text, {
		value = if social.Premium then `PREMIUM +{math.floor(social.PremiumBonus * 100 + 0.5)}%` else "PREMIUM BONUS OFF",
		size = 10,
		color = if social.Premium then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, 30),
		sizeConstraint = UDim2.new(0.58, -14, 0, 16),
		zIndex = 613,
	}), not shortSurface and React.createElement("frame", {
		Size = UDim2.new(0.54, -18, 0, 4),
		Position = UDim2.fromOffset(10, 51),
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
		Size = UDim2.new(0.4, -7, 0, if shortSurface then 36 else 42),
		Position = UDim2.new(0.6, -1, 0.5, if shortSurface then -18 else -21),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 614,
	}, React.createElement(Button, {
		text = if inviteBusy then "OPENING" else "INVITE FRIENDS",
		icon = "Crew",
		onClick = invite,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = inviteBusy,
		highlight = true,
		zIndex = 614,
	})))
	local _exp_8 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#rows)
	local _callback_1 = function(row, index)
		local _attributes = {
			key = row.UserId,
			player = row,
		}
		local _exp_9 = row.UserId
		local _result_4 = selected
		if _result_4 ~= nil then
			_result_4 = _result_4.UserId
		end
		_attributes.selected = _exp_9 == _result_4
		_attributes.onSelect = function()
			setSelectedId(row.UserId)
			setInventoryOpen(false)
			setReportOpen(false)
			Audio:play("playerlistSelect")
		end
		_attributes.layoutOrder = index
		_attributes.reducedMotion = reducedMotion
		_attributes.awayStamp = awayTick
		return React.createElement(PlayerRow, _attributes)
	end
	for _k, _v in rows do
		_newValue[_k] = _callback_1(_v, _k - 1, rows)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_9 = React.createElement("scrollingframe", {
		Size = UDim2.new(1, -20, 0, listH),
		Position = UDim2.fromOffset(10, listTop),
		CanvasSize = UDim2.new(0, 0, 0, #rows * 64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = not actionCovered,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.cyan,
		ScrollBarImageTransparency = 0.32,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 619,
	}, _exp_8, _newValue)
	local _condition_1 = selected ~= nil and not selected.IsLocal and actionH > 0
	if _condition_1 then
		local _exp_10 = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 9),
		})
		local _exp_11 = React.createElement("uistroke", {
			Color = Palette.cyan,
			Thickness = 1,
			Transparency = 0.56,
		})
		local _result_4
		if reportOpen then
			local _exp_12 = React.createElement(Text, {
				value = `REPORT {string.upper(selected.DisplayName)}`,
				size = 12,
				color = Palette.coral,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 9,
				position = UDim2.fromOffset(10, 7),
				sizeConstraint = UDim2.new(1, -20, 0, 18),
				zIndex = 632,
			})
			local _exp_13 = React.createElement("uigridlayout", {
				CellSize = if shortSurface then UDim2.new(1 / 3, -4, 0, 28) else UDim2.new(0.5, -3, 0, 30),
				CellPadding = UDim2.new(0, 6, 0, 6),
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			-- ▼ ReadonlyArray.map ▼
			local _newValue_1 = table.create(#REPORT_REASONS)
			local _callback_2 = function(reason)
				return React.createElement(Button, {
					key = reason,
					text = string.upper(reason),
					onClick = function()
						setReportReason(reason)
						Audio:play("tabSwitch")
					end,
					color = if reportReason == reason then Palette.coral else Palette.panelSoft,
					textColor = if reportReason == reason then Palette.ink else Palette.creamSoft,
					outline = reportReason ~= reason,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 633,
				})
			end
			for _k, _v in REPORT_REASONS do
				_newValue_1[_k] = _callback_2(_v, _k - 1, REPORT_REASONS)
			end
			-- ▲ ReadonlyArray.map ▲
			_result_4 = React.createElement(React.Fragment, nil, _exp_12, React.createElement("frame", {
				Size = UDim2.new(1, -16, 0, if shortSurface then 62 else 108),
				Position = UDim2.fromOffset(8, 26),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 632,
			}, _exp_13, _newValue_1), React.createElement("frame", {
				Size = UDim2.new(1, -16, 0, 36),
				Position = UDim2.new(0, 8, 1, -42),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 633,
			}, React.createElement("frame", {
				Size = UDim2.new(0.4, -4, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = "BACK",
				icon = "Back",
				onClick = function()
					Audio:play("playerlistSelect")
					setReportOpen(false)
				end,
				color = Palette.panelSoft,
				textColor = Palette.creamSoft,
				outline = true,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				disabled = reportBusy,
				zIndex = 633,
			})), React.createElement("frame", {
				Size = UDim2.new(0.6, -4, 1, 0),
				Position = UDim2.new(0.4, 4, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = if reportBusy then "SENDING..." else "SEND REPORT",
				icon = "Admin",
				onClick = submitReport,
				color = Palette.coral,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				disabled = reportBusy,
				highlight = true,
				zIndex = 633,
			}))))
		else
			local _result_5
			if inventoryOpen then
				_result_5 = React.createElement(React.Fragment, nil, React.createElement(Text, {
					value = `{selected.DisplayName}'S RELICS`,
					size = 12,
					color = Palette.violet,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(10, 7),
					sizeConstraint = UDim2.new(1, -82, 0, 18),
					zIndex = 632,
				}), React.createElement(Text, {
					value = if #(selected.EquippedItems or {}) > 0 then table.concat((selected.EquippedItems or {}), ", ") else "No relics equipped.",
					size = 10,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(10, 28),
					sizeConstraint = UDim2.new(1, -20, 0, if shortSurface then 30 else 46),
					zIndex = 632,
				}), React.createElement("frame", {
					Size = UDim2.new(1, -16, 0, 36),
					Position = UDim2.new(0, 8, 1, -42),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, {
					text = "BACK TO PLAYER",
					icon = "Back",
					onClick = function()
						Audio:play("playerlistSelect")
						setInventoryOpen(false)
					end,
					color = Palette.panelSoft,
					textColor = Palette.creamSoft,
					outline = true,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 633,
				})))
			else
				local _exp_12 = React.createElement(Text, {
					value = `@{selected.Name}  •  WORLD {compactNumber(selected.CurrentZone)}  •  {compactNumber(selected.Rebirths)} REBIRTHS`,
					size = 10,
					color = Palette.cyan,
					weight = Enum.FontWeight.Bold,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(10, 5),
					sizeConstraint = UDim2.new(1, -46, 0, 16),
					zIndex = 632,
				})
				local _exp_13 = React.createElement("frame", {
					Size = UDim2.fromOffset(28, 20),
					Position = UDim2.new(1, -36, 0, 4),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 634,
				}, React.createElement(Button, {
					text = "",
					icon = "Admin",
					onClick = function()
						Audio:play("dangerPress")
						setReportOpen(true)
					end,
					color = Palette.panelSoft,
					textColor = Palette.coral,
					outline = true,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 634,
				}))
				local _attributes = {}
				local _userId = selected.UserId
				_attributes.text = if friends[_userId] ~= nil then "UNFRIEND" else "ADD FRIEND"
				_attributes.icon = "Crew"
				_attributes.onClick = function()
					return prompt("friend")
				end
				_attributes.color = Palette.blue
				_attributes.textColor = Palette.ink
				_attributes.size = UDim2.fromScale(1, 1)
				_attributes.reducedMotion = reducedMotion
				_attributes.zIndex = 633
				local _exp_14 = React.createElement("frame", {
					Size = UDim2.new(1 / 3, -7, 0, 36),
					Position = UDim2.fromOffset(8, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, _attributes))
				local _attributes_1 = {}
				local _userId_1 = selected.UserId
				_attributes_1.text = if blocked[_userId_1] ~= nil then "UNBLOCK" else "BLOCK"
				_attributes_1.icon = "Close"
				_attributes_1.onClick = function()
					return prompt("block")
				end
				_attributes_1.color = Palette.coral
				_attributes_1.textColor = Palette.ink
				_attributes_1.size = UDim2.fromScale(1, 1)
				_attributes_1.reducedMotion = reducedMotion
				_attributes_1.zIndex = 633
				_result_5 = React.createElement(React.Fragment, nil, _exp_12, _exp_13, _exp_14, React.createElement("frame", {
					Size = UDim2.new(1 / 3, -7, 0, 36),
					Position = UDim2.new(1 / 3, 4, 0, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, _attributes_1)), React.createElement("frame", {
					Size = UDim2.new(1 / 3, -7, 0, 36),
					Position = UDim2.new(2 / 3, 3, 0, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, {
					text = "RELICS",
					icon = "Inventory",
					onClick = function()
						Audio:play("playerlistAction")
						setInventoryOpen(true)
					end,
					color = Palette.violet,
					textColor = Palette.cream,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 633,
				})))
			end
			_result_4 = _result_5
		end
		_condition_1 = React.createElement("frame", {
			Size = UDim2.new(1, -20, 0, if actionCovered then math.max(actionH, height - headerH - 16) else actionH),
			Position = UDim2.fromOffset(10, actionTop),
			BackgroundColor3 = Palette.panelRaised,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 630,
		}, _exp_10, _exp_11, _result_4)
	end
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
	}, _exp_2, React.createElement("frame", {
		ref = padFocus,
		Size = UDim2.fromOffset(width, height),
		Position = panelPosition,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = showAmount:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 610,
		Visible = showAmount:map(function(amount)
			return amount > 0.005
		end),
	}, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _exp_9, _condition_1)))
end
return {
	PlayerlistOverlay = PlayerlistOverlay,
}
end

-- ======================================================================
-- Module: onboarding   (merged from onboarding.luau, 1001 lines)
-- ======================================================================
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
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = __load("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local OverlayPresence = _ui.OverlayPresence
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local function TutorialOverlay(_param)
	local copy = _param.copy
	local step = _param.step
	local count = _param.count
	local viewportWidth = _param.viewportWidth
	local reducedMotion = _param.reducedMotion
	local ctaLabel = _param.ctaLabel
	local onCta = _param.onCta
	local onNext = _param.onNext
	local onBack = _param.onBack
	local onSkip = _param.onSkip
	local onJump = _param.onJump
	local viewport = useViewport()
	React.useEffect(function()
		Audio:play("modalOpen")
	end, {})
	React.useEffect(function()
		if step > 1 then
			Audio:play("tutorialStep")
		end
	end, { step })
	local sideInset = math.max(10, viewport.sideInset)
	local bottomInset = math.max(12, viewport.bottomInset)
	local phone = viewport.width < 720 or viewport.height < 560
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local dockW = math.min(if phone then viewportWidth - sideInset * 2 else 560, viewportWidth - sideInset * 2)
	local hasCta = ctaLabel ~= nil and onCta ~= nil
	local hasGoal = copy.goal ~= nil and copy.goal ~= ""
	local hasHint = copy.hint ~= nil and copy.hint ~= ""
	local hasControls = copy.controls ~= nil and copy.controls ~= ""
	local live = _param.live
	if type(live) ~= "table" then
		live = {}
	end
	local watch = copy.watch
	local vaultNow = live.vaultFlux
	if type(vaultNow) ~= "number" then
		vaultNow = 0
	end
	local collected, setCollected = React.useState(false)
	local vaultMark = React.useRef(vaultNow)
	React.useEffect(function()
		setCollected(false)
		vaultMark.current = vaultNow
	end, { step })
	React.useEffect(function()
		if watch == "collect" and vaultNow < vaultMark.current - 0.5 then
			setCollected(true)
		end
	end, { step, vaultNow, watch })
	local ownedMachines = live.ownedMachines
	if type(ownedMachines) ~= "number" then
		ownedMachines = 0
	end
	local buyAmount = live.buyAmount
	if type(buyAmount) ~= "number" then
		buyAmount = 1
	end
	local here = live.page
	local goalMet = watch == "finish"
	if watch == "vault" then
		goalMet = here == "Overview"
	elseif watch == "collect" then
		goalMet = collected
	elseif watch == "workshop" then
		goalMet = here == "Workshop"
	elseif watch == "buy" then
		goalMet = ownedMachines > 0
	elseif watch == "amount" then
		goalMet = buyAmount ~= 1
	elseif watch == "research" then
		goalMet = here == "Research"
	elseif watch == "rebirth" then
		goalMet = here == "Overview"
	end
	local liveText = `Stored Flux {live.vault or "0"}  ·  {live.production or "0"} / sec`
	if watch == "workshop" or watch == "buy" or watch == "amount" then
		liveText = `MACHINES {ownedMachines}  ·  BUY x{buyAmount}  ·  {here or "Workshop"}`
	elseif watch == "research" or watch == "rebirth" or watch == "finish" then
		liveText = `{here or "Overview"}  ·  {live.production or "0"} / sec`
	end
	local beat = usePulse(not reducedMotion, if goalMet then 1.15 else 1.7)
	local progress = math.clamp((step - (if goalMet then 0 else 0.45)) / math.max(1, count), 0.08, 1)
	local dockH = (if phone then 212 else 198) + (if hasGoal then 18 else 0) + (if hasHint then 18 else 0) + (if hasControls then 16 else 0) + (if hasCta then TapTarget + 8 else 0)
	local nextLabel = if step >= count then "FINISH" else "CONTINUE"
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
	local onBackRef = React.useRef(onBack)
	local onCtaRef = React.useRef(onCta)
	local requestNextRef = React.useRef(requestNext)
	local stepRef = React.useRef(step)
	local exitingRef = React.useRef(exiting)
	local hasCtaRef = React.useRef(hasCta)
	onBackRef.current = onBack
	onCtaRef.current = onCta
	requestNextRef.current = requestNext
	stepRef.current = step
	exitingRef.current = exiting
	hasCtaRef.current = hasCta
	React.useEffect(function()
		local actionName = "AstralForgeTutorialBack"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin and stepRef.current > 1 and not exitingRef.current then
				onBackRef.current()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, {})
	React.useEffect(function()
		local actionName = "AstralForgeTutorialConfirm"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin and not exitingRef.current then
				if hasCtaRef.current and onCtaRef.current ~= nil then
					onCtaRef.current()
				else
					requestNextRef.current()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonA)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, {})
	local bodyTop = if hasGoal then 72 else 54
	local hintTop = bodyTop + (if phone then 42 else 36)
	local controlsTop = hintTop + (if hasHint then 18 else 0)
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
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local _exp_1 = table.create(count, 0)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_1)
	local _callback = function(_, index)
		local n = index + 1
		local active = n == step
		local done = n < step
		return React.createElement("imagebutton", {
			key = `step-{n}`,
			Size = UDim2.fromOffset(if active then 34 else 24, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = not exiting,
			Selectable = not exiting,
			LayoutOrder = n,
			Event = {
				Activated = function()
					if not exiting and n ~= step then
						onJump(n)
					end
				end,
			},
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(if active then 28 else 18, 18),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if active then Palette.mint elseif done then Palette.cyan else Palette.panelSoft,
			BackgroundTransparency = if active then 0 elseif done then 0.15 else 0.2,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), active and React.createElement(Text, {
			value = tostring(n),
			size = 10,
			color = Palette.ink,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.fromScale(1, 1),
		})))
	end
	for _k, _v in _exp_1 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_1)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 300,
		Visible = reveal:map(function(amount)
			return amount > 0.015
		end),
	}, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.new(0, dockW, 0, dockH),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 1, -(bottomInset + 10) + math.floor((1 - amount) * 24))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 310,
		Active = true,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = if phone then 12 else 14,
		zIndex = 310,
		reveal = reveal,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -92, 0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 312,
	}, _exp, _newValue), React.createElement(Text, {
		value = `{step} / {count}`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -88, 0, 2),
		sizeConstraint = UDim2.fromOffset(88, 18),
		zIndex = 312,
	}), React.createElement(Text, {
		value = copy.title,
		size = if phone then 18 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
		zIndex = 312,
	}), hasGoal and React.createElement(Text, {
		value = `GOAL · {copy.goal}`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 312,
	}), React.createElement(Text, {
		value = copy.body,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, bodyTop),
		sizeConstraint = UDim2.new(1, 0, 0, if phone then 40 else 34),
		zIndex = 312,
	}), hasHint and React.createElement(Text, {
		value = copy.hint,
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, hintTop),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 312,
	}), hasControls and React.createElement(Text, {
		value = copy.controls,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, controlsTop),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		zIndex = 312,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 1, -((if hasCta then TapTarget * 2 + 8 else TapTarget) + 32)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 313,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = 313,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromScale(progress, 1),
		BackgroundColor3 = if goalMet then Palette.mint else Palette.cyan,
		BackgroundTransparency = beat:map(function(amount)
			return if goalMet then 0.05 else 0.2 + (1 - amount) * 0.35
		end),
		BorderSizePixel = 0,
		ZIndex = 314,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement(Text, {
		value = if goalMet then `READY  ·  {liveText}` else liveText,
		size = 11,
		color = if goalMet then Palette.mint else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 8),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 314,
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if hasCta then TapTarget * 2 + 8 else TapTarget),
		Position = UDim2.new(0, 0, 1, -(if hasCta then TapTarget * 2 + 8 else TapTarget)),
		BackgroundTransparency = 1,
		ZIndex = 312,
	}, hasCta and React.createElement(Button, {
		text = if goalMet and (watch == "workshop" or watch == "buy") then "YOU'RE IN WORKSHOP" elseif goalMet and watch == "collect" then "VAULT CASHED" elseif goalMet and watch == "research" then "RESEARCH IS OPEN" else ctaLabel,
		onClick = if goalMet and (watch == "collect" or watch == "workshop" or watch == "buy" or watch == "research") then requestNext else onCta,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = exiting,
		highlight = true,
		zIndex = 312,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.fromOffset(0, if hasCta then TapTarget + 8 else 0),
		BackgroundTransparency = 1,
		ZIndex = 312,
	}, React.createElement(Button, {
		text = "SKIP",
		onClick = requestSkip,
		sound = "close",
		color = Palette.panelSoft,
		textColor = Palette.muted,
		size = UDim2.new(0.22, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 312,
	}), React.createElement(Button, {
		text = "BACK",
		onClick = onBack,
		sound = "tutorialStep",
		disabled = step <= 1 or exiting,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(0.26, -4, 1, 0),
		position = UDim2.new(0.22, 2, 0, 0),
		reducedMotion = reducedMotion,
		zIndex = 312,
	}), React.createElement(Button, {
		text = if goalMet and step < count then "CONTINUE" else nextLabel,
		onClick = requestNext,
		sound = if step >= count then "tutorialFinish" else "tutorialStep",
		color = if goalMet or not hasCta then Palette.mint else Palette.panelSoft,
		textColor = if goalMet or not hasCta then Palette.ink else Palette.cream,
		size = UDim2.new(0.52, -2, 1, 0),
		position = UDim2.new(0.48, 4, 0, 0),
		reducedMotion = reducedMotion,
		disabled = exiting,
		highlight = goalMet or not hasCta,
		zIndex = 312,
	})))))))
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
		-- ▼ ReadonlyArray.map ▼
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
		-- ▲ ReadonlyArray.map ▲
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
				-- ▼ ReadonlyArray.filter ▼
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
				-- ▲ ReadonlyArray.filter ▲
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
	-- ▼ ReadonlyArray.reduce ▼
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
	-- ▲ ReadonlyArray.reduce ▲
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
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
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

-- ======================================================================
-- Module: AdminPrankOverlay   (merged from AdminPrankOverlay.luau, 468 lines)
-- ======================================================================
__defs["AdminPrankOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AdminPrankOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local kind = _condition
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AdminPrankOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
		body = "0 / 100 bag. No relics. This is a fake empty-bag card — your relics are still there.",
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

-- ======================================================================
-- Module: notifications   (merged from notifications.luau, 721 lines)
-- ======================================================================
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
local MotionTokens = require(script.Parent.MotionKit)("motionTokens")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local ensureContrast = _theme.ensureContrast
local Breakpoints = _theme.Breakpoints
local Layout = _theme.Layout
local _ui = __load("ui")
local Stroke = _ui.Stroke
local Text = _ui.Text
local NOTICE_LIFETIME = 4.2
local NOTICE_EXIT_SECONDS = 0.24
local SWIPE_DISMISS_PX = 56
-- A dragged card springs home: about a third of a second, no wobble.
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
local CARD_HEIGHT = 46
local CARD_HEIGHT_MOBILE = 48
local CARD_GAP = 6
local CARD_GAP_MOBILE = 6
local RAIL_WIDTH = 268
local RAIL_WIDTH_MOBILE = 236
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
	local titleSize = if props.compact then 11 else 12
	local bodySize = if props.compact then 10 else 11
	local dismiss = if props.touch then 28 else 20
	local iconSize = 20
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
	React.useEffect(function()
		if not visible or notice.sound == false then
			return nil
		end
		Audio:play(toneCue(notice.tone))
	end, { notice.sound, notice.tone, visible })
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			local state = drag.current
			if state.mode ~= "return" or leavingRef.current then
				return nil
			end
			-- Exact spring step: the card eases home the same at any frame rate.
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
	local progress = useFlipperSpring(if visible then 1 else 0, props.reducedMotion, if visible then 460 else 820, if visible then 32 else 42)
	local hover = useFlipperSpring(if hovered and visible then 1 else 0, props.reducedMotion, 640, 38)
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
		return if leavingRef.current then 0 else math.round((1 - math.clamp(shown, 0, 1)) * 22)
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
		return math.round(-amount)
	end)
	local cardPosition = React.joinBindings({ enterX, swipeX, lift }):map(function(values)
		return UDim2.new(0.5, math.round(values[1] + values[2]), 0.5, values[3])
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
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = fade:map(function(amount)
			return 0.62 + amount * 0.38
		end),
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		BackgroundColor3 = color,
		BackgroundTransparency = fade:map(function(amount)
			return 0.18 + amount
		end),
		BorderSizePixel = 0,
		ZIndex = 102,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = UDim2.fromOffset(14, math.floor((cardH - iconSize) / 2)),
		BackgroundColor3 = color,
		BackgroundTransparency = fade:map(function(amount)
			return 0.82 + amount * 0.18
		end),
		BorderSizePixel = 0,
		ZIndex = 103,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement(Icon, {
		kind = toneIcon(notice.tone),
		color = color,
		accent = color,
		size = iconSize,
		spin = false,
		reducedMotion = props.reducedMotion,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), React.createElement(Text, {
		value = string.upper(notice.title),
		size = titleSize,
		color = titleColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(40, if hasBody then 6 else 0),
		sizeConstraint = UDim2.new(1, -(dismiss + 50), 0, if hasBody then 16 else cardH),
		zIndex = 105,
	}), hasBody and React.createElement("textlabel", {
		Size = UDim2.new(1, -(dismiss + 50), 0, 16),
		Position = UDim2.fromOffset(40, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Text = notice.body,
		TextColor3 = bodyColor,
		TextTransparency = fade:map(function(amount)
			return 0.12 + amount
		end),
		TextSize = bodySize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 105,
	}, React.createElement("uitextsizeconstraint", {
		MinTextSize = 9,
		MaxTextSize = bodySize,
	})), count > 1 and React.createElement("frame", {
		Size = UDim2.fromOffset(24, 16),
		Position = UDim2.new(1, -(dismiss + 30), 0, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 106,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Text, {
		value = `×{count}`,
		size = 9,
		color = Palette.ink,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 107,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -12, 0, 2),
		Position = UDim2.new(0, 6, 1, -5),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = fade:map(function(amount)
			return 0.55 + amount * 0.45
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
			return 0.08 + amount
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("imagebutton", {
		Size = UDim2.fromOffset(dismiss, dismiss),
		Position = UDim2.new(1, if props.touch then -4 else -6, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
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
	}, React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "×",
		TextColor3 = if hovered then color else mutedX,
		TextTransparency = fade,
		TextSize = if props.touch then 16 else 14,
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
	local maxVisible = math.max(1, math.min(requestedVisible, fittingVisible, if stack then MAX_VISIBLE_MOBILE + 1 else MAX_VISIBLE + 2))
	local railHeight = maxVisible * (cardH + cardGap)
	local minX = (plan.sideSafe + 8 + railW / 2) / width
	local maxX = math.max(minX, 1 - minX)
	local minY = topInset / height
	local maxY = math.max(minY, (height - bottomReserve - railHeight - 8) / height)
	local customX = if mobileLayout ~= nil then math.clamp(mobileLayout.x, minX, maxX) else 0.5
	local customY = if mobileLayout ~= nil then math.clamp(mobileLayout.y, minY, maxY) else minY
	-- ▼ ReadonlyArray.filter ▼
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
	-- ▲ ReadonlyArray.filter ▲
	local live = _newValue
	local _result
	if #live > maxVisible then
		-- ▼ ReadonlyArray.filter ▼
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
		-- ▲ ReadonlyArray.filter ▲
		_result = _newValue_1
	else
		_result = live
	end
	local visible = _result
	local _exp = function()
		local entries = {}
		-- ▼ ReadonlyArray.forEach ▼
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
		-- ▲ ReadonlyArray.forEach ▲
		return entries
	end
	local _result_1 = mobileLayout
	if _result_1 ~= nil then
		_result_1 = _result_1.opacity
	end
	local rendered = React.useMemo(_exp, { _result_1, plan.mobile, reducedMotion, remove, setHovered, stack, visible })
	local hiddenCount = math.max(0, #live - maxVisible)
	local useCustom = mobileLayout ~= nil
	-- Desktop notices sit at the bottom of the nav column so they don't cover
	-- the page's right-hand stats or the goal badge.
	local defaultPosition = if stack
		then UDim2.new(0.5, 0, 1, -(plan.tabBarH + plan.bottomSafe + 14))
		else UDim2.new(0, Layout.sidebarWidth + 16, 1, -(plan.bottomSafe + 16))
	local defaultAnchor = if stack then Vector2.new(0.5, 1) else Vector2.new(0, 1)
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
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
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

-- ======================================================================
-- Module: CreditsView   (merged from pages/CreditsView.luau, 530 lines)
-- ======================================================================
__defs["CreditsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local _ui = __load("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local PageScaffold = require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local DEV_USERNAME = "usingINales"
local DEV_USER_ID = 10916707683
local function DevAvatarThumbnail(_param)
	local size = _param.size
	return React.createElement("imagelabel", {
		Size = size,
		BackgroundColor3 = darken(Palette.violet, 0.62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarBust&id={DEV_USER_ID}&w=420&h=420`,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 330,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		Color = Palette.violet,
		Thickness = 1.5,
		Transparency = 0.28,
	}))
end
local ROLES = { {
	label = "Design",
	detail = "Loops, screens, and Bay Seven tone",
}, {
	label = "Code",
	detail = "Client, server, and economy",
}, {
	label = "World",
	detail = "Story, missions, and docks",
} }
local function CreditsOverlay(_param)
	local version = _param.version
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — CreditsView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local headerReveal = useStagger(0, softMotion)
	local rolesReveal = useStagger(1, softMotion)
	-- Canonical softMotion antilag gate — CreditsRoles.
	local thanksReveal = useStagger(2, softMotion)
	-- Canonical softMotion antilag gate — CreditsThanks.
	local closingReveal = useStagger(3, softMotion)
	-- Canonical softMotion antilag gate — CreditsClose.
	local brandReveal = useStagger(4, softMotion)
	local _binding = useExitTransition(softMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	-- Prefer reducedMotion stagger when antilag already wants quiet decoration.
	local panelReveal = if softMotion then headerReveal else reveal
	local listReveal = if softMotion then rolesReveal else reveal
	local thanksSoft = softMotion or thanksReveal == nil or closingReveal == nil or brandReveal == nil
	local rolesSoft = softMotion or listReveal == nil
	local requestClose = React.useCallback(function()
		if exiting then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, exiting, onClose })
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local pad = if stack then 14 else 22
	local safeSide = math.max(8, viewport.sideInset, chrome.sideSafe)
	local safeTop = math.max(8, viewport.topInset)
	local safeBottom = math.max(8, viewport.bottomInset, chrome.bottomSafe)
	local availableWidth = math.max(220, viewport.width - safeSide * 2 - 12)
	local width = math.min(if stack then 600 else 620, availableWidth)
	local desired = if stack then 520 else 460
	local availableHeight = math.max(220, viewport.height - safeTop - safeBottom - 12)
	local height = math.min(desired, availableHeight)
	local centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2)
	local avatarSize = if stack then math.min(160, math.floor(width - pad * 2 - 8)) else 188
	local closeSize = math.max(TapTarget - 4, 44)
	local stackBodyTop = 70
	local stackBodyReserve = closeSize + 16
	local stackBodyH = math.max(120, height - pad * 2 - stackBodyTop - stackBodyReserve)
	local rolesListH = 132
	local avatarBlockH = avatarSize + 8 + 28 + 8 + 28 + 8 + 48
	local attributionH = 20
	React.useEffect(function()
		ClientLog:debug("nav", "credits opened")
		return function()
			return ClientLog:debug("nav", "credits closed")
		end
	end, {})
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
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 319,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 320,
	})
	local _exp_2 = React.createElement(Text, {
		value = "CREDITS",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 16),
		zIndex = 322,
	})
	local _exp_3 = React.createElement(Text, {
		value = "ASTRAL FORGE",
		size = if stack then 20 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 32),
		zIndex = 322,
	})
	local _exp_4 = React.createElement(Text, {
		value = `VERSION {version}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 14),
		zIndex = 322,
	})
	local _exp_5 = React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromOffset(closeSize, closeSize),
		position = UDim2.new(1, -closeSize, 0, 0),
		reducedMotion = rolesSoft,
		disabled = exiting,
		zIndex = 323,
	})
	local _result
	if stack then
		local avatarBlock = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(avatarSize, avatarSize),
			Position = UDim2.fromOffset(math.floor((width - pad * 2 - avatarSize) / 2), 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, React.createElement(DevAvatarThumbnail, {
			size = UDim2.fromScale(1, 1),
		})), React.createElement(Badge, {
			value = "SOLO DEV",
			accent = Palette.violet,
			filled = true,
			size = UDim2.fromOffset(110, 28),
			position = UDim2.fromOffset(math.floor((width - pad * 2 - 110) / 2), avatarSize + 8),
			zIndex = 322,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, avatarSize + 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = DEV_USERNAME,
			TextColor3 = Palette.cream,
			TextSize = 18,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 322,
		}), React.createElement(Text, {
			value = "Thanks for playing. Built solo — machines, worlds, and stories included.",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, avatarSize + 72),
			sizeConstraint = UDim2.new(1, 0, 0, 48),
			zIndex = 322,
		}))
		local _exp_10 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#ROLES)
		local _callback = function(role, index)
			return React.createElement("frame", {
				key = role.label,
				Size = UDim2.new(1, 0, 0, 38),
				LayoutOrder = index,
				BackgroundColor3 = Palette.panel,
				BorderSizePixel = 0,
				ZIndex = 322,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 8),
			}), React.createElement(Text, {
				value = role.label,
				size = 11,
				color = Palette.violet,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(10, 4),
				sizeConstraint = UDim2.new(1, -20, 0, 14),
				zIndex = 323,
			}), React.createElement(Text, {
				value = role.detail,
				size = 11,
				color = Palette.creamSoft,
				wrap = true,
				fit = false,
				position = UDim2.fromOffset(10, 18),
				sizeConstraint = UDim2.new(1, -20, 0, 16),
				zIndex = 323,
			}))
		end
		for _k, _v in ROLES do
			_newValue[_k] = _callback(_v, _k - 1, ROLES)
		end
		-- ▲ ReadonlyArray.map ▲
		local rolesBlock = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, _exp_10, _newValue)
		local attribution = React.createElement(Text, {
			value = "Interface icons by Flaticon / Freepik Company",
			size = 9,
			color = Palette.muted,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 16),
			zIndex = 322,
		})
		_result = React.createElement(PageScaffold, {
			size = UDim2.new(1, 0, 0, stackBodyH),
			position = UDim2.fromOffset(0, stackBodyTop),
			gap = 8,
			tailPad = 4,
			scrollBarColor = Palette.violet,
			scrollBarThickness = 3,
			zIndex = 322,
			sections = {
				{
					id = "avatar",
					height = avatarBlockH,
					element = avatarBlock,
				},
				{
					id = "roles",
					height = rolesListH,
					element = rolesBlock,
				},
				{
					id = "attribution",
					height = attributionH,
					element = attribution,
				},
			},
		})
	else
		local _exp_6 = React.createElement("frame", {
			Size = UDim2.fromOffset(avatarSize, avatarSize),
			Position = UDim2.fromOffset(0, 78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, React.createElement(DevAvatarThumbnail, {
			size = UDim2.fromScale(1, 1),
		}))
		local _exp_7 = React.createElement(Badge, {
			value = "SOLO DEV",
			accent = Palette.violet,
			filled = true,
			size = UDim2.fromOffset(110, 28),
			position = UDim2.fromOffset(avatarSize + 20, 78),
			zIndex = 322,
		})
		local _exp_8 = React.createElement("textlabel", {
			Size = UDim2.new(1, -(avatarSize + 28), 0, 34),
			Position = UDim2.fromOffset(avatarSize + 20, 110),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = DEV_USERNAME,
			TextColor3 = Palette.cream,
			TextSize = 26,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 322,
		})
		local _exp_9 = React.createElement(Text, {
			value = "Built solo · code · UI · game design",
			size = 13,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(avatarSize + 20, 148),
			sizeConstraint = UDim2.new(1, -(avatarSize + 28), 0, 36),
			zIndex = 322,
		})
		local _exp_10 = React.createElement(Text, {
			value = "One person built the forge you're running. Thanks for playing.",
			size = 13,
			color = Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(avatarSize + 20, 188),
			sizeConstraint = UDim2.new(1, -(avatarSize + 28), 0, 44),
			zIndex = 322,
		})
		local _exp_11 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#ROLES)
		local _callback = function(role, index)
			return React.createElement("frame", {
				key = role.label,
				Size = UDim2.new(1 / 3, -8, 0, 112),
				LayoutOrder = index,
				BackgroundColor3 = Palette.panel,
				BorderSizePixel = 0,
				ZIndex = 322,
				ClipsDescendants = false,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 12),
			}), React.createElement("uistroke", {
				Color = lighten(Palette.violet, 0.1),
				Thickness = 1,
				Transparency = 0.55,
			}), React.createElement(Text, {
				value = string.upper(role.label),
				size = 10,
				color = Palette.violet,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(12, 14),
				sizeConstraint = UDim2.new(1, -24, 0, 16),
				zIndex = 323,
			}), React.createElement(Text, {
				value = role.detail,
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				fit = false,
				position = UDim2.fromOffset(12, 36),
				sizeConstraint = UDim2.new(1, -24, 0, 60),
				zIndex = 323,
			}))
		end
		for _k, _v in ROLES do
			_newValue[_k] = _callback(_v, _k - 1, ROLES)
		end
		-- ▲ ReadonlyArray.map ▲
		local desktopBody = React.createElement(React.Fragment, nil, _exp_6, _exp_7, _exp_8, _exp_9, _exp_10, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 112),
			Position = UDim2.fromOffset(0, 78 + avatarSize + 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, _exp_11, _newValue), React.createElement(Text, {
			value = "Interface icons by Flaticon / Freepik Company",
			size = 9,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(0, 400),
			sizeConstraint = UDim2.new(1, 0, 0, 14),
			zIndex = 322,
		}))
		-- Desktop fits without nested scroll; still mount PageScaffold so HOT_PAGES stays honest.
		_result = React.createElement(PageScaffold, {
			size = UDim2.fromScale(1, 1),
			gap = 0,
			tailPad = 0,
			scrollBarThickness = 0,
			scrollBarColor = Palette.violet,
			zIndex = 322,
			sections = {
				{
					id = "desktop",
					fill = true,
					minHeight = 420,
					height = 420,
					element = desktopBody,
				},
			},
		})
	end
	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		-- FocusClaim prefers Claim-named hosts; CLOSE is the primary Credits CTA.
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
	}, _exp, React.createElement("frame", {
		ref = padFocus,
		Size = UDim2.fromOffset(width, height),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 0, centerY + math.floor((1 - amount) * 18))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 320,
		Visible = reveal:map(function(amount)
			return amount > 0.002
		end),
	}, _exp_1, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = pad,
		zIndex = 321,
		clips = false,
		reveal = panelReveal,
		reducedMotion = softMotion,
		highlight = not softMotion and not thanksSoft,
	}, _exp_2, _exp_3, _exp_4, _exp_5, _result, stack and React.createElement("frame", {
		Size = UDim2.fromOffset(0, closeSize),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -2),
		BackgroundTransparency = 1,
		ZIndex = 323,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "CLOSE",
		icon = "Close",
		onClick = requestClose,
		color = Palette.violet,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, closeSize),
		hug = true,
		reducedMotion = softMotion,
		disabled = exiting,
		zIndex = 324,
	}))))))
end
return {
	CreditsOverlay = CreditsOverlay,
}
end

-- ======================================================================
-- Module: CrateRevealOverlay   (merged from pages/CrateRevealOverlay.luau, 732 lines)
-- ======================================================================
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
local CrateRevealStage = __load("CrateRevealStageSimple").CrateRevealStage
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
	-- ▼ ReadonlyArray.find ▼
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
	-- ▲ ReadonlyArray.find ▲
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
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	-- Every display frame: capping the reel at 60 made it judder on 120/144 Hz
	-- screens next to the rest of the interface. The cap only stops sub-frame
	-- double updates now.
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
	-- Soft boat tweens on antilag tiers avoid Flipper spring chatter during claim/earn moments.
	local motionScale = if reducedMotion then 0.55 else 1
	local boatShow = useBoatTween(if present then 1 else 0, (if present then 0.3 else EXIT_SETTLE) * motionScale, false, easeOutCubic, 0)
	local showSpring = useFlipperSpring(if present then 1 else 0, false, 720, 36)
	local showBoat = useBoatTween(if present then 1 else 0, (if present then 0.28 else EXIT_SETTLE) * motionScale, false, easeOutCubic, 0)
	local show = showSpring
	local landHold = phase == "land" or phase == "done" or phase == "exit"
	local claimHold = phase == "done" or phase == "exit"
	local landPopSpring = useFlipperSpring(if landHold then 1 else 0, false, 640, 14)
	local landPopBoat = useBoatTween(if landHold then 1 else 0, 0.22 * motionScale, false, easeOutCubic, 0)
	local landPop = landPopSpring
	local claimSlideSpring = useFlipperSpring(if claimHold then 1 else 0, false, 520, 24)
	local claimSlideBoat = useBoatTween(if claimHold then 1 else 0, 0.2 * motionScale, false, easeOutCubic, 0)
	local claimSlide = claimSlideSpring
	local landFlash = useFlash(if phase == "land" then rollIndex + 1 else 0, false, 0.62 * motionScale)
	-- Claim CTA flash — intentional polish without noisy springs on low tiers.
	local claimFlash = useFlash(if phase == "done" then rollIndex + 11 else 0, false, 0.48 * motionScale)
	local chargePulseSpring = useFlipperSpring(if phase == "charge" then 1 else 0, false, 360, 19)
	local chargePulseBoat = useBoatTween(if phase == "charge" then 1 else 0, 0.18 * motionScale, false, easeOutCubic, 0)
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
		local job = task.delay(if reducedMotion then 0.28 else 0.48, function()
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
		setPhase("land")
		if currentRoll ~= nil then
			local mythic = currentRoll.Rarity == "Mythic"
			local special = currentRoll.New == true or currentRoll.Pity == true or currentRoll.Rarity == "Legendary" or mythic
			if mythic then
				Audio:playCelebration({ "crateRare", "discovery", "reward" }, 0.08)
			else
				Audio:play(if special then "crateRare" else "crateLand")
			end
		else
			Audio:play("crateLand")
		end
		InteractionFeedback.reward()
	end, { currentRoll, setOffset, setSpinEnergy, setSpinProgress, setTickEnergy })
	local skipSpin = React.useCallback(function()
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
		local job = task.delay(if rollIndex >= #rolls - 1 then 0.72 else 0.62, function()
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
				if phase == "spin" then
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
			if phase == "spin" then
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
	-- ▼ ReadonlyArray.every ▼
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
	-- ▲ ReadonlyArray.every ▲
	local claimText = if _result_1 then "BANK ESSENCE" elseif count == 1 then "CLAIM RELIC" else `CLAIM {count} DROPS`
	local visualShow = React.joinBindings({ show, boatShow, exitAmount }):map(function(values)
		return math.clamp(math.min(values[1], values[2], values[3]), 0, 1)
	end)
	local winnerCardScale = React.joinBindings({ landPop, landFlash, claimFlash }):map(function(values)
		return 0.94 + values[1] * 0.075 + values[2] * 0.025 + values[3] * 0.02
	end)
	return React.createElement(CrateRevealStage, {
		crateName = session.crateName,
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
		-- FocusClaim CLAIM CTA must not clip overshoot (Stage/StageSimple already false).
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

-- ======================================================================
-- Module: CrateRevealStageSimple   (merged from pages/CrateRevealStageSimple.luau, 392 lines)
-- ======================================================================
__defs["CrateRevealStageSimple"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local _ui = __load("ui")
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
