local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Audio = require(script.Parent.audio).Audio
local Icon = require(script.Parent.Icon).Icon
local createFlipperMotor = require(script.Parent.motion).createFlipperMotor
local useViewport = require(script.Parent.motion).useViewport
local useClientSelector = require(script.Parent.clientStore).useClientSelector
local Text = require(script.Parent.ui).Text
local chromeFor = require(script.Parent.theme).chromeFor
local Palette = require(script.Parent.theme).Palette
local surfaceGradient = require(script.Parent.theme).surfaceGradient

local SCREEN_NAME = "AstralForgeStudioUI"
local DOCK_GAP = 14
local SAFE_EDGE = 24
local PULSE_SECONDS = 0.16
local SPLIT_OFFSET = 0.03
local TRAVEL_STIFFNESS = 340
local TRAVEL_DAMPING = 46

local LEFT_DOCK = {
	{ key = "Overview", pageId = "Overview", label = "Overview", icon = "Overview" },
	{ key = "Workshop", pageId = "Workshop", label = "Workshop", icon = "Forge" },
	{ key = "StarGrid", pageId = "StarGrid", label = "Star Grid", icon = "StarGrid" },
	{ key = "Continuum", pageId = "Continuum", label = "Next Rank", icon = "Continuum" },
	{ key = "Missions", pageId = "Missions", label = "Missions", icon = "Mission" },
	{ key = "Rebirth", pageId = "Overview", label = "Rebirth", icon = "Rebirth" },
}

local RIGHT_DOCK = {
	{ key = "Shop", pageId = "Shop", label = "Shop", icon = "Shop" },
	{ key = "Rewards", pageId = "Rewards", label = "Rewards", icon = "Crate" },
	{ key = "Boosts", pageId = "Boosts", label = "Boosts", icon = "Boost" },
	{ key = "Guild", pageId = "Guild", label = "Guild", icon = "Crew" },
	{ key = "Leaderboards", pageId = "Leaderboards", label = "Ranks", icon = "Leaderboard" },
	{ key = "Settings", pageId = "Settings", label = "Settings", icon = "Settings" },
}

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

local function seamTransparency(value)
	local shown = math.clamp(value, 0, 1)
	return 1 - shown * 0.96
end

local function seamWidth(value)
	return 2 + math.clamp(value, 0, 1) * 10
end

local function travelShift(value)
	return math.clamp(value, 0, 1.2) * 0.58
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
		Audio:play("hover")
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
				Audio:play("click")
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

local function DockColumn(props)
	local buttons = {
		Layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, DOCK_GAP),
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
		Size = UDim2.fromOffset(props.button, props.button * #props.entries + DOCK_GAP * (#props.entries - 1)),
		Position = if props.side == "left" then UDim2.new(0, props.pad, 0.5, 0) else UDim2.new(1, -props.pad, 0.5, 0),
		AnchorPoint = if props.side == "left" then Vector2.new(0, 0.5) else Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ClipsDescendants = false,
		ZIndex = 40,
	}, buttons)
end

local function edgePad(chrome, inset)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local screen = playerGui and playerGui:FindFirstChild(SCREEN_NAME)
	local consumed = false
	if screen ~= nil and screen:IsA("ScreenGui") then
		consumed = screen.IgnoreGuiInset == false or screen.ScreenInsets ~= Enum.ScreenInsets.None
	end
	local sideSafe = if chrome ~= nil and type(chrome.sideSafe) == "number" then chrome.sideSafe else 0
	local bottomSafe = if chrome ~= nil and type(chrome.bottomSafe) == "number" then chrome.bottomSafe else 0
	local side = SAFE_EDGE + sideSafe + (if consumed then 0 else inset.X)
	local top = SAFE_EDGE + (if consumed then 0 else inset.Y)
	local bottom = SAFE_EDGE + bottomSafe
	return side, top, bottom
end

local function SplitCurtain(props)
	local open = props.open == true
	local strictReduced = useClientSelector(settingsReduced)
	local strictReducedRef = React.useRef(strictReduced)
	strictReducedRef.current = strictReduced
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local inset, setInset = React.useState(function()
		return GuiService:GetGuiInset()
	end)
	local phase, setPhase = React.useState("shut")
	local leftTravel, setLeftTravel = React.useBinding(0)
	local rightTravel, setRightTravel = React.useBinding(0)
	local seam, setSeam = React.useBinding(0)
	local motors = React.useRef(nil)
	local phaseRef = React.useRef("shut")
	local openRef = React.useRef(open)
	local travelSample = React.useRef({
		left = 0,
		right = 0,
		leftPrev = 0,
		rightPrev = 0,
	})
	local delayToken = React.useRef(nil)
	local commandedTravel = React.useRef(nil)
	local paneRef = React.useRef(nil)
	local rightClipRef = React.useRef(nil)
	local cloneRef = React.useRef(nil)
	local wasOpen = React.useRef(false)
	if motors.current == nil then
		motors.current = {
			left = createFlipperMotor(0, TRAVEL_STIFFNESS, TRAVEL_DAMPING),
			right = createFlipperMotor(0, TRAVEL_STIFFNESS, TRAVEL_DAMPING),
			seam = createFlipperMotor(0, 640, 44),
		}
	end
	phaseRef.current = phase
	openRef.current = open

	local function noteTravel(side, value)
		local sample = travelSample.current
		local previous = sample[side]
		sample[side] = value
		if openRef.current or phaseRef.current ~= "apart" then
			sample[side .. "Prev"] = value
			return nil
		end
		local leftDelta = math.abs(sample.left - sample.leftPrev)
		local rightDelta = math.abs(sample.right - sample.rightPrev)
		sample.leftPrev = sample.left
		sample.rightPrev = sample.right
		if previous == nil then
			return nil
		end
		-- Flipper snaps the last sample onto the goal. A fly-through still has speed.
		if math.abs(sample.left) <= 0.001 and math.abs(sample.right) <= 0.001 and leftDelta <= 0.02 and rightDelta <= 0.02 then
			phaseRef.current = "shut"
			setPhase("shut")
		end
		return nil
	end

	React.useEffect(function()
		local function sync()
			setInset(GuiService:GetGuiInset())
		end
		sync()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(sync)
		return function()
			connection:Disconnect()
		end
	end, {})

	-- Subscribe once. Cleanup runs on unmount, not when the curtain retargets.
	React.useLayoutEffect(function()
		local pack = motors.current
		if pack == nil then
			return nil
		end
		local disconnectLeft = pack.left:onChange(function(value)
			setLeftTravel(value)
			noteTravel("left", value)
		end)
		local disconnectRight = pack.right:onChange(function(value)
			setRightTravel(value)
			noteTravel("right", value)
		end)
		local disconnectSeam = pack.seam:onChange(setSeam)
		return function()
			disconnectLeft()
			disconnectRight()
			disconnectSeam()
			pack.left:destroy()
			pack.right:destroy()
			pack.seam:destroy()
			if motors.current == pack then
				motors.current = nil
			end
		end
	end, {})

	React.useEffect(function()
		if wasOpen.current and not open then
			Audio:play("close")
		end
		wasOpen.current = open
	end, { open })

	React.useEffect(function()
		if not open then
			if phaseRef.current == "pulse" then
				setPhase("shut")
			end
			return nil
		end
		if phaseRef.current == "apart" then
			return nil
		end
		setPhase("pulse")
		Audio:play("tick")
		local pulse = if strictReducedRef.current then PULSE_SECONDS * 0.5 else PULSE_SECONDS
		local pending = true
		local thread = task.delay(pulse, function()
			pending = false
			if not openRef.current then
				return nil
			end
			phaseRef.current = "apart"
			setPhase("apart")
			return nil
		end)
		return function()
			if pending then
				pcall(task.cancel, thread)
			end
		end
	end, { open })

	React.useLayoutEffect(function()
		local pack = motors.current
		if pack == nil then
			return nil
		end
		if phase == "pulse" then
			local stiff = if strictReducedRef.current then 980 else 640
			pack.seam:configure(stiff, 44)
			pack.seam:setGoal(1)
			return nil
		end
		pack.seam:setGoal(0)
		return nil
	end, { phase })

	React.useLayoutEffect(function()
		if phase == "apart" then
			if cloneRef.current ~= nil then
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
			muteClone(copy)
			copy.Parent = slot
			cloneRef.current = copy
			return nil
		end
		local existing = cloneRef.current
		cloneRef.current = nil
		if existing ~= nil then
			pcall(function()
				existing:Destroy()
			end)
		end
		return nil
	end, { phase })

	React.useLayoutEffect(function()
		local pack = motors.current
		if pack == nil or phase ~= "apart" then
			return nil
		end
		local goal = if open then 1 else 0
		if commandedTravel.current == goal then
			return nil
		end
		commandedTravel.current = goal
		local stiff = if strictReducedRef.current then TRAVEL_STIFFNESS * 1.75 else TRAVEL_STIFFNESS
		pack.left:configure(stiff, TRAVEL_DAMPING)
		pack.right:configure(stiff, TRAVEL_DAMPING)
		local token = {}
		delayToken.current = token
		pack.left:setGoal(goal)
		local offset = if strictReducedRef.current then SPLIT_OFFSET * 0.5 else SPLIT_OFFSET
		task.delay(offset, function()
			if delayToken.current ~= token then
				return nil
			end
			local live = motors.current
			if live == nil or not live.right:alive() then
				return nil
			end
			live.right:setGoal(goal)
			return nil
		end)
		return nil
	end, { open, phase })

	React.useEffect(function()
		local pane = paneRef.current
		if pane == nil then
			return nil
		end
		pcall(function()
			pane.Interactable = phase == "shut"
		end)
		return nil
	end, { phase })

	local apart = phase == "apart"
	local showDocks = apart
	local seamVisible = seam:map(function(value)
		return value > 0.05
	end)
	local side, topInset, bottomInset = edgePad(chrome, inset)
	local available = math.max(220, viewport.height - topInset - bottomInset)
	local button = math.clamp(math.floor((available - DOCK_GAP * (#LEFT_DOCK - 1)) / #LEFT_DOCK), 46, 64)
	local leftPosition = leftTravel:map(function(value)
		return UDim2.fromScale(-travelShift(value), 0)
	end)
	local rightPosition = rightTravel:map(function(value)
		return UDim2.fromScale(0.5 + travelShift(value), 0)
	end)

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = false,
	}, React.createElement("frame", {
		Size = if apart then UDim2.fromScale(0.5, 1) else UDim2.fromScale(1, 1),
		Position = if apart then leftPosition else UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = apart,
		Active = not apart,
		ZIndex = 2,
	}, React.createElement("frame", {
		ref = paneRef,
		Size = if apart then UDim2.fromScale(2, 1) else UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = not apart,
	}, props.children)), apart and React.createElement("frame", {
		ref = rightClipRef,
		Size = UDim2.fromScale(0.5, 1),
		Position = rightPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = false,
		ZIndex = 2,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 24, 1, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Visible = seamVisible,
		ZIndex = 6,
	}, React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = seam:map(function(value)
			return UDim2.new(0, seamWidth(value) + 6, 1, 0)
		end),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = seam:map(function(value)
			return math.clamp(seamTransparency(value) + 0.28, 0, 1)
		end),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = surfaceGradient(Palette.panel, 0.7),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
	})), React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = seam:map(function(value)
			return UDim2.new(0, seamWidth(value), 1, 0)
		end),
		BackgroundColor3 = Palette.cyan,
		BackgroundTransparency = seam:map(seamTransparency),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 2,
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.cyan),
			ColorSequenceKeypoint.new(0.5, Palette.mint),
			ColorSequenceKeypoint.new(1, Palette.cyan),
		}),
	}))), showDocks and React.createElement(DockColumn, {
		entries = LEFT_DOCK,
		side = "left",
		pad = side,
		button = button,
		onNavigate = props.onNavigate,
	}), showDocks and React.createElement(DockColumn, {
		entries = RIGHT_DOCK,
		side = "right",
		pad = side,
		button = button,
		onNavigate = props.onNavigate,
	}))
end

return {
	SplitCurtain = SplitCurtain,
}
