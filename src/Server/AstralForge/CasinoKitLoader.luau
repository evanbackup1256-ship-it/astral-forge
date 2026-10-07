--!strict

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLog = require(script.Parent:WaitForChild("ModuleLog"))

local CasinoKitLoader = {}

function CasinoKitLoader.load()
	task.spawn(function()
		require(script.Parent.CrateKitLoader).load()
	end)
	if ReplicatedStorage:FindFirstChild("CasinoKit") ~= nil then
		return
	end
	local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
	local kit = require(shared:WaitForChild("CasinoKit")) :: any
	local id = kit.Id
	if type(id) ~= "number" or id <= 0 then
		return
	end
	local ok, result = false, nil :: any
	for attempt = 1, 4 do
		ok, result = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok and typeof(result) == "Instance" then
			break
		end
		task.wait(2 * attempt)
	end
	if not ok or typeof(result) ~= "Instance" then
		ModuleLog.Warn("Casino", `couldn't load the casino kit {id}: {result}. The game owner must own the asset.`)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CasinoKit"
	for _, item in result:GetDescendants() do
		local kitPart = string.sub(item.Name, 1, 7) == "Casino_" or string.sub(item.Name, 1, 6) == "Crate_"
		if item:IsA("MeshPart") and kitPart and folder:FindFirstChild(item.Name) == nil then
			local copy = item:Clone()
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.CFrame = CFrame.new()
			copy.Parent = folder
		end
	end
	result:Destroy()
	folder.Parent = ReplicatedStorage
	ModuleLog.Info("Casino", `kit ready ({#folder:GetChildren()} pieces)`)
end

return CasinoKitLoader
