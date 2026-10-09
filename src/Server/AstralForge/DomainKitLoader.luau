--!strict
-- Purpose: load the Domain lattice gem kit once and publish its MeshParts for clients.
-- Owner: asset pipeline. Dependencies: InsertService, Shared/DomainKit. Review: 2026-10-08.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = {}

function Loader.load(): boolean
	if ReplicatedStorage:FindFirstChild("DomainKit") then
		return true
	end
	local shared = ReplicatedStorage:FindFirstChild("AstralForge")
	local folder = shared and shared:FindFirstChild("Shared")
	local manifest = folder and folder:FindFirstChild("DomainKit")
	if not manifest or not manifest:IsA("ModuleScript") then
		return false
	end
	local kit = require(manifest) :: any
	if type(kit.Id) ~= "number" or kit.Id <= 0 then
		return false
	end
	local asset: Instance? = nil
	for attempt = 1, 3 do
		local loaded, result = pcall(function(): Instance
			return InsertService:LoadAsset(kit.Id)
		end)
		if loaded then
			asset = result
			break
		end
		task.wait(2 * attempt)
	end
	if asset == nil then
		-- non-fatal: the lattice keeps its procedural glass orbs
		warn("Domain gem kit could not load; the lattice keeps its procedural orbs.")
		return false
	end
	local pending = Instance.new("Folder")
	pending.Name = "DomainKit"
	for _, item in asset:GetDescendants() do
		if item:IsA("MeshPart") and string.sub(item.Name, 1, 7) == "Domain_" and not pending:FindFirstChild(item.Name) then
			local copy = item:Clone()
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.CFrame = CFrame.new()
			copy.Parent = pending
		end
	end
	asset:Destroy()
	pending:SetAttribute("AssetId", kit.Id)
	pending.Parent = ReplicatedStorage
	return true
end

return table.freeze(Loader)
