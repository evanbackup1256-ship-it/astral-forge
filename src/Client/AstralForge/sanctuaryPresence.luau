--!strict
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

local Controls = require(script.Parent.sanctuaryControls)
local Curtain = require(script.Parent.curtainTransition)
local World = require(script.Parent.sanctuaryWorld)
local SanctuaryLayout = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SanctuaryLayout"))

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
export type EntryHandle = { token: number?, cancelled: boolean, job: thread? }

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
