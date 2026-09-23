--!strict
-- Replaces Roblox's default PlayerScriptsLoader so PlayerModule never starts.
-- This game is UI-only: no character camera, popper raycasts, or movement controls.

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
end

local camera = Workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
end
