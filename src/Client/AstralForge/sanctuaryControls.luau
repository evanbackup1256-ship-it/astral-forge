--!strict
-- Movement and camera for walking the sanctuary.
--
-- The game ships without Roblox's PlayerModule, so the sanctuary brings its
-- own controls. Every input device gets the same verbs:
--
--   verb      keyboard/mouse        gamepad            touch
--   move      WASD / arrows         left stick         floating thumbstick (left half)
--   look      right-drag            right stick        drag (right half)
--   zoom      mouse wheel           --                 pinch
--   jump      Space                 A                  Jump button
--   sprint    hold Shift            L3 (toggle)        Run button (toggle)
--
-- The camera orbits the character with smoothing and pulls in whenever
-- terrain or a pillar would come between the lens and the player, so the
-- view is never blocked. Touch controls respect the device safe area (notch,
-- rounded corners, home indicator) and scale with the screen.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HudPlan = require(script.Parent.sanctuaryHudPlan)

local Controls = {}

local WALK_SPEED = 16
local SPRINT_SPEED = 26
local MIN_ZOOM, MAX_ZOOM = 9, 42
local MIN_PITCH, MAX_PITCH = math.rad(-72), math.rad(-6)
local MOUSE_SENSITIVITY = 0.0042
local TOUCH_SENSITIVITY = 0.0068
local STICK_SPEED = 2.6 -- radians per second at full right-stick tilt
local THUMBSTICK_RADIUS = 58

type TouchState = {
	moveInput: InputObject?,
	moveOrigin: Vector2,
	lookInputs: { [InputObject]: Vector2 },
	pinchDistance: number?,
}

local active = false
local enabled = true
local yaw = 0
local pitch = math.rad(-22)
local zoom = 18
local targetZoom = 18
local focus: Vector3? = nil
local sprinting = false
local sprintToggled = false
local jumpQueued = false
local shakeStrength = 0
local keyboardLooking = false
local gamepadMove = Vector2.zero
local gamepadLook = Vector2.zero
local touchMove = Vector2.zero
local touch: TouchState = { moveInput = nil, moveOrigin = Vector2.zero, lookInputs = {}, pinchDistance = nil }
local connections: { RBXScriptConnection } = {}
local touchGui: ScreenGui? = nil
local stickBase: Frame? = nil
local stickKnob: Frame? = nil
local runButton: TextButton? = nil
local touchPlan: HudPlan.Plan? = nil

local function track(connection: RBXScriptConnection)
	table.insert(connections, connection)
end

local function character(): (Model?, Humanoid?, BasePart?)
	local model = Players.LocalPlayer.Character
	if model == nil then
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and not root:IsA("BasePart") then
		root = nil
	end
	return model, humanoid, root :: BasePart?
end

local function setRunLabel()
	local button = runButton
	if button ~= nil then
		button.BackgroundTransparency = if sprintToggled then 0.15 else 0.45
		button.TextTransparency = if sprintToggled then 0 else 0.2
	end
end

------------------------------------------------------------------------
-- Touch controls
------------------------------------------------------------------------

local function roundButton(parent: Instance, name: string, label: string, size: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(size, size)
	button.AnchorPoint = Vector2.new(1, 1)
	button.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	button.BackgroundTransparency = 0.45
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = label
	button.TextColor3 = Color3.fromRGB(236, 240, 248)
	button.TextSize = math.floor(size * 0.24)
	button.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(236, 240, 248)
	stroke.Transparency = 0.7
	stroke.Thickness = 1.5
	stroke.Parent = button
	button.Parent = parent
	return button
end

-- The safe area the HUD lays itself out in (see sanctuaryHudPlan).
local function safeArea(): (Vector2, Vector2)
	local rect = GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
	return rect.Min, rect.Max - rect.Min
end

local function currentPlan(): HudPlan.Plan
	local _, size = safeArea()
	return HudPlan.compute({ width = size.X, height = size.Y, touch = true })
end

local function buildTouchGui()
	if touchGui ~= nil or not UserInputService.TouchEnabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SanctuaryTouchControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- The same safe area as the HUD, so the plan's rectangles line up exactly:
	-- clear of notches, rounded corners, the home bar and the Roblox top bar.
	gui.IgnoreGuiInset = false
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)

	local plan = currentPlan()
	touchPlan = plan
	local jumpRect = plan.jump :: HudPlan.Rect
	local runRect = plan.run :: HudPlan.Rect

	local jump = roundButton(gui, "Jump", "JUMP", jumpRect.w)
	jump.AnchorPoint = Vector2.zero
	jump.Position = UDim2.fromOffset(jumpRect.x, jumpRect.y)
	jump.MouseButton1Down:Connect(function()
		jumpQueued = true
	end)

	local run = roundButton(gui, "Run", "RUN", runRect.w)
	run.AnchorPoint = Vector2.zero
	run.Position = UDim2.fromOffset(runRect.x, runRect.y)
	run.MouseButton1Down:Connect(function()
		sprintToggled = not sprintToggled
		setRunLabel()
	end)
	runButton = run
	setRunLabel()

	local base = Instance.new("Frame")
	base.Name = "StickBase"
	base.Size = UDim2.fromOffset(THUMBSTICK_RADIUS * 2, THUMBSTICK_RADIUS * 2)
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	base.BackgroundTransparency = 0.55
	base.BorderSizePixel = 0
	base.Visible = false
	local baseCorner = Instance.new("UICorner")
	baseCorner.CornerRadius = UDim.new(1, 0)
	baseCorner.Parent = base
	local baseStroke = Instance.new("UIStroke")
	baseStroke.Color = Color3.fromRGB(236, 240, 248)
	baseStroke.Transparency = 0.75
	baseStroke.Thickness = 1.5
	baseStroke.Parent = base
	base.Parent = gui

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(44, 44)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(236, 240, 248)
	knob.BackgroundTransparency = 0.3
	knob.BorderSizePixel = 0
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	knob.Parent = base

	stickBase = base
	stickKnob = knob
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	touchGui = gui
end

local function destroyTouchGui()
	if touchGui ~= nil then
		touchGui:Destroy()
	end
	touchGui = nil
	stickBase = nil
	stickKnob = nil
	runButton = nil
	touchPlan = nil
end

local function resetTouch()
	touch.moveInput = nil
	table.clear(touch.lookInputs)
	touch.pinchDistance = nil
	touchMove = Vector2.zero
	if stickBase ~= nil then
		stickBase.Visible = false
	end
end

local function onTouchBegan(input: InputObject, processed: boolean)
	if processed or not enabled then
		return
	end
	local at = Vector2.new(input.Position.X, input.Position.Y)
	-- Touch positions and the controls' ScreenGui share one space; the plan's
	-- rectangles are relative to the gui's top-left.
	local origin = if touchGui ~= nil then touchGui.AbsolutePosition else Vector2.zero
	local localAt = at - origin
	local zone = if touchPlan ~= nil then touchPlan.stickZone else nil
	local inZone = if zone ~= nil
		then localAt.X >= zone.x and localAt.X <= zone.x + zone.w and localAt.Y >= zone.y and localAt.Y <= zone.y + zone.h
		else localAt.X < (if touchGui ~= nil then touchGui.AbsoluteSize.X else 800) * 0.5
	if inZone and touch.moveInput == nil then
		touch.moveInput = input
		touch.moveOrigin = at
		if stickBase ~= nil then
			stickBase.Position = UDim2.fromOffset(localAt.X, localAt.Y)
			stickBase.Visible = true
		end
		if stickKnob ~= nil then
			stickKnob.Position = UDim2.fromScale(0.5, 0.5)
		end
	else
		touch.lookInputs[input] = at
		touch.pinchDistance = nil
	end
end

local function onTouchMoved(input: InputObject)
	local at = Vector2.new(input.Position.X, input.Position.Y)
	if input == touch.moveInput then
		local offset = at - touch.moveOrigin
		local length = offset.Magnitude
		local clamped = if length > THUMBSTICK_RADIUS then offset.Unit * THUMBSTICK_RADIUS else offset
		touchMove = Vector2.new(clamped.X / THUMBSTICK_RADIUS, -clamped.Y / THUMBSTICK_RADIUS)
		if stickKnob ~= nil then
			stickKnob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
		end
		return
	end
	local last: Vector2? = touch.lookInputs[input]
	if last == nil then
		return
	end
	-- Two fingers on the look side pinch to zoom; one finger drags the view.
	local fingers = {}
	for other, position in touch.lookInputs do
		table.insert(fingers, if other == input then at else position)
	end
	touch.lookInputs[input] = at
	if #fingers >= 2 then
		local distance = (fingers[1] - fingers[2]).Magnitude
		if touch.pinchDistance ~= nil then
			targetZoom = math.clamp(targetZoom - (distance - touch.pinchDistance) * 0.08, MIN_ZOOM, MAX_ZOOM)
		end
		touch.pinchDistance = distance
		return
	end
	local delta = at - last
	yaw -= delta.X * TOUCH_SENSITIVITY
	pitch = math.clamp(pitch - delta.Y * TOUCH_SENSITIVITY, MIN_PITCH, MAX_PITCH)
end

local function onTouchEnded(input: InputObject)
	if input == touch.moveInput then
		touch.moveInput = nil
		touchMove = Vector2.zero
		if stickBase ~= nil then
			stickBase.Visible = false
		end
		return
	end
	touch.lookInputs[input] = nil
	touch.pinchDistance = nil
end

------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------

local function bindInput()
	track(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			onTouchBegan(input, processed)
			return
		end
		if processed or not enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			keyboardLooking = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			jumpQueued = true
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			sprintToggled = not sprintToggled
			setRunLabel()
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			onTouchMoved(input)
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if keyboardLooking then
				yaw -= input.Delta.X * MOUSE_SENSITIVITY
				pitch = math.clamp(pitch - input.Delta.Y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			targetZoom = math.clamp(targetZoom - input.Position.Z * 3, MIN_ZOOM, MAX_ZOOM)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			gamepadMove = if stick.Magnitude > 0.16 then stick else Vector2.zero
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			gamepadLook = if stick.Magnitude > 0.16 then stick else Vector2.zero
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onTouchEnded(input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			keyboardLooking = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			gamepadMove = Vector2.zero
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.zero
		end
	end))
	-- Losing focus mid-drag must not leave the mouse locked or a key "held".
	track(UserInputService.WindowFocusReleased:Connect(function()
		keyboardLooking = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		resetTouch()
	end))
	-- A rotated or resized screen rebuilds the touch controls at the new size.
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if touchGui ~= nil then
				destroyTouchGui()
				resetTouch()
				buildTouchGui()
			end
		end))
	end
end

local function keyboardMove(): Vector2
	if UserInputService:GetFocusedTextBox() ~= nil then
		return Vector2.zero
	end
	local x, y = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		y += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		y -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	return Vector2.new(x, y)
end

------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------

-- Begin controlling the character, looking the way `facing` points.
function Controls.start(facing: Vector3?)
	if active then
		return
	end
	active = true
	enabled = true
	local look = facing or Vector3.new(0, 0, -1)
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.rad(-20)
	zoom, targetZoom = 18, 18
	focus = nil
	sprintToggled = false
	jumpQueued = false
	shakeStrength = 0
	bindInput()
	buildTouchGui()
end

function Controls.stop()
	if not active then
		return
	end
	active = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	destroyTouchGui()
	resetTouch()
	gamepadMove, gamepadLook = Vector2.zero, Vector2.zero
	keyboardLooking = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local _, humanoid = character()
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero, false)
	end
end

function Controls.isActive(): boolean
	return active
end

-- Pause movement while a menu has focus (the camera still follows).
function Controls.setEnabled(value: boolean)
	enabled = value
	if not value then
		resetTouch()
		gamepadMove = Vector2.zero
	end
end

-- Kick the camera (boss slams, heavy landings).
function Controls.shake(strength: number)
	shakeStrength = math.max(shakeStrength, strength)
end

-- Knock the character away from a point (a slam's stagger).
function Controls.knockback(from: Vector3, force: number)
	local _, _, root = character()
	if root == nil then
		return
	end
	local away = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local dir = if away.Magnitude > 0.5 then away.Unit else Vector3.new(0, 0, 1)
	root.AssemblyLinearVelocity = dir * force + Vector3.new(0, force * 0.55, 0)
end

-- One frame: move the character and place the camera. Called on RenderStepped.
function Controls.step(dt: number)
	if not active then
		return
	end
	local camera = Workspace.CurrentCamera
	local _, humanoid, root = character()
	if camera == nil or humanoid == nil or root == nil then
		return
	end

	-- Look.
	if gamepadLook.Magnitude > 0 and enabled then
		yaw -= gamepadLook.X * STICK_SPEED * dt
		pitch = math.clamp(pitch + gamepadLook.Y * STICK_SPEED * 0.6 * dt, MIN_PITCH, MAX_PITCH)
	end

	-- Move, relative to where the camera faces.
	local input = if enabled then keyboardMove() + gamepadMove + touchMove else Vector2.zero
	if input.Magnitude > 1 then
		input = input.Unit
	end
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local worldMove = right * input.X + forward * input.Y
	humanoid:Move(worldMove, false)
	sprinting = enabled and (sprintToggled or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)) and input.Magnitude > 0.1
	humanoid.WalkSpeed = if sprinting then SPRINT_SPEED else WALK_SPEED
	if jumpQueued then
		jumpQueued = false
		if enabled then
			humanoid.Jump = true
		end
	end

	-- Camera: smooth focus and zoom, orbit, then pull in past obstacles.
	local target = root.Position + Vector3.new(0, 2.6, 0)
	local current = focus or target
	local follow = 1 - math.exp(-14 * dt)
	current = current:Lerp(target, follow)
	focus = current
	zoom += (targetZoom - zoom) * (1 - math.exp(-10 * dt))
	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local desiredEye = current - rotation.LookVector * zoom
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local model = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if model ~= nil then { model } else {}
	local offset = desiredEye - current
	local hit = Workspace:Raycast(current, offset, params)
	local eye = if hit ~= nil then hit.Position - offset.Unit * 0.8 else desiredEye
	local frame = CFrame.lookAt(eye, current)
	if shakeStrength > 0.001 then
		local t = os.clock() * 38
		frame *= CFrame.Angles(math.sin(t) * shakeStrength * 0.02, math.cos(t * 1.3) * shakeStrength * 0.02, 0)
		shakeStrength *= math.exp(-6 * dt)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	camera.CFrame = frame
end

-- The camera's flat forward, for anything that aims relative to the view.
function Controls.forward(): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

return Controls
