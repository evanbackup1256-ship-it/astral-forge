--!strict
-- Purpose: validate a complete Blender crate kit before exposing it to clients.
-- Owner: asset pipeline. Dependencies: InsertService and CrateKit asset manifest.
-- Review: 2026-10-05.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = {}
type Expansion = { Id: number, Skins: { string } }
type KitManifest = { Id: number, Skins: { string }, TextureOverrides: { [string]: number }?, Expansions: { Expansion }? }

local function prepare(item: MeshPart, overrides: { [string]: number }?): MeshPart
	local copy = item:Clone()
	local replacement = overrides and overrides[item.Name]
	if replacement and replacement > 0 then
		copy.TextureID = ("rbxassetid://" .. tostring(replacement)) :: any
		local surface = copy:FindFirstChildWhichIsA("SurfaceAppearance")
		if surface then
			-- SurfaceAppearance maps are not script-writable; drop it so TextureID shows.
			surface:Destroy()
		end
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CFrame = CFrame.new()
	return copy
end

-- Later crates ship as separate kits so the original kit never has to be re-uploaded. A failed or
-- unpublished expansion only costs its own skins (they keep the procedural crate).
local function hasAll(folder: Instance, skins: { string }): boolean
	for _, skinId in skins do
		if not folder:FindFirstChild("Crate_" .. skinId .. "_Body") or not folder:FindFirstChild("Crate_" .. skinId .. "_Lid") then
			return false
		end
	end
	return true
end

local function mergeExpansions(kit: KitManifest, pending: Folder, skins: { string })
	for _, expansion in kit.Expansions or {} do
		if type(expansion.Id) ~= "number" or expansion.Id <= 0 then
			continue
		end
		if hasAll(pending, expansion.Skins) then
			for _, skinId in expansion.Skins do
				table.insert(skins, skinId)
			end
			continue
		end
		local loaded, asset = pcall(function(): Instance
			return InsertService:LoadAsset(expansion.Id)
		end)
		if not loaded then
			warn(`Crate expansion kit {expansion.Id} could not load; its crates stay procedural.`)
			continue
		end
		for _, item in asset:GetDescendants() do
			if item:IsA("MeshPart") and string.sub(item.Name, 1, 6) == "Crate_" and not pending:FindFirstChild(item.Name) then
				prepare(item, kit.TextureOverrides).Parent = pending
			end
		end
		asset:Destroy()
		for _, skinId in expansion.Skins do
			table.insert(skins, skinId)
		end
	end
end

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
	local existing = ReplicatedStorage:FindFirstChild("CrateKit")
	if existing then
		-- a kit saved into the place file skips the base download, but it still needs any
		-- expansion kits published after it was saved
		if existing:IsA("Folder") then
			mergeExpansions(kit, existing, {})
		end
		return true
	end
	local loaded, asset = pcall(function(): Instance
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
			prepare(item, kit.TextureOverrides).Parent = pending
		end
	end
	asset:Destroy()
	local skins = table.clone(kit.Skins)
	mergeExpansions(kit, pending, skins)
	-- Skins without a meshed pair fall back to the client's procedural crate, so only
	-- half pairs and a missing default are fatal.
	local complete, missing = 0, {}
	for _, skinId in skins do
		local hasBody = pending:FindFirstChild("Crate_" .. skinId .. "_Body") ~= nil
		local hasLid = pending:FindFirstChild("Crate_" .. skinId .. "_Lid") ~= nil
		if hasBody and hasLid then
			complete += 1
		else
			for _, piece in { "Body", "Lid" } do
				local orphan = pending:FindFirstChild("Crate_" .. skinId .. "_" .. piece)
				if orphan then
					orphan:Destroy()
				end
			end
			table.insert(missing, skinId)
		end
	end
	if complete == 0 or not pending:FindFirstChild("Crate_Classic_Body") then
		pending:Destroy()
		warn("Crate model kit is incomplete; keeping the existing kit.")
		return false
	end
	if #missing > 0 then
		warn(`Crate model kit has no mesh for {table.concat(missing, ", ")}; those skins use procedural crates.`)
	end
	pending:SetAttribute("AssetId", kit.Id)
	pending.Parent = ReplicatedStorage
	return true
end

return table.freeze(Loader)
