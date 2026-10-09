--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts", 5)

local function mute(instance: Instance?)
	if instance == nil then
		return
	end
	if instance:IsA("BaseScript") then
		(instance :: BaseScript).Disabled = true
	end
	for _, child in instance:GetChildren() do
		mute(child)
	end
end

if playerScripts then
	mute(playerScripts:FindFirstChild("PlayerModule"))
	mute(playerScripts:FindFirstChild("RbxCharacterSounds"))
else
	warn("[PlayerScriptsLoader] PlayerScripts not found within timeout; default controls/sounds may remain active.")
end

local function configureCamera(camera: Camera?)
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
end

configureCamera(Workspace.CurrentCamera)
local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	configureCamera(Workspace.CurrentCamera)
end)

player.Destroying:Once(function()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
end)
