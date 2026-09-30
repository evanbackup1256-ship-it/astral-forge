--!nonstrict
--[=[
	SanctuaryKit: merged module suite.
	Members (8): sanctuaryAmbience, sanctuaryControls, sanctuaryHud, sanctuaryHudPlan, sanctuarySignals, sanctuaryWorld, sanctuaryPresence, curtainTransition.

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
	if def == nil then error("SanctuaryKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("SanctuaryKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: sanctuaryAmbience   (merged from sanctuaryAmbience.luau, 159 lines)
-- ======================================================================
__defs["sanctuaryAmbience"] = function()
-- Region ambience in the sanctuary: a warm hum at the Forge Heart, lava and
-- crackle in Emberreach, glassy wind and chimes in the Hollows, high wind at
-- the Spire and a slow drone in the Riftmaw.
--
-- All five loops live in one uploaded file (tools/assetgen/ambience.py) and
-- each plays as a looping region of it. Two voices crossfade when the player
-- crosses into a new region; on a bridge the last region's bed carries on,
-- quieter. Played through the mixer's ambient group, so the ambient volume
-- setting applies. Silent until the ambience file is uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Signals = __load("sanctuarySignals")
local Manifest = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("AssetManifest")

local Ambience = {}

local BED = {
	Heart = "amb_heart",
	Emberreach = "amb_ember",
	Hollows = "amb_hollows",
	Spire = "amb_spire",
	Riftmaw = "amb_riftmaw",
}
local LEVEL = 0.55
local BRIDGE_LEVEL = 0.3
local FADE_SECONDS = 2.5

type Voice = { sound: Sound, bed: string?, level: number, target: number }

local voices: { Voice } = {}
local current: Voice? = nil
local stepper: RBXScriptConnection? = nil
local unsubscribe: (() -> ())? = nil
local active = false

local function ambientGroup(): SoundGroup?
	local master = SoundService:FindFirstChild("ForgeMaster")
	local group = master and master:FindFirstChild("ForgeAmbient")
	return if group ~= nil and group:IsA("SoundGroup") then group else nil
end

local function makeVoice(): Voice
	local sound = Instance.new("Sound")
	sound.Name = "SanctuaryAmbience"
	sound.SoundId = `rbxassetid://{Manifest.Ambience.Id}`
	sound.Looped = true
	sound.PlaybackRegionsEnabled = true
	sound.Volume = 0
	sound.SoundGroup = ambientGroup()
	sound.Parent = SoundService
	return { sound = sound, bed = nil, level = 0, target = 0 }
end

local function play(voice: Voice, bed: string)
	local region = Manifest.Ambience.Regions[bed]
	if region == nil then
		return
	end
	local range = NumberRange.new(region[1], region[1] + region[2])
	voice.bed = bed
	voice.sound.PlaybackRegion = range
	voice.sound.LoopRegion = range
	voice.sound.TimePosition = region[1]
	if not voice.sound.IsPlaying then
		voice.sound:Play()
	end
end

local function onRegion(payload)
	if type(payload) ~= "table" or type(payload.Id) ~= "string" then
		return
	end
	local bed = BED[payload.Id]
	if bed == nil then
		-- On a bridge: keep what's playing, a little quieter.
		if current ~= nil then
			current.target = BRIDGE_LEVEL
		end
		return
	end
	if current ~= nil and current.bed == bed then
		current.target = LEVEL
		return
	end
	-- Fade the old bed out and bring the new one in on the other voice.
	local nextVoice = if voices[1] == current then voices[2] else voices[1]
	if current ~= nil then
		current.target = 0
	end
	play(nextVoice, bed)
	nextVoice.target = LEVEL
	current = nextVoice
end

function Ambience.start()
	if active or Manifest.Ambience.Id <= 0 then
		return
	end
	active = true
	voices = { makeVoice(), makeVoice() }
	current = nil
	unsubscribe = Signals.on("RegionChanged", onRegion)
	stepper = RunService.Heartbeat:Connect(function(dt: number)
		local step = dt / FADE_SECONDS
		for _, voice in voices do
			if voice.level < voice.target then
				voice.level = math.min(voice.target, voice.level + step)
			elseif voice.level > voice.target then
				voice.level = math.max(voice.target, voice.level - step)
			end
			voice.sound.Volume = voice.level * voice.level
			if voice.level <= 0 and voice.target <= 0 and voice.sound.IsPlaying then
				voice.sound:Stop()
			end
		end
	end)
end

function Ambience.stop()
	if not active then
		return
	end
	active = false
	if unsubscribe ~= nil then
		unsubscribe()
		unsubscribe = nil
	end
	if stepper ~= nil then
		stepper:Disconnect()
		stepper = nil
	end
	-- A short fade so leaving the rift never cuts the bed off mid-breath.
	local leaving = voices
	voices = {}
	current = nil
	task.spawn(function()
		local started = os.clock()
		local from = {}
		for index, voice in leaving do
			from[index] = voice.sound.Volume
		end
		while os.clock() - started < 0.8 do
			local k = 1 - (os.clock() - started) / 0.8
			for index, voice in leaving do
				voice.sound.Volume = from[index] * k
			end
			task.wait()
		end
		for _, voice in leaving do
			voice.sound:Destroy()
		end
	end)
end

return Ambience
end

-- ======================================================================
-- Module: sanctuaryControls   (merged from sanctuaryControls.luau, 557 lines)
-- ======================================================================
__defs["sanctuaryControls"] = function()
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

local HudPlan = __load("sanctuaryHudPlan")

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
-- Field of view: widens a touch while sprinting, eased, and restored on stop.
local BASE_FOV = 70
local SPRINT_FOV = 77
local fov = BASE_FOV
local savedFov: number? = nil
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

-- Touch controls

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

-- Input

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

-- Public

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
	-- Put the lens back exactly as the shell had it.
	local camera = Workspace.CurrentCamera
	if camera ~= nil and savedFov ~= nil then
		camera.FieldOfView = savedFov
	end
	savedFov = nil
	fov = BASE_FOV
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
	-- Speed reads through the lens: the view widens as you sprint.
	if savedFov == nil then
		savedFov = camera.FieldOfView
	end
	fov += ((if sprinting then SPRINT_FOV else BASE_FOV) - fov) * (1 - math.exp(-6 * dt))
	camera.FieldOfView = fov
end

-- The camera's flat forward, for anything that aims relative to the view.
function Controls.forward(): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

return Controls
end

-- ======================================================================
-- Module: sanctuaryHud   (merged from sanctuaryHud.luau, 1583 lines)
-- ======================================================================
__defs["sanctuaryHud"] = function()
-- The sanctuary HUD: everything on screen while the player walks the world.
--
--   * region banner when you cross into a new part of the map
--   * ore chips (what you've mined)
--   * the Rift Warden bar: countdown while it sleeps, forming progress, then
--     its health while it fights
--   * Strike (F / R2 / the button) while the Warden is up and you're in the
--     Riftmaw; Recall to jump back to the Forge Heart
--   * the navigation menu (when the docks don't fit) and the waystone sheet
--
-- Every rectangle comes from sanctuaryHudPlan, so nothing overlaps at any
-- screen size and nothing sits where the thumbs go on a phone.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local Palette = require(script.Parent.CoreKit)("theme").Palette
local Signals = __load("sanctuarySignals")
local Controls = __load("sanctuaryControls")
local HudPlan = __load("sanctuaryHudPlan")
local MotionTokens = require(script.Parent.MotionKit)("motionTokens")
local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("SharedData"))("SanctuaryLayout")
local SanctuaryConfig = require(Shared:WaitForChild("SharedData"))("SanctuaryConfig")

local e = React.createElement

local BOSS = SanctuaryConfig.RiftBoss
local STRIKE_COOLDOWN = BOSS.StrikeCooldown + 0.04
local RECALL_COOLDOWN = 8
local BANNER_SECONDS = 2.8
local FONT_MEDIUM = Font.fromEnum(Enum.Font.BuilderSansMedium)
local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_HEAVY = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
local RIFT = Color3.fromRGB(164, 124, 255)
local RIFT_SOFT = Color3.fromRGB(214, 196, 255)
local PANEL = Palette.ink
local PANEL_ALPHA = 0.18

local REGION_LINES = {
	Heart = "The forge altar",
	Emberreach = "Emberite grows here",
	Hollows = "Voidglass grows here",
	Spire = "Starsteel grows here",
	Riftmaw = "Where the Rift Warden wakes",
}

local function rgb(triple): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local ORE_COLORS = {}
for _, ore in SanctuaryConfig.Ore.Types do
	ORE_COLORS[ore.Id] = rgb(ore.Color)
end

local function compact(value: number): string
	value = math.floor(value)
	if value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e4 then
		return string.format("%.1fK", value / 1e3)
	end
	-- 1,234 style below ten thousand.
	local text = tostring(value)
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return formatted
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rectProps(r)
	return UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.w, r.h)
end

local function preferGamepad(): boolean
	local preferred = UserInputService.PreferredInput
	return preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad
end

-- Hooks

-- Eases a binding toward `target` over `seconds` on the shared standard curve, starting from
-- `initial` on mount (default: already at the target). Instant when motion
-- is reduced.
local function useEase(target: number, seconds: number, reduced: boolean, initial: number?)
	local start = if reduced or initial == nil then target else initial
	local binding, setBinding = React.useBinding(start)
	local current = React.useRef(start)
	React.useEffect(function()
		local from = current.current
		if reduced or math.abs(from - target) < 1e-3 then
			current.current = target
			setBinding(target)
			return nil
		end
		local started = os.clock()
		local duration = math.max(0.05, seconds * math.abs(target - from))
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - started) / duration, 0, 1)
			local eased = MotionTokens.EASE.standard(k)
			local value = from + (target - from) * eased
			current.current = value
			setBinding(value)
			if k >= 1 and connection ~= nil then
				connection:Disconnect()
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, { target, reduced } :: { any })
	return binding
end

local function findWarden(): Model?
	local worldFolder = Workspace:FindFirstChild("AstralForgeWorld")
	local expanse = worldFolder and worldFolder:FindFirstChild("SanctuaryWorld")
	local model = expanse and expanse:FindFirstChild("RiftWarden")
	if model ~= nil and model:IsA("Model") then
		return model
	end
	return nil
end

type WardenInfo = { phase: string, endsAt: number, health: number, maxHealth: number, name: string }

local function readWarden(model: Model?): WardenInfo
	if model == nil then
		return { phase = "Unknown", endsAt = 0, health = 0, maxHealth = 1, name = BOSS.Name }
	end
	return {
		phase = tostring(model:GetAttribute("Phase") or "Dormant"),
		endsAt = tonumber(model:GetAttribute("EndsAt")) or 0,
		health = tonumber(model:GetAttribute("Health")) or 0,
		maxHealth = math.max(1, tonumber(model:GetAttribute("MaxHealth")) or 1),
		name = tostring(model:GetAttribute("BossName") or BOSS.Name),
	}
end

-- The Warden's replicated state, kept current from its attributes.
local function useWarden(): WardenInfo
	local info, setInfo = React.useState(function()
		return readWarden(findWarden())
	end)
	React.useEffect(function()
		local alive = true
		local model: Model? = nil
		local connection: RBXScriptConnection? = nil
		local function attach()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			model = findWarden()
			if model ~= nil then
				connection = model.AttributeChanged:Connect(function()
					setInfo(readWarden(model))
				end)
			end
			setInfo(readWarden(model))
		end
		attach()
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive and (model == nil or model.Parent == nil) then
					attach()
				end
			end
		end)
		return function()
			alive = false
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, {})
	return info
end

-- Server time, ticking a few times a second (for countdowns).
local function useServerClock(rate: number): number
	local now, setNow = React.useState(function()
		return Workspace:GetServerTimeNow()
	end)
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(rate)
				if alive then
					setNow(Workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, { rate })
	return now
end

-- Is the local player close enough to the Warden to strike?
local function useInArena(): boolean
	local inArena, setInArena = React.useState(false)
	React.useEffect(function()
		local arena = Layout.arena()
		local origin = Layout.ORIGIN
		local center = Vector3.new(origin.X + arena.Center.X, 0, origin.Z + arena.Center.Z)
		local reach = BOSS.StrikeRange - 3
		local last = false
		local elapsed = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < 0.2 then
				return
			end
			elapsed = 0
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local inside = false
			if root ~= nil and root:IsA("BasePart") then
				local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
				inside = (flat - center).Magnitude <= reach
			end
			if inside ~= last then
				last = inside
				setInArena(inside)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return inArena
end

-- Small pieces

local function Panel(props)
	return e("frame", {
		Position = props.position,
		Size = props.size,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.color or PANEL,
		BackgroundTransparency = props.transparency or PANEL_ALPHA,
		BorderSizePixel = 0,
		ClipsDescendants = props.clip == true,
		Visible = props.visible ~= false,
		ZIndex = props.zIndex or 50,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, props.radius or 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = props.strokeColor or Palette.white,
		Transparency = props.strokeTransparency or 0.86,
		Thickness = 1,
	}), props.children)
end

local function Label(props)
	return e("textlabel", {
		Position = props.position,
		Size = props.size or UDim2.fromScale(1, 1),
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Text = props.text,
		TextColor3 = props.color or Palette.cream,
		TextTransparency = props.transparency or 0,
		TextSize = props.textSize or 14,
		FontFace = props.font or FONT_MEDIUM,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = false,
		AutoLocalize = true,
		ZIndex = props.zIndex or 51,
	})
end

-- Hover/press state for a button, and the Event handlers that drive it.
local function useButtonFeel()
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local events = {
		MouseEnter = function()
			setHovered(true)
		end,
		MouseLeave = function()
			setHovered(false)
			setPressed(false)
		end,
		SelectionGained = function()
			setHovered(true)
		end,
		SelectionLost = function()
			setHovered(false)
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
	}
	return hovered, pressed, events
end

local function IconButton(props)
	local hovered, pressed, events = useButtonFeel()
	local merged = table.clone(events)
	merged.Activated = function()
		Audio:play(props.cue or "sanctuaryClick")
		props.onActivate()
	end
	local position, size = rectProps(props.rect)
	return e("textbutton", {
		Position = position,
		Size = size,
		BackgroundColor3 = if pressed then Palette.panelRaised else PANEL,
		BackgroundTransparency = if hovered then 0.06 else PANEL_ALPHA,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 52,
		Event = merged,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.white,
		Transparency = if hovered then 0.6 else 0.86,
		Thickness = 1,
	}), e(Icon, {
		kind = props.icon,
		size = math.floor(math.min(props.rect.w, props.rect.h) * 0.46),
		color = Palette.cream,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}), props.children)
end

-- Region banner

type BannerMessage = { key: number, eyebrow: string, title: string, line: string, accent: Color3 }

local function Banner(props)
	local plan = props.plan
	local message: BannerMessage? = props.message
	local shown = message ~= nil and props.visible
	local amount = useEase(if shown then 1 else 0, if shown then 0.45 else 0.6, props.reducedMotion)
	local last = React.useRef(message)
	if message ~= nil then
		last.current = message
	end
	local current: BannerMessage? = last.current
	if current == nil then
		return nil
	end
	local r = plan.banner
	local titleSize = plan.text.title
	return e("frame", {
		Position = amount:map(function(value)
			return UDim2.fromOffset(r.x, r.y + math.floor((1 - value) * 10))
		end),
		Size = UDim2.fromOffset(r.w, r.h),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
	}, e("textlabel", {
		Size = UDim2.new(1, 0, 0, plan.text.label + 4),
		BackgroundTransparency = 1,
		Text = string.upper(current.eyebrow),
		TextColor3 = current.accent,
		TextTransparency = amount:map(function(value)
			return 1 - value
		end),
		TextSize = plan.text.label,
		FontFace = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutoLocalize = true,
		ZIndex = 51,
	}), e("textlabel", {
		Position = UDim2.fromOffset(0, plan.text.label + 6),
		Size = UDim2.new(1, 0, 0, titleSize + 6),
		BackgroundTransparency = 1,
		Text = current.title,
		TextColor3 = Palette.cream,
		TextTransparency = amount:map(function(value)
			return 1 - value
		end),
		TextStrokeColor3 = Palette.void,
		TextStrokeTransparency = amount:map(function(value)
			return 1 - value * 0.55
		end),
		TextSize = titleSize,
		FontFace = FONT_HEAVY,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = true,
		ZIndex = 51,
	}), e("frame", {
		-- A hairline that draws outward from the centre.
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, plan.text.label + titleSize + 16),
		Size = amount:map(function(value)
			return UDim2.fromOffset(math.floor(r.w * 0.36 * value), 1)
		end),
		BackgroundColor3 = current.accent,
		BackgroundTransparency = amount:map(function(value)
			return 1 - value * 0.8
		end),
		BorderSizePixel = 0,
		ZIndex = 51,
	}), current.line ~= "" and e("textlabel", {
		Position = UDim2.fromOffset(0, plan.text.label + titleSize + 22),
		Size = UDim2.new(1, 0, 0, plan.text.body + 6),
		BackgroundTransparency = 1,
		Text = current.line,
		TextColor3 = Palette.creamSoft,
		TextTransparency = amount:map(function(value)
			return 1 - value * 0.9
		end),
		TextSize = plan.text.body,
		FontFace = FONT_MEDIUM,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = true,
		ZIndex = 51,
	}))
end

-- Ore chips

local function OreChip(props)
	local bump = useEase(props.bumpKey % 2, 0.18, props.reducedMotion)
	local chip = props.width
	local height = props.height
	local numberSize = props.plan.text.number
	return e("frame", {
		Size = UDim2.fromOffset(chip, height),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = PANEL_ALPHA,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
		ZIndex = 50,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = props.color,
		Transparency = 0.7,
		Thickness = 1,
	}), e("frame", {
		-- The ore's colour: a small gem-cut square.
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		Rotation = 45,
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = 51,
	}), e("textlabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -30, 1, if props.compact then 0 else -math.floor(height * 0.36)),
		BackgroundTransparency = 1,
		Text = compact(props.amount),
		TextColor3 = bump:map(function(value)
			-- A brief brightening when the count changes.
			local pulse = math.sin(math.clamp(value, 0, 1) * math.pi)
			return Palette.cream:Lerp(props.color, pulse * 0.6)
		end),
		TextSize = numberSize,
		FontFace = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if props.compact then Enum.TextYAlignment.Center else Enum.TextYAlignment.Bottom,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = false,
		ZIndex = 51,
	}), not props.compact and e("textlabel", {
		Position = UDim2.new(0, 24, 1, -math.floor(height * 0.4)),
		Size = UDim2.new(1, -30, 0, math.floor(height * 0.32)),
		BackgroundTransparency = 1,
		Text = props.name,
		TextColor3 = Palette.muted,
		TextSize = props.plan.text.label,
		FontFace = FONT_MEDIUM,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = true,
		ZIndex = 51,
	}))
end

local function OreChips(props)
	local plan = props.plan
	local balances = if type(props.ore) == "table" and type(props.ore.Balances) == "table" then props.ore.Balances else {}
	local counts = React.useRef({})
	local bumps = React.useRef({})
	local children = {
		Layout = e("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, math.max(4, math.floor(plan.gap * 0.6))),
		}),
	}
	for index, ore in SanctuaryConfig.Ore.Types do
		local amount = tonumber(balances[ore.Id]) or 0
		local previous = counts.current[ore.Id]
		if previous ~= nil and amount > previous then
			bumps.current[ore.Id] = (bumps.current[ore.Id] or 0) + 1
		end
		counts.current[ore.Id] = amount
		children[ore.Id] = e(OreChip, {
			order = index,
			name = ore.Name,
			amount = amount,
			color = ORE_COLORS[ore.Id],
			width = plan.oreChip,
			height = plan.ore.h,
			compact = plan.oreCompact,
			plan = plan,
			bumpKey = bumps.current[ore.Id] or 0,
			reducedMotion = props.reducedMotion,
		})
	end
	local position, size = rectProps(plan.ore)
	return e("frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
	}, children)
end

-- The Warden bar

local function HealthTrack(props)
	-- The fill follows health quickly; a pale "chip" trails behind it so a
	-- hit reads as a bite taken out of the bar.
	local fraction = math.clamp(props.health / math.max(1, props.maxHealth), 0, 1)
	local fill = useEase(fraction, 0.25, props.reducedMotion)
	local chip = useEase(fraction, 1.1, props.reducedMotion)
	return e("frame", {
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 51,
	}, e("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), e("frame", {
		Size = chip:map(function(value)
			return UDim2.fromScale(math.clamp(value, 0, 1), 1)
		end),
		BackgroundColor3 = RIFT_SOFT,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 52,
	}, e("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), e("frame", {
		Size = fill:map(function(value)
			return UDim2.fromScale(math.clamp(value, 0, 1), 1)
		end),
		BackgroundColor3 = props.color or RIFT,
		BorderSizePixel = 0,
		ZIndex = 53,
	}, e("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), e("uigradient", {
		Color = ColorSequence.new(RIFT_SOFT, props.color or RIFT),
		Rotation = 90,
	})))
end

local function WardenBar(props)
	local plan = props.plan
	local warden: WardenInfo = props.warden
	local now = useServerClock(0.25)
	local phase = warden.phase
	if phase == "Unknown" then
		return nil
	end
	local r = plan.warden
	local position, size = rectProps(r)
	local left = math.max(10, math.floor(r.h * 0.26))
	local labelSize = plan.text.label
	local remaining = warden.endsAt - now
	local title: string
	local right: string
	local track = nil
	if phase == "Active" then
		title = string.upper(warden.name)
		right = if props.inArena then clock(remaining) else `Riftmaw · {clock(remaining)}`
		track = e(HealthTrack, {
			position = UDim2.new(0, left, 1, -left - 6),
			size = UDim2.new(1, -left * 2, 0, 6),
			health = warden.health,
			maxHealth = warden.maxHealth,
			reducedMotion = props.reducedMotion,
		})
	elseif phase == "Forming" then
		title = "THE WARDEN IS FORMING"
		right = clock(remaining)
		local progress = math.clamp(1 - remaining / BOSS.FormingSeconds, 0, 1)
		track = e(HealthTrack, {
			position = UDim2.new(0, left, 1, -left - 4),
			size = UDim2.new(1, -left * 2, 0, 3),
			health = progress,
			maxHealth = 1,
			color = RIFT_SOFT,
			reducedMotion = props.reducedMotion,
		})
	elseif phase == "Defeated" then
		title = "THE WARDEN FALLS"
		right = ""
	elseif phase == "Escaped" then
		title = "THE WARDEN ESCAPED"
		right = ""
	else
		title = "RIFT WARDEN"
		right = `returns in {clock(remaining)}`
	end
	local lively = phase == "Active" or phase == "Forming"
	return e(Panel, {
		position = position,
		size = size,
		radius = 10,
		strokeColor = if lively then RIFT else Palette.white,
		strokeTransparency = if lively then 0.5 else 0.86,
	}, e(Label, {
		position = UDim2.fromOffset(left, if track ~= nil then math.floor(r.h * 0.14) else 0),
		size = UDim2.new(0.62, -left, 0, if track ~= nil then labelSize + 8 else r.h),
		text = title,
		textSize = labelSize,
		font = FONT_BOLD,
		color = if lively then RIFT_SOFT else Palette.creamSoft,
	}), e(Label, {
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -left, 0, if track ~= nil then math.floor(r.h * 0.14) else 0),
		size = UDim2.new(0.38, 0, 0, if track ~= nil then labelSize + 8 else r.h),
		text = right,
		textSize = labelSize,
		font = FONT_MEDIUM,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
	}), track)
end

-- Strike and recall

type Hit = { id: number, text: string, crit: boolean }

local function HitNumber(props)
	local rise = useEase(1, 0.8, false, 0)
	return e("textlabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = rise:map(function(value)
			return UDim2.new(0.5, props.offset, 0, -6 - math.floor(value * 46))
		end),
		Size = UDim2.fromOffset(140, 28),
		BackgroundTransparency = 1,
		Text = props.text,
		TextColor3 = if props.crit then Palette.mango else Palette.cream,
		TextTransparency = rise:map(function(value)
			return math.clamp((value - 0.55) / 0.45, 0, 1)
		end),
		TextStrokeColor3 = Palette.void,
		TextStrokeTransparency = rise:map(function(value)
			return 0.35 + 0.65 * math.clamp((value - 0.55) / 0.45, 0, 1)
		end),
		TextSize = if props.crit then 22 else 17,
		FontFace = FONT_HEAVY,
		AutoLocalize = false,
		ZIndex = 56,
	})
end

local function StrikeButton(props)
	local plan = props.plan
	local r = plan.strike
	local hovered, pressed, events = useButtonFeel()
	local dazed = props.dazedUntil > os.clock()
	local cooldown = props.cooldown
	local position, size = rectProps(r)
	local round = plan.touch
	local ready = not dazed
	local hits = {}
	for _, hit in props.hits do
		hits[`hit{hit.id}`] = e(HitNumber, {
			text = hit.text,
			crit = hit.crit,
			offset = ((hit.id * 37) % 60) - 30,
		})
	end
	return e("textbutton", {
		Position = position,
		Size = size,
		BackgroundColor3 = if dazed then Palette.panel elseif pressed then Color3.fromRGB(92, 64, 170) else Color3.fromRGB(40, 28, 78),
		BackgroundTransparency = if hovered and ready then 0.02 else 0.12,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ClipsDescendants = false,
		ZIndex = 54,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = function(rbx)
				events.MouseLeave(rbx)
				props.onHold(false)
			end,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = function(rbx, input)
				events.InputBegan(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					props.onHold(true)
				end
			end,
			InputEnded = function(rbx, input)
				events.InputEnded(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					props.onHold(false)
				end
			end,
			Activated = function()
				-- Gamepad "A" on a selected button; mouse/touch strike through onHold.
				if preferGamepad() then
					props.onStrike()
				end
			end,
		},
	}, e("uicorner", {
		CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, 12),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if dazed then Palette.lineSoft else RIFT_SOFT,
		Transparency = if hovered then 0.1 else 0.4,
		Thickness = 1.5,
	}), e("frame", {
		-- The recovery sweep: fills back up across the cooldown.
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = cooldown:map(function(value)
			return UDim2.fromScale(1, math.clamp(value, 0, 1))
		end),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 55,
	}, e("uicorner", {
		CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, 12),
	})), e("textlabel", {
		Size = if round then UDim2.fromScale(1, 1) else UDim2.new(1, -44, 1, 0),
		Position = if round then UDim2.fromScale(0, 0) else UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = if dazed then "DAZED" else "STRIKE",
		TextColor3 = if dazed then Palette.muted else Palette.cream,
		TextSize = if round then math.clamp(math.floor(r.w * 0.2), 12, 18) else plan.text.body + 1,
		FontFace = FONT_HEAVY,
		TextXAlignment = if round then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		AutoLocalize = true,
		ZIndex = 56,
	}), not round and e("frame", {
		-- Key cap.
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 56,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), e("uistroke", {
		Color = Palette.white,
		Transparency = 0.7,
		Thickness = 1,
	}), e(Label, {
		text = if preferGamepad() then "R2" else "F",
		textSize = 13,
		font = FONT_BOLD,
		align = Enum.TextXAlignment.Center,
		zIndex = 57,
	})), props.status ~= "" and e("textlabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(math.max(180, r.w), 20),
		BackgroundTransparency = 1,
		Text = props.status,
		TextColor3 = Palette.creamSoft,
		TextStrokeColor3 = Palette.void,
		TextStrokeTransparency = 0.4,
		TextSize = plan.text.label + 1,
		FontFace = FONT_BOLD,
		AutoLocalize = true,
		ZIndex = 56,
	}), hits)
end

local function RecallButton(props)
	local plan = props.plan
	local r = plan.recall
	local hovered, pressed, events = useButtonFeel()
	local position, size = rectProps(r)
	local square = plan.touch
	local cooling = props.cooling
	return e("textbutton", {
		Position = position,
		Size = size,
		BackgroundColor3 = if pressed then Palette.panelRaised else PANEL,
		BackgroundTransparency = if hovered then 0.06 else PANEL_ALPHA,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ClipsDescendants = true,
		ZIndex = 52,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = events.MouseLeave,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = events.InputBegan,
			InputEnded = events.InputEnded,
			Activated = function()
				Audio:play("sanctuaryRecall")
				props.onRecall()
			end,
		},
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.white,
		Transparency = if hovered then 0.6 else 0.86,
		Thickness = 1,
	}), e("frame", {
		-- Cooldown: drains left to right.
		Size = props.recharge:map(function(value)
			return UDim2.fromScale(math.clamp(value, 0, 1), 1)
		end),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 52,
	}), e(Icon, {
		kind = "Back",
		size = math.floor(math.min(r.w, r.h) * 0.44),
		color = if cooling then Palette.muted else Palette.cream,
		spin = false,
		position = if square then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 12, 0.5, 0),
		anchorPoint = if square then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
	}), not square and e(Label, {
		position = UDim2.fromOffset(math.floor(r.h * 0.44) + 20, 0),
		size = UDim2.new(1, -(math.floor(r.h * 0.44) + 26), 1, 0),
		text = "Recall",
		textSize = plan.text.body,
		font = FONT_BOLD,
		color = if cooling then Palette.muted else Palette.cream,
		zIndex = 53,
	}))
end

-- Sheets

local function Sheet(props)
	local plan = props.plan
	local r = plan.sheet
	local shown = useEase(1, 0.22, props.reducedMotion, 0)
	local header = math.max(HudPlan.MIN_TAP, plan.sheetRow - 4)
	return e("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 60,
	}, e("textbutton", {
		-- The dim behind the sheet; a tap outside closes it.
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = shown:map(function(value)
			return 1 - value * 0.5
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		ZIndex = 60,
		Event = {
			Activated = function()
				props.onClose()
			end,
		},
	}), e("frame", {
		Position = shown:map(function(value)
			return UDim2.fromOffset(r.x, r.y + math.floor((1 - value) * 14))
		end),
		Size = UDim2.fromOffset(r.w, r.h),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 61,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.white,
		Transparency = 0.84,
		Thickness = 1,
	}), e(Label, {
		position = UDim2.fromOffset(18, 0),
		size = UDim2.new(1, -(header + 30), 0, header),
		text = props.title,
		textSize = plan.text.body + 3,
		font = FONT_HEAVY,
		zIndex = 62,
	}), props.subtitle ~= nil and e(Label, {
		position = UDim2.fromOffset(18, header - 10),
		size = UDim2.new(1, -36, 0, plan.text.label + 6),
		text = props.subtitle,
		textSize = plan.text.label,
		color = Palette.muted,
		zIndex = 62,
	}), e(IconButton, {
		rect = { x = r.w - header - 6, y = 6, w = header, h = header - 12 },
		icon = "Close",
		cue = "sanctuarySheetClose",
		onActivate = props.onClose,
	}), e("frame", {
		Position = UDim2.fromOffset(0, header + (if props.subtitle ~= nil then plan.text.label + 2 else 0)),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 62,
	}), e("scrollingframe", {
		Position = UDim2.fromOffset(0, header + 1 + (if props.subtitle ~= nil then plan.text.label + 2 else 0)),
		Size = UDim2.new(1, 0, 1, -(header + 1 + (if props.subtitle ~= nil then plan.text.label + 2 else 0))),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.3,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Selectable = false,
		ZIndex = 62,
	}, e("uipadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}), props.children)))
end

local function MenuTile(props)
	local hovered, pressed, events = useButtonFeel()
	return e("textbutton", {
		BackgroundColor3 = if pressed then Palette.panelRaised else Palette.panel,
		BackgroundTransparency = if hovered then 0 else 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		LayoutOrder = props.order,
		ZIndex = 63,
		ref = props.buttonRef,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = events.MouseLeave,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = events.InputBegan,
			InputEnded = events.InputEnded,
			Activated = function()
				Audio:play(props.cue or "sanctuaryClick")
				props.onActivate()
			end,
		},
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if hovered then Palette.cyan else Palette.white,
		Transparency = if hovered then 0.4 else 0.88,
		Thickness = 1,
	}), e(Icon, {
		kind = props.icon,
		size = math.floor(props.cell * 0.3),
		color = Palette.cream,
		spin = false,
		position = UDim2.new(0.5, 0, 0.42, 0),
		anchorPoint = Vector2.new(0.5, 0.5),
	}), e(Label, {
		position = UDim2.new(0, 4, 1, -24),
		size = UDim2.new(1, -8, 0, 18),
		text = props.label,
		textSize = 13,
		font = FONT_BOLD,
		color = Palette.creamSoft,
		align = Enum.TextXAlignment.Center,
		zIndex = 64,
	}))
end

local function MenuSheet(props)
	local plan = props.plan
	local columns = plan.sheetColumns
	local inner = plan.sheet.w - 28
	local pad = 10
	local cell = math.floor((inner - pad * (columns - 1)) / columns)
	local cellH = math.max(HudPlan.MIN_TAP + 20, math.floor(cell * 0.78))
	local firstRef = React.useRef(nil)
	React.useEffect(function()
		if preferGamepad() and firstRef.current ~= nil then
			GuiService.SelectedObject = firstRef.current
		end
		return nil
	end, {})
	local tiles = {
		Grid = e("uigridlayout", {
			CellSize = UDim2.fromOffset(cell, cellH),
			CellPadding = UDim2.fromOffset(pad, pad),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in props.entries do
		tiles[entry.key] = e(MenuTile, {
			order = index,
			icon = entry.icon,
			label = entry.label,
			cue = "navOpen" .. entry.key,
			cell = math.min(cell, cellH),
			buttonRef = if index == 1 then firstRef else nil,
			onActivate = function()
				props.onClose()
				props.onNavigate(entry.pageId)
			end,
		})
	end
	return e(Sheet, {
		plan = plan,
		title = "Leave the sanctuary",
		subtitle = "Pick where to go",
		reducedMotion = props.reducedMotion,
		onClose = props.onClose,
	}, tiles)
end

local function WaystoneRow(props)
	local plan = props.plan
	local hovered, pressed, events = useButtonFeel()
	local here = props.here
	return e("textbutton", {
		Size = UDim2.new(1, 0, 0, plan.sheetRow),
		BackgroundColor3 = if pressed then Palette.panelRaised else Palette.panel,
		BackgroundTransparency = if here then 0.5 elseif hovered then 0 else 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = not here,
		Active = not here,
		LayoutOrder = props.order,
		ZIndex = 63,
		ref = props.buttonRef,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = events.MouseLeave,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = events.InputBegan,
			InputEnded = events.InputEnded,
			Activated = function()
				if not here then
					Audio:play(if props.id ~= nil then "waystone" .. props.id else "waystoneTravel")
					props.onTravel()
				end
			end,
		},
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if hovered and not here then props.accent else Palette.white,
		Transparency = if hovered and not here then 0.35 else 0.88,
		Thickness = 1,
	}), e("frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Rotation = 45,
		BackgroundColor3 = props.accent,
		BorderSizePixel = 0,
		ZIndex = 64,
	}), e(Label, {
		position = UDim2.new(0, 38, 0, 0),
		size = UDim2.new(1, -120, 0.58, 0),
		text = props.name,
		textSize = plan.text.body + 1,
		font = FONT_BOLD,
		color = if here then Palette.muted else Palette.cream,
		zIndex = 64,
	}), e(Label, {
		position = UDim2.new(0, 38, 0.5, 0),
		size = UDim2.new(1, -120, 0.42, 0),
		text = props.line,
		textSize = plan.text.label,
		color = Palette.muted,
		zIndex = 64,
	}), e(Label, {
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -16, 0, 0),
		size = UDim2.new(0, 90, 1, 0),
		text = if here then "You are here" else props.status,
		textSize = plan.text.label,
		font = FONT_BOLD,
		color = if here then Palette.muted else props.accent,
		align = Enum.TextXAlignment.Right,
		zIndex = 64,
	}))
end

local function WaystoneSheet(props)
	local plan = props.plan
	local firstRef = React.useRef(nil)
	local pending, setPending = React.useState(nil)
	local problem, setProblem = React.useState("")
	React.useEffect(function()
		if preferGamepad() and firstRef.current ~= nil then
			GuiService.SelectedObject = firstRef.current
		end
		return nil
	end, {})
	local rows = {
		Layout = e("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	local firstAssigned = false
	for index, stone in Layout.waystones() do
		local region = Layout.region(stone.Region)
		local oreId = region and region.Ore
		local accent = if oreId ~= nil then ORE_COLORS[oreId] elseif stone.Id == "Riftmaw" then RIFT else Palette.mango
		local here = stone.Id == props.from
		local useRef = not here and not firstAssigned
		if useRef then
			firstAssigned = true
		end
		rows[stone.Id] = e(WaystoneRow, {
			order = index,
			plan = plan,
			id = stone.Id,
			name = stone.Name,
			line = REGION_LINES[stone.Id] or "",
			accent = accent,
			here = here,
			status = if pending == stone.Id then "Opening…" else "Travel",
			buttonRef = if useRef then firstRef else nil,
			onTravel = function()
				if pending ~= nil then
					return
				end
				setPending(stone.Id)
				setProblem("")
				props.dispatch("TravelWaystone", { To = stone.Id }, function(response)
					setPending(nil)
					if type(response) == "table" and response.ok == true then
						props.onClose()
					elseif type(response) == "table" and type(response.error) == "string" then
						setProblem(response.error)
					end
				end)
			end,
		})
	end
	if problem ~= "" then
		rows.Problem = e(Label, {
			size = UDim2.new(1, 0, 0, 22),
			text = problem,
			textSize = plan.text.label + 1,
			color = Palette.coral,
			zIndex = 64,
		})
	end
	return e(Sheet, {
		plan = plan,
		title = "Waystones",
		subtitle = "Step through to any region",
		reducedMotion = props.reducedMotion,
		onClose = props.onClose,
	}, rows)
end

-- Key hint (mouse and keyboard)

local function KeyHint(props)
	local plan = props.plan
	local r = plan.hint
	if r == nil then
		return nil
	end
	local position, size = rectProps(r)
	return e(Label, {
		position = position,
		size = size,
		text = props.text,
		textSize = plan.text.label,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
		zIndex = 50,
	})
end

-- The HUD

local function SanctuaryHud(props)
	local plan = props.plan
	local reduced = props.reducedMotion == true
	local warden = useWarden()
	local inArena = useInArena()
	local banner, setBanner = React.useState(nil :: BannerMessage?)
	local bannerVisible, setBannerVisible = React.useState(false)
	local bannerSeq = React.useRef(0)
	local region, setRegion = React.useState("Heart")
	local sheet, setSheet = React.useState(nil :: string?)
	local sheetFrom, setSheetFrom = React.useState("Heart")
	local hits, setHits = React.useState({} :: { Hit })
	local hitSeq = React.useRef(0)
	local status, setStatus = React.useState("")
	local statusSeq = React.useRef(0)
	local dazedUntil, setDazedUntil = React.useState(0)
	local lastStrike = React.useRef(0)
	local striking = React.useRef(false)
	local holding = React.useRef(false)
	local recallAt, setRecallAt = React.useState(-math.huge)
	local cooldown, setCooldown = React.useBinding(0)
	local recharge, setRecharge = React.useBinding(0)
	local lastDefeat = React.useRef(0)

	local canStrike = warden.phase == "Active" and inArena

	local function showBanner(eyebrow: string, title: string, line: string, accent: Color3, seconds: number?)
		bannerSeq.current += 1
		local seq = bannerSeq.current
		setBanner({ key = seq, eyebrow = eyebrow, title = title, line = line, accent = accent })
		setBannerVisible(true)
		task.delay(seconds or BANNER_SECONDS, function()
			if bannerSeq.current == seq then
				setBannerVisible(false)
			end
		end)
	end

	local function flashStatus(text: string)
		statusSeq.current += 1
		local seq = statusSeq.current
		setStatus(text)
		task.delay(1.4, function()
			if statusSeq.current == seq then
				setStatus("")
			end
		end)
	end

	local function pushHit(damage: number, crit: boolean)
		hitSeq.current += 1
		local id = hitSeq.current
		setHits(function(current)
			local nextHits = table.clone(current)
			table.insert(nextHits, { id = id, text = if crit then `CRIT {compact(damage)}` else compact(damage), crit = crit })
			while #nextHits > 6 do
				table.remove(nextHits, 1)
			end
			return nextHits
		end)
		task.delay(0.85, function()
			setHits(function(current)
				local kept = {}
				for _, hit in current do
					if hit.id ~= id then
						table.insert(kept, hit)
					end
				end
				return kept
			end)
		end)
	end

	-- One strike attempt, if the cooldown and the Warden allow it.
	local strikeRef = React.useRef(nil :: (() -> ())?)
	local function strike()
		if not canStrike or striking.current then
			return
		end
		local now = os.clock()
		if now < dazedUntil or now - lastStrike.current < STRIKE_COOLDOWN then
			return
		end
		lastStrike.current = now
		striking.current = true
		props.dispatch("StrikeRiftBoss", {}, function(response)
			striking.current = false
			if type(response) ~= "table" then
				return
			end
			if response.ok == true then
				local damage = tonumber(response.Damage) or 0
				local crit = response.Crit == true
				Audio:play(if crit then "wardenCrit" else "wardenStrike")
				pushHit(damage, crit)
				Signals.fire("StrikeLanded", { Damage = damage, Crit = crit })
				if crit then
					Controls.shake(0.35)
				end
			elseif type(response.error) == "string" then
				local lowered = string.lower(response.error)
				if string.find(lowered, "working", 1, true) == nil and string.find(lowered, "too fast", 1, true) == nil and string.find(lowered, "busy", 1, true) == nil then
					flashStatus(response.error)
				end
			end
		end)
	end
	strikeRef.current = strike

	-- Cooldown sweeps for strike and recall, driven while they matter.
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local strikeLeft = math.max(0, STRIKE_COOLDOWN - (now - lastStrike.current))
			local dazeLeft = math.max(0, dazedUntil - now)
			if dazeLeft > 0 then
				setCooldown(dazeLeft / BOSS.DazeSeconds)
			else
				setCooldown(strikeLeft / STRIKE_COOLDOWN)
			end
			setRecharge(math.clamp(1 - (now - recallAt) / RECALL_COOLDOWN, 0, 1))
			-- Held button or key: keep striking at the cooldown.
			if holding.current and strikeRef.current ~= nil then
				strikeRef.current()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { dazedUntil, recallAt } :: { any })

	-- Keys: F / R2 strike (hold to keep striking), Esc / B closes a sheet.
	React.useEffect(function()
		local began = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				if sheet ~= nil then
					setSheet(nil)
				end
				return
			end
			if processed or sheet ~= nil then
				return
			end
			if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
				holding.current = true
				if strikeRef.current ~= nil then
					strikeRef.current()
				end
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
				holding.current = false
			end
		end)
		return function()
			began:Disconnect()
			ended:Disconnect()
			holding.current = false
		end
	end, { sheet })

	-- Movement pauses while a sheet is open.
	React.useEffect(function()
		Controls.setEnabled(sheet == nil)
		return function()
			Controls.setEnabled(true)
		end
	end, { sheet })

	-- Sanctuary events.
	React.useEffect(function()
		local unsubscribe = {
			Signals.on("RegionChanged", function(payload)
				if type(payload) ~= "table" or type(payload.Id) ~= "string" then
					return
				end
				setRegion(payload.Id)
				if payload.Id == "Bridge" then
					return
				end
				local layoutRegion = Layout.region(payload.Id)
				local oreId = layoutRegion and layoutRegion.Ore
				local accent = if oreId ~= nil then ORE_COLORS[oreId] elseif payload.Id == "Riftmaw" then RIFT else Palette.mango
				showBanner(if payload.Id == "Heart" then "The sanctuary" else "Entering", tostring(payload.Name), REGION_LINES[payload.Id] or "", accent)
			end),
			Signals.on("WaystoneOpen", function(payload)
				setSheetFrom(if type(payload) == "table" and type(payload.From) == "string" then payload.From else "Heart")
				setSheet("waystones")
			end),
			Signals.on("RiftBossAwake", function()
				showBanner("The rift opens", "The Rift Warden has woken", "Strike it in the Riftmaw", RIFT, 3.4)
			end),
			Signals.on("RiftBossStagger", function(payload)
				local seconds = if type(payload) == "table" then tonumber(payload.Daze) or BOSS.DazeSeconds else BOSS.DazeSeconds
				setDazedUntil(os.clock() + seconds)
			end),
			Signals.on("RiftBossDefeated", function(payload)
				lastDefeat.current = os.clock()
				local share = if type(payload) == "table" then tonumber(payload.Share) or 0 else 0
				showBanner("Victory", "The Rift Warden falls", `Your share of the fight: {math.floor(share * 100 + 0.5)}%`, Palette.mango, 4)
			end),
			Signals.on("RiftBossFell", function()
				task.delay(0.6, function()
					if os.clock() - lastDefeat.current > 2 then
						showBanner("The rift closes", "The Rift Warden falls", "Strike it next time to share the spoils", RIFT, 3.4)
					end
				end)
			end),
		}
		return function()
			for _, stop in unsubscribe do
				stop()
			end
		end
	end, {})

	-- Stop holding when the Warden can't be struck.
	React.useEffect(function()
		if not canStrike then
			holding.current = false
		end
		return nil
	end, { canStrike })

	local function recall()
		local now = os.clock()
		if now - recallAt < RECALL_COOLDOWN then
			return
		end
		setRecallAt(now)
		props.dispatch("TravelWaystone", { Recall = true }, function(response)
			if type(response) == "table" and response.ok ~= true then
				-- Refused (already home, or cooling on the server): free the button.
				setRecallAt(-math.huge)
			end
		end)
	end

	local hintText = if canStrike
		then "F to strike · Shift to run · Right-drag to look"
		elseif region == "Emberreach" or region == "Hollows" or region == "Spire"
		then "Hold E at a glowing outcrop to mine"
		else "WASD to move · Shift to run · Right-drag to look"

	return e("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
	}, e(Banner, {
		plan = plan,
		message = banner,
		visible = bannerVisible,
		reducedMotion = reduced,
	}), e(OreChips, {
		plan = plan,
		ore = props.ore,
		reducedMotion = reduced,
	}), e(WardenBar, {
		plan = plan,
		warden = warden,
		inArena = inArena,
		reducedMotion = reduced,
	}), plan.menuButton ~= nil and e(IconButton, {
		rect = plan.menuButton,
		icon = "Menu",
		cue = "sanctuaryMenu",
		onActivate = function()
			setSheet("menu")
		end,
	}), e(RecallButton, {
		plan = plan,
		cooling = os.clock() - recallAt < RECALL_COOLDOWN,
		recharge = recharge,
		onRecall = recall,
	}), canStrike and e(StrikeButton, {
		plan = plan,
		cooldown = cooldown,
		dazedUntil = dazedUntil,
		hits = hits,
		status = status,
		onStrike = strike,
		onHold = function(held: boolean)
			holding.current = held
			if held then
				strike()
			end
		end,
	}), not plan.touch and e(KeyHint, {
		plan = plan,
		text = hintText,
	}), sheet == "menu" and e(MenuSheet, {
		plan = plan,
		entries = props.entries,
		reducedMotion = reduced,
		onNavigate = props.onNavigate,
		onClose = function()
			setSheet(nil)
		end,
	}), sheet == "waystones" and e(WaystoneSheet, {
		plan = plan,
		from = sheetFrom,
		dispatch = props.dispatch,
		reducedMotion = reduced,
		onClose = function()
			setSheet(nil)
		end,
	}))
end

return {
	SanctuaryHud = SanctuaryHud,
	REGION_LINES = REGION_LINES,
}
end

-- ======================================================================
-- Module: sanctuaryHudPlan   (merged from sanctuaryHudPlan.luau, 359 lines)
-- ======================================================================
__defs["sanctuaryHudPlan"] = function()
-- Where everything goes on screen while the player walks the sanctuary.
--
-- One pure function turns the safe-area size and input kind into pixel
-- rectangles for every piece of sanctuary UI: the navigation docks (or the
-- menu button that replaces them), the ore chips, the Warden bar, the strike
-- and recall buttons, the touch jump/run cluster, the thumbstick zone and the
-- sheets. The HUD, the curtain docks and the touch controls all read the same
-- plan, so they can never disagree about who owns a corner.
--
-- Rules the plan keeps at every size (scripts/verify_sanctuary_hud_plan.luau
-- sweeps hundreds of screens to hold it to them):
--   * every rectangle lies inside the safe area;
--   * no two interactive rectangles overlap, and none sits in the
--     thumbstick zone;
--   * touch targets are at least MIN_TAP pixels on both sides;
--   * the docks become a single menu button whenever a column of them would
--     not fit at a comfortable size.
--
-- Coordinates are pixels from the top-left of the CoreUISafeInsets area.
-- No Roblox services are used, so Lune can run it.

type Rect = { x: number, y: number, w: number, h: number }

type Input = {
	width: number,
	height: number,
	touch: boolean,
	-- Entries per dock column (both columns hold the same count).
	dockEntries: number?,
}

type Plan = {
	width: number,
	height: number,
	touch: boolean,
	portrait: boolean,
	edge: number,
	gap: number,
	-- "columns": two vertical docks. "menu": one button opens a sheet.
	dockMode: string,
	dockButton: number,
	dockGap: number,
	dockLeft: Rect?,
	dockRight: Rect?,
	menuButton: Rect?,
	-- Ore chips and the Warden bar.
	ore: Rect,
	oreChip: number,
	oreCompact: boolean,
	warden: Rect,
	-- Buttons.
	strike: Rect,
	recall: Rect,
	jump: Rect?,
	run: Rect?,
	stickZone: Rect?,
	-- Transient, non-interactive.
	banner: Rect,
	hint: Rect?,
	-- Centered sheets (menu, waystone travel).
	sheet: Rect,
	sheetColumns: number,
	sheetRow: number,
	text: { title: number, body: number, label: number, number: number },
}

local Plan = {}

Plan.MIN_TAP = 44
Plan.ORE_KINDS = 3

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = math.floor(x), y = math.floor(y), w = math.max(0, math.floor(w)), h = math.max(0, math.floor(h)) }
end

local function clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

-- Do two rectangles share any area? Touching edges do not count.
function Plan.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function Plan.inside(inner: Rect, width: number, height: number): boolean
	return inner.x >= 0 and inner.y >= 0 and inner.x + inner.w <= width and inner.y + inner.h <= height
end

-- The interactive rectangles of a plan, by name, for overlap checks.
function Plan.interactive(plan: Plan): { [string]: Rect }
	local result: { [string]: Rect } = {
		ore = plan.ore,
		warden = plan.warden,
		strike = plan.strike,
		recall = plan.recall,
	}
	if plan.dockLeft ~= nil then
		result.dockLeft = plan.dockLeft
	end
	if plan.dockRight ~= nil then
		result.dockRight = plan.dockRight
	end
	if plan.menuButton ~= nil then
		result.menuButton = plan.menuButton
	end
	if plan.jump ~= nil then
		result.jump = plan.jump
	end
	if plan.run ~= nil then
		result.run = plan.run
	end
	return result
end

function Plan.compute(input: Input): Plan
	local width = math.max(200, math.floor(input.width))
	local height = math.max(200, math.floor(input.height))
	local touch = input.touch == true
	local entries = math.max(1, input.dockEntries or 6)
	local short = math.min(width, height)
	local portrait = height > width
	local edge = clamp(math.floor(short * 0.03), 10, 24)
	local gap = clamp(math.floor(short * 0.018), 6, 12)
	local tap = if touch then Plan.MIN_TAP else 36

	local text = {
		title = clamp(math.floor(short * 0.05), 20, 34),
		body = clamp(math.floor(short * 0.03), 13, 17),
		label = clamp(math.floor(short * 0.024), 11, 14),
		number = clamp(math.floor(short * 0.034), 14, 20),
	}

	-- The top strip holds, left to right: the menu button (menu mode), the
	-- recall button (touch), the Warden bar, the ore chips.
	local stripH = math.max(tap, clamp(math.floor(short * 0.075), 36, 48))
	local top = edge

	-- Touch cluster first: it owns the bottom-right corner on touch screens.
	local jump: Rect? = nil
	local run: Rect? = nil
	local clusterTop = height - edge
	if touch then
		local jumpSize = clamp(math.floor(short * 0.19), 64, 96)
		local runSize = math.max(Plan.MIN_TAP, math.floor(jumpSize * 0.74))
		local j = rect(width - edge - jumpSize, height - edge - jumpSize, jumpSize, jumpSize)
		local r = rect(j.x - math.floor(gap * 1.5) - runSize, height - edge - runSize - math.floor(jumpSize * 0.35), runSize, runSize)
		jump, run = j, r
		clusterTop = math.min(j.y, r.y)
	end

	-- Strike: the big action. On touch it sits above the jump button, in the
	-- thumb's arc; with a mouse or gamepad it is a wide pill at bottom center.
	local strike: Rect
	if touch then
		local j = jump :: Rect
		local size = math.max(Plan.MIN_TAP, math.floor(j.w * 0.96))
		strike = rect(j.x + j.w - size, clusterTop - gap * 2 - size, size, size)
	else
		local w = clamp(math.floor(width * 0.2), 160, 260)
		local h = clamp(math.floor(short * 0.07), 44, 56)
		strike = rect((width - w) / 2, height - edge - h, w, h)
	end

	-- Recall. Touch: a square beside the menu button, so the lower-left stays
	-- free for the thumbstick. Mouse/gamepad: a pill at the bottom-left.
	local recallW = if touch then stripH else math.max(tap, clamp(math.floor(short * 0.2), 96, 132))
	local recallH = if touch then stripH else math.max(tap, clamp(math.floor(short * 0.06), 36, 44))
	local menuSize = math.max(tap, clamp(math.floor(short * 0.075), 40, 52))

	local dockGap = clamp(math.floor(short * 0.014), 8, 14)
	local dockButton = 0
	local dockLeft: Rect? = nil
	local dockRight: Rect? = nil
	local menuButton: Rect? = nil
	local recall = rect(0, 0, recallW, recallH)
	local ore = rect(0, 0, 0, 0)
	local warden = rect(0, 0, 0, 0)
	local chip = 0
	local oreCompact = false
	local wardenH = clamp(math.floor(short * 0.085), 44, 58)

	-- Lays out the top strip from `leftEdge` (the first free x) and returns
	-- the lowest y the top rows reach.
	local function placeTop(leftEdge: number): number
		local chipGap = math.max(4, math.floor(gap * 0.6))
		chip = clamp(math.floor(width * 0.085), 60, 112)
		oreCompact = false
		local room = width - edge - leftEdge
		if chip * Plan.ORE_KINDS + chipGap * (Plan.ORE_KINDS - 1) > room then
			chip = math.floor((room - chipGap * (Plan.ORE_KINDS - 1)) / Plan.ORE_KINDS)
		end
		if chip < 72 then
			oreCompact = true
		end
		local oreW = chip * Plan.ORE_KINDS + chipGap * (Plan.ORE_KINDS - 1)
		ore = rect(width - edge - oreW, top, oreW, stripH)
		-- The Warden bar: centred between the left group and the chips when it
		-- fits with room to breathe, otherwise its own row beneath the strip.
		local between = ore.x - gap - leftEdge
		if between >= 260 then
			-- Centred on the screen, and only nudged aside when it would touch
			-- the menu/recall group or the ore chips.
			local w = math.min(520, between)
			local x = math.clamp((width - w) / 2, leftEdge, ore.x - gap - w)
			warden = rect(x, top, w, math.max(stripH, wardenH))
		else
			local w = math.min(520, width - 2 * edge)
			warden = rect((width - w) / 2, top + stripH + gap, w, wardenH)
		end
		return math.max(ore.y + ore.h, warden.y + warden.h)
	end

	local function menuMode(): number
		dockLeft, dockRight = nil, nil
		dockButton = menuSize
		menuButton = rect(edge, top, menuSize, stripH)
		local leftEdge = edge + menuSize + gap
		if touch then
			recall = rect(leftEdge, top, recallW, recallH)
			leftEdge = recall.x + recall.w + gap
		end
		return placeTop(leftEdge)
	end

	-- Docks: two columns when they fit comfortably (and never on touch, where
	-- the edges belong to thumbs), otherwise one menu button.
	local dockMode = "menu"
	local topOccupied: number
	if touch then
		topOccupied = menuMode()
	else
		topOccupied = placeTop(edge)
		local bandTop = topOccupied + gap
		local bandBottom = height - edge - math.max(strike.h, recallH) - gap
		local band = bandBottom - bandTop
		local button = math.min(64, math.floor((band - dockGap * (entries - 1)) / entries))
		local centerRoom = width - 2 * (edge + button + gap)
		if button >= 46 and centerRoom >= math.max(360, strike.w + 2 * (recallW + gap)) then
			dockMode = "columns"
			dockButton = button
			local columnH = button * entries + dockGap * (entries - 1)
			local y = bandTop + math.floor((band - columnH) / 2)
			dockLeft = rect(edge, y, button, columnH)
			dockRight = rect(width - edge - button, y, button, columnH)
		else
			topOccupied = menuMode()
		end
	end

	if not touch then
		recall = rect(edge, height - edge - recallH, recallW, recallH)
		-- A narrow window: the centred strike pill would cover recall, so it
		-- moves to the bottom-right; narrower still, recall steps up a row.
		if Plan.overlaps(strike, recall) then
			strike = rect(width - edge - strike.w, strike.y, strike.w, strike.h)
			if Plan.overlaps(strike, recall) then
				recall = rect(edge, strike.y - gap - recallH, recallW, recallH)
			end
		end
	end

	-- Strike must never climb into the top rows on a short touch screen: shrink
	-- it into the space above the cluster, or else set it left of run.
	if touch and strike.y < topOccupied + gap then
		local j = jump :: Rect
		local r = run :: Rect
		local size = math.min(math.floor(j.w * 0.96), clusterTop - gap * 2 - (topOccupied + gap))
		if size >= Plan.MIN_TAP then
			strike = rect(j.x + j.w - size, clusterTop - gap * 2 - size, size, size)
		else
			size = math.max(Plan.MIN_TAP, math.min(j.w, r.x - gap - math.floor(width * 0.5)))
			strike = rect(r.x - gap - size, height - edge - size, size, size)
		end
	end

	-- Thumbstick zone: the lower-left, below the top rows and clear of the
	-- right-hand cluster.
	local stickZone: Rect? = nil
	if touch then
		local zoneTop = topOccupied + gap
		local right = math.floor(width * 0.5)
		for _, other in { run :: Rect, strike } do
			if other.x < right and other.y + other.h > zoneTop then
				right = math.min(right, other.x - gap)
			end
		end
		stickZone = rect(0, zoneTop, math.max(0, right), height - zoneTop)
	end

	-- Region banner: the upper third, never interactive.
	local bannerW = math.min(width - 2 * edge, 560)
	local bannerH = text.title * 2 + 24
	local bannerY = math.min(math.max(topOccupied + gap, math.floor(height * 0.2)), height - bannerH - edge)
	local banner = rect((width - bannerW) / 2, math.max(0, bannerY), bannerW, bannerH)

	-- The key hint row, mouse/keyboard only: bottom-right, dropped if crowded.
	local hint: Rect? = nil
	if not touch then
		local w = clamp(math.floor(width * 0.24), 180, 320)
		local h = text.label + 12
		local candidate = rect(width - edge - w, height - edge - h, w, h)
		local clear = not Plan.overlaps(candidate, strike) and not Plan.overlaps(candidate, recall)
		if dockRight ~= nil and Plan.overlaps(candidate, dockRight) then
			clear = false
		end
		if clear then
			hint = candidate
		end
	end

	-- Sheets: centered, capped, and clear of the notch area by the edge margin.
	local sheetW = math.min(width - 2 * edge, 560)
	local sheetH = math.min(height - 2 * edge, 520)
	local sheet = rect((width - sheetW) / 2, (height - sheetH) / 2, sheetW, sheetH)
	local sheetColumns = if sheetW >= 520 then 4 elseif sheetW >= 380 then 3 else 2
	local sheetRow = math.max(tap, clamp(math.floor(short * 0.1), 48, 64))

	return {
		width = width,
		height = height,
		touch = touch,
		portrait = portrait,
		edge = edge,
		gap = gap,
		dockMode = dockMode,
		dockButton = dockButton,
		dockGap = dockGap,
		dockLeft = dockLeft,
		dockRight = dockRight,
		menuButton = menuButton,
		ore = ore,
		oreChip = chip,
		oreCompact = oreCompact,
		warden = warden,
		strike = strike,
		recall = recall,
		jump = jump,
		run = run,
		stickZone = stickZone,
		banner = banner,
		hint = hint,
		sheet = sheet,
		sheetColumns = sheetColumns,
		sheetRow = sheetRow,
		text = text,
	}
end

-- UDim2 helpers for the plan's rectangles (Roblox only).
function Plan.position(r: Rect): UDim2
	return UDim2.fromOffset(r.x, r.y)
end

function Plan.size(r: Rect): UDim2
	return UDim2.fromOffset(r.w, r.h)
end

return Plan
end

-- ======================================================================
-- Module: sanctuarySignals   (merged from sanctuarySignals.luau, 65 lines)
-- ======================================================================
__defs["sanctuarySignals"] = function()
-- A small event bus for the sanctuary.
--
-- Server effects arrive in one place (MainGame's effect listener). Several
-- client systems care about the sanctuary ones -- the world controller that
-- draws them and the HUD that reports them -- so MainGame forwards those here
-- and each system subscribes to what it needs. Client-side events (a waystone
-- opened, a region entered) travel the same way.

local Signals = {}

-- Server effect types MainGame forwards to the bus.
Signals.SERVER_KINDS = table.freeze({
	OreMined = true,
	OreCooldowns = true,
	RiftBossAwake = true,
	RiftBossSlam = true,
	RiftBossSlamLand = true,
	RiftBossStagger = true,
	RiftBossDefeated = true,
	RiftBossFell = true,
	WaystoneArrived = true,
})

local listeners: { [string]: { [(any) -> ()]: boolean } } = {}

function Signals.handles(kind: string): boolean
	return Signals.SERVER_KINDS[kind] == true
end

-- Subscribe; returns a function that unsubscribes.
function Signals.on(kind: string, callback: (any) -> ()): () -> ()
	local bucket = listeners[kind]
	if bucket == nil then
		bucket = {}
		listeners[kind] = bucket
	end
	bucket[callback] = true
	return function()
		local current = listeners[kind]
		if current ~= nil then
			current[callback] = nil
		end
	end
end

function Signals.fire(kind: string, payload: any)
	local bucket = listeners[kind]
	if bucket == nil then
		return
	end
	-- Copy first: a listener may unsubscribe (or subscribe) while we iterate.
	local snapshot = {}
	for callback in bucket do
		table.insert(snapshot, callback)
	end
	for _, callback in snapshot do
		local ok, problem = pcall(callback :: (any) -> any, payload)
		if not ok then
			warn(`[sanctuary] {kind} listener failed: {problem}`)
		end
	end
end

return Signals
end

-- ======================================================================
-- Module: sanctuaryWorld   (merged from sanctuaryWorld.luau, 1119 lines)
-- ======================================================================
__defs["sanctuaryWorld"] = function()
-- The sanctuary, as the client sees it.
--
--   * Scenery tagged AF_Spin / AF_Bob / AF_Pulse is animated here in one
--     batched update (BulkMoveTo), only near the camera.
--   * Ore outcrops are drawn per player: a node you mined sinks and dims, then
--     grows back when its regrow time passes. Holding the mining prompt makes
--     its crystals tremble.
--   * The Rift Warden's body is built and animated entirely on the client from
--     the server's anchor (phase, health, timing attributes): it forms out of
--     the rift, reacts to hits, winds up and slams, shatters when defeated and
--     folds away if it escapes.
--   * Slam telegraphs, shockwaves and staggers.
--   * Which region the player stands in, and waystone use.
--
-- Nothing here is authoritative: the server decides every outcome. All client
-- parts are CanQuery = false so the camera's collision probe ignores them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.AudioKit)("audio").Audio
local Signals = __load("sanctuarySignals")
local Controls = __load("sanctuaryControls")
local Ambience = __load("sanctuaryAmbience")
local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("SharedData"))("SanctuaryLayout")
local SanctuaryConfig = require(Shared:WaitForChild("SharedData"))("SanctuaryConfig")
local AssetKit = require(Shared:WaitForChild("SharedData"))("AssetKit")
local Vfx = require(Shared:WaitForChild("SharedData"))("Vfx")

local World = {}

local TAU = math.pi * 2
local ANIMATE_RANGE = 420
local ORIGIN = Vector3.new(Layout.ORIGIN.X, Layout.ORIGIN.Y, Layout.ORIGIN.Z)
local RIFT = Color3.fromRGB(128, 92, 255)
local RIFT_HOT = Color3.fromRGB(214, 196, 255)
local SLAM = Color3.fromRGB(255, 84, 120)
local DEPLETED = 0.26

type AnimEntry = {
	base: CFrame,
	spin: number,
	amplitude: number,
	period: number,
	phase: number,
	pulse: number?,
	light: PointLight?,
	lightBase: number,
	transparencyBase: number,
	-- Spin about the world's up axis (tilted rings) instead of the part's own.
	worldSpin: boolean,
}

type Crystal = { part: BasePart, restCFrame: CFrame, restSize: Vector3, restTransparency: number }

type NodeEntry = {
	id: string,
	ore: string,
	crystals: { Crystal },
	light: PointLight?,
	lightBase: number,
	sparkle: ParticleEmitter?,
	aura: ParticleEmitter?,
	prompt: ProximityPrompt?,
	fill: number,
	ready: boolean,
	trembling: boolean,
}

local active = false
local connections: { RBXScriptConnection } = {}
local unsubscribers: { () -> () } = {}
local animated: { [BasePart]: AnimEntry } = {}
local nodes: { [Model]: NodeEntry } = {}
local readyAt: { [string]: number } = {}
local clientFolder: Folder? = nil
local currentRegion: string? = nil
-- The Warden's body waits for the model kit (or for knowing there is none).
local kitSettled = false
local regionClock = 0

local function track(connection: RBXScriptConnection)
	table.insert(connections, connection)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function oreColor(oreId: string): (Color3, Color3)
	for _, ore in SanctuaryConfig.Ore.Types do
		if ore.Id == oreId then
			return rgb(ore.Color), rgb(ore.Glow)
		end
	end
	return Color3.new(1, 1, 1), Color3.new(1, 1, 1)
end

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- A client-only part: never collides, never blocks the camera probe.
local function vfxPart(name: string, shape: Enum.PartType?, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape ~= nil then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = clientFolder
	return p
end

-- Scenery animation

local function entryFor(part: BasePart): AnimEntry
	local entry = animated[part]
	if entry == nil then
		local light = part:FindFirstChildOfClass("PointLight")
		entry = {
			base = part.CFrame,
			spin = 0,
			amplitude = 0,
			period = 4,
			phase = (part.Position.X * 0.37 + part.Position.Z * 0.21) % 10,
			pulse = nil,
			light = light,
			lightBase = if light ~= nil then light.Brightness else 0,
			transparencyBase = part.Transparency,
			worldSpin = false,
		}
		animated[part] = entry
	end
	return entry :: AnimEntry
end

local function registerTagged(tag: string, instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local entry = entryFor(instance)
	if tag == "AF_Spin" then
		entry.spin = tonumber(instance:GetAttribute("Speed")) or 30
		entry.worldSpin = instance:GetAttribute("World") == true
	elseif tag == "AF_Bob" then
		entry.amplitude = tonumber(instance:GetAttribute("Amplitude")) or 1
		entry.period = math.max(0.5, tonumber(instance:GetAttribute("Period")) or 4)
	elseif tag == "AF_Pulse" then
		entry.pulse = math.max(0.5, tonumber(instance:GetAttribute("Period")) or 3)
	end
end

local function restoreAnimated()
	for part, entry in animated do
		if part.Parent ~= nil then
			part.CFrame = entry.base
			part.Transparency = entry.transparencyBase
			if entry.light ~= nil then
				entry.light.Brightness = entry.lightBase
			end
		end
	end
	table.clear(animated)
end

local function stepScenery(t: number, cameraPosition: Vector3)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for part, entry in animated do
		if part.Parent == nil then
			animated[part] = nil
			continue
		end
		if (entry.base.Position - cameraPosition).Magnitude > ANIMATE_RANGE then
			continue
		end
		if entry.spin ~= 0 or entry.amplitude ~= 0 then
			local frame = entry.base
			if entry.amplitude ~= 0 then
				frame += Vector3.new(0, math.sin((t + entry.phase) * TAU / entry.period) * entry.amplitude, 0)
			end
			if entry.spin ~= 0 then
				local turn = CFrame.Angles(0, math.rad(entry.spin * t) % TAU, 0)
				frame = if entry.worldSpin then CFrame.new(frame.Position) * turn * frame.Rotation else frame * turn
			end
			table.insert(parts, part)
			table.insert(frames, frame)
		end
		local pulse = entry.pulse
		if pulse ~= nil then
			local wave = 0.5 + 0.5 * math.sin((t + entry.phase) * TAU / pulse)
			if entry.light ~= nil then
				entry.light.Brightness = entry.lightBase * (0.7 + 0.3 * wave)
			end
			part.Transparency = math.clamp(entry.transparencyBase + 0.14 * (1 - wave), 0, 1)
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Ore outcrops

local function registerNode(model: Instance)
	if not model:IsA("Model") or nodes[model] ~= nil then
		return
	end
	local id = model:GetAttribute("NodeId")
	local ore = model:GetAttribute("Ore")
	if type(id) ~= "string" or type(ore) ~= "string" then
		return
	end
	local crystals: { Crystal } = {}
	local light: PointLight? = nil
	local sparkle: ParticleEmitter? = nil
	local aura: ParticleEmitter? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Crystal" or child.Name == "Core") then
			local rest = child:GetAttribute("RestSize")
			table.insert(crystals, {
				part = child,
				restCFrame = child.CFrame,
				restSize = if typeof(rest) == "Vector3" then rest else child.Size,
				restTransparency = child.Transparency,
			})
			light = light or child:FindFirstChild("Glow") :: PointLight?
			sparkle = sparkle or child:FindFirstChild("Sparkle") :: ParticleEmitter?
			aura = aura or child:FindFirstChild("Aura") :: ParticleEmitter?
		end
	end
	local seat = model:FindFirstChild("Seat")
	local prompt = seat and seat:FindFirstChild("MinePrompt")
	nodes[model] = {
		id = id,
		ore = ore,
		crystals = crystals,
		light = light,
		lightBase = if light ~= nil then light.Brightness else 0,
		sparkle = sparkle,
		aura = aura,
		prompt = if prompt ~= nil and prompt:IsA("ProximityPrompt") then prompt else nil,
		fill = 1,
		ready = true,
		trembling = false,
	}
end

local function applyFill(entry: NodeEntry, t: number)
	local scale = DEPLETED + (1 - DEPLETED) * entry.fill
	local tremble = if entry.trembling then math.sin(t * 60) * 0.05 else 0
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, crystal in entry.crystals do
		local size = crystal.restSize * scale
		local foot = crystal.restCFrame * CFrame.new(0, -crystal.restSize.Y / 2, 0)
		crystal.part.Size = size
		table.insert(parts, crystal.part)
		table.insert(frames, foot * CFrame.new(tremble, size.Y / 2, 0))
		crystal.part.Transparency = math.clamp(crystal.restTransparency + (1 - entry.fill) * 0.45, 0, 1)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if entry.light ~= nil then
		entry.light.Brightness = entry.lightBase * entry.fill
	end
	if entry.sparkle ~= nil then
		entry.sparkle.Enabled = entry.fill > 0.9
	end
	if entry.aura ~= nil then
		entry.aura.Enabled = entry.fill > 0.9
	end
end

local function stepNodes(dt: number, t: number)
	local now = serverNow()
	for model, entry in nodes do
		if model.Parent == nil then
			nodes[model] = nil
			continue
		end
		local ready = (readyAt[entry.id] or 0) <= now
		if ready ~= entry.ready then
			entry.ready = ready
			if entry.prompt ~= nil then
				entry.prompt.Enabled = ready
			end
		end
		local target = if ready then 1 else 0
		if entry.fill ~= target or entry.trembling then
			-- Sinks fast and settles when mined; grows back gently. An eased
			-- approach (the same at any frame rate) rather than a constant speed,
			-- so the motion slows into place instead of stopping dead.
			local rate = if target > entry.fill then 2.6 else 9
			entry.fill += (target - entry.fill) * (1 - math.exp(-rate * dt))
			if math.abs(target - entry.fill) < 0.002 then
				entry.fill = target
			end
			applyFill(entry, t)
		end
	end
end

local function nodeById(id: string): (Model?, NodeEntry?)
	for model, entry in nodes do
		if entry.id == id then
			return model, entry
		end
	end
	return nil, nil
end

-- Floating "+4 Emberite" over a node, rising and fading.
local function floatText(at: Vector3, text: string, color: Color3)
	local anchor = vfxPart("FloatAnchor", nil, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(at)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(180, 40)
	board.StudsOffset = Vector3.new(0, 0, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	label.Parent = board
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / 1.3, 0, 1)
		board.StudsOffset = Vector3.new(0, 1 + k * 3.5, 0)
		label.TextTransparency = k * k
		label.TextStrokeTransparency = 0.4 + 0.6 * k * k
		if k >= 1 and connection ~= nil then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
end

-- A textured burst: glinting shards, a bright core flash and a quick light.
local function burst(at: Vector3, color: Color3, count: number, speed: number)
	local folder = clientFolder
	Vfx.burst(at, "Shatter", count, { Color = color, Color2 = Color3.new(1, 1, 1):Lerp(color, 0.5), Speed = NumberRange.new(speed * 0.5, speed) }, folder)
	Vfx.burst(at, "Flash", 1, { Color = color, Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 3.5),
		NumberSequenceKeypoint.new(1, 4),
	}) }, folder)
	local holder = vfxPart("BurstLight", nil, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(at)
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Range = 16
	flash.Brightness = 4
	flash.Parent = holder
	task.delay(0.12, function()
		flash.Brightness = 1.5
	end)
	task.delay(0.3, function()
		holder:Destroy()
	end)
end
local function onOreMined(payload)
	if type(payload) ~= "table" or type(payload.NodeId) ~= "string" then
		return
	end
	if type(payload.ReadyAt) == "number" then
		readyAt[payload.NodeId] = payload.ReadyAt
	end
	local model = nodeById(payload.NodeId)
	local color, glowColor = oreColor(tostring(payload.Ore))
	local oreId = tostring(payload.Ore)
	local mineCue = if oreId == "Emberite" or oreId == "Voidglass" or oreId == "Starsteel" then "oreMine" .. oreId else "oreMine"
	local collectCue = if oreId == "Emberite" or oreId == "Voidglass" or oreId == "Starsteel" then "oreCollect" .. oreId else "oreCollect"
	Audio:play(mineCue)
	task.delay(0.14, function()
		Audio:play(collectCue)
	end)
	if model ~= nil and model.PrimaryPart ~= nil then
		local at = model.PrimaryPart.Position + Vector3.new(0, 3, 0)
		burst(at, glowColor, 26, 16)
		floatText(at + Vector3.new(0, 2, 0), `+{tonumber(payload.Amount) or 0} {tostring(payload.Ore)}`, color:Lerp(Color3.new(1, 1, 1), 0.35))
	end
end

local function onOreCooldowns(payload)
	if type(payload) ~= "table" or type(payload.Nodes) ~= "table" then
		return
	end
	for id, at in payload.Nodes do
		if type(id) == "string" and type(at) == "number" then
			readyAt[id] = at
		end
	end
end

-- The Rift Warden

type Piece = { part: BasePart, base: Vector3, spin: Vector3, velocity: Vector3?, tilt: CFrame, transparency: number, childOffset: CFrame }

type Boss = {
	anchor: BasePart,
	model: Model,
	core: BasePart,
	shell: BasePart,
	eye: BasePart,
	coreLight: PointLight,
	aura: ParticleEmitter,
	swirl: ParticleEmitter,
	glowHalo: ParticleEmitter,
	coreSize: Vector3,
	shellSize: Vector3,
	rings: { Piece },
	plates: { Piece },
	shards: { Piece },
	lastHealth: number,
	flash: number,
	lastPhase: string,
	outroStarted: number,
	slamLift: number,
	slamUntil: number,
	visible: number,
}

local boss: Boss? = nil

local function findWarden(): Model?
	local worldFolder = Workspace:FindFirstChild("AstralForgeWorld")
	local expanse = worldFolder and worldFolder:FindFirstChild("SanctuaryWorld")
	local model = expanse and expanse:FindFirstChild("RiftWarden")
	if model ~= nil and model:IsA("Model") and model.PrimaryPart ~= nil then
		return model
	end
	return nil
end

-- A body part from the model kit when it is loaded, else a primitive.
local function bossPart(kitName: string, name: string, shape: Enum.PartType?, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local mesh = AssetKit.make(kitName, size, nil, color, material, false)
	if mesh ~= nil then
		mesh.Name = name
		mesh.CanQuery = false
		mesh.CastShadow = false
		mesh.Parent = clientFolder
		return mesh
	end
	return vfxPart(name, shape, size, color, material)
end

local function buildBoss(model: Model): Boss
	local anchor = model.PrimaryPart :: BasePart
	local coreSize = Vector3.new(9, 9, 9)
	local shellSize = Vector3.new(11.5, 11.5, 11.5)
	-- Faceted crystal heart inside a glass shell.
	local core = bossPart("WardenCore", "WardenCore", Enum.PartType.Ball, coreSize, RIFT, Enum.Material.Neon)
	local shell = bossPart("WardenCore", "WardenShell", Enum.PartType.Ball, shellSize, RIFT_HOT, Enum.Material.Glass)
	shell.Transparency = 0.6
	local eye = vfxPart("WardenEye", Enum.PartType.Ball, Vector3.new(2.3, 2.3, 2.3), Color3.fromRGB(240, 250, 255), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = RIFT
	light.Range = 70
	light.Brightness = 3
	light.Shadows = false
	light.Parent = core
	-- Motes streaming off the heart, a slow rift vortex and a soft glow.
	local aura = Vfx.attach(core, "Motes", { Color = RIFT_HOT, Color2 = RIFT, Rate = 16, Speed = NumberRange.new(2, 5) })
	local swirl = Vfx.attach(core, "Swirl", { Color = RIFT, Color2 = RIFT_HOT, Size = NumberSequence.new(20, 26) })
	local glowHalo = Vfx.attach(core, "Halo", { Color = RIFT, Size = NumberSequence.new(24, 28) })

	local rings: { Piece } = {}
	local ringSpecs = {
		{ diameter = 17, tilt = CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 40, 0) },
		{ diameter = 22, tilt = CFrame.Angles(math.rad(62), math.rad(30), 0), spin = Vector3.new(0, -28, 0) },
		{ diameter = 28, tilt = CFrame.Angles(math.rad(110), math.rad(-40), 0), spin = Vector3.new(0, 18, 0) },
	}
	for index, spec in ringSpecs do
		-- The kit halo lies flat (normal +Y); the primitive ring's axis is X.
		local size = if AssetKit.has("Halo") then Vector3.new(spec.diameter, 0.6, spec.diameter) else Vector3.new(0.35, spec.diameter, spec.diameter)
		local ring = bossPart("Halo", `WardenRing{index}`, Enum.PartType.Cylinder, size, RIFT_HOT, Enum.Material.Neon)
		ring.Transparency = 0.5
		local tilt = if AssetKit.has("Halo") then spec.tilt * CFrame.Angles(0, 0, math.rad(90)) else spec.tilt
		local piece: Piece = { part = ring, base = Vector3.zero, spin = spec.spin, velocity = nil, tilt = tilt, transparency = 0.5, childOffset = CFrame.identity }
		table.insert(rings, piece)
	end

	local plates: { Piece } = {}
	for index = 1, 6 do
		local meshPlate = AssetKit.has("WardenPlate")
		local plate = bossPart("WardenPlate", `WardenPlate{index}`, nil, if meshPlate then AssetKit.sized("WardenPlate", 1.6) else Vector3.new(5, 7, 1.2), Color3.fromRGB(34, 32, 46), Enum.Material.Basalt)
		plate.CastShadow = true
		-- A glowing seam on each plate's outer face. The kit plate's outer
		-- (convex) side is +Z, so it faces out without the half-turn the flat
		-- primitive plate needs.
		local seam: BasePart = if meshPlate
			then bossPart("WardenPlate", `WardenSeam{index}`, nil, AssetKit.sized("WardenPlate", 0.7), RIFT, Enum.Material.Neon)
			else vfxPart(`WardenSeam{index}`, nil, Vector3.new(0.4, 6, 0.4), RIFT, Enum.Material.Neon)
		seam.Parent = plate
		local piece: Piece = {
			part = plate,
			base = Vector3.zero,
			spin = Vector3.new(0, index, 0),
			velocity = nil,
			tilt = if meshPlate then CFrame.identity else CFrame.Angles(0, math.pi, 0),
			transparency = 0,
			childOffset = if meshPlate then CFrame.new(0, 0, 0.55) else CFrame.new(0, 0, -0.5),
		}
		table.insert(plates, piece)
	end

	local shards: { Piece } = {}
	for index = 1, 8 do
		local shard = bossPart("WardenBlade", `WardenShard{index}`, nil, if AssetKit.has("WardenBlade") then AssetKit.sized("WardenBlade", 1.3) else Vector3.new(1, 6.5, 1), RIFT_HOT, Enum.Material.Neon)
		shard.Transparency = 0.15
		local piece: Piece = { part = shard, base = Vector3.zero, spin = Vector3.new(0, index, 0), velocity = nil, tilt = CFrame.identity, transparency = 0.15, childOffset = CFrame.identity }
		table.insert(shards, piece)
	end

	return {
		anchor = anchor,
		model = model,
		core = core,
		shell = shell,
		eye = eye,
		coreLight = light,
		aura = aura,
		swirl = swirl,
		glowHalo = glowHalo,
		coreSize = coreSize,
		shellSize = shellSize,
		rings = rings,
		plates = plates,
		shards = shards,
		lastHealth = tonumber(model:GetAttribute("Health")) or 0,
		flash = 0,
		lastPhase = tostring(model:GetAttribute("Phase") or "Dormant"),
		outroStarted = 0,
		slamLift = 0,
		slamUntil = 0,
		visible = 0,
	}
end
local function destroyBoss()
	local current = boss
	boss = nil
	if current == nil then
		return
	end
	for _, part in { current.core, current.shell, current.eye } do
		part:Destroy()
	end
	for _, list in { current.rings, current.plates, current.shards } do
		for _, piece in list do
			piece.part:Destroy()
		end
	end
end

-- Rift tethers (beams from the arena pillars to the seal, built by the
-- server) light up while the Warden is forming or fighting.
local tethersOn = false
local function setTethers(on: boolean)
	tethersOn = on
	for _, beam in CollectionService:GetTagged("AF_RiftTether") do
		if beam:IsA("Beam") then
			beam.Enabled = on
		end
	end
end

local function setBossTransparency(current: Boss, visible: number)
	local hide = 1 - math.clamp(visible, 0, 1)
	current.core.Transparency = hide
	current.shell.Transparency = 0.6 + 0.4 * hide
	current.eye.Transparency = hide
	current.coreLight.Enabled = visible > 0.02
	current.aura.Enabled = visible > 0.2
	current.swirl.Enabled = visible > 0.3
	current.glowHalo.Enabled = visible > 0.3
	for _, list in { current.rings, current.plates, current.shards } do
		for _, piece in list do
			piece.part.Transparency = piece.transparency + (1 - piece.transparency) * hide
			for _, child in piece.part:GetChildren() do
				if child:IsA("BasePart") then
					child.Transparency = hide
				end
			end
		end
	end
end

local function stepBoss(dt: number, t: number)
	if boss == nil then
		-- Build once the model kit has loaded (or is known to be absent).
		if not kitSettled then
			return
		end
		local model = findWarden()
		if model == nil then
			return
		end
		boss = buildBoss(model)
		local joined = tostring(model:GetAttribute("Phase") or "Dormant")
		setTethers(joined == "Forming" or joined == "Active")
	end
	local current = boss :: Boss
	if current.model.Parent == nil then
		destroyBoss()
		return
	end
	local config = SanctuaryConfig.RiftBoss
	local phase = tostring(current.model:GetAttribute("Phase") or "Dormant")
	local endsAt = tonumber(current.model:GetAttribute("EndsAt")) or 0
	local health = tonumber(current.model:GetAttribute("Health")) or 0
	local now = serverNow()

	-- Phase changes: sounds and one-off moments.
	if phase ~= current.lastPhase then
		local at = current.anchor.Position
		if phase == "Forming" then
			Audio:play("wardenForming")
			setTethers(true)
			Vfx.burst(at, "Implode", 1, { Color = RIFT_HOT, Color2 = RIFT, Size = NumberSequence.new(40, 2) }, clientFolder)
			Vfx.burst(at, "Shatter", 40, { Color = RIFT_HOT, Speed = NumberRange.new(4, 10), Acceleration = Vector3.new(0, 6, 0) }, clientFolder)
		elseif phase == "Active" then
			Audio:play("wardenAwake")
			Controls.shake(0.5)
			setTethers(true)
			Vfx.burst(at, "Flash", 1, { Color = RIFT_HOT, Size = NumberSequence.new(10, 34) }, clientFolder)
			Vfx.burst(at - Vector3.new(0, 24, 0), "Shockwave", 1, { Color = RIFT, Size = NumberSequence.new(4, 90) }, clientFolder)
		elseif phase == "Defeated" then
			Audio:play("wardenDefeat")
			current.outroStarted = t
			setTethers(false)
			Vfx.burst(at, "Flash", 2, { Color = Color3.new(1, 1, 1), Color2 = RIFT_HOT, Size = NumberSequence.new(12, 44) }, clientFolder)
			Vfx.burst(at, "Shatter", 110, { Color = RIFT_HOT, Color2 = RIFT, Speed = NumberRange.new(18, 40), Size = NumberSequence.new(1.1, 0) }, clientFolder)
			Vfx.burst(at - Vector3.new(0, 24, 0), "Shockwave", 1, { Color = RIFT_HOT, Size = NumberSequence.new(6, 120) }, clientFolder)
			for _, list in { current.rings, current.plates, current.shards } do
				for _, piece in list do
					local away = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
					piece.velocity = (if away.Magnitude > 0.05 then away.Unit else Vector3.yAxis) * (24 + math.random() * 30)
				end
			end
			local root = localRoot()
			if root ~= nil and (root.Position - current.anchor.Position).Magnitude < 160 then
				Controls.shake(1)
			end
		elseif phase == "Escaped" then
			Audio:play("wardenEscape")
			current.outroStarted = t
			setTethers(false)
			Vfx.burst(at, "Implode", 1, { Color = RIFT, Size = NumberSequence.new(30, 0.5) }, clientFolder)
		elseif phase == "Dormant" then
			setTethers(false)
			for _, list in { current.rings, current.plates, current.shards } do
				for _, piece in list do
					piece.velocity = nil
				end
			end
		end
		current.lastPhase = phase
	end

	-- Hit reaction: a flash whenever health drops.
	if health < current.lastHealth - 0.01 then
		current.flash = 1
	end
	current.lastHealth = health
	current.flash = math.max(0, current.flash - dt * 5)

	-- How present the Warden is.
	local visible = 0
	if phase == "Forming" then
		visible = math.clamp(1 - (endsAt - now) / config.FormingSeconds, 0, 1)
	elseif phase == "Active" then
		visible = 1
	elseif phase == "Defeated" or phase == "Escaped" then
		visible = math.clamp(1 - (t - current.outroStarted) / 2.2, 0, 1)
	end
	current.visible += (visible - current.visible) * (1 - math.exp(-8 * dt))
	if current.visible < 0.005 and visible == 0 then
		setBossTransparency(current, 0)
		return
	end
	setBossTransparency(current, current.visible)

	-- Slam wind-up lifts the Warden and heats its core toward the slam colour,
	-- pulsing faster as the moment nears; the landing drops it.
	local lift = 0
	local charge = 0
	if current.slamUntil > now then
		local total = config.SlamTelegraphSeconds
		local k = math.clamp(1 - (current.slamUntil - now) / total, 0, 1)
		lift = math.sin(k * math.pi * 0.5) * 5
		charge = k
	end
	current.slamLift += (lift - current.slamLift) * (1 - math.exp(-12 * dt))
	local chargePulse = if charge > 0 then charge * (0.55 + 0.45 * math.sin(t * (8 + charge * 22))) else 0

	local escaping = phase == "Escaped"
	local collapse = if escaping then math.clamp((t - current.outroStarted) / 1.4, 0, 1) else 0
	local hover = current.anchor.Position + Vector3.new(0, math.sin(t * 0.9) * 1.4 + current.slamLift, 0)
	local coreScale = 1 + current.flash * 0.12 + (if phase == "Defeated" then math.clamp((t - current.outroStarted) * 0.8, 0, 1.2) else 0)
	coreScale *= (1 - collapse * 0.95)
	current.core.Size = Vector3.new(9, 9, 9) * coreScale
	current.core.Color = RIFT:Lerp(SLAM, chargePulse * 0.75):Lerp(Color3.new(1, 1, 1), current.flash * 0.7)
	current.shell.Size = Vector3.new(11.5, 11.5, 11.5) * coreScale
	current.coreLight.Brightness = 3 + current.flash * 6 + chargePulse * 4
	current.coreLight.Color = RIFT:Lerp(SLAM, chargePulse)

	local parts: { BasePart } = { current.core, current.shell }
	local frames: { CFrame } = { CFrame.new(hover), CFrame.new(hover) }

	-- The eye turns toward the local player.
	local root = localRoot()
	local lookDir = if root ~= nil then (root.Position - hover) else Vector3.new(0, 0, 1)
	lookDir = if lookDir.Magnitude > 0.5 then lookDir.Unit else Vector3.new(0, 0, 1)
	table.insert(parts, current.eye)
	table.insert(frames, CFrame.new(hover + lookDir * 5.2 * coreScale))

	local outro = if phase == "Defeated" then t - current.outroStarted else 0
	local function place(piece: Piece, frame: CFrame)
		if piece.velocity ~= nil and outro > 0 then
			local drift = piece.velocity * outro + Vector3.new(0, -9 * outro * outro, 0)
			frame = CFrame.new(frame.Position + drift) * CFrame.Angles(outro * 3, outro * 2, 0) * frame.Rotation
		end
		if collapse > 0 then
			frame = CFrame.new(frame.Position:Lerp(hover, collapse)) * frame.Rotation
		end
		table.insert(parts, piece.part)
		table.insert(frames, frame)
		for _, child in piece.part:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
				table.insert(frames, frame * piece.childOffset)
			end
		end
	end

	for _, ring in current.rings do
		local spin = CFrame.Angles(0, math.rad(ring.spin.Y * t) % TAU, 0)
		place(ring, CFrame.new(hover) * spin * ring.tilt)
	end
	for index, plate in current.plates do
		local angle = (index / #current.plates) * TAU + t * 0.35
		local jolt = current.flash * 0.9
		local radius = 9.5 + jolt + math.sin(t * 1.3 + index) * 0.4
		local position = hover + Vector3.new(math.cos(angle) * radius, math.sin(t * 1.1 + index * 0.8) * 1.2, math.sin(angle) * radius)
		place(plate, CFrame.lookAt(position, hover) * plate.tilt)
	end
	for index, shard in current.shards do
		local side = if index <= 4 then -1 else 1
		local k = ((index - 1) % 4) / 3
		local sway = math.sin(t * 1.6 + index) * 0.12
		local offset = Vector3.new(side * (8 + k * 5), 3 - k * 5, 4 + k * 2)
		local position = hover + offset
		place(shard, CFrame.new(position) * CFrame.Angles(0, 0, side * (0.5 + k * 0.4 + sway)))
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Slams

local function ringAdornment(anchor: BasePart, radius: number, inner: number, color: Color3, transparency: number): CylinderHandleAdornment
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	ring.AlwaysOnTop = false
	ring.ZIndex = 1
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	ring.Height = 0.25
	ring.Radius = math.max(0.05, radius)
	ring.InnerRadius = math.clamp(inner, 0, math.max(0, radius - 0.05))
	ring.Color3 = color
	ring.Transparency = transparency
	ring.Parent = anchor
	return ring
end

local function worldPoint(p: any): Vector3
	return Vector3.new(tonumber(p and p.X) or 0, tonumber(p and p.Y) or 0, tonumber(p and p.Z) or 0)
end

local function onSlam(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.2, 0)
	local radius = tonumber(payload.Radius) or 24
	local detonateAt = tonumber(payload.DetonateAt) or (serverNow() + 1.5)
	if boss ~= nil then
		boss.slamUntil = detonateAt
	end
	Audio:play("wardenSlamCharge")
	local anchor = vfxPart("SlamAnchor", nil, Vector3.new(0.2, 0.2, 0.2), SLAM, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local fill = ringAdornment(anchor, 0.1, 0, SLAM, 0.85)
	local edge = ringAdornment(anchor, radius, radius - 0.9, SLAM, 0.35)
	local started = serverNow()
	local total = math.max(0.2, detonateAt - started)
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((serverNow() - started) / total, 0, 1)
		fill.Radius = math.max(0.1, radius * k)
		fill.Transparency = 0.85 - 0.3 * k
		edge.Transparency = 0.35 - 0.2 * math.abs(math.sin(k * math.pi * 6))
		if k >= 1 and connection ~= nil then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
end

local function onSlamLand(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.3, 0)
	local radius = tonumber(payload.Radius) or 24
	Audio:play("wardenSlam")
	burst(center + Vector3.new(0, 1, 0), RIFT_HOT, 40, 28)
	-- A textured shockwave across the floor, dust thrown up, and a flash.
	Vfx.burst(center + Vector3.new(0, 0.4, 0), "Shockwave", 1, { Color = RIFT_HOT, Size = NumberSequence.new(4, radius * 2.6) }, clientFolder)
	Vfx.burst(center, "Dust", 26, { Color = Color3.fromRGB(70, 62, 90) }, clientFolder)
	Vfx.burst(center + Vector3.new(0, 2, 0), "Flash", 1, { Color = SLAM, Size = NumberSequence.new(6, radius) }, clientFolder)
	local anchor = vfxPart("ShockAnchor", nil, Vector3.new(0.2, 0.2, 0.2), SLAM, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local wave = ringAdornment(anchor, radius, radius - 2, RIFT_HOT, 0.1)
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / 0.55, 0, 1)
		local r = radius * (1 + 0.8 * k)
		wave.Radius = r
		wave.InnerRadius = math.max(0, r - 2 - 3 * k)
		wave.Transparency = 0.1 + 0.9 * k
		if k >= 1 and connection ~= nil then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
	local root = localRoot()
	if root ~= nil then
		local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
		if distance < radius + 30 then
			Controls.shake(math.clamp(1.2 - distance / (radius + 30), 0.25, 1.1))
		end
	end
end

local function onStagger(payload)
	local center = worldPoint(type(payload) == "table" and payload.Center or nil)
	Controls.knockback(center, 58)
	Controls.shake(1.3)
	local root = localRoot()
	if root ~= nil then
		Vfx.burst(root.Position, "Spark", 18, { Color = SLAM, Color2 = RIFT_HOT }, clientFolder)
	end
end

-- The local player's strike landed (the HUD fires this with the result):
-- sparks off the Warden, and a flash on a critical hit.
local function onStrikeLanded(payload)
	local current = boss
	if current == nil then
		return
	end
	local crit = type(payload) == "table" and payload.Crit == true
	local root = localRoot()
	local at = current.core.Position
	if root ~= nil then
		-- The side of the Warden facing the player.
		local toward = root.Position - at
		if toward.Magnitude > 1 then
			at += toward.Unit * current.core.Size.X * 0.5
		end
	end
	Vfx.burst(at, "Spark", if crit then 34 else 16, { Color = RIFT_HOT, Color2 = if crit then Color3.fromRGB(255, 214, 120) else RIFT }, clientFolder)
	if crit then
		Vfx.burst(at, "Flash", 1, { Color = Color3.fromRGB(255, 226, 150), Size = NumberSequence.new(3, 12) }, clientFolder)
	end
end

-- Regions and waystones

local function stepRegion(dt: number)
	regionClock += dt
	if regionClock < 0.4 then
		return
	end
	regionClock = 0
	local root = localRoot()
	if root == nil then
		return
	end
	local here = root.Position - ORIGIN
	local region = Layout.regionAt({ X = here.X, Y = here.Y, Z = here.Z })
	local id = if region ~= nil then region.Id else "Bridge"
	if id ~= currentRegion then
		local first = currentRegion == nil
		currentRegion = id
		Signals.fire("RegionChanged", { Id = id, Name = if region ~= nil then region.Name else "Sky road" })
		if region ~= nil and not first then
			Audio:play("regionEnter")
		end
	end
end

-- After a waystone jump, hold the character still until the ground under
-- the destination has streamed in, so nobody falls through a region that is
-- still loading.
local function onArrived(payload)
	Audio:play("waystoneTravel")
	local root = localRoot()
	if root == nil then
		return
	end
	-- Step out of a column of light.
	Vfx.burst(root.Position - Vector3.new(0, 2.5, 0), "Rising", 45, { Color = Color3.fromRGB(150, 220, 255), Speed = NumberRange.new(6, 14) }, clientFolder)
	Vfx.burst(root.Position, "Shatter", 24, { Color = Color3.fromRGB(190, 236, 255), Speed = NumberRange.new(6, 12) }, clientFolder)
	Vfx.burst(root.Position - Vector3.new(0, 2.8, 0), "Shockwave", 1, { Color = Color3.fromRGB(150, 220, 255), Size = NumberSequence.new(2, 18) }, clientFolder)
	root.Anchored = true
	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local character = Players.LocalPlayer.Character
		params.FilterDescendantsInstances = if character ~= nil then { character } else {}
		local deadline = os.clock() + 2.5
		while os.clock() < deadline and root.Parent ~= nil do
			if Workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params) ~= nil then
				break
			end
			task.wait(0.05)
		end
		if root.Parent ~= nil then
			root.Anchored = false
		end
	end)
	Signals.fire("Arrived", payload)
end

-- Lifecycle

function World.start()
	if active then
		return
	end
	active = true
	currentRegion = nil
	regionClock = 1
	local folder = Instance.new("Folder")
	folder.Name = "SanctuaryClientFx"
	folder.Parent = Workspace
	clientFolder = folder
	-- Ambience subscribes to region changes before the first one fires.
	Ambience.start()
	-- The Warden's body waits for the model kit (at most a few seconds, and
	-- not at all when none is uploaded).
	kitSettled = AssetKit.ready()
	if not kitSettled then
		task.spawn(function()
			AssetKit.load(10)
			kitSettled = true
		end)
	end
	track(CollectionService:GetInstanceAddedSignal("AF_RiftTether"):Connect(function(beam)
		if beam:IsA("Beam") then
			beam.Enabled = tethersOn
		end
	end))

	for _, tagName in { "AF_Spin", "AF_Bob", "AF_Pulse" } do
		for _, instance in CollectionService:GetTagged(tagName) do
			registerTagged(tagName, instance)
		end
		track(CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
			registerTagged(tagName, instance)
		end))
	end
	for _, model in CollectionService:GetTagged("AF_OreNode") do
		registerNode(model)
	end
	track(CollectionService:GetInstanceAddedSignal("AF_OreNode"):Connect(registerNode))

	track(ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "WaystonePrompt" then
			Signals.fire("WaystoneOpen", { From = prompt:GetAttribute("WaystoneId") })
		end
	end))
	track(ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "MinePrompt" then
			return
		end
		local _, entry = nodeById(tostring(prompt:GetAttribute("NodeId")))
		if entry ~= nil then
			entry.trembling = true
		end
	end))
	track(ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "MinePrompt" then
			return
		end
		local _, entry = nodeById(tostring(prompt:GetAttribute("NodeId")))
		if entry ~= nil then
			entry.trembling = false
		end
	end))

	table.insert(unsubscribers, Signals.on("OreMined", onOreMined))
	table.insert(unsubscribers, Signals.on("OreCooldowns", onOreCooldowns))
	table.insert(unsubscribers, Signals.on("RiftBossSlam", onSlam))
	table.insert(unsubscribers, Signals.on("RiftBossSlamLand", onSlamLand))
	table.insert(unsubscribers, Signals.on("RiftBossStagger", onStagger))
	table.insert(unsubscribers, Signals.on("WaystoneArrived", onArrived))
	table.insert(unsubscribers, Signals.on("StrikeLanded", onStrikeLanded))

	track(RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera ~= nil then camera.CFrame.Position else ORIGIN
		stepScenery(t, cameraPosition)
		stepNodes(dt, t)
		local ok, problem = pcall(stepBoss :: (number, number) -> any, dt, t)
		if not ok then
			warn(`[sanctuary] warden visuals: {problem}`)
			destroyBoss()
		end
		stepRegion(dt)
	end))
end

function World.stop()
	if not active then
		return
	end
	active = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, unsubscribe in unsubscribers do
		unsubscribe()
	end
	table.clear(unsubscribers)
	destroyBoss()
	setTethers(false)
	Ambience.stop()
	restoreAnimated()
	-- Put every outcrop back to full so nothing is left half-drawn. Outcrops
	-- that streamed out are gone already and come back fresh.
	for model, entry in nodes do
		if model.Parent == nil then
			continue
		end
		entry.fill = 1
		entry.trembling = false
		pcall(applyFill, entry, 0)
		if entry.prompt ~= nil then
			entry.prompt.Enabled = true
		end
	end
	table.clear(nodes)
	if clientFolder ~= nil then
		clientFolder:Destroy()
		clientFolder = nil
	end
	currentRegion = nil
end

function World.region(): string?
	return currentRegion
end

return World
end

-- ======================================================================
-- Module: sanctuaryPresence   (merged from sanctuaryPresence.luau, 603 lines)
-- ======================================================================
__defs["sanctuaryPresence"] = function()
-- Walkable rift behind the shell. The idle UI stays on a scriptable camera.
-- PlayerModule is not under PlayerScripts; sanctuaryControls moves the avatar
-- and runs the follow camera on every device, and sanctuaryWorld animates the
-- world. Leave restores the forge camera and lighting, and the server
-- destroys the sanctuary character.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controls = __load("sanctuaryControls")
local Curtain = __load("curtainTransition")
local World = __load("sanctuaryWorld")
local SanctuaryLayout = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("SanctuaryLayout")

local Presence = {}

type Dispatch = (string, { [string]: any }?, (({ [string]: any }) -> ())?) -> ()

type LightingSnapshot = {
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogStart: number,
	fogEnd: number,
	fogColor: Color3,
	clockTime: number,
	colorShiftTop: Color3,
	colorShiftBottom: Color3,
	diffuseScale: number,
	specularScale: number,
	exposure: number,
}
-- The arrival check: the character has been placed on the forge deck when it
-- stands this close to the spawn slab. It covers every walkable surface of
-- the hand-built deck (the far corners sit just past 48 studs). Once walking,
-- the controls follow the player anywhere inside the sanctuary's bounds
-- (SanctuaryLayout.WORLD_RADIUS), not just the deck.
local DECK_RADIUS = 72

-- Post effects that exist only while the sanctuary is open.
local EFFECT_NAMES = { "AF_SanctuaryBloom", "AF_SanctuaryGrade", "AF_SanctuaryRays" }
local ATMOSPHERE_NAME = "AF_SanctuaryAtmosphere"
local SKY_NAME = "AF_SanctuarySky"

type SkySnapshot = { instance: Sky, stars: number, bodies: boolean, moonSize: number }

type AtmosphereSnapshot = {
	instance: Atmosphere,
	density: number,
	offset: number,
	color: Color3,
	decay: Color3,
	glare: number,
	haze: number,
}

local activeToken = 0
local walking = false
local lightingHeld = false
local savedLighting: LightingSnapshot? = nil
local spawnAim: CFrame? = nil
local aiming = false
local shellCameraCFrame: CFrame? = nil
local shellCameraType: Enum.CameraType? = nil
local shellCameraSubject: Instance? = nil
local connections: { RBXScriptConnection } = {}
local cameraGuard: RBXScriptConnection? = nil
local savedAtmosphere: AtmosphereSnapshot? = nil
local savedSky: SkySnapshot? = nil

local function track(connection: RBXScriptConnection)
	table.insert(connections, connection)
end

local function disconnectAll()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function findSpawn(): BasePart?
	local world = Workspace:FindFirstChild("AstralForgeWorld")
	local sanctuary = world and world:FindFirstChild("Sanctuary")
	local spawn = sanctuary and sanctuary:FindFirstChild("Spawn")
	if spawn ~= nil and spawn:IsA("BasePart") then
		return spawn
	end
	return nil
end

local function applySanctuaryLighting()
	if not lightingHeld then
		savedLighting = {
			brightness = Lighting.Brightness,
			ambient = Lighting.Ambient,
			outdoorAmbient = Lighting.OutdoorAmbient,
			fogStart = Lighting.FogStart,
			fogEnd = Lighting.FogEnd,
			fogColor = Lighting.FogColor,
			clockTime = Lighting.ClockTime,
			colorShiftTop = Lighting.ColorShift_Top,
			colorShiftBottom = Lighting.ColorShift_Bottom,
			diffuseScale = Lighting.EnvironmentDiffuseScale,
			specularScale = Lighting.EnvironmentSpecularScale,
			exposure = Lighting.ExposureCompensation,
		}
		lightingHeld = true
	end
	-- A clear, starlit night. Moonlight plus a generous violet ambient keeps
	-- every island readable (a dim dusk turned the rock into black silhouettes),
	-- and the neon -- lava, crystals, runes, the Warden -- glows against it.
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(92, 92, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(122, 116, 168)
	Lighting.ColorShift_Top = Color3.fromRGB(150, 160, 230)
	Lighting.ColorShift_Bottom = Color3.fromRGB(40, 30, 70)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = 0.3
	Lighting.FogColor = Color3.fromRGB(14, 12, 30)
	-- The world reaches ~500 studs out; distant islands fade into haze rather
	-- than popping out of a black wall.
	Lighting.FogStart = 200
	Lighting.FogEnd = 1100

	-- Deep violet haze, light enough that the stars show through and dark
	-- enough that the void below reads as depth rather than a flat floor. An
	-- Atmosphere already in Lighting (the shell's) is borrowed and put back
	-- exactly; otherwise one is added for the visit.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere ~= nil and atmosphere.Name ~= ATMOSPHERE_NAME then
		if savedAtmosphere == nil then
			savedAtmosphere = {
				instance = atmosphere,
				density = atmosphere.Density,
				offset = atmosphere.Offset,
				color = atmosphere.Color,
				decay = atmosphere.Decay,
				glare = atmosphere.Glare,
				haze = atmosphere.Haze,
			}
		end
	elseif atmosphere == nil then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = ATMOSPHERE_NAME
		atmosphere.Parent = Lighting
	end
	local haze = atmosphere :: Atmosphere
	haze.Density = 0.2
	haze.Offset = 0.04
	haze.Color = Color3.fromRGB(48, 40, 94)
	haze.Decay = Color3.fromRGB(18, 14, 40)
	haze.Glare = 0
	haze.Haze = 0.8

	-- Stars and the moon: Roblox's own sky, with a dense starfield.
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky ~= nil and sky.Name ~= SKY_NAME then
		if savedSky == nil then
			savedSky = { instance = sky, stars = sky.StarCount, bodies = sky.CelestialBodiesShown, moonSize = sky.MoonAngularSize }
		end
	elseif sky == nil then
		sky = Instance.new("Sky")
		sky.Name = SKY_NAME
		sky.Parent = Lighting
	end
	local night = sky :: Sky
	night.StarCount = 5000
	night.CelestialBodiesShown = true
	night.MoonAngularSize = 14

	-- Neon blooms softly; a gentle grade lifts contrast and colour.
	if Lighting:FindFirstChild(EFFECT_NAMES[1]) == nil then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = EFFECT_NAMES[1]
		bloom.Intensity = 0.6
		bloom.Size = 26
		bloom.Threshold = 1.3
		bloom.Parent = Lighting
	end
	if Lighting:FindFirstChild(EFFECT_NAMES[2]) == nil then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = EFFECT_NAMES[2]
		grade.Brightness = 0.03
		grade.Contrast = 0.1
		grade.Saturation = 0.14
		grade.TintColor = Color3.fromRGB(238, 236, 255)
		grade.Parent = Lighting
	end
	if Lighting:FindFirstChild(EFFECT_NAMES[3]) == nil then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = EFFECT_NAMES[3]
		rays.Intensity = 0.04
		rays.Spread = 0.6
		rays.Parent = Lighting
	end
end

local function restoreLighting()
	-- Post effects, the haze and the sky go whether or not the base lighting
	-- was held, so a failed entry never leaves any of them behind.
	for _, name in EFFECT_NAMES do
		local effect = Lighting:FindFirstChild(name)
		if effect ~= nil then
			effect:Destroy()
		end
	end
	for _, name in { ATMOSPHERE_NAME, SKY_NAME } do
		local added = Lighting:FindFirstChild(name)
		if added ~= nil then
			added:Destroy()
		end
	end
	local borrowed = savedAtmosphere
	savedAtmosphere = nil
	if borrowed ~= nil and borrowed.instance.Parent ~= nil then
		borrowed.instance.Density = borrowed.density
		borrowed.instance.Offset = borrowed.offset
		borrowed.instance.Color = borrowed.color
		borrowed.instance.Decay = borrowed.decay
		borrowed.instance.Glare = borrowed.glare
		borrowed.instance.Haze = borrowed.haze
	end
	local borrowedSky = savedSky
	savedSky = nil
	if borrowedSky ~= nil and borrowedSky.instance.Parent ~= nil then
		borrowedSky.instance.StarCount = borrowedSky.stars
		borrowedSky.instance.CelestialBodiesShown = borrowedSky.bodies
		borrowedSky.instance.MoonAngularSize = borrowedSky.moonSize
	end

	local saved = savedLighting
	if not lightingHeld or saved == nil then
		lightingHeld = false
		return
	end
	lightingHeld = false
	savedLighting = nil
	Lighting.Brightness = saved.brightness
	Lighting.Ambient = saved.ambient
	Lighting.OutdoorAmbient = saved.outdoorAmbient
	Lighting.FogStart = saved.fogStart
	Lighting.FogEnd = saved.fogEnd
	Lighting.FogColor = saved.fogColor
	Lighting.ClockTime = saved.clockTime
	Lighting.ColorShift_Top = saved.colorShiftTop
	Lighting.ColorShift_Bottom = saved.colorShiftBottom
	Lighting.EnvironmentDiffuseScale = saved.diffuseScale
	Lighting.EnvironmentSpecularScale = saved.specularScale
	Lighting.ExposureCompensation = saved.exposure
end
local ensureCameraGuard: () -> ()

local function rememberShellCamera()
	if shellCameraCFrame ~= nil then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	shellCameraCFrame = camera.CFrame
	shellCameraType = camera.CameraType
	shellCameraSubject = camera.CameraSubject
end

local function restoreShellCamera()
	local camera = Workspace.CurrentCamera
	local saved = shellCameraCFrame
	local savedType = shellCameraType
	local savedSubject = shellCameraSubject
	shellCameraCFrame = nil
	shellCameraType = nil
	shellCameraSubject = nil
	if camera == nil or saved == nil then
		return
	end
	camera.CameraType = if savedType ~= nil then savedType else Enum.CameraType.Scriptable
	camera.CameraSubject = savedSubject
	camera.CFrame = saved
end

local function releaseCameraGuard()
	local guard = cameraGuard
	cameraGuard = nil
	if guard ~= nil then
		guard:Disconnect()
	end
end

local function clearCamera(eye: Vector3, focus: Vector3): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		params.FilterDescendantsInstances = { character }
	end
	local lifted = eye
	for _ = 1, 4 do
		local delta = lifted - focus
		if delta.Magnitude < 0.5 then
			break
		end
		local hit = Workspace:Raycast(focus, delta, params)
		if hit == nil then
			break
		end
		lifted += Vector3.new(0, 8, 0)
	end
	return CFrame.lookAt(lifted, focus)
end

local function overlookCFrame(): CFrame?
	if not aiming then
		return nil
	end
	local basis = spawnAim
	if basis == nil then
		local spawn = findSpawn()
		if spawn ~= nil then
			basis = spawn.CFrame
			spawnAim = basis
		end
	end
	if basis == nil then
		return nil
	end
	local position = basis.Position
	local look = basis.LookVector
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	-- Behind the avatar and well above the path, so the lens is not inside a slab.
	local eye = position - look * 24 + Vector3.new(0, 14, 0)
	local focus = position + look * 10 + Vector3.new(0, 2, 0)
	return clearCamera(eye, focus)
end

local function aimCamera()
	local camera = Workspace.CurrentCamera
	local aim = overlookCFrame()
	if camera == nil or aim == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	camera.CFrame = aim
end

ensureCameraGuard = function()
	if cameraGuard ~= nil then
		return
	end
	cameraGuard = RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		if walking then
			-- Movement and the orbit camera, for every input device.
			Controls.step(dt)
			return
		end
		local aim = overlookCFrame()
		if aim == nil then
			-- No deck aim yet. Leaving the subject nil snaps the lens to the origin.
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = nil
		camera.CFrame = aim
	end)
end

local function lockAvatar()
	walking = false
	Controls.stop()
	World.stop()
	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero, false)
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = nil
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function rootOnDeck(root: BasePart): boolean
	local basis = spawnAim
	if basis == nil then
		local spawn = findSpawn()
		if spawn ~= nil then
			basis = spawn.CFrame
			spawnAim = basis
		end
	end
	if basis == nil then
		return false
	end
	return (root.Position - basis.Position).Magnitude <= DECK_RADIUS
end

-- Anywhere in the sanctuary: the hub, the bridges and every region.
local function rootInWorld(root: BasePart): boolean
	local origin = SanctuaryLayout.ORIGIN
	return SanctuaryLayout.inBounds({
		X = root.Position.X - origin.X,
		Y = root.Position.Y - origin.Y,
		Z = root.Position.Z - origin.Z,
	})
end

local function followAvatar(humanoid: Humanoid)
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
	local character = humanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local facing: Vector3? = nil
	if root ~= nil and root:IsA("BasePart") then
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		facing = if flat.Magnitude > 0.05 then flat.Unit else nil
	end
	if not Controls.isActive() then
		Controls.start(facing)
	end
	World.start()
	walking = true
	ensureCameraGuard()
	return true
end

function Presence.enter(dispatch: Dispatch, onClose: () -> (), onFailed: () -> (), onReady: (() -> ())?): number
	activeToken += 1
	local token = activeToken
	rememberShellCamera()
	applySanctuaryLighting()
	track(ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggerPlayer: Player)
		if token ~= activeToken then
			return
		end
		if triggerPlayer ~= Players.LocalPlayer then
			return
		end
		if prompt.Name == "SanctuaryClose" then
			onClose()
		end
	end))
	dispatch("EnterSanctuary", {}, function(response)
		if token ~= activeToken then
			return
		end
		if type(response) ~= "table" or response.ok ~= true then
			restoreLighting()
			onFailed()
			return
		end
		if response.Closed == true then
			if token == activeToken then
				restoreLighting()
				onFailed()
			end
			return
		end
		local spawnValue = response.Spawn
		if typeof(spawnValue) == "CFrame" then
			spawnAim = spawnValue
			aiming = true
			ensureCameraGuard()
			aimCamera()
		end
		task.spawn(function()
			local player = Players.LocalPlayer
			if typeof(spawnValue) == "CFrame" then
				pcall(function()
					player:RequestStreamAroundAsync(spawnValue.Position, 5)
				end)
			end
			if token ~= activeToken then
				return
			end
			local deadline = os.clock() + 10
			local followed = false
			local announced = false
			while token == activeToken and os.clock() < deadline do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root ~= nil and root:IsA("BasePart") and humanoid ~= nil and rootOnDeck(root) then
					followAvatar(humanoid)
					followed = true
					if not announced and onReady ~= nil then
						announced = true
						onReady()
					end
					break
				end
				task.wait(0.1)
			end
			if token ~= activeToken then
				return
			end
			if not followed then
				restoreLighting()
				onFailed()
				return
			end
			local missingSince: number? = nil
			while token == activeToken do
				local live = player.Character
				local liveRoot = live and live.Parent ~= nil and live:FindFirstChild("HumanoidRootPart")
				if liveRoot == nil or not liveRoot:IsA("BasePart") then
					if missingSince == nil then
						missingSince = os.clock()
					elseif os.clock() - missingSince > 6 then
						restoreLighting()
						onFailed()
						return
					end
				else
					missingSince = nil
					if not walking and rootInWorld(liveRoot) then
						local liveHumanoid = live and live:FindFirstChildOfClass("Humanoid")
						if liveHumanoid ~= nil then
							followAvatar(liveHumanoid)
						end
					end
				end
				task.wait(0.25)
			end
		end)
	end)
	return token
end

-- Enter once the curtain has had its head start: the camera move, lighting,
-- server request and streaming begin after the halves are mostly apart, so
-- none of that work lands on the curtain's first frames. The veil covers the
-- world until the sanctuary is ready either way.
type EntryHandle = { token: number?, cancelled: boolean, job: thread? }

function Presence.enterSoon(dispatch: Dispatch, onClose: () -> (), onFailed: () -> (), onReady: (() -> ())?): EntryHandle
	local handle: EntryHandle = { token = nil, cancelled = false, job = nil }
	handle.job = task.delay(Curtain.LOAD_HEAD_START, function()
		if handle.cancelled then
			return
		end
		handle.token = Presence.enter(dispatch, onClose, onFailed, onReady)
	end)
	return handle
end

-- Leave (or cancel an entry that hasn't started yet).
function Presence.leaveSoon(dispatch: Dispatch, handle: EntryHandle)
	handle.cancelled = true
	if handle.job ~= nil then
		pcall(task.cancel, handle.job)
	end
	if handle.token ~= nil then
		Presence.leave(dispatch, handle.token :: number)
	end
end

function Presence.leave(dispatch: Dispatch, token: number)
	if token ~= activeToken then
		return
	end
	activeToken += 1
	aiming = false
	walking = false
	spawnAim = nil
	disconnectAll()
	releaseCameraGuard()
	lockAvatar()
	restoreShellCamera()
	restoreLighting()
	dispatch("LeaveSanctuary", {}, function() end)
end

return Presence
end

-- ======================================================================
-- Module: curtainTransition   (merged from curtainTransition.luau, 114 lines)
-- ======================================================================
__defs["curtainTransition"] = function()
-- Motion curves for the sanctuary rift curtain.
--
-- Opening the rift splits the shell down the middle and slides the two halves
-- off opposite edges, revealing the sanctuary. Both halves read one `travel`
-- value (0 shut .. 1 open), so they always move as an exact mirror pair.
--
-- Travel is a time-based tween driven on RenderStepped, not a spring, so there
-- is no overshoot and no settle wobble. Opening uses a quartic ease-out -- it
-- moves on the very first frame (no perceptible delay) at a speed the eye can
-- follow, then glides into place; closing uses a cubic ease-in-out so the
-- halves gather speed and meet softly instead of slamming. A reversal
-- mid-motion starts from wherever the halves are, and a partial run takes
-- proportionally less time.
--
-- Time advances by the frame's delta, capped at MAX_FRAME_STEP. Opening the
-- rift does one-off work (the right half's snapshot, the sanctuary's lighting,
-- streaming); a long frame from that used to leap the halves most of the way
-- across in one step. Now a slow frame just slows the curtain for a moment.
--
-- A dark veil sits behind the halves and hides the world until the sanctuary
-- is ready, so the camera move into the rift is never seen.
--
-- Pure: no Roblox instances, so the curves are unit tested under Lune
-- (scripts/verify_sanctuary_curtain.luau). sanctuaryChrome.luau draws them.

local Curtain = {}

Curtain.OPEN_SECONDS = 0.62
Curtain.CLOSE_SECONDS = 0.5
-- The most time one rendered frame may advance the curtain (seconds).
Curtain.MAX_FRAME_STEP = 1 / 40
-- How long the rift's loading (camera, lighting, streaming) waits after the
-- press, so it starts once the halves are mostly apart instead of competing
-- with their first frames.
Curtain.LOAD_HEAD_START = 0.36
-- Reduced motion keeps the same path and runs it in about half the time.
Curtain.REDUCED_SCALE = 0.55
-- A partial run (reversing mid-motion) never takes less than this share of a
-- full one, so a quick flick still reads as motion rather than a snap.
Curtain.MIN_RUN_SHARE = 0.35

-- How far each half travels, in screen widths. A half is 0.5 wide, so 0.5
-- clears the screen; the small extra carries the rim and shading out too.
Curtain.TRAVEL = 0.53

-- Veil fade once the sanctuary is ready (flipper motor stiffness/damping).
Curtain.VEIL_STIFFNESS = 220
Curtain.VEIL_DAMPING = 50

local function unit(t: number): number
	if t ~= t then
		return 0
	end
	return math.clamp(t, 0, 1)
end

-- Quartic ease-out: moving from the first frame, a long soft landing.
function Curtain.easeOpen(t: number): number
	local inv = 1 - unit(t)
	return 1 - inv * inv * inv * inv
end

-- Advance a run's clock by one rendered frame.
function Curtain.advance(elapsed: number, dt: number): number
	return elapsed + math.clamp(dt, 0, Curtain.MAX_FRAME_STEP)
end

-- Cubic ease-in-out: the halves gather speed and meet gently.
function Curtain.easeClose(t: number): number
	local x = unit(t)
	if x < 0.5 then
		return 4 * x * x * x
	end
	local k = -2 * x + 2
	return 1 - (k * k * k) / 2
end

-- Seconds for a run covering `distance` of travel (0..1).
function Curtain.duration(opening: boolean, distance: number, reduced: boolean): number
	local full = if opening then Curtain.OPEN_SECONDS else Curtain.CLOSE_SECONDS
	local seconds = full * math.clamp(distance, Curtain.MIN_RUN_SHARE, 1)
	return if reduced then seconds * Curtain.REDUCED_SCALE else seconds
end

-- Travel at `elapsed` seconds into a run from `from` to `to`.
function Curtain.sample(from: number, to: number, elapsed: number, seconds: number): number
	local t = if seconds <= 0 then 1 else elapsed / seconds
	local eased = if to > from then Curtain.easeOpen(t) else Curtain.easeClose(t)
	return from + (to - from) * eased
end

-- Offset of each half from its closed position, in screen widths.
function Curtain.shift(travel: number): number
	return unit(travel) * Curtain.TRAVEL
end

-- A half dims a little as it swings away, which gives the pair depth.
function Curtain.shadeTransparency(travel: number): number
	return 1 - unit(travel) * 0.4
end

-- The hairline rim along each parting edge: brightest as the seam opens,
-- gone by the time the halves are off screen.
function Curtain.rimTransparency(travel: number): number
	return 0.3 + unit(travel) * 0.7
end

-- The veil is 1 while it covers the world and 0 once the sanctuary shows.
function Curtain.veilTransparency(veil: number): number
	return 1 - unit(veil)
end

return Curtain
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
