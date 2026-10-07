--!strict
-- Purpose: validate a complete Blender crate kit before exposing it to clients.
-- Owner: asset pipeline. Dependencies: InsertService and CrateKit asset manifest.
-- Review: 2026-10-05.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = {}
type KitManifest = { Id: number, Skins: { string }, TextureOverrides: { [string]: number }? }

function Loader.load(): boolean
	local shared = ReplicatedStorage:FindFirstChild("AstralForge")
	local folder = shared and shared:FindFirstChild("Shared")
	local manifest = folder and folder:FindFirstChild("CrateKit")
	if not manifest or not manifest:IsA("ModuleScript") then
		return false
	end
	local kit: KitManifest = require(manifest)
	if type(kit.Id) ~= "number" or kit.Id <= 0 then
		return false
	end
	if ReplicatedStorage:FindFirstChild("CrateKit") then
		return true
	end
	local loaded, asset = pcall(function(): Model
		return InsertService:LoadAsset(kit.Id)
	end)
	if not loaded then
		warn("Crate model kit could not load; keeping the existing kit.")
		return false
	end
	local pending = Instance.new("Folder")
	pending.Name = "CrateKit"
	for _, item in asset:GetDescendants() do
		if item:IsA("MeshPart") and string.sub(item.Name, 1, 6) == "Crate_" then
			if pending:FindFirstChild(item.Name) then
				pending:Destroy()
				asset:Destroy()
				return false
			end
			local copy = item:Clone()
			local replacement = kit.TextureOverrides and kit.TextureOverrides[item.Name]
			if replacement and replacement > 0 then
				copy.TextureID = "rbxassetid://" .. tostring(replacement)
				local surface = copy:FindFirstChildWhichIsA("SurfaceAppearance")
				if surface then
					surface.ColorMap = copy.TextureID
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CFrame = CFrame.new()
			copy.Parent = pending
		end
	end
	asset:Destroy()
	for _, skinId in kit.Skins do
		for _, piece in { "Body", "Lid" } do
			if not pending:FindFirstChild("Crate_" .. skinId .. "_" .. piece) then
				pending:Destroy()
				warn("Crate model kit is incomplete; keeping the existing kit.")
				return false
			end
		end
	end
	pending:SetAttribute("AssetId", kit.Id)
	pending.Parent = ReplicatedStorage
	return true
end

return table.freeze(Loader)
