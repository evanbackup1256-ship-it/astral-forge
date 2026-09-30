--!strict
-- The model kit (tools/assetgen/meshes.py -> AstralForgeKit.glb) at runtime.
--
-- Where the kit comes from, first match wins:
--   1. ServerStorage.AstralForgeKit   -- imported by hand in Studio
--   2. the uploaded model, Manifest.Kit.Id, loaded with InsertService
-- The server publishes one copy of every MeshPart to
-- ReplicatedStorage.AstralForgeKit, so clients (the Warden's body) clone the
-- same templates. With no kit at all, make() returns nil and every caller
-- falls back to its part-built shape, so the game looks as it did before.
--
--   AssetKit.load(8)                        -- server: at most 8 s; client: waits for the publish
--   AssetKit.make("Crystal", size) -> MeshPart?
--   AssetKit.sized("Obelisk", 1.4) -> Vector3  (native proportions, scaled)

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = if RunService:IsServer() then game:GetService("ServerStorage") else nil

local Manifest = require(script.Parent:WaitForChild("AssetManifest"))

local AssetKit = {}

local PUBLISHED = "AstralForgeKit"

local templates: { [string]: MeshPart? } = {}
local state = "idle" -- idle | loading | ready | missing
local waiters: { thread } = {}

-- Importers sometimes decorate names ("Crystal.001", "Crystal_Mesh"); match
-- the longest kit name the instance's name starts with.
local function kitName(name: string): string?
	local best: string? = nil
	for key in Manifest.Kit.Sizes do
		if name == key then
			return key
		end
		if string.sub(name, 1, #key) == key and not string.match(string.sub(name, #key + 1, #key + 1), "%w") then
			if best == nil or #key > #best then
				best = key
			end
		end
	end
	return best
end

local function collect(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("MeshPart") then
			local key = kitName(item.Name)
			if key ~= nil and templates[key] == nil then
				templates[key] = item
			end
		end
	end
end

local function finish(ready: boolean)
	state = if ready then "ready" else "missing"
	local list = waiters
	waiters = {}
	for _, thread in list do
		task.spawn(thread)
	end
end

local function publish()
	if ReplicatedStorage:FindFirstChild(PUBLISHED) ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = PUBLISHED
	for key, template in templates do
		if template == nil then
			continue
		end
		local copy = template:Clone()
		copy.Name = key
		copy.Anchored = true
		copy.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function loadServer()
	local source: Instance? = if ServerStorage ~= nil then ServerStorage:FindFirstChild(PUBLISHED) else nil
	if source == nil and Manifest.Kit.Id > 0 then
		local ok, result = pcall(function()
			return InsertService:LoadAsset(Manifest.Kit.Id)
		end)
		if ok and typeof(result) == "Instance" then
			source = result
		else
			warn(`[AssetKit] couldn't load kit {Manifest.Kit.Id}: {result}. The game owner must own the asset.`)
		end
	end
	if source ~= nil then
		collect(source)
	end
	if next(templates) ~= nil then
		publish()
	end
	finish(next(templates) ~= nil)
end

local function loadClient()
	local folder = ReplicatedStorage:WaitForChild(PUBLISHED, 12)
	if folder ~= nil then
		collect(folder)
		for _, item in folder:GetChildren() do
			if item:IsA("MeshPart") and templates[item.Name] == nil then
				templates[item.Name] = item
			end
		end
	end
	finish(next(templates) ~= nil)
end

-- Load the kit, waiting at most `timeout` seconds. Safe to call many times.
function AssetKit.load(timeout: number?): boolean
	if state == "ready" or state == "missing" then
		return state == "ready"
	end
	-- Nothing uploaded and nothing imported: skip the wait entirely.
	if RunService:IsServer() and Manifest.Kit.Id == 0 and (ServerStorage == nil or ServerStorage:FindFirstChild(PUBLISHED) == nil) then
		finish(false)
		return false
	end
	if RunService:IsClient() and Manifest.Kit.Id == 0 and ReplicatedStorage:FindFirstChild(PUBLISHED) == nil then
		finish(false)
		return false
	end
	if state == "idle" then
		state = "loading"
		task.spawn(if RunService:IsServer() then loadServer else loadClient)
	end
	if state == "loading" then
		local me = coroutine.running()
		table.insert(waiters, me)
		local deadline = task.delay(timeout or 8, function()
			local index = table.find(waiters, me)
			if index ~= nil then
				table.remove(waiters, index)
				task.spawn(me)
			end
		end)
		coroutine.yield()
		pcall(task.cancel, deadline)
	end
	return state == "ready"
end

function AssetKit.ready(): boolean
	return state == "ready"
end

function AssetKit.has(name: string): boolean
	return templates[name] ~= nil
end

-- Native proportions of a model, scaled.
function AssetKit.sized(name: string, scale: number): Vector3
	local native: Vector3? = Manifest.Kit.Sizes[name]
	return if native ~= nil then native * scale else Vector3.one * scale
end

-- A fresh, anchored MeshPart of `name` at `size`, or nil if the kit isn't loaded.
function AssetKit.make(name: string, size: Vector3, cframe: CFrame?, color: Color3?, material: Enum.Material?, collide: boolean?): MeshPart?
	local template: MeshPart? = templates[name]
	if template == nil then
		return nil
	end
	local part = template:Clone()
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CanCollide = collide == true
	part.CanQuery = collide == true
	part.CanTouch = false
	if cframe ~= nil then
		part.CFrame = cframe
	end
	if color ~= nil then
		part.Color = color
	end
	if material ~= nil then
		part.Material = material
	end
	-- Imported meshes can carry a texture or surface appearance; the kit is
	-- coloured by material, so drop both.
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	pcall(function()
		part.TextureID = ""
	end)
	return part
end

return AssetKit
