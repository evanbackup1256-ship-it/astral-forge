--!strict

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLog = require(script.Parent:WaitForChild("ModuleLog"))

local PropKitLoader = {}

-- Supply-chain guard: only these root classes are expected from a kit asset.
local ALLOWED_ROOT_CLASSES: { [string]: boolean } = {
	Folder = true,
	Model = true,
	Configuration = true,
}

function PropKitLoader.load()
	task.spawn(function()
		require(script.Parent.CrateKitLoader).load()
	end)
	task.spawn(function()
		require(script.Parent.DomainKitLoader).load()
	end)
	if ReplicatedStorage:FindFirstChild("PropKit") ~= nil then
		return
	end
	local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
	local kit = require(shared:WaitForChild("PropKit")) :: any
	if kit.KitReady ~= true then
		-- Release guard: loading remains non-fatal until the uploaded kit is configured.
		ModuleLog.Warn("PropKit", "[RELEASE BLOCKER] Prop/crate kit is not uploaded; KitReady is false.")
		return
	end
	local id = kit.Id
	if type(id) ~= "number" or id <= 0 then
		ModuleLog.Warn("PropKit", "[RELEASE BLOCKER] Prop/crate kit has no valid uploaded asset ID.")
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
		ModuleLog.Warn("PropKit", `LoadAsset attempt {attempt} failed for asset {id}; retrying...`)
		task.wait(2 * attempt)
	end

	if not ok or typeof(result) ~= "Instance" then
		ModuleLog.Warn("PropKit", `couldn't load the prop kit {id}: {result}. The game owner must own the asset.`)
		return
	end

	-- Reject any inserted asset whose root class is not on the allowlist.
	if not ALLOWED_ROOT_CLASSES[result.ClassName] then
		ModuleLog.Warn("PropKit", `rejected prop kit {id}: unexpected root class {result.ClassName}. Destroying inserted content.`)
		result:Destroy()
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "PropKit"
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
	ModuleLog.Info("PropKit", `kit ready ({#folder:GetChildren()} pieces)`)
end

return PropKitLoader
