--!strict

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLog = require(script.Parent:WaitForChild("ModuleLog"))

local CasinoKitLoader = {}

-- Supply-chain guard: only these root classes are expected from a kit asset.
local ALLOWED_ROOT_CLASSES: { [string]: boolean } = {
	Folder = true,
	Model = true,
	Configuration = true,
}

function CasinoKitLoader.load()
	if ReplicatedStorage:FindFirstChild("CasinoKit") ~= nil then
		return
	end
	local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
	local kit = require(shared:WaitForChild("CasinoKit")) :: any
	if kit.KitReady ~= true then
		-- Release guard: loading remains non-fatal until the uploaded kit is configured.
		ModuleLog.Warn("Casino", "[RELEASE BLOCKER] Casino/crate kit is not uploaded; KitReady is false.")
		return
	end
	local id = kit.Id
	if type(id) ~= "number" or id <= 0 then
		ModuleLog.Warn("Casino", "[RELEASE BLOCKER] Casino/crate kit has no valid uploaded asset ID.")
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
		ModuleLog.Warn("Casino", `LoadAsset attempt {attempt} failed for asset {id}; retrying...`)
		task.wait(2 * attempt)
	end

	if not ok or typeof(result) ~= "Instance" then
		ModuleLog.Warn("Casino", `couldn't load the casino kit {id}: {result}. The game owner must own the asset.`)
		return
	end

	-- Reject any inserted asset whose root class is not on the allowlist.
	if not ALLOWED_ROOT_CLASSES[result.ClassName] then
		ModuleLog.Warn("Casino", `rejected casino kit {id}: unexpected root class {result.ClassName}. Destroying inserted content.`)
		result:Destroy()
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
