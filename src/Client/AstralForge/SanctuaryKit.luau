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
	ChoirIsle = "amb_hollows",
	RegentIsle = "amb_ember",
}
local LEVEL = 0.55
local BRIDGE_LEVEL = 0.3
local FADE_SECONDS = 2.5

type Voice = { sound: Sound, bed: string?, level: number, target: number }

local voices: { Voice } = {}
local current: Voice? = nil
-- The fight layer: a boss's own bed, played over the region's and raised per phase.
local fightVoice: Voice? = nil
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

-- Start, retune or (with nil) fade out the fight layer. `profile` is a boss's Music entry:
-- Bed names an ambience region, or Id an uploaded track to use instead; Pitch and Level set
-- its voice and loudness; Effect dresses it. Each phase raises pitch and level a notch.
function Ambience.fight(profile, phase: number?)
	if not active then
		return
	end
	if profile == nil then
		if fightVoice ~= nil then
			fightVoice.target = 0
		end
		return
	end
	local voice = fightVoice
	if voice == nil then
		voice = makeVoice()
		voice.sound.Name = "SanctuaryFight"
		fightVoice = voice
	end
	local step = math.max(0, (phase or 1) - 1)
	local fresh = voice.bed ~= profile.Bed or not voice.sound.IsPlaying
	if fresh then
		if profile.Id ~= nil and profile.Id > 0 then
			voice.sound.SoundId = `rbxassetid://{profile.Id}`
			voice.sound.PlaybackRegionsEnabled = false
			voice.sound.TimePosition = 0
			voice.bed = profile.Bed
			voice.sound:Play()
		else
			play(voice, profile.Bed)
		end
		for _, child in voice.sound:GetChildren() do
			if child:IsA("SoundEffect") then
				child:Destroy()
			end
		end
		if profile.Effect == "Reverb" then
			local reverb = Instance.new("ReverbSoundEffect")
			reverb.DecayTime = 3.4
			reverb.Density = 0.9
			reverb.WetLevel = 4
			reverb.Parent = voice.sound
		elseif profile.Effect == "Distortion" then
			local distortion = Instance.new("DistortionSoundEffect")
			distortion.Level = 0.35
			distortion.Parent = voice.sound
		end
	end
	voice.sound.PlaybackSpeed = profile.Pitch * (1 + 0.07 * step)
	voice.target = math.min(0.85, profile.Level + 0.08 * step)
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
		local fight = fightVoice
		if fight ~= nil then
			if fight.level < fight.target then
				fight.level = math.min(fight.target, fight.level + step)
			elseif fight.level > fight.target then
				fight.level = math.max(fight.target, fight.level - step)
			end
			fight.sound.Volume = fight.level * fight.level
			if fight.level <= 0 and fight.target <= 0 and fight.sound.IsPlaying then
				fight.sound:Stop()
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
	if fightVoice ~= nil then
		table.insert(leaving, fightVoice)
		fightVoice = nil
	end
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
-- Module: sanctuaryControls   (merged from sanctuaryControls.luau, 570 lines)
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

-- One RaycastParams for the life of the module: its filter only changes when the
-- character does. Building a fresh params object (and filter table) every frame
-- allocated needlessly on the camera path.
local cameraParams = RaycastParams.new()
cameraParams.FilterType = Enum.RaycastFilterType.Exclude
local cameraFilterCharacter: Model? = nil
local function cameraRayParams(): RaycastParams
	local character = Players.LocalPlayer.Character
	if character ~= cameraFilterCharacter then
		cameraFilterCharacter = character
		cameraParams.FilterDescendantsInstances = if character ~= nil then { character } else {}
	end
	return cameraParams
end

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
-- Collision: the lens is swept as a small sphere (a point ray lets the near plane clip
-- through corners and thin walls). The distance it is allowed is smoothed: it pulls in
-- almost at once when something closes in, and eases back out when the way clears, so
-- the view never pops as an obstacle enters or leaves the line.
local CAMERA_RADIUS = 0.55
local MIN_CLEAR_ZOOM = 2.2
local clearZoom = 18
-- The character fades out as an obstacle drags the lens close, so it never fills the view.
local FADE_NEAR, FADE_FAR = 2.2, 5.5
local fadedModel: Model? = nil
local fadedParts: { BasePart } = {}
local fadeApplied = 0
local keyboardLooking = false
-- A cinematic shot is blended over the gameplay camera (Controls.cinematic). The player
-- keeps their own view underneath, so ending a shot eases back with nothing to restore.
type Shot = {
	focus: () -> Vector3,
	startedAt: number,
	seconds: number,
	startAngle: number,
	sweep: number,
	distance: number,
	push: number,
	height: number,
	fov: number,
	lock: boolean,
}
local shot: Shot? = nil
-- Kept while the weight eases back to zero after a shot ends.
local lastShot: Shot? = nil
local shotWeight = 0
local SHOT_BLEND_IN, SHOT_BLEND_OUT = 0.6, 0.8
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

-- LocalTransparencyModifier fades only our own view of the character. The part list is
-- rebuilt when the character changes (respawn) and every part is restored on reset.
local function setCharacterFade(model: Model?, amount: number)
	if model ~= fadedModel then
		for _, part in fadedParts do
			if part.Parent ~= nil then
				part.LocalTransparencyModifier = 0
			end
		end
		table.clear(fadedParts)
		fadedModel = model
		fadeApplied = 0
		if model ~= nil then
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(fadedParts, descendant)
				end
			end
		end
	end
	if model == nil or math.abs(amount - fadeApplied) < 0.03 then
		return
	end
	fadeApplied = amount
	for _, part in fadedParts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = amount
		end
	end
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
	clearZoom = 18
	focus = nil
	sprintToggled = false
	jumpQueued = false
	shakeStrength = 0
	shot, lastShot = nil, nil
	shotWeight = 0
	bindInput()
	buildTouchGui()
end

function Controls.stop()
	if not active then
		return
	end
	active = false
	shot, lastShot = nil, nil
	shotWeight = 0
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
	setCharacterFade(nil, 0)
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

-- Play a cinematic shot: the camera orbits `focus` (a point or a function returning one)
-- for `seconds`, sweeping `sweep` radians from the player's current bearing while pushing
-- in by `push` (a fraction of `distance`). `lock` holds the character still for the shot.
-- Returns false when the controls aren't running (nothing to direct).
function Controls.cinematic(spec: {
	Focus: Vector3 | () -> Vector3,
	Seconds: number,
	Sweep: number?,
	Distance: number?,
	Push: number?,
	Height: number?,
	Fov: number?,
	Lock: boolean?,
}): boolean
	if not active then
		return false
	end
	local focusSpec = spec.Focus
	local focusFn: () -> Vector3 = if typeof(focusSpec) == "function" then focusSpec else function()
		return focusSpec :: Vector3
	end
	-- Start from wherever the gameplay camera already looks from, so the cut is seamless.
	local camera = Workspace.CurrentCamera
	local start = focusFn()
	local startAngle = if camera ~= nil then math.atan2(camera.CFrame.Position.Z - start.Z, camera.CFrame.Position.X - start.X) else yaw
	lastShot = nil
	shot = {
		focus = focusFn,
		startedAt = os.clock(),
		seconds = math.max(0.5, spec.Seconds),
		startAngle = startAngle,
		sweep = spec.Sweep or 0.8,
		distance = spec.Distance or 50,
		push = spec.Push or 0.2,
		height = spec.Height or 14,
		fov = spec.Fov or 55,
		lock = spec.Lock == true,
	}
	lastShot = shot
	return true
end

function Controls.endCinematic()
	shot = nil
end

function Controls.inCinematic(): boolean
	return shot ~= nil
end

-- Drag the character toward a point on the ground plane (a gravity well). Called every
-- frame while the pull lasts; `strength` is studs/s added per second, and the result is
-- capped so sprinting away always wins slowly.
function Controls.pull(toward: Vector3, strength: number, dt: number)
	local _, _, root = character()
	if root == nil then
		return
	end
	local offset = Vector3.new(toward.X - root.Position.X, 0, toward.Z - root.Position.Z)
	if offset.Magnitude < 1.5 then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local pulled = velocity + offset.Unit * strength * dt
	local flat = Vector3.new(pulled.X, 0, pulled.Z)
	if flat.Magnitude > 34 then
		flat = flat.Unit * 34
	end
	root.AssemblyLinearVelocity = Vector3.new(flat.X, pulled.Y, flat.Z)
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
	local model, humanoid, root = character()
	if camera == nil or humanoid == nil or root == nil then
		return
	end

	-- Look.
	if gamepadLook.Magnitude > 0 and enabled then
		yaw -= gamepadLook.X * STICK_SPEED * dt
		pitch = math.clamp(pitch + gamepadLook.Y * STICK_SPEED * 0.6 * dt, MIN_PITCH, MAX_PITCH)
	end

	-- Move, relative to where the camera faces.
	local currentShot = shot
	if currentShot ~= nil and os.clock() - currentShot.startedAt >= currentShot.seconds then
		shot, currentShot = nil, nil
	end
	local input = if enabled and not (currentShot ~= nil and currentShot.lock) then keyboardMove() + gamepadMove + touchMove else Vector2.zero
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
	local look = rotation.LookVector
	-- Sweep a sphere back along the view ray to see how far the lens may sit.
	local hit = Workspace:Spherecast(current, CAMERA_RADIUS, -look * zoom, cameraRayParams())
	local allowed = if hit ~= nil then math.clamp(hit.Distance, MIN_CLEAR_ZOOM, zoom) else zoom
	if allowed < clearZoom then
		clearZoom += (allowed - clearZoom) * (1 - math.exp(-45 * dt))
	else
		clearZoom += (allowed - clearZoom) * (1 - math.exp(-5 * dt))
	end
	local eye = current - look * clearZoom
	local frame = CFrame.lookAt(eye, current)
	setCharacterFade(model, math.clamp((FADE_FAR - clearZoom) / (FADE_FAR - FADE_NEAR), 0, 1))
	-- Cinematic shot: ease the weight toward 1 while a shot plays and back to 0 after, and
	-- blend the director's frame over the player's (smoothstep, so cuts in and out are soft).
	local shotTarget = if currentShot ~= nil then 1 else 0
	shotWeight += (shotTarget - shotWeight) * (1 - math.exp(-(if shotTarget > shotWeight then 1 / SHOT_BLEND_IN else 1 / SHOT_BLEND_OUT) * 3 * dt))
	if shotWeight < 0.002 and shotTarget == 0 then
		shotWeight = 0
		lastShot = nil
	end
	local shotFov = BASE_FOV
	local shown = currentShot or lastShot
	if shown ~= nil and shotWeight > 0 then
		local progress = math.min(1, (os.clock() - shown.startedAt) / shown.seconds)
		local angle = shown.startAngle + shown.sweep * progress
		local distance = shown.distance * (1 - shown.push * progress)
		local aim = shown.focus()
		local eyePosition = aim + Vector3.new(math.cos(angle) * distance, shown.height, math.sin(angle) * distance)
		local blend = shotWeight * shotWeight * (3 - 2 * shotWeight)
		frame = frame:Lerp(CFrame.lookAt(eyePosition, aim), blend)
		shotFov = shown.fov
	end
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
	camera.FieldOfView = fov + (shotFov - fov) * shotWeight * shotWeight * (3 - 2 * shotWeight)
end

-- The camera's flat forward, for anything that aims relative to the view.
function Controls.forward(): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

return Controls
end

-- ======================================================================
-- Module: sanctuaryHud   (merged from sanctuaryHud.luau, 1606 lines)
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
	ChoirIsle = "Seven voices, one silence",
	RegentIsle = "The last crown of Emberreach",
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

type WardenInfo = { phase: string, endsAt: number, health: number, maxHealth: number, name: string, island: string }

local function readWarden(model: Model?): WardenInfo
	if model == nil then
		return { phase = "Unknown", endsAt = 0, health = 0, maxHealth = 1, name = BOSS.Name, island = "Riftmaw" }
	end
	return {
		phase = tostring(model:GetAttribute("Phase") or "Dormant"),
		endsAt = tonumber(model:GetAttribute("EndsAt")) or 0,
		health = tonumber(model:GetAttribute("Health")) or 0,
		maxHealth = math.max(1, tonumber(model:GetAttribute("MaxHealth")) or 1),
		name = tostring(model:GetAttribute("BossName") or BOSS.Name),
		island = tostring(model:GetAttribute("BossIsland") or "Riftmaw"),
	}
end

local function sameWardenInfo(a: WardenInfo, b: WardenInfo): boolean
	return a.phase == b.phase and a.endsAt == b.endsAt and a.health == b.health and a.maxHealth == b.maxHealth and a.name == b.name and a.island == b.island
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
		-- Only publish a change: while the Warden model is missing, attach() runs once a
		-- second and a fresh table every time re-rendered the whole HUD forever.
		local function publish()
			local nextInfo = readWarden(model)
			setInfo(function(current)
				if sameWardenInfo(current, nextInfo) then
					return current
				end
				return nextInfo
			end)
		end
		local function attach()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			model = findWarden()
			if model ~= nil then
				connection = model.AttributeChanged:Connect(function()
					publish()
				end)
			end
			publish()
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
local function useInArena(island: string): boolean
	local inArena, setInArena = React.useState(false)
	React.useEffect(function()
		local arena = Layout.arena(island)
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
	end, { island })
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
		right = if props.inArena then clock(remaining) else `{(Layout.region(warden.island) or { Name = "Riftmaw" }).Name} · {clock(remaining)}`
		track = e(HealthTrack, {
			position = UDim2.new(0, left, 1, -left - 6),
			size = UDim2.new(1, -left * 2, 0, 6),
			health = warden.health,
			maxHealth = warden.maxHealth,
			reducedMotion = props.reducedMotion,
		})
	elseif phase == "Forming" then
		title = `{string.upper(warden.name)} · FORMING`
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
		title = `{string.upper(warden.name)} FALLS`
		right = ""
	elseif phase == "Escaped" then
		title = `{string.upper(warden.name)} ESCAPED`
		right = ""
	else
		title = string.upper(warden.name)
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
	local inArena = useInArena(warden.island)
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
		-- Push only on change: at rest both values are constant, and pushing them every
		-- frame for the whole session was a binding update per frame for nothing.
		local pushedCooldown = -1
		local pushedRecharge = -1
		local connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local strikeLeft = math.max(0, STRIKE_COOLDOWN - (now - lastStrike.current))
			local dazeLeft = math.max(0, dazedUntil - now)
			local cooldown = if dazeLeft > 0 then dazeLeft / BOSS.DazeSeconds else strikeLeft / STRIKE_COOLDOWN
			if cooldown ~= pushedCooldown then
				pushedCooldown = cooldown
				setCooldown(cooldown)
			end
			local recharge = math.clamp(1 - (now - recallAt) / RECALL_COOLDOWN, 0, 1)
			if recharge ~= pushedRecharge then
				pushedRecharge = recharge
				setRecharge(recharge)
			end
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
			Signals.on("RiftBossAwake", function(payload)
				local info = if type(payload) == "table" then payload else {}
				showBanner("The rift opens", `{info.Name or BOSS.Name} has woken`, tostring(info.Title or "Strike it in the Riftmaw"), RIFT, 3.4)
			end),
			Signals.on("RiftBossPhase", function(payload)
				local info = if type(payload) == "table" then payload else {}
				local final = (tonumber(info.Phase) or 2) >= 3
				showBanner(if final then "Final phase" else "It changes", tostring(info.Name or BOSS.Name), if final then "It is done holding back" else "Its attacks come faster", RIFT, 2.2)
			end),
			Signals.on("RiftBossStagger", function(payload)
				local seconds = if type(payload) == "table" then tonumber(payload.Daze) or BOSS.DazeSeconds else BOSS.DazeSeconds
				setDazedUntil(os.clock() + seconds)
			end),
			Signals.on("RiftBossDefeated", function(payload)
				lastDefeat.current = os.clock()
				local share = if type(payload) == "table" then tonumber(payload.Share) or 0 else 0
				showBanner("Victory", `{if type(payload) == "table" and payload.Name then payload.Name else BOSS.Name} falls`, `Your share of the fight: {math.floor(share * 100 + 0.5)}%`, Palette.mango, 4)
			end),
			Signals.on("RiftBossFell", function(payload)
				task.delay(0.6, function()
					if os.clock() - lastDefeat.current > 2 then
						showBanner("The rift closes", `{if type(payload) == "table" and payload.Name then payload.Name else BOSS.Name} falls`, "Strike it next time to share the spoils", RIFT, 3.4)
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
	RiftBossPhase = true,
	RiftBossRings = true,
	RiftBossRingLand = true,
	RiftBossSweep = true,
	RiftBossAttack = true,
	RiftBossLances = true,
	RiftBossWell = true,
	RiftBossDissonance = true,
	RiftBossDissonanceLand = true,
	RiftBossWall = true,
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
-- Module: sanctuaryWorld   (merged from sanctuaryWorld.luau, 1164 lines)
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
local ProcAnim = require(Shared:WaitForChild("SharedData"))("ProcAnim")

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

-- Reused every frame (cleared, not reallocated).
local sceneryParts: { BasePart } = {}
local sceneryFrames: { CFrame } = {}

local function stepScenery(t: number, cameraPosition: Vector3)
	local parts = sceneryParts
	local frames = sceneryFrames
	table.clear(parts)
	table.clear(frames)
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
	kind: string,
	config: any,
	extras: { Instance },
	-- Conducting (Choir): eases to 1 while a ring attack is in flight.
	conduct: number,
	conductUntil: number,
	-- The Regent's live beam, if any: { begin, endAt, start, speed }.
	beam: any?,
	spinPhase: number,
	-- Length of the current wind-up, so every ability (not only slams) charges the body.
	slamTotal: number,
	-- The jointed rig (arms or chains) and what it is currently aiming at.
	rig: any,
	aim: any?,
}

local boss: Boss? = nil

-- The fight's colours and config for the boss on stage. Mutated in place (rather than
-- swapped) so every handler below reads the current boss without being passed it.
local pal = { Primary = RIFT, Hot = RIFT_HOT, Alert = SLAM }

-- The audio cue this boss uses for a beat (Forming, Awake, Charge, Land, Phase, Defeat,
-- Escape). Each boss names its own in SanctuaryConfig so the fights sound different.
local function bossCue(beat: string): string
	local current = boss
	local cues = if current ~= nil then current.config.Cues else nil
	return if cues ~= nil and cues[beat] ~= nil then cues[beat] else "wardenSlam"
end

-- Every ability winds the body up (lift, flare, heat) until it lands.
local function windUp(untilAt: number, seconds: number)
	local current = boss
	if current ~= nil then
		current.slamUntil = untilAt
		current.slamTotal = math.max(0.3, seconds)
	end
end

-- While it forms, each piece of the body starts far off along its own heading and flies in.
local scatterDirs: { [BasePart]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local function scatterOf(part: BasePart): Vector3
	local dir = scatterDirs[part]
	if dir == nil then
		local v = Vector3.new(math.random() - 0.5, math.random() * 0.6 + 0.1, math.random() - 0.5)
		dir = if v.Magnitude > 0.05 then v.Unit else Vector3.yAxis
		scatterDirs[part] = dir
	end
	return dir :: Vector3
end
local function configFor(kind: string?): any
	for _, candidate in SanctuaryConfig.RiftBosses do
		if candidate.Kind == kind then
			pal.Primary, pal.Hot, pal.Alert = rgb(candidate.Theme.Primary), rgb(candidate.Theme.Hot), rgb(candidate.Theme.Alert)
			return candidate
		end
	end
	pal.Primary, pal.Hot, pal.Alert = RIFT, RIFT_HOT, SLAM
	return SanctuaryConfig.RiftBoss
end

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

-- Procedural rigs ------------------------------------------------------------------------
-- The bosses are jointed: parts hung on Motor6Ds from an anchored root that turns to face
-- the fight. Nothing here plays a stored animation. Each frame the code decides where the
-- hands should be (or how the chains should hang) and solves the joints to match:
--   arms    two-bone IK reaches for a target, smoothed by a spring so they have weight and
--           overshoot; the claws curl on their own spring
--   chains  each link bends toward a travelling wave plus the pose, on a spring that gets
--           looser toward the tip, so the end trails and whips
-- The Warden and the Regent have arms; the Choir has seven chains (its voices).
type Claw = { motor: Motor6D, base: CFrame, side: number }
type Limb = {
	side: number,
	shoulder: Motor6D,
	elbow: Motor6D,
	claws: { Claw },
	l1: number,
	l2: number,
	offset: Vector3,
	pos: Vector3,
	vel: Vector3,
	curl: number,
	curlVel: number,
}
type Link = { motor: Motor6D, length: number, bend: number, bendVel: number, side: number, sideVel: number }
type Chain = { angle: number, offset: Vector3, links: { Link }, pitch: number, pitchVel: number }
type Rig = {
	root: BasePart,
	limbs: { Limb },
	chains: { Chain },
	parts: { { part: BasePart, base: number } },
	yaw: number,
	yawVel: number,
}

local function riggedPart(rig: Rig, name: string, shape: Enum.PartType?, size: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
	local p = vfxPart(name, shape, size, color, material)
	p.Anchored = false
	p.Massless = true
	p.Transparency = transparency
	table.insert(rig.parts, { part = p, base = transparency })
	return p
end

local function joint(parent: BasePart, child: BasePart, c0: CFrame, c1: CFrame?): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Part0 = parent
	motor.Part1 = child
	motor.C0 = c0
	motor.C1 = c1 or CFrame.identity
	motor.Parent = child
	return motor
end

-- A limb part hangs along its own -Y; this turns that axis to point along `dir`.
local function limbRotation(dir: Vector3): CFrame
	local up = if math.abs(dir.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(Vector3.zero, dir, up) * CFrame.Angles(math.pi / 2, 0, 0)
end

local function buildRig(kind: string, anchorPosition: Vector3): Rig
	local root = vfxPart("RigRoot", nil, Vector3.new(1, 1, 1), pal.Primary, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.CFrame = CFrame.new(anchorPosition)
	local rig: Rig = { root = root, limbs = {}, chains = {}, parts = {}, yaw = 0, yawVel = 0 }
	if kind == "Choir" then
		-- Seven voices: a chain of glass beads hanging round the body, the last one bright.
		local voices, links = 7, 7
		for voice = 1, voices do
			local angle = (voice / voices) * TAU
			local offset = Vector3.new(math.cos(angle) * 3.5, -2, math.sin(angle) * 3.5)
			local chain: Chain = { angle = angle, offset = offset, links = {}, pitch = 0.35, pitchVel = 0 }
			local parent: BasePart = root
			for index = 1, links do
				local size = 2.6 * (1 - 0.09 * index)
				local tip = index == links
				local bead = riggedPart(rig, "Voice", Enum.PartType.Ball, Vector3.new(size, size, size), if tip then pal.Hot else pal.Primary, if index % 2 == 0 or tip then Enum.Material.Neon else Enum.Material.Glass, if index % 2 == 0 or tip then 0.1 else 0.35)
				local length = 4.6 * (1 - 0.05 * index)
				local c0 = if index == 1 then CFrame.new(offset) * CFrame.Angles(0, -angle, 0) else CFrame.new(0, -length, 0)
				table.insert(chain.links, { motor = joint(parent, bead, c0), length = length, bend = 0, bendVel = 0, side = 0, sideVel = 0 })
				parent = bead
			end
			table.insert(rig.chains, chain)
		end
		return rig
	end
	local regent = kind == "Regent"
	local dark = if regent then Color3.fromRGB(28, 22, 26) else Color3.fromRGB(34, 32, 46)
	local l1, l2 = if regent then 11 else 10, if regent then 11 else 10
	local thick = if regent then 3.4 else 2.6
	for _, side in { -1, 1 } do
		local offset = Vector3.new(side * (if regent then 8 else 7), 1, 0)
		local upper = riggedPart(rig, "ArmUpper", nil, Vector3.new(thick, l1, thick), dark, Enum.Material.Basalt, 0)
		local shoulder = joint(rig.root, upper, CFrame.new(offset), CFrame.new(0, l1 / 2, 0))
		local fore = riggedPart(rig, "ArmFore", nil, Vector3.new(thick * 0.85, l2, thick * 0.85), dark, Enum.Material.Basalt, 0)
		local elbow = joint(upper, fore, CFrame.new(0, -l1 / 2, 0), CFrame.new(0, l2 / 2, 0))
		-- Glowing joints at the shoulder and elbow.
		local shoulderBall = riggedPart(rig, "ShoulderGlow", Enum.PartType.Ball, Vector3.new(thick * 1.5, thick * 1.5, thick * 1.5), pal.Primary, Enum.Material.Neon, 0.1)
		joint(rig.root, shoulderBall, CFrame.new(offset))
		local elbowBall = riggedPart(rig, "ElbowGlow", Enum.PartType.Ball, Vector3.new(thick * 1.3, thick * 1.3, thick * 1.3), pal.Primary, Enum.Material.Neon, 0.1)
		joint(upper, elbowBall, CFrame.new(0, -l1 / 2, 0))
		local hand = riggedPart(rig, "Hand", nil, Vector3.new(thick * 1.1, thick * 1.1, thick * 1.4), dark, Enum.Material.Basalt, 0)
		joint(fore, hand, CFrame.new(0, -l2 / 2, 0), CFrame.new(0, thick * 0.55, 0))
		local claws: { Claw } = {}
		for slot = -1, 1 do
			local claw = riggedPart(rig, "Claw", nil, Vector3.new(0.5, thick * 1.6, 0.5), pal.Hot, Enum.Material.Neon, 0.05)
			local base = CFrame.new(slot * thick * 0.35, -thick * 0.5, -thick * 0.3)
			table.insert(claws, { motor = joint(hand, claw, base, CFrame.new(0, thick * 0.8, 0)), base = base, side = slot })
		end
		table.insert(rig.limbs, {
			side = side,
			shoulder = shoulder,
			elbow = elbow,
			claws = claws,
			l1 = l1,
			l2 = l2,
			offset = offset,
			pos = anchorPosition + Vector3.new(side * 9, -8, -4),
			vel = Vector3.zero,
			curl = 0.25,
			curlVel = 0,
		})
	end
	return rig
end

local function destroyRig(rig: Rig)
	for _, entry in rig.parts do
		entry.part:Destroy()
	end
	rig.root:Destroy()
end

local function springVec(position: Vector3, velocity: Vector3, target: Vector3, stiffness: number, ratio: number, dt: number): (Vector3, Vector3)
	local damping = ProcAnim.damping(stiffness, ratio)
	local x, vx = ProcAnim.spring(position.X, velocity.X, target.X, stiffness, damping, dt)
	local y, vy = ProcAnim.spring(position.Y, velocity.Y, target.Y, stiffness, damping, dt)
	local z, vz = ProcAnim.spring(position.Z, velocity.Z, target.Z, stiffness, damping, dt)
	return Vector3.new(x, y, z), Vector3.new(vx, vy, vz)
end

-- Reach a hand toward `target`: smooth the hand with a spring, solve the two bones, and
-- write the joint rotations. Elbows bow out, up and back.
local function solveLimb(rig: Rig, limb: Limb, target: Vector3, curlTarget: number, dt: number)
	limb.pos, limb.vel = springVec(limb.pos, limb.vel, target, 120, 0.55, dt)
	limb.curl, limb.curlVel = ProcAnim.spring(limb.curl, limb.curlVel, curlTarget, 90, ProcAnim.damping(90, 0.7), dt)
	local rootFrame = rig.root.CFrame
	local shoulderWorld = rootFrame:PointToWorldSpace(limb.offset)
	local toTarget = limb.pos - shoulderWorld
	local distance = toTarget.Magnitude
	local direction = if distance > 0.01 then toTarget / distance else -rootFrame.UpVector
	local shoulderAngle, _, reach = ProcAnim.twoBone(limb.l1, limb.l2, distance)
	local pole = rootFrame:VectorToWorldSpace(Vector3.new(limb.side * 0.8, 0.7, 0.6))
	local axis = direction:Cross(pole)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else rootFrame.RightVector
	local upperDirection = CFrame.fromAxisAngle(axis, shoulderAngle):VectorToWorldSpace(direction)
	local elbowWorld = shoulderWorld + upperDirection * limb.l1
	local foreVector = shoulderWorld + direction * reach - elbowWorld
	local foreDirection = if foreVector.Magnitude > 1e-3 then foreVector.Unit else direction
	local upperRotation = limbRotation(upperDirection)
	local foreRotation = limbRotation(foreDirection)
	limb.shoulder.C0 = CFrame.new(limb.offset) * (rootFrame.Rotation:Inverse() * upperRotation)
	limb.elbow.C0 = CFrame.new(0, -limb.l1 / 2, 0) * (upperRotation:Inverse() * foreRotation)
	for _, claw in limb.claws do
		claw.motor.C0 = claw.base * CFrame.Angles(limb.curl * 1.2, 0, claw.side * 0.25 * (1 - limb.curl))
	end
end

-- One chain: its root pitches outward on a spring, every later link bends toward a wave
-- (plus the pose's curl) on springs that loosen toward the tip.
local function solveChain(chain: Chain, pitch: number, curl: number, amplitude: number, beat: number, t: number, dt: number)
	chain.pitch, chain.pitchVel = ProcAnim.spring(chain.pitch, chain.pitchVel, pitch, 30, ProcAnim.damping(30, 0.5), dt)
	local first = chain.links[1]
	first.motor.C0 = CFrame.new(chain.offset) * CFrame.Angles(0, -chain.angle, 0) * CFrame.Angles(0, 0, chain.pitch)
	local count = #chain.links
	for index = 2, count do
		local link = chain.links[index]
		local stiffness = 70 - index * 7
		local damping = ProcAnim.damping(stiffness, 0.45)
		local bendTarget = curl * 0.35 + ProcAnim.wave(index, count, t + chain.angle, 1.6 + beat * 3.6, 0.7, amplitude, 0.9)
		local sideTarget = ProcAnim.wave(index, count, t * 0.8 + chain.angle * 2, 1.2, 0.9, amplitude * 0.6, 0.8)
		link.bend, link.bendVel = ProcAnim.spring(link.bend, link.bendVel, bendTarget, stiffness, damping, dt)
		link.side, link.sideVel = ProcAnim.spring(link.side, link.sideVel, sideTarget, stiffness, damping, dt)
		link.motor.C0 = CFrame.new(0, -link.length, 0) * CFrame.Angles(link.side, 0, link.bend)
	end
end

local strikeCounter = 0
-- What the body is doing right now, as the ability handlers tell it: style is one of slam,
-- thrust, pull, sweep, floor or roar; `point` is where it is aimed (if anywhere); the style
-- lasts until `untilAt` (the moment of impact) and a moment after.
local function setAim(style: string, point: Vector3?, untilAt: number)
	local current = boss
	if current == nil then
		return
	end
	strikeCounter += 1
	current.aim = { style = style, point = point, untilAt = untilAt, striker = strikeCounter % 2 + 1 }
end

-- Where each hand should be. `charge` is the wind-up (0..1) toward the next impact.
local function handTargets(current: Boss, rig: Rig, now: number, t: number, charge: number, phase: string, beamAngle: number?, out: { Vector3 }): number
	local frame = rig.root.CFrame
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local curl = 0.25
	local aim = current.aim
	if aim ~= nil and now > aim.untilAt + 0.9 then
		current.aim = nil
		aim = nil
	end
	for index, limb in rig.limbs do
		local s = limb.side
		local sway = math.sin(t * 1.1 + index * 2) * 0.8
		local target = at(s * 9, -8 + sway, -4)
		if phase == "Dormant" or phase == "Forming" or phase == "Escaped" then
			target = at(s * 3, -3 + sway, -4)
			curl = 0.9
		elseif phase == "Defeated" then
			-- Limp: the arms drop and hang.
			target = at(s * 6, -34, 2)
			curl = 0
		elseif aim ~= nil then
			local style = aim.style
			local since = math.clamp((now - aim.untilAt) / 0.45, 0, 1)
			local blow = ProcAnim.strike(since)
			if style == "slam" and aim.point ~= nil then
				local striker = index == aim.striker
				local raised = at(s * 6, 4 + 13 * (if striker then charge else charge * 0.7), -3 - 2 * charge)
				if now < aim.untilAt then
					target = raised
					curl = 0.9
				elseif striker then
					target = raised:Lerp(aim.point + Vector3.new(0, 1, 0), blow)
					curl = 0.15
				else
					target = at(s * 8, -6, -6)
				end
			elseif style == "thrust" then
				local spread = at(s * 19, 3, -2)
				if now < aim.untilAt then
					target = spread
					curl = 0
				else
					target = spread:Lerp(at(s * 6, 2, -19), blow)
					curl = 0.2
				end
			elseif style == "pull" and aim.point ~= nil then
				local drag = 0.5 + 0.5 * math.sin(now * 5 + index * math.pi)
				target = aim.point:Lerp(at(s * 6, -2, -8), drag * 0.6) + Vector3.new(0, 6, 0)
				curl = 0.3 + 0.7 * drag
			elseif style == "sweep" and beamAngle ~= nil then
				-- One arm points down the beam, the other braces.
				if s > 0 then
					target = rig.root.Position + Vector3.new(math.cos(beamAngle) * 19, 2, math.sin(beamAngle) * 19)
					curl = 0
				else
					target = at(-10, 4, -2)
					curl = 0.6
				end
			elseif style == "floor" then
				local raised = at(s * 8, 12 * charge, -2)
				if now < aim.untilAt then
					target = raised
					curl = 0.9
				else
					target = raised:Lerp(at(s * 10, -24, -6), blow)
					curl = 0.1
				end
			elseif style == "roar" then
				target = at(s * 15, 15 + math.sin(t * 6) * 1.5, 0)
				curl = 0
			end
		elseif charge > 0 then
			target = at(s * 8, -4 + 8 * charge, -4 - 2 * charge)
			curl = 0.6
		end
		out[index] = target
	end
	return curl
end

local chainScratch = { 0.35, 0.1, 0.18, 0 }
-- How the chains hang: pitch (0 hangs, ~2.2 raised), curl, sway amplitude and beat sync.
local function chainPose(current: Boss, now: number, charge: number, phase: string): { number }
	local pitch, curl, amplitude, beat = 0.35, 0.1, 0.18, 0
	local aim = current.aim
	if phase == "Defeated" then
		pitch, curl, amplitude = 0, 0, 0.05
	elseif phase == "Dormant" or phase == "Forming" or phase == "Escaped" then
		pitch, curl, amplitude = -0.1, 0.8, 0.06
	elseif current.conduct > 0.05 then
		-- Conducting the rings: raised and beating in time.
		pitch = 0.35 + 1.9 * current.conduct
		curl = 0.6 * current.conduct
		amplitude = 0.05
		beat = current.conduct
	elseif aim ~= nil and now < aim.untilAt + 0.9 then
		if aim.style == "slam" then
			if now < aim.untilAt then
				pitch = 0.35 + 1.9 * charge
				curl = 0.5 * charge
			else
				-- The lash: down hard from the top of the swing, past the mark and back.
				local blow = ProcAnim.strike((now - aim.untilAt) / 0.5)
				pitch = 2.25 * (1 - blow) - 0.25 * blow
				amplitude = 0.3
			end
		elseif aim.style == "roar" then
			pitch, amplitude, curl = 1.3, 0.32, 0.2
		end
	elseif charge > 0 then
		pitch = 0.35 + 1.2 * charge
		curl = 0.3 * charge
	end
	chainScratch[1], chainScratch[2], chainScratch[3], chainScratch[4] = pitch, curl, amplitude, beat
	return chainScratch
end

local handScratch: { Vector3 } = {}
local function buildBoss(model: Model): Boss
	local anchor = model.PrimaryPart :: BasePart
	local kind = tostring(model:GetAttribute("BossKind") or "Warden")
	local config = configFor(kind)
	local rig = buildRig(kind, anchor.Position)
	-- Body proportions differ: the Choir is a small bright core in a large glass shell, the
	-- Regent a heavy ember heart that nearly fills its shell.
	local coreSize = if kind == "Choir" then Vector3.new(7, 7, 7) elseif kind == "Regent" then Vector3.new(10.5, 10.5, 10.5) else Vector3.new(9, 9, 9)
	local shellSize = if kind == "Choir" then Vector3.new(13.5, 13.5, 13.5) elseif kind == "Regent" then Vector3.new(13, 13, 13) else Vector3.new(11.5, 11.5, 11.5)
	-- Faceted crystal heart inside a glass shell.
	local core = bossPart("WardenCore", "WardenCore", Enum.PartType.Ball, coreSize, pal.Primary, Enum.Material.Neon)
	local shell = bossPart("WardenCore", "WardenShell", Enum.PartType.Ball, shellSize, pal.Hot, Enum.Material.Glass)
	shell.Transparency = 0.6
	local eye = vfxPart("WardenEye", Enum.PartType.Ball, Vector3.new(2.3, 2.3, 2.3), Color3.fromRGB(240, 250, 255), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = pal.Primary
	light.Range = 70
	light.Brightness = 3
	light.Shadows = false
	light.Parent = core
	-- Motes streaming off the heart, a slow rift vortex and a soft glow.
	local aura = Vfx.attach(core, "Motes", { Color = pal.Hot, Color2 = pal.Primary, Rate = 16, Speed = NumberRange.new(2, 5) })
	local swirl = Vfx.attach(core, "Swirl", { Color = pal.Primary, Color2 = pal.Hot, Size = NumberSequence.new(20, 26) })
	local glowHalo = Vfx.attach(core, "Halo", { Color = pal.Primary, Size = NumberSequence.new(24, 28) })
	-- Each boss adds its own effects: the Choir sheds fine glass dust, the Regent burns.
	local extras: { Instance } = {}
	if kind == "Choir" then
		table.insert(extras, Vfx.attach(core, "Motes", { Color = pal.Hot, Color2 = pal.Primary, Rate = 26, Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.5, 0) }))
	elseif kind == "Regent" then
		table.insert(extras, Vfx.attach(core, "Rising", { Color = pal.Primary, Color2 = pal.Hot, Rate = 34, Speed = NumberRange.new(6, 14) }))
		local flame = Instance.new("Fire")
		flame.Color = pal.Primary
		flame.SecondaryColor = pal.Hot
		flame.Size = 22
		flame.Heat = 16
		flame.Parent = core
		table.insert(extras, flame)
	end

	local rings: { Piece } = {}
	local ringSpecs = {
		{ diameter = 17, tilt = CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 40, 0) },
		{ diameter = 22, tilt = CFrame.Angles(math.rad(62), math.rad(30), 0), spin = Vector3.new(0, -28, 0) },
		{ diameter = 28, tilt = CFrame.Angles(math.rad(110), math.rad(-40), 0), spin = Vector3.new(0, 18, 0) },
	}
	for index, spec in ringSpecs do
		-- The kit halo lies flat (normal +Y); the primitive ring's axis is X.
		local size = if AssetKit.has("Halo") then Vector3.new(spec.diameter, 0.6, spec.diameter) else Vector3.new(0.35, spec.diameter, spec.diameter)
		local ring = bossPart("Halo", `WardenRing{index}`, Enum.PartType.Cylinder, size, pal.Hot, Enum.Material.Neon)
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
			then bossPart("WardenPlate", `WardenSeam{index}`, nil, AssetKit.sized("WardenPlate", 0.7), pal.Primary, Enum.Material.Neon)
			else vfxPart(`WardenSeam{index}`, nil, Vector3.new(0.4, 6, 0.4), pal.Primary, Enum.Material.Neon)
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
		local shard = bossPart("WardenBlade", `WardenShard{index}`, nil, if AssetKit.has("WardenBlade") then AssetKit.sized("WardenBlade", 1.3) else Vector3.new(1, 6.5, 1), pal.Hot, Enum.Material.Neon)
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
		kind = kind,
		config = config,
		extras = extras,
		conduct = 0,
		conductUntil = 0,
		beam = nil,
		spinPhase = 0,
		slamTotal = 1.5,
		rig = rig,
		aim = nil,
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
	destroyRig(current.rig)
end

-- Rift tethers (beams from the arena pillars to the seal, built by the
-- server) light up while the Warden is forming or fighting.
local tethersOn = false
local function setTethers(on: boolean, kind: string?)
	tethersOn = on
	for _, beam in CollectionService:GetTagged("AF_RiftTether") do
		if beam:IsA("Beam") then
			beam.Enabled = on and (kind == nil or beam:GetAttribute("BossKind") == kind)
		end
	end
end

-- A piece's child parts never change after buildBoss, so list them once instead
-- of calling GetChildren on every piece every frame.
local pieceKids: { [BasePart]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any
local function kidsOf(part: BasePart): { BasePart }
	local kids = pieceKids[part]
	if kids == nil then
		kids = {}
		for _, child in part:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(kids :: { BasePart }, child)
			end
		end
		pieceKids[part] = kids
	end
	return kids :: { BasePart }
end

local function applyPieceTransparency(list: { Piece }, hide: number)
	for _, piece in list do
		piece.part.Transparency = piece.transparency + (1 - piece.transparency) * hide
		for _, child in kidsOf(piece.part) do
			child.Transparency = hide
		end
	end
end

-- The last (boss, hide) pair written: fades hold at 0 or 1 for long stretches and
-- rewriting every part's Transparency each frame for nothing is measurable.
local appliedBoss: Boss? = nil
local appliedHide = -1

local function setBossTransparency(current: Boss, visible: number)
	local hide = 1 - math.clamp(visible, 0, 1)
	if appliedBoss == current and math.abs(appliedHide - hide) < 0.002 then
		return
	end
	appliedBoss = current
	appliedHide = hide
	current.core.Transparency = hide
	current.shell.Transparency = 0.6 + 0.4 * hide
	current.eye.Transparency = hide
	current.coreLight.Enabled = visible > 0.02
	current.aura.Enabled = visible > 0.2
	for _, extra in current.extras do
		(extra :: any).Enabled = visible > 0.3
	end
	current.swirl.Enabled = visible > 0.3
	current.glowHalo.Enabled = visible > 0.3
	applyPieceTransparency(current.rings, hide)
	applyPieceTransparency(current.plates, hide)
	applyPieceTransparency(current.shards, hide)
	for _, entry in current.rig.parts do
		entry.part.Transparency = entry.base + (1 - entry.base) * hide
	end
end

-- Effects library: the big set pieces the fights are built from. Everything here is
-- client-only, made of neon parts that fade themselves out, and a handful of GUI layers.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- A jagged bolt between two points: short neon blocks along a jittered path.
local function lightning(from: Vector3, to: Vector3, color: Color3, seconds: number?, width: number?)
	local life = seconds or 0.25
	local thick = width or 0.7
	local along = to - from
	if along.Magnitude < 1 then
		return
	end
	local perp = along:Cross(Vector3.yAxis)
	perp = if perp.Magnitude < 0.01 then Vector3.xAxis else perp.Unit
	local other = perp:Cross(along.Unit)
	local steps = math.clamp(math.floor(along.Magnitude / 6), 3, 14)
	local previous = from
	for index = 1, steps do
		local k = index / steps
		local point = from:Lerp(to, k)
		if index < steps then
			local jitter = (1 - math.abs(k - 0.5) * 0.6) * (along.Magnitude / steps) * 0.5
			point += perp * (math.random() - 0.5) * 2 * jitter + other * (math.random() - 0.5) * 2 * jitter
		end
		local length = (point - previous).Magnitude
		if length > 0.05 then
			local bolt = vfxPart("Bolt", nil, Vector3.new(thick, thick, length), color, Enum.Material.Neon)
			bolt.CFrame = CFrame.lookAt((previous + point) / 2, point)
			bolt.Transparency = 0.05
			TweenService:Create(bolt, TweenInfo.new(life), { Transparency = 1 }):Play()
			Debris:AddItem(bolt, life + 0.05)
		end
		previous = point
	end
end

-- A column of light that flares and collapses to a thread.
local function lightPillar(at: Vector3, color: Color3, height: number, radius: number, seconds: number)
	local column = vfxPart("LightPillar", Enum.PartType.Cylinder, Vector3.new(height, radius * 2, radius * 2), color, Enum.Material.Neon)
	column.CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Transparency = 0.2
	TweenService:Create(column, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = Vector3.new(height, radius * 0.25, radius * 0.25) }):Play()
	Debris:AddItem(column, seconds + 0.1)
	Vfx.burst(at + Vector3.new(0, 1, 0), "Flash", 1, { Color = color, Size = NumberSequence.new(radius * 2, radius * 6) }, clientFolder)
end

-- Cracks racing out across the floor from a point, glowing and fading.
local function groundCrack(center: Vector3, radius: number, color: Color3, seconds: number)
	local spokes = 10
	for index = 1, spokes do
		local angle = (index / spokes) * TAU + math.random() * 0.3
		local length = radius * (0.6 + math.random() * 0.5)
		local strip = vfxPart("Crack", nil, Vector3.new(length, 0.2, 0.6 + math.random() * 0.8), color, Enum.Material.Neon)
		strip.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * length / 2, 0.15, math.sin(angle) * length / 2)) * CFrame.Angles(0, -angle, 0)
		strip.Transparency = 0.1
		TweenService:Create(strip, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		Debris:AddItem(strip, seconds + 0.05)
	end
end

local flashGui: ScreenGui? = nil
local flashFrame: Frame? = nil

-- A wash of colour over the whole screen that fades out.
local function screenFlash(color: Color3, strength: number, seconds: number)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	if flashGui == nil or flashGui.Parent == nil or flashFrame == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "SanctuaryFlash"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 45
		local frame = Instance.new("Frame")
		frame.Name = "Flash"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		gui.Parent = playerGui
		flashGui, flashFrame = gui, frame
	end
	local frame = flashFrame :: Frame
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	TweenService:Create(frame, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

-- Dialogue: a caption box low on the screen, the speaker's name in their colour, and the
-- line typed out. One line at a time; a new line replaces the last.
local speechGui: ScreenGui? = nil
local speechBox: Frame? = nil
local speechName: TextLabel? = nil
local speechText: TextLabel? = nil
local speechStroke: UIStroke? = nil
local speechSeq = 0

local function ensureSpeech(): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return false
	end
	if speechGui ~= nil and speechGui.Parent ~= nil then
		return true
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SanctuarySpeech"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 42
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.fromScale(0.5, 0.8)
	box.Size = UDim2.new(0.6, 0, 0, 96)
	box.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
	box.BackgroundTransparency = 0.25
	box.BorderSizePixel = 0
	box.Active = false
	box.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, 120)
	limit.MinSize = Vector2.new(240, 80)
	limit.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0.45
	stroke.Parent = box
	local name = Instance.new("TextLabel")
	name.Name = "Speaker"
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 16, 0, 8)
	name.Size = UDim2.new(1, -32, 0, 18)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = box
	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 16, 0, 30)
	text.Size = UDim2.new(1, -32, 1, -38)
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 19
	text.TextColor3 = Color3.fromRGB(240, 240, 250)
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Parent = box
	box.Parent = gui
	gui.Parent = playerGui
	speechGui, speechBox, speechName, speechText, speechStroke = gui, box, name, text, stroke
	return true
end

local function say(speaker: string, line: string, color: Color3?)
	if not ensureSpeech() then
		return
	end
	local box, name, text, stroke = speechBox :: Frame, speechName :: TextLabel, speechText :: TextLabel, speechStroke :: UIStroke
	speechSeq += 1
	local seq = speechSeq
	local accent = color or Color3.new(1, 1, 1)
	name.Text = string.upper(speaker)
	name.TextColor3 = accent
	stroke.Color = accent
	text.Text = line
	text.MaxVisibleGraphemes = 0
	box.BackgroundTransparency = 0.25
	box.Visible = true
	task.spawn(function()
		local count = utf8.len(line) or #line
		local each = math.clamp(1.1 / math.max(1, count), 0.012, 0.035)
		for shown = 1, count do
			if speechSeq ~= seq or text.Parent == nil then
				return
			end
			text.MaxVisibleGraphemes = shown
			task.wait(each)
		end
		text.MaxVisibleGraphemes = -1
	end)
	task.delay(1.8 + (utf8.len(line) or #line) * 0.05, function()
		if speechSeq == seq and box.Parent ~= nil then
			box.Visible = false
		end
	end)
end

local function clearFx()
	speechSeq += 1
	for _, gui in { speechGui, flashGui } do
		if gui ~= nil then
			gui:Destroy()
		end
	end
	speechGui, speechBox, speechName, speechText, speechStroke = nil, nil, nil, nil, nil
	flashGui, flashFrame = nil, nil
end
-- Cinematics: black bars slide in over the top and bottom of the screen while the camera
-- (Controls.cinematic) is directed, and slide out just before it hands back.
local TweenService = game:GetService("TweenService")
local cinemaGui: ScreenGui? = nil
local cinemaSeq = 0
local BAR_HEIGHT = 0.11

local function cinemaBars(seconds: number)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local gui = cinemaGui
	if gui == nil or gui.Parent == nil then
		gui = Instance.new("ScreenGui")
		gui.Name = "SanctuaryCinema"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 40
		for _, edge in { "Top", "Bottom" } do
			local bar = Instance.new("Frame")
			bar.Name = edge
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.Active = false
			bar.AnchorPoint = Vector2.new(0, if edge == "Top" then 0 else 1)
			bar.Position = UDim2.fromScale(0, if edge == "Top" then 0 else 1)
			bar.Size = UDim2.fromScale(1, 0)
			bar.Parent = gui
		end
		gui.Parent = playerGui
		cinemaGui = gui
	end
	local shown = gui :: ScreenGui
	cinemaSeq += 1
	local seq = cinemaSeq
	local function slide(height: number, seconds: number, direction: Enum.EasingDirection)
		for _, bar in shown:GetChildren() do
			TweenService:Create(bar, TweenInfo.new(seconds, Enum.EasingStyle.Quint, direction), { Size = UDim2.fromScale(1, height) }):Play()
		end
	end
	slide(BAR_HEIGHT, 0.5, Enum.EasingDirection.Out)
	task.delay(math.max(0.6, seconds - 0.6), function()
		if cinemaSeq == seq and shown.Parent ~= nil then
			slide(0, 0.6, Enum.EasingDirection.In)
		end
	end)
end

local function clearCinema()
	clearFx()
	cinemaSeq += 1
	if cinemaGui ~= nil then
		cinemaGui:Destroy()
		cinemaGui = nil
	end
end

-- Direct the camera at the boss for a moment, if the local player is near enough to care.
-- `bars` is how long the letterbox stays (defaults to the shot; 0 leaves it alone, for a
-- shot that continues a scene already showing them). `spec.Lift` raises the focus above the
-- boss's body (negative looks up at it from below).
local function playShot(current: Boss, spec: { [string]: any }, bars: number?): boolean
	local root = localRoot()
	if root == nil or (root.Position - current.anchor.Position).Magnitude > 300 then
		return false
	end
	local lift = tonumber(spec.Lift) or 0
	spec.Focus = function()
		return current.anchor.Position + Vector3.new(0, 4 + lift, 0)
	end
	if Controls.cinematic(spec) then
		local barSeconds = if bars == nil then spec.Seconds else bars
		if barSeconds > 0 then
			cinemaBars(barSeconds)
		end
		return true
	end
	return false
end

-- Where the arena's pillar lights are, for scenes that play off them.
local function pillarTops(current: Boss): { Vector3 }
	local arena = Layout.arena(current.config.Island)
	local kind = current.kind
	local count = if kind == "Choir" then 7 elseif kind == "Regent" then 6 else 8
	local rise = if kind == "Choir" then 39 elseif kind == "Regent" then 33 else 29
	local tops = {}
	for k = 1, count do
		local angle = (k / count) * TAU + math.pi / count
		table.insert(tops, ORIGIN + Vector3.new(arena.Center.X + math.cos(angle) * arena.PillarRadius, arena.Center.Y + rise, arena.Center.Z + math.sin(angle) * arena.PillarRadius))
	end
	return tops
end

-- Run steps at offsets (seconds) while the same boss is still on stage.
local function sequence(current: Boss, steps: { { at: number, run: () -> () } })
	for _, step in steps do
		task.delay(step.at, function()
			if boss == current and current.model.Parent ~= nil then
				step.run()
			end
		end)
	end
end

-- Dialogue. Lines live in each boss's SanctuaryConfig entry; these play them at offsets, or
-- as occasional quips that are rate limited so a fight is not a monologue.
local function near(current: Boss): boolean
	local root = localRoot()
	return root ~= nil and (root.Position - current.anchor.Position).Magnitude < 300
end

local function speakLines(current: Boss, key: string, startAt: number, gap: number)
	local lines = current.config.Dialogue[key]
	if lines == nil then
		return
	end
	for index, line in lines do
		task.delay(startAt + (index - 1) * gap, function()
			if boss == current and near(current) then
				say(current.config.Name, line, pal.Hot)
			end
		end)
	end
end

local lastQuip = 0
local function quip(current: Boss, lines: { string }?, cooldown: number, chance: number)
	if lines == nil or #lines == 0 or os.clock() - lastQuip < cooldown or math.random() > chance or not near(current) then
		return
	end
	lastQuip = os.clock()
	say(current.config.Name, lines[math.random(#lines)], pal.Hot)
end

-- Each boss wakes with its own cutscene. The letterbox and title card (the HUD banner) are
-- shared; the camera work and what happens on the pillars are not.
--   Warden  one slow orbit round the opening rift
--   Choir   starts on the floor as the seven voices wake one by one, then rises to the boss
--   Regent  looks up at the crown from below as the flames catch, then pulls back wide
local function awakeScene(current: Boss)
	local kind = current.kind
	local tops = pillarTops(current)
	-- The boss speaks over the scene, and every pillar arcs its light into the body as it wakes.
	speakLines(current, "Awake", 0.6, 2.1)
	for index, top in tops do
		task.delay(0.2 * index, function()
			if boss == current then
				lightning(top, current.anchor.Position, pal.Hot, 0.45, 0.9)
			end
		end)
	end
	screenFlash(pal.Hot, 0.4, 0.8)
	task.delay(0.5, function()
		if boss == current then
			lightPillar(current.anchor.Position - Vector3.new(0, 26, 0), pal.Hot, 90, 7, 1.4)
		end
	end)
	if kind == "Choir" then
		local steps = {}
		for index, top in tops do
			table.insert(steps, {
				at = 0.25 * index,
				run = function()
					Vfx.burst(top, "Flash", 1, { Color = pal.Hot, Size = NumberSequence.new(4, 14) }, clientFolder)
					Vfx.burst(top, "Shatter", 10, { Color = pal.Hot, Color2 = pal.Primary, Speed = NumberRange.new(3, 9) }, clientFolder)
					Audio:play(bossCue("Phase"))
				end,
			})
		end
		table.insert(steps, { at = 0, run = function() playShot(current, { Seconds = 2.7, Sweep = 0.9, Distance = 44, Height = 3, Lift = -2, Fov = 62, Lock = true }, 6.3) end })
		table.insert(steps, { at = 2.7, run = function() playShot(current, { Seconds = 3.6, Sweep = 1.3, Distance = 66, Push = 0.3, Height = 28, Lift = 6, Fov = 46, Lock = true }, 0) end })
		sequence(current, steps)
	elseif kind == "Regent" then
		local steps = {}
		for index, top in tops do
			table.insert(steps, {
				at = 0.4 * index,
				run = function()
					Vfx.burst(top, "Flash", 1, { Color = pal.Alert, Size = NumberSequence.new(6, 20) }, clientFolder)
					Vfx.burst(top, "Shatter", 16, { Color = pal.Primary, Color2 = pal.Hot, Speed = NumberRange.new(6, 16), Acceleration = Vector3.new(0, 10, 0) }, clientFolder)
					Audio:play(bossCue("Phase"))
				end,
			})
		end
		table.insert(steps, { at = 0, run = function() playShot(current, { Seconds = 3, Sweep = -0.7, Distance = 46, Height = -10, Lift = 4, Fov = 64, Lock = true }, 6.8) end })
		table.insert(steps, { at = 3, run = function() playShot(current, { Seconds = 3.8, Sweep = -1.2, Distance = 84, Push = 0.15, Height = 24, Fov = 46, Lock = true }, 0) end })
		sequence(current, steps)
	else
		playShot(current, { Seconds = 4.2, Sweep = 1.6, Distance = 58, Push = 0.28, Height = 15, Fov = 50, Lock = true })
	end
end

local function defeatScene(current: Boss)
	local kind = current.kind
	speakLines(current, "Defeat", 0.9, 3.2)
	-- The body comes apart in light: a great column, bolts to every pillar, a white-out.
	screenFlash(Color3.new(1, 1, 1), 0.75, 1.6)
	lightPillar(current.anchor.Position - Vector3.new(0, 26, 0), pal.Hot, 140, 12, 2.4)
	for index, top in pillarTops(current) do
		task.delay(0.15 * index, function()
			if boss == current then
				lightning(current.anchor.Position, top, pal.Hot, 0.5, 1.2)
			end
		end)
	end
	if kind == "Warden" then
		playShot(current, { Seconds = 5, Sweep = 1.2, Distance = 64, Push = -0.15, Height = 10, Fov = 48 })
		return
	end
	-- The arena gives way pillar by pillar while the camera backs off.
	local steps = {}
	for index, top in pillarTops(current) do
		table.insert(steps, {
			at = 0.3 * index,
			run = function()
				Vfx.burst(top, "Shatter", 40, { Color = pal.Hot, Color2 = pal.Primary, Speed = NumberRange.new(10, 24), Acceleration = Vector3.new(0, if kind == "Regent" then 12 else -8, 0) }, clientFolder)
				Vfx.burst(top, "Flash", 1, { Color = pal.Hot, Size = NumberSequence.new(6, 22) }, clientFolder)
				Audio:play(bossCue("Phase"))
			end,
		})
	end
	if kind == "Choir" then
		table.insert(steps, { at = 0, run = function() playShot(current, { Seconds = 5.5, Sweep = 1.5, Distance = 70, Push = -0.2, Height = 20, Fov = 50 }) end })
	else
		table.insert(steps, { at = 0, run = function() playShot(current, { Seconds = 5.5, Sweep = -1, Distance = 56, Push = -0.25, Height = 4, Lift = 4, Fov = 52 }) end })
	end
	sequence(current, steps)
end

-- After a failed frame the warden is torn down; rebuilding it on the very next
-- frame would repeat a deterministic error 60 times a second.
local bossRetryAt = 0
local bossParts: { BasePart } = {}
local bossFrames: { CFrame } = {}

local function stepBoss(dt: number, t: number)
	if boss == nil then
		-- Build once the model kit has loaded (or is known to be absent).
		if not kitSettled or os.clock() < bossRetryAt then
			return
		end
		local model = findWarden()
		if model == nil then
			return
		end
		boss = buildBoss(model)
		local joined = tostring(model:GetAttribute("Phase") or "Dormant")
		setTethers(joined == "Forming" or joined == "Active", (boss :: Boss).kind)
		if joined == "Active" then
			Ambience.fight((boss :: Boss).config.Music, tonumber(model:GetAttribute("BossPhase")) or 1)
		end
	end
	local current = boss :: Boss
	if current.model.Parent == nil then
		destroyBoss()
		return
	end
	-- A different boss takes the stage each cycle: rebuild the body in its colours.
	if tostring(current.model:GetAttribute("BossKind") or "Warden") ~= current.kind then
		destroyBoss()
		return
	end
	local config = current.config
	local phase = tostring(current.model:GetAttribute("Phase") or "Dormant")
	local endsAt = tonumber(current.model:GetAttribute("EndsAt")) or 0
	local health = tonumber(current.model:GetAttribute("Health")) or 0
	local now = serverNow()

	-- Phase changes: sounds and one-off moments.
	if phase ~= current.lastPhase then
		local at = current.anchor.Position
		if phase == "Forming" then
			Audio:play(bossCue("Forming"))
			speakLines(current, "Forming", 0.4, 2)
			setTethers(true, current.kind)
			Vfx.burst(at, "Implode", 1, { Color = pal.Hot, Color2 = pal.Primary, Size = NumberSequence.new(40, 2) }, clientFolder)
			Vfx.burst(at, "Shatter", 40, { Color = pal.Hot, Speed = NumberRange.new(4, 10), Acceleration = Vector3.new(0, 6, 0) }, clientFolder)
		elseif phase == "Active" then
			Audio:play(bossCue("Awake"))
			Controls.shake(0.5)
			awakeScene(current)
			setTethers(true, current.kind)
			Ambience.fight(config.Music, 1)
			Vfx.burst(at, "Flash", 1, { Color = pal.Hot, Size = NumberSequence.new(10, 34) }, clientFolder)
			Vfx.burst(at - Vector3.new(0, 24, 0), "Shockwave", 1, { Color = pal.Primary, Size = NumberSequence.new(4, 90) }, clientFolder)
		elseif phase == "Defeated" then
			Audio:play(bossCue("Defeat"))
			Ambience.fight(nil)
			current.outroStarted = t
			setTethers(false)
			Vfx.burst(at, "Flash", 2, { Color = Color3.new(1, 1, 1), Color2 = pal.Hot, Size = NumberSequence.new(12, 44) }, clientFolder)
			Vfx.burst(at, "Shatter", 110, { Color = pal.Hot, Color2 = pal.Primary, Speed = NumberRange.new(18, 40), Size = NumberSequence.new(1.1, 0) }, clientFolder)
			Vfx.burst(at - Vector3.new(0, 24, 0), "Shockwave", 1, { Color = pal.Hot, Size = NumberSequence.new(6, 120) }, clientFolder)
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
			defeatScene(current)
		elseif phase == "Escaped" then
			Audio:play(bossCue("Escape"))
			speakLines(current, "Escape", 0.4, 2.5)
			Ambience.fight(nil)
			current.outroStarted = t
			setTethers(false)
			Vfx.burst(at, "Implode", 1, { Color = pal.Primary, Size = NumberSequence.new(30, 0.5) }, clientFolder)
		elseif phase == "Dormant" then
			Ambience.fight(nil)
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
		local total = current.slamTotal
		local k = math.clamp(1 - (current.slamUntil - now) / total, 0, 1)
		lift = math.sin(k * math.pi * 0.5) * 5
		charge = k
	end
	current.slamLift += (lift - current.slamLift) * (1 - math.exp(-12 * dt))
	local chargePulse = if charge > 0 then charge * (0.55 + 0.45 * math.sin(t * (8 + charge * 22))) else 0

	local escaping = phase == "Escaped"
	local collapse = if escaping then math.clamp((t - current.outroStarted) / 1.4, 0, 1) else 0
	-- How each body idles: the Choir floats high and slow, the Regent sits heavy and steady.
	local kind = current.kind
	local bob = if kind == "Choir" then math.sin(t * 1.4) * 2.2 elseif kind == "Regent" then math.sin(t * 0.6) * 1.0 else math.sin(t * 0.9) * 1.4
	local conducting = if current.conductUntil > now then 1 else 0
	current.conduct += (conducting - current.conduct) * (1 - math.exp(-6 * dt))
	local beam = current.beam
	local beamAngle: number? = nil
	if beam ~= nil then
		if now > beam.endAt + 0.3 then
			current.beam = nil
		elseif now >= beam.begin - 0.6 then
			beamAngle = beam.start + beam.speed * math.clamp(now - beam.begin, 0, beam.endAt - beam.begin)
		end
	end
	-- The crown turns faster while the beam is out.
	current.spinPhase += dt * (if beamAngle ~= nil then 1.6 else 0.35)
	local hover = current.anchor.Position + Vector3.new(0, bob + current.slamLift + current.conduct * 3, 0)
	local coreScale = 1 + current.flash * 0.12 + (if phase == "Defeated" then math.clamp((t - current.outroStarted) * 0.8, 0, 1.2) else 0)
	if kind == "Choir" then
		coreScale *= 1 + 0.06 * math.sin(t * 3.2) + current.conduct * 0.1
	elseif kind == "Regent" then
		coreScale *= 1 + 0.04 * math.sin(t * 1.6) + (if beamAngle ~= nil then 0.08 else 0)
	end
	coreScale *= (1 - collapse * 0.95)
	current.core.Size = current.coreSize * coreScale
	current.core.Color = pal.Primary:Lerp(pal.Alert, chargePulse * 0.75):Lerp(Color3.new(1, 1, 1), current.flash * 0.7)
	current.shell.Size = current.shellSize * coreScale
	current.coreLight.Brightness = 3 + current.flash * 6 + chargePulse * 4
	current.coreLight.Color = pal.Primary:Lerp(pal.Alert, chargePulse)

	-- Reused every frame (cleared, not reallocated); BulkMoveTo needs exact-length arrays.
	local parts = bossParts
	local frames = bossFrames
	table.clear(parts)
	table.clear(frames)
	parts[1], parts[2] = current.core, current.shell
	frames[1], frames[2] = CFrame.new(hover), CFrame.new(hover)

	-- The eye turns toward the local player.
	local root = localRoot()
	local lookDir = if root ~= nil then (root.Position - hover) else Vector3.new(0, 0, 1)
	lookDir = if lookDir.Magnitude > 0.5 then lookDir.Unit else Vector3.new(0, 0, 1)
	-- The Regent's eye follows its own beam round the arena.
	if beamAngle ~= nil then
		lookDir = Vector3.new(math.cos(beamAngle), 0, math.sin(beamAngle))
	end
	table.insert(parts, current.eye)
	table.insert(frames, CFrame.new(hover + lookDir * 5.2 * coreScale))

	-- The rig: the root turns to face the fight (the beam, what it is striking, else the local
	-- player) on a spring, then the arms reach and the chains hang for the current pose.
	local rig: Rig = current.rig
	do
		local aim = current.aim
		local focusAngle: number? = nil
		if beamAngle ~= nil then
			focusAngle = beamAngle
		elseif aim ~= nil and aim.point ~= nil and now < aim.untilAt + 0.9 then
			focusAngle = math.atan2(aim.point.Z - hover.Z, aim.point.X - hover.X)
		elseif root ~= nil then
			focusAngle = math.atan2(root.Position.Z - hover.Z, root.Position.X - hover.X)
		end
		if focusAngle ~= nil then
			local moved, velocity = ProcAnim.spring(0, rig.yawVel, ProcAnim.angleDelta(focusAngle, rig.yaw), 14, ProcAnim.damping(14, 0.6), dt)
			rig.yaw += moved
			rig.yawVel = velocity
		end
		rig.root.CFrame = CFrame.lookAt(hover, hover + Vector3.new(math.cos(rig.yaw), 0, math.sin(rig.yaw)))
		if #rig.limbs > 0 then
			local curl = handTargets(current, rig, now, t, charge, phase, beamAngle, handScratch)
			for index, limb in rig.limbs do
				solveLimb(rig, limb, handScratch[index], curl, dt)
			end
		end
		if #rig.chains > 0 then
			local pose = chainPose(current, now, charge, phase)
			for _, chain in rig.chains do
				solveChain(chain, pose[1], pose[2], pose[3], pose[4], t, dt)
			end
		end
	end

	-- Forming: the body is assembling out of the dark, pieces converging from afar.
	local spread = if phase == "Forming" then (1 - current.visible) ^ 2 * 70 else 0
	local outro = if phase == "Defeated" then t - current.outroStarted else 0
	local function place(piece: Piece, frame: CFrame)
		if piece.velocity ~= nil and outro > 0 then
			local drift = piece.velocity * outro + Vector3.new(0, -9 * outro * outro, 0)
			frame = CFrame.new(frame.Position + drift) * CFrame.Angles(outro * 3, outro * 2, 0) * frame.Rotation
		end
		if collapse > 0 then
			frame = CFrame.new(frame.Position:Lerp(hover, collapse)) * frame.Rotation
		end
		if spread > 0.5 then
			frame += scatterOf(piece.part) * spread
		end
		table.insert(parts, piece.part)
		table.insert(frames, frame)
		for _, child in kidsOf(piece.part) do
			table.insert(parts, child)
			table.insert(frames, frame * piece.childOffset)
		end
	end

	for _, ring in current.rings do
		local spin = CFrame.Angles(0, math.rad(ring.spin.Y * t) % TAU, 0)
		place(ring, CFrame.new(hover) * spin * ring.tilt)
	end
	local kind = current.kind
	for index, plate in current.plates do
		local angle = (index / #current.plates) * TAU + current.spinPhase
		local jolt = current.flash * 0.9
		if kind == "Choir" then
			-- Six voices standing in a ring, rising and falling in a travelling wave.
			local radius = 13.5 + jolt + charge * 2
			local lift = math.sin(t * 2.1 - index * 1.05) * 3 + current.conduct * 5
			local position = hover + Vector3.new(math.cos(angle) * radius, lift, math.sin(angle) * radius)
			place(plate, CFrame.lookAt(position, Vector3.new(hover.X, position.Y, hover.Z)) * plate.tilt)
		elseif kind == "Regent" then
			-- A crown: the plates stand up round the top of the body like points.
			local radius = 7 + jolt + charge * 2.5 + math.sin(t * 1.8 + index) * 0.25
			local lift = 8.5 + charge * 3 + (index % 2) * 2 + math.sin(t * 2.4 + index) * 0.5
			local position = hover + Vector3.new(math.cos(angle) * radius, lift, math.sin(angle) * radius)
			place(plate, CFrame.lookAt(position, Vector3.new(hover.X, position.Y, hover.Z)) * plate.tilt)
		else
			local radius = 9.5 + jolt + charge * 3.5 + math.sin(t * 1.3 + index) * 0.4
			local position = hover + Vector3.new(math.cos(angle) * radius, math.sin(t * 1.1 + index * 0.8) * 1.2, math.sin(angle) * radius)
			place(plate, CFrame.lookAt(position, hover) * plate.tilt)
		end
	end
	for index, shard in current.shards do
		local side = if index <= 4 then -1 else 1
		local k = ((index - 1) % 4) / 3
		if kind == "Choir" then
			-- Tuning blades orbiting high above, points down.
			local angle = (index / #current.shards) * TAU - t * 0.9
			local position = hover + Vector3.new(math.cos(angle) * 7, 11 + math.sin(t * 2 + index) * 0.8, math.sin(angle) * 7)
			place(shard, CFrame.new(position) * CFrame.Angles(math.pi, angle, 0))
		elseif kind == "Regent" then
			-- Wings of embers, beating slowly.
			local flap = math.sin(t * (if beamAngle ~= nil then 4 else 1.4)) * 0.22
			local offset = Vector3.new(side * (9 + k * 7), 4 - k * 3, 2 + k * 3)
			place(shard, CFrame.new(hover + offset) * CFrame.Angles(0, 0, side * (0.9 + k * 0.5 + flap)))
		else
			local sway = math.sin(t * 1.6 + index) * 0.12
			local offset = Vector3.new(side * (8 + k * 5), 3 - k * 5, 4 + k * 2) * (1 + charge * 0.25)
			local position = hover + offset
			place(shard, CFrame.new(position) * CFrame.Angles(0, 0, side * (0.5 + k * 0.4 + sway)))
		end
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
	windUp(detonateAt, detonateAt - serverNow())
	setAim("slam", center, detonateAt)
	Audio:play(bossCue("Charge"))
	local anchor = vfxPart("SlamAnchor", nil, Vector3.new(0.2, 0.2, 0.2), pal.Alert, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local fill = ringAdornment(anchor, 0.1, 0, pal.Alert, 0.85)
	local edge = ringAdornment(anchor, radius, radius - 0.9, pal.Alert, 0.35)
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
	Audio:play(bossCue("Land"))
	burst(center + Vector3.new(0, 1, 0), pal.Hot, 40, 28)
	-- A column of light where it lands, cracks across the floor, a bolt from the body.
	lightPillar(center, pal.Hot, 46, math.max(2.5, radius * 0.22), 0.7)
	groundCrack(center, radius, pal.Alert, 0.9)
	if boss ~= nil then
		boss.flash = 1
		lightning(boss.core.Position, center, pal.Hot, 0.3, 0.9)
	end
	local kind = if boss ~= nil then boss.kind else "Warden"
	if kind == "Regent" then
		-- Embers thrown up by the blow.
		Vfx.burst(center + Vector3.new(0, 1, 0), "Shatter", 34, { Color = pal.Primary, Color2 = pal.Hot, Speed = NumberRange.new(10, 26), Acceleration = Vector3.new(0, 14, 0) }, clientFolder)
	elseif kind == "Choir" then
		-- Glass shards scattering.
		Vfx.burst(center + Vector3.new(0, 1, 0), "Shatter", 30, { Color = pal.Hot, Color2 = pal.Primary, Speed = NumberRange.new(8, 20) }, clientFolder)
	end
	-- A textured shockwave across the floor, dust thrown up, and a flash.
	Vfx.burst(center + Vector3.new(0, 0.4, 0), "Shockwave", 1, { Color = pal.Hot, Size = NumberSequence.new(4, radius * 2.6) }, clientFolder)
	Vfx.burst(center, "Dust", 26, { Color = Color3.fromRGB(70, 62, 90) }, clientFolder)
	Vfx.burst(center + Vector3.new(0, 2, 0), "Flash", 1, { Color = pal.Alert, Size = NumberSequence.new(6, radius) }, clientFolder)
	local anchor = vfxPart("ShockAnchor", nil, Vector3.new(0.2, 0.2, 0.2), pal.Alert, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local wave = ringAdornment(anchor, radius, radius - 2, pal.Hot, 0.1)
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
	if boss ~= nil then
		quip(boss, boss.config.Dialogue.Hit, 8, 0.4)
	end
	local root = localRoot()
	if root ~= nil then
		Vfx.burst(root.Position, "Spark", 18, { Color = pal.Alert, Color2 = pal.Hot }, clientFolder)
	end
end

-- The boss changes phase: a pulse through the arena, a short directed shot, and the HUD banner.
local function onPhase(payload)
	local current = boss
	if current == nil then
		return
	end
	Audio:play(bossCue("Phase"))
	Ambience.fight(current.config.Music, if type(payload) == "table" then tonumber(payload.Phase) or 2 else 2)
	local at = current.anchor.Position
	Vfx.burst(at, "Flash", 1, { Color = pal.Hot, Size = NumberSequence.new(10, 30) }, clientFolder)
	Vfx.burst(at - Vector3.new(0, 24, 0), "Shockwave", 1, { Color = pal.Primary, Size = NumberSequence.new(4, 100) }, clientFolder)
	Controls.shake(0.9)
	current.flash = 1
	setAim("roar", nil, serverNow() + 1.6)
	-- The roar: a white-hot flash, bolts to every pillar, and the boss speaks.
	local phaseNumber = if type(payload) == "table" then tonumber(payload.Phase) or 2 else 2
	screenFlash(pal.Hot, 0.5, 0.9)
	lightPillar(at - Vector3.new(0, 26, 0), pal.Hot, 80, 6, 1.2)
	for index, top in pillarTops(current) do
		task.delay(0.1 * index, function()
			if boss == current then
				lightning(current.anchor.Position, top, pal.Hot, 0.4, 1)
			end
		end)
	end
	task.delay(0.4, function()
		if boss == current and near(current) then
			local lines = current.config.Dialogue[if phaseNumber >= 3 then "Phase3" else "Phase2"]
			if lines ~= nil then
				say(current.config.Name, lines[1], pal.Hot)
				if lines[2] ~= nil then
					task.delay(2.4, function()
						if boss == current then
							say(current.config.Name, lines[2], pal.Hot)
						end
					end)
				end
			end
		end
	end)
	playShot(current, { Seconds = 2.4, Sweep = -0.7, Distance = 52, Height = 12, Fov = 58 })
end

-- Shockwave rings (the Choir): every ring is drawn at once so the rhythm can be read, then
-- each one flares and expands the moment the server lands it.
local function onRings(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.25, 0)
	local count = math.clamp(math.floor(tonumber(payload.Count) or 3), 1, 8)
	local firstRadius = tonumber(payload.FirstRadius) or 16
	local gap = tonumber(payload.Gap) or 20
	local width = tonumber(payload.Width) or 5
	local step = tonumber(payload.StepSeconds) or 0.6
	local firstAt = tonumber(payload.DetonateAt) or (serverNow() + 2)
	local started = serverNow()
	windUp(firstAt, firstAt - started)
	Audio:play(bossCue("Charge"))
	local anchor = vfxPart("RingAnchor", nil, Vector3.new(0.2, 0.2, 0.2), pal.Alert, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local rings = {}
	for index = 1, count do
		local radius = firstRadius + (index - 1) * gap
		table.insert(rings, {
			at = firstAt + (index - 1) * step,
			radius = radius,
			band = ringAdornment(anchor, radius + width / 2, radius - width / 2, pal.Alert, 0.6),
		})
	end
	local finish = firstAt + (count - 1) * step + 0.8
	if boss ~= nil then
		boss.conductUntil = finish - 0.4
	end
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = serverNow()
		for _, ring in rings do
			if now < ring.at then
				-- Charging: brightens and pulses harder as its moment nears.
				local k = math.clamp(1 - (ring.at - now) / math.max(0.2, ring.at - started), 0, 1)
				ring.band.Transparency = 0.62 - 0.32 * k - 0.12 * math.abs(math.sin(now * (6 + k * 14)))
			else
				-- Landed: the band flares white-hot, widens and fades.
				local since = math.clamp((now - ring.at) / 0.6, 0, 1)
				local grow = since * 7
				ring.band.Color3 = pal.Alert:Lerp(pal.Hot, 1 - since)
				ring.band.Radius = ring.radius + width / 2 + grow
				ring.band.InnerRadius = math.max(0, ring.radius - width / 2 + grow)
				ring.band.Transparency = 0.05 + 0.95 * since
			end
		end
		if now >= finish or not active then
			if connection ~= nil then
				connection:Disconnect()
			end
			anchor:Destroy()
		end
	end)
end

local function onRingLand(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.4, 0)
	local radius = tonumber(payload.Radius) or 16
	local width = tonumber(payload.Width) or 5
	Audio:play(bossCue("Land"))
	Vfx.burst(center, "Shockwave", 1, { Color = pal.Hot, Size = NumberSequence.new(radius * 1.8, radius * 2.5 + 6) }, clientFolder)
	local root = localRoot()
	if root ~= nil then
		local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		if math.abs(offset.Magnitude - radius) < width + 10 then
			Controls.shake(0.55)
		end
	end
end

-- A sweeping beam (the Regent): a stepped wedge from the boss to `Range`, drawn from the
-- same angle the server tests, so the danger on screen is the danger that hurts.
local BEAM_SEGMENTS = 8

local function onSweep(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.5, 0)
	local startAngle = tonumber(payload.StartAngle) or 0
	local speed = tonumber(payload.Speed) or 1
	local halfWidth = math.clamp(tonumber(payload.HalfWidth) or 0.17, 0.02, 0.6)
	local range = tonumber(payload.Range) or 80
	local beginAt = tonumber(payload.BeginAt) or (serverNow() + 1.5)
	local endAt = tonumber(payload.EndAt) or (beginAt + 5)
	if boss ~= nil then
		boss.beam = { begin = beginAt, endAt = endAt, start = startAngle, speed = speed }
	end
	windUp(beginAt, beginAt - serverNow())
	setAim("sweep", nil, endAt)
	Audio:play(bossCue("Charge"))
	local segments = {}
	for index = 1, BEAM_SEGMENTS do
		local near = (index - 1) / BEAM_SEGMENTS * range
		local far = index / BEAM_SEGMENTS * range
		local part = vfxPart("SweepBeam", nil, Vector3.new(far - near + 0.2, 0.3, 0.4), pal.Alert, Enum.Material.Neon)
		part.Transparency = 0.9
		table.insert(segments, { part = part, mid = (near + far) / 2, length = far - near + 0.2, width = 2 * far * math.tan(halfWidth) })
	end
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = serverNow()
		local angle = startAngle + speed * math.clamp(now - beginAt, 0, endAt - beginAt)
		local cosine, sine = math.cos(angle), math.sin(angle)
		local live = math.clamp((now - beginAt) / 0.2, 0, 1)
		local fade = math.clamp((endAt - now) / 0.35, 0, 1)
		for _, segment in segments do
			local part = segment.part
			-- Before it fires the beam is a thin aim line; it then opens to full width.
			part.Size = Vector3.new(segment.length, 0.3, math.max(0.4, segment.width * live * live))
			part.CFrame = CFrame.new(center + Vector3.new(cosine * segment.mid, 0, sine * segment.mid)) * CFrame.Angles(0, -angle, 0)
			if now < beginAt then
				part.Transparency = 0.86 - 0.1 * math.abs(math.sin(now * 12))
			else
				part.Transparency = 1 - (0.62 - 0.12 * math.abs(math.sin(now * 30))) * fade
			end
		end
		if now >= endAt + 0.05 or not active then
			if connection ~= nil then
				connection:Disconnect()
			end
			for _, segment in segments do
				segment.part:Destroy()
			end
		end
	end)
end
-- A stepped wedge of neon from the boss out to `range`, drawn from the angle the server
-- tests, so the danger on screen is the danger that hurts.
local function newBeam(center: Vector3, halfWidth: number, range: number)
	local segments = {}
	for index = 1, BEAM_SEGMENTS do
		local near = (index - 1) / BEAM_SEGMENTS * range
		local far = index / BEAM_SEGMENTS * range
		local part = vfxPart("Beam", nil, Vector3.new(far - near + 0.2, 0.3, 0.4), pal.Alert, Enum.Material.Neon)
		part.Transparency = 1
		table.insert(segments, { part = part, mid = (near + far) / 2, length = far - near + 0.2, width = 2 * far * math.tan(halfWidth) })
	end
	return {
		place = function(angle: number, live: number, transparency: number)
			local cosine, sine = math.cos(angle), math.sin(angle)
			for _, segment in segments do
				segment.part.Size = Vector3.new(segment.length, 0.3, math.max(0.4, segment.width * live))
				segment.part.CFrame = CFrame.new(center + Vector3.new(cosine * segment.mid, 0, sine * segment.mid)) * CFrame.Angles(0, -angle, 0)
				segment.part.Transparency = transparency
			end
		end,
		destroy = function()
			for _, segment in segments do
				segment.part:Destroy()
			end
		end,
	}
end

-- Every attack announces itself: the body flares and, now and then, the boss speaks.
local function onAttack(payload)
	local current = boss
	if current == nil or type(payload) ~= "table" then
		return
	end
	current.flash = math.max(current.flash, 0.7)
	quip(current, current.config.Dialogue.Attack[tostring(payload.Attack)], 9, 0.7)
end

-- Lances (the Warden): thin aim lines from the body, then every beam fires at once.
local function onLances(payload)
	if type(payload) ~= "table" or type(payload.Angles) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.5, 0)
	local halfWidth = math.clamp(tonumber(payload.HalfWidth) or 0.075, 0.02, 0.6)
	local range = tonumber(payload.Range) or 90
	local fireAt = tonumber(payload.FireAt) or (serverNow() + 1.5)
	local started = serverNow()
	windUp(fireAt, fireAt - started)
	setAim("thrust", nil, fireAt)
	Audio:play(bossCue("Charge"))
	local beams = {}
	for _, angle in payload.Angles do
		table.insert(beams, { angle = tonumber(angle) or 0, beam = newBeam(center, halfWidth, range) })
	end
	local fired = false
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = serverNow()
		if now < fireAt then
			local k = math.clamp((now - started) / math.max(0.2, fireAt - started), 0, 1)
			for _, entry in beams do
				entry.beam.place(entry.angle, 0.04 + 0.05 * k, 0.88 - 0.3 * k * math.abs(math.sin(now * (8 + k * 18))))
			end
			return
		end
		local since = now - fireAt
		if not fired then
			fired = true
			Audio:play(bossCue("Land"))
			Controls.shake(0.8)
			screenFlash(pal.Hot, 0.25, 0.4)
			local origin = if boss ~= nil then boss.core.Position else center + Vector3.new(0, 24, 0)
			for _, entry in beams do
				local tip = center + Vector3.new(math.cos(entry.angle) * range, 0, math.sin(entry.angle) * range)
				lightning(origin, tip, pal.Hot, 0.35, 1.1)
				Vfx.burst(tip, "Flash", 1, { Color = pal.Hot, Size = NumberSequence.new(6, 22) }, clientFolder)
			end
		end
		local fade = math.clamp(1 - since / 0.45, 0, 1)
		for _, entry in beams do
			entry.beam.place(entry.angle, math.min(1, 0.1 + since / 0.06), 1 - 0.75 * fade)
		end
		if since > 0.5 or not active then
			if connection ~= nil then
				connection:Disconnect()
			end
			for _, entry in beams do
				entry.beam.destroy()
			end
		end
	end)
end

-- Gravity well (the Warden): a vortex opens, the local player is dragged toward it while it
-- lasts, and the server's core detonation (a slam landing) ends it.
local function onWell(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.3, 0)
	local radius = tonumber(payload.Radius) or 30
	local core = tonumber(payload.Core) or 15
	local strength = tonumber(payload.Strength) or 34
	local pullFrom = tonumber(payload.PullFrom) or serverNow()
	local detonateAt = tonumber(payload.DetonateAt) or (serverNow() + 3)
	local started = serverNow()
	windUp(detonateAt, detonateAt - started)
	setAim("pull", center, detonateAt)
	Audio:play(bossCue("Charge"))
	local anchor = vfxPart("WellAnchor", nil, Vector3.new(0.2, 0.2, 0.2), pal.Alert, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	Vfx.attach(anchor, "Swirl", { Color = pal.Primary, Color2 = pal.Alert, Size = NumberSequence.new(radius * 1.4, radius * 1.8) })
	local heart = vfxPart("WellCore", Enum.PartType.Ball, Vector3.new(2, 2, 2), pal.Primary, Enum.Material.Neon)
	heart.CFrame = CFrame.new(center + Vector3.new(0, 2, 0))
	heart.Transparency = 0.15
	local marker = ringAdornment(anchor, core, core - 0.8, pal.Alert, 0.3)
	local rings = {}
	for index = 1, 3 do
		rings[index] = ringAdornment(anchor, radius, radius - 1, pal.Hot, 0.5)
	end
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt)
		local now = serverNow()
		local k = math.clamp((now - started) / math.max(0.3, detonateAt - started), 0, 1)
		heart.Size = Vector3.new(1, 1, 1) * (2 + core * 0.6 * k)
		for index, ring in rings do
			local phase = (now * 0.9 + index / 3) % 1
			local r = math.max(1.5, radius * (1 - phase))
			ring.Radius = r
			ring.InnerRadius = math.max(0, r - 1.2)
			ring.Transparency = 1 - 0.7 * phase
		end
		marker.Transparency = 0.45 - 0.25 * math.abs(math.sin(k * math.pi * 8))
		if now >= pullFrom and now < detonateAt then
			local root = localRoot()
			if root ~= nil then
				local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
				if flat < radius * 1.8 then
					Controls.pull(center, strength, dt)
				end
			end
			Controls.shake(0.15 + 0.25 * k)
		end
		if now >= detonateAt + 0.05 or not active then
			if connection ~= nil then
				connection:Disconnect()
			end
			heart:Destroy()
			anchor:Destroy()
		end
	end)
end

-- Dissonance (the Choir): the whole floor is marked to hurt except a few bright pockets.
local function onDissonance(payload)
	if type(payload) ~= "table" or type(payload.Zones) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.2, 0)
	local arenaRadius = tonumber(payload.ArenaRadius) or 74
	local zoneRadius = tonumber(payload.ZoneRadius) or 13
	local detonateAt = tonumber(payload.DetonateAt) or (serverNow() + 2.5)
	local started = serverNow()
	windUp(detonateAt, detonateAt - started)
	setAim("roar", nil, detonateAt)
	Audio:play(bossCue("Charge"))
	local anchor = vfxPart("DissonanceAnchor", nil, Vector3.new(0.2, 0.2, 0.2), pal.Alert, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local floorFill = ringAdornment(anchor, arenaRadius, 0, pal.Alert, 0.82)
	local floorEdge = ringAdornment(anchor, arenaRadius, arenaRadius - 1.2, pal.Alert, 0.3)
	local pockets = {}
	for _, zone in payload.Zones do
		local at = Vector3.new(tonumber(zone.X) or center.X, center.Y + 0.1, tonumber(zone.Z) or center.Z)
		local spot = vfxPart("Pocket", nil, Vector3.new(0.2, 0.2, 0.2), pal.Hot, Enum.Material.SmoothPlastic)
		spot.Transparency = 1
		spot.CFrame = CFrame.new(at)
		local fill = ringAdornment(spot, zoneRadius, 0, pal.Hot, 0.35)
		fill.ZIndex = 3
		local rim = ringAdornment(spot, zoneRadius, zoneRadius - 0.9, Color3.new(1, 1, 1), 0.1)
		rim.ZIndex = 4
		-- A column of light over each pocket so it can be found from across the hall.
		local beacon = vfxPart("PocketLight", Enum.PartType.Cylinder, Vector3.new(30, zoneRadius * 0.5, zoneRadius * 0.5), pal.Hot, Enum.Material.Neon)
		beacon.CFrame = CFrame.new(at + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beacon.Transparency = 0.75
		table.insert(pockets, { spot = spot, rim = rim, fill = fill, beacon = beacon })
	end
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = serverNow()
		local k = math.clamp((now - started) / math.max(0.3, detonateAt - started), 0, 1)
		floorFill.Transparency = 0.82 - 0.22 * k - 0.1 * math.abs(math.sin(now * (4 + k * 20)))
		floorEdge.Transparency = 0.35 - 0.25 * math.abs(math.sin(now * 6))
		for _, pocket in pockets do
			pocket.rim.Transparency = 0.1 + 0.25 * math.abs(math.sin(now * 5))
			pocket.fill.Transparency = 0.4 - 0.15 * k
			pocket.beacon.Transparency = 0.78 - 0.2 * math.abs(math.sin(now * 3))
		end
		if now >= detonateAt + 0.8 or not active then
			if connection ~= nil then
				connection:Disconnect()
			end
			for _, pocket in pockets do
				pocket.beacon:Destroy()
				pocket.spot:Destroy()
			end
			anchor:Destroy()
		end
	end)
end

local function onDissonanceLand(payload)
	local center = worldPoint(type(payload) == "table" and payload.Center or nil)
	Audio:play(bossCue("Land"))
	screenFlash(pal.Alert, 0.55, 0.7)
	Controls.shake(1.1)
	groundCrack(center, 70, pal.Alert, 1.2)
	Vfx.burst(center + Vector3.new(0, 0.5, 0), "Shockwave", 1, { Color = pal.Hot, Size = NumberSequence.new(10, 190) }, clientFolder)
	Vfx.burst(center + Vector3.new(0, 2, 0), "Flash", 1, { Color = pal.Hot, Size = NumberSequence.new(10, 60) }, clientFolder)
	if boss ~= nil then
		boss.flash = 1
		lightning(boss.core.Position, center, pal.Hot, 0.4, 1.4)
	end
end

-- Inferno wall (the Regent): a wall of flame crosses the arena with a marked gap.
local function onWall(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.2, 0)
	local angle = tonumber(payload.Angle) or 0
	local speed = tonumber(payload.Speed) or 24
	local half = tonumber(payload.Half) or 3
	local range = tonumber(payload.Range) or 84
	local gapCenter = tonumber(payload.GapCenter) or 0
	local gapHalf = tonumber(payload.GapHalf) or 9
	local beginAt = tonumber(payload.BeginAt) or (serverNow() + 2)
	local endAt = tonumber(payload.EndAt) or (beginAt + range * 2 / speed)
	windUp(beginAt, beginAt - serverNow())
	setAim("floor", nil, beginAt + 0.6)
	Audio:play(bossCue("Charge"))
	local slabs = {}
	local function addSlab(from: number, to: number)
		if to - from < 1 then
			return
		end
		local part = vfxPart("FlameWall", nil, Vector3.new(half * 2, 9, to - from), pal.Alert, Enum.Material.Neon)
		part.Transparency = 1
		local flame = Instance.new("Fire")
		flame.Color = pal.Primary
		flame.SecondaryColor = pal.Hot
		flame.Size = 14
		flame.Heat = 16
		flame.Enabled = false
		flame.Parent = part
		table.insert(slabs, { part = part, flame = flame, across = (from + to) / 2 })
	end
	addSlab(-range, gapCenter - gapHalf)
	addSlab(gapCenter + gapHalf, range)
	local posts = {}
	for _, side in { -1, 1 } do
		local post = vfxPart("GapPost", nil, Vector3.new(0.7, 14, 0.7), pal.Hot, Enum.Material.Neon)
		post.Transparency = 0.2
		table.insert(posts, { part = post, across = gapCenter + side * gapHalf })
	end
	local cosine, sine = math.cos(angle), math.sin(angle)
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = serverNow()
		local along = -range + speed * math.clamp(now - beginAt, 0, endAt - beginAt)
		local lit = now >= beginAt
		local base = center + Vector3.new(cosine * along, 0, sine * along)
		local rotation = CFrame.Angles(0, -angle, 0)
		for _, slab in slabs do
			local at = base + Vector3.new(-sine * slab.across, 4.5, cosine * slab.across)
			slab.part.CFrame = CFrame.new(at) * rotation
			slab.part.Transparency = if lit then 0.45 - 0.1 * math.sin(now * 14) else 0.9 - 0.15 * math.abs(math.sin(now * 9))
			slab.flame.Enabled = lit
		end
		for _, post in posts do
			post.part.CFrame = CFrame.new(base + Vector3.new(-sine * post.across, 7, cosine * post.across))
			post.part.Transparency = 0.15 + 0.2 * math.abs(math.sin(now * 6))
		end
		if lit then
			Controls.shake(0.12)
		end
		if now >= endAt + 0.3 or not active then
			if connection ~= nil then
				connection:Disconnect()
			end
			for _, slab in slabs do
				slab.part:Destroy()
			end
			for _, post in posts do
				post.part:Destroy()
			end
		end
	end)
end

-- The player's own blows: a bright arc thrown toward the boss and the sword arm swinging.
local function slashArc(root: BasePart, toward: Vector3, color: Color3)
	local flat = Vector3.new(toward.X - root.Position.X, 0, toward.Z - root.Position.Z)
	local forward = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	local origin = root.Position + Vector3.new(0, 0.6, 0)
	local facing = CFrame.lookAt(Vector3.zero, forward)
	for index = 1, 7 do
		local sweep = (index / 7 - 0.5) * math.pi * 0.95
		local direction = (facing * CFrame.Angles(0, -sweep, 0)).LookVector
		local at = origin + direction * 3.6 + Vector3.new(0, 1.6 - index * 0.08, 0)
		local blade = vfxPart("Slash", nil, Vector3.new(0.35, 0.35, 2.4), color, Enum.Material.Neon)
		blade.CFrame = CFrame.lookAt(at, at + direction:Cross(Vector3.yAxis))
		blade.Transparency = 0.1
		TweenService:Create(blade, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 3.2) }):Play()
		Debris:AddItem(blade, 0.3)
	end
end

local swinging = false
local function swingArm()
	if swinging then
		return
	end
	local character = Players.LocalPlayer.Character
	local shoulder = character and character:FindFirstChild("RightShoulder", true)
	if shoulder == nil or not shoulder:IsA("Motor6D") then
		return
	end
	swinging = true
	local base = shoulder.C0
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - started) / 0.22
		if k >= 1 or shoulder.Parent == nil or not active then
			shoulder.C0 = base
			swinging = false
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		shoulder.C0 = base * CFrame.Angles(-math.sin(k * math.pi) * math.rad(110), 0, 0)
	end)
end
-- The local player's strike landed (the HUD fires this with the result):
-- sparks off the Warden, and a flash on a critical hit.
local function onStrikeLanded(payload)
	local current = boss
	if current == nil then
		return
	end
	local crit = type(payload) == "table" and payload.Crit == true
	local striker = localRoot()
	if striker ~= nil then
		slashArc(striker, current.core.Position, if crit then Color3.fromRGB(255, 226, 150) else pal.Hot)
		swingArm()
	end
	local root = localRoot()
	local at = current.core.Position
	if root ~= nil then
		-- The side of the Warden facing the player.
		local toward = root.Position - at
		if toward.Magnitude > 1 then
			at += toward.Unit * current.core.Size.X * 0.5
		end
	end
	Vfx.burst(at, "Spark", if crit then 34 else 16, { Color = pal.Hot, Color2 = if crit then Color3.fromRGB(255, 214, 120) else pal.Primary }, clientFolder)
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
	table.insert(unsubscribers, Signals.on("RiftBossPhase", onPhase))
	table.insert(unsubscribers, Signals.on("RiftBossRings", onRings))
	table.insert(unsubscribers, Signals.on("RiftBossRingLand", onRingLand))
	table.insert(unsubscribers, Signals.on("RiftBossSweep", onSweep))
	table.insert(unsubscribers, Signals.on("RiftBossAttack", onAttack))
	table.insert(unsubscribers, Signals.on("RiftBossLances", onLances))
	table.insert(unsubscribers, Signals.on("RiftBossWell", onWell))
	table.insert(unsubscribers, Signals.on("RiftBossDissonance", onDissonance))
	table.insert(unsubscribers, Signals.on("RiftBossDissonanceLand", onDissonanceLand))
	table.insert(unsubscribers, Signals.on("RiftBossWall", onWall))
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
			bossRetryAt = os.clock() + 5
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
	clearCinema()
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
-- Module: sanctuaryPresence   (merged from sanctuaryPresence.luau, 614 lines)
-- ======================================================================
__defs["sanctuaryPresence"] = function()
-- Walkable rift behind the shell. The idle UI stays on a scriptable camera.
-- PlayerModule is not under PlayerScripts; sanctuaryControls moves the avatar
-- and runs the follow camera on every device, and sanctuaryWorld animates the
-- world. Leave restores the forge camera and lighting, and the server
-- destroys the sanctuary character.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- One RaycastParams for the life of the module: its filter only changes when the
-- character does. Building a fresh params object (and filter table) every frame
-- allocated needlessly on the camera path.
local cameraParams = RaycastParams.new()
cameraParams.FilterType = Enum.RaycastFilterType.Exclude
local cameraFilterCharacter: Model? = nil
local function cameraRayParams(): RaycastParams
	local character = Players.LocalPlayer.Character
	if character ~= cameraFilterCharacter then
		cameraFilterCharacter = character
		cameraParams.FilterDescendantsInstances = if character ~= nil then { character } else {}
	end
	return cameraParams
end

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controls = __load("sanctuaryControls")
local Curtain = __load("curtainTransition")
local World = __load("sanctuaryWorld")
local Signals = __load("sanctuarySignals")
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

-- Region moods. The base night (Bridge) is what the sanctuary always used; each region
-- tints the haze, fog, ambient light and grade toward its own palette as you cross into
-- it, eased rather than cut. Fields are numbers and Color3s only, so blending is one
-- lerp per field.
type Mood = {
	ambient: Color3,
	outdoor: Color3,
	fog: Color3,
	exposure: number,
	hazeColor: Color3,
	hazeDecay: Color3,
	density: number,
	haze: number,
	bloom: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	rays: number,
}
local MOODS: { [string]: Mood } = {
	Bridge = {
		ambient = Color3.fromRGB(92, 92, 128), outdoor = Color3.fromRGB(122, 116, 168), fog = Color3.fromRGB(14, 12, 30), exposure = 0.3,
		hazeColor = Color3.fromRGB(48, 40, 94), hazeDecay = Color3.fromRGB(18, 14, 40), density = 0.2, haze = 0.8,
		bloom = 0.6, tint = Color3.fromRGB(238, 236, 255), saturation = 0.14, contrast = 0.1, rays = 0.04,
	},
	Heart = {
		ambient = Color3.fromRGB(100, 92, 126), outdoor = Color3.fromRGB(132, 118, 164), fog = Color3.fromRGB(18, 14, 30), exposure = 0.32,
		hazeColor = Color3.fromRGB(60, 44, 96), hazeDecay = Color3.fromRGB(24, 16, 42), density = 0.2, haze = 0.8,
		bloom = 0.7, tint = Color3.fromRGB(246, 238, 255), saturation = 0.16, contrast = 0.1, rays = 0.05,
	},
	Emberreach = {
		ambient = Color3.fromRGB(122, 82, 70), outdoor = Color3.fromRGB(156, 102, 86), fog = Color3.fromRGB(36, 14, 10), exposure = 0.36,
		hazeColor = Color3.fromRGB(118, 54, 36), hazeDecay = Color3.fromRGB(62, 22, 14), density = 0.27, haze = 1.25,
		bloom = 0.95, tint = Color3.fromRGB(255, 232, 212), saturation = 0.22, contrast = 0.12, rays = 0.08,
	},
	Hollows = {
		ambient = Color3.fromRGB(84, 110, 142), outdoor = Color3.fromRGB(112, 142, 184), fog = Color3.fromRGB(10, 22, 36), exposure = 0.3,
		hazeColor = Color3.fromRGB(40, 92, 126), hazeDecay = Color3.fromRGB(10, 32, 54), density = 0.22, haze = 0.95,
		bloom = 0.8, tint = Color3.fromRGB(220, 240, 255), saturation = 0.12, contrast = 0.12, rays = 0.05,
	},
	Spire = {
		ambient = Color3.fromRGB(112, 112, 152), outdoor = Color3.fromRGB(152, 150, 202), fog = Color3.fromRGB(32, 32, 58), exposure = 0.42,
		hazeColor = Color3.fromRGB(150, 150, 192), hazeDecay = Color3.fromRGB(70, 70, 112), density = 0.12, haze = 0.4,
		bloom = 0.62, tint = Color3.fromRGB(248, 246, 255), saturation = 0.1, contrast = 0.08, rays = 0.13,
	},
	Riftmaw = {
		ambient = Color3.fromRGB(92, 70, 112), outdoor = Color3.fromRGB(114, 86, 140), fog = Color3.fromRGB(22, 6, 24), exposure = 0.2,
		hazeColor = Color3.fromRGB(88, 30, 86), hazeDecay = Color3.fromRGB(32, 8, 32), density = 0.3, haze = 1.4,
		bloom = 1.0, tint = Color3.fromRGB(255, 226, 250), saturation = 0.18, contrast = 0.15, rays = 0.02,
	},
	-- The Hall of the Hollow Choir: cold and glassy, bright haze like light through ice.
	ChoirIsle = {
		ambient = Color3.fromRGB(86, 122, 158), outdoor = Color3.fromRGB(120, 168, 214), fog = Color3.fromRGB(8, 26, 44), exposure = 0.36,
		hazeColor = Color3.fromRGB(56, 140, 190), hazeDecay = Color3.fromRGB(14, 52, 84), density = 0.2, haze = 0.8,
		bloom = 1.1, tint = Color3.fromRGB(214, 244, 255), saturation = 0.2, contrast = 0.14, rays = 0.12,
	},
	-- The Cinderthrone: low red light, thick smoky haze, heavy bloom off the flames.
	RegentIsle = {
		ambient = Color3.fromRGB(136, 78, 58), outdoor = Color3.fromRGB(176, 98, 70), fog = Color3.fromRGB(42, 12, 8), exposure = 0.3,
		hazeColor = Color3.fromRGB(150, 56, 30), hazeDecay = Color3.fromRGB(72, 20, 10), density = 0.32, haze = 1.5,
		bloom = 1.15, tint = Color3.fromRGB(255, 220, 196), saturation = 0.26, contrast = 0.16, rays = 0.04,
	},
}
local MOOD_TAU = 1.4 -- seconds for a region change to cover ~63% of the way
local MOOD_SETTLE_SECONDS = 7 -- stop blending this long after the last change (5 tau)
local moodNow: Mood = table.clone(MOODS.Bridge)
local moodTarget: Mood = MOODS.Bridge
local moodUntil = 0
local moodConnection: RBXScriptConnection? = nil
local moodRegionSub: (() -> ())? = nil

local function blendMood(alpha: number)
	local now, target = moodNow, moodTarget
	now.ambient = now.ambient:Lerp(target.ambient, alpha)
	now.outdoor = now.outdoor:Lerp(target.outdoor, alpha)
	now.fog = now.fog:Lerp(target.fog, alpha)
	now.hazeColor = now.hazeColor:Lerp(target.hazeColor, alpha)
	now.hazeDecay = now.hazeDecay:Lerp(target.hazeDecay, alpha)
	now.tint = now.tint:Lerp(target.tint, alpha)
	now.exposure += (target.exposure - now.exposure) * alpha
	now.density += (target.density - now.density) * alpha
	now.haze += (target.haze - now.haze) * alpha
	now.bloom += (target.bloom - now.bloom) * alpha
	now.saturation += (target.saturation - now.saturation) * alpha
	now.contrast += (target.contrast - now.contrast) * alpha
	now.rays += (target.rays - now.rays) * alpha
end

local function writeMood()
	local m = moodNow
	Lighting.Ambient = m.ambient
	Lighting.OutdoorAmbient = m.outdoor
	Lighting.FogColor = m.fog
	Lighting.ExposureCompensation = m.exposure
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere ~= nil then
		atmosphere.Color = m.hazeColor
		atmosphere.Decay = m.hazeDecay
		atmosphere.Density = m.density
		atmosphere.Haze = m.haze
	end
	local bloom = Lighting:FindFirstChild(EFFECT_NAMES[1])
	if bloom ~= nil and bloom:IsA("BloomEffect") then
		bloom.Intensity = m.bloom
	end
	local grade = Lighting:FindFirstChild(EFFECT_NAMES[2])
	if grade ~= nil and grade:IsA("ColorCorrectionEffect") then
		grade.TintColor = m.tint
		grade.Saturation = m.saturation
		grade.Contrast = m.contrast
	end
	local rays = Lighting:FindFirstChild(EFFECT_NAMES[3])
	if rays ~= nil and rays:IsA("SunRaysEffect") then
		rays.Intensity = m.rays
	end
end

local function stopMood()
	if moodConnection ~= nil then
		moodConnection:Disconnect()
		moodConnection = nil
	end
	if moodRegionSub ~= nil then
		moodRegionSub()
		moodRegionSub = nil
	end
end

-- Runs only while the sanctuary lighting is held, and only does work for a few seconds
-- after a region change (the blend converges; a settled mood costs nothing per frame).
local function startMood()
	stopMood()
	moodNow = table.clone(MOODS.Bridge)
	moodTarget = MOODS.Bridge
	moodUntil = 0
	moodRegionSub = Signals.on("RegionChanged", function(payload)
		local id = if type(payload) == "table" then payload.Id else nil
		moodTarget = MOODS[id :: any] or MOODS.Bridge
		moodUntil = os.clock() + MOOD_SETTLE_SECONDS
	end)
	moodConnection = RunService.Heartbeat:Connect(function(dt)
		if os.clock() > moodUntil then
			return
		end
		blendMood(1 - math.exp(-dt / MOOD_TAU))
		writeMood()
	end)
end

local function applySanctuaryLighting()	if not lightingHeld then
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
	startMood()
end

local function restoreLighting()
	stopMood()
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
	local params = cameraRayParams()
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
