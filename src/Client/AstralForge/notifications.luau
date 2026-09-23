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
local Audio = require(script.Parent.audio).Audio
local Icon = require(script.Parent.Icon).Icon
local usesDesktopStructure = require(script.Parent.interaction).usesDesktopStructure
local planMobileLayout = require(script.Parent.mobileLayout).planMobileLayout
local _motion = require(script.Parent.motion)
local useClock = _motion.useClock
local useFlipperSpring = _motion.useFlipperSpring
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local ensureContrast = _theme.ensureContrast
local Breakpoints = _theme.Breakpoints
local Layout = _theme.Layout
local _ui = require(script.Parent.ui)
local Stroke = _ui.Stroke
local Text = _ui.Text
local NOTICE_LIFETIME = 4.2
local NOTICE_EXIT_SECONDS = 0.24
local SWIPE_DISMISS_PX = 56
local SWIPE_RETURN_STIFFNESS = 420
local SWIPE_RETURN_DAMPING = 28
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
		local job = task.defer(function()
			return setEntered(true)
		end)
		return function()
			return task.cancel(job)
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
			local accel = -SWIPE_RETURN_STIFFNESS * state.x - SWIPE_RETURN_DAMPING * state.v
			state.v += accel * dt
			state.x += state.v * dt
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
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = color,
		Thickness = 1,
		Transparency = fade:map(function(amount)
			return 0.5 + amount * 0.5
		end),
	}), React.createElement("frame", {
		Size = UDim2.new(0, 4, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = color,
		BackgroundTransparency = fade,
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
		CornerRadius = UDim.new(0, 6),
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
		Text = notice.body,
		TextColor3 = bodyColor,
		TextTransparency = fade:map(function(amount)
			return 0.12 + amount
		end),
		TextSize = bodySize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 105,
	}), count > 1 and React.createElement("frame", {
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
	local railW = (if stack then math.min(RAIL_WIDTH_MOBILE, math.max(220, width - plan.sideSafe * 2 - 24)) else RAIL_WIDTH) * layoutScale
	local cardH = if stack then CARD_HEIGHT_MOBILE else CARD_HEIGHT
	local cardGap = if stack then CARD_GAP_MOBILE else CARD_GAP
	local topInset = math.max(topbarInset, Layout.minTopInset) + (if stack then plan.topbarRows + 12 else Layout.topbarClearance + 12)
	local keyboardOpen = UserInputService.TouchEnabled and UserInputService.OnScreenKeyboardVisible
	local requestedVisible = if keyboardOpen then 1 else (if stack then MAX_VISIBLE_MOBILE else MAX_VISIBLE)
	local fittingVisible = math.max(1, math.floor((height - topInset - plan.bottomSafe - plan.tabBarH - 8) / math.max(1, cardH + cardGap)))
	local maxVisible = math.max(1, math.min(requestedVisible, fittingVisible))
	local railHeight = maxVisible * (cardH + cardGap)
	local minX = (plan.sideSafe + 8 + railW / 2) / width
	local maxX = math.max(minX, 1 - minX)
	local minY = topInset / height
	local maxY = math.max(minY, (height - plan.bottomSafe - plan.tabBarH - railHeight - 12) / height)
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
	local defaultPosition = if stack then UDim2.new(0.5, 0, 1, -(plan.tabBarH + plan.bottomSafe + 16)) else UDim2.new(1, -20, 1, -(plan.bottomSafe + 28))
	local defaultAnchor = if stack then Vector2.new(0.5, 1) else Vector2.new(1, 1)
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
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 249,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Stroke, {
		color = Palette.lineSoft,
		thickness = 1,
		transparency = 0.5,
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
