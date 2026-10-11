--!nonstrict
-- Purpose: public equipped-artifact companion and nameplate, without orbiting
-- shards, particle wakes or world lights. Reads server-replicated attributes.
-- Reads the EquippedArtifact* attributes replicated by GameService:_syncLeaderstats.
-- Owner: presentation. Dependencies: Shared/ElementSprites. Review: 2026-10-09.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local ElementSprites = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ElementSprites"))
local Theme = require(ReplicatedStorage.AstralForge.Shared.ForgeTheme)

local ArtifactPresence = {}

local DRAW_DISTANCE = 140
local MAX_ANIMATED_COMPANIONS = 12
local ATTRS = {
	"EquippedArtifact",
	"EquippedArtifactName",
	"EquippedArtifactElement",
	"EquippedArtifactRarity",
	"EquippedArtifactLevel",
	"EquippedArtifactColor",
	"EquippedArtifactEffect",
}

local function read(player)
	local id = player:GetAttribute("EquippedArtifact")
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local color = player:GetAttribute("EquippedArtifactColor")
	local level = player:GetAttribute("EquippedArtifactLevel")
	local name = player:GetAttribute("EquippedArtifactName")
	return {
		Id = id,
		Name = if type(name) == "string" and name ~= "" then name else id,
		Element = player:GetAttribute("EquippedArtifactElement"),
		Rarity = tostring(player:GetAttribute("EquippedArtifactRarity") or "COMMON"),
		Level = if type(level) == "number" then math.max(1, math.floor(level)) else 1,
		Color = if typeof(color) == "Color3" then color else Color3.fromRGB(240, 212, 140),
		Effect = player:GetAttribute("EquippedArtifactEffect"),
	}
end

local function lighten(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function visibleRig(rig, camera)
	local plate, root = rig.plate, rig.root
	if camera == nil or root == nil or root.Parent == nil or plate == nil or not plate.Enabled
		or plate.Adornee == nil or plate.Adornee.Parent == nil then return false end
	local position = plate.Adornee.Position + plate.StudsOffsetWorldSpace
	local distance = (position - camera.CFrame.Position).Magnitude
	if distance > math.min(DRAW_DISTANCE, plate.MaxDistance) then return false end
	local projected = camera:WorldToViewportPoint(position)
	local viewport = camera.ViewportSize
	return projected.Z > 0 and projected.X >= -120 and projected.X <= viewport.X + 120
		and projected.Y >= -70 and projected.Y <= viewport.Y + 70
end

local function nameplate(info, adornee)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ArtifactPlate"
	gui.Adornee = adornee
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.ResetOnSpawn = false

	-- the companion's elemental light is lit into its own frames; nothing plays behind it
	local sheet = ElementSprites.sheet(info.Element)
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromOffset(64, 64)
	glyph.Position = UDim2.fromOffset(0, 3)
	glyph.ImageColor3 = Color3.new(1, 1, 1)
	glyph.ZIndex = 2
	if sheet ~= nil then
		glyph.Image = sheet.Image
		glyph.ImageRectSize = Vector2.new(ElementSprites.FRAME, ElementSprites.FRAME)
		glyph.ImageRectOffset = Vector2.new(0, 0)
	end
	glyph.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(70, 12)
	title.Size = UDim2.new(1, -70, 0, 22)
	title.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = lighten(info.Color, 0.25)
	title.TextStrokeColor3 = Theme.Base.void
	title.TextStrokeTransparency = 0.35
	title.Text = string.upper(info.Name)
	title.Parent = gui

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(70, 36)
	detail.Size = UDim2.new(1, -70, 0, 26)
	detail.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	detail.TextScaled = true
	detail.TextWrapped = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = Theme.Base.creamSoft
	detail.TextStrokeColor3 = Theme.Base.void
	detail.TextStrokeTransparency = 0.45
	local effect = if type(info.Effect) == "string" and info.Effect ~= "" then ` · {info.Effect}` else ""
	detail.Text = `{string.upper(info.Rarity)} LV{info.Level}{effect}`
	detail.Parent = gui
	return gui, glyph, sheet ~= nil
end

function ArtifactPresence.attach()
	local folder = Instance.new("Folder")
	folder.Name = "ArtifactPresence"
	folder.Parent = workspace

	local rigs = {}
	local watchers = {}
	local connections = {}
	local spriteClock = 0
	local spriteFrame = 0
	local alive = true
	local refreshJobs = {}
	local rigBuilds = {}

	local function clearRig(player)
		rigBuilds[player] = nil
		local rig = rigs[player]
		if rig == nil then
			return
		end
		rigs[player] = nil
		for _, instance in rig.instances do
			instance:Destroy()
		end
	end

	local function burst(rig)
		if GuiService.ReducedMotionEnabled or rig.glyph == nil or rig.glyph.Parent == nil then
			return
		end
		rig.glyph.ImageTransparency = 1
		TweenService:Create(rig.glyph, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { ImageTransparency = 0 }):Play()
	end

	local function buildRig(player, announce)
		if not alive or watchers[player] == nil then
			return
		end
		clearRig(player)
		local info = read(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local head = character and character:FindFirstChild("Head")
		if info == nil or root == nil then
			return
		end
		local buildToken = {}
		rigBuilds[player] = buildToken
		local rig = {
			id = info.Id,
			root = root,
			color = info.Color,
			instances = {},
		}

		local plate, glyph, animated = nameplate(info, head or root)
		plate.Parent = folder
		table.insert(rig.instances, plate)
		rig.glyph = if animated then glyph else nil
		rig.plate = plate

		if rigBuilds[player] ~= buildToken or not alive or watchers[player] == nil
			or player.Parent == nil or player.Character ~= character
			or player:GetAttribute("EquippedArtifact") ~= info.Id then
			for _, instance in rig.instances do
				instance:Destroy()
			end
			return
		end
		rigs[player] = rig
		if announce then
			burst(rig)
		end
	end

	local function watch(player)
		local list = {}
		watchers[player] = list
		local lastId = player:GetAttribute("EquippedArtifact")
		local function refresh(announce)
			local pending = refreshJobs[player]
			if pending ~= nil then
				pending.announce = pending.announce or announce
				return
			end
			pending = { announce = announce }
			refreshJobs[player] = pending
			pending.job = task.defer(function()
				refreshJobs[player] = nil
				buildRig(player, pending.announce)
			end)
		end
		-- EquippedArtifact is written last on the server, so the other fields are already current
		table.insert(list, player:GetAttributeChangedSignal("EquippedArtifact"):Connect(function()
			local nextId = player:GetAttribute("EquippedArtifact")
			local changed = nextId ~= lastId and type(nextId) == "string" and nextId ~= ""
			lastId = nextId
			refresh(changed)
		end))
		for _, attr in ATTRS do
			if attr ~= "EquippedArtifact" then
				table.insert(list, player:GetAttributeChangedSignal(attr):Connect(function()
					local rig = rigs[player]
					if rig ~= nil and rig.id == player:GetAttribute("EquippedArtifact") then
						refresh(false)
					end
				end))
			end
		end
		table.insert(list, player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 5)
			if alive and player.Parent ~= nil and player.Character == character then
				buildRig(player, false)
			end
		end))
		table.insert(list, player.CharacterRemoving:Connect(function()
			clearRig(player)
		end))
		if player.Character ~= nil then
			local character = player.Character
			task.spawn(function()
				character:WaitForChild("HumanoidRootPart", 10)
				if alive and player.Character == character then
					buildRig(player, false)
				end
			end)
		end
	end

	local function unwatch(player)
		local pending = refreshJobs[player]
		if pending ~= nil then
			task.cancel(pending.job)
			refreshJobs[player] = nil
		end
		clearRig(player)
		local list = watchers[player]
		watchers[player] = nil
		if list ~= nil then
			for _, connection in list do
				connection:Disconnect()
			end
		end
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(watch))
	table.insert(connections, Players.PlayerRemoving:Connect(unwatch))

	local frameStep = 1 / ElementSprites.FRAMERATE
	local grid = ElementSprites.FRAME
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		spriteClock += dt
		local advance = false
		if spriteClock >= frameStep then
			local frames = math.floor(spriteClock / frameStep)
			spriteClock %= frameStep
			spriteFrame = (spriteFrame + frames) % ElementSprites.COUNT
			advance = true
		end
		if not advance or GuiService.ReducedMotionEnabled then return end
		local offset = Vector2.new((spriteFrame % ElementSprites.COLUMNS) * grid, math.floor(spriteFrame / ElementSprites.COLUMNS) * grid)
		local animated = 0
		for _, rig in rigs do
			if animated < MAX_ANIMATED_COMPANIONS and rig.glyph ~= nil and visibleRig(rig, camera) then
				animated += 1
				rig.glyph.ImageRectOffset = offset			end
		end
	end))

	return function()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, player in Players:GetPlayers() do
			unwatch(player)
		end
		for player in watchers do
			unwatch(player)
		end
		folder:Destroy()
	end
end

return ArtifactPresence
