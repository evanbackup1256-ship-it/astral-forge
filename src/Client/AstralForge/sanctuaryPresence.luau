--!strict
-- Walkable rift behind the shell. The idle UI stays on a scriptable camera.
-- PlayerModule is not under PlayerScripts; this script moves the avatar with
-- WASD and a Scriptable follow camera. Leave restores the forge camera and
-- the server destroys the sanctuary character.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
}

local DECK_RADIUS = 48

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
		}
		lightingHeld = true
	end
	Lighting.Brightness = 2.15
	Lighting.Ambient = Color3.fromRGB(46, 60, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(32, 44, 60)
	Lighting.FogColor = Color3.fromRGB(5, 7, 12)
	Lighting.FogStart = 70
	Lighting.FogEnd = 280
	Lighting.ClockTime = 18.6
end

local function restoreLighting()
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
	local player = Players.LocalPlayer
	cameraGuard = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		if walking then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid == nil or root == nil or not root:IsA("BasePart") then
				return
			end
			-- Scripted WASD. The follow camera stays Scriptable on the deck.
			local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
			if flatLook.Magnitude < 0.05 then
				flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			end
			if flatLook.Magnitude < 0.05 then
				flatLook = Vector3.new(0, 0, -1)
			end
			flatLook = flatLook.Unit
			local flatRight = Vector3.new(flatLook.Z, 0, -flatLook.X)
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
				move += flatLook
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
				move -= flatLook
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
				move -= flatRight
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
				move += flatRight
			end
			if move.Magnitude > 0.05 then
				humanoid:Move(move.Unit, false)
			else
				humanoid:Move(Vector3.zero, false)
			end
			local focus = root.Position + Vector3.new(0, 2.5, 0)
			local eye = focus - flatLook * 16 + Vector3.new(0, 7, 0)
			local aim = clearCamera(eye, focus)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CameraSubject = nil
			camera.CFrame = aim
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

local function seedDeckCamera(root: BasePart)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end
	local focus = root.Position + Vector3.new(0, 2.5, 0)
	local eye = focus - flatLook * 16 + Vector3.new(0, 7, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	camera.CFrame = clearCamera(eye, focus)
end

local function followAvatar(humanoid: Humanoid)
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
	local character = humanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		seedDeckCamera(root)
	end
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
					if not walking and rootOnDeck(liveRoot) then
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
