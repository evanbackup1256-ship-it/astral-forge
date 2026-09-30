local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.audio).Audio
local Icon = require(script.Parent.Icon).Icon
local createFlipperMotor = require(script.Parent.motion).createFlipperMotor
local useViewport = require(script.Parent.motion).useViewport
local useClientSelector = require(script.Parent.clientStore).useClientSelector
local Text = require(script.Parent.ui).Text
local Palette = require(script.Parent.theme).Palette
local surfaceGradient = require(script.Parent.theme).surfaceGradient
local Curtain = require(script.Parent.curtainTransition)
local HudPlan = require(script.Parent.sanctuaryHudPlan)
local SanctuaryHud = require(script.Parent.sanctuaryHud).SanctuaryHud

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
