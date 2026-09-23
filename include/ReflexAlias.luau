--!strict

-- This alias is only valid when it sits inside the Reflex package module.
-- In this place rbxts_include is a Folder, so fall through to Packages.Reflex.
local root = script.Parent
if root:IsA("ModuleScript") then
	return require(root)
end

local packages = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
local reflex = packages and packages:FindFirstChild("Reflex")
if reflex and reflex:IsA("ModuleScript") then
	return require(reflex)
end

return {}
